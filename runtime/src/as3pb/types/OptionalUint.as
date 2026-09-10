package as3pb.types
{
    /**
     * Nullable presence wrapper for unsigned 32-bit protobuf values.
     */
    public final class OptionalUint
    {
        /**
         * The present unsigned 32-bit value.
         */
        public var value:uint;

        /**
         * Creates a present optional unsigned 32-bit value.
         * @param value Initial value.
         */
        public function OptionalUint(value:uint = 0)
        {
            this.value = value;
        }

        /**
         * Creates a copy of the source.
         * @param src Source to clone.
         * @return A new copy, or null when src is null.
         */
        [Inline]
        public static function clone(src:OptionalUint):OptionalUint
        {
            if (!src)
                return null;

            return new OptionalUint(src.value);
        }
    }
}
