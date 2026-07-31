package internal

import (
	"fmt"

	"google.golang.org/protobuf/compiler/protogen"
	"google.golang.org/protobuf/reflect/protoreflect"
)

func (g *Generator) generateDeserializeMethod(message *protogen.Message, names *MessageNames) {
	currentPackage := string(message.Desc.ParentFile().Package())
	messageName := MessageClassName(message)

	g.generateLeadingComment(protogen.Comments(
		"Deserializes the message from protobuf wire format.\n"+
			"@param src The source ByteArray.\n"+
			"@param dst Optional reusable destination message.\n"+
			"@param limit Optional end position; zero means the remaining bytes.",
	), false)
	g.w.Line(
		"public static function deserializeBytes(src:ByteArray, dst:%s = null, limit:uint = 0):%s",
		messageName,
		messageName,
	)
	g.w.Line("{")
	g.w.Indent()

	g.w.Line("if (!dst)")
	g.w.Indent()
	g.w.Line("dst = new %s();", messageName)
	g.w.Dedent()
	g.w.Line("else")
	g.w.Indent()
	g.w.Line("%s.reset(dst);", messageName)
	g.w.Dedent()
	g.w.BlankLine()

	if hasMessageFields(message) {
		g.w.Line("var messageLength:uint = 0;")
		g.w.BlankLine()
	}

	g.w.Line("const end:uint = limit ? limit : src.position + src.bytesAvailable;")
	g.w.Line("if (end < src.position || end > src.length)")
	g.w.Indent()
	g.w.Line(`throw new Error("Invalid protobuf message limit");`)
	g.w.Dedent()
	g.w.BlankLine()
	g.w.Line("while (src.position < end)")
	g.w.Line("{")
	g.w.Indent()
	g.w.Line("const tag:uint = Deserialize.readVarint32(src);")
	g.w.Line("switch (tag)")
	g.w.Line("{")
	g.w.Indent()

	for _, field := range message.Fields {
		tag := (int(field.Desc.Number()) << 3) | int(WireTypeForField(field))
		fieldName := "dst." + names.Field(field)

		g.w.Line("case %d:", tag)
		g.w.Line("{")
		g.w.Indent()

		if field.Oneof != nil {
			g.w.Line("dst.%s = %d;", names.OneofCase(field.Oneof), field.Desc.Number())
		}

		if field.Desc.IsList() || field.Desc.IsMap() {
			if field.Desc.IsPacked() {
				g.generateFieldDeserializerForRepeatedPackedType(field, fieldName)
			} else {
				g.generateFieldDeserializerForRepeatedUnpackedType(field, fieldName, currentPackage)
			}
		} else {
			g.generateFieldDeserializerForType(field, fieldName, currentPackage)
		}

		g.w.Line("break;")
		g.w.Dedent()
		g.w.Line("}")
	}

	g.w.Line("default:")
	g.w.Line("{")
	g.w.Indent()
	g.w.Line("Deserialize.skipField(src, tag & 7);")
	g.w.Line("break;")
	g.w.Dedent()
	g.w.Line("}")

	g.w.Dedent()
	g.w.Line("}")
	g.w.Dedent()
	g.w.Line("}")
	g.w.BlankLine()

	g.w.Line("if (src.position > end)")
	g.w.Indent()
	g.w.Line(`throw new Error("Truncated protobuf message");`)
	g.w.Dedent()
	g.w.BlankLine()

	g.w.Line("return dst;")
	g.w.Dedent()
	g.w.Line("}")
}

func (g *Generator) generateFieldDeserializerForType(field *protogen.Field, fieldName string, currentPackage string) {
	switch field.Desc.Kind() {
	case protoreflect.BoolKind:
		g.w.Line("%s = Deserialize.readVarint32(src) !== 0;", fieldName)
	case protoreflect.Uint32Kind:
		g.w.Line("%s = Deserialize.readVarint32(src);", fieldName)
	case protoreflect.EnumKind, protoreflect.Int32Kind:
		g.w.Line("%s = Deserialize.readInt32(src);", fieldName)
	case protoreflect.Sint32Kind:
		g.w.Line("%s = Deserialize.readSint32(src);", fieldName)
	case protoreflect.Sfixed32Kind:
		g.w.Line("%s = src.readInt();", fieldName)
	case protoreflect.Fixed32Kind:
		g.w.Line("%s = src.readUnsignedInt();", fieldName)
	case protoreflect.Int64Kind:
		g.w.Line("Deserialize.readVarint64s(src, %s);", fieldName)
	case protoreflect.Sint64Kind:
		g.w.Line("Deserialize.readSint64(src, %s);", fieldName)
	case protoreflect.Uint64Kind:
		g.w.Line("Deserialize.readVarint64(src, %s);", fieldName)
	case protoreflect.Sfixed64Kind:
		g.w.Line("Deserialize.readSfixed64(src, %s);", fieldName)
	case protoreflect.Fixed64Kind:
		g.w.Line("Deserialize.readFixed64(src, %s);", fieldName)
	case protoreflect.FloatKind:
		g.w.Line("%s = src.readFloat();", fieldName)
	case protoreflect.DoubleKind:
		g.w.Line("%s = src.readDouble();", fieldName)
	case protoreflect.StringKind:
		g.w.Line("%s = src.readUTFBytes(Deserialize.readVarint32(src));", fieldName)
	case protoreflect.BytesKind:
		g.w.Line("%s.length = 0;", fieldName)
		g.w.Line("src.readBytes(%s, 0, Deserialize.readVarint32(src));", fieldName)
	case protoreflect.MessageKind:
		messageType := as3ElementType(field, currentPackage)
		g.w.Line("if ((messageLength = Deserialize.readVarint32(src)) !== 0)")
		g.w.Indent()
		// Passing the existing field here would allow singular message reuse and merge semantics.
		// For now, prefer the safer default that pairs with reset assigning message fields to null.
		g.w.Line("%s = %s.deserializeBytes(src, null, src.position + messageLength);", fieldName, messageType)
		g.w.Dedent()
	}
}

