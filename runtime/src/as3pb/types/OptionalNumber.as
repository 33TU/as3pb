package as3pb.types
{
    /**
     * Nullable presence wrapper for floating-point protobuf values.
     */
    public final class OptionalNumber
    {
        /**
         * The present floating-point value.
         */
        public var value:Number;

        /**
         * Creates a present optional floating-point value.
         * @param value Initial value.
         */
        public function OptionalNumber(value:Number = 0.0)
        {
            this.value = value;
        }

        /**
         * Creates a copy of the source.
         * @param src Source to clone.
         * @return A new copy, or null when src is null.
         */
        [Inline]
        public static function clone(src:OptionalNumber):OptionalNumber
        {
            if (!src)
                return null;

            return new OptionalNumber(src.value);
        }
    }
}
