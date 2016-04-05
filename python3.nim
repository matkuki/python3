
## Python 3 bindings for the Nim programming language
## Based on Andreas Rumpf's "Light-weight binding for the Python interpreter"
## Copyright (c) Matic Kukovec
## Licensed under the MIT license

## Notes:
##   Functions that are described as being non-portable must be compiled
##   with the same compiler that the Python dynamic library was compiled with

{.deadCodeElim: on.}

import
  dynlib,
  strutils,
  sets

# Define the library filename
when defined(windows): 
  const libraryString = "python(35|34|33|32|31|3).dll"
elif defined(macosx):
  const libraryString = "libpython(3.5|3.4|3.3|3.2|3.1|3).dylib"
else: 
  const versionString = ".1"
  const libraryString = "libpython(3.5|3.4|3.3|3.2|3.1|3).so" & versionString


## Forward declarations for helper procedures needed before their declaration
proc libCandidates*(s: string, dest: var seq[string])
proc loadDllLib*(libNames: string): LibHandle


## Python 3 constants/enums/symbols/...
const
  PYTHON_API_VERSION* = 1013
  PYTHON_API_STRING*  = "1013"
  pySingleInput* = 256
  pyFileInput*   = 257
  pyEvalInput*   = 258
  # Max static block nesting within a function
  CO_FUTURE_DIVISION* = 8192
  # This bit can be set in flags to cause division operator / to be
  # interpreted as “true division” according to PEP 238
  CO_MAXBLOCKS* = 20
  # Method object constants
  METH_VARARGS*  = 0x0001
  METH_KEYWORDS* = 0x0002
  METH_NOARGS*   = 0x0004
  METH_O*        = 0x0008
  METH_CLASS*    = 0x0010
  METH_STATIC*   = 0x0020
  METH_COEXIST*  = 0x0040


type
  UncheckedArray*{.unchecked.}[T] = array[1,T]
  PySizeTPtr = ptr PySizeT
  PySizeT* = int # C definition: 'typedef long PySizeT'
  PyHashT* = PySizeT # C definition: 'typedef PySizeT Py_hash_t;'
  WideCStringPtr* = ptr WideCString
  PyUnicodePtr* = ptr PyUnicode
  PyUnicode* = string # C definition: 'typedef wchar_t Py_UNICODE;'
  PyOS_sighandler_t* = proc (parameter: cint) {.cdecl.}
  
  # Function pointers used for various Python methods
  FreeFunc* = proc (p: pointer){.cdecl.}
  Destructor* = proc (ob: PyObjectPtr){.cdecl.}
  PrintFunc* = proc (ob: PyObjectPtr, f: File, i: int): int{.cdecl.}
  GetAttrFunc* = proc (ob1: PyObjectPtr, name: cstring): PyObjectPtr{.cdecl.}
  GetAttrOFunc* = proc (ob1, ob2: PyObjectPtr): PyObjectPtr{.cdecl.}
  SetAttrFunc* = proc (ob1: PyObjectPtr, name: cstring, ob2: PyObjectPtr): int{.cdecl.}
  SetAttrOFunc* = proc (ob1, ob2, ob3: PyObjectPtr): int{.cdecl.} 
  ReprFunc* = proc (ob: PyObjectPtr): PyObjectPtr{.cdecl.}
  BinaryFunc* = proc (ob1, ob2: PyObjectPtr): PyObjectPtr{.cdecl.}
  TernaryFunc* = proc (ob1, ob2, ob3: PyObjectPtr): PyObjectPtr{.cdecl.}
  UnaryFunc* = proc (ob: PyObjectPtr): PyObjectPtr{.cdecl.}
  Inquiry* = proc (ob: PyObjectPtr): int{.cdecl.}
  LenFunc* = proc (ob: PyObjectPtr): PySizeT{.cdecl.}
  PySizeArgFunc* = proc (ob: PyObjectPtr, i: PySizeT): PyObjectPtr{.cdecl.}
  PySizeSizeArgFunc* = proc (ob: PyObjectPtr, i1, i2: PySizeT): PyObjectPtr{.cdecl.}
  PySizeObjArgFunc* = proc (ob1: PyObjectPtr, i: PySizeT, ob2: PyObjectPtr): int{.cdecl.}
  PySizeSizeObjArgFunc* = proc (ob1: PyObjectPtr, i1, i2: PySizeT, ob2: PyObjectPtr): int{.cdecl.}
  ObjObjArgProc* = proc (ob1, ob2, ob3: PyObjectPtr): int{.cdecl.}
  HashFunc* = proc (ob: PyObjectPtr): PyHashT{.cdecl.}
  GetBufferProc* = proc (ob: PyObjectPtr, buf: PyBufferPtr, i: int)
  ReleaseBufferProc* = proc (ob: PyObjectPtr, buf: PyBufferPtr)
  ObjObjProc* = proc (ob1, ob2: PyObjectPtr): int{.cdecl.}
  VisitProc* = proc (ob: PyObjectPtr, p: pointer): int{.cdecl.}
  TraverseProc* = proc (ob: PyObjectPtr, prc: VisitProc, p: pointer): int{.cdecl.}
  RichCmpFunc* = proc (ob1, ob2: PyObjectPtr, i: int): PyObjectPtr{.cdecl.}
  GetIterFunc* = proc (ob: PyObjectPtr): PyObjectPtr{.cdecl.}
  IterNextFunc* = proc (ob: PyObjectPtr): PyObjectPtr{.cdecl.}
  PyCFunction* = proc (self, args: PyObjectPtr): PyObjectPtr{.cdecl.}
  Getter* = proc (obj: PyObjectPtr, context: pointer): PyObjectPtr{.cdecl.}
  Setter* = proc (obj, value: PyObjectPtr, context: pointer): int{.cdecl.}
  DescrGetFunc* = proc (ob1, ob2, ob3: PyObjectPtr): PyObjectPtr{.cdecl.}
  DescrSetFunc* = proc (ob1, ob2, ob3: PyObjectPtr): int{.cdecl.}
  InitProc* = proc (self, args, kwds: PyObjectPtr): int{.cdecl.}
  NewFunc* = proc (subtype: PyTypeObjectPtr, args, kwds: PyObjectPtr): PyObjectPtr{.cdecl.}
  AllocFunc* = proc (self: PyTypeObjectPtr, nitems: PySizeT): PyObjectPtr{.cdecl.}
  PyTraceFunc* = proc (obj: PyObjectPtr; frame: PyFrameObjectPtr; what: cint; arg: PyObjectPtr): cint{.cdecl.}
  
  PyObjectPtrPtr* = ptr PyObjectPtr
  PyObjectPtr* = ptr PyObject
  PyObject* {.pure, inheritable.} = object # Defined in "Include/object.h"
    ob_refcnt*: PySizeT
    ob_type*: PyTypeObjectPtr
  
  PyTypeObjectPtr* = ptr PyTypeObject
  PyTypeObject* = object of PyObject  # Defined in "Include/object.h"
    # 'ob_base*: PyVarObject' isn't here because the object already inherits from PyObject
    ob_size*: PySizeT
    tp_name*: cstring
    tp_basicsize*: PySizeT
    tp_itemsize*: PySizeT
    # Methods to implement standard operations
    tp_dealloc*: Destructor
    tp_print*: PrintFunc
    tp_getattr*: GetAttrFunc
    tp_setattr*: SetAttrFunc
    tp_reserved*: pointer # formerly known as tp_compare
    tp_repr*: ReprFunc
    # Method suites for standard classes
    tp_as_number*: PyNumberMethodsPtr
    tp_as_sequence*: PySequenceMethodsPtr
    tp_as_mapping*: PyMappingMethodsPtr 
    # More standard operations (here for binary compatibility)
    tp_hash*: HashFunc
    tp_call*: TernaryFunc
    tp_str*: ReprFunc
    tp_getattro*: GetAttrOFunc
    tp_setattro*: SetAttrOFunc
    # Functions to access object as input/output buffer
    tp_as_buffer*: PyBufferProcsPtr
    # Flags to define presence of optional/expanded features
    tp_flags*: int32
    # Documentation string
    tp_doc*: cstring
    # Call function for all accessible objects
    tp_traverse*: TraverseProc
    # Delete references to contained objects
    tp_clear*: Inquiry       
    # Rich comparisons
    tp_richcompare*: RichCmpFunc 
    # Weak reference enabler
    tp_weaklistoffset*: PySizeT 
    # Iterators
    tp_iter*: GetIterFunc
    tp_iternext*: IterNextFunc 
    # Attribute descriptor and subclassing stuff
    tp_methods*: PyMethodDefPtr
    tp_members*: PyMemberDefPtr
    tp_getset*: PyGetSetDefPtr
    tp_base*: PyTypeObjectPtr
    tp_dict*: PyObjectPtr
    tp_descr_get*: DescrGetFunc
    tp_descr_set*: DescrSetFunc
    tp_dictoffset*: PySizeT
    tp_init*: InitProc
    tp_alloc*: AllocFunc
    tp_new*: NewFunc
    tp_free*: FreeFunc # Low-level free-memory routine
    tp_is_gc*: Inquiry  # For PyObject_IS_GC
    tp_bases*: PyObjectPtr
    tp_mro*: PyObjectPtr    # method resolution order
    tp_cache*: PyObjectPtr
    tp_subclasses*: PyObjectPtr
    tp_weaklist*: PyObjectPtr
    tp_del*: Destructor
    tp_version_tag*: uint # Type attribute cache version tag
    tp_finalize*: Destructor
    # These must be last and never explicitly initialized
    tp_allocs*: PySizeT 
    tp_frees*: PySizeT 
    tp_maxalloc*: PySizeT
    tp_prev*: PyTypeObjectPtr
    tp_next*: PyTypeObjectPtr
  
  PyBufferPtr* = ptr PyBuffer
  PyBuffer* {.pure, inheritable.} = object # Defined in "Include/object.h"
    buf*: pointer
    obj*: PyObjectPtr
    length*: PySizeT
    itemsize*: PySizeT
    readonly*: int
    ndim*: int
    format*: cstring
    shape*: PySizeTPtr
    strides*: PySizeTPtr
    suboffsets*: PySizeTPtr
    internal*: pointer
  
  PyNumberMethodsPtr* = ptr PyNumberMethods
  PyNumberMethods*{.final.} = object # Defined in "Include/object.h"
    nb_add*: BinaryFunc
    nb_substract*: BinaryFunc
    nb_multiply*: BinaryFunc
    nb_remainder*: BinaryFunc
    nb_divmod*: BinaryFunc
    nb_power*: TernaryFunc
    nb_negative*: UnaryFunc
    nb_positive*: UnaryFunc
    nb_absolute*: UnaryFunc
    nb_bool*: Inquiry
    nb_invert*: UnaryFunc
    nb_lshift*: BinaryFunc
    nb_rshift*: BinaryFunc
    nb_and*: BinaryFunc
    nb_xor*: BinaryFunc
    nb_or*: BinaryFunc
    nb_int*: UnaryFunc
    nb_reserved*: pointer
    nb_float*: UnaryFunc     
    
    nb_inplace_add*: BinaryFunc
    nb_inplace_subtract*: BinaryFunc
    nb_inplace_multiply*: BinaryFunc
    nb_inplace_remainder*: BinaryFunc
    nb_inplace_power*: TernaryFunc
    nb_inplace_lshift*: BinaryFunc
    nb_inplace_rshift*: BinaryFunc
    nb_inplace_and*: BinaryFunc
    nb_inplace_xor*: BinaryFunc
    nb_inplace_or*: BinaryFunc
    
    nb_floor_divide*: BinaryFunc
    nb_true_divide*: BinaryFunc
    nb_inplace_floor_divide*: BinaryFunc
    nb_inplace_true_divide*: BinaryFunc
    
    nb_index*: UnaryFunc
  
  PySequenceMethodsPtr* = ptr PySequenceMethods
  PySequenceMethods*{.final.} = object    # Defined in "Include/object.h"
    sq_length*: LenFunc
    sq_concat*: BinaryFunc
    sq_repeat*: PySizeArgFunc
    sq_item*: PySizeArgFunc
    was_sq_slice*: pointer
    sq_ass_item*: PySizeObjArgFunc
    was_sq_ass_slice*: pointer 
    sq_contains*: ObjObjProc
    sq_inplace_concat*: BinaryFunc
    sq_inplace_repeat*: PySizeArgFunc
  
  PyMappingMethodsPtr* = ptr PyMappingMethods 
  PyMappingMethods*{.final.} = object # Defined in "Include/object.h"
    mp_length: LenFunc
    mp_subscript: BinaryFunc
    mp_ass_subscript: ObjObjArgProc
  
  PyBufferProcsPtr* = ptr PyBufferProcs
  PyBufferProcs*{.final.} = object    # Defined in "Include/object.h"
    bf_getbuffer*: GetBufferProc
    bf_releasebuffer*: ReleaseBufferProc
  
  PyMethodDefPtr* = ptr PyMethodDef
  PyMethodDef*{.final.} = object  # Defined in "Include/methodobject.h"
    ml_name*: cstring
    ml_meth*: PyCFunction
    ml_flags*: int
    ml_doc*: cstring
  
  PyMemberDefPtr* = ptr PyMemberDef
  PyMemberDef*{.final.} = object  # Defined in "Include/structmember.h"
    name*: cstring
    theType*: int
    offset*: PySizeT
    flags*: int
    doc*: cstring

  PyGetSetDefPtr* = ptr PyGetSetDef
  PyGetSetDef*{.final.} = object  # Defined in "Include/descrobject.h"
    name*: cstring
    get*: Getter
    setter*: Setter
    doc*: cstring
    closure*: pointer
  
  PyVarObjectPtr* = ptr PyVarObject
  PyVarObject* = object # Defined in "Include/object.h"
    ob_base*: PyObject
    ob_size*: PySizeT

  PyCompilerFlagsPtr* = ptr PyCompilerFlags
  PyCompilerFlags* = object # Defined in "Include/pythonrun.h"
    cf_flags: int
  
  PyNodePtr* = ptr PyNode
  PyNode* = object # Defined in "Include/node.h"
    n_type: int16
    n_str: cstring
    n_lineno: int
    n_col_offset: int
    n_nchildren: int
    n_child: PyNodePtr

  PyTryBlockPtr* = ptr PyTryBlock
  PyTryBlock = object # Defined in "Include/frameobject.h"
    b_type: int # what kind of block this is
    b_handler: int # where to jump to find handler
    b_level: int # value stack level to pop to

  PyCodeObjectPtr* = ptr PyCodeObject
  PyCodeObject = object   # Defined in "Include/code.h"
    ob_base*: PyObject
    co_argcount*: int   # arguments, except *args 
    co_kwonlyargcount*: int # keyword only arguments
    co_nlocals*: int    # local variables
    co_stacksize*: int  # entries needed for evaluation stack
    co_flags*: int  # CO_..., see below
    co_code*: PyObjectPtr   # instruction opcodes
    co_consts*: PyObjectPtr # list (constants used)
    co_names*: PyObjectPtr  # list of strings (names used)
    co_varnames*: PyObjectPtr   # tuple of strings (local variable names)
    co_freevars*: PyObjectPtr   # tuple of strings (free variable names)
    co_cellvars*: PyObjectPtr   # tuple of strings (cell variable names)
    # The rest doesn't count for hash or comparisons
    co_cell2arg*: ptr uint8 # Maps cell vars which are arguments
    co_filename*: PyObjectPtr   # unicode (where it was loaded from)
    co_name*: PyObjectPtr   # unicode (name, for reference)
    co_firstlineno*: int    # first source line number
    co_lnotab*: PyObjectPtr # string (encoding addr<->lineno mapping) See Objects/lnotab_notes.txt for details.
    co_zombieframe*: pointer    # for optimization only (see frameobject.c)
    co_weakreflist*: PyObjectPtr    # to support weakrefs to code objects

  PyFrameObjectPtr* = ptr PyFrameObject
  PyFrameObject* = object # Defined in "Include/frameobject.h"
    ob_base*: PyVarObject
    f_back*: PyFrameObjectPtr   # previous frame, or NULL
    f_code*: PyCodeObject       # code segment
    f_builtins*: PyObjectPtr    # builtin symbol table (PyDictObject)
    f_globals*: PyObjectPtr     # global symbol table (PyDictObject)
    f_locals*: PyObjectPtr      # local symbol table (any mapping)
    f_valuestack*: PyObjectPtrPtr   # points after the last local
    f_stacktop*: PyObjectPtrPtr     # points after the last local
    f_trace*: PyObjectPtr   # Trace function
    f_exc_type*, f_exc_value*, f_exc_traceback*: PyObjectPtr
    f_gen*: PyObjectPtr # Borrowed reference to a generator, or NULL
    f_lasti*: int   # Last instruction if called
    f_lineno*: int  # Current line number
    f_iblock*: int  # index in f_blockstack
    f_executing*: int8  # whether the frame is still executing
    f_blockstack: array[0..CO_MAXBLOCKS-1, PyTryBlock]  # for try and loop blocks
    f_localsplus*: UncheckedArray[PyObjectPtr]
    
