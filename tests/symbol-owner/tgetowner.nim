discard """
  targets: "c js"
  cmd: "nim $target --warningAsError:Deprecated:on $options $file"
"""
import std/macros

type Owned = object
  field: int
proc top() = discard

macro inspect(x: typed): untyped =
  doAssert getOwner(bindSym"top").symKind == nskModule
  doAssert getOwner(bindSym"Owned") == getOwner(bindSym"top")
  let module = getOwner(bindSym"top")
  doAssert getOwner(module) == module
  result = newEmptyNode()

macro localAndCapture(own, captured: typed): untyped =
  doAssert getOwner(own) != getOwner(captured)
  doAssert getOwner(own).strVal == "nested"
  doAssert getOwner(captured).strVal == "parent"
  doAssert getOwner(getOwner(own)) == getOwner(captured)
  result = newEmptyNode()

proc parent(x: int) =
  var captured = x
  proc nested() =
    var own = 1
    localAndCapture(own, captured)
  nested()
inspect(parent(1))

macro nestedOverloads(body: typed): untyped =
  let a = body[0][6][0][0]
  let b = body[1][6][0][0]
  doAssert a.strVal == "nested" and b.strVal == "nested"
  doAssert a != b
  doAssert getOwner(a) == body[0][0]
  doAssert getOwner(b) == body[1][0]
  doAssert getOwner(a) != getOwner(b)
  doAssert getOwner(a).strVal == getOwner(b).strVal
  result = body
nestedOverloads:
  proc overloaded(x: int) =
    proc nested() = discard
    nested()
  proc overloaded(x: string) =
    proc nested() = discard
    nested()
parent(1)
macro inspectField(x: typed): untyped =
  doAssert x[1].kind == nnkSym
  doAssert getOwner(x[1]) == bindSym"Owned"
  result = newEmptyNode()
var owned: Owned
inspectField(owned.field)
static:
  let detached = genSym(nskVar, "detached")
  doAssert getOwner(getOwner(detached)).kind == nnkNilLit

macro instantiatedOwner(fn: typed): untyped =
  doAssert fn.kind == nnkSym
  doAssert getOwner(fn) == getOwner(bindSym"top")
  result = newEmptyNode()
proc generic[T](x: T) = discard
instantiatedOwner(generic[int])
