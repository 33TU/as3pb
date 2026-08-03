package as3pb.types
{
    /** Nullable presence wrapper for signed 32-bit protobuf values and enums. */
    public final class OptionalInt
    {
        public var value:int;

        public function OptionalInt(value:int = 0)
        {
            this.value = value;
        }
    }
}
