package as3pb.rpc
{
    import flash.net.URLRequest;
    import flash.net.URLLoader;
    import flash.net.URLLoaderDataFormat;
    import flash.net.URLRequestMethod;
    import flash.events.Event;
    import flash.events.IOErrorEvent;
    import flash.events.SecurityErrorEvent;
    import flash.utils.ByteArray;
    import flash.utils.Endian;

    /**
     * Performs HTTP POST requests for protobuf RPC calls.
     */
    public final class HttpTransport
    {
        /**
         * Sends a protobuf payload to the specified URL using HTTP POST.
         *
         * @param url The endpoint URL to which the request will be sent.
         * @param payload The serialized protobuf request payload as a ByteArray.
         * @param onComplete Callback invoked when the request completes successfully.
         * @param onError Callback invoked if the request fails due to a network or security error.
         */
        public function send(
                url:String,
                contentType:String,
                headers:Array,
                payload:ByteArray,
                onComplete:Function,
                onError:Function
            ):void
        {
            const request:URLRequest = new URLRequest(url);
            request.method = URLRequestMethod.POST;
            request.requestHeaders = headers;
            request.contentType = contentType;
            request.data = payload;

            const loader:URLLoader = new URLLoader();
            loader.dataFormat = URLLoaderDataFormat.BINARY;

            /**
             * Removes all event listeners from the active URLLoader.
             */
            function cleanup():void
            {
                loader.removeEventListener(Event.COMPLETE, completeHandler);
                loader.removeEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
                loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
            }

            /**
             * Handles a successful HTTP response.
             * @param e Completion event from URLLoader.
             */
            function completeHandler(e:Event):void
            {
                cleanup();
                const responseBytes:ByteArray = ByteArray(loader.data);
                responseBytes.endian = Endian.LITTLE_ENDIAN;
                onComplete(responseBytes);
            }

            /**
             * Handles an HTTP I/O failure.
             * @param e I/O error event from URLLoader.
             */
            function ioErrorHandler(e:IOErrorEvent):void
            {
                cleanup();
                onError(e);
            }

            /**
             * Handles a Flash security sandbox failure.
             * @param e Security error event from URLLoader.
             */
            function securityErrorHandler(e:SecurityErrorEvent):void
            {
                cleanup();
                onError(e);
            }

            loader.addEventListener(Event.COMPLETE, completeHandler);
            loader.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
            loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);

            loader.load(request);
        }
    }
}
