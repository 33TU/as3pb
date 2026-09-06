# AS3PB Apache Royale optimization notes

Date: 2026-08-09

Repository: `/home/eetu/Projects/github.com-33TU/as3pb-conformance/as3pb`

## Result

The same 28,300-byte payload across 100 messages reached approximately:

```text
Stock Royale Vector + ByteArray          7760 ns/msg    36.5 MB/s
Retained-capacity ByteArray              7350 ns/msg    38.5 MB/s
Manual native repeated-field arrays      1490 ns/msg   189.9 MB/s
Bulk DataView + cached TextDecoder        1110 ns/msg   255.0 MB/s
Royale Array emulation compiler flags     1040 ns/msg   272.1 MB/s
```

Representative final typed-Vector source run using Array emulation:

```text
Node v24.13.1; Apache Royale 0.9.12
payload: 28300 bytes across 100 messages
trial 1: 211ms (1055 ns/msg, 268.2 MB/s)
trial 2: 213ms (1065 ns/msg, 265.7 MB/s)
trial 3: 208ms (1040 ns/msg, 272.1 MB/s)
trial 4: 208ms (1040 ns/msg, 272.1 MB/s)
trial 5: 208ms (1040 ns/msg, 272.1 MB/s)
trial 6: 208ms (1040 ns/msg, 272.1 MB/s)
trial 7: 208ms (1040 ns/msg, 272.1 MB/s)
median: 208ms (1040 ns/msg, 272.1 MB/s)
sink: 1287220220000
```

For context, earlier measurements on the same message were approximately:

```text
protobuf.js                   1044 ns/msg
protobuf-ts                   1146 ns/msg
Royale AS3PB optimized        1040 ns/msg
AVM2 domain memory            1840 ns/msg
PepFlash AS3PB                2000 ns/msg
ADL ByteArray                 2530 ns/msg
protobuf-es                   4395 ns/msg
```

These are useful comparisons, but not a rigorous cross-runtime benchmark suite.

## Main performance patches

### 1. Compile typed Vector as native Array

This was by far the largest improvement.

The initial experiment manually changed repeated fields to `Array`, but this was ultimately unnecessary. Royale already provides these advanced compiler flags:

```text
-js-vector-emulation-class=Array
-js-vector-index-checks=false
```

The AS sources therefore retain their normal typed declarations:

```actionscript
public var samples:Vector.<uint> = new Vector.<uint>();
```

Royale emits native JS arrays without the expensive `VectorSupport` wrappers or `_ci` index checks. `Int64Vector.low/high`, generated fields, and Serialize/Deserialize APIs remain typed as Vector in source.

Royale's default Vector compatibility implementation performs argument slicing, type validation/coercion, `apply()`, and index checking. Array emulation reduced decode time by several times while retaining a clean typed AS API. It was also slightly faster than the manual Array experiment because every Vector in the benchmark harness and supporting runtime was lowered consistently.

### 2. Retained-capacity ByteArray

A Royale-specific replacement exists at:

```text
runtime/royale-patches/mx/utils/ByteArray.as
```

Stock Royale reallocates its underlying `ArrayBuffer` whenever logical `length` changes. Generated message reuse repeatedly clears and refills bytes fields.

The patch:

- retains backing capacity when logical length shrinks;
- grows capacity geometrically, with a 64-byte minimum;
- overwrites existing storage when possible;
- zeros truncated regions to preserve regrowth semantics;
- makes `writeBinaryData()` use the source's logical length.

Important caveat: `byteArray.data.byteLength` may exceed `byteArray.length` because capacity and logical length are separate.

### 3. Bulk packed-field DataView decoding

The patched ByteArray provides:

```actionscript
readPackedFixed32(out, count)
readPackedSfixed64(low, high, count)
readPackedFloat(out, count)
```

Each method obtains one `DataView`, keeps a local cursor for the complete packed field, and commits `_position` once. It avoids a ByteArray method call, endianness check, DataView lookup, and position mutation for every individual element.

The optimized pattern is effectively:

```actionscript
const view:DataView = getDataView();
var p:uint = _position;

for (var i:uint = 0; i < count; i++, p += 4)
    out[i] = view.getUint32(p, true);

_position = p;
```

`runtime/src/as3pb/proto/Deserialize.as` routes packed fixed32, signed fixed64, and float fields through these methods.

### 4. Cached TextDecoder

Royale's stock `BinaryData.readUTFBytes()` constructs a new `TextDecoder("utf-8")` for every string.

The patched ByteArray keeps one static decoder:

```actionscript
private static const UTF8_DECODER:TextDecoder =
    new TextDecoder("utf-8");
```

