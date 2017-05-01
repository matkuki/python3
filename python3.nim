
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

# Python 3.5 introduced a few changes to some structs, so there has
# to be a way to determine which Python 3 version the user will be using!
const
  PYTHON_VERSION = 3.0

# Display the used Python 3 version
static:
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "!! Compiling for Python ", PYTHON_VERSION, " !!"
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

# Define the library filename
when defined(windows): 
  const libraryString = "python(36|35|34|33|32|31|3).dll"
elif defined(macosx):
  const libraryString = "libpython(3.6|3.5|3.4|3.3|3.2|3.1|3).dylib"
else: 
  const versionString = ".1.0"
  const libraryString = "libpython(3.6m|3.6|3.5m|3.5|3.4m|3.4|3.3m|3.3|3.2m|3.2|3.1|3).so" & versionString

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
  # Method object constants
  methOldargs* = 0x0000
  methVarargs* = 0x0001
  methKeywords* = 0x0002
  methNoargs* = 0x0004
  methO* = 0x0008
  methClass* = 0x0010
  methStatic* = 0x0020
  methCoexist* = 0x0040
  # Masks for the co_flags field of PyCodeObject
  coOptimized* = 0x0001
  coNewlocals* = 0x0002
  coVarargs* = 0x0004
  coVarkeywords* = 0x0008
  coNested* = 0x0010
  coMaxBlocks* = 0x0014
  coGenerator* = 0x0020
  coFutureDivision* = 0x2000
  coFutureAbsoluteImport* = 0x4000
  coFutureWithStatement* = 0x8000
  coFuturePrintFunction* = 0x10000


type
  UncheckedArray*{.unchecked.}[T] = array[1,T]
  PySizeTPtr = ptr PySizeT
  PySizeT* = int # C definition: 'typedef long PySizeT'
  PyHashT* = PySizeT # C definition: 'typedef PySizeT Py_hash_t;'
  WideCStringPtr* = ptr WideCString
  PyUnicodePtr* = ptr PyUnicode
  PyUnicode* = string # C definition: 'typedef wchar_t Py_UNICODE;'
  PyosSighandler* = proc (parameter: cint) {.cdecl.}
  
  # Function pointers used for various Python methods
  FreeFunc* = proc (p: pointer){.cdecl.}
  Destructor* = proc (ob: PyObjectPtr){.cdecl.}
  PrintFunc* = proc (ob: PyObjectPtr, f: File, i: int): int{.cdecl.}
  GetAttrFunc* = proc (ob1: PyObjectPtr, name: cstring): PyObjectPtr{.cdecl.}
  GetAttrOFunc* = proc (ob1, ob2: PyObjectPtr): PyObjectPtr{.cdecl.}
  SetAttrFunc* = proc (ob1: PyObjectPtr, name: cstring, 
                       ob2: PyObjectPtr): int{.cdecl.}
  SetAttrOFunc* = proc (ob1, ob2, ob3: PyObjectPtr): int{.cdecl.} 
  ReprFunc* = proc (ob: PyObjectPtr): PyObjectPtr{.cdecl.}
  BinaryFunc* = proc (ob1, ob2: PyObjectPtr): PyObjectPtr{.cdecl.}
  TernaryFunc* = proc (ob1, ob2, ob3: PyObjectPtr): PyObjectPtr{.cdecl.}
  UnaryFunc* = proc (ob: PyObjectPtr): PyObjectPtr{.cdecl.}
  Inquiry* = proc (ob: PyObjectPtr): int{.cdecl.}
  LenFunc* = proc (ob: PyObjectPtr): PySizeT{.cdecl.}
  PySizeArgFunc* = proc (ob: PyObjectPtr, i: PySizeT): PyObjectPtr{.cdecl.}
  PySizeSizeArgFunc* = proc (ob: PyObjectPtr, 
                             i1, i2: PySizeT): PyObjectPtr{.cdecl.}
  PySizeObjArgFunc* = proc (ob1: PyObjectPtr, i: PySizeT, 
                            ob2: PyObjectPtr): int{.cdecl.}
  PySizeSizeObjArgFunc* = proc (ob1: PyObjectPtr, i1, i2: PySizeT, 
                                ob2: PyObjectPtr): int{.cdecl.}
  ObjObjArgProc* = proc (ob1, ob2, ob3: PyObjectPtr): int{.cdecl.}
  HashFunc* = proc (ob: PyObjectPtr): PyHashT{.cdecl.}
  GetBufferProc* = proc (ob: PyObjectPtr, buf: PyBufferPtr, i: int)
  ReleaseBufferProc* = proc (ob: PyObjectPtr, buf: PyBufferPtr)
  ObjObjProc* = proc (ob1, ob2: PyObjectPtr): int{.cdecl.}
  VisitProc* = proc (ob: PyObjectPtr, p: pointer): int{.cdecl.}
  TraverseProc* = proc (ob: PyObjectPtr, prc: VisitProc, 
                        p: pointer): int{.cdecl.}
  RichCmpFunc* = proc (ob1, ob2: PyObjectPtr, i: int): PyObjectPtr{.cdecl.}
  GetIterFunc* = proc (ob: PyObjectPtr): PyObjectPtr{.cdecl.}
  IterNextFunc* = proc (ob: PyObjectPtr): PyObjectPtr{.cdecl.}
  PyCFunction* = proc (self, args: PyObjectPtr): PyObjectPtr{.cdecl.}
  Getter* = proc (obj: PyObjectPtr, context: pointer): PyObjectPtr{.cdecl.}
  Setter* = proc (obj, value: PyObjectPtr, context: pointer): int{.cdecl.}
  DescrGetFunc* = proc (ob1, ob2, ob3: PyObjectPtr): PyObjectPtr{.cdecl.}
  DescrSetFunc* = proc (ob1, ob2, ob3: PyObjectPtr): int{.cdecl.}
  InitProc* = proc (self, args, kwds: PyObjectPtr): int{.cdecl.}
  NewFunc* = proc (subtype: PyTypeObjectPtr, 
                   args, kwds: PyObjectPtr): PyObjectPtr{.cdecl.}
  AllocFunc* = proc (self: PyTypeObjectPtr, 
                     nitems: PySizeT): PyObjectPtr{.cdecl.}
  PyTraceFunc* = proc (obj: PyObjectPtr; frame: PyFrameObjectPtr; 
                       what: cint; arg: PyObjectPtr): cint{.cdecl.}
  
  PyObjectPtrPtr* = ptr PyObjectPtr
  PyObjectPtr* = ptr PyObject
  PyObject* {.pure, inheritable.} = object # Defined in "Include/object.h"
    obRefcnt*: PySizeT
    obType*: PyTypeObjectPtr
  
  PyTypeObjectPtr* = ptr PyTypeObject
  PyTypeObject* = object of PyObject  # Defined in "Include/object.h"
    # 'ob_base*: PyVarObject' isn't here because the object 
    #  already inherits from PyObject
    obSize*: PySizeT
    tpName*: cstring
    tpBasicsize*: PySizeT
    tpItemsize*: PySizeT
    # Methods to implement standard operations
    tpDealloc*: Destructor
    tpPrint*: PrintFunc
    tpGetattr*: GetAttrFunc
    tpSetattr*: SetAttrFunc
    tpReserved*: pointer # formerly known as tp_compare
    tpRepr*: ReprFunc
    # Method suites for standard classes
    tpAsNumber*: PyNumberMethodsPtr
    tpAsSequence*: PySequenceMethodsPtr
    tpAsMapping*: PyMappingMethodsPtr 
    # More standard operations (here for binary compatibility)
    tpHash*: HashFunc
    tpCall*: TernaryFunc
    tpStr*: ReprFunc
    tpGetattro*: GetAttrOFunc
    tpSetattro*: SetAttrOFunc
    # Functions to access object as input/output buffer
    tpAsBuffer*: PyBufferProcsPtr
    # Flags to define presence of optional/expanded features
    tpFlags*: int32
    # Documentation string
    tpDoc*: cstring
    # Call function for all accessible objects
    tpTraverse*: TraverseProc
    # Delete references to contained objects
    tpClear*: Inquiry       
    # Rich comparisons
    tpRichcompare*: RichCmpFunc 
    # Weak reference enabler
    tpWeaklistoffset*: PySizeT 
    # Iterators
    tpIter*: GetIterFunc
    tpIternext*: IterNextFunc 
    # Attribute descriptor and subclassing stuff
    tpMethods*: PyMethodDefPtr
    tpMembers*: PyMemberDefPtr
    tpGetset*: PyGetSetDefPtr
    tpBase*: PyTypeObjectPtr
    tpDict*: PyObjectPtr
    tpDescrGet*: DescrGetFunc
    tpDescrSet*: DescrSetFunc
    tpDictoffset*: PySizeT
    tpInit*: InitProc
    tpAlloc*: AllocFunc
    tpNew*: NewFunc
    tpFree*: FreeFunc # Low-level free-memory routine
    tpIsGc*: Inquiry  # For PyObject_IS_GC
    tpBases*: PyObjectPtr
    tpMro*: PyObjectPtr    # method resolution order
    tpCache*: PyObjectPtr
    tpSubclasses*: PyObjectPtr
    tpWeaklist*: PyObjectPtr
    tpDel*: Destructor
    tpVersionTag*: uint # Type attribute cache version tag
    tpFinalize*: Destructor
    # These must be last and never explicitly initialized
    tpAllocs*: PySizeT 
    tpFrees*: PySizeT 
    tpMaxalloc*: PySizeT
    tpPrev*: PyTypeObjectPtr
    tpNext*: PyTypeObjectPtr
  
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
    nbAdd*: BinaryFunc
    nbSubstract*: BinaryFunc
    nbMultiply*: BinaryFunc
    nbRemainder*: BinaryFunc
    nbDivmod*: BinaryFunc
    nbPower*: TernaryFunc
    nbNegative*: UnaryFunc
    nbPositive*: UnaryFunc
    nbAbsolute*: UnaryFunc
    nbBool*: Inquiry
    nbInvert*: UnaryFunc
    nbLshift*: BinaryFunc
    nbRshift*: BinaryFunc
    nbAnd*: BinaryFunc
    nbXor*: BinaryFunc
    nbOr*: BinaryFunc
    nbInt*: UnaryFunc
    nbReserved*: pointer
    nbFloat*: UnaryFunc     
    
    nbInplaceAdd*: BinaryFunc
    nbInplaceSubtract*: BinaryFunc
    nbInplaceMultiply*: BinaryFunc
    nbInplaceRemainder*: BinaryFunc
    nbInplacePower*: TernaryFunc
    nbInplaceLshift*: BinaryFunc
    nbInplaceRshift*: BinaryFunc
    nbInplaceAnd*: BinaryFunc
    nbInplaceXor*: BinaryFunc
    nbInplaceOr*: BinaryFunc
    
    nbFloorDivide*: BinaryFunc
    nbTrueDivide*: BinaryFunc
    nbInplaceFloorDivide*: BinaryFunc
    nbInplaceTrueDivide*: BinaryFunc
    
    nbIndex*: UnaryFunc
  
  PySequenceMethodsPtr* = ptr PySequenceMethods
  PySequenceMethods*{.final.} = object    # Defined in "Include/object.h"
    sqLength*: LenFunc
    sqConcat*: BinaryFunc
    sqRepeat*: PySizeArgFunc
    sqItem*: PySizeArgFunc
    wasSqSlice*: pointer
    sqAssItem*: PySizeObjArgFunc
    wasSqAssSlice*: pointer 
    sqContains*: ObjObjProc
    sqInplaceConcat*: BinaryFunc
    sqInplaceRepeat*: PySizeArgFunc
  
  PyMappingMethodsPtr* = ptr PyMappingMethods 
  PyMappingMethods*{.final.} = object # Defined in "Include/object.h"
    mp_length: LenFunc
    mp_subscript: BinaryFunc
    mp_ass_subscript: ObjObjArgProc
  
  PyBufferProcsPtr* = ptr PyBufferProcs
  PyBufferProcs*{.final.} = object    # Defined in "Include/object.h"
    bfGetbuffer*: GetBufferProc
    bfReleasebuffer*: ReleaseBufferProc
  
  PyMethodDefPtr* = ptr PyMethodDef
  PyMethodDef*{.final.} = object  # Defined in "Include/methodobject.h"
    mlName*: cstring
    mlMeth*: PyCFunction
    mlFlags*: int
    mlDoc*: cstring
  
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
    obBase*: PyObject
    obSize*: PySizeT

  PyCompilerFlagsPtr* = ptr PyCompilerFlags
  PyCompilerFlags* = object # Defined in "Include/pythonrun.h"
    cfFlags: int
  
  PyNodePtr* = ptr PyNode
  PyNode* = object # Defined in "Include/node.h"
    nType: int16
    nStr: cstring
    nLineno: int
    nColOffset: int
    nNchildren: int
    nChild: PyNodePtr

  PyTryBlockPtr* = ptr PyTryBlock
  PyTryBlock = object # Defined in "Include/frameobject.h"
    bType: int # what kind of block this is
    bHandler: int # where to jump to find handler
    bLevel: int # value stack level to pop to

  PyCodeObjectPtr* = ptr PyCodeObject
  PyCodeObject = object   # Defined in "Include/code.h"
    obBase*: PyObject
    coArgcount*: int   # arguments, except *args 
    coKwonlyargcount*: int # keyword only arguments
    coNlocals*: int    # local variables
    coStacksize*: int  # entries needed for evaluation stack
    coFlags*: int  # CO..., see below
    coCode*: PyObjectPtr   # instruction opcodes
    coConsts*: PyObjectPtr # list (constants used)
    coNames*: PyObjectPtr  # list of strings (names used)
    coVarnames*: PyObjectPtr   # tuple of strings (local variable names)
    coFreevars*: PyObjectPtr   # tuple of strings (free variable names)
    coCellvars*: PyObjectPtr   # tuple of strings (cell variable names)
    # The rest doesn't count for hash or comparisons
    coCell2arg*: ptr uint8 # Maps cell vars which are arguments
    coFilename*: PyObjectPtr   # unicode (where it was loaded from)
    coName*: PyObjectPtr   # unicode (name, for reference)
    coFirstlineno*: int    # first source line number
    coLnotab*: PyObjectPtr # string (encoding addr<->lineno mapping) 
                           # See Objects/lnotabNotes.txt for details.
    coZombieframe*: pointer    # for optimization only (see frameobject.c)
    coWeakreflist*: PyObjectPtr    # to support weakrefs to code objects

  PyFrameObjectPtr* = ptr PyFrameObject
  PyFrameObject* = object # Defined in "Include/frameobject.h"
    obBase*: PyVarObject
    fBack*: PyFrameObjectPtr   # previous frame, or NULL
    fCode*: PyCodeObject       # code segment
    fBuiltins*: PyObjectPtr    # builtin symbol table (PyDictObject)
    fGlobals*: PyObjectPtr     # global symbol table (PyDictObject)
    fLocals*: PyObjectPtr      # local symbol table (any mapping)
    fValuestack*: PyObjectPtrPtr   # points after the last local
    fStacktop*: PyObjectPtrPtr     # points after the last local
    fTrace*: PyObjectPtr   # Trace function
    fExcType*, fExcValue*, fExcTraceback*: PyObjectPtr
    fGen*: PyObjectPtr # Borrowed reference to a generator, or NULL
    fLasti*: int   # Last instruction if called
    fLineno*: int  # Current line number
    fIblock*: int  # index in fBlockstack
    fExecuting*: int8  # whether the frame is still executing
    fBlockstack: array[0..coMaxBlocks-1, PyTryBlock]  # for try and loop blocks
    fLocalsplus*: UncheckedArray[PyObjectPtr]
    
var
  # Library handle used by the hooks, defined below
  libraryHandle = loadDllLib(libraryString)

  ## Hooks (need to be loaded from the dynamic library)
  # Hook 'PyOS_InputHook' C specification: 'int func(void)'
  osInputHook* = cast[ptr proc(): int{.cdecl.}](
                 dynlib.symAddr(libraryHandle, "PyOS_InputHook"))
  # Hook 'PyOS_InputHook' C specification:
  # 'char *func(FILE *stdin, FILE *stdout, char *prompt)'
  osReadlineFunctionPointer* = cast[ptr proc(): int{.cdecl.}](
                  dynlib.symAddr(libraryHandle, "PyOS_ReadlineFunctionPointer"))
  
  ## Standard exception base classes
  excBaseException*: PyObjectPtr = cast[PyObjectPtr](
                     dynlib.symAddr(libraryHandle, "PyExc_BaseException"))
  excException*: PyObjectPtr = cast[PyObjectPtr](
                 dynlib.symAddr(libraryHandle, "PyExc_Exception"))
  excStopIteration*: PyObjectPtr = cast[PyObjectPtr](
                     dynlib.symAddr(libraryHandle, "PyExc_StopIteration"))
  excGeneratorExit*: PyObjectPtr = cast[PyObjectPtr](
                     dynlib.symAddr(libraryHandle, "PyExc_GeneratorExit"))
  excArithmeticError*: PyObjectPtr = cast[PyObjectPtr](
                       dynlib.symAddr(libraryHandle, "PyExc_ArithmeticError"))
  excLookupError*: PyObjectPtr = cast[PyObjectPtr](
                   dynlib.symAddr(libraryHandle, "PyExc_LookupError"))
  excAssertionError*: PyObjectPtr = cast[PyObjectPtr](
                      dynlib.symAddr(libraryHandle, "PyExc_AssertionError"))
  excAttributeError*: PyObjectPtr = cast[PyObjectPtr](
                      dynlib.symAddr(libraryHandle, "PyExc_AttributeError"))
  excBufferError*: PyObjectPtr = cast[PyObjectPtr](
                   dynlib.symAddr(libraryHandle, "PyExc_BufferError"))
  excEOFError*: PyObjectPtr = cast[PyObjectPtr](
                dynlib.symAddr(libraryHandle, "PyExc_EOFError"))
  excFloatingPointError*: PyObjectPtr = cast[PyObjectPtr](
                    dynlib.symAddr(libraryHandle, "PyExc_FloatingPointError"))
  excOSError*: PyObjectPtr = cast[PyObjectPtr](
               dynlib.symAddr(libraryHandle, "PyExc_OSError"))
  excImportError*: PyObjectPtr = cast[PyObjectPtr](
                   dynlib.symAddr(libraryHandle, "PyExc_ImportError"))
  excIndexError*: PyObjectPtr = cast[PyObjectPtr](
                  dynlib.symAddr(libraryHandle, "PyExc_IndexError"))
  excKeyError*: PyObjectPtr = cast[PyObjectPtr](
                dynlib.symAddr(libraryHandle, "PyExc_KeyError"))
  excKeyboardInterrupt*: PyObjectPtr = cast[PyObjectPtr](
                       dynlib.symAddr(libraryHandle, "PyExc_KeyboardInterrupt"))
  excMemoryError*: PyObjectPtr = cast[PyObjectPtr](
                   dynlib.symAddr(libraryHandle, "PyExc_MemoryError"))
  excNameError*: PyObjectPtr = cast[PyObjectPtr](
                 dynlib.symAddr(libraryHandle, "PyExc_NameError"))
  excOverflowError*: PyObjectPtr = cast[PyObjectPtr](
                     dynlib.symAddr(libraryHandle, "PyExc_OverflowError"))
  excRuntimeError*: PyObjectPtr = cast[PyObjectPtr](
                    dynlib.symAddr(libraryHandle, "PyExc_RuntimeError"))
  excNotImplementedError*: PyObjectPtr = cast[PyObjectPtr](
                    dynlib.symAddr(libraryHandle, "PyExc_NotImplementedError"))
  excSyntaxError*: PyObjectPtr = cast[PyObjectPtr](
                   dynlib.symAddr(libraryHandle, "PyExc_SyntaxError"))
  excIndentationError*: PyObjectPtr = cast[PyObjectPtr](
                        dynlib.symAddr(libraryHandle, "PyExc_IndentationError"))
  excTabError*: PyObjectPtr = cast[PyObjectPtr](
                dynlib.symAddr(libraryHandle, "PyExc_TabError"))
  excReferenceError*: PyObjectPtr = cast[PyObjectPtr](
                      dynlib.symAddr(libraryHandle, "PyExc_ReferenceError"))
  excSystemError*: PyObjectPtr = cast[PyObjectPtr](
                   dynlib.symAddr(libraryHandle, "PyExc_SystemError"))
  excSystemExit*: PyObjectPtr = cast[PyObjectPtr](
                  dynlib.symAddr(libraryHandle, "PyExc_SystemExit"))
  excTypeError*: PyObjectPtr = cast[PyObjectPtr](
                 dynlib.symAddr(libraryHandle, "PyExc_TypeError"))
  excUnboundLocalError*: PyObjectPtr = cast[PyObjectPtr](
                    dynlib.symAddr(libraryHandle, "PyExc_UnboundLocalError"))
  excUnicodeError*: PyObjectPtr = cast[PyObjectPtr](
                    dynlib.symAddr(libraryHandle, "PyExc_UnicodeError"))
  excUnicodeEncodeError*: PyObjectPtr = cast[PyObjectPtr](
                    dynlib.symAddr(libraryHandle, "PyExc_UnicodeEncodeError"))
  excUnicodeDecodeError*: PyObjectPtr = cast[PyObjectPtr](
                    dynlib.symAddr(libraryHandle, "PyExc_UnicodeDecodeError"))
  excUnicodeTranslateError*: PyObjectPtr = cast[PyObjectPtr](
                dynlib.symAddr(libraryHandle, "PyExc_UnicodeTranslateError"))
  excValueError*: PyObjectPtr = cast[PyObjectPtr](
                  dynlib.symAddr(libraryHandle, "PyExc_ValueError"))
  excZeroDivisionError*: PyObjectPtr = cast[PyObjectPtr](
                    dynlib.symAddr(libraryHandle, "PyExc_ZeroDivisionError"))
  # Exceptions available only in Python 3.3 and higher
  excBlockingIOError*: PyObjectPtr = cast[PyObjectPtr](
                       dynlib.symAddr(libraryHandle, "PyExc_BlockingIOError"))
  excBrokenPipeError*: PyObjectPtr = cast[PyObjectPtr](
                       dynlib.symAddr(libraryHandle, "PyExc_BrokenPipeError"))
  excChildProcessError*: PyObjectPtr = cast[PyObjectPtr](
                    dynlib.symAddr(libraryHandle, "PyExc_ChildProcessError"))
  excConnectionError*: PyObjectPtr = cast[PyObjectPtr](
                       dynlib.symAddr(libraryHandle, "PyExc_ConnectionError"))
  excConnectionAbortedError*: PyObjectPtr = cast[PyObjectPtr](
                dynlib.symAddr(libraryHandle, "PyExc_ConnectionAbortedError"))
  excConnectionRefusedError*: PyObjectPtr = cast[PyObjectPtr](
                dynlib.symAddr(libraryHandle, "PyExc_ConnectionRefusedError"))
  excConnectionResetError*: PyObjectPtr = cast[PyObjectPtr](
                    dynlib.symAddr(libraryHandle, "PyExc_ConnectionResetError"))
  excFileExistsError*: PyObjectPtr = cast[PyObjectPtr](
                       dynlib.symAddr(libraryHandle, "PyExc_FileExistsError"))
  excFileNotFoundError*: PyObjectPtr = cast[PyObjectPtr](
                    dynlib.symAddr(libraryHandle, "PyExc_FileNotFoundError"))
  excInterruptedError*: PyObjectPtr = cast[PyObjectPtr](
                        dynlib.symAddr(libraryHandle, "PyExc_InterruptedError"))
  excIsADirectoryError*: PyObjectPtr = cast[PyObjectPtr](
                       dynlib.symAddr(libraryHandle, "PyExc_IsADirectoryError"))
  excNotADirectoryError*: PyObjectPtr = cast[PyObjectPtr](
                    dynlib.symAddr(libraryHandle, "PyExc_NotADirectoryError"))
  excPermissionError*: PyObjectPtr = cast[PyObjectPtr](
                       dynlib.symAddr(libraryHandle, "PyExc_PermissionError"))
  excProcessLookupError*: PyObjectPtr = cast[PyObjectPtr](
                    dynlib.symAddr(libraryHandle, "PyExc_ProcessLookupError"))
  excTimeoutError*: PyObjectPtr = cast[PyObjectPtr](
                    dynlib.symAddr(libraryHandle, "PyExc_TimeoutError"))


