package as3pb.proto
{
    import flash.utils.ByteArray;

    import as3pb.types.UInt64Vector;
    import as3pb.types.Int64Vector;

    /**
     * Serialization utilities for Protocol Buffers in ActionScript 3 for bytearrays.
     * All dsts should use little-endian byte order as per protobuf specification
     */
    public final class Serialize
    {
        /**
         * Write a varint-encoded 32-bit unsigned integer
         * @param dst The destination ByteArray to write to
         * @param value The 32-bit unsigned integer value to encode
         */
        [Inline]
        public static function writeVarint32(dst:ByteArray, value:uint):void
        {
            // 1 byte
            if (value < 0x80)
            {
                dst.writeByte(value);
                return;
            }

            // 2 bytes
            if (value < 0x4000)
            {
                dst.writeShort(((value >>> 7) << 8) | ((value & 0x7F) | 0x80));
                return;
            }

            // 3 bytes
            if (value < 0x200000)
            {
                dst.writeShort(
                        ((((value >>> 7) & 0x7F) | 0x80) << 8) |
                        ((value & 0x7F) | 0x80)
                    );
                dst.writeByte(value >>> 14);
                return;
            }

            // 4 bytes
            if (value < 0x10000000)
            {
                dst.writeUnsignedInt(
                        ((value >>> 21) << 24) |
                        ((((value >>> 14) & 0x7F) | 0x80) << 16) |
                        ((((value >>> 7) & 0x7F) | 0x80) << 8) |
                        ((value & 0x7F) | 0x80)
                    );
                return;
            }

            // 5 bytes
            dst.writeUnsignedInt(
                    ((((value >>> 21) & 0x7F) | 0x80) << 24) |
                    ((((value >>> 14) & 0x7F) | 0x80) << 16) |
                    ((((value >>> 7) & 0x7F) | 0x80) << 8) |
                    ((value & 0x7F) | 0x80)
                );
            dst.writeByte(value >>> 28);
        }

        /**
         * Write a varint-encoded vector of 32-bit unsigned integers as a length-delimited field
         * @param dst The destination ByteArray to write to
         * @param vec The vector of 32-bit unsigned integers to encode as varints
         * @param reuseBuffer A ByteArray to reuse for encoding the varints to reduce allocations
         * @param n Parameter.
         */
        public static function writeVarint32Vector(dst:ByteArray, vec:Vector.<uint>, reuseBuffer:ByteArray, n:uint):void
        {
            reuseBuffer.length = 0;

            for (var i:uint = 0; i < n; i++)
                writeVarint32(reuseBuffer, vec[i]);

            writeVarint32(dst, reuseBuffer.length);
            dst.writeBytes(reuseBuffer, 0, reuseBuffer.length);
        }

        /**
         * Write a varint-encoded vector of 32-bit signed integers as a length-delimited field
         * @param dst The destination ByteArray to write to
         * @param vec The vector of 32-bit signed integers to encode as varints
         * @param reuseBuffer A ByteArray to reuse for encoding the varints to reduce allocations
         * @param n Parameter.
         */
        public static function writeVarint32sVector(dst:ByteArray, vec:Vector.<int>, reuseBuffer:ByteArray, n:uint):void
        {
            reuseBuffer.length = 0;

            for (var i:uint = 0; i < n; i++)
                writeVarint32(reuseBuffer, vec[i]);

            writeVarint32(dst, reuseBuffer.length);
            dst.writeBytes(reuseBuffer, 0, reuseBuffer.length);
        }

        /**
         * Write a varint-encoded unsigned 64-bit number
         * @param dst The destination ByteArray to write to
         * @param low The low 32 bits of the unsigned 64-bit number value to encode
         * @param high The high 32 bits of the unsigned 64-bit number value to encode
         */
        [Inline]
        public static function writeVarint64(dst:ByteArray, low:uint, high:uint):void
        {
            // 32-bit varint encoding (common case) (this is manually inlined for better performance, nested functions don't inline everything automatically)
            if (high == 0)
            {
                // 1 byte
                if (low < 0x80)
                {
                    dst.writeByte(low);
                    return;
                }

                // 2 bytes
                if (low < 0x4000)
                {
                    dst.writeShort(((low >>> 7) << 8) | ((low & 0x7F) | 0x80));
                    return;
                }

                // 3 bytes
                if (low < 0x200000)
                {
                    dst.writeShort(
                            ((((low >>> 7) & 0x7F) | 0x80) << 8) |
                            ((low & 0x7F) | 0x80)
                        );
                    dst.writeByte(low >>> 14);
                    return;
                }

                // 4 bytes
                if (low < 0x10000000)
                {
                    dst.writeUnsignedInt(
                            ((low >>> 21) << 24) |
                            ((((low >>> 14) & 0x7F) | 0x80) << 16) |
                            ((((low >>> 7) & 0x7F) | 0x80) << 8) |
                            ((low & 0x7F) | 0x80)
                        );
                    return;
                }

                // 5 bytes
                dst.writeUnsignedInt(
                        ((((low >>> 21) & 0x7F) | 0x80) << 24) |
                        ((((low >>> 14) & 0x7F) | 0x80) << 16) |
                        ((((low >>> 7) & 0x7F) | 0x80) << 8) |
                        ((low & 0x7F) | 0x80)
                    );
                dst.writeByte(low >>> 28);
                return;
            }

            // 64-bit varint encoding
            do
            {
                dst.writeByte((low & 0x7F) | 0x80);
                low = (low >>> 7) | (high << 25);
                high >>>= 7;
            }
            while (high != 0 || low >= 0x80);

            dst.writeByte(low);
        }

        /**
         * Write a varint-encoded vector of unsigned 64-bit numbers as a length-delimited field
         * @param dst The destination ByteArray to write to
         * @param vec The vector of unsigned 64-bit numbers to encode as varints
         * @param reuseBuffer A ByteArray to reuse for encoding the varints to reduce allocations
         * @param n Parameter.
         */
        public static function writeVarint64Vector(dst:ByteArray, vec:UInt64Vector, reuseBuffer:ByteArray, n:uint):void
        {
            reuseBuffer.length = 0;

            const lowVec:Vector.<uint> = vec.low;
            const highVec:Vector.<uint> = vec.high;

            for (var i:uint = 0; i < n; i++)
                writeVarint64(reuseBuffer, lowVec[i], highVec[i]);

            writeVarint32(dst, reuseBuffer.length);
            dst.writeBytes(reuseBuffer, 0, reuseBuffer.length);
        }

        /**
         * Write a varint-encoded signed 64-bit number
         * @param dst The destination ByteArray to write to
         * @param low The low 32 bits of the signed 64-bit number value to encode
         * @param high The high 32 bits of the signed 64-bit number value to encode
         */
        [Inline]
        public static function writeVarint64s(dst:ByteArray, low:uint, high:int):void
        {
            // 32-bit varint encoding (common case) (this is manually inlined for better performance, nested functions don't inline everything automatically)
            if (high == 0)
            {
                // 1 byte
                if (low < 0x80)
                {
                    dst.writeByte(low);
                    return;
                }

                // 2 bytes
                if (low < 0x4000)
                {
                    dst.writeShort(((low >>> 7) << 8) | ((low & 0x7F) | 0x80));
                    return;
                }

                // 3 bytes
                if (low < 0x200000)
                {
                    dst.writeShort(
                            ((((low >>> 7) & 0x7F) | 0x80) << 8) |
                            ((low & 0x7F) | 0x80)
                        );
                    dst.writeByte(low >>> 14);
                    return;
                }

                // 4 bytes
                if (low < 0x10000000)
                {
                    dst.writeUnsignedInt(
                            ((low >>> 21) << 24) |
                            ((((low >>> 14) & 0x7F) | 0x80) << 16) |
                            ((((low >>> 7) & 0x7F) | 0x80) << 8) |
                            ((low & 0x7F) | 0x80)
                        );
                    return;
                }

                // 5 bytes
                dst.writeUnsignedInt(
                        ((((low >>> 21) & 0x7F) | 0x80) << 24) |
                        ((((low >>> 14) & 0x7F) | 0x80) << 16) |
                        ((((low >>> 7) & 0x7F) | 0x80) << 8) |
                        ((low & 0x7F) | 0x80)
                    );
                dst.writeByte(low >>> 28);
                return;
            }

            // 64-bit varint encoding
            do
            {
                dst.writeByte((low & 0x7F) | 0x80);
                low = (low >>> 7) | (high << 25);
                high >>>= 7;
            }
            while (high != 0 || low >= 0x80);

            dst.writeByte(low);
        }

        /**
         * Write a varint-encoded vector of signed 64-bit numbers as a length-delimited field
         * @param dst The destination ByteArray to write to
         * @param vec The vector of signed 64-bit numbers to encode as varints
         * @param reuseBuffer A ByteArray to reuse for encoding the varints to reduce allocations
         * @param n Parameter.
         */
        public static function writeVarint64sVector(dst:ByteArray, vec:Int64Vector, reuseBuffer:ByteArray, n:uint):void
        {
            reuseBuffer.length = 0;

            const lowVec:Vector.<uint> = vec.low;
            const highVec:Vector.<int> = vec.high;

            for (var i:uint = 0; i < n; i++)
                writeVarint64s(reuseBuffer, lowVec[i], highVec[i]);

            writeVarint32(dst, reuseBuffer.length);
            dst.writeBytes(reuseBuffer, 0, reuseBuffer.length);
        }

        /**
         * Write a varint-encoded signed 32-bit integer.
         * Negative values are sign-extended, matching protobuf int32 encoding.
         * @param dst The destination ByteArray to write to
         * @param value The signed 32-bit integer value to encode
         */
        [Inline]
        public static function writeInt32(dst:ByteArray, value:int):void
        {
            if (value < 0)
            {
                writeVarint64(dst, uint(value), 0xffffffff);
                return;
            }

            // 1 byte
            if (value < 0x80)
            {
                dst.writeByte(value);
                return;
            }

            // 2 bytes
            if (value < 0x4000)
            {
                dst.writeShort(((value >>> 7) << 8) | ((value & 0x7F) | 0x80));
                return;
            }

            // 3 bytes
            if (value < 0x200000)
            {
                dst.writeShort(
                        ((((value >>> 7) & 0x7F) | 0x80) << 8) |
                        ((value & 0x7F) | 0x80)
                    );
                dst.writeByte(value >>> 14);
                return;
            }

            // 4 bytes
            if (value < 0x10000000)
            {
                dst.writeUnsignedInt(
                        ((value >>> 21) << 24) |
                        ((((value >>> 14) & 0x7F) | 0x80) << 16) |
                        ((((value >>> 7) & 0x7F) | 0x80) << 8) |
                        ((value & 0x7F) | 0x80)
                    );
                return;
            }

            // 5 bytes
            dst.writeUnsignedInt(
                    ((((value >>> 21) & 0x7F) | 0x80) << 24) |
                    ((((value >>> 14) & 0x7F) | 0x80) << 16) |
                    ((((value >>> 7) & 0x7F) | 0x80) << 8) |
                    ((value & 0x7F) | 0x80)
                );
            dst.writeByte(value >>> 28);
        }

        /**
         * Write a varint-encoded vector of signed 32-bit integers as a length-delimited field.
         * Negative values are sign-extended, matching protobuf int32 encoding.
         * @param dst The destination ByteArray to write to
         * @param vec The vector of 32-bit signed integers to encode as varints
         * @param reuseBuffer A ByteArray to reuse for encoding the varints to reduce allocations
         * @param n Parameter.
         */
        public static function writeInt32Vector(dst:ByteArray, vec:Vector.<int>, reuseBuffer:ByteArray, n:uint):void
        {
            reuseBuffer.length = 0;

            for (var i:uint = 0; i < n; i++)
                writeInt32(reuseBuffer, vec[i]);

            writeVarint32(dst, reuseBuffer.length);
            dst.writeBytes(reuseBuffer, 0, reuseBuffer.length);
        }

        /**
         * Write a zigzag-encoded signed 32-bit integer
         * @param dst The destination ByteArray to write to
         * @param value The signed 32-bit integer value to encode with zigzag encoding
         */
        [Inline]
        public static function writeSint32(dst:ByteArray, value:int):void
        {
            writeVarint32(dst, uint((value << 1) ^ (value >> 31)));
        }

        /**
         * Write a zigzag-encoded varint vector of 32-bit signed integers as a length-delimited field
         * @param dst The destination ByteArray to write to
         * @param vec The vector of 32-bit signed integers to encode using zigzag + varint encoding
         * @param reuseBuffer A ByteArray to reuse for encoding the varints to reduce allocations
         * @param n Parameter.
         */
        public static function writeSint32Vector(dst:ByteArray, vec:Vector.<int>, reuseBuffer:ByteArray, n:uint):void
        {
            reuseBuffer.length = 0;

            for (var i:uint = 0; i < n; i++)
                writeVarint32(reuseBuffer, uint((vec[i] << 1) ^ (vec[i] >> 31)));

            writeVarint32(dst, reuseBuffer.length);
            dst.writeBytes(reuseBuffer, 0, reuseBuffer.length);
        }

        /**
         * Write a zigzag-encoded signed 64-bit integer
         * @param dst The destination ByteArray to write to
         * @param value The signed 64-bit number value to encode with zigzag encoding
         * @param low Parameter.
         * @param high Parameter.
         */
        [Inline]
        public static function writeSint64(dst:ByteArray, low:uint, high:int):void
        {
            const mask:uint = high >> 31;
            const carry:uint = low >>> 31;

            // zigzag encode
            low = (low << 1) ^ mask;
            high = ((high << 1) | carry) ^ mask;

            // 32-bit varint encoding (common case) (this is manually inlined for better performance, nested functions don't inline everything automatically)
            if (high == 0)
            {
                // 1 byte
                if (low < 0x80)
                {
                    dst.writeByte(low);
                    return;
                }

                // 2 bytes
                if (low < 0x4000)
                {
                    dst.writeShort(((low >>> 7) << 8) | ((low & 0x7F) | 0x80));
                    return;
                }

                // 3 bytes
                if (low < 0x200000)
                {
                    dst.writeShort(
                            ((((low >>> 7) & 0x7F) | 0x80) << 8) |
                            ((low & 0x7F) | 0x80)
                        );
                    dst.writeByte(low >>> 14);
                    return;
                }

                // 4 bytes
                if (low < 0x10000000)
                {
                    dst.writeUnsignedInt(
                            ((low >>> 21) << 24) |
                            ((((low >>> 14) & 0x7F) | 0x80) << 16) |
                            ((((low >>> 7) & 0x7F) | 0x80) << 8) |
                            ((low & 0x7F) | 0x80)
                        );
                    return;
                }

                // 5 bytes
                dst.writeUnsignedInt(
                        ((((low >>> 21) & 0x7F) | 0x80) << 24) |
                        ((((low >>> 14) & 0x7F) | 0x80) << 16) |
                        ((((low >>> 7) & 0x7F) | 0x80) << 8) |
                        ((low & 0x7F) | 0x80)
                    );
                dst.writeByte(low >>> 28);
                return;
            }

            // 64-bit varint encoding
            do
            {
                dst.writeByte((low & 0x7F) | 0x80);
                low = (low >>> 7) | (high << 25);
                high >>>= 7;
            }
            while (high != 0 || low >= 0x80);

            dst.writeByte(low);
        }

        /**
         * Write a zigzag-encoded varint vector of 64-bit signed integers as a length-delimited field
         * @param dst The destination ByteArray to write to
         * @param vec The vector of 64-bit signed integers to encode using zigzag + varint encoding
         * @param reuseBuffer A ByteArray to reuse for encoding the varints to reduce allocations
         * @param n Parameter.
         */
        public static function writeSint64Vector(dst:ByteArray, vec:Int64Vector, reuseBuffer:ByteArray, n:uint):void
        {
            reuseBuffer.length = 0;

            const lowVec:Vector.<uint> = vec.low;
            const highVec:Vector.<int> = vec.high;

            for (var i:uint = 0; i < n; i++)
                writeSint64(reuseBuffer, lowVec[i], highVec[i]);

            writeVarint32(dst, reuseBuffer.length);
            dst.writeBytes(reuseBuffer, 0, reuseBuffer.length);
        }

        /**
         * Write a 32-bit fixed-size little-endian unsigned integer
         * @param dst The destination ByteArray to write to
         * @param value The 32-bit unsigned integer value to write
         */
        [Inline]
        public static function writeFixed32(dst:ByteArray, value:uint):void
        {
            dst.writeUnsignedInt(value); // ActionScript writeUnsignedInt is little-endian
        }

        /**
         * Write a fixed-size vector of 32-bit unsigned integers as a length-delimited field
         * @param dst The destination ByteArray to write to
         * @param vec The vector of 32-bit unsigned integers to write
         * @param n Parameter.
         */
        public static function writeFixed32Vector(dst:ByteArray, vec:Vector.<uint>, n:uint):void
        {
            const length:uint = n << 2;
            writeVarint32(dst, length);

            // 4x unrolled loop
            var i:uint = 0;
            for (; i + 3 < n; i += 4)
            {
                dst.writeUnsignedInt(vec[i]);
                dst.writeUnsignedInt(vec[i + 1]);
                dst.writeUnsignedInt(vec[i + 2]);
                dst.writeUnsignedInt(vec[i + 3]);
            }

            // tail loop
            for (; i < n; i++)
                dst.writeUnsignedInt(vec[i]);
        }

        /**
         * Write a 32-bit fixed-size little-endian signed integer
         * Codegen inlines this method for better performance
         * @param dst The destination ByteArray to write to
         * @param value The 32-bit signed integer value to write
         */
        [Inline]
        public static function writeSfixed32(dst:ByteArray, value:int):void
        {
            dst.writeInt(value); // ActionScript writeInt is little-endian
        }

        /**
         * Write a fixed-size vector of 32-bit signed integers as a length-delimited field
         * @param dst The destination ByteArray to write to
         * @param vec The vector of 32-bit signed integers to write
         * @param n Parameter.
         */
        public static function writeSfixed32Vector(dst:ByteArray, vec:Vector.<int>, n:uint):void
        {
            const length:uint = n << 2;
            writeVarint32(dst, length);

            // 4x unrolled loop
            var i:uint = 0;
            for (; i + 3 < n; i += 4)
            {
                dst.writeInt(vec[i]);
                dst.writeInt(vec[i + 1]);
                dst.writeInt(vec[i + 2]);
                dst.writeInt(vec[i + 3]);
            }

            // tail loop
            for (; i < n; i++)
                dst.writeInt(vec[i]);
        }

        /**
         * Write a 64-bit fixed-size little-endian number
         * Codegen inlines this method for better performance
         * @param dst The destination ByteArray to write to
         * @param value The 64-bit number value to write
         * @param low Parameter.
         * @param high Parameter.
         */
        [Inline]
        public static function writeFixed64(dst:ByteArray, low:uint, high:uint):void
        {
            dst.writeUnsignedInt(low);
            dst.writeUnsignedInt(high);
        }

        /**
         * Write a fixed-size vector of 64-bit unsigned integers as a length-delimited field
         * @param dst The destination ByteArray to write to
         * @param vec The vector of 64-bit unsigned integers to write
         * @param n Parameter.
         */
        public static function writeFixed64Vector(dst:ByteArray, vec:UInt64Vector, n:uint):void
        {
            const length:uint = n << 3;
            writeVarint32(dst, length);

            const lowVec:Vector.<uint> = vec.low;
            const highVec:Vector.<uint> = vec.high;

            // 4x unrolled loop
            var i:uint = 0;
            for (; i + 3 < n; i += 4)
            {
                dst.writeUnsignedInt(lowVec[i]);
                dst.writeUnsignedInt(highVec[i]);

                dst.writeUnsignedInt(lowVec[i + 1]);
                dst.writeUnsignedInt(highVec[i + 1]);

                dst.writeUnsignedInt(lowVec[i + 2]);
                dst.writeUnsignedInt(highVec[i + 2]);

                dst.writeUnsignedInt(lowVec[i + 3]);
                dst.writeUnsignedInt(highVec[i + 3]);
            }

            // tail loop
            for (; i < n; i++)
            {
                dst.writeUnsignedInt(lowVec[i]);
                dst.writeUnsignedInt(highVec[i]);
            }
        }

        /**
         * Write a 64-bit fixed-size little-endian signed number
         * Codegen inlines this method for better performance
         * @param dst The destination ByteArray to write to
         * @param value The 64-bit signed number value to write
         * @param low Parameter.
         * @param high Parameter.
         */
        [Inline]
        public static function writeSfixed64(dst:ByteArray, low:uint, high:int):void
        {
            dst.writeUnsignedInt(low);
            dst.writeInt(high);
        }

        /**
         * Write a fixed-size vector of 64-bit signed integers as a length-delimited field
         * @param dst The destination ByteArray to write to
         * @param vec The vector of 64-bit signed integers to write
         * @param n Parameter.
         */
        public static function writeSfixed64Vector(dst:ByteArray, vec:Int64Vector, n:uint):void
        {
            const length:uint = n << 3;
            writeVarint32(dst, length);

            const lowVec:Vector.<uint> = vec.low;
            const highVec:Vector.<int> = vec.high;

            // 4x unrolled loop
            var i:uint = 0;
            for (; i + 3 < n; i += 4)
            {
                dst.writeUnsignedInt(lowVec[i]);
                dst.writeInt(highVec[i]);

                dst.writeUnsignedInt(lowVec[i + 1]);
                dst.writeInt(highVec[i + 1]);

                dst.writeUnsignedInt(lowVec[i + 2]);
                dst.writeInt(highVec[i + 2]);

                dst.writeUnsignedInt(lowVec[i + 3]);
                dst.writeInt(highVec[i + 3]);
            }

            // tail loop
            for (; i < n; i++)
            {
                dst.writeUnsignedInt(lowVec[i]);
                dst.writeInt(highVec[i]);
            }
        }

        /**
         * Write a 32-bit IEEE 754 float
         * ActionScript uses little-endian IEEE 754 format
         * Codegen inlines this method for better performance
         * @param dst The destination ByteArray to write to
         * @param value The float value to write
         */
        [Inline]
        public static function writeFloat(dst:ByteArray, value:Number):void
        {
            dst.writeFloat(value); // Little-endian IEEE 754 single precision
        }

        /**
         * Write a vector of 32-bit IEEE 754 floats as a length-delimited field
         * @param dst The destination ByteArray to write to
         * @param vec The vector of float values to write
         * @param n Parameter.
         */
        public static function writeFloatVector(dst:ByteArray, vec:Vector.<Number>, n:uint):void
        {
            const length:uint = n << 2;
            writeVarint32(dst, length);

            var i:uint = 0;

            // 4x unrolled loop
            for (; i + 3 < n; i += 4)
            {
                dst.writeFloat(vec[i]);
                dst.writeFloat(vec[i + 1]);
                dst.writeFloat(vec[i + 2]);
                dst.writeFloat(vec[i + 3]);
            }

            // tail loop
            for (; i < n; i++)
                dst.writeFloat(vec[i]);
        }

        /**
         * Write a 64-bit IEEE 754 double
         * ActionScript uses little-endian IEEE 754 format
         * Codegen inlines this method for better performance
         * @param dst The destination ByteArray to write to
         * @param value The double value to write
         */
        [Inline]
        public static function writeDouble(dst:ByteArray, value:Number):void
        {
            dst.writeDouble(value); // Little-endian IEEE 754 double precision
        }

        /**
         * Write a vector of 64-bit IEEE 754 doubles as a length-delimited field
         * @param dst The destination ByteArray to write to
         * @param vec The vector of double values to write
         * @param n Parameter.
         */
        public static function writeDoubleVector(dst:ByteArray, vec:Vector.<Number>, n:uint):void
        {
            const length:uint = n << 3;
            writeVarint32(dst, length);

            // 4x unrolled loop
            var i:uint = 0;
            for (; i + 3 < n; i += 4)
            {
                dst.writeDouble(vec[i]);
                dst.writeDouble(vec[i + 1]);
                dst.writeDouble(vec[i + 2]);
                dst.writeDouble(vec[i + 3]);
            }

            // tail loop
            for (; i < n; i++)
                dst.writeDouble(vec[i]);
        }

        /**
         * Write a boolean value as varint (0 or 1)
         * Codegen inlines this method for better performance
         * @param dst The destination ByteArray to write to
         * @param value The boolean value to write (true = 1, false = 0)
         */
        [Inline]
        public static function writeBool(dst:ByteArray, value:Boolean):void
        {
            dst.writeByte(value ? 1 : 0);
        }

        /**
         * Write a vector of boolean values as a length-delimited field
         * @param dst The destination ByteArray to write to
         * @param vec The vector of boolean values to write (true = 1, false = 0)
         * @param n Parameter.
         */
        public static function writeBoolVector(dst:ByteArray, vec:Vector.<Boolean>, n:uint):void
        {
            const length:uint = n; // 1 byte per boolean
            writeVarint32(dst, length);

            // 4x unrolled loop
            var i:uint = 0;
            for (; i + 3 < n; i += 4)
            {
                dst.writeByte(vec[i] ? 1 : 0);
                dst.writeByte(vec[i + 1] ? 1 : 0);
                dst.writeByte(vec[i + 2] ? 1 : 0);
                dst.writeByte(vec[i + 3] ? 1 : 0);
            }

            // tail loop
            for (; i < n; i++)
                dst.writeByte(vec[i] ? 1 : 0);
        }

        /**
         * Write a length-delimited UTF-8 string
         * @param dst The destination ByteArray to write to
         * @param value The string value to write as UTF-8 bytes
         * @param reuseBuffer A ByteArray to reuse for encoding the string to reduce allocations
         */
        public static function writeString(dst:ByteArray, value:String, reuseBuffer:ByteArray):void
        {
            reuseBuffer.length = 0;
            reuseBuffer.writeUTFBytes(value);

            const length:uint = reuseBuffer.length;
            writeVarint32(dst, length);
            dst.writeBytes(reuseBuffer, 0, length);
        }

        /**
         * Write length-delimited raw bytes
         * @param dst The destination ByteArray to write to
         * @param value The ByteArray containing raw bytes to write
         */
        public static function writeBytes(dst:ByteArray, value:ByteArray):void
        {
            const length:uint = value.length;
            writeVarint32(dst, length);
            dst.writeBytes(value, 0, length);
        }

        /**
         * Write a field tag (field number and wire type)
         * Codegen inlines this method to "output.writeByte / output.writeShort / writeVarint32" for better performance with constant folding.
         * @param dst The destination ByteArray to write to
         * @param fieldNumber The protobuf field number
         * @param wireType The protobuf wire type (0-5)
         */
        public static function writeTag(dst:ByteArray, fieldNumber:uint, wireType:uint):void
        {
            writeVarint32(dst, (fieldNumber << 3) | wireType);
        }
    }
}
