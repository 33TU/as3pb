package as3pb.rpc
{
    import flash.utils.ByteArray;
    import flash.utils.Endian;

    /**
     * Utility class that is used internally to create buffers for deserialization and serialization. (used by generated code)
     */
    public final class BufferPool
    {
        /**
         * Maximum number of buffers to keep in the pool to prevent unbounded memory usage.
         */
        private static const MAX_POOL_SIZE:uint = 128;

        /**
         * Shared little-endian buffer for reuse in serialization to reduce allocations.
         */
        private static const pool:Vector.<ByteArray> = new Vector.<ByteArray>();

        /**
         * Acquires a ByteArray from the pool or creates a new one if the pool is empty.
         */
        public static function acquire():ByteArray
        {
            if (pool.length === 0)
            {
                const buffer:ByteArray = new ByteArray();
                buffer.endian = Endian.LITTLE_ENDIAN;
                return buffer;
            }

            return pool.pop();
        }

        /**
         * Releases a ByteArray back to the pool for reuse. The buffer's length is reset to 0 before being added back to the pool.
         * Buffer will be discarded if the pool has reached its maximum size to prevent unbounded memory usage.
         * @param buffer The ByteArray to release back to the pool
         */
        public static function release(buffer:ByteArray):void
        {
            if (pool.length < MAX_POOL_SIZE)
            {
                buffer.length = 0;
                pool.push(buffer);
            }
        }

        /**
         * Clears the pooled buffers and their resources.
         * Calling this method explicitly frees up the memory used by the ByteArray instances.
         */
        public static function clearBuffers():void
        {
            for each (var buffer:ByteArray in pool)
                buffer.clear();

            pool.length = 0;
        }
    }
}