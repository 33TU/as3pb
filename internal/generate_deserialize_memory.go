package internal

import (
	"fmt"

	"google.golang.org/protobuf/compiler/protogen"
	"google.golang.org/protobuf/encoding/protowire"
	"google.golang.org/protobuf/reflect/protoreflect"
)

func (g *Generator) generateDeserializeMemoryMethod(message *protogen.Message, names *MessageNames) {
	currentPackage := string(message.Desc.ParentFile().Package())
	messageName := QualifiedMessageClassName(message)

	g.generateLeadingComment(protogen.Comments(
		"Deserializes the message from protobuf wire format.\n"+
			"@param src The active UnpackContext; bind with Unpack.begin first.\n"+
			"@param dst Reusable destination message, or null to allocate.\n"+
			"@param length Number of bytes to decode from the current position; zero means an empty message.\n"+
			"@param reset Whether to reset a reusable destination before decoding.",
	), false)
	g.w.Line(
		"public static function deserializeMemory(src:UnpackContext, dst:%s, length:uint, reset:Boolean = true):%s",
		messageName,
		messageName,
	)
	g.w.Line("{")
	g.w.Indent()

	g.w.Line("if (!dst)")
	g.w.Indent()
	g.w.Line("dst = new %s();", messageName)
	g.w.Dedent()
	g.w.Line("else if (reset)")
	g.w.Indent()
	g.w.Line("%s.reset(dst);", messageName)
	g.w.Dedent()
	g.w.BlankLine()

	g.w.Line("if (!length)")
	g.w.Indent()
	g.w.Line("return dst;")
	g.w.Dedent()
	g.w.Line("else if (src.position > src.limit || length > src.limit - src.position)")
	g.w.Indent()
	g.w.Line(`throw new Error("Invalid protobuf message length");`)
	g.w.Dedent()
	g.w.BlankLine()

	g.w.Line("const end:uint = src.position + length;")
	g.w.Line("const previousLimit:uint = src.limit;")
	g.w.Line("src.limit = end;")
	g.w.Line("try")
	g.w.Line("{")
	g.w.Indent()
	g.w.BlankLine()
	g.w.Line("while (src.position < end)")
	g.w.Line("{")
	g.w.Indent()
	g.w.Line("const tag:uint = Unpack.readTag(src);")
	g.w.Line("switch (tag)")
	g.w.Line("{")
	g.w.Indent()

	for _, field := range message.Fields {
		if isPackableRepeatedField(field) {
			g.generateMemoryFieldDeserializeCase(field, names, currentPackage, wireTypeForKind(field.Desc.Kind()), false)
			g.generateMemoryFieldDeserializeCase(field, names, currentPackage, protowire.BytesType, true)
			continue
		}

		g.generateMemoryFieldDeserializeCase(
			field,
			names,
			currentPackage,
			WireTypeForField(field),
			field.Desc.IsPacked(),
		)
	}

	g.w.Line("default:")
	g.w.Line("{")
	g.w.Indent()
	g.w.Line("if ((tag >>> 3) == 0)")
	g.w.Indent()
	g.w.Line(`throw new Error("Invalid protobuf field number");`)
	g.w.Dedent()
	g.w.BlankLine()
	g.w.Line("if (dst.unknownFields == null)")
	g.w.Indent()
	g.w.Line("dst.unknownFields = Buffers.newByteArray();")
	g.w.Dedent()
	g.w.BlankLine()
	g.w.Line("Unpack.captureUnknownField(src, tag, dst.unknownFields);")
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

	g.w.Dedent()
	g.w.Line("}")
	g.w.Line("finally")
	g.w.Line("{")
	g.w.Indent()
	g.w.Line("src.limit = previousLimit;")
	g.w.Dedent()
	g.w.Line("}")
	g.w.Line("return dst;")
	g.w.Dedent()
	g.w.Line("}")
}

