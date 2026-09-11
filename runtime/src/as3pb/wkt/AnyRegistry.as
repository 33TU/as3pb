package as3pb.wkt
{
    import flash.utils.ByteArray;
    import google.protobuf.Any;

    /**
     * Explicit registry for packing and unpacking protobuf Any values.
     */
    public final class AnyRegistry
    {
        private static const DESERIALIZERS:Object = {};
        private static const SERIALIZERS:Object = {};

        /**
         * Registers either or both generated codecs, preserving codecs omitted from this call.
         * @param typeUrl The canonical protobuf type URL.
         * @param deserializer The generated deserializeBytes function, or null.
         * @param serializer The generated serializeBytes function, or null.
         */
        public static function register(typeUrl:String, deserializer:Function, serializer:Function):void
        {
            if (!typeUrl)
                return;
            if (deserializer)
                DESERIALIZERS[typeUrl] = deserializer;
            if (serializer)
                SERIALIZERS[typeUrl] = serializer;
        }

        /**
         * Returns whether a type URL has a serializer for packing Any values.
         * @param typeUrl The protobuf type URL to find.
         * @return True when a serializer is registered.
         */
        public static function hasSerializer(typeUrl:String):Boolean
        {
            return !!SERIALIZERS[typeUrl];
        }

        /**
         * Returns whether a type URL has a deserializer for unpacking Any values.
         * @param typeUrl The protobuf type URL to find.
         * @return True when a deserializer is registered.
         */
        public static function hasDeserializer(typeUrl:String):Boolean
        {
            return !!DESERIALIZERS[typeUrl];
        }

        /**
         * Serializes a message into an Any envelope.
         * @param typeUrl The registered protobuf type URL.
         * @param message The message to serialize.
         * @param dst Optional reusable destination envelope.
         * @return The packed envelope.
         */
        public static function pack(typeUrl:String, message:Object, dst:Any = null):Any
        {
            const serializer:Function = SERIALIZERS[typeUrl];
            if (!serializer)
                throw new ArgumentError("No serializer registered for protobuf type URL: " + typeUrl);

            if (!dst)
                dst = new Any();
            else
                Any.reset(dst);

            dst.typeUrl = typeUrl;
            serializer(message, dst.value);
            dst.value.position = 0;
            return dst;
        }

        /**
         * Deserializes the message stored in an Any envelope.
         * @param src The envelope to unpack.
         * @param dst Optional reusable destination message.
         * @return The unpacked message.
         */
        public static function unpack(src:Any, dst:Object = null):Object
        {
            const deserializer:Function = DESERIALIZERS[src.typeUrl];
            if (!deserializer)
                throw new ArgumentError("No deserializer registered for protobuf type URL: " + src.typeUrl);

            const value:ByteArray = src.value;
            value.position = 0;
            return deserializer(value, dst, value.length);
        }
    }
}
