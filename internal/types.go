package internal

import (
	"slices"
	"strings"

	"google.golang.org/protobuf/compiler/protogen"
	"google.golang.org/protobuf/encoding/protowire"
	"google.golang.org/protobuf/reflect/protoreflect"
)

// WireTypeForField returns the protobuf wire type used when writing a field tag.
func WireTypeForField(field *protogen.Field) protowire.Type {
	if field.Desc.IsMap() || field.Desc.IsPacked() {
		return protowire.BytesType
	}
	return wireTypeForKind(field.Desc.Kind())
}

func wireTypeForKind(kind protoreflect.Kind) protowire.Type {
	switch kind {
	case protoreflect.BoolKind,
		protoreflect.EnumKind,
		protoreflect.Int32Kind,
		protoreflect.Sint32Kind,
		protoreflect.Uint32Kind,
		protoreflect.Int64Kind,
		protoreflect.Sint64Kind,
		protoreflect.Uint64Kind:
		return protowire.VarintType
	case protoreflect.Fixed64Kind,
		protoreflect.Sfixed64Kind,
		protoreflect.DoubleKind:
		return protowire.Fixed64Type
	case protoreflect.Fixed32Kind,
		protoreflect.Sfixed32Kind,
		protoreflect.FloatKind:
		return protowire.Fixed32Type
	case protoreflect.StringKind,
		protoreflect.BytesKind,
		protoreflect.MessageKind:
		return protowire.BytesType
	default:
		return protowire.BytesType
	}
}

// AS3DefaultValue returns the default ActionScript expression for field.
func AS3DefaultValue(field *protogen.Field, currentProtoPackage string) string {
	if field.Desc.IsList() || field.Desc.IsMap() {
		switch field.Desc.Kind() {
		case protoreflect.Int64Kind, protoreflect.Sint64Kind, protoreflect.Sfixed64Kind:
			return "new Int64Vector()"
		case protoreflect.Uint64Kind, protoreflect.Fixed64Kind:
			return "new UInt64Vector()"
		default:
			return "new Vector.<" + as3ElementType(field, currentProtoPackage) + ">()"
		}
	}

	switch field.Desc.Kind() {
	case protoreflect.StringKind:
		return `""`
	case protoreflect.Int32Kind,
		protoreflect.Sint32Kind,
		protoreflect.Sfixed32Kind,
		protoreflect.Uint32Kind,
		protoreflect.Fixed32Kind,
		protoreflect.EnumKind:
		return "0"
	case protoreflect.Int64Kind,
		protoreflect.Sint64Kind,
		protoreflect.Sfixed64Kind:
		return "new Int64()"
	case protoreflect.Uint64Kind,
		protoreflect.Fixed64Kind:
		return "new UInt64()"
	case protoreflect.FloatKind,
		protoreflect.DoubleKind:
		return "0.0"
	case protoreflect.BoolKind:
		return "false"
	case protoreflect.BytesKind:
		return "Buffers.newByteArray()"
	default:
		return "null"
	}
}

// AS3Type returns the ActionScript type for a protobuf field.
func AS3Type(field *protogen.Field, currentProtoPackage string) string {
	if field.Desc.IsMap() {
		return "Vector.<" + as3MessageTypeName(field.Message, currentProtoPackage) + ">"
	}
	if field.Desc.IsList() {
		switch field.Desc.Kind() {
		case protoreflect.Int64Kind, protoreflect.Sint64Kind, protoreflect.Sfixed64Kind:
			return "Int64Vector"
		case protoreflect.Uint64Kind, protoreflect.Fixed64Kind:
			return "UInt64Vector"
		default:
			return "Vector.<" + as3ElementType(field, currentProtoPackage) + ">"
		}
	}
	return as3ElementType(field, currentProtoPackage)
}

func as3ElementType(field *protogen.Field, currentProtoPackage string) string {
	switch field.Desc.Kind() {
	case protoreflect.StringKind:
		return "String"
	case protoreflect.Int32Kind,
		protoreflect.Sint32Kind,
		protoreflect.Sfixed32Kind:
		return "int"
	case protoreflect.Uint32Kind,
		protoreflect.Fixed32Kind:
		return "uint"
	case protoreflect.Int64Kind,
		protoreflect.Sint64Kind,
		protoreflect.Sfixed64Kind:
		return "Int64"
	case protoreflect.Uint64Kind,
		protoreflect.Fixed64Kind:
		return "UInt64"
	case protoreflect.FloatKind,
		protoreflect.DoubleKind:
		return "Number"
	case protoreflect.BoolKind:
		return "Boolean"
	case protoreflect.BytesKind:
		return "ByteArray"
	case protoreflect.EnumKind:
		return "int"
	case protoreflect.MessageKind:
		if isAnyField(field) {
			return "Any"
		}
		return as3MessageTypeName(field.Message, currentProtoPackage)
	default:
		return "Object"
	}
}

func as3MessageTypeName(message *protogen.Message, currentProtoPackage string) string {
	names := []string{}
	for desc := message.Desc; ; {
		names = append(names, string(desc.Name()))
		parent, ok := desc.Parent().(protoreflect.MessageDescriptor)
		if !ok {
			break
		}
		desc = parent
	}
	slices.Reverse(names)

	name := toPascalCase(strings.Join(names, ""))
	pkg := string(message.Desc.ParentFile().Package())
	if pkg == "" || pkg == currentProtoPackage {
		return name
	}
	return pkg + "." + name
}
