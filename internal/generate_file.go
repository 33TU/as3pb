package internal

import (
	"fmt"
	"strings"

	"google.golang.org/protobuf/compiler/protogen"
	"google.golang.org/protobuf/reflect/protoreflect"
)

var runtimeProvidedFiles = map[string]struct{}{
	"google/protobuf/any.proto":            {},
	"google/protobuf/api.proto":            {},
	"google/protobuf/duration.proto":       {},
	"google/protobuf/empty.proto":          {},
	"google/protobuf/field_mask.proto":     {},
	"google/protobuf/source_context.proto": {},
	"google/protobuf/struct.proto":         {},
	"google/protobuf/timestamp.proto":      {},
	"google/protobuf/type.proto":           {},
	"google/protobuf/wrappers.proto":       {},
}

// GenerateFile emits ActionScript 3 code for one protobuf file.
func (g *Generator) GenerateFile(file *protogen.File) error {
	_, runtimeProvided := runtimeProvidedFiles[file.Desc.Path()]
	if runtimeProvided && !file.Generate {
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
	if err := validateServiceMethods(file); err != nil {
		return err
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

func validateServiceMethods(file *protogen.File) error {
	for _, service := range file.Services {
		for _, method := range service.Methods {
			clientStreaming := method.Desc.IsStreamingClient()
			serverStreaming := method.Desc.IsStreamingServer()
			if !clientStreaming && !serverStreaming {
				continue
			}

			kind := "server-streaming"
			if clientStreaming && serverStreaming {
				kind = "bidirectional-streaming"
			} else if clientStreaming {
				kind = "client-streaming"
			}
			return fmt.Errorf("%s: RPC method %s.%s is %s; streaming RPCs are not supported",
				file.Desc.Path(), service.Desc.FullName(), method.Desc.Name(), kind)
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
