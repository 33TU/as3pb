# Examples

[game.proto](proto/game.proto) and its [generated ActionScript](generated) show the default ByteArray API.

Run from the AS3PB root:

```sh
just generate-examples  # Regenerate examples/generated
just build-examples    # Regenerate and compile examples/generated/examples.swc
```

For optional AVM2 codecs, see the [memory guide](../runtime/MEMORY.md).
