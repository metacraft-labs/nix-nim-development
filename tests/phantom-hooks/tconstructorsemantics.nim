discard """
  targets: "c cpp"
  matrix: "--mm:arc --sinkInference:off; --mm:orc --sinkInference:off; --mm:arc --sinkInference:on; --mm:orc --sinkInference:on"
  output: ""
"""
# Real reference lifetimes and constructor side effects, no mocks. Preserve
# default/inherited construction, operand order and partial-initialization
# cleanup when a later operand raises before the borrowed call can run.
var finalized: array[3, int]
var events: seq[int]
type ResourceData = object
  id: int
proc `=destroy`(value: var ResourceData) = inc finalized[value.id]
type
  Resource = ref ResourceData
  Base = object of RootObj
    value: Resource
proc `=destroy`(value: var Base) = `=destroy`(value.value)
type Child = object of Base
  other: Resource
proc resource(id: int): Resource =
  events.add id
  Resource(id: id)
proc observe(value: Child) =
  if value.value != nil: doAssert value.value.id == 0
  if value.other != nil: doAssert value.other.id == 1
proc observeDefault(value: Child) =
  doAssert value.value == nil and value.other == nil
proc inheritedConstructors() =
  observe(Child(value: resource(0), other: resource(1)))
observeDefault(Child())
doAssert finalized == [0, 0, 0], $finalized

type Scalars = object
  a, b: int
proc `=destroy`(value: var Scalars) = discard
proc step(id: int): int =
  events.add id
  id
proc observe(value: Scalars) = doAssert value.a == 2 and value.b == 3
observe(Scalars(a: step(2), b: step(3)))
doAssert events == @[2, 3]

type Owned = object
  first, second: Resource
proc `=destroy`(value: var Owned) =
  `=destroy`(value.first)
  `=destroy`(value.second)
proc fail(): Resource = raise newException(ValueError, "expected")
proc observe(value: Owned) = doAssert false, "constructor must raise first"
proc partialConstruction() =
  try:
    observe(Owned(first: resource(2), second: fail()))
    doAssert false, "missing constructor exception"
  except ValueError:
    discard
partialConstruction()
doAssert events == @[2, 3, 2]
doAssert finalized == [0, 0, 1], $finalized

inheritedConstructors()
doAssert events == @[2, 3, 2, 0, 1]
doAssert finalized == [1, 1, 1], $finalized
