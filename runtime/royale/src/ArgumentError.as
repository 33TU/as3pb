package
{
    /** Royale implementation of Flash's globally available ArgumentError. */
    public class ArgumentError extends Error
    {
        public function ArgumentError(message:String = "")
        {
            super(message);
            // JavaScript Error returns a new object when called by Royale's
            // ES5 superclass helper, so preserve the message on this instance.
            this.message = message;
            name = "ArgumentError";
        }
    }
}
