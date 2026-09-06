#!/usr/bin/env bash
set -euo pipefail

royale_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "$royale_dir/../.." && pwd)"
build_dir="$repo_dir/runtime/bin/royale"

if [[ -z "${ROYALE_SDK:-}" || ! -x "$ROYALE_SDK/js/bin/asnodec" ]]; then
    echo 'Set ROYALE_SDK to the royale-asjs directory of Apache Royale 0.9.12.' >&2
    exit 1
fi

# Keep compiler output in the ignored build directory.
rm -rf -- "$build_dir"
mkdir -p "$build_dir/bench"
cp "$royale_dir/bench/"*.as "$build_dir/bench/"

"$ROYALE_SDK/js/bin/asnodec" \
    -debug=false \
    -define+=COMPILE::JS,true \
    -js-vector-emulation-class=Array \
    -js-vector-index-checks=false \
    -library-path+="$ROYALE_SDK/frameworks/js/libs/CoreJS.swc" \
    -library-path+="$ROYALE_SDK/frameworks/js/libs/XMLJS.swc" \
    -source-path+="$royale_dir/src" \
    -source-path+="$repo_dir/runtime/src" \
    -source-path+="$repo_dir/runtime/test/generated" \
    "$build_dir/bench/Main.as"

node \
    "$build_dir/bench/bin/js-release/index.js"
