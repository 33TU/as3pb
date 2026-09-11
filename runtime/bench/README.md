# Benchmarks

Run commands from the AS3PB root with Go, protoc, Python 3, and AIR's `amxmlc`/`adl` on `PATH`. Use `PROTOC`, `AMXMLC`, and `ADL` to override tool paths.

## Interactive SWF

```sh
just build-runtime-bench
```

Open `runtime/bin/as3pb-bench.swf` in your target runtime. It compares AS3PB ByteArray, AS3PB memory, AMF3, and JSON over 100 messages and 300 iterations. The button repeats the run.

AS3PB reuses output buffers and decode destinations. AMF3/JSON allocate output buffers and decoded objects; JSON maps only a subset of fields back to the typed message. AMF3 uses registered class aliases. Memory includes attach/detach per message, with binding and input preparation outside timing. Memory wire bytes and round trips are checked before timing.

This interactive comparison differs from the controlled format benchmark below.

## AMF3 and JSON comparison

```sh
python3 runtime/bench/formats.py
```

Compares ByteArray, AVM2, AMF3, and JSON with 64 varied fixtures across six workloads. All encoders reuse buffers. AS3PB reports fresh and reused decoding separately; AMF3/JSON decode fresh plain objects. JSON timings include UTF-8 conversion.

Plain-object conversion occurs before timing and preserves every logical field: 64-bit integers use low/high word pairs, vectors use arrays, and bytes use unsigned-byte arrays. Unknown-field storage is excluded. All decoded fields are validated; both protobuf backends must emit identical bytes.

AVM2 includes per-message attach/detach. Binding, input copying, and buffer/context preparation are outside timing. Sizes are logical payload lengths, not capacity. This models callers already managing domain memory; small messages can still favor ByteArray.

Results and logs go to `runtime/bin/formats-bench/`. See [recorded results](FORMATS.md) and [raw samples](formats/result.json).

Regenerate the README SVG with Matplotlib:

```sh
python3 runtime/bench/graph.py --input runtime/bench/formats/result.json
```

For a new run, use `runtime/bin/formats-bench/result.json` instead.

## ByteArray revision comparison

```sh
python3 runtime/bench/bytearray.py --baseline main --candidate HEAD
```

Snapshots committed runtime sources without switching branches and uses the working-tree generator for both sides. Revisions must support the same generated API. Workloads cover negative int32, full-width 64-bit integers, packed bool/64-bit vectors, and repeated messages.

Both revisions run in one optimized AIR process, with inlining enabled and the debugger disabled. Wire bytes, decoded fields, and cursors are checked before timing. Results go to `runtime/bin/bytearray-bench/`; percentage changes are candidate relative to baseline. [Historical results](RESULTS.md).

Use controls when assessing small differences:

```sh
python3 runtime/bench/bytearray.py --baseline HEAD --candidate HEAD --workloads tables --output runtime/bin/bytearray-aa
python3 runtime/bench/bytearray.py --baseline HEAD --candidate main --workloads tables --output runtime/bin/bytearray-reversed
```

Both Python benchmarks warm up and calibrate each operation, then report median throughput from nine rotating/alternating samples targeting 150 ms. Use `--samples`, `--target-ms`, and `--output` to adjust runs. Keep power state and background load consistent; small differences need repeat measurements.
