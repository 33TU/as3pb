package internal

import "log/slog"

// Options controls generator behavior.
type Options struct {
	Debug                     bool
	GenerateAlways            bool
	GenerateAny               *bool
	GenerateClone             *bool
	GenerateSerialize         *bool
	GenerateDeserialize       *bool
	GenerateSerializeMemory   bool
	GenerateDeserializeMemory bool
	Indent                    string
	InlineReset               *bool
	Logger                    *slog.Logger
}

func (o Options) logger() *slog.Logger {
	if o.Logger != nil {
		return o.Logger
	}
	return slog.Default()
}

func (o Options) indent() string {
	if o.Indent != "" {
		return o.Indent
	}
	return DefaultIndent
}

func (o Options) inlineReset() bool {
	return o.InlineReset == nil || *o.InlineReset
}

func (o Options) generateAny() bool {
	return o.GenerateAny == nil || *o.GenerateAny
}

func (o Options) generateClone() bool {
	return o.GenerateClone == nil || *o.GenerateClone
}

func (o Options) generateSerialize() bool {
	return o.GenerateSerialize == nil || *o.GenerateSerialize
}

func (o Options) generateDeserialize() bool {
	return o.GenerateDeserialize == nil || *o.GenerateDeserialize
}

func (o Options) generateSerializeMemory() bool {
	return o.GenerateSerializeMemory
}

func (o Options) generateDeserializeMemory() bool {
	return o.GenerateDeserializeMemory
}

func (o Options) anyDeserialize() bool {
	return o.generateDeserialize() || o.generateDeserializeMemory()
}
