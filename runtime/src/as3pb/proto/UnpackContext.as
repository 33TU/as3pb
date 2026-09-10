package as3pb.proto
{
    import flash.utils.ByteArray;
    import flash.utils.Endian;
    import flash.system.ApplicationDomain;

    /** Reusable decode storage. Positions and limits are relative to the copied input range. */
    public final class UnpackContext
    {
        private static const SCRATCH:ByteArray = new ByteArray();
        {
            SCRATCH.endian = Endian.LITTLE_ENDIAN;
            SCRATCH.length = ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH;
        }

        public var position:uint;
        public var limit:uint;
        internal var start:uint;
        internal var bytes:ByteArray;
        internal var previous:ByteArray;
        internal const memory:ByteArray = SCRATCH;
    }
}
