package internal

import (
	"fmt"
	"strings"

	"google.golang.org/protobuf/compiler/protogen"
	"google.golang.org/protobuf/reflect/protoreflect"
)

func (g *Generator) generateSerializeMethod(message *protogen.Message, names *MessageNames) {
	currentPackage := string(message.Desc.ParentFile().Package())
	messageName := MessageClassName(message)

	nonOneofFields := make([]*protogen.Field, 0, len(message.Fields))
	oneofGroups := make(map[*protogen.Oneof][]*protogen.Field)
	oneofs := make([]*protogen.Oneof, 0, len(message.Oneofs))
	for _, oneof := range message.Oneofs {
		if oneof.Desc.IsSynthetic() {
			continue
		}
		oneofs = append(oneofs, oneof)
	}
	for _, field := range message.Fields {
		if isRealOneof(field) {
			oneofGroups[field.Oneof] = append(oneofGroups[field.Oneof], field)
			continue
		}
		nonOneofFields = append(nonOneofFields, field)
	}

	g.generateLeadingComment(protogen.Comments(
		"Serializes the message to protobuf wire format.\n"+
			"@param src The message to serialize; null writes an empty payload.\n"+
			"@param dst The destination ByteArray.",
	), false)
	g.w.Line("public static function serializeBytes(src:%s, dst:ByteArray):void", messageName)
	g.w.Line("{")
	g.w.Indent()

	g.w.Line("if (!src)")
	g.w.Indent()
	g.w.Line("return;")
	g.w.Dedent()
	g.w.BlankLine()

	newLine := false
	if hasRepeatedUnpackedFields(message) {
		g.w.Line("var vecIndex:uint = 0;")
		newLine = true
	}
	if hasListOrMapFields(message) {
		g.w.Line("var vecLength:uint = 0;")
		newLine = true
	}
	if hasPackedFields(message) || hasBytesFields(message) || hasStringFields(message) {
		g.w.Line("const reuseBuffer:ByteArray = Buffers.SHARED_BUFFER;")
		newLine = true
	}
	if hasMessageFields(message) {
		g.w.Line("const messageReuseBuffer:ByteArray = Buffers.acquireMessageBuffer();")
		newLine = true
	}
	if newLine {
		g.w.BlankLine()
	}

	for _, field := range message.Fields {
		g.w.Line(
			"const %s:%s = src.%s;",
			localFieldName(field, names),
			AS3Type(field, currentPackage),
			names.Field(field),
		)
	}
	if len(message.Fields) > 0 {
		g.w.BlankLine()
	}

	if hasMessageFields(message) {
		g.w.Line("try")
		g.w.Line("{")
		g.w.Indent()
	}

	for _, field := range nonOneofFields {
		g.generateSerializeFieldBlock(field, names, currentPackage)
	}
	if len(nonOneofFields) > 0 && len(oneofs) > 0 {
		g.w.BlankLine()
	}

	for i, oneof := range oneofs {
		if i > 0 {
			g.w.BlankLine()
		}
		g.w.Line("switch (src.%s)", names.OneofCase(oneof))
		g.w.Line("{")
		g.w.Indent()
		for _, field := range oneofGroups[oneof] {
			g.w.Line("case %s:", names.FieldNumber(field))
			g.w.Line("{")
			g.w.Indent()
			g.generateMessageFieldSerializer(field, localFieldName(field, names), currentPackage)
			g.w.Line("break;")
			g.w.Dedent()
			g.w.Line("}")
		}
		g.w.Dedent()
		g.w.Line("}")
	}

	if hasMessageFields(message) {
		g.w.Dedent()
		g.w.Line("}")
		g.w.Line("finally")
		g.w.Line("{")
		g.w.Indent()
		g.w.Line("Buffers.releaseMessageBuffer(messageReuseBuffer);")
		g.w.Dedent()
		g.w.Line("}")
	}

	g.w.Dedent()
	g.w.Line("}")
}

func (g *Generator) generateSerializeFieldBlock(field *protogen.Field, names *MessageNames, currentPackage string) {
	localName := localFieldName(field, names)

	if field.Desc.IsList() || field.Desc.IsMap() {
		g.w.Line("if ((vecLength = %s.length) !== 0)", localName)
	} else {
		g.w.Line("if (%s)", fieldCondition(field, localName))
	}
	g.w.Line("{")
	g.w.Indent()
	g.generateMessageFieldSerializer(field, localName, currentPackage)
	g.w.Dedent()
	g.w.Line("}")
}

