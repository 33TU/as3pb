package as3pb.proto
{
    import flash.utils.Endian;
    import flash.utils.ByteArray;

    /**
     * Utility class for managing ByteArray buffers used in Protocol Buffers serialization and deserialization. (used by generated code)
     */
    public final class Buffers
    {
        /**
         * Shared little-endian buffer for reuse in serialization to reduce allocations.
         * Used for: bytes fields, string fields and packed fields.
         */
        public static const SHARED_BUFFER:ByteArray = newByteArray();

        /**
         * Stack of reusable ByteArray instances for nested message serialization.
         */
        private static const MESSAGE_BUFFER_POOL:Vector.<ByteArray> = new Vector.<ByteArray>();

        /**
         * Current depth of nested message serialization, used to manage the MESSAGE_BUFFER_POOL.
         */
        private static var messageBufferDepth:uint = 0;

        /**
         * Creates a new ByteArray instance with little-endian byte order.
         */
        public static function newByteArray():ByteArray
        {
            const buffer:ByteArray = new ByteArray();
            buffer.endian = Endian.LITTLE_ENDIAN;
            return buffer;
        }

        /**
         * Acquires a reusable message serialization buffer for the current nesting depth.
         */
        public static function acquireMessageBuffer():ByteArray
        {
            if (messageBufferDepth == MESSAGE_BUFFER_POOL.length)
                MESSAGE_BUFFER_POOL.push(newByteArray());

            const buffer:ByteArray = MESSAGE_BUFFER_POOL[messageBufferDepth++];
            buffer.length = 0;
            return buffer;
        }

        /**
         * Releases a message serialization buffer acquired by acquireMessageBuffer.
         */
        public static function releaseMessageBuffer(buffer:ByteArray):void
        {
            if (messageBufferDepth == 0)
                return;

            messageBufferDepth--;
            buffer.length = 0;
        }

        /**
         * Clears the shared buffers and their resources.
         * Calling this method explicitly frees up the memory used by the ByteArray instances.
         */
        public static function clearBuffers():void
        {
            SHARED_BUFFER.clear();

            for each (var buffer:ByteArray in MESSAGE_BUFFER_POOL)
                buffer.clear();

            messageBufferDepth = 0;
        }
    }
}
