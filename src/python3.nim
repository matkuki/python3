
## Python 3 bindings for the Nim programming language
## Based on Andreas Rumpf's "Light-weight binding for the Python interpreter"
## Copyright (c) Matic Kukovec
## Licensed under the MIT license

## Notes:
##   Functions that are described as being non-portable must be compiled
##   with the same compiler that the Python dynamic library was compiled with

{.deadCodeElim: on.}

import strutils


# Python 3.5 introduced a few changes to some structs, so there has
# to be a way to determine which Python 3 version the user will be using!
when not defined(py3_version):
    var error = "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n"
    error    &= "!! Python 3 ERROR:                                                                      !!\n"
    error    &= "!!     Select the Python 3 version by compiling with the following flag:                !!\n"
    error    &= "!!         -d:py3_version=value(float)                                                        !!\n"
    error    &= "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    quit error
else:
    const
        py3_version {.strdefine.}: string = "3.0"
        PYTHON_VERSION* = parseFloat(py3_version)
        

# Display compilation information
when defined(py3_static):
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "!! Compiling for Python ", PYTHON_VERSION, " (STATIC) !!"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
elif defined(py3_dynamic):
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "!! Compiling for Python ", PYTHON_VERSION, " (DYNAMIC) !!"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
else:
    var error = "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n"
    error    &= "!! Python 3 ERROR:                                                                      !!\n"
    error    &= "!!     Either static or dynamic binding system has to be selected at compile time!      !!\n"
    error    &= "!!     Select the Python 3 binding system by compiling with one of the following flags: !!\n"
    error    &= "!!         -d:py3_static or -d:py3_dynamic                                              !!\n"
    error    &= "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    quit error


# Python 3 common constants/enums/symbols/...
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

# Select binding system
when defined(py3_static):
    include "static/python3_static"
elif defined(py3_dynamic):
    include "dynamic/python3_dynamic"


