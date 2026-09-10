package internal

import (
	"fmt"

	"google.golang.org/protobuf/compiler/protogen"
	"google.golang.org/protobuf/reflect/protoreflect"
)

func (g *Generator) generateSerializeMemoryMethod(message *protogen.Message, names *MessageNames) {
	currentPackage := string(message.Desc.ParentFile().Package())
	messageName := QualifiedMessageClassName(message)

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
			"@param dst The active PackContext; bind with Pack.begin first.",
	), false)
	g.w.Line("public static function serializeMemory(src:%s, dst:PackContext):void", messageName)
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
	if hasMessageFields(message) {
		g.w.Line("var messageStart:uint;")
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

	for _, field := range nonOneofFields {
		g.generateMemorySerializeFieldBlock(field, names, currentPackage)
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
			g.generateMemoryMessageFieldSerializer(field, localFieldName(field, names), currentPackage)
			g.w.Line("break;")
			g.w.Dedent()
			g.w.Line("}")
		}
		g.w.Dedent()
		g.w.Line("}")
	}

	g.w.EnsureBlankLine()
	g.w.Line("if (src.unknownFields)")
	g.w.Indent()
	g.w.Line("Pack.writeRawBytes(dst, src.unknownFields);")
	g.w.Dedent()

	g.w.Dedent()
	g.w.Line("}")
}

func (g *Generator) generateMemorySerializeFieldBlock(field *protogen.Field, names *MessageNames, currentPackage string) {
	localName := localFieldName(field, names)

	if field.Desc.IsList() || field.Desc.IsMap() {
		g.w.Line("if ((vecLength = %s.length) !== 0)", localName)
	} else {
		g.w.Line("if (%s)", fieldCondition(field, localName))
	}
	g.w.Line("{")
	g.w.Indent()
	g.generateMemoryMessageFieldSerializer(field, localName, currentPackage)
	g.w.Dedent()
	g.w.Line("}")
}

func (g *Generator) generateMemoryWriteTag(field *protogen.Field) {
	fieldNumber := int(field.Desc.Number())
	wireType := int(WireTypeForField(field))
	tag := (fieldNumber << 3) | wireType

	if tag < 128 {
		g.w.Line("Pack.writeByte(dst, %d);", tag)
		return
	}
	if tag < 16384 {
		byte1 := (tag & 0x7F) | 0x80
		byte2 := tag >> 7
		shortValue := (byte2 << 8) | byte1
		g.w.Line("Pack.writeShort(dst, %d);", shortValue)
		return
	}
	if tag < 2097152 {
		byte1 := (tag & 0x7F) | 0x80
		byte2 := ((tag >> 7) & 0x7F) | 0x80
		byte3 := tag >> 14
		shortValue := (byte3 << 8) | byte2
		g.w.Line("Pack.writeByte(dst, %d);", byte1)
		g.w.Line("Pack.writeShort(dst, %d);", shortValue)
		return
	}
	if tag < 268435456 {
		byte1 := (tag & 0x7F) | 0x80
		byte2 := ((tag >> 7) & 0x7F) | 0x80
		byte3 := ((tag >> 14) & 0x7F) | 0x80
		byte4 := tag >> 21
		shortValue1 := (byte2 << 8) | byte1
		shortValue2 := (byte4 << 8) | byte3
		g.w.Line("Pack.writeShort(dst, %d);", shortValue1)
		g.w.Line("Pack.writeShort(dst, %d);", shortValue2)
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
		g.w.Line("Pack.writeShort(dst, %d);", shortValue1)
		g.w.Line("Pack.writeShort(dst, %d);", shortValue2)
		g.w.Line("Pack.writeByte(dst, %d);", byte5)
		return
	}
	panic(fmt.Sprintf("protobuf tag %d exceeds uint32", tag))
}

