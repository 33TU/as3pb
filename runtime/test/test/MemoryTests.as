package test
{
    import as3pb.proto.Buffers;
    import as3pb.proto.Serialize;
    import as3pb.types.UInt64;
    import as3pb.types.Int64;
    import as3pb.proto.Unpack;
    import as3pb.proto.UnpackContext;
    import flash.system.ApplicationDomain;
    import flash.utils.ByteArray;
    import flash.utils.Endian;

    public final class MemoryTests
    {
        public static function run():void
        {
            testValidVarintsAtCapacity();
            testVarintBoundaries();
            testWideVarints();
            testPackedUint32Limits();
            const domain:ApplicationDomain = ApplicationDomain.currentDomain;
            const previous:ByteArray = domain.domainMemory;
            const sentinel:ByteArray = new ByteArray();
            sentinel.length = ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH;
            sentinel[0] = 91;
            domain.domainMemory = sentinel;
            try
            {
                const msg:RuntimeNested = new RuntimeNested();
                msg.label_ = "hello π";
                msg.flags = 0xfedcba98;
                msg.ratio = -1.25;
                const input:ByteArray = Buffers.newByteArray();
                input.writeByte(77);
                RuntimeNested.serializeBytes(msg, input);
                const end:uint = input.position;
                input.writeByte(88);
                input.position = 1;
                input.endian = Endian.BIG_ENDIAN;
                const out:RuntimeNested = RuntimeNested.deserializeBytes(input, null, end);
                check(out.label_ == msg.label_ && out.flags == msg.flags && out.ratio == msg.ratio,
                        "Range decode uses little-endian intrinsics and native strings");
                check(input.position == end && input.length == end + 1 && input.endian == Endian.BIG_ENDIAN,
                        "Decode preserves input length and endian, advances absolute cursor");
                check(input[0] == 77 && input[end] == 88 && domain.domainMemory === sentinel && sentinel[0] == 91,
                        "Decode preserves adjacent bytes and restores domain memory");

                // Reuse previously populated scratch with an empty range and truncated fixed/varint fields.
                input.position = input.length;
                RuntimeNested.deserializeBytes(input, out);
                check(out.label_ == "" && out.flags == 0, "Empty input does not decode stale scratch bytes");
                const cases:Array = [[0x15, 1, 2, 3], [0x1a, 8, 1], [0x10, 0x80], [0x0a, 0xff, 0xff, 0xff, 0xff, 0x0f]];
                for each (var data:Array in cases)
                {
                    const bad:ByteArray = Buffers.newByteArray();
                    for each (var value:uint in data)
                        bad.writeByte(value);
                    bad.position = 0;
                    rejects(function():void { RuntimeNested.deserializeBytes(bad); });
                    check(bad.length == data.length && domain.domainMemory === sentinel,
                            "Malformed input restores binding without growing source");
                }
                // Child declares a single byte containing a fixed32 tag. Following parent bytes cannot satisfy it.
                const child:ByteArray = Buffers.newByteArray();
                for each (value in [0x32, 1, 0x15, 0, 0, 0, 0])
                    child.writeByte(value);
                child.position = 0;
                rejects(function():void { RuntimeSample.deserializeBytes(child); });
                check(domain.domainMemory === sentinel, "Child-limit failure restores caller binding");

                const context:UnpackContext = new UnpackContext();
                input.position = 1;
                Unpack.begin(context, input, end);
                const memory:ByteArray = domain.domainMemory;
                try
                {
                    RuntimeNested.deserializeMemory(context, out, context.limit, true);
                    check(out.flags == msg.flags && context.position == context.limit, "Explicit memory API consumes range");
                    const other:ByteArray = Buffers.newByteArray();
                    RuntimeSample.deserializeBytes(other);
                    check(domain.domainMemory === memory, "Independent nested wrapper restores outer binding");
                }
                finally
                {
                    Unpack.end(context);
                }
                check(domain.domainMemory === sentinel, "Explicit memory API restores caller");
            }
            finally
            {
                domain.domainMemory = previous;
            }
        }

        private static function testValidVarintsAtCapacity():void
        {
            const context:UnpackContext = new UnpackContext();
            const input:ByteArray = Buffers.newByteArray();
            const unsigned:UInt64 = new UInt64();
            const signed:Int64 = new Int64();
            const previous:ByteArray = ApplicationDomain.currentDomain.domainMemory;
            for (var remaining:uint = 1; remaining <= 10; remaining++)
            {
                input.position = 0;
                Unpack.begin(context, input, 0);
                const capacity:uint = ApplicationDomain.currentDomain.domainMemory.length;
                Unpack.end(context);

                // Force growth even when earlier tests have already populated shared scratch.
                input.length = capacity + 1;
                input.position = input.length - remaining;
                const start:uint = input.position;
                input.writeByte(3);
                input.position = 0;
                Unpack.begin(context, input, 0);
                try
                {
                    context.position = start;
                    const tag:uint = Unpack.readTag(context);
                    check(tag == 3 && context.position == start + 1, "Tag near scratch capacity");
                    context.position = start;
                    const value:uint = Unpack.readVarint32(context);
                    check(value == 3 && context.position == start + 1, "Uint32 near scratch capacity");
                    context.position = start;
                    const integer:int = Unpack.readInt32(context);
                    check(integer == 3 && context.position == start + 1, "Int32 near scratch capacity");
                    context.position = start;
                    Unpack.readVarint64(context, unsigned);
                    check(unsigned.low == 3 && unsigned.high == 0 && context.position == start + 1,
                            "Uint64 near scratch capacity");
                    context.position = start;
                    Unpack.readVarint64s(context, signed);
                    check(signed.low == 3 && signed.high == 0 && context.position == start + 1,
                            "Int64 near scratch capacity");
                    context.position = start;
                    const boolean:Boolean = Unpack.readBool(context);
                    check(boolean && context.position == start + 1, "Bool near scratch capacity");
                    context.position = start;
                    Unpack.skipVarint(context);
                    check(context.position == start + 1 && context.limit == input.length,
                            "Skip near scratch capacity preserves logical limit");
                }
                finally { Unpack.end(context); }
                check(input.length == capacity + 1 && input.position == start + 1 &&
                        ApplicationDomain.currentDomain.domainMemory === previous,
                        "Capacity growth preserves source and restores domain memory");
            }
        }

        private static function testVarintBoundaries():void
        {
            const context:UnpackContext = new UnpackContext();
            const input:ByteArray = Buffers.newByteArray();
            const values:Array = [0, 1, 127, 128, 16383, 16384, 2097151, 2097152,
                    268435455, 268435456, uint.MAX_VALUE, 0x80808080, 0x01020304];
            for each (var value:uint in values)
            {
                for each (var padding:uint in [0, 4])
                {
                    input.length = 0;
                    Serialize.writeVarint32(input, value);
                    const encoded:uint = input.length;
                    input.writeUnsignedInt(0xffffffff);
                    input.position = 0;
                    Unpack.begin(context, input, encoded + padding);
                    try
                    {
                        const actualUint:uint = Unpack.readVarint32(context);
                        check(actualUint == value && context.position == encoded,
                                "Varint32 preserves value and consumes only encoded bytes");
                        context.position = 0;
                        const actualInt:int = Unpack.readInt32(context);
                        check(actualInt == int(value) && context.position == encoded,
                                "Int32 preserves signed low bits");
                        context.position = 0;
                        const actualTag:uint = Unpack.readTag(context);
                        check(actualTag == value && context.position == encoded,
                                "Tag " + value + " / " + padding + " got " + actualTag + " at " + context.position + " expected " + encoded);
                    }
                    finally { Unpack.end(context); }
                    for (var prefix:uint = 1; prefix < encoded; prefix++)
                    {
                        input.position = 0;
                        Unpack.begin(context, input, prefix);
                        try
                        {
                            rejects(function():void { Unpack.readVarint32(context); });
                            check(context.position <= prefix, "Truncated varint stays within its logical limit");
                        }
                        finally { Unpack.end(context); }
                    }
                }
            }
            // Exercise reads at scratch growth boundaries and ending exactly at the limit.
            for each (var size:uint in [ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH - 1,
                    ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH, ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH + 1,
                    ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH * 2])
            {
                input.length = size;
                input[size - 1] = 127;
                input.position = 0;
                Unpack.begin(context, input, 0);
                try
                {
                    context.position = size - 1;
                    const finalValue:uint = Unpack.readVarint32(context);
                    check(finalValue == 127 && context.position == size, "Varint may end exactly at its limit");
                    rejects(function():void { Unpack.readVarint32(context); });
                }
                finally { Unpack.end(context); }
                input[size - 1] = 0x80;
                input.position = 0;
                Unpack.begin(context, input, 0);
                try
                {
                    context.position = size - 1;
                    rejects(function():void { Unpack.readVarint32(context); });
                    // AIR may reject the load before the decoder publishes its local cursor.
                    check(context.position == size - 1 || context.position == size,
                            "Truncated boundary varint keeps the published cursor within the input");
                }
                finally { Unpack.end(context); }
            }
            for each (var signed:int in [-1, int.MIN_VALUE, -268435456])
            {
                input.length = 0;
                Serialize.writeInt32(input, signed);
                input.position = 0;
                Unpack.begin(context, input, 0);
                try
                {
                    check(Unpack.readInt32(context) == signed && context.position == 10,
                            "Ten-byte negative int32 decodes correctly");
                }
                finally { Unpack.end(context); }
            }
        }

        private static function testWideVarints():void
        {
            const context:UnpackContext = new UnpackContext();
            const input:ByteArray = Buffers.newByteArray();
            const unsigned:UInt64 = new UInt64();
            const signed:Int64 = new Int64();
            const values:Array = [[0, 0], [127, 0], [128, 0], [0xffffffff, 0],
                    [0, 1], [0, 0x80000000], [0xffffffff, 0xffffffff]];
            for (var bit:uint = 0; bit < 64; bit++)
                values.push(bit < 32 ? [uint(1 << bit), 0] : [0, uint(1 << (bit - 32))]);
            for each (var pair:Array in values)
            {
                input.length = 0;
                Serialize.writeVarint64(input, pair[0], pair[1]);
                const encoded:uint = input.length;
                input.position = 0;
                Unpack.begin(context, input, 0);
                try
                {
                    Unpack.readVarint64(context, unsigned);
                    check(unsigned.low == pair[0] && unsigned.high == pair[1] && context.position == encoded,
                            "Memory uint64 preserves both words and encoded length");
                    context.position = 0;
                    Unpack.readVarint64s(context, signed);
                    check(signed.low == pair[0] && uint(signed.high) == pair[1] && context.position == encoded,
                            "Memory int64 preserves both words and encoded length");
                    context.position = 0;
                    const value:Boolean = Unpack.readBool(context);
                    check(value == (pair[0] != 0 || pair[1] != 0) && context.position == encoded,
                            "Memory bool considers the entire 64-bit varint");
                    context.position = 0;
                    Unpack.skipVarint(context);
                    check(context.position == encoded, "Memory skip consumes exactly one varint");
                }
                finally { Unpack.end(context); }
                for (var prefix:uint = 1; prefix < encoded; prefix++)
                {
                    input.position = 0;
                    Unpack.begin(context, input, prefix);
                    try
                    {
                        rejects(function():void { Unpack.readVarint64(context, unsigned); });
                        context.position = 0;
                        rejects(function():void { Unpack.readVarint64s(context, signed); });
                        context.position = 0;
                        rejects(function():void { Unpack.readInt32(context); });
                        context.position = 0;
                        rejects(function():void { Unpack.readBool(context); });
                        context.position = 0;
                        rejects(function():void { Unpack.skipVarint(context); });
                    }
                    finally { Unpack.end(context); }
                }
            }
        }

        private static function testPackedUint32Limits():void
        {
            const context:UnpackContext = new UnpackContext();
            const input:ByteArray = Buffers.newByteArray();
            const out:Vector.<uint> = new Vector.<uint>();
            for each (var length:uint in [0, 1, uint.MAX_VALUE])
            {
                input.length = 0;
                Serialize.writeVarint32(input, length);
                input.position = 0;
                Unpack.begin(context, input, 0);
                try
                {
                    if (length == 0)
                    {
                        Unpack.readVarint32Vector(context, out);
                        check(context.position == context.limit && out.length == 0,
                                "Empty packed vector can end exactly at limit");
                    }
                    else
                    {
                        rejects(function():void { Unpack.readVarint32Vector(context, out); });
                        check(out.length == 0, "Truncated or overflowing packed length is rejected before appending");
                    }
                }
                finally { Unpack.end(context); }
            }
        }

        private static function check(value:Boolean, message:String):void
        {
            if (!value)
                throw new Error(message);
        }

        private static function rejects(callback:Function):void
        {
            var rejected:Boolean = false;
            try { callback(); }
            catch (error:Error) { rejected = true; }
            check(rejected, "Truncated memory input must be rejected");
        }
    }
}
