package as3pb.rpc
{
    import flash.net.URLRequest;
    import flash.net.URLLoader;
    import flash.net.URLLoaderDataFormat;
    import flash.net.URLRequestMethod;
    import flash.events.Event;
    import flash.events.IOErrorEvent;
    import flash.events.SecurityErrorEvent;
    import flash.events.TimerEvent;
    import flash.utils.ByteArray;
    import flash.utils.Endian;
    import flash.utils.Timer;

    /**
     * Performs HTTP POST requests for protobuf RPC calls.
     */
    public final class HttpTransport
    {
        /**
         * Maximum request duration in milliseconds; zero disables the timeout.
         */
        public var timeoutMilliseconds:uint;

        /**
         * Creates an HTTP transport.
         * @param timeoutMilliseconds Maximum request duration; zero disables the timeout.
         */
        public function HttpTransport(timeoutMilliseconds:uint = 0)
        {
            this.timeoutMilliseconds = timeoutMilliseconds;
        }

        /**
         * Sends a protobuf payload to the specified URL using HTTP POST.
         *
         * @param url The endpoint URL to which the request will be sent.
         * @param contentType HTTP content type for the request.
         * @param headers HTTP request headers.
         * @param payload The serialized protobuf request payload as a ByteArray.
         * @param onComplete Callback invoked when the request completes successfully.
         * @param onError Callback invoked for network, security, or timeout failures.
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
            const requestTimeout:uint = timeoutMilliseconds;
            var timer:Timer = null;

            /**
             * Removes all event listeners from the active URLLoader.
             */
            function cleanup():void
            {
                loader.removeEventListener(Event.COMPLETE, completeHandler);
                loader.removeEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
                loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
                if (timer)
                {
                    timer.stop();
                    timer.removeEventListener(TimerEvent.TIMER_COMPLETE, timeoutHandler);
                    timer = null;
                }
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

            /**
             * Cancels a request that exceeded its configured duration.
             * @param e Timer completion event.
             */
            function timeoutHandler(e:TimerEvent):void
            {
                cleanup();
                try
                {
                    loader.close();
                }
                catch (error:Error)
                {
                    // The request may have completed while the timeout event was queued.
                }
                onError(new IOErrorEvent(
                        IOErrorEvent.IO_ERROR,
                        false,
                        false,
                        "HTTP request timed out after " + requestTimeout + " ms"
                    ));
            }

            loader.addEventListener(Event.COMPLETE, completeHandler);
            loader.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
            loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);

            if (requestTimeout)
            {
                timer = new Timer(requestTimeout, 1);
                timer.addEventListener(TimerEvent.TIMER_COMPLETE, timeoutHandler);
                timer.start();
            }
            loader.load(request);
        }
    }
}
