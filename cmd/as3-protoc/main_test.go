package main

import (
	"os"
	"path/filepath"
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
