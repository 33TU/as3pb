// Plugin for protoc that generates ActionScript 3 code from .proto files.
package main

import (
	"fmt"
	"log/slog"
	"os"
	"strings"

	"github.com/33TU/as3pb/internal"
	"google.golang.org/protobuf/compiler/protogen"
	"google.golang.org/protobuf/types/pluginpb"
)

func main() {
	options := internal.Options{
		Debug:          parseBool(os.Getenv("AS3PB_DEBUG")),
		GenerateAlways: parseBool(os.Getenv("AS3PB_GENERATE_ALWAYS")),
		Indent:         os.Getenv("AS3PB_INDENT"),
	}
	if value := os.Getenv("AS3PB_INLINE_RESET"); value != "" {
		inlineReset := parseBool(value)
		options.InlineReset = &inlineReset
	}
	if value := os.Getenv("AS3PB_GENERATE_ANY"); value != "" {
		generateAny := parseBool(value)
		options.GenerateAny = &generateAny
	}
	if value := os.Getenv("AS3PB_GENERATE_SERIALIZE"); value != "" {
		generateSerialize := parseBool(value)
		options.GenerateSerialize = &generateSerialize
	}
	if value := os.Getenv("AS3PB_GENERATE_DESERIALIZE"); value != "" {
		generateDeserialize := parseBool(value)
		options.GenerateDeserialize = &generateDeserialize
	}

	protogen.Options{
		ParamFunc: func(name, value string) error {
			switch name {
			case "debug":
				options.Debug = parseBool(value)
			case "generate_always":
				options.GenerateAlways = parseBool(value)
			case "indent":
				options.Indent = value
			case "inline_reset":
				inlineReset := parseBool(value)
				options.InlineReset = &inlineReset
			case "generate_any":
				generateAny := parseBool(value)
				options.GenerateAny = &generateAny
			case "generate_serialize":
				generateSerialize := parseBool(value)
				options.GenerateSerialize = &generateSerialize
			case "generate_deserialize":
				generateDeserialize := parseBool(value)
				options.GenerateDeserialize = &generateDeserialize
			default:
				return fmt.Errorf("unknown parameter %q", name)
			}
			return nil
		},
	}.Run(func(plugin *protogen.Plugin) error {
		plugin.SupportedFeatures = uint64(pluginpb.CodeGeneratorResponse_FEATURE_PROTO3_OPTIONAL)
		options.Logger = logger(options.Debug)
		generator := internal.NewGenerator(plugin, options)
		for _, file := range plugin.Files {
			if err := generator.GenerateFile(file); err != nil {
				return err
			}
		}
		return nil
	})
}

func parseBool(value string) bool {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "1", "t", "true", "y", "yes", "on":
		return true
	default:
		return false
	}
}

func logger(debug bool) *slog.Logger {
	level := slog.LevelInfo
	if debug {
		level = slog.LevelDebug
	}
	return slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{
		Level: level,
	}))
}
