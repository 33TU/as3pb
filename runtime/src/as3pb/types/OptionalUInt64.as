package as3pb.types
{
    /** Nullable presence wrapper for unsigned 64-bit protobuf values. */
    public final class OptionalUInt64
    {
        public var value:UInt64;

        public function OptionalUInt64(value:UInt64 = null)
        {
            this.value = value ? value : new UInt64();
        }
    }
}
