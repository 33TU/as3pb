package flash.errors
{
    /**
     * Royale compatibility implementation of flash.errors.IOError.
     */
    public class IOError extends Error
    {
        public function IOError(message:String = "")
        {
            super(message);
        }
    }
}
