# Real owned references and native hooks; no mocks or synthetic finalizers.
var finalized*: int
var hooks*: array[2, int]
var emptyHooks*: array[2, int]
var nominalFinalized*: array[4, int]
type NominalResourceData = object
  id: int
proc `=destroy`(value: var NominalResourceData) =
  inc nominalFinalized[value.id]
type NominalResource = ref NominalResourceData
proc resource*(id: int): NominalResource = NominalResource(id: id)
type TokenData* = object of RootObj
  marker*: string
proc `=destroy`(value: var TokenData) =
  inc finalized
  `=destroy`(value.marker)
type Token* = ref TokenData
when defined(phantomAlias):
  type Secret*[T] = Token
else:
  type Secret*[T] = distinct Token
type
  Base* = ref object of RootObj
  Container*[T] = ref object of Base
    value*: T
  ValueContainer*[T] = object
    value*: T
  Nominal*[T] = object
    marker*: string
  ResourceNominal*[T] = object
    marker*: string
    resource*: NominalResource
proc checkMarker[T](marker: string) =
  if marker.len > 0:
    when T is string: doAssert marker == "string"
    else: doAssert marker == "int"
proc `=destroy`*[T](value: var ResourceNominal[T]) =
  checkMarker[T](value.marker)
  `=destroy`(value.marker)
  `=destroy`(value.resource)
proc `=destroy`*[T](value: var Nominal[T]) =
  # 2.2.4 may copy nonempty temporaries that 2.3.1 eliminates. Verify every
  # callback's nominal dispatch and count the real owned resources separately.
  when T is string:
    inc hooks[0]
    if value.marker.len == 0: inc emptyHooks[0]
    else: doAssert value.marker == "string"
  else:
    inc hooks[1]
    if value.marker.len == 0: inc emptyHooks[1]
    else: doAssert value.marker == "int"
  `=destroy`(value.marker)
proc secret*[T](value: T): Secret[T] = Secret[T](Token(marker: "owned"))
proc create*[T](value: T): Container[T] = Container[T](value: value)
