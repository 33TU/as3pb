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
        [Inline]
        public static function newByteArray():ByteArray
        {
            const buffer:ByteArray = new ByteArray();
            buffer.endian = Endian.LITTLE_ENDIAN;
            return buffer;
        }

        /**
         * Acquires a reusable message serialization buffer for the current nesting depth.
         */
        [Inline]
        public static function acquireMessageBuffer():ByteArray
        {
            const pool:Vector.<ByteArray> = MESSAGE_BUFFER_POOL;

            if (messageBufferDepth == pool.length)
                pool.push(newByteArray());

            return pool[messageBufferDepth++];
        }

        /**
         * Releases a message serialization buffer acquired by acquireMessageBuffer.
         */
        [Inline]
        public static function releaseMessageBuffer(buffer:ByteArray):void
        {
            if (messageBufferDepth != 0)
            {
                buffer.length = 0;
                messageBufferDepth--;
            }
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
