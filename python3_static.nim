
#[
    This is a raw wrapper, 1-on-1 with the Python 3 naming convention
]#

# C constants
const
    datetimeDateDataSize* = 4 # number of bytes for year, month, and day. 
    datetimeTimeDataSize* = 6 # number of bytes for hour, minute, second, and usecond.
    datetimeDateTimeDataSize* = 10 # number of bytes for year, month, day, hour, minute, second, and usecond. 

# C types
type
    UncheckedArray*{.unchecked.}[T] = array[1,T]
    # C definition: 'typedef long Py_ssize_t'
    Py_ssize_t* = int
    # C definition: 'typedef Py_ssize_t Py_hash_t;'
    Py_hash_t* = Py_ssize_t
    # C definition: 'typedef wchar_t Py_UNICODE;'
    PyUnicode* = string
    PyosSighandler* = proc (parameter: cint) {.cdecl.}
    
    # Function pointers used for various Python methods
    freefunc* = proc (p: pointer){.cdecl.}
    destructor* = proc (ob: ptr PyObject){.cdecl.}
    printfunc* = proc (ob: ptr PyObject, f: File, i: int): int{.cdecl.}
    getattrfunc* = proc (ob1: ptr PyObject, name: cstring): ptr PyObject{.cdecl.}
    getattrofunc* = proc (ob1, ob2: ptr PyObject): ptr PyObject{.cdecl.}
    setattrfunc* = proc (ob1: ptr PyObject, name: cstring, ob2: ptr PyObject): int{.cdecl.}
    setattrofunc* = proc (ob1, ob2, ob3: ptr PyObject): int{.cdecl.} 
    reprfunc* = proc (ob: ptr PyObject): ptr PyObject{.cdecl.}
    binaryfunc* = proc (ob1, ob2: ptr PyObject): ptr PyObject{.cdecl.}
    ternaryfunc* = proc (ob1, ob2, ob3: ptr PyObject): ptr PyObject{.cdecl.}
    unaryfunc* = proc (ob: ptr PyObject): ptr PyObject{.cdecl.}
    inquiry* = proc (ob: ptr PyObject): int{.cdecl.}
    lenfunc* = proc (ob: ptr PyObject): Py_ssize_t{.cdecl.}
    ssizeargfunc* = proc (ob: ptr PyObject, i: Py_ssize_t): ptr PyObject{.cdecl.}
    ssizessizeargfunc* = proc (ob: ptr PyObject, i1, i2: Py_ssize_t): ptr PyObject{.cdecl.}
    ssizeobjargproc* = proc (ob1: ptr PyObject, i: Py_ssize_t, ob2: ptr PyObject): int{.cdecl.}
    ssizessizeobjargproc* = proc (ob1: ptr PyObject, i1, i2: Py_ssize_t, ob2: ptr PyObject): int{.cdecl.}
    objobjargproc* = proc (ob1, ob2, ob3: ptr PyObject): int{.cdecl.}
    hashfunc* = proc (ob: ptr PyObject): Py_hash_t{.cdecl.}
    getbufferproc* = proc (ob: ptr PyObject, buf: ptr PyBuffer, i: int)
    releasebufferproc* = proc (ob: ptr PyObject, buf: ptr PyBuffer)
    objobjproc* = proc (ob1, ob2: ptr PyObject): int{.cdecl.}
    visitproc* = proc (ob: ptr PyObject, p: pointer): int{.cdecl.}
    traverseproc* = proc (ob: ptr PyObject, prc: visitproc, p: pointer): int{.cdecl.}
    richcmpfunc* = proc (ob1, ob2: ptr PyObject, i: int): ptr PyObject{.cdecl.}
    getiterfunc* = proc (ob: ptr PyObject): ptr PyObject{.cdecl.}
    iternextfunc* = proc (ob: ptr PyObject): ptr PyObject{.cdecl.}
    PyCFunction* = proc (self, args: ptr PyObject): ptr PyObject{.cdecl.}
    getter* = proc (obj: ptr PyObject, context: pointer): ptr PyObject{.cdecl.}
    setter* = proc (obj, value: ptr PyObject, context: pointer): int{.cdecl.}
    descrgetfunc* = proc (ob1, ob2, ob3: ptr PyObject): ptr PyObject{.cdecl.}
    descrsetfunc* = proc (ob1, ob2, ob3: ptr PyObject): int{.cdecl.}
    initproc* = proc (self, args, kwds: ptr PyObject): int{.cdecl.}
    newfunc* = proc (subtype: ptr PyTypeObject, args, kwds: ptr PyObject): ptr PyObject{.cdecl.}
    allocfunc* = proc (self: ptr PyTypeObject, nitems: Py_ssize_t): ptr PyObject{.cdecl.}
    pytracefunc* = proc (obj: ptr PyObject; frame: ptr PyFrameObject; what: cint; arg: ptr PyObject): cint{.cdecl.}
    
    # Defined in "Include/object.h"
    PyObject* {.header: "Python.h", importc: "PyObject".} = object
        `ob_refcnt`*: Py_ssize_t
        `ob_type`*: ptr PyTypeObject
    
    # Defined in "Include/object.h"
    PyTypeObject* {.header: "Python.h", importc: "PyTypeObject".} = object
        `ob_base`*: PyVarObject
        `tp_name`*: cstring
        `tp_basicsize`*: Py_ssize_t
        `tp_itemsize`*: Py_ssize_t
        # Methods to implement standard operations
        `tp_dealloc`*: destructor
        `tp_print`*: printfunc
        `tp_getattr`*: getattrfunc
        `tp_setattr`*: setattrfunc
        `tp_reserved`*: pointer # formerly known as tp_compare
        `tp_repr`*: reprfunc
        # Method suites for standard classes
        `tp_as_number`*: ptr PyNumberMethods
        `tp_as_sequence`*: ptr PySequenceMethods
        `tp_as_mapping`*: ptr PyMappingMethods 
        # More standard operations (here for binary compatibility)
        `tp_hash`*: hashfunc
        `tp_call`*: ternaryfunc
        `tp_str`*: reprfunc
        `tp_getattro`*: getattrofunc
        `tp_setattro`*: setattrofunc
        # Functions to access object as input/output buffer
        `tp_as_buffer`*: ptr PyBufferProcs
        # Flags to define presence of optional/expanded features
        `tp_flags`*: int32
        # Documentation string
        `tp_doc`*: cstring
        # Call function for all accessible objects
        `tp_traverse`*: traverseproc
        # Delete references to contained objects
        `tp_clear`*: inquiry       
        # Rich comparisons
        `tp_richcompare`*: richcmpfunc 
        # Weak reference enabler
        `tp_weaklistoffset`*: Py_ssize_t 
        # Iterators
        `tp_iter`*: getiterfunc
        `tp_iternext`*: iternextfunc 
        # Attribute descriptor and subclassing stuff
        `tp_methods`*: ptr PyMethodDef
        `tp_members`*: ptr PyMemberDef
        `tp_getset`*: ptr PyGetSetDef
        `tp_base`*: ptr PyTypeObject
        `tp_dict`*: ptr PyObject
        `tp_descr_get`*: descrgetfunc
        `tp_descr_set`*: descrsetfunc
        `tp_dictoffset`*: Py_ssize_t
        `tp_init`*: initproc
        `tp_alloc`*: allocfunc
        `tp_new`*: newfunc
        `tp_free`*: freefunc # Low-level free-memory routine
        `tp_is_gc`*: inquiry  # For PyObject_IS_GC
        `tp_bases`*: ptr PyObject
        `tp_mro`*: ptr PyObject    # method resolution order
        `tp_cache`*: ptr PyObject
        `tp_subclasses`*: ptr PyObject
        `tp_weaklist`*: ptr PyObject
        `tp_del`*: destructor
        `tp_version_tag`*: uint # Type attribute cache version tag
        `tp_finalize`*: destructor
        # These must be last and never explicitly initialized
#        `tp_allocs`*: Py_ssize_t 
#        `tp_frees`*: Py_ssize_t 
#        `tp_maxalloc`*: Py_ssize_t
#        `tp_prev`*: ptr PyTypeObject
#        `tp_next`*: ptr PyTypeObject
    
    # Defined in "Include/object.h"
    PyVarObject* {.header: "Python.h", importc: "PyVarObject".} = object
        `ob_base`*: PyObject
        `ob_size`*: Py_ssize_t
    
    # Defined in "Include/object.h"
    PyBuffer* {.header: "Python.h", importc: "Py_buffer".} = object
        `buf`*: pointer
        `obj`*: ptr PyObject
        `length`*: Py_ssize_t
        `itemsize`*: Py_ssize_t
        `readonly`*: int
        `ndim`*: int
        `format`*: cstring
        `shape`*: ptr Py_ssize_t
        `strides`*: ptr Py_ssize_t
        `suboffsets`*: ptr Py_ssize_t
        `internal`*: pointer
    
    # Defined in "Include/object.h"
    PyNumberMethods* {.header: "Python.h", importc: "PyNumberMethods".} = object
        `nb_add`*: binaryfunc
        `nb_subtract`*: binaryfunc
        `nb_multiply`*: binaryfunc
        `nb_remainder`*: binaryfunc
        `nb_divmod`*: binaryfunc
        `nb_power`*: ternaryfunc
        `nb_negative`*: unaryfunc
        `nb_positive`*: unaryfunc
        `nb_absolute`*: unaryfunc
        `nb_bool`*: inquiry
        `nb_invert`*: unaryfunc
        `nb_lshift`*: binaryfunc
        `nb_rshift`*: binaryfunc
        `nb_and`*: binaryfunc
        `nb_xor`*: binaryfunc
        `nb_or`*: binaryfunc
        `nb_int`*: unaryfunc
        `nb_reserved`*: pointer
        `nb_float`*: unaryfunc     
        
        `nb_inplace_add`*: binaryfunc
        `nb_inplace_subtract`*: binaryfunc
        `nb_inplace_multiply`*: binaryfunc
        `nb_inplace_remainder`*: binaryfunc
        `nb_inplace_power`*: ternaryfunc
        `nb_inplace_lshift`*: binaryfunc
        `nb_inplace_rshift`*: binaryfunc
        `nb_inplace_and`*: binaryfunc
        `nb_inplace_xor`*: binaryfunc
        `nb_inplace_or`*: binaryfunc
        
        `nb_floor_divide`*: binaryfunc
        `nb_true_divide`*: binaryfunc
        `nb_inplace_floor_divide`*: binaryfunc
        `nb_inplace_true_divide`*: binaryfunc
        
        `nb_index`*: unaryfunc
    
    # Defined in "Include/frameobject.h"
    PyFrameObject* {.header: "Python.h", importc: "PyFrameObject".} = object
        `ob_base`*: PyVarObject
        `f_back`*: ptr PyFrameObject   # previous frame, or NULL
        `f_code`*: PyCodeObject       # code segment
        `f_builtins`*: ptr PyObject    # builtin symbol table (PyDictObject)
        `f_globals`*: ptr PyObject     # global symbol table (PyDictObject)
        `f_locals`*: ptr PyObject      # local symbol table (any mapping)
        `f_valuestack`*: ptr ptr PyObject   # points after the last local
        `f_stacktop`*: ptr ptr PyObject     # points after the last local
        `f_trace`*: ptr PyObject   # Trace function
        `f_exc_type`*, `f_exc_value`*, `f_exc_traceback`*: ptr PyObject
        `f_gen`*: ptr PyObject # Borrowed reference to a generator, or NULL
        `f_lasti`*: int   # Last instruction if called
        `f_lineno`*: int  # Current line number
        `f_iblock`*: int  # index in fBlockstack
        `f_executing`*: int8  # whether the frame is still executing
        `f_blockstack`: array[0..co_max_blocks-1, PyTryBlock]  # for try and loop blocks
        `f_localsplus`*: UncheckedArray[ptr PyObject]
    
    # Defined in "Include/frameobject.h"
    PyTryBlock* {.header: "Python.h", importc: "PyTryBlock".} = object
        `b_type`*: cint # what kind of block this is
        `b_handler`*: cint # where to jump to find handler
        `b_level`*: cint # value stack level to pop to

    # Defined in "Include/object.h"
    PySequenceMethods* {.header: "Python.h", importc: "PySequenceMethods".} = object
        `sq_length`*: lenfunc
        `sq_concat`*: binaryfunc
        `sq_repeat`*: ssizeargfunc
        `sq_item`*: ssizeargfunc
        `was_sq_slice`*: pointer
        `sq_ass_item`*: ssizeobjargproc
        `was_sq_ass_slice`*: pointer 
        `sq_contains`*: objobjproc
        `sq_inplace_concat`*: binaryfunc
        `sq_inplace_repeat`*: ssizeargfunc
    
    # Defined in "Include/object.h"
    PyMappingMethods* {.header: "Python.h", importc: "PyMappingMethods".} = object
        `mp_length`*: lenfunc
        `mp_subscript`*: binaryfunc
        `mp_ass_subscript`*: objobjargproc
    
    # Defined in "Include/object.h"
    PyBufferProcs* {.header: "Python.h", importc: "PyBufferProcs".} = object
        `bf_getbuffer`*: getbufferproc
        `bf_releasebuffer`*: releasebufferproc
    
    # Defined in "Include/methodobject.h"
    PyMethodDef* {.header: "Python.h", importc: "PyMethodDef".} = object
        `ml_name`*: cstring
        `ml_meth`*: PyCFunction
        `ml_flags`*: cint
        `ml_doc`*: cstring
    
    # Defined in "Include/structmember.h"
    PyMemberDef* {.header: "Python.h", importc: "PyMemberDef".} = object
        `name`*: cstring
        `type`*: cint
        `offset`*: Py_ssize_t
        `flags`*: cint
        `doc`*: cstring
    
    # Defined in "Include/descrobject.h"
    PyGetSetDef* {.header: "Python.h", importc: "PyGetSetDef".}  = object
        `name`*: cstring
        `get`*: getter
        `set`*: setter
        `doc`*: cstring
        `closure`*: pointer
    
    # Defined in "Include/pythonrun.h"
    PyCompilerFlags* {.header: "Python.h", importc: "PyCompilerFlags".}  = object
        `cf_flags`*: cint

    # Defined in "Include/node.h"
    PyNode* {.header: "Python.h", importc: "PyNode".}  = object
        `n_type`*: int16
        `n_str`*: cstring
        `n_lineno`*: int
        `n_col_offset`*: int
        `n_nchildren`*: int
        `n_child`*: ptr PyNode

    # Defined in "Include/code.h"
    PyCodeObject {.header: "Python.h", importc: "PyCodeObject".} = object
        `ob_base`*: PyObject
        `co_argcount`*: cint   # arguments, except *args 
        `co_kwonlyargcount`*: cint # keyword only arguments
        `co_nlocals`*: cint    # local variables
        `co_stacksize`*: cint  # entries needed for evaluation stack
        `co_flags`*: cint  # CO..., see below
        `co_code`*: ptr PyObject   # instruction opcodes
        `co_consts`*: ptr PyObject # list (constants used)
        `co_names`*: ptr PyObject  # list of strings (names used)
        `co_varnames`*: ptr PyObject   # tuple of strings (local variable names)
        `co_freevars`*: ptr PyObject   # tuple of strings (free variable names)
        `co_cellvars`*: ptr PyObject   # tuple of strings (cell variable names)
        # The rest doesn't count for hash or comparisons
        `co_cell2arg`*: ptr uint8 # Maps cell vars which are arguments
        `co_filename`*: ptr PyObject   # unicode (where it was loaded from)
        `co_name`*: ptr PyObject   # unicode (name, for reference)
        `co_firstlineno`*: int    # first source line number
        `co_lnotab`*: ptr PyObject # string (encoding addr<->lineno mapping) 
                                # See Objects/lnotabNotes.txt for details.
        `co_zombieframe`*: pointer    # for optimization only (see frameobject.c)
        `co_weakreflist`*: ptr PyObject    # to support weakrefs to code objects
    
    inittab* {.header: "Python.h", importc: "_inittab".} = object 
        name*: cstring
        initfunc*: proc (): ptr PyObject {.cdecl.}
    
    frozen* {.header: "Python.h", importc: "_frozen".} = object
        name*: cstring
        code*: ptr cuchar
        size*: cint
    
    PyTypeSlot* {.header: "Python.h", importc: "PyTypeSlot".} = object 
        slot*: cint
        pfunc*: pointer
    
    PyTypeSpec* {.header: "Python.h", importc: "PyTypeSpec".} = object 
        name*: cstring
        basicsize*: cint
        itemsize*: cint
        flags*: cuint
        slots*: ptr PyTypeSlot
    
    PyComplex* {.header: "Python.h", importc: "PyComplex".} = object 
        real*: float64
        imag*: float64
    
    PyASCIIObject* {.header: "Python.h", importc: "PyASCIIObject".} = object 
        `ob_base`*: PyObject
        `length`*: Py_ssize_t       
        `hash`*: Py_hash_t  
        `wstr`*: ptr PyUnicode
    
    PyCompactUnicodeObject* {.header: "Python.h", importc: "PyCompactUnicodeObject".} = object 
        base*: PyASCIIObject
        `utf8_length`*: Py_ssize_t 
        utf8*: cstring          
        `wstr_length`*: Py_ssize_t
    
    PyUCS1* = cuchar
    PyUCS2* = cushort

