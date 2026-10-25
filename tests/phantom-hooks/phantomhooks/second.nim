import ./owner
proc makeSecond*() =
  when defined(reverseOrder):
    let value = create(secret("second"))
  else:
    let value = create(secret(2))
  doAssert value != nil
