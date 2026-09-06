package
{
    import flash.utils.ByteArray;

    import as3pb.proto.Buffers;
    import as3pb.wkt.AnyRegistry;
    import as3pb.types.Int64;
    import as3pb.types.UInt64;

    import bench.BenchMessage;

    /**
     * Minimal Apache Royale/Node decode benchmark for the generated AS3 codec.
     */
    public final class Main
    {
        private static const MESSAGE_COUNT:int = 100;
        private static const ROUNDS:int = 2000;
        private static const TRIALS:int = 7;

        public function Main()
        {
            ByteArrayTest.run();

            const frames:Vector.<ByteArray> = buildFrames(MESSAGE_COUNT);
            const decoded:BenchMessage = new BenchMessage();
            // Royale 0.9.12 omits the generated class-initializer block.
            AnyRegistry.register(BenchMessage.TYPE_URL,
                BenchMessage.deserializeBytes, BenchMessage.serializeBytes);
            if (!AnyRegistry.isRegistered(BenchMessage.TYPE_URL))
                throw new Error("BenchMessage registration is missing");
            var argumentErrorCaught:Boolean = false;
            try { AnyRegistry.pack("unregistered-benchmark-type", decoded); }
            catch (error:ArgumentError)
            {
                argumentErrorCaught = error.name == "ArgumentError" &&
                    error.message == "Unregistered protobuf type URL: unregistered-benchmark-type";
            }
            if (!argumentErrorCaught)
                throw new Error("AnyRegistry ArgumentError check failed");
            console.log("AnyRegistry checks passed");
            var totalBytes:uint = 0;
            var frame:ByteArray;
            var i:int;
            var round:int;
            var sink:Number = 0;

            for each (frame in frames)
                totalBytes += frame.length;

            // Warm the generated decoder and the JavaScript optimizer.
            for (round = 0; round < 300; round++)
            {
                for each (frame in frames)
                {
                    frame.position = 0;
                    BenchMessage.deserializeBytes(frame, decoded);
                    sink += decoded.sequence + decoded.samples[9] + decoded.positions[9];
                }
            }

            console.log("Node " + process.version + "; Apache Royale 0.9.12");
            console.log("payload: " + totalBytes + " bytes across " + frames.length + " messages");

            const times:Vector.<Number> = new Vector.<Number>();
            for (i = 0; i < TRIALS; i++)
            {
                const start:Number = new Date().time;
                for (round = 0; round < ROUNDS; round++)
                {
                    for each (frame in frames)
                    {
                        frame.position = 0;
                        BenchMessage.deserializeBytes(frame, decoded);
                        sink += decoded.sequence + decoded.samples[9] + decoded.positions[9];
                    }
                }
                const elapsed:Number = new Date().time - start;
                times.push(elapsed);

                console.log("trial " + (i + 1) + ": " + elapsed + "ms (" +
                    nanosPerMessage(elapsed) + " ns/msg, " +
                    megabytesPerSecond(totalBytes, elapsed) + " MB/s)");
            }

            times.sort(Array.NUMERIC);
            const median:Number = times[TRIALS >>> 1];
            console.log("median: " + median + "ms (" + nanosPerMessage(median) +
                " ns/msg, " + megabytesPerSecond(totalBytes, median) + " MB/s)");
            console.log("sink: " + sink);
        }

        private static function nanosPerMessage(milliseconds:Number):Number
        {
            return Math.round(milliseconds * 1000000 /
                (Number(MESSAGE_COUNT) * Number(ROUNDS)) * 10) / 10;
        }

        private static function megabytesPerSecond(bytesPerRound:Number,
            milliseconds:Number):Number
        {
            return Math.round(bytesPerRound * Number(ROUNDS) /
                (milliseconds / 1000) / 1000000 * 10) / 10;
        }

        private static function buildFrames(count:int):Vector.<ByteArray>
        {
            const frames:Vector.<ByteArray> = new Vector.<ByteArray>();
            const scratch:ByteArray = Buffers.newByteArray();

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

                scratch.length = 0;
                scratch.position = 0;
                BenchMessage.serializeBytes(msg, scratch);
                frames.push(Buffers.cloneByteArray(scratch));
            }

            return frames;
        }
    }
}
