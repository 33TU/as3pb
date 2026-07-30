package as3pb.types
{
    import flash.utils.ByteArray;

    import as3pb.proto.Buffers;
    import as3pb.proto.Deserialize;
    import as3pb.proto.Serialize;

    /**
     * Protobuf Any wire envelope.
     */
    public final class Any
    {
        public static const TYPE_URL:String = "type.googleapis.com/google.protobuf.Any";

        /**
         * Canonical URL identifying the embedded message type.
         */
        public var typeUrl:String = "";

        /**
         * Serialized protobuf message bytes.
         */
        public var value:ByteArray = Buffers.newByteArray();

        /**
         * Resets the envelope to its default values.
         * @param msg The envelope to reset.
         */
        [Inline]
        public static function reset(msg:Any):void
        {
            msg.typeUrl = "";
            msg.value.length = 0;
        }

        /**
         * Deserializes an Any envelope from protobuf wire format.
         * @param src The source ByteArray.
         * @param dst Optional reusable destination envelope.
         * @param limit Optional end position; zero means the remaining bytes.
         * @return The deserialized envelope.
         */
        public static function deserializeBytes(src:ByteArray, dst:Any = null, limit:uint = 0):Any
        {
            if (!dst)
                dst = new Any();
            else
                reset(dst);

            const end:uint = limit ? limit : src.position + src.bytesAvailable;
            while (src.position < end)
            {
                const tag:uint = Deserialize.readVarint32(src);
                switch (tag)
                {
                    case 10:
                        dst.typeUrl = src.readUTFBytes(Deserialize.readVarint32(src));
                        break;
                    case 18:
                        src.readBytes(dst.value, 0, Deserialize.readVarint32(src));
                        break;
                    default:
                        Deserialize.skipField(src, tag & 7);
                        break;
                }
            }

            if (src.position > end)
                throw new Error("Truncated protobuf Any");

            return dst;
        }

        /**
         * Serializes an Any envelope to protobuf wire format.
         * @param src The envelope to serialize.
         * @param dst The destination ByteArray.
         */
        public static function serializeBytes(src:Any, dst:ByteArray):void
        {
            if (src.typeUrl)
            {
                dst.writeByte(10);
                Serialize.writeString(dst, src.typeUrl, Buffers.SHARED_BUFFER);
            }
            if (src.value.length)
            {
                dst.writeByte(18);
                Serialize.writeBytes(dst, src.value);
            }
        }
    }
}
