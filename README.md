# Python 3 wrapper for Nim [![nimble](https://raw.githubusercontent.com/yglukhov/nimble-tag/master/nimble.png)](https://github.com/yglukhov/nimble-tag)

## NOTIFICATION: <br></br>There will be a large upgrade which will add static bindings, for building Python3 modules that statically link to the Python3 interpreter! To current bindings (dynamic) will be stay unchanged! binding type selection will be selectable with compile flags and described in this README.

## Description:
Nim wrapper for the Python 3 programming language.<br>
Based on the official nim-lang/python wrapper.

## Notes:
Compatible with Python 3.1 to 3.5 (Examples tested with Python 3.3).<br>
This is a fresh wrapper, please report typos/bugs!<br><br>
If you have time, please open an issue and tell me which coding style you prefer for this wrapper library, the original Python ("proc PyModule_NewObject") or the current Nim ("proc moduleNewObject") style.
