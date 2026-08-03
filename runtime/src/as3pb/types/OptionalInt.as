package as3pb.types
{
    /** Nullable presence wrapper for signed 32-bit protobuf values and enums. */
    public final class OptionalInt
    {
        /** The present signed 32-bit value. */
        public var value:int;

        /** Creates a present optional signed 32-bit value. */
        public function OptionalInt(value:int = 0)
        {
            this.value = value;
        }
    }
}
