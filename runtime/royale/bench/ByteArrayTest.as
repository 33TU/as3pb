package
{
    import flash.errors.IOError;
    import flash.utils.ByteArray;
    import flash.utils.Endian;

    /** Checks the shim before running the timed benchmark. */
    public final class ByteArrayTest
    {
        public static function run():void
        {
            testShortStrings();
            testPackedReuse();

            const src:ByteArray = new ByteArray();
            src.writeUnsignedInt(0x12345678);
            src.position = 0;
            check(src.readUnsignedByte() == 0x12, "default big endian");
            src.clear();
            src.endian = Endian.LITTLE_ENDIAN;
            src.writeInt(-123456);
            src.writeUnsignedInt(0xfedcba98);
            src.writeShort(-123);
            src.writeFloat(1.25);
            src.writeDouble(-123.125);
            src.position = 0;
            check(src.readInt() == -123456, "signed int");
            check(src.readUnsignedInt() == 0xfedcba98, "unsigned int");
            check(src.readShort() == -123, "signed short");
            check(src.readFloat() == 1.25, "float");
            check(src.readDouble() == -123.125, "double");

            const capacity:uint = src.data.byteLength;
            src.length = 1;
            src.length = 8;
            src.position = 1;
            check(src.readUnsignedInt() == 0, "regrowth clears truncated bytes");
            check(src.data.byteLength == capacity, "capacity retained");
            src.clear();
            src.position = 3;
            src.writeByte(42);
            src.position = 0;
            check(src.readUnsignedShort() == 0 && src.readUnsignedByte() == 0,
                "writing past the end zero fills the gap");

            const dst:ByteArray = new ByteArray();
            src.position = 3;
            dst.position = 10;
            src.readBytes(dst, 2);
            check(src.position == 4 && dst.position == 10 && dst.length == 3,
                "readBytes preserves destination cursor");
            dst.position = 2;
            check(dst.readUnsignedByte() == 42, "readBytes offset and default length");
            dst.clear();
            dst.writeBytes(src, 3);
            check(dst.length == 1 && src.position == 4,
                "writeBytes uses logical length and preserves source cursor");
            dst.writeBytes(src, src.length);
            check(dst.length == 1, "empty write excludes retained capacity");
            dst.position = 0;
            dst.writeBytes(dst);
            check(dst.length == 1 && dst.position == 1, "self copy");

            src.clear();
            src.writeUTFBytes("Hello, ä世界😀");
            src.position = 0;
            check(src.readUTFBytes(src.length) == "Hello, ä世界😀", "UTF-8 round trip");
            src.length = 1;
            src.position = 0;
            var caught:Boolean = false;
            try { src.readUnsignedInt(); }
            catch (error:IOError) { caught = true; }
            check(caught && src.position == 0, "scalar read checks logical length");
            caught = false;
            try { src.readBytes(dst, 0, 2); }
            catch (copyError:IOError) { caught = true; }
            check(caught && src.position == 0, "copy checks logical length");
            caught = false;
            try { src.readPackedFixed32(new Vector.<uint>(), 1); }
            catch (packedError:IOError) { caught = true; }
            check(caught && src.position == 0, "packed read checks logical length");
            console.log("ByteArray checks passed");
        }

        private static function testPackedReuse():void
        {
            const bytes:ByteArray = new ByteArray();
            bytes.endian = Endian.LITTLE_ENDIAN;
            bytes.writeUnsignedInt(0xfedcba98);
            bytes.writeUnsignedInt(42);
            bytes.position = 0;
            const words:Vector.<uint> = new <uint>[1, 2, 3];
            bytes.readPackedFixed32(words, 2);
            check(words.length == 2 && words[0] == 0xfedcba98 && words[1] == 42
                && bytes.position == 8, "packed fixed32 replaces old values");
            bytes.readPackedFixed32(words, 0);
            check(words.length == 0 && bytes.position == 8, "empty packed fixed32");

            bytes.clear();
            bytes.writeUnsignedInt(0xffffffff);
            bytes.writeInt(-2);
            bytes.position = 0;
            const low:Vector.<uint> = new <uint>[1, 2];
            const high:Vector.<int> = new <int>[3, 4];
            bytes.readPackedSfixed64(low, high, 1);
            check(low.length == 1 && high.length == 1 && low[0] == 0xffffffff
                && high[0] == -2 && bytes.position == 8,
                "packed sfixed64 replaces both word arrays");
            bytes.readPackedSfixed64(low, high, 0);
            check(low.length == 0 && high.length == 0 && bytes.position == 8,
                "empty packed sfixed64");

            bytes.clear();
            bytes.writeFloat(-1.25);
            bytes.writeFloat(2.5);
            bytes.position = 0;
            const floats:Vector.<Number> = new <Number>[99];
            bytes.readPackedFloat(floats, 2);
            check(floats.length == 2 && floats[0] == -1.25 && floats[1] == 2.5
                && bytes.position == 8, "packed float replaces old values");
            bytes.readPackedFloat(floats, 0);
            check(floats.length == 0 && bytes.position == 8, "empty packed float");
        }

        private static function testShortStrings():void
        {
            const strings:Array = ["", "a", "abcdefg", "abcdefgh", "abcdefghi",
                "123456789012345678901234567890123",
                "1234567890123456789012345678901234",
                "12345678901234567890123456789012345",
                "abcdefgé", "abcdefghé", "世界", "abcdefgh😀", "a\u0000b"];
            const bytes:ByteArray = new ByteArray();
            for each (var text:String in strings)
            {
                bytes.clear();
                bytes.writeByte(42);
                bytes.writeUTFBytes(text);
                const length:uint = bytes.length - 1;
                bytes.writeByte(99);
                bytes.position = 1;
                check(bytes.readUTFBytes(length) == text, "ASCII/UTF-8 boundary round trip");
                check(bytes.readUnsignedByte() == 99, "string read cursor");
            }
            bytes.clear();
            bytes.writeUTFBytes("abcdefgh");
            bytes.writeByte(0xc3);
            bytes.writeByte(0x28);
            bytes.position = 0;
            check(bytes.readUTFBytes(bytes.length) == "abcdefgh\ufffd(",
                "invalid UTF-8 fallback preserves replacement behavior");
            bytes.position = 0;
            var caught:Boolean = false;
            try { bytes.readUTFBytes(bytes.length + 1); }
            catch (error:IOError) { caught = true; }
            check(caught && bytes.position == 0, "short string EOF preserves cursor");
        }

        private static function check(condition:Boolean, message:String):void
        {
            if (!condition)
                throw new Error("ByteArray check failed: " + message);
        }
    }
}
