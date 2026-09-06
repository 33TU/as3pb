package flash.utils
{
    import flash.errors.IOError;

    /**
     * Royale ByteArray with a retained backing capacity.
     *
     * BinaryData normally reallocates its ArrayBuffer for every length change.
     * Protobuf repeatedly clears and refills bytes fields, so retaining capacity
     * avoids two allocations and copies per decoded field.
     */
    public class ByteArray
    {
        private static const MIN_CAPACITY:uint = 64;
        private static const UTF8_DECODER:TextDecoder = new TextDecoder("utf-8");
        private static const UTF8_ENCODER:TextEncoder = new TextEncoder();

        private var ba:ArrayBuffer = new ArrayBuffer(0);
        private var _typedArray:Uint8Array = new Uint8Array(ba);
        private var _dataView:DataView;
        private var _len:uint = 0;
        private var _position:uint = 0;
        private var _littleEndian:Boolean = false;

        public function ByteArray()
        {
        }

        // The backing buffer may be larger than the logical length.
        public function get data():ArrayBuffer
        {
            return ba;
        }

        public function get length():uint
        {
            return _len;
        }

        public function set length(value:uint):void
        {
            setBufferSize(value);
        }

        public function get position():uint
        {
            return _position;
        }

        public function set position(value:uint):void
        {
            _position = value;
        }

        public function get bytesAvailable():uint
        {
            return _position < _len ? _len - _position : 0;
        }

        public function get endian():String
        {
            return _littleEndian ? Endian.LITTLE_ENDIAN : Endian.BIG_ENDIAN;
        }

        public function set endian(value:String):void
        {
            if (value != Endian.LITTLE_ENDIAN && value != Endian.BIG_ENDIAN)
                throw new Error("Invalid endian value");
            _littleEndian = value == Endian.LITTLE_ENDIAN;
        }

        public function clear():void
        {
            length = 0;
        }

        private function getTypedArray():Uint8Array
        {
            return _typedArray;
        }

        private function getDataView():DataView
        {
            if (!_dataView)
                _dataView = new DataView(ba);
            return _dataView;
        }

        private function requireBytes(count:uint):void
        {
            if (_position > _len || count > _len - _position)
                throw new IOError("End of file was encountered");
        }

        private function reserveWrite(count:uint):void
        {
            const end:Number = Number(_position) + count;
            if (end > uint.MAX_VALUE)
                throw new RangeError("ByteArray length overflow");
            if (end > _len)
                setBufferSize(uint(end));
        }

        private function setBufferSize(newSize:uint):void
        {
            const oldLength:uint = _len;
            var view:Uint8Array = getTypedArray();
            const capacity:uint = view.length;

            if (newSize > capacity)
            {
                var newCapacity:uint = capacity < MIN_CAPACITY
                    ? MIN_CAPACITY
                    : capacity << 1;
                if (newCapacity < newSize)
                    newCapacity = newSize;

                const grown:Uint8Array = new Uint8Array(newCapacity);
                if (oldLength)
                    grown.set (new Uint8Array(ba, 0, oldLength));
                ba = grown.buffer;
                _typedArray = grown;
                _dataView = null;
                view = grown;
            }
            else if (newSize != oldLength)
            {
                // Flash fills newly exposed bytes with zero. Clear truncated
                // storage now so a later logical regrowth has the same result.
                const from:uint = newSize < oldLength ? newSize : oldLength;
                const to:uint = newSize < oldLength ? oldLength : newSize;
                view.fill(0, from, to);
            }

            _len = newSize;
            if (_position > newSize)
                _position = newSize;
        }

        public function writeBytes(bytes:ByteArray, offset:uint = 0, length:uint = 0):void
        {
            if (!bytes)
                throw new TypeError("Parameter bytes must be non-null");
            if (offset > bytes.length || length > bytes.length - offset)
                throw new RangeError("Source range is out of bounds");
            if (!length)
                length = bytes.length - offset;
            if (!length)
                return;
            const source:Uint8Array = new Uint8Array(bytes.ba, offset, length);
            reserveWrite(length);
            _typedArray.set (source, _position);
            _position += length;
        }

        public function readBytes(bytes:ByteArray, offset:uint = 0, length:uint = 0):void
        {
            if (!bytes)
                throw new TypeError("Parameter bytes must be non-null");
            if (!length)
                length = bytesAvailable;
            requireBytes(length);
            if (!length)
                return;
            const end:Number = Number(offset) + length;
            if (end > uint.MAX_VALUE)
                throw new RangeError("Destination range is out of bounds");
            const source:Uint8Array = new Uint8Array(ba, _position, length);
            const destinationPosition:uint = bytes.position;
            if (end > bytes.length)
                bytes.length = uint(end);
            bytes._typedArray.set (source, offset);
            bytes.position = destinationPosition;
            _position += length;
        }

        public function writeUTFBytes(value:String):void
        {
            const bytes:Uint8Array = UTF8_ENCODER.encode(value);
            if (!bytes.length)
                return;
            reserveWrite(bytes.length);
            _typedArray.set (bytes, _position);
            _position += bytes.length;
        }

        public function readUTFBytes(length:uint):String
        {
            requireBytes(length);

            if (length <= 32)
            {
                const ascii:String = readShortASCII(length);
                if (ascii !== null)
                {
                    _position += length;
                    return ascii;
                }
            }

            const bytes:Uint8Array = new Uint8Array(ba, _position, length);
            _position += length;
            return UTF8_DECODER.decode(bytes);
        }

        // Return null without advancing the cursor when UTF-8 decoding is needed.
        private function readShortASCII(length:uint):String
        {
            const bytes:Uint8Array = _typedArray;
            var p:uint = _position;
            const end:uint = p + length;
            var result:String = "";
            while (p + 8 <= end)
            {
                const a:uint = bytes[p];
                const b:uint = bytes[p + 1];
                const c:uint = bytes[p + 2];
                const d:uint = bytes[p + 3];
                const e:uint = bytes[p + 4];
                const f:uint = bytes[p + 5];
                const g:uint = bytes[p + 6];
                const h:uint = bytes[p + 7];
                if ((a | b | c | d | e | f | g | h) & 0x80)
                    return null;
                result += String.fromCharCode(a, b, c, d, e, f, g, h);
                p += 8;
            }
            while (p < end)
            {
                const value:uint = bytes[p++];
                if (value & 0x80)
                    return null;
                result += String.fromCharCode(value);
            }
            return result;
        }

        [Inline]
        public function readPackedFixed32(out:Vector.<uint>, count:uint):void
        {
            if (count > bytesAvailable / 4)
                throw new IOError("End of file was encountered");
            const view:DataView = getDataView();
            var p:uint = _position;
            out.length = count;

            for (var i:uint = 0; i < count; i++, p += 4)
                out[i] = view.getUint32(p, true);

            _position = p;
        }

        [Inline]
        public function readPackedSfixed64(low:Vector.<uint>, high:Vector.<int>,
                count:uint):void
        {
            if (count > bytesAvailable / 8)
                throw new IOError("End of file was encountered");
            const view:DataView = getDataView();
            var p:uint = _position;
            low.length = count;
            high.length = count;

            for (var i:uint = 0; i < count; i++, p += 8)
            {
                low[i] = view.getUint32(p, true);
                high[i] = view.getInt32(p + 4, true);
            }

            _position = p;
        }

        [Inline]
        public function readPackedFloat(out:Vector.<Number>, count:uint):void
        {
            if (count > bytesAvailable / 4)
                throw new IOError("End of file was encountered");
            const view:DataView = getDataView();
            var p:uint = _position;
            out.length = count;

            for (var i:uint = 0; i < count; i++, p += 4)
                out[i] = view.getFloat32(p, true);

            _position = p;
        }

        public function readByte():int
        {
            requireBytes(1);
            const value:int = getDataView().getInt8(_position);
            _position += 1;
            return value;
        }

        public function writeByte(value:int):void
        {
            reserveWrite(1);
            _typedArray[_position++] = value;
        }

        public function readUnsignedByte():uint
        {
            if (_position >= _len)
                throw new IOError("End of file was encountered");
            return _typedArray[_position++];
        }

        public function readShort():int
        {
            requireBytes(2);
            const value:int = getDataView().getInt16(_position, _littleEndian);
            _position += 2;
            return value;
        }

        public function writeShort(value:int):void
        {
            reserveWrite(2);
            getDataView().setInt16(_position, value, _littleEndian);
            _position += 2;
        }

        public function readUnsignedShort():uint
        {
            requireBytes(2);
            const value:uint = getDataView().getUint16(_position, _littleEndian);
            _position += 2;
            return value;
        }

        public function readInt():int
        {
            requireBytes(4);
            const value:int = getDataView().getInt32(_position, _littleEndian);
            _position += 4;
            return value;
        }

        public function writeInt(value:int):void
        {
            reserveWrite(4);
            getDataView().setInt32(_position, value, _littleEndian);
            _position += 4;
        }

        public function readUnsignedInt():uint
        {
            requireBytes(4);
            const value:uint = getDataView().getUint32(_position, _littleEndian);
            _position += 4;
            return value;
        }

        public function writeUnsignedInt(value:uint):void
        {
            reserveWrite(4);
            getDataView().setUint32(_position, value, _littleEndian);
            _position += 4;
        }

        public function readFloat():Number
        {
            requireBytes(4);
            const value:Number = getDataView().getFloat32(_position, _littleEndian);
            _position += 4;
            return value;
        }

        public function writeFloat(value:Number):void
        {
            reserveWrite(4);
            getDataView().setFloat32(_position, value, _littleEndian);
            _position += 4;
        }

        public function readDouble():Number
        {
            requireBytes(8);
            const value:Number = getDataView().getFloat64(_position, _littleEndian);
            _position += 8;
            return value;
        }

        public function writeDouble(value:Number):void
        {
            reserveWrite(8);
            getDataView().setFloat64(_position, value, _littleEndian);
            _position += 8;
        }
    }
}