var
  # Library handle used by the hooks, defined below
  libraryHandle = loadDllLib(libraryString)

  ## Hooks (need to be loaded from the dynamic library)
  # Hook 'PyOS_InputHook' C specification: 'int func(void)'
  PyOS_InputHook* = cast[ptr proc(): int{.cdecl.}](dynlib.symAddr(libraryHandle, "PyOS_InputHook"))
  # Hook 'PyOS_InputHook' C specification: 'char *func(FILE *stdin, FILE *stdout, char *prompt)'
  PyOS_ReadlineFunctionPointer* = cast[ptr proc(): int{.cdecl.}](dynlib.symAddr(libraryHandle, "PyOS_ReadlineFunctionPointer"))
  
  ## Standard exception base classes
  PyExc_BaseException*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_BaseException"))
  PyExc_Exception*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_Exception"))
  PyExc_StopIteration*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_StopIteration"))
  PyExc_GeneratorExit*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_GeneratorExit"))
  PyExc_ArithmeticError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_ArithmeticError"))
  PyExc_LookupError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_LookupError"))
  PyExc_AssertionError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_AssertionError"))
  PyExc_AttributeError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_AttributeError"))
  PyExc_BufferError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_BufferError"))
  PyExc_EOFError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_EOFError"))
  PyExc_FloatingPointError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_FloatingPointError"))
  PyExc_OSError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_OSError"))
  PyExc_ImportError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_ImportError"))
  PyExc_IndexError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_IndexError"))
  PyExc_KeyError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_KeyError"))
  PyExc_KeyboardInterrupt*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_KeyboardInterrupt"))
  PyExc_MemoryError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_MemoryError"))
  PyExc_NameError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_NameError"))
  PyExc_OverflowError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_OverflowError"))
  PyExc_RuntimeError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_RuntimeError"))
  PyExc_NotImplementedError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_NotImplementedError"))
  PyExc_SyntaxError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_SyntaxError"))
  PyExc_IndentationError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_IndentationError"))
  PyExc_TabError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_TabError"))
  PyExc_ReferenceError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_ReferenceError"))
  PyExc_SystemError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_SystemError"))
  PyExc_SystemExit*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_SystemExit"))
  PyExc_TypeError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_TypeError"))
  PyExc_UnboundLocalError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_UnboundLocalError"))
  PyExc_UnicodeError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_UnicodeError"))
  PyExc_UnicodeEncodeError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_UnicodeEncodeError"))
  PyExc_UnicodeDecodeError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_UnicodeDecodeError"))
  PyExc_UnicodeTranslateError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_UnicodeTranslateError"))
  PyExc_ValueError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_ValueError"))
  PyExc_ZeroDivisionError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_ZeroDivisionError"))
  # Exceptions available only in Python 3.3 and higher
  PyExc_BlockingIOError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_BlockingIOError"))
  PyExc_BrokenPipeError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_BrokenPipeError"))
  PyExc_ChildProcessError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_ChildProcessError"))
  PyExc_ConnectionError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_ConnectionError"))
  PyExc_ConnectionAbortedError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_ConnectionAbortedError"))
  PyExc_ConnectionRefusedError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_ConnectionRefusedError"))
  PyExc_ConnectionResetError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_ConnectionResetError"))
  PyExc_FileExistsError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_FileExistsError"))
  PyExc_FileNotFoundError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_FileNotFoundError"))
  PyExc_InterruptedError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_InterruptedError"))
  PyExc_IsADirectoryError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_IsADirectoryError"))
  PyExc_NotADirectoryError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_NotADirectoryError"))
  PyExc_PermissionError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_PermissionError"))
  PyExc_ProcessLookupError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_ProcessLookupError"))
  PyExc_TimeoutError*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "PyExc_TimeoutError"))


## Python C functions that can be used 'As is' from Nim
# Initializing and finalizing the interpreter
proc Py_Initialize*(){.cdecl, importc, dynlib: libraryString.}
proc Py_Finalize*(){.cdecl, importc, dynlib: libraryString.}
# Run the interpreter independantly of the Nim application
proc Py_Main*(argc: int, argv: WideCStringPtr): int{.cdecl, importc, dynlib: libraryString.}
# Execute a script from a string
proc PyRun_SimpleString*(command: cstring): int{.cdecl, importc, dynlib: libraryString.}
proc PyRun_SimpleStringFlags*(command: cstring, flags: PyCompilerFlagsPtr): int{.cdecl, importc, dynlib: libraryString.}
# Advanced string execution
proc PyRun_String*(str: cstring, start: int, globals: PyObjectPtr, locals: PyObjectPtr): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyRun_StringFlags*(str: cstring, start: int, globals: PyObjectPtr, locals: PyObjectPtr, flags: PyCompilerFlags): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
# Parsing python source code and returning a node object
proc PyParser_SimpleParseString*(str: cstring, start: int): PyNodePtr{.cdecl, importc, dynlib: libraryString.}
proc PyParser_SimpleParseStringFlags*(str: cstring, start: int, flags: int): PyNodePtr{.cdecl, importc, dynlib: libraryString.}
proc PyParser_SimpleParseStringFlagsFilename*(str: cstring, filename: cstring, start: int, flags: int): PyNodePtr{.cdecl, importc, dynlib: libraryString.}
# Parse and compile the Python source code in str, returning the resulting code object
proc Py_CompileString*(str: cstring, filename: cstring, start: int): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc Py_CompileStringFlags*(str: cstring, filename: cstring, start: int, flags: PyCompilerFlagsPtr): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc Py_CompileStringExFlags*(str: cstring, filename: cstring, start: int, flags: PyCompilerFlagsPtr, optimize: int): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc Py_CompileStringObject*(str: cstring, filename: PyObjectPtr, start: int, flags: PyCompilerFlagsPtr, optimize: int): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
# Evaluate a precompiled code object, given a particular environment for its evaluation
proc PyEval_EvalCode*(ob: PyObjectPtr, globals: PyObjectPtr, locals: PyObjectPtr): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyEval_EvalCodeEx*(ob: PyObjectPtr, globals: PyObjectPtr, locals: PyObjectPtr, args: PyObjectPtrPtr, argcount: int, kws: PyObjectPtrPtr, kwcount: int, defs: PyObjectPtrPtr, defcount: int, closure: PyObjectPtr): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
# Evaluate an execution frame
proc PyEval_EvalFrame*(f: PyFrameObjectPtr): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
# This is the main, unvarnished function of Python interpretation
proc PyEval_EvalFrameEx*(f: PyFrameObjectPtr, throwflag: int): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
# This function changes the flags of the current evaluation frame, 
# and returns true on success, false on failure
proc PyEval_MergeCompilerFlags*(cf: PyCompilerFlagsPtr): int{.cdecl, importc, dynlib: libraryString.}
# Reference Counting, C macros converted to Nim templates
template Py_INCREF*(ob: PyObjectPtr) = 
  inc(ob.ob_refcnt)

template Py_XINCREF*(ob: PyObjectPtr) =
  if ob != nil:
    Py_INCREF(ob)

template Py_DECREF*(ob: PyObjectPtr) =
  dec(ob.ob_refcnt)
  if ob.ob_refcnt == 0:
    ob.ob_type.tp_dealloc(ob)

template Py_XDECREF*(ob: PyObjectPtr) = 
  if ob != nil:
    Py_DECREF(ob)

template Py_CLEAR*(ob: PyObjectPtr) =
  var
    tempOb: PyObjectPtr = ob
  if tempOb != nil:
    ob = nil
    Py_DECREF(tempOb)
