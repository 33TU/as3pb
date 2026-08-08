package internal

import (
	"maps"
	"slices"

	"google.golang.org/protobuf/compiler/protogen"
	"google.golang.org/protobuf/reflect/protoreflect"
)

func hasPackedFields(message *protogen.Message) bool {
	return slices.ContainsFunc(message.Fields, func(field *protogen.Field) bool {
		return field.Desc.IsPacked()
	})
}

func hasSingularSigned64Fields(message *protogen.Message) bool {
	return slices.ContainsFunc(message.Fields, func(field *protogen.Field) bool {
		return !field.Desc.IsList() && isSigned64(field.Desc.Kind())
	})
}

func hasSingularUnsigned64Fields(message *protogen.Message) bool {
	return slices.ContainsFunc(message.Fields, func(field *protogen.Field) bool {
		return !field.Desc.IsList() && isUnsigned64(field.Desc.Kind())
	})
}

func hasOptionalKind(message *protogen.Message, kinds ...protoreflect.Kind) bool {
	return slices.ContainsFunc(message.Fields, func(field *protogen.Field) bool {
		return hasExplicitPresence(field) && slices.Contains(kinds, field.Desc.Kind())
	})
}

func isRealOneof(field *protogen.Field) bool {
	return field.Oneof != nil && !field.Oneof.Desc.IsSynthetic()
}

// hasExplicitPresence reports whether a singular non-message field tracks
// presence explicitly and therefore needs a nullable AS3 representation:
// proto3 `optional`, or editions `features.field_presence = EXPLICIT`.
// Message fields and real-oneof members track presence through other means.
func hasExplicitPresence(field *protogen.Field) bool {
	if field.Desc.IsList() || field.Desc.IsMap() || isRealOneof(field) {
		return false
	}
	if field.Desc.Kind() == protoreflect.MessageKind || field.Desc.Kind() == protoreflect.GroupKind {
		return false
	}
	return field.Desc.HasPresence()
}

func hasRepeatedSigned64Fields(message *protogen.Message) bool {
	return slices.ContainsFunc(message.Fields, func(field *protogen.Field) bool {
		return field.Desc.IsList() && isSigned64(field.Desc.Kind())
	})
}

func hasRepeatedUnsigned64Fields(message *protogen.Message) bool {
	return slices.ContainsFunc(message.Fields, func(field *protogen.Field) bool {
		return field.Desc.IsList() && isUnsigned64(field.Desc.Kind())
	})
}

func hasRepeatedSignedVarint64Fields(message *protogen.Message) bool {
	return slices.ContainsFunc(message.Fields, func(field *protogen.Field) bool {
		return field.Desc.IsList() && isSignedVarint64(field.Desc.Kind())
	})
}

func hasRepeatedUnsignedVarint64Fields(message *protogen.Message) bool {
	return slices.ContainsFunc(message.Fields, func(field *protogen.Field) bool {
		return field.Desc.IsList() && field.Desc.Kind() == protoreflect.Uint64Kind
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

// messageForeignImports lists the message classes a message's fields
// reference from other proto packages, as sorted import targets. The
// generated code writes such types fully qualified, and AS3 resolves a
// fully-qualified reference only when the class is imported.
func messageForeignImports(message *protogen.Message) []string {
	currentPackage := string(message.Desc.ParentFile().Package())
	seen := make(map[string]struct{})
	for _, field := range message.Fields {
		if field.Message != nil {
			collectForeignImport(seen, field.Message, currentPackage)
		}
	}
	return slices.Sorted(maps.Keys(seen))
}

// serviceForeignImports is messageForeignImports for a service's method
// request and response types.
func serviceForeignImports(service *protogen.Service) []string {
	currentPackage := string(service.Desc.ParentFile().Package())
	seen := make(map[string]struct{})
	for _, method := range service.Methods {
		collectForeignImport(seen, method.Input, currentPackage)
		collectForeignImport(seen, method.Output, currentPackage)
	}
	return slices.Sorted(maps.Keys(seen))
}

func collectForeignImport(seen map[string]struct{}, message *protogen.Message, currentPackage string) {
	pkg := string(message.Desc.ParentFile().Package())
	if pkg == "" || pkg == currentPackage {
		return
	}
	seen[as3MessageTypeName(message, currentPackage)] = struct{}{}
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

func isSigned64(kind protoreflect.Kind) bool {
	return isSignedVarint64(kind) || kind == protoreflect.Sfixed64Kind
}

func isUnsigned64(kind protoreflect.Kind) bool {
	return kind == protoreflect.Uint64Kind || kind == protoreflect.Fixed64Kind
}

func isSignedVarint64(kind protoreflect.Kind) bool {
	return kind == protoreflect.Int64Kind || kind == protoreflect.Sint64Kind
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
