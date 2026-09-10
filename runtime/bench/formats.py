#!/usr/bin/env python3
"""Compare current AS3PB with lossless plain-object AMF3 and JSON."""
import argparse
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import bytearray as bench


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=bench.ROOT / 'runtime/bin/formats-bench')
    parser.add_argument('--samples', type=int, default=9)
    parser.add_argument('--target-ms', type=int, default=150)
    args = parser.parse_args()
    if args.samples < 3 or args.target_ms < 20:
        parser.error('Use at least 3 samples and a 20 ms target')
    root = args.output.resolve()
    root.mkdir(parents=True, exist_ok=True)
    generated = root / 'generated'
    generated.mkdir(exist_ok=True)
    plugin = root / 'protoc-gen-as3'
    bench.run(['go', 'build', '-o', plugin, './cmd/protoc-gen-as3'], cwd=bench.ROOT)
    protoc = os.environ.get('PROTOC') or shutil.which('protoc') or str(bench.ROOT.parent / 'tools/protobuf-build/protoc')
    bench.run([*shlex.split(protoc), '--plugin=protoc-gen-as3=' + str(plugin), '--as3_out=' + str(generated),
               '-I' + str(bench.HERE), bench.HERE / 'bytearray.proto'])
    # Reuse the exact README fixture schema, supplying its Go package externally.
    bench.run([*shlex.split(protoc), '--plugin=protoc-gen-as3=' + str(plugin), '--as3_out=' + str(generated),
               '--as3_opt=Mbench.proto=example.com/as3pb/bench', '-I' + str(bench.ROOT / 'runtime/test/data'),
               bench.ROOT / 'runtime/test/data/bench.proto'])
    dest = root / 'src/test/bench'
    dest.mkdir(parents=True, exist_ok=True)
    for p in generated.rglob('*.as'):
        source = p.read_text().replace('package bench', 'package test.bench').replace('bench.', 'test.bench.')
        (dest / p.name).write_text(source)
    kinds = {'readme-mixed': 'BenchMessage', **bench.CASES}
    for kind in bench.CASES:
        (root / 'src/test' / (bench.CASES[kind] + 'Work.as')).write_text(bench.workload('test', kind))
    mixed = bench.workload('test', 'negative-int32').replace('NegativeInts', 'BenchMessage')
    start = mixed.index('msg.sequence = i + 1;')
    end = mixed.index('values.push(msg);', start)
    mixed = mixed[:start] + '''msg.sequence=i+1;msg.id="message-"+i;msg.delta=i%2==0?i:-int(i);
msg.accountId.low=100000+i;msg.accountId.high=1;
var sign:int=i%2==0?1:-1;
msg.scoreDelta.copyFrom(as3pb.types.Int64.fromNumber(sign*(1337+i)));
msg.checksum=0x12340000+i;msg.signedTick.copyFrom(as3pb.types.Int64.fromNumber(-1000000-i));
msg.x=i*1.25;msg.precision=i*0.0009765625;msg.active=i%2==0;
msg.payload.writeUTFBytes("payload-"+i);msg.payload.position=0;
for(var j:uint=0;j<10;j++){
msg.samples.push(j*100000+i);msg.offsets.push(j%2==0?j+i:-int(j)-int(i));
msg.hashes.push(0xabcdef00+j+i);msg.positions.push(i+j*0.5);
var tick:as3pb.types.Int64=as3pb.types.Int64.fromNumber(-1000000000-j*1000-i);msg.ticks.push(tick.low,tick.high);
}
''' + mixed[end:]
    mixed = re.sub(r'private function check\(got:BenchMessage,want:BenchMessage\):void\{[^\n]*\}',
                   'private function check(got:BenchMessage,want:BenchMessage):void{formats.FormatBaseline.equal(formats.FormatBaseline.plain(got),formats.FormatBaseline.plain(want));}', mixed)
    mixed = mixed.replace('import test.bench.*;', 'import test.bench.*;\nimport as3pb.types.Int64;\nimport formats.FormatBaseline;')
    (root / 'src/test/BenchMessageWork.as').write_text(mixed)
    (root / 'src/formats').mkdir(exist_ok=True)
    shutil.copy2(bench.HERE / 'FormatBaseline.as', root / 'src/formats/FormatBaseline.as')
    imports = '\n'.join('import test.' + cls + 'Work;' for cls in kinds.values())
    cases = ','.join('{name:"' + kind + '",pb:new test.' + cls + 'Work()}' for kind, cls in kinds.items())
    source = r'''package {
import flash.display.Sprite;
import flash.desktop.NativeApplication;
import flash.events.InvokeEvent;
import flash.utils.*;
import flash.filesystem.*;
import formats.FormatBaseline;
IMPORTS
public class Main extends Sprite {
private var sink:Number=0;
public function Main(){NativeApplication.nativeApplication.addEventListener(InvokeEvent.INVOKE,run);}
private function run(e:InvokeEvent):void{try{
var results:Array=[];
var cases:Array=[CASES];
for each(var workload:Object in cases){
var pb:Object=workload.pb;var other:FormatBaseline=new FormatBaseline(pb.values);
var ops:Array=[];
for each(var mode:String in ["pack","fresh","reuse"])ops.push({format:"as3pb",mode:mode,target:pb,key:mode,buffers:pb.encoded});
for each(var format:String in ["amf3","json"])for each(mode in ["pack","fresh"])ops.push({format:format,mode:mode,target:other,key:format+"/"+mode,buffers:format=="json"?other.json:other.amf});
for each(var op:Object in ops){
var rounds:uint=1;var elapsed:int;var start:int;
do{start=getTimer();sink+=op.target.run(op.key,rounds);elapsed=getTimer()-start;if(elapsed<40)rounds*=2;}while(elapsed<40);
op.rounds=Math.max(1,Math.round(rounds*TARGET/elapsed));op.times=[];
}
for(var sample:uint=0;sample<SAMPLES;sample++)for(var i:uint=0;i<ops.length;i++){
op=ops[(sample+i)%ops.length];start=getTimer();sink+=op.target.run(op.key,op.rounds);op.times.push(getTimer()-start);
}
for each(op in ops){
var sorted:Array=op.times.concat().sort(Array.NUMERIC);var total:uint=0;
for each(var buffer:ByteArray in op.buffers)total+=buffer.length;
results.push({workload:workload.name,format:op.format,mode:op.mode,ops:op.rounds*64000/sorted[uint(sorted.length/2)],bytes:total/64,samples:op.times});
}
save("progress.json",JSON.stringify(results));
}
save("result.json",JSON.stringify(results));NativeApplication.nativeApplication.exit(0);
}catch(err:Error){save("error.txt",err.toString()+"\n"+err.getStackTrace());NativeApplication.nativeApplication.exit(1);}}
private function save(name:String,text:String):void{var fs:FileStream=new FileStream();fs.open(new File(File.applicationDirectory.nativePath).resolvePath(name),FileMode.WRITE);fs.writeUTFBytes(text);fs.close();}
}}
'''
    source = source.replace('IMPORTS', imports).replace('CASES', cases).replace('TARGET', str(args.target_ms)).replace('SAMPLES', str(args.samples))
    (root / 'Main.as').write_text(source)
    (root / 'application.xml').write_text('<application xmlns="http://ns.adobe.com/air/application/51.3"><id>as3pb.formats.bench</id><versionNumber>0.1.0</versionNumber><filename>formats-bench</filename><initialWindow><content>test.swf</content><visible>false</visible></initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>')
    for stale in ['result.json', 'error.txt', 'progress.json']:
        (root / stale).unlink(missing_ok=True)
    with (root / 'build.log').open('w') as log:
        bench.run([*shlex.split(os.environ.get('AMXMLC', 'amxmlc')), '-source-path', root / 'src',
                   '-source-path', bench.ROOT / 'runtime/src', '-output', root / 'test.swf',
                   '-compiler.inline=true', '-optimize=true', '-debug=false', root / 'Main.as'], stdout=log, stderr=subprocess.STDOUT)
    print('Running format comparison...', flush=True)
    with (root / 'run.log').open('w') as log:
        bench.run([*shlex.split(os.environ.get('ADL', 'adl')), '-nodebug', 'application.xml'], cwd=root, stdout=log, stderr=subprocess.STDOUT)
    results = json.loads((root / 'result.json').read_text())
    (root / 'metadata.json').write_text(json.dumps({'commit': bench.git('rev-parse', 'HEAD'), 'samples': args.samples,
        'targetMs': args.target_ms, 'fixtures': 64, 'inline': True, 'debug': False}, indent=2))
    report = ['| Workload | Format | Average bytes | Encode msg/s | Fresh decode msg/s | Reused decode msg/s |',
              '|---|---|---:|---:|---:|---:|']
    for kind in kinds:
        for format in ['as3pb', 'amf3', 'json']:
            group = {x['mode']: x for x in results if x['workload'] == kind and x['format'] == format}
            reuse = f"{group['reuse']['ops']:,.0f}" if 'reuse' in group else '—'
            report.append(f"| {kind} | {format} | {group['pack']['bytes']:.1f} | {group['pack']['ops']:,.0f} | {group['fresh']['ops']:,.0f} | {reuse} |")
    text = '\n'.join(report) + '\n'
    (root / 'comparison.md').write_text(text)
    print(text)


if __name__ == '__main__':
    main()
