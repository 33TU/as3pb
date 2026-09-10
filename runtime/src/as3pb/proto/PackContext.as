package as3pb.proto
{
    import flash.utils.ByteArray;

    /** Reusable encode state. Positions are absolute offsets in the caller-owned buffer. */
    public final class PackContext
    {
        public var position:uint;
        internal var bytes:ByteArray;
        internal var previous:ByteArray;
    }
}