when (sizeof(int) == 4) or (defined(posix) and sizeof(cuint) == 4):
    type PyUCS4* = cuint
elif sizeof(clong) == 4: 
    type PyUCS4* = culong
    
type
    UcsUnion* {.header: "Python.h", importc: "UcsUnion".} = object  {.union.}
        any*: pointer
        latin1*: ptr PyUCS1
        ucs2*: ptr PyUCS2
        ucs4*: ptr PyUCS4
    
    PyUnicodeObject* {.header: "Python.h", importc: "PyUnicodeObject".} = object 
        base*: PyCompactUnicodeObject
        data*: UcsUnion # Canonical, smallest-form Unicode buffer
    
#Module Objects
when PYTHON_VERSION >= 3.5:
    type
        PyModuleDef_Base* {.header: "Python.h", importc: "PyModuleDef_Base".} = object 
            `ob_base`*: PyObject
            `m_init`*: proc (): ptr PyObject {.cdecl.}
            `m_index`*: Py_ssize_t
            `m_copy`*: ptr PyObject
    
        PyModuleDef* {.header: "Python.h", importc: "PyModuleDef".}  = object
            `m_base`*: PyModuleDefBase
            `m_name`*: cstring
            `m_doc`*: cstring
            `m_size`*: Py_ssize_t
            `m_methods`*: ptr PyMethodDef
            `m_slots`*: ptr PyModuleDefSlot
            `m_traverse`*: traverseproc
            `m_clear`*: inquiry
            `m_free`*: freefunc
        
        PyModuleDefSlot* {.header: "Python.h", importc: "PyModuleDefSlot".} = object
            slot*: cint
            value*: pointer
else:
    type
        PyModuleDef_Base* {.header: "Python.h", importc: "PyModuleDef_Base".} = object 
            `ob_base`*: PyObject
            `m_init`*: proc (): ptr PyObject {.cdecl.}
            `m_index`*: Py_ssize_t
            `m_copy`*: ptr PyObject
        
        PyModuleDef* {.header: "Python.h", importc: "PyModuleDef".} = object 
            `m_base`*: PyModuleDefBase
            `m_name`*: cstring
            `m_doc`*: cstring
            `m_size`*: Py_ssize_t
            `m_methods`*: ptr PyMethodDef
            `m_reload`*: inquiry
            `m_traverse`*: traverseproc
            `m_clear`*: inquiry
            `m_free`*: freefunc  

type
    WrapperFunc* = proc (self: ptr PyObject; args: ptr PyObject; wrapped: pointer): ptr PyObject {.cdecl.}
    
    WrapperBase* {.header: "Python.h", importc: "WrapperBase".} = object
        name*: cstring
        offset*: cint
        function*: pointer
        wrapper*: WrapperFunc
        doc*: cstring
        flags*: cint
        `name_strobj`*: ptr PyObject
    
    PyCapsuleDestructor* = proc (arg: ptr PyObject) {.cdecl.}
    
    Frame* = object
    
    PyGenObject* {.header: "Python.h", importc: "PyGenObject".} = object 
        `ob_base`*: PyVarObject
        `gi_frame`*: ptr Frame
        `gi_running`*: char
        `gi_code`*: ptr PyObject
        `gi_weakreflist`*: ptr PyObject
    
    PyTupleObject* {.header: "Python.h", importc: "PyTupleObject".} = object
        `ob_base`*: PyVarObject
        `ob_item`*: UncheckedArray[ptr PyObject]
    
    PyStructSequenceField* {.header: "Python.h", importc: "PyStructSequenceField".} = object
        name*: cstring
        doc*: cstring
    
    PyStructSequenceDesc* {.header: "Python.h", importc: "PyStructSequenceDesc".} = object 
        `name`*: cstring
        `doc`*: cstring
        `fields`*: ptr PyStructSequenceField
        `n_in_sequence`*: cint
    
    PyDateTime_Time* {.header: "Python.h", importc: "PyDateTime_Time".} = object
        # _PyDateTime_TIMEHEAD
        # _PyTZINFO_HEAD
        `ob_base`*: PyObject
        hashcode*: Py_hash_t
        hastzinfo*: int8
        # _PyTZINFO_HEAD
        data*: array[datetimeTimeDataSize, cuchar]
        # _PyDateTime_TIMEHEAD
        tzinfo*: ptr PyObject
    
    PyDateTime_Date* {.header: "Python.h", importc: "PyDateTime_Date".} = object
        # _PyTZINFO_HEAD
        `ob_base`*: PyObject
        `hashcode`*: Py_hash_t
        `hastzinfo`*: int8
        # _PyTZINFO_HEAD
        `data`*: array[datetimeTimeDataSize, cuchar]
        
    PyDateTime_DateTime* {.header: "Python.h", importc: "PyDateTime_DateTime".} = object
        # _PyDateTime_DATETIMEHEAD  
        # _PyTZINFO_HEAD
        `ob_base`*: PyObject
        `hashcode`*: Py_hash_t
        `hastzinfo`*: int8
        # _PyTZINFO_HEAD
        `data`*: array[datetimeDateTimeDataSize, cuchar]
        # _PyDateTime_DATETIMEHEAD  
        `tzinfo`*: ptr PyObject
    
    PyDateTimeDelta* {.header: "Python.h", importc: "PyDateTimeDelta".} = object 
        # _PyTZINFO_HEAD
        obBase*: PyObject
        hashcode*: Py_hash_t
        hastzinfo*: int8
        # _PyTZINFO_HEAD
        days*: int                # -MAX_DELTA_DAYS <= days <= MAX_DELTA_DAYS 
        seconds*: int             # 0 <= seconds < 24*3600 is invariant 
        microseconds*: int        # 0 <= microseconds < 1000000 is invariant 
    
    CallStats* = enum 
        PCALL_ALL = 0, PCALL_FUNCTION = 1, PCALL_FAST_FUNCTION = 2, 
        PCALL_FASTER_FUNCTION = 3, PCALL_METHOD = 4, PCALL_BOUND_METHOD = 5, 
        PCALL_CFUNCTION = 6, PCALL_TYPE = 7, PCALL_GENERATOR = 8, PCALL_OTHER = 9, 
        PCALL_POP = 10
    
    PyInterpreterState* {.header: "Python.h", importc: "PyInterpreterState".} = object
    
    PyThreadState* {.header: "Python.h", importc: "PyThreadState".} = object 
        `prev`*: ptr PyThreadState
        `next`*: ptr PyThreadState
        `interp`*: ptr PyInterpreterState
        `frame`*: ptr Frame
        `recursion_depth`*: cint
        `overflowed`*: char
        `recursion_critical`*: char
        `tracing`*: cint
        `use_tracing`*: cint
        `c_profilefunc`*: pytracefunc
        `c_tracefunc`*: pytracefunc
        `c_profileobj`*: ptr PyObject
        `c_traceobj`*: ptr PyObject
        `curexc_type`*: ptr PyObject
        `curexc_value`*: ptr PyObject
        `curexc_traceback`*: ptr PyObject
        `exc_type`*: ptr PyObject
        `exc_value`*: ptr PyObject
        `exc_traceback`*: ptr PyObject
        `dict`*: ptr PyObject
        `gilstate_counter`*: cint
        `async_exc`*: ptr PyObject
        `thread_id`*: clong
        `trash_delete_nesting`*: cint
        `trash_delete_later`*: ptr PyObject
        `on_delete`*: proc (arg: pointer) {.cdecl.}
        `on_delete_data`*: pointer
        
    PyGILStateState* {.size: sizeof(cint).} = enum 
        gsLOCKED
        gsUNLOCKED
    
    PyMemAllocator* {.header: "Python.h", importc: "PyStructSequenceField".} = object 
        `ctx`*: pointer
        `malloc`*: proc (ctx: pointer; size: csize): pointer {.cdecl.}
        `realloc`*: proc (ctx: pointer; pt: pointer; new_size: csize): pointer {.cdecl.}
        `free`*: proc (ctx: pointer; pt: pointer) {.cdecl.}
    
    PyMemAllocatorDomain* {.size: sizeof(cint).} = enum
        pmadRAW,   # PyMem_RawMalloc(), PyMem_RawRealloc() and PyMem_RawFree()      
        pmadMEM,   # PyMem_Malloc(), PyMem_Realloc() and PyMem_Free()       
        pmadOBJ    # PyObject_Malloc(), PyObject_Realloc() and PyObject_Free() 

# C macros that need to be reimplemented as templates
template Py_RETURN_NONE*() = {.emit: "Py_RETURN_NONE;".}

