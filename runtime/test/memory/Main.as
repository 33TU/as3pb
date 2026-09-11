package memory
{
    import flash.display.Sprite;
    import flash.system.ApplicationDomain;
    import flash.utils.ByteArray;
    import flash.utils.Endian;
    import as3pb.proto.*;
    import as3pb.types.Int64Vector;
    import as3pb.types.UInt64Vector;
    import flash.errors.IOError;
    import flash.errors.EOFError;
    import test.RuntimeSample;
    import test.RuntimeNested;
    import test.RuntimeAnyEnvelope;
    import google.protobuf.Any;

    /** Compile with both memory generation options enabled. */
    public final class Main extends Sprite
    {
        public function Main()
        {
            const domain:ApplicationDomain = ApplicationDomain.currentDomain;
            const original:ByteArray = domain.domainMemory;
            const sentinel:ByteArray = new ByteArray();
            sentinel.length = ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH;
            domain.domainMemory = sentinel;
            try
            {
                attachedContexts(sentinel);
                roundTripAndBatch(sentinel);
                shippedTypes(sentinel);
                nestedContexts(sentinel);
                failureRestoration(sentinel);
                capacityAndBinding(sentinel);
                fixedVectors(sentinel);
                fixedWidthVectors(sentinel);
                boolVectors(sentinel);
                varint32Vectors(sentinel);
                trace("MEMORY BACKEND TESTS PASSED");
            }
            finally
            {
                domain.domainMemory = original;
            }
        }

        private static function check(ok:Boolean, message:String):void
        {
            if (!ok)
                throw new Error(message);
        }

        private static function same(a:ByteArray, b:ByteArray):void
        {
            check(a.length == b.length, "wire length");
            for (var i:uint = 0; i < a.length; i++)
                check(a[i] == b[i], "wire byte " + i);
        }

        private static function attachedContexts(previous:ByteArray):void
        {
            const domain:ApplicationDomain = ApplicationDomain.currentDomain;
            const encoder:PackContext = new PackContext();
            const decoder:UnpackContext = new UnpackContext();
            const nested:PackContext = new PackContext();
            const other:ByteArray = new ByteArray();
            other.length = ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH;
            const message:RuntimeSample = new RuntimeSample();
            message.id = "attached \u20ac";
            message.payload.length = 4096;
            message.payload[4095] = 123;
            message.scores.push(-1, 0, 127, 128);
            const expected:ByteArray = Buffers.newByteArray();
            RuntimeSample.serializeBytes(message, expected);
            previous.position = 11;
            Pack.attach(encoder, 7);
            try
            {
                check(previous.position == 11 && domain.domainMemory === previous, "pack attach preserves binding and cursor");
                var failed:Boolean = false;
                Pack.attach(encoder, 0);
                check(encoder.position == 0, "pack reattach resets cursor");
                Pack.attach(encoder, 7);
                RuntimeSample.serializeMemory(message, encoder);
                Pack.begin(nested, other);
                try { Pack.writeVarint32(nested, 123); }
                finally { Pack.end(nested); }
                check(domain.domainMemory === previous, "nested begin restores attached binding");
            }
            finally { Pack.detach(encoder); }
            const length:uint = encoder.position - 7;
            check(length == expected.length && previous.position == encoder.position, "attached output cursor");
            check(previous.length > 4096 && previous.endian == Endian.BIG_ENDIAN, "attached output grows without changing endian");
            for (var i:uint = 0; i < length; i++)
                check(previous[7 + i] == expected[i], "attached output wire bytes");
            // Decode requires spare capacity even if packing ended exactly at capacity.
            if (previous.length < 7 + length + 10) previous.length = 7 + length + 10;
            previous.position = 11;
            Unpack.attach(decoder, 7, length);
            try
            {
                check(previous.position == 11 && domain.domainMemory === previous, "unpack attach preserves binding and cursor");
                Unpack.attach(decoder, 7, 0);
                check(decoder.limit == 7, "unpack reattach resets limit");
                Unpack.attach(decoder, 7, length);
                check(decoder.position == 7 && decoder.limit == 7 + length, "unpack reattach resets range");
                const decoded:RuntimeSample = RuntimeSample.deserializeMemory(decoder, null, length);
                check(decoded.id == message.id && decoded.scores.join() == message.scores.join(), "attached values");
                same(decoded.payload, message.payload);
            }
            finally { Unpack.detach(decoder); }
            check(previous.position == 7 + length && domain.domainMemory === previous, "unpack detach preserves binding");
            Unpack.attach(decoder, 7, 0);
            try { check(RuntimeSample.deserializeMemory(decoder, null, 0) != null, "attached empty range"); }
            finally { Unpack.detach(decoder); }
            for each (var position:uint in [previous.length - 9, 0xffffffff])
            {
                failed = false;
                try { Unpack.attach(decoder, position, 1); }
                catch (error:Error) { failed = true; }
                check(failed && domain.domainMemory === previous, "invalid attached decode range");
            }
            const writePosition:uint = previous.length + 1;
            Pack.attach(encoder, writePosition);
            try
            {
                Pack.writeVarint32(encoder, 42);
                check(previous[writePosition] == 42 && encoder.position == writePosition + 1,
                    "attached writer grows beyond existing capacity");
            }
            finally { Pack.detach(encoder); }
            Pack.attach(encoder, 0);
            check(encoder.position == 0, "pack attach uses explicit zero");
            domain.domainMemory = other;
            failed = false;
            try { Pack.detach(encoder); }
            catch (error:Error) { failed = true; }
            check(failed && domain.domainMemory === other, "detach rejects replaced binding");
            domain.domainMemory = previous;
            Pack.detach(encoder);
            Pack.begin(nested, other);
            try
            {
                failed = false;
                try { Pack.detach(nested); }
                catch (error:Error) { failed = true; }
                check(failed, "detach cannot discard a different previous binding");
            }
            finally { Pack.end(nested); }

        }

        private static function roundTripAndBatch(previous:ByteArray):void
        {
            const msg:RuntimeSample = new RuntimeSample();
            msg.id = "memory \u20ac \uD83D\uDE00";
            msg.count.low = 0xffffffff;
            msg.count.high = 0xabcdef01;
            msg.delta.low = 0x12345678;
            msg.delta.high = -123;
            msg.nested = new RuntimeNested();
            msg.nested.label_ = "child";
            msg.children.push(new RuntimeNested(), msg.nested, new RuntimeNested());
            for (var i:uint = 0; i < 10000; i++)
                msg.scores.push(int(i) - 5000);
            msg.payload.length = 100000;
            msg.payload[99999] = 127;

            const expected:ByteArray = Buffers.newByteArray();
            expected.writeByte(77);
            RuntimeSample.serializeBytes(msg, expected);
            const first:uint = expected.position - 1;
            RuntimeNested.serializeBytes(msg.nested, expected);
            const second:uint = expected.position - first - 1;

            const output:ByteArray = new ByteArray();
            output.endian = Endian.BIG_ENDIAN;
            output.writeByte(77);
            output.length = ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH;
            const pack:PackContext = new PackContext();
            Pack.begin(pack, output);
            try
            {
                RuntimeSample.serializeMemory(msg, pack);
                check(pack.position == first + 1, "first packed position");
                RuntimeNested.serializeMemory(msg.nested, pack);
            }
            finally
            {
                Pack.end(pack);
            }
            check(output.position == expected.length, "written position");
            for (var wireIndex:uint = 0; wireIndex < expected.length; wireIndex++)
                check(output[wireIndex] == expected[wireIndex], "direct wire byte");
            check(output.endian == Endian.BIG_ENDIAN, "output endian preserved");
            check(ApplicationDomain.currentDomain.domainMemory === previous, "pack binding restored");

            const length:uint = output.length;
            output.position = 1;
            const unpack:UnpackContext = new UnpackContext();
            const reused:RuntimeSample = new RuntimeSample();
            Unpack.begin(unpack, output, first + second);
            try
            {
                check(RuntimeSample.deserializeMemory(unpack, reused, first) === reused, "reuse identity");
                check(unpack.position == first + 1, "first decoded position");
                check(unpack.limit == first + second + 1, "nested limit restored");
                check(reused.id == msg.id && reused.scores.length == 10000, "string and packed vector");
                check(reused.count.low == msg.count.low && reused.count.high == msg.count.high, "uint64 words");
                check(reused.payload.length == 100000 && reused.payload[99999] == 127, "grown bytes");
                check(reused.children.length == 3 && reused.children[0] !== reused.children[2], "empty children");
                check(RuntimeNested.deserializeMemory(unpack, null, second).label_ == "child", "second message");
            }
            finally
            {
                Unpack.end(unpack);
            }
            check(output.length == length && output.position == expected.length, "input length and position");
            check(output.endian == Endian.BIG_ENDIAN, "input endian preserved");
            check(ApplicationDomain.currentDomain.domainMemory === previous, "unpack binding restored");
            const encodedAgain:ByteArray = Buffers.newByteArray();
            RuntimeSample.serializeBytes(reused, encodedAgain);
            expected.position = 1;
            const firstBytes:ByteArray = new ByteArray();
            expected.readBytes(firstBytes, 0, first);
            same(encodedAgain, firstBytes);

            // Reusing contexts after large operations must not expose stale data.
            output.position = 0;
            Unpack.begin(unpack, output, 0);
            try
            {
                check(RuntimeSample.deserializeMemory(unpack, reused, 0).id == "", "empty reset");
            }
            finally
            {
                Unpack.end(unpack);
            }
            check(output.position == 0 && output.length == length, "empty cursor");
            Pack.begin(pack, output);
            try
            {
                RuntimeSample.serializeMemory(null, pack);
            }
            finally
            {
                Pack.end(pack);
            }
            check(output.position == 0 && output.length == length, "null encode writes nothing");
        }

        private static function shippedTypes(previous:ByteArray):void
        {
            const message:RuntimeAnyEnvelope = new RuntimeAnyEnvelope();
            message.payload = new Any();
            message.payload.typeUrl = "type.googleapis.com/test.RuntimeNested";
            const child:RuntimeNested = new RuntimeNested();
            child.label_ = "shipped Any";
            RuntimeNested.serializeBytes(child, message.payload.value);

            const expected:ByteArray = Buffers.newByteArray();
            RuntimeAnyEnvelope.serializeBytes(message, expected);
            const output:ByteArray = Buffers.newByteArray();
            output.length = ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH;
            const encoder:PackContext = new PackContext();
            Pack.begin(encoder, output);
            try
            {
                RuntimeAnyEnvelope.serializeMemory(message, encoder);
            }
            finally
            {
                Pack.end(encoder);
            }
            check(output.position == expected.length, "written position");
            for (var wireIndex:uint = 0; wireIndex < expected.length; wireIndex++)
                check(output[wireIndex] == expected[wireIndex], "direct wire byte");

            const decoder:UnpackContext = new UnpackContext();
            output.position = 0;
            Unpack.begin(decoder, output, expected.length);
            try
            {
                const decoded:RuntimeAnyEnvelope = RuntimeAnyEnvelope.deserializeMemory(decoder, null, expected.length);
                check(decoded.payload.typeUrl == message.payload.typeUrl, "shipped Any type URL");
                same(decoded.payload.value, message.payload.value);
            }
            finally
            {
                Unpack.end(decoder);
            }
            check(ApplicationDomain.currentDomain.domainMemory === previous, "shipped Any binding restored");
        }

        private static function nestedContexts(previous:ByteArray):void
        {
            const input:ByteArray = Buffers.newByteArray();
            Serialize.writeVarint32(input, 300);
            input.length = ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH;
            input.position = 0;
            const outer:UnpackContext = new UnpackContext();
            const inner:UnpackContext = new UnpackContext();
            const pack:PackContext = new PackContext();
            const output:ByteArray = new ByteArray();
            output.length = ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH;
            Unpack.begin(outer, input, 2);
            const boundMemory:ByteArray = ApplicationDomain.currentDomain.domainMemory;
            try
            {
                Unpack.begin(inner, input, 2);
                try
                {
                    check(Unpack.readVarint32(inner) == 300, "inner decode");
                }
                finally
                {
                    Unpack.end(inner);
                }
                check(ApplicationDomain.currentDomain.domainMemory === boundMemory, "outer memory restored");
                Pack.begin(pack, output);
                try
                {
                    Pack.writeVarint32(pack, 12345);
                }
                finally
                {
                    Pack.end(pack);
                }
                check(ApplicationDomain.currentDomain.domainMemory === boundMemory, "cross-direction binding restored");
                check(Unpack.readVarint32(outer) == 300, "outer storage preserved");
            }
            finally
            {
                Unpack.end(outer);
            }
            check(ApplicationDomain.currentDomain.domainMemory === previous, "nested binding restored");
        }

        private static function failureRestoration(previous:ByteArray):void
        {
            const input:ByteArray = new ByteArray();
            input.writeByte(10);
            input.writeByte(5);
            input.writeByte(65);
            input.length = ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH;
            input.position = 0;
            const context:UnpackContext = new UnpackContext();
            Unpack.begin(context, input, 3);
            var failed:Boolean = false;
            try
            {
                try
                {
                    RuntimeSample.deserializeMemory(context, null, 3);
                }
                catch (error:Error)
                {
                    failed = true;
                }
                check(context.limit == 3, "limit restored on failure");
            }
            finally
            {
                Unpack.end(context);
            }
            check(failed, "truncated string rejected");
            check(ApplicationDomain.currentDomain.domainMemory === previous, "failed decode restored binding");

            input.position = 0;
            input.writeByte(0x80);
            input.position = 0;
            Unpack.begin(context, input, 1);
            failed = false;
            try
            {
                Unpack.readVarint32(context);
            }
            catch (error:Error)
            {
                failed = true;
            }
            finally
            {
                Unpack.end(context);
            }
            check(failed && input.position == 1, "logical varint boundary");
            check(ApplicationDomain.currentDomain.domainMemory === previous, "failed varint restored binding");
        }
        private static function varint32Vectors(previous:ByteArray):void
        {
            const bytes:ByteArray = new ByteArray();
            const context:UnpackContext = new UnpackContext();
            const fixtures:Array = [
                [], [127], [0, 1, 127], [0, 1, 2, 127], [0, 1, 2, 127, 126],
                [128, 1, 0, 1, 2, 127], [0, 128, 1, 1, 2, 127],
                [0, 1, 128, 1, 2, 127], [0, 1, 2, 128, 1, 127],
                [0, 1, 2, 127, 255, 255, 255, 255, 15, 0, 1, 2, 127],
                [0, 1, 2, 127, 255, 255, 255, 255, 255, 255, 255, 255, 255, 1]
            ];
            for each (var data:Array in fixtures)
            {
                bytes.position = 3;
                bytes.writeByte(data.length);
                for each (var value:uint in data) bytes.writeByte(value);
                bytes.length = ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH;
                for (var variant:uint = 0; variant < 4; variant++)
                {
                    const expectedUnsigned:Vector.<uint> = new <uint>[42];
                    const actualUnsigned:Vector.<uint> = new <uint>[42];
                    const expectedSigned:Vector.<int> = new <int>[42];
                    const actualSigned:Vector.<int> = new <int>[42];
                    bytes.position = 3;
                    switch (variant)
                    {
                        case 0: Deserialize.readVarint32Vector(bytes, expectedUnsigned); break;
                        case 1: Deserialize.readVarint32sVector(bytes, expectedSigned); break;
                        case 2: Deserialize.readInt32Vector(bytes, expectedSigned); break;
                        case 3: Deserialize.readSint32Vector(bytes, expectedSigned); break;
                    }
                    bytes.position = 3;
                    Unpack.begin(context, bytes, 1 + data.length);
                    try
                    {
                        switch (variant)
                        {
                            case 0: Unpack.readVarint32Vector(context, actualUnsigned); break;
                            case 1: Unpack.readVarint32sVector(context, actualSigned); break;
                            case 2: Unpack.readInt32Vector(context, actualSigned); break;
                            case 3: Unpack.readSint32Vector(context, actualSigned); break;
                        }
                        check(actualUnsigned.join() == expectedUnsigned.join() &&
                            actualSigned.join() == expectedSigned.join(), "batched varint values and append");
                        check(context.position == 4 + data.length, "batched varint cursor");
                    }
                    finally { Unpack.end(context); }
                }
            }
            check(ApplicationDomain.currentDomain.domainMemory === previous, "varint vectors restore binding");
        }

        private static function boolVectors(previous:ByteArray):void
        {
            const bytes:ByteArray = new ByteArray();
            const context:UnpackContext = new UnpackContext();
            const out:Vector.<Boolean> = new Vector.<Boolean>();
            const fixtures:Array = [
                {data: [], expected: []},
                {data: [0], expected: [false]},
                {data: [0, 1, 2], expected: [false, true, true]},
                {data: [0, 1, 2, 127], expected: [false, true, true, true]},
                {data: [0, 1, 2, 127, 0, 1, 0, 1, 1],
                    expected: [false, true, true, true, false, true, false, true, true]},
                {data: [0, 1, 0, 1, 128, 0, 128, 1, 0, 2, 0, 127, 1],
                    expected: [false, true, false, true, false, true, false, true, false, true, true]},
                {data: [128, 128, 128, 128, 128, 128, 128, 128, 128, 1, 0, 1, 0, 1],
                    expected: [true, false, true, false, true]},
                {data: [0, 128, 0, 1, 1], expected: [false, false, true, true]},
                {data: [0, 1, 128, 0, 1], expected: [false, true, false, true]},
                {data: [0, 1, 0, 128, 0], expected: [false, true, false, false]}
            ];
            for each (var fixture:Object in fixtures)
            {
                bytes.position = 3;
                bytes.writeByte(fixture.data.length);
                for each (var value:uint in fixture.data) bytes.writeByte(value);
                bytes.length = ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH;
                bytes.position = 3;
                out.length = 0;
                out.push(true);
                Unpack.begin(context, bytes, 1 + fixture.data.length);
                try
                {
                    Unpack.readBoolVector(context, out);
                    check(context.position == 4 + fixture.data.length, "packed bool cursor");
                    check(out.length == fixture.expected.length + 1 && out[0], "packed bool append");
                    for (var i:uint = 0; i < fixture.expected.length; i++)
                        check(out[i + 1] == fixture.expected[i], "packed bool value");
                }
                finally { Unpack.end(context); }
            }
            for each (var malformed:Boolean in [false, true])
            {
                bytes.position = 3;
                const length:uint = malformed ? 14 : 5;
                bytes.writeByte(length);
                bytes.writeUnsignedInt(0);
                for (i = 4; i < length; i++) bytes.writeByte(0x80);
                bytes.position = 3;
                Unpack.begin(context, bytes, 1 + length);
                var failed:Boolean = false;
                try { Unpack.readBoolVector(context, out); }
                catch (error:Error)
                {
                    failed = malformed ? error is IOError : error is EOFError;
                }
                finally { Unpack.end(context); }
                check(failed, "packed bool validates fallback after fast block");
            }
            check(ApplicationDomain.currentDomain.domainMemory === previous, "packed bool restores binding");
        }

        private static function fixedWidthVectors(previous:ByteArray):void
        {
            const bytes:ByteArray = new ByteArray();
            bytes.endian = Endian.LITTLE_ENDIAN;
            const context:UnpackContext = new UnpackContext();
            const words:Array = [0, 0x80000000, 0x7f800000, 0xff800000, 0x7fc00001, 0x3fa00000, 0xbfa00000, 1];
            const highWords:Array = [0, 0x80000000, 0x7ff00000, 0xfff00000, 0x7ff80000, 0x3ff40000, 0xbff40000, 1];
            for (var variant:uint = 0; variant < 4; variant++)
            {
                const width:uint = variant == 2 ? 8 : 4;
                for each (var count:uint in [0, 1, 3, 4, 5, 8, 9])
                {
                    bytes.position = 5;
                    bytes.writeByte(count * width);
                    for (var i:uint = 0; i < count; i++)
                    {
                        if (variant == 2)
                        {
                            bytes.writeUnsignedInt(0);
                            bytes.writeUnsignedInt(highWords[i % highWords.length]);
                        }
                        else bytes.writeUnsignedInt(words[i % words.length]);
                    }
                    bytes.length = ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH;
                    const expectedUnsigned:Vector.<uint> = new <uint>[42];
                    const actualUnsigned:Vector.<uint> = new <uint>[42];
                    const expectedInts:Vector.<int> = new <int>[42];
                    const actualInts:Vector.<int> = new <int>[42];
                    const expected:Vector.<Number> = new <Number>[42];
                    const actual:Vector.<Number> = new <Number>[42];
                    bytes.position = 5;
                    if (variant == 3) Deserialize.readFixed32Vector(bytes, expectedUnsigned);
                    else if (variant == 0) Deserialize.readFixed32sVector(bytes, expectedInts);
                    else if (variant == 1) Deserialize.readFloatVector(bytes, expected);
                    else Deserialize.readDoubleVector(bytes, expected);
                    bytes.position = 5;
                    Unpack.begin(context, bytes, 1 + count * width);
                    try
                    {
                        if (variant == 3) Unpack.readFixed32Vector(context, actualUnsigned);
                        else if (variant == 0) Unpack.readFixed32sVector(context, actualInts);
                        else if (variant == 1) Unpack.readFloatVector(context, actual);
                        else Unpack.readDoubleVector(context, actual);
                        check(context.position == 6 + count * width, "fixed width vector cursor");
                        check(actualUnsigned.join() == expectedUnsigned.join() &&
                            actualInts.join() == expectedInts.join() && actual.length == expected.length,
                            "fixed width vectors append, including empty input");
                        for (i = 0; i < expected.length; i++)
                            check((isNaN(actual[i]) && isNaN(expected[i])) ||
                                (actual[i] === expected[i] && (actual[i] != 0 || 1 / actual[i] == 1 / expected[i])),
                                "fixed width vector values include infinities, NaN and signed zero");
                    }
                    finally { Unpack.end(context); }
                }
                for each (var length:uint in [1, width - 1, width + 1])
                {
                    bytes[5] = length;
                    bytes.position = 5;
                    Unpack.begin(context, bytes, 1 + length);
                    var failed:Boolean = false;
                    try
                    {
                        if (variant == 3) Unpack.readFixed32Vector(context, actualUnsigned);
                        else if (variant == 0) Unpack.readFixed32sVector(context, actualInts);
                        else if (variant == 1) Unpack.readFloatVector(context, actual);
                        else Unpack.readDoubleVector(context, actual);
                    }
                    catch (error:IOError) { failed = true; }
                    finally { Unpack.end(context); }
                    check(failed && context.position == 6 + length - length % width,
                        "fixed width vector rejects partial elements");
                }
            }
            check(ApplicationDomain.currentDomain.domainMemory === previous, "fixed width vectors restore binding");
        }

        private static function fixedVectors(previous:ByteArray):void
        {
            const bytes:ByteArray = new ByteArray();
            bytes.endian = Endian.LITTLE_ENDIAN;
            const context:UnpackContext = new UnpackContext();
            const unsigned:UInt64Vector = new UInt64Vector();
            const signed:Int64Vector = new Int64Vector();
            for each (var count:uint in [0, 1, 3, 4, 5, 8, 9])
            {
                bytes.position = 7;
                bytes.writeByte(count * 8);
                for (var i:uint = 0; i < count; i++)
                {
                    bytes.writeUnsignedInt(0xabcdef00 + i);
                    bytes.writeInt(-1 - i);
                }
                bytes.length = ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH;
                bytes.position = 7;
                unsigned.length = 0;
                signed.length = 0;
                Unpack.begin(context, bytes, 1 + count * 8);
                try
                {
                    for (var pass:uint = 0; pass < 2; pass++)
                    {
                        context.position = 7;
                        Unpack.readFixed64Vector(context, unsigned);
                        check(context.position == 8 + count * 8, "unsigned fixed vector cursor");
                        context.position = 7;
                        Unpack.readFixed64sVector(context, signed);
                        check(context.position == 8 + count * 8, "signed fixed vector cursor");
                    }
                    check(unsigned.length == count * 2 && signed.length == count * 2,
                        "fixed vectors append, including empty vectors");
                    for (i = 0; i < count * 2; i++)
                    {
                        check(unsigned.low[i] == uint(0xabcdef00 + i % count) &&
                            unsigned.high[i] == uint(-1 - int(i % count)), "unsigned fixed vector words");
                        check(signed.low[i] == uint(0xabcdef00 + i % count) &&
                            signed.high[i] == -1 - int(i % count), "signed fixed vector words");
                    }
                }
                finally { Unpack.end(context); }
            }
            for each (var length:uint in [1, 7, 9, 15])
            {
                bytes[7] = length;
                for (var variant:uint = 0; variant < 2; variant++)
                {
                    bytes.position = 7;
                    Unpack.begin(context, bytes, 1 + length);
                    var failed:Boolean = false;
                    try
                    {
                        if (variant) Unpack.readFixed64sVector(context, signed);
                        else Unpack.readFixed64Vector(context, unsigned);
                    }
                    catch (error:IOError) { failed = true; }
                    finally { Unpack.end(context); }
                    check(failed && context.position == 8 + (length & ~7), "fixed vector partial element");
                }
            }
            bytes[7] = 8;
            bytes.position = 7;
            Unpack.begin(context, bytes, 1);
            failed = false;
            try { Unpack.readFixed64Vector(context, unsigned); }
            catch (error:EOFError) { failed = true; }
            finally { Unpack.end(context); }
            check(failed, "fixed vector respects logical limit despite spare capacity");
            check(ApplicationDomain.currentDomain.domainMemory === previous, "fixed vectors restore binding");
        }

        private static function capacityAndBinding(previous:ByteArray):void
        {
            const bytes:ByteArray = new ByteArray();
            bytes.length = ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH;
            bytes.position = bytes.length - 11;
            const start:uint = bytes.position;
            const encoder:PackContext = new PackContext();
            Pack.begin(encoder, bytes);
            try
            {
                check(ApplicationDomain.currentDomain.domainMemory === bytes, "caller buffer bound for encode");
                Pack.writeVarint32(encoder, 42);
                check(bytes[start] == 42, "encoded byte immediately visible");
                const capacityBefore:uint = bytes.length;
                var oversized:Boolean = false;
                try { Pack.ensure(encoder, 0x80000000); }
                catch (error:RangeError) { oversized = true; }
                check(oversized && bytes.length == capacityBefore && encoder.position == start + 1,
                    "oversized reservation rejected before resizing or advancing");
            }
            finally
            {
                Pack.end(encoder);
            }
            check(encoder.position == start + 1 && bytes.position == encoder.position, "final position retained");
            const decoder:UnpackContext = new UnpackContext();
            bytes.position = start;
            Unpack.begin(decoder, bytes, 1);
            try
            {
                check(ApplicationDomain.currentDomain.domainMemory === bytes, "caller buffer bound for decode");
                bytes[start] = 43;
                check(Unpack.readVarint32(decoder) == 43, "decode reads caller memory directly");
            }
            finally
            {
                Unpack.end(decoder);
            }
            check(decoder.position == start + 1, "decode final position retained");
            const capacity:uint = bytes.length;
            bytes.position = capacity - 1;
            var failed:Boolean = false;
            try
            {
                Unpack.begin(decoder, bytes, 1);
            }
            catch (error:RangeError)
            {
                failed = true;
            }
            check(failed && bytes.length == capacity, "caller must supply spare capacity");
            check(ApplicationDomain.currentDomain.domainMemory === previous, "failed begin preserves binding");

            bytes.position = capacity - 1;
            Pack.begin(encoder, bytes);
            try
            {
                Pack.writeVarint32(encoder, 0xffffffff);
                check(bytes.length > capacity && encoder.position == capacity + 4,
                    "scalar writer grows capacity without an explicit reservation");
                check(bytes[capacity - 1] == 0xff && bytes[capacity + 3] == 0x0f,
                    "scalar growth preserves encoded bytes");
            }
            finally
            {
                Pack.end(encoder);
            }
        }
    }
}
