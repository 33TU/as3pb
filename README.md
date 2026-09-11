# AS3PB

Protocol Buffers code generation and runtime for ActionScript 3, with reusable messages and optional AVM2 memory codecs.

![AS3PB ByteArray and AVM2, AMF3 and JSON benchmark summary](assets/benchmark-summary.svg)

[Benchmark results](runtime/bench/FORMATS.md) · [Memory API](runtime/MEMORY.md) · [Examples](examples/README.md) · [Conformance](https://github.com/33TU/as3pb-conformance)

## Quick start

Install Go and protoc, then install the generator and wrapper:

```sh
go install github.com/33TU/as3pb/cmd/protoc-gen-as3@latest
go install github.com/33TU/as3pb/cmd/as3-protoc@latest
as3-protoc -I proto --as3_out=generated proto/game.proto
```

Compile your generated files together with `runtime/src` from this repository. Using runtime source lets the compiler inline its helpers:

```sh
mxmlc \
  -source-path src \
  -source-path generated \
  -source-path path/to/as3pb/runtime/src \
  -compiler.inline=true \
  src/Main.as
```

Alternatively, build a runtime SWC with `just build-swc`.

## Encode and decode

Replace `Message` with your generated message class:

```actionscript
const output:ByteArray = Buffers.newByteArray();
Message.serializeBytes(message, output);

output.position = 0;
const decoded:Message = Message.deserializeBytes(output, null, output.bytesAvailable);

// Reuse the destination on subsequent messages.
input.position = frameStart;
Message.deserializeBytes(input, decoded, frameLength);
```

Import `flash.utils.ByteArray`, `as3pb.proto.Buffers`, and your message class. To reuse an output buffer, set its `length` and `position` to zero before encoding.

`deserializeBytes(input, destination, length, reset = true)` requires a destination and byte count. Pass `null` to allocate. Length is relative to the current input position; zero means an empty message. Decoding resets an existing destination unless `reset` is false, which merges into it.

The optional [memory backend](runtime/MEMORY.md) adds `serializeMemory` and `deserializeMemory` for applications managing AVM2 domain memory. ByteArray methods remain enabled by default.

## Supported features

- Proto3 messages, enums, repeated fields, maps, oneofs, optional fields, and unknown-field preservation.
- Editions 2023/2024 with proto3 semantics, explicit presence, and declared defaults.
- Bundled Google protobuf types, `Any` registration, cloning, and generated unary HTTP RPC clients.

Optional scalars use nullable wrappers such as `OptionalInt`; 64-bit values, strings, bytes, and messages use nullable references. A present default value is still serialized. Declared defaults are `DEFAULT_*` constants; unset fields remain null:

```actionscript
const speed:int = msg.speed != null ? msg.speed.value : Config.DEFAULT_SPEED;
```

Both codecs pass 1,404 tests with zero unexpected failures in the protobuf v35.1 conformance suite. Invalid UTF-8 strings are deliberately accepted. Protobuf JSON/text formats, proto2, extensions, delimited encoding, and closed enums are out of scope. See [the conformance harness](https://github.com/33TU/as3pb-conformance) for details.

## Generator options

Pass options through `--as3_opt=name=value`. Environment variables use the same name with an `AS3PB_` prefix and uppercase letters, for example `AS3PB_GENERATE_DESERIALIZE_MEMORY=true`. Explicit options take precedence.

| Option | Default | Effect |
|---|---|---|
| `debug` | `false` | Log generator diagnostics. |
| `generate_always` | `false` | Include imported files, except bundled Google types. |
| `indent` | Four spaces | Generated indentation. |
| `inline_reset` | `true` | Add `[Inline]` to generated reset methods. |
| `generate_any` | `true` | Generate type URLs and automatic `AnyRegistry` registration. |
| `generate_clone` | `true` | Generate clone methods; disable to reduce code size. |
| `generate_serialize` | `true` | Generate `serializeBytes`. |
| `generate_deserialize` | `true` | Generate `deserializeBytes`. |
| `generate_serialize_memory` | `false` | Generate `serializeMemory`. |
| `generate_deserialize_memory` | `false` | Generate `deserializeMemory`. |

`as3-protoc` supplies import mappings automatically. To invoke the plugin directly, imported protos need usable Go package metadata or explicit mappings:

```sh
protoc --as3_out=generated --as3_opt=Mgame.proto=as3.pb -I proto proto/game.proto
```

## RPC

Generated methods accept an optional reusable response after the timeout:

```actionscript
client.echo(request, onComplete, onError, 0, response);
```

The response is reset and populated before the callback receives it. Omit it or pass `null` to allocate. Use separate destinations for overlapping requests; later reuse changes retained references. RPC and `AnyRegistry` require ByteArray codecs.

![AS3PB RPC sample running against the Go fixture server](assets/rpc.png)

## Development

Install Just and put the AIR SDK tools on `PATH`. `just download-air-sdk` downloads the host SDK; append `linux`, `mac`, or `windows` to select another OS. Run commands from this repository's root:

| Command | Purpose |
|---|---|
| `just` | List all recipes. |
| `just build` | Build both Go tools and the runtime SWC. |
| `just test` | Run Go tests. |
| `just test-memory` | Compile backend combinations and run memory tests in AIR. |
| `just build-runtime-test` | Generate fixtures and build the runtime test SWF. |
| `just build-runtime-bench` | Build `runtime/bin/as3pb-bench.swf` with all four codecs. |
| `just build-runtime-rpc` | Build the RPC sample SWF. |
| `just run-runtime-rpc-server` | Generate Go stubs and run the RPC fixture server. |
| `just generate-google-protobuf` | Regenerate bundled Google types with both codecs. |
| `just generate-examples` | Regenerate example messages. |
| `just build-examples` | Regenerate and compile the examples SWC. |

Runtime fixtures require protoc 27+; set `PROTOC` to select a binary. `GOOGLE_PROTOBUF_PATH` defaults to `/usr/include/google/protobuf`. Local Go tools are built into `bin/`; generated build artifacts go into `runtime/bin/`.

See [benchmark instructions](runtime/bench/README.md) for repeatable comparisons and chart generation.

## License

[MIT](LICENSE).
