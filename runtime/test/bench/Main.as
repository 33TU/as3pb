package bench
{
    import flash.display.Sprite;
    import flash.events.MouseEvent;
    import flash.text.TextField;
    import flash.text.TextFormat;
    import flash.utils.ByteArray;

    import as3pb.bench.BenchAddress;
    import as3pb.bench.BenchAddressMetadata;
    import as3pb.proto.Buffers;
    import as3pb.types.Int64;

    public final class Main extends Sprite
    {
        private static const TEST_DATA_SIZE:int = 100;
        private static const ITERATIONS:int = 300;

        private var _logDisplay:TextField;
        private var _logText:String = "";

        public function Main()
        {
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

            const testData:Vector.<BenchAddress> = createTestData(TEST_DATA_SIZE);
            const protoResults:Object = benchmarkProtocolBuffers(testData, ITERATIONS);
            const jsonResults:Object = benchmarkJSON(testData, ITERATIONS);

            displayBenchmarkResults(protoResults, jsonResults);
        }

        private function createTestData(count:int):Vector.<BenchAddress>
        {
            const addresses:Vector.<BenchAddress> = new Vector.<BenchAddress>();
            const streets:Array = ["Main Street", "Oak Avenue", "Pine Road", "Elm Circle", "Maple Lane"];
            const cities:Array = ["Springfield", "Franklin", "Georgetown", "Madison", "Arlington"];
            const states:Array = ["IL", "TX", "CA", "NY", "FL"];
            const zips:Array = ["12345", "67890", "54321", "98765", "13579"];

            for (var i:int = 0; i < count; i++)
            {
                const address:BenchAddress = new BenchAddress();
                address.street = (i + 1) + " " + streets[i % streets.length];
                address.city = cities[i % cities.length];
                address.state = states[i % states.length];
                address.zip = zips[i % zips.length];

                const metadata:BenchAddressMetadata = new BenchAddressMetadata();
                for (var j:int = 0; j < 10; j++)
                    metadata.luckyNumbers.push(j * 100000000 + i);

                for (var k:int = 0; k < 10; k++)
                {
                    const num:Int64 = Int64.fromNumber(k * 1000000000000 + i + 1);
                    metadata.bigLuckyNumbers.push(num.low, num.high);
                }

                metadata.aField = i;
                metadata.bField = Int64.fromNumber(1337 + i);
                metadata.cField = i * 3.14;
                metadata.dField = i * 2.71828;
                metadata.eField = (i % 2) == 0;
                metadata.fField.writeUTFBytes("Binary data for address " + i);
                metadata.fField.position = 0;

                address.metadata.push(metadata);
                addresses.push(address);
            }

            return addresses;
        }

        private function benchmarkProtocolBuffers(testData:Vector.<BenchAddress>, iterations:int):Object
        {
            const buffer:ByteArray = Buffers.newByteArray();
            const serialized:Vector.<ByteArray> = new Vector.<ByteArray>();
            var totalSerializedSize:int = 0;

            var startTime:Number = new Date().time;
            for (var iter:int = 0; iter < iterations; iter++)
            {
                for each (var address:BenchAddress in testData)
                {
                    buffer.length = 0;
                    buffer.position = 0;
                    BenchAddress.serializeBytes(address, buffer);

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

            const decoded:BenchAddress = new BenchAddress();
            startTime = new Date().time;
            for (iter = 0; iter < iterations; iter++)
            {
                for each (var bytes:ByteArray in serialized)
                {
                    bytes.position = 0;
                    BenchAddress.deserializeBytes(bytes, decoded);
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

        private function benchmarkJSON(testData:Vector.<BenchAddress>, iterations:int):Object
        {
            const serialized:Vector.<ByteArray> = new Vector.<ByteArray>();
            var totalSerializedSize:int = 0;
            var jsonBytes:ByteArray;

            var startTime:Number = new Date().time;
            for (var iter:int = 0; iter < iterations; iter++)
            {
                for each (var address:BenchAddress in testData)
                {
                    jsonBytes = Buffers.newByteArray();
                    jsonBytes.writeUTFBytes(JSON.stringify(address));

                    if (iter == 0)
                    {
                        serialized.push(jsonBytes);
                        totalSerializedSize += jsonBytes.length;
                    }
                }
            }
            const serializationTime:Number = new Date().time - startTime;

            const decoded:BenchAddress = new BenchAddress();
            startTime = new Date().time;
            for (iter = 0; iter < iterations; iter++)
            {
                for each (jsonBytes in serialized)
                {
                    jsonBytes.position = 0;
                    const parsed:Object = JSON.parse(jsonBytes.readUTFBytes(jsonBytes.length));
                    decoded.street = parsed.street;
                    decoded.city = parsed.city;
                    decoded.state = parsed.state;
                    decoded.zip = parsed.zip;
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

        private function displayBenchmarkResults(protoResults:Object, jsonResults:Object):void
        {
            const sizeRatio:Number = ratio(jsonResults.serializedSize, protoResults.serializedSize);
            const serializeRatio:Number = ratio(jsonResults.serializationTime, protoResults.serializationTime);
            const deserializeRatio:Number = ratio(jsonResults.deserializationTime, protoResults.deserializationTime);
            const totalRatio:Number = ratio(jsonResults.totalTime, protoResults.totalTime);

            log("--- Data Size ---");
            log("Protocol Buffers total: " + protoResults.serializedSize + " bytes");
            log("JSON total: " + jsonResults.serializedSize + " bytes");
            log("Protocol Buffers avg: " + protoResults.averageSize + " bytes/message");
            log("JSON avg: " + jsonResults.averageSize + " bytes/message");
            log("JSON/Proto size ratio: " + sizeRatio + "x");
            log("");
            log("--- Timing ---");
            log("Protocol Buffers serialize: " + protoResults.serializationTime + "ms");
            log("JSON serialize: " + jsonResults.serializationTime + "ms");
            log("JSON/Proto serialize ratio: " + serializeRatio + "x");
            log("Protocol Buffers deserialize: " + protoResults.deserializationTime + "ms");
            log("JSON deserialize: " + jsonResults.deserializationTime + "ms");
            log("JSON/Proto deserialize ratio: " + deserializeRatio + "x");
            log("Protocol Buffers total: " + protoResults.totalTime + "ms");
            log("JSON total: " + jsonResults.totalTime + "ms");
            log("JSON/Proto total ratio: " + totalRatio + "x");
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
