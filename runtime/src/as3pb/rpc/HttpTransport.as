package as3pb.rpc
{
    import flash.utils.ByteArray;

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
            new HttpRequestContext(
                    url,
                    contentType,
                    headers,
                    payload,
                    timeoutMilliseconds,
                    onComplete,
                    onError
                ).start();
        }
    }
}

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
 * Owns the lifecycle and callbacks for one HTTP request.
 */
final class HttpRequestContext
{
    private var request:URLRequest;
    private var loader:URLLoader;
    private var timer:Timer;
    private var timeoutMilliseconds:uint;
    private var onComplete:Function;
    private var onError:Function;
    private var settled:Boolean;
    private var httpStatus:int;

    /**
     * Creates a context for one HTTP request.
     * @param url Endpoint URL.
     * @param contentType HTTP content type.
     * @param headers HTTP request headers.
     * @param payload Serialized request payload.
     * @param timeoutMilliseconds Maximum request duration; zero disables the timeout.
     * @param onComplete Success callback.
     * @param onError Failure callback.
     */
    public function HttpRequestContext(
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
     * Starts the request and its optional timeout.
     */
    public function start():void
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
            throw error;
        }
    }

    /**
     * Settles this request exactly once and releases its resources.
     * @return True for the first caller, or false after the request has settled.
     */
    [Inline]
    private function trySettle():Boolean
    {
        if (!settled)
        {
            settled = true;
            cleanup();
            return true;
        }

        return false;
    }

    /**
     * Removes listeners, stops the timeout, and releases this context.
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
     * Records the HTTP status code for error reporting.
     * @param event Status event from URLLoader.
     */
    private function httpStatusHandler(event:HTTPStatusEvent):void
    {
        httpStatus = event.status;
    }

    /**
     * Handles a successful HTTP response.
     * @param event Completion event from URLLoader.
     */
    private function completeHandler(event:Event):void
    {
        if (!trySettle())
            return;

        if (httpStatus >= 400)
        {
            onError(new IOErrorEvent(
                        IOErrorEvent.IO_ERROR,
                        false,
                        false,
                        "HTTP request failed with status " + httpStatus
                    ));
            return;
        }

        const responseBytes:ByteArray = ByteArray(loader.data);
        responseBytes.endian = Endian.LITTLE_ENDIAN;
        onComplete(responseBytes);
    }

    /**
     * Handles an HTTP I/O failure.
     * @param event I/O error event from URLLoader.
     */
    private function ioErrorHandler(event:IOErrorEvent):void
    {
        if (!trySettle())
            return;

        if (httpStatus)
        {
            onError(new IOErrorEvent(
                        IOErrorEvent.IO_ERROR,
                        false,
                        false,
                        event.text + " (HTTP status " + httpStatus + ")",
                        event.errorID
                    ));
            return;
        }
        onError(event);
    }

    /**
     * Handles a Flash security sandbox failure.
     * @param event Security error event from URLLoader.
     */
    private function securityErrorHandler(event:SecurityErrorEvent):void
    {
        if (!trySettle())
            return;

        onError(event);
    }

    /**
     * Cancels a request that exceeded its configured duration.
     * @param event Timer completion event.
     */
    private function timeoutHandler(event:TimerEvent):void
    {
        if (!trySettle())
            return;

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
                    "HTTP request timed out after " + timeoutMilliseconds + " ms"
                ));
    }
}
