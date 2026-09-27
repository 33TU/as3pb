package bench
{
    import flash.net.ObjectEncoding;
    import flash.net.registerClassAlias;
    import flash.system.ApplicationDomain;
    import flash.utils.ByteArray;

    import bench.BenchMessage;
    import as3pb.proto.Buffers;
    import as3pb.proto.Pack;
    import as3pb.proto.PackContext;
    import as3pb.proto.Unpack;
    import as3pb.proto.UnpackContext;
    import as3pb.types.Int64;
    import as3pb.types.Int64Vector;
    import as3pb.types.UInt64;
    import as3pb.types.UInt64Vector;

    /**
     * The benchmark itself, shared by the Flash/AIR app (Main) and the avmshell
     * entry point (ShellMain). Lines whose values are timings are logged with
     * measured = true, so a comparison of two runs can skip exactly those.
     */
    public final class Benchmark
    {
        private static const TEST_DATA_SIZE:int = 100;
        private static const ITERATIONS:int = 300;

        /** function(message:String, measured:Boolean):void */
        private var _log:Function;

        public function Benchmark(log:Function)
        {
            _log = log;
            registerClassAlias("bench.BenchMessage", BenchMessage);
            registerClassAlias("as3pb.types.Int64", Int64);
            registerClassAlias("as3pb.types.Int64Vector", Int64Vector);
            registerClassAlias("as3pb.types.UInt64", UInt64);
            registerClassAlias("as3pb.types.UInt64Vector", UInt64Vector);
        }

        /** Run every benchmark and report the results through the log function. */
        public function run():void
        {
            log("=== AS3PB Runtime Benchmark ===");
            log("Messages: " + TEST_DATA_SIZE);
            log("Iterations: " + ITERATIONS);
            log("");

            const testData:Vector.<BenchMessage> = createTestData(TEST_DATA_SIZE);
            const protoResults:Object = benchmarkProtocolBuffers(testData, ITERATIONS);
            const memoryResults:Object = benchmarkMemory(testData, ITERATIONS);
            const jsonResults:Object = benchmarkJSON(testData, ITERATIONS);
            const amf3Results:Object = benchmarkAMF3(testData, ITERATIONS);

            displayBenchmarkResults(protoResults, memoryResults, jsonResults, amf3Results);
            log("");
            log("--- Wire checksum ---");
            log("AS3PB bytes: " + wireChecksum(testData));
            log("");
            log("Done.");
        }

        /** FNV-1a over every message's protobuf bytes: sizes alone miss wrong bytes of the right length. */
        private function wireChecksum(testData:Vector.<BenchMessage>):String
        {
            const buffer:ByteArray = Buffers.newByteArray();
            var hash:uint = 2166136261;
            for each (var msg:BenchMessage in testData)
            {
                buffer.length = 0;
                buffer.position = 0;
                BenchMessage.serializeBytes(msg, buffer);
                for (var i:uint = 0; i < buffer.length; i++)
                {
                    hash ^= buffer[i];
                    hash = uint(hash * 16777619);
                }
            }
            return hash.toString(16);
        }

        private function createTestData(count:int):Vector.<BenchMessage>
        {
            const messages:Vector.<BenchMessage> = new Vector.<BenchMessage>();

            for (var i:int = 0; i < count; i++)
            {
                const msg:BenchMessage = new BenchMessage();
                msg.id = "message-" + i;
                msg.sequence = i + 1;
                msg.delta = (i % 2 == 0) ? i : -i;
                msg.accountId = new UInt64(100000 + i, 1);
                msg.scoreDelta = Int64.fromNumber((i % 2 == 0 ? 1 : -1) * (1337 + i));
                msg.checksum = 0x12340000 + i;
                msg.signedTick = Int64.fromNumber(-1000000 - i);
                msg.x = i * 1.25;
                msg.precision = i * 0.0009765625;
                msg.active = (i % 2) == 0;
                msg.payload.writeUTFBytes("payload-" + i);
                msg.payload.position = 0;

                for (var j:int = 0; j < 10; j++)
                {
                    msg.samples.push(j * 100000 + i);
                    msg.offsets.push((j % 2 == 0) ? j + i : -j - i);
                    msg.hashes.push(0xabcdef00 + j + i);
                    msg.positions.push(i + j * 0.5);
                }

                for (var k:int = 0; k < 10; k++)
                {
                    const tick:Int64 = Int64.fromNumber(-1000000000 - (k * 1000) - i);
                    msg.ticks.push(tick.low, tick.high);
                }

                messages.push(msg);
            }

            return messages;
        }

        private function benchmarkProtocolBuffers(testData:Vector.<BenchMessage>, iterations:int):Object
        {
            const buffer:ByteArray = Buffers.newByteArray();
            const serialized:Vector.<ByteArray> = new Vector.<ByteArray>();
            var totalSerializedSize:int = 0;

            var startTime:Number = new Date().time;
            for (var iter:int = 0; iter < iterations; iter++)
            {
                for each (var msg:BenchMessage in testData)
                {
                    buffer.length = 0;
                    buffer.position = 0;
                    BenchMessage.serializeBytes(msg, buffer);

                    if (iter == 0)
                    {
                        const copy:ByteArray = Buffers.newByteArray();
                        copy.writeBytes(buffer, 0, buffer.length);
                        serialized.push(copy);
                        totalSerializedSize += buffer.length;
                    }
                }
            }
            const serializationTime:Number = new Date().time - startTime;

            const decoded:BenchMessage = new BenchMessage();
            startTime = new Date().time;
            for (iter = 0; iter < iterations; iter++)
            {
                for each (var bytes:ByteArray in serialized)
                {
                    bytes.position = 0;
                    BenchMessage.deserializeBytes(bytes, decoded, bytes.bytesAvailable);
                }
            }
            const deserializationTime:Number = new Date().time - startTime;

            return {
                    serializationTime: serializationTime,
                    deserializationTime: deserializationTime,
                    totalTime: serializationTime + deserializationTime,
                    serializedSize: totalSerializedSize,
                    averageSize: Math.round(totalSerializedSize / testData.length)
                };
        }

        private function benchmarkMemory(testData:Vector.<BenchMessage>, iterations:int):Object
        {
            const output:ByteArray = Buffers.newByteArray();
            const input:ByteArray = Buffers.newByteArray();
            const reference:ByteArray = Buffers.newByteArray();
            const offsets:Vector.<uint> = new Vector.<uint>();
            const lengths:Vector.<uint> = new Vector.<uint>();
            const encoder:PackContext = new PackContext();
            const decoder:UnpackContext = new UnpackContext();
            const decoded:BenchMessage = new BenchMessage();
            var maximumLength:uint = 0;

            // Prepare input and output capacity outside timing.
            for each (var msg:BenchMessage in testData)
            {
                reference.length = 0;
                reference.position = 0;
                BenchMessage.serializeBytes(msg, reference);
                offsets.push(input.length);
                lengths.push(reference.length);
                input.position = input.length;
                if (reference.length)
                    input.writeBytes(reference);
                maximumLength = Math.max(maximumLength, reference.length);
            }
            const totalSerializedSize:uint = input.length;
            input.length = Math.max(ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH, input.length + 10);
            output.length = Math.max(ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH, maximumLength);

            const domain:ApplicationDomain = ApplicationDomain.currentDomain;
            const previous:ByteArray = domain.domainMemory;
            var serializationTime:Number;
            var deserializationTime:Number;
            try
            {
                domain.domainMemory = output;
                // Validate identical wire bytes before timing.
                for (var i:uint = 0; i < testData.length; i++)
                {
                    Pack.attach(encoder, 0);
                    try
                    {
                        BenchMessage.serializeMemory(testData[i], encoder);
                    }
                    finally
                    {
                        Pack.detach(encoder);
                    }
                    if (encoder.position != lengths[i])
                        throw new Error("Memory encode length mismatch");
                    for (var j:uint = 0; j < lengths[i]; j++)
                    {
                        if (output[j] != input[offsets[i] + j])
                            throw new Error("Memory encode bytes mismatch");
                    }
                }

                domain.domainMemory = input;
                for (i = 0; i < testData.length; i++)
                {
                    Unpack.attach(decoder, offsets[i], lengths[i]);
                    try
                    {
                        BenchMessage.deserializeMemory(decoder, decoded, lengths[i]);
                    }
                    finally
                    {
                        Unpack.detach(decoder);
                    }
                    if (decoder.position != offsets[i] + lengths[i])
                        throw new Error("Memory decode cursor mismatch");
                    reference.length = 0;
                    reference.position = 0;
                    BenchMessage.serializeBytes(decoded, reference);
                    if (reference.length != lengths[i])
                        throw new Error("Memory round-trip length mismatch");
                    for (j = 0; j < lengths[i]; j++)
                    {
                        if (reference[j] != input[offsets[i] + j])
                            throw new Error("Memory round-trip bytes mismatch");
                    }
                }

                domain.domainMemory = output;
                var startTime:Number = new Date().time;
                for (var iter:int = 0; iter < iterations; iter++)
                {
                    for each (msg in testData)
                    {
                        Pack.attach(encoder, 0);
                        try
                        {
                            BenchMessage.serializeMemory(msg, encoder);
                        }
                        finally
                        {
                            Pack.detach(encoder);
                        }
                    }
                }
                serializationTime = new Date().time - startTime;

                domain.domainMemory = input;
                startTime = new Date().time;
                for (iter = 0; iter < iterations; iter++)
                {
                    for (i = 0; i < testData.length; i++)
                    {
                        Unpack.attach(decoder, offsets[i], lengths[i]);
                        try
                        {
                            BenchMessage.deserializeMemory(decoder, decoded, lengths[i]);
                        }
                        finally
                        {
                            Unpack.detach(decoder);
                        }
                    }
                }
                deserializationTime = new Date().time - startTime;
            }
            finally
            {
                domain.domainMemory = previous;
            }

            return {
                    serializationTime: serializationTime,
                    deserializationTime: deserializationTime,
                    totalTime: serializationTime + deserializationTime,
                    serializedSize: totalSerializedSize,
                    averageSize: Math.round(totalSerializedSize / testData.length)
                };
        }

        private function benchmarkJSON(testData:Vector.<BenchMessage>, iterations:int):Object
        {
            const serialized:Vector.<ByteArray> = new Vector.<ByteArray>();
            var totalSerializedSize:int = 0;
            var jsonBytes:ByteArray;

            var startTime:Number = new Date().time;
            for (var iter:int = 0; iter < iterations; iter++)
            {
                for each (var msg:BenchMessage in testData)
                {
                    jsonBytes = Buffers.newByteArray();
                    jsonBytes.writeUTFBytes(JSON.stringify(msg));

                    if (iter == 0)
                    {
                        serialized.push(jsonBytes);
                        totalSerializedSize += jsonBytes.length;
                    }
                }
            }
            const serializationTime:Number = new Date().time - startTime;

            const decoded:BenchMessage = new BenchMessage();
            startTime = new Date().time;
            for (iter = 0; iter < iterations; iter++)
            {
                for each (jsonBytes in serialized)
                {
                    jsonBytes.position = 0;
                    const parsed:Object = JSON.parse(jsonBytes.readUTFBytes(jsonBytes.length));
                    decoded.id = parsed.id;
                    decoded.sequence = parsed.sequence;
                    decoded.delta = parsed.delta;
                    decoded.checksum = parsed.checksum;
                    decoded.x = parsed.x;
                    decoded.precision = parsed.precision;
                    decoded.active = parsed.active;
                }
            }
            const deserializationTime:Number = new Date().time - startTime;

            return {
                    serializationTime: serializationTime,
                    deserializationTime: deserializationTime,
                    totalTime: serializationTime + deserializationTime,
                    serializedSize: totalSerializedSize,
                    averageSize: Math.round(totalSerializedSize / testData.length)
                };
        }

        private function benchmarkAMF3(testData:Vector.<BenchMessage>, iterations:int):Object
        {
            const serialized:Vector.<ByteArray> = new Vector.<ByteArray>();
            var totalSerializedSize:int = 0;
            var amfBytes:ByteArray;

            var startTime:Number = new Date().time;
            for (var iter:int = 0; iter < iterations; iter++)
            {
                for each (var msg:BenchMessage in testData)
                {
                    amfBytes = Buffers.newByteArray();
                    amfBytes.objectEncoding = ObjectEncoding.AMF3;
                    amfBytes.writeObject(msg);

                    if (iter == 0)
                    {
                        serialized.push(amfBytes);
                        totalSerializedSize += amfBytes.length;
                    }
                }
            }
            const serializationTime:Number = new Date().time - startTime;

            var decoded:BenchMessage;
            startTime = new Date().time;
            for (iter = 0; iter < iterations; iter++)
            {
                for each (amfBytes in serialized)
                {
                    amfBytes.position = 0;
                    decoded = BenchMessage(amfBytes.readObject());
                }
            }
            const deserializationTime:Number = new Date().time - startTime;

            return {
                    serializationTime: serializationTime,
                    deserializationTime: deserializationTime,
                    totalTime: serializationTime + deserializationTime,
                    serializedSize: totalSerializedSize,
                    averageSize: Math.round(totalSerializedSize / testData.length)
                };
        }

        private function displayBenchmarkResults(protoResults:Object, memoryResults:Object, jsonResults:Object, amf3Results:Object):void
        {
            const names:Array = ["AS3PB bytes", "AS3PB memory", "AMF3", "JSON"];
            const results:Array = [protoResults, memoryResults, amf3Results, jsonResults];
            log("AS3PB decode reuses messages; AMF3/JSON allocate objects.");
            log("Memory: attach/detach per message; binding and input copy excluded.");
            log("AS3PB output buffers reused; AMF3/JSON allocate buffers.");
            log("JSON retains this harness's partial field mapping.");
            log("");
            log("--- Data Size ---");
            for (var i:uint = 0; i < names.length; i++)
                log(names[i] + ": " + results[i].serializedSize + " bytes, " + results[i].averageSize + " bytes/message");
            log("");
            log("--- Serialize ---");
            for (i = 0; i < names.length; i++)
                log(names[i] + ": " + results[i].serializationTime + "ms", true);
            log("");
            log("--- Deserialize ---");
            for (i = 0; i < names.length; i++)
                log(names[i] + ": " + results[i].deserializationTime + "ms", true);
            log("");
            log("--- Total ---");
            for (i = 0; i < names.length; i++)
                log(names[i] + ": " + results[i].totalTime + "ms", true);
            log("");
            log("--- Time / AS3PB memory (higher = slower) ---");
            for (i = 0; i < names.length; i++)
            {
                log(names[i] + ": encode " + ratio(results[i].serializationTime, memoryResults.serializationTime) +
                    "x, decode " + ratio(results[i].deserializationTime, memoryResults.deserializationTime) +
                    "x, total " + ratio(results[i].totalTime, memoryResults.totalTime) + "x", true);
            }
        }

        private function ratio(a:Number, b:Number):Number
        {
            if (b == 0)
                return 0;
            return Math.round((a / b) * 100) / 100;
        }

        private function log(message:String, measured:Boolean = false):void
        {
            _log(message, measured);
        }
    }
}
