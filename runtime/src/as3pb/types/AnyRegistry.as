package as3pb.types
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
         * Registers generated codec functions for a protobuf type URL.
         * @param typeUrl The canonical protobuf type URL.
         * @param deserializer The generated deserializeBytes function.
         * @param serializer The generated serializeBytes function.
         */
        public static function register(typeUrl:String, deserializer:Function, serializer:Function):void
        {
            if (typeUrl && deserializer && serializer)
            {
                DESERIALIZERS[typeUrl] = deserializer;
                SERIALIZERS[typeUrl] = serializer;
            }
        }

        /**
         * Returns whether a type URL has registered codec functions.
         * @param typeUrl The protobuf type URL to find.
         * @return True when both codec functions are registered.
         */
        public static function isRegistered(typeUrl:String):Boolean
        {
            return DESERIALIZERS[typeUrl] && SERIALIZERS[typeUrl];
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
            if (serializer == null)
                throw new ArgumentError("Unregistered protobuf type URL: " + typeUrl);

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
            if (deserializer == null)
                throw new ArgumentError("Unregistered protobuf type URL: " + src.typeUrl);

            const value:ByteArray = src.value;
            value.position = 0;
            return deserializer(value, dst, value.length);
        }
    }
}