## Python C functions that can be used 'As is' from Nim
# Initializing and finalizing the interpreter
proc initialize*(){.cdecl, importc: "Py_Initialize" dynlib: libraryString.}
proc finalize*(){.cdecl, importc: "Py_Finalize" dynlib: libraryString.}
# Run the interpreter independantly of the Nim application
proc main*(argc: int, argv: WideCStringPtr): int{.cdecl, importc: "Py_Main" 
  dynlib: libraryString.}
# Execute a script from a string
proc runSimpleString*(command: cstring): int{.cdecl, importc: "PyRun_SimpleString" 
  dynlib: libraryString.}
proc runSimpleStringFlags*(command: cstring, flags: PyCompilerFlagsPtr): int{.
  cdecl, importc: "PyRun_SimpleStringFlags" dynlib: libraryString.}
# Advanced string execution
proc runString*(str: cstring, start: int, globals: PyObjectPtr, 
                locals: PyObjectPtr): PyObjectPtr{.cdecl, 
                importc: "PyRun_String" dynlib: libraryString.}
proc runStringFlags*(str: cstring, start: int, globals: 
                     PyObjectPtr, locals: PyObjectPtr, 
                     flags: PyCompilerFlags): PyObjectPtr{.cdecl, 
                     importc: "PyRun_StringFlags" dynlib: libraryString.}
# Parsing python source code and returning a node object
proc parserSimpleParseString*(str: cstring, start: int): PyNodePtr{.cdecl, 
  importc: "PyParser_SimpleParseString" dynlib: libraryString.}
proc parserSimpleParseStringFlags*(str: cstring, start: int, 
                                   flags: int): PyNodePtr{.cdecl, 
                                   importc: "PyParser_SimpleParseStringFlags"
                                   dynlib: libraryString.}
proc parserSimpleParseStringFlagsFilename*(str: cstring, 
  filename: cstring, start: int, flags: int): PyNodePtr{.cdecl, 
  importc: "PyParser_SimpleParseStringFlagsFilename" dynlib: libraryString.}
# Parse and compile the Python source code in str, returning the resulting code object
proc compileString*(str: cstring, filename: cstring, start: int): PyObjectPtr{.
  cdecl, importc: "Py_CompileString" dynlib: libraryString.}
proc compileStringFlags*(str: cstring, filename: cstring, start: int, 
  flags: PyCompilerFlagsPtr): PyObjectPtr{.cdecl, 
  importc: "Py_CompileStringFlags" dynlib: libraryString.}
proc compileStringExFlags*(str: cstring, filename: cstring, start: int, 
  flags: PyCompilerFlagsPtr, optimize: int): PyObjectPtr{.cdecl, 
  importc: "Py_CompileStringExFlags" dynlib: libraryString.}
proc compileStringObject*(str: cstring, filename: PyObjectPtr, start: int, 
  flags: PyCompilerFlagsPtr, optimize: int): PyObjectPtr{.cdecl, 
  importc: "Py_CompileStringObject" dynlib: libraryString.}
# Evaluate a precompiled code object, 
# given a particular environment for its evaluation
proc evalEvalCode*(ob: PyObjectPtr, globals: PyObjectPtr, 
  locals: PyObjectPtr): PyObjectPtr{.cdecl, importc: "PyEval_EvalCode" 
  dynlib: libraryString.}
proc evalEvalCodeEx*(ob: PyObjectPtr, globals: PyObjectPtr, 
  locals: PyObjectPtr, args: PyObjectPtrPtr, argcount: int, 
  kws: PyObjectPtrPtr, kwcount: int, defs: PyObjectPtrPtr, 
  defcount: int, closure: PyObjectPtr): PyObjectPtr{.cdecl, 
  importc: "PyEval_EvalCodeEx" dynlib: libraryString.}
# Evaluate an execution frame
proc evalEvalFrame*(f: PyFrameObjectPtr): PyObjectPtr{.cdecl, 
  importc: "PyEval_EvalFrame" dynlib: libraryString.}
# This is the main, unvarnished function of Python interpretation
proc evalEvalFrameEx*(f: PyFrameObjectPtr, throwflag: int): PyObjectPtr{.cdecl, 
  importc: "PyEval_EvalFrameEx" dynlib: libraryString.}
# This function changes the flags of the current evaluation frame, 
# and returns true on success, false on failure
proc evalMergeCompilerFlags*(cf: PyCompilerFlagsPtr): int{.cdecl, 
  importc: "PyEval_MergeCompilerFlags" dynlib: libraryString.}
# Reference Counting, C macros converted to Nim templates
template incref*(ob: PyObjectPtr) = 
  inc(ob.ob_refcnt)

template xincref*(ob: PyObjectPtr) =
  if ob != nil:
    incref(ob)

template decref*(ob: PyObjectPtr) =
  dec(ob.obRefcnt)
  if ob.obRefcnt == 0:
    ob.obType.tpDealloc(ob)

template xDecref*(ob: PyObjectPtr) = 
  if ob != nil:
    decref(ob)

template clear*(ob: PyObjectPtr) =
  var
    tempOb: PyObjectPtr = ob
  if tempOb != nil:
    ob = nil
    decref(tempOb)
# Exception Handling
proc errPrintEx*(set_sys_last_vars: int){.cdecl, importc: "PyErr_PrintEx" 
  dynlib: libraryString.}
proc errPrint*(){.cdecl, importc: "PyErr_Print" dynlib: libraryString.}
proc errOccurred*(): PyObjectPtr {.cdecl, importc: "PyErr_Occurred" 
  dynlib: libraryString.}
proc errExceptionMatches*(exc: PyObjectPtr): int{.cdecl, 
  importc: "PyErr_ExceptionMatches" dynlib: libraryString.}
proc errGivenExceptionMatches*(given: PyObjectPtr, exc: PyObjectPtr): int{.
  cdecl, importc: "PyErr_GivenExceptionMatches" dynlib: libraryString.}
proc errNormalizeException*(exc: PyObjectPtrPtr, val: PyObjectPtrPtr, 
  tb: PyObjectPtrPtr){.cdecl, importc: "PyErr_NormalizeException" 
  dynlib: libraryString.}
proc errClear*(){.cdecl, importc: "PyErr_Clear" dynlib: libraryString.}
proc errFetch*(ptype: PyObjectPtrPtr, pvalue: PyObjectPtrPtr, 
  ptraceback: PyObjectPtrPtr){.cdecl, importc: "PyErr_Fetch" 
  dynlib: libraryString.}
proc errRestore*(typ: PyObjectPtr, value: PyObjectPtr, traceback: PyObjectPtr){.
  cdecl, importc: "PyErr_Restore" dynlib: libraryString.}
proc errGetExcInfo*(ptype: PyObjectPtrPtr, pvalue: PyObjectPtrPtr, 
  ptraceback: PyObjectPtrPtr){.cdecl, importc: "PyErr_GetExcInfo" 
  dynlib: libraryString.}
proc errSetExcInfo*(typ: PyObjectPtr, value: PyObjectPtr, 
  traceback: PyObjectPtr){.cdecl, importc: "PyErr_SetExcInfo" 
  dynlib: libraryString.}
proc errSetString*(typ: PyObjectPtr, message: cstring){.cdecl, 
  importc: "PyErr_SetString" dynlib: libraryString.}
proc errSetObject*(typ: PyObjectPtr, value: PyObjectPtr){.cdecl, 
  importc: "PyErr_SetObject" dynlib: libraryString.}
proc errFormat*(exception: PyObjectPtr, format: cstring): PyObjectPtr{.cdecl, 
  importc: "PyErr_Format" varargs, dynlib: libraryString, discardable.}
proc errSetNone*(typ: PyObjectPtr){.cdecl, importc: "PyErr_SetNone" 
  dynlib: libraryString.}
proc errBadArgument*(): int{.cdecl, importc: "PyErr_BadArgument" 
  dynlib: libraryString.}
proc errNoMemory*(): PyObjectPtr{.cdecl, importc: "PyErr_NoMemory" 
  dynlib: libraryString.}
proc errSetFromErrno*(typ: PyObjectPtr): PyObjectPtr{.cdecl, 
  importc: "PyErr_SetFromErrno" dynlib: libraryString.}
proc errSetFromErrnoWithFilenameObject*(typ: PyObjectPtr, 
  filenameObject: PyObjectPtr): PyObjectPtr{.cdecl, 
  importc: "PyErr_SetFromErrnoWithFilenameObject" dynlib: libraryString.}
proc errSetFromErrnoWithFilenameObjects*(typ: PyObjectPtr, 
  filenameObject: PyObjectPtr, filenameObject2: PyObjectPtr): PyObjectPtr{.
  cdecl, importc: "PyErr_SetFromErrnoWithFilenameObjects" dynlib: libraryString.}
proc errSetFromErrnoWithFilename*(typ: PyObjectPtr, 
  filename: cstring): PyObjectPtr{.cdecl, 
  importc: "PyErr_SetFromErrnoWithFilename" dynlib: libraryString.}
proc errSetFromWindowsErr*(ierr: int): PyObjectPtr{.cdecl, 
  importc: "PyErr_SetFromWindowsErr" dynlib: libraryString.}
proc errSetExcFromWindowsErr*(typ: PyObjectPtr, ierr: int): PyObjectPtr{.cdecl, 
  importc: "PyErr_SetExcFromWindowsErr" dynlib: libraryString.}
proc errSetFromWindowsErrWithFilename*(ierr: int, 
  filename: cstring): PyObjectPtr{.cdecl, 
  importc: "PyErr_SetFromWindowsErrWithFilename" dynlib: libraryString.}
proc errSetExcFromWindowsErrWithFilenameObject*(typ: PyObjectPtr, ierr: int, 
  filename: PyObjectPtr): PyObjectPtr{.cdecl, 
  importc: "PyErr_SetExcFromWindowsErrWithFilenameObject" dynlib: libraryString.}
proc errSetExcFromWindowsErrWithFilenameObjects*(typ: PyObjectPtr, ierr: int, 
  filename: PyObjectPtr, filename2: PyObjectPtr): PyObjectPtr{.cdecl, 
  importc: "PyErr_SetExcFromWindowsErrWithFilenameObjects" 
  dynlib: libraryString.}
proc errSetExcFromWindowsErrWithFilename*(typ: PyObjectPtr, ierr: int, 
  filename: cstring): PyObjectPtr{.cdecl, 
  importc: "PyErr_SetExcFromWindowsErrWithFilename" dynlib: libraryString.}
proc errSetImportError*(msg: PyObjectPtr, name: PyObjectPtr, 
  path: PyObjectPtr): PyObjectPtr{.cdecl, importc: "PyErr_SetImportError" 
  dynlib: libraryString.}
proc errSyntaxLocationObject*(filename: PyObjectPtr, lineno: int, 
  col_offset: int){.cdecl, importc: "PyErr_SyntaxLocationObject" 
  dynlib: libraryString.}
proc errSyntaxLocationEx*(filename: cstring, lineno: int, col_offset: int){.
  cdecl, importc: "PyErr_SyntaxLocationEx" dynlib: libraryString.}
proc errSyntaxLocation*(filename: cstring, lineno: int){.cdecl, 
  importc: "PyErr_SyntaxLocation" dynlib: libraryString.}
proc errBadInternalCall*(){.cdecl, importc: "PyErr_BadInternalCall" 
  dynlib: libraryString.}
proc errWarnEx*(category: PyObjectPtr, message: cstring, 
  stack_level: PySizeT): int{.cdecl, importc: "PyErr_WarnEx" 
  dynlib: libraryString.}
proc errWarnExplicitObject*(category: PyObjectPtr, message: PyObjectPtr, 
  filename: PyObjectPtr, lineno: int, module: PyObjectPtr, 
  registry: PyObjectPtr): int{.cdecl, importc: "PyErr_WarnExplicitObject" 
  dynlib: libraryString.}
proc errWarnExplicit*(category: PyObjectPtr, message: cstring, 
  filename: cstring, lineno: int, module: cstring, registry: PyObjectPtr): int{.
  cdecl, importc: "PyErr_WarnExplicit" dynlib: libraryString.}
proc errWarnFormat*(category: PyObjectPtr, stack_level: 
  PySizeT, format: cstring): int{.cdecl, importc: "PyErr_WarnFormat" varargs, 
  dynlib: libraryString.}
proc errCheckSignals*(): int{.cdecl, importc: "PyErr_CheckSignals" 
  dynlib: libraryString.}
proc errSetInterrupt*(){.cdecl, importc: "PyErr_SetInterrupt" 
  dynlib: libraryString.}
proc signalSetWakeupFd*(fd: int): int{.cdecl, importc: "PySignal_SetWakeupFd" 
  dynlib: libraryString.}
proc errNewException*(name: cstring, base: PyObjectPtr, 
  dict: PyObjectPtr): PyObjectPtr{.cdecl, importc: "PyErr_NewException" 
  dynlib: libraryString.}
proc errNewExceptionWithDoc*(name: cstring, doc: cstring, base: PyObjectPtr, 
  dict: PyObjectPtr): PyObjectPtr{.cdecl, importc: "PyErr_NewExceptionWithDoc" 
  dynlib: libraryString.}
proc errWriteUnraisable*(obj: PyObjectPtr){.cdecl, 
  importc: "PyErr_WriteUnraisable" dynlib: libraryString.}
proc exceptionGetTraceback*(ex: PyObjectPtr): PyObjectPtr{.cdecl, 
  importc: "PyException_GetTraceback" dynlib: libraryString.}
proc exceptionSetTraceback*(ex: PyObjectPtr, tb: PyObjectPtr): int{.cdecl, 
  importc: "PyException_SetTraceback" dynlib: libraryString.}
proc exceptionGetContext*(ex: PyObjectPtr): PyObjectPtr{.cdecl, 
  importc: "PyException_GetContext" dynlib: libraryString.}
proc exceptionSetContext*(ex: PyObjectPtr, ctx: PyObjectPtr){.cdecl, 
  importc: "PyException_SetContext" dynlib: libraryString.}
proc exceptionGetCause*(ex: PyObjectPtr): PyObjectPtr{.cdecl, 
  importc: "PyException_GetCause" dynlib: libraryString.}
proc exceptionSetCause*(ex: PyObjectPtr, cause: PyObjectPtr){.cdecl, 
  importc: "PyException_SetCause" dynlib: libraryString.}
proc unicodeDecodeErrorCreate*(encoding: cstring, obj: cstring, length: PySizeT,
  start: PySizeT, ending: PySizeT, reason: cstring): PyObjectPtr{.cdecl, 
  importc: "PyUnicodeDecodeError_Create" dynlib: libraryString.}
proc unicodeEncodeErrorCreate*(encoding: cstring, obj: PyUnicodePtr, 
  length: PySizeT, start: PySizeT, ending: PySizeT, 
  reason: cstring): PyObjectPtr{.cdecl, importc: "PyUnicodeEncodeError_Create" 
  dynlib: libraryString.}
proc unicodeTranslateErrorCreate*(obj: PyUnicodePtr, length: PySizeT, 
  start: PySizeT, ending: PySizeT, reason: cstring): PyObjectPtr{.cdecl, 
  importc: "PyUnicodeTranslateError_Create" dynlib: libraryString.}
proc unicodeDecodeErrorGetEncoding*(exc: PyObjectPtr): PyObjectPtr{.cdecl, 
  importc: "PyUnicodeDecodeError_GetEncoding" dynlib: libraryString.}
proc unicodeEncodeErrorGetEncoding*(exc: PyObjectPtr): PyObjectPtr{.cdecl, 
  importc: "PyUnicodeEncodeError_GetEncoding" dynlib: libraryString.}
proc unicodeDecodeErrorGetObject*(exc: PyObjectPtr): PyObjectPtr{.cdecl, 
  importc: "PyUnicodeDecodeError_GetObject" dynlib: libraryString.}
proc unicodeEncodeErrorGetObject*(exc: PyObjectPtr): PyObjectPtr{.cdecl, 
  importc: "PyUnicodeEncodeError_GetObject" dynlib: libraryString.}
proc unicodeTranslateErrorGetObject*(exc: PyObjectPtr): PyObjectPtr{.cdecl, 
  importc: "PyUnicodeTranslateError_GetObject" dynlib: libraryString.}
proc unicodeDecodeErrorGetStart*(exc: PyObjectPtr, start: PySizeTPtr): int{.
  cdecl, importc: "PyUnicodeDecodeError_GetStart" dynlib: libraryString.}
proc unicodeEncodeErrorGetStart*(exc: PyObjectPtr, start: PySizeTPtr): int{.
  cdecl, importc: "PyUnicodeEncodeError_GetStart" dynlib: libraryString.}
proc unicodeTranslateErrorGetStart*(exc: PyObjectPtr, start: PySizeTPtr): int{.
  cdecl, importc: "PyUnicodeTranslateError_GetStart" dynlib: libraryString.}
proc unicodeDecodeErrorSetStart*(exc: PyObjectPtr, start: PySizeT): int{.cdecl, 
  importc: "PyUnicodeDecodeError_SetStart" dynlib: libraryString.}
proc unicodeEncodeErrorSetStart*(exc: PyObjectPtr, start: PySizeT): int{.cdecl, 
  importc: "PyUnicodeEncodeError_SetStart" dynlib: libraryString.}
proc unicodeTranslateErrorSetStart*(exc: PyObjectPtr, start: PySizeT): int{.
  cdecl, importc: "PyUnicodeTranslateError_SetStart" dynlib: libraryString.}
proc unicodeDecodeErrorGetEnd*(exc: PyObjectPtr, ending: PySizeTPtr): int{.
  cdecl, importc: "PyUnicodeDecodeError_GetEnd" dynlib: libraryString.}
proc unicodeEncodeErrorGetEnd*(exc: PyObjectPtr, ending: PySizeTPtr): int{.
  cdecl, importc: "PyUnicodeEncodeError_GetEnd" dynlib: libraryString.}
proc unicodeTranslateErrorGetEnd*(exc: PyObjectPtr, ending: PySizeTPtr): int{.
  cdecl, importc: "PyUnicodeTranslateError_GetEnd" dynlib: libraryString.}
proc unicodeDecodeErrorSetEnd*(exc: PyObjectPtr, ending: PySizeT): int{.cdecl, 
  importc: "PyUnicodeDecodeError_SetEnd" dynlib: libraryString.}
proc unicodeEncodeErrorSetEnd*(exc: PyObjectPtr, ending: PySizeT): int{.cdecl, 
  importc: "PyUnicodeEncodeError_SetEnd" dynlib: libraryString.}
proc unicodeTranslateErrorSetEnd*(exc: PyObjectPtr, ending: PySizeT): int{.
  cdecl, importc: "PyUnicodeTranslateError_SetEnd" dynlib: libraryString.}
