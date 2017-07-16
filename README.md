# Python 3 wrapper for Nim [![nimble](https://raw.githubusercontent.com/yglukhov/nimble-tag/master/nimble.png)](https://github.com/yglukhov/nimble-tag)

## New static/dynamic functionality incorporated into the wrapper. Please report any bugs!

## Description:
Nim wrapper for the Python 3 programming language.<br>
Can be used to link either statically or dynamically to the Python 3 interpreter.

## Usage:
There are now **three** new flags that are used to select the binding type:
- **py3_version**: This is a **required** flag that selects the Python version you wish to compile for. Omitting this flag produces a compile time error.
- **py3_static**: This flag selects the bindings to be compiled **statically**. Static bindings are usually used when you are creating a Nim module that will be **imported** in Python.
- **py3_dynamic**: This flag selects the bindings to be compiled **dynamically**. Dynamic bindings are used when a Nim application wants to use Python functionality during runtime. A dynamic Python 3 shared library is required to be installed on the system to dynamic bindings (**python3.dll** on Windows or **libpython3.X.so.1**/**libpython3.Xm.so.1** on Linux/MacOS).

Flags **py3_static** and **py3_dynamic** are mutually exclusive!

An example of building a static module for importing into Python:<br>    ```nim c my_py3_module.nim -d:py3_version:3.5 -d:py3_static```

## Notes:
Compatible with Python 3.1 to 3.6 (Examples tested with Python 3.4).