func (g *Generator) generateMemoryFieldSerializerForType(field *protogen.Field, valueExpr string, currentPackage string) {
	switch field.Desc.Kind() {
	case protoreflect.BoolKind:
		g.w.Line("Pack.writeByte(dst, %s ? 1 : 0);", valueExpr)
	case protoreflect.Uint32Kind:
		g.w.Line("Pack.writeVarint32(dst, %s);", valueExpr)
	case protoreflect.EnumKind, protoreflect.Int32Kind:
		g.w.Line("Pack.writeInt32(dst, %s);", valueExpr)
	case protoreflect.Sint32Kind:
		g.w.Line("Pack.writeSint32(dst, %s);", valueExpr)
	case protoreflect.Int64Kind:
		g.w.Line("Pack.writeVarint64s(dst, %s, %s);", int64WordExpression(field, valueExpr, "low"), int64WordExpression(field, valueExpr, "high"))
	case protoreflect.Uint64Kind:
		g.w.Line("Pack.writeVarint64(dst, %s, %s);", int64WordExpression(field, valueExpr, "low"), int64WordExpression(field, valueExpr, "high"))
	case protoreflect.Sint64Kind:
		g.w.Line("Pack.writeSint64(dst, %s, %s);", int64WordExpression(field, valueExpr, "low"), int64WordExpression(field, valueExpr, "high"))
	case protoreflect.Sfixed32Kind:
		g.w.Line("Pack.writeSfixed32(dst, %s);", valueExpr)
	case protoreflect.Fixed32Kind:
		g.w.Line("Pack.writeFixed32(dst, %s);", valueExpr)
	case protoreflect.FloatKind:
		g.w.Line("Pack.writeFloat(dst, %s);", valueExpr)
	case protoreflect.Sfixed64Kind:
		g.w.Line("Pack.writeFixed32(dst, %s);", int64WordExpression(field, valueExpr, "low"))
		g.w.Line("Pack.writeSfixed32(dst, %s);", int64WordExpression(field, valueExpr, "high"))
	case protoreflect.Fixed64Kind:
		g.w.Line("Pack.writeFixed32(dst, %s);", int64WordExpression(field, valueExpr, "low"))
		g.w.Line("Pack.writeFixed32(dst, %s);", int64WordExpression(field, valueExpr, "high"))
	case protoreflect.DoubleKind:
		g.w.Line("Pack.writeDouble(dst, %s);", valueExpr)
	case protoreflect.StringKind:
		if isRealOneof(field) {
			g.generateMemoryNullableOneofLengthDelimited(valueExpr, func() {
				g.w.Line("Pack.writeString(dst, %s);", valueExpr)
			})
		} else {
			g.w.Line("Pack.writeString(dst, %s);", valueExpr)
		}
	case protoreflect.BytesKind:
		if isRealOneof(field) {
			g.generateMemoryNullableOneofLengthDelimited(valueExpr, func() {
				g.w.Line("Pack.writeBytes(dst, %s);", valueExpr)
			})
		} else {
			g.w.Line("Pack.writeBytes(dst, %s);", valueExpr)
		}
	case protoreflect.MessageKind:
		messageType := as3ElementType(field, currentPackage)
		g.w.Line("messageStart = Pack.startMessage(dst);")
		g.w.Line("%s.serializeMemory(%s, dst);", messageType, valueExpr)
		g.w.Line("Pack.endMessage(dst, messageStart);")
	}
}

func (g *Generator) generateMemoryNullableOneofLengthDelimited(valueExpr string, writeValue func()) {
	g.w.Line("if (%s != null)", valueExpr)
	g.w.Line("{")
	g.w.Indent()
	writeValue()
	g.w.Dedent()
	g.w.Line("}")
	g.w.Line("else")
	g.w.Line("{")
	g.w.Indent()
	g.w.Line("Pack.writeVarint32(dst, 0);")
	g.w.Dedent()
	g.w.Line("}")
}

