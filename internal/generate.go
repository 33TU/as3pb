package internal

import (
	"log/slog"

	"google.golang.org/protobuf/compiler/protogen"
)

// Generator emits ActionScript 3 code from protobuf descriptors.
type Generator struct {
	plugin         *protogen.Plugin
	opts           Options
	log            *slog.Logger
	w              IndentWriter
	generatedFiles map[string]string
}

// NewGenerator creates a generator with normalized options.
func NewGenerator(plugin *protogen.Plugin, opts Options) *Generator {
	return &Generator{
		plugin:         plugin,
		opts:           opts,
		log:            opts.logger(),
		w:              NewIndentWriter(nil, opts.indent()),
		generatedFiles: make(map[string]string),
	}
}
