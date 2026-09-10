package as3pb.proto
{
    import flash.utils.ByteArray;

    /** Reusable decode state. Positions and limits are absolute offsets in the caller-owned buffer. */
    public final class UnpackContext
    {
        public var position:uint;
        public var limit:uint;
        internal var bytes:ByteArray;
        internal var previous:ByteArray;
    }
}
