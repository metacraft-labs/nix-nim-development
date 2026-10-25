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
  let a = create(Nominal[string](marker: "string", owned: resource(0)))
  let b = create(Nominal[int](marker: "int", owned: resource(1)))
  doAssert a.value.marker == "string" and b.value.marker == "int"
run()
doAssert finalized == [1, 1], $finalized
