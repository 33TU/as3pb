# ByteArray revision comparison

Run from the as3pb directory with Go, protoc, and AIR SDK amxmlc / adl on PATH:

~~~sh
python3 runtime/bench/bytearray.py --baseline main --candidate HEAD
~~~

The benchmark snapshots **committed** runtime sources without switching branches. It uses the current working-tree generator for both sides, so the comparison requires revisions with the same generated API and is intended to isolate runtime changes. Set PROTOC, AMXMLC, or ADL to override the corresponding command.

Workloads contain 64 varied messages and measure serialization into a reused ByteArray, fresh decoding, and decoding into a reused message:
- Eight negative int32 fields.
- Eight full-width uint64, int64, and sint64 fields.
- Packed bool vectors of 0, 8, 16, and 32 elements.
- Packed signed, unsigned, and zigzag 64-bit vectors of those lengths.
- Repeated point messages, to exercise allocation-heavy decoding.

Each side validates every decoded field and input cursor before timing. Serialized bytes must match across revisions. Both versions run in one optimized AIR process with compiler inlining enabled and the debugger disabled. Calibration warms each operation, then measurement order alternates over nine samples of approximately 150 ms. Results report median throughput. GC, class layout, and timing noise can still affect results; small differences require repeat runs and controls.

Artifacts go to runtime/bin/bytearray-bench/ by default: comparison.md, raw result.json, commit metadata, generated sources, and build/runtime logs. Use a distinct --output directory to retain each run.

For an A/A control and a reversed comparison:

~~~sh
python3 runtime/bench/bytearray.py --baseline HEAD --candidate HEAD --workloads tables --output runtime/bin/bytearray-aa
python3 runtime/bench/bytearray.py --baseline HEAD --candidate main --workloads tables --output runtime/bin/bytearray-reversed
~~~

Use --samples and --target-ms to change measurement duration. Percentage changes are always **candidate relative to baseline**.

See [RESULTS.md](RESULTS.md) for the mains-powered comparison and controls.

## AMF3 and JSON comparison

~~~sh
python3 runtime/bench/formats.py
~~~

This uses the current checkout, the README's mixed-message schema and fixture pattern (64 messages), plus the expanded integer, bool, and table workloads. All encoders reuse their output ByteArray. JSON includes UTF-8 conversion in both directions. AMF3 and JSON decode fresh plain objects; AS3PB ByteArray and AVM2 each report fresh and reused typed-message decoding separately.

AVM2 uses `Pack.attach`/`Pack.detach` or `Unpack.attach`/`Unpack.detach` for every message, inside timing. The domain-memory binding is installed before each sample and restored afterward, outside timing. Decode inputs are copied into a contiguous buffer with spare capacity before timing; no input copy is measured. Output buffers and contexts are reused. Payload sizes report logical message lengths, not allocated capacity. This measures callers that already manage domain memory; small messages can still favor ByteArray.

The plain-object projection happens before timing and preserves all logical fields: 64-bit values are represented as low/high word pairs, vectors as arrays, and bytes as arrays of unsigned byte values. Unknown-field storage is excluded. This is a plain-object AMF3 comparison, not the class-alias AMF3 representation used by the historical README screenshot. Results are not directly comparable to that older benchmark, which allocated new output buffers for AMF3/JSON and measured only reused protobuf decoding.

All decoded fields are validated before timing. Output artifacts, including average payload sizes and raw samples, go to runtime/bin/formats-bench/. Set --output, --samples, and --target-ms as in the revision comparison. See [FORMATS.md](FORMATS.md) for recorded results and the saved samples used by the README SVG.

Regenerate the README SVG from a format comparison result (requires matplotlib):

~~~sh
python3 runtime/bench/graph.py --input runtime/bin/formats-bench/result.json
~~~