func (g *Generator) generateWriteTag(field *protogen.Field) {
	fieldNumber := int(field.Desc.Number())
	wireType := int(WireTypeForField(field))
	tag := (fieldNumber << 3) | wireType

	if tag < 128 {
		g.w.Line("dst.writeByte(%d);", tag)
		return
	}
	if tag < 16384 {
		byte1 := (tag & 0x7F) | 0x80
		byte2 := tag >> 7
		shortValue := (byte2 << 8) | byte1
		g.w.Line("dst.writeShort(%d);", shortValue)
		return
	}
	if tag < 2097152 {
		byte1 := (tag & 0x7F) | 0x80
		byte2 := ((tag >> 7) & 0x7F) | 0x80
		byte3 := tag >> 14
		shortValue := (byte3 << 8) | byte2
		g.w.Line("dst.writeByte(%d);", byte1)
		g.w.Line("dst.writeShort(%d);", shortValue)
		return
	}
	if tag < 268435456 {
		byte1 := (tag & 0x7F) | 0x80
		byte2 := ((tag >> 7) & 0x7F) | 0x80
		byte3 := ((tag >> 14) & 0x7F) | 0x80
		byte4 := tag >> 21
		shortValue1 := (byte2 << 8) | byte1
		shortValue2 := (byte4 << 8) | byte3
		g.w.Line("dst.writeShort(%d);", shortValue1)
		g.w.Line("dst.writeShort(%d);", shortValue2)
		return
	}
	if tag <= 0xffffffff {
		byte1 := (tag & 0x7F) | 0x80
		byte2 := ((tag >> 7) & 0x7F) | 0x80
		byte3 := ((tag >> 14) & 0x7F) | 0x80
		byte4 := ((tag >> 21) & 0x7F) | 0x80
		byte5 := tag >> 28
		shortValue1 := (byte2 << 8) | byte1
		shortValue2 := (byte4 << 8) | byte3
		g.w.Line("dst.writeShort(%d);", shortValue1)
		g.w.Line("dst.writeShort(%d);", shortValue2)
		g.w.Line("dst.writeByte(%d);", byte5)
		return
	}
	panic(fmt.Sprintf("protobuf tag %d exceeds uint32", tag))
}

func (g *Generator) generateFieldSerializerForType(field *protogen.Field, valueExpr string, currentPackage string) {
	switch field.Desc.Kind() {
	case protoreflect.BoolKind:
		g.w.Line("dst.writeByte(%s ? 1 : 0);", valueExpr)
	case protoreflect.Uint32Kind:
		g.w.Line("Serialize.writeVarint32(dst, %s);", valueExpr)
	case protoreflect.EnumKind, protoreflect.Int32Kind:
		g.w.Line("Serialize.writeInt32(dst, %s);", valueExpr)
	case protoreflect.Sint32Kind:
		g.w.Line("Serialize.writeSint32(dst, %s);", valueExpr)
	case protoreflect.Int64Kind:
		g.w.Line("Serialize.writeVarint64s(dst, %s.low, %s.high);", valueExpr, valueExpr)
	case protoreflect.Uint64Kind:
		g.w.Line("Serialize.writeVarint64(dst, %s.low, %s.high);", valueExpr, valueExpr)
	case protoreflect.Sint64Kind:
		g.w.Line("Serialize.writeSint64(dst, %s.low, %s.high);", valueExpr, valueExpr)
	case protoreflect.Sfixed32Kind:
		g.w.Line("dst.writeInt(%s);", valueExpr)
	case protoreflect.Fixed32Kind:
		g.w.Line("dst.writeUnsignedInt(%s);", valueExpr)
	case protoreflect.FloatKind:
		g.w.Line("dst.writeFloat(%s);", valueExpr)
	case protoreflect.Sfixed64Kind:
		g.w.Line("dst.writeUnsignedInt(%s.low);", valueExpr)
		g.w.Line("dst.writeInt(%s.high);", valueExpr)
	case protoreflect.Fixed64Kind:
		g.w.Line("dst.writeUnsignedInt(%s.low);", valueExpr)
		g.w.Line("dst.writeUnsignedInt(%s.high);", valueExpr)
	case protoreflect.DoubleKind:
		g.w.Line("dst.writeDouble(%s);", valueExpr)
	case protoreflect.StringKind:
		g.w.Line("Serialize.writeString(dst, %s, reuseBuffer);", valueExpr)
	case protoreflect.BytesKind:
		g.w.Line("Serialize.writeBytes(dst, %s);", valueExpr)
	case protoreflect.MessageKind:
		messageType := as3ElementType(field, currentPackage)
		g.w.Line("messageReuseBuffer.length = 0;")
		g.w.Line("%s.serializeBytes(%s, messageReuseBuffer);", messageType, valueExpr)
		g.w.Line("Serialize.writeVarint32(dst, messageReuseBuffer.length);")
		g.w.Line("dst.writeBytes(messageReuseBuffer);")
	}
}