# Exception Handling
proc PyErr_PrintEx*(set_sys_last_vars: int){.cdecl, importc, dynlib: libraryString.}
proc PyErr_Print*(){.cdecl, importc, dynlib: libraryString.}
proc PyErr_Occurred*(): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyErr_ExceptionMatches*(exc: PyObjectPtr): int{.cdecl, importc, dynlib: libraryString.}
proc PyErr_GivenExceptionMatches*(given: PyObjectPtr, exc: PyObjectPtr): int{.cdecl, importc, dynlib: libraryString.}
proc PyErr_NormalizeException*(exc: PyObjectPtrPtr, val: PyObjectPtrPtr, tb: PyObjectPtrPtr){.cdecl, importc, dynlib: libraryString.}
proc PyErr_Clear*(){.cdecl, importc, dynlib: libraryString.}
proc PyErr_Fetch*(ptype: PyObjectPtrPtr, pvalue: PyObjectPtrPtr, ptraceback: PyObjectPtrPtr){.cdecl, importc, dynlib: libraryString.}
proc PyErr_Restore*(typ: PyObjectPtr, value: PyObjectPtr, traceback: PyObjectPtr){.cdecl, importc, dynlib: libraryString.}
proc PyErr_GetExcInfo*(ptype: PyObjectPtrPtr, pvalue: PyObjectPtrPtr, ptraceback: PyObjectPtrPtr){.cdecl, importc, dynlib: libraryString.}
proc PyErr_SetExcInfo*(typ: PyObjectPtr, value: PyObjectPtr, traceback: PyObjectPtr){.cdecl, importc, dynlib: libraryString.}
proc PyErr_SetString*(typ: PyObjectPtr, message: cstring){.cdecl, importc, dynlib: libraryString.}
proc PyErr_SetObject*(typ: PyObjectPtr, value: PyObjectPtr){.cdecl, importc, dynlib: libraryString.}
proc PyErr_Format*(exception: PyObjectPtr, format: cstring): PyObjectPtr{.cdecl, importc, varargs, dynlib: libraryString, discardable.}
proc PyErr_SetNone*(typ: PyObjectPtr){.cdecl, importc, dynlib: libraryString.}
proc PyErr_BadArgument*(): int{.cdecl, importc, dynlib: libraryString.}
proc PyErr_NoMemory*(): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyErr_SetFromErrno*(typ: PyObjectPtr): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyErr_SetFromErrnoWithFilenameObject*(typ: PyObjectPtr, filenameObject: PyObjectPtr): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyErr_SetFromErrnoWithFilenameObjects*(typ: PyObjectPtr, filenameObject: PyObjectPtr, filenameObject2: PyObjectPtr): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyErr_SetFromErrnoWithFilename*(typ: PyObjectPtr, filename: cstring): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyErr_SetFromWindowsErr*(ierr: int): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyErr_SetExcFromWindowsErr*(typ: PyObjectPtr, ierr: int): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyErr_SetFromWindowsErrWithFilename*(ierr: int, filename: cstring): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyErr_SetExcFromWindowsErrWithFilenameObject*(typ: PyObjectPtr, ierr: int, filename: PyObjectPtr): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyErr_SetExcFromWindowsErrWithFilenameObjects*(typ: PyObjectPtr, ierr: int, filename: PyObjectPtr, filename2: PyObjectPtr): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyErr_SetExcFromWindowsErrWithFilename*(typ: PyObjectPtr, ierr: int, filename: cstring): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyErr_SetImportError*(msg: PyObjectPtr, name: PyObjectPtr, path: PyObjectPtr): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyErr_SyntaxLocationObject*(filename: PyObjectPtr, lineno: int, col_offset: int){.cdecl, importc, dynlib: libraryString.}
proc PyErr_SyntaxLocationEx*(filename: cstring, lineno: int, col_offset: int){.cdecl, importc, dynlib: libraryString.}
proc PyErr_SyntaxLocation*(filename: cstring, lineno: int){.cdecl, importc, dynlib: libraryString.}
proc PyErr_BadInternalCall*(){.cdecl, importc, dynlib: libraryString.}
proc PyErr_WarnEx*(category: PyObjectPtr, message: cstring, stack_level: PySizeT): int{.cdecl, importc, dynlib: libraryString.}
proc PyErr_WarnExplicitObject*(category: PyObjectPtr, message: PyObjectPtr, filename: PyObjectPtr, lineno: int, module: PyObjectPtr, registry: PyObjectPtr): int{.cdecl, importc, dynlib: libraryString.}
proc PyErr_WarnExplicit*(category: PyObjectPtr, message: cstring, filename: cstring, lineno: int, module: cstring, registry: PyObjectPtr): int{.cdecl, importc, dynlib: libraryString.}
proc PyErr_WarnFormat*(category: PyObjectPtr, stack_level: PySizeT, format: cstring): int{.cdecl, importc, varargs, dynlib: libraryString.}
proc PyErr_CheckSignals*(): int{.cdecl, importc, dynlib: libraryString.}
proc PyErr_SetInterrupt*(){.cdecl, importc, dynlib: libraryString.}
proc PySignal_SetWakeupFd*(fd: int): int{.cdecl, importc, dynlib: libraryString.}
proc PyErr_NewException*(name: cstring, base: PyObjectPtr, dict: PyObjectPtr): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyErr_NewExceptionWithDoc*(name: cstring, doc: cstring, base: PyObjectPtr, dict: PyObjectPtr): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyErr_WriteUnraisable*(obj: PyObjectPtr){.cdecl, importc, dynlib: libraryString.}
proc PyException_GetTraceback*(ex: PyObjectPtr): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyException_SetTraceback*(ex: PyObjectPtr, tb: PyObjectPtr): int{.cdecl, importc, dynlib: libraryString.}
proc PyException_GetContext*(ex: PyObjectPtr): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyException_SetContext*(ex: PyObjectPtr, ctx: PyObjectPtr){.cdecl, importc, dynlib: libraryString.}
proc PyException_GetCause*(ex: PyObjectPtr): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyException_SetCause*(ex: PyObjectPtr, cause: PyObjectPtr){.cdecl, importc, dynlib: libraryString.}
proc PyUnicodeDecodeError_Create*(encoding: cstring, obj: cstring, length: PySizeT, start: PySizeT, ending: PySizeT, reason: cstring): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyUnicodeEncodeError_Create*(encoding: cstring, obj: PyUnicodePtr, length: PySizeT, start: PySizeT, ending: PySizeT, reason: cstring): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyUnicodeTranslateError_Create*(obj: PyUnicodePtr, length: PySizeT, start: PySizeT, ending: PySizeT, reason: cstring): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyUnicodeDecodeError_GetEncoding*(exc: PyObjectPtr): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyUnicodeEncodeError_GetEncoding*(exc: PyObjectPtr): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyUnicodeDecodeError_GetObject*(exc: PyObjectPtr): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyUnicodeEncodeError_GetObject*(exc: PyObjectPtr): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyUnicodeTranslateError_GetObject*(exc: PyObjectPtr): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyUnicodeDecodeError_GetStart*(exc: PyObjectPtr, start: PySizeTPtr): int{.cdecl, importc, dynlib: libraryString.}
proc PyUnicodeEncodeError_GetStart*(exc: PyObjectPtr, start: PySizeTPtr): int{.cdecl, importc, dynlib: libraryString.}
proc PyUnicodeTranslateError_GetStart*(exc: PyObjectPtr, start: PySizeTPtr): int{.cdecl, importc, dynlib: libraryString.}
proc PyUnicodeDecodeError_SetStart*(exc: PyObjectPtr, start: PySizeT): int{.cdecl, importc, dynlib: libraryString.}
proc PyUnicodeEncodeError_SetStart*(exc: PyObjectPtr, start: PySizeT): int{.cdecl, importc, dynlib: libraryString.}
proc PyUnicodeTranslateError_SetStart*(exc: PyObjectPtr, start: PySizeT): int{.cdecl, importc, dynlib: libraryString.}
proc PyUnicodeDecodeError_GetEnd*(exc: PyObjectPtr, ending: PySizeTPtr): int{.cdecl, importc, dynlib: libraryString.}
proc PyUnicodeEncodeError_GetEnd*(exc: PyObjectPtr, ending: PySizeTPtr): int{.cdecl, importc, dynlib: libraryString.}
proc PyUnicodeTranslateError_GetEnd*(exc: PyObjectPtr, ending: PySizeTPtr): int{.cdecl, importc, dynlib: libraryString.}
proc PyUnicodeDecodeError_SetEnd*(exc: PyObjectPtr, ending: PySizeT): int{.cdecl, importc, dynlib: libraryString.}
proc PyUnicodeEncodeError_SetEnd*(exc: PyObjectPtr, ending: PySizeT): int{.cdecl, importc, dynlib: libraryString.}
proc PyUnicodeTranslateError_SetEnd*(exc: PyObjectPtr, ending: PySizeT): int{.cdecl, importc, dynlib: libraryString.}
proc PyUnicodeDecodeError_GetReason*(exc: PyObjectPtr): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyUnicodeEncodeError_GetReason*(exc: PyObjectPtr): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyUnicodeTranslateError_GetReason*(exc: PyObjectPtr): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyUnicodeDecodeError_SetReason*(exc: PyObjectPtr, reason: cstring): int{.cdecl, importc, dynlib: libraryString.}
proc PyUnicodeEncodeError_SetReason*(exc: PyObjectPtr, reason: cstring): int{.cdecl, importc, dynlib: libraryString.}
proc PyUnicodeTranslateError_SetReason*(exc: PyObjectPtr, reason: cstring): int{.cdecl, importc, dynlib: libraryString.}
proc Py_EnterRecursiveCall*(where: cstring): int{.cdecl, importc, dynlib: libraryString.}
proc Py_LeaveRecursiveCall*(){.cdecl, importc, dynlib: libraryString.}
proc Py_ReprEnter*(obj: PyObjectPtr): int{.cdecl, importc, dynlib: libraryString.}
proc Py_ReprLeave*(obj: PyObjectPtr){.cdecl, importc, dynlib: libraryString.}
# Operating System Utilities
proc PyOS_AfterFork*(){.cdecl, importc, dynlib: libraryString.}
proc PyOS_CheckStack*(): cint{.cdecl, importc, dynlib: libraryString.}
proc PyOS_getsig*(i: cint): PyOS_sighandler_t{.cdecl, importc, dynlib: libraryString.}
proc PyOS_setsig*(i: cint, h: PyOS_sighandler_t): PyOS_sighandler_t{.cdecl, importc, dynlib: libraryString.}
# System Functions
proc PySys_GetObject*(name: cstring): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PySys_SetObject*(name: cstring; v: PyObjectPtr): cint{.cdecl, importc, dynlib: libraryString.}
proc PySys_ResetWarnOptions*(){.cdecl, importc, dynlib: libraryString.}
proc PySys_AddWarnOption*(s: WideCStringPtr){.cdecl, importc, dynlib: libraryString.}
proc PySys_AddWarnOptionUnicode*(unicode: PyObjectPtr){.cdecl, importc, dynlib: libraryString.}
proc PySys_SetPath*(path: WideCStringPtr){.cdecl, importc, dynlib: libraryString.}
proc PySys_WriteStdout*(format: cstring){.cdecl, importc, varargs, dynlib: libraryString.}
proc PySys_WriteStderr*(format: cstring){.cdecl, importc, varargs, dynlib: libraryString.}
proc PySys_FormatStdout*(format: cstring){.cdecl, importc, varargs, dynlib: libraryString.}
proc PySys_FormatStderr*(format: cstring){.cdecl, importc, varargs, dynlib: libraryString.}
proc PySys_AddXOption*(s: WideCStringPtr){.cdecl, importc, dynlib: libraryString.}
proc PySys_GetXOptions*(): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
# Process Control
proc Py_FatalError*(message: cstring){.cdecl, importc, dynlib: libraryString.}
proc Py_Exit*(status: cint){.cdecl, importc, dynlib: libraryString.}
proc Py_AtExit*(fun: proc (){.cdecl}): cint{.cdecl, importc, dynlib: libraryString.}


## Functions that are not portable across compilers (The 'File' type is different across compilers),
## each is usually followed by a Nim portable implementation of the same function
# Execute a script from a file
proc PyRun_AnyFile*(fp: File, filename: cstring): int{.cdecl, importc, dynlib: libraryString.}
proc PyRun_AnyFile*(filename: string): int =
  result = PyRun_SimpleString(readFile(filename))
# Execute a script from a file with flags
proc PyRun_AnyFileFlags*(fp: File, filename: cstring, flags: PyCompilerFlags): int{.cdecl, importc, dynlib: libraryString.}
proc PyRun_AnyFileFlags*(filename: string, flags: PyCompilerFlagsPtr): int =
  result = PyRun_SimpleStringFlags(readFile(filename), flags)
# Executing a script from a file with additional options and a return value
proc PyRun_File*(fp: File, filename: cstring, start: int, globals: PyObjectPtr, locals: PyObjectPtr): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyRun_File*(filename: string, start: int, globals: PyObjectPtr, locals: PyObjectPtr): PyObjectPtr =
  var fileContents = readFile(fileName)
  result = PyRun_String(fileContents, pyFileInput, globals, locals)
proc PyRun_FileFlags*(fp: File, filename: cstring, start: int, globals: PyObjectPtr, locals: PyObjectPtr, flags: PyCompilerFlags): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyRun_FileFlags*(filename: string, start: int, globals: PyObjectPtr, locals: PyObjectPtr, flags: PyCompilerFlags): PyObjectPtr =
  var fileContents = readFile(fileName)
  result = PyRun_StringFlags(fileContents, pyFileInput, globals, locals, flags)
# These C functions do not need to be ported, the above procedures are enough
proc PyRun_AnyFileEx*(fp: File, filename: cstring, closeit: int): int{.cdecl, importc, dynlib: libraryString.}
proc PyRun_AnyFileExFlags*(fp: File, filename: cstring, closeit: int, flags: PyCompilerFlags): int{.cdecl, importc, dynlib: libraryString.}
proc PyRun_SimpleFile*(fp: File, filename: cstring): int{.cdecl, importc, dynlib: libraryString.}
proc PyRun_SimpleFileEx*(fp: File, filename: cstring, closeit: int): int{.cdecl, importc, dynlib: libraryString.}
proc PyRun_SimpleFileExFlags*(fp: File, filename: cstring, closeit: int, flags: PyCompilerFlags): int{.cdecl, importc, dynlib: libraryString.}
proc PyParser_SimpleParseFile*(fp: File, filename: cstring, start: int): PyNodePtr{.cdecl, importc, dynlib: libraryString.}
proc PyParser_SimpleParseFileFlags*(fp: File, filename: cstring, start: int, flags: int): PyNodePtr{.cdecl, importc, dynlib: libraryString.}
proc PyRun_FileEx*(fp: File, filename: cstring, start: int, globals: PyObjectPtr, locals: PyObjectPtr, closeit: int): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
proc PyRun_FileExFlags*(fp: File, filename: cstring, start: int, globals: PyObjectPtr, locals: PyObjectPtr, closeit: int, flags: PyCompilerFlags): PyObjectPtr{.cdecl, importc, dynlib: libraryString.}
# Functions for reading and executing code from a file associated with an interactive device. For now they will stay non-portable.
proc PyRun_InteractiveOne*(fp: File, filename: cstring): int{.cdecl, importc, dynlib: libraryString.}
proc PyRun_InteractiveOneFlags*(fp: File, filename: cstring, flags: PyCompilerFlags): int{.cdecl, importc, dynlib: libraryString.}
proc PyRun_InteractiveLoop*(fp: File, filename: cstring): int{.cdecl, importc, dynlib: libraryString.}
proc PyRun_InteractiveLoopFlags*(fp: File, filename: cstring, flags: PyCompilerFlags): int{.cdecl, importc, dynlib: libraryString.}
# Non-portable operating system functions
proc Py_FdIsInteractive*(fp: File; filename: cstring): cint{.cdecl, importc, dynlib: libraryString.}


#Importing modules
type 
  InitTab* {.final.} = object 
    name*: cstring
    initfunc*: proc (): PyObjectPtr {.cdecl.}

  FrozenPtr* = ptr Frozen
  Frozen* {.final.} = object
    name*: cstring
    code*: ptr cuchar
    size*: cint

var PyImport_FrozenModules*: FrozenPtr = cast[FrozenPtr](dynlib.symAddr(libraryHandle, "PyImport_FrozenModules"))
    