proc unicodeDecodeErrorGetReason*(exc: PyObjectPtr): PyObjectPtr{.cdecl, 
  importc: "PyUnicodeDecodeError_GetReason" dynlib: libraryString.}
proc unicodeEncodeErrorGetReason*(exc: PyObjectPtr): PyObjectPtr{.cdecl, 
  importc: "PyUnicodeEncodeError_GetReason" dynlib: libraryString.}
proc unicodeTranslateErrorGetReason*(exc: PyObjectPtr): PyObjectPtr{.cdecl, 
  importc: "PyUnicodeTranslateError_GetReason" dynlib: libraryString.}
proc unicodeDecodeErrorSetReason*(exc: PyObjectPtr, reason: cstring): int{.
  cdecl, importc: "PyUnicodeDecodeError_SetReason" dynlib: libraryString.}
proc unicodeEncodeErrorSetReason*(exc: PyObjectPtr, reason: cstring): int{.
  cdecl, importc: "PyUnicodeEncodeError_SetReason" dynlib: libraryString.}
proc unicodeTranslateErrorSetReason*(exc: PyObjectPtr, reason: cstring): int{.
  cdecl, importc: "PyUnicodeTranslateError_SetReason" dynlib: libraryString.}
proc enterRecursiveCall*(where: cstring): int{.cdecl, 
  importc: "Py_EnterRecursiveCall" dynlib: libraryString.}
proc leaveRecursiveCall*(){.cdecl, importc: "Py_LeaveRecursiveCall" 
  dynlib: libraryString.}
proc reprEnter*(obj: PyObjectPtr): int{.cdecl, importc: "Py_ReprEnter" 
  dynlib: libraryString.}
proc reprLeave*(obj: PyObjectPtr){.cdecl, importc: "Py_ReprLeave" 
  dynlib: libraryString.}
# Operating System Utilities
proc osAfterFork*(){.cdecl, importc: "PyOS_AfterFork" dynlib: libraryString.}
proc osCheckStack*(): cint{.cdecl, importc: "PyOS_CheckStack" 
  dynlib: libraryString.}
proc osGetsig*(i: cint): PyosSighandler{.cdecl, importc: "PyOS_getsig" 
  dynlib: libraryString.}
proc osSetsig*(i: cint, h: PyosSighandler): PyosSighandler{.cdecl, 
  importc: "PyOS_setsig" dynlib: libraryString.}
# System Functions
proc sysGetObject*(name: cstring): PyObjectPtr{.cdecl, 
  importc: "PySys_GetObject" dynlib: libraryString.}
proc sysSetObject*(name: cstring; v: PyObjectPtr): cint{.cdecl, 
  importc: "PySys_SetObject" dynlib: libraryString.}
proc sysResetWarnOptions*(){.cdecl, importc: "PySys_ResetWarnOptions" 
  dynlib: libraryString.}
proc sysAddWarnOption*(s: WideCStringPtr){.cdecl, 
  importc: "PySys_AddWarnOption" dynlib: libraryString.}
proc sysAddWarnOptionUnicode*(unicode: PyObjectPtr){.cdecl, 
  importc: "PySys_AddWarnOptionUnicode" dynlib: libraryString.}
proc sysSetPath*(path: WideCStringPtr){.cdecl, importc: "PySys_SetPath" 
  dynlib: libraryString.}
proc sysWriteStdout*(format: cstring){.cdecl, 
  importc: "PySys_WriteStdout" varargs, dynlib: libraryString.}
proc sysWriteStderr*(format: cstring){.cdecl, 
  importc: "PySys_WriteStderr" varargs, dynlib: libraryString.}
proc sysFormatStdout*(format: cstring){.cdecl, 
  importc: "PySys_FormatStdout" varargs, dynlib: libraryString.}
proc sysFormatStderr*(format: cstring){.cdecl, 
  importc: "PySys_FormatStderr" varargs, dynlib: libraryString.}
proc sysAddXOption*(s: WideCStringPtr){.cdecl, importc: "PySys_AddXOption" 
  dynlib: libraryString.}
proc sysGetXOptions*(): PyObjectPtr{.cdecl, importc: "PySys_GetXOptions" 
  dynlib: libraryString.}
# Process Control
proc fatalError*(message: cstring){.cdecl, importc: "Py_FatalError" 
  dynlib: libraryString.}
proc exit*(status: cint){.cdecl, importc: "Py_Exit" dynlib: libraryString.}
proc atExit*(fun: proc (){.cdecl}): cint{.cdecl, importc: "Py_AtExit" 
  dynlib: libraryString.}


## Functions that are not portable across compilers (The 'File' type is different across compilers),
## each is usually followed by a Nim portable implementation of the same function
# Execute a script from a file
proc runAnyFile*(fp: File, filename: cstring): int{.cdecl, 
  importc: "PyRun_AnyFile" dynlib: libraryString.}
proc runAnyFile*(filename: string): int =
  result = runSimpleString(readFile(filename))
# Execute a script from a file with flags
proc runAnyFileFlags*(fp: File, filename: cstring, flags: PyCompilerFlags): int{.
  cdecl, importc: "PyRun_AnyFileFlags" dynlib: libraryString.}
proc runAnyFileFlags*(filename: string, flags: PyCompilerFlagsPtr): int =
  result = runSimpleStringFlags(readFile(filename), flags)
# Executing a script from a file with additional options and a return value
proc runFile*(fp: File, filename: cstring, start: int, globals: 
  PyObjectPtr, locals: PyObjectPtr): PyObjectPtr{.cdecl, 
  importc: "PyRun_File" dynlib: libraryString.}
proc runFile*(filename: string, start: int, globals: PyObjectPtr, 
              locals: PyObjectPtr): PyObjectPtr =
  var fileContents = readFile(fileName)
  result = runString(fileContents, pyFileInput, globals, locals)
proc runFileFlags*(fp: File, filename: cstring, start: int, 
  globals: PyObjectPtr, locals: PyObjectPtr, 
  flags: PyCompilerFlags): PyObjectPtr{.cdecl, 
  importc: "PyRun_FileFlags" dynlib: libraryString.}
proc runFileFlags*(filename: string, start: int, globals: PyObjectPtr, 
  locals: PyObjectPtr, flags: PyCompilerFlags): PyObjectPtr =
  var fileContents = readFile(fileName)
  result = runStringFlags(fileContents, pyFileInput, globals, locals, flags)
# These C functions do not need to be ported, the above procedures are enough
proc runAnyFileEx*(fp: File, filename: cstring, closeit: int): int{.cdecl, 
  importc: "PyRun_AnyFileEx" dynlib: libraryString.}
proc runAnyFileExFlags*(fp: File, filename: cstring, closeit: int, 
  flags: PyCompilerFlags): int{.cdecl, importc: "PyRun_AnyFileExFlags" 
  dynlib: libraryString.}
proc runSimpleFile*(fp: File, filename: cstring): int{.cdecl, 
  importc: "PyRun_SimpleFile" dynlib: libraryString.}
proc runSimpleFileEx*(fp: File, filename: cstring, closeit: int): int{.cdecl, 
  importc: "PyRun_SimpleFileEx" dynlib: libraryString.}
proc runSimpleFileExFlags*(fp: File, filename: cstring, closeit: int, 
  flags: PyCompilerFlags): int{.cdecl, importc: "PyRun_SimpleFileExFlags" 
  dynlib: libraryString.}
proc parserSimpleParseFile*(fp: File, filename: cstring, start: int): PyNodePtr{.
  cdecl, importc: "PyParser_SimpleParseFile" dynlib: libraryString.}
proc parserSimpleParseFileFlags*(fp: File, filename: cstring, start: int, 
  flags: int): PyNodePtr{.cdecl, importc: "PyParser_SimpleParseFileFlags" 
  dynlib: libraryString.}
proc runFileEx*(fp: File, filename: cstring, start: int, globals: PyObjectPtr, 
  locals: PyObjectPtr, closeit: int): PyObjectPtr{.cdecl, 
  importc: "PyRun_FileEx" dynlib: libraryString.}
proc runFileExFlags*(fp: File, filename: cstring, start: int, 
  globals: PyObjectPtr, locals: PyObjectPtr, closeit: int, 
  flags: PyCompilerFlags): PyObjectPtr{.cdecl, importc: "PyRun_FileExFlags" 
  dynlib: libraryString.}
# Functions for reading and executing code from a file associated with an interactive device. For now they will stay non-portable.
proc runInteractiveOne*(fp: File, filename: cstring): int{.cdecl, 
  importc: "PyRun_InteractiveOne" dynlib: libraryString.}
proc runInteractiveOneFlags*(fp: File, filename: cstring, 
  flags: PyCompilerFlags): int{.cdecl, importc: "PyRun_InteractiveOneFlags" 
  dynlib: libraryString.}
proc runInteractiveLoop*(fp: File, filename: cstring): int{.cdecl, 
  importc: "PyRun_InteractiveLoop" dynlib: libraryString.}
proc runInteractiveLoopFlags*(fp: File, filename: cstring, 
  flags: PyCompilerFlags): int{.cdecl, importc: "PyRun_InteractiveLoopFlags" 
  dynlib: libraryString.}
# Non-portable operating system functions
proc fdIsInteractive*(fp: File; filename: cstring): cint{.cdecl, 
  importc: "Py_FdIsInteractive" dynlib: libraryString.}


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

var importFrozenModules*: FrozenPtr = cast[FrozenPtr](dynlib.symAddr(libraryHandle, "PyImport_FrozenModules"))
    
proc importImportModule*(name: cstring): PyObjectPtr {.cdecl, importc: "PyImport_ImportModule" dynlib: libraryString.}
proc importImportModuleNoBlock*(name: cstring): PyObjectPtr {.cdecl, 
  importc: "PyImport_ImportModuleNoBlock" dynlib: libraryString.}
