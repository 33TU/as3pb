package as3pb.types
{
    /**
     * Nullable presence wrapper for signed 32-bit protobuf values and enums.
     */
    public final class OptionalInt
    {
        /**
         * The present signed 32-bit value.
         */
        public var value:int;

        /**
         * Creates a present optional signed 32-bit value.
         * @param value Initial value.
         */
        public function OptionalInt(value:int = 0)
        {
            this.value = value;
        }

        /**
         * Creates a copy of the source.
         * @param src Source to clone.
         * @return A new copy, or null when src is null.
         */
        [Inline]
        public static function clone(src:OptionalInt):OptionalInt
        {
            if (!src)
                return null;

            return new OptionalInt(src.value);
        }
    }
}
