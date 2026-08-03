package as3pb.types
{
    /** Nullable presence wrapper for boolean protobuf values. */
    public final class OptionalBoolean
    {
        public var value:Boolean;

        public function OptionalBoolean(value:Boolean = false)
        {
            this.value = value;
        }
    }
}
