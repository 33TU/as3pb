package as3pb.proto
{
    import flash.utils.ByteArray;
    import flash.system.ApplicationDomain;
    import avm2.intrinsics.memory.*;

    import as3pb.types.UInt64Vector;
    import as3pb.types.Int64Vector;

    /**
     * Serialization utilities for Protocol Buffers in ActionScript 3 using AVM2 domain memory.
     * Intrinsic writes always use little-endian byte order.
     * Writers reserve their own capacity; packed vectors reserve once before looping.
     */
    public final class Pack
    {
        private static const DOMAIN:ApplicationDomain = ApplicationDomain.currentDomain;
        private static const SCRATCH:ByteArray = new ByteArray();

        /** Bind caller-owned domain memory at dst.position. Capacity must be at least MIN_DOMAIN_MEMORY_LENGTH. */
        [Inline]
        public static function begin(context:PackContext, dst:ByteArray):void
        {
            if (!dst || context.bytes)
                throw new ArgumentError("Destination must be non-null and context must be inactive");
            if (dst.length > 0x7fffffff)
                throw new RangeError("Domain memory output is too large");
            const previous:ByteArray = DOMAIN.domainMemory;
            DOMAIN.domainMemory = dst;
            context.previous = previous;
            context.bytes = dst;
            context.position = dst.position;
        }

        /** Publish the final position and restore the previous binding. No copying or truncation. Use in finally. */
        [Inline]
        public static function end(context:PackContext):void
        {
            if (!context.bytes || DOMAIN.domainMemory !== context.bytes)
                throw new Error("Memory contexts must end in reverse binding order");
            DOMAIN.domainMemory = context.previous;
            context.bytes.position = context.position;
            context.previous = null;
            context.bytes = null;
        }

        /** Reserve capacity before intrinsic writes. The context must already be bound. */
        [Inline]
        public static function ensure(context:PackContext, count:Number):void
        {
            const required:Number = context.position + count;
            if (required > context.bytes.length)
            {
                if (required > 0x7fffffff)
                    throw new RangeError("Domain memory output is too large");
                const bytes:ByteArray = context.bytes;
                bytes.length = uint(Math.min(0x7fffffff, Math.max(required, Number(bytes.length) * 2)));
            }
        }

        [Inline]
        public static function writeByte(dst:PackContext, value:int):void
        {
            ensure(dst, 1);
            si8(value, dst.position++);
        }

        [Inline]
        public static function writeShort(dst:PackContext, value:int):void
        {
            ensure(dst, 2);
            si16(value, dst.position);
            dst.position += 2;
        }

        /** Copy raw bytes without a length prefix. Zero length means copy no bytes. */
        public static function writeRawBytes(dst:PackContext, value:ByteArray, offset:uint = 0, length:Number = -1):void
        {
            if (length < 0)
                length = value.length - offset;
            if (offset > value.length || length > value.length - offset)
                throw new RangeError("Invalid byte range");
            ensure(dst, length);
            if (length)
            {
                dst.bytes.position = dst.position;
                dst.bytes.writeBytes(value, offset, uint(length));
                dst.position += uint(length);
            }
        }

        /** Reserve the maximum canonical length prefix before an embedded message or packed vector. */
        [Inline]
        public static function startMessage(dst:PackContext):uint
        {
            ensure(dst, 5);
            const start:uint = dst.position;
            dst.position += 5;
            return start;
        }

        /** Compact the payload and write its canonical varint length. Nested messages share the binding. */
        public static function endMessage(dst:PackContext, start:uint):void
        {
            const end:uint = dst.position;
            const length:uint = end - start - 5;
            const width:uint = length < 0x80 ? 1 : length < 0x4000 ? 2 : length < 0x200000 ? 3 : length < 0x10000000 ? 4 : 5;
            if (length && width != 5)
            {
                dst.bytes.position = start + width;
                dst.bytes.writeBytes(dst.bytes, start + 5, length);
            }
            dst.position = start;
            writeVarint32Unchecked(dst, length);
            dst.position = start + width + length;
        }

        /**
         * Write a varint-encoded 32-bit unsigned integer
         * @param dst The active encode context
         * @param value The 32-bit unsigned integer value to encode
         */
        [Inline]
        public static function writeVarint32(dst:PackContext, value:uint):void
        {
            ensure(dst, 5);
            // 1 byte
            if (value < 0x80)
            {
                si8(value, dst.position);
                dst.position++;
                return;
            }

            // 2 bytes
            if (value < 0x4000)
            {
                si16(((value >>> 7) << 8) | ((value & 0x7F) | 0x80), dst.position);
                dst.position += 2;
                return;
            }

            // 3 bytes
            if (value < 0x200000)
            {
                si16(
                        ((((value >>> 7) & 0x7F) | 0x80) << 8) |
                        ((value & 0x7F) | 0x80),
                        dst.position);
                dst.position += 2;
                si8(value >>> 14, dst.position);
                dst.position++;
                return;
            }

            // 4 bytes
            if (value < 0x10000000)
            {
                si32(
                        ((value >>> 21) << 24) |
                        ((((value >>> 14) & 0x7F) | 0x80) << 16) |
                        ((((value >>> 7) & 0x7F) | 0x80) << 8) |
                        ((value & 0x7F) | 0x80),
                        dst.position);
                dst.position += 4;
                return;
            }

            // 5 bytes
            si32(
                    ((((value >>> 21) & 0x7F) | 0x80) << 24) |
                    ((((value >>> 14) & 0x7F) | 0x80) << 16) |
                    ((((value >>> 7) & 0x7F) | 0x80) << 8) |
                    ((value & 0x7F) | 0x80),
                    dst.position);
            dst.position += 4;
            si8(value >>> 28, dst.position);
            dst.position++;
        }

        /**
         * Write a varint-encoded vector of 32-bit unsigned integers as a length-delimited field
         * @param dst The active encode context
         * @param vec The vector of 32-bit unsigned integers to encode as varints
         * @param n Parameter.
         */
        public static function writeVarint32Vector(dst:PackContext, vec:Vector.<uint>, n:uint):void
        {
            ensure(dst, Number(n) * 5 + 5);
            const start:uint = dst.position;
            dst.position += 5;
            for (var i:uint = 0; i < n; i++)
                writeVarint32Unchecked(dst, uint(vec[i]));
            endMessage(dst, start);
        }

        /**
         * Write a varint-encoded vector of 32-bit signed integers as a length-delimited field
         * @param dst The active encode context
         * @param vec The vector of 32-bit signed integers to encode as varints
         * @param n Parameter.
         */
        public static function writeVarint32sVector(dst:PackContext, vec:Vector.<int>, n:uint):void
        {
            ensure(dst, Number(n) * 5 + 5);
            const start:uint = dst.position;
            dst.position += 5;
            for (var i:uint = 0; i < n; i++)
                writeVarint32Unchecked(dst, uint(vec[i]));
            endMessage(dst, start);
        }

        /**
         * Write a varint-encoded unsigned 64-bit number
         * @param dst The active encode context
         * @param low The low 32 bits of the unsigned 64-bit number value to encode
         * @param high The high 32 bits of the unsigned 64-bit number value to encode
         */
        [Inline]
        public static function writeVarint64(dst:PackContext, low:uint, high:uint):void
        {
            ensure(dst, 10);
            if (high != 0)
            {
                // A nonzero high word guarantees at least five encoded bytes.
                si32(
                        (((low >>> 21) & 0x7F) << 24) |
                        (((low >>> 14) & 0x7F) << 16) |
                        (((low >>> 7) & 0x7F) << 8) |
                        (low & 0x7F) | 0x80808080, dst.position);
                dst.position += 4;
                low = (low >>> 28) | (high << 4);
                high >>>= 28;

                if (high != 0)
                {
                    si32(
                            (((low >>> 21) & 0x7F) << 24) |
                            (((low >>> 14) & 0x7F) << 16) |
                            (((low >>> 7) & 0x7F) << 8) |
                            (low & 0x7F) | 0x80808080, dst.position);
                    dst.position += 4;
                    const last:uint = (low >>> 28) | (high << 4);
                    if (last < 0x80)
                    {
                        si8(last, dst.position);
                        dst.position++;
                    }
                    else
                    {
                        si16(((last >>> 7) << 8) | (last & 0x7F) | 0x80, dst.position);
                        dst.position += 2;
                    }
                    return;
                }
            }

            // 1 byte
            if (low < 0x80)
            {
                si8(low, dst.position);
                dst.position++;
                return;
            }

            // 2 bytes
            if (low < 0x4000)
            {
                si16(((low >>> 7) << 8) | ((low & 0x7F) | 0x80), dst.position);
                dst.position += 2;
                return;
            }

            // 3 bytes
            if (low < 0x200000)
            {
                si16(
                        ((((low >>> 7) & 0x7F) | 0x80) << 8) |
                        ((low & 0x7F) | 0x80),
                        dst.position);
                dst.position += 2;
                si8(low >>> 14, dst.position);
                dst.position++;
                return;
            }

            // 4 bytes
            if (low < 0x10000000)
            {
                si32(
                        ((low >>> 21) << 24) |
                        ((((low >>> 14) & 0x7F) | 0x80) << 16) |
                        ((((low >>> 7) & 0x7F) | 0x80) << 8) |
                        ((low & 0x7F) | 0x80),
                        dst.position);
                dst.position += 4;
                return;
            }

            // 5 bytes
            si32(
                    ((((low >>> 21) & 0x7F) | 0x80) << 24) |
                    ((((low >>> 14) & 0x7F) | 0x80) << 16) |
                    ((((low >>> 7) & 0x7F) | 0x80) << 8) |
                    ((low & 0x7F) | 0x80),
                    dst.position);
            dst.position += 4;
            si8(low >>> 28, dst.position);
            dst.position++;
        }

        /**
         * Write a varint-encoded vector of unsigned 64-bit numbers as a length-delimited field
         * @param dst The active encode context
         * @param vec The vector of unsigned 64-bit numbers to encode as varints
         * @param n Parameter.
         */
        public static function writeVarint64Vector(dst:PackContext, vec:UInt64Vector, n:uint):void
        {
            ensure(dst, Number(n) * 10 + 5);
            const start:uint = dst.position;
            dst.position += 5;
            const low:Vector.<uint> = vec.low;
            const high:Vector.<uint> = vec.high;
            for (var i:uint = 0; i < n; i++)
                writeVarint64Unchecked(dst, low[i], uint(high[i]));
            endMessage(dst, start);
        }

        /**
         * Write a varint-encoded signed 64-bit number
         * @param dst The active encode context
         * @param low The low 32 bits of the signed 64-bit number value to encode
         * @param high The high 32 bits of the signed 64-bit number value to encode
         */
        [Inline]
        public static function writeVarint64s(dst:PackContext, low:uint, high:int):void
        {
            ensure(dst, 10);
            if (high != 0)
            {
                // A nonzero high word guarantees at least five encoded bytes.
                si32(
                        (((low >>> 21) & 0x7F) << 24) |
                        (((low >>> 14) & 0x7F) << 16) |
                        (((low >>> 7) & 0x7F) << 8) |
                        (low & 0x7F) | 0x80808080, dst.position);
                dst.position += 4;
                low = (low >>> 28) | (high << 4);
                high >>>= 28;

                if (high != 0)
                {
                    si32(
                            (((low >>> 21) & 0x7F) << 24) |
                            (((low >>> 14) & 0x7F) << 16) |
                            (((low >>> 7) & 0x7F) << 8) |
                            (low & 0x7F) | 0x80808080, dst.position);
                    dst.position += 4;
                    const last:uint = (low >>> 28) | (high << 4);
                    if (last < 0x80)
                    {
                        si8(last, dst.position);
                        dst.position++;
                    }
                    else
                    {
                        si16(((last >>> 7) << 8) | (last & 0x7F) | 0x80, dst.position);
                        dst.position += 2;
                    }
                    return;
                }
            }

            // 1 byte
            if (low < 0x80)
            {
                si8(low, dst.position);
                dst.position++;
                return;
            }

            // 2 bytes
            if (low < 0x4000)
            {
                si16(((low >>> 7) << 8) | ((low & 0x7F) | 0x80), dst.position);
                dst.position += 2;
                return;
            }

            // 3 bytes
            if (low < 0x200000)
            {
                si16(
                        ((((low >>> 7) & 0x7F) | 0x80) << 8) |
                        ((low & 0x7F) | 0x80),
                        dst.position);
                dst.position += 2;
                si8(low >>> 14, dst.position);
                dst.position++;
                return;
            }

            // 4 bytes
            if (low < 0x10000000)
            {
                si32(
                        ((low >>> 21) << 24) |
                        ((((low >>> 14) & 0x7F) | 0x80) << 16) |
                        ((((low >>> 7) & 0x7F) | 0x80) << 8) |
                        ((low & 0x7F) | 0x80),
                        dst.position);
                dst.position += 4;
                return;
            }

            // 5 bytes
            si32(
                    ((((low >>> 21) & 0x7F) | 0x80) << 24) |
                    ((((low >>> 14) & 0x7F) | 0x80) << 16) |
                    ((((low >>> 7) & 0x7F) | 0x80) << 8) |
                    ((low & 0x7F) | 0x80),
                    dst.position);
            dst.position += 4;
            si8(low >>> 28, dst.position);
            dst.position++;
        }

        /**
         * Write a varint-encoded vector of signed 64-bit numbers as a length-delimited field
         * @param dst The active encode context
         * @param vec The vector of signed 64-bit numbers to encode as varints
         * @param n Parameter.
         */
        public static function writeVarint64sVector(dst:PackContext, vec:Int64Vector, n:uint):void
        {
            ensure(dst, Number(n) * 10 + 5);
            const start:uint = dst.position;
            dst.position += 5;
            const low:Vector.<uint> = vec.low;
            const high:Vector.<int> = vec.high;
            for (var i:uint = 0; i < n; i++)
                writeVarint64Unchecked(dst, low[i], uint(high[i]));
            endMessage(dst, start);
        }

        /**
         * Write a varint-encoded signed 32-bit integer.
         * Negative values are sign-extended, matching protobuf int32 encoding.
         * @param dst The active encode context
         * @param value The signed 32-bit integer value to encode
         */
        [Inline]
        public static function writeInt32(dst:PackContext, value:int):void
        {
            ensure(dst, 10);
            if (value < 0)
            {
                // Negative int32 values always occupy ten sign-extended varint bytes.
                si32(
                        (((value >>> 21) & 0x7F) << 24) |
                        (((value >>> 14) & 0x7F) << 16) |
                        (((value >>> 7) & 0x7F) << 8) |
                        (value & 0x7F) | 0x80808080, dst.position);
                dst.position += 4;
                si32(0xFFFFFFF0 | (value >>> 28), dst.position);
                dst.position += 4;
                si16(0x01FF, dst.position);
                dst.position += 2;
                return;
            }

            // 1 byte
            if (value < 0x80)
            {
                si8(value, dst.position);
                dst.position++;
                return;
            }

            // 2 bytes
            if (value < 0x4000)
            {
                si16(((value >>> 7) << 8) | ((value & 0x7F) | 0x80), dst.position);
                dst.position += 2;
                return;
            }

            // 3 bytes
            if (value < 0x200000)
            {
                si16(
                        ((((value >>> 7) & 0x7F) | 0x80) << 8) |
                        ((value & 0x7F) | 0x80),
                        dst.position);
                dst.position += 2;
                si8(value >>> 14, dst.position);
                dst.position++;
                return;
            }

            // 4 bytes
            if (value < 0x10000000)
            {
                si32(
                        ((value >>> 21) << 24) |
                        ((((value >>> 14) & 0x7F) | 0x80) << 16) |
                        ((((value >>> 7) & 0x7F) | 0x80) << 8) |
                        ((value & 0x7F) | 0x80),
                        dst.position);
                dst.position += 4;
                return;
            }

            // 5 bytes
            si32(
                    ((((value >>> 21) & 0x7F) | 0x80) << 24) |
                    ((((value >>> 14) & 0x7F) | 0x80) << 16) |
                    ((((value >>> 7) & 0x7F) | 0x80) << 8) |
                    ((value & 0x7F) | 0x80),
                    dst.position);
            dst.position += 4;
            si8(value >>> 28, dst.position);
            dst.position++;
        }

        /**
         * Write a varint-encoded vector of signed 32-bit integers as a length-delimited field.
         * Negative values are sign-extended, matching protobuf int32 encoding.
         * @param dst The active encode context
         * @param vec The vector of 32-bit signed integers to encode as varints
         * @param n Parameter.
         */
        public static function writeInt32Vector(dst:PackContext, vec:Vector.<int>, n:uint):void
        {
            ensure(dst, Number(n) * 10 + 5);
            const start:uint = dst.position;
            dst.position += 5;
            for (var i:uint = 0; i < n; i++)
                writeVarint64Unchecked(dst, uint(vec[i]), vec[i] < 0 ? 0xffffffff : 0);
            endMessage(dst, start);
        }

        /**
         * Write a zigzag-encoded signed 32-bit integer
         * @param dst The active encode context
         * @param value The signed 32-bit integer value to encode with zigzag encoding
         */
        [Inline]
        public static function writeSint32(dst:PackContext, value:int):void
        {
            ensure(dst, 5);
            const encoded:uint = uint((value << 1) ^ (value >> 31));

            // 1 byte
            if (encoded < 0x80)
            {
                si8(encoded, dst.position);
                dst.position++;
                return;
            }

            // 2 bytes
            if (encoded < 0x4000)
            {
                si16(((encoded >>> 7) << 8) | ((encoded & 0x7F) | 0x80), dst.position);
                dst.position += 2;
                return;
            }

            // 3 bytes
            if (encoded < 0x200000)
            {
                si16(
                        ((((encoded >>> 7) & 0x7F) | 0x80) << 8) |
                        ((encoded & 0x7F) | 0x80),
                        dst.position);
                dst.position += 2;
                si8(encoded >>> 14, dst.position);
                dst.position++;
                return;
            }

            // 4 bytes
            if (encoded < 0x10000000)
            {
                si32(
                        ((encoded >>> 21) << 24) |
                        ((((encoded >>> 14) & 0x7F) | 0x80) << 16) |
                        ((((encoded >>> 7) & 0x7F) | 0x80) << 8) |
                        ((encoded & 0x7F) | 0x80),
                        dst.position);
                dst.position += 4;
                return;
            }

            // 5 bytes
            si32(
                    ((((encoded >>> 21) & 0x7F) | 0x80) << 24) |
                    ((((encoded >>> 14) & 0x7F) | 0x80) << 16) |
                    ((((encoded >>> 7) & 0x7F) | 0x80) << 8) |
                    ((encoded & 0x7F) | 0x80),
                    dst.position);
            dst.position += 4;
            si8(encoded >>> 28, dst.position);
            dst.position++;
        }

        /**
         * Write a zigzag-encoded varint vector of 32-bit signed integers as a length-delimited field
         * @param dst The active encode context
         * @param vec The vector of 32-bit signed integers to encode using zigzag + varint encoding
         * @param n Parameter.
         */
        public static function writeSint32Vector(dst:PackContext, vec:Vector.<int>, n:uint):void
        {
            ensure(dst, Number(n) * 5 + 5);
            const start:uint = dst.position;
            dst.position += 5;
            for (var i:uint = 0; i < n; i++)
                writeVarint32Unchecked(dst, uint((vec[i] << 1) ^ (vec[i] >> 31)));
            endMessage(dst, start);
        }

        /**
         * Write a zigzag-encoded signed 64-bit integer
         * @param dst The active encode context
         * @param value The signed 64-bit number value to encode with zigzag encoding
         * @param low Parameter.
         * @param high Parameter.
         */
        [Inline]
        public static function writeSint64(dst:PackContext, low:uint, high:int):void
        {
            ensure(dst, 10);
            const mask:uint = high >> 31;
            const carry:uint = low >>> 31;

            // zigzag encode
            low = (low << 1) ^ mask;
            high = ((high << 1) | carry) ^ mask;

            if (high != 0)
            {
                // A nonzero high word guarantees at least five encoded bytes.
                si32(
                        (((low >>> 21) & 0x7F) << 24) |
                        (((low >>> 14) & 0x7F) << 16) |
                        (((low >>> 7) & 0x7F) << 8) |
                        (low & 0x7F) | 0x80808080, dst.position);
                dst.position += 4;
                low = (low >>> 28) | (high << 4);
                high >>>= 28;

                if (high != 0)
                {
                    si32(
                            (((low >>> 21) & 0x7F) << 24) |
                            (((low >>> 14) & 0x7F) << 16) |
                            (((low >>> 7) & 0x7F) << 8) |
                            (low & 0x7F) | 0x80808080, dst.position);
                    dst.position += 4;
                    const last:uint = (low >>> 28) | (high << 4);
                    if (last < 0x80)
                    {
                        si8(last, dst.position);
                        dst.position++;
                    }
                    else
                    {
                        si16(((last >>> 7) << 8) | (last & 0x7F) | 0x80, dst.position);
                        dst.position += 2;
                    }
                    return;
                }
            }

            // 1 byte
            if (low < 0x80)
            {
                si8(low, dst.position);
                dst.position++;
                return;
            }

            // 2 bytes
            if (low < 0x4000)
            {
                si16(((low >>> 7) << 8) | ((low & 0x7F) | 0x80), dst.position);
                dst.position += 2;
                return;
            }

            // 3 bytes
            if (low < 0x200000)
            {
                si16(
                        ((((low >>> 7) & 0x7F) | 0x80) << 8) |
                        ((low & 0x7F) | 0x80),
                        dst.position);
                dst.position += 2;
                si8(low >>> 14, dst.position);
                dst.position++;
                return;
            }

            // 4 bytes
            if (low < 0x10000000)
            {
                si32(
                        ((low >>> 21) << 24) |
                        ((((low >>> 14) & 0x7F) | 0x80) << 16) |
                        ((((low >>> 7) & 0x7F) | 0x80) << 8) |
                        ((low & 0x7F) | 0x80),
                        dst.position);
                dst.position += 4;
                return;
            }

            // 5 bytes
            si32(
                    ((((low >>> 21) & 0x7F) | 0x80) << 24) |
                    ((((low >>> 14) & 0x7F) | 0x80) << 16) |
                    ((((low >>> 7) & 0x7F) | 0x80) << 8) |
                    ((low & 0x7F) | 0x80),
                    dst.position);
            dst.position += 4;
            si8(low >>> 28, dst.position);
            dst.position++;
        }

        /**
         * Write a zigzag-encoded varint vector of 64-bit signed integers as a length-delimited field
         * @param dst The active encode context
         * @param vec The vector of 64-bit signed integers to encode using zigzag + varint encoding
         * @param n Parameter.
         */
        public static function writeSint64Vector(dst:PackContext, vec:Int64Vector, n:uint):void
        {
            ensure(dst, Number(n) * 10 + 5);
            const start:uint = dst.position;
            dst.position += 5;
            const low:Vector.<uint> = vec.low;
            const high:Vector.<int> = vec.high;
            for (var i:uint = 0; i < n; i++)
                writeVarint64Unchecked(dst, uint((low[i] << 1) ^ (high[i] >> 31)),
                    uint(((high[i] << 1) | (low[i] >>> 31)) ^ (high[i] >> 31)));
            endMessage(dst, start);
        }

        /**
         * Write a 32-bit fixed-size little-endian unsigned integer
         * @param dst The active encode context
         * @param value The 32-bit unsigned integer value to write
         */
        [Inline]
        public static function writeFixed32(dst:PackContext, value:uint):void
        {
            ensure(dst, 4);
            si32(value, dst.position);
            dst.position += 4;
        }

        /**
         * Write a fixed-size vector of 32-bit unsigned integers as a length-delimited field
         * @param dst The active encode context
         * @param vec The vector of 32-bit unsigned integers to write
         * @param n Parameter.
         */
        public static function writeFixed32Vector(dst:PackContext, vec:Vector.<uint>, n:uint):void
        {
            ensure(dst, Number(n) * 4 + 5);
            const length:uint = n << 2;
            writeVarint32Unchecked(dst, length);

            // 4x unrolled loop
            var i:uint = 0;
            for (; i + 3 < n; i += 4)
            {
                si32(vec[i], dst.position);
                dst.position += 4;
                si32(vec[i + 1], dst.position);
                dst.position += 4;
                si32(vec[i + 2], dst.position);
                dst.position += 4;
                si32(vec[i + 3], dst.position);
                dst.position += 4;
            }

            // tail loop
            for (; i < n; i++)
            {
                si32(vec[i], dst.position);
                dst.position += 4;
            }
        }

        /**
         * Write a 32-bit fixed-size little-endian signed integer
         * Codegen inlines this method for better performance
         * @param dst The active encode context
         * @param value The 32-bit signed integer value to write
         */
        [Inline]
        public static function writeSfixed32(dst:PackContext, value:int):void
        {
            ensure(dst, 4);
            si32(value, dst.position);
            dst.position += 4;
        }

        /**
         * Write a fixed-size vector of 32-bit signed integers as a length-delimited field
         * @param dst The active encode context
         * @param vec The vector of 32-bit signed integers to write
         * @param n Parameter.
         */
        public static function writeSfixed32Vector(dst:PackContext, vec:Vector.<int>, n:uint):void
        {
            ensure(dst, Number(n) * 4 + 5);
            const length:uint = n << 2;
            writeVarint32Unchecked(dst, length);

            // 4x unrolled loop
            var i:uint = 0;
            for (; i + 3 < n; i += 4)
            {
                si32(vec[i], dst.position);
                dst.position += 4;
                si32(vec[i + 1], dst.position);
                dst.position += 4;
                si32(vec[i + 2], dst.position);
                dst.position += 4;
                si32(vec[i + 3], dst.position);
                dst.position += 4;
            }

            // tail loop
            for (; i < n; i++)
            {
                si32(vec[i], dst.position);
                dst.position += 4;
            }
        }

        /**
         * Write a 64-bit fixed-size little-endian number
         * Codegen inlines this method for better performance
         * @param dst The active encode context
         * @param value The 64-bit number value to write
         * @param low Parameter.
         * @param high Parameter.
         */
        [Inline]
        public static function writeFixed64(dst:PackContext, low:uint, high:uint):void
        {
            ensure(dst, 8);
            si32(low, dst.position);
            dst.position += 4;
            si32(high, dst.position);
            dst.position += 4;
        }

        /**
         * Write a fixed-size vector of 64-bit unsigned integers as a length-delimited field
         * @param dst The active encode context
         * @param vec The vector of 64-bit unsigned integers to write
         * @param n Parameter.
         */
        public static function writeFixed64Vector(dst:PackContext, vec:UInt64Vector, n:uint):void
        {
            ensure(dst, Number(n) * 8 + 5);
            const length:uint = n << 3;
            writeVarint32Unchecked(dst, length);

            const lowVec:Vector.<uint> = vec.low;
            const highVec:Vector.<uint> = vec.high;

            // 4x unrolled loop
            var i:uint = 0;
            for (; i + 3 < n; i += 4)
            {
                si32(lowVec[i], dst.position);
                dst.position += 4;
                si32(highVec[i], dst.position);
                dst.position += 4;

                si32(lowVec[i + 1], dst.position);
                dst.position += 4;
                si32(highVec[i + 1], dst.position);
                dst.position += 4;

                si32(lowVec[i + 2], dst.position);
                dst.position += 4;
                si32(highVec[i + 2], dst.position);
                dst.position += 4;

                si32(lowVec[i + 3], dst.position);
                dst.position += 4;
                si32(highVec[i + 3], dst.position);
                dst.position += 4;
            }

            // tail loop
            for (; i < n; i++)
            {
                si32(lowVec[i], dst.position);
                dst.position += 4;
                si32(highVec[i], dst.position);
                dst.position += 4;
            }
        }

        /**
         * Write a 64-bit fixed-size little-endian signed number
         * Codegen inlines this method for better performance
         * @param dst The active encode context
         * @param value The 64-bit signed number value to write
         * @param low Parameter.
         * @param high Parameter.
         */
        [Inline]
        public static function writeSfixed64(dst:PackContext, low:uint, high:int):void
        {
            ensure(dst, 8);
            si32(low, dst.position);
            dst.position += 4;
            si32(high, dst.position);
            dst.position += 4;
        }

        /**
         * Write a fixed-size vector of 64-bit signed integers as a length-delimited field
         * @param dst The active encode context
         * @param vec The vector of 64-bit signed integers to write
         * @param n Parameter.
         */
        public static function writeSfixed64Vector(dst:PackContext, vec:Int64Vector, n:uint):void
        {
            ensure(dst, Number(n) * 8 + 5);
            const length:uint = n << 3;
            writeVarint32Unchecked(dst, length);

            const lowVec:Vector.<uint> = vec.low;
            const highVec:Vector.<int> = vec.high;

            // 4x unrolled loop
            var i:uint = 0;
            for (; i + 3 < n; i += 4)
            {
                si32(lowVec[i], dst.position);
                dst.position += 4;
                si32(highVec[i], dst.position);
                dst.position += 4;

                si32(lowVec[i + 1], dst.position);
                dst.position += 4;
                si32(highVec[i + 1], dst.position);
                dst.position += 4;

                si32(lowVec[i + 2], dst.position);
                dst.position += 4;
                si32(highVec[i + 2], dst.position);
                dst.position += 4;

                si32(lowVec[i + 3], dst.position);
                dst.position += 4;
                si32(highVec[i + 3], dst.position);
                dst.position += 4;
            }

            // tail loop
            for (; i < n; i++)
            {
                si32(lowVec[i], dst.position);
                dst.position += 4;
                si32(highVec[i], dst.position);
                dst.position += 4;
            }
        }

        /**
         * Write a 32-bit IEEE 754 float
         * ActionScript uses little-endian IEEE 754 format
         * Codegen inlines this method for better performance
         * @param dst The active encode context
         * @param value The float value to write
         */
        [Inline]
        public static function writeFloat(dst:PackContext, value:Number):void
        {
            ensure(dst, 4);
            sf32(value, dst.position);
            dst.position += 4; // Little-endian IEEE 754 single precision
        }

        /**
         * Write a vector of 32-bit IEEE 754 floats as a length-delimited field
         * @param dst The active encode context
         * @param vec The vector of float values to write
         * @param n Parameter.
         */
        public static function writeFloatVector(dst:PackContext, vec:Vector.<Number>, n:uint):void
        {
            ensure(dst, Number(n) * 4 + 5);
            const length:uint = n << 2;
            writeVarint32Unchecked(dst, length);

            var i:uint = 0;

            // 4x unrolled loop
            for (; i + 3 < n; i += 4)
            {
                sf32(vec[i], dst.position);
                dst.position += 4;
                sf32(vec[i + 1], dst.position);
                dst.position += 4;
                sf32(vec[i + 2], dst.position);
                dst.position += 4;
                sf32(vec[i + 3], dst.position);
                dst.position += 4;
            }

            // tail loop
            for (; i < n; i++)
            {
                sf32(vec[i], dst.position);
                dst.position += 4;
            }
        }

        /**
         * Write a 64-bit IEEE 754 double
         * ActionScript uses little-endian IEEE 754 format
         * Codegen inlines this method for better performance
         * @param dst The active encode context
         * @param value The double value to write
         */
        [Inline]
        public static function writeDouble(dst:PackContext, value:Number):void
        {
            ensure(dst, 8);
            sf64(value, dst.position);
            dst.position += 8; // Little-endian IEEE 754 double precision
        }

        /**
         * Write a vector of 64-bit IEEE 754 doubles as a length-delimited field
         * @param dst The active encode context
         * @param vec The vector of double values to write
         * @param n Parameter.
         */
        public static function writeDoubleVector(dst:PackContext, vec:Vector.<Number>, n:uint):void
        {
            ensure(dst, Number(n) * 8 + 5);
            const length:uint = n << 3;
            writeVarint32Unchecked(dst, length);

            // 4x unrolled loop
            var i:uint = 0;
            for (; i + 3 < n; i += 4)
            {
                sf64(vec[i], dst.position);
                dst.position += 8;
                sf64(vec[i + 1], dst.position);
                dst.position += 8;
                sf64(vec[i + 2], dst.position);
                dst.position += 8;
                sf64(vec[i + 3], dst.position);
                dst.position += 8;
            }

            // tail loop
            for (; i < n; i++)
            {
                sf64(vec[i], dst.position);
                dst.position += 8;
            }
        }

        /**
         * Write a boolean value as varint (0 or 1)
         * Codegen inlines this method for better performance
         * @param dst The active encode context
         * @param value The boolean value to write (true = 1, false = 0)
         */
        [Inline]
        public static function writeBool(dst:PackContext, value:Boolean):void
        {
            ensure(dst, 1);
            si8(value ? 1 : 0, dst.position);
            dst.position++;
        }

        /**
         * Write a vector of boolean values as a length-delimited field
         * @param dst The active encode context
         * @param vec The vector of boolean values to write (true = 1, false = 0)
         * @param n Parameter.
         */
        public static function writeBoolVector(dst:PackContext, vec:Vector.<Boolean>, n:uint):void
        {
            ensure(dst, Number(n) * 1 + 5);
            const length:uint = n; // 1 byte per boolean
            writeVarint32Unchecked(dst, length);

            // 4x unrolled loop
            var i:uint = 0;
            for (; i + 3 < n; i += 4)
            {
                si32(
                        (vec[i] ? 1 : 0) |
                        (vec[i + 1] ? 0x100 : 0) |
                        (vec[i + 2] ? 0x10000 : 0) |
                        (vec[i + 3] ? 0x1000000 : 0), dst.position);
                dst.position += 4;
            }

            // tail loop
            for (; i < n; i++)
            {
                si8(vec[i] ? 1 : 0, dst.position);
                dst.position++;
            }
        }

        /**
         * Write a length-delimited UTF-8 string
         * @param dst The active encode context
         * @param value The string value to write as UTF-8 bytes
         */
        public static function writeString(dst:PackContext, value:String):void
        {
            const reuseBuffer:ByteArray = SCRATCH;
            reuseBuffer.length = 0;
            reuseBuffer.writeUTFBytes(value);

            const length:uint = reuseBuffer.length;
            ensure(dst, Number(length) + 5);
            writeVarint32Unchecked(dst, length);
            writeRawBytes(dst, reuseBuffer, 0, length);
        }

        /**
         * Write length-delimited raw bytes
         * @param dst The active encode context
         * @param value The ByteArray containing raw bytes to write
         */
        public static function writeBytes(dst:PackContext, value:ByteArray):void
        {
            const length:uint = value.length;
            ensure(dst, Number(length) + 5);
            writeVarint32Unchecked(dst, length);
            writeRawBytes(dst, value, 0, length);
        }

        /**
         * Write a field tag (field number and wire type)
         * Codegen inlines this method to "output.writeByte / output.writeShort / writeVarint32" for better performance with constant folding.
         * @param dst The active encode context
         * @param fieldNumber The protobuf field number
         * @param wireType The protobuf wire type (0-5)
         */
        public static function writeTag(dst:PackContext, fieldNumber:uint, wireType:uint):void
        {
            ensure(dst, 5);
            writeVarint32Unchecked(dst, (fieldNumber << 3) | wireType);
        }

        /** Write into capacity already reserved by the enclosing operation. */
        [Inline]
        private static function writeVarint32Unchecked(dst:PackContext, value:uint):void
        {
            // 1 byte
            if (value < 0x80)
            {
                si8(value, dst.position);
                dst.position++;
                return;
            }

            // 2 bytes
            if (value < 0x4000)
            {
                si16(((value >>> 7) << 8) | ((value & 0x7F) | 0x80), dst.position);
                dst.position += 2;
                return;
            }

            // 3 bytes
            if (value < 0x200000)
            {
                si16(
                        ((((value >>> 7) & 0x7F) | 0x80) << 8) |
                        ((value & 0x7F) | 0x80),
                        dst.position);
                dst.position += 2;
                si8(value >>> 14, dst.position);
                dst.position++;
                return;
            }

            // 4 bytes
            if (value < 0x10000000)
            {
                si32(
                        ((value >>> 21) << 24) |
                        ((((value >>> 14) & 0x7F) | 0x80) << 16) |
                        ((((value >>> 7) & 0x7F) | 0x80) << 8) |
                        ((value & 0x7F) | 0x80),
                        dst.position);
                dst.position += 4;
                return;
            }

            // 5 bytes
            si32(
                    ((((value >>> 21) & 0x7F) | 0x80) << 24) |
                    ((((value >>> 14) & 0x7F) | 0x80) << 16) |
                    ((((value >>> 7) & 0x7F) | 0x80) << 8) |
                    ((value & 0x7F) | 0x80),
                    dst.position);
            dst.position += 4;
            si8(value >>> 28, dst.position);
            dst.position++;
        }

        /** Write into capacity already reserved by the enclosing operation. */
        [Inline]
        private static function writeVarint64Unchecked(dst:PackContext, low:uint, high:uint):void
        {
            if (high != 0)
            {
                // A nonzero high word guarantees at least five encoded bytes.
                si32(
                        (((low >>> 21) & 0x7F) << 24) |
                        (((low >>> 14) & 0x7F) << 16) |
                        (((low >>> 7) & 0x7F) << 8) |
                        (low & 0x7F) | 0x80808080, dst.position);
                dst.position += 4;
                low = (low >>> 28) | (high << 4);
                high >>>= 28;

                if (high != 0)
                {
                    si32(
                            (((low >>> 21) & 0x7F) << 24) |
                            (((low >>> 14) & 0x7F) << 16) |
                            (((low >>> 7) & 0x7F) << 8) |
                            (low & 0x7F) | 0x80808080, dst.position);
                    dst.position += 4;
                    const last:uint = (low >>> 28) | (high << 4);
                    if (last < 0x80)
                    {
                        si8(last, dst.position);
                        dst.position++;
                    }
                    else
                    {
                        si16(((last >>> 7) << 8) | (last & 0x7F) | 0x80, dst.position);
                        dst.position += 2;
                    }
                    return;
                }
            }

            // 1 byte
            if (low < 0x80)
            {
                si8(low, dst.position);
                dst.position++;
                return;
            }

            // 2 bytes
            if (low < 0x4000)
            {
                si16(((low >>> 7) << 8) | ((low & 0x7F) | 0x80), dst.position);
                dst.position += 2;
                return;
            }

            // 3 bytes
            if (low < 0x200000)
            {
                si16(
                        ((((low >>> 7) & 0x7F) | 0x80) << 8) |
                        ((low & 0x7F) | 0x80),
                        dst.position);
                dst.position += 2;
                si8(low >>> 14, dst.position);
                dst.position++;
                return;
            }

            // 4 bytes
            if (low < 0x10000000)
            {
                si32(
                        ((low >>> 21) << 24) |
                        ((((low >>> 14) & 0x7F) | 0x80) << 16) |
                        ((((low >>> 7) & 0x7F) | 0x80) << 8) |
                        ((low & 0x7F) | 0x80),
                        dst.position);
                dst.position += 4;
                return;
            }

            // 5 bytes
            si32(
                    ((((low >>> 21) & 0x7F) | 0x80) << 24) |
                    ((((low >>> 14) & 0x7F) | 0x80) << 16) |
                    ((((low >>> 7) & 0x7F) | 0x80) << 8) |
                    ((low & 0x7F) | 0x80),
                    dst.position);
            dst.position += 4;
            si8(low >>> 28, dst.position);
            dst.position++;
        }
    }
}
