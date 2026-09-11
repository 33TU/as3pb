package as3pb.proto
{
    import flash.utils.ByteArray;

    /** Reusable encode state. Positions are absolute offsets in the caller-owned buffer. */
    public final class PackContext
    {
        /** Absolute byte offset of the next write; advances as values are encoded. */
        public var position:uint;

        /**
         * Output buffer, or null when inactive. Must match the current domain-memory
         * binding while encoding. Its length is capacity, not the encoded length;
         * writers grow it as needed, up to 0x7fffffff bytes. Endian is unchanged.
         * Direct assignment does not bind domain memory or initialize restoration state.
         */
        public var bytes:ByteArray;

        /** Binding saved by begin, or the current buffer for an attached context. */
        internal var previous:ByteArray;
    }
}
