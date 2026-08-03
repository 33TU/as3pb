package internal

import (
	"fmt"
	"strings"

	"google.golang.org/protobuf/compiler/protogen"
	"google.golang.org/protobuf/reflect/protoreflect"
)

// GenerateFile emits ActionScript 3 code for one protobuf file.
func (g *Generator) GenerateFile(file *protogen.File) error {
	if file.Desc.Path() == "google/protobuf/any.proto" && !file.Generate {
		g.log.Debug("skipping runtime-provided file", "path", file.Desc.Path())
		return nil
	}
	if !file.Generate && !g.opts.GenerateAlways {
		g.log.Debug("skipping file", "path", file.Desc.Path())
		return nil
	}
	if file.Desc.Syntax() != protoreflect.Proto3 {
		return fmt.Errorf("%s: only proto3 files are supported", file.Desc.Path())
	}

	g.log.Debug("processing file", "path", file.Desc.Path())

	for _, enum := range file.Enums {
		if err := g.generateEnumFile(enum); err != nil {
			return err
		}
	}
	for _, message := range file.Messages {
		if err := g.generateMessageFile(message); err != nil {
			return err
		}
	}
	if len(file.Services) > 0 && (!g.opts.generateSerialize() || !g.opts.generateDeserialize()) {
		return fmt.Errorf("%s: services require serialize and deserialize generation", file.Desc.Path())
	}
	for _, service := range file.Services {
		if err := g.generateServiceFile(service); err != nil {
			return err
		}
	}

	return nil
}

func (g *Generator) newGeneratedFile(packageName, name string) (string, *protogen.GeneratedFile, error) {
	dir := strings.ReplaceAll(packageName, ".", "/")
	filename := name + ".as"
	if dir != "" {
		filename = dir + "/" + filename
	}

	if existing, ok := g.generatedFiles[filename]; ok {
		return "", nil, fmt.Errorf("generated AS3 file %q for %s collides with %s", filename, name, existing)
	}
	g.generatedFiles[filename] = name

	return filename, g.plugin.NewGeneratedFile(filename, ""), nil
}
