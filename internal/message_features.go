package internal

import (
	"slices"

	"google.golang.org/protobuf/compiler/protogen"
	"google.golang.org/protobuf/reflect/protoreflect"
)

func hasPackedFields(message *protogen.Message) bool {
	return slices.ContainsFunc(message.Fields, func(field *protogen.Field) bool {
		return field.Desc.IsPacked()
	})
}

func has64BitFields(message *protogen.Message) bool {
	return slices.ContainsFunc(message.Fields, func(field *protogen.Field) bool {
		return is64BitInteger(field.Desc.Kind())
	})
}

func hasRepeatedVarint64Fields(message *protogen.Message) bool {
	return slices.ContainsFunc(message.Fields, func(field *protogen.Field) bool {
		return field.Desc.IsList() && isVarint64(field.Desc.Kind())
	})
}

func hasListOrMapFields(message *protogen.Message) bool {
	return slices.ContainsFunc(message.Fields, func(field *protogen.Field) bool {
		return field.Desc.IsList() || field.Desc.IsMap()
	})
}

func hasRepeatedUnpackedFields(message *protogen.Message) bool {
	return slices.ContainsFunc(message.Fields, func(field *protogen.Field) bool {
		return (field.Desc.IsList() || field.Desc.IsMap()) && !field.Desc.IsPacked()
	})
}

func hasBytesFields(message *protogen.Message) bool {
	return slices.ContainsFunc(message.Fields, func(field *protogen.Field) bool {
		return field.Desc.Kind() == protoreflect.BytesKind
	})
}

func hasRepeatedBytesFields(message *protogen.Message) bool {
	return slices.ContainsFunc(message.Fields, func(field *protogen.Field) bool {
		return field.Desc.IsList() && field.Desc.Kind() == protoreflect.BytesKind
	})
}

func hasStringFields(message *protogen.Message) bool {
	return slices.ContainsFunc(message.Fields, func(field *protogen.Field) bool {
		return field.Desc.Kind() == protoreflect.StringKind
	})
}

func hasMessageFields(message *protogen.Message) bool {
	return slices.ContainsFunc(message.Fields, func(field *protogen.Field) bool {
		return field.Desc.Kind() == protoreflect.MessageKind
	})
}

func hasAnyFields(message *protogen.Message) bool {
	return slices.ContainsFunc(message.Fields, isAnyField)
}

func isAnyField(field *protogen.Field) bool {
	return field.Desc.Kind() == protoreflect.MessageKind &&
		field.Message.Desc.FullName() == "google.protobuf.Any"
}

func isPackableRepeatedField(field *protogen.Field) bool {
	if !field.Desc.IsList() || field.Desc.IsMap() {
		return false
	}

	switch field.Desc.Kind() {
	case protoreflect.BoolKind,
		protoreflect.EnumKind,
		protoreflect.Int32Kind,
		protoreflect.Sint32Kind,
		protoreflect.Uint32Kind,
		protoreflect.Int64Kind,
		protoreflect.Sint64Kind,
		protoreflect.Uint64Kind,
		protoreflect.Fixed32Kind,
		protoreflect.Sfixed32Kind,
		protoreflect.FloatKind,
		protoreflect.Fixed64Kind,
		protoreflect.Sfixed64Kind,
		protoreflect.DoubleKind:
		return true
	default:
		return false
	}
}

func is64BitInteger(kind protoreflect.Kind) bool {
	return isVarint64(kind) || isFixed64Integer(kind)
}

func isVarint64(kind protoreflect.Kind) bool {
	switch kind {
	case protoreflect.Int64Kind,
		protoreflect.Sint64Kind,
		protoreflect.Uint64Kind:
		return true
	default:
		return false
	}
}

func isFixed64Integer(kind protoreflect.Kind) bool {
	switch kind {
	case protoreflect.Fixed64Kind,
		protoreflect.Sfixed64Kind:
		return true
	default:
		return false
	}
}
