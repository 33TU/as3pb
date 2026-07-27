package internal

import (
	"fmt"
	"io"
)

// DefaultIndent is the default indentation string used by IndentWriter. It is set to four spaces.
const DefaultIndent = "    "

type IndentWriter struct {
	dst    io.Writer
	depth  int
	err    error
	indent string
}

func NewIndentWriter(dst io.Writer, indent string) IndentWriter {
	return IndentWriter{
		dst:    dst,
		indent: indent,
	}
}

func (w *IndentWriter) Reset(dst io.Writer) {
	w.dst = dst
	w.depth = 0
	w.err = nil
}

func (w *IndentWriter) Indent() {
	w.depth++
}

func (w *IndentWriter) Dedent() {
	if w.depth > 0 {
		w.depth--
	}
}

func (w *IndentWriter) Write(format string, args ...any) {
	w.write(format, args...)
}

func (w *IndentWriter) Line(format string, args ...any) {
	w.writeIndent()
	w.write(format, args...)
	w.writeString("\n")
}

func (w *IndentWriter) WriteIndent() {
	w.writeIndent()
}

func (w *IndentWriter) BlankLine() {
	w.writeString("\n")
}

func (w *IndentWriter) Err() error {
	return w.err
}

func (w *IndentWriter) writeIndent() {
	for range w.depth {
		w.writeString(w.indent)
	}
}

func (w *IndentWriter) write(format string, args ...any) {
	if len(args) == 0 {
		w.writeString(format)
		return
	}
	if w.err != nil {
		return
	}
	_, err := fmt.Fprintf(w.dst, format, args...)
	w.setErr(err)
}

func (w *IndentWriter) writeString(s string) {
	if w.err != nil {
		return
	}
	_, err := io.WriteString(w.dst, s)
	w.setErr(err)
}

func (w *IndentWriter) setErr(err error) {
	if err != nil && w.err == nil {
		w.err = err
	}
}
