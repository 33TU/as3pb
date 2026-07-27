// Command-line wrapper around protoc and protoc-gen-as3.
package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

type stringSlice []string

func (s *stringSlice) String() string {
	return strings.Join(*s, ",")
}

func (s *stringSlice) Set(value string) error {
	*s = append(*s, value)
	return nil
}

func main() {
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage: %s [options] proto_files...\n\n", os.Args[0])
		fmt.Fprintln(os.Stderr, "Generates ActionScript 3 code from .proto files using protoc-gen-as3.")
		fmt.Fprintln(os.Stderr, "\nOptions:")
		flag.PrintDefaults()
		fmt.Fprintln(os.Stderr, "\nExamples:")
		fmt.Fprintf(os.Stderr, "  %s --as3_out=generated example.proto\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  %s -I proto --as3_out=generated proto/user.proto\n", os.Args[0])
	}

	protocBin := flag.String("protoc_bin", "protoc", "Path to protoc binary.")
	protocGenAS3Bin := flag.String("protoc_gen_as3_bin", "protoc-gen-as3", "Path to protoc-gen-as3 plugin binary.")
	as3Out := flag.String("as3_out", ".", "Output directory for generated AS3 files.")
	verbose := flag.Bool("v", false, "Print the protoc command before running it.")

	var includes stringSlice
	flag.Var(&includes, "I", "Proto include path. May be repeated.")

	var as3Options stringSlice
	flag.Var(&as3Options, "as3_opt", "Extra protoc-gen-as3 option. May be repeated.")

	flag.Parse()

	protoFiles := flag.Args()
	if len(protoFiles) == 0 {
		fmt.Fprintln(os.Stderr, "Error: no proto files specified")
		fmt.Fprintln(os.Stderr)
		flag.Usage()
		os.Exit(1)
	}
	if len(includes) == 0 {
		includes = append(includes, ".")
	}

	if err := runProtoc(*protocBin, *protocGenAS3Bin, *as3Out, *verbose, includes, as3Options, protoFiles); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func runProtoc(
	protocBin string,
	protocGenAS3Bin string,
	as3Out string,
	verbose bool,
	includes []string,
	as3Options []string,
	protoFiles []string,
) error {
	mappings, err := protoMappings(includes)
	if err != nil {
		return err
	}

	args := []string{
		fmt.Sprintf("--plugin=protoc-gen-as3=%s", protocGenAS3Bin),
	}
	for _, include := range includes {
		args = append(args, "-I", filepath.ToSlash(include))
	}

	options := append(mappings, as3Options...)
	if len(options) > 0 {
		args = append(args, "--as3_opt="+strings.Join(options, ","))
	}
	args = append(args, "--as3_out="+as3Out)

	for _, protoFile := range protoFiles {
		args = append(args, normalizeProtoPath(protoFile))
	}

	if verbose {
		fmt.Printf("Executing: %s %s\n", protocBin, strings.Join(args, " "))
	}

	cmd := exec.Command(protocBin, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func protoMappings(includes []string) ([]string, error) {
	const goPackage = "as3.pb"

	protoFiles, err := collectProtoFiles(includes)
	if err != nil {
		return nil, err
	}

	mappings := make([]string, 0, len(protoFiles))
	for _, protoFile := range protoFiles {
		mappings = append(mappings, fmt.Sprintf("M%s=%s", protoFile, goPackage))
	}
	return mappings, nil
}

func collectProtoFiles(includes []string) ([]string, error) {
	seen := make(map[string]struct{})
	var files []string

	for _, include := range includes {
		err := filepath.WalkDir(include, func(path string, d os.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if d.IsDir() || !strings.HasSuffix(d.Name(), ".proto") {
				return nil
			}
			protoPath, err := filepath.Rel(include, path)
			if err != nil {
				return err
			}
			protoPath = normalizeProtoPath(protoPath)
			if _, ok := seen[protoPath]; ok {
				return nil
			}
			seen[protoPath] = struct{}{}
			files = append(files, protoPath)
			return nil
		})
		if err != nil {
			return nil, err
		}
	}

	return files, nil
}

func normalizeProtoPath(path string) string {
	return strings.TrimPrefix(filepath.ToSlash(path), "./")
}
