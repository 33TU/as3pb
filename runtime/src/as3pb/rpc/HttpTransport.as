package as3pb.rpc
{
    import flash.utils.ByteArray;

    /**
     * Performs HTTP POST requests for protobuf RPC calls.
     */
    public final class HttpTransport
    {
        /**
         * Default request duration in milliseconds; zero disables the timeout.
         */
        public var defaultTimeoutMilliseconds:uint;

        /**
         * Creates an HTTP transport.
         * @param defaultTimeoutMilliseconds Default request duration; zero disables the timeout.
         */
        public function HttpTransport(defaultTimeoutMilliseconds:uint = 0)
        {
            this.defaultTimeoutMilliseconds = defaultTimeoutMilliseconds;
        }

        /**
         * Sends a protobuf payload to the specified URL using HTTP POST.
         * @param url The endpoint URL to which the request will be sent.
         * @param contentType HTTP content type for the request.
         * @param headers HTTP request headers.
         * @param payload The serialized protobuf request payload as a ByteArray.
         * @param onComplete Callback invoked when the request completes successfully.
         * @param onError Callback invoked for network, security, cancellation, or timeout failures.
         * @param timeoutMilliseconds Request timeout; zero uses the transport default.
         * @return The active request handle.
         */
        public function send(
                url:String,
                contentType:String,
                headers:Array,
                payload:ByteArray,
                onComplete:Function,
                onError:Function,
                timeoutMilliseconds:uint = 0
            ):HttpRequest
        {
            const result:HttpRequest = new HttpRequest(
                    url,
                    contentType,
                    headers,
                    payload,
                    timeoutMilliseconds || defaultTimeoutMilliseconds,
                    onComplete,
                    onError
                );
            result.start();
            return result;
        }
    }
}
