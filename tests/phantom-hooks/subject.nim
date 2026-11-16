## No application imports. The full hook precedes every reference/type alias.
var finalized = 0
type TokenData = object of RootObj
  marker: string
proc `=destroy`(value: var TokenData) =
  inc finalized
  `=destroy`(value.marker)
type Token = ref TokenData
when defined(plainToken):
  type Secret = Token
elif defined(phantomAlias):
  type Secret[T] = Token
else:
  type Secret[T] = distinct Token
type
  Base = ref object of RootObj
  Container[T] = ref object of Base
    value: T
when defined(plainToken):
  proc secret[T](value: T): Token = Token(marker: "owned")
else:
  proc secret[T](value: T): Secret[T] = Secret[T](Token(marker: "owned"))
proc create[T](value: T): Container[T] =
  result = Container[T]()
  result.value = value
when defined(plainToken):
  proc make(): Container[Token] = create(secret(1))
elif defined(singleType):
  proc make(): Container[Secret[string]] = create(secret("other"))
else:
  proc make(): Container[Secret[int]] = create(secret(1))
template exercise() =
  block:
    let first = create(secret("text"))
    doAssert first != nil
  block:
    let second = make()
    doAssert second != nil
when defined(procedureBoundary):
  proc run() = exercise()
  run()
else:
  exercise()
echo "finalized=", finalized
doAssert finalized == 2, $finalized
