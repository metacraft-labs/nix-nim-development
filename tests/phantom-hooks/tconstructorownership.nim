discard """
  targets: "c cpp"
  matrix: "--mm:arc --sinkInference:off; --mm:orc --sinkInference:off; --mm:arc --sinkInference:on; --mm:orc --sinkInference:on"
  output: ""
"""
# Actual references, no mocks. Check both the lifetime boundary and the final
# resource ID counts, rather than optimization-dependent value-hook counts.
{.experimental: "views".}
var finalized: array[14, int]
type ResourceData = object
  id: int
proc `=destroy`(value: var ResourceData) = inc finalized[value.id]
type
  Resource = ref ResourceData
  Owned = object
    value: Resource
  Plain = object
    value: Resource
  WithCursor = object
    value: Resource
    borrowed {.cursor.}: Resource
  Aggregate = object
    pair: tuple[a, b: Resource]
    values: array[2, Resource]
  WithView = object
    value: Resource
    borrowed: openArray[Resource]
proc `=destroy`(value: var Owned) = `=destroy`(value.value)
proc `=destroy`(value: var WithCursor) = `=destroy`(value.value)
proc `=destroy`(value: var Aggregate) =
  `=destroy`(value.pair)
  `=destroy`(value.values)
proc `=destroy`(value: var WithView) = `=destroy`(value.value)
proc resource(id: int): Resource = Resource(id: id)
proc observe(value: Owned): int = value.value.id
proc observe(value: Plain): int = value.value.id
proc observe(value: WithCursor): int =
  doAssert value.borrowed.id == 4
  value.value.id
proc observe(value: Aggregate): int =
  value.pair.a.id + value.pair.b.id + value.values[0].id + value.values[1].id
proc observe(value: WithView): int =
  doAssert value.borrowed.len == 1 and value.borrowed[0].id == 12
  value.value.id

proc explicitTransfer() =
  var r = resource(0)
  var value = Owned(value: move(r))
  doAssert r == nil
  doAssert observe(move(value)) == 0
explicitTransfer()
doAssert finalized[0] == 1

proc retainedLocal() =
  var r = resource(1)
  doAssert observe(Owned(value: r)) == 1
  doAssert finalized[1] == 0 and r.id == 1
retainedLocal()
doAssert finalized[1] == 1

var shared: Resource
proc retainedGlobal() =
  shared = resource(2)
  doAssert observe(Owned(value: shared)) == 2
retainedGlobal()
doAssert finalized[2] == 0 and shared.id == 2
shared = nil
doAssert finalized[2] == 1

proc ordinaryConstructor() =
  var r = resource(3)
  doAssert observe(Plain(value: r)) == 3
  doAssert finalized[3] == 0 and r.id == 3
ordinaryConstructor()
doAssert finalized[3] == 1

proc cursorField() =
  var r = resource(4)
  doAssert observe(WithCursor(value: resource(5), borrowed: r)) == 5
  doAssert finalized[4] == 0 and r.id == 4
cursorField()
doAssert finalized[4] == 1 and finalized[5] == 1

proc nestedAggregates() =
  doAssert observe(Aggregate(pair: (resource(6), resource(7)),
    values: [resource(8), resource(9)])) == 30
nestedAggregates()
for id in 6..9: doAssert finalized[id] == 1, $finalized

proc sharedFields() =
  var r = resource(10)
  let a = Owned(value: r)
  let b = Owned(value: r)
  doAssert observe(a) == 10 and observe(b) == 10 and r.id == 10
  doAssert finalized[10] == 0
sharedFields()
doAssert finalized[10] == 1

proc ordinaryTemporary() =
  doAssert observe(Plain(value: resource(11))) == 11
ordinaryTemporary()
proc openArrayField() =
  var values = [resource(12)]
  doAssert observe(WithView(value: resource(13), borrowed: values)) == 13
  doAssert finalized[12] == 0 and values[0].id == 12
openArrayField()
doAssert finalized == [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], $finalized