func (g *Generator) generateMemoryFieldDeserializeCase(
	field *protogen.Field,
	names *MessageNames,
	currentPackage string,
	wireType protowire.Type,
	packed bool,
) {
	tag := (int(field.Desc.Number()) << 3) | int(wireType)
	fieldName := "dst." + names.Field(field)

	g.w.Line("case %d:", tag)
	g.w.Line("{")
	g.w.Indent()

	messageReset := "false"
	if isRealOneof(field) && field.Desc.Kind() == protoreflect.MessageKind {
		messageReset = fmt.Sprintf(
			"dst.%s != %s",
			names.OneofCase(field.Oneof),
			names.FieldNumber(field),
		)
	}

	if field.Desc.IsList() || field.Desc.IsMap() {
		if packed {
			g.generateMemoryFieldDeserializerForRepeatedPackedType(field, fieldName)
		} else {
			g.generateMemoryFieldDeserializerForRepeatedUnpackedType(field, fieldName, currentPackage)
		}
	} else {
		valueName := fieldName
		if hasExplicitPresence(field) {
			switch field.Desc.Kind() {
			case protoreflect.StringKind, protoreflect.MessageKind:
			case protoreflect.BytesKind:
				g.w.Line("if (%s == null)", fieldName)
				g.w.Indent()
				g.w.Line("%s = Buffers.newByteArray();", fieldName)
				g.w.Dedent()
			case protoreflect.Int64Kind, protoreflect.Sint64Kind, protoreflect.Uint64Kind,
				protoreflect.Sfixed64Kind, protoreflect.Fixed64Kind:
				g.w.Line("if (%s == null)", fieldName)
				g.w.Indent()
				g.w.Line("%s = new %s();", fieldName, AS3Type(field, currentPackage))
				g.w.Dedent()
			default:
				g.w.Line("if (%s == null)", fieldName)
				g.w.Indent()
				g.w.Line("%s = new %s();", fieldName, AS3Type(field, currentPackage))
				g.w.Dedent()
				valueName += ".value"
			}
		}
		g.generateMemoryFieldDeserializerForType(field, valueName, currentPackage, messageReset)
	}

	if isRealOneof(field) {
		g.w.Line("dst.%s = %s;", names.OneofCase(field.Oneof), names.FieldNumber(field))
	}

	g.w.Line("break;")
	g.w.Dedent()
	g.w.Line("}")
}

func (g *Generator) generateMemoryFieldDeserializerForType(
	field *protogen.Field,
	fieldName string,
	currentPackage string,
	messageReset string,
) {
	switch field.Desc.Kind() {
	case protoreflect.BoolKind:
		g.w.Line("%s = Unpack.readBool(src);", fieldName)
	case protoreflect.Uint32Kind:
		g.w.Line("%s = Unpack.readVarint32(src);", fieldName)
	case protoreflect.EnumKind, protoreflect.Int32Kind:
		g.w.Line("%s = Unpack.readInt32(src);", fieldName)
	case protoreflect.Sint32Kind:
		g.w.Line("%s = Unpack.readSint32(src);", fieldName)
	case protoreflect.Sfixed32Kind:
		g.w.Line("%s = Unpack.readSfixed32(src);", fieldName)
	case protoreflect.Fixed32Kind:
		g.w.Line("%s = Unpack.readFixed32(src);", fieldName)
	case protoreflect.Int64Kind:
		g.w.Line("Unpack.readVarint64s(src, %s);", fieldName)
	case protoreflect.Sint64Kind:
		g.w.Line("Unpack.readSint64(src, %s);", fieldName)
	case protoreflect.Uint64Kind:
		g.w.Line("Unpack.readVarint64(src, %s);", fieldName)
	case protoreflect.Sfixed64Kind:
		g.w.Line("Unpack.readSfixed64(src, %s);", fieldName)
	case protoreflect.Fixed64Kind:
		g.w.Line("Unpack.readFixed64(src, %s);", fieldName)
	case protoreflect.FloatKind:
		g.w.Line("%s = Unpack.readFloat(src);", fieldName)
	case protoreflect.DoubleKind:
		g.w.Line("%s = Unpack.readDouble(src);", fieldName)
	case protoreflect.StringKind:
		g.w.Line("%s = Unpack.readString(src);", fieldName)
	case protoreflect.BytesKind:
		g.w.Line("Unpack.readBytesInto(src, %s);", fieldName)
	case protoreflect.MessageKind:
		messageType := as3ElementType(field, currentPackage)
		g.w.Line("%s = %s.deserializeMemory(src, %s, Unpack.readVarint32(src), %s);", fieldName, messageType, fieldName, messageReset)
	}
}

