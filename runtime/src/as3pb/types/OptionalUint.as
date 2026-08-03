package as3pb.types
{
    /** Nullable presence wrapper for unsigned 32-bit protobuf values. */
    public final class OptionalUint
    {
        public var value:uint;

        public function OptionalUint(value:uint = 0)
        {
            this.value = value;
        }
    }
}
