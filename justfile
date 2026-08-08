set windows-shell := ["powershell", "-c"]

BIN_DIR := "bin"
AS3_BIN_DIR := "runtime/bin"
AS3_OPTIMIZE := env("AS3_OPTIMIZE", "true")
AS3_INLINE := env("AS3_INLINE", "true")
AS3_FLOAT := env("AS3_FLOAT", "false")
AS3_DEBUG := env("AS3_DEBUG", "false")
SDK_DIR := env("SDK_DIR", "sdk")
GOOGLE_PROTOBUF_PATH := env("GOOGLE_PROTOBUF_PATH", "/usr/include/google/protobuf")
GOOGLE_PROTOBUF_INCLUDE := parent_directory(parent_directory(GOOGLE_PROTOBUF_PATH))
EXAMPLES_OUT := "examples/generated"
PROTOC := env("PROTOC", "protoc")
RUNTIME_TEST_PROTOS := "runtime/test/data/test.proto runtime/test/data/bench.proto runtime/test/data/rpc.proto runtime/test/data/defaults.proto"
RUNTIME_TEST_GENERATED := "runtime/test/generated"

default:
    @just --list

test:
    go test ./...

build: build-protoc-gen-as3 build-as3-protoc build-swc

build-protoc-gen-as3:
    mkdir -p {{ BIN_DIR }}
    go build -o {{ BIN_DIR }}/protoc-gen-as3 ./cmd/protoc-gen-as3

build-as3-protoc:
    mkdir -p {{ BIN_DIR }}
    go build -o {{ BIN_DIR }}/as3-protoc ./cmd/as3-protoc

# Regenerate the runtime-provided Google protobuf types
generate-google-protobuf: build-protoc-gen-as3 build-as3-protoc
    {{ BIN_DIR }}/as3-protoc \
        --protoc_gen_as3_bin={{ BIN_DIR }}/protoc-gen-as3 \
        --as3_out=runtime/src \
        -I {{ GOOGLE_PROTOBUF_INCLUDE }} \
        {{ GOOGLE_PROTOBUF_PATH }}/any.proto \
        {{ GOOGLE_PROTOBUF_PATH }}/api.proto \
        {{ GOOGLE_PROTOBUF_PATH }}/duration.proto \
        {{ GOOGLE_PROTOBUF_PATH }}/empty.proto \
        {{ GOOGLE_PROTOBUF_PATH }}/field_mask.proto \
        {{ GOOGLE_PROTOBUF_PATH }}/source_context.proto \
        {{ GOOGLE_PROTOBUF_PATH }}/struct.proto \
        {{ GOOGLE_PROTOBUF_PATH }}/timestamp.proto \
        {{ GOOGLE_PROTOBUF_PATH }}/type.proto \
        {{ GOOGLE_PROTOBUF_PATH }}/wrappers.proto

# Download AIR SDK for current OS, or one of: linux, mac, windows
download-air-sdk os="" sdk_dir=SDK_DIR:
    go run ./cmd/air-sdk-downloader -dir {{ sdk_dir }} {{ if os == "" { "" } else { "-os " + os } }}

build-swc:
    mkdir -p {{ AS3_BIN_DIR }}
    compc \
        -source-path runtime/src \
        -include-sources runtime/src \
        -output {{ AS3_BIN_DIR }}/as3pb.swc \
        -optimize={{ AS3_OPTIMIZE }} \
        -compiler.strict=true \
        -compiler.inline={{ AS3_INLINE }} \
        -compiler.float={{ AS3_FLOAT }} \
        -debug={{ AS3_DEBUG }} \
        -omit-trace-statements=true

# defaults.proto is an editions file: protoc 27+ required (PROTOC=...
# overrides which binary is used).
generate-runtime-test-data: build-protoc-gen-as3 build-as3-protoc
    rm -rf {{ RUNTIME_TEST_GENERATED }}
    mkdir -p {{ RUNTIME_TEST_GENERATED }}
    {{ BIN_DIR }}/as3-protoc \
        --protoc_bin={{ PROTOC }} \
        --protoc_gen_as3_bin={{ BIN_DIR }}/protoc-gen-as3 \
        --as3_out={{ RUNTIME_TEST_GENERATED }} \
        -I runtime/test/data \
        -I {{ GOOGLE_PROTOBUF_INCLUDE }} \
        {{ RUNTIME_TEST_PROTOS }}

build-runtime-test: generate-runtime-test-data
    mkdir -p {{ AS3_BIN_DIR }}
    mxmlc \
        -source-path runtime/src \
        -source-path runtime/test \
        -source-path {{ RUNTIME_TEST_GENERATED }} \
        -output {{ AS3_BIN_DIR }}/as3pb-test.swf \
        -optimize={{ AS3_OPTIMIZE }} \
        -compiler.strict=true \
        -compiler.inline={{ AS3_INLINE }} \
        -compiler.float={{ AS3_FLOAT }} \
        -debug=true \
        runtime/test/test/Main.as

build-runtime-bench: generate-runtime-test-data
    mkdir -p {{ AS3_BIN_DIR }}
    mxmlc \
        -source-path runtime/src \
        -source-path runtime/test \
        -source-path {{ RUNTIME_TEST_GENERATED }} \
        -output {{ AS3_BIN_DIR }}/as3pb-bench.swf \
        -optimize={{ AS3_OPTIMIZE }} \
        -compiler.strict=true \
        -compiler.inline={{ AS3_INLINE }} \
        -compiler.float={{ AS3_FLOAT }} \
        -debug={{ AS3_DEBUG }} \
        runtime/test/bench/Main.as

build-runtime-rpc: generate-runtime-test-data
    mkdir -p {{ AS3_BIN_DIR }}
    mxmlc \
        -source-path runtime/src \
        -source-path runtime/test \
        -source-path {{ RUNTIME_TEST_GENERATED }} \
        -output {{ AS3_BIN_DIR }}/as3pb-rpc.swf \
        -optimize={{ AS3_OPTIMIZE }} \
        -compiler.strict=true \
        -compiler.inline={{ AS3_INLINE }} \
        -compiler.float={{ AS3_FLOAT }} \
        -debug={{ AS3_DEBUG }} \
        runtime/test/rpc/Main.as

# Regenerate Go stubs for the runtime RPC test server
generate-runtime-rpc-server:
    cd runtime/test/rpc-server && go tool buf generate --config buf.yaml --template buf.gen.yaml ../data/rpc.proto

run-runtime-rpc-server: generate-runtime-rpc-server
    cd runtime/test/rpc-server && go run .

generate-examples: build-protoc-gen-as3 build-as3-protoc
    rm -rf {{ EXAMPLES_OUT }}
    mkdir -p {{ EXAMPLES_OUT }}
    {{ BIN_DIR }}/as3-protoc \
        --protoc_gen_as3_bin={{ BIN_DIR }}/protoc-gen-as3 \
        --as3_out={{ EXAMPLES_OUT }} \
        -I examples/proto \
        examples/proto/game.proto

build-examples: generate-examples
    compc \
        -source-path runtime/src \
        -source-path {{ EXAMPLES_OUT }} \
        -include-sources {{ EXAMPLES_OUT }} \
        -library-path runtime/libs \
        -output {{ EXAMPLES_OUT }}/examples.swc \
        -compiler.strict=true \
        -compiler.inline={{ AS3_INLINE }} \
        -compiler.float={{ AS3_FLOAT }} \
        -debug={{ AS3_DEBUG }}
