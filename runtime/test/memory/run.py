#!/usr/bin/env python3
"""Compile and run opt-in memory tests without changing checked-in generated code."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
BUILD = Path("runtime/bin/memory-test")


def run(*args):
    subprocess.run([str(arg) for arg in args], cwd=ROOT, check=True)


def route_through_memory(source, destination):
    """Route the existing runtime/conformance entry points through generated memory APIs."""
    for path in source.rglob("*.as"):
        text = path.read_text()
        for method in ("serializeBytes", "deserializeBytes"):
            match = re.search(r"        public static function " + method + r"\([^\n]+", text)
            if not match:
                continue
            # Generated method bodies contain balanced braces, including their strings.
            start = text.index("{", match.end())
            end, depth = start + 1, 1
            while depth:
                depth += (text[end] == "{") - (text[end] == "}")
                end += 1
            if method == "serializeBytes":
                body = """
        {
            const context:PackContext = new PackContext();
            const oldLength:uint = dst.length;
            if (dst.length < ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH)
                dst.length = ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH;
            Pack.begin(context, dst);
            try { serializeMemory(src, context); }
            finally
            {
                Pack.end(context);
                dst.length = Math.max(oldLength, dst.position);
            }
        }"""
            else:
                body = """
        {
            if (length && length > src.bytesAvailable)
                throw new Error("Invalid protobuf message length");
            const context:UnpackContext = new UnpackContext();
            const oldLength:uint = src.length;
            src.length = Math.max(oldLength, ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH, Number(src.position) + length + 10);
            Unpack.begin(context, src, length);
            try { dst = deserializeMemory(context, dst, length, reset); }
            finally
            {
                Unpack.end(context);
                src.length = oldLength;
                src.position = context.position;
            }
            return dst;
        }"""
            text = text[:match.start()] + match[0] + body + text[end:]
        if "const oldLength:uint" in text:
            text = text.replace("    import flash.utils.ByteArray;", "    import flash.utils.ByteArray;\n    import flash.system.ApplicationDomain;", 1)
        output = destination / path.relative_to(source)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(text)


def generate(directory, options, protos):
    output = ROOT / directory
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)
    include = Path(os.environ.get("GOOGLE_PROTOBUF_PATH", "/usr/include/google/protobuf")).parent.parent
    run(os.environ.get("PROTOC", "protoc"),
        f"--plugin=protoc-gen-as3={BUILD}/protoc-gen-as3", f"--as3_out={directory}",
        "--as3_opt=" + ",".join(options + [f"M{name}.proto=example.com/{name}" for name in ("test", "bench", "rpc", "defaults")]), "-I", "runtime/test/data", "-I", include, *protos)


def air_test(generated, package):
    runner = ROOT / BUILD / "runner/MemoryRunner.as"
    runner.parent.mkdir(parents=True, exist_ok=True)
    runner.write_text("""package
{
    import flash.display.Sprite;
    import flash.desktop.NativeApplication;
    import flash.events.InvokeEvent;
    import PACKAGE.Main;

    public final class MemoryRunner extends Sprite
    {
        public function MemoryRunner()
        {
            NativeApplication.nativeApplication.addEventListener(InvokeEvent.INVOKE, run);
        }

        private function run(event:InvokeEvent):void
        {
            try
            {
                new PACKAGE.Main();
                trace("PACKAGE TESTS PASSED");
                NativeApplication.nativeApplication.exit(0);
            }
            catch (error:Error)
            {
                trace(error.getStackTrace());
                NativeApplication.nativeApplication.exit(1);
            }
        }
    }
}
""".replace("PACKAGE", package))
    run(os.environ.get("AMXMLC", "amxmlc"),
        "-source-path", generated, "-source-path", BUILD / "runtime", "-source-path", BUILD / "tests",
        "-source-path", BUILD / "runner", "-output", BUILD / "test.swf",
        "-compiler.inline=true", "-optimize=true", "-debug=true", BUILD / "runner" / runner.name)
    run(os.environ.get("ADL", "adl"), "-nodebug", BUILD / "application.xml")


def main():
    if len(sys.argv) == 4 and sys.argv[1] == "--wrap":
        route_through_memory(Path(sys.argv[2]), Path(sys.argv[3]))
        return
    (ROOT / BUILD).mkdir(parents=True, exist_ok=True)
    # Exclude default generated classes so the compiler cannot silently use them.
    for directory in (BUILD / "runtime", BUILD / "tests"):
        if (ROOT / directory).exists():
            shutil.rmtree(ROOT / directory)
    shutil.copytree(ROOT / "runtime/src", ROOT / BUILD / "runtime")
    shutil.copytree(ROOT / "runtime/test/test", ROOT / BUILD / "tests/test")
    (ROOT / BUILD / "tests/memory").mkdir(parents=True)
    shutil.copy2(ROOT / "runtime/test/memory/Main.as", ROOT / BUILD / "tests/memory/Main.as")
    run("go", "build", "-o", BUILD / "protoc-gen-as3", "./cmd/protoc-gen-as3")
    version = os.environ.get("AIR_VERSION", "51.3")
    (ROOT / BUILD / "application.xml").write_text(f"""<application xmlns="http://ns.adobe.com/air/application/{version}">
    <id>as3pb.memory.tests</id>
    <versionNumber>0.1.0</versionNumber>
    <filename>memory-test</filename>
    <initialWindow><content>test.swf</content><visible>false</visible></initialWindow>
    <supportedProfiles>extendedDesktop</supportedProfiles>
</application>
""")
    # Explicit values make this test independent of the user's generation defaults.
    byte_options = ["generate_serialize=true", "generate_deserialize=true", "generate_always=true"]
    memory_options = ["generate_serialize_memory=true", "generate_deserialize_memory=true"]
    protos = ["runtime/test/data/" + name + ".proto" for name in ("test", "bench", "rpc", "defaults")]
    protos += ["google/protobuf/" + name + ".proto" for name in
               ("any", "api", "duration", "empty", "field_mask", "source_context", "struct", "timestamp", "type", "wrappers")]
    generated = BUILD / "generated"
    # Exercise the shipped Google types without regenerating them.
    generate(generated, byte_options + memory_options, protos[:4])
    air_test(generated, "memory")
    # Route the entire runtime suite, including Google types, through memory APIs.
    generate(generated, byte_options + memory_options, protos)
    shutil.rmtree(ROOT / BUILD / "runtime/google")
    wrapped = BUILD / "wrapped"
    if (ROOT / wrapped).exists():
        shutil.rmtree(ROOT / wrapped)
    route_through_memory(ROOT / generated, ROOT / wrapped)
    air_test(wrapped, "test")
    shutil.copytree(ROOT / "runtime/src/google", ROOT / BUILD / "runtime/google")
    for serialize, deserialize in ((True, False), (False, True), (True, True)):
        options = ["generate_serialize=false", "generate_deserialize=false", "generate_always=true",
                   f"generate_serialize_memory={str(serialize).lower()}",
                   f"generate_deserialize_memory={str(deserialize).lower()}"]
        output = BUILD / f"only-{int(serialize)}-{int(deserialize)}"
        generate(output, options, ["runtime/test/data/test.proto"])
        run(os.environ.get("COMPC", "compc"), "-source-path", output, "-source-path", BUILD / "runtime",
            "-include-sources", output, "-output", BUILD / "memory-only.swc",
            "-compiler.inline=true", "-optimize=true")
    print("All memory backend tests passed.")


if __name__ == "__main__":
    main()
