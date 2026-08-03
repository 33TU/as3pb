package as3pb.types
{
    /** Nullable presence wrapper for boolean protobuf values. */
    public final class OptionalBoolean
    {
        /** The present boolean value. */
        public var value:Boolean;

        /** Creates a present optional boolean value. */
        public function OptionalBoolean(value:Boolean = false)
        {
            this.value = value;
        }
    }
}
