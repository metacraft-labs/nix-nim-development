discard """
  action: reject
  targets: "c js"
  cmd: "nim $target --warningAsError:Deprecated:on $options $file"
  errormsg: "owner is deprecated"
"""
import std/macros
static:
  discard owner(bindSym"int")
