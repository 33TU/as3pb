package main

import (
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"testing"
)

func TestExecutablePathReturnsAbsolutePath(t *testing.T) {
	dir := t.TempDir()
	name := "protoc-gen-as3"
	if runtime.GOOS == "windows" {
		name += ".exe"
	}
	path := filepath.Join(dir, name)
	if err := os.WriteFile(path, []byte{}, 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir)

	got, err := executablePath("protoc-gen-as3")
	if err != nil {
		t.Fatal(err)
	}
	want, err := filepath.Abs(path)
	if err != nil {
		t.Fatal(err)
	}
	if got != want {
		t.Fatalf("executablePath() = %q, want %q", got, want)
	}
}

func TestProtoMappingsUseConsistentPackageName(t *testing.T) {
	dir := t.TempDir()
	for _, name := range []string{"first.proto", "second.proto"} {
		if err := os.WriteFile(filepath.Join(dir, name), []byte("syntax = \"proto3\";\n"), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	got, err := protoMappings([]string{dir})
	if err != nil {
		t.Fatal(err)
	}
	want := []string{
		"Mfirst.proto=as3.pb;as3pb",
		"Msecond.proto=as3.pb;as3pb",
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("protoMappings() = %#v, want %#v", got, want)
	}
}