func (g *Generator) generateMemoryFieldDeserializerForRepeatedUnpackedType(field *protogen.Field, fieldName string, currentPackage string) {
	switch field.Desc.Kind() {
	case protoreflect.BoolKind:
		g.w.Line("%s.push(Unpack.readBool(src));", fieldName)
	case protoreflect.Uint32Kind:
		g.w.Line("%s.push(Unpack.readVarint32(src));", fieldName)
	case protoreflect.EnumKind, protoreflect.Int32Kind:
		g.w.Line("%s.push(Unpack.readInt32(src));", fieldName)
	case protoreflect.Sint32Kind:
		g.w.Line("%s.push(Unpack.readSint32(src));", fieldName)
	case protoreflect.Sfixed32Kind:
		g.w.Line("%s.push(Unpack.readSfixed32(src));", fieldName)
	case protoreflect.Fixed32Kind:
		g.w.Line("%s.push(Unpack.readFixed32(src));", fieldName)
	case protoreflect.Uint64Kind:
		g.w.Line("Unpack.readVarint64(src, TMP_UINT64);")
		g.w.Line("%s.push(TMP_UINT64.low, TMP_UINT64.high);", fieldName)
	case protoreflect.Int64Kind:
		g.w.Line("Unpack.readVarint64s(src, TMP_INT64);")
		g.w.Line("%s.push(TMP_INT64.low, TMP_INT64.high);", fieldName)
	case protoreflect.Sint64Kind:
		g.w.Line("Unpack.readSint64(src, TMP_INT64);")
		g.w.Line("%s.push(TMP_INT64.low, TMP_INT64.high);", fieldName)
	case protoreflect.Sfixed64Kind:
		g.w.Line("%s.push(Unpack.readFixed32(src), Unpack.readSfixed32(src));", fieldName)
	case protoreflect.Fixed64Kind:
		g.w.Line("%s.push(Unpack.readFixed32(src), Unpack.readFixed32(src));", fieldName)
	case protoreflect.FloatKind:
		g.w.Line("%s.push(Unpack.readFloat(src));", fieldName)
	case protoreflect.DoubleKind:
		g.w.Line("%s.push(Unpack.readDouble(src));", fieldName)
	case protoreflect.StringKind:
		g.w.Line("%s.push(Unpack.readString(src));", fieldName)
	case protoreflect.BytesKind:
		g.w.Line("var tmp:ByteArray = Buffers.newByteArray();")
		g.w.Line("Unpack.readBytesInto(src, tmp);")
		g.w.Line("%s.push(tmp);", fieldName)
	case protoreflect.MessageKind:
		messageType := as3ElementType(field, currentPackage)
		g.w.Line("%s.push(%s.deserializeMemory(src, null, Unpack.readVarint32(src)));", fieldName, messageType)
	}
}

func (g *Generator) generateMemoryFieldDeserializerForRepeatedPackedType(field *protogen.Field, fieldName string) {
	switch field.Desc.Kind() {
	case protoreflect.Uint32Kind:
		g.w.Line("Unpack.readVarint32Vector(src, %s);", fieldName)
	case protoreflect.EnumKind, protoreflect.Int32Kind:
		g.w.Line("Unpack.readInt32Vector(src, %s);", fieldName)
	case protoreflect.Sint32Kind:
		g.w.Line("Unpack.readSint32Vector(src, %s);", fieldName)
	case protoreflect.Int64Kind:
		g.w.Line("Unpack.readVarint64sVector(src, %s);", fieldName)
	case protoreflect.Uint64Kind:
		g.w.Line("Unpack.readVarint64Vector(src, %s);", fieldName)
	case protoreflect.Sint64Kind:
		g.w.Line("Unpack.readSint64Vector(src, %s);", fieldName)
	case protoreflect.Fixed32Kind:
		g.w.Line("Unpack.readFixed32Vector(src, %s);", fieldName)
	case protoreflect.Sfixed32Kind:
		g.w.Line("Unpack.readFixed32sVector(src, %s);", fieldName)
	case protoreflect.Fixed64Kind:
		g.w.Line("Unpack.readFixed64Vector(src, %s);", fieldName)
	case protoreflect.Sfixed64Kind:
		g.w.Line("Unpack.readFixed64sVector(src, %s);", fieldName)
	case protoreflect.FloatKind:
		g.w.Line("Unpack.readFloatVector(src, %s);", fieldName)
	case protoreflect.DoubleKind:
		g.w.Line("Unpack.readDoubleVector(src, %s);", fieldName)
	case protoreflect.BoolKind:
		g.w.Line("Unpack.readBoolVector(src, %s);", fieldName)
	default:
		g.w.Line("// unsupported packed field %s", fmt.Sprint(field.Desc.FullName()))
	}
}
