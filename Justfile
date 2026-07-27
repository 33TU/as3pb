BIN_DIR := "bin"
AIRSDK_HOME := env("AIRSDK_HOME", "/home/user/Bin/AIRSDK")
AS3_BIN_DIR := "runtime/bin"
AS3_OPTIMIZE := env("AS3_OPTIMIZE", "true")
AS3_INLINE := env("AS3_INLINE", "true")
AS3_FLOAT := env("AS3_FLOAT", "false")
AS3_DEBUG := env("AS3_DEBUG", "false")
EXAMPLES_OUT := "examples/generated"
RUNTIME_TEST_PROTOS := "runtime/test/data/runtime_test.proto runtime/test/data/runtime_bench.proto runtime/test/data/runtime_rpc.proto"
RUNTIME_TEST_GENERATED := "runtime/test/generated"

test:
    go test ./...

build: build-protoc-gen-as3 build-as3-protoc build-swc

build-protoc-gen-as3:
    mkdir -p {{ BIN_DIR }}
    go build -o {{ BIN_DIR }}/protoc-gen-as3 ./cmd/protoc-gen-as3

build-as3-protoc:
    mkdir -p {{ BIN_DIR }}
    go build -o {{ BIN_DIR }}/as3-protoc ./cmd/as3-protoc

build-swc:
    mkdir -p {{ AS3_BIN_DIR }}
    {{ AIRSDK_HOME }}/bin/compc \
        -source-path runtime/src \
        -include-sources runtime/src \
        -library-path runtime/libs \
        -output {{ AS3_BIN_DIR }}/as3pb.swc \
        -optimize={{ AS3_OPTIMIZE }} \
        -compiler.strict=true \
        -compiler.inline={{ AS3_INLINE }} \
        -compiler.float={{ AS3_FLOAT }} \
        -debug={{ AS3_DEBUG }} \
        -omit-trace-statements=true

generate-runtime-test-data: build-protoc-gen-as3 build-as3-protoc
    rm -rf {{ RUNTIME_TEST_GENERATED }}
    mkdir -p {{ RUNTIME_TEST_GENERATED }}
    {{ BIN_DIR }}/as3-protoc \
        --protoc_gen_as3_bin={{ BIN_DIR }}/protoc-gen-as3 \
        --as3_out={{ RUNTIME_TEST_GENERATED }} \
        -I runtime/test/data \
        {{ RUNTIME_TEST_PROTOS }}

build-runtime-test: generate-runtime-test-data
    mkdir -p {{ AS3_BIN_DIR }}
    {{ AIRSDK_HOME }}/bin/mxmlc \
        -source-path runtime/src \
        -source-path runtime/test \
        -source-path {{ RUNTIME_TEST_GENERATED }} \
        -output {{ AS3_BIN_DIR }}/as3pb-test.swf \
        -optimize={{ AS3_OPTIMIZE }} \
        -compiler.strict=true \
        -compiler.inline={{ AS3_INLINE }} \
        -compiler.float={{ AS3_FLOAT }} \
        -debug={{ AS3_DEBUG }} \
        runtime/test/test/Main.as

build-runtime-bench: generate-runtime-test-data
    mkdir -p {{ AS3_BIN_DIR }}
    {{ AIRSDK_HOME }}/bin/mxmlc \
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

generate-examples: build-protoc-gen-as3 build-as3-protoc
    rm -rf {{ EXAMPLES_OUT }}
    mkdir -p {{ EXAMPLES_OUT }}
    {{ BIN_DIR }}/as3-protoc \
        --protoc_gen_as3_bin={{ BIN_DIR }}/protoc-gen-as3 \
        --as3_out={{ EXAMPLES_OUT }} \
        -I examples/proto \
        examples/proto/game.proto

build-examples: generate-examples
    {{ AIRSDK_HOME }}/bin/compc \
        -source-path runtime/src \
        -source-path {{ EXAMPLES_OUT }} \
        -include-sources {{ EXAMPLES_OUT }} \
        -library-path runtime/libs \
        -output {{ EXAMPLES_OUT }}/examples.swc \
        -compiler.strict=true \
        -compiler.inline={{ AS3_INLINE }} \
        -compiler.float={{ AS3_FLOAT }} \
        -debug={{ AS3_DEBUG }}
