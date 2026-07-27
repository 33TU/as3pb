package bench
{
    import flash.display.Sprite;
    import flash.events.MouseEvent;
    import flash.net.ObjectEncoding;
    import flash.net.registerClassAlias;
    import flash.text.TextField;
    import flash.text.TextFormat;
    import flash.utils.ByteArray;

    import bench.BenchMessage;
    import as3pb.proto.Buffers;
    import as3pb.types.Int64;
    import as3pb.types.UInt64;

    public final class Main extends Sprite
    {
        private static const TEST_DATA_SIZE:int = 100;
        private static const ITERATIONS:int = 300;

        private var _logDisplay:TextField;
        private var _logText:String = "";

        public function Main()
        {
            registerClassAlias("bench.BenchMessage", BenchMessage);
            registerClassAlias("as3pb.types.Int64", Int64);
            registerClassAlias("as3pb.types.UInt64", UInt64);

            setupDisplay();
            runBenchmark();
        }

        private function setupDisplay():void
        {
            _logDisplay = new TextField();
            _logDisplay.x = 10;
            _logDisplay.y = 10;
            _logDisplay.width = stage ? stage.stageWidth - 20 : 480;
            _logDisplay.height = stage ? stage.stageHeight - 20 : 355;
            _logDisplay.multiline = true;
            _logDisplay.wordWrap = true;
            _logDisplay.border = true;
            _logDisplay.borderColor = 0x333333;
            _logDisplay.background = true;
            _logDisplay.backgroundColor = 0x000000;
            _logDisplay.selectable = true;

            const format:TextFormat = new TextFormat();
            format.font = "_typewriter";
            format.size = 11;
            format.color = 0x00ff00;
            _logDisplay.defaultTextFormat = format;
            addChild(_logDisplay);

            const runButton:Sprite = createButton("Run Benchmark", stage ? stage.stageWidth - 135 : 345, 14, 125, 26);
            runButton.addEventListener(MouseEvent.CLICK, function(event:MouseEvent):void
                {
                    runBenchmark();
                });
            addChild(runButton);
        }

        private function createButton(label:String, x:Number, y:Number, width:Number, height:Number):Sprite
        {
            const button:Sprite = new Sprite();
            button.x = x;
            button.y = y;
            button.buttonMode = true;
            button.useHandCursor = true;

            function drawBackground(color:uint):void
            {
                button.graphics.clear();
                button.graphics.beginFill(color);
                button.graphics.drawRoundRect(0, 0, width, height, 4, 4);
                button.graphics.endFill();
            }

            drawBackground(0x1e3a1e);

            const text:TextField = new TextField();
            text.mouseEnabled = false;
            text.selectable = false;
            text.width = width;
            text.height = height;
            text.defaultTextFormat = new TextFormat("_sans", 11, 0xffffff, true, null, null, null, null, "center");
            text.text = label;
            text.y = 5;
            button.addChild(text);

            button.addEventListener(MouseEvent.MOUSE_OVER, function(event:MouseEvent):void
                {
                    drawBackground(0x2d5a2d);
                });
            button.addEventListener(MouseEvent.MOUSE_OUT, function(event:MouseEvent):void
                {
                    drawBackground(0x1e3a1e);
                });

            return button;
        }

        private function runBenchmark():void
        {
            _logText = "";
            log("=== AS3PB Runtime Benchmark ===");
            log("Messages: " + TEST_DATA_SIZE);
            log("Iterations: " + ITERATIONS);
            log("");

            const testData:Vector.<BenchMessage> = createTestData(TEST_DATA_SIZE);
            const protoResults:Object = benchmarkProtocolBuffers(testData, ITERATIONS);
            const jsonResults:Object = benchmarkJSON(testData, ITERATIONS);
            const amf3Results:Object = benchmarkAMF3(testData, ITERATIONS);

            displayBenchmarkResults(protoResults, jsonResults, amf3Results);
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
                    BenchMessage.deserializeBytes(bytes, decoded);
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

        private function displayBenchmarkResults(protoResults:Object, jsonResults:Object, amf3Results:Object):void
        {
            const sizeRatio:Number = ratio(jsonResults.serializedSize, protoResults.serializedSize);
            const serializeRatio:Number = ratio(jsonResults.serializationTime, protoResults.serializationTime);
            const deserializeRatio:Number = ratio(jsonResults.deserializationTime, protoResults.deserializationTime);
            const totalRatio:Number = ratio(jsonResults.totalTime, protoResults.totalTime);
            const amf3SizeRatio:Number = ratio(amf3Results.serializedSize, protoResults.serializedSize);
            const amf3SerializeRatio:Number = ratio(amf3Results.serializationTime, protoResults.serializationTime);
            const amf3DeserializeRatio:Number = ratio(amf3Results.deserializationTime, protoResults.deserializationTime);
            const amf3TotalRatio:Number = ratio(amf3Results.totalTime, protoResults.totalTime);

            log("--- Data Size ---");
            log("Protocol Buffers total: " + protoResults.serializedSize + " bytes");
            log("JSON total: " + jsonResults.serializedSize + " bytes");
            log("AMF3 total: " + amf3Results.serializedSize + " bytes");
            log("Protocol Buffers avg: " + protoResults.averageSize + " bytes/message");
            log("JSON avg: " + jsonResults.averageSize + " bytes/message");
            log("AMF3 avg: " + amf3Results.averageSize + " bytes/message");
            log("JSON/Proto size ratio: " + sizeRatio + "x");
            log("AMF3/Proto size ratio: " + amf3SizeRatio + "x");
            log("");
            log("--- Timing ---");
            log("Protocol Buffers serialize: " + protoResults.serializationTime + "ms");
            log("JSON serialize: " + jsonResults.serializationTime + "ms");
            log("AMF3 serialize: " + amf3Results.serializationTime + "ms");
            log("JSON/Proto serialize ratio: " + serializeRatio + "x");
            log("AMF3/Proto serialize ratio: " + amf3SerializeRatio + "x");
            log("Protocol Buffers deserialize: " + protoResults.deserializationTime + "ms");
            log("JSON deserialize: " + jsonResults.deserializationTime + "ms");
            log("AMF3 deserialize: " + amf3Results.deserializationTime + "ms");
            log("JSON/Proto deserialize ratio: " + deserializeRatio + "x");
            log("AMF3/Proto deserialize ratio: " + amf3DeserializeRatio + "x");
            log("Protocol Buffers total: " + protoResults.totalTime + "ms");
            log("JSON total: " + jsonResults.totalTime + "ms");
            log("AMF3 total: " + amf3Results.totalTime + "ms");
            log("JSON/Proto total ratio: " + totalRatio + "x");
            log("AMF3/Proto total ratio: " + amf3TotalRatio + "x");
            log("");
            log("Done.");
        }

        private function ratio(a:Number, b:Number):Number
        {
            if (b == 0)
                return 0;
            return Math.round((a / b) * 100) / 100;
        }

        private function log(message:String):void
        {
            trace(message);
            _logText += message + "\n";
            if (_logDisplay)
            {
                _logDisplay.text = _logText;
                _logDisplay.scrollV = _logDisplay.maxScrollV;
            }
        }
    }
}
