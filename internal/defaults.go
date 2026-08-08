package internal

import (
	"bytes"
	"fmt"
	"math"
	"strconv"
	"strings"
	"unicode/utf16"
	"unicode/utf8"

	"google.golang.org/protobuf/compiler/protogen"
	"google.golang.org/protobuf/reflect/protoreflect"
)

// generateDefaultConstants emits a DEFAULT_<FIELD> constant for every field
// with a declared default (editions `default = ...` on explicit-presence
// fields). Defaults never appear on the wire and do not affect presence:
// an unset field stays null, and the constant is what callers substitute.
func (g *Generator) generateDefaultConstants(message *protogen.Message, names *MessageNames) {
	var bytesFields []*protogen.Field
	emitted := false

	for _, field := range message.Fields {
		if !field.Desc.HasDefault() {
			continue
		}
		constName := names.Default(field)
		g.generateLeadingComment(protogen.Comments("Declared default for "+names.Field(field)+"; the field itself is null when unset."), false)

		switch kind := field.Desc.Kind(); kind {
		case protoreflect.BoolKind:
			g.w.Line("public static const %s:Boolean = %t;", constName, field.Desc.Default().Bool())
		case protoreflect.Int32Kind, protoreflect.Sint32Kind, protoreflect.Sfixed32Kind:
			g.w.Line("public static const %s:int = %d;", constName, field.Desc.Default().Int())
		case protoreflect.EnumKind:
			g.w.Line("public static const %s:int = %d;", constName, field.Desc.Default().Enum())
		case protoreflect.Uint32Kind, protoreflect.Fixed32Kind:
			g.w.Line("public static const %s:uint = %d;", constName, field.Desc.Default().Uint())
		case protoreflect.FloatKind:
			g.w.Line("public static const %s:Number = %s;", constName, as3NumberLiteral(field.Desc.Default().Float(), 32))
		case protoreflect.DoubleKind:
			g.w.Line("public static const %s:Number = %s;", constName, as3NumberLiteral(field.Desc.Default().Float(), 64))
		case protoreflect.StringKind:
			g.w.Line("public static const %s:String = %s;", constName, as3StringLiteral(field.Desc.Default().String()))
		case protoreflect.Int64Kind, protoreflect.Sint64Kind, protoreflect.Sfixed64Kind:
			value := field.Desc.Default().Int()
			g.w.Line("public static const %s:Int64 = new Int64(%d, %d);", constName, uint32(value), int32(value>>32))
		case protoreflect.Uint64Kind, protoreflect.Fixed64Kind:
			value := field.Desc.Default().Uint()
			g.w.Line("public static const %s:UInt64 = new UInt64(%d, %d);", constName, uint32(value), uint32(value>>32))
		case protoreflect.BytesKind:
			g.w.Line("public static const %s:ByteArray = %s();", constName, names.DefaultMaker(field))
			bytesFields = append(bytesFields, field)
		default:
			panic(fmt.Sprintf("unexpected default on %s field %s", kind, field.Desc.FullName()))
		}
		emitted = true
	}

	if !emitted {
		return
	}
	g.w.BlankLine()

	for _, field := range bytesFields {
		g.w.Line("private static function %s():ByteArray", names.DefaultMaker(field))
		g.w.Line("{")
		g.w.Indent()
		g.w.Line("const bytes:ByteArray = Buffers.newByteArray();")
		value := field.Desc.Default().Bytes()
		if utf8.Valid(value) && !bytes.ContainsRune(value, 0) {
			// Valid UTF-8 round-trips losslessly through the string type,
			// so one writeUTFBytes reproduces the exact default bytes.
			g.w.Line("bytes.writeUTFBytes(%s);", as3StringLiteral(string(value)))
		} else {
			for _, b := range value {
				g.w.Line("bytes.writeByte(%d);", b)
			}
		}
		g.w.Line("return bytes;")
		g.w.Dedent()
		g.w.Line("}")
		g.w.BlankLine()
	}
}

// as3NumberLiteral renders a float default as an AS3 Number expression,
// including the non-finite values proto allows (`inf`, `-inf`, `nan`).
func as3NumberLiteral(value float64, bits int) string {
	switch {
	case math.IsNaN(value):
		return "NaN"
	case math.IsInf(value, 1):
		return "Number.POSITIVE_INFINITY"
	case math.IsInf(value, -1):
		return "Number.NEGATIVE_INFINITY"
	default:
		return strconv.FormatFloat(value, 'g', -1, bits)
	}
}

// as3StringLiteral renders a string default as a double-quoted AS3 literal,
// escaping everything outside printable ASCII so generated files stay
// encoding-agnostic.
func as3StringLiteral(value string) string {
	var b strings.Builder
	b.WriteByte('"')
	for _, r := range value {
		switch {
		case r == '\\':
			b.WriteString(`\\`)
		case r == '"':
			b.WriteString(`\"`)
		case r == '\n':
			b.WriteString(`\n`)
		case r == '\r':
			b.WriteString(`\r`)
		case r == '\t':
			b.WriteString(`\t`)
		case r >= 0x20 && r <= 0x7e:
			b.WriteRune(r)
		case r > 0xffff:
			high, low := utf16.EncodeRune(r)
			fmt.Fprintf(&b, `\u%04x\u%04x`, high, low)
		default:
			fmt.Fprintf(&b, `\u%04x`, r)
		}
	}
	b.WriteByte('"')
	return b.String()
}
