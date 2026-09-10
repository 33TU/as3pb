package formats
{
    import flash.net.ObjectEncoding;
    import flash.utils.*;
    import as3pb.types.*;

    /** Equivalent plain-object data for AMF3 and JSON. Projection is outside timing. */
    public final class FormatBaseline
    {
        public const values:Vector.<Object> = new Vector.<Object>();
        public const json:Vector.<ByteArray> = new Vector.<ByteArray>();
        public const amf:Vector.<ByteArray> = new Vector.<ByteArray>();
        private const output:ByteArray = new ByteArray();

        public function FormatBaseline(source:Object)
        {
            output.objectEncoding = ObjectEncoding.AMF3;
            for (var i:uint = 0; i < source.length; i++)
            {
                const value:Object = plain(source[i]);
                values.push(value);
                const j:ByteArray = new ByteArray();
                j.writeUTFBytes(JSON.stringify(value));
                json.push(j);
                j.position = 0;
                equal(JSON.parse(j.readUTFBytes(j.length)), value);
                if (j.position != j.length) throw new Error("JSON cursor");
                const a:ByteArray = new ByteArray();
                a.objectEncoding = ObjectEncoding.AMF3;
                a.writeObject(value);
                amf.push(a);
                a.position = 0;
                equal(a.readObject(), value);
                if (a.position != a.length) throw new Error("AMF cursor");
            }
        }

        public static function plain(value:*):*
        {
            if (value == null || typeof value != "object") return value;
            if (value is Int64 || value is UInt64)
                return {low:value.low, high:value.high};
            var array:Array;
            var i:uint;
            if (value is Int64Vector || value is UInt64Vector)
            {
                array = [];
                for (i = 0; i < value.length; i++)
                    array.push({low:value.low[i], high:value.high[i]});
                return array;
            }
            if (value is ByteArray)
            {
                array = [];
                for (i = 0; i < value.length; i++) array.push(uint(value[i]));
                return array;
            }
            if (value is Array || getQualifiedClassName(value).indexOf("__AS3__.vec::Vector") == 0)
            {
                array = [];
                for (i = 0; i < value.length; i++) array.push(plain(value[i]));
                return array;
            }
            const out:Object = {};
            for each (var field:XML in describeType(value).variable)
            {
                const name:String = field.@name.toString();
                if (name != "unknownFields") out[name] = plain(value[name]);
            }
            return out;
        }

        public static function equal(actual:*, expected:*):void
        {
            if (expected == null || typeof expected != "object")
            {
                if (actual !== expected) throw new Error("Value mismatch: " + actual + " != " + expected);
                return;
            }
            if (actual == null) throw new Error("Null mismatch");
            if (expected is Array)
            {
                if (!(actual is Array) || actual.length != expected.length) throw new Error("Array length");
                for (var i:uint = 0; i < expected.length; i++) equal(actual[i], expected[i]);
                return;
            }
            var key:String;
            for (key in expected)
            {
                if (!actual.hasOwnProperty(key)) throw new Error("Missing " + key);
                equal(actual[key], expected[key]);
            }
            for (key in actual)
                if (!expected.hasOwnProperty(key)) throw new Error("Extra " + key);
        }

        public function run(mode:String, rounds:uint):Number
        {
            var sum:Number = 0;
            var r:uint;
            var i:uint;
            var bytes:ByteArray;
            switch (mode)
            {
                case "json/pack":
                    for (r = 0; r < rounds; r++) for (i = 0; i < values.length; i++)
                    {
                        output.length = 0; output.position = 0;
                        output.writeUTFBytes(JSON.stringify(values[i]));
                        sum += output.length;
                    }
                    break;
                case "amf3/pack":
                    for (r = 0; r < rounds; r++) for (i = 0; i < values.length; i++)
                    {
                        output.length = 0; output.position = 0;
                        output.writeObject(values[i]);
                        sum += output.length;
                    }
                    break;
                case "json/fresh":
                    for (r = 0; r < rounds; r++) for (i = 0; i < values.length; i++)
                    {
                        bytes = json[i]; bytes.position = 0;
                        sum += JSON.parse(bytes.readUTFBytes(bytes.length)).sequence;
                    }
                    break;
                case "amf3/fresh":
                    for (r = 0; r < rounds; r++) for (i = 0; i < values.length; i++)
                    {
                        bytes = amf[i]; bytes.position = 0;
                        sum += bytes.readObject().sequence;
                    }
                    break;
            }
            return sum;
        }
    }
}