func (g *Generator) generateFieldSerializerForRepeatedPackedType(field *protogen.Field, locName string) {
	g.generateWriteTag(field)

	switch field.Desc.Kind() {
	case protoreflect.Uint32Kind:
		g.w.Line("Serialize.writeVarint32Vector(dst, %s, reuseBuffer, vecLength);", locName)
	case protoreflect.EnumKind, protoreflect.Int32Kind:
		g.w.Line("Serialize.writeInt32Vector(dst, %s, reuseBuffer, vecLength);", locName)
	case protoreflect.Sint32Kind:
		g.w.Line("Serialize.writeSint32Vector(dst, %s, reuseBuffer, vecLength);", locName)
	case protoreflect.Int64Kind:
		g.w.Line("Serialize.writeVarint64sVector(dst, %s, reuseBuffer, vecLength);", locName)
	case protoreflect.Uint64Kind:
		g.w.Line("Serialize.writeVarint64Vector(dst, %s, reuseBuffer, vecLength);", locName)
	case protoreflect.Sint64Kind:
		g.w.Line("Serialize.writeSint64Vector(dst, %s, reuseBuffer, vecLength);", locName)
	case protoreflect.Fixed32Kind:
		g.w.Line("Serialize.writeFixed32Vector(dst, %s, vecLength);", locName)
	case protoreflect.Sfixed32Kind:
		g.w.Line("Serialize.writeSfixed32Vector(dst, %s, vecLength);", locName)
	case protoreflect.Fixed64Kind:
		g.w.Line("Serialize.writeFixed64Vector(dst, %s, vecLength);", locName)
	case protoreflect.Sfixed64Kind:
		g.w.Line("Serialize.writeSfixed64Vector(dst, %s, vecLength);", locName)
	case protoreflect.FloatKind:
		g.w.Line("Serialize.writeFloatVector(dst, %s, vecLength);", locName)
	case protoreflect.DoubleKind:
		g.w.Line("Serialize.writeDoubleVector(dst, %s, vecLength);", locName)
	case protoreflect.BoolKind:
		g.w.Line("Serialize.writeBoolVector(dst, %s, vecLength);", locName)
	default:
		g.w.Line("// unsupported packed field %s", fmt.Sprint(field.Desc.FullName()))
	}
}

func (g *Generator) generateFieldSerializerForRepeatedUnpackedType(field *protogen.Field, locName string, currentPackage string) {
	g.w.Line("for (vecIndex = 0; vecIndex < vecLength; vecIndex++)")
	g.w.Line("{")
	g.w.Indent()
	g.generateWriteTag(field)
	g.generateFieldSerializerForType(field, locName+"[vecIndex]", currentPackage)
	g.w.Dedent()
	g.w.Line("}")
}

func (g *Generator) generateMessageFieldSerializer(field *protogen.Field, fieldName string, currentPackage string) {
	if field.Desc.IsList() || field.Desc.IsMap() {
		if field.Desc.IsPacked() {
			g.generateFieldSerializerForRepeatedPackedType(field, fieldName)
			return
		}
		g.generateFieldSerializerForRepeatedUnpackedType(field, fieldName, currentPackage)
		return
	}

	g.generateWriteTag(field)
	g.generateFieldSerializerForType(field, optionalValueExpression(field, fieldName), currentPackage)
}

func fieldCondition(field *protogen.Field, fieldName string) string {
	if field.Desc.HasOptionalKeyword() {
		return fieldName + " != null"
	}
	switch field.Desc.Kind() {
	case protoreflect.BytesKind:
		return fieldName + ".length"
	case protoreflect.FloatKind, protoreflect.DoubleKind:
		return fieldName + " != 0.0"
	case protoreflect.Int64Kind, protoreflect.Sint64Kind, protoreflect.Uint64Kind, protoreflect.Sfixed64Kind, protoreflect.Fixed64Kind:
		return fmt.Sprintf("%s.low || %s.high", fieldName, fieldName)
	default:
		return fieldName
	}
}

func optionalValueExpression(field *protogen.Field, fieldName string) string {
	if !field.Desc.HasOptionalKeyword() {
		return fieldName
	}
	switch field.Desc.Kind() {
	case protoreflect.StringKind, protoreflect.BytesKind, protoreflect.MessageKind:
		return fieldName
	default:
		return fieldName + ".value"
	}
}

func localFieldName(field *protogen.Field, names *MessageNames) string {
	return "local" + toPascalCase(strings.TrimSuffix(names.Field(field), "_"))
}
