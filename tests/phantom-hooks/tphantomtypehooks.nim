discard """
  targets: "c cpp"
  matrix: "--mm:arc; --mm:orc; --mm:arc -d:phantomAlias; --mm:orc -d:phantomAlias; --mm:arc -d:reverseOrder; --mm:orc -d:reverseOrder; --mm:arc -d:phantomAlias -d:reverseOrder; --mm:orc -d:phantomAlias -d:reverseOrder; --mm:atomicArc"
"""
# Exercise RTTI destruction in two modules, with both phantom instantiation
# orders. Value ownership and nominal generic hooks guard canonical sharing.
import ./phantomhooks/[owner, second]
proc first() =
  when defined(reverseOrder):
    let value = create(secret(1))
  else:
    let value = create(secret("first"))
  doAssert value != nil
first()
makeSecond()
doAssert finalized == 2, $finalized
proc values() =
  let a = ValueContainer[Secret[string]](value: secret("value"))
  let b = ValueContainer[Secret[int]](value: secret(3))
  doAssert Token(a.value) != nil and Token(b.value) != nil
values()
doAssert finalized == 4, $finalized
proc nominalValues() =
  let a = ValueContainer[Nominal[string]](value: Nominal[string](marker: "string"))
  let b = ValueContainer[Nominal[int]](value: Nominal[int](marker: "int"))
  doAssert a.value.marker == "string" and b.value.marker == "int"
nominalValues()
doAssert hooks == [1, 1], $hooks
proc nominalRefs() =
  let a = create(Nominal[string](marker: "string"))
  let b = create(Nominal[int](marker: "int"))
  doAssert a.value.marker == "string" and b.value.marker == "int"
nominalRefs()

# Name each resource and transfer it explicitly. This separates real ownership
# from version-dependent copying of constructor temporaries.
proc ownedValues() =
  var first = resource(0)
  var second = resource(1)
  var aValue = ResourceNominal[string](marker: "string", resource: move(first))
  var bValue = ResourceNominal[int](marker: "int", resource: move(second))
  let a = ValueContainer[ResourceNominal[string]](value: move(aValue))
  let b = ValueContainer[ResourceNominal[int]](value: move(bValue))
  doAssert a.value.marker == "string" and b.value.marker == "int"
ownedValues()
doAssert nominalFinalized == [1, 1, 0, 0], $nominalFinalized
proc ownedRefs() =
  var first = resource(2)
  var second = resource(3)
  var aValue = ResourceNominal[string](marker: "string", resource: move(first))
  var bValue = ResourceNominal[int](marker: "int", resource: move(second))
  let a = create(move(aValue))
  let b = create(move(bValue))
  doAssert a.value.marker == "string" and b.value.marker == "int"
ownedRefs()
doAssert nominalFinalized == [1, 1, 1, 1], $nominalFinalized
echo "nominal callbacks=", hooks, " empty=", emptyHooks,
  " finalized=", nominalFinalized
