package as3pb.types
{
    /** Nullable presence wrapper for signed 64-bit protobuf values. */
    public final class OptionalInt64
    {
        public var value:Int64;

        public function OptionalInt64(value:Int64 = null)
        {
            this.value = value ? value : new Int64();
        }
    }
}
