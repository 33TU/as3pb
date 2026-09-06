# Apache Royale experiment

This source set preserves the optimized AS3PB/Node benchmark on the `royale`
branch. Shared runtime and generated sources remain suitable for Flash builds.
This is a benchmark prototype, not a supported Royale target yet.

## Run

Requires Bash, Node, Java, and Apache Royale 0.9.12. Install the compiler
outside the repository, for example:

```bash
npm install --prefix "$HOME/.cache/as3pb-royale" @apache-royale/royale-js@0.9.12
export ROYALE_SDK="$HOME/.cache/as3pb-royale/node_modules/@apache-royale/royale-js/royale-asjs"
just bench-royale
```

Alternatively run `bash runtime/royale/bench.sh` from the repository root.
The script compiles the shared runtime and generated sources directly, with
compiler output under ignored `runtime/bin/royale`. It adds the Royale shims to
the source path and runs compatibility checks before the timed benchmark.
`MXRoyaleBaseJS.swc` is not needed.

## Layout and scope

- `src/flash/utils/`: standalone ByteArray and Endian compatibility classes.
- `src/flash/errors/IOError.as`: the Royale error implementation.
- `src/ArgumentError.as`: global error shim used by the unchanged AnyRegistry.
- `bench/Main.as`: the original decode benchmark.
- `bench/ByteArrayTest.as`: byte-copy/cursor, numeric, UTF-8, capacity, and EOF checks.
- `experiment-notes.md`: archived August 2026 measurements and production plan.
  Its old source paths and manual build instructions are historical; use this
  README for the current layout and build command.

The recorded result was 1040–1055 ns/message, approximately tied with
protobuf.js on that fixture. It is not a fresh measurement or a general
performance guarantee. The main gains came from native Array vector emulation,
retained buffer capacity, bulk DataView reads, and a cached TextDecoder.

## Platform boundary

Shared and generated sources retain their `flash.utils` and `flash.errors` imports.
Only Royale builds include this compatibility source set; Flash builds use the SDK
classes. ByteArray provides the typed read/write, UTF-8, and byte-copy methods
used by AS3PB, caches both UTF helpers, and requires no browser `window` shim.

Royale 0.9.12 omits the generated class-initializer registration block from JS.
The benchmark therefore registers BenchMessage explicitly and checks the registry
and its ArgumentError path before timing. Production integration still needs to
provide explicit registration or a supported initialization mechanism.

The three optimized packed readers use `if (COMPILE::JS) { ... return; }`
in the shared decoder, followed by the Flash loops. The Royale build explicitly
passes `-define+=COMPILE::JS,true`. The JS-only calls use `Object(src)` because
Flash type-checks ordinary `if` bodies even when the condition is constant false.
Flash/AIR builds must pass `-define+=COMPILE::JS,false` (included in the just recipes).

## Validation and remaining work

The as3pb-conformance repository's Royale harness passed the existing binary
proto3/editions-proto3 suite on 2026-09-06: 1404 successes, 4217 skipped,
10 expected invalid-UTF-8 failures, and no unexpected failures, matching AIR.
The text-format suite remains unsupported (909 skipped). No Royale-specific
failure exclusions were added. Conformance caught and fixed Royale's signed
compound-assignment result in the unsigned varint32 decoder.

This validates the supported binary scope, not the entire Flash API. Broader
runtime reuse, cloning, Any registration, and Vector behavior still need targeted
coverage before treating Royale as a production target. Keep typed Vector APIs.
The shim intentionally implements the AS3PB subset of ByteArray; AMF, compression,
and multibyte character sets are not implemented. Vector runtime semantics are
relaxed through compiler flags.
