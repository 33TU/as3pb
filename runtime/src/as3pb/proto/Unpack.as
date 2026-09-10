package as3pb.proto
{
    import avm2.intrinsics.memory.*;
    import flash.errors.EOFError;
    import flash.errors.IOError;
    import flash.system.ApplicationDomain;
    import flash.utils.ByteArray;

    import as3pb.types.Int64;
    import as3pb.types.UInt64;
    import as3pb.types.UInt64Vector;
    import as3pb.types.Int64Vector;

    /**
     * Deserialization utilities for Protocol Buffers in ActionScript 3 using domain memory.
     * Intrinsic reads use little-endian byte order regardless of the input endian setting.
     */
    public final class Unpack
    {
        private static const DOMAIN:ApplicationDomain = ApplicationDomain.currentDomain;

        /** Bind caller-owned domain memory. Length is logical; capacity must include ten spare bytes. */
        [Inline]
        public static function begin(context:UnpackContext, input:ByteArray, length:uint):void
        {
            if (!input || context.bytes)
                throw new ArgumentError("Input must be non-null and context must be inactive");
            const end:Number = Number(input.position) + length;
            if (end > input.length)
                throw new Error("Invalid protobuf message length");
            // AIR may combine the bounds checks in unrolled intrinsic readers.
            // Spare capacity allows speculative reads; readers still enforce the logical limit.
            if (end + 10 > input.length)
                throw new RangeError("Domain memory input needs ten spare bytes after the message limit");

            const previous:ByteArray = DOMAIN.domainMemory;
            DOMAIN.domainMemory = input;
            context.previous = previous;
            context.bytes = input;
            context.position = input.position;
            context.limit = uint(end);
        }

        /** Publish the consumed position and restore the previous binding without resizing or copying. */
        [Inline]
        public static function end(context:UnpackContext):void
        {
            if (!context.bytes || DOMAIN.domainMemory !== context.bytes)
                throw new Error("Memory contexts must end in reverse binding order");
            DOMAIN.domainMemory = context.previous;
            context.bytes.position = context.position;
            context.previous = null;
            context.bytes = null;
        }

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
         * @param src The active decode context
         * @return The decoded value.
         */
        [Inline]
        public static function readVarint32(src:UnpackContext):uint
        {
            var position:uint = src.position;
            var result:uint = 0;
            var malformed:Boolean = false;

            do
            {
                var b:uint = li8(position++);
                result |= (b & 0x7f) << 0;
                if (b < 0x80)
                    break;

                b = li8(position++);
                result |= (b & 0x7f) << 7;
                if (b < 0x80)
                    break;

                b = li8(position++);
                result |= (b & 0x7f) << 14;
                if (b < 0x80)
                    break;

                b = li8(position++);
                result |= (b & 0x7f) << 21;
                if (b < 0x80)
                    break;

                b = li8(position++);
                result |= (b & 0x7f) << 28;
                if (b < 0x80)
                    break;

                // Bytes 6–10 carry bits beyond uint; consume them while validating the encoding.
                malformed = true;
                for (var i:uint = 0; i < 5; i++)
                {
                    b = li8(position++);
                    if (i == 4 && b > 1)
                        break;
                    if (b < 0x80)
                    {
                        malformed = false;
                        break;
                    }
                }
            }
            while (false);

            if (position > src.limit)
            {
                src.position = src.limit;
                throw new EOFError("Truncated protobuf input");
            }

            src.position = position;
            if (malformed)
                throw new IOError("Malformed varint32: exceeds 64 bits");

            return result;
        }

        /**
         * Read a field tag as a strict 32-bit varint. Unlike value varints,
         * a tag whose encoding exceeds 32 bits or five bytes is malformed.
         * @param src The active decode context
         * @return The decoded tag.
         */
        [Inline]
        public static function readTag(src:UnpackContext):uint
        {
            var position:uint = src.position;
            var result:uint = 0;
            var malformed:Boolean = false;

            do
            {
                var b:uint = li8(position++);
                result |= (b & 0x7f) << 0;
                if (b < 0x80)
                    break;

                b = li8(position++);
                result |= (b & 0x7f) << 7;
                if (b < 0x80)
                    break;

                b = li8(position++);
                result |= (b & 0x7f) << 14;
                if (b < 0x80)
                    break;

                b = li8(position++);
                result |= (b & 0x7f) << 21;
                if (b < 0x80)
                    break;

                b = li8(position++);
                result |= (b & 0x7f) << 28;
                malformed = b > 0x0f;
            }
            while (false);

            if (position > src.limit)
            {
                src.position = src.limit;
                throw new EOFError("Truncated protobuf input");
            }

            src.position = position;
            if (malformed)
                throw new IOError("Malformed tag: exceeds 32 bits");

            return result;
        }

        /**
         * Reads packed unsigned 32-bit varint values into a vector.
         * @param src Active decode context.
         * @param out Destination object to populate.
         */
        public static function readVarint32Vector(src:UnpackContext, out:Vector.<uint>):void
        {
            const length:uint = readVarint32(src);
            const end:Number = Number(src.position) + length;

            if (end > src.limit)
                throw new EOFError("Truncated protobuf input");

            while (src.position < end)
                out.push(readVarint32(src));

            if (src.position != end)
                throw new IOError("Varint32 vector length mismatch");
        }

        /**
         * Reads packed signed 32-bit varint values into a vector.
         * @param src Active decode context.
         * @param out Destination object to populate.
         */
        public static function readVarint32sVector(src:UnpackContext, out:Vector.<int>):void
        {
            const length:uint = readVarint32(src);
            const end:Number = Number(src.position) + length;

            if (end > src.limit)
                throw new EOFError("Truncated protobuf input");

            while (src.position < end)
                out.push(readVarint32(src));

            if (src.position != end)
                throw new IOError("Varint32 vector length mismatch");
        }

        /**
         * Read a varint-encoded signed 32-bit integer.
         * Canonical protobuf negative int32 values can use 10 bytes.
         * @param src The active decode context
         * @return The decoded value.
         */
        [Inline]
        public static function readInt32(src:UnpackContext):int
        {
            var position:uint = src.position;
            var result:uint = 0;
            var malformed:Boolean = false;

            do
            {
                var b:uint = li8(position++);
                result |= (b & 0x7f) << 0;
                if (b < 0x80)
                    break;

                b = li8(position++);
                result |= (b & 0x7f) << 7;
                if (b < 0x80)
                    break;

                b = li8(position++);
                result |= (b & 0x7f) << 14;
                if (b < 0x80)
                    break;

                b = li8(position++);
                result |= (b & 0x7f) << 21;
                if (b < 0x80)
                    break;

                b = li8(position++);
                result |= (b & 0x7f) << 28;
                if (b < 0x80)
                    break;

                // Bytes 6–10 carry bits beyond uint; consume them while validating the encoding.
                malformed = true;
                for (var i:uint = 0; i < 5; i++)
                {
                    b = li8(position++);
                    if (i == 4 && b > 1)
                        break;
                    if (b < 0x80)
                    {
                        malformed = false;
                        break;
                    }
                }
            }
            while (false);

            if (position > src.limit)
            {
                src.position = src.limit;
                throw new EOFError("Truncated protobuf input");
            }

            src.position = position;
            if (malformed)
                throw new IOError("Malformed int32: exceeds 64 bits");

            return int(result);
        }

        /**
         * Reads packed signed 32-bit int32 values into a vector.
         * @param src Active decode context.
         * @param out Destination object to populate.
         */
        public static function readInt32Vector(src:UnpackContext, out:Vector.<int>):void
        {
            const length:uint = readVarint32(src);
            const end:Number = Number(src.position) + length;

            if (end > src.limit)
                throw new EOFError("Truncated protobuf input");

            while (src.position < end)
                out.push(readInt32(src));

            if (src.position != end)
                throw new IOError("Int32 vector length mismatch");
        }

        /**
         * Read a varint-encoded 64-bit unsigned integer
         * @param src The active decode context
         * @param out The UInt64 object to write into
         */
        [Inline]
        public static function readVarint64(src:UnpackContext, out:UInt64):void
        {
            var position:uint = src.position;
            var low:uint = 0;
            var high:uint = 0;
            var malformed:Boolean = false;

            do
            {
                var b:uint = li8(position++);
                low |= (b & 0x7f) << 0;
                if (b < 0x80)
                    break;

                b = li8(position++);
                low |= (b & 0x7f) << 7;
                if (b < 0x80)
                    break;

                b = li8(position++);
                low |= (b & 0x7f) << 14;
                if (b < 0x80)
                    break;

                b = li8(position++);
                low |= (b & 0x7f) << 21;
                if (b < 0x80)
                    break;

                b = li8(position++);
                low |= (b & 0x7f) << 28;
                high = (b & 0x7f) >>> 4;
                if (b < 0x80)
                    break;

                b = li8(position++);
                high |= (b & 0x7f) << 3;
                if (b < 0x80)
                    break;

                b = li8(position++);
                high |= (b & 0x7f) << 10;
                if (b < 0x80)
                    break;

                b = li8(position++);
                high |= (b & 0x7f) << 17;
                if (b < 0x80)
                    break;

                b = li8(position++);
                high |= (b & 0x7f) << 24;
                if (b < 0x80)
                    break;

                b = li8(position++);
                high |= (b & 1) << 31;
                malformed = b > 1;
            }
            while (false);

            if (position > src.limit)
            {
                src.position = src.limit;
                throw new EOFError("Truncated protobuf input");
            }

            src.position = position;
            if (malformed)
                throw new IOError("Malformed varint64: exceeds 64 bits");

            out.low = low;
            out.high = high;
        }

        /**
         * Reads packed Varint64 values into a vector.
         * @param src Active decode context.
         * @param out Destination object to populate.
         */
        public static function readVarint64Vector(src:UnpackContext, out:UInt64Vector):void
        {
            const length:uint = readVarint32(src);
            const end:Number = Number(src.position) + length;

            if (end > src.limit)
                throw new EOFError("Truncated protobuf input");

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
         * @param src The active decode context
         * @param out The Int64 object to write into
         */
        [Inline]
        public static function readVarint64s(src:UnpackContext, out:Int64):void
        {
            var position:uint = src.position;
            var low:uint = 0;
            var high:uint = 0;
            var malformed:Boolean = false;

            do
            {
                var b:uint = li8(position++);
                low |= (b & 0x7f) << 0;
                if (b < 0x80)
                    break;

                b = li8(position++);
                low |= (b & 0x7f) << 7;
                if (b < 0x80)
                    break;

                b = li8(position++);
                low |= (b & 0x7f) << 14;
                if (b < 0x80)
                    break;

                b = li8(position++);
                low |= (b & 0x7f) << 21;
                if (b < 0x80)
                    break;

                b = li8(position++);
                low |= (b & 0x7f) << 28;
                high = (b & 0x7f) >>> 4;
                if (b < 0x80)
                    break;

                b = li8(position++);
                high |= (b & 0x7f) << 3;
                if (b < 0x80)
                    break;

                b = li8(position++);
                high |= (b & 0x7f) << 10;
                if (b < 0x80)
                    break;

                b = li8(position++);
                high |= (b & 0x7f) << 17;
                if (b < 0x80)
                    break;

                b = li8(position++);
                high |= (b & 0x7f) << 24;
                if (b < 0x80)
                    break;

                b = li8(position++);
                high |= (b & 1) << 31;
                malformed = b > 1;
            }
            while (false);

            if (position > src.limit)
            {
                src.position = src.limit;
                throw new EOFError("Truncated protobuf input");
            }

            src.position = position;
            if (malformed)
                throw new IOError("Malformed varint64: exceeds 64 bits");

            out.low = low;
            out.high = high;
        }

        /**
         * Reads packed Varint64s values into a vector.
         * @param src Active decode context.
         * @param out Destination object to populate.
         */
        public static function readVarint64sVector(src:UnpackContext, out:Int64Vector):void
        {
            const length:uint = readVarint32(src);
            const end:Number = Number(src.position) + length;

            if (end > src.limit)
                throw new EOFError("Truncated protobuf input");

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
         * @param src The active decode context
         * @return The decoded value.
         */
        [Inline]
        public static function readSint32(src:UnpackContext):int
        {
            const value:uint = readVarint32(src);
            return int((value >>> 1) ^ (-(value & 1)));
        }

        /**
         * Reads packed Sint32 values into a vector.
         * @param src Active decode context.
         * @param out Destination object to populate.
         */
        public static function readSint32Vector(src:UnpackContext, out:Vector.<int>):void
        {
            const length:uint = readVarint32(src);
            const end:Number = Number(src.position) + length;

            if (end > src.limit)
                throw new EOFError("Truncated protobuf input");

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
         * @param src The active decode context
         * @param out The Int64 object to write into
         */
        [Inline]
        public static function readSint64(src:UnpackContext, out:Int64):void
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
         * @param src Active decode context.
         * @param out Destination object to populate.
         */
        public static function readSint64Vector(src:UnpackContext, out:Int64Vector):void
        {
            const length:uint = readVarint32(src);
            const end:Number = Number(src.position) + length;

            if (end > src.limit)
                throw new EOFError("Truncated protobuf input");

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
         * Generated decoders use this intrinsic reader
         * @param src The active decode context
         * @return The decoded value.
         */
        [Inline]
        public static function readFixed32(src:UnpackContext):uint
        {
            if (Number(src.position) + 4 > src.limit)
                throw new EOFError("Truncated protobuf input");
            const value:uint = uint(li32(src.position));
            src.position += 4;
            return value;
        }

        /**
         * Reads packed Fixed32 values into a vector.
         * @param src Active decode context.
         * @param out Destination object to populate.
         */
        public static function readFixed32Vector(src:UnpackContext, out:Vector.<uint>):void
        {
            const length:uint = readVarint32(src);
            const end:Number = Number(src.position) + length;

            if (end > src.limit)
                throw new EOFError("Truncated protobuf input");
            const n:uint = length >>> 2;

            const start:uint = out.length;
            out.length = start + n;

            const outEnd:uint = start + n;
            var i:uint = start;
            for (; i + 3 < outEnd; i += 4)
            {
                out[i] = uint(li32(src.position));
                src.position += 4;
                out[i + 1] = uint(li32(src.position));
                src.position += 4;
                out[i + 2] = uint(li32(src.position));
                src.position += 4;
                out[i + 3] = uint(li32(src.position));
                src.position += 4;
            }

            for (; i < outEnd; i++)
            {
                out[i] = uint(li32(src.position));
                src.position += 4;
            }

            if ((n << 2) != length)
                throw new IOError("Fixed32 vector length mismatch");
        }

        /**
         * Read a 64-bit fixed-size little-endian number
         * Generated decoders use this intrinsic reader
         * @param src The active decode context
         * @param out Destination value.
         */
        [Inline]
        public static function readFixed64(src:UnpackContext, out:UInt64):void
        {
            if (Number(src.position) + 8 > src.limit)
                throw new EOFError("Truncated protobuf input");
            out.low = uint(li32(src.position));
            out.high = uint(li32(src.position + 4));
            src.position += 8;
        }

        /**
         * Reads packed Fixed64 values into a vector.
         * @param src Active decode context.
         * @param out Destination object to populate.
         */
        public static function readFixed64Vector(src:UnpackContext, out:UInt64Vector):void
        {
            const length:uint = readVarint32(src);
            const end:Number = Number(src.position) + length;

            if (end > src.limit)
                throw new EOFError("Truncated protobuf input");
            const n:uint = length >>> 3;

            const lowVec:Vector.<uint> = out.low;
            const highVec:Vector.<uint> = out.high;

            const start:uint = lowVec.length;
            lowVec.length = start + n;
            highVec.length = start + n;

            const outEnd:uint = start + n;
            var position:uint = src.position;
            var i:uint = start;
            for (; i + 3 < outEnd; i += 4)
            {
                lowVec[i] = uint(li32(position));
                highVec[i] = uint(li32(position + 4));

                lowVec[i + 1] = uint(li32(position + 8));
                highVec[i + 1] = uint(li32(position + 12));

                lowVec[i + 2] = uint(li32(position + 16));
                highVec[i + 2] = uint(li32(position + 20));

                lowVec[i + 3] = uint(li32(position + 24));
                highVec[i + 3] = uint(li32(position + 28));
                position += 32;
            }

            for (; i < outEnd; i++)
            {
                lowVec[i] = uint(li32(position));
                highVec[i] = uint(li32(position + 4));
                position += 8;
            }

            src.position = position;
            if ((n << 3) != length)
                throw new IOError("Fixed64 vector length mismatch");
        }

        /**
         * Read a 32-bit fixed-size little-endian signed integer
         * Generated decoders use this intrinsic reader
         * @param src The active decode context
         * @return The decoded value.
         */
        [Inline]
        public static function readSfixed32(src:UnpackContext):int
        {
            if (src.position + 4 > src.limit)
                throw new EOFError("Truncated protobuf input");
            const value:int = li32(src.position);
            src.position += 4;
            return value;
        }

        /**
         * Reads packed Fixed32s values into a vector.
         * @param src Active decode context.
         * @param out Destination object to populate.
         */
        public static function readFixed32sVector(src:UnpackContext, out:Vector.<int>):void
        {
            const length:uint = readVarint32(src);
            const end:Number = Number(src.position) + length;

            if (end > src.limit)
                throw new EOFError("Truncated protobuf input");
            const n:uint = length >>> 2;

            const start:uint = out.length;
            out.length = start + n;

            const outEnd:uint = start + n;
            var i:uint = start;
            for (; i + 3 < outEnd; i += 4)
            {
                out[i] = readSfixed32(src);
                out[i + 1] = readSfixed32(src);
                out[i + 2] = readSfixed32(src);
                out[i + 3] = readSfixed32(src);
            }

            for (; i < outEnd; i++)
                out[i] = readSfixed32(src);

            if ((n << 2) != length)
                throw new IOError("Fixed32 vector length mismatch");
        }

        /**
         * Read a 64-bit fixed-size little-endian signed number
         * Generated decoders use this intrinsic reader
         * @param src The active decode context
         * @param out Destination value.
         */
        [Inline]
        public static function readSfixed64(src:UnpackContext, out:Int64):void
        {
            if (Number(src.position) + 8 > src.limit)
                throw new EOFError("Truncated protobuf input");
            out.low = uint(li32(src.position));
            out.high = li32(src.position + 4);
            src.position += 8;
        }

        /**
         * Reads packed Fixed64s values into a vector.
         * @param src Active decode context.
         * @param out Destination object to populate.
         */
        public static function readFixed64sVector(src:UnpackContext, out:Int64Vector):void
        {
            const length:uint = readVarint32(src);
            const end:Number = Number(src.position) + length;

            if (end > src.limit)
                throw new EOFError("Truncated protobuf input");

            const n:uint = length >>> 3;
            const lowVec:Vector.<uint> = out.low;
            const highVec:Vector.<int> = out.high;

            const start:uint = lowVec.length;
            lowVec.length = start + n;
            highVec.length = start + n;

            const outEnd:uint = start + n;
            var position:uint = src.position;
            var i:uint = start;
            for (; i + 3 < outEnd; i += 4)
            {
                lowVec[i] = uint(li32(position));
                highVec[i] = int(li32(position + 4));

                lowVec[i + 1] = uint(li32(position + 8));
                highVec[i + 1] = int(li32(position + 12));

                lowVec[i + 2] = uint(li32(position + 16));
                highVec[i + 2] = int(li32(position + 20));

                lowVec[i + 3] = uint(li32(position + 24));
                highVec[i + 3] = int(li32(position + 28));
                position += 32;
            }

            for (; i < outEnd; i++)
            {
                lowVec[i] = uint(li32(position));
                highVec[i] = int(li32(position + 4));
                position += 8;
            }

            src.position = position;
            if ((n << 3) != length)
                throw new IOError("Fixed64 vector length mismatch");
        }

        /**
         * Read a 32-bit IEEE 754 float
         * ActionScript uses little-endian IEEE 754 format
         * Generated decoders use this intrinsic reader
         * @param src The active decode context
         * @return The decoded value.
         */
        [Inline]
        public static function readFloat(src:UnpackContext):Number
        {
            if (src.position + 4 > src.limit)
                throw new EOFError("Truncated protobuf input");

            const value:Number = lf32(src.position);
            src.position += 4;
            return value;
        }

        /**
         * Reads packed Float values into a vector.
         * @param src Active decode context.
         * @param out Destination object to populate.
         */
        public static function readFloatVector(src:UnpackContext, out:Vector.<Number>):void
        {
            const length:uint = readVarint32(src);
            const end:Number = Number(src.position) + length;

            if (end > src.limit)
                throw new EOFError("Truncated protobuf input");

            const n:uint = length >>> 2;
            const start:uint = out.length;
            out.length = start + n;

            const outEnd:uint = start + n;
            var i:uint = start;
            for (; i + 3 < outEnd; i += 4)
            {
                out[i] = readFloat(src);
                out[i + 1] = readFloat(src);
                out[i + 2] = readFloat(src);
                out[i + 3] = readFloat(src);
            }

            for (; i < outEnd; i++)
                out[i] = readFloat(src);

            if ((n << 2) != length)
                throw new IOError("Float vector length mismatch");
        }

        /**
         * Read a 64-bit IEEE 754 double
         * ActionScript uses little-endian IEEE 754 format
         * Generated decoders use this intrinsic reader
         * @param src The active decode context
         * @return The decoded value.
         */
        [Inline]
        public static function readDouble(src:UnpackContext):Number
        {
            if (src.position + 8 > src.limit)
                throw new EOFError("Truncated protobuf input");

            const value:Number = lf64(src.position);
            src.position += 8;
            return value;
        }

        /**
         * Reads packed Double values into a vector.
         * @param src Active decode context.
         * @param out Destination object to populate.
         */
        public static function readDoubleVector(src:UnpackContext, out:Vector.<Number>):void
        {
            const length:uint = readVarint32(src);
            const end:Number = Number(src.position) + length;

            if (end > src.limit)
                throw new EOFError("Truncated protobuf input");

            const n:uint = length >>> 3;
            const start:uint = out.length;
            out.length = start + n;

            const outEnd:uint = start + n;
            var i:uint = start;
            for (; i + 3 < outEnd; i += 4)
            {
                out[i] = readDouble(src);
                out[i + 1] = readDouble(src);
                out[i + 2] = readDouble(src);
                out[i + 3] = readDouble(src);
            }

            for (; i < outEnd; i++)
                out[i] = readDouble(src);

            if ((n << 3) != length)
                throw new IOError("Double vector length mismatch");
        }

        /**
         * Read a boolean value (varint 0 or 1)
         * Generated decoders use this intrinsic reader
         * @param src The active decode context
         * @return The decoded value.
         */
        [Inline]
        public static function readBool(src:UnpackContext):Boolean
        {
            var position:uint = src.position;
            var result:uint = 0;
            var malformed:Boolean = false;

            do
            {
                var b:uint = li8(position++);
                result |= b & 0x7f;
                if (b < 0x80)
                    break;

                malformed = true;
                for (var i:uint = 1; i < 10; i++)
                {
                    b = li8(position++);
                    if (i == 9 && b > 1)
                        break;
                    result |= b & 0x7f;
                    if (b < 0x80)
                    {
                        malformed = false;
                        break;
                    }
                }
            }
            while (false);

            if (position > src.limit)
            {
                src.position = src.limit;
                throw new EOFError("Truncated protobuf input");
            }

            src.position = position;
            if (malformed)
                throw new IOError("Malformed varint: exceeds 64 bits");

            return result != 0;
        }

        /**
         * Reads packed Bool values into a vector.
         * @param src Active decode context.
         * @param out Destination object to populate.
         */
        public static function readBoolVector(src:UnpackContext, out:Vector.<Boolean>):void
        {
            const length:uint = readVarint32(src);
            const end:Number = Number(src.position) + length;

            if (end > src.limit)
                throw new EOFError("Truncated protobuf input");

            while (src.position < end)
                out.push(readBool(src));

            if (src.position != end)
                throw new IOError("Bool vector length mismatch");
        }

        /**
         * Read a length-delimited UTF-8 string
         * Generated decoders use this intrinsic reader
         * @param src The active decode context
         * @return The decoded string.
         */
        [Inline]
        public static function readString(src:UnpackContext):String
        {
            const length:uint = readVarint32(src);
            if (src.position > src.limit || length > src.limit - src.position)
                throw new EOFError("Truncated protobuf input");
            const bytes:ByteArray = src.bytes;
            bytes.position = src.position;
            const value:String = bytes.readUTFBytes(length);
            src.position += length;
            return value;
        }

        /**
         * Read length-delimited raw bytes
         * Generated decoders use this intrinsic reader
         * @param src The active decode context
         * @param dest The destination ByteArray to write the read bytes to
         */
        [Inline]
        public static function readBytesInto(src:UnpackContext, dest:ByteArray):void
        {
            const length:uint = readVarint32(src);
            dest.length = 0;

            if (length)
            {
                if (src.position > src.limit || length > src.limit - src.position)
                    throw new EOFError("Truncated protobuf input");
                src.bytes.position = src.position;
                src.bytes.readBytes(dest, 0, length);
                src.position += length;
            }
        }

        /**
         * Copies an unknown field into an unknown-fields buffer: the tag is
         * re-encoded canonically, the payload bytes verbatim. Appending such
         * buffers on serialization preserves unknown fields across a
         * deserialize/serialize round trip.
         * @param src The active context, positioned just after the tag
         * @param tag The already-decoded field tag
         * @param out The destination buffer accumulating unknown fields
         */
        public static function captureUnknownField(src:UnpackContext, tag:uint, out:ByteArray):void
        {
            Serialize.writeVarint32(out, tag);
            const start:uint = src.position;
            skipFieldTag(src, tag);
            out.writeBytes(src.bytes, start, src.position - start);
        }

        /**
         * Skip a field based on its full tag, including group fields whose
         * extent is only known from the field number in the tag
         * @param src The active decode context
         * @param tag The already-decoded field tag
         */
        [Inline]
        public static function skipFieldTag(src:UnpackContext, tag:uint):void
        {
            if ((tag & 7) == 3) // START_GROUP
            {
                skipGroup(src, tag >>> 3);
                return;
            }
            skipField(src, tag & 7);
        }

        /**
         * Skip a group field: consume nested fields until the matching
         * END_GROUP tag
         * @param src The active context, positioned just after the START_GROUP tag
         * @param fieldNumber The group's field number
         */
        [Inline]
        public static function skipGroup(src:UnpackContext, fieldNumber:uint):void
        {
            while (true)
            {
                const tag:uint = readTag(src);
                if (tag == 0)
                    throw new IOError("Invalid zero tag inside group");
                if ((tag & 7) == 4) // END_GROUP
                {
                    if ((tag >>> 3) != fieldNumber)
                        throw new IOError("Mismatched end-group tag");
                    return;
                }
                skipFieldTag(src, tag);
            }
        }

        /**
         * Skip a field based on its wire type
         * @param src The active decode context
         * @param wireType The protobuf wire type (0=VARINT, 1=FIXED64, 2=LENGTH_DELIMITED, 5=FIXED32)
         */
        [Inline]
        public static function skipField(src:UnpackContext, wireType:uint):void
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
                    if (src.position + 8 > src.limit)
                        throw new EOFError("Truncated protobuf input");
                    src.position += 8;
                    return;
                }
                case 2: // LENGTH_DELIMITED
                {
                    const length:uint = readVarint32(src);
                    if (length > (src.limit - src.position))
                        throw new IOError("Truncated length-delimited field");
                    src.position += length;
                    return;
                }
                case 5: // FIXED32
                {
                    if (src.position + 4 > src.limit)
                        throw new EOFError("Truncated protobuf input");
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
         * @param src The active decode context.
         */
        [Inline]
        public static function skipVarint(src:UnpackContext):void
        {
            var position:uint = src.position;
            var malformed:Boolean = false;

            do
            {
                var b:uint = li8(position++);
                if (b < 0x80)
                    break;

                malformed = true;
                for (var i:uint = 1; i < 10; i++)
                {
                    b = li8(position++);
                    if (b < 0x80)
                    {
                        malformed = false;
                        break;
                    }
                }
            }
            while (false);

            if (position > src.limit)
            {
                src.position = src.limit;
                throw new EOFError("Truncated protobuf input");
            }

            src.position = position;
            if (malformed)
                throw new IOError("Malformed varint: exceeds 64 bits");
        }
    }
}