func (g *Generator) generateFieldDeserializerForRepeatedUnpackedType(field *protogen.Field, fieldName string, currentPackage string) {
	switch field.Desc.Kind() {
	case protoreflect.BoolKind:
		g.w.Line("%s.push(Deserialize.readVarint32(src) !== 0);", fieldName)
	case protoreflect.Uint32Kind:
		g.w.Line("%s.push(Deserialize.readVarint32(src));", fieldName)
	case protoreflect.EnumKind, protoreflect.Int32Kind:
		g.w.Line("%s.push(Deserialize.readInt32(src));", fieldName)
	case protoreflect.Sint32Kind:
		g.w.Line("%s.push(Deserialize.readSint32(src));", fieldName)
	case protoreflect.Sfixed32Kind:
		g.w.Line("%s.push(src.readInt());", fieldName)
	case protoreflect.Fixed32Kind:
		g.w.Line("%s.push(src.readUnsignedInt());", fieldName)
	case protoreflect.Uint64Kind:
		g.w.Line("Deserialize.readVarint64(src, TMP_UINT64);")
		g.w.Line("%s.push(TMP_UINT64.low, TMP_UINT64.high);", fieldName)
	case protoreflect.Int64Kind:
		g.w.Line("Deserialize.readVarint64s(src, TMP_INT64);")
		g.w.Line("%s.push(TMP_INT64.low, TMP_INT64.high);", fieldName)
	case protoreflect.Sint64Kind:
		g.w.Line("Deserialize.readSint64(src, TMP_INT64);")
		g.w.Line("%s.push(TMP_INT64.low, TMP_INT64.high);", fieldName)
	case protoreflect.Sfixed64Kind:
		g.w.Line("%s.push(src.readUnsignedInt(), src.readInt());", fieldName)
	case protoreflect.Fixed64Kind:
		g.w.Line("%s.push(src.readUnsignedInt(), src.readUnsignedInt());", fieldName)
	case protoreflect.FloatKind:
		g.w.Line("%s.push(src.readFloat());", fieldName)
	case protoreflect.DoubleKind:
		g.w.Line("%s.push(src.readDouble());", fieldName)
	case protoreflect.StringKind:
		g.w.Line("%s.push(src.readUTFBytes(Deserialize.readVarint32(src)));", fieldName)
	case protoreflect.BytesKind:
		g.w.Line("var tmp:ByteArray = Buffers.newByteArray();")
		g.w.Line("Deserialize.readBytesInto(src, tmp);")
		g.w.Line("%s.push(tmp);", fieldName)
	case protoreflect.MessageKind:
		messageType := as3ElementType(field, currentPackage)
		messageName := "msg" + FieldNamePascal(field)
		g.w.Line("const %s:%s = new %s();", messageName, messageType, messageType)
		g.w.Line("if ((messageLength = Deserialize.readVarint32(src)) !== 0)")
		g.w.Indent()
		g.w.Line("%s.deserializeBytes(src, %s, src.position + messageLength);", messageType, messageName)
		g.w.Dedent()
		g.w.Line("%s.push(%s);", fieldName, messageName)
	}
}

func (g *Generator) generateFieldDeserializerForRepeatedPackedType(field *protogen.Field, fieldName string) {
	switch field.Desc.Kind() {
	case protoreflect.EnumKind, protoreflect.Uint32Kind:
		g.w.Line("Deserialize.readVarint32Vector(src, %s);", fieldName)
	case protoreflect.Int32Kind:
		g.w.Line("Deserialize.readInt32Vector(src, %s);", fieldName)
	case protoreflect.Sint32Kind:
		g.w.Line("Deserialize.readSint32Vector(src, %s);", fieldName)
	case protoreflect.Int64Kind:
		g.w.Line("Deserialize.readVarint64sVector(src, %s);", fieldName)
	case protoreflect.Uint64Kind:
		g.w.Line("Deserialize.readVarint64Vector(src, %s);", fieldName)
	case protoreflect.Sint64Kind:
		g.w.Line("Deserialize.readSint64Vector(src, %s);", fieldName)
	case protoreflect.Fixed32Kind:
		g.w.Line("Deserialize.readFixed32Vector(src, %s);", fieldName)
	case protoreflect.Sfixed32Kind:
		g.w.Line("Deserialize.readFixed32sVector(src, %s);", fieldName)
	case protoreflect.Fixed64Kind:
		g.w.Line("Deserialize.readFixed64Vector(src, %s);", fieldName)
	case protoreflect.Sfixed64Kind:
		g.w.Line("Deserialize.readFixed64sVector(src, %s);", fieldName)
	case protoreflect.FloatKind:
		g.w.Line("Deserialize.readFloatVector(src, %s);", fieldName)
	case protoreflect.DoubleKind:
		g.w.Line("Deserialize.readDoubleVector(src, %s);", fieldName)
	case protoreflect.BoolKind:
		g.w.Line("Deserialize.readBoolVector(src, %s);", fieldName)
	default:
		g.w.Line("// unsupported packed field %s", fmt.Sprint(field.Desc.FullName()))
	}
}
