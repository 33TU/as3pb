package as3pb.types
{
    /** Nullable presence wrapper for floating-point protobuf values. */
    public final class OptionalNumber
    {
        public var value:Number;

        public function OptionalNumber(value:Number = 0.0)
        {
            this.value = value;
        }
    }
}
