package as3pb.wkt
{
    import as3pb.types.Int64;
    import google.protobuf.Duration;

    /**
     * Conversion, validation, and normalization helpers for protobuf durations.
     */
    public final class DurationUtils
    {
        private static const MAX_SECONDS:Number = 315576000000;
        private static const NANOS_PER_SECOND:Number = 1000000000;
        private static const NANOS_PER_MILLISECOND:Number = 1000000;

        /**
         * Converts milliseconds to a protobuf Duration.
         * @param milliseconds Milliseconds to convert.
         * @param dst Optional reusable destination.
         * @return The converted duration.
         */
        public static function fromMilliseconds(milliseconds:Number, dst:Duration = null):Duration
        {
            if (isNaN(milliseconds) || !isFinite(milliseconds))
                throw new ArgumentError("Invalid millisecond duration");

            const seconds:Number = milliseconds < 0
                ? Math.ceil(milliseconds / 1000)
                : Math.floor(milliseconds / 1000);
            if (seconds < -MAX_SECONDS || seconds > MAX_SECONDS)
                throw new RangeError("Duration is outside the protobuf range");

            if (!dst)
                dst = new Duration();
            dst.seconds.copyFrom(Int64.fromNumber(seconds));
            dst.nanos = int((milliseconds - seconds * 1000) * NANOS_PER_MILLISECOND);
            return dst;
        }

        /**
         * Converts a valid protobuf Duration to milliseconds.
         * @param duration Duration to convert.
         * @return The duration in milliseconds.
         */
        public static function toMilliseconds(duration:Duration):Number
        {
            if (!isValid(duration))
                throw new RangeError("Invalid protobuf Duration");

            return duration.seconds.toNumber() * 1000 +
                duration.nanos / NANOS_PER_MILLISECOND;
        }

        /**
         * Returns whether a duration follows the protobuf range and sign rules.
         * @param duration Duration to validate.
         * @return True when the duration is valid.
         */
        public static function isValid(duration:Duration):Boolean
        {
            if (!duration || !duration.seconds)
                return false;

            const seconds:Number = duration.seconds.toNumber();
            if (seconds < -MAX_SECONDS || seconds > MAX_SECONDS ||
                duration.nanos <= -NANOS_PER_SECOND || duration.nanos >= NANOS_PER_SECOND)
                return false;

            return seconds == 0 || duration.nanos == 0 ||
                (seconds < 0) == (duration.nanos < 0);
        }

        /**
         * Normalizes nanos and makes their sign consistent with seconds.
         * @param duration Duration to normalize in place.
         * @return The normalized duration.
         */
        public static function normalize(duration:Duration):Duration
        {
            if (!duration || !duration.seconds)
                throw new ArgumentError("Duration is null");

            const carry:int = int(duration.nanos / NANOS_PER_SECOND);
            if (carry)
                duration.seconds.add(Int64.fromNumber(carry));
            duration.nanos = int(duration.nanos - carry * NANOS_PER_SECOND);

            if (!duration.seconds.isZero())
            {
                if (duration.seconds.isNegative() && duration.nanos > 0)
                {
                    duration.seconds.addUint(1);
                    duration.nanos -= NANOS_PER_SECOND;
                }
                else if (!duration.seconds.isNegative() && duration.nanos < 0)
                {
                    duration.seconds.subUint(1);
                    duration.nanos += NANOS_PER_SECOND;
                }
            }
            return duration;
        }
    }
}
