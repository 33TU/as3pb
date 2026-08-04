package as3pb.rpc
{
    import flash.events.Event;
    import flash.events.HTTPStatusEvent;
    import flash.events.IOErrorEvent;
    import flash.events.SecurityErrorEvent;
    import flash.events.TimerEvent;
    import flash.net.URLLoader;
    import flash.net.URLLoaderDataFormat;
    import flash.net.URLRequest;
    import flash.net.URLRequestMethod;
    import flash.utils.ByteArray;
    import flash.utils.Endian;
    import flash.utils.Timer;

    /**
     * Represents one active HTTP request and allows it to be cancelled.
     */
    public final class HttpRequest
    {
        private var request:URLRequest;
        private var loader:URLLoader;
        private var timer:Timer;
        private var timeoutMilliseconds:uint;
        private var onComplete:Function;
        private var onError:Function;
        private var _settled:Boolean;
        private var _httpStatus:int;

        /**
         * Creates a request owned by HttpTransport.
         * @param url Endpoint URL.
         * @param contentType HTTP content type.
         * @param headers HTTP request headers.
         * @param payload Serialized request payload.
         * @param timeoutMilliseconds Maximum request duration; zero disables the timeout.
         * @param onComplete Success callback.
         * @param onError Failure callback.
         */
        public function HttpRequest(
                url:String,
                contentType:String,
                headers:Array,
                payload:ByteArray,
                timeoutMilliseconds:uint,
                onComplete:Function,
                onError:Function
            )
        {
            request = new URLRequest(url);
            request.method = URLRequestMethod.POST;
            request.requestHeaders = headers;
            request.contentType = contentType;
            request.data = payload;

            loader = new URLLoader();
            loader.dataFormat = URLLoaderDataFormat.BINARY;
            this.timeoutMilliseconds = timeoutMilliseconds;
            this.onComplete = onComplete;
            this.onError = onError;
        }

        /**
         * Returns whether this request has completed, failed, timed out, or been cancelled.
         * @return True after the request settles.
         */
        public function get settled():Boolean
        {
            return _settled;
        }

        /**
         * Returns the latest HTTP status code, or zero when none was received.
         * @return The HTTP status code.
         */
        public function get httpStatus():int
        {
            return _httpStatus;
        }

        /**
         * Cancels this request and reports cancellation through its error callback.
         * @return True when this call cancelled the request; false if it was already settled.
         */
        public function cancel():Boolean
        {
            if (!trySettle())
                return false;

            closeLoader();
            notifyError(new IOErrorEvent(
                        IOErrorEvent.IO_ERROR,
                        false,
                        false,
                        "HTTP request cancelled"
                    ));
            return true;
        }

        /**
         * Settles this request exactly once and releases its resources.
         * @return True for the first caller, or false after the request has settled.
         */
        [Inline]
        private function trySettle():Boolean
        {
            if (_settled)
                return false;

            _settled = true;
            cleanup();
            return true;
        }

        /**
         * Releases payload, loader, and callback references after settlement.
         */
        [Inline]
        private function releaseReferences():void
        {
            request = null;
            loader = null;
            onComplete = null;
            onError = null;
        }

        /**
         * Closes the loader, ignoring races with request completion.
         */
        private function closeLoader():void
        {
            try
            {
                loader.close();
            }
            catch (error:Error)
            {
                // The request may have completed while cancellation was queued.
            }
        }

        /**
         * Starts the request and its optional timeout.
         */
        internal function start():void
        {
            loader.addEventListener(Event.COMPLETE, completeHandler);
            loader.addEventListener(HTTPStatusEvent.HTTP_STATUS, httpStatusHandler);
            loader.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
            loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);

            if (timeoutMilliseconds)
            {
                timer = new Timer(timeoutMilliseconds, 1);
                timer.addEventListener(TimerEvent.TIMER_COMPLETE, timeoutHandler);
                timer.start();
            }

            try
            {
                loader.load(request);
            }
            catch (error:Error)
            {
                trySettle();
                releaseReferences();
                throw error;
            }
        }

        /**
         * Removes listeners and stops the timeout.
         */
        private function cleanup():void
        {
            loader.removeEventListener(Event.COMPLETE, completeHandler);
            loader.removeEventListener(HTTPStatusEvent.HTTP_STATUS, httpStatusHandler);
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
         * Invokes the success callback without retaining request resources afterward.
         * @param responseBytes Serialized response payload.
         */
        private function notifyComplete(responseBytes:ByteArray):void
        {
            const callback:Function = onComplete;
            releaseReferences();
            callback(responseBytes);
        }

        /**
         * Invokes the error callback without retaining request resources afterward.
         * @param error Failure value to report.
         */
        private function notifyError(error:*):void
        {
            const callback:Function = onError;
            releaseReferences();
            callback(error);
        }

        /**
         * Records the HTTP status code for error reporting.
         * @param event Status event from URLLoader.
         */
        private function httpStatusHandler(event:HTTPStatusEvent):void
        {
            _httpStatus = event.status;
        }

        /**
         * Handles a successful HTTP response.
         * @param event Completion event from URLLoader.
         */
        private function completeHandler(event:Event):void
        {
            if (!trySettle())
                return;

            if (_httpStatus >= 400)
            {
                notifyError(new IOErrorEvent(
                            IOErrorEvent.IO_ERROR,
                            false,
                            false,
                            "HTTP request failed with status " + _httpStatus
                        ));
                return;
            }

            const responseBytes:ByteArray = ByteArray(loader.data);
            responseBytes.endian = Endian.LITTLE_ENDIAN;
            notifyComplete(responseBytes);
        }

        /**
         * Handles an HTTP I/O failure.
         * @param event I/O error event from URLLoader.
         */
        private function ioErrorHandler(event:IOErrorEvent):void
        {
            if (!trySettle())
                return;

            if (_httpStatus)
            {
                notifyError(new IOErrorEvent(
                            IOErrorEvent.IO_ERROR,
                            false,
                            false,
                            event.text + " (HTTP status " + _httpStatus + ")",
                            event.errorID
                        ));
                return;
            }
            notifyError(event);
        }

        /**
         * Handles a Flash security sandbox failure.
         * @param event Security error event from URLLoader.
         */
        private function securityErrorHandler(event:SecurityErrorEvent):void
        {
            if (!trySettle())
                return;
            notifyError(event);
        }

        /**
         * Cancels a request that exceeded its configured duration.
         * @param event Timer completion event.
         */
        private function timeoutHandler(event:TimerEvent):void
        {
            if (!trySettle())
                return;

            closeLoader();
            notifyError(new IOErrorEvent(
                        IOErrorEvent.IO_ERROR,
                        false,
                        false,
                        "HTTP request timed out after " + timeoutMilliseconds + " ms"
                    ));
        }
    }
}
