var finalized: array[2, int]
type ResourceData = object
  id: int
proc `=destroy`(value: var ResourceData) = inc finalized[value.id]
type Resource = ref ResourceData
proc resource(id: int): Resource = Resource(id: id)
type
  Nominal[T] = object
    marker: string
    owned: Resource
  Container[T] = ref object
    value: T
proc `=destroy`[T](value: var Nominal[T]) =
  if value.marker.len > 0:
    when T is string: doAssert value.marker == "string"
    else: doAssert value.marker == "int"
  `=destroy`(value.marker)
  `=destroy`(value.owned)
proc create[T](value: T): Container[T] = Container[T](value: value)
proc run() =
  var first = resource(0)
  var second = resource(1)
  var aValue = Nominal[string](marker: "string", owned: move(first))
  var bValue = Nominal[int](marker: "int", owned: move(second))
  let a = create(move(aValue))
  let b = create(move(bValue))
  doAssert a.value.marker == "string" and b.value.marker == "int"
run()
doAssert finalized == [1, 1], $finalized