# C functions and macros
proc Py_INCREF*(ob: ptr PyObject){.header: "Python.h", importc: "Py_INCREF", cdecl.}
proc Py_XINCREF*(ob: ptr PyObject){.header: "Python.h", importc: "Py_XINCREF", cdecl.}
proc Py_DECREF*(ob: ptr PyObject){.header: "Python.h", importc: "Py_DECREF", cdecl.}
proc Py_XDECREF*(ob: ptr PyObject){.header: "Python.h", importc: "Py_XDECREF", cdecl.}
proc Py_CLEAR*(ob: ptr PyObject){.header: "Python.h", importc: "Py_CLEAR", cdecl.}
proc Py_Initialize*(){.header: "Python.h", importc: "Py_Initialize".}
proc Py_Finalize*(){.header: "Python.h", importc: "Py_Finalize".}
proc Py_Main*(argc: int, argv: ptr WideCString): int{.header: "Python.h", importc: "Py_Main".}
proc PyRun_SimpleString*(command: cstring): int{.header: "Python.h", importc: "PyRun_SimpleString".}
proc PyRun_SimpleStringFlags*(command: cstring, flags: ptr PyCompilerFlags): int{.header: "Python.h", importc: "PyRun_SimpleStringFlags".}
proc PyRun_String*(str: cstring, start: int, globals: ptr PyObject, locals: ptr PyObject): ptr PyObject{.header: "Python.h", importc: "PyRun_String".}
proc PyRun_StringFlags*(str: cstring, start: int, globals: ptr PyObject, locals: ptr PyObject,flags: PyCompilerFlags): ptr PyObject{.header: "Python.h", importc: "PyRun_StringFlags".}
proc PyParser_SimpleParseString*(str: cstring, start: int): ptr PyNode{.header: "Python.h", importc: "PyParser_SimpleParseString".}
proc PyParser_SimpleParseStringFlags*(str: cstring, start: int, flags: int): ptr PyNode{.header: "Python.h", importc: "PyParser_SimpleParseStringFlags".}
proc PyParser_SimpleParseStringFlagsFilename*(str: cstring, filename: cstring, start: int, flags: int): ptr PyNode{.header: "Python.h", importc: "PyParser_SimpleParseStringFlagsFilename".}
proc Py_CompileString*(str: cstring, filename: cstring, start: int): ptr PyObject{.header: "Python.h", importc: "Py_CompileString".}
proc Py_CompileStringFlags*(str: cstring, filename: cstring, start: int, flags: ptr PyCompilerFlags): ptr PyObject{.header: "Python.h", importc: "Py_CompileStringFlags".}
proc Py_CompileStringExFlags*(str: cstring, filename: cstring, start: int, flags: ptr PyCompilerFlags, optimize: int): ptr PyObject{.header: "Python.h", importc: "Py_CompileStringExFlags".}
proc Py_CompileStringObject*(str: cstring, filename: ptr PyObject, start: int, flags: ptr PyCompilerFlags, optimize: int): ptr PyObject{.header: "Python.h", importc: "Py_CompileStringObject".}
proc PyEval_EvalCode*(ob: ptr PyObject, globals: ptr PyObject, locals: ptr PyObject): ptr PyObject{.header: "Python.h", importc: "PyEval_EvalCode".}
proc PyEval_EvalCodeEx*(ob: ptr PyObject, globals: ptr PyObject, locals: ptr PyObject, args: ptr ptr PyObject, argcount: int,kws: ptr ptr PyObject, kwcount: int, defs: ptr ptr PyObject,defcount: int, closure: ptr PyObject): ptr PyObject{.header: "Python.h", importc: "PyEval_EvalCodeEx".}
proc PyEval_EvalFrame*(f: ptr PyFrameObject): ptr PyObject{.header: "Python.h", importc: "PyEval_EvalFrame".}
proc PyEval_EvalFrameEx*(f: ptr PyFrameObject, throwflag: int): ptr PyObject{.header: "Python.h", importc: "PyEval_EvalFrameEx".}
proc PyEval_MergeCompilerFlags*(cf: ptr PyCompilerFlags): int{.header: "Python.h", importc: "PyEval_MergeCompilerFlags".}
proc PyErr_PrintEx*(set_sys_last_vars: int){.header: "Python.h", importc: "PyErr_PrintEx".}
proc PyErr_Print*(){.header: "Python.h", importc: "PyErr_Print".}
proc PyErr_Occurred*(): ptr PyObject {.header: "Python.h", importc: "PyErr_Occurred".}
proc PyErr_ExceptionMatches*(exc: ptr PyObject): int{.header: "Python.h", importc: "PyErr_ExceptionMatches".}
proc PyErr_GivenExceptionMatches*(given: ptr PyObject, exc: ptr PyObject): int{.header: "Python.h", importc: "PyErr_GivenExceptionMatches".}
proc PyErr_NormalizeException*(exc: ptr ptr PyObject, val: ptr ptr PyObject, tb: ptr ptr PyObject){.header: "Python.h", importc: "PyErr_NormalizeException".}
proc PyErr_Clear*(){.header: "Python.h", importc: "PyErr_Clear".}
proc PyErr_Fetch*(ptype: ptr ptr PyObject, pvalue: ptr ptr PyObject, ptraceback: ptr ptr PyObject){.header: "Python.h", importc: "PyErr_Fetch".}
proc PyErr_Restore*(typ: ptr PyObject, value: ptr PyObject, traceback: ptr PyObject){.header: "Python.h", importc: "PyErr_Restore".}
proc PyErr_GetExcInfo*(ptype: ptr ptr PyObject, pvalue: ptr ptr PyObject, ptraceback: ptr ptr PyObject){.header: "Python.h", importc: "PyErr_GetExcInfo".}
proc PyErr_SetExcInfo*(typ: ptr PyObject, value: ptr PyObject, traceback: ptr PyObject){.header: "Python.h", importc: "PyErr_SetExcInfo".}
proc PyErr_SetString*(typ: ptr PyObject, message: cstring){.header: "Python.h", importc: "PyErr_SetString".}
proc PyErr_SetObject*(typ: ptr PyObject, value: ptr PyObject){.header: "Python.h", importc: "PyErr_SetObject".}
proc PyErr_Format*(exception: ptr PyObject, format: cstring): ptr PyObject{.header: "Python.h", importc: "PyErr_Format".}
proc PyErr_SetNone*(typ: ptr PyObject){.header: "Python.h", importc: "PyErr_SetNone".}
proc PyErr_BadArgument*(): int{.header: "Python.h", importc: "PyErr_BadArgument".}
proc PyErr_NoMemory*(): ptr PyObject{.header: "Python.h", importc: "PyErr_NoMemory".}
proc PyErr_SetFromErrno*(typ: ptr PyObject): ptr PyObject{.header: "Python.h", importc: "PyErr_SetFromErrno".}
proc PyErr_SetFromErrnoWithFilenameObject*(typ: ptr PyObject, filenameObject: ptr PyObject): ptr PyObject{.header: "Python.h", importc: "PyErr_SetFromErrnoWithFilenameObject".}
proc PyErr_SetFromErrnoWithFilenameObjects*(typ: ptr PyObject, filenameObject: ptr PyObject, filenameObject2: ptr PyObject): ptr PyObject{.header: "Python.h", importc: "PyErr_SetFromErrnoWithFilenameObjects".}
proc PyErr_SetFromErrnoWithFilename*(typ: ptr PyObject, filename: cstring): ptr PyObject{.header: "Python.h", importc: "PyErr_SetFromErrnoWithFilename".}
proc PyErr_SetFromWindowsErr*(ierr: int): ptr PyObject{.header: "Python.h", importc: "PyErr_SetFromWindowsErr".}
proc PyErr_SetExcFromWindowsErr*(typ: ptr PyObject, ierr: int): ptr PyObject{.header: "Python.h", importc: "PyErr_SetExcFromWindowsErr".}
proc PyErr_SetFromWindowsErrWithFilename*(ierr: int, filename: cstring): ptr PyObject{.header: "Python.h", importc: "PyErr_SetFromWindowsErrWithFilename".}
proc PyErr_SetExcFromWindowsErrWithFilenameObject*(typ: ptr PyObject, ierr: int, filename: ptr PyObject): ptr PyObject{.header: "Python.h", importc: "PyErr_SetExcFromWindowsErrWithFilenameObject".}
proc PyErr_SetExcFromWindowsErrWithFilenameObjects*(typ: ptr PyObject, ierr: int, filename: ptr PyObject, filename2: ptr PyObject): ptr PyObject{.header: "Python.h", importc: "PyErr_SetExcFromWindowsErrWithFilenameObjects".}
proc PyErr_SetExcFromWindowsErrWithFilename*(typ: ptr PyObject, ierr: int, filename: cstring): ptr PyObject{.header: "Python.h", importc: "PyErr_SetExcFromWindowsErrWithFilename".}
proc PyErr_SetImportError*(msg: ptr PyObject, name: ptr PyObject, path: ptr PyObject): ptr PyObject{.header: "Python.h", importc: "PyErr_SetImportError".}
proc PyErr_SyntaxLocationObject*(filename: ptr PyObject, lineno: int, col_offset: int){.header: "Python.h", importc: "PyErr_SyntaxLocationObject".}
proc PyErr_SyntaxLocationEx*(filename: cstring, lineno: int, col_offset: int){.header: "Python.h", importc: "PyErr_SyntaxLocationEx".}
proc PyErr_SyntaxLocation*(filename: cstring, lineno: int){.header: "Python.h", importc: "PyErr_SyntaxLocation".}
proc PyErr_BadInternalCall*(){.header: "Python.h", importc: "PyErr_BadInternalCall".}
proc PyErr_WarnEx*(category: ptr PyObject, message: cstring, stack_level: Py_ssize_t): int{.header: "Python.h", importc: "PyErr_WarnEx".}
proc PyErr_WarnExplicitObject*(category: ptr PyObject, message: ptr PyObject, filename: ptr PyObject, lineno: int, module: ptr PyObject,registry: ptr PyObject): int{.header: "Python.h", importc: "PyErr_WarnExplicitObject".}
proc PyErr_WarnExplicit*(category: ptr PyObject, message: cstring, filename: cstring, lineno: int, module: cstring, registry: ptr PyObject): int{.header: "Python.h", importc: "PyErr_WarnExplicit".}
proc PyErr_WarnFormat*(category: ptr PyObject, stack_level: Py_ssize_t, format: cstring): int{.header: "Python.h", importc: "PyErr_WarnFormat".}
proc PyErr_CheckSignals*(): int{.header: "Python.h", importc: "PyErr_CheckSignals".}
proc PyErr_SetInterrupt*(){.header: "Python.h", importc: "PyErr_SetInterrupt".}
proc PySignal_SetWakeupFd*(fd: int): int{.header: "Python.h", importc: "PySignal_SetWakeupFd".}
proc PyErr_NewException*(name: cstring, base: ptr PyObject, dict: ptr PyObject): ptr PyObject{.header: "Python.h", importc: "PyErr_NewException".}
proc PyErr_NewExceptionWithDoc*(name: cstring, doc: cstring, base: ptr PyObject, dict: ptr PyObject): ptr PyObject{.header: "Python.h", importc: "PyErr_NewExceptionWithDoc".}
proc PyErr_WriteUnraisable*(obj: ptr PyObject){.header: "Python.h", importc: "PyErr_WriteUnraisable".}
proc PyException_GetTraceback*(ex: ptr PyObject): ptr PyObject{.header: "Python.h", importc: "PyException_GetTraceback".}
proc PyException_SetTraceback*(ex: ptr PyObject, tb: ptr PyObject): int{.header: "Python.h", importc: "PyException_SetTraceback".}
proc PyException_GetContext*(ex: ptr PyObject): ptr PyObject{.header: "Python.h", importc: "PyException_GetContext".}
proc PyException_SetContext*(ex: ptr PyObject, ctx: ptr PyObject){.header: "Python.h", importc: "PyException_SetContext".}
proc PyException_GetCause*(ex: ptr PyObject): ptr PyObject{.header: "Python.h", importc: "PyException_GetCause".}
proc PyException_SetCause*(ex: ptr PyObject, cause: ptr PyObject){.header: "Python.h", importc: "PyException_SetCause".}
proc PyUnicodeDecodeError_Create*(encoding: cstring, obj: cstring, length: Py_ssize_t,start: Py_ssize_t, ending: Py_ssize_t, reason: cstring): ptr PyObject{.header: "Python.h", importc: "PyUnicodeDecodeError_Create".}
proc PyUnicodeEncodeError_Create*(encoding: cstring, obj: ptr PyUnicode, length: Py_ssize_t, start: Py_ssize_t, ending: Py_ssize_t,reason: cstring): ptr PyObject{.header: "Python.h", importc: "PyUnicodeEncodeError_Create".}
proc PyUnicodeTranslateError_Create*(obj: ptr PyUnicode, length: Py_ssize_t, start: Py_ssize_t, ending: Py_ssize_t, reason: cstring): ptr PyObject{.header: "Python.h", importc: "PyUnicodeTranslateError_Create".}
proc PyUnicodeDecodeError_GetEncoding*(exc: ptr PyObject): ptr PyObject{.header: "Python.h", importc: "PyUnicodeDecodeError_GetEncoding".}
proc PyUnicodeEncodeError_GetEncoding*(exc: ptr PyObject): ptr PyObject{.header: "Python.h", importc: "PyUnicodeEncodeError_GetEncoding".}
proc PyUnicodeDecodeError_GetObject*(exc: ptr PyObject): ptr PyObject{.header: "Python.h", importc: "PyUnicodeDecodeError_GetObject".}
proc PyUnicodeEncodeError_GetObject*(exc: ptr PyObject): ptr PyObject{.header: "Python.h", importc: "PyUnicodeEncodeError_GetObject".}
proc PyUnicodeTranslateError_GetObject*(exc: ptr PyObject): ptr PyObject{.header: "Python.h", importc: "PyUnicodeTranslateError_GetObject".}
proc PyUnicodeDecodeError_GetStart*(exc: ptr PyObject, start: ptr Py_ssize_t): int{.header: "Python.h", importc: "PyUnicodeDecodeError_GetStart".}
proc PyUnicodeEncodeError_GetStart*(exc: ptr PyObject, start: ptr Py_ssize_t): int{.header: "Python.h", importc: "PyUnicodeEncodeError_GetStart".}
proc PyUnicodeTranslateError_GetStart*(exc: ptr PyObject, start: ptr Py_ssize_t): int{.header: "Python.h", importc: "PyUnicodeTranslateError_GetStart".}
proc PyUnicodeDecodeError_SetStart*(exc: ptr PyObject, start: Py_ssize_t): int{.header: "Python.h", importc: "PyUnicodeDecodeError_SetStart".}
proc PyUnicodeEncodeError_SetStart*(exc: ptr PyObject, start: Py_ssize_t): int{.header: "Python.h", importc: "PyUnicodeEncodeError_SetStart".}
proc PyUnicodeTranslateError_SetStart*(exc: ptr PyObject, start: Py_ssize_t): int{.header: "Python.h", importc: "PyUnicodeTranslateError_SetStart".}
proc PyUnicodeDecodeError_GetEnd*(exc: ptr PyObject, ending: ptr Py_ssize_t): int{.header: "Python.h", importc: "PyUnicodeDecodeError_GetEnd".}
proc PyUnicodeEncodeError_GetEnd*(exc: ptr PyObject, ending: ptr Py_ssize_t): int{.header: "Python.h", importc: "PyUnicodeEncodeError_GetEnd".}
proc PyUnicodeTranslateError_GetEnd*(exc: ptr PyObject, ending: ptr Py_ssize_t): int{.header: "Python.h", importc: "PyUnicodeTranslateError_GetEnd".}
proc PyUnicodeDecodeError_SetEnd*(exc: ptr PyObject, ending: Py_ssize_t): int{.header: "Python.h", importc: "PyUnicodeDecodeError_SetEnd".}
proc PyUnicodeEncodeError_SetEnd*(exc: ptr PyObject, ending: Py_ssize_t): int{.header: "Python.h", importc: "PyUnicodeEncodeError_SetEnd".}
proc PyUnicodeTranslateError_SetEnd*(exc: ptr PyObject, ending: Py_ssize_t): int{.header: "Python.h", importc: "PyUnicodeTranslateError_SetEnd".}
proc PyUnicodeDecodeError_GetReason*(exc: ptr PyObject): ptr PyObject{.header: "Python.h", importc: "PyUnicodeDecodeError_GetReason".}
proc PyUnicodeEncodeError_GetReason*(exc: ptr PyObject): ptr PyObject{.header: "Python.h", importc: "PyUnicodeEncodeError_GetReason".}
proc PyUnicodeTranslateError_GetReason*(exc: ptr PyObject): ptr PyObject{.header: "Python.h", importc: "PyUnicodeTranslateError_GetReason".}
proc PyUnicodeDecodeError_SetReason*(exc: ptr PyObject, reason: cstring): int{.header: "Python.h", importc: "PyUnicodeDecodeError_SetReason".}
proc PyUnicodeEncodeError_SetReason*(exc: ptr PyObject, reason: cstring): int{.header: "Python.h", importc: "PyUnicodeEncodeError_SetReason".}
proc PyUnicodeTranslateError_SetReason*(exc: ptr PyObject, reason: cstring): int{.header: "Python.h", importc: "PyUnicodeTranslateError_SetReason".}
proc Py_EnterRecursiveCall*(where: cstring): int{.header: "Python.h", importc: "Py_EnterRecursiveCall".}
proc Py_LeaveRecursiveCall*(){.header: "Python.h", importc: "Py_LeaveRecursiveCall".}
proc Py_ReprEnter*(obj: ptr PyObject): int{.header: "Python.h", importc: "Py_ReprEnter".}
proc Py_ReprLeave*(obj: ptr PyObject){.header: "Python.h", importc: "Py_ReprLeave".}
proc PyOS_AfterFork*(){.header: "Python.h", importc: "PyOS_AfterFork".}
proc PyOS_CheckStack*(): cint{.header: "Python.h", importc: "PyOS_CheckStack".}
proc PyOS_getsig*(i: cint): PyosSighandler{.header: "Python.h", importc: "PyOS_getsig".}
proc PyOS_setsig*(i: cint, h: PyosSighandler): PyosSighandler{.header: "Python.h", importc: "PyOS_setsig".}
proc PySys_GetObject*(name: cstring): ptr PyObject{.header: "Python.h", importc: "PySys_GetObject".}
proc PySys_SetObject*(name: cstring; v: ptr PyObject): cint{.header: "Python.h", importc: "PySys_SetObject".}
proc PySys_ResetWarnOptions*(){.header: "Python.h", importc: "PySys_ResetWarnOptions".}
proc PySys_AddWarnOption*(s: ptr WideCString){.header: "Python.h", importc: "PySys_AddWarnOption".}
proc PySys_AddWarnOptionUnicode*(unicode: ptr PyObject){.header: "Python.h", importc: "PySys_AddWarnOptionUnicode".}
proc PySys_SetPath*(path: ptr WideCString){.header: "Python.h", importc: "PySys_SetPath".}
proc PySys_WriteStdout*(format: cstring){.header: "Python.h", importc: "PySys_WriteStdout".}
proc PySys_WriteStderr*(format: cstring){.header: "Python.h", importc: "PySys_WriteStderr".}
proc PySys_FormatStdout*(format: cstring){.header: "Python.h", importc: "PySys_FormatStdout".}
proc PySys_FormatStderr*(format: cstring){.header: "Python.h", importc: "PySys_FormatStderr".}
proc PySys_AddXOption*(s: ptr WideCString){.header: "Python.h", importc: "PySys_AddXOption".}
proc PySys_GetXOptions*(): ptr PyObject{.header: "Python.h", importc: "PySys_GetXOptions".}
proc Py_FatalError*(message: cstring){.header: "Python.h", importc: "Py_FatalError".}
proc Py_Exit*(status: cint){.header: "Python.h", importc: "Py_Exit".}
proc Py_AtExit*(fun: proc (){.cdecl.}){.header: "Python.h", importc: "Py_AtExit".}
proc PyRun_AnyFile*(fp: File, filename: cstring): int{.header: "Python.h", importc: "PyRun_AnyFile".}
proc PyRun_AnyFileFlags*(fp: File, filename: cstring, flags: PyCompilerFlags): int{.header: "Python.h", importc: "PyRun_AnyFileFlags".}
proc PyRun_File*(fp: File, filename: cstring, start: int, globals: ptr PyObject, locals: ptr PyObject): ptr PyObject{.header: "Python.h", importc: "PyRun_File".}
proc PyRun_FileFlags*(fp: File, filename: cstring, start: int, globals: ptr PyObject, locals: ptr PyObject,flags: PyCompilerFlags): ptr PyObject{.header: "Python.h", importc: "PyRun_FileFlags".}
proc PyRun_AnyFileEx*(fp: File, filename: cstring, closeit: int): int{.header: "Python.h", importc: "PyRun_AnyFileEx".}
proc PyRun_AnyFileExFlags*(fp: File, filename: cstring, closeit: int, flags: PyCompilerFlags): int{.header: "Python.h", importc: "PyRun_AnyFileExFlags".}
proc PyRun_SimpleFile*(fp: File, filename: cstring): int{.header: "Python.h", importc: "PyRun_SimpleFile".}
proc PyRun_SimpleFileEx*(fp: File, filename: cstring, closeit: int): int{.header: "Python.h", importc: "PyRun_SimpleFileEx".}
proc PyRun_SimpleFileExFlags*(fp: File, filename: cstring, closeit: int, flags: PyCompilerFlags): int{.header: "Python.h", importc: "PyRun_SimpleFileExFlags".}
proc PyParser_SimpleParseFile*(fp: File, filename: cstring, start: int): ptr PyNode{.header: "Python.h", importc: "PyParser_SimpleParseFile".}
proc PyParser_SimpleParseFileFlags*(fp: File, filename: cstring, start: int, flags: int): ptr PyNode{.header: "Python.h", importc: "PyParser_SimpleParseFileFlags".}
proc PyRun_FileEx*(fp: File, filename: cstring, start: int, globals: ptr PyObject, locals: ptr PyObject, closeit: int): ptr PyObject{.header: "Python.h", importc: "PyRun_FileEx".}
proc PyRun_FileExFlags*(fp: File, filename: cstring, start: int, globals: ptr PyObject, locals: ptr PyObject, closeit: int,flags: PyCompilerFlags): ptr PyObject{.header: "Python.h", importc: "PyRun_FileExFlags".}
proc PyRun_InteractiveOne*(fp: File, filename: cstring): int{.header: "Python.h", importc: "PyRun_InteractiveOne".}
proc PyRun_InteractiveOneFlags*(fp: File, filename: cstring, flags: PyCompilerFlags): int{.header: "Python.h", importc: "PyRun_InteractiveOneFlags".}
proc PyRun_InteractiveLoop*(fp: File, filename: cstring): int{.header: "Python.h", importc: "PyRun_InteractiveLoop".}
proc PyRun_InteractiveLoopFlags*(fp: File, filename: cstring, flags: PyCompilerFlags): int{.header: "Python.h", importc: "PyRun_InteractiveLoopFlags".}
proc Py_FdIsInteractive*(fp: File; filename: cstring): cint{.header: "Python.h", importc: "Py_FdIsInteractive".}
proc PyImport_ImportModule*(name: cstring): ptr PyObject {.header: "Python.h", importc: "PyImport_ImportModule".}
proc PyImport_ImportModuleNoBlock*(name: cstring): ptr PyObject {.header: "Python.h", importc: "PyImport_ImportModuleNoBlock".}
proc PyImport_ImportModuleEx*(name: cstring; globals: ptr PyObject; locals: ptr PyObject; fromlist: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyImport_ImportModuleEx".}
proc PyImport_ImportModuleLevelObject*(name: ptr PyObject; globals: ptr PyObject; locals: ptr PyObject; fromlist: ptr PyObject; level: cint): ptr PyObject {.header: "Python.h", importc: "PyImport_ImportModuleLevelObject".}
proc PyImport_ImportModuleLevel*(name: cstring; globals: ptr PyObject; locals: ptr PyObject; fromlist: ptr PyObject; level: cint): ptr PyObject {.header: "Python.h", importc: "PyImport_ImportModuleLevel".}
proc PyImport_Import*(name: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyImport_Import".}
proc PyImport_ReloadModule*(m: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyImport_ReloadModule".}
proc PyImport_AddModuleObject*(name: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyImport_AddModuleObject".}
proc PyImport_AddModule*(name: cstring): ptr PyObject {.header: "Python.h", importc: "PyImport_AddModule".}
proc PyImport_ExecCodeModule*(name: cstring; co: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyImport_ExecCodeModule".}
proc PyImport_ExecCodeModuleEx*(name: cstring; co: ptr PyObject; pathname: cstring): ptr PyObject {.header: "Python.h", importc: "PyImport_ExecCodeModuleEx".}
proc PyImport_ExecCodeModuleObject*(name: ptr PyObject; co: ptr PyObject; pathname: ptr PyObject; cpathname: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyImport_ExecCodeModuleObject".}
proc PyImport_ExecCodeModuleWithPathnames*(name: cstring; co: ptr PyObject; pathname: cstring; cpathname: cstring): ptr PyObject {.header: "Python.h", importc: "PyImport_ExecCodeModuleWithPathnames".}
proc PyImport_GetMagicNumber*(): clong {.header: "Python.h", importc: "PyImport_GetMagicNumber".}
proc PyImport_GetMagicTag*(): cstring {.header: "Python.h", importc: "PyImport_GetMagicTag".}
proc PyImport_GetModuleDict*(): ptr PyObject {.header: "Python.h", importc: "PyImport_GetModuleDict".}
proc PyImport_GetImporter*(path: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyImport_GetImporter".}
proc PyImport_Init*() {.header: "Python.h", importc: "_PyImport_Init".}
proc PyImport_Cleanup*() {.header: "Python.h", importc: "PyImport_Cleanup".}
proc PyImport_Fini*() {.header: "Python.h", importc: "_PyImport_Fini".}
proc PyImport_FindExtension*(arg0: cstring; arg1: cstring): ptr PyObject {.header: "Python.h", importc: "_PyImport_FindExtension".}
proc PyImport_ImportFrozenModuleObject*(name: ptr PyObject): cint {.header: "Python.h", importc: "PyImport_ImportFrozenModuleObject".}
proc PyImport_ImportFrozenModule*(name: cstring): cint {.header: "Python.h", importc: "PyImport_ImportFrozenModule".}
proc PyImport_AppendInitTab*(name: cstring; initfunc: proc (){.cdecl.}): ptr PyObject {.header: "Python.h", importc: "PyImport_AppendInitTab".}
proc PyImport_ExtendInitTab*(newtab: ptr inittab): cint {.header: "Python.h", importc: "PyImport_ExtendInitTab".}
proc PyMarshal_WriteLongToFile*(value: clong; file: File; version: cint) {.header: "Python.h", importc: "PyMarshal_WriteLongToFile".}
proc PyMarshal_WriteObjectToFile*(value: ptr PyObject; file: File; version: cint) {.header: "Python.h", importc: "PyMarshal_WriteObjectToFile".}
proc PyMarshal_WriteObjectToString*(value: ptr PyObject; version: cint): ptr PyObject {.header: "Python.h", importc: "PyMarshal_WriteObjectToString".}
proc PyMarshal_ReadLongFromFile*(file: File): clong {.header: "Python.h", importc: "PyMarshal_ReadLongFromFile".}
proc PyMarshal_ReadShortFromFile*(file: File): cint {.header: "Python.h", importc: "PyMarshal_ReadShortFromFile".}
proc PyMarshal_ReadObjectFromFile*(file: File): ptr PyObject {.header: "Python.h", importc: "PyMarshal_ReadObjectFromFile".}
proc PyMarshal_ReadLastObjectFromFile*(file: File): ptr PyObject {.header: "Python.h", importc: "PyMarshal_ReadLastObjectFromFile".}
proc PyMarshal_ReadObjectFromString*(string: cstring; lenght: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PyMarshal_ReadObjectFromString".}
proc PyArg_ParseTuple*(args: ptr PyObject; format: cstring): cint {.header: "Python.h", importc: "PyArg_ParseTuple", varargs.}
proc PyArg_VaParse*(args: ptr PyObject; format: cstring; vargs: varargs): cint {.header: "Python.h", importc: "PyArg_VaParse".}
proc PyArg_ParseTupleAndKeywords*(args: ptr PyObject; kw: ptr PyObject; format: cstring; keywords: ptr cstring): cint {.header: "Python.h", importc: "PyArg_ParseTupleAndKeywords", varargs.}
proc PyArg_VaParseTupleAndKeywords*(args: ptr PyObject; kw: ptr PyObject; format: cstring; keywords: ptr cstring; vargs: varargs): cint {.header: "Python.h", importc: "PyArg_VaParseTupleAndKeywords".}
proc PyArg_ValidateKeywordArguments*(arg: ptr PyObject): cint {.header: "Python.h", importc: "PyArg_ValidateKeywordArguments".}
proc PyArg_Parse*(args: ptr PyObject; format: cstring): cint {.header: "Python.h", importc: "PyArg_Parse", varargs.}
proc PyArg_UnpackTuple*(args: ptr PyObject; name: cstring; min: Py_ssize_t; max: Py_ssize_t): cint {.header: "Python.h", importc: "PyArg_UnpackTuple", varargs.}
proc Py_BuildValue*(format: cstring): ptr PyObject {.header: "Python.h", importc: "Py_BuildValue", varargs.}
proc Py_VaBuildValue*(format: cstring; vargs: varargs): ptr PyObject {.header: "Python.h", importc: "Py_VaBuildValue".}
proc PyOS_snprintf*(str: cstring; size: csize; format: cstring): cint {.header: "Python.h", importc: "PyOS_snprintf", varargs.}
proc PyOS_vsnprintf*(str: cstring; size: csize; format: cstring; va: varargs): cint {.header: "Python.h", importc: "PyOS_vsnprintf".}
proc PyOS_string_to_double*(s: cstring; endptr: cstringArray; overflow_exception: ptr PyObject): cdouble {.header: "Python.h", importc: "PyOS_string_to_double".}
proc PyOS_double_to_string*(val: cdouble; format_code: char; precision: cint; flags: cint; ptype: ptr cint): cstring {.header: "Python.h", importc: "PyOS_double_to_string".}
proc PyOS_stricmp*(s1: cstring; s2: cstring): cint {.header: "Python.h", importc: "PyOS_stricmp".}
proc PyOS_strnicmp*(s1: cstring; s2: cstring; size: Py_ssize_t): cint {.header: "Python.h", importc: "PyOS_strnicmp".}
proc PyEval_GetBuiltins*(): ptr PyObject {.header: "Python.h", importc: "PyEval_GetBuiltins".}
proc PyEval_GetLocals*(): ptr PyObject {.header: "Python.h", importc: "PyEval_GetLocals".}
proc PyEval_GetGlobals*(): ptr PyObject {.header: "Python.h", importc: "PyEval_GetGlobals".}
proc PyEval_GetFrame*(): ptr PyFrameObject {.header: "Python.h", importc: "PyEval_GetFrame".}
proc PyFrame_GetLineNumber*(frame: ptr PyFrameObject): cint {.header: "Python.h", importc: "PyFrame_GetLineNumber".}
proc PyEval_GetFuncName*(fun: ptr PyObject): cstring {.header: "Python.h", importc: "PyEval_GetFuncName".}
proc PyEval_GetFuncDesc*(fun: ptr PyObject): cstring {.header: "Python.h", importc: "PyEval_GetFuncDesc".}
proc PyCodec_Register*(search_function: ptr PyObject): cint {.header: "Python.h", importc: "PyCodec_Register".}
proc PyCodec_KnownEncoding*(encoding: cstring): cint {.header: "Python.h", importc: "PyCodec_KnownEncoding".}
proc PyCodec_Encode*(obj: ptr PyObject; encoding: cstring;errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyCodec_Encode".}
proc PyCodec_Decode*(obj: ptr PyObject; encoding: cstring;errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyCodec_Decode".}
proc PyCodec_Encoder*(encoding: cstring): ptr PyObject {.header: "Python.h", importc: "PyCodec_Encoder".}
proc PyCodec_IncrementalEncoder*(encoding: cstring; errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyCodec_IncrementalEncoder".}
proc PyCodec_IncrementalDecoder*(encoding: cstring; errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyCodec_IncrementalDecoder".}
proc PyCodec_StreamReader*(encoding: cstring; stream: ptr PyObject;errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyCodec_StreamReader".}
proc PyCodec_StreamWriter*(encoding: cstring; stream: ptr PyObject;errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyCodec_StreamWriter".}
proc PyCodec_RegisterError*(name: cstring; error: ptr PyObject): cint {.header: "Python.h", importc: "PyCodec_RegisterError".}
proc PyCodec_LookupError*(name: cstring): ptr PyObject {.header: "Python.h", importc: "PyCodec_LookupError".}
proc PyCodec_StrictErrors*(exc: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyCodec_StrictErrors".}
proc PyCodec_IgnoreErrors*(exc: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyCodec_IgnoreErrors".}
proc PyCodec_ReplaceErrors*(exc: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyCodec_ReplaceErrors".}
proc PyCodec_XMLCharRefReplaceErrors*(exc: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyCodec_XMLCharRefReplaceErrors".}
proc PyCodec_BackslashReplaceErrors*(exc: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyCodec_BackslashReplaceErrors".}
proc PyObject_Print*(o: ptr PyObject; fp: File; flags: cint): cint {.header: "Python.h", importc: "PyObject_Print".}
proc PyObject_HasAttr*(o: ptr PyObject; attr_name: ptr PyObject): cint {.header: "Python.h", importc: "PyObject_HasAttr".}
proc PyObject_HasAttrString*(o: ptr PyObject; attr_name: cstring): cint {.header: "Python.h", importc: "PyObject_HasAttrString".}
proc PyObject_GetAttr*(o: ptr PyObject; attr_name: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyObject_GetAttr".}
proc PyObject_GetAttrString*(o: ptr PyObject; attr_name: cstring): ptr PyObject {.header: "Python.h", importc: "PyObject_GetAttrString".}
proc PyObject_GenericGetAttr*(o: ptr PyObject; name: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyObject_GenericGetAttr".}
proc PyObject_SetAttr*(o: ptr PyObject; attr_name: ptr PyObject;v: ptr PyObject): cint {.header: "Python.h", importc: "PyObject_SetAttr".}
proc PyObject_SetAttrString*(o: ptr PyObject; attr_name: cstring;v: ptr PyObject): cint {.header: "Python.h", importc: "PyObject_SetAttrString".}
proc PyObject_GenericSetAttr*(o: ptr PyObject; name: ptr PyObject;value: ptr PyObject): cint {.header: "Python.h", importc: "PyObject_GenericSetAttr".}
proc PyObject_DelAttr*(o: ptr PyObject; attr_name: ptr PyObject): cint {.header: "Python.h", importc: "PyObject_DelAttr".}
proc PyObject_DelAttrString*(o: ptr PyObject; attr_name: cstring): cint {.header: "Python.h", importc: "PyObject_DelAttrString".}
proc PyObject_GenericGetDict*(o: ptr PyObject; context: pointer): ptr PyObject {.header: "Python.h", importc: "PyObject_GenericGetDict".}
proc PyObject_GenericSetDict*(o: ptr PyObject; context: pointer): cint {.header: "Python.h", importc: "PyObject_GenericSetDict".}
proc PyObject_RichCompare*(o1: ptr PyObject; o2: ptr PyObject;opid: cint): ptr PyObject {.header: "Python.h", importc: "PyObject_RichCompare".}
proc PyObject_RichCompareBool*(o1: ptr PyObject; o2: ptr PyObject; opid: cint): cint {.header: "Python.h", importc: "PyObject_RichCompareBool".}
proc PyObject_Repr*(o: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyObject_Repr".}
proc PyObject_ASCII*(o: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyObject_ASCII".}
proc PyObject_Str*(o: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyObject_Str".}
proc PyObject_Bytes*(o: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyObject_Bytes".}
proc PyObject_IsSubclass*(derived: ptr PyObject; cls: ptr PyObject): cint {.header: "Python.h", importc: "PyObject_IsSubclass".}
proc PyObject_IsInstance*(inst: ptr PyObject; cls: ptr PyObject): cint {.header: "Python.h", importc: "PyObject_IsInstance".}
proc PyCallable_Check*(o: ptr PyObject): cint {.header: "Python.h", importc: "PyCallable_Check".}
proc PyObject_Call*(callable_object: ptr PyObject; args: ptr PyObject;kw: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyObject_Call".}
proc PyObject_CallObject*(callable_object: ptr PyObject;args: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyObject_CallObject".}
proc PyObject_CallFunction*(callable: ptr PyObject; format: cstring): ptr PyObject {.header: "Python.h", importc: "PyObject_CallFunction", varargs.}
proc PyObject_CallMethod*(o: ptr PyObject; meth: cstring;format: cstring): ptr PyObject {.header: "Python.h", importc: "PyObject_CallMethod", varargs.}
proc PyObject_CallFunctionObjArgs*(callable: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyObject_CallFunctionObjArgs", varargs.}
proc PyObject_CallMethodObjArgs*(o: ptr PyObject; name: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyObject_CallMethodObjArgs", varargs.}
proc PyObject_Hash*(o: ptr PyObject): Py_hash_t {.header: "Python.h", importc: "PyObject_Hash".}
proc PyObject_HashNotImplemented*(o: ptr PyObject): Py_hash_t {.header: "Python.h", importc: "PyObject_HashNotImplemented".}
proc PyObject_IsTrue*(o: ptr PyObject): cint {.header: "Python.h", importc: "PyObject_IsTrue".}
proc PyObject_Not*(o: ptr PyObject): cint {.header: "Python.h", importc: "PyObject_Not".}
proc PyObject_Type*(o: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyObject_Type".}
proc PyObject_Length*(o: ptr PyObject): Py_ssize_t {.header: "Python.h", importc: "PyObject_Length".}
proc PyObject_Size*(o: ptr PyObject): Py_ssize_t {.header: "Python.h", importc: "PyObject_Size".}
proc PyObject_LengthHint*(o: ptr PyObject; default: Py_ssize_t): Py_ssize_t {.header: "Python.h", importc: "PyObject_LengthHint".}
proc PyObject_GetItem*(o: ptr PyObject; key: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyObject_GetItem".}
proc PyObject_SetItem*(o: ptr PyObject; key: ptr PyObject; v: ptr PyObject): cint {.header: "Python.h", importc: "PyObject_SetItem".}
proc PyObject_DelItem*(o: ptr PyObject; key: ptr PyObject): cint {.header: "Python.h", importc: "PyObject_DelItem".}
proc PyObject_Dir*(o: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyObject_Dir".}
proc PyObject_GetIter*(o: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyObject_GetIter".}
proc PyNumber_Check*(o: ptr PyObject): cint {.header: "Python.h", importc: "PyNumber_Check".}
proc PyNumber_Add*(o1: ptr PyObject; o2: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_Add".}
proc PyNumber_Subtract*(o1: ptr PyObject; o2: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_Subtract".}
proc PyNumber_Multiply*(o1: ptr PyObject; o2: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_Multiply".}
proc PyNumber_FloorDivide*(o1: ptr PyObject; o2: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_FloorDivide".}
proc PyNumber_TrueDivide*(o1: ptr PyObject; o2: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_TrueDivide".}
proc PyNumber_Remainder*(o1: ptr PyObject; o2: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_Remainder".}
proc PyNumber_Divmod*(o1: ptr PyObject; o2: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_Divmod".}
proc PyNumber_Power*(o1: ptr PyObject; o2: ptr PyObject;o3: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_Power".}
proc PyNumber_Negative*(o: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_Negative".}
proc PyNumber_Positive*(o: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_Positive".}
proc PyNumber_Absolute*(o: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_Absolute".}
proc PyNumber_Invert*(o: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_Invert".}
proc PyNumber_Lshift*(o1: ptr PyObject; o2: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_Lshift".}
proc PyNumber_Rshift*(o1: ptr PyObject; o2: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_Rshift".}
proc PyNumber_And*(o1: ptr PyObject; o2: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_And".}
proc PyNumber_Xor*(o1: ptr PyObject; o2: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_Xor".}
proc PyNumber_Or*(o1: ptr PyObject; o2: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_Or".}
proc PyNumber_InPlaceAdd*(o1: ptr PyObject; o2: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_InPlaceAdd".}
proc PyNumber_InPlaceSubtract*(o1: ptr PyObject; o2: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_InPlaceSubtract".}
proc PyNumber_InPlaceMultiply*(o1: ptr PyObject; o2: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_InPlaceMultiply".}
proc PyNumber_InPlaceFloorDivide*(o1: ptr PyObject; o2: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_InPlaceFloorDivide".}
proc PyNumber_InPlaceTrueDivide*(o1: ptr PyObject; o2: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_InPlaceTrueDivide".}
proc PyNumber_InPlaceRemainder*(o1: ptr PyObject; o2: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_InPlaceRemainder".}
proc PyNumber_InPlacePower*(o1: ptr PyObject; o2: ptr PyObject;o3: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_InPlacePower".}
proc PyNumber_InPlaceLshift*(o1: ptr PyObject; o2: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_InPlaceLshift".}
proc PyNumber_InPlaceRshift*(o1: ptr PyObject; o2: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_InPlaceRshift".}
proc PyNumber_InPlaceAnd*(o1: ptr PyObject; o2: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_InPlaceAnd".}
proc PyNumber_InPlaceXor*(o1: ptr PyObject; o2: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_InPlaceXor".}
proc PyNumber_InPlaceOr*(o1: ptr PyObject; o2: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_InPlaceOr".}
proc PyNumber_Long*(o: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_Long".}
proc PyNumber_Float*(o: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_Float".}
proc PyNumber_Index*(o: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyNumber_Index".}
proc PyNumber_ToBase*(n: ptr PyObject; base: cint): ptr PyObject {.header: "Python.h", importc: "PyNumber_ToBase".}
proc PyNumber_AsSsize_t*(o: ptr PyObject; exc: ptr PyObject): Py_ssize_t {.header: "Python.h", importc: "PyNumber_AsSsize_t".}
proc PyIndex_Check*(o: ptr PyObject): cint {.header: "Python.h", importc: "PyIndex_Check".}
proc PySequence_Check*(o: ptr PyObject): cint {.header: "Python.h", importc: "PySequence_Check".}
proc PySequence_Size*(o: ptr PyObject): Py_ssize_t {.header: "Python.h", importc: "PySequence_Size".}
proc PySequence_Length*(o: ptr PyObject): Py_ssize_t {.header: "Python.h", importc: "PySequence_Length".}
proc PySequence_Concat*(o1: ptr PyObject; o2: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PySequence_Concat".}
proc PySequence_Repeat*(o: ptr PyObject; count: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PySequence_Repeat".}
proc PySequence_InPlaceConcat*(o1: ptr PyObject; o2: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PySequence_InPlaceConcat".}
proc PySequence_InPlaceRepeat*(o: ptr PyObject; count: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PySequence_InPlaceRepeat".}
proc PySequence_GetItem*(o: ptr PyObject; i: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PySequence_GetItem".}
proc PySequence_GetSlice*(o: ptr PyObject; i1: Py_ssize_t; i2: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PySequence_GetSlice".}
proc PySequence_SetItem*(o: ptr PyObject; i: Py_ssize_t; v: ptr PyObject): cint {.header: "Python.h", importc: "PySequence_SetItem".}
proc PySequence_DelItem*(o: ptr PyObject; i: Py_ssize_t): cint {.header: "Python.h", importc: "PySequence_DelItem".}
proc PySequence_SetSlice*(o: ptr PyObject; i1: Py_ssize_t; i2: Py_ssize_t;v: ptr PyObject): cint {.header: "Python.h", importc: "PySequence_SetSlice".}
proc PySequence_DelSlice*(o: ptr PyObject; i1: Py_ssize_t; i2: Py_ssize_t): cint {.header: "Python.h", importc: "PySequence_DelSlice".}
proc PySequence_Count*(o: ptr PyObject; value: ptr PyObject): Py_ssize_t {.header: "Python.h", importc: "PySequence_Count".}
proc PySequence_Contains*(o: ptr PyObject; value: ptr PyObject): cint {.header: "Python.h", importc: "PySequence_Contains".}
proc PySequence_Index*(o: ptr PyObject; value: ptr PyObject): Py_ssize_t {.header: "Python.h", importc: "PySequence_Index".}
proc PySequence_List*(o: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PySequence_List".}
proc PySequence_Tuple*(o: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PySequence_Tuple".}
proc PySequence_Fast*(o: ptr PyObject; m: cstring): ptr PyObject {.header: "Python.h", importc: "PySequence_Fast".}
proc PySequence_Fast_GET_ITEM*(o: ptr PyObject; i: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PySequence_Fast_GET_ITEM", cdecl.}
proc PySequence_Fast_ITEMS*(o: ptr PyObject): ptr ptr PyObject {.header: "Python.h", importc: "PySequence_Fast_ITEMS", cdecl.}
proc PySequence_ITEM*(o: ptr PyObject; i: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PySequence_ITEM", cdecl.}
proc PySequence_Fast_GET_SIZE*(o: ptr PyObject): Py_ssize_t {.header: "Python.h", importc: "PySequence_Fast_GET_SIZE", cdecl.}
proc PyMapping_Check*(o: ptr PyObject): cint {.header: "Python.h", importc: "PyMapping_Check".}
proc PyMapping_Size*(o: ptr PyObject): Py_ssize_t {.header: "Python.h", importc: "PyMapping_Size".}
proc PyMapping_Length*(o: ptr PyObject): Py_ssize_t {.header: "Python.h", importc: "PyMapping_Length".}
proc PyMapping_DelItemString*(o: ptr PyObject; key: cstring): cint {.header: "Python.h", importc: "PyMapping_DelItemString".}
proc PyMapping_DelItem*(o: ptr PyObject; key: ptr PyObject): cint {.header: "Python.h", importc: "PyMapping_DelItem".}
proc PyMapping_HasKeyString*(o: ptr PyObject; key: cstring): cint {.header: "Python.h", importc: "PyMapping_HasKeyString".}
proc PyMapping_HasKey*(o: ptr PyObject; key: ptr PyObject): cint {.header: "Python.h", importc: "PyMapping_HasKey".}
proc PyMapping_Keys*(o: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyMapping_Keys".}
proc PyMapping_Values*(o: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyMapping_Values".}
proc PyMapping_Items*(o: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyMapping_Items".}
proc PyMapping_GetItemString*(o: ptr PyObject; key: cstring): ptr PyObject {.header: "Python.h", importc: "PyMapping_GetItemString".}
proc PyMapping_SetItemString*(o: ptr PyObject; key: cstring; v: ptr PyObject): cint {.header: "Python.h", importc: "PyMapping_SetItemString".}
proc PyIter_Check*(o: ptr PyObject): cint {.header: "Python.h", importc: "PyIter_Check".}
proc PyIter_Next*(o: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyIter_Next".}
proc PyObject_CheckBuffer*(obj: ptr PyObject): cint {.header: "Python.h", importc: "PyObject_CheckBuffer".}
proc PyObject_GetBuffer*(exporter: ptr PyObject; view: ptr PyBuffer;flags: cint): cint {.header: "Python.h", importc: "PyObject_GetBuffer".}
proc PyBuffer_Release*(view: ptr PyBuffer) {.header: "Python.h", importc: "PyBuffer_Release".}
proc PyBuffer_SizeFromFormat*(arg: cstring): Py_ssize_t {.header: "Python.h", importc: "PyBuffer_SizeFromFormat".}
proc PyBuffer_IsContiguous*(view: ptr PyBuffer; order: char): cint {.header: "Python.h", importc: "PyBuffer_IsContiguous".}
proc PyBuffer_FillContiguousStrides*(ndim: cint; shape: ptr Py_ssize_t;strides: ptr Py_ssize_t; itemsize: Py_ssize_t; order: char) {.header: "Python.h", importc: "PyBuffer_FillContiguousStrides".}
proc PyBuffer_FillInfo*(view: ptr PyBuffer; exporter: ptr PyObject; buf: pointer;len: Py_ssize_t; readonly: cint; flags: cint): cint {.header: "Python.h", importc: "PyBuffer_FillInfo".}
proc PyType_Check*(o: ptr PyObject): cint {.header: "Python.h", importc: "PyType_Check".}
proc PyType_CheckExact*(o: ptr PyObject): cint {.header: "Python.h", importc: "PyType_CheckExact".}
proc PyType_ClearCache*(): cuint {.header: "Python.h", importc: "PyType_ClearCache".}
proc PyType_GetFlags*(typ: ptr PyTypeObject): clong {.header: "Python.h", importc: "PyType_GetFlags".}
proc PyType_Modified*(typ: ptr PyTypeObject) {.header: "Python.h", importc: "PyType_Modified".}
proc PyType_HasFeature*(o: ptr PyTypeObject; feature: cint): cint {.header: "Python.h", importc: "PyType_HasFeature".}
proc PyType_IS_GC*(o: ptr PyTypeObject): cint {.header: "Python.h", importc: "PyType_IS_GC", cdecl.}
proc PyType_IsSubtype*(a: ptr PyTypeObject; b: ptr PyTypeObject): cint {.header: "Python.h", importc: "PyType_IsSubtype".}
proc PyType_GenericAlloc*(typ: ptr PyTypeObject; nitems: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PyType_GenericAlloc".}
proc PyType_GenericNew*(typ: ptr PyTypeObject; args: ptr PyObject;kwds: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyType_GenericNew".}
proc PyType_Ready*(typ: ptr PyTypeObject): cint {.header: "Python.h", importc: "PyType_Ready".}
proc PyType_FromSpec*(spec: ptr PyTypeSpec): ptr PyObject {.header: "Python.h", importc: "PyType_FromSpec".}
proc PyType_FromSpecWithBases*(spec: ptr PyTypeSpec;bases: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyType_FromSpecWithBases".}
proc PyType_GetSlot*(typ: ptr PyTypeObject; slot: cint): pointer {.header: "Python.h", importc: "PyType_GetSlot".}
proc PyLong_FromLong*(v: clong): ptr PyObject {.header: "Python.h", importc: "PyLong_FromLong".}
proc PyLong_FromUnsignedLong*(v: culong): ptr PyObject {.header: "Python.h", importc: "PyLong_FromUnsignedLong".}
proc PyLong_FromSsize_t*(v: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PyLong_FromSsize_t".}
proc PyLong_FromSize_t*(v: csize): ptr PyObject {.header: "Python.h", importc: "PyLong_FromSize_t".}
proc PyLong_FromDouble*(v: cdouble): ptr PyObject {.header: "Python.h", importc: "PyLong_FromDouble".}
proc PyLong_FromString*(str: cstring; pend: cstringArray; base: cint): ptr PyObject {.header: "Python.h", importc: "PyLong_FromString".}
proc PyLong_FromUnicode*(u: ptr PyUnicode; length: Py_ssize_t;base: cint): ptr PyObject {.header: "Python.h", importc: "PyLong_FromUnicode".}
proc PyLong_FromUnicodeObject*(u: ptr PyObject; base: cint): ptr PyObject {.header: "Python.h", importc: "PyLong_FromUnicodeObject".}
proc PyLong_FromVoidPtr*(p: pointer): ptr PyObject {.header: "Python.h", importc: "PyLong_FromVoidPtr".}
proc PyLong_AsLong*(obj: ptr PyObject): clong {.header: "Python.h", importc: "PyLong_AsLong".}
proc PyLong_AsLongAndOverflow*(obj: ptr PyObject; overflow: ptr cint): clong {.header: "Python.h", importc: "PyLong_AsLongAndOverflow".}
proc PyLong_AsLongLong*(obj: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyLong_AsLongLong".}
proc PyLong_AsLongLongAndOverflow*(obj: ptr PyObject;overflow: ptr cint): ptr PyObject {.header: "Python.h", importc: "PyLong_AsLongLongAndOverflow".}
proc PyLong_AsSsize_t*(pylong: ptr PyObject): Py_ssize_t {.header: "Python.h", importc: "PyLong_AsSsize_t".}
proc PyLong_AsUnsignedLong*(pylong: ptr PyObject): culong {.header: "Python.h", importc: "PyLong_AsUnsignedLong".}
proc PyLong_AsSize_t*(pylong: ptr PyObject): csize {.header: "Python.h", importc: "PyLong_AsSize_t".}
proc PyLong_AsUnsignedLongLong*(pylong: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyLong_AsUnsignedLongLong".}
proc PyLong_AsUnsignedLongMask*(obj: ptr PyObject): culong {.header: "Python.h", importc: "PyLong_AsUnsignedLongMask".}
proc PyLong_AsUnsignedLongLongMask*(obj: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyLong_AsUnsignedLongLongMask".}
proc PyLong_AsDouble*(pylong: ptr PyObject): cdouble {.header: "Python.h", importc: "PyLong_AsDouble".}
proc PyLong_AsVoidPtr*(pylong: ptr PyObject): pointer {.header: "Python.h", importc: "PyLong_AsVoidPtr".}
proc PyBool_Check*(o: ptr PyObject): cint {.header: "Python.h", importc: "PyBool_Check".}
proc PyBool_FromLong*(v: clong): ptr PyObject {.header: "Python.h", importc: "PyBool_FromLong".}
proc PyFloat_Check*(p: ptr PyObject): cint {.header: "Python.h", importc: "PyFloat_Check".}
proc PyFloat_CheckExact*(p: ptr PyObject): cint {.header: "Python.h", importc: "PyFloat_CheckExact".}
proc PyFloat_FromString*(str: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyFloat_FromString".}
proc PyFloat_FromDouble*(v: cdouble): ptr PyObject {.header: "Python.h", importc: "PyFloat_FromDouble".}
proc PyFloat_AsDouble*(pyfloat: ptr PyObject): cdouble {.header: "Python.h", importc: "PyFloat_AsDouble".}
proc PyFloat_GetInfo*(): ptr PyObject {.header: "Python.h", importc: "PyFloat_GetInfo".}
proc PyFloat_GetMax*(): cdouble {.header: "Python.h", importc: "PyFloat_GetMax".}
proc PyFloat_GetMin*(): cdouble {.header: "Python.h", importc: "PyFloat_GetMin".}
proc PyFloat_ClearFreeList*(): cint {.header: "Python.h", importc: "PyFloat_ClearFreeList".}
proc cSum*(arg_left: PyComplex; arg_right: PyComplex): PyComplex {.header: "Python.h", importc: "_cSum".}
proc cDiff*(arg_left: PyComplex; arg_right: PyComplex): PyComplex {.header: "Python.h", importc: "_cDiff".}
proc cNeg*(arg_complex: PyComplex): PyComplex {.header: "Python.h", importc: "_cNeg".}
proc cProd*(arg_left: PyComplex; arg_right: PyComplex): PyComplex {.header: "Python.h", importc: "_cProd".}
proc cQuot*(arg_dividend: PyComplex; arg_divisor: PyComplex): PyComplex {.header: "Python.h", importc: "_cQuot".}
proc cPow*(arg_num: PyComplex; arg_exp: PyComplex): PyComplex {.header: "Python.h", importc: "_cPow".}
proc PyComplex_Check*(p: ptr PyObject): cint {.header: "Python.h", importc: "PyComplex_Check".}
proc PyComplex_CheckExact*(p: ptr PyObject): cint {.header: "Python.h", importc: "PyComplex_CheckExact".}
proc PyComplex_FromCComplex*(v: PyComplex): ptr PyObject {.header: "Python.h", importc: "PyComplex_FromCComplex".}
proc PyComplex_FromDoubles*(real: cdouble; imag: cdouble): ptr PyObject {.header: "Python.h", importc: "PyComplex_FromDoubles".}
proc PyComplex_RealAsDouble*(op: ptr PyObject): cdouble {.header: "Python.h", importc: "PyComplex_RealAsDouble".}
proc PyComplex_ImagAsDouble*(op: ptr PyObject): cdouble {.header: "Python.h", importc: "PyComplex_ImagAsDouble".}
proc PyComplex_AsCComplex*(op: ptr PyObject): PyComplex {.header: "Python.h", importc: "PyComplex_AsCComplex".}
proc PyBytes_Check*(o: ptr PyObject): cint {.header: "Python.h", importc: "PyBytes_Check".}
proc PyBytes_CheckExact*(o: ptr PyObject): cint {.header: "Python.h", importc: "PyBytes_CheckExact".}
proc PyBytes_FromString*(v: cstring): ptr PyObject {.header: "Python.h", importc: "PyBytes_FromString".}
proc PyBytes_FromStringAndSize*(v: cstring; len: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PyBytes_FromStringAndSize".}
proc PyBytes_FromFormat*(format: cstring): ptr PyObject {.header: "Python.h", importc: "PyBytes_FromFormat", varargs.}
proc PyBytes_FromFormatV*(format: cstring; vargs: varargs): ptr PyObject {.header: "Python.h", importc: "PyBytes_FromFormatV".}
proc PyBytes_FromObject*(o: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyBytes_FromObject".}
proc PyBytes_Size*(o: ptr PyObject): Py_ssize_t {.header: "Python.h", importc: "PyBytes_Size".}
proc PyBytes_AsString*(o: ptr PyObject): cstring {.header: "Python.h", importc: "PyBytes_AsString".}
proc PyBytes_AsStringAndSize*(obj: ptr PyObject; buffer: cstringArray;length: ptr Py_ssize_t): cint {.header: "Python.h", importc: "PyBytes_AsStringAndSize".}
proc PyBytes_Concat*(bytes: ptr ptr PyObject; newpart: ptr PyObject) {.header: "Python.h", importc: "PyBytes_Concat".}
proc PyBytes_ConcatAndDel*(bytes: ptr ptr PyObject; newpart: ptr PyObject) {.header: "Python.h", importc: "PyBytes_ConcatAndDel".}
proc bytesResize*(arg_bytes: ptr ptr PyObject; newsize: Py_ssize_t): cint {.header: "Python.h", importc: "_bytesResize".}
proc PyByteArray_Check*(o: ptr PyObject): cint {.header: "Python.h", importc: "PyByteArray_Check".}
proc PyByteArray_CheckExact*(o: ptr PyObject): cint {.header: "Python.h", importc: "PyByteArray_CheckExact".}
proc PyByteArray_FromObject*(o: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyByteArray_FromObject".}
proc PyByteArray_FromStringAndSize*(string: cstring; length: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PyByteArray_FromStringAndSize".}
proc PyByteArray_Concat*(a: ptr PyObject; b: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyByteArray_Concat".}
proc PyByteArray_Size*(bytearray: ptr PyObject): Py_ssize_t {.header: "Python.h", importc: "PyByteArray_Size".}
proc PyByteArray_AsString*(bytearray: ptr PyObject): cstring {.header: "Python.h", importc: "PyByteArray_AsString".}
proc PyByteArray_Resize*(bytearray: ptr PyObject; length: Py_ssize_t): cint {.header: "Python.h", importc: "PyByteArray_Resize".}
proc PyUnicode_Check*(o: ptr PyObject): cint {.header: "Python.h", importc: "PyUnicode_Check".}
proc PyUnicode_CheckExact*(o: ptr PyObject): cint {.header: "Python.h", importc: "PyUnicode_CheckExact".}
proc PyUnicode_ClearFreeList*(): cint {.header: "Python.h", importc: "PyUnicode_ClearFreeList".}
proc PyUnicode_New*(size: Py_ssize_t; maxchar: Py_UCS4): ptr PyObject {.header: "Python.h", importc: "PyUnicode_New".}
proc PyUnicode_FromKindAndData*(kind: cint; buffer: pointer;size: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PyUnicode_FromKindAndData".}
proc PyUnicode_FromStringAndSize*(u: cstring; size: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PyUnicode_FromStringAndSize".}
proc PyUnicode_FromString*(u: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_FromString".}
proc PyUnicode_FromFormat*(format: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_FromFormat", varargs.}
proc PyUnicode_FromFormatV*(format: cstring; vargs: varargs): ptr PyObject {.header: "Python.h", importc: "PyUnicode_FromFormatV".}
proc PyUnicode_FromEncodedObject*(obj: ptr PyObject; encoding: cstring;errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_FromEncodedObject".}
proc PyUnicode_GetLength*(unicode: ptr PyObject): Py_ssize_t {.header: "Python.h", importc: "PyUnicode_GetLength".}
proc PyUnicode_CopyCharacters*(to: ptr PyObject; to_start: Py_ssize_t;fr: ptr PyObject; from_start: Py_ssize_t; how_many: Py_ssize_t): cint {.header: "Python.h", importc: "PyUnicode_CopyCharacters".}
proc PyUnicode_Fill*(unicode: ptr PyObject; start: Py_ssize_t; length: Py_ssize_t;fill_char: Py_UCS4): Py_ssize_t {.header: "Python.h", importc: "PyUnicode_Fill".}
proc PyUnicode_WriteChar*(unicode: ptr PyObject; index: Py_ssize_t;character: Py_UCS4): cint {.header: "Python.h", importc: "PyUnicode_WriteChar".}
proc PyUnicode_ReadChar*(unicode: ptr PyObject; index: Py_ssize_t): Py_UCS4 {.header: "Python.h", importc: "PyUnicode_ReadChar".}
proc PyUnicode_Substring*(str: ptr PyObject; start: Py_ssize_t;`end`: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PyUnicode_Substring".}
proc PyUnicode_AsUCS4*(u: ptr PyObject; buffer: ptr Py_UCS4; buflen: Py_ssize_t;copy_null: cint): ptr Py_UCS4 {.header: "Python.h", importc: "PyUnicode_AsUCS4".}
proc PyUnicode_AsUCS4Copy*(u: ptr PyObject): ptr Py_UCS4 {.header: "Python.h", importc: "PyUnicode_AsUCS4Copy".}
proc PyUnicode_DecodeLocaleAndSize*(str: cstring; len: Py_ssize_t;errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_DecodeLocaleAndSize".}
proc PyUnicode_DecodeLocale*(str: cstring; errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_DecodeLocale".}
proc PyUnicode_EncodeLocale*(unicode: ptr PyObject; errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_EncodeLocale".}
proc PyUnicode_FSConverter*(obj: ptr PyObject; result: pointer): cint {.header: "Python.h", importc: "PyUnicode_FSConverter".}
proc PyUnicode_FSDecoder*(obj: ptr PyObject; result: pointer): cint {.header: "Python.h", importc: "PyUnicode_FSDecoder".}
proc PyUnicode_DecodeFSDefaultAndSize*(s: cstring; size: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PyUnicode_DecodeFSDefaultAndSize".}
proc PyUnicode_DecodeFSDefault*(s: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_DecodeFSDefault".}
proc PyUnicode_EncodeFSDefault*(unicode: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyUnicode_EncodeFSDefault".}
proc PyUnicode_FromWideChar*(w: PyUnicode; size: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PyUnicode_FromWideChar".}
proc PyUnicode_AsWideChar*(unicode: ptr PyUnicodeObject; w: PyUnicode;size: Py_ssize_t): Py_ssize_t {.header: "Python.h", importc: "PyUnicode_AsWideChar".}
proc PyUnicode_AsWideCharString*(unicode: ptr PyObject;size: ptr Py_ssize_t): PyUnicode {.header: "Python.h", importc: "PyUnicode_AsWideCharString".}
proc Py_UCS4_strlen*(u: ptr Py_UCS4): csize {.header: "Python.h", importc: "Py_UCS4_strlen".}
proc Py_UCS4_strcpy*(s1: ptr Py_UCS4; s2: ptr Py_UCS4): ptr Py_UCS4 {.header: "Python.h", importc: "Py_UCS4_strcpy".}
proc Py_UCS4_strncpy*(s1: ptr Py_UCS4; s2: ptr Py_UCS4; n: csize): ptr Py_UCS4 {.header: "Python.h", importc: "Py_UCS4_strncpy".}
proc Py_UCS4_strcat*(s1: ptr Py_UCS4; s2: ptr Py_UCS4): ptr Py_UCS4 {.header: "Python.h", importc: "Py_UCS4_strcat".}
proc Py_UCS4_strcmp*(s1: ptr Py_UCS4; s2: ptr Py_UCS4): cint {.header: "Python.h", importc: "Py_UCS4_strcmp".}
proc Py_UCS4_strncmp*(s1: ptr Py_UCS4; s2: ptr Py_UCS4; n: csize): cint {.header: "Python.h", importc: "Py_UCS4_strncmp".}
proc Py_UCS4_strchr*(s: ptr Py_UCS4; c: Py_UCS4): ptr Py_UCS4 {.header: "Python.h", importc: "Py_UCS4_strchr".}
proc Py_UCS4_strrchr*(s: ptr Py_UCS4; c: Py_UCS4): ptr Py_UCS4 {.header: "Python.h", importc: "Py_UCS4_strrchr".}
proc PyUnicode_Decode*(s: cstring; size: Py_ssize_t; encoding: cstring;errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_Decode".}
proc PyUnicode_AsEncodedString*(unicode: ptr PyObject; encoding: cstring;errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_AsEncodedString".}
proc PyUnicode_Encode*(s: ptr PyUnicode; size: Py_ssize_t; encoding: cstring;errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_Encode".}
proc PyUnicode_DecodeUTF8*(s: cstring; size: Py_ssize_t;errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_DecodeUTF8".}
proc PyUnicode_DecodeUTF8Stateful*(s: cstring; size: Py_ssize_t; errors: cstring;consumed: ptr Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PyUnicode_DecodeUTF8Stateful".}
proc PyUnicode_AsUTF8String*(unicode: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyUnicode_AsUTF8String".}
proc PyUnicode_AsUTF8AndSize*(unicode: ptr PyObject; size: ptr Py_ssize_t): cstring {.header: "Python.h", importc: "PyUnicode_AsUTF8AndSize".}
proc PyUnicode_AsUTF8*(unicode: ptr PyObject): cstring {.header: "Python.h", importc: "PyUnicode_AsUTF8".}
proc PyUnicode_EncodeUTF8*(s: ptr PyUnicode; size: Py_ssize_t;errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_EncodeUTF8".}
proc PyUnicode_DecodeUTF32*(s: cstring; size: Py_ssize_t; errors: cstring;byteorder: ptr cint): ptr PyObject {.header: "Python.h", importc: "PyUnicode_DecodeUTF32".}
proc PyUnicode_DecodeUTF32Stateful*(s: cstring; size: Py_ssize_t; errors: cstring;byteorder: ptr cint; consumed: ptr Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PyUnicode_DecodeUTF32Stateful".}
proc PyUnicode_AsUTF32String*(unicode: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyUnicode_AsUTF32String".}
proc PyUnicode_EncodeUTF32*(s: ptr PyUnicode; size: Py_ssize_t; errors: cstring;byteorder: cint): ptr PyObject {.header: "Python.h", importc: "PyUnicode_EncodeUTF32".}
proc PyUnicode_DecodeUTF16*(s: cstring; size: Py_ssize_t; errors: cstring;byteorder: ptr cint): ptr PyObject {.header: "Python.h", importc: "PyUnicode_DecodeUTF16".}
proc PyUnicode_DecodeUTF16Stateful*(s: cstring; size: Py_ssize_t; errors: cstring;byteorder: ptr cint; consumed: ptr Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PyUnicode_DecodeUTF16Stateful".}
proc PyUnicode_AsUTF16String*(unicode: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyUnicode_AsUTF16String".}
proc PyUnicode_EncodeUTF16*(s: ptr PyUnicode; size: Py_ssize_t; errors: cstring;byteorder: cint): ptr PyObject {.header: "Python.h", importc: "PyUnicode_EncodeUTF16".}
proc PyUnicode_DecodeUTF7*(s: cstring; size: Py_ssize_t;errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_DecodeUTF7".}
proc PyUnicode_DecodeUTF7Stateful*(s: cstring; size: Py_ssize_t; errors: cstring;consumed: ptr Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PyUnicode_DecodeUTF7Stateful".}
proc PyUnicode_EncodeUTF7*(s: ptr PyUnicode; size: Py_ssize_t; base64SetO: cint;base64WhiteSpace: cint; errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_EncodeUTF7".}
proc PyUnicode_DecodeUnicodeEscape*(s: cstring; size: Py_ssize_t;errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_DecodeUnicodeEscape".}
proc PyUnicode_AsUnicodeEscapeString*(unicode: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyUnicode_AsUnicodeEscapeString".}
proc PyUnicode_EncodeUnicodeEscape*(s: ptr PyUnicode; size: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PyUnicode_EncodeUnicodeEscape".}
proc PyUnicode_DecodeRawUnicodeEscape*(s: cstring; size: Py_ssize_t;errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_DecodeRawUnicodeEscape".}
proc PyUnicode_AsRawUnicodeEscapeString*(unicode: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyUnicode_AsRawUnicodeEscapeString".}
proc PyUnicode_EncodeRawUnicodeEscape*(s: ptr PyUnicode; size: Py_ssize_t; errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_EncodeRawUnicodeEscape".}
proc PyUnicode_DecodeLatin1*(s: cstring; size: Py_ssize_t; errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_DecodeLatin1".}
proc PyUnicode_AsLatin1String*(unicode: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyUnicode_AsLatin1String".}
proc PyUnicode_EncodeLatin1*(s: ptr PyUnicode; size: Py_ssize_t; errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_EncodeLatin1".}
proc PyUnicode_DecodeASCII*(s: cstring; size: Py_ssize_t;errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_DecodeASCII".}
proc PyUnicode_AsASCIIString*(unicode: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyUnicode_AsASCIIString".}
proc PyUnicode_EncodeASCII*(s: ptr PyUnicode; size: Py_ssize_t;errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_EncodeASCII".}
proc PyUnicode_DecodeCharmap*(s: cstring; size: Py_ssize_t; mapping: ptr PyObject;errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_DecodeCharmap".}
proc PyUnicode_AsCharmapString*(unicode: ptr PyObject;mapping: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyUnicode_AsCharmapString".}
proc PyUnicode_TranslateCharmap*(s: ptr PyUnicode; size: Py_ssize_t;table: ptr PyObject; errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_TranslateCharmap".}
proc PyUnicode_EncodeCharmap*(s: ptr PyUnicode; size: Py_ssize_t; mapping: ptr PyObject;errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_EncodeCharmap".}
proc PyUnicode_DecodeMBCS*(s: cstring; size: Py_ssize_t;errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_DecodeMBCS".}
proc PyUnicode_DecodeMBCSStateful*(s: cstring; size: cint; errors: cstring;consumed: ptr cint): ptr PyObject {.header: "Python.h", importc: "PyUnicode_DecodeMBCSStateful".}
proc PyUnicode_AsMBCSString*(unicode: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyUnicode_AsMBCSString".}
proc PyUnicode_EncodeCodePage*(code_page: cint; unicode: ptr PyObject;errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_EncodeCodePage".}
proc PyUnicode_EncodeMBCS*(s: ptr PyUnicode; size: Py_ssize_t;errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_EncodeMBCS".}
proc PyUnicode_Concat*(left: ptr PyObject; right: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyUnicode_Concat".}
proc PyUnicode_Split*(s: ptr PyObject; sep: ptr PyObject;maxsplit: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PyUnicode_Split".}
proc PyUnicode_Splitlines*(s: ptr PyObject; keepend: cint): ptr PyObject {.header: "Python.h", importc: "PyUnicode_Splitlines".}
proc PyUnicode_Translate*(str: ptr PyObject; table: ptr PyObject;errors: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_Translate".}
proc PyUnicode_Join*(separator: ptr PyObject; seq: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyUnicode_Join".}
proc PyUnicode_Tailmatch*(str: ptr PyObject; substr: ptr PyObject; start: Py_ssize_t;`end`: Py_ssize_t; direction: cint): Py_ssize_t {.header: "Python.h", importc: "PyUnicode_Tailmatch".}
proc PyUnicode_Find*(str: ptr PyObject; substr: ptr PyObject; start: Py_ssize_t;`end`: Py_ssize_t; direction: cint): Py_ssize_t {.header: "Python.h", importc: "PyUnicode_Find".}
proc PyUnicode_FindChar*(str: ptr PyObject; ch: Py_UCS4; start: Py_ssize_t;`end`: Py_ssize_t; direction: cint): Py_ssize_t {.header: "Python.h", importc: "PyUnicode_FindChar".}
proc PyUnicode_Count*(str: ptr PyObject; substr: ptr PyObject; start: Py_ssize_t;`end`: Py_ssize_t): Py_ssize_t {.header: "Python.h", importc: "PyUnicode_Count".}
proc PyUnicode_Replace*(str: ptr PyObject; substr: ptr PyObject;replstr: ptr PyObject; maxcount: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PyUnicode_Replace".}
proc PyUnicode_Compare*(left: ptr PyObject; right: ptr PyObject): cint {.header: "Python.h", importc: "PyUnicode_Compare".}
proc PyUnicode_CompareWithASCIIString*(uni: ptr PyObject; string: cstring): cint {.header: "Python.h", importc: "PyUnicode_CompareWithASCIIString".}
proc PyUnicode_RichCompare*(left: ptr PyObject; right: ptr PyObject;op: cint): ptr PyObject {.header: "Python.h", importc: "PyUnicode_RichCompare".}
proc PyUnicode_Format*(format: ptr PyObject; args: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyUnicode_Format".}
proc PyUnicode_Contains*(container: ptr PyObject; element: ptr PyObject): cint {.header: "Python.h", importc: "PyUnicode_Contains".}
proc PyUnicode_InternInPlace*(string: ptr ptr PyObject) {.header: "Python.h", importc: "PyUnicode_InternInPlace".}
proc PyUnicode_InternFromString*(v: cstring): ptr PyObject {.header: "Python.h", importc: "PyUnicode_InternFromString".}
proc PyTuple_Check*(p: ptr PyObject): cint {.header: "Python.h", importc: "PyTuple_Check".}
proc PyTuple_CheckExact*(p: ptr PyObject): cint {.header: "Python.h", importc: "PyTuple_CheckExact".}
proc PyTuple_New*(len: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PyTuple_New".}
proc PyTuple_Pack*(n: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PyTuple_Pack", varargs.}
proc PyTuple_Size*(p: ptr PyObject): Py_ssize_t {.header: "Python.h", importc: "PyTuple_Size".}
proc PyTuple_GET_SIZE*(p: ptr PyObject): Py_ssize_t {.header: "Python.h", importc: "PyTuple_GET_SIZE".}
proc PyTuple_GetItem*(p: ptr PyObject; pos: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PyTuple_GetItem".}
proc PyTuple_GetSlice*(p: ptr PyObject; low: Py_ssize_t; high: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PyTuple_GetSlice".}
proc PyTuple_SetItem*(p: ptr PyObject; pos: Py_ssize_t; o: ptr PyObject): cint {.header: "Python.h", importc: "PyTuple_SetItem".}
proc tupleResize*(p: ptr ptr PyObject; arg_newsize: Py_ssize_t): cint {.header: "Python.h", importc: "_tupleResize".}
proc PyTuple_ClearFreeList*(): cint {.header: "Python.h", importc: "PyTuple_ClearFreeList".}
proc PyStructSequence_NewType*(desc: ptr PyStructSequenceDesc): ptr PyTypeObject {.header: "Python.h", importc: "PyStructSequence_NewType".}
proc PyStructSequence_InitType*(typ: ptr PyTypeObject;desc: ptr PyStructSequenceDesc) {.header: "Python.h", importc: "PyStructSequence_InitType".}
proc PyStructSequence_InitType2*(typ: ptr PyTypeObject;desc: ptr PyStructSequenceDesc): cint {.header: "Python.h", importc: "PyStructSequence_InitType2".}
proc PyStructSequence_New*(typ: ptr PyTypeObject): ptr PyObject {.header: "Python.h", importc: "PyStructSequence_New".}
proc PyStructSequence_GetItem*(p: ptr PyObject; pos: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PyStructSequence_GetItem".}
proc PyStructSequence_SetItem*(p: ptr PyObject; pos: Py_ssize_t; o: ptr PyObject) {.header: "Python.h", importc: "PyStructSequence_SetItem".}
proc PyList_Check*(p: ptr PyObject): cint {.header: "Python.h", importc: "PyList_Check".}
proc PyList_CheckExact*(p: ptr PyObject): cint {.header: "Python.h", importc: "PyList_CheckExact".}
proc PyList_New*(len: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PyList_New".}
proc PyList_Size*(list: ptr PyObject): Py_ssize_t {.header: "Python.h", importc: "PyList_Size".}
proc PyList_GET_SIZE*(list: ptr PyObject): Py_ssize_t {.header: "Python.h", importc: "PyList_GET_SIZE", cdecl.}
proc PyList_GetItem*(list: ptr PyObject; index: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PyList_GetItem".}
proc PyList_GET_ITEM_MACRO*(list: ptr PyObject; i: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PyList_GET_ITEM", cdecl.}
proc PyList_SetItem*(list: ptr PyObject; index: Py_ssize_t; item: ptr PyObject): cint {.header: "Python.h", importc: "PyList_SetItem".}
proc PyList_SET_ITEM_MACRO*(list: ptr PyObject; i: Py_ssize_t; o: ptr PyObject) {.header: "Python.h", importc: "PyList_SET_ITEM", cdecl.}
proc PyList_Insert*(list: ptr PyObject; index: Py_ssize_t; item: ptr PyObject): cint {.header: "Python.h", importc: "PyList_Insert".}
proc PyList_Append*(list: ptr PyObject; item: ptr PyObject): cint {.header: "Python.h", importc: "PyList_Append".}
proc PyList_GetSlice*(list: ptr PyObject; low: Py_ssize_t; high: Py_ssize_t): ptr PyObject {.header: "Python.h", importc: "PyList_GetSlice".}
proc PyList_SetSlice*(list: ptr PyObject; low: Py_ssize_t; high: Py_ssize_t;itemlist: ptr PyObject): cint {.header: "Python.h", importc: "PyList_SetSlice".}
proc PyList_Sort*(list: ptr PyObject): cint {.header: "Python.h", importc: "PyList_Sort".}
proc PyList_Reverse*(list: ptr PyObject): cint {.header: "Python.h", importc: "PyList_Reverse".}
proc PyList_AsTuple*(list: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyList_AsTuple".}
proc PyList_ClearFreeList*(): cint {.header: "Python.h", importc: "PyList_ClearFreeList".}
proc PyDict_Check*(p: ptr PyObject): cint {.header: "Python.h", importc: "PyDict_Check".}
proc PyDict_CheckExact*(p: ptr PyObject): cint {.header: "Python.h", importc: "PyDict_CheckExact".}
proc PyDict_New*(): ptr PyObject {.header: "Python.h", importc: "PyDict_New".}
proc PyDictProxy_New*(mapping: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyDictProxy_New".}
proc PyDict_Clear*(p: ptr PyObject) {.header: "Python.h", importc: "PyDict_Clear".}
proc PyDict_Contains*(p: ptr PyObject; key: ptr PyObject): cint {.header: "Python.h", importc: "PyDict_Contains".}
proc PyDict_Copy*(p: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyDict_Copy".}
proc PyDict_SetItem*(p: ptr PyObject; key: ptr PyObject; val: ptr PyObject): cint {.header: "Python.h", importc: "PyDict_SetItem".}
proc PyDict_SetItemString*(p: ptr PyObject; key: cstring; val: ptr PyObject): cint {.header: "Python.h", importc: "PyDict_SetItemString".}
proc PyDict_DelItem*(p: ptr PyObject; key: ptr PyObject): cint {.header: "Python.h", importc: "PyDict_DelItem".}
proc PyDict_DelItemString*(p: ptr PyObject; key: cstring): cint {.header: "Python.h", importc: "PyDict_DelItemString".}
proc PyDict_GetItem*(p: ptr PyObject; key: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyDict_GetItem".}
proc PyDict_GetItemWithError*(p: ptr PyObject; key: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyDict_GetItemWithError".}
proc PyDict_GetItemString*(p: ptr PyObject; key: cstring): ptr PyObject {.header: "Python.h", importc: "PyDict_GetItemString".}
proc PyDict_SetDefault*(p: ptr PyObject; key: ptr PyObject;default: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyDict_SetDefault".}
proc PyDict_Items*(p: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyDict_Items".}
proc PyDict_Keys*(p: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyDict_Keys".}
proc PyDict_Values*(p: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyDict_Values".}
proc PyDict_Size*(p: ptr PyObject): Py_ssize_t {.header: "Python.h", importc: "PyDict_Size".}
proc PyDict_Next*(p: ptr PyObject; ppos: ptr Py_ssize_t; pkey: ptr ptr PyObject;pvalue: ptr ptr PyObject): cint {.header: "Python.h", importc: "PyDict_Next".}
proc PyDict_Merge*(a: ptr PyObject; b: ptr PyObject; override: cint): cint {.header: "Python.h", importc: "PyDict_Merge".}
proc PyDict_Update*(a: ptr PyObject; b: ptr PyObject): cint {.header: "Python.h", importc: "PyDict_Update".}
proc PyDict_MergeFromSeq2*(a: ptr PyObject; seq2: ptr PyObject;override: cint): cint {.header: "Python.h", importc: "PyDict_MergeFromSeq2".}
proc PyDict_ClearFreeList*(): cint {.header: "Python.h", importc: "PyDict_ClearFreeList".}
proc PySet_Check*(p: ptr PyObject): cint {.header: "Python.h", importc: "PySet_Check".}
proc PyFrozenSet_Check*(p: ptr PyObject): cint {.header: "Python.h", importc: "PyFrozenSet_Check".}
proc PyAnySet_Check*(p: ptr PyObject): cint {.header: "Python.h", importc: "PyAnySet_Check".}
proc PyAnySet_CheckExact*(p: ptr PyObject): cint {.header: "Python.h", importc: "PyAnySet_CheckExact".}
proc PyFrozenSet_CheckExact*(p: ptr PyObject): cint {.header: "Python.h", importc: "PyFrozenSet_CheckExact".}
proc PySet_New*(iterable: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PySet_New".}
proc PyFrozenSet_New*(iterable: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyFrozenSet_New".}
proc PySet_Size*(anyset: ptr PyObject): Py_ssize_t {.header: "Python.h", importc: "PySet_Size".}
proc PySet_GET_SIZE*(anyset: ptr PyObject): Py_ssize_t {.header: "Python.h", importc: "PySet_GET_SIZE", cdecl.}
proc PySet_Contains*(anyset: ptr PyObject; key: ptr PyObject): cint {.header: "Python.h", importc: "PySet_Contains".}
proc PySet_Add*(set: ptr PyObject; key: ptr PyObject): cint {.header: "Python.h", importc: "PySet_Add".}
proc PySet_Discard*(set: ptr PyObject; key: ptr PyObject): cint {.header: "Python.h", importc: "PySet_Discard".}
proc PySet_Pop*(set: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PySet_Pop".}
proc PySet_Clear*(set: ptr PyObject): cint {.header: "Python.h", importc: "PySet_Clear".}
proc PySet_ClearFreeList*(): cint {.header: "Python.h", importc: "PySet_ClearFreeList".}
proc PyFunction_Check*(o: ptr PyObject): cint {.header: "Python.h", importc: "PyFunction_Check".}
proc PyFunction_New*(code: ptr PyObject; globals: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyFunction_New".}
proc PyFunction_NewWithQualName*(code: ptr PyObject; globals: ptr PyObject;qualname: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyFunction_NewWithQualName".}
proc PyFunction_GetCode*(op: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyFunction_GetCode".}
proc PyFunction_GetGlobals*(op: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyFunction_GetGlobals".}
proc PyFunction_GetModule*(op: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyFunction_GetModule".}
proc PyFunction_GetDefaults*(op: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyFunction_GetDefaults".}
proc PyFunction_SetDefaults*(op: ptr PyObject; defaults: ptr PyObject): cint {.header: "Python.h", importc: "PyFunction_SetDefaults".}
proc PyFunction_GetClosure*(op: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyFunction_GetClosure".}
proc PyFunction_SetClosure*(op: ptr PyObject; closure: ptr PyObject): cint {.header: "Python.h", importc: "PyFunction_SetClosure".}
proc PyFunction_GetAnnotations*(op: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyFunction_GetAnnotations".}
proc PyFunction_SetAnnotations*(op: ptr PyObject; annotations: ptr PyObject): cint {.header: "Python.h", importc: "PyFunction_SetAnnotations".}
proc PyInstanceMethod_Check*(o: ptr PyObject): cint {.header: "Python.h", importc: "PyInstanceMethod_Check".}
proc PyInstanceMethod_New*(fun: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyInstanceMethod_New".}
proc PyInstanceMethod_Function*(im: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyInstanceMethod_Function".}
proc PyInstanceMethod_GET_FUNCTION*(im: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyInstanceMethod_GET_FUNCTION", cdecl.}
proc PyMethod_Check*(o: ptr PyObject): cint {.header: "Python.h", importc: "PyMethod_Check".}
proc PyMethod_New*(fun: ptr PyObject; self: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyMethod_New".}
proc PyMethod_Function*(meth: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyMethod_Function".}
proc PyMethod_GET_FUNCTION*(meth: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyMethod_GET_FUNCTION", cdecl.}
proc PyMethod_Self*(meth: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyMethod_Self".}
proc PyMethod_GET_SELF*(meth: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyMethod_GET_SELF, cdecl".}
proc PyMethod_ClearFreeList*(): cint {.header: "Python.h", importc: "PyMethod_ClearFreeList".}
proc PyCell_Check*(ob: pointer): cint {.header: "Python.h", importc: "PyCell_Check".}
proc PyCell_New*(ob: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyCell_New".}
proc PyCell_Get*(cell: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyCell_Get".}
proc PyCell_Set*(cell: ptr PyObject; value: ptr PyObject): cint {.header: "Python.h", importc: "PyCell_Set".}
proc PyCode_Check*(co: ptr PyObject): cint {.header: "Python.h", importc: "PyCode_Check".}
proc PyCode_GetNumFree*(co: ptr PyCodeObject): cint {.header: "Python.h", importc: "PyCode_GetNumFree".}
proc PyCode_New*(argcount: cint; kwonlyargcount: cint; nlocals: cint;stacksize: cint; flags: cint; code: ptr PyObject; consts: ptr PyObject; names: ptr PyObject; varnames: ptr PyObject; freevars: ptr PyObject; cellvars: ptr PyObject; filename: ptr PyObject; name: ptr PyObject; firstlineno: cint; lnotab: ptr PyObject): ptr PyCodeObject {.header: "Python.h", importc: "PyCode_New".}
proc PyCode_NewEmpty*(filename: cstring; funcname: cstring;firstlineno: cint): ptr PyCodeObject {.header: "Python.h", importc: "PyCode_NewEmpty".}
proc PyObject_AsFileDescriptor*(p: ptr PyObject): cint {.header: "Python.h", importc: "PyObject_AsFileDescriptor".}
proc PyFile_GetLine*(p: ptr PyObject; n: cint): ptr PyObject {.header: "Python.h", importc: "PyFile_GetLine".}
proc PyFile_WriteObject*(obj: ptr PyObject; p: ptr PyObject; flags: cint): cint {.header: "Python.h", importc: "PyFile_WriteObject".}
proc PyFile_WriteString*(s: cstring; p: ptr PyObject): cint {.header: "Python.h", importc: "PyFile_WriteString".}
proc PyModule_Check*(p: ptr PyObject): cint {.header: "Python.h", importc: "PyModule_Check".}
proc PyModule_CheckExact*(p: ptr PyObject): cint {.header: "Python.h", importc: "PyModule_CheckExact".}
proc PyModule_NewObject*(name: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyModule_NewObject".}
proc PyModule_New*(name: cstring): ptr PyObject {.header: "Python.h", importc: "PyModule_New".}
proc PyModule_GetDict*(module: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyModule_GetDict".}
proc PyModule_GetNameObject*(module: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyModule_GetNameObject".}
proc PyModule_GetName*(module: ptr PyObject): cstring {.header: "Python.h", importc: "PyModule_GetName".}
proc PyModule_GetFilenameObject*(module: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyModule_GetFilenameObject".}
proc PyModule_GetFilename*(module: ptr PyObject): cstring {.header: "Python.h", importc: "PyModule_GetFilename".}
proc PyModule_GetState*(module: ptr PyObject): pointer {.header: "Python.h", importc: "PyModule_GetState".}
proc PyModule_GetDef*(module: ptr PyObject): ptr PyModuleDef {.header: "Python.h", importc: "PyModule_GetDef".}
proc PyState_FindModule*(def: ptr PyModuleDef): ptr PyObject {.header: "Python.h", importc: "PyState_FindModule".}
proc PyState_AddModule*(module: ptr PyObject; def: ptr PyModuleDef): cint {.header: "Python.h", importc: "PyState_AddModule".}
proc PyState_RemoveModule*(def: ptr PyModuleDef): cint {.header: "Python.h", importc: "PyState_RemoveModule".}
proc PyModule_Create2*(module: ptr PyModuleDef;module_api_version: cint): ptr PyObject {.header: "Python.h", importc: "PyModule_Create2".}
proc PyModule_AddObject*(module: ptr PyObject; name: cstring;value: ptr PyObject): cint {.header: "Python.h", importc: "PyModule_AddObject".}
proc PyModule_AddIntConstant*(module: ptr PyObject; name: cstring;value: clong): cint {.header: "Python.h", importc: "PyModule_AddIntConstant".}
proc PyModule_AddStringConstant*(module: ptr PyObject; name: cstring;value: cstring): cint {.header: "Python.h", importc: "PyModule_AddStringConstant".}
proc PySeqIter_New*(seq: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PySeqIter_New".}
proc PyCallIter_New*(callable: ptr PyObject; sentinel: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyCallIter_New".}
proc PyDescr_NewGetSet*(typ: ptr PyTypeObject; getset: ptr PyGetSetDef): ptr PyObject {.header: "Python.h", importc: "PyDescr_NewGetSet".}
proc PyDescr_NewMember*(typ: ptr PyTypeObject; meth: ptr PyMemberDef): ptr PyObject {.header: "Python.h", importc: "PyDescr_NewMember".}
proc PyDescr_NewMethod*(typ: ptr PyTypeObject; meth: ptr PyMethodDef): ptr PyObject {.header: "Python.h", importc: "PyDescr_NewMethod".}
proc PyDescr_NewWrapper*(typ: ptr PyTypeObject; wrapper: ptr WrapperBase;wrapped: pointer): ptr PyObject {.header: "Python.h", importc: "PyDescr_NewWrapper".}
proc PyDescr_NewClassMethod*(typ: ptr PyTypeObject;meth: ptr PyMethodDef): ptr PyObject {.header: "Python.h", importc: "PyDescr_NewClassMethod".}
proc PyDescr_IsData*(descr: ptr PyObject): cint {.header: "Python.h", importc: "PyDescr_IsData".}
proc PyWrapper_New*(arg0: ptr PyObject; arg1: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyWrapper_New".}
proc PySlice_Check*(ob: ptr PyObject): cint {.header: "Python.h", importc: "PySlice_Check".}
proc PySlice_New*(start: ptr PyObject; stop: ptr PyObject;step: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PySlice_New".}
proc PySlice_GetIndices*(slice: ptr PyObject; length: Py_ssize_t; start: ptr Py_ssize_t;stop: ptr Py_ssize_t; step: ptr Py_ssize_t): cint {.header: "Python.h", importc: "PySlice_GetIndices".}
proc PySlice_GetIndicesEx*(slice: ptr PyObject; length: Py_ssize_t; start: ptr Py_ssize_t;stop: ptr Py_ssize_t; step: ptr Py_ssize_t; slicelength: ptr Py_ssize_t): cint {.header: "Python.h", importc: "PySlice_GetIndicesEx".}
proc PyMemoryView_FromObject*(obj: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyMemoryView_FromObject".}
proc PyMemoryView_FromMemory*(mem: cstring; size: Py_ssize_t;flags: cint): ptr PyObject {.header: "Python.h", importc: "PyMemoryView_FromMemory".}
proc PyMemoryView_FromBuffer*(view: ptr PyBuffer): ptr PyObject {.header: "Python.h", importc: "PyMemoryView_FromBuffer".}
proc PyMemoryView_GetContiguous*(obj: ptr PyObject; buffertype: cint;order: char): ptr PyObject {.header: "Python.h", importc: "PyMemoryView_GetContiguous".}
proc PyMemoryView_Check*(obj: ptr PyObject): cint {.header: "Python.h", importc: "PyMemoryView_Check".}
proc PyWeakref_NewRef*(ob: ptr PyObject; callback: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyWeakref_NewRef".}
proc PyWeakref_NewProxy*(ob: ptr PyObject; callback: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyWeakref_NewProxy".}
proc PyWeakref_GetObject*(rf: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyWeakref_GetObject".}
proc PyCapsule_CheckExact*(p: ptr PyObject): cint {.header: "Python.h", importc: "PyCapsule_CheckExact".}
proc PyCapsule_New*(pointer: pointer; name: cstring;destructor: PyCapsuledestructor): ptr PyObject {.header: "Python.h", importc: "PyCapsule_New".}
proc PyCapsule_GetPointer*(capsule: ptr PyObject; name: cstring): pointer {.header: "Python.h", importc: "PyCapsule_GetPointer".}
proc PyCapsule_Getdestructor*(capsule: ptr PyObject): PyCapsuledestructor {.header: "Python.h", importc: "PyCapsule_Getdestructor".}
proc PyCapsule_GetContext*(capsule: ptr PyObject): pointer {.header: "Python.h", importc: "PyCapsule_GetContext".}
proc PyCapsule_GetName*(capsule: ptr PyObject): cstring {.header: "Python.h", importc: "PyCapsule_GetName".}
proc PyCapsule_Import*(name: cstring; no_block: cint): pointer {.header: "Python.h", importc: "PyCapsule_Import".}
proc PyCapsule_IsValid*(capsule: ptr PyObject; name: cstring): cint {.header: "Python.h", importc: "PyCapsule_IsValid".}
proc PyCapsule_SetContext*(capsule: ptr PyObject; context: pointer): cint {.header: "Python.h", importc: "PyCapsule_SetContext".}
proc PyCapsule_Setdestructor*(capsule: ptr PyObject;destructor: PyCapsuledestructor): cint {.header: "Python.h", importc: "PyCapsule_Setdestructor".}
proc PyCapsule_SetName*(capsule: ptr PyObject; name: cstring): cint {.header: "Python.h", importc: "PyCapsule_SetName".}
proc PyCapsule_SetPointer*(capsule: ptr PyObject; pointer: pointer): cint {.header: "Python.h", importc: "PyCapsule_SetPointer".}
proc PyGen_New*(frame: ptr PyFrameObject): ptr PyObject {.header: "Python.h", importc: "PyGen_New".}
proc PyDate_Check*(ob: ptr PyObject): cint {.header: "Python.h", importc: "PyDate_Check".}
proc PyDate_CheckExact*(ob: ptr PyObject): cint {.header: "Python.h", importc: "PyDate_CheckExact".}
proc PyDateTime_Check*(ob: ptr PyObject): cint {.header: "Python.h", importc: "PyDateTime_Check".}
proc PyDateTime_CheckExact*(ob: ptr PyObject): cint {.header: "Python.h", importc: "PyDateTime_CheckExact".}
proc PyTime_Check*(ob: ptr PyObject): cint {.header: "Python.h", importc: "PyTime_Check".}
proc PyTime_CheckExact*(ob: ptr PyObject): cint {.header: "Python.h", importc: "PyTime_CheckExact".}
proc PyDelta_Check*(ob: ptr PyObject): cint {.header: "Python.h", importc: "PyDelta_Check".}
proc PyDelta_CheckExact*(ob: ptr PyObject): cint {.header: "Python.h", importc: "PyDelta_CheckExact".}
proc PyTZInfo_Check*(ob: ptr PyObject): cint {.header: "Python.h", importc: "PyTZInfo_Check".}
proc PyTZInfo_CheckExact*(ob: ptr PyObject): cint {.header: "Python.h", importc: "PyTZInfo_CheckExact".}
proc PyDate_FromDate*(year: cint; month: cint; day: cint): ptr PyObject {.header: "Python.h", importc: "PyDate_FromDate".}
proc PyDateTime_FromDateAndTime*(year: cint; month: cint; day: cint; hour: cint;minute: cint; second: cint; usecond: cint): ptr PyObject {.header: "Python.h", importc: "PyDateTime_FromDateAndTime".}
proc PyTime_FromTime*(hour: cint; minute: cint; second: cint;usecond: cint): ptr PyObject {.header: "Python.h", importc: "PyTime_FromTime".}
proc PyDelta_FromDSU*(days: cint; seconds: cint; useconds: cint): ptr PyObject {.header: "Python.h", importc: "PyDelta_FromDSU".}
proc PyDateTime_GET_YEAR*(o: ptr PyDateTime_Date): cint {.header: "Python.h", importc: "PyDateTime_GET_YEAR", cdecl.}
proc PyDateTime_GET_MONTH*(o: ptr PyDateTime_Date): cint {.header: "Python.h", importc: "PyDateTime_GET_MONTH", cdecl.}
proc PyDateTime_GET_DAY*(o: ptr PyDateTime_Date): cint {.header: "Python.h", importc: "PyDateTime_GET_DAY", cdecl.}
proc PyDateTime_DATE_GET_HOUR*(o: ptr PyDateTime_DateTime): cint {.header: "Python.h", importc: "PyDateTime_DATE_GET_HOUR", cdecl.}
proc PyDateTime_DATE_GET_MINUTE*(o: ptr PyDateTime_DateTime): cint {.header: "Python.h", importc: "PyDateTime_DATE_GET_MINUTE", cdecl.}
proc PyDateTime_DATE_GET_SECOND*(o: ptr PyDateTime_DateTime): cint {.header: "Python.h", importc: "PyDateTime_DATE_GET_SECOND", cdecl.}
proc PyDateTime_DATE_GET_MICROSECOND*(o: ptr PyDateTime_DateTime): cint {.header: "Python.h", importc: "PyDateTime_DATE_GET_MICROSECOND", cdecl.}
proc PyDateTime_TIME_GET_HOUR*(o: ptr PyDateTime_Time): cint {.header: "Python.h", importc: "PyDateTime_TIME_GET_HOUR", cdecl.}
proc PyDateTime_TIME_GET_MINUTE*(o: ptr PyDateTime_Time): cint {.header: "Python.h", importc: "PyDateTime_TIME_GET_MINUTE", cdecl.}
proc PyDateTime_TIME_GET_SECOND*(o: ptr PyDateTime_Time): cint {.header: "Python.h", importc: "PyDateTime_TIME_GET_SECOND", cdecl.}
proc PyDateTime_TIME_GET_MICROSECOND*(o: ptr PyDateTime_Time): cint {.header: "Python.h", importc: "PyDateTime_TIME_GET_MICROSECOND", cdecl.}
proc PyDateTimeDelta_GET_DAYS*(o: ptr PyDateTimeDelta): cint {.header: "Python.h", importc: "PyDateTimeDelta_GET_DAYS", cdecl.}
proc PyDateTimeDelta_GET_SECONDS*(o: ptr PyDateTimeDelta): cint {.header: "Python.h", importc: "PyDateTimeDelta_GET_SECONDS", cdecl.}
proc PyDateTimeDelta_GET_MICROSECOND*(o: ptr PyDateTimeDelta): cint {.header: "Python.h", importc: "PyDateTimeDelta_GET_MICROSECOND", cdecl.}
proc PyDateTime_FromTimestamp*(args: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyDateTime_FromTimestamp".}
proc PyDate_FromTimestamp*(args: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyDate_FromTimestamp".}
proc Py_InitializeEx*(initsigs: cint) {.header: "Python.h", importc: "Py_InitializeEx".}
proc Py_IsInitialized*(): cint {.header: "Python.h", importc: "Py_IsInitialized".}
proc Py_SetStandardStreamEncoding*(encoding: cstring; errors: cstring): cint {.header: "Python.h", importc: "Py_SetStandardStreamEncoding".}
proc Py_SetProgramName*(name: PyUnicode) {.header: "Python.h", importc: "Py_SetProgramName".}
proc Py_GetProgramName*(): PyUnicode {.header: "Python.h", importc: "Py_GetProgramName".}
proc Py_GetPrefix*(): PyUnicode {.header: "Python.h", importc: "Py_GetPrefix".}
proc Py_GetExecPrefix*(): PyUnicode {.header: "Python.h", importc: "Py_GetExecPrefix".}
proc Py_GetProgramFullPath*(): PyUnicode {.header: "Python.h", importc: "Py_GetProgramFullPath".}
proc Py_GetPath*(): PyUnicode {.header: "Python.h", importc: "Py_GetPath".}
proc Py_SetPath*(arg: PyUnicode) {.header: "Python.h", importc: "Py_SetPath".}
proc Py_GetVersion*(): cstring {.header: "Python.h", importc: "Py_GetVersion".}
proc Py_GetPlatform*(): cstring {.header: "Python.h", importc: "Py_GetPlatform".}
proc Py_GetCopyright*(): cstring {.header: "Python.h", importc: "Py_GetCopyright".}
proc Py_GetCompiler*(): cstring {.header: "Python.h", importc: "Py_GetCompiler".}
proc Py_GetBuildInfo*(): cstring {.header: "Python.h", importc: "Py_GetBuildInfo".}
proc PySys_SetArgvEx*(argc: cint; argv: ptr PyUnicode; updatepath: cint) {.header: "Python.h", importc: "PySys_SetArgvEx".}
proc PySys_SetArgv*(argc: cint; argv: ptr PyUnicode) {.header: "Python.h", importc: "PySys_SetArgv".}
proc Py_SetPythonHome*(home: PyUnicode) {.header: "Python.h", importc: "Py_SetPythonHome".}
proc Py_GetPythonHome*(): PyUnicode {.header: "Python.h", importc: "Py_GetPythonHome".}
proc PyEval_InitThreads*() {.header: "Python.h", importc: "PyEval_InitThreads".}
proc PyEval_ThreadsInitialized*(): cint {.header: "Python.h", importc: "PyEval_ThreadsInitialized".}
proc PyEval_SaveThread*(): ptr PyThreadState {.header: "Python.h", importc: "PyEval_SaveThread".}
proc PyEval_RestoreThread*(tstate: ptr PyThreadState) {.header: "Python.h", importc: "PyEval_RestoreThread".}
proc PyThreadState_Get*(): ptr PyThreadState {.header: "Python.h", importc: "PyThreadState_Get".}
proc PyThreadState_Swap*(tstate: ptr PyThreadState): ptr PyThreadState {.header: "Python.h", importc: "PyThreadState_Swap".}
proc PyEval_ReInitThreads*() {.header: "Python.h", importc: "PyEval_ReInitThreads".}
proc PyGILState_Ensure*(): PyGILState_STATE {.header: "Python.h", importc: "PyGILState_Ensure".}
proc PyGILState_Release*(arg: PyGILState_STATE) {.header: "Python.h", importc: "PyGILState_Release".}
proc PyGILState_GetThisThreadState*(): ptr PyThreadState {.header: "Python.h", importc: "PyGILState_GetThisThreadState".}
proc PyGILState_Check*(): cint {.header: "Python.h", importc: "PyGILState_Check".}
proc PyInterpreterState_New*(): ptr PyInterpreterState {.header: "Python.h", importc: "PyInterpreterState_New".}
proc PyInterpreterState_Clear*(interp: ptr PyInterpreterState) {.header: "Python.h", importc: "PyInterpreterState_Clear".}
proc PyInterpreterState_Delete*(interp: ptr PyInterpreterState) {.header: "Python.h", importc: "PyInterpreterState_Delete".}
proc PyThreadState_New*(interp: ptr PyInterpreterState): ptr PyThreadState {.header: "Python.h", importc: "PyThreadState_New".}
proc PyThreadState_Clear*(tstate: ptr PyThreadState) {.header: "Python.h", importc: "PyThreadState_Clear".}
proc PyThreadState_Delete*(tstate: ptr PyThreadState) {.header: "Python.h", importc: "PyThreadState_Delete".}
proc PyThreadState_GetDict*(): ptr PyObject {.header: "Python.h", importc: "PyThreadState_GetDict".}
proc PyThreadState_SetAsyncExc*(id: clong; exc: ptr PyObject): cint {.header: "Python.h", importc: "PyThreadState_SetAsyncExc".}
proc PyEval_AcquireThread*(tstate: ptr PyThreadState) {.header: "Python.h", importc: "PyEval_AcquireThread".}
proc PyEval_ReleaseThread*(tstate: ptr PyThreadState) {.header: "Python.h", importc: "PyEval_ReleaseThread".}
proc PyEval_AcquireLock*() {.header: "Python.h", importc: "PyEval_AcquireLock".}
proc PyEval_ReleaseLock*() {.header: "Python.h", importc: "PyEval_ReleaseLock".}
proc Py_NewInterpreter*(): ptr PyThreadState {.header: "Python.h", importc: "Py_NewInterpreter".}
proc Py_EndInterpreter*(tstate: ptr PyThreadState) {.header: "Python.h", importc: "Py_EndInterpreter".}
proc Py_AddPendingCall*(fun: proc (arg: pointer){.cdecl.}): cint {.header: "Python.h", importc: "Py_AddPendingCall".}
proc PyEval_SetProfile*(fun: pytracefunc; obj: ptr PyObject) {.header: "Python.h", importc: "PyEval_SetProfile".}
proc PyEval_SetTrace*(fun: pytracefunc; obj: ptr PyObject) {.header: "Python.h", importc: "PyEval_SetTrace".}
proc PyEval_GetCallStats*(self: ptr PyObject): ptr PyObject {.header: "Python.h", importc: "PyEval_GetCallStats".}
proc PyInterpreterState_Head*(): ptr PyInterpreterState {.header: "Python.h", importc: "PyInterpreterState_Head".}
proc PyInterpreterState_Next*(interp: ptr PyInterpreterState): ptr PyInterpreterState {.header: "Python.h", importc: "PyInterpreterState_Next".}
proc PyInterpreterState_ThreadHead*(interp: ptr PyInterpreterState): ptr PyThreadState {.header: "Python.h", importc: "PyInterpreterState_ThreadHead".}
proc PyThreadState_Next*(tstate: ptr PyThreadState): ptr PyThreadState {.header: "Python.h", importc: "PyThreadState_Next".}
proc PyMem_RawMalloc*(n: csize): pointer {.header: "Python.h", importc: "PyMem_RawMalloc".}
proc PyMem_RawRealloc*(p: pointer; n: csize): pointer {.header: "Python.h", importc: "PyMem_RawRealloc".}
proc PyMem_RawFree*(p: pointer) {.header: "Python.h", importc: "PyMem_RawFree".}
proc PyMem_Malloc*(n: csize): pointer {.header: "Python.h", importc: "PyMem_Malloc".}
proc PyMem_Realloc*(p: pointer; n: csize): pointer {.header: "Python.h", importc: "PyMem_Realloc".}
proc PyMem_Free*(p: pointer) {.header: "Python.h", importc: "PyMem_Free".}
proc PyMem_Del*(p: pointer) {.header: "Python.h", importc: "PyMem_Del".}
proc PyMem_GetAllocator*(domain: PyMemAllocatorDomain;allocator: ptr PyMemAllocator) {.header: "Python.h", importc: "PyMem_GetAllocator".}
proc PyMem_SetAllocator*(domain: PyMemAllocatorDomain;allocator: ptr PyMemAllocator) {.header: "Python.h", importc: "PyMem_SetAllocator".}
proc PyMem_SetupDebugHooks*() {.header: "Python.h", importc: "PyMem_SetupDebugHooks".}
proc pyObject_New*(typ: ptr PyTypeObject): ptr PyObject {.header: "Python.h", importc: "_PyObject_New".}
proc pyObject_NewVar*(typ: ptr PyTypeObject; size: Py_ssize_t): ptr PyVarObject {.header: "Python.h", importc: "_PyObject_NewVar".}
proc PyObject_Init*(op: ptr PyObject; typ: ptr PyTypeObject): ptr PyObject {.header: "Python.h", importc: "PyObject_Init".}
proc PyObject_InitVar*(op: ptr PyVarObject; typ: ptr PyTypeObject;size: Py_ssize_t): ptr PyVarObject {.header: "Python.h", importc: "PyObject_InitVar".}
proc PyObject_Del*(op: ptr PyObject) {.header: "Python.h", importc: "PyObject_Del".}