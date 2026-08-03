package as3pb.proto
{
    import flash.utils.ByteArray;
    import flash.errors.IOError;

    import as3pb.types.Int64;
    import as3pb.types.UInt64;
    import as3pb.types.UInt64Vector;
    import as3pb.types.Int64Vector;

    /**
     * Deserialization utilities for Protocol Buffers in ActionScript 3 for bytearrays.
     * All srcs are expected to be in little-endian byte order as per Protocol Buffers specification.
     */
    public final class Deserialize
    {
        /**
         * Reusable uint64 scratch value.
         */
        private static const TMP_UINT64:UInt64 = new UInt64();

        /**
         * Reusable int64 scratch value.
         */
        private static const TMP_INT64:Int64 = new Int64();

        /**
         * Read a varint-encoded 32-bit unsigned integer
         * @param src The source ByteArray to read from
         * @return The decoded value.
         */
        [Inline]
        public static function readVarint32(src:ByteArray):uint
        {
            // Byte 1 (fast path)
            var b:uint = src.readUnsignedByte();
            if (b < 0x80)
                return b;
            var result:uint = b & 0x7F;

            // Byte 2
            b = src.readUnsignedByte();
            if (b < 0x80)
                return result | (b << 7);
            result |= (b & 0x7F) << 7;

            // Byte 3
            b = src.readUnsignedByte();
            if (b < 0x80)
                return result | (b << 14);
            result |= (b & 0x7F) << 14;

            // Byte 4
            b = src.readUnsignedByte();
            if (b < 0x80)
                return result | (b << 21);
            result |= (b & 0x7F) << 21;

            // Byte 5 (only the low four bits fit in a 32-bit value)
            b = src.readUnsignedByte();
            if (b > 0x0F)
                throw new IOError("Malformed varint32: exceeds 32 bits");

            return result | (b << 28);
        }

        /**
         * Reads packed unsigned 32-bit varint values into a vector.
         * @param src Source ByteArray.
         * @param out Destination object to populate.
         */
        public static function readVarint32Vector(src:ByteArray, out:Vector.<uint>):void
        {
            const length:uint = readVarint32(src);
            const end:uint = src.position + length;

            while (src.position < end)
                out.push(readVarint32(src));

            if (src.position != end)
                throw new IOError("Varint32 vector length mismatch");
        }

        /**
         * Reads packed signed 32-bit varint values into a vector.
         * @param src Source ByteArray.
         * @param out Destination object to populate.
         */
        public static function readVarint32sVector(src:ByteArray, out:Vector.<int>):void
        {
            const length:uint = readVarint32(src);
            const end:uint = src.position + length;

            while (src.position < end)
                out.push(readVarint32(src));

            if (src.position != end)
                throw new IOError("Varint32 vector length mismatch");
        }

        /**
         * Read a varint-encoded signed 32-bit integer.
         * Canonical protobuf negative int32 values can use 10 bytes.
         * @param src The source ByteArray to read from
         * @return The decoded value.
         */
        [Inline]
        public static function readInt32(src:ByteArray):int
        {
            var b:uint = src.readUnsignedByte();
            if (b < 0x80)
                return int(b);
            var result:uint = b & 0x7F;

            b = src.readUnsignedByte();
            if (b < 0x80)
                return int(result | (b << 7));
            result |= (b & 0x7F) << 7;

            b = src.readUnsignedByte();
            if (b < 0x80)
                return int(result | (b << 14));
            result |= (b & 0x7F) << 14;

            b = src.readUnsignedByte();
            if (b < 0x80)
                return int(result | (b << 21));
            result |= (b & 0x7F) << 21;

            b = src.readUnsignedByte();
            result |= (b & 0x7F) << 28;
            if (b < 0x80)
                return int(result);

            for (var i:uint = 0; i < 5; i++)
            {
                b = src.readUnsignedByte();
                if (i == 4 && b > 0x01)
                    throw new IOError("Malformed int32: exceeds 64 bits");
                if (b < 0x80)
                    return int(result);
            }

            throw new IOError("Malformed int32: exceeds 64 bits");
        }

        /**
         * Reads packed signed 32-bit int32 values into a vector.
         * @param src Source ByteArray.
         * @param out Destination object to populate.
         */
        public static function readInt32Vector(src:ByteArray, out:Vector.<int>):void
        {
            const length:uint = readVarint32(src);
            const end:uint = src.position + length;

            while (src.position < end)
                out.push(readInt32(src));

            if (src.position != end)
                throw new IOError("Int32 vector length mismatch");
        }

        /**
         * Read a varint-encoded 64-bit unsigned integer
         * @param src The source ByteArray
         * @param out The UInt64 object to write into
         */
        [Inline]
        public static function readVarint64(src:ByteArray, out:UInt64):void
        {
            var b:uint;
            var low:uint = 0;
            var high:uint = 0;

            // byte 1
            b = src.readUnsignedByte();
            low = b & 0x7F;
            if (b < 0x80)
            {
                out.low = low;
                out.high = 0;
                return;
            }

            // byte 2
            b = src.readUnsignedByte();
            low |= (b & 0x7F) << 7;
            if (b < 0x80)
            {
                out.low = low;
                out.high = 0;
                return;
            }

            // byte 3
            b = src.readUnsignedByte();
            low |= (b & 0x7F) << 14;
            if (b < 0x80)
            {
                out.low = low;
                out.high = 0;
                return;
            }

            // byte 4
            b = src.readUnsignedByte();
            low |= (b & 0x7F) << 21;
            if (b < 0x80)
            {
                out.low = low;
                out.high = 0;
                return;
            }

            // byte 5
            b = src.readUnsignedByte();
            low |= (b & 0x7F) << 28;
            if (b < 0x80)
            {
                out.low = low;
                out.high = (b & 0x70) >>> 4;
                return;
            }

            high = (b & 0x7F) >>> 4;

            // byte 6
            b = src.readUnsignedByte();
            high |= (b & 0x7F) << 3;
            if (b < 0x80)
            {
                out.low = low;
                out.high = high;
                return;
            }

            // byte 7
            b = src.readUnsignedByte();
            high |= (b & 0x7F) << 10;
            if (b < 0x80)
            {
                out.low = low;
                out.high = high;
                return;
            }

            // byte 8
            b = src.readUnsignedByte();
            high |= (b & 0x7F) << 17;
            if (b < 0x80)
            {
                out.low = low;
                out.high = high;
                return;
            }

            // byte 9
            b = src.readUnsignedByte();
            high |= (b & 0x7F) << 24;
            if (b < 0x80)
            {
                out.low = low;
                out.high = high;
                return;
            }

            // byte 10 (only 1 bit used)
            b = src.readUnsignedByte();
            if (b > 0x01)
                throw new IOError("Malformed varint64: exceeds 64 bits");

            high |= (b & 0x01) << 31;

            out.low = low;
            out.high = high;
        }

        /**
         * Reads packed Varint64 values into a vector.
         * @param src Source ByteArray.
         * @param out Destination object to populate.
         */
        public static function readVarint64Vector(src:ByteArray, out:UInt64Vector):void
        {
            const length:uint = readVarint32(src);
            const end:uint = src.position + length;
            const tmp:UInt64 = TMP_UINT64;

            while (src.position < end)
            {
                readVarint64(src, tmp);
                out.push(tmp.low, tmp.high);
            }

            if (src.position != end)
                throw new IOError("Varint64 vector length mismatch");
        }

        /**
         * Read a varint-encoded 64-bit signed integer
         * @param src The source ByteArray
         * @param out The Int64 object to write into
         */
        [Inline]
        public static function readVarint64s(src:ByteArray, out:Int64):void
        {
            // NOTE: duplicate logic of above
            var b:uint;
            var low:uint = 0;
            var high:uint = 0;

            // byte 0
            b = src.readUnsignedByte();
            low = b & 0x7F;
            if (b < 0x80)
            {
                out.low = low;
                out.high = 0;
                return;
            }

            // byte 1
            b = src.readUnsignedByte();
            low |= (b & 0x7F) << 7;
            if (b < 0x80)
            {
                out.low = low;
                out.high = 0;
                return;
            }

            // byte 2
            b = src.readUnsignedByte();
            low |= (b & 0x7F) << 14;
            if (b < 0x80)
            {
                out.low = low;
                out.high = 0;
                return;
            }

            // byte 3
            b = src.readUnsignedByte();
            low |= (b & 0x7F) << 21;
            if (b < 0x80)
            {
                out.low = low;
                out.high = 0;
                return;
            }

            // byte 4
            b = src.readUnsignedByte();
            low |= (b & 0x7F) << 28;
            if (b < 0x80)
            {
                out.low = low;
                out.high = (b & 0x70) >>> 4;
                return;
            }

            high = (b & 0x7F) >>> 4;

            // byte 5
            b = src.readUnsignedByte();
            high |= (b & 0x7F) << 3;
            if (b < 0x80)
            {
                out.low = low;
                out.high = high;
                return;
            }

            // byte 6
            b = src.readUnsignedByte();
            high |= (b & 0x7F) << 10;
            if (b < 0x80)
            {
                out.low = low;
                out.high = high;
                return;
            }

            // byte 7
            b = src.readUnsignedByte();
            high |= (b & 0x7F) << 17;
            if (b < 0x80)
            {
                out.low = low;
                out.high = high;
                return;
            }

            // byte 8
            b = src.readUnsignedByte();
            high |= (b & 0x7F) << 24;
            if (b < 0x80)
            {
                out.low = low;
                out.high = high;
                return;
            }

            // byte 9 (only 1 bit used)
            b = src.readUnsignedByte();
            if (b > 0x01)
                throw new IOError("Malformed varint64: exceeds 64 bits");

            high |= (b & 0x01) << 31;

            out.low = low;
            out.high = high;
        }

        /**
         * Reads packed Varint64s values into a vector.
         * @param src Source ByteArray.
         * @param out Destination object to populate.
         */
        public static function readVarint64sVector(src:ByteArray, out:Int64Vector):void
        {
            const length:uint = readVarint32(src);
            const end:uint = src.position + length;
            const tmp:Int64 = TMP_INT64;

            while (src.position < end)
            {
                readVarint64s(src, tmp);
                out.push(tmp.low, tmp.high);
            }

            if (src.position != end)
                throw new IOError("Varint64 vector length mismatch");
        }

        /**
         * Read a zigzag-encoded signed 32-bit integer
         * @param src The source ByteArray to read from
         * @return The decoded value.
         */
        [Inline]
        public static function readSint32(src:ByteArray):int
        {
            const value:uint = readVarint32(src);
            return int((value >>> 1) ^ (-(value & 1)));
        }

        /**
         * Reads packed Sint32 values into a vector.
         * @param src Source ByteArray.
         * @param out Destination object to populate.
         */
        public static function readSint32Vector(src:ByteArray, out:Vector.<int>):void
        {
            const length:uint = readVarint32(src);
            const end:uint = src.position + length;

            while (src.position < end)
            {
                const v:uint = readVarint32(src);
                out.push(int((v >>> 1) ^ (-(v & 1))));
            }

            if (src.position != end)
                throw new IOError("Sint32 vector length mismatch");
        }

        /**
         * Read a zigzag-encoded signed 64-bit integer
         * @param src The source ByteArray to read from
         * @param out The Int64 object to write into
         */
        [Inline]
        public static function readSint64(src:ByteArray, out:Int64):void
        {
            readVarint64s(src, out);

            var low:uint = out.low;
            var high:int = out.high;
            const sign:uint = low & 1;

            // logical shift right across the 64-bit value
            low = (low >>> 1) | (high << 31);
            high = uint(high) >>> 1;

            const mask:int = -sign;
            low ^= mask;
            high ^= mask;

            out.low = low;
            out.high = high;
        }

        /**
         * Reads packed Sint64 values into a vector.
         * @param src Source ByteArray.
         * @param out Destination object to populate.
         */
        public static function readSint64Vector(src:ByteArray, out:Int64Vector):void
        {
            const length:uint = readVarint32(src);
            const end:uint = src.position + length;

            const lowVec:Vector.<uint> = out.low;
            const highVec:Vector.<int> = out.high;
            const tmp:Int64 = TMP_INT64;

            while (src.position < end)
            {
                readVarint64s(src, tmp);

                var low:uint = tmp.low;
                var high:int = tmp.high;
                const sign:uint = low & 1;

                low = (low >>> 1) | (high << 31);
                high = uint(high) >>> 1;

                const mask:int = -sign;
                low ^= mask;
                high ^= mask;

                lowVec.push(low);
                highVec.push(high);
            }

            if (src.position != end)
                throw new IOError("Sint64 vector length mismatch");
        }

        /**
         * Read a 32-bit fixed-size little-endian unsigned integer
         * Codegen inlines this method for better performance
         * @param src The source ByteArray to read from
         * @return The decoded value.
         */
        [Inline]
        public static function readFixed32(src:ByteArray):uint
        {
            return src.readUnsignedInt(); // ActionScript readUnsignedInt is little-endian
        }

        /**
         * Reads packed Fixed32 values into a vector.
         * @param src Source ByteArray.
         * @param out Destination object to populate.
         */
        public static function readFixed32Vector(src:ByteArray, out:Vector.<uint>):void
        {
            const length:uint = readVarint32(src);
            const n:uint = length >>> 2;

            out.length = n;

            var i:uint = 0;
            for (; i + 3 < n; i += 4)
            {
                out[i] = src.readUnsignedInt();
                out[i + 1] = src.readUnsignedInt();
                out[i + 2] = src.readUnsignedInt();
                out[i + 3] = src.readUnsignedInt();
            }

            for (; i < n; i++)
                out[i] = src.readUnsignedInt();

            if ((n << 2) != length)
                throw new IOError("Fixed32 vector length mismatch");
        }

        /**
         * Read a 64-bit fixed-size little-endian number
         * Codegen inlines this method for better performance
         * @param src The source ByteArray to read from
         * @param out Destination value.
         */
        [Inline]
        public static function readFixed64(src:ByteArray, out:UInt64):void
        {
            out.low = src.readUnsignedInt();
            out.high = src.readUnsignedInt();
        }

        /**
         * Reads packed Fixed64 values into a vector.
         * @param src Source ByteArray.
         * @param out Destination object to populate.
         */
        public static function readFixed64Vector(src:ByteArray, out:UInt64Vector):void
        {
            const length:uint = readVarint32(src);
            const n:uint = length >>> 3;

            const lowVec:Vector.<uint> = out.low;
            const highVec:Vector.<uint> = out.high;

            lowVec.length = n;
            highVec.length = n;

            var i:uint = 0;
            for (; i + 3 < n; i += 4)
            {
                lowVec[i] = src.readUnsignedInt();
                highVec[i] = src.readUnsignedInt();

                lowVec[i + 1] = src.readUnsignedInt();
                highVec[i + 1] = src.readUnsignedInt();

                lowVec[i + 2] = src.readUnsignedInt();
                highVec[i + 2] = src.readUnsignedInt();

                lowVec[i + 3] = src.readUnsignedInt();
                highVec[i + 3] = src.readUnsignedInt();
            }

            for (; i < n; i++)
            {
                lowVec[i] = src.readUnsignedInt();
                highVec[i] = src.readUnsignedInt();
            }

            if ((n << 3) != length)
                throw new IOError("Fixed64 vector length mismatch");
        }

        /**
         * Read a 32-bit fixed-size little-endian signed integer
         * Codegen inlines this method for better performance
         * @param src The source ByteArray to read from
         * @return The decoded value.
         */
        [Inline]
        public static function readSfixed32(src:ByteArray):int
        {
            return src.readInt();
        }

        /**
         * Reads packed Fixed32s values into a vector.
         * @param src Source ByteArray.
         * @param out Destination object to populate.
         */
        public static function readFixed32sVector(src:ByteArray, out:Vector.<int>):void
        {
            const length:uint = readVarint32(src);
            const n:uint = length >>> 2;

            out.length = n;

            var i:uint = 0;
            for (; i + 3 < n; i += 4)
            {
                out[i] = src.readInt();
                out[i + 1] = src.readInt();
                out[i + 2] = src.readInt();
                out[i + 3] = src.readInt();
            }

            for (; i < n; i++)
                out[i] = src.readInt();

            if ((n << 2) != length)
                throw new IOError("Fixed32 vector length mismatch");
        }

        /**
         * Read a 64-bit fixed-size little-endian signed number
         * Codegen inlines this method for better performance
         * @param src The source ByteArray to read from
         * @param out Destination value.
         */
        [Inline]
        public static function readSfixed64(src:ByteArray, out:Int64):void
        {
            out.low = src.readUnsignedInt();
            out.high = src.readInt();
        }

        /**
         * Reads packed Fixed64s values into a vector.
         * @param src Source ByteArray.
         * @param out Destination object to populate.
         */
        public static function readFixed64sVector(src:ByteArray, out:Int64Vector):void
        {
            const length:uint = readVarint32(src);
            const n:uint = length >>> 3;

            const lowVec:Vector.<uint> = out.low;
            const highVec:Vector.<int> = out.high;

            lowVec.length = n;
            highVec.length = n;

            var i:uint = 0;
            for (; i + 3 < n; i += 4)
            {
                lowVec[i] = src.readUnsignedInt();
                highVec[i] = src.readInt();

                lowVec[i + 1] = src.readUnsignedInt();
                highVec[i + 1] = src.readInt();

                lowVec[i + 2] = src.readUnsignedInt();
                highVec[i + 2] = src.readInt();

                lowVec[i + 3] = src.readUnsignedInt();
                highVec[i + 3] = src.readInt();
            }

            for (; i < n; i++)
            {
                lowVec[i] = src.readUnsignedInt();
                highVec[i] = src.readInt();
            }

            if ((n << 3) != length)
                throw new IOError("Fixed64 vector length mismatch");
        }

        /**
         * Read a 32-bit IEEE 754 float
         * ActionScript uses little-endian IEEE 754 format
         * Codegen inlines this method for better performance
         * @param src The source ByteArray to read from
         * @return The decoded value.
         */
        [Inline]
        public static function readFloat(src:ByteArray):Number
        {
            return src.readFloat(); // Little-endian IEEE 754 single precision
        }

        /**
         * Reads packed Float values into a vector.
         * @param src Source ByteArray.
         * @param out Destination object to populate.
         */
        public static function readFloatVector(src:ByteArray, out:Vector.<Number>):void
        {
            const length:uint = readVarint32(src);
            const n:uint = length >>> 2;
            out.length = n;

            var i:uint = 0;
            for (; i + 3 < n; i += 4)
            {
                out[i] = src.readFloat();
                out[i + 1] = src.readFloat();
                out[i + 2] = src.readFloat();
                out[i + 3] = src.readFloat();
            }

            for (; i < n; i++)
                out[i] = src.readFloat();

            if ((n << 2) != length)
                throw new IOError("Float vector length mismatch");
        }

        /**
         * Read a 64-bit IEEE 754 double
         * ActionScript uses little-endian IEEE 754 format
         * Codegen inlines this method for better performance
         * @param src The source ByteArray to read from
         * @return The decoded value.
         */
        [Inline]
        public static function readDouble(src:ByteArray):Number
        {
            return src.readDouble(); // Little-endian IEEE 754 double precision
        }

        /**
         * Reads packed Double values into a vector.
         * @param src Source ByteArray.
         * @param out Destination object to populate.
         */
        public static function readDoubleVector(src:ByteArray, out:Vector.<Number>):void
        {
            const length:uint = readVarint32(src);
            const n:uint = length >>> 3;

            out.length = n;

            var i:uint = 0;
            for (; i + 3 < n; i += 4)
            {
                out[i] = src.readDouble();
                out[i + 1] = src.readDouble();
                out[i + 2] = src.readDouble();
                out[i + 3] = src.readDouble();
            }

            for (; i < n; i++)
                out[i] = src.readDouble();

            if ((n << 3) != length)
                throw new IOError("Double vector length mismatch");
        }

        /**
         * Read a boolean value (varint 0 or 1)
         * Codegen inlines this method for better performance
         * @param src The source ByteArray to read from
         * @return The decoded value.
         */
        [Inline]
        public static function readBool(src:ByteArray):Boolean
        {
            return readVarint32(src) !== 0;
        }

        /**
         * Reads packed Bool values into a vector.
         * @param src Source ByteArray.
         * @param out Destination object to populate.
         */
        public static function readBoolVector(src:ByteArray, out:Vector.<Boolean>):void
        {
            const length:uint = readVarint32(src);
            const end:uint = src.position + length;

            while (src.position < end)
                out.push(readVarint32(src) !== 0);

            if (src.position != end)
                throw new IOError("Bool vector length mismatch");
        }

        /**
         * Read a length-delimited UTF-8 string
         * Codegen inlines this method for better performance
         * @param src The source ByteArray to read from
         * @return The decoded string.
         */
        [Inline]
        public static function readString(src:ByteArray):String
        {
            return src.readUTFBytes(readVarint32(src));
        }

        /**
         * Read length-delimited raw bytes
         * Codegen inlines this method for better performance
         * @param src The source ByteArray to read from
         * @param dest The destination ByteArray to write the read bytes to
         */
        [Inline]
        public static function readBytesInto(src:ByteArray, dest:ByteArray):void
        {
            const length:uint = readVarint32(src);
            dest.length = 0;
            if (length)
                src.readBytes(dest, 0, length);
        }

        /**
         * Skip a field based on its wire type
         * @param src The source ByteArray to skip data from
         * @param wireType The protobuf wire type (0=VARINT, 1=FIXED64, 2=LENGTH_DELIMITED, 5=FIXED32)
         */
        public static function skipField(src:ByteArray, wireType:uint):void
        {
            switch (wireType)
            {
                case 0: // VARINT
                {
                    skipVarint(src);
                    return;
                }
                case 1: // FIXED64
                {
                    src.position += 8;
                    return;
                }
                case 2: // LENGTH_DELIMITED
                {
                    const length:uint = readVarint32(src);
                    src.position += length;
                    return;
                }
                case 5: // FIXED32
                {
                    src.position += 4;
                    return;
                }
                default:
                {
                    throw new IOError("Unknown wire type");
                }
            }
        }

        /**
         * Skips a varint value without assuming its width.
         * @param src The source ByteArray to skip data from.
         */
        [Inline]
        public static function skipVarint(src:ByteArray):void
        {
            for (var i:uint = 0; i < 10; i++)
            {
                if (src.readUnsignedByte() < 0x80)
                    return;
            }

            throw new IOError("Malformed varint: exceeds 64 bits");
        }
    }
}
