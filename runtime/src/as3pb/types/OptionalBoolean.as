package as3pb.types
{
    /**
     * Nullable presence wrapper for boolean protobuf values.
     */
    public final class OptionalBoolean
    {
        /**
         * The present boolean value.
         */
        public var value:Boolean;

        /**
         * Creates a present optional boolean value.
         * @param value Initial value.
         */
        public function OptionalBoolean(value:Boolean = false)
        {
            this.value = value;
        }
    }
}