Its `readUTFBytes()` override reuses that decoder. TextDecoder construction disappeared from the optimized CPU profile.

## Royale compatibility changes

The temporary AS source conversion also includes:

- `flash.utils.ByteArray` to `mx.utils.ByteArray`;
- `flash.utils.Endian` to `mx.utils.Endian`;
- ByteArray-to-ByteArray copies changed from `readBytes/writeBytes` to `readBinaryData/writeBinaryData`;
- local `runtime/src/as3pb/proto/IOError.as`;
- local `runtime/royale-patches/mx/utils/Endian.as`;
- benchmark-only removal of `AnyRegistry` registration;
- benchmark entry point at `runtime/test/royalebench/Main.as`.

No Go generator code was changed.

## Final profile summary

After native arrays, bulk reads, and cached UTF decoding, approximate sampled CPU time was:

```text
19.6%  generated message loop and tag dispatch
11.3%  bulk packed signed fixed64
 8.9%  message reset
 6.5%  bulk packed fixed32
 6.2%  bulk packed float
 4.8%  UTF-8 decoding
 4.5%  packed sint32
 4.3%  packed varint32
 3.6%  garbage collection
```

At this stage the old Vector bottleneck is gone. Most remaining time is real field decoding, message dispatch, and reset work.

## Compile and run

Run from the nested `as3pb` repository:

```bash
cd /home/eetu/Projects/github.com-33TU/as3pb-conformance/as3pb

ROYALE_SDK=/tmp/as3pb-royale/node_modules/@apache-royale/royale-js/royale-asjs

"$ROYALE_SDK/js/bin/asnodec" \
  -debug=false \
  -js-vector-emulation-class=Array \
  -js-vector-index-checks=false \
  -library-path+="$ROYALE_SDK/frameworks/js/libs/CoreJS.swc" \
  -library-path+="$ROYALE_SDK/frameworks/js/libs/XMLJS.swc" \
  -source-path+="$PWD/runtime/royale-patches" \
  -source-path+="$PWD/runtime/src" \
  -source-path+="$PWD/runtime/test/generated" \
  "$PWD/runtime/test/royalebench/Main.as"
```

Do not link `MXRoyaleBaseJS.swc` for this experiment. The source path deliberately replaces its `mx.utils.ByteArray` and `mx.utils.Endian` classes.

Run the optimized bundle:

```bash
node -e 'global.window=globalThis; require("./runtime/test/royalebench/bin/js-release/index.js")'
```

The `window` shim is needed because Royale's binary utilities test for browser UTF APIs through `window` even on the Node target.

## Production considerations

The source-level repeated-field API can remain typed `Vector.<T>` and therefore does not require generator changes. Flash continues to use native AVM2 Vector, while Royale uses Array emulation through compiler configuration.

The Array-emulation flags deliberately relax JS-side Vector semantics: runtime element coercion, fixed-length enforcement, Vector identity checks, and index errors may differ. They are appropriate only when generated code already writes correctly typed values and performs valid indexing.

The ByteArray replacement and bulk DataView methods remain Royale-specific. The normal Flash build still needs native `flash.utils.ByteArray`, so those imports and implementations require conditionalization or separate target source paths for production.

## Current conclusion

Apache Royale support should not require a separate protobuf codec or manually generated Array fields. The shared codec structure translates efficiently. The remaining work is primarily a small platform layer around ByteArray, errors, and target-specific bulk operations.

The preferred target arrangement is:

```text
Shared generated/runtime code
├── typed Vector.<T> declarations
├── Serialize/Deserialize logic
├── Int64/UInt64
└── message APIs

Flash build
├── native flash.utils.ByteArray
├── native AVM2 Vector.<T>
└── optional domain-memory backend

Royale build
├── project-owned ByteArray implementation
├── Vector.<T> compiled as Array
├── cached TextEncoder/TextDecoder
└── bulk Uint8Array/DataView operations
```

## Suggested next-session plan

### 1. Create a project-owned Royale ByteArray

Move the experimental `mx.utils.ByteArray` behavior into a deliberate, documented Royale platform source set. Required API surface for AS3PB includes:

- `position`, `length`, `bytesAvailable`, and `endian`;
- `clear()`;
- byte, int32, float32, and float64 reads/writes;
- UTF-8 reads/writes;
- ByteArray-to-ByteArray copying;
- access to the backing `Uint8Array`, `DataView`, or `ArrayBuffer`;
- retained capacity separate from logical length.

The class should grow geometrically rather than reallocating for every write. Decide whether exposed backing data may be larger than logical length; if so, document that consumers must use `.length`.

### 2. Cache both UTF helpers

