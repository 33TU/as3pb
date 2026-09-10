# AS3PB, AMF3, and JSON

![Mixed-message benchmark](../../assets/benchmark-summary.svg)

Measured on mains power with AS3PB commit da728181c1020c57487b8233b755ac55259c88bd, optimized AIR 51.3, compiler inlining enabled, and the debugger disabled. Nine rotating samples per operation targeted 150 ms each; figures use median throughput. Each workload contains 64 varied messages. All fields and decode cursors are checked before timing.

All encoders reuse their output ByteArray. JSON timings include UTF-8 encoding and decoding. AMF3 and JSON use equivalent plain objects; AS3PB uses generated typed messages. Projection into plain objects is outside timing, and decoding AMF3/JSON does not include conversion into generated message classes. 64-bit values use lossless low/high word pairs, vectors use arrays, and byte fields use unsigned-byte arrays. AMF3 could have different results with native ByteArrays, typed vectors, or registered class aliases.

The mixed workload follows the README fixture pattern using 64 messages instead of 100. The historical README numbers used different allocation and representation choices and are not directly comparable.

## Mixed-message throughput ratios

- Versus AMF3: encoding 3.11×, fresh decoding 3.40×, and reused protobuf decoding 9.83× the throughput.
- Versus JSON: encoding 16.41×, fresh decoding 4.36×, and reused protobuf decoding 12.60× the throughput.

Reused protobuf decoding is shown separately because AMF3 and JSON allocate fresh objects. It is not a fresh-to-fresh comparison.

## Full results

| Workload | Format | Average bytes | Encode msg/s | Fresh decode msg/s | Reused decode msg/s |
|---|---|---:|---:|---:|---:|
| readme-mixed | as3pb | 279.1 | 156,541 | 141,227 | 408,500 |
| readme-mixed | amf3 | 669.7 | 50,255 | 41,536 | — |
| readme-mixed | json | 873.1 | 9,540 | 32,421 | — |
| negative-int32 | as3pb | 90.0 | 503,351 | 744,533 | 799,147 |
| negative-int32 | amf3 | 71.0 | 195,200 | 184,795 | — |
| negative-int32 | json | 117.7 | 116,907 | 350,926 | — |
| wide-int64 | as3pb | 82.7 | 533,616 | 521,684 | 891,762 |
| wide-int64 | amf3 | 202.0 | 112,941 | 94,189 | — |
| wide-int64 | json | 323.5 | 21,189 | 96,221 | — |
| packed-bools | as3pb | 17.5 | 1,917,908 | 793,854 | 2,094,389 |
| packed-bools | amf3 | 39.0 | 262,013 | 227,556 | — |
| packed-bools | json | 100.8 | 132,129 | 445,217 | — |
| packed-int64 | as3pb | 323.5 | 151,415 | 95,147 | 202,378 |
| packed-int64 | amf3 | 875.2 | 35,137 | 29,165 | — |
| packed-int64 | json | 1343.6 | 4,539 | 20,259 | — |
| tables | as3pb | 235.2 | 122,526 | 240,865 | 289,503 |
| tables | amf3 | 394.6 | 76,387 | 60,108 | — |
| tables | json | 401.9 | 12,075 | 65,730 | — |

Values are messages per second; average bytes exclude transport framing and compression. Payload size is workload-dependent: AMF3 is smaller than protobuf for the negative-int32 fixture, despite protobuf encoding faster. These results are specific to these schemas, representations, and hardware.

Run the comparison again with:

~~~sh
python3 runtime/bench/formats.py
~~~

## User-provided runs of the original harness

These timings were supplied from the existing interactive benchmark. They use its original allocation choices: protobuf reuses its output buffer and decode destination; JSON and AMF3 allocate output buffers. They are recorded separately from the controlled comparison above. Exact runtime versions, hardware, power state, and message counts were not recorded with these runs.

| Runtime | Protobuf encode | JSON encode | AMF3 encode | Protobuf decode | JSON decode | AMF3 decode |
|---|---:|---:|---:|---:|---:|---:|
| Ruffle | 327 ms | 359 ms | 706 ms | 474 ms | 408 ms | 429 ms |
| Electron / PepperFlash | 130 ms | 3,031 ms | 372 ms | 60 ms | 523 ms | 657 ms |

Within the PepperFlash run, protobuf encoding throughput was 23.32× JSON and 2.86× AMF3; reused protobuf decoding throughput was 8.72× JSON and 10.95× AMF3. These runs are not controlled comparisons between runtimes.
