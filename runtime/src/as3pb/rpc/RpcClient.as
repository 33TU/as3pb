package as3pb.rpc
{
    import flash.utils.ByteArray;

    /**
     * Base class for generated RPC service clients.
     */
    public class RpcClient
    {
        /**
         * Base URL of the RPC server.
         * Example: https://api.example.com
         */
        protected var $baseUrl:String;

        /**
         * Content type for RPC requests. Default is "application/proto".
         */
        protected var $contentType:String;

        /**
         * Additional headers for RPC requests. Array of URLRequestHeader. Default is empty array.
         */
        protected var $headers:Array;

        /**
         * HTTP transport used for RPC calls. Default is an new instance of HttpTransport.
         */
        protected var $transport:HttpTransport;

        /**
         * Creates a new RpcClient instance.
         * @param baseUrl baseUrl value.
         * @param contentType contentType value.
         * @param headers headers value.
         * @param transport transport value.
         */
        public function RpcClient(
                baseUrl:String,
                contentType:String = "application/proto",
                headers:Array = null,
                transport:HttpTransport = null
            )
        {
            this.$baseUrl = baseUrl;
            this.$contentType = contentType;
            this.$headers = headers || [];
            this.$transport = transport || new HttpTransport();
        }

        /**
         * Executes a unary RPC call.
         *
         * @param path The RPC method path (e.g., "/example.ExampleService/ExampleMethod")
         * @param payload The serialized protobuf request payload.
         * @param onComplete Called with the response ByteArray when the request completes successfully.
         * @param onError Called with the error event for network, security, or timeout failures.
         */
        protected function $callUnary(
                path:String,
                payload:ByteArray,
                onComplete:Function,
                onError:Function
            ):void
        {
            $transport.send(
                    $baseUrl + path,
                    $contentType,
                    $headers,
                    payload,
                    onComplete,
                    onError
                );
        }
    }
}
