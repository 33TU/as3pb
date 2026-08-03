package test
{
    import flash.display.Sprite;
    import flash.errors.IOError;
    import flash.utils.ByteArray;

    import as3pb.proto.Buffers;
    import as3pb.proto.Deserialize;
    import as3pb.proto.Serialize;
    import as3pb.wkt.AnyRegistry;
    import google.protobuf.Any;
    import as3pb.types.Int64;
    import as3pb.types.Int64Vector;
    import as3pb.types.OptionalBoolean;
    import as3pb.types.OptionalInt;
    import as3pb.types.OptionalUInt64;
    import as3pb.wkt.TimestampUtils;
    import as3pb.types.UInt64;
    import as3pb.types.UInt64Vector;
    import google.protobuf.Timestamp;

    public final class Main extends Sprite
    {
        public function Main()
        {
            trace("as3pb runtime tests");

            testVarint32();
            testVarint64();
            testSint32();
            testSint64();
            testFixedWidth();
            testStringsAndBytes();
            testPackedVectors();
            testPackedEncodingCompatibility();
            testSkipUnknownVarint64();
            testMalformedVarints();
            testInvalidFieldNumbers();
            testInvalidMessageLimits();
            testInt64FixedIO();
            testGeneratedMessageRoundTrip();
            testOptionalPresence();
            testTimestampUtils();
            testEmptyMessagePresence();
            testMessageMerging();
            testRecursiveMessageRoundTrip();
            testAnyRegistry();

            trace("ok");
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

            msg.optionalCount = new OptionalInt(0);
            msg.optionalEnabled = new OptionalBoolean(false);
            msg.optionalLabel = "";
            msg.optionalPayload = Buffers.newByteArray();
            msg.optionalTotal = new OptionalUInt64();
            msg.optionalNested = new RuntimeNested();

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
            assertUintEq("optional uint64 low", out.optionalTotal.value.low, 0);
            assertUintEq("optional uint64 high", out.optionalTotal.value.high, 0);
            assertTrue("optional message present", out.optionalNested != null);

            RuntimeSample.reset(out);
            assertEq("optional int reset", out.optionalCount, null);
            assertEq("optional message reset", out.optionalNested, null);
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

        private static function nested(label:String, flags:uint, ratio:Number):RuntimeNested
        {
            const msg:RuntimeNested = new RuntimeNested();
            msg.label_ = label;
            msg.flags = flags;
            msg.ratio = ratio;
            return msg;
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
