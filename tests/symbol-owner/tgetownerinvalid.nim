discard """
  action: reject
  targets: "c js"
  errormsg: "node is not a symbol"
"""
import std/macros
static:
  discard getOwner(ident"notASymbol")
