package bench
{
    import flash.display.Sprite;
    import flash.events.MouseEvent;
    import flash.text.TextField;
    import flash.text.TextFormat;

    public final class Main extends Sprite
    {
        private var _logDisplay:TextField;
        private var _logText:String = "";

        public function Main()
        {
            setupDisplay();
            runBenchmark();
        }

        private function setupDisplay():void
        {
            _logDisplay = new TextField();
            _logDisplay.x = 10;
            _logDisplay.y = 10;
            _logDisplay.width = stage ? stage.stageWidth - 20 : 480;
            _logDisplay.height = stage ? stage.stageHeight - 20 : 355;
            _logDisplay.multiline = true;
            _logDisplay.wordWrap = true;
            _logDisplay.border = true;
            _logDisplay.borderColor = 0x333333;
            _logDisplay.background = true;
            _logDisplay.backgroundColor = 0x000000;
            _logDisplay.selectable = true;

            const format:TextFormat = new TextFormat();
            format.font = "_typewriter";
            format.size = 11;
            format.color = 0x00ff00;
            _logDisplay.defaultTextFormat = format;
            addChild(_logDisplay);

            const runButton:Sprite = createButton("Run Benchmark", stage ? stage.stageWidth - 135 : 345, 14, 125, 26);
            runButton.addEventListener(MouseEvent.CLICK, function(event:MouseEvent):void
                {
                    runBenchmark();
                });
            addChild(runButton);
        }

        private function createButton(label:String, x:Number, y:Number, width:Number, height:Number):Sprite
        {
            const button:Sprite = new Sprite();
            button.x = x;
            button.y = y;
            button.buttonMode = true;
            button.useHandCursor = true;

            function drawBackground(color:uint):void
            {
                button.graphics.clear();
                button.graphics.beginFill(color);
                button.graphics.drawRoundRect(0, 0, width, height, 4, 4);
                button.graphics.endFill();
            }

            drawBackground(0x1e3a1e);

            const text:TextField = new TextField();
            text.mouseEnabled = false;
            text.selectable = false;
            text.width = width;
            text.height = height;
            text.defaultTextFormat = new TextFormat("_sans", 11, 0xffffff, true, null, null, null, null, "center");
            text.text = label;
            text.y = 5;
            button.addChild(text);

            button.addEventListener(MouseEvent.MOUSE_OVER, function(event:MouseEvent):void
                {
                    drawBackground(0x2d5a2d);
                });
            button.addEventListener(MouseEvent.MOUSE_OUT, function(event:MouseEvent):void
                {
                    drawBackground(0x1e3a1e);
                });

            return button;
        }

        private function runBenchmark():void
        {
            _logText = "";
            new Benchmark(log).run();
        }

        private function log(message:String, measured:Boolean = false):void
        {
            trace(message);
            _logText += message + "\n";
            if (_logDisplay)
            {
                _logDisplay.text = _logText;
                _logDisplay.scrollV = _logDisplay.maxScrollV;
            }
        }
    }
}
