package as3pb.types
{
    /** Nullable presence wrapper for floating-point protobuf values. */
    public final class OptionalNumber
    {
        /** The present floating-point value. */
        public var value:Number;

        /** Creates a present optional floating-point value. */
        public function OptionalNumber(value:Number = 0.0)
        {
            this.value = value;
        }
    }
}
