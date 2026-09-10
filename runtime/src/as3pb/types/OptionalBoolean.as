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

        /**
         * Creates a copy of the source.
         * @param src Source to clone.
         * @return A new copy, or null when src is null.
         */
        [Inline]
        public static function clone(src:OptionalBoolean):OptionalBoolean
        {
            if (!src)
                return null;

            return new OptionalBoolean(src.value);
        }
    }
}
