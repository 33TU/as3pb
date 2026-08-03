package as3pb.types
{
    /** Nullable presence wrapper for unsigned 64-bit protobuf values. */
    public final class OptionalUInt64
    {
        /** The present unsigned 64-bit value. */
        public var value:UInt64;

        /** Creates a present optional unsigned 64-bit value. */
        public function OptionalUInt64(value:UInt64 = null)
        {
            this.value = value ? value : new UInt64();
        }
    }
}
