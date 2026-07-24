module StdlibBytesZerosDualToolchain

observed contract Direct {
  compute value = stdlib.bytes.zeros(64)
  compute report = join([
    int_to_text(stdlib.bytes.length(value)),
    stdlib.bytes.encode_hex(value)
  ], ":")
  output report : Text
}

observed contract Nested {
  compute lengths = map([-1, 0, 1, 64], n -> stdlib.bytes.length(stdlib.bytes.zeros(n)))
  compute report = join(map(lengths, n -> int_to_text(n)), ",")
  output report : Text
}
