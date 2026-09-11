# ByteArray benchmark results

Baseline: f7617c4 (main). Candidate: f5e2cac (bytearray-optimizations).
Results were measured on mains power.

## Expanded full-message workloads

Optimized AIR 51.3, compiler inlining enabled, debugger disabled. Both revisions run in one process using the same generated API. Each workload uses 64 fixtures, with nine alternating samples targeting 150 ms per variant and median throughput. Every decoded field and cursor is checked before timing; serialized bytes match between revisions.

| Workload       |    Pack | Fresh decode | Reused decode |
| -------------- | ------: | -----------: | ------------: |
| negative-int32 | +168.5% |        -0.7% |         +0.0% |
| wide-int64     | +185.3% |        +0.0% |         +0.0% |
| packed-bools   | +114.7% |        -1.2% |         -0.6% |
| packed-int64   | +161.6% |        +0.7% |         +1.2% |
| tables         |   +0.0% |        +0.0% |         -0.7% |

These encoding gains are approximately 2.69×, 2.85×, 2.15×, and 2.62× respectively for the first four workloads. They deliberately exercise the optimized field types; they are not general speedups for arbitrary messages.

## Table-vector controls

Identical candidate commits on both sides (A/A):

| Workload |  Pack | Fresh decode | Reused decode |
| -------- | ----: | -----------: | ------------: |
| tables   | -0.2% |        +0.0% |         +0.7% |

Reversed comparison (baseline is the branch; candidate is main, so positive favors main):

| Workload |  Pack | Fresh decode | Reused decode |
| -------- | ----: | -----------: | ------------: |
| tables   | -0.1% |        +0.1% |         +0.0% |

## Original mixed workloads

The earlier FlatBuffers comparison fixtures were also rerun against main using the current candidate runtime. These use seven alternating samples targeting 100 ms, with 64 fixtures per workload. They do not include negative int32, packed bool, or varint64 fields.

| Workload        |  Pack | Fresh decode | Reused decode |
| --------------- | ----: | -----------: | ------------: |
| scalars         | +1.3% |        +2.3% |         +1.1% |
| inline-structs  | +0.2% |        +0.9% |         +1.0% |
| nested-8-nodes  | -1.0% |        +0.0% |         -0.7% |
| strings-short   | +1.0% |        -0.4% |         -1.0% |
| strings-long    | +0.0% |        +0.0% |         +0.0% |
| vectors-scalars | +0.9% |        -0.1% |         -0.2% |
| vectors-strings | +1.2% |        -1.1% |         -2.0% |
| vectors-structs | -0.1% |        +0.3% |         -0.8% |
| vectors-tables  | +0.1% |        +0.9% |         -0.3% |

The controls do not establish a consistent table-vector regression; small differences may be timing noise.

## Generator timing

One run over a 109-file production schema (~950 generated classes),
protoc 35.1, warm cache, plugin startup included:

| Generator                 | Time   | Files |
| ------------------------- | ------ | ----- |
| python (in-process)       | 0.11 s | 107   |
| **as3-protoc**            | 0.24 s | 925   |
| java (in-process)         | 0.80 s | 107   |
| C++ (in-process)          | 1.30 s | 214   |
| protobuf-ts 2.11 (plugin) | 1.63 s | 113   |

File counts reflect language layout: AS3 emits one public class per file. Built-in generators run inside protoc; plugin timings include descriptor transfer and subprocess startup.
