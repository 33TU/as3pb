package as3pb.proto
{
    import flash.utils.ByteArray;

    /** Reusable decode state. Positions and limits are absolute offsets in the caller-owned buffer. */
    public final class UnpackContext
    {
        /** Absolute byte offset of the next read; advances as values are decoded. */
        public var position:uint;

        /**
         * Exclusive absolute end of the readable range, not its length or capacity.
         * Generated decoders temporarily narrow this limit for nested messages.
         */
        public var limit:uint;

        /**
         * Input buffer, or null when inactive. Must match the current domain-memory
         * binding while decoding, including string and byte-field reads. Capacity
         * must extend at least ten bytes beyond limit. Endian is unchanged.
         * Direct assignment does not bind domain memory or initialize restoration state.
         */
        public var bytes:ByteArray;

        /** Binding saved by begin, or the current buffer for an attached context. */
        internal var previous:ByteArray;
    }
}
