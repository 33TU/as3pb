package as3pb.types
{
    import google.protobuf.Timestamp;

    /** Conversion, validation, and normalization helpers for protobuf timestamps. */
    public final class TimestampUtils
    {
        private static const MIN_SECONDS:Number = -62135596800;
        private static const MAX_SECONDS:Number = 253402300799;
        private static const NANOS_PER_SECOND:Number = 1000000000;
        private static const NANOS_PER_MILLISECOND:Number = 1000000;

        /** Converts an AS3 Date to a protobuf Timestamp. */
        public static function fromDate(date:Date, dst:Timestamp = null):Timestamp
        {
            if (!date || isNaN(date.time))
                throw new ArgumentError("Invalid Date");

            const milliseconds:Number = date.time;
            const seconds:Number = Math.floor(milliseconds / 1000);
            if (seconds < MIN_SECONDS || seconds > MAX_SECONDS)
                throw new RangeError("Date is outside the protobuf Timestamp range");

            if (!dst)
                dst = new Timestamp();
            dst.seconds.copyFrom(Int64.fromNumber(seconds));
            dst.nanos = int((milliseconds - seconds * 1000) * NANOS_PER_MILLISECOND);
            return dst;
        }

        /** Converts a valid protobuf Timestamp to an AS3 Date, truncating sub-millisecond precision. */
        public static function toDate(timestamp:Timestamp):Date
        {
            if (!isValid(timestamp))
                throw new RangeError("Invalid protobuf Timestamp");

            return new Date(
                timestamp.seconds.toNumber() * 1000 +
                Math.floor(timestamp.nanos / NANOS_PER_MILLISECOND)
            );
        }

        /** Returns the current time as a protobuf Timestamp. */
        public static function now(dst:Timestamp = null):Timestamp
        {
            return fromDate(new Date(), dst);
        }

        /** Returns whether a timestamp is within the protobuf-defined range. */
        public static function isValid(timestamp:Timestamp):Boolean
        {
            if (!timestamp || !timestamp.seconds)
                return false;

            const seconds:Number = timestamp.seconds.toNumber();
            return seconds >= MIN_SECONDS && seconds <= MAX_SECONDS &&
                timestamp.nanos >= 0 && timestamp.nanos < NANOS_PER_SECOND;
        }

        /** Normalizes nanos into the range 0 through 999,999,999. */
        public static function normalize(timestamp:Timestamp):Timestamp
        {
            if (!timestamp || !timestamp.seconds)
                throw new ArgumentError("Timestamp is null");

            const carry:int = int(Math.floor(timestamp.nanos / NANOS_PER_SECOND));
            if (carry)
                timestamp.seconds.add(Int64.fromNumber(carry));
            timestamp.nanos = int(timestamp.nanos - carry * NANOS_PER_SECOND);
            return timestamp;
        }
    }
}
