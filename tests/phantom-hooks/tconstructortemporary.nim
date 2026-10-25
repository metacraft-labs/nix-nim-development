discard """
  targets: "c cpp"
  cmd: "nim $target --sinkInference:off $options $file"
  matrix: "--mm:arc; --mm:orc; --mm:arc -d:singleType; --mm:orc -d:singleType; --mm:arc -d:nonGeneric; --mm:orc -d:nonGeneric"
  output: ""
"""
# Real reference resources guard constructor ownership independently of custom
# value-hook call counts. No mocks: each allocated resource must finalize once.
# Disable this category's sink inference: the argument must be borrowed so its
# constructor temporary needs its own destructor after the call.
var finalized: array[2, int]
type ResourceData = object
  id: int
proc `=destroy`(value: var ResourceData) = inc finalized[value.id]
type Resource = ref ResourceData
proc resource(id: int): Resource = Resource(id: id)
when defined(nonGeneric):
  type NominalValue = object
    marker: string
    owned: Resource
  type Nominal[T] = NominalValue
else:
  type Nominal[T] = object
    marker: string
    owned: Resource
type Container[T] = ref object
  value: T
template destroyFields(value: untyped, tag: string) =
  if value.marker.len > 0:
    doAssert value.marker == tag
  `=destroy`(value.marker)
  `=destroy`(value.owned)
when defined(nonGeneric):
  proc `=destroy`(value: var NominalValue) = destroyFields(value, "string")
else:
  proc `=destroy`[T](value: var Nominal[T]) =
    when T is string: destroyFields(value, "string")
    else: destroyFields(value, "int")
proc create[T](value: T): Container[T] = Container[T](value: value)
proc run() =
  let a = create(Nominal[string](marker: "string", owned: resource(0)))
  when defined(singleType) or defined(nonGeneric):
    let b = create(Nominal[string](marker: "string", owned: resource(1)))
    doAssert a.value.marker == "string" and b.value.marker == "string"
  else:
    let b = create(Nominal[int](marker: "int", owned: resource(1)))
    doAssert a.value.marker == "string" and b.value.marker == "int"
run()
doAssert finalized == [1, 1], $finalized