func (g *Generator) generateMemoryFieldSerializerForRepeatedPackedType(field *protogen.Field, locName string) {
	g.generateMemoryWriteTag(field)

	switch field.Desc.Kind() {
	case protoreflect.Uint32Kind:
		g.w.Line("Pack.writeVarint32Vector(dst, %s, vecLength);", locName)
	case protoreflect.EnumKind, protoreflect.Int32Kind:
		g.w.Line("Pack.writeInt32Vector(dst, %s, vecLength);", locName)
	case protoreflect.Sint32Kind:
		g.w.Line("Pack.writeSint32Vector(dst, %s, vecLength);", locName)
	case protoreflect.Int64Kind:
		g.w.Line("Pack.writeVarint64sVector(dst, %s, vecLength);", locName)
	case protoreflect.Uint64Kind:
		g.w.Line("Pack.writeVarint64Vector(dst, %s, vecLength);", locName)
	case protoreflect.Sint64Kind:
		g.w.Line("Pack.writeSint64Vector(dst, %s, vecLength);", locName)
	case protoreflect.Fixed32Kind:
		g.w.Line("Pack.writeFixed32Vector(dst, %s, vecLength);", locName)
	case protoreflect.Sfixed32Kind:
		g.w.Line("Pack.writeSfixed32Vector(dst, %s, vecLength);", locName)
	case protoreflect.Fixed64Kind:
		g.w.Line("Pack.writeFixed64Vector(dst, %s, vecLength);", locName)
	case protoreflect.Sfixed64Kind:
		g.w.Line("Pack.writeSfixed64Vector(dst, %s, vecLength);", locName)
	case protoreflect.FloatKind:
		g.w.Line("Pack.writeFloatVector(dst, %s, vecLength);", locName)
	case protoreflect.DoubleKind:
		g.w.Line("Pack.writeDoubleVector(dst, %s, vecLength);", locName)
	case protoreflect.BoolKind:
		g.w.Line("Pack.writeBoolVector(dst, %s, vecLength);", locName)
	default:
		g.w.Line("// unsupported packed field %s", fmt.Sprint(field.Desc.FullName()))
	}
}

func (g *Generator) generateMemoryFieldSerializerForRepeatedUnpackedType(field *protogen.Field, locName string, currentPackage string) {
	g.w.Line("for (vecIndex = 0; vecIndex < vecLength; vecIndex++)")
	g.w.Line("{")
	g.w.Indent()
	g.generateMemoryWriteTag(field)
	switch field.Desc.Kind() {
	case protoreflect.Int64Kind:
		g.w.Line("Pack.writeVarint64s(dst, %s.low[vecIndex], %s.high[vecIndex]);", locName, locName)
	case protoreflect.Uint64Kind:
		g.w.Line("Pack.writeVarint64(dst, %s.low[vecIndex], %s.high[vecIndex]);", locName, locName)
	case protoreflect.Sint64Kind:
		g.w.Line("Pack.writeSint64(dst, %s.low[vecIndex], %s.high[vecIndex]);", locName, locName)
	case protoreflect.Sfixed64Kind:
		g.w.Line("Pack.writeFixed32(dst, %s.low[vecIndex]);", locName)
		g.w.Line("Pack.writeSfixed32(dst, %s.high[vecIndex]);", locName)
	case protoreflect.Fixed64Kind:
		g.w.Line("Pack.writeFixed32(dst, %s.low[vecIndex]);", locName)
		g.w.Line("Pack.writeFixed32(dst, %s.high[vecIndex]);", locName)
	default:
		// Int64Vector/UInt64Vector are structure-of-arrays and cannot be
		// indexed per element, hence the cases above; everything else is a
		// plain Vector whose elements serialize like singular values.
		g.generateMemoryFieldSerializerForType(field, locName+"[vecIndex]", currentPackage)
	}
	g.w.Dedent()
	g.w.Line("}")
}

func (g *Generator) generateMemoryMessageFieldSerializer(field *protogen.Field, fieldName string, currentPackage string) {
	if field.Desc.IsList() || field.Desc.IsMap() {
		if field.Desc.IsPacked() {
			g.generateMemoryFieldSerializerForRepeatedPackedType(field, fieldName)
			return
		}
		g.generateMemoryFieldSerializerForRepeatedUnpackedType(field, fieldName, currentPackage)
		return
	}

	g.generateMemoryWriteTag(field)
	g.generateMemoryFieldSerializerForType(field, optionalValueExpression(field, fieldName), currentPackage)
}
