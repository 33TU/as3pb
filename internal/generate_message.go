package internal

import (
	"strings"

	"google.golang.org/protobuf/compiler/protogen"
	"google.golang.org/protobuf/reflect/protoreflect"
)

func (g *Generator) generateMessageFile(message *protogen.Message) error {
	for _, nested := range message.Messages {
		if err := g.generateMessageFile(nested); err != nil {
			return err
		}
	}
	for _, enum := range message.Enums {
		if err := g.generateEnumFile(enum); err != nil {
			return err
		}
	}

	filename, file, err := g.newGeneratedFile(string(message.Desc.ParentFile().Package()), MessageClassName(message))
	if err != nil {
		return err
	}
	g.w.Reset(file)

	if err := g.generateMessageClass(message); err != nil {
		return err
	}
	if err := g.w.Err(); err != nil {
		return err
	}

	g.log.Debug("generated message file", "path", filename)
	return nil
}

func (g *Generator) generateMessageClass(message *protogen.Message) error {
	packageName := string(message.Desc.ParentFile().Package())
	names := NewMessageNames(message)

	g.generateFileHeaderComment(message.Desc.ParentFile().Path())
	g.w.Line("package %s", packageName)
	g.w.Line("{")
	g.w.Indent()

	g.generateMessageFieldImports(message)
	g.generateLeadingComment(message.Comments.Leading, false)
	g.w.Line("public final class %s", MessageClassName(message))
	g.w.Line("{")
	g.w.Indent()

	if g.generateTrailingComment(true, message.Comments.Trailing) {
		g.w.BlankLine()
	}
	if g.needsMessageStaticFields(message) {
		g.generateMessageStaticFields(message)
		g.w.BlankLine()
	}
	g.generateMessageFields(message, names)
	if len(message.Fields) > 0 || len(message.Oneofs) > 0 {
		g.w.BlankLine()
	}
	g.generateResetMethod(message, names)
	if g.opts.generateDeserialize() {
		g.w.BlankLine()
		g.generateDeserializeMethod(message, names)
	}
	if g.opts.generateSerialize() {
		g.w.BlankLine()
		g.generateSerializeMethod(message, names)
	}
	if g.opts.generateAny() && g.opts.generateDeserialize() && g.opts.generateSerialize() {
		g.w.BlankLine()
		g.generateAnyRegistration()
	}

	g.w.Dedent()
	g.w.Line("}")
	g.w.Dedent()
	g.w.Line("}")
	return nil
}

func (g *Generator) generateMessageFieldImports(message *protogen.Message) {
	if g.needsByteArrayImport(message) {
		g.w.Line("import flash.utils.ByteArray;")
	}
	if g.opts.generateDeserialize() {
		g.w.Line("import as3pb.proto.Deserialize;")
	}
	if g.opts.generateSerialize() {
		g.w.Line("import as3pb.proto.Serialize;")
	}
	if g.needsBuffersImport(message) {
		g.w.Line("import as3pb.proto.Buffers;")
	}
	if has64BitFields(message) {
		g.w.Line("import as3pb.types.Int64;")
		g.w.Line("import as3pb.types.UInt64;")
		g.w.Line("import as3pb.types.Int64Vector;")
		g.w.Line("import as3pb.types.UInt64Vector;")
	}
	if hasAnyFields(message) {
		g.w.Line("import as3pb.types.Any;")
	}
	if g.opts.generateAny() && g.opts.generateDeserialize() && g.opts.generateSerialize() {
		g.w.Line("import as3pb.types.AnyRegistry;")
	}
	g.w.BlankLine()
}

func (g *Generator) generateMessageStaticFields(message *protogen.Message) {
	if g.opts.generateAny() {
		g.w.Line(
			`public static const TYPE_URL:String = "type.googleapis.com/%s";`,
			message.Desc.FullName(),
		)
	}
	if g.opts.generateDeserialize() && hasRepeatedVarint64Fields(message) {
		g.w.Line("private static const TMP_UINT64:UInt64 = new UInt64();")
		g.w.Line("private static const TMP_INT64:Int64 = new Int64();")
	}
}

