#!/usr/bin/env python3
"""Compare complete messages across two AS3PB revisions in one optimized AIR process."""
import argparse
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
CASES = {"negative-int32": "NegativeInts", "wide-int64": "WideInts",
         "packed-bools": "PackedBools", "packed-int64": "PackedInts", "tables": "Tables"}


def run(command, **kwargs):
    return subprocess.run([str(x) for x in command], check=True, **kwargs)


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True).strip()


def workload(ns, kind):
    cls = CASES[kind]
    setup = "msg.sequence = i + 1;\n"
    checks = ["if (got.sequence != want.sequence) throw new Error('sequence');"]
    if cls == "NegativeInts":
        for j, field in enumerate("abcdefgh"):
            setup += f"msg.{field} = -int(1 + i * 131071 + {j} * 16383);\n"
            checks.append(f"if(got.{field} != want.{field}) throw new Error('{field}');")
    elif cls == "WideInts":
        for j, field in enumerate("abcdefgh"):
            setup += f"msg.{field}.low = uint(0xffffffff - i * 131071 - {j});\n"
            high = f"uint(0x12345678 + i * 8191 + {j})" if j < 3 else f"-int(1 + i * 8191 + {j})"
            setup += f"msg.{field}.high = {high};\n"
            checks.append(f"if(got.{field}.low != want.{field}.low || got.{field}.high != want.{field}.high) throw new Error('{field}');")
    elif cls == "PackedBools":
        setup += "for(var j:uint=0;j<[0,8,16,32][i%4];j++) msg.values.push((i+j)%3!=0);"
        checks += ["if(got.values.length!=want.values.length) throw new Error('bool length');",
                   "for(var j:uint=0;j<want.values.length;j++) if(got.values[j]!=want.values[j]) throw new Error('bool');"]
    elif cls == "PackedInts":
        setup += """for(var j:uint=0;j<[0,8,16,32][i%4];j++){
msg.unsignedValues.push(uint(0xffffffff-i-j),j%2?0:0x12345678);
msg.signedValues.push(uint(0xffffffff-i-j),-int(1+j));
msg.zigzagValues.push(uint(0xffffffff-i-j),-int(1+j));
}"""
        for field in ["unsignedValues", "signedValues", "zigzagValues"]:
            checks += [f"if(got.{field}.length!=want.{field}.length) throw new Error('length');",
                       f"for(var j{field}:uint=0;j{field}<want.{field}.length;j{field}++) if(got.{field}.low[j{field}]!=want.{field}.low[j{field}] || got.{field}.high[j{field}]!=want.{field}.high[j{field}]) throw new Error('words');"]
    else:
        setup += f"""for(var j:uint=0;j<[0,8,16,32][i%4];j++){{
var point:{ns}.bench.Point=new {ns}.bench.Point();
point.x=(i+j)*0.25;point.y=(int(i)-int(j))*0.5;point.z=j*1.25;
msg.points.push(point);
}}"""
        checks += ["if(got.points.length!=want.points.length) throw new Error('points length');",
                   "for(var j:uint=0;j<want.points.length;j++) if(got.points[j].x!=want.points[j].x || got.points[j].y!=want.points[j].y || got.points[j].z!=want.points[j].z) throw new Error('point');"]
    return f"""package {ns} {{
import flash.utils.ByteArray;
import flash.utils.Endian;
import {ns}.bench.*;
public final class {cls}Work {{
public const values:Vector.<{cls}>=new Vector.<{cls}>();
public const encoded:Vector.<ByteArray>=new Vector.<ByteArray>();
private const output:ByteArray=new ByteArray();
private const reused:{cls}=new {cls}();
public function {cls}Work(){{
output.endian=Endian.LITTLE_ENDIAN;
for(var i:uint=0;i<64;i++){{
var msg:{cls}=new {cls}();
{setup}
values.push(msg);
var bytes:ByteArray=new ByteArray();bytes.endian=Endian.LITTLE_ENDIAN;
{cls}.serializeBytes(msg,bytes);encoded.push(bytes);
bytes.position=0;check({cls}.deserializeBytes(bytes,null,bytes.length),msg);
if(bytes.position!=bytes.length)throw new Error("fresh cursor");
bytes.position=0;check({cls}.deserializeBytes(bytes,reused,bytes.length),msg);
if(bytes.position!=bytes.length)throw new Error("cursor");
}}
}}
private function check(got:{cls},want:{cls}):void{{{''.join(checks)}}}
public function run(mode:String,rounds:uint):Number{{
var checksum:Number=0;var r:uint;var i:uint;var bytes:ByteArray;
switch(mode){{
case "pack":
for(r=0;r<rounds;r++)for(i=0;i<64;i++){{output.length=0;output.position=0;{cls}.serializeBytes(values[i],output);checksum+=output.length;}}
break;
case "fresh":
for(r=0;r<rounds;r++)for(i=0;i<64;i++){{bytes=encoded[i];bytes.position=0;checksum+={cls}.deserializeBytes(bytes,null,bytes.length).sequence;}}
break;
case "reuse":
for(r=0;r<rounds;r++)for(i=0;i<64;i++){{bytes=encoded[i];bytes.position=0;checksum+={cls}.deserializeBytes(bytes,reused,bytes.length).sequence;}}
break;
}}
return checksum;
}}
}}
}}"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", default="main")
    parser.add_argument("--candidate", default="HEAD")
    parser.add_argument("--workloads", nargs="+", choices=CASES, default=list(CASES))
    parser.add_argument("--samples", type=int, default=9)
    parser.add_argument("--target-ms", type=int, default=150)
    parser.add_argument("--output", type=Path, default=ROOT / "runtime/bin/bytearray-bench")
    args = parser.parse_args()
    if args.samples < 3 or args.target_ms < 20:
        parser.error("Use at least 3 samples and a 20 ms target")
    build = args.output.resolve()
    build.mkdir(parents=True, exist_ok=True)
    refs = [git("rev-parse", args.baseline), git("rev-parse", args.candidate)]
    # Snapshot committed sources without changing either checkout.
    for ns, ref in zip(["base", "test"], refs):
        for rel in git("ls-tree", "-r", "--name-only", ref, "runtime/src").splitlines():
            if not rel.endswith(".as"):
                continue
            source = git("show", ref + ":" + rel)
            source = source.replace("as3pb.", ns + ".as3pb.").replace("google.protobuf", ns + ".google.protobuf")
            dest = build / "src" / ns / Path(rel).relative_to("runtime/src")
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text(source + "\n")
    plugin = build / "protoc-gen-as3"
    run(["go", "build", "-o", plugin, "./cmd/protoc-gen-as3"], cwd=ROOT)
    generated = build / "generated"
    generated.mkdir(exist_ok=True)
    protoc = os.environ.get("PROTOC") or shutil.which("protoc")
    if not protoc:
        protoc = str(ROOT.parent / "tools/protobuf-build/protoc")
    run([*shlex.split(protoc), "--plugin=protoc-gen-as3=" + str(plugin),
         "--as3_out=" + str(generated), "-I" + str(HERE), HERE / "bytearray.proto"])
    for ns in ["base", "test"]:
        for file in generated.rglob("*.as"):
            source = file.read_text().replace("package bench", "package " + ns + ".bench")
            source = source.replace("bench.", ns + ".bench.").replace("as3pb.", ns + ".as3pb.")
            dest = build / "src" / ns / "bench" / file.name
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text(source)
        for kind in args.workloads:
            (build / "src" / ns / (CASES[kind] + "Work.as")).write_text(workload(ns, kind))
    imports = "\n".join(f"import {ns}.{CASES[k]}Work;" for ns in ["base", "test"] for k in args.workloads)
    pairs = ",".join(f'{{name:"{k}",pair:[new base.{CASES[k]}Work(),new test.{CASES[k]}Work()]}}' for k in args.workloads)
    runner = """package {
import flash.display.Sprite;
import flash.desktop.NativeApplication;
import flash.events.InvokeEvent;
import flash.utils.*;
import flash.filesystem.*;
IMPORTS
public class Main extends Sprite {
private var sink:Number=0;
public function Main(){NativeApplication.nativeApplication.addEventListener(InvokeEvent.INVOKE,run);}
private function run(e:InvokeEvent):void{try{
var results:Array=[];
var cases:Array=[PAIRS];
for each(var workload:Object in cases){
var pair:Array=workload.pair;
for(var i:uint=0;i<64;i++){
var a:ByteArray=pair[0].encoded[i];var b:ByteArray=pair[1].encoded[i];
if(a.length!=b.length)throw new Error("wire length");
for(var j:uint=0;j<a.length;j++)if(a[j]!=b[j])throw new Error("wire bytes");
}
for each(var mode:String in ["pack","fresh","reuse"]){
var rounds:Array=[];var samples:Array=[[],[]];var elapsed:int;var start:int;
for(var k:uint=0;k<2;k++){
var r:uint=1;
do{start=getTimer();sink+=pair[k].run(mode,r);elapsed=getTimer()-start;if(elapsed<40)r*=2;}while(elapsed<40);
rounds[k]=Math.max(1,Math.round(r*TARGET/elapsed));
}
for(var sample:uint=0;sample<SAMPLES;sample++)for(var m:uint=0;m<2;m++){
k=(sample+m)%2;start=getTimer();sink+=pair[k].run(mode,rounds[k]);samples[k].push(getTimer()-start);
}
for(k=0;k<2;k++){
var sorted:Array=samples[k].concat().sort(Array.NUMERIC);
results.push({workload:workload.name,mode:mode,variant:k?"candidate":"baseline",ops:rounds[k]*64000/sorted[uint(sorted.length/2)],samples:samples[k]});
}
}
save("progress.json",JSON.stringify(results));
}
save("result.json",JSON.stringify(results));NativeApplication.nativeApplication.exit(0);
}catch(err:Error){save("error.txt",err.toString()+"\n"+err.getStackTrace());NativeApplication.nativeApplication.exit(1);}}
private function save(name:String,text:String):void{
var fs:FileStream=new FileStream();fs.open(new File(File.applicationDirectory.nativePath).resolvePath(name),FileMode.WRITE);fs.writeUTFBytes(text);fs.close();
}
}}
"""
    runner = runner.replace("IMPORTS", imports).replace("PAIRS", pairs).replace("TARGET", str(args.target_ms)).replace("SAMPLES", str(args.samples))
    # Keep the AS3 error string escaped instead of embedding a literal newline.
    runner = runner.replace('err.toString()+"\n"', 'err.toString()+"\\n"')
    (build / "Main.as").write_text(runner)
    (build / "application.xml").write_text("""<application xmlns="http://ns.adobe.com/air/application/51.3">
