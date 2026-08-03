package test
{
    import flash.display.Sprite;
    import flash.utils.ByteArray;

    import as3pb.proto.Buffers;
    import as3pb.proto.Deserialize;
    import as3pb.proto.Serialize;
    import as3pb.rpc.HttpTransport;
    import as3pb.wkt.AnyRegistry;
    import google.protobuf.Any;
    import as3pb.types.Int64;
    import as3pb.types.Int64Vector;
    import as3pb.types.OptionalBoolean;
    import as3pb.types.OptionalInt;
    import as3pb.types.OptionalNumber;
    import as3pb.types.OptionalUint;
    import as3pb.wkt.DurationUtils;
    import as3pb.wkt.TimestampUtils;
    import as3pb.types.UInt64;
    import as3pb.types.UInt64Vector;
    import google.protobuf.Duration;
    import google.protobuf.Timestamp;

    public final class Main extends Sprite
    {
        public function Main()
        {
            trace("as3pb runtime tests");

            runTest("testVarint32", testVarint32);
            runTest("testVarint64", testVarint64);
            runTest("testSignedVarint64", testSignedVarint64);
            runTest("testSint32", testSint32);
            runTest("testSint64", testSint64);
            runTest("testFixedWidth", testFixedWidth);
            runTest("testStringsAndBytes", testStringsAndBytes);
            runTest("testPackedVectors", testPackedVectors);
            runTest("testPackedEncodingCompatibility", testPackedEncodingCompatibility);
            runTest("testSkipUnknownVarint64", testSkipUnknownVarint64);
            runTest("testGeneratedUnknownFields", testGeneratedUnknownFields);
            runTest("testMalformedVarints", testMalformedVarints);
            runTest("testInvalidFieldNumbers", testInvalidFieldNumbers);
            runTest("testInvalidMessageLimits", testInvalidMessageLimits);
            runTest("testTruncatedLengthDelimitedFields", testTruncatedLengthDelimitedFields);
            runTest("testInt64FixedIO", testInt64FixedIO);
            runTest("testGeneratedMessageRoundTrip", testGeneratedMessageRoundTrip);
            runTest("testGeneratedMessageClone", testGeneratedMessageClone);
            runTest("testGeneratedIntegerKinds", testGeneratedIntegerKinds);
            runTest("testOptionalPresence", testOptionalPresence);
            runTest("testOptionalScalarKinds", testOptionalScalarKinds);
            runTest("testSingularLastValueWins", testSingularLastValueWins);
            runTest("testTimestampUtils", testTimestampUtils);
            runTest("testDurationUtils", testDurationUtils);
            runTest("testHttpTransportConfiguration", testHttpTransportConfiguration);
            runTest("testEmptyMessagePresence", testEmptyMessagePresence);
            runTest("testMessageMerging", testMessageMerging);
            runTest("testOneofReferenceReplacement", testOneofReferenceReplacement);
            runTest("testRecursiveMessageRoundTrip", testRecursiveMessageRoundTrip);
            runTest("testAnyRegistry", testAnyRegistry);
            runTest("testAnyRegistryFailure", testAnyRegistryFailure);

            trace("ok");
        }

        private static function runTest(name:String, test:Function):void
        {
            trace(name);
            test();
        }

        private static function testVarint32():void
        {
            const values:Array = [0, 1, 127, 128, 255, 16383, 16384, 2097151, 2097152, uint.MAX_VALUE];
            const buffer:ByteArray = Buffers.newByteArray();

            for each (var value:uint in values)
            {
                reset(buffer);
                Serialize.writeVarint32(buffer, value);
                buffer.position = 0;
                assertUintEq("varint32 " + value, Deserialize.readVarint32(buffer), value);
                assertEq("varint32 consumed " + value, buffer.position, buffer.length);
            }
        }

        private static function testVarint64():void
        {
            const values:Array = [
                    new UInt64(0, 0),
                    new UInt64(1, 0),
                    new UInt64(0xffffffff, 0),
                    new UInt64(0, 1),
                    new UInt64(0xffffffff, 0xffffffff)
                ];
            const buffer:ByteArray = Buffers.newByteArray();
            const out:UInt64 = new UInt64();

            for each (var value:UInt64 in values)
            {
                reset(buffer);
                Serialize.writeVarint64(buffer, value.low, value.high);
                buffer.position = 0;
                Deserialize.readVarint64(buffer, out);
                assertTrue("varint64 " + value.toHex(), value.eq(out));
                assertEq("varint64 consumed " + value.toHex(), buffer.position, buffer.length);
            }
        }

        private static function testSignedVarint64():void
        {
            const values:Array = [
                    new Int64(0, 0),
                    new Int64(127, 0),
                    new Int64(128, 0),
                    new Int64(0xffffffff, -1),
                    new Int64(0, int.MIN_VALUE)
                ];
            const lengths:Array = [1, 1, 2, 10, 10];
            const buffer:ByteArray = Buffers.newByteArray();

            for (var i:uint = 0; i < values.length; i++)
            {
                const value:Int64 = values[i];
                reset(buffer);
                Serialize.writeVarint64s(buffer, value.low, value.high);
                assertEq("signed varint64 length " + value.toHex(), buffer.length, lengths[i]);

                buffer.position = 0;
                const out:Int64 = new Int64();
                Deserialize.readVarint64s(buffer, out);
                assertTrue("signed varint64 round trip " + value.toHex(), value.eq(out));
                assertEq("signed varint64 consumed " + value.toHex(), buffer.position, buffer.length);
            }

            reset(buffer);
            Serialize.writeVarint64s(buffer, 0xffffffff, -1);
            buffer.position = 0;
            for (i = 0; i < 9; i++)
                assertEq("negative one varint byte " + i, buffer.readUnsignedByte(), 0xff);
            assertEq("negative one varint final byte", buffer.readUnsignedByte(), 0x01);
        }

        private static function testSint32():void
        {
            const values:Array = [-2147483648, -1000, -1, 0, 1, 1000, 2147483647];
            const buffer:ByteArray = Buffers.newByteArray();

            for each (var value:int in values)
            {
                reset(buffer);
                Serialize.writeSint32(buffer, value);
                buffer.position = 0;
                assertEq("sint32 " + value, Deserialize.readSint32(buffer), value);
            }
        }

        private static function testSint64():void
        {
            const values:Array = [
                    new Int64(0, 0),
                    new Int64(1, 0),
                    new Int64(0xffffffff, -1),
                    new Int64(0, 1),
                    new Int64(0, -1),
                    new Int64(0xffffffff, int.MIN_VALUE)
                ];
            const buffer:ByteArray = Buffers.newByteArray();
            const out:Int64 = new Int64();

            for each (var value:Int64 in values)
            {
                reset(buffer);
                Serialize.writeSint64(buffer, value.low, value.high);
                buffer.position = 0;
                Deserialize.readSint64(buffer, out);
                assertTrue("sint64 " + value.toHex(), value.eq(out));
            }
        }

        private static function testFixedWidth():void
        {
            const buffer:ByteArray = Buffers.newByteArray();
            const u64:UInt64 = new UInt64();
            const i64:Int64 = new Int64();

            reset(buffer);
            Serialize.writeFixed32(buffer, 0x12345678);
            buffer.position = 0;
            assertUintEq("fixed32", Deserialize.readFixed32(buffer), 0x12345678);

            reset(buffer);
            Serialize.writeSfixed32(buffer, -12345678);
            buffer.position = 0;
            assertEq("sfixed32", Deserialize.readSfixed32(buffer), -12345678);

            reset(buffer);
            Serialize.writeFixed64(buffer, 0x89abcdef, 0x12345678);
            buffer.position = 0;
            Deserialize.readFixed64(buffer, u64);
            assertUintEq("fixed64 low", u64.low, 0x89abcdef);
            assertUintEq("fixed64 high", u64.high, 0x12345678);

            reset(buffer);
            Serialize.writeSfixed64(buffer, 0x89abcdef, -12345678);
            buffer.position = 0;
            Deserialize.readSfixed64(buffer, i64);
            assertUintEq("sfixed64 low", i64.low, 0x89abcdef);
            assertEq("sfixed64 high", i64.high, -12345678);
        }

        private static function testStringsAndBytes():void
        {
            const buffer:ByteArray = Buffers.newByteArray();
            const reuse:ByteArray = Buffers.newByteArray();

            reset(buffer);
            Serialize.writeString(buffer, "hello world", reuse);
            buffer.position = 0;
            assertEq("string", Deserialize.readString(buffer), "hello world");

            const bytes:ByteArray = Buffers.newByteArray();
            bytes.writeByte(1);
            bytes.writeByte(2);
            bytes.writeByte(255);

            reset(buffer);
            Serialize.writeBytes(buffer, bytes);
            buffer.position = 0;

            const out:ByteArray = Buffers.newByteArray();
            Deserialize.readBytesInto(buffer, out);
            assertEq("bytes length", out.length, 3);
            out.position = 0;
            assertEq("bytes[0]", out.readUnsignedByte(), 1);
            assertEq("bytes[1]", out.readUnsignedByte(), 2);
            assertEq("bytes[2]", out.readUnsignedByte(), 255);

            reset(buffer);
            buffer.writeByte(0);
            buffer.writeByte(42);
            buffer.position = 0;
            Deserialize.readBytesInto(buffer, out);
            assertEq("empty bytes length", out.length, 0);
            assertEq("empty bytes preserves following data", buffer.readUnsignedByte(), 42);
        }

        private static function testPackedVectors():void
        {
            const buffer:ByteArray = Buffers.newByteArray();
            const reuse:ByteArray = Buffers.newByteArray();

            const ints:Vector.<int> = new <int>[-1, 0, 1, 123456];
            const outInts:Vector.<int> = new Vector.<int>();
            reset(buffer);
            Serialize.writeSint32Vector(buffer, ints, reuse, ints.length);
            buffer.position = 0;
            Deserialize.readSint32Vector(buffer, outInts);
            assertEq("sint32 vector length", outInts.length, ints.length);
            for (var i:uint = 0; i < ints.length; i++)
                assertEq("sint32 vector " + i, outInts[i], ints[i]);

            const uint64s:UInt64Vector = new UInt64Vector();
            uint64s.push(1, 0);
            uint64s.push(0xffffffff, 0xffffffff);
            const outUInt64s:UInt64Vector = new UInt64Vector();
            reset(buffer);
            Serialize.writeVarint64Vector(buffer, uint64s, reuse, uint64s.length);
            buffer.position = 0;
            Deserialize.readVarint64Vector(buffer, outUInt64s);
            assertEq("uint64 vector length", outUInt64s.length, uint64s.length);
            assertUintEq("uint64 vector low", outUInt64s.low[1], 0xffffffff);
            assertUintEq("uint64 vector high", outUInt64s.high[1], 0xffffffff);

            const int64s:Int64Vector = new Int64Vector();
            int64s.push(0xffffffff, -1);
            int64s.push(0, int.MIN_VALUE);
            const outInt64s:Int64Vector = new Int64Vector();
            reset(buffer);
            Serialize.writeSint64Vector(buffer, int64s, reuse, int64s.length);
            buffer.position = 0;
            Deserialize.readSint64Vector(buffer, outInt64s);
            assertEq("int64 vector length", outInt64s.length, int64s.length);
            assertEq("int64 vector low", outInt64s.low[1], 0);
            assertEq("int64 vector high", outInt64s.high[1], int.MIN_VALUE);
        }

        private static function testPackedEncodingCompatibility():void
        {
            const buffer:ByteArray = Buffers.newByteArray();
            const values:Vector.<int> = new <int>[-1, 0, 123456];

            for each (var value:int in values)
            {
                buffer.writeByte(40);
                Serialize.writeSint32(buffer, value);
            }
            buffer.position = 0;
            var out:RuntimeSample = RuntimeSample.deserializeBytes(buffer);
            assertEq("unpacked input length", out.scores.length, values.length);
            for (var i:uint = 0; i < values.length; i++)
                assertEq("unpacked input " + i, out.scores[i], values[i]);

            reset(buffer);
            buffer.writeByte(98);
            Serialize.writeInt32Vector(buffer, values, Buffers.SHARED_BUFFER, values.length);
            buffer.position = 0;
            out = RuntimeSample.deserializeBytes(buffer);
            assertEq("packed input length", out.expandedScores.length, values.length);
            for (i = 0; i < values.length; i++)
                assertEq("packed input " + i, out.expandedScores[i], values[i]);

            const msg:RuntimeSample = new RuntimeSample();
            msg.scores.push(1);
            reset(buffer);
            RuntimeSample.serializeBytes(msg, buffer);
            buffer.position = 0;
            assertEq("packed serializer tag", Deserialize.readVarint32(buffer), 42);

            msg.scores.length = 0;
            msg.expandedScores.push(1);
            reset(buffer);
            RuntimeSample.serializeBytes(msg, buffer);
            buffer.position = 0;
            assertEq("unpacked serializer tag", Deserialize.readVarint32(buffer), 96);
        }

        private static function testSkipUnknownVarint64():void
        {
            const buffer:ByteArray = Buffers.newByteArray();
            Serialize.writeVarint64(buffer, 0xffffffff, 0xffffffff);
            buffer.writeByte(7);
            buffer.position = 0;

            Deserialize.skipField(buffer, 0);
            assertEq("skip varint64 position", buffer.position, buffer.length - 1);
            assertEq("skip varint64 tail", buffer.readUnsignedByte(), 7);
        }

        private static function testGeneratedUnknownFields():void
        {
            const buffer:ByteArray = Buffers.newByteArray();
            buffer.writeByte(10);
            Serialize.writeString(buffer, "before", Buffers.SHARED_BUFFER);

            Serialize.writeVarint32(buffer, (100 << 3) | 0);
            Serialize.writeVarint64(buffer, 0xffffffff, 0xffffffff);
            Serialize.writeVarint32(buffer, (101 << 3) | 1);
            buffer.writeUnsignedInt(0x01234567);
            buffer.writeUnsignedInt(0x89abcdef);
            Serialize.writeVarint32(buffer, (102 << 3) | 2);
            Serialize.writeVarint32(buffer, 3);
            buffer.writeByte(1);
            buffer.writeByte(2);
            buffer.writeByte(3);
            Serialize.writeVarint32(buffer, (103 << 3) | 5);
            buffer.writeUnsignedInt(0x12345678);

            buffer.writeByte(10);
            Serialize.writeString(buffer, "after", Buffers.SHARED_BUFFER);
            buffer.position = 0;
            const out:RuntimeSample = RuntimeSample.deserializeBytes(buffer);
            assertEq("known field after unknown wire types", out.id, "after");
            assertEq("unknown fields consumed", buffer.position, buffer.length);

            reset(buffer);
            Serialize.writeVarint32(buffer, (100 << 3) | 2);
            Serialize.writeVarint32(buffer, uint.MAX_VALUE);
            buffer.position = 0;
            assertThrows("unknown length-delimited field overflow", function():void
                {
                    RuntimeSample.deserializeBytes(buffer);
                });

            reset(buffer);
            Serialize.writeVarint32(buffer, (100 << 3) | 3);
            buffer.position = 0;
            assertThrows("start group wire type rejected", function():void
                {
                    RuntimeSample.deserializeBytes(buffer);
                });

            reset(buffer);
            Serialize.writeVarint32(buffer, (100 << 3) | 4);
            buffer.position = 0;
            assertThrows("end group wire type rejected", function():void
                {
                    RuntimeSample.deserializeBytes(buffer);
                });
        }

        private static function testMalformedVarints():void
        {
            const buffer:ByteArray = Buffers.newByteArray();

            reset(buffer);
            for (var i:uint = 0; i < 10; i++)
                buffer.writeByte(0x80);
            buffer.position = 0;
            assertThrows("skip malformed varint", function():void
                {
                    Deserialize.skipVarint(buffer);
                });

            reset(buffer);
            for (i = 0; i < 9; i++)
                buffer.writeByte(0x80);
            buffer.writeByte(0x02);
            buffer.position = 0;
            assertThrows("read malformed varint64", function():void
                {
                    Deserialize.readVarint64(buffer, new UInt64());
                });

            reset(buffer);
            for (i = 0; i < 5; i++)
                buffer.writeByte(0x80);
            buffer.position = 0;
            assertThrows("read varint32 longer than five bytes", function():void
                {
                    Deserialize.readVarint32(buffer);
                });

            reset(buffer);
            buffer.writeByte(0xff);
            buffer.writeByte(0xff);
            buffer.writeByte(0xff);
            buffer.writeByte(0xff);
            buffer.writeByte(0x10);
            buffer.position = 0;
            assertThrows("read varint32 overflow bits", function():void
                {
                    Deserialize.readVarint32(buffer);
                });
        }

        private static function testInvalidMessageLimits():void
        {
            const buffer:ByteArray = Buffers.newByteArray();

            assertThrows("generated invalid message limit", function():void
                {
                    RuntimeNested.deserializeBytes(buffer, null, 1);
                });
            assertThrows("Any invalid message limit", function():void
                {
                    Any.deserializeBytes(buffer, null, 1);
                });
        }

        private static function testTruncatedLengthDelimitedFields():void
        {
            const buffer:ByteArray = Buffers.newByteArray();

            buffer.writeByte(10);
            buffer.writeByte(3);
            buffer.writeUTFBytes("abc");
            buffer.position = 0;
            assertThrows("string length beyond message boundary", function():void
                {
                    RuntimeSample.deserializeBytes(buffer, null, 4);
                });

            reset(buffer);
            buffer.writeByte(18);
            buffer.writeByte(3);
            buffer.writeByte(1);
            buffer.writeByte(2);
            buffer.writeByte(3);
            buffer.position = 0;
            assertThrows("bytes length beyond message boundary", function():void
                {
                    RuntimeSample.deserializeBytes(buffer, null, 4);
                });

            reset(buffer);
            buffer.writeByte(42);
            buffer.writeByte(2);
            buffer.writeByte(0);
            buffer.writeByte(0);
            buffer.position = 0;
            assertThrows("packed length beyond message boundary", function():void
                {
                    RuntimeSample.deserializeBytes(buffer, null, 3);
                });

            reset(buffer);
            buffer.writeByte(50);
            buffer.writeByte(2);
            buffer.writeByte(10);
            buffer.writeByte(0);
            buffer.position = 0;
            assertThrows("nested message length beyond parent boundary", function():void
                {
                    RuntimeSample.deserializeBytes(buffer, null, 3);
                });
        }

        private static function testInvalidFieldNumbers():void
        {
            const buffer:ByteArray = Buffers.newByteArray();
            buffer.writeByte(0);

            buffer.position = 0;
            assertThrows("generated invalid field number", function():void
                {
                    RuntimeNested.deserializeBytes(buffer);
                });

            buffer.position = 0;
            assertThrows("Any invalid field number", function():void
                {
                    Any.deserializeBytes(buffer);
                });
        }

        private static function testInt64FixedIO():void
        {
            const buffer:ByteArray = Buffers.newByteArray();

            const i64:Int64 = new Int64(0x89abcdef, -12345678);
            reset(buffer);
            i64.write(buffer);
            buffer.position = 0;
            const readI64:Int64 = new Int64();
            readI64.read(buffer);
            assertTrue("int64 fixed io", i64.eq(readI64));

            const u64:UInt64 = new UInt64(0x89abcdef, 0x12345678);
            reset(buffer);
            u64.write(buffer);
            buffer.position = 0;
            const readU64:UInt64 = new UInt64();
            readU64.read(buffer);
            assertTrue("uint64 fixed io", u64.eq(readU64));
        }

        private static function testGeneratedMessageRoundTrip():void
        {
            const msg:RuntimeSample = new RuntimeSample();
            msg.id = "runtime";
            msg.payload.writeByte(1);
            msg.payload.writeByte(2);
            msg.payload.writeByte(255);
            msg.count.low = 0xffffffff;
            msg.count.high = 1;
            msg.delta.low = 12345;
            msg.delta.high = -1;
            msg.scores.push(-1, 0, 123456);
            msg.nested = nested("root", 0x12345678, 1.5);
            msg.children.push(nested("child", 0x89abcdef, -2.25));
            msg.checksum.low = 0x89abcdef;
            msg.checksum.high = 0x12345678;
            msg.signedCount = -123456;
            msg.choiceCase = RuntimeSample.FIELD_NAME;
            msg.name = "picked";

            const buffer:ByteArray = Buffers.newByteArray();
            RuntimeSample.serializeBytes(msg, buffer);
            buffer.position = 0;

            const out:RuntimeSample = RuntimeSample.deserializeBytes(buffer);
            assertEq("generated id", out.id, msg.id);
            assertBytesEq("generated payload", out.payload, msg.payload);
            assertUintEq("generated uint64 low", out.count.low, msg.count.low);
            assertUintEq("generated uint64 high", out.count.high, msg.count.high);
            assertUintEq("generated sint64 low", out.delta.low, msg.delta.low);
            assertEq("generated sint64 high", out.delta.high, msg.delta.high);
            assertEq("generated scores length", out.scores.length, msg.scores.length);
            assertEq("generated scores[0]", out.scores[0], msg.scores[0]);
            assertEq("generated scores[2]", out.scores[2], msg.scores[2]);
            assertEq("generated nested label", out.nested.label_, msg.nested.label_);
            assertUintEq("generated nested flags", out.nested.flags, msg.nested.flags);
            assertEq("generated nested ratio", out.nested.ratio, msg.nested.ratio);
            assertEq("generated child length", out.children.length, msg.children.length);
            assertEq("generated child label", out.children[0].label_, msg.children[0].label_);
            assertUintEq("generated fixed64 low", out.checksum.low, msg.checksum.low);
            assertUintEq("generated fixed64 high", out.checksum.high, msg.checksum.high);
            assertEq("generated int32", out.signedCount, msg.signedCount);
            assertEq("generated oneof case", out.choiceCase, msg.choiceCase);
            assertEq("generated oneof name", out.name, msg.name);

            msg.id = "reuse";
            msg.payload.length = 0;
            reset(buffer);
            RuntimeSample.serializeBytes(msg, buffer);
            buffer.position = 0;
            RuntimeSample.deserializeBytes(buffer, out);
            assertEq("generated reuse reset id", out.id, "reuse");
            assertEq("generated reuse reset payload", out.payload.length, 0);
        }

        private static function testGeneratedMessageClone():void
        {
            const msg:RuntimeSample = new RuntimeSample();
            msg.id = "source";
            msg.payload.writeByte(7);
            msg.payload.position = 0;
            msg.count.set(0x89abcdef, 0x01234567);
            msg.scores.push(-1, 2);
            msg.nested = nested("nested", 3, 1.5);
            msg.children.push(nested("child", 4, 2.5));
            msg.optionalCount = new OptionalInt(5);
            msg.optionalPayload = bytes(6);
            msg.optionalTotal = new UInt64(7, 8);
            msg.optionalNested = nested("optional", 9, 3.5);
            msg.choiceCase = RuntimeSample.FIELD_SELECTED;
            msg.selected = nested("selected", 10, 4.5);

            const copy:RuntimeSample = RuntimeSample.clone(msg);
            assertTrue("clone message identity", copy !== msg);
            assertEq("clone scalar", copy.id, msg.id);
            assertTrue("clone bytes identity", copy.payload !== msg.payload);
            assertBytesEq("clone bytes", copy.payload, msg.payload);
            assertTrue("clone int64 identity", copy.count !== msg.count);
            assertTrue("clone int64 value", copy.count.eq(msg.count));
            assertTrue("clone vector identity", copy.scores !== msg.scores);
            assertEq("clone vector value", copy.scores[1], 2);
            assertTrue("clone message field identity", copy.nested !== msg.nested);
            assertEq("clone message field value", copy.nested.label_, "nested");
            assertTrue("clone repeated message identity", copy.children[0] !== msg.children[0]);
            assertEq("clone repeated message value", copy.children[0].label_, "child");
            assertTrue("clone optional wrapper identity", copy.optionalCount !== msg.optionalCount);
            assertEq("clone optional wrapper value", copy.optionalCount.value, 5);
            assertTrue("clone optional bytes identity", copy.optionalPayload !== msg.optionalPayload);
            assertTrue("clone optional uint64 identity", copy.optionalTotal !== msg.optionalTotal);
            assertTrue("clone optional message identity", copy.optionalNested !== msg.optionalNested);
            assertEq("clone oneof case", copy.choiceCase, RuntimeSample.FIELD_SELECTED);
            assertTrue("clone oneof message identity", copy.selected !== msg.selected);

            copy.payload[0] = 8;
            copy.scores[1] = 12;
            copy.nested.label_ = "changed";
            copy.children[0].label_ = "changed";
            copy.optionalCount.value = 15;
            copy.optionalPayload[0] = 16;
            copy.optionalTotal.low = 17;
            copy.optionalNested.label_ = "changed";
            copy.selected.label_ = "changed";
            assertEq("clone source bytes independent", msg.payload[0], 7);
            assertEq("clone source vector independent", msg.scores[1], 2);
            assertEq("clone source message independent", msg.nested.label_, "nested");
            assertEq("clone source repeated message independent", msg.children[0].label_, "child");
            assertEq("clone source optional wrapper independent", msg.optionalCount.value, 5);
            assertEq("clone source optional bytes independent", msg.optionalPayload[0], 6);
            assertUintEq("clone source optional uint64 independent", msg.optionalTotal.low, 7);
            assertEq("clone source optional message independent", msg.optionalNested.label_, "optional");
            assertEq("clone source oneof independent", msg.selected.label_, "selected");

            const payloadChoice:RuntimeSample = new RuntimeSample();
            payloadChoice.choiceCase = RuntimeSample.FIELD_CHOICE_PAYLOAD;
            payloadChoice.choicePayload.writeByte(20);
            const payloadCopy:RuntimeSample = RuntimeSample.clone(payloadChoice);
            assertTrue("clone oneof bytes identity", payloadCopy.choicePayload !== payloadChoice.choicePayload);
            assertEq("clone oneof bytes value", payloadCopy.choicePayload[0], 20);

            const nullDelta:RuntimeSample = new RuntimeSample();
            nullDelta.choiceCase = RuntimeSample.FIELD_CHOICE_DELTA;
            nullDelta.choiceDelta = null;
            const nullDeltaCopy:RuntimeSample = RuntimeSample.clone(nullDelta);
            assertEq("clone null oneof int64 case", nullDeltaCopy.choiceCase, RuntimeSample.FIELD_CHOICE_DELTA);
            assertTrue("clone null oneof int64 default", nullDeltaCopy.choiceDelta != null);
            assertEq("clone null oneof int64 value", nullDeltaCopy.choiceDelta.toNumber(), 0);
            RuntimeSample.reset(nullDeltaCopy);

            const nullPayload:RuntimeSample = new RuntimeSample();
            nullPayload.choiceCase = RuntimeSample.FIELD_CHOICE_PAYLOAD;
            nullPayload.choicePayload = null;
            const nullPayloadCopy:RuntimeSample = RuntimeSample.clone(nullPayload);
            assertEq("clone null oneof bytes case", nullPayloadCopy.choiceCase, RuntimeSample.FIELD_CHOICE_PAYLOAD);
            assertTrue("clone null oneof bytes default", nullPayloadCopy.choicePayload != null);
            assertEq("clone null oneof bytes value", nullPayloadCopy.choicePayload.length, 0);
            RuntimeSample.reset(nullPayloadCopy);
            assertEq("clone null", RuntimeSample.clone(null), null);
        }

        private static function testGeneratedIntegerKinds():void
        {
            const msg:RuntimeIntegers = new RuntimeIntegers();
            msg.int32Value = -1;
            msg.uint32Value = uint.MAX_VALUE;
            msg.sint32Value = int.MIN_VALUE;
            msg.fixed32Value = 0x89abcdef;
            msg.sfixed32Value = -123456789;
            msg.int64Value = new Int64(0xffffffff, -1);
            msg.uint64Value = new UInt64(0xffffffff, 0xffffffff);
            msg.sint64Value = new Int64(0, int.MIN_VALUE);
            msg.fixed64Value = new UInt64(0x01234567, 0x89abcdef);
            msg.sfixed64Value = new Int64(0x89abcdef, -123456789);

            msg.int32Values.push(-1, int.MAX_VALUE);
            msg.uint32Values.push(0, uint.MAX_VALUE);
            msg.sint32Values.push(int.MIN_VALUE, int.MAX_VALUE);
            msg.fixed32Values.push(0x01234567, 0x89abcdef);
            msg.sfixed32Values.push(int.MIN_VALUE, -1);
            msg.int64Values.push(0xffffffff, -1);
            msg.int64Values.push(0, int.MIN_VALUE);
            msg.uint64Values.push(0xffffffff, 0xffffffff);
            msg.uint64Values.push(0, 1);
            msg.sint64Values.push(0xffffffff, -1);
            msg.sint64Values.push(0, int.MIN_VALUE);
            msg.fixed64Values.push(0x01234567, 0x89abcdef);
            msg.fixed64Values.push(0xffffffff, 0xffffffff);
            msg.sfixed64Values.push(0xffffffff, -1);
            msg.sfixed64Values.push(0, int.MIN_VALUE);

            const buffer:ByteArray = Buffers.newByteArray();
            RuntimeIntegers.serializeBytes(msg, buffer);
            buffer.position = 0;
            const out:RuntimeIntegers = RuntimeIntegers.deserializeBytes(buffer);

            assertEq("integer int32", out.int32Value, msg.int32Value);
            assertUintEq("integer uint32", out.uint32Value, msg.uint32Value);
            assertEq("integer sint32", out.sint32Value, msg.sint32Value);
            assertUintEq("integer fixed32", out.fixed32Value, msg.fixed32Value);
            assertEq("integer sfixed32", out.sfixed32Value, msg.sfixed32Value);
            assertTrue("integer int64", out.int64Value.eq(msg.int64Value));
            assertTrue("integer uint64", out.uint64Value.eq(msg.uint64Value));
            assertTrue("integer sint64", out.sint64Value.eq(msg.sint64Value));
            assertTrue("integer fixed64", out.fixed64Value.eq(msg.fixed64Value));
            assertTrue("integer sfixed64", out.sfixed64Value.eq(msg.sfixed64Value));

            assertEq("integer int32 vector length", out.int32Values.length, 2);
            assertEq("integer uint32 vector length", out.uint32Values.length, 2);
            assertEq("integer sint32 vector length", out.sint32Values.length, 2);
            assertEq("integer fixed32 vector length", out.fixed32Values.length, 2);
            assertEq("integer sfixed32 vector length", out.sfixed32Values.length, 2);
            assertEq("integer int64 vector length", out.int64Values.length, 2);
            assertEq("integer uint64 vector length", out.uint64Values.length, 2);
            assertEq("integer sint64 vector length", out.sint64Values.length, 2);
            assertEq("integer fixed64 vector length", out.fixed64Values.length, 2);
            assertEq("integer sfixed64 vector length", out.sfixed64Values.length, 2);
            assertEq("integer int32 vector", out.int32Values[0], -1);
            assertUintEq("integer uint32 vector", out.uint32Values[1], uint.MAX_VALUE);
            assertEq("integer sint32 vector", out.sint32Values[0], int.MIN_VALUE);
            assertUintEq("integer fixed32 vector", out.fixed32Values[1], 0x89abcdef);
            assertEq("integer sfixed32 vector", out.sfixed32Values[0], int.MIN_VALUE);
            assertEq("integer int64 vector high", out.int64Values.high[1], int.MIN_VALUE);
            assertUintEq("integer uint64 vector high", out.uint64Values.high[0], 0xffffffff);
            assertEq("integer sint64 vector high", out.sint64Values.high[1], int.MIN_VALUE);
            assertUintEq("integer fixed64 vector low", out.fixed64Values.low[0], 0x01234567);
            assertEq("integer sfixed64 vector high", out.sfixed64Values.high[1], int.MIN_VALUE);

            const copy:RuntimeIntegers = RuntimeIntegers.clone(out);
            assertTrue("integer int64 vector clone identity", copy.int64Values !== out.int64Values);
            assertTrue("integer int64 low vector clone identity", copy.int64Values.low !== out.int64Values.low);
            assertTrue("integer uint64 high vector clone identity", copy.uint64Values.high !== out.uint64Values.high);
            copy.int64Values.high[1] = 0;
            assertEq("integer vector clone independent", out.int64Values.high[1], int.MIN_VALUE);

            const reusedInt64:Int64Vector = new Int64Vector();
            const reusedInt64Low:Vector.<uint> = reusedInt64.low;
            const reusedInt64High:Vector.<int> = reusedInt64.high;
            assertTrue("int64 vector copy result", reusedInt64.copyFrom(out.int64Values) === reusedInt64);
            assertTrue("int64 vector copy reuses low", reusedInt64.low === reusedInt64Low);
            assertTrue("int64 vector copy reuses high", reusedInt64.high === reusedInt64High);
            assertEq("int64 vector copy length", reusedInt64.length, out.int64Values.length);
            assertEq("int64 vector copy value", reusedInt64.high[1], int.MIN_VALUE);

            const reusedUInt64:UInt64Vector = new UInt64Vector();
            const reusedUInt64Low:Vector.<uint> = reusedUInt64.low;
            const reusedUInt64High:Vector.<uint> = reusedUInt64.high;
            assertTrue("uint64 vector copy result", reusedUInt64.copyFrom(out.uint64Values) === reusedUInt64);
            assertTrue("uint64 vector copy reuses low", reusedUInt64.low === reusedUInt64Low);
            assertTrue("uint64 vector copy reuses high", reusedUInt64.high === reusedUInt64High);
            assertEq("uint64 vector copy length", reusedUInt64.length, out.uint64Values.length);
            assertUintEq("uint64 vector copy value", reusedUInt64.high[0], 0xffffffff);
        }

        private static function testRecursiveMessageRoundTrip():void
        {
            const root:RuntimeNode = new RuntimeNode();
            root.value = "root";
            root.next = new RuntimeNode();
            root.next.value = "middle";
            root.next.next = new RuntimeNode();
            root.next.next.value = "leaf";

            const buffer:ByteArray = Buffers.newByteArray();
            RuntimeNode.serializeBytes(root, buffer);
            buffer.position = 0;

            const out:RuntimeNode = RuntimeNode.deserializeBytes(buffer);
            assertEq("recursive root", out.value, root.value);
            assertEq("recursive middle", out.next.value, root.next.value);
            assertEq("recursive leaf", out.next.next.value, root.next.next.value);
        }

        private static function testOptionalPresence():void
        {
            const msg:RuntimeSample = new RuntimeSample();
            assertEq("optional int absent", msg.optionalCount, null);
            assertEq("optional bool absent", msg.optionalEnabled, null);
            assertEq("optional string absent", msg.optionalLabel, null);
            assertEq("optional bytes absent", msg.optionalPayload, null);
            assertEq("optional uint64 absent", msg.optionalTotal, null);
            assertEq("optional message absent", msg.optionalNested, null);
            assertEq("optional int64 absent", msg.optionalDelta, null);

            msg.optionalCount = new OptionalInt(0);
            msg.optionalEnabled = new OptionalBoolean(false);
            msg.optionalLabel = "";
            msg.optionalPayload = Buffers.newByteArray();
            msg.optionalTotal = new UInt64();
            msg.optionalNested = new RuntimeNested();
            msg.optionalDelta = new Int64();

            const buffer:ByteArray = Buffers.newByteArray();
            RuntimeSample.serializeBytes(msg, buffer);
            assertTrue("present optional defaults serialized", buffer.length > 0);
            buffer.position = 0;

            const out:RuntimeSample = RuntimeSample.deserializeBytes(buffer);
            assertTrue("optional int present", out.optionalCount != null);
            assertEq("optional int default", out.optionalCount.value, 0);
            assertTrue("optional bool present", out.optionalEnabled != null);
            assertEq("optional bool default", out.optionalEnabled.value, false);
            assertTrue("optional string present", out.optionalLabel != null);
            assertEq("optional string default", out.optionalLabel, "");
            assertTrue("optional bytes present", out.optionalPayload != null);
            assertEq("optional bytes default", out.optionalPayload.length, 0);
            assertTrue("optional uint64 present", out.optionalTotal != null);
            assertUintEq("optional uint64 low", out.optionalTotal.low, 0);
            assertUintEq("optional uint64 high", out.optionalTotal.high, 0);
            assertTrue("optional message present", out.optionalNested != null);
            assertTrue("optional int64 present", out.optionalDelta != null);
            assertUintEq("optional int64 low", out.optionalDelta.low, 0);
            assertEq("optional int64 high", out.optionalDelta.high, 0);

            RuntimeSample.reset(out);
            assertEq("optional int reset", out.optionalCount, null);
            assertEq("optional message reset", out.optionalNested, null);

            const partial:RuntimeSample = new RuntimeSample();
            partial.optionalCount = new OptionalInt(7);
            reset(buffer);
            RuntimeSample.serializeBytes(partial, buffer);
            buffer.position = 0;
            const partialOut:RuntimeSample = RuntimeSample.deserializeBytes(buffer);
            assertEq("present optional survives round trip", partialOut.optionalCount.value, 7);
            assertEq("absent optional bool survives round trip", partialOut.optionalEnabled, null);
            assertEq("absent optional string survives round trip", partialOut.optionalLabel, null);
            assertEq("absent optional bytes survives round trip", partialOut.optionalPayload, null);
            assertEq("absent optional uint64 survives round trip", partialOut.optionalTotal, null);
            assertEq("absent optional message survives round trip", partialOut.optionalNested, null);
            assertEq("absent optional int64 survives round trip", partialOut.optionalDelta, null);
        }

        private static function testOptionalScalarKinds():void
        {
            const msg:RuntimeSample = new RuntimeSample();
            msg.optionalStatus = new OptionalInt(RuntimeStatus.RUNTIME_STATUS_READY);
            msg.optionalFloat = new OptionalNumber(1.25);
            msg.optionalDouble = new OptionalNumber(-2.5);
            msg.optionalFixed32 = new OptionalUint(0x89abcdef);
            msg.optionalFixed64 = new UInt64(0x01234567, 0x89abcdef);
            msg.optionalInt64 = new Int64(0xffffffff, -1);

            const buffer:ByteArray = Buffers.newByteArray();
            RuntimeSample.serializeBytes(msg, buffer);
            buffer.position = 0;
            var out:RuntimeSample = RuntimeSample.deserializeBytes(buffer);
            assertEq("optional enum", out.optionalStatus.value, RuntimeStatus.RUNTIME_STATUS_READY);
            assertEq("optional float", out.optionalFloat.value, 1.25);
            assertEq("optional double", out.optionalDouble.value, -2.5);
            assertUintEq("optional fixed32", out.optionalFixed32.value, 0x89abcdef);
            assertUintEq("optional fixed64 low", out.optionalFixed64.low, 0x01234567);
            assertUintEq("optional fixed64 high", out.optionalFixed64.high, 0x89abcdef);
            assertEq("optional int64", out.optionalInt64.toNumber(), -1);

            reset(buffer);
            buffer.writeByte(0xb0);
            buffer.writeByte(0x01);
            Serialize.writeVarint32(buffer, 123);
            buffer.position = 0;
            out = RuntimeSample.deserializeBytes(buffer);
            assertEq("unknown enum numeric value", out.optionalStatus.value, 123);
        }

        private static function testSingularLastValueWins():void
        {
            const buffer:ByteArray = Buffers.newByteArray();
            buffer.writeByte(10);
            Serialize.writeString(buffer, "first", Buffers.SHARED_BUFFER);
            buffer.writeByte(10);
            Serialize.writeString(buffer, "last", Buffers.SHARED_BUFFER);
            buffer.position = 0;
            var out:RuntimeSample = RuntimeSample.deserializeBytes(buffer);
            assertEq("duplicate singular scalar", out.id, "last");

            reset(buffer);
            buffer.writeByte(104);
            Serialize.writeVarint32(buffer, 1);
            buffer.writeByte(104);
            Serialize.writeVarint32(buffer, 2);
            buffer.position = 0;
            out = RuntimeSample.deserializeBytes(buffer);
            assertEq("repeated optional field", out.optionalCount.value, 2);
        }

        private static function testTimestampUtils():void
        {
            const negativeOne:Int64 = Int64.fromNumber(-1);
            assertUintEq("int64 negative number low", negativeOne.low, uint.MAX_VALUE);
            assertEq("int64 negative number high", negativeOne.high, -1);
            assertEq("int64 negative number round trip", negativeOne.toNumber(), -1);

            var timestamp:Timestamp = TimestampUtils.fromDate(new Date(1234));
            assertEq("timestamp positive seconds", timestamp.seconds.toNumber(), 1);
            assertEq("timestamp positive nanos", timestamp.nanos, 234000000);
            assertEq("timestamp positive round trip", TimestampUtils.toDate(timestamp).time, 1234);

            timestamp = TimestampUtils.fromDate(new Date(-1), timestamp);
            assertEq("timestamp negative seconds", timestamp.seconds.toNumber(), -1);
            assertEq("timestamp negative nanos", timestamp.nanos, 999000000);
            assertEq("timestamp negative round trip", TimestampUtils.toDate(timestamp).time, -1);

            timestamp.seconds.reset();
            timestamp.nanos = -1;
            TimestampUtils.normalize(timestamp);
            assertEq("timestamp normalized seconds", timestamp.seconds.toNumber(), -1);
            assertEq("timestamp normalized nanos", timestamp.nanos, 999999999);
            assertTrue("timestamp normalized valid", TimestampUtils.isValid(timestamp));

            timestamp.nanos = 1000000000;
            assertEq("timestamp invalid nanos", TimestampUtils.isValid(timestamp), false);
            assertEq("timestamp null invalid", TimestampUtils.isValid(null), false);

            const current:Timestamp = TimestampUtils.now();
            assertTrue("timestamp now valid", TimestampUtils.isValid(current));
        }

        private static function testDurationUtils():void
        {
            var duration:Duration = DurationUtils.fromMilliseconds(1234.5);
            assertEq("duration positive seconds", duration.seconds.toNumber(), 1);
            assertEq("duration positive nanos", duration.nanos, 234500000);
            assertEq("duration positive round trip", DurationUtils.toMilliseconds(duration), 1234.5);

            duration = DurationUtils.fromMilliseconds(-1234.5, duration);
            assertEq("duration negative seconds", duration.seconds.toNumber(), -1);
            assertEq("duration negative nanos", duration.nanos, -234500000);
            assertEq("duration negative round trip", DurationUtils.toMilliseconds(duration), -1234.5);

            duration.seconds.copyFrom(Int64.fromNumber(1));
            duration.nanos = -1;
            DurationUtils.normalize(duration);
            assertEq("duration positive normalize seconds", duration.seconds.toNumber(), 0);
            assertEq("duration positive normalize nanos", duration.nanos, 999999999);
            assertTrue("duration positive normalize valid", DurationUtils.isValid(duration));

            duration.seconds.copyFrom(Int64.fromNumber(-1));
            duration.nanos = 1;
            DurationUtils.normalize(duration);
            assertEq("duration negative normalize seconds", duration.seconds.toNumber(), 0);
            assertEq("duration negative normalize nanos", duration.nanos, -999999999);
            assertTrue("duration negative normalize valid", DurationUtils.isValid(duration));

            duration.seconds.reset();
            duration.nanos = 1000000000;
            assertEq("duration invalid nanos", DurationUtils.isValid(duration), false);
            duration.seconds.copyFrom(Int64.fromNumber(1));
            duration.nanos = -1;
            assertEq("duration inconsistent signs", DurationUtils.isValid(duration), false);
            assertEq("duration null invalid", DurationUtils.isValid(null), false);
        }

        private static function testHttpTransportConfiguration():void
        {
            const transport:HttpTransport = new HttpTransport(5000);
            assertEq("HTTP transport timeout", transport.timeoutMilliseconds, 5000);
            transport.timeoutMilliseconds = 1000;
            assertEq("HTTP transport mutable timeout", transport.timeoutMilliseconds, 1000);
            assertEq("HTTP transport default timeout", new HttpTransport().timeoutMilliseconds, 0);
        }

        private static function testEmptyMessagePresence():void
        {
            const buffer:ByteArray = Buffers.newByteArray();

            buffer.writeByte(50);
            buffer.writeByte(0);
            buffer.position = 0;
            var out:RuntimeSample = RuntimeSample.deserializeBytes(buffer);
            assertTrue("empty singular message presence", out.nested != null);

            reset(buffer);
            buffer.writeByte(82);
            buffer.writeByte(0);
            buffer.position = 0;
            out = RuntimeSample.deserializeBytes(buffer);
            assertEq("empty oneof case", out.choiceCase, RuntimeSample.FIELD_SELECTED);
            assertTrue("empty oneof message presence", out.selected != null);

            reset(buffer);
            buffer.writeByte(10);
            buffer.writeByte(0);
            buffer.position = 0;
            const envelope:RuntimeAnyEnvelope = RuntimeAnyEnvelope.deserializeBytes(buffer);
            assertTrue("empty Any presence", envelope.payload != null);

            reset(buffer);
            RuntimeSample.serializeBytes(null, buffer);
            assertEq("null message bytes", buffer.length, 0);

            reset(buffer);
            Any.serializeBytes(null, buffer);
            assertEq("null Any bytes", buffer.length, 0);

            const selected:RuntimeSample = new RuntimeSample();
            selected.choiceCase = RuntimeSample.FIELD_SELECTED;
            reset(buffer);
            RuntimeSample.serializeBytes(selected, buffer);
            buffer.position = 0;
            const selectedOut:RuntimeSample = RuntimeSample.deserializeBytes(buffer);
            assertEq("null oneof message case", selectedOut.choiceCase, RuntimeSample.FIELD_SELECTED);
            assertTrue("null oneof empty message", selectedOut.selected != null);

            const named:RuntimeSample = new RuntimeSample();
            named.choiceCase = RuntimeSample.FIELD_NAME;
            named.name = null;
            reset(buffer);
            RuntimeSample.serializeBytes(named, buffer);
            buffer.position = 0;
            const namedOut:RuntimeSample = RuntimeSample.deserializeBytes(buffer);
            assertEq("null oneof string case", namedOut.choiceCase, RuntimeSample.FIELD_NAME);
            assertEq("null oneof empty string", namedOut.name, "");

            const delta:RuntimeSample = new RuntimeSample();
            delta.choiceCase = RuntimeSample.FIELD_CHOICE_DELTA;
            delta.choiceDelta = null;
            reset(buffer);
            RuntimeSample.serializeBytes(delta, buffer);
            buffer.position = 0;
            const deltaOut:RuntimeSample = RuntimeSample.deserializeBytes(buffer);
            assertEq("null oneof int64 case", deltaOut.choiceCase, RuntimeSample.FIELD_CHOICE_DELTA);
            assertTrue("null oneof int64 value", deltaOut.choiceDelta != null);
            assertEq("null oneof int64 zero", deltaOut.choiceDelta.toNumber(), 0);

            const payload:RuntimeSample = new RuntimeSample();
            payload.choiceCase = RuntimeSample.FIELD_CHOICE_PAYLOAD;
            payload.choicePayload = null;
            reset(buffer);
            RuntimeSample.serializeBytes(payload, buffer);
            buffer.position = 0;
            const payloadOut:RuntimeSample = RuntimeSample.deserializeBytes(buffer);
            assertEq("null oneof bytes case", payloadOut.choiceCase, RuntimeSample.FIELD_CHOICE_PAYLOAD);
            assertTrue("null oneof bytes value", payloadOut.choicePayload != null);
            assertEq("null oneof empty bytes", payloadOut.choicePayload.length, 0);
        }

        private static function testMessageMerging():void
        {
            const buffer:ByteArray = Buffers.newByteArray();

            writeNestedField(buffer, 50, nested("merged", 0, 0.0));
            writeNestedField(buffer, 50, nested("", 0x12345678, 0.0));
            buffer.position = 0;
            var out:RuntimeSample = RuntimeSample.deserializeBytes(buffer);
            assertEq("merged singular label", out.nested.label_, "merged");
            assertUintEq("merged singular flags", out.nested.flags, 0x12345678);

            reset(buffer);
            writeNestedField(buffer, 82, nested("same case", 0, 0.0));
            writeNestedField(buffer, 82, nested("", 7, 0.0));
            buffer.position = 0;
            out = RuntimeSample.deserializeBytes(buffer);
            assertEq("merged oneof label", out.selected.label_, "same case");
            assertUintEq("merged oneof flags", out.selected.flags, 7);

            reset(buffer);
            writeNestedField(buffer, 82, nested("discarded", 0, 0.0));
            buffer.writeByte(74);
            Serialize.writeString(buffer, "other case", Buffers.SHARED_BUFFER);
            writeNestedField(buffer, 82, nested("", 0, 2.5));
            buffer.position = 0;
            out = RuntimeSample.deserializeBytes(buffer);
            assertEq("replaced oneof case", out.choiceCase, RuntimeSample.FIELD_SELECTED);
            assertEq("replaced oneof label", out.selected.label_, "");
            assertEq("replaced oneof ratio", out.selected.ratio, 2.5);

            const reusable:RuntimeSample = new RuntimeSample();
            reusable.scores.push(7);
            const update:RuntimeSample = new RuntimeSample();
            update.id = "merged";
            reset(buffer);
            RuntimeSample.serializeBytes(update, buffer);
            buffer.position = 0;
            RuntimeSample.deserializeBytes(buffer, reusable, 0, false);
            assertEq("top-level merge id", reusable.id, update.id);
            assertEq("top-level merge retained scores", reusable.scores.length, 1);
        }

        private static function testOneofReferenceReplacement():void
        {
            const buffer:ByteArray = Buffers.newByteArray();

            buffer.writeByte(0xaa);
            buffer.writeByte(0x01);
            Serialize.writeBytes(buffer, bytes(1));
            buffer.writeByte(74);
            Serialize.writeString(buffer, "name", Buffers.SHARED_BUFFER);
            buffer.position = 0;
            var out:RuntimeSample = RuntimeSample.deserializeBytes(buffer);
            assertEq("oneof bytes to string", out.choiceCase, RuntimeSample.FIELD_NAME);

            reset(buffer);
            buffer.writeByte(74);
            Serialize.writeString(buffer, "name", Buffers.SHARED_BUFFER);
            writeNestedField(buffer, 82, nested("selected", 0, 0.0));
            buffer.position = 0;
            out = RuntimeSample.deserializeBytes(buffer);
            assertEq("oneof string to message", out.choiceCase, RuntimeSample.FIELD_SELECTED);

            reset(buffer);
            writeNestedField(buffer, 82, nested("selected", 0, 0.0));
            buffer.writeByte(0xa0);
            buffer.writeByte(0x01);
            Serialize.writeVarint64(buffer, 7, 0);
            buffer.position = 0;
            out = RuntimeSample.deserializeBytes(buffer);
            assertEq("oneof message to int64", out.choiceCase, RuntimeSample.FIELD_CHOICE_DELTA);

            reset(buffer);
            buffer.writeByte(0xa0);
            buffer.writeByte(0x01);
            Serialize.writeVarint64(buffer, 7, 0);
            buffer.writeByte(0xaa);
            buffer.writeByte(0x01);
            Serialize.writeBytes(buffer, bytes(9));
            buffer.position = 0;
            out = RuntimeSample.deserializeBytes(buffer);
            assertEq("oneof int64 to bytes", out.choiceCase, RuntimeSample.FIELD_CHOICE_PAYLOAD);
            assertEq("oneof replacement bytes", out.choicePayload[0], 9);
        }

        private static function writeNestedField(dst:ByteArray, tag:uint, msg:RuntimeNested):void
        {
            const payload:ByteArray = Buffers.newByteArray();
            RuntimeNested.serializeBytes(msg, payload);
            dst.writeByte(tag);
            Serialize.writeVarint32(dst, payload.length);
            dst.writeBytes(payload);
        }

        private static function testAnyRegistry():void
        {
            const msg:RuntimeNested = nested("packed", 0x12345678, 1.5);
            const packed:Any = AnyRegistry.pack(RuntimeNested.TYPE_URL, msg);
            assertEq("any type URL", packed.typeUrl, RuntimeNested.TYPE_URL);

            const out:RuntimeNested = AnyRegistry.unpack(packed) as RuntimeNested;
            assertEq("any nested label", out.label_, msg.label_);
            assertUintEq("any nested flags", out.flags, msg.flags);
            assertEq("any nested ratio", out.ratio, msg.ratio);

            const envelope:RuntimeAnyEnvelope = new RuntimeAnyEnvelope();
            envelope.payload = packed;
            const buffer:ByteArray = Buffers.newByteArray();
            RuntimeAnyEnvelope.serializeBytes(envelope, buffer);
            buffer.position = 0;
            const decoded:RuntimeAnyEnvelope = RuntimeAnyEnvelope.deserializeBytes(buffer);
            const decodedMessage:RuntimeNested = AnyRegistry.unpack(decoded.payload) as RuntimeNested;
            assertEq("any wire round trip", decodedMessage.label_, msg.label_);
        }

        private static function testAnyRegistryFailure():void
        {
            const value:Any = new Any();
            value.typeUrl = "type.googleapis.com/test.Unregistered";
            assertEq("unregistered Any type", AnyRegistry.isRegistered(value.typeUrl), false);
            assertThrows("unregistered Any unpack", function():void
                {
                    AnyRegistry.unpack(value);
                });
            assertThrows("unregistered Any pack", function():void
                {
                    AnyRegistry.pack(value.typeUrl, {});
                });
        }

        private static function nested(label:String, flags:uint, ratio:Number):RuntimeNested
        {
            const msg:RuntimeNested = new RuntimeNested();
            msg.label_ = label;
            msg.flags = flags;
            msg.ratio = ratio;
            return msg;
        }

        private static function bytes(value:uint):ByteArray
        {
            const result:ByteArray = Buffers.newByteArray();
            result.writeByte(value);
            return result;
        }

        private static function reset(buffer:ByteArray):void
        {
            buffer.length = 0;
            buffer.position = 0;
        }

        private static function assertEq(name:String, got:*, want:*):void
        {
            if (got !== want)
                throw new Error(name + ": got " + got + ", want " + want);
        }

        private static function assertUintEq(name:String, got:uint, want:uint):void
        {
            if (got != want)
                throw new Error(name + ": got " + got + ", want " + want);
        }

        private static function assertTrue(name:String, ok:Boolean):void
        {
            if (!ok)
                throw new Error(name);
        }

        private static function assertBytesEq(name:String, got:ByteArray, want:ByteArray):void
        {
            assertEq(name + " length", got.length, want.length);

            const gotPosition:uint = got.position;
            const wantPosition:uint = want.position;
            got.position = 0;
            want.position = 0;

            for (var i:uint = 0; i < want.length; i++)
                assertEq(name + "[" + i + "]", got.readUnsignedByte(), want.readUnsignedByte());

            got.position = gotPosition;
            want.position = wantPosition;
        }

        private static function assertThrows(name:String, fn:Function):void
        {
            try
            {
                fn();
            }
            catch (error:Error)
            {
                return;
            }

            throw new Error(name + ": expected error");
        }
    }
}