func (g *Generator) generateAnyRegistration() {
	g.w.Line("{")
	g.w.Indent()
	g.w.Line("AnyRegistry.register(TYPE_URL, deserializeBytes, serializeBytes);")
	g.w.Dedent()
	g.w.Line("}")
}

func (g *Generator) needsMessageStaticFields(message *protogen.Message) bool {
	return g.opts.generateAny() ||
		(g.opts.generateDeserialize() && hasRepeatedVarint64Fields(message))
}

func (g *Generator) needsByteArrayImport(message *protogen.Message) bool {
	return g.opts.generateSerialize() || g.opts.generateDeserialize() || hasBytesFields(message)
}

func (g *Generator) needsBuffersImport(message *protogen.Message) bool {
	return hasBytesFields(message) ||
		(g.opts.generateSerialize() && (hasPackedFields(message) || hasStringFields(message) || hasMessageFields(message))) ||
		(g.opts.generateDeserialize() && hasRepeatedBytesFields(message))
}

func (g *Generator) generateMessageFields(message *protogen.Message, names *MessageNames) {
	currentPackage := string(message.Desc.ParentFile().Package())

	for _, field := range message.Fields {
		if field.Oneof == nil {
			continue
		}
		g.w.Line("public static const %s:uint = %d;", names.FieldNumber(field), field.Desc.Number())
	}
	if len(message.Oneofs) > 0 {
		g.w.BlankLine()
	}

	for i, field := range message.Fields {
		if field.Comments.Leading != "" && i > 0 {
			g.w.BlankLine()
		}
		g.generateLeadingComment(field.Comments.Leading, false)
		g.w.WriteIndent()
		g.w.Write(
			"public var %s:%s = %s;",
			names.Field(field),
			AS3Type(field, currentPackage),
			AS3DefaultValue(field, currentPackage),
		)
		g.generateTrailingComment(false, field.Comments.Trailing)
		g.w.Write("\n")
	}

	for _, oneof := range message.Oneofs {
		g.w.BlankLine()
		g.generateLeadingComment(oneofCaseComment(oneof, names), false)
		g.w.Line("public var %s:uint;", names.OneofCase(oneof))
	}
}

func oneofCaseComment(oneof *protogen.Oneof, names *MessageNames) protogen.Comments {
	values := make([]string, 0, len(oneof.Fields))
	for _, field := range oneof.Fields {
		values = append(values, names.FieldNumber(field))
	}

	lines := commentLines(oneof.Comments.Leading)
	lines = append(lines, "Active case for "+string(oneof.Desc.Name())+": "+strings.Join(values, ", ")+".")
	return protogen.Comments(strings.Join(lines, "\n"))
}

func (g *Generator) generateResetMethod(message *protogen.Message, names *MessageNames) {
	currentPackage := string(message.Desc.ParentFile().Package())

	g.generateLeadingComment(protogen.Comments("Resets the message fields to their default values.\n@param msg The message to reset."), false)
	if g.opts.inlineReset() {
		g.w.Line("[Inline]")
	}
	g.w.Line("public static function reset(msg:%s):void", MessageClassName(message))
	g.w.Line("{")
	g.w.Indent()

	for _, field := range message.Fields {
		fieldName := "msg." + names.Field(field)

		if field.Desc.IsList() || field.Desc.IsMap() || field.Desc.Kind() == protoreflect.BytesKind {
			g.w.Line("%s.length = 0;", fieldName)
			continue
		}

		if is64BitInteger(field.Desc.Kind()) {
			g.w.Line("%s.low = 0;", fieldName)
			g.w.Line("%s.high = 0;", fieldName)
			continue
		}

		g.w.Line("%s = %s;", fieldName, AS3DefaultValue(field, currentPackage))
	}

	for _, oneof := range message.Oneofs {
		g.w.Line("msg.%s = 0;", names.OneofCase(oneof))
	}

	g.w.Dedent()
	g.w.Line("}")
}
