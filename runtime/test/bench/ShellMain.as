package bench
{
    /**
     * The benchmark in avmshell, which has no display list: results go to
     * trace(), and lines holding timings start with "time: ".
     */
    public final class ShellMain
    {
        public static function main():void
        {
            new Benchmark(function(message:String, measured:Boolean):void
                {
                    trace(measured ? "time: " + message : message);
                }).run();
        }
    }
}

bench.ShellMain.main();
