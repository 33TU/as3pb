package as3pb.types
{
    /** Nullable presence wrapper for signed 64-bit protobuf values. */
    public final class OptionalInt64
    {
        /** The present signed 64-bit value. */
        public var value:Int64;

        /** Creates a present optional signed 64-bit value. */
        public function OptionalInt64(value:Int64 = null)
        {
            this.value = value ? value : new Int64();
        }
    }
}