The decode experiment caches `TextDecoder`. Serialization should similarly cache `TextEncoder` instead of constructing one for every string.

The project-owned implementation should reference `TextEncoder` and `TextDecoder` directly on JS and avoid requiring:

```js
global.window = globalThis;
```

### 3. Preserve typed Vector source declarations

Do not generate manual Array fields. Use:

```text
-js-vector-emulation-class=Array
-js-vector-index-checks=false
```

This retains clean AS APIs and native AVM2 Vector behavior while producing plain arrays on Royale.

The JS-side semantic tradeoff is intentional: fixed-length enforcement, runtime element coercion, Vector identity, and index errors are relaxed. Generated protobuf code already writes correctly typed values and valid indices.

### 4. Isolate target-specific bulk reads

Keep these Royale optimizations:

- packed fixed32 through one local DataView/cursor;
- packed signed fixed64 through one local DataView/cursor;
- packed float through one local DataView/cursor.

Use conditional target code so Flash retains its existing native ByteArray loops or domain-memory path.

### 5. Unify binary-copy operations

Flash exposes `readBytes/writeBytes`; Royale BinaryData exposes `readBinaryData/writeBinaryData`. Hide this difference behind a small platform helper or provide the same logical methods on the project-owned shim. Avoid scattering target conditionals throughout generated messages.

### 6. Normalize errors

Either use `Error` everywhere or define an AS3PB error with target-specific bases:

```actionscript
COMPILE::SWF
public class IOError extends flash.errors.IOError {}

COMPILE::JS
public class IOError extends Error {}
```

### 7. Restore production-only behavior

The benchmark manually removed `AnyRegistry` registration to avoid pulling unrelated generated types into the test bundle. Restore or preserve registration in production builds.

### 8. Validate before treating it as supported

Run both Flash and Royale tests covering:

- conformance vectors and malformed/truncated inputs;
- all scalar wire types;
- packed and unpacked repeated fields;
- nested messages and reusable message buffers;
- bytes/string fields of changing lengths;
- unknown-field capture and re-emission;
- cloning and buffer-position semantics;
- Int64/UInt64 edge values;
- serialization as well as deserialization benchmarks.

## Modern JavaScript output finding

Royale 0.9.12 primarily emits ES5-style prototype code. Passing this Closure option succeeds:

```text
-js-compiler-option="--language_out ECMASCRIPT_2015"
```

However, the tested release bundle still contained no native `class`, `let`, `const`, or arrow syntax. A modern-syntax emitter would require compiler work and is not expected to materially improve codec performance. Data layout, allocation behavior, and method-call overhead were much more important.

## AIR/Royale conditional compilation

The feature used by blocks such as these is called **ActionScript conditional compilation**. `COMPILE` is a configuration namespace, while `JS` and `SWF` are compile-time Boolean constants:

```actionscript
COMPILE::JS
{
    // Royale/JavaScript implementation
}

COMPILE::SWF
{
    // AIR/Flash implementation
}
```

`COMPILE::JS` and `COMPILE::SWF` are Royale conventions rather than built-in ActionScript keywords. Royale normally supplies values appropriate to its output target. AIR's `mxmlc`/`amxmlc` supports the same underlying mechanism, but the values should be supplied explicitly:

```bash
amxmlc \
  -define+=COMPILE::SWF,true \
  -define+=COMPILE::JS,false \
  Main.as
```

Use `+=` so these definitions do not replace other compiler definitions. The corresponding Royale JS configuration should select the opposite values:

```text
COMPILE::SWF=false
COMPILE::JS=true
```

Conditional compilation can guard statements, method bodies, variables, functions, and class definitions. This makes it suitable for the project-owned ByteArray implementation, error classes, and optimized packed-field paths.

Important AIR compiler limitation: do not put `import` statements or metadata inside conditional-compilation blocks. For code shared with AIR, keep common imports unconditional, use fully qualified class names inside target blocks, or place target-specific implementations in separate source paths.

For example, a target-specific error can avoid conditional imports:

```actionscript
COMPILE::SWF
public class IOError extends flash.errors.IOError
{
    public function IOError(message:String = "")
    {
        super(message);
    }
}

COMPILE::JS
public class IOError extends Error
{
    public function IOError(message:String = "")
    {
        super(message);
    }
}
```

Compiler references:

- AIR application compiler: <https://airsdk.dev/docs/building/actionscript-compilers/application-compiler>
- Royale compiler options: <https://apache.github.io/royale-docs/compiler/compiler-options>
- Royale target-specific library configuration: <https://apache.github.io/royale-docs/libraries/compiled-code-libraries>