proc importImportModuleEx*(name: cstring; globals: PyObjectPtr; 
  locals: PyObjectPtr; fromlist: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyImport_ImportModuleEx" dynlib: libraryString.}
proc importImportModuleLevelObject*(name: PyObjectPtr; globals: PyObjectPtr; 
  locals: PyObjectPtr; fromlist: PyObjectPtr; level: cint): PyObjectPtr {.cdecl, 
  importc: "PyImport_ImportModuleLevelObject" dynlib: libraryString.}
proc importImportModuleLevel*(name: cstring; globals: PyObjectPtr; 
  locals: PyObjectPtr; fromlist: PyObjectPtr; level: cint): PyObjectPtr {.cdecl, 
  importc: "PyImport_ImportModuleLevel" dynlib: libraryString.}
proc importImport*(name: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyImport_Import" dynlib: libraryString.}
proc importReloadModule*(m: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyImport_ReloadModule" dynlib: libraryString.}
proc importAddModuleObject*(name: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyImport_AddModuleObject" dynlib: libraryString.}
proc importAddModule*(name: cstring): PyObjectPtr {.cdecl, 
  importc: "PyImport_AddModule" dynlib: libraryString.}
proc importExecCodeModule*(name: cstring; co: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyImport_ExecCodeModule" dynlib: libraryString.}
proc importExecCodeModuleEx*(name: cstring; co: PyObjectPtr; 
  pathname: cstring): PyObjectPtr {.cdecl, importc: "PyImport_ExecCodeModuleEx" 
  dynlib: libraryString.}
proc importExecCodeModuleObject*(name: PyObjectPtr; co: PyObjectPtr; 
  pathname: PyObjectPtr; cpathname: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyImport_ExecCodeModuleObject" dynlib: libraryString.}
proc importExecCodeModuleWithPathnames*(name: cstring; co: PyObjectPtr; 
  pathname: cstring; cpathname: cstring): PyObjectPtr {.cdecl, 
  importc: "PyImport_ExecCodeModuleWithPathnames" dynlib: libraryString.}
proc importGetMagicNumber*(): clong {.cdecl, importc: "PyImport_GetMagicNumber" 
  dynlib: libraryString.}
proc importGetMagicTag*(): cstring {.cdecl, importc: "PyImport_GetMagicTag" 
  dynlib: libraryString.}
proc importGetModuleDict*(): PyObjectPtr {.cdecl, 
  importc: "PyImport_GetModuleDict" dynlib: libraryString.}
proc importGetImporter*(path: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyImport_GetImporter" dynlib: libraryString.}
proc importInit*() {.cdecl, importc: "_PyImport_Init", dynlib: libraryString.}
proc importCleanup*() {.cdecl, importc: "PyImport_Cleanup" dynlib: libraryString.}
proc importFini*() {.cdecl, importc: "_PyImport_Fini", dynlib: libraryString.}
proc importFindExtension*(arg0: cstring; arg1: cstring): PyObjectPtr {.cdecl, 
  importc: "_PyImport_FindExtension", dynlib: libraryString.}
proc importImportFrozenModuleObject*(name: PyObjectPtr): cint {.cdecl, 
  importc: "PyImport_ImportFrozenModuleObject" dynlib: libraryString.}
proc importImportFrozenModule*(name: cstring): cint {.cdecl, 
  importc: "PyImport_ImportFrozenModule" dynlib: libraryString.}
proc importAppendInittab*(name: cstring; 
  initfunc: proc (): PyObjectPtr {.cdecl.}): cint {.cdecl, 
  importc: "PyImport_AppendInittab" dynlib: libraryString, discardable.}
proc importExtendInittab*(newtab: ptr InitTab): cint {.cdecl, 
  importc: "PyImport_ExtendInittab" dynlib: libraryString.}

#Data marshalling support
proc marshalWriteLongToFile*(value: clong; file: File; version: cint) {.cdecl, 
  importc: "PyMarshal_WriteLongToFile" dynlib: libraryString.}
proc marshalWriteObjectToFile*(value: PyObjectPtr; file: File; version: cint) {.
  cdecl, importc: "PyMarshal_WriteObjectToFile" dynlib: libraryString.}
proc marshalWriteObjectToString*(value: PyObjectPtr; 
  version: cint): PyObjectPtr {.cdecl, importc: "PyMarshal_WriteObjectToString" 
  dynlib: libraryString.}
proc marshalReadLongFromFile*(file: File): clong {.cdecl, 
  importc: "PyMarshal_ReadLongFromFile" dynlib: libraryString.}
proc marshalReadShortFromFile*(file: File): cint {.cdecl, 
  importc: "PyMarshal_ReadShortFromFile" dynlib: libraryString.}
proc marshalReadObjectFromFile*(file: File): PyObjectPtr {.cdecl, 
  importc: "PyMarshal_ReadObjectFromFile" dynlib: libraryString.}
proc marshalReadLastObjectFromFile*(file: File): PyObjectPtr {.cdecl, 
  importc: "PyMarshal_ReadLastObjectFromFile" dynlib: libraryString.}
proc marshalReadObjectFromString*(string: cstring; 
  len: PySizeT): PyObjectPtr {.cdecl, importc: "PyMarshal_ReadObjectFromString" 
  dynlib: libraryString.}

#Parsing arguments and building values
proc argParseTuple*(args: PyObjectPtr; format: cstring): cint {.varargs, cdecl, 
  importc: "PyArg_ParseTuple" dynlib: libraryString.}
proc argVaParse*(args: PyObjectPtr; format: cstring; vargs: varargs): cint {.
  cdecl, importc: "PyArg_VaParse" dynlib: libraryString.}
proc argParseTupleAndKeywords*(args: PyObjectPtr; kw: PyObjectPtr; 
  format: cstring; keywords: ptr cstring): cint {.varargs, cdecl, 
  importc: "PyArg_ParseTupleAndKeywords" dynlib: libraryString.}
proc argVaParseTupleAndKeywords*(args: PyObjectPtr; kw: PyObjectPtr; 
  format: cstring; keywords: ptr cstring; vargs: varargs): cint {.cdecl, 
  importc: "PyArg_VaParseTupleAndKeywords" dynlib: libraryString.}
proc argValidateKeywordArguments*(arg: PyObjectPtr): cint {.cdecl, 
  importc: "PyArg_ValidateKeywordArguments" dynlib: libraryString.}
proc argParse*(args: PyObjectPtr; format: cstring): cint {.varargs, cdecl, 
  importc: "PyArg_Parse" dynlib: libraryString.}
proc argUnpackTuple*(args: PyObjectPtr; name: cstring; min: PySizeT; 
  max: PySizeT): cint {.varargs, cdecl, importc: "PyArg_UnpackTuple" 
  dynlib: libraryString.}
proc buildValue*(format: cstring): PyObjectPtr {.varargs, cdecl, 
  importc: "Py_BuildValue" dynlib: libraryString.}
proc vaBuildValue*(format: cstring; vargs: varargs): PyObjectPtr {.cdecl, 
  importc: "Py_VaBuildValue" dynlib: libraryString.}

#String conversion and formatting
proc osSnprintf*(str: cstring; size: csize; format: cstring): cint {.varargs, 
  cdecl, importc: "PyOS_snprintf" dynlib: libraryString.}
proc osVsnprintf*(str: cstring; size: csize; format: cstring; 
  va: varargs): cint {.cdecl, importc: "PyOS_vsnprintf" dynlib: libraryString.}
proc osStringToDouble*(s: cstring; endptr: cstringArray; 
  overflow_exception: PyObjectPtr): cdouble {.cdecl, 
  importc: "PyOS_string_to_double" dynlib: libraryString.}
proc osDoubleToString*(val: cdouble; format_code: char; precision: cint; 
  flags: cint; ptype: ptr cint): cstring {.cdecl, 
  importc: "PyOS_double_to_string" dynlib: libraryString.}
proc osStricmp*(s1: cstring; s2: cstring): cint {.cdecl, 
  importc: "PyOS_stricmp" dynlib: libraryString.}
proc osStrnicmp*(s1: cstring; s2: cstring; size: PySizeT): cint {.cdecl, 
  importc: "PyOS_strnicmp" dynlib: libraryString.}

#Reflection
proc evalGetBuiltins*(): PyObjectPtr {.cdecl, importc: "PyEval_GetBuiltins" 
  dynlib: libraryString.}
proc evalGetLocals*(): PyObjectPtr {.cdecl, importc: "PyEval_GetLocals" 
  dynlib: libraryString.}
proc evalGetGlobals*(): PyObjectPtr {.cdecl, importc: "PyEval_GetGlobals" 
  dynlib: libraryString.}
proc evalGetFrame*(): PyFrameObjectPtr {.cdecl, importc: "PyEval_GetFrame" 
  dynlib: libraryString.}
proc frameGetLineNumber*(frame: PyFrameObjectPtr): cint {.cdecl, 
  importc: "PyFrame_GetLineNumber" dynlib: libraryString.}
proc evalGetFuncName*(fun: PyObjectPtr): cstring {.cdecl, 
  importc: "PyEval_GetFuncName" dynlib: libraryString.}
proc evalGetFuncDesc*(fun: PyObjectPtr): cstring {.cdecl, 
  importc: "PyEval_GetFuncDesc" dynlib: libraryString.}

#Codec registry and support functions
proc codecRegister*(search_function: PyObjectPtr): cint {.cdecl, importc: "PyCodec_Register" 
  dynlib: libraryString.}
proc codecKnownEncoding*(encoding: cstring): cint {.cdecl, 
  importc: "PyCodec_KnownEncoding" dynlib: libraryString.}
proc codecEncode*(obj: PyObjectPtr; encoding: cstring;
  errors: cstring): PyObjectPtr {.cdecl, importc: "PyCodec_Encode" 
  dynlib: libraryString.}
proc codecDecode*(obj: PyObjectPtr; encoding: cstring;
  errors: cstring): PyObjectPtr {.cdecl, importc: "PyCodec_Decode" 
  dynlib: libraryString.}
proc codecEncoder*(encoding: cstring): PyObjectPtr {.cdecl, 
  importc: "PyCodec_Encoder" dynlib: libraryString.}
proc codecIncrementalEncoder*(encoding: cstring; errors: cstring): PyObjectPtr {.
  cdecl, importc: "PyCodec_IncrementalEncoder" dynlib: libraryString.}
proc codecIncrementalDecoder*(encoding: cstring; errors: cstring): PyObjectPtr {.
  cdecl, importc: "PyCodec_IncrementalDecoder" dynlib: libraryString.}
proc codecStreamReader*(encoding: cstring; stream: PyObjectPtr;
  errors: cstring): PyObjectPtr {.cdecl, importc: "PyCodec_StreamReader" 
  dynlib: libraryString.}
proc codecStreamWriter*(encoding: cstring; stream: PyObjectPtr;
  errors: cstring): PyObjectPtr {.cdecl, importc: "PyCodec_StreamWriter" 
  dynlib: libraryString.}
proc codecRegisterError*(name: cstring; error: PyObjectPtr): cint {.cdecl, 
  importc: "PyCodec_RegisterError" dynlib: libraryString.}
proc codecLookupError*(name: cstring): PyObjectPtr {.cdecl, 
  importc: "PyCodec_LookupError" dynlib: libraryString.}
proc codecStrictErrors*(exc: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyCodec_StrictErrors" dynlib: libraryString.}
proc codecIgnoreErrors*(exc: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyCodec_IgnoreErrors" dynlib: libraryString.}
proc codecReplaceErrors*(exc: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyCodec_ReplaceErrors" dynlib: libraryString.}
proc codecXMLCharRefReplaceErrors*(exc: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyCodec_XMLCharRefReplaceErrors" dynlib: libraryString.}
proc codecBackslashReplaceErrors*(exc: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyCodec_BackslashReplaceErrors" dynlib: libraryString.}

#Object Protocol
var notImplemented*: PyObjectPtr = cast[PyObjectPtr](dynlib.symAddr(libraryHandle, "Py_NotImplemented"))

proc objectPrint*(o: PyObjectPtr; fp: File; flags: cint): cint {.cdecl, 
  importc: "PyObject_Print" dynlib: libraryString.}
proc objectHasAttr*(o: PyObjectPtr; attr_name: PyObjectPtr): cint {.cdecl, 
  importc: "PyObject_HasAttr" dynlib: libraryString.}
proc objectHasAttrString*(o: PyObjectPtr; attr_name: cstring): cint {.cdecl, 
  importc: "PyObject_HasAttrString" dynlib: libraryString.}
proc objectGetAttr*(o: PyObjectPtr; attr_name: PyObjectPtr): PyObjectPtr {.
  cdecl, importc: "PyObject_GetAttr" dynlib: libraryString.}
proc objectGetAttrString*(o: PyObjectPtr; attr_name: cstring): PyObjectPtr {.
  cdecl, importc: "PyObject_GetAttrString" dynlib: libraryString.}
proc objectGenericGetAttr*(o: PyObjectPtr; name: PyObjectPtr): PyObjectPtr {.
  cdecl, importc: "PyObject_GenericGetAttr" dynlib: libraryString.}
proc objectSetAttr*(o: PyObjectPtr; attr_name: PyObjectPtr;
  v: PyObjectPtr): cint {.cdecl, importc: "PyObject_SetAttr" 
  dynlib: libraryString.}
proc objectSetAttrString*(o: PyObjectPtr; attr_name: cstring;
  v: PyObjectPtr): cint {.cdecl, importc: "PyObject_SetAttrString" 
  dynlib: libraryString.}
proc objectGenericSetAttr*(o: PyObjectPtr; name: PyObjectPtr;
  value: PyObjectPtr): cint {.cdecl, importc: "PyObject_GenericSetAttr" 
  dynlib: libraryString.}
proc objectDelAttr*(o: PyObjectPtr; attr_name: PyObjectPtr): cint {.cdecl, 
  importc: "PyObject_DelAttr" dynlib: libraryString.}
proc objectDelAttrString*(o: PyObjectPtr; attr_name: cstring): cint {.cdecl, 
  importc: "PyObject_DelAttrString" dynlib: libraryString.}
proc objectGenericGetDict*(o: PyObjectPtr; context: pointer): PyObjectPtr {.
  cdecl, importc: "PyObject_GenericGetDict" dynlib: libraryString.}
proc objectGenericSetDict*(o: PyObjectPtr; context: pointer): cint {.cdecl, 
  importc: "PyObject_GenericSetDict" dynlib: libraryString.}
proc objectRichCompare*(o1: PyObjectPtr; o2: PyObjectPtr;
  opid: cint): PyObjectPtr {.cdecl, importc: "PyObject_RichCompare" 
  dynlib: libraryString.}
proc objectRichCompareBool*(o1: PyObjectPtr; o2: PyObjectPtr; opid: cint): cint {.
  cdecl, importc: "PyObject_RichCompareBool" dynlib: libraryString.}
proc objectRepr*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc: "PyObject_Repr" 
  dynlib: libraryString.}
proc objectASCII*(o: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyObject_ASCII" dynlib: libraryString.}
proc objectStr*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc: "PyObject_Str" 
  dynlib: libraryString.}
proc objectBytes*(o: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyObject_Bytes" dynlib: libraryString.}
proc objectIsSubclass*(derived: PyObjectPtr; cls: PyObjectPtr): cint {.cdecl, 
  importc: "PyObject_IsSubclass" dynlib: libraryString.}
proc objectIsInstance*(inst: PyObjectPtr; cls: PyObjectPtr): cint {.cdecl, 
  importc: "PyObject_IsInstance" dynlib: libraryString.}
proc callableCheck*(o: PyObjectPtr): cint {.cdecl, importc: "PyCallable_Check" 
  dynlib: libraryString.}
proc objectCall*(callable_object: PyObjectPtr; args: PyObjectPtr;
   kw: PyObjectPtr): PyObjectPtr {.cdecl, importc: "PyObject_Call" 
   dynlib: libraryString.}
proc objectCallObject*(callable_object: PyObjectPtr;
  args: PyObjectPtr): PyObjectPtr {.cdecl, importc: "PyObject_CallObject" 
  dynlib: libraryString.}
proc objectCallFunction*(callable: PyObjectPtr; format: cstring): PyObjectPtr {.
  varargs, cdecl, importc: "PyObject_CallFunction" dynlib: libraryString.}
proc objectCallMethod*(o: PyObjectPtr; meth: cstring;
  format: cstring): PyObjectPtr {.varargs, cdecl, importc: "PyObject_CallMethod" 
  dynlib: libraryString.}
proc objectCallFunctionObjArgs*(callable: PyObjectPtr): PyObjectPtr {.varargs, 
  cdecl, importc: "PyObject_CallFunctionObjArgs" dynlib: libraryString.} 
  #Last paramater HAS to be NULL
proc objectCallMethodObjArgs*(o: PyObjectPtr; name: PyObjectPtr): PyObjectPtr {.
  varargs, cdecl, importc: "PyObject_CallMethodObjArgs" dynlib: libraryString.} 
  #Last paramater HAS to be NULL
proc objectHash*(o: PyObjectPtr): PyHashT {.cdecl, importc: "PyObject_Hash" 
  dynlib: libraryString.}
proc objectHashNotImplemented*(o: PyObjectPtr): PyHashT {.cdecl, 
  importc: "PyObject_HashNotImplemented" dynlib: libraryString.}
proc objectIsTrue*(o: PyObjectPtr): cint {.cdecl, importc: "PyObject_IsTrue" 
  dynlib: libraryString.}
proc objectNot*(o: PyObjectPtr): cint {.cdecl, importc: "PyObject_Not" 
  dynlib: libraryString.}
proc objectType*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc: "PyObject_Type" 
  dynlib: libraryString.}
template objectTypeCheck*(ob, tp) = 
  (pyType(ob) == tp or typeIsSubtype(pyType(ob), (tp)) == 1)
proc objectLength*(o: PyObjectPtr): PySizeT {.cdecl, importc: "PyObject_Length" 
  dynlib: libraryString.}
proc objectSize*(o: PyObjectPtr): PySizeT {.cdecl, importc: "PyObject_Size" 
  dynlib: libraryString.}
proc objectLengthHint*(o: PyObjectPtr; default: PySizeT): PySizeT {.cdecl, 
  importc: "PyObject_LengthHint" dynlib: libraryString.}
proc objectGetItem*(o: PyObjectPtr; key: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyObject_GetItem" dynlib: libraryString.}
proc objectSetItem*(o: PyObjectPtr; key: PyObjectPtr; v: PyObjectPtr): cint {.
  cdecl, importc: "PyObject_SetItem" dynlib: libraryString.}
proc objectDelItem*(o: PyObjectPtr; key: PyObjectPtr): cint {.cdecl, 
  importc: "PyObject_DelItem" dynlib: libraryString.}
proc objectDir*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc: "PyObject_Dir" 
  dynlib: libraryString.}
proc objectGetIter*(o: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyObject_GetIter" dynlib: libraryString.}

#Number Protocol
proc numberCheck*(o: PyObjectPtr): cint {.cdecl, importc: "PyNumber_Check" 
  dynlib: libraryString.}
proc numberAdd*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyNumber_Add" dynlib: libraryString.}
proc numberSubtract*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyNumber_Subtract" dynlib: libraryString.}
proc numberMultiply*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyNumber_Multiply" dynlib: libraryString.}
proc numberFloorDivide*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyNumber_FloorDivide" dynlib: libraryString.}
proc numberTrueDivide*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyNumber_TrueDivide" dynlib: libraryString.}
proc numberRemainder*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyNumber_Remainder" dynlib: libraryString.}
proc numberDivmod*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyNumber_Divmod" dynlib: libraryString.}
proc numberPower*(o1: PyObjectPtr; o2: PyObjectPtr;
  o3: PyObjectPtr): PyObjectPtr {.cdecl, importc: "PyNumber_Power" 
  dynlib: libraryString.}
proc numberNegative*(o: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyNumber_Negative" dynlib: libraryString.}
proc numberPositive*(o: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyNumber_Positive" dynlib: libraryString.}
proc numberAbsolute*(o: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyNumber_Absolute" dynlib: libraryString.}
proc numberInvert*(o: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyNumber_Invert" dynlib: libraryString.}
proc numberLshift*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyNumber_Lshift" dynlib: libraryString.}
proc numberRshift*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyNumber_Rshift" dynlib: libraryString.}
proc numberAnd*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyNumber_And" dynlib: libraryString.}
proc numberXor*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyNumber_Xor" dynlib: libraryString.}
proc numberOr*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyNumber_Or" dynlib: libraryString.}
proc numberInPlaceAdd*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyNumber_InPlaceAdd" dynlib: libraryString.}
proc numberInPlaceSubtract*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.
  cdecl, importc: "PyNumber_InPlaceSubtract" dynlib: libraryString.}
proc numberInPlaceMultiply*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.
  cdecl, importc: "PyNumber_InPlaceMultiply" dynlib: libraryString.}
proc numberInPlaceFloorDivide*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.
  cdecl, importc: "PyNumber_InPlaceFloorDivide" dynlib: libraryString.}
proc numberInPlaceTrueDivide*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.
  cdecl, importc: "PyNumber_InPlaceTrueDivide" dynlib: libraryString.}
proc numberInPlaceRemainder*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.
  cdecl, importc: "PyNumber_InPlaceRemainder" dynlib: libraryString.}
proc numberInPlacePower*(o1: PyObjectPtr; o2: PyObjectPtr;
  o3: PyObjectPtr): PyObjectPtr {.cdecl, importc: "PyNumber_InPlacePower" 
  dynlib: libraryString.}
proc numberInPlaceLshift*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.
  cdecl, importc: "PyNumber_InPlaceLshift" dynlib: libraryString.}
proc numberInPlaceRshift*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.
  cdecl, importc: "PyNumber_InPlaceRshift" dynlib: libraryString.}
proc numberInPlaceAnd*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyNumber_InPlaceAnd" dynlib: libraryString.}
proc numberInPlaceXor*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyNumber_InPlaceXor" dynlib: libraryString.}
proc numberInPlaceOr*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyNumber_InPlaceOr" dynlib: libraryString.}
proc numberLong*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc: "PyNumber_Long" 
  dynlib: libraryString.}
proc numberFloat*(o: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyNumber_Float" dynlib: libraryString.}
proc numberIndex*(o: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyNumber_Index" dynlib: libraryString.}
proc numberToBase*(n: PyObjectPtr; base: cint): PyObjectPtr {.cdecl, 
  importc: "PyNumber_ToBase" dynlib: libraryString.}
proc numberAsSsizeT*(o: PyObjectPtr; exc: PyObjectPtr): PySizeT {.cdecl, 
  importc: "PyNumber_AsSsize_t" dynlib: libraryString.}
proc indexCheck*(o: PyObjectPtr): cint {.cdecl, importc: "PyIndex_Check" 
  dynlib: libraryString.}

#Sequence Protocol
proc sequenceCheck*(o: PyObjectPtr): cint {.cdecl, importc: "PySequence_Check" 
  dynlib: libraryString.}
proc sequenceSize*(o: PyObjectPtr): PySizeT {.cdecl, importc: "PySequence_Size" 
  dynlib: libraryString.}
proc sequenceLength*(o: PyObjectPtr): PySizeT {.cdecl, 
  importc: "PySequence_Length" dynlib: libraryString.}
proc sequenceConcat*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PySequence_Concat" dynlib: libraryString.}
proc sequenceRepeat*(o: PyObjectPtr; count: PySizeT): PyObjectPtr {.cdecl, 
  importc: "PySequence_Repeat" dynlib: libraryString.}
proc sequenceInPlaceConcat*(o1: PyObjectPtr; o2: PyObjectPtr): PyObjectPtr {.
  cdecl, importc: "PySequence_InPlaceConcat" dynlib: libraryString.}
proc sequenceInPlaceRepeat*(o: PyObjectPtr; count: PySizeT): PyObjectPtr {.
  cdecl, importc: "PySequence_InPlaceRepeat" dynlib: libraryString.}
proc sequenceGetItem*(o: PyObjectPtr; i: PySizeT): PyObjectPtr {.cdecl, 
  importc: "PySequence_GetItem" dynlib: libraryString.}
proc sequenceGetSlice*(o: PyObjectPtr; i1: PySizeT; i2: PySizeT): PyObjectPtr {.
  cdecl, importc: "PySequence_GetSlice" dynlib: libraryString.}
proc sequenceSetItem*(o: PyObjectPtr; i: PySizeT; v: PyObjectPtr): cint {.cdecl, 
  importc: "PySequence_SetItem" dynlib: libraryString.}
proc sequenceDelItem*(o: PyObjectPtr; i: PySizeT): cint {.cdecl, 
  importc: "PySequence_DelItem" dynlib: libraryString.}
proc sequenceSetSlice*(o: PyObjectPtr; i1: PySizeT; i2: PySizeT;
  v: PyObjectPtr): cint {.cdecl, importc: "PySequence_SetSlice" 
  dynlib: libraryString.}
proc sequenceDelSlice*(o: PyObjectPtr; i1: PySizeT; i2: PySizeT): cint {.cdecl, 
  importc: "PySequence_DelSlice" dynlib: libraryString.}
proc sequenceCount*(o: PyObjectPtr; value: PyObjectPtr): PySizeT {.cdecl, 
  importc: "PySequence_Count" dynlib: libraryString.}
proc sequenceContains*(o: PyObjectPtr; value: PyObjectPtr): cint {.cdecl, 
  importc: "PySequence_Contains" dynlib: libraryString.}
proc sequenceIndex*(o: PyObjectPtr; value: PyObjectPtr): PySizeT {.cdecl, 
  importc: "PySequence_Index" dynlib: libraryString.}
proc sequenceList*(o: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PySequence_List" dynlib: libraryString.}
proc sequenceTuple*(o: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PySequence_Tuple" dynlib: libraryString.}
proc sequenceFast*(o: PyObjectPtr; m: cstring): PyObjectPtr {.cdecl, 
  importc: "PySequence_Fast" dynlib: libraryString.}
proc sequenceFastGetItem*(o: PyObjectPtr; i: PySizeT): PyObjectPtr {.cdecl, 
  importc: "PySequence_Fast_GET_ITEM" dynlib: libraryString.}
proc sequenceFastItems*(o: PyObjectPtr): ptr PyObjectPtr {.cdecl, 
  importc: "PySequence_Fast_ITEMS" dynlib: libraryString.}
proc sequenceItem*(o: PyObjectPtr; i: PySizeT): PyObjectPtr {.cdecl, 
  importc: "PySequence_ITEM" dynlib: libraryString.}
proc sequenceFastGetSize*(o: PyObjectPtr): PySizeT {.cdecl, 
  importc: "PySequence_Fast_GET_SIZE" dynlib: libraryString.}

#Mapping Protocol
proc mappingCheck*(o: PyObjectPtr): cint {.cdecl, importc: "PyMapping_Check" 
  dynlib: libraryString.}
proc mappingSize*(o: PyObjectPtr): PySizeT {.cdecl, importc: "PyMapping_Size" 
  dynlib: libraryString.}
proc mappingLength*(o: PyObjectPtr): PySizeT {.cdecl, 
  importc: "PyMapping_Length" dynlib: libraryString.}
proc mappingDelItemString*(o: PyObjectPtr; key: cstring): cint {.cdecl, 
  importc: "PyMapping_DelItemString" dynlib: libraryString.}
proc mappingDelItem*(o: PyObjectPtr; key: PyObjectPtr): cint {.cdecl, 
  importc: "PyMapping_DelItem" dynlib: libraryString.}
proc mappingHasKeyString*(o: PyObjectPtr; key: cstring): cint {.cdecl, 
  importc: "PyMapping_HasKeyString" dynlib: libraryString.}
proc mappingHasKey*(o: PyObjectPtr; key: PyObjectPtr): cint {.cdecl, 
  importc: "PyMapping_HasKey" dynlib: libraryString.}
proc mappingKeys*(o: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyMapping_Keys" dynlib: libraryString.}
proc mappingValues*(o: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyMapping_Values" dynlib: libraryString.}
proc mappingItems*(o: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyMapping_Items" dynlib: libraryString.}
proc mappingGetItemString*(o: PyObjectPtr; key: cstring): PyObjectPtr {.cdecl, 
  importc: "PyMapping_GetItemString" dynlib: libraryString.}
proc mappingSetItemString*(o: PyObjectPtr; key: cstring; v: PyObjectPtr): cint {.
  cdecl, importc: "PyMapping_SetItemString" dynlib: libraryString.}

#Iterator Protocol
proc iterCheck*(o: PyObjectPtr): cint {.cdecl, importc: "PyIter_Check" 
  dynlib: libraryString.}
proc iterNext*(o: PyObjectPtr): PyObjectPtr {.cdecl, importc: "PyIter_Next" 
  dynlib: libraryString.}
proc objectCheckBuffer*(obj: PyObjectPtr): cint {.cdecl, 
  importc: "PyObject_CheckBuffer" dynlib: libraryString.}
proc objectGetBuffer*(exporter: PyObjectPtr; view: PyBufferPtr;
  flags: cint): cint {.cdecl, importc: "PyObject_GetBuffer" 
  dynlib: libraryString.}
proc bufferRelease*(view: PyBufferPtr) {.cdecl, importc: "PyBuffer_Release" 
  dynlib: libraryString.}
proc bufferSizeFromFormat*(arg: cstring): PySizeT {.cdecl, 
  importc: "PyBuffer_SizeFromFormat" dynlib: libraryString.}
proc bufferIsContiguous*(view: PyBufferPtr; order: char): cint {.cdecl, 
  importc: "PyBuffer_IsContiguous" dynlib: libraryString.}
proc bufferFillContiguousStrides*(ndim: cint; shape: PySizeTPtr;
  strides: PySizeTPtr; itemsize: PySizeT; order: char) {.cdecl, 
  importc: "PyBuffer_FillContiguousStrides" dynlib: libraryString.}
proc bufferFillInfo*(view: PyBufferPtr; exporter: PyObjectPtr; buf: pointer;
  len: PySizeT; readonly: cint; flags: cint): cint {.cdecl, 
  importc: "PyBuffer_FillInfo" dynlib: libraryString.}

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
  typeType*: PyTypeObject = cast[PyTypeObject](
             dynlib.symAddr(libraryHandle, "PyType_Type"))
  baseObjectType*: PyTypeObject = cast[PyTypeObject](
                   dynlib.symAddr(libraryHandle, "PyBaseObject_Type"))
  superType*: PyTypeObject = cast[PyTypeObject](
              dynlib.symAddr(libraryHandle, "PySuper_Type"))

proc typeCheck*(o: PyObjectPtr): cint {.cdecl, importc: "PyType_Check" 
  dynlib: libraryString.}
proc typeCheckExact*(o: PyObjectPtr): cint {.cdecl, 
  importc: "PyType_CheckExact" dynlib: libraryString.}
proc typeClearCache*(): cuint {.cdecl, importc: "PyType_ClearCache" 
  dynlib: libraryString.}
proc typeGetFlags*(typ: PyTypeObjectPtr): clong {.cdecl, 
  importc: "PyType_GetFlags" dynlib: libraryString.}
proc typeModified*(typ: PyTypeObjectPtr) {.cdecl, importc: "PyType_Modified" 
  dynlib: libraryString.}
proc typeHasFeature*(o: PyTypeObjectPtr; feature: cint): cint {.cdecl, 
  importc: "PyType_HasFeature" dynlib: libraryString.}
proc typeISGC*(o: PyTypeObjectPtr): cint {.cdecl, importc: "PyType_IS_GC" 
  dynlib: libraryString.}
proc typeIsSubtype*(a: PyTypeObjectPtr; b: PyTypeObjectPtr): cint {.cdecl, 
  importc: "PyType_IsSubtype" dynlib: libraryString.}
proc typeGenericAlloc*(typ: PyTypeObjectPtr; nitems: PySizeT): PyObjectPtr {.
  cdecl, importc: "PyType_GenericAlloc" dynlib: libraryString.}
proc typeGenericNew*(typ: PyTypeObjectPtr; args: PyObjectPtr;
  kwds: PyObjectPtr): PyObjectPtr {.cdecl, importc: "PyType_GenericNew" 
  dynlib: libraryString.}
proc typeReady*(typ: PyTypeObjectPtr): cint {.cdecl, importc: "PyType_Ready" 
  dynlib: libraryString.}
proc typeFromSpec*(spec: PyTypeSpecPtr): PyObjectPtr {.cdecl, 
  importc: "PyType_FromSpec" dynlib: libraryString.}
proc typeFromSpecWithBases*(spec: PyTypeSpecPtr;
  bases: PyObjectPtr): PyObjectPtr {.cdecl, importc: "PyType_FromSpecWithBases" 
  dynlib: libraryString.}
proc typeGetSlot*(typ: PyTypeObjectPtr; slot: cint): pointer {.cdecl, 
  importc: "PyType_GetSlot" dynlib: libraryString.}

#The None Object
var noneStruct*: PyObject = cast[PyObject](
                 dynlib.symAddr(libraryHandle, "_Py_NoneStruct"))

template none*() = addr(noneStruct)
template returnNone*() =
    incref(none())
    return none()

#Integer Objects
var PyLongType*: PyTypeObject = cast[PyTypeObject](
                  dynlib.symAddr(libraryHandle, "PyLong_Type"))
const Py_TPFLAGS_LONG_SUBCLASS = culong(1) shl 24

template typeHasFeature*(t, f) =
  ((uint32(t.tpFlags) and (f)) != 0)
template longCheck*(op) =
  typeHasFeature(pyType(op), Py_TPFLAGS_LONG_SUBCLASS)
template longCheckExact*(op) =
  (pyType(op) == addr(PyLongType))

proc longFromLong*(v: clong): PyObjectPtr {.cdecl, importc: "PyLong_FromLong" 
  dynlib: libraryString.}
proc longFromUnsignedLong*(v: culong): PyObjectPtr {.cdecl, 
  importc: "PyLong_FromUnsignedLong" dynlib: libraryString.}
proc longFromSsizeT*(v: PySizeT): PyObjectPtr {.cdecl, 
  importc: "PyLong_FromSsize_t" dynlib: libraryString.}
proc longFromSizeT*(v: csize): PyObjectPtr {.cdecl, 
  importc: "PyLong_FromSize_t" dynlib: libraryString.}
#PyObject* PyLong_FromLongLong(PY_LONG_LONG v);
#PyObject* PyLong_FromUnsignedLongLong(unsigned PY_LONG_LONG v);

proc longFromDouble*(v: cdouble): PyObjectPtr {.cdecl, 
  importc: "PyLong_FromDouble" dynlib: libraryString.}
proc longFromString*(str: cstring; pend: cstringArray; base: cint): PyObjectPtr {.
  cdecl, importc: "PyLong_FromString" dynlib: libraryString.}
proc longFromUnicode*(u: PyUnicodePtr; length: PySizeT;
  base: cint): PyObjectPtr {.cdecl, importc: "PyLong_FromUnicode" 
  dynlib: libraryString.}
proc longFromUnicodeObject*(u: PyObjectPtr; base: cint): PyObjectPtr {.cdecl, 
  importc: "PyLong_FromUnicodeObject" dynlib: libraryString.}
proc longFromVoidPtr*(p: pointer): PyObjectPtr {.cdecl, 
  importc: "PyLong_FromVoidPtr" dynlib: libraryString.}
proc longAsLong*(obj: PyObjectPtr): clong {.cdecl, importc: "PyLong_AsLong" 
  dynlib: libraryString.}
proc longAsLongAndOverflow*(obj: PyObjectPtr; overflow: ptr cint): clong {.
  cdecl, importc: "PyLong_AsLongAndOverflow" dynlib: libraryString.}
proc longAsLongLong*(obj: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyLong_AsLongLong" dynlib: libraryString.}
proc longAsLongLongAndOverflow*(obj: PyObjectPtr;
  overflow: ptr cint): PyObjectPtr {.cdecl, 
importc: "PyLong_AsLongLongAndOverflow" dynlib: libraryString.}
proc longAsSsizeT*(pylong: PyObjectPtr): PySizeT {.cdecl, 
  importc: "PyLong_AsSsize_t" dynlib: libraryString.}
proc longAsUnsignedLong*(pylong: PyObjectPtr): culong {.cdecl, 
  importc: "PyLong_AsUnsignedLong" dynlib: libraryString.}
proc longAsSizeT*(pylong: PyObjectPtr): csize {.cdecl, 
  importc: "PyLong_AsSize_t" dynlib: libraryString.}
proc longAsUnsignedLongLong*(pylong: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyLong_AsUnsignedLongLong" dynlib: libraryString.}

proc longAsUnsignedLongMask*(obj: PyObjectPtr): culong {.cdecl, 
  importc: "PyLong_AsUnsignedLongMask" dynlib: libraryString.}
proc longAsUnsignedLongLongMask*(obj: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyLong_AsUnsignedLongLongMask" dynlib: libraryString.}

proc longAsDouble*(pylong: PyObjectPtr): cdouble {.cdecl, 
  importc: "PyLong_AsDouble" dynlib: libraryString.}
proc longAsVoidPtr*(pylong: PyObjectPtr): pointer {.cdecl, 
  importc: "PyLong_AsVoidPtr" dynlib: libraryString.}

#Boolean Objects
var 
  pyFalse*: PyObjectPtr = cast[PyObjectPtr](
            dynlib.symAddr(libraryHandle, "Py_False"))
  pyTrue*: PyObjectPtr = cast[PyObjectPtr](
           dynlib.symAddr(libraryHandle, "Py_True"))

proc boolCheck*(o: PyObjectPtr): cint {.cdecl, importc: "PyBool_Check" 
  dynlib: libraryString.}
proc boolFromLong*(v: clong): PyObjectPtr {.cdecl, importc: "PyBool_FromLong" 
  dynlib: libraryString.}

#Floating Point Objects
var floatType*: PyTypeObject = cast[PyTypeObject](
                dynlib.symAddr(libraryHandle, "PyFloat_Type"))

proc floatCheck*(p: PyObjectPtr): cint {.cdecl, importc: "PyFloat_Check" 
  dynlib: libraryString.}
proc floatCheckExact*(p: PyObjectPtr): cint {.cdecl, 
  importc: "PyFloat_CheckExact" dynlib: libraryString.}
proc floatFromString*(str: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyFloat_FromString" dynlib: libraryString.}
proc floatFromDouble*(v: cdouble): PyObjectPtr {.cdecl, 
  importc: "PyFloat_FromDouble" dynlib: libraryString.}
proc floatAsDouble*(pyfloat: PyObjectPtr): cdouble {.cdecl, 
  importc: "PyFloat_AsDouble" dynlib: libraryString.}
#proc PyFloat_AS_DOUBLE*(pyfloat: PyObjectPtr): cdouble {.cdecl, importc, dynlib: libraryString.}
proc floatGetInfo*(): PyObjectPtr {.cdecl, importc: "PyFloat_GetInfo" 
  dynlib: libraryString.}
proc floatGetMax*(): cdouble {.cdecl, importc: "PyFloat_GetMax" 
  dynlib: libraryString.}
proc floatGetMin*(): cdouble {.cdecl, importc: "PyFloat_GetMin" 
  dynlib: libraryString.}
proc floatClearFreeList*(): cint {.cdecl, importc: "PyFloat_ClearFreeList" 
  dynlib: libraryString.}

#Complex Number Objects
type
  PyComplex* {.final.} = object 
    real*: float64
    imag*: float64

var complexType*: PyTypeObject = cast[PyTypeObject](
                  dynlib.symAddr(libraryHandle, "PyComplex_Type"))

proc cSum*(left: PyComplex; right: PyComplex): PyComplex {.cdecl, 
  importc: "_cSum", dynlib: libraryString.}
proc cDiff*(left: PyComplex; right: PyComplex): PyComplex {.cdecl, 
  importc: "_cDiff", dynlib: libraryString.}
proc cNeg*(complex: PyComplex): PyComplex {.cdecl, importc: "_cNeg", 
  dynlib: libraryString.}
proc cProd*(left: PyComplex; right: PyComplex): PyComplex {.cdecl, 
  importc: "_cProd", dynlib: libraryString.}
proc cQuot*(dividend: PyComplex; divisor: PyComplex): PyComplex {.cdecl, 
  importc: "_cQuot", dynlib: libraryString.}
proc cPow*(num: PyComplex; exp: PyComplex): PyComplex {.cdecl, 
  importc: "_cPow", dynlib: libraryString.}
proc complexCheck*(p: PyObjectPtr): cint {.cdecl, importc: "PyComplex_Check" 
  dynlib: libraryString.}
proc complexCheckExact*(p: PyObjectPtr): cint {.cdecl, 
  importc: "PyComplex_CheckExact" dynlib: libraryString.}
proc complexFromCComplex*(v: PyComplex): PyObjectPtr {.cdecl, 
  importc: "PyComplex_FromCComplex" dynlib: libraryString.}
proc complexFromDoubles*(real: cdouble; imag: cdouble): PyObjectPtr {.cdecl, 
  importc: "PyComplex_FromDoubles" dynlib: libraryString.}
proc complexRealAsDouble*(op: PyObjectPtr): cdouble {.cdecl, 
  importc: "PyComplex_RealAsDouble" dynlib: libraryString.}
proc complexImagAsDouble*(op: PyObjectPtr): cdouble {.cdecl, 
  importc: "PyComplex_ImagAsDouble" dynlib: libraryString.}
proc complexAsCComplex*(op: PyObjectPtr): PyComplex {.cdecl, 
  importc: "PyComplex_AsCComplex" dynlib: libraryString.}

#Bytes Objects
var bytesType*: PyTypeObject = cast[PyTypeObject](
                dynlib.symAddr(libraryHandle, "PyBytes_Type"))

proc bytesCheck*(o: PyObjectPtr): cint {.cdecl, importc: "PyBytes_Check" 
  dynlib: libraryString.}
proc bytesCheckExact*(o: PyObjectPtr): cint {.cdecl, 
  importc: "PyBytes_CheckExact" dynlib: libraryString.}
proc bytesFromString*(v: cstring): PyObjectPtr {.cdecl, 
  importc: "PyBytes_FromString" dynlib: libraryString.}
proc bytesFromStringAndSize*(v: cstring; len: PySizeT): PyObjectPtr {.cdecl, 
  importc: "PyBytes_FromStringAndSize" dynlib: libraryString.}
proc bytesFromFormat*(format: cstring): PyObjectPtr {.varargs, cdecl, 
  importc: "PyBytes_FromFormat" dynlib: libraryString.}
proc bytesFromFormatV*(format: cstring; vargs: varargs): PyObjectPtr {.cdecl, 
  importc: "PyBytes_FromFormatV" dynlib: libraryString.}
proc bytesFromObject*(o: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyBytes_FromObject" dynlib: libraryString.}
proc bytesSize*(o: PyObjectPtr): PySizeT {.cdecl, importc: "PyBytes_Size" 
  dynlib: libraryString.}
#proc PyBytes_GET_SIZE*(o: PyObjectPtr): PySizeT
proc bytesAsString*(o: PyObjectPtr): cstring {.cdecl, 
  importc: "PyBytes_AsString" dynlib: libraryString.}
#proc PyBytes_AS_STRING*(string: PyObjectPtr): cstring
proc bytesAsStringAndSize*(obj: PyObjectPtr; buffer: cstringArray;
  length: PySizeTPtr): cint {.cdecl, importc: "PyBytes_AsStringAndSize" 
  dynlib: libraryString.}
proc bytesConcat*(bytes: ptr PyObjectPtr; newpart: PyObjectPtr) {.cdecl, 
  importc: "PyBytes_Concat" dynlib: libraryString.}
proc bytesConcatAndDel*(bytes: ptr PyObjectPtr; newpart: PyObjectPtr) {.cdecl, 
  importc: "PyBytes_ConcatAndDel" dynlib: libraryString.}
proc bytesResize*(bytes: ptr PyObjectPtr; newsize: PySizeT): cint {.cdecl, 
  importc: "_bytesResize", dynlib: libraryString.}

#Byte Array Objects
var byteArrayType*: PyTypeObject = cast[PyTypeObject](
                    dynlib.symAddr(libraryHandle, "PyByteArray_Type"))

proc byteArrayCheck*(o: PyObjectPtr): cint {.cdecl, 
  importc: "PyByteArray_Check" dynlib: libraryString.}
proc byteArrayCheckExact*(o: PyObjectPtr): cint {.cdecl, 
  importc: "PyByteArray_CheckExact" dynlib: libraryString.}
proc byteArrayFromObject*(o: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyByteArray_FromObject" dynlib: libraryString.}
proc byteArrayFromStringAndSize*(string: cstring; length: PySizeT): PyObjectPtr {.
  cdecl, importc: "PyByteArray_FromStringAndSize" dynlib: libraryString.}
proc byteArrayConcat*(a: PyObjectPtr; b: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyByteArray_Concat" dynlib: libraryString.}
proc byteArraySize*(bytearray: PyObjectPtr): PySizeT {.cdecl, 
  importc: "PyByteArray_Size" dynlib: libraryString.}
proc byteArrayAsString*(bytearray: PyObjectPtr): cstring {.cdecl, 
  importc: "PyByteArray_AsString" dynlib: libraryString.}
proc byteArrayResize*(bytearray: PyObjectPtr; length: PySizeT): cint {.cdecl, 
  importc: "PyByteArray_Resize" dynlib: libraryString.}

#Unicode Objects and Codecs
type 
  PyUCS1* = cuchar
  PyUCS2* = cushort

when (sizeof(int) == 4) or (defined(posix) and sizeof(cuint) == 4):
  type
    PyUCS4* = cuint
elif sizeof(clong) == 4: 
  type 
    PyUCS4* = culong
type 
  UcsUnion* = object  {.union.}
    any*: pointer
    latin1*: ptr PyUCS1
    ucs2*: ptr PyUCS2
    ucs4*: ptr PyUCS4

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
    data*: UcsUnion # Canonical, smallest-form Unicode buffer 

var unicodeType*: PyTypeObject = cast[PyTypeObject](
                  dynlib.symAddr(libraryHandle, "PyUnicode_Type"))

#Unicode type
proc unicodeCheck*(o: PyObjectPtr): cint {.cdecl, importc: "PyUnicode_Check" 
  dynlib: libraryString.}
proc unicodeCheckExact*(o: PyObjectPtr): cint {.cdecl, 
  importc: "PyUnicode_CheckExact" dynlib: libraryString.}
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
proc unicodeClearFreeList*(): cint {.cdecl, importc: "PyUnicode_ClearFreeList" 
  dynlib: libraryString.}
#Creating and accessing Unicode strings
proc unicodeNew*(size: PySizeT; maxchar: Py_UCS4): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_New" dynlib: libraryString.}
proc unicodeFromKindAndData*(kind: cint; buffer: pointer;
  size: PySizeT): PyObjectPtr {.cdecl, importc: "PyUnicode_FromKindAndData" 
  dynlib: libraryString.}
proc unicodeFromStringAndSize*(u: cstring; size: PySizeT): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_FromStringAndSize" dynlib: libraryString.}
proc unicodeFromString*(u: cstring): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_FromString" dynlib: libraryString.}
proc unicodeFromFormat*(format: cstring): PyObjectPtr {.varargs, cdecl, 
  importc: "PyUnicode_FromFormat" dynlib: libraryString.}
proc unicodeFromFormatV*(format: cstring; vargs: varargs): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_FromFormatV" dynlib: libraryString.}
proc unicodeFromEncodedObject*(obj: PyObjectPtr; encoding: cstring;
  errors: cstring): PyObjectPtr {.cdecl, importc: "PyUnicode_FromEncodedObject" 
  dynlib: libraryString.}
proc unicodeGetLength*(unicode: PyObjectPtr): PySizeT {.cdecl, 
  importc: "PyUnicode_GetLength" dynlib: libraryString.}
proc unicodeCopyCharacters*(to: PyObjectPtr; to_start: PySizeT;
  fr: PyObjectPtr; from_start: PySizeT; how_many: PySizeT): cint {.cdecl, 
importc: "PyUnicode_CopyCharacters" dynlib: libraryString.}
proc unicodeFill*(unicode: PyObjectPtr; start: PySizeT; length: PySizeT;
  fill_char: Py_UCS4): PySizeT {.cdecl, importc: "PyUnicode_Fill" 
  dynlib: libraryString.}
proc unicodeWriteChar*(unicode: PyObjectPtr; index: PySizeT;
  character: Py_UCS4): cint {.cdecl, importc: "PyUnicode_WriteChar" 
  dynlib: libraryString.}
proc unicodeReadChar*(unicode: PyObjectPtr; index: PySizeT): Py_UCS4 {.cdecl, 
  importc: "PyUnicode_ReadChar" dynlib: libraryString.}
proc unicodeSubstring*(str: PyObjectPtr; start: PySizeT;
  `end`: PySizeT): PyObjectPtr {.cdecl, importc: "PyUnicode_Substring" 
  dynlib: libraryString.}
proc unicodeAsUCS4*(u: PyObjectPtr; buffer: ptr Py_UCS4; buflen: PySizeT;
  copy_null: cint): ptr Py_UCS4 {.cdecl, importc: "PyUnicode_AsUCS4" 
  dynlib: libraryString.}
proc unicodeAsUCS4Copy*(u: PyObjectPtr): ptr Py_UCS4 {.cdecl, 
  importc: "PyUnicode_AsUCS4Copy" dynlib: libraryString.}
#Locale Encoding
proc unicodeDecodeLocaleAndSize*(str: cstring; len: PySizeT;
  errors: cstring): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_DecodeLocaleAndSize" dynlib: libraryString.}
proc unicodeDecodeLocale*(str: cstring; errors: cstring): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_DecodeLocale" dynlib: libraryString.}
proc unicodeEncodeLocale*(unicode: PyObjectPtr; errors: cstring): PyObjectPtr {.
  cdecl, importc: "PyUnicode_EncodeLocale" dynlib: libraryString.}
#File System Encoding
proc unicodeFSConverter*(obj: PyObjectPtr; result: pointer): cint {.cdecl, 
  importc: "PyUnicode_FSConverter" dynlib: libraryString.}
proc unicodeFSDecoder*(obj: PyObjectPtr; result: pointer): cint {.cdecl, 
  importc: "PyUnicode_FSDecoder" dynlib: libraryString.}
proc unicodeDecodeFSDefaultAndSize*(s: cstring; size: PySizeT): PyObjectPtr {.
  cdecl, importc: "PyUnicode_DecodeFSDefaultAndSize" dynlib: libraryString.}
proc unicodeDecodeFSDefault*(s: cstring): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_DecodeFSDefault" dynlib: libraryString.}
proc unicodeEncodeFSDefault*(unicode: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_EncodeFSDefault" dynlib: libraryString.}
#wchar_t Support
proc unicodeFromWideChar*(w: PyUnicode; size: PySizeT): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_FromWideChar" dynlib: libraryString.}
proc unicodeAsWideChar*(unicode: ptr PyUnicodeObject; w: PyUnicode;
  size: PySizeT): PySizeT {.cdecl, importc: "PyUnicode_AsWideChar" 
  dynlib: libraryString.}
proc unicodeAsWideCharString*(unicode: PyObjectPtr;
  size: PySizeTPtr): PyUnicode {.cdecl, importc: "PyUnicode_AsWideCharString" 
  dynlib: libraryString.}
#UCS4 Support
proc ucs4Strlen*(u: ptr Py_UCS4): csize {.cdecl, importc: "Py_UCS4_strlen" 
  dynlib: libraryString.}
proc ucs4Strcpy*(s1: ptr Py_UCS4; s2: ptr Py_UCS4): ptr Py_UCS4 {.cdecl, 
  importc: "Py_UCS4_strcpy" dynlib: libraryString.}
proc ucs4Strncpy*(s1: ptr Py_UCS4; s2: ptr Py_UCS4; n: csize): ptr Py_UCS4 {.
  cdecl, importc: "Py_UCS4_strncpy" dynlib: libraryString.}
proc ucs4Strcat*(s1: ptr Py_UCS4; s2: ptr Py_UCS4): ptr Py_UCS4 {.cdecl, 
  importc: "Py_UCS4_strcat" dynlib: libraryString.}
proc ucs4Strcmp*(s1: ptr Py_UCS4; s2: ptr Py_UCS4): cint {.cdecl, 
  importc: "Py_UCS4_strcmp" dynlib: libraryString.}
proc ucs4Strncmp*(s1: ptr Py_UCS4; s2: ptr Py_UCS4; n: csize): cint {.cdecl, 
  importc: "Py_UCS4_strncmp" dynlib: libraryString.}
proc ucs4Strchr*(s: ptr Py_UCS4; c: Py_UCS4): ptr Py_UCS4 {.cdecl, 
  importc: "Py_UCS4_strchr" dynlib: libraryString.}
proc ucs4Strrchr*(s: ptr Py_UCS4; c: Py_UCS4): ptr Py_UCS4 {.cdecl, 
  importc: "Py_UCS4_strrchr" dynlib: libraryString.}
#Generic Codecs
proc unicodeDecode*(s: cstring; size: PySizeT; encoding: cstring;
  errors: cstring): PyObjectPtr {.cdecl, importc: "PyUnicode_Decode" 
  dynlib: libraryString.}
proc unicodeAsEncodedString*(unicode: PyObjectPtr; encoding: cstring;
  errors: cstring): PyObjectPtr {.cdecl, importc: "PyUnicode_AsEncodedString" 
  dynlib: libraryString.}
proc unicodeEncode*(s: PyUnicodePtr; size: PySizeT; encoding: cstring;
  errors: cstring): PyObjectPtr {.cdecl, importc: "PyUnicode_Encode" 
  dynlib: libraryString.}
#UTF-8 Codecs
proc unicodeDecodeUTF8*(s: cstring; size: PySizeT;
  errors: cstring): PyObjectPtr {.cdecl, importc: "PyUnicode_DecodeUTF8" 
  dynlib: libraryString.}
proc unicodeDecodeUTF8Stateful*(s: cstring; size: PySizeT; errors: cstring;
  consumed: PySizeTPtr): PyObjectPtr {.cdecl, 
importc: "PyUnicode_DecodeUTF8Stateful" dynlib: libraryString.}
proc unicodeAsUTF8String*(unicode: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_AsUTF8String" dynlib: libraryString.}
proc unicodeAsUTF8AndSize*(unicode: PyObjectPtr; size: PySizeTPtr): cstring {.
  cdecl, importc: "PyUnicode_AsUTF8AndSize" dynlib: libraryString.}
proc unicodeAsUTF8*(unicode: PyObjectPtr): cstring {.cdecl, 
  importc: "PyUnicode_AsUTF8" dynlib: libraryString.}
proc unicodeEncodeUTF8*(s: PyUnicodePtr; size: PySizeT;
  errors: cstring): PyObjectPtr {.cdecl, importc: "PyUnicode_EncodeUTF8" 
  dynlib: libraryString.}
#UTF-32 Codecs
proc unicodeDecodeUTF32*(s: cstring; size: PySizeT; errors: cstring;
  byteorder: ptr cint): PyObjectPtr {.cdecl, importc: "PyUnicode_DecodeUTF32" 
  dynlib: libraryString.}
proc unicodeDecodeUTF32Stateful*(s: cstring; size: PySizeT; errors: cstring;
  byteorder: ptr cint; consumed: PySizeTPtr): PyObjectPtr {.cdecl, 
importc: "PyUnicode_DecodeUTF32Stateful" dynlib: libraryString.}
proc unicodeAsUTF32String*(unicode: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_AsUTF32String" dynlib: libraryString.}
proc unicodeEncodeUTF32*(s: PyUnicodePtr; size: PySizeT; errors: cstring;
  byteorder: cint): PyObjectPtr {.cdecl, importc: "PyUnicode_EncodeUTF32" 
  dynlib: libraryString.}
#UTF-16 Codecs
proc unicodeDecodeUTF16*(s: cstring; size: PySizeT; errors: cstring;
  byteorder: ptr cint): PyObjectPtr {.cdecl, importc: "PyUnicode_DecodeUTF16" 
  dynlib: libraryString.}
proc unicodeDecodeUTF16Stateful*(s: cstring; size: PySizeT; errors: cstring;
  byteorder: ptr cint; consumed: PySizeTPtr): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_DecodeUTF16Stateful" dynlib: libraryString.}
proc unicodeAsUTF16String*(unicode: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_AsUTF16String" dynlib: libraryString.}
proc unicodeEncodeUTF16*(s: PyUnicodePtr; size: PySizeT; errors: cstring;
  byteorder: cint): PyObjectPtr {.cdecl, importc: "PyUnicode_EncodeUTF16" 
  dynlib: libraryString.}
#UTF-7 Codecs
proc unicodeDecodeUTF7*(s: cstring; size: PySizeT;
  errors: cstring): PyObjectPtr {.cdecl, importc: "PyUnicode_DecodeUTF7" 
  dynlib: libraryString.}
proc unicodeDecodeUTF7Stateful*(s: cstring; size: PySizeT; errors: cstring;
  consumed: PySizeTPtr): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_DecodeUTF7Stateful" dynlib: libraryString.}
proc unicodeEncodeUTF7*(s: PyUnicodePtr; size: PySizeT; base64SetO: cint;
  base64WhiteSpace: cint; errors: cstring): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_EncodeUTF7" dynlib: libraryString.}
#Unicode-Escape Codecs
proc unicodeDecodeUnicodeEscape*(s: cstring; size: PySizeT;
  errors: cstring): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_DecodeUnicodeEscape" dynlib: libraryString.}
proc unicodeAsUnicodeEscapeString*(unicode: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_AsUnicodeEscapeString" dynlib: libraryString.}
proc unicodeEncodeUnicodeEscape*(s: PyUnicodePtr; size: PySizeT): PyObjectPtr {.
  cdecl, importc: "PyUnicode_EncodeUnicodeEscape" dynlib: libraryString.}
#Raw-Unicode-Escape Codecs
proc unicodeDecodeRawUnicodeEscape*(s: cstring; size: PySizeT;
  errors: cstring): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_DecodeRawUnicodeEscape" dynlib: libraryString.}
proc unicodeAsRawUnicodeEscapeString*(unicode: PyObjectPtr): PyObjectPtr {.
  cdecl, importc: "PyUnicode_AsRawUnicodeEscapeString" dynlib: libraryString.}
proc unicodeEncodeRawUnicodeEscape*(s: PyUnicodePtr; size: 
  PySizeT; errors: cstring): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_EncodeRawUnicodeEscape" dynlib: libraryString.}
#Latin-1 Codecs
proc unicodeDecodeLatin1*(s: cstring; size: PySizeT; 
  errors: cstring): PyObjectPtr {.cdecl, importc: "PyUnicode_DecodeLatin1" 
  dynlib: libraryString.}
proc unicodeAsLatin1String*(unicode: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_AsLatin1String" dynlib: libraryString.}
proc unicodeEncodeLatin1*(s: PyUnicodePtr; size: PySizeT; 
  errors: cstring): PyObjectPtr {.cdecl, importc: "PyUnicode_EncodeLatin1" 
  dynlib: libraryString.}
#ASCII Codecs
proc unicodeDecodeASCII*(s: cstring; size: PySizeT;
  errors: cstring): PyObjectPtr {.cdecl, importc: "PyUnicode_DecodeASCII" 
  dynlib: libraryString.}
proc unicodeAsASCIIString*(unicode: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_AsASCIIString" dynlib: libraryString.}
proc unicodeEncodeASCII*(s: PyUnicodePtr; size: PySizeT;
  errors: cstring): PyObjectPtr {.cdecl, importc: "PyUnicode_EncodeASCII" 
  dynlib: libraryString.}
#Character Map Codecs
proc unicodeDecodeCharmap*(s: cstring; size: PySizeT; mapping: PyObjectPtr;
  errors: cstring): PyObjectPtr {.cdecl, importc: "PyUnicode_DecodeCharmap" 
  dynlib: libraryString.}
proc unicodeAsCharmapString*(unicode: PyObjectPtr;
  mapping: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_AsCharmapString" dynlib: libraryString.}
proc unicodeTranslateCharmap*(s: PyUnicodePtr; size: PySizeT;
  table: PyObjectPtr; errors: cstring): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_TranslateCharmap" dynlib: libraryString.}
proc unicodeEncodeCharmap*(s: PyUnicodePtr; size: PySizeT; mapping: PyObjectPtr;
  errors: cstring): PyObjectPtr {.cdecl, importc: "PyUnicode_EncodeCharmap" 
  dynlib: libraryString.}
#MBCS codecs for Windows
proc unicodeDecodeMBCS*(s: cstring; size: PySizeT;
  errors: cstring): PyObjectPtr {.cdecl, importc: "PyUnicode_DecodeMBCS" 
  dynlib: libraryString.}
proc unicodeDecodeMBCSStateful*(s: cstring; size: cint; errors: cstring;
  consumed: ptr cint): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_DecodeMBCSStateful" dynlib: libraryString.}
proc unicodeAsMBCSString*(unicode: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_AsMBCSString" dynlib: libraryString.}
proc unicodeEncodeCodePage*(code_page: cint; unicode: PyObjectPtr;
  errors: cstring): PyObjectPtr {.cdecl, importc: "PyUnicode_EncodeCodePage" 
  dynlib: libraryString.}
proc unicodeEncodeMBCS*(s: PyUnicodePtr; size: PySizeT;
  errors: cstring): PyObjectPtr {.cdecl, importc: "PyUnicode_EncodeMBCS" 
  dynlib: libraryString.}

#Methods & Slots
proc unicodeConcat*(left: PyObjectPtr; right: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_Concat" dynlib: libraryString.}
proc unicodeSplit*(s: PyObjectPtr; sep: PyObjectPtr;
  maxsplit: PySizeT): PyObjectPtr {.cdecl, importc: "PyUnicode_Split" 
  dynlib: libraryString.}
proc unicodeSplitlines*(s: PyObjectPtr; keepend: cint): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_Splitlines" dynlib: libraryString.}
proc unicodeTranslate*(str: PyObjectPtr; table: PyObjectPtr;
  errors: cstring): PyObjectPtr {.cdecl, importc: "PyUnicode_Translate" 
  dynlib: libraryString.}
proc unicodeJoin*(separator: PyObjectPtr; seq: PyObjectPtr): PyObjectPtr {.
  cdecl, importc: "PyUnicode_Join" dynlib: libraryString.}
proc unicodeTailmatch*(str: PyObjectPtr; substr: PyObjectPtr; start: PySizeT;
  `end`: PySizeT; direction: cint): PySizeT {.cdecl, 
  importc: "PyUnicode_Tailmatch" dynlib: libraryString.}
proc unicodeFind*(str: PyObjectPtr; substr: PyObjectPtr; start: PySizeT;
  `end`: PySizeT; direction: cint): PySizeT {.cdecl, importc: "PyUnicode_Find" 
  dynlib: libraryString.}
proc unicodeFindChar*(str: PyObjectPtr; ch: Py_UCS4; start: PySizeT;
  `end`: PySizeT; direction: cint): PySizeT {.cdecl, 
  importc: "PyUnicode_FindChar" dynlib: libraryString.}
proc unicodeCount*(str: PyObjectPtr; substr: PyObjectPtr; start: PySizeT;
  `end`: PySizeT): PySizeT {.cdecl, importc: "PyUnicode_Count" 
  dynlib: libraryString.}
proc unicodeReplace*(str: PyObjectPtr; substr: PyObjectPtr;
  replstr: PyObjectPtr; maxcount: PySizeT): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_Replace" dynlib: libraryString.}
proc unicodeCompare*(left: PyObjectPtr; right: PyObjectPtr): cint {.cdecl, 
  importc: "PyUnicode_Compare" dynlib: libraryString.}
proc unicodeCompareWithASCIIString*(uni: PyObjectPtr; string: cstring): cint {.
  cdecl, importc: "PyUnicode_CompareWithASCIIString" dynlib: libraryString.}
proc unicodeRichCompare*(left: PyObjectPtr; right: PyObjectPtr;
  op: cint): PyObjectPtr {.cdecl, importc: "PyUnicode_RichCompare" 
  dynlib: libraryString.}
proc unicodeFormat*(format: PyObjectPtr; args: PyObjectPtr): PyObjectPtr {.
  cdecl, importc: "PyUnicode_Format" dynlib: libraryString.}
proc unicodeContains*(container: PyObjectPtr; element: PyObjectPtr): cint {.
  cdecl, importc: "PyUnicode_Contains" dynlib: libraryString.}
proc unicodeInternInPlace*(string: ptr PyObjectPtr) {.cdecl, 
  importc: "PyUnicode_InternInPlace" dynlib: libraryString.}
proc unicodeInternFromString*(v: cstring): PyObjectPtr {.cdecl, 
  importc: "PyUnicode_InternFromString" dynlib: libraryString.}

#Tuple Objects
type
  PyTupleObjectPtr* = ptr PyTupleObject
  PyTupleObject* = object of PyObject
    obItem*: UncheckedArray[PyObjectPtr]

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
  tupleType*: PyTypeObject = cast[PyTypeObject](
              dynlib.symAddr(libraryHandle, "PyTuple_Type"))
  structSequenceUnnamedField*: cstring = cast[cstring](
                 dynlib.symAddr(libraryHandle, "PyStructSequence_UnnamedField"))

proc tupleCheck*(p: PyObjectPtr): cint {.cdecl, importc: "PyTuple_Check" 
  dynlib: libraryString.}
proc tupleCheckExact*(p: PyObjectPtr): cint {.cdecl, 
  importc: "PyTuple_CheckExact" dynlib: libraryString.}
proc tupleNew*(len: PySizeT): PyObjectPtr {.cdecl, importc: "PyTuple_New" 
  dynlib: libraryString.}
proc tuplePack*(n: PySizeT): PyObjectPtr {.varargs, cdecl, 
  importc: "PyTuple_Pack" dynlib: libraryString.}
proc tupleSize*(p: PyObjectPtr): PySizeT {.cdecl, importc: "PyTuple_Size" 
  dynlib: libraryString.}
proc tupleGETSIZE*(p: PyObjectPtr): PySizeT {.cdecl, 
  importc: "PyTuple_GET_SIZE" dynlib: libraryString.}
proc tupleGetItem*(p: PyObjectPtr; pos: PySizeT): PyObjectPtr {.cdecl, 
  importc: "PyTuple_GetItem" dynlib: libraryString.}
#proc PyTuple_GET_ITEM*(p: PyObjectPtr; pos: PySizeT): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc tupleGetSlice*(p: PyObjectPtr; low: PySizeT; high: PySizeT): PyObjectPtr {.
  cdecl, importc: "PyTuple_GetSlice" dynlib: libraryString.}
proc tupleSetItem*(p: PyObjectPtr; pos: PySizeT; o: PyObjectPtr): cint {.cdecl, 
  importc: "PyTuple_SetItem" dynlib: libraryString.}
template tupleSetItemNoErrorCheck*(p: PyObjectPtr; pos: PySizeT; o: PyObjectPtr) =
    (cast[PyTupleObjectPtr](p)).obItem[pos] = o
proc tupleResize*(p: ptr PyObjectPtr; newsize: PySizeT): cint {.cdecl, 
  importc: "_tupleResize", dynlib: libraryString.}
proc tupleClearFreeList*(): cint {.cdecl, importc: "PyTuple_ClearFreeList" 
  dynlib: libraryString.}
proc structSequenceNewType*(desc: PyStructSequenceDescPtr): PyTypeObjectPtr {.
  cdecl, importc: "PyStructSequence_NewType" dynlib: libraryString.}
proc structSequenceInitType*(typ: PyTypeObjectPtr;
  desc: PyStructSequenceDescPtr) {.cdecl, importc: "PyStructSequence_InitType" 
  dynlib: libraryString.}
proc structSequenceInitType2*(typ: PyTypeObjectPtr;
  desc: PyStructSequenceDescPtr): cint {.cdecl, 
  importc: "PyStructSequence_InitType2" dynlib: libraryString.}
proc structSequenceNew*(typ: PyTypeObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyStructSequence_New" dynlib: libraryString.}
proc structSequenceGetItem*(p: PyObjectPtr; pos: PySizeT): PyObjectPtr {.cdecl, 
  importc: "PyStructSequence_GetItem" dynlib: libraryString.}
proc structSequenceSetItem*(p: PyObjectPtr; pos: PySizeT; o: PyObjectPtr) {.
  cdecl, importc: "PyStructSequence_SetItem" dynlib: libraryString.}

#List Objects
var listType*: PyTypeObject = cast[PyTypeObject](
               dynlib.symAddr(libraryHandle, "PyList_Type"))

proc listCheck*(p: PyObjectPtr): cint {.cdecl, importc: "PyList_Check" 
  dynlib: libraryString.}
proc listCheckExact*(p: PyObjectPtr): cint {.cdecl, 
  importc: "PyList_CheckExact" dynlib: libraryString.}
proc listNew*(len: PySizeT): PyObjectPtr {.cdecl, importc: "PyList_New" 
  dynlib: libraryString.}
proc listSize*(list: PyObjectPtr): PySizeT {.cdecl, importc: "PyList_Size" 
  dynlib: libraryString.}
proc listGETSIZE*(list: PyObjectPtr): PySizeT {.cdecl, 
  importc: "PyList_GET_SIZE" dynlib: libraryString.}
proc listGetItem*(list: PyObjectPtr; index: PySizeT): PyObjectPtr {.cdecl, 
  importc: "PyList_GetItem" dynlib: libraryString.}
proc listGETITEM*(list: PyObjectPtr; i: PySizeT): PyObjectPtr {.cdecl, 
  importc: "PyList_GET_ITEM" dynlib: libraryString.}
proc listSetItem*(list: PyObjectPtr; index: PySizeT; item: PyObjectPtr): cint {.
  cdecl, importc: "PyList_SetItem" dynlib: libraryString.}
proc listSETITEM*(list: PyObjectPtr; i: PySizeT; o: PyObjectPtr) {.cdecl, 
  importc: "PyList_SET_ITEM" dynlib: libraryString.}
proc listInsert*(list: PyObjectPtr; index: PySizeT; item: PyObjectPtr): cint {.
  cdecl, importc: "PyList_Insert" dynlib: libraryString.}
proc listAppend*(list: PyObjectPtr; item: PyObjectPtr): cint {.cdecl, 
  importc: "PyList_Append" dynlib: libraryString.}
proc listGetSlice*(list: PyObjectPtr; low: PySizeT; high: PySizeT): PyObjectPtr {.
  cdecl, importc: "PyList_GetSlice" dynlib: libraryString.}
proc listSetSlice*(list: PyObjectPtr; low: PySizeT; high: PySizeT;
  itemlist: PyObjectPtr): cint {.cdecl, importc: "PyList_SetSlice" 
  dynlib: libraryString.}
proc listSort*(list: PyObjectPtr): cint {.cdecl, importc: "PyList_Sort" 
  dynlib: libraryString.}
proc listReverse*(list: PyObjectPtr): cint {.cdecl, importc: "PyList_Reverse" 
  dynlib: libraryString.}
proc listAsTuple*(list: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyList_AsTuple" dynlib: libraryString.}
proc listClearFreeList*(): cint {.cdecl, importc: "PyList_ClearFreeList" 
  dynlib: libraryString.}

#Dictionary Objects
var dictType*: PyTypeObject = cast[PyTypeObject](
               dynlib.symAddr(libraryHandle, "PyDict_Type"))

proc dictCheck*(p: PyObjectPtr): cint {.cdecl, importc: "PyDict_Check" 
  dynlib: libraryString.}
proc dictCheckExact*(p: PyObjectPtr): cint {.cdecl, 
  importc: "PyDict_CheckExact" dynlib: libraryString.}
proc dictNew*(): PyObjectPtr {.cdecl, importc: "PyDict_New" 
  dynlib: libraryString.}
proc dictProxyNew*(mapping: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyDictProxy_New" dynlib: libraryString.}
proc dictClear*(p: PyObjectPtr) {.cdecl, importc: "PyDict_Clear" 
  dynlib: libraryString.}
proc dictContains*(p: PyObjectPtr; key: PyObjectPtr): cint {.cdecl, 
  importc: "PyDict_Contains" dynlib: libraryString.}
proc dictCopy*(p: PyObjectPtr): PyObjectPtr {.cdecl, importc: "PyDict_Copy" 
  dynlib: libraryString.}
proc dictSetItem*(p: PyObjectPtr; key: PyObjectPtr; val: PyObjectPtr): cint {.
  cdecl, importc: "PyDict_SetItem" dynlib: libraryString.}
proc dictSetItemString*(p: PyObjectPtr; key: cstring; val: PyObjectPtr): cint {.
  cdecl, importc: "PyDict_SetItemString" dynlib: libraryString.}
proc dictDelItem*(p: PyObjectPtr; key: PyObjectPtr): cint {.cdecl, 
  importc: "PyDict_DelItem" dynlib: libraryString.}
proc dictDelItemString*(p: PyObjectPtr; key: cstring): cint {.cdecl, 
  importc: "PyDict_DelItemString" dynlib: libraryString.}
proc dictGetItem*(p: PyObjectPtr; key: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyDict_GetItem" dynlib: libraryString.}
proc dictGetItemWithError*(p: PyObjectPtr; key: PyObjectPtr): PyObjectPtr {.
  cdecl, importc: "PyDict_GetItemWithError" dynlib: libraryString.}
proc dictGetItemString*(p: PyObjectPtr; key: cstring): PyObjectPtr {.cdecl, 
  importc: "PyDict_GetItemString" dynlib: libraryString.}
proc dictSetDefault*(p: PyObjectPtr; key: PyObjectPtr;
  default: PyObjectPtr): PyObjectPtr {.cdecl, importc: "PyDict_SetDefault" 
  dynlib: libraryString.}
proc dictItems*(p: PyObjectPtr): PyObjectPtr {.cdecl, importc: "PyDict_Items" 
  dynlib: libraryString.}
proc dictKeys*(p: PyObjectPtr): PyObjectPtr {.cdecl, importc: "PyDict_Keys" 
  dynlib: libraryString.}
proc dictValues*(p: PyObjectPtr): PyObjectPtr {.cdecl, importc: "PyDict_Values" 
  dynlib: libraryString.}
proc dictSize*(p: PyObjectPtr): PySizeT {.cdecl, importc: "PyDict_Size" 
  dynlib: libraryString.}
proc dictNext*(p: PyObjectPtr; ppos: PySizeTPtr; pkey: ptr PyObjectPtr;
  pvalue: ptr PyObjectPtr): cint {.cdecl, importc: "PyDict_Next" 
  dynlib: libraryString.}
proc dictMerge*(a: PyObjectPtr; b: PyObjectPtr; override: cint): cint {.cdecl, 
  importc: "PyDict_Merge" dynlib: libraryString.}
proc dictUpdate*(a: PyObjectPtr; b: PyObjectPtr): cint {.cdecl, 
  importc: "PyDict_Update" dynlib: libraryString.}
proc dictMergeFromSeq2*(a: PyObjectPtr; seq2: PyObjectPtr;
  override: cint): cint {.cdecl, importc: "PyDict_MergeFromSeq2" 
  dynlib: libraryString.}
proc dictClearFreeList*(): cint {.cdecl, importc: "PyDict_ClearFreeList" 
  dynlib: libraryString.}

#Set Objects
var setType*: PyTypeObject = cast[PyTypeObject](
              dynlib.symAddr(libraryHandle, "PySet_Type"))

proc setCheck*(p: PyObjectPtr): cint {.cdecl, importc: "PySet_Check" 
  dynlib: libraryString.}
proc frozenSetCheck*(p: PyObjectPtr): cint {.cdecl, 
  importc: "PyFrozenSet_Check" dynlib: libraryString.}
proc anySetCheck*(p: PyObjectPtr): cint {.cdecl, importc: "PyAnySet_Check" 
  dynlib: libraryString.}
proc anySetCheckExact*(p: PyObjectPtr): cint {.cdecl, 
  importc: "PyAnySet_CheckExact" dynlib: libraryString.}
proc frozenSetCheckExact*(p: PyObjectPtr): cint {.cdecl, 
  importc: "PyFrozenSet_CheckExact" dynlib: libraryString.}
proc setNew*(iterable: PyObjectPtr): PyObjectPtr {.cdecl, importc: "PySet_New" 
  dynlib: libraryString.}
proc frozenSetNew*(iterable: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyFrozenSet_New" dynlib: libraryString.}
proc setSize*(anyset: PyObjectPtr): PySizeT {.cdecl, importc: "PySet_Size" 
  dynlib: libraryString.}
proc setGETSIZE*(anyset: PyObjectPtr): PySizeT {.cdecl, 
  importc: "PySet_GET_SIZE" dynlib: libraryString.}
proc setContains*(anyset: PyObjectPtr; key: PyObjectPtr): cint {.cdecl, 
  importc: "PySet_Contains" dynlib: libraryString.}
proc setAdd*(set: PyObjectPtr; key: PyObjectPtr): cint {.cdecl, 
  importc: "PySet_Add" dynlib: libraryString.}
proc setDiscard*(set: PyObjectPtr; key: PyObjectPtr): cint {.cdecl, 
  importc: "PySet_Discard" dynlib: libraryString.}
proc setPop*(set: PyObjectPtr): PyObjectPtr {.cdecl, importc: "PySet_Pop" 
  dynlib: libraryString.}
proc setClear*(set: PyObjectPtr): cint {.cdecl, importc: "PySet_Clear" 
  dynlib: libraryString.}
proc setClearFreeList*(): cint {.cdecl, importc: "PySet_ClearFreeList" 
  dynlib: libraryString.}

#Function Objects
var functionType*: PyTypeObject = cast[PyTypeObject](
                   dynlib.symAddr(libraryHandle, "PyFunction_Type"))

proc functionCheck*(o: PyObjectPtr): cint {.cdecl, importc: "PyFunction_Check" 
  dynlib: libraryString.}
proc functionNew*(code: PyObjectPtr; globals: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyFunction_New" dynlib: libraryString.}
proc functionNewWithQualName*(code: PyObjectPtr; globals: PyObjectPtr;
  qualname: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyFunction_NewWithQualName" dynlib: libraryString.}
proc functionGetCode*(op: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyFunction_GetCode" dynlib: libraryString.}
proc functionGetGlobals*(op: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyFunction_GetGlobals" dynlib: libraryString.}
proc functionGetModule*(op: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyFunction_GetModule" dynlib: libraryString.}
proc functionGetDefaults*(op: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyFunction_GetDefaults" dynlib: libraryString.}
proc functionSetDefaults*(op: PyObjectPtr; defaults: PyObjectPtr): cint {.cdecl, 
  importc: "PyFunction_SetDefaults" dynlib: libraryString.}
proc functionGetClosure*(op: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyFunction_GetClosure" dynlib: libraryString.}
proc functionSetClosure*(op: PyObjectPtr; closure: PyObjectPtr): cint {.cdecl, 
  importc: "PyFunction_SetClosure" dynlib: libraryString.}
proc functionGetAnnotations*(op: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyFunction_GetAnnotations" dynlib: libraryString.}
proc functionSetAnnotations*(op: PyObjectPtr; annotations: PyObjectPtr): cint {.
  cdecl, importc: "PyFunction_SetAnnotations" dynlib: libraryString.}

#Instance Method Objects
var instanceMethodType*: PyTypeObject = cast[PyTypeObject](
                         dynlib.symAddr(libraryHandle, "PyInstanceMethod_Type"))

proc instanceMethodCheck*(o: PyObjectPtr): cint {.cdecl, 
  importc: "PyInstanceMethod_Check" dynlib: libraryString.}
proc instanceMethodNew*(fun: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyInstanceMethod_New" dynlib: libraryString.}
proc instanceMethodFunction*(im: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyInstanceMethod_Function" dynlib: libraryString.}
proc instanceMethodGETFUNCTION*(im: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyInstanceMethod_GET_FUNCTION" dynlib: libraryString.}

#Method Objects
var methodType*: PyTypeObject = cast[PyTypeObject](
                 dynlib.symAddr(libraryHandle, "PyMethod_Type"))

proc methodCheck*(o: PyObjectPtr): cint {.cdecl, importc: "PyMethod_Check" 
  dynlib: libraryString.}
proc methodNew*(fun: PyObjectPtr; self: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyMethod_New" dynlib: libraryString.}
proc methodFunction*(meth: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyMethod_Function" dynlib: libraryString.}
proc methodGetFunction*(meth: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyMethod_GET_FUNCTION" dynlib: libraryString.}
proc methodSelf*(meth: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyMethod_Self" dynlib: libraryString.}
proc methodGetSelf*(meth: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyMethod_GET_SELF" dynlib: libraryString.}
proc methodClearFreeList*(): cint {.cdecl, importc: "PyMethod_ClearFreeList" 
  dynlib: libraryString.}

#Cell Objects
var cellType*: PyTypeObject = cast[PyTypeObject](
               dynlib.symAddr(libraryHandle, "PyCell_Type"))

proc cellCheck*(ob: pointer): cint {.cdecl, importc: "PyCell_Check" 
  dynlib: libraryString.}
proc cellNew*(ob: PyObjectPtr): PyObjectPtr {.cdecl, importc: "PyCell_New" 
  dynlib: libraryString.}
proc cellGet*(cell: PyObjectPtr): PyObjectPtr {.cdecl, importc: "PyCell_Get" 
  dynlib: libraryString.}
#proc PyCell_GET*(cell: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}
proc cellSet*(cell: PyObjectPtr; value: PyObjectPtr): cint {.cdecl, 
  importc: "PyCell_Set" dynlib: libraryString.}
#proc PyCell_SET*(cell: PyObjectPtr; value: PyObjectPtr) {.cdecl, importc, dynlib: libraryString.}

#Code Objects
var codeType*: PyTypeObject = cast[PyTypeObject](
               dynlib.symAddr(libraryHandle, "PyCode_Type"))

proc codeCheck*(co: PyObjectPtr): cint {.cdecl, importc: "PyCode_Check" 
  dynlib: libraryString.}
proc codeGetNumFree*(co: ptr PyCodeObject): cint {.cdecl, 
  importc: "PyCode_GetNumFree" dynlib: libraryString.}
proc codeNew*(argcount: cint; kwonlyargcount: cint; nlocals: cint;
  stacksize: cint; flags: cint; code: PyObjectPtr; consts: PyObjectPtr; names: PyObjectPtr; varnames: PyObjectPtr; freevars: PyObjectPtr; cellvars: PyObjectPtr; filename: PyObjectPtr; name: PyObjectPtr; firstlineno: cint; lnotab: PyObjectPtr): ptr PyCodeObject {.cdecl, 
  importc: "PyCode_New" dynlib: libraryString.}
proc codeNewEmpty*(filename: cstring; funcname: cstring;
  firstlineno: cint): ptr PyCodeObject {.cdecl, importc: "PyCode_NewEmpty" 
  dynlib: libraryString.}

#File Objects
proc objectAsFileDescriptor*(p: PyObjectPtr): cint {.cdecl, 
  importc: "PyObject_AsFileDescriptor" dynlib: libraryString.}
proc fileGetLine*(p: PyObjectPtr; n: cint): PyObjectPtr {.cdecl, 
  importc: "PyFile_GetLine" dynlib: libraryString.}
proc fileWriteObject*(obj: PyObjectPtr; p: PyObjectPtr; flags: cint): cint {.
  cdecl, importc: "PyFile_WriteObject" dynlib: libraryString.}
proc fileWriteString*(s: cstring; p: PyObjectPtr): cint {.cdecl, 
  importc: "PyFile_WriteString" dynlib: libraryString.}

#Module Objects
when PYTHON_VERSION >= 3.5:
 type
    PyModuleDefBasePtr* = ptr PyModuleDefBase
    PyModuleDefBase* = object 
      ob_base*: PyObject
      m_init*: proc (): PyObjectPtr {.cdecl.}
      m_index*: PySizeT
      m_copy*: PyObjectPtr
  
  
    PyModuleDefPtr* = ptr PyModuleDef
    PyModuleDef* {.final.}  = object
      m_base*: PyModuleDefBase
      m_name*: cstring
      m_doc*: cstring
      m_size*: PySizeT
      m_methods*: PyMethodDefPtr
      m_slots*: PyModuleDefSlotPtr
      m_traverse*: TraverseProc
      m_clear*: Inquiry
      m_free*: FreeFunc
    
    PyModuleDefSlotPtr* = ptr PyModuleDefSlot
    PyModuleDefSlot* = object
      slot*: cint
      value*: pointer
else:
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
    
var moduleType*: PyTypeObject = cast[PyTypeObject](
                 dynlib.symAddr(libraryHandle, "PyModule_Type"))

proc moduleCheck*(p: PyObjectPtr): cint {.cdecl, importc: "PyModule_Check" 
  dynlib: libraryString.}
proc moduleCheckExact*(p: PyObjectPtr): cint {.cdecl, 
  importc: "PyModule_CheckExact" dynlib: libraryString.}
proc moduleNewObject*(name: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyModule_NewObject" dynlib: libraryString.}
proc moduleNew*(name: cstring): PyObjectPtr {.cdecl, importc: "PyModule_New" 
  dynlib: libraryString.}
proc moduleGetDict*(module: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyModule_GetDict" dynlib: libraryString.}
proc moduleGetNameObject*(module: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyModule_GetNameObject" dynlib: libraryString.}
proc moduleGetName*(module: PyObjectPtr): cstring {.cdecl, 
  importc: "PyModule_GetName" dynlib: libraryString.}
proc moduleGetFilenameObject*(module: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyModule_GetFilenameObject" dynlib: libraryString.}
proc moduleGetFilename*(module: PyObjectPtr): cstring {.cdecl, 
  importc: "PyModule_GetFilename" dynlib: libraryString.}
proc moduleGetState*(module: PyObjectPtr): pointer {.cdecl, 
  importc: "PyModule_GetState" dynlib: libraryString.}
proc moduleGetDef*(module: PyObjectPtr): PyModuleDefPtr {.cdecl, 
  importc: "PyModule_GetDef" dynlib: libraryString.}
proc stateFindModule*(def: PyModuleDefPtr): PyObjectPtr {.cdecl, 
  importc: "PyState_FindModule" dynlib: libraryString.}
proc stateAddModule*(module: PyObjectPtr; def: PyModuleDefPtr): cint {.cdecl, 
  importc: "PyState_AddModule" dynlib: libraryString.}
proc stateRemoveModule*(def: PyModuleDefPtr): cint {.cdecl, 
  importc: "PyState_RemoveModule" dynlib: libraryString.}
proc moduleCreate2*(module: PyModuleDefPtr;
  module_api_version: cint): PyObjectPtr {.cdecl, importc: "PyModule_Create2" 
  dynlib: libraryString.}
proc moduleCreate*(module: PyModuleDefPtr): PyObjectPtr =
  result = moduleCreate2(module, PYTHON_API_VERSION)
proc moduleAddObject*(module: PyObjectPtr; name: cstring;
  value: PyObjectPtr): cint {.cdecl, importc: "PyModule_AddObject" 
  dynlib: libraryString.}
proc moduleAddIntConstant*(module: PyObjectPtr; name: cstring;
  value: clong): cint {.cdecl, importc: "PyModule_AddIntConstant" 
  dynlib: libraryString.}
proc moduleAddStringConstant*(module: PyObjectPtr; name: cstring;
  value: cstring): cint {.cdecl, importc: "PyModule_AddStringConstant" 
  dynlib: libraryString.}
#proc PyModule_AddIntMacro*(module: PyObjectPtr; a3: `macro`): cint {.cdecl, importc, dynlib: libraryString.}
#proc PyModule_AddStringMacro*(module: PyObjectPtr; a3: `macro`): cint {.cdecl, importc, dynlib: libraryString.}

#Iterator Objects
var
  seqIterType*: PyTypeObject = cast[PyTypeObject](
                dynlib.symAddr(libraryHandle, "PySeqIter_Type"))
  callIterType*: PyTypeObject = cast[PyTypeObject](
                 dynlib.symAddr(libraryHandle, "PyCallIter_Type"))

template refcnt*(ob) = cast[PyObjectPtr](ob).obRefcnt
template pyType*(ob) = cast[PyObjectPtr](ob).obType
template size*(ob) = cast[PyObjectPtr](ob).obSize
# #define PyCallIter_Check(op) (Py_TYPE(op) == &PyCallIter_Type)
template callIterCheck*(op) = Py_TYPE(op) == addr(callIterType)
# #define PySeqIter_Check(op) (Py_TYPE(op) == &PySeqIter_Type)
template seqIterCheck*(op) = Py_TYPE(op) == addr(seqIterType)
proc seqIterNew*(seq: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PySeqIter_New" dynlib: libraryString.}
proc callIterNew*(callable: PyObjectPtr; sentinel: PyObjectPtr): PyObjectPtr {.
  cdecl, importc: "PyCallIter_New" dynlib: libraryString.}

#Descriptor Objects
type 
  WrapperFunc* = proc (self: PyObjectPtr; args: PyObjectPtr; 
                       wrapped: pointer): PyObjectPtr {.cdecl.}
  WrapperBasePtr* = ptr WrapperBase
  WrapperBase* = object
    name*: cstring
    offset*: cint
    function*: pointer
    wrapper*: WrapperFunc
    doc*: cstring
    flags*: cint
    nameStrobj*: PyObjectPtr

var propertyType*: PyTypeObject = cast[PyTypeObject](
                   dynlib.symAddr(libraryHandle, "PyProperty_Type"))

proc descrNewGetSet*(typ: PyTypeObjectPtr; getset: PyGetSetDefPtr): PyObjectPtr {.
  cdecl, importc: "PyDescr_NewGetSet" dynlib: libraryString.}
proc descrNewMember*(typ: PyTypeObjectPtr; meth: PyMemberDefPtr): PyObjectPtr {.
  cdecl, importc: "PyDescr_NewMember" dynlib: libraryString.}
proc descrNewMethod*(typ: PyTypeObjectPtr; meth: PyMethodDefPtr): PyObjectPtr {.
  cdecl, importc: "PyDescr_NewMethod" dynlib: libraryString.}
proc descrNewWrapper*(typ: PyTypeObjectPtr; wrapper: WrapperBasePtr;
  wrapped: pointer): PyObjectPtr {.cdecl, importc: "PyDescr_NewWrapper" 
  dynlib: libraryString.}
proc descrNewClassMethod*(typ: PyTypeObjectPtr;
  meth: PyMethodDefPtr): PyObjectPtr {.cdecl, importc: "PyDescr_NewClassMethod" 
  dynlib: libraryString.}
proc descrIsData*(descr: PyObjectPtr): cint {.cdecl, importc: "PyDescr_IsData" 
  dynlib: libraryString.}
proc wrapperNew*(arg0: PyObjectPtr; arg1: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyWrapper_New" dynlib: libraryString.}

#Slice Objects
var sliceType*: PyTypeObject = cast[PyTypeObject](
                dynlib.symAddr(libraryHandle, "PySlice_Type"))

proc sliceCheck*(ob: PyObjectPtr): cint {.cdecl, importc: "PySlice_Check" 
  dynlib: libraryString.}
proc sliceNew*(start: PyObjectPtr; stop: PyObjectPtr;
  step: PyObjectPtr): PyObjectPtr {.cdecl, importc: "PySlice_New" 
  dynlib: libraryString.}
proc sliceGetIndices*(slice: PyObjectPtr; length: PySizeT; start: PySizeTPtr;
  stop: PySizeTPtr; step: PySizeTPtr): cint {.cdecl, 
  importc: "PySlice_GetIndices" dynlib: libraryString.}
proc sliceGetIndicesEx*(slice: PyObjectPtr; length: PySizeT; start: PySizeTPtr;
  stop: PySizeTPtr; step: PySizeTPtr; slicelength: PySizeTPtr): cint {.cdecl, 
  importc: "PySlice_GetIndicesEx" dynlib: libraryString.}

#MemoryView objects
proc memoryViewFromObject*(obj: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyMemoryView_FromObject" dynlib: libraryString.}
proc memoryViewFromMemory*(mem: cstring; size: PySizeT;
  flags: cint): PyObjectPtr {.cdecl, importc: "PyMemoryView_FromMemory" 
  dynlib: libraryString.}
proc memoryViewFromBuffer*(view: PyBufferPtr): PyObjectPtr {.cdecl, 
  importc: "PyMemoryView_FromBuffer" dynlib: libraryString.}
proc memoryViewGetContiguous*(obj: PyObjectPtr; buffertype: cint;
  order: char): PyObjectPtr {.cdecl, importc: "PyMemoryView_GetContiguous" 
  dynlib: libraryString.}
proc memoryViewCheck*(obj: PyObjectPtr): cint {.cdecl, 
  importc: "PyMemoryView_Check" dynlib: libraryString.}
#proc PyMemoryView_GET_BUFFER*(mview: PyObjectPtr): PyBufferPtr {.cdecl, importc, dynlib: libraryString.}
#proc PyMemoryView_GET_BASE*(mview: PyObjectPtr): PyBufferPtr {.cdecl, importc, dynlib: libraryString.}

#Weak Reference Objects
var
  weakrefRefType*: PyTypeObject = cast[PyTypeObject](
                   dynlib.symAddr(libraryHandle, "_PyWeakref_RefType"))
  weakrefProxyType*: PyTypeObject = cast[PyTypeObject](
                     dynlib.symAddr(libraryHandle, "_PyWeakref_ProxyType"))
  weakrefCallableProxyType*: PyTypeObject = cast[PyTypeObject](
                  dynlib.symAddr(libraryHandle, "_PyWeakref_CallableProxyType"))

# #define PyWeakref_CheckRef(op) PyObject_TypeCheck(op, &_PyWeakref_RefType)
template weakrefCheckRef*(op): cint = 
  PyObject_TypeCheck(op, addr(weakrefRefType))
# #define PyWeakref_CheckProxy(op) ((Py_TYPE(op) == &_PyWeakref_ProxyType) || (Py_TYPE(op) == &_PyWeakref_CallableProxyType))
template weakrefCheckProxy*(op): cint = 
  ((pyType(op) == addr(weakrefProxyType)) or 
   (pyType(op) == addr(weakrefCallableProxyType)))
# #define PyWeakref_Check(op) (PyWeakref_CheckRef(op) || PyWeakref_CheckProxy(op))
template weakrefCheck*(ob) = weakrefCheckRef(op) or weakrefCheckProxy(op)
proc weakrefNewRef*(ob: PyObjectPtr; callback: PyObjectPtr): PyObjectPtr {.
  cdecl, importc: "PyWeakref_NewRef" dynlib: libraryString.}
proc weakrefNewProxy*(ob: PyObjectPtr; callback: PyObjectPtr): PyObjectPtr {.
  cdecl, importc: "PyWeakref_NewProxy" dynlib: libraryString.}
proc weakrefGetObject*(rf: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyWeakref_GetObject" dynlib: libraryString.}
#proc PyWeakref_GET_OBJECT*(rf: PyObjectPtr): PyObjectPtr {.cdecl, importc, dynlib: libraryString.}

#Capsules
var capsuleType*: PyTypeObject = cast[PyTypeObject](
                  dynlib.symAddr(libraryHandle, "PyCapsule_Type"))

type 
  PyCapsuleDestructor* = proc (arg: PyObjectPtr) {.cdecl.}

proc capsuleCheckExact*(p: PyObjectPtr): cint {.cdecl, 
  importc: "PyCapsule_CheckExact" dynlib: libraryString.}
proc capsuleNew*(pointer: pointer; name: cstring;
  destructor: PyCapsuleDestructor): PyObjectPtr {.cdecl, 
  importc: "PyCapsule_New" dynlib: libraryString.}
proc capsuleGetPointer*(capsule: PyObjectPtr; name: cstring): pointer {.cdecl, 
  importc: "PyCapsule_GetPointer" dynlib: libraryString.}
proc capsuleGetDestructor*(capsule: PyObjectPtr): PyCapsuleDestructor {.cdecl, 
  importc: "PyCapsule_GetDestructor" dynlib: libraryString.}
proc capsuleGetContext*(capsule: PyObjectPtr): pointer {.cdecl, 
  importc: "PyCapsule_GetContext" dynlib: libraryString.}
proc capsuleGetName*(capsule: PyObjectPtr): cstring {.cdecl, 
  importc: "PyCapsule_GetName" dynlib: libraryString.}
proc capsuleImport*(name: cstring; no_block: cint): pointer {.cdecl, 
  importc: "PyCapsule_Import" dynlib: libraryString.}
proc capsuleIsValid*(capsule: PyObjectPtr; name: cstring): cint {.cdecl, 
  importc: "PyCapsule_IsValid" dynlib: libraryString.}
proc capsuleSetContext*(capsule: PyObjectPtr; context: pointer): cint {.cdecl, 
  importc: "PyCapsule_SetContext" dynlib: libraryString.}
proc capsuleSetDestructor*(capsule: PyObjectPtr;
  destructor: PyCapsuleDestructor): cint {.cdecl, 
  importc: "PyCapsule_SetDestructor" dynlib: libraryString.}
proc capsuleSetName*(capsule: PyObjectPtr; name: cstring): cint {.cdecl, 
  importc: "PyCapsule_SetName" dynlib: libraryString.}
proc capsuleSetPointer*(capsule: PyObjectPtr; pointer: pointer): cint {.cdecl, 
  importc: "PyCapsule_SetPointer" dynlib: libraryString.}

#Generator Objects
type 
  Frame* = object 
  PyGenObject* = object 
    obBase*: PyVarObject
    giFrame*: ptr Frame
    giRunning*: char
    giCode*: PyObjectPtr
    giWeakreflist*: PyObjectPtr

var genType*: PyTypeObject = cast[PyTypeObject](
              dynlib.symAddr(libraryHandle, "PyGen_Type"))

# #define PyGen_Check(op) PyObject_TypeCheck(op, &PyGen_Type)
template genCheck*(op): cint = objectTypeCheck(op, addr(genType))
# #define PyGen_CheckExact(op) (Py_TYPE(op) == &PyGen_Type)
template genCheckExact*(op): cint = pyType(op) == addr(genType)
proc genNew*(frame: PyFrameObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyGen_New" dynlib: libraryString.}

#DateTime Objects
const 
  datetimeDateDataSize* = 4 # number of bytes for year, month, and day. 
  datetimeTimeDataSize* = 6 # number of bytes for hour, minute, second, and usecond.
  datetimeDateTimeDataSize* = 10 # number of bytes for year, month, day, hour, minute, second, and usecond. 

type 
  PyDateTime_TimePtr* = ptr PyDateTime_Time
  PyDateTime_Time* = object
    # _PyDateTime_TIMEHEAD
    # _PyTZINFO_HEAD
    ob_base*: PyObject
    hashcode*: PyHashT
    hastzinfo*: int8
    # _PyTZINFO_HEAD
    data*: array[datetimeTimeDataSize, cuchar]
    # _PyDateTime_TIMEHEAD
    tzinfo*: PyObjectPtr
    
  PyDateTime_DatePtr* = ptr PyDateTime_Date
  PyDateTime_Date* = object
    # _PyTZINFO_HEAD
    obBase*: PyObject
    hashcode*: PyHashT
    hastzinfo*: int8
    # _PyTZINFO_HEAD
    data*: array[datetimeTimeDataSize, cuchar]
    
  PyDateTime_DateTimePtr* = ptr PyDateTime_DateTime
  PyDateTime_DateTime* = object
    # _PyDateTime_DATETIMEHEAD  
    # _PyTZINFO_HEAD
    obBase*: PyObject
    hashcode*: PyHashT
    hastzinfo*: int8
    # _PyTZINFO_HEAD
    data*: array[datetimeDateTimeDataSize, cuchar]
    # _PyDateTime_DATETIMEHEAD  
    tzinfo*: PyObjectPtr

  PyDateTimeDeltaPtr* = ptr PyDateTimeDelta
  PyDateTimeDelta* = object 
    # _PyTZINFO_HEAD
    obBase*: PyObject
    hashcode*: PyHashT
    hastzinfo*: int8
    # _PyTZINFO_HEAD
    days*: int                # -MAX_DELTA_DAYS <= days <= MAX_DELTA_DAYS 
    seconds*: int             # 0 <= seconds < 24*3600 is invariant 
    microseconds*: int        # 0 <= microseconds < 1000000 is invariant 
  

proc dateCheck*(ob: PyObjectPtr): cint {.cdecl, importc: "PyDate_Check" 
  dynlib: libraryString.}
proc dateCheckExact*(ob: PyObjectPtr): cint {.cdecl, 
  importc: "PyDate_CheckExact" dynlib: libraryString.}
proc dateTimeCheck*(ob: PyObjectPtr): cint {.cdecl, importc: "PyDateTime_Check" 
  dynlib: libraryString.}
proc dateTimeCheckExact*(ob: PyObjectPtr): cint {.cdecl, 
  importc: "PyDateTime_CheckExact" dynlib: libraryString.}
proc timeCheck*(ob: PyObjectPtr): cint {.cdecl, importc: "PyTime_Check" 
  dynlib: libraryString.}
proc timeCheckExact*(ob: PyObjectPtr): cint {.cdecl, 
  importc: "PyTime_CheckExact" dynlib: libraryString.}
proc deltaCheck*(ob: PyObjectPtr): cint {.cdecl, importc: "PyDelta_Check" 
  dynlib: libraryString.}
proc deltaCheckExact*(ob: PyObjectPtr): cint {.cdecl, 
  importc: "PyDelta_CheckExact" dynlib: libraryString.}
proc tzInfoCheck*(ob: PyObjectPtr): cint {.cdecl, importc: "PyTZInfo_Check" 
  dynlib: libraryString.}
proc tzInfoCheckExact*(ob: PyObjectPtr): cint {.cdecl, 
  importc: "PyTZInfo_CheckExact" dynlib: libraryString.}
proc dateFromDate*(year: cint; month: cint; day: cint): PyObjectPtr {.cdecl, 
  importc: "PyDate_FromDate" dynlib: libraryString.}
proc dateTimeFromDateAndTime*(year: cint; month: cint; day: cint; hour: cint;
  minute: cint; second: cint; usecond: cint): PyObjectPtr {.cdecl, 
  importc: "PyDateTime_FromDateAndTime" dynlib: libraryString.}
proc timeFromTime*(hour: cint; minute: cint; second: cint;
  usecond: cint): PyObjectPtr {.cdecl, importc: "PyTime_FromTime" 
  dynlib: libraryString.}
proc deltaFromDSU*(days: cint; seconds: cint; useconds: cint): PyObjectPtr {.
  cdecl, importc: "PyDelta_FromDSU" dynlib: libraryString.}
proc dateTimeGETYEAR*(o: PyDateTime_DatePtr): cint {.cdecl, 
  importc: "PyDateTime_GET_YEAR" dynlib: libraryString.}
proc dateTimeGETMONTH*(o: PyDateTime_DatePtr): cint {.cdecl, 
  importc: "PyDateTime_GET_MONTH" dynlib: libraryString.}
proc dateTimeGETDAY*(o: PyDateTime_DatePtr): cint {.cdecl, 
  importc: "PyDateTime_GET_DAY" dynlib: libraryString.}
proc dateTimeDATEGETHOUR*(o: PyDateTime_DateTimePtr): cint {.cdecl, 
  importc: "PyDateTime_DATE_GET_HOUR" dynlib: libraryString.}
proc dateTimeDATEGETMINUTE*(o: PyDateTime_DateTimePtr): cint {.cdecl, 
  importc: "PyDateTime_DATE_GET_MINUTE" dynlib: libraryString.}
proc dateTimeDATEGETSECOND*(o: PyDateTime_DateTimePtr): cint {.cdecl, 
  importc: "PyDateTime_DATE_GET_SECOND" dynlib: libraryString.}
proc dateTimeDATEGETMICROSECOND*(o: PyDateTime_DateTimePtr): cint {.cdecl, 
  importc: "PyDateTime_DATE_GET_MICROSECOND" dynlib: libraryString.}
proc dateTimeTIMEGETHOUR*(o: PyDateTime_TimePtr): cint {.cdecl, 
  importc: "PyDateTime_TIME_GET_HOUR" dynlib: libraryString.}
proc dateTimeTIMEGETMINUTE*(o: PyDateTime_TimePtr): cint {.cdecl, 
  importc: "PyDateTime_TIME_GET_MINUTE" dynlib: libraryString.}
proc dateTimeTIMEGETSECOND*(o: PyDateTime_TimePtr): cint {.cdecl, 
  importc: "PyDateTime_TIME_GET_SECOND" dynlib: libraryString.}
proc dateTimeTIMEGETMICROSECOND*(o: PyDateTime_TimePtr): cint {.cdecl, 
  importc: "PyDateTime_TIME_GET_MICROSECOND" dynlib: libraryString.}
proc dateTimeDeltaGETDAYS*(o: PyDateTimeDeltaPtr): cint {.cdecl, 
  importc: "PyDateTimeDelta_GET_DAYS" dynlib: libraryString.}
proc dateTimeDeltaGETSECONDS*(o: PyDateTimeDeltaPtr): cint {.cdecl, 
  importc: "PyDateTimeDelta_GET_SECONDS" dynlib: libraryString.}
proc dateTimeDeltaGETMICROSECOND*(o: PyDateTimeDeltaPtr): cint {.cdecl, 
  importc: "PyDateTimeDelta_GET_MICROSECOND" dynlib: libraryString.}
proc dateTimeFromTimestamp*(args: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyDateTime_FromTimestamp" dynlib: libraryString.}
proc dateFromTimestamp*(args: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyDate_FromTimestamp" dynlib: libraryString.}

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
    recursionDepth*: cint
    overflowed*: char
    recursionCritical*: char
    tracing*: cint
    useTracing*: cint
    cProfilefunc*: PyTraceFunc
    cTracefunc*: PyTraceFunc
    cProfileobj*: PyObjectPtr
    cTraceobj*: PyObjectPtr
    curexcType*: PyObjectPtr
    curexcValue*: PyObjectPtr
    curexcTraceback*: PyObjectPtr
    excType*: PyObjectPtr
    excValue*: PyObjectPtr
    excTraceback*: PyObjectPtr
    dict*: PyObjectPtr
    gilstateCounter*: cint
    asyncExc*: PyObjectPtr
    threadId*: clong
    trashDeleteNesting*: cint
    trashDeleteLater*: PyObjectPtr
    onDelete*: proc (arg: pointer) {.cdecl.}
    onDeleteData*: pointer
    
  PyGILStateState* {.size: sizeof(cint).} = enum 
    gsLOCKED
    gsUNLOCKED


#Py_BEGIN_ALLOW_THREADS
#Py_END_ALLOW_THREADS
#Py_BLOCK_THREADS
#Py_UNBLOCK_THREADS

var
  traceCALL*: cint = cast[cint](dynlib.symAddr(libraryHandle, "PyTrace_CALL"))
  traceEXCEPTION*: cint = cast[cint](
                   dynlib.symAddr(libraryHandle, "PyTrace_EXCEPTION"))
  traceLINE*: cint = cast[cint](dynlib.symAddr(libraryHandle, "PyTrace_LINE"))
  traceRETURN*: cint = cast[cint](
                dynlib.symAddr(libraryHandle, "PyTrace_RETURN"))
  traceCCALL*: cint = cast[cint](
               dynlib.symAddr(libraryHandle, "PyTrace_C_CALL"))
  traceCEXCEPTION*: cint = cast[cint](
                    dynlib.symAddr(libraryHandle, "PyTrace_C_EXCEPTION"))
  traceCRETURN*: cint = cast[cint](
                 dynlib.symAddr(libraryHandle, "PyTrace_C_RETURN"))

#proc Py_Initialize*() {.cdecl, importc, dynlib: libraryString.}
proc initializeEx*(initsigs: cint) {.cdecl, importc: "Py_InitializeEx" 
  dynlib: libraryString.}
proc isInitialized*(): cint {.cdecl, importc: "Py_IsInitialized" 
  dynlib: libraryString.}
#proc Py_Finalize*() {.cdecl, importc, dynlib: libraryString.}
proc setStandardStreamEncoding*(encoding: cstring; errors: cstring): cint {.
  cdecl, importc: "Py_SetStandardStreamEncoding" dynlib: libraryString.}
proc setProgramName*(name: PyUnicode) {.cdecl, importc: "Py_SetProgramName" 
  dynlib: libraryString.}
proc getProgramName*(): PyUnicode {.cdecl, importc: "Py_GetProgramName" 
  dynlib: libraryString.}
proc getPrefix*(): PyUnicode {.cdecl, importc: "Py_GetPrefix" 
  dynlib: libraryString.}
proc getExecPrefix*(): PyUnicode {.cdecl, importc: "Py_GetExecPrefix" 
  dynlib: libraryString.}
proc getProgramFullPath*(): PyUnicode {.cdecl, importc: "Py_GetProgramFullPath" 
  dynlib: libraryString.}
proc getPath*(): PyUnicode {.cdecl, importc: "Py_GetPath" dynlib: libraryString.}
proc setPath*(arg: PyUnicode) {.cdecl, importc: "Py_SetPath" 
  dynlib: libraryString.}
proc getVersion*(): cstring {.cdecl, importc: "Py_GetVersion" 
  dynlib: libraryString.}
proc getPlatform*(): cstring {.cdecl, importc: "Py_GetPlatform" 
  dynlib: libraryString.}
proc getCopyright*(): cstring {.cdecl, importc: "Py_GetCopyright" 
  dynlib: libraryString.}
proc getCompiler*(): cstring {.cdecl, importc: "Py_GetCompiler" 
  dynlib: libraryString.}
proc getBuildInfo*(): cstring {.cdecl, importc: "Py_GetBuildInfo" 
  dynlib: libraryString.}
proc sysSetArgvEx*(argc: cint; argv: PyUnicodePtr; updatepath: cint) {.cdecl, 
  importc: "PySys_SetArgvEx" dynlib: libraryString.}
proc sysSetArgv*(argc: cint; argv: PyUnicodePtr) {.cdecl, 
  importc: "PySys_SetArgv" dynlib: libraryString.}
proc setPythonHome*(home: PyUnicode) {.cdecl, importc: "Py_SetPythonHome" 
  dynlib: libraryString.}
proc getPythonHome*(): PyUnicode {.cdecl, importc: "Py_GetPythonHome" 
  dynlib: libraryString.}
proc evalInitThreads*() {.cdecl, importc: "PyEval_InitThreads" 
  dynlib: libraryString.}
proc evalThreadsInitialized*(): cint {.cdecl, 
  importc: "PyEval_ThreadsInitialized" dynlib: libraryString.}
proc evalSaveThread*(): PyThreadStatePtr {.cdecl, importc: "PyEval_SaveThread" 
  dynlib: libraryString.}
proc evalRestoreThread*(tstate: PyThreadStatePtr) {.cdecl, 
  importc: "PyEval_RestoreThread" dynlib: libraryString.}
proc threadStateGet*(): PyThreadStatePtr {.cdecl, importc: "PyThreadState_Get" 
  dynlib: libraryString.}
proc threadStateSwap*(tstate: PyThreadStatePtr): PyThreadStatePtr {.cdecl, 
  importc: "PyThreadState_Swap" dynlib: libraryString.}
proc evalReInitThreads*() {.cdecl, importc: "PyEval_ReInitThreads" 
  dynlib: libraryString.}
proc gilStateEnsure*(): PyGILState_STATE {.cdecl, importc: "PyGILState_Ensure" 
  dynlib: libraryString.}
proc gilStateRelease*(arg: PyGILState_STATE) {.cdecl, 
  importc: "PyGILState_Release" dynlib: libraryString.}
proc gilStateGetThisThreadState*(): PyThreadStatePtr {.cdecl, 
  importc: "PyGILState_GetThisThreadState" dynlib: libraryString.}
proc gilStateCheck*(): cint {.cdecl, importc: "PyGILState_Check" 
  dynlib: libraryString.}

#Low-level API
proc interpreterStateNew*(): PyInterpreterStatePtr {.cdecl, 
  importc: "PyInterpreterState_New" dynlib: libraryString.}
proc interpreterStateClear*(interp: PyInterpreterStatePtr) {.cdecl, 
  importc: "PyInterpreterState_Clear" dynlib: libraryString.}
proc interpreterStateDelete*(interp: PyInterpreterStatePtr) {.cdecl, 
  importc: "PyInterpreterState_Delete" dynlib: libraryString.}
proc threadStateNew*(interp: PyInterpreterStatePtr): PyThreadStatePtr {.cdecl, 
  importc: "PyThreadState_New" dynlib: libraryString.}
proc threadStateClear*(tstate: PyThreadStatePtr) {.cdecl, 
  importc: "PyThreadState_Clear" dynlib: libraryString.}
proc threadStateDelete*(tstate: PyThreadStatePtr) {.cdecl, 
  importc: "PyThreadState_Delete" dynlib: libraryString.}
proc threadStateGetDict*(): PyObjectPtr {.cdecl, 
  importc: "PyThreadState_GetDict" dynlib: libraryString.}
proc threadStateSetAsyncExc*(id: clong; exc: PyObjectPtr): cint {.cdecl, 
  importc: "PyThreadState_SetAsyncExc" dynlib: libraryString.}
proc evalAcquireThread*(tstate: PyThreadStatePtr) {.cdecl, 
  importc: "PyEval_AcquireThread" dynlib: libraryString.}
proc evalReleaseThread*(tstate: PyThreadStatePtr) {.cdecl, 
  importc: "PyEval_ReleaseThread" dynlib: libraryString.}
proc evalAcquireLock*() {.cdecl, importc: "PyEval_AcquireLock" 
  dynlib: libraryString.}
proc evalReleaseLock*() {.cdecl, importc: "PyEval_ReleaseLock" 
  dynlib: libraryString.}

#Sub-interpreter support
proc newInterpreter*(): PyThreadStatePtr {.cdecl, importc: "Py_NewInterpreter" 
  dynlib: libraryString.}
proc endInterpreter*(tstate: PyThreadStatePtr) {.cdecl, 
  importc: "Py_EndInterpreter" dynlib: libraryString.}
proc addPendingCall*(fun: proc (arg: pointer): cint {.cdecl.}; arg: pointer): cint {.
  cdecl, importc: "Py_AddPendingCall" dynlib: libraryString.}

#Profiling and Tracing
proc evalSetProfile*(fun: PyTraceFunc; obj: PyObjectPtr) {.cdecl, 
  importc: "PyEval_SetProfile" dynlib: libraryString.}
proc evalSetTrace*(fun: PyTraceFunc; obj: PyObjectPtr) {.cdecl, 
  importc: "PyEval_SetTrace" dynlib: libraryString.}
proc evalGetCallStats*(self: PyObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyEval_GetCallStats" dynlib: libraryString.}

#Advanced Debugger Support
proc interpreterStateHead*(): PyInterpreterStatePtr {.cdecl, 
  importc: "PyInterpreterState_Head" dynlib: libraryString.}
proc interpreterStateNext*(
  interp: PyInterpreterStatePtr): PyInterpreterStatePtr {.cdecl, 
  importc: "PyInterpreterState_Next" dynlib: libraryString.}
proc interpreterStateThreadHead*(
  interp: PyInterpreterStatePtr): PyThreadStatePtr {.cdecl, 
  importc: "PyInterpreterState_ThreadHead" dynlib: libraryString.}
proc threadStateNext*(tstate: PyThreadStatePtr): PyThreadStatePtr {.cdecl, 
  importc: "PyThreadState_Next" dynlib: libraryString.}

#Memory Management
#Raw Memory Interface
proc memRawMalloc*(n: csize): pointer {.cdecl, importc: "PyMem_RawMalloc" 
  dynlib: libraryString.}
proc memRawRealloc*(p: pointer; n: csize): pointer {.cdecl, 
  importc: "PyMem_RawRealloc" dynlib: libraryString.}
proc memRawFree*(p: pointer) {.cdecl, importc: "PyMem_RawFree" 
  dynlib: libraryString.}

#Memory Interface
proc memMalloc*(n: csize): pointer {.cdecl, importc: "PyMem_Malloc" 
  dynlib: libraryString.}
proc memRealloc*(p: pointer; n: csize): pointer {.cdecl, 
  importc: "PyMem_Realloc" dynlib: libraryString.}
proc memFree*(p: pointer) {.cdecl, importc: "PyMem_Free" dynlib: libraryString.}
#TYPE* PyMem_New(TYPE, size_t n);
#TYPE* PyMem_Resize(void *p, TYPE, size_t n);

proc memDel*(p: pointer) {.cdecl, importc: "PyMem_Del" dynlib: libraryString.}

#Customize Memory Allocators
type
  PyMemAllocatorPtr = ptr PyMemAllocator
  PyMemAllocator* {.final.} = object 
    ctx*: pointer
    malloc*: proc (ctx: pointer; size: csize): pointer {.cdecl.}
    realloc*: proc (ctx: pointer; pt: pointer; new_size: csize): pointer {.cdecl.}
    free*: proc (ctx: pointer; pt: pointer) {.cdecl.}

  PyMemAllocatorDomain* {.size: sizeof(cint).} = enum
    pmadRAW,   # PyMem_RawMalloc(), PyMem_RawRealloc() and PyMem_RawFree()      
    pmadMEM,   # PyMem_Malloc(), PyMem_Realloc() and PyMem_Free()       
    pmadOBJ    # PyObject_Malloc(), PyObject_Realloc() and PyObject_Free() 


proc memGetAllocator*(domain: PyMemAllocatorDomain;
  allocator: PyMemAllocatorPtr) {.cdecl, importc: "PyMem_GetAllocator" 
  dynlib: libraryString.}
proc memSetAllocator*(domain: PyMemAllocatorDomain;
  allocator: PyMemAllocatorPtr) {.cdecl, importc: "PyMem_SetAllocator" 
  dynlib: libraryString.}
proc memSetupDebugHooks*() {.cdecl, importc: "PyMem_SetupDebugHooks" 
  dynlib: libraryString.}

#Allocating Objects on the Heap
proc objectNew*(typ: PyTypeObjectPtr): PyObjectPtr {.cdecl, 
  importc: "_PyObject_New", dynlib: libraryString.}
proc objectNewVar*(typ: PyTypeObjectPtr; size: PySizeT): PyVarObjectPtr {.cdecl, 
  importc: "_PyObject_NewVar", dynlib: libraryString.}
proc objectInit*(op: PyObjectPtr; typ: PyTypeObjectPtr): PyObjectPtr {.cdecl, 
  importc: "PyObject_Init", dynlib: libraryString.}
proc objectInitVar*(op: PyVarObjectPtr; typ: PyTypeObjectPtr;
  size: PySizeT): PyVarObjectPtr {.cdecl, importc: "PyObject_InitVar", 
  dynlib: libraryString.}
#TYPE* PyObject_New(TYPE, PyTypeObject *type);
#TYPE* PyObject_NewVar(TYPE, PyTypeObject *type, PySizeT size);
proc objectDel*(op: PyObjectPtr) {.cdecl, importc: "PyObject_Del" 
  dynlib: libraryString.}


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