<id>as3pb.bytearray.bench</id><versionNumber>0.1.0</versionNumber><filename>bytearray-bench</filename>
<initialWindow><content>test.swf</content><visible>false</visible></initialWindow>
<supportedProfiles>extendedDesktop</supportedProfiles></application>""")
    for stale in ["result.json", "error.txt", "progress.json"]:
        (build / stale).unlink(missing_ok=True)
    with (build / "build.log").open("w") as log:
        run([*shlex.split(os.environ.get("AMXMLC", "amxmlc")), "-source-path", build / "src",
             "-output", build / "test.swf", "-compiler.inline=true", "-optimize=true",
             "-debug=false", build / "Main.as"], stdout=log, stderr=subprocess.STDOUT)
    print("Running AIR benchmark...", flush=True)
    with (build / "run.log").open("w") as log:
        run([*shlex.split(os.environ.get("ADL", "adl")), "-nodebug", "application.xml"], cwd=build,
            stdout=log, stderr=subprocess.STDOUT)
    results = json.loads((build / "result.json").read_text())
    (build / "metadata.json").write_text(json.dumps({"baseline": refs[0], "candidate": refs[1],
        "samples": args.samples, "targetMs": args.target_ms, "fixtures": 64, "generatorCommit": git("rev-parse", "HEAD"),
        "inline": True, "debug": False, "workloads": args.workloads}, indent=2))
    report = ["| Workload | Pack | Fresh decode | Reused decode |", "|---|---:|---:|---:|"]
    for i in range(0, len(results), 6):
        group = results[i:i+6]
        changes = [100 * (group[j+1]["ops"] / group[j]["ops"] - 1) for j in [0, 2, 4]]
        report.append("| " + group[0]["workload"] + " | " + " | ".join(f"{v:+.1f}%" for v in changes) + " |")
    text = "\n".join(report) + "\n"
    (build / "comparison.md").write_text(text)
    print(text)


if __name__ == "__main__":
    main()
