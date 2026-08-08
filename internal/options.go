package internal

import "log/slog"

// Options controls generator behavior.
type Options struct {
	Debug               bool
	GenerateAlways      bool
	GenerateAny         *bool
	GenerateClone       *bool
	GenerateSerialize   *bool
	GenerateDeserialize *bool
	Indent              string
	InlineReset         *bool
	Logger              *slog.Logger
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
