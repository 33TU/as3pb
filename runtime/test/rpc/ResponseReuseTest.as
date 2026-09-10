package rpc
{
    /** Integration check against the RPC fixture server; includes the original three-argument call. */
    public final class ResponseReuseTest
    {
        public static function run(baseUrl:String, onComplete:Function, onError:Function):void
        {
            const client:RpcFixtureServiceRpcClient = new RpcFixtureServiceRpcClient(baseUrl);
            const request:RpcEchoRequest = new RpcEchoRequest();
            request.message = "allocated";
            client.echo(request, function(fresh:RpcEchoResponse):void
                {
                    try
                    {
                        check(fresh != null && fresh.message == "allocated" && fresh.ok, "Default allocation");
                        const response:RpcEchoResponse = new RpcEchoResponse();
                        response.message = "stale";
                        request.message = "reused";
                        client.echo(request, function(reused:RpcEchoResponse):void
                            {
                                try
                                {
                                    check(reused === response && reused.message == "reused" && reused.ok, "Response identity and values");
                                    request.message = "";
                                    client.echo(request, function(empty:RpcEchoResponse):void
                                        {
                                            try
                                            {
                                                check(empty === response && empty.message == "" && empty.ok, "Reuse resets absent fields");
                                                check(fresh.message == "allocated", "Previous allocated response unchanged");
                                                onComplete();
                                            }
                                            catch (error:Error) { onError(error); }
                                        }, onError, 5000, response);
                                }
                                catch (error:Error) { onError(error); }
                            }, onError, 5000, response);
                    }
                    catch (error:Error) { onError(error); }
                }, onError);
        }

        private static function check(ok:Boolean, message:String):void
        {
            if (!ok) throw new Error(message);
        }
    }
}