proc PyImport_ImportModule*(name: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyImport_ImportModuleNoBlock*(name: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyImport_ImportModuleEx*(name: cstring; globals: PyObjectPtr; locals: PyObjectPtr; fromlist: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyImport_ImportModuleLevelObject*(name: PyObjectPtr; globals: PyObjectPtr; locals: PyObjectPtr; fromlist: PyObjectPtr; level: cint): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyImport_ImportModuleLevel*(name: cstring; globals: PyObjectPtr; locals: PyObjectPtr; fromlist: PyObjectPtr; level: cint): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyImport_Import*(name: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyImport_ReloadModule*(m: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyImport_AddModuleObject*(name: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyImport_AddModule*(name: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyImport_ExecCodeModule*(name: cstring; co: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyImport_ExecCodeModuleEx*(name: cstring; co: PyObjectPtr; pathname: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyImport_ExecCodeModuleObject*(name: PyObjectPtr; co: PyObjectPtr; pathname: PyObjectPtr; cpathname: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyImport_ExecCodeModuleWithPathnames*(name: cstring; co: PyObjectPtr; pathname: cstring; cpathname: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyImport_GetMagicNumber*(): clong {.cdecl, importc, dynlib: libraryString.}
proc PyImport_GetMagicTag*(): cstring {.cdecl, importc, dynlib: libraryString.}
proc PyImport_GetModuleDict*(): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyImport_GetImporter*(path: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyImport_Init*() {.cdecl, importc: "_PyImport_Init", dynlib: libraryString.}
proc PyImport_Cleanup*() {.cdecl, importc, dynlib: libraryString.}
proc PyImport_Fini*() {.cdecl, importc: "_PyImport_Fini", dynlib: libraryString.}
proc PyImport_FindExtension*(arg0: cstring; arg1: cstring): PyObjectPtr {.cdecl, importc: "_PyImport_FindExtension", dynlib: libraryString.}
proc PyImport_ImportFrozenModuleObject*(name: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyImport_ImportFrozenModule*(name: cstring): cint {.cdecl, importc, dynlib: libraryString.}
proc PyImport_AppendInittab*(name: cstring; initfunc: proc (): PyObjectPtr {.cdecl.}): cint {.cdecl, importc, dynlib: libraryString, discardable.}
proc PyImport_ExtendInittab*(newtab: ptr InitTab): cint {.cdecl, importc, dynlib: libraryString.}

#Data marshalling support
proc PyMarshal_WriteLongToFile*(value: clong; file: File; version: cint) {.cdecl, importc, dynlib: libraryString.}
proc PyMarshal_WriteObjectToFile*(value: PyObjectPtr; file: File; version: cint) {.cdecl, importc, dynlib: libraryString.}
proc PyMarshal_WriteObjectToString*(value: PyObjectPtr; version: cint): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyMarshal_ReadLongFromFile*(file: File): clong {.cdecl, importc, dynlib: libraryString.}
proc PyMarshal_ReadShortFromFile*(file: File): cint {.cdecl, importc, dynlib: libraryString.}
proc PyMarshal_ReadObjectFromFile*(file: File): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyMarshal_ReadLastObjectFromFile*(file: File): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyMarshal_ReadObjectFromString*(string: cstring; len: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}

#Parsing arguments and building values
proc PyArg_ParseTuple*(args: PyObjectPtr; format: cstring): cint {.varargs, cdecl, importc, dynlib: libraryString.}
proc PyArg_VaParse*(args: PyObjectPtr; format: cstring; vargs: varargs): cint {.cdecl, importc, dynlib: libraryString.}
proc PyArg_ParseTupleAndKeywords*(args: PyObjectPtr; kw: PyObjectPtr; format: cstring; keywords: ptr cstring): cint {.varargs, cdecl, importc, dynlib: libraryString.}
proc PyArg_VaParseTupleAndKeywords*(args: PyObjectPtr; kw: PyObjectPtr; format: cstring; keywords: ptr cstring; vargs: varargs): cint {.cdecl, importc, dynlib: libraryString.}
proc PyArg_ValidateKeywordArguments*(arg: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyArg_Parse*(args: PyObjectPtr; format: cstring): cint {.varargs, cdecl, importc, dynlib: libraryString.}
proc PyArg_UnpackTuple*(args: PyObjectPtr; name: cstring; min: PySizeT; max: PySizeT): cint {.varargs, cdecl, importc, dynlib: libraryString.}
proc Py_BuildValue*(format: cstring): PyObjectPtr {.varargs, cdecl, importc, dynlib: libraryString.}
proc Py_VaBuildValue*(format: cstring; vargs: varargs): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}

#String conversion and formatting
proc PyOS_snprintf*(str: cstring; size: csize; format: cstring): cint {.varargs, cdecl, importc, dynlib: libraryString.}
proc PyOS_vsnprintf*(str: cstring; size: csize; format: cstring; va: varargs): cint {.cdecl, importc, dynlib: libraryString.}
proc PyOS_string_to_double*(s: cstring; endptr: cstringArray; overflow_exception: PyObjectPtr): cdouble {.cdecl, importc, dynlib: libraryString.}
proc PyOS_double_to_string*(val: cdouble; format_code: char; precision: cint; flags: cint; ptype: ptr cint): cstring {.cdecl, importc, dynlib: libraryString.}
proc PyOS_stricmp*(s1: cstring; s2: cstring): cint {.cdecl, importc, dynlib: libraryString.}
proc PyOS_strnicmp*(s1: cstring; s2: cstring; size: PySizeT): cint {.cdecl, importc, dynlib: libraryString.}

#Reflection
proc PyEval_GetBuiltins*(): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyEval_GetLocals*(): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyEval_GetGlobals*(): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyEval_GetFrame*(): PyFrameObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyFrame_GetLineNumber*(frame: PyFrameObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyEval_GetFuncName*(fun: PyObjectPtr): cstring {.cdecl, importc, dynlib: libraryString.}
proc PyEval_GetFuncDesc*(fun: PyObjectPtr): cstring {.cdecl, importc, dynlib: libraryString.}

#Codec registry and support functions
proc PyCodec_Register*(search_function: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyCodec_KnownEncoding*(encoding: cstring): cint {.cdecl, importc, dynlib: libraryString.}
proc PyCodec_Encode*(`object`: PyObjectPtr; encoding: cstring; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyCodec_Decode*(`object`: PyObjectPtr; encoding: cstring; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyCodec_Encoder*(encoding: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyCodec_IncrementalEncoder*(encoding: cstring; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyCodec_IncrementalDecoder*(encoding: cstring; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyCodec_StreamReader*(encoding: cstring; stream: PyObjectPtr; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyCodec_StreamWriter*(encoding: cstring; stream: PyObjectPtr; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyCodec_RegisterError*(name: cstring; error: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyCodec_LookupError*(name: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyCodec_StrictErrors*(exc: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyCodec_IgnoreErrors*(exc: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyCodec_ReplaceErrors*(exc: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyCodec_XMLCharRefReplaceErrors*(exc: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyCodec_BackslashReplaceErrors*(exc: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}

#Object Protocol
var Py_NotImplemented*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "Py_NotImplemented"))

proc PyObject_Print*(o: PyObjectPtr; fp: File; flags: cint): cint {.cdecl, importc, dynlib: libraryString.}
proc PyObject_HasAttr*(o: PyObjectPtr; attr_name: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyObject_HasAttrString*(o: PyObjectPtr; attr_name: cstring): cint {.cdecl, importc, dynlib: libraryString.}
proc PyObject_GetAttr*(o: PyObjectPtr; attr_name: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyObject_GetAttrString*(o: PyObjectPtr; attr_name: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyObject_GenericGetAttr*(o: PyObjectPtr; name: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyObject_SetAttr*(o: PyObjectPtr; attr_name: PyObjectPtr; v: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyObject_SetAttrString*(o: PyObjectPtr; attr_name: cstring; v: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyObject_GenericSetAttr*(o: PyObjectPtr; name: PyObjectPtr; value: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyObject_DelAttr*(o: PyObjectPtr; attr_name: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyObject_DelAttrString*(o: PyObjectPtr; attr_name: cstring): cint {.cdecl, importc, dynlib: libraryString.}
proc PyObject_GenericGetDict*(o: PyObjectPtr; context: pointer): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyObject_GenericSetDict*(o: PyObjectPtr; context: pointer): cint {.cdecl, importc, dynlib: libraryString.}
proc PyObject_RichCompare*(o1: PyObjectPtr; o2: PyObjectPtr; opid: cint): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyObject_RichCompareBool*(o1: PyObjectPtr; o2: PyObjectPtr; opid: cint): cint {.cdecl, importc, dynlib: libraryString.}
proc PyObject_Repr*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyObject_ASCII*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyObject_Str*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyObject_Bytes*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyObject_IsSubclass*(derived: PyObjectPtr; cls: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyObject_IsInstance*(inst: PyObjectPtr; cls: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyCallable_Check*(o: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyObject_Call*(callable_object: PyObjectPtr; args: PyObjectPtr; kw: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyObject_CallObject*(callable_object: PyObjectPtr; args: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyObject_CallFunction*(callable: PyObjectPtr; format: cstring): PyObjectPtr {.varargs, cdecl, importc, dynlib: libraryString.}
proc PyObject_CallMethod*(o: PyObjectPtr; meth: cstring; format: cstring): PyObjectPtr {.varargs, cdecl, importc, dynlib: libraryString.}
proc PyObject_CallFunctionObjArgs*(callable: PyObjectPtr): PyObjectPtr {.varargs, cdecl, importc, dynlib: libraryString.} #Last paramater HAS to be NULL {.cdecl, importc, dynlib: libraryString.}
proc PyObject_CallMethodObjArgs*(o: PyObjectPtr; name: PyObjectPtr): PyObjectPtr {.varargs, cdecl, importc, dynlib: libraryString.} #Last paramater HAS to be NULL {.cdecl, importc, dynlib: libraryString.}
proc PyObject_Hash*(o: PyObjectPtr): PyHashT {.cdecl, importc, dynlib: libraryString.}
proc PyObject_HashNotImplemented*(o: PyObjectPtr): PyHashT {.cdecl, importc, dynlib: libraryString.}
proc PyObject_IsTrue*(o: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyObject_Not*(o: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyObject_Type*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyObject_TypeCheck*(o: PyObjectPtr; typ: PyTypeObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyObject_Length*(o: PyObjectPtr): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PyObject_Size*(o: PyObjectPtr): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PyObject_LengthHint*(o: PyObjectPtr; default: PySizeT): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PyObject_GetItem*(o: PyObjectPtr; key: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyObject_SetItem*(o: PyObjectPtr; key: PyObjectPtr; v: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyObject_DelItem*(o: PyObjectPtr; key: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyObject_Dir*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyObject_GetIter*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}

#Number Protocol
proc PyNumber_Check*(o: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_Add*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_Subtract*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_Multiply*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_FloorDivide*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_TrueDivide*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_Remainder*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_Divmod*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_Power*(o1: PyObjectPtr; o2: PyObjectPtr; o3: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_Negative*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_Positive*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_Absolute*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_Invert*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_Lshift*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_Rshift*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_And*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_Xor*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_Or*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_InPlaceAdd*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_InPlaceSubtract*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_InPlaceMultiply*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_InPlaceFloorDivide*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_InPlaceTrueDivide*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_InPlaceRemainder*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_InPlacePower*(o1: PyObjectPtr; o2: PyObjectPtr; o3: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_InPlaceLshift*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_InPlaceRshift*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_InPlaceAnd*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_InPlaceXor*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_InPlaceOr*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_Long*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_Float*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_Index*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_ToBase*(n: PyObjectPtr; base: cint): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyNumber_AsSsize_t*(o: PyObjectPtr; exc: PyObjectPtr): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PyIndex_Check*(o: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}

#Sequence Protocol
proc PySequence_Check*(o: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PySequence_Size*(o: PyObjectPtr): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PySequence_Length*(o: PyObjectPtr): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PySequence_Concat*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PySequence_Repeat*(o: PyObjectPtr; count: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PySequence_InPlaceConcat*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PySequence_InPlaceRepeat*(o: PyObjectPtr; count: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PySequence_GetItem*(o: PyObjectPtr; i: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PySequence_GetSlice*(o: PyObjectPtr; i1: PySizeT; i2: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PySequence_SetItem*(o: PyObjectPtr; i: PySizeT; v: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PySequence_DelItem*(o: PyObjectPtr; i: PySizeT): cint {.cdecl, importc, dynlib: libraryString.}
proc PySequence_SetSlice*(o: PyObjectPtr; i1: PySizeT; i2: PySizeT; v: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PySequence_DelSlice*(o: PyObjectPtr; i1: PySizeT; i2: PySizeT): cint {.cdecl, importc, dynlib: libraryString.}
proc PySequence_Count*(o: PyObjectPtr; value: PyObjectPtr): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PySequence_Contains*(o: PyObjectPtr; value: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PySequence_Index*(o: PyObjectPtr; value: PyObjectPtr): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PySequence_List*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PySequence_Tuple*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PySequence_Fast*(o: PyObjectPtr; m: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PySequence_Fast_GET_ITEM*(o: PyObjectPtr; i: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PySequence_Fast_ITEMS*(o: PyObjectPtr): ptr PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PySequence_ITEM*(o: PyObjectPtr; i: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PySequence_Fast_GET_SIZE*(o: PyObjectPtr): PySizeT {.cdecl, importc, dynlib: libraryString.}

#Mapping Protocol
proc PyMapping_Check*(o: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyMapping_Size*(o: PyObjectPtr): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PyMapping_Length*(o: PyObjectPtr): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PyMapping_DelItemString*(o: PyObjectPtr; key: cstring): cint {.cdecl, importc, dynlib: libraryString.}
proc PyMapping_DelItem*(o: PyObjectPtr; key: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyMapping_HasKeyString*(o: PyObjectPtr; key: cstring): cint {.cdecl, importc, dynlib: libraryString.}
proc PyMapping_HasKey*(o: PyObjectPtr; key: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyMapping_Keys*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyMapping_Values*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyMapping_Items*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyMapping_GetItemString*(o: PyObjectPtr; key: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyMapping_SetItemString*(o: PyObjectPtr; key: cstring; v: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}

#Iterator Protocol
proc PyIter_Check*(o: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyIter_Next*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyObject_CheckBuffer*(obj: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyObject_GetBuffer*(exporter: PyObjectPtr; view: PyBufferPtr; flags: cint): cint {.cdecl, importc, dynlib: libraryString.}
proc PyBuffer_Release*(view: PyBufferPtr) {.cdecl, importc, dynlib: libraryString.}
proc PyBuffer_SizeFromFormat*(arg: cstring): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PyBuffer_IsContiguous*(view: PyBufferPtr; order: char): cint {.cdecl, importc, dynlib: libraryString.}
proc PyBuffer_FillContiguousStrides*(ndim: cint; shape: PySizeTPtr; strides: PySizeTPtr; itemsize: PySizeT; order: char) {.cdecl, importc, dynlib: libraryString.}
proc PyBuffer_FillInfo*(view: PyBufferPtr; exporter: PyObjectPtr; buf: pointer; len: PySizeT; readonly: cint; flags: cint): cint {.cdecl, importc, dynlib: libraryString.}

#Type Objects
type
  PyTypeSlotPtr* = ptr PyTypeSlot
  PyTypeSlot* {.final.} = object 
    slot*: cint
    pfunc*: pointer

  PyTypeSpecPtr* = ptr PyTypeSpec
  PyTypeSpec* {.final.} = object 
    name*: cstring
    basicsize*: cint
    itemsize*: cint
    flags*: cuint
    slots*: PyTypeSlotPtr
    
var 
  PyType_Type*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "PyType_Type"))
  PyBaseObject_Type*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "PyBaseObject_Type"))
  PySuper_Type*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "PySuper_Type"))

proc PyType_Check*(o: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyType_CheckExact*(o: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyType_ClearCache*(): cuint {.cdecl, importc, dynlib: libraryString.}
proc PyType_GetFlags*(typ: PyTypeObjectPtr): clong {.cdecl, importc, dynlib: libraryString.}
proc PyType_Modified*(typ: PyTypeObjectPtr) {.cdecl, importc, dynlib: libraryString.}
proc PyType_HasFeature*(o: PyTypeObjectPtr; feature: cint): cint {.cdecl, importc, dynlib: libraryString.}
proc PyType_IS_GC*(o: PyTypeObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyType_IsSubtype*(a: PyTypeObjectPtr; b: PyTypeObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyType_GenericAlloc*(typ: PyTypeObjectPtr; nitems: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyType_GenericNew*(typ: PyTypeObjectPtr; args: PyObjectPtr; kwds: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyType_Ready*(typ: PyTypeObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyType_FromSpec*(spec: PyTypeSpecPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyType_FromSpecWithBases*(spec: PyTypeSpecPtr; bases: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyType_GetSlot*(typ: PyTypeObjectPtr; slot: cint): pointer {.cdecl, importc, dynlib: libraryString.}

#The None Object
var Py_NoneStruct*: PyObject = cast[PyObject](dynlib.symAddr(libraryHandle, "_Py_NoneStruct"))

template Py_None*(): expr = addr(Py_NoneStruct)
template Py_RETURN_NONE*(): expr =
    Py_INCREF(Py_None)
    return Py_None

#Integer Objects
var PyLong_Type*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "PyLong_Type"))

proc PyLong_Check*(p: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyLong_CheckExact*(p: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyLong_FromLong*(v: clong): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyLong_FromUnsignedLong*(v: culong): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyLong_FromSsize_t*(v: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyLong_FromSize_t*(v: csize): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
#PyObject* PyLong_FromLongLong(PY_LONG_LONG v);
#PyObject* PyLong_FromUnsignedLongLong(unsigned PY_LONG_LONG v);

proc PyLong_FromDouble*(v: cdouble): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyLong_FromString*(str: cstring; pend: cstringArray; base: cint): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyLong_FromUnicode*(u: PyUnicodePtr; length: PySizeT; base: cint): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyLong_FromUnicodeObject*(u: PyObjectPtr; base: cint): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyLong_FromVoidPtr*(p: pointer): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyLong_AsLong*(obj: PyObjectPtr): clong {.cdecl, importc, dynlib: libraryString.}
proc PyLong_AsLongAndOverflow*(obj: PyObjectPtr; overflow: ptr cint): clong {.cdecl, importc, dynlib: libraryString.}
proc PyLong_AsLongLong*(obj: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyLong_AsLongLongAndOverflow*(obj: PyObjectPtr; overflow: ptr cint): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyLong_AsSsize_t*(pylong: PyObjectPtr): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PyLong_AsUnsignedLong*(pylong: PyObjectPtr): culong {.cdecl, importc, dynlib: libraryString.}
proc PyLong_AsSize_t*(pylong: PyObjectPtr): csize {.cdecl, importc, dynlib: libraryString.}
proc PyLong_AsUnsignedLongLong*(pylong: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}

proc PyLong_AsUnsignedLongMask*(obj: PyObjectPtr): culong {.cdecl, importc, dynlib: libraryString.}
proc PyLong_AsUnsignedLongLongMask*(obj: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}

proc PyLong_AsDouble*(pylong: PyObjectPtr): cdouble {.cdecl, importc, dynlib: libraryString.}
proc PyLong_AsVoidPtr*(pylong: PyObjectPtr): pointer {.cdecl, importc, dynlib: libraryString.}

#Boolean Objects
var 
  Py_False*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "Py_False"))
  Py_True*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "Py_True"))

proc PyBool_Check*(o: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyBool_FromLong*(v: clong): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}

#Floating Point Objects
var PyFloat_Type*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "PyFloat_Type"))

proc PyFloat_Check*(p: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyFloat_CheckExact*(p: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyFloat_FromString*(str: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyFloat_FromDouble*(v: cdouble): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyFloat_AsDouble*(pyfloat: PyObjectPtr): cdouble {.cdecl, importc, dynlib: libraryString.}
#proc PyFloat_AS_DOUBLE*(pyfloat: PyObjectPtr): cdouble {.cdecl, importc, dynlib: libraryString.}
proc PyFloat_GetInfo*(): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyFloat_GetMax*(): cdouble {.cdecl, importc, dynlib: libraryString.}
proc PyFloat_GetMin*(): cdouble {.cdecl, importc, dynlib: libraryString.}
proc PyFloat_ClearFreeList*(): cint {.cdecl, importc, dynlib: libraryString.}

#Complex Number Objects
type
  PyComplex* {.final.} = object 
    real*: float64
    imag*: float64

var PyComplex_Type*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "PyComplex_Type"))

proc Py_c_sum*(left: PyComplex; right: PyComplex): PyComplex {.cdecl, importc: "_Py_c_sum", dynlib: libraryString.}
proc Py_c_diff*(left: PyComplex; right: PyComplex): PyComplex {.cdecl, importc: "_Py_c_diff", dynlib: libraryString.}
proc Py_c_neg*(complex: PyComplex): PyComplex {.cdecl, importc: "_Py_c_neg", dynlib: libraryString.}
proc Py_c_prod*(left: PyComplex; right: PyComplex): PyComplex {.cdecl, importc: "_Py_c_prod", dynlib: libraryString.}
proc Py_c_quot*(dividend: PyComplex; divisor: PyComplex): PyComplex {.cdecl, importc: "_Py_c_quot", dynlib: libraryString.}
proc Py_c_pow*(num: PyComplex; exp: PyComplex): PyComplex {.cdecl, importc: "_Py_c_pow", dynlib: libraryString.}
proc PyComplex_Check*(p: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyComplex_CheckExact*(p: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyComplex_FromCComplex*(v: PyComplex): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyComplex_FromDoubles*(real: cdouble; imag: cdouble): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyComplex_RealAsDouble*(op: PyObjectPtr): cdouble {.cdecl, importc, dynlib: libraryString.}
proc PyComplex_ImagAsDouble*(op: PyObjectPtr): cdouble {.cdecl, importc, dynlib: libraryString.}
proc PyComplex_AsCComplex*(op: PyObjectPtr): PyComplex {.cdecl, importc, dynlib: libraryString.}

#Bytes Objects
var PyBytes_Type*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "PyBytes_Type"))

proc PyBytes_Check*(o: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyBytes_CheckExact*(o: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyBytes_FromString*(v: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyBytes_FromStringAndSize*(v: cstring; len: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyBytes_FromFormat*(format: cstring): PyObjectPtr {.varargs, cdecl, importc, dynlib: libraryString.}
proc PyBytes_FromFormatV*(format: cstring; vargs: varargs): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyBytes_FromObject*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyBytes_Size*(o: PyObjectPtr): PySizeT {.cdecl, importc, dynlib: libraryString.}
#proc PyBytes_GET_SIZE*(o: PyObjectPtr): PySizeT
proc PyBytes_AsString*(o: PyObjectPtr): cstring {.cdecl, importc, dynlib: libraryString.}
#proc PyBytes_AS_STRING*(string: PyObjectPtr): cstring
proc PyBytes_AsStringAndSize*(obj: PyObjectPtr; buffer: cstringArray; length: PySizeTPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyBytes_Concat*(bytes: ptr PyObjectPtr; newpart: PyObjectPtr) {.cdecl, importc, dynlib: libraryString.}
proc PyBytes_ConcatAndDel*(bytes: ptr PyObjectPtr; newpart: PyObjectPtr) {.cdecl, importc, dynlib: libraryString.}
proc PyBytes_Resize*(bytes: ptr PyObjectPtr; newsize: PySizeT): cint {.cdecl, importc: "_PyBytes_Resize", dynlib: libraryString.}

#Byte Array Objects
var PyByteArray_Type*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "PyByteArray_Type"))

proc PyByteArray_Check*(o: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyByteArray_CheckExact*(o: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyByteArray_FromObject*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyByteArray_FromStringAndSize*(string: cstring; length: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyByteArray_Concat*(a: PyObjectPtr; b: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyByteArray_Size*(bytearray: PyObjectPtr): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PyByteArray_AsString*(bytearray: PyObjectPtr): cstring {.cdecl, importc, dynlib: libraryString.}
proc PyByteArray_Resize*(bytearray: PyObjectPtr; length: PySizeT): cint {.cdecl, importc, dynlib: libraryString.}

#Unicode Objects and Codecs
type 
  Py_UCS1* = cuchar
  Py_UCS2* = cushort

when sizeof(int) == 4: 
  type 
    Py_UCS4* = cuint
elif sizeof(clong) == 4: 
  type 
    Py_UCS4* = culong
type 
  INNER_C_UNION_4256751451* = object  {.union.}
    any*: pointer
    latin1*: ptr Py_UCS1
    ucs2*: ptr Py_UCS2
    ucs4*: ptr Py_UCS4

  PyASCIIObject* = object 
    ob_base*: PyObject
    length*: PySizeT       
    hash*: PyHashT  
    wstr*: PyUnicodePtr
  
  PyCompactUnicodeObject* = object 
    base*: PyASCIIObject
    utf8_length*: PySizeT 
    utf8*: cstring          
    wstr_length*: PySizeT
  
  PyUnicodeObject* = object 
    base*: PyCompactUnicodeObject
    data*: INNER_C_UNION_4256751451 # Canonical, smallest-form Unicode buffer 

var PyUnicode_Type*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "PyUnicode_Type"))

#Unicode type
proc PyUnicode_Check*(o: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_CheckExact*(o: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
#proc PyUnicode_READY*(o: PyObjectPtr): cint
#proc PyUnicode_GET_LENGTH*(o: PyObjectPtr): PySizeT
#proc PyUnicode_1BYTE_DATA*(o: PyObjectPtr): ptr Py_UCS1
#proc PyUnicode_2BYTE_DATA*(o: PyObjectPtr): ptr Py_UCS2
#proc PyUnicode_4BYTE_DATA*(o: PyObjectPtr): ptr Py_UCS4
#PyUnicode_WCHAR_KIND
#PyUnicode_1BYTE_KIND
#PyUnicode_2BYTE_KIND
#PyUnicode_4BYTE_KIND
#proc PyUnicode_KIND*(o: PyObjectPtr): cint
#proc PyUnicode_DATA*(o: PyObjectPtr): pointer
#proc PyUnicode_WRITE*(kind: cint; data: pointer; index: PySizeT; value: Py_UCS4)
#proc PyUnicode_READ*(kind: cint; data: pointer; index: PySizeT): Py_UCS4
#proc PyUnicode_READ_CHAR*(o: PyObjectPtr; index: PySizeT): Py_UCS4
#PyUnicode_MAX_CHAR_VALUE(PyObject * o)
proc PyUnicode_ClearFreeList*(): cint {.cdecl, importc, dynlib: libraryString.}
#Creating and accessing Unicode strings
proc PyUnicode_New*(size: PySizeT; maxchar: Py_UCS4): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_FromKindAndData*(kind: cint; buffer: pointer; size: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_FromStringAndSize*(u: cstring; size: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_FromString*(u: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_FromFormat*(format: cstring): PyObjectPtr {.varargs, cdecl, importc, dynlib: libraryString.}
proc PyUnicode_FromFormatV*(format: cstring; vargs: varargs): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_FromEncodedObject*(obj: PyObjectPtr; encoding: cstring; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_GetLength*(unicode: PyObjectPtr): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_CopyCharacters*(to: PyObjectPtr; to_start: PySizeT; `from`: PyObjectPtr; from_start: PySizeT; how_many: PySizeT): cint {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_Fill*(unicode: PyObjectPtr; start: PySizeT; length: PySizeT; fill_char: Py_UCS4): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_WriteChar*(unicode: PyObjectPtr; index: PySizeT; character: Py_UCS4): cint {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_ReadChar*(unicode: PyObjectPtr; index: PySizeT): Py_UCS4 {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_Substring*(str: PyObjectPtr; start: PySizeT; `end`: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_AsUCS4*(u: PyObjectPtr; buffer: ptr Py_UCS4; buflen: PySizeT; copy_null: cint): ptr Py_UCS4 {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_AsUCS4Copy*(u: PyObjectPtr): ptr Py_UCS4 {.cdecl, importc, dynlib: libraryString.}
#Locale Encoding
proc PyUnicode_DecodeLocaleAndSize*(str: cstring; len: PySizeT; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_DecodeLocale*(str: cstring; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_EncodeLocale*(unicode: PyObjectPtr; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
#File System Encoding
proc PyUnicode_FSConverter*(obj: PyObjectPtr; result: pointer): cint {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_FSDecoder*(obj: PyObjectPtr; result: pointer): cint {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_DecodeFSDefaultAndSize*(s: cstring; size: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_DecodeFSDefault*(s: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_EncodeFSDefault*(unicode: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
#wchar_t Support
proc PyUnicode_FromWideChar*(w: PyUnicode; size: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_AsWideChar*(unicode: ptr PyUnicodeObject; w: PyUnicode; size: PySizeT): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_AsWideCharString*(unicode: PyObjectPtr; size: PySizeTPtr): PyUnicode {.cdecl, importc, dynlib: libraryString.}
#UCS4 Support
proc Py_UCS4_strlen*(u: ptr Py_UCS4): csize {.cdecl, importc, dynlib: libraryString.}
proc Py_UCS4_strcpy*(s1: ptr Py_UCS4; s2: ptr Py_UCS4): ptr Py_UCS4 {.cdecl, importc, dynlib: libraryString.}
proc Py_UCS4_strncpy*(s1: ptr Py_UCS4; s2: ptr Py_UCS4; n: csize): ptr Py_UCS4 {.cdecl, importc, dynlib: libraryString.}
proc Py_UCS4_strcat*(s1: ptr Py_UCS4; s2: ptr Py_UCS4): ptr Py_UCS4 {.cdecl, importc, dynlib: libraryString.}
proc Py_UCS4_strcmp*(s1: ptr Py_UCS4; s2: ptr Py_UCS4): cint {.cdecl, importc, dynlib: libraryString.}
proc Py_UCS4_strncmp*(s1: ptr Py_UCS4; s2: ptr Py_UCS4; n: csize): cint {.cdecl, importc, dynlib: libraryString.}
proc Py_UCS4_strchr*(s: ptr Py_UCS4; c: Py_UCS4): ptr Py_UCS4 {.cdecl, importc, dynlib: libraryString.}
proc Py_UCS4_strrchr*(s: ptr Py_UCS4; c: Py_UCS4): ptr Py_UCS4 {.cdecl, importc, dynlib: libraryString.}
#Generic Codecs
proc PyUnicode_Decode*(s: cstring; size: PySizeT; encoding: cstring; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_AsEncodedString*(unicode: PyObjectPtr; encoding: cstring; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_Encode*(s: PyUnicodePtr; size: PySizeT; encoding: cstring; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
#UTF-8 Codecs
proc PyUnicode_DecodeUTF8*(s: cstring; size: PySizeT; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_DecodeUTF8Stateful*(s: cstring; size: PySizeT; errors: cstring; consumed: PySizeTPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_AsUTF8String*(unicode: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_AsUTF8AndSize*(unicode: PyObjectPtr; size: PySizeTPtr): cstring {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_AsUTF8*(unicode: PyObjectPtr): cstring {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_EncodeUTF8*(s: PyUnicodePtr; size: PySizeT; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
#UTF-32 Codecs
proc PyUnicode_DecodeUTF32*(s: cstring; size: PySizeT; errors: cstring; byteorder: ptr cint): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_DecodeUTF32Stateful*(s: cstring; size: PySizeT; errors: cstring; byteorder: ptr cint; consumed: PySizeTPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_AsUTF32String*(unicode: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_EncodeUTF32*(s: PyUnicodePtr; size: PySizeT; errors: cstring; byteorder: cint): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
#UTF-16 Codecs
proc PyUnicode_DecodeUTF16*(s: cstring; size: PySizeT; errors: cstring; byteorder: ptr cint): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_DecodeUTF16Stateful*(s: cstring; size: PySizeT; errors: cstring; byteorder: ptr cint; consumed: PySizeTPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_AsUTF16String*(unicode: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_EncodeUTF16*(s: PyUnicodePtr; size: PySizeT; errors: cstring; byteorder: cint): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
#UTF-7 Codecs
proc PyUnicode_DecodeUTF7*(s: cstring; size: PySizeT; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_DecodeUTF7Stateful*(s: cstring; size: PySizeT; errors: cstring; consumed: PySizeTPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_EncodeUTF7*(s: PyUnicodePtr; size: PySizeT; base64SetO: cint; base64WhiteSpace: cint; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
#Unicode-Escape Codecs
proc PyUnicode_DecodeUnicodeEscape*(s: cstring; size: PySizeT; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_AsUnicodeEscapeString*(unicode: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_EncodeUnicodeEscape*(s: PyUnicodePtr; size: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
#Raw-Unicode-Escape Codecs
proc PyUnicode_DecodeRawUnicodeEscape*(s: cstring; size: PySizeT; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_AsRawUnicodeEscapeString*(unicode: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_EncodeRawUnicodeEscape*(s: PyUnicodePtr; size: PySizeT; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
#Latin-1 Codecs
proc PyUnicode_DecodeLatin1*(s: cstring; size: PySizeT; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_AsLatin1String*(unicode: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_EncodeLatin1*(s: PyUnicodePtr; size: PySizeT; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
#ASCII Codecs
proc PyUnicode_DecodeASCII*(s: cstring; size: PySizeT; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_AsASCIIString*(unicode: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_EncodeASCII*(s: PyUnicodePtr; size: PySizeT; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
#Character Map Codecs
proc PyUnicode_DecodeCharmap*(s: cstring; size: PySizeT; mapping: PyObjectPtr; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_AsCharmapString*(unicode: PyObjectPtr; mapping: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_TranslateCharmap*(s: PyUnicodePtr; size: PySizeT; table: PyObjectPtr; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_EncodeCharmap*(s: PyUnicodePtr; size: PySizeT; mapping: PyObjectPtr; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
#MBCS codecs for Windows
proc PyUnicode_DecodeMBCS*(s: cstring; size: PySizeT; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_DecodeMBCSStateful*(s: cstring; size: cint; errors: cstring; consumed: ptr cint): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_AsMBCSString*(unicode: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_EncodeCodePage*(code_page: cint; unicode: PyObjectPtr; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_EncodeMBCS*(s: PyUnicodePtr; size: PySizeT; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}

#Methods & Slots
proc PyUnicode_Concat*(left: PyObjectPtr; right: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_Split*(s: PyObjectPtr; sep: PyObjectPtr; maxsplit: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_Splitlines*(s: PyObjectPtr; keepend: cint): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_Translate*(str: PyObjectPtr; table: PyObjectPtr; errors: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_Join*(separator: PyObjectPtr; seq: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_Tailmatch*(str: PyObjectPtr; substr: PyObjectPtr; start: PySizeT; `end`: PySizeT; direction: cint): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_Find*(str: PyObjectPtr; substr: PyObjectPtr; start: PySizeT; `end`: PySizeT; direction: cint): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_FindChar*(str: PyObjectPtr; ch: Py_UCS4; start: PySizeT; `end`: PySizeT; direction: cint): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_Count*(str: PyObjectPtr; substr: PyObjectPtr; start: PySizeT; `end`: PySizeT): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_Replace*(str: PyObjectPtr; substr: PyObjectPtr; replstr: PyObjectPtr; maxcount: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_Compare*(left: PyObjectPtr; right: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_CompareWithASCIIString*(uni: PyObjectPtr; string: cstring): cint {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_RichCompare*(left: PyObjectPtr; right: PyObjectPtr; op: cint): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_Format*(format: PyObjectPtr; args: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_Contains*(container: PyObjectPtr; element: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_InternInPlace*(string: ptr PyObjectPtr) {.cdecl, importc, dynlib: libraryString.}
proc PyUnicode_InternFromString*(v: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}

#Tuple Objects
type
  PyStructSequenceFieldPtr = ptr PyStructSequenceField
  PyStructSequenceField* = object
    name*: cstring
    doc*: cstring

  PyStructSequenceDescPtr = ptr PyStructSequenceDesc
  PyStructSequenceDesc* = object 
    name*: cstring
    doc*: cstring
    fields*: PyStructSequenceFieldPtr
    n_in_sequence*: cint

var
  PyTuple_Type*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "PyTuple_Type"))
  PyStructSequence_UnnamedField*: cstring = cast[cstring](dynlib.symAddr(libraryHandle, "PyStructSequence_UnnamedField"))

proc PyTuple_Check*(p: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyTuple_CheckExact*(p: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyTuple_New*(len: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyTuple_Pack*(n: PySizeT): PyObjectPtr {.varargs, cdecl, importc, dynlib: libraryString.}
proc PyTuple_Size*(p: PyObjectPtr): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PyTuple_GET_SIZE*(p: PyObjectPtr): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PyTuple_GetItem*(p: PyObjectPtr; pos: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
#proc PyTuple_GET_ITEM*(p: PyObjectPtr; pos: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyTuple_GetSlice*(p: PyObjectPtr; low: PySizeT; high: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyTuple_SetItem*(p: PyObjectPtr; pos: PySizeT; o: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
#proc PyTuple_SET_ITEM*(p: PyObjectPtr; pos: PySizeT; o: PyObjectPtr) {.cdecl, importc, dynlib: libraryString.}
proc PyTuple_Resize*(p: ptr PyObjectPtr; newsize: PySizeT): cint {.cdecl, importc: "_PyTuple_Resize", dynlib: libraryString.}
proc PyTuple_ClearFreeList*(): cint {.cdecl, importc, dynlib: libraryString.}
proc PyStructSequence_NewType*(desc: PyStructSequenceDescPtr): PyTypeObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyStructSequence_InitType*(typ: PyTypeObjectPtr; desc: PyStructSequenceDescPtr) {.cdecl, importc, dynlib: libraryString.}
proc PyStructSequence_InitType2*(typ: PyTypeObjectPtr; desc: PyStructSequenceDescPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyStructSequence_New*(typ: PyTypeObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyStructSequence_GetItem*(p: PyObjectPtr; pos: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyStructSequence_SetItem*(p: PyObjectPtr; pos: PySizeT; o: PyObjectPtr) {.cdecl, importc, dynlib: libraryString.}

#List Objects
var PyList_Type*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "PyList_Type"))

proc PyList_Check*(p: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyList_CheckExact*(p: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyList_New*(len: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyList_Size*(list: PyObjectPtr): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PyList_GET_SIZE*(list: PyObjectPtr): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PyList_GetItem*(list: PyObjectPtr; index: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyList_GET_ITEM*(list: PyObjectPtr; i: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyList_SetItem*(list: PyObjectPtr; index: PySizeT; item: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyList_SET_ITEM*(list: PyObjectPtr; i: PySizeT; o: PyObjectPtr) {.cdecl, importc, dynlib: libraryString.}
proc PyList_Insert*(list: PyObjectPtr; index: PySizeT; item: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyList_Append*(list: PyObjectPtr; item: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyList_GetSlice*(list: PyObjectPtr; low: PySizeT; high: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyList_SetSlice*(list: PyObjectPtr; low: PySizeT; high: PySizeT; itemlist: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyList_Sort*(list: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyList_Reverse*(list: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyList_AsTuple*(list: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyList_ClearFreeList*(): cint {.cdecl, importc, dynlib: libraryString.}

#Dictionary Objects
var PyDict_Type*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "PyDict_Type"))

proc PyDict_Check*(p: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDict_CheckExact*(p: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDict_New*(): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyDictProxy_New*(mapping: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyDict_Clear*(p: PyObjectPtr) {.cdecl, importc, dynlib: libraryString.}
proc PyDict_Contains*(p: PyObjectPtr; key: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDict_Copy*(p: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyDict_SetItem*(p: PyObjectPtr; key: PyObjectPtr; val: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDict_SetItemString*(p: PyObjectPtr; key: cstring; val: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDict_DelItem*(p: PyObjectPtr; key: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDict_DelItemString*(p: PyObjectPtr; key: cstring): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDict_GetItem*(p: PyObjectPtr; key: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyDict_GetItemWithError*(p: PyObjectPtr; key: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyDict_GetItemString*(p: PyObjectPtr; key: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyDict_SetDefault*(p: PyObjectPtr; key: PyObjectPtr; default: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyDict_Items*(p: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyDict_Keys*(p: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyDict_Values*(p: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyDict_Size*(p: PyObjectPtr): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PyDict_Next*(p: PyObjectPtr; ppos: PySizeTPtr; pkey: ptr PyObjectPtr; pvalue: ptr PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDict_Merge*(a: PyObjectPtr; b: PyObjectPtr; override: cint): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDict_Update*(a: PyObjectPtr; b: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDict_MergeFromSeq2*(a: PyObjectPtr; seq2: PyObjectPtr; override: cint): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDict_ClearFreeList*(): cint {.cdecl, importc, dynlib: libraryString.}

#Set Objects
var PySet_Type*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "PySet_Type"))

proc PySet_Check*(p: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyFrozenSet_Check*(p: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyAnySet_Check*(p: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyAnySet_CheckExact*(p: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyFrozenSet_CheckExact*(p: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PySet_New*(iterable: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyFrozenSet_New*(iterable: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PySet_Size*(anyset: PyObjectPtr): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PySet_GET_SIZE*(anyset: PyObjectPtr): PySizeT {.cdecl, importc, dynlib: libraryString.}
proc PySet_Contains*(anyset: PyObjectPtr; key: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PySet_Add*(set: PyObjectPtr; key: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PySet_Discard*(set: PyObjectPtr; key: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PySet_Pop*(set: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PySet_Clear*(set: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PySet_ClearFreeList*(): cint {.cdecl, importc, dynlib: libraryString.}

#Function Objects
var PyFunction_Type*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "PyFunction_Type"))

proc PyFunction_Check*(o: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyFunction_New*(code: PyObjectPtr; globals: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyFunction_NewWithQualName*(code: PyObjectPtr; globals: PyObjectPtr; qualname: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyFunction_GetCode*(op: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyFunction_GetGlobals*(op: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyFunction_GetModule*(op: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyFunction_GetDefaults*(op: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyFunction_SetDefaults*(op: PyObjectPtr; defaults: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyFunction_GetClosure*(op: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyFunction_SetClosure*(op: PyObjectPtr; closure: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyFunction_GetAnnotations*(op: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyFunction_SetAnnotations*(op: PyObjectPtr; annotations: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}

#Instance Method Objects
var PyInstanceMethod_Type*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "PyInstanceMethod_Type"))

proc PyInstanceMethod_Check*(o: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyInstanceMethod_New*(fun: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyInstanceMethod_Function*(im: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyInstanceMethod_GET_FUNCTION*(im: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}

#Method Objects
var PyMethod_Type*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "PyMethod_Type"))

proc PyMethod_Check*(o: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyMethod_New*(fun: PyObjectPtr; self: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyMethod_Function*(meth: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyMethod_GET_FUNCTION*(meth: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyMethod_Self*(meth: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyMethod_GET_SELF*(meth: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyMethod_ClearFreeList*(): cint {.cdecl, importc, dynlib: libraryString.}

#Cell Objects
var PyCell_Type*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "PyCell_Type"))

proc PyCell_Check*(ob: pointer): cint {.cdecl, importc, dynlib: libraryString.}
proc PyCell_New*(ob: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyCell_Get*(cell: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
#proc PyCell_GET*(cell: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyCell_Set*(cell: PyObjectPtr; value: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
#proc PyCell_SET*(cell: PyObjectPtr; value: PyObjectPtr) {.cdecl, importc, dynlib: libraryString.}

#Code Objects
var PyCode_Type*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "PyCode_Type"))

proc PyCode_Check*(co: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyCode_GetNumFree*(co: ptr PyCodeObject): cint {.cdecl, importc, dynlib: libraryString.}
proc PyCode_New*(argcount: cint; kwonlyargcount: cint; nlocals: cint; stacksize: cint; flags: cint; code: PyObjectPtr; consts: PyObjectPtr; names: PyObjectPtr; varnames: PyObjectPtr; freevars: PyObjectPtr; cellvars: PyObjectPtr; filename: PyObjectPtr; name: PyObjectPtr; firstlineno: cint; lnotab: PyObjectPtr): ptr PyCodeObject {.cdecl, importc, dynlib: libraryString.}
proc PyCode_NewEmpty*(filename: cstring; funcname: cstring; firstlineno: cint): ptr PyCodeObject {.cdecl, importc, dynlib: libraryString.}

#File Objects
proc PyObject_AsFileDescriptor*(p: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyFile_GetLine*(p: PyObjectPtr; n: cint): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyFile_WriteObject*(obj: PyObjectPtr; p: PyObjectPtr; flags: cint): cint {.cdecl, importc, dynlib: libraryString.}
proc PyFile_WriteString*(s: cstring; p: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}

#Module Objects
type
  PyModuleDefBasePtr* = ptr PyModuleDefBase
  PyModuleDefBase* = object 
    ob_base*: PyObject
    m_init*: proc (): PyObjectPtr {.cdecl.}
    m_index*: PySizeT
    m_copy*: PyObjectPtr

  PyModuleDefPtr* = ptr PyModuleDef
  PyModuleDef* = object 
    m_base*: PyModuleDefBase
    m_name*: cstring
    m_doc*: cstring
    m_size*: PySizeT
    m_methods*: PyMethodDefPtr
    m_reload*: Inquiry
    m_traverse*: TraverseProc
    m_clear*: Inquiry
    m_free*: FreeFunc
    
var PyModule_Type*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "PyModule_Type"))

proc PyModule_Check*(p: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyModule_CheckExact*(p: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyModule_NewObject*(name: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyModule_New*(name: cstring): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyModule_GetDict*(module: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyModule_GetNameObject*(module: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyModule_GetName*(module: PyObjectPtr): cstring {.cdecl, importc, dynlib: libraryString.}
proc PyModule_GetFilenameObject*(module: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyModule_GetFilename*(module: PyObjectPtr): cstring {.cdecl, importc, dynlib: libraryString.}
proc PyModule_GetState*(module: PyObjectPtr): pointer {.cdecl, importc, dynlib: libraryString.}
proc PyModule_GetDef*(module: PyObjectPtr): PyModuleDefPtr {.cdecl, importc, dynlib: libraryString.}
proc PyState_FindModule*(def: PyModuleDefPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyState_AddModule*(module: PyObjectPtr; def: PyModuleDefPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyState_RemoveModule*(def: PyModuleDefPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyModule_Create2*(module: PyModuleDefPtr; module_api_version: cint): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyModule_Create*(module: PyModuleDefPtr): PyObjectPtr =
  result = PyModule_Create2(module, PYTHON_API_VERSION)
proc PyModule_AddObject*(module: PyObjectPtr; name: cstring; value: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyModule_AddIntConstant*(module: PyObjectPtr; name: cstring; value: clong): cint {.cdecl, importc, dynlib: libraryString.}
proc PyModule_AddStringConstant*(module: PyObjectPtr; name: cstring; value: cstring): cint {.cdecl, importc, dynlib: libraryString.}
#proc PyModule_AddIntMacro*(module: PyObjectPtr; a3: `macro`): cint {.cdecl, importc, dynlib: libraryString.}
#proc PyModule_AddStringMacro*(module: PyObjectPtr; a3: `macro`): cint {.cdecl, importc, dynlib: libraryString.}

#Iterator Objects
var
  PySeqIter_Type*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "PySeqIter_Type"))
  PyCallIter_Type*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "PyCallIter_Type"))

template Py_REFCNT*(ob): expr = cast[PyObjectPtr](ob).ob_refcnt
template Py_TYPE*(ob): expr = cast[PyObjectPtr](ob).ob_type
template Py_SIZE*(ob): expr = cast[PyObjectPtr](ob).ob_size
# #define PyCallIter_Check(op) (Py_TYPE(op) == &PyCallIter_Type)
template PyCallIter_Check*(op): expr = Py_TYPE(op) == addr(PyCallIter_Type)
# #define PySeqIter_Check(op) (Py_TYPE(op) == &PySeqIter_Type)
template PySeqIter_Check*(op): expr = Py_TYPE(op) == addr(PySeqIter_Type)
proc PySeqIter_New*(seq: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyCallIter_New*(callable: PyObjectPtr; sentinel: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}

#Descriptor Objects
type 
  WrapperFunc* = proc (self: PyObjectPtr; args: PyObjectPtr; wrapped: pointer): PyObjectPtr {.cdecl.}
  WrapperBasePtr* = ptr WrapperBase
  WrapperBase* = object
    name*: cstring
    offset*: cint
    function*: pointer
    wrapper*: WrapperFunc
    doc*: cstring
    flags*: cint
    name_strobj*: PyObjectPtr

var PyProperty_Type*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "PyProperty_Type"))

proc PyDescr_NewGetSet*(typ: PyTypeObjectPtr; getset: PyGetSetDefPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyDescr_NewMember*(typ: PyTypeObjectPtr; meth: PyMemberDefPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyDescr_NewMethod*(typ: PyTypeObjectPtr; meth: PyMethodDefPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyDescr_NewWrapper*(typ: PyTypeObjectPtr; wrapper: WrapperBasePtr; wrapped: pointer): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyDescr_NewClassMethod*(typ: PyTypeObjectPtr; meth: PyMethodDefPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyDescr_IsData*(descr: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyWrapper_New*(arg0: PyObjectPtr; arg1: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}

#Slice Objects
var PySlice_Type*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "PySlice_Type"))

proc PySlice_Check*(ob: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PySlice_New*(start: PyObjectPtr; stop: PyObjectPtr; step: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PySlice_GetIndices*(slice: PyObjectPtr; length: PySizeT; start: PySizeTPtr; stop: PySizeTPtr; step: PySizeTPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PySlice_GetIndicesEx*(slice: PyObjectPtr; length: PySizeT; start: PySizeTPtr; stop: PySizeTPtr; step: PySizeTPtr; slicelength: PySizeTPtr): cint {.cdecl, importc, dynlib: libraryString.}

#MemoryView objects
proc PyMemoryView_FromObject*(obj: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyMemoryView_FromMemory*(mem: cstring; size: PySizeT; flags: cint): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyMemoryView_FromBuffer*(view: PyBufferPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyMemoryView_GetContiguous*(obj: PyObjectPtr; buffertype: cint; order: char): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyMemoryView_Check*(obj: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
#proc PyMemoryView_GET_BUFFER*(mview: PyObjectPtr): PyBufferPtr {.cdecl, importc, dynlib: libraryString.}
#proc PyMemoryView_GET_BASE*(mview: PyObjectPtr): PyBufferPtr {.cdecl, importc, dynlib: libraryString.}

#Weak Reference Objects
var
  PyWeakref_RefType*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "_PyWeakref_RefType"))
  PyWeakref_ProxyType*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "_PyWeakref_ProxyType"))
  PyWeakref_CallableProxyType*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "_PyWeakref_CallableProxyType"))

# #define PyWeakref_CheckRef(op) PyObject_TypeCheck(op, &_PyWeakref_RefType)
template PyWeakref_CheckRef*(op): cint = PyObject_TypeCheck(op, addr(PyWeakref_RefType))
# #define PyWeakref_CheckProxy(op) ((Py_TYPE(op) == &_PyWeakref_ProxyType) || (Py_TYPE(op) == &_PyWeakref_CallableProxyType))
template PyWeakref_CheckProxy*(op): cint = (Py_TYPE(op) == addr(PyWeakref_ProxyType)) or (Py_TYPE(op) == addr(PyWeakref_CallableProxyType))
# #define PyWeakref_Check(op) (PyWeakref_CheckRef(op) || PyWeakref_CheckProxy(op))
template PyWeakref_Check*(ob): expr = PyWeakref_CheckRef(op) or PyWeakref_CheckProxy(op)
proc PyWeakref_NewRef*(ob: PyObjectPtr; callback: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyWeakref_NewProxy*(ob: PyObjectPtr; callback: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyWeakref_GetObject*(rf: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
#proc PyWeakref_GET_OBJECT*(rf: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}

#Capsules
var PyCapsule_Type*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "PyCapsule_Type"))

type 
  PyCapsuleDestructor* = proc (arg: PyObjectPtr) {.cdecl.}

proc PyCapsule_CheckExact*(p: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyCapsule_New*(pointer: pointer; name: cstring; destructor: PyCapsuleDestructor): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyCapsule_GetPointer*(capsule: PyObjectPtr; name: cstring): pointer {.cdecl, importc, dynlib: libraryString.}
proc PyCapsule_GetDestructor*(capsule: PyObjectPtr): PyCapsuleDestructor {.cdecl, importc, dynlib: libraryString.}
proc PyCapsule_GetContext*(capsule: PyObjectPtr): pointer {.cdecl, importc, dynlib: libraryString.}
proc PyCapsule_GetName*(capsule: PyObjectPtr): cstring {.cdecl, importc, dynlib: libraryString.}
proc PyCapsule_Import*(name: cstring; no_block: cint): pointer {.cdecl, importc, dynlib: libraryString.}
proc PyCapsule_IsValid*(capsule: PyObjectPtr; name: cstring): cint {.cdecl, importc, dynlib: libraryString.}
proc PyCapsule_SetContext*(capsule: PyObjectPtr; context: pointer): cint {.cdecl, importc, dynlib: libraryString.}
proc PyCapsule_SetDestructor*(capsule: PyObjectPtr; destructor: PyCapsuleDestructor): cint {.cdecl, importc, dynlib: libraryString.}
proc PyCapsule_SetName*(capsule: PyObjectPtr; name: cstring): cint {.cdecl, importc, dynlib: libraryString.}
proc PyCapsule_SetPointer*(capsule: PyObjectPtr; pointer: pointer): cint {.cdecl, importc, dynlib: libraryString.}

#Generator Objects
type 
  Frame* = object 
  PyGenObject* = object 
    ob_base*: PyVarObject
    gi_frame*: ptr Frame
    gi_running*: char
    gi_code*: PyObjectPtr
    gi_weakreflist*: PyObjectPtr

var PyGen_Type*: PyTypeObject = cast[PyTypeObject](dynlib.symAddr(libraryHandle, "PyGen_Type"))

# #define PyGen_Check(op) PyObject_TypeCheck(op, &PyGen_Type)
template PyGen_Check*(op): cint = PyObject_TypeCheck(op, addr(PyGen_Type))
# #define PyGen_CheckExact(op) (Py_TYPE(op) == &PyGen_Type)
template PyGen_CheckExact*(op): cint = Py_TYPE(op) == addr(PyGen_Type)
proc PyGen_New*(frame: PyFrameObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}

#DateTime Objects
const 
  PyDateTime_DATE_DATASIZE* = 4 # number of bytes for year, month, and day. 
  PyDateTime_TIME_DATASIZE* = 6 # number of bytes for hour, minute, second, and usecond.
  PyDateTime_DATETIME_DATASIZE* = 10 # number of bytes for year, month, day, hour, minute, second, and usecond. 

type 
  PyDateTime_TimePtr* = ptr PyDateTime_Time
  PyDateTime_Time* = object
    # _PyDateTime_TIMEHEAD
    # _PyTZINFO_HEAD
    ob_base*: PyObject
    hashcode*: PyHashT
    hastzinfo*: int8
    # _PyTZINFO_HEAD
    data*: array[PyDateTime_TIME_DATASIZE, cuchar]
    # _PyDateTime_TIMEHEAD
    tzinfo*: PyObjectPtr
    
  PyDateTime_DatePtr* = ptr PyDateTime_Date
  PyDateTime_Date* = object
    # _PyTZINFO_HEAD
    ob_base*: PyObject
    hashcode*: PyHashT
    hastzinfo*: int8
    # _PyTZINFO_HEAD
    data*: array[PyDateTime_DATE_DATASIZE, cuchar]
    
  PyDateTime_DateTimePtr* = ptr PyDateTime_DateTime
  PyDateTime_DateTime* = object
    # _PyDateTime_DATETIMEHEAD  
    # _PyTZINFO_HEAD
    ob_base*: PyObject
    hashcode*: PyHashT
    hastzinfo*: int8
    # _PyTZINFO_HEAD
    data*: array[PyDateTime_DATETIME_DATASIZE, cuchar]
    # _PyDateTime_DATETIMEHEAD  
    tzinfo*: PyObjectPtr

  PyDateTimeDeltaPtr* = ptr PyDateTimeDelta
  PyDateTimeDelta* = object 
    # _PyTZINFO_HEAD
    ob_base*: PyObject
    hashcode*: PyHashT
    hastzinfo*: int8
    # _PyTZINFO_HEAD
    days*: int                # -MAX_DELTA_DAYS <= days <= MAX_DELTA_DAYS 
    seconds*: int             # 0 <= seconds < 24*3600 is invariant 
    microseconds*: int        # 0 <= microseconds < 1000000 is invariant 
  

proc PyDate_Check*(ob: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDate_CheckExact*(ob: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDateTime_Check*(ob: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDateTime_CheckExact*(ob: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyTime_Check*(ob: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyTime_CheckExact*(ob: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDelta_Check*(ob: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDelta_CheckExact*(ob: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyTZInfo_Check*(ob: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyTZInfo_CheckExact*(ob: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDate_FromDate*(year: cint; month: cint; day: cint): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyDateTime_FromDateAndTime*(year: cint; month: cint; day: cint; hour: cint; minute: cint; second: cint; usecond: cint): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyTime_FromTime*(hour: cint; minute: cint; second: cint; usecond: cint): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyDelta_FromDSU*(days: cint; seconds: cint; useconds: cint): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyDateTime_GET_YEAR*(o: PyDateTime_DatePtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDateTime_GET_MONTH*(o: PyDateTime_DatePtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDateTime_GET_DAY*(o: PyDateTime_DatePtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDateTime_DATE_GET_HOUR*(o: PyDateTime_DateTimePtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDateTime_DATE_GET_MINUTE*(o: PyDateTime_DateTimePtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDateTime_DATE_GET_SECOND*(o: PyDateTime_DateTimePtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDateTime_DATE_GET_MICROSECOND*(o: PyDateTime_DateTimePtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDateTime_TIME_GET_HOUR*(o: PyDateTime_TimePtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDateTime_TIME_GET_MINUTE*(o: PyDateTime_TimePtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDateTime_TIME_GET_SECOND*(o: PyDateTime_TimePtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDateTime_TIME_GET_MICROSECOND*(o: PyDateTime_TimePtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDateTimeDelta_GET_DAYS*(o: PyDateTimeDeltaPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDateTimeDelta_GET_SECONDS*(o: PyDateTimeDeltaPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDateTimeDelta_GET_MICROSECOND*(o: PyDateTimeDeltaPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyDateTime_FromTimestamp*(args: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyDate_FromTimestamp*(args: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}

#Initialization, Finalization, and Threads
type 
  CallStats* = enum 
    PCALL_ALL = 0, PCALL_FUNCTION = 1, PCALL_FAST_FUNCTION = 2, 
    PCALL_FASTER_FUNCTION = 3, PCALL_METHOD = 4, PCALL_BOUND_METHOD = 5, 
    PCALL_CFUNCTION = 6, PCALL_TYPE = 7, PCALL_GENERATOR = 8, PCALL_OTHER = 9, 
    PCALL_POP = 10


type 
  PyInterpreterStatePtr* = ptr PyInterpreterState
  PyInterpreterState* {.final.} = object
  
  PyThreadStatePtr* = ptr PyThreadState
  PyThreadState* {.final.} = object 
    prev*: PyThreadStatePtr
    next*: PyThreadStatePtr
    interp*: PyInterpreterStatePtr
    frame*: ptr Frame
    recursion_depth*: cint
    overflowed*: char
    recursion_critical*: char
    tracing*: cint
    use_tracing*: cint
    c_profilefunc*: PyTraceFunc
    c_tracefunc*: PyTraceFunc
    c_profileobj*: PyObjectPtr
    c_traceobj*: PyObjectPtr
    curexc_type*: PyObjectPtr
    curexc_value*: PyObjectPtr
    curexc_traceback*: PyObjectPtr
    exc_type*: PyObjectPtr
    exc_value*: PyObjectPtr
    exc_traceback*: PyObjectPtr
    dict*: PyObjectPtr
    gilstate_counter*: cint
    async_exc*: PyObjectPtr
    thread_id*: clong
    trash_delete_nesting*: cint
    trash_delete_later*: PyObjectPtr
    on_delete*: proc (arg: pointer) {.cdecl.}
    on_delete_data*: pointer
    
  PyGILState_STATE* {.size: sizeof(cint).} = enum 
    PyGILState_LOCKED
    PyGILState_UNLOCKED


#Py_BEGIN_ALLOW_THREADS
#Py_END_ALLOW_THREADS
#Py_BLOCK_THREADS
#Py_UNBLOCK_THREADS

var
  PyTrace_CALL*: cint = cast[cint](dynlib.symAddr(libraryHandle, "PyTrace_CALL"))
  PyTrace_EXCEPTION*: cint = cast[cint](dynlib.symAddr(libraryHandle, "PyTrace_EXCEPTION"))
  PyTrace_LINE*: cint = cast[cint](dynlib.symAddr(libraryHandle, "PyTrace_LINE"))
  PyTrace_RETURN*: cint = cast[cint](dynlib.symAddr(libraryHandle, "PyTrace_RETURN"))
  PyTrace_C_CALL*: cint = cast[cint](dynlib.symAddr(libraryHandle, "PyTrace_C_CALL"))
  PyTrace_C_EXCEPTION*: cint = cast[cint](dynlib.symAddr(libraryHandle, "PyTrace_C_EXCEPTION"))
  PyTrace_C_RETURN*: cint = cast[cint](dynlib.symAddr(libraryHandle, "PyTrace_C_RETURN"))

#proc Py_Initialize*() {.cdecl, importc, dynlib: libraryString.}
proc Py_InitializeEx*(initsigs: cint) {.cdecl, importc, dynlib: libraryString.}
proc Py_IsInitialized*(): cint {.cdecl, importc, dynlib: libraryString.}
#proc Py_Finalize*() {.cdecl, importc, dynlib: libraryString.}
proc Py_SetStandardStreamEncoding*(encoding: cstring; errors: cstring): cint {.cdecl, importc, dynlib: libraryString.}
proc Py_SetProgramName*(name: PyUnicode) {.cdecl, importc, dynlib: libraryString.}
proc Py_GetProgramName*(): PyUnicode {.cdecl, importc, dynlib: libraryString.}
proc Py_GetPrefix*(): PyUnicode {.cdecl, importc, dynlib: libraryString.}
proc Py_GetExecPrefix*(): PyUnicode {.cdecl, importc, dynlib: libraryString.}
proc Py_GetProgramFullPath*(): PyUnicode {.cdecl, importc, dynlib: libraryString.}
proc Py_GetPath*(): PyUnicode {.cdecl, importc, dynlib: libraryString.}
proc Py_SetPath*(arg: PyUnicode) {.cdecl, importc, dynlib: libraryString.}
proc Py_GetVersion*(): cstring {.cdecl, importc, dynlib: libraryString.}
proc Py_GetPlatform*(): cstring {.cdecl, importc, dynlib: libraryString.}
proc Py_GetCopyright*(): cstring {.cdecl, importc, dynlib: libraryString.}
proc Py_GetCompiler*(): cstring {.cdecl, importc, dynlib: libraryString.}
proc Py_GetBuildInfo*(): cstring {.cdecl, importc, dynlib: libraryString.}
proc PySys_SetArgvEx*(argc: cint; argv: PyUnicodePtr; updatepath: cint) {.cdecl, importc, dynlib: libraryString.}
proc PySys_SetArgv*(argc: cint; argv: PyUnicodePtr) {.cdecl, importc, dynlib: libraryString.}
proc Py_SetPythonHome*(home: PyUnicode) {.cdecl, importc, dynlib: libraryString.}
proc Py_GetPythonHome*(): PyUnicode {.cdecl, importc, dynlib: libraryString.}
proc PyEval_InitThreads*() {.cdecl, importc, dynlib: libraryString.}
proc PyEval_ThreadsInitialized*(): cint {.cdecl, importc, dynlib: libraryString.}
proc PyEval_SaveThread*(): PyThreadStatePtr {.cdecl, importc, dynlib: libraryString.}
proc PyEval_RestoreThread*(tstate: PyThreadStatePtr) {.cdecl, importc, dynlib: libraryString.}
proc PyThreadState_Get*(): PyThreadStatePtr {.cdecl, importc, dynlib: libraryString.}
proc PyThreadState_Swap*(tstate: PyThreadStatePtr): PyThreadStatePtr {.cdecl, importc, dynlib: libraryString.}
proc PyEval_ReInitThreads*() {.cdecl, importc, dynlib: libraryString.}
proc PyGILState_Ensure*(): PyGILState_STATE {.cdecl, importc, dynlib: libraryString.}
proc PyGILState_Release*(arg: PyGILState_STATE) {.cdecl, importc, dynlib: libraryString.}
proc PyGILState_GetThisThreadState*(): PyThreadStatePtr {.cdecl, importc, dynlib: libraryString.}
proc PyGILState_Check*(): cint {.cdecl, importc, dynlib: libraryString.}

#Low-level API
proc PyInterpreterState_New*(): PyInterpreterStatePtr {.cdecl, importc, dynlib: libraryString.}
proc PyInterpreterState_Clear*(interp: PyInterpreterStatePtr) {.cdecl, importc, dynlib: libraryString.}
proc PyInterpreterState_Delete*(interp: PyInterpreterStatePtr) {.cdecl, importc, dynlib: libraryString.}
proc PyThreadState_New*(interp: PyInterpreterStatePtr): PyThreadStatePtr {.cdecl, importc, dynlib: libraryString.}
proc PyThreadState_Clear*(tstate: PyThreadStatePtr) {.cdecl, importc, dynlib: libraryString.}
proc PyThreadState_Delete*(tstate: PyThreadStatePtr) {.cdecl, importc, dynlib: libraryString.}
proc PyThreadState_GetDict*(): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyThreadState_SetAsyncExc*(id: clong; exc: PyObjectPtr): cint {.cdecl, importc, dynlib: libraryString.}
proc PyEval_AcquireThread*(tstate: PyThreadStatePtr) {.cdecl, importc, dynlib: libraryString.}
proc PyEval_ReleaseThread*(tstate: PyThreadStatePtr) {.cdecl, importc, dynlib: libraryString.}
proc PyEval_AcquireLock*() {.cdecl, importc, dynlib: libraryString.}
proc PyEval_ReleaseLock*() {.cdecl, importc, dynlib: libraryString.}

#Sub-interpreter support
proc Py_NewInterpreter*(): PyThreadStatePtr {.cdecl, importc, dynlib: libraryString.}
proc Py_EndInterpreter*(tstate: PyThreadStatePtr) {.cdecl, importc, dynlib: libraryString.}
proc Py_AddPendingCall*(fun: proc (arg: pointer): cint {.cdecl.}; arg: pointer): cint {.cdecl, importc, dynlib: libraryString.}

#Profiling and Tracing
proc PyEval_SetProfile*(fun: PyTraceFunc; obj: PyObjectPtr) {.cdecl, importc, dynlib: libraryString.}
proc PyEval_SetTrace*(fun: PyTraceFunc; obj: PyObjectPtr) {.cdecl, importc, dynlib: libraryString.}
proc PyEval_GetCallStats*(self: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}

#Advanced Debugger Support
proc PyInterpreterState_Head*(): PyInterpreterStatePtr {.cdecl, importc, dynlib: libraryString.}
proc PyInterpreterState_Next*(interp: PyInterpreterStatePtr): PyInterpreterStatePtr {.cdecl, importc, dynlib: libraryString.}
proc PyInterpreterState_ThreadHead*(interp: PyInterpreterStatePtr): PyThreadStatePtr {.cdecl, importc, dynlib: libraryString.}
proc PyThreadState_Next*(tstate: PyThreadStatePtr): PyThreadStatePtr {.cdecl, importc, dynlib: libraryString.}

#Memory Management
#Raw Memory Interface
proc PyMem_RawMalloc*(n: csize): pointer {.cdecl, importc, dynlib: libraryString.}
proc PyMem_RawRealloc*(p: pointer; n: csize): pointer {.cdecl, importc, dynlib: libraryString.}
proc PyMem_RawFree*(p: pointer) {.cdecl, importc, dynlib: libraryString.}

#Memory Interface
proc PyMem_Malloc*(n: csize): pointer {.cdecl, importc, dynlib: libraryString.}
proc PyMem_Realloc*(p: pointer; n: csize): pointer {.cdecl, importc, dynlib: libraryString.}
proc PyMem_Free*(p: pointer) {.cdecl, importc, dynlib: libraryString.}
#TYPE* PyMem_New(TYPE, size_t n);
#TYPE* PyMem_Resize(void *p, TYPE, size_t n);

proc PyMem_Del*(p: pointer) {.cdecl, importc, dynlib: libraryString.}

#Customize Memory Allocators
type
  PyMemAllocatorPtr = ptr PyMemAllocator
  PyMemAllocator* {.final.} = object 
    ctx*: pointer
    malloc*: proc (ctx: pointer; size: csize): pointer {.cdecl.}
    realloc*: proc (ctx: pointer; pt: pointer; new_size: csize): pointer {.cdecl.}
    free*: proc (ctx: pointer; pt: pointer) {.cdecl.}

  PyMemAllocatorDomain* {.size: sizeof(cint).} = enum
    PYMEM_DOMAIN_RAW,   # PyMem_RawMalloc(), PyMem_RawRealloc() and PyMem_RawFree()      
    PYMEM_DOMAIN_MEM,   # PyMem_Malloc(), PyMem_Realloc() and PyMem_Free()       
    PYMEM_DOMAIN_OBJ    # PyObject_Malloc(), PyObject_Realloc() and PyObject_Free() 


proc PyMem_GetAllocator*(domain: PyMemAllocatorDomain; allocator: PyMemAllocatorPtr) {.cdecl, importc, dynlib: libraryString.}
proc PyMem_SetAllocator*(domain: PyMemAllocatorDomain; allocator: PyMemAllocatorPtr) {.cdecl, importc, dynlib: libraryString.}
proc PyMem_SetupDebugHooks*() {.cdecl, importc, dynlib: libraryString.}

#Allocating Objects on the Heap
proc PyObject_New*(typ: PyTypeObjectPtr): PyObjectPtr {.cdecl, importc: "_PyObject_New", dynlib: libraryString.}
proc PyObject_NewVar*(typ: PyTypeObjectPtr; size: PySizeT): PyVarObjectPtr {.cdecl, importc: "_PyObject_NewVar", dynlib: libraryString.}
proc PyObject_Init*(op: PyObjectPtr; typ: PyTypeObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc PyObject_InitVar*(op: PyVarObjectPtr; typ: PyTypeObjectPtr; size: PySizeT): PyVarObjectPtr {.cdecl, importc, dynlib: libraryString.}
#TYPE* PyObject_New(TYPE, PyTypeObject *type);
#TYPE* PyObject_NewVar(TYPE, PyTypeObject *type, PySizeT size);
proc PyObject_Del*(op: PyObjectPtr) {.cdecl, importc, dynlib: libraryString.}


## Helper procedures
proc libCandidates*(s: string, dest: var seq[string]) =
  ## Procedure for simple parsing of library names, 
  ## taken from the 'compiler/options' module
  var
    le = strutils.find(s, '(')
    ri = strutils.find(s, ')', le+1)
  if le >= 0 and ri > le:
    var
      prefix = substr(s, 0, le - 1)
      suffix = substr(s, ri + 1)
    for middle in split(substr(s, le + 1, ri - 1), '|'):
      libCandidates(prefix & middle & suffix, dest)
  else:
    add(dest, s)

proc loadDllLib*(libNames: string): LibHandle =
  ## Procedure for loading a dynamic library from a special string,
  ## the same way as the importc pragma
  var
    lib_list: seq[string] = newSeq[string]()
  # Parse the library name string into a list
  libCandidates(libNames, lib_list)
  # Load the library
  result = nil
  for libName in lib_list:
    result = loadLib(libName, global_symbols=true)
    if result != nil:
      echo "Loaded dynamic library: '$1'" % libName
      break
  # Check for a successfully loaded library
  if result == nil:
    quit("Could not load python library!")
