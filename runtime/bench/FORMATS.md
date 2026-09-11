# AS3PB ByteArray and AVM2, AMF3, and JSON

![Mixed-message benchmark](../../assets/benchmark-summary.svg)

Measured on mains power with AS3PB codec commit bfa3c22d246ed47b885c603936f9eef6c6233dbb, optimized AIR 51.3, compiler inlining enabled, and the debugger disabled. Nine rotating samples per operation targeted 150 ms each; figures use median throughput. Each workload contains 64 varied messages. Fields, decode cursors, and matching ByteArray/AVM2 wire bytes are checked before timing.

All encoders reuse their output buffers. AVM2 includes `attach`/`detach` for every message. Domain-memory binding, input copying/preparation, and context allocation occur outside timing. Decode input is prepared in a contiguous buffer with ten spare bytes after its logical end. This represents callers already managing domain memory; it does not include copying a newly received message for each decode. Small-message decoding can still favor ByteArray.

JSON timings include UTF-8 conversion. AMF3 and JSON use equivalent plain objects; AS3PB uses generated typed messages. Projection into plain objects is outside timing, and AMF3/JSON decoding does not include conversion into generated classes. 64-bit values use lossless low/high word pairs, vectors use arrays, and byte fields use unsigned-byte arrays. AMF3 can produce different results with native ByteArrays, typed vectors, or registered class aliases.

The mixed workload follows the README fixture pattern using 64 messages instead of 100. Historical README timings used different allocation and representation choices and are not directly comparable.

## Mixed-message throughput ratios

- AVM2 versus AS3PB ByteArray: encoding **5.13×**, fresh decoding **1.15×**, and reused AVM2 decoding **1.50×**.
- AVM2 versus AMF3: encoding **16.02×**, fresh decoding **3.87×**, and reused AVM2 decoding **14.42×**.
- AVM2 versus JSON: encoding **83.25×**, fresh decoding **4.92×**, and reused AVM2 decoding **18.34×**.

The ByteArray reused comparison also reuses its destination. AMF3 and JSON allocate fresh objects, so comparisons against reused AVM2 decoding are not fresh-to-fresh comparisons.

## Full results

| Workload       | Format          | Average bytes | Encode msg/s | Fresh decode msg/s | Reused decode msg/s |
| -------------- | --------------- | ------------: | -----------: | -----------------: | ------------------: |
| readme-mixed   | AS3PB AVM2      |         279.1 |      808,421 |            162,755 |             606,720 |
| readme-mixed   | AS3PB ByteArray |         279.1 |      157,605 |            141,227 |             404,211 |
| readme-mixed   | AMF3            |         669.7 |       50,479 |             42,082 |                   — |
| readme-mixed   | JSON            |         873.1 |        9,710 |             33,074 |                   — |
| negative-int32 | AS3PB AVM2      |          90.0 |    2,730,667 |          1,229,838 |           1,394,347 |
| negative-int32 | AS3PB ByteArray |          90.0 |      503,351 |            744,533 |             796,299 |
| negative-int32 | AMF3            |          71.0 |      198,667 |            185,114 |                   — |
| negative-int32 | JSON            |         117.7 |      118,667 |            353,907 |                   — |
| wide-int64     | AS3PB AVM2      |          82.7 |    2,504,053 |            687,248 |           1,465,987 |
| wide-int64     | AS3PB ByteArray |          82.7 |      525,139 |            525,139 |             897,707 |
| wide-int64     | AMF3            |         202.0 |      113,509 |             97,215 |                   — |
| wide-int64     | JSON            |         323.5 |       21,616 |             99,097 |                   — |
| packed-bools   | AS3PB AVM2      |          17.5 |    4,489,748 |          1,114,947 |           3,141,584 |
| packed-bools   | AS3PB ByteArray |          17.5 |    1,912,268 |            825,469 |           2,094,389 |
| packed-bools   | AMF3            |          39.0 |      259,241 |            230,486 |                   — |
| packed-bools   | JSON            |         100.8 |      133,901 |            458,507 |                   — |
| packed-int64   | AS3PB AVM2      |         323.5 |    1,671,837 |            133,154 |             622,389 |
| packed-int64   | AS3PB ByteArray |         323.5 |      152,421 |             95,147 |             204,800 |
| packed-int64   | AMF3            |         875.2 |       35,282 |             29,474 |                   — |
| packed-int64   | JSON            |        1343.6 |        4,601 |             20,463 |                   — |
| tables         | AS3PB AVM2      |         235.2 |      395,243 |            253,506 |             313,514 |
| tables         | AS3PB ByteArray |         235.2 |      116,994 |            247,089 |             292,693 |
| tables         | AMF3            |         394.6 |       76,883 |             61,808 |                   — |
| tables         | JSON            |         401.9 |       12,211 |             67,090 |                   — |

Values are messages per second; average bytes exclude transport framing and compression. Both AS3PB backends emit identical bytes. Payload sizes are logical lengths rather than allocated capacities. Results depend on schemas, representations, and hardware.

Run the comparison again with:

```sh
python3 runtime/bench/formats.py
```

The recorded samples and metadata are in [formats/result.json](formats/result.json) and [formats/metadata.json](formats/metadata.json). Regenerate this SVG from those exact samples with:

```sh
python3 runtime/bench/graph.py --input runtime/bench/formats/result.json
```

## User-provided runs of the original harness

These timings were supplied from the existing interactive benchmark. They use its original allocation choices: protobuf reuses its output buffer and decode destination; JSON and AMF3 allocate output buffers. They are recorded separately from the controlled comparison above. Exact runtime versions, hardware, power state, and message counts were not recorded with these runs.

| Runtime                | Protobuf encode | JSON encode | AMF3 encode | Protobuf decode | JSON decode | AMF3 decode |
| ---------------------- | --------------: | ----------: | ----------: | --------------: | ----------: | ----------: |
| Ruffle                 |          327 ms |      359 ms |      706 ms |          474 ms |      408 ms |      429 ms |
| Electron / PepperFlash |          130 ms |    3,031 ms |      372 ms |           60 ms |      523 ms |      657 ms |

Within the PepperFlash run, protobuf encoding throughput was 23.32× JSON and 2.86× AMF3; reused protobuf decoding throughput was 8.72× JSON and 10.95× AMF3. These runs are not controlled comparisons between runtimes.

## Earlier README snapshot

This older Flash Player run used 100 messages and 300 iterations. Runtime version and hardware were not recorded; it is separate from the controlled results above.

![Earlier Flash Player benchmark](../../assets/benchmark.png)

| Format          | Average bytes |   Encode | Decode |    Total |
| --------------- | ------------: | -------: | -----: | -------: |
| AS3PB ByteArray |           285 |    85 ms |  35 ms |   120 ms |
| JSON            |           718 | 1,608 ms | 283 ms | 1,891 ms |
| AMF3            |           593 |   197 ms | 374 ms |   571 ms |
