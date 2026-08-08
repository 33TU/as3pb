package internal

import (
	"strconv"

	"google.golang.org/protobuf/compiler/protogen"
	"google.golang.org/protobuf/reflect/protoreflect"
)

// MessageNames stores collision-safe generated names for one message.
type MessageNames struct {
	used          map[string]struct{}
	fields        map[*protogen.Field]string
	fieldNumbers  map[*protogen.Field]string
	defaults      map[*protogen.Field]string
	defaultMakers map[*protogen.Field]string
	oneofCases    map[*protogen.Oneof]string
}

// NewMessageNames creates stable names for generated members in a message class.
func NewMessageNames(message *protogen.Message) *MessageNames {
	names := &MessageNames{
		used: map[string]struct{}{
			"clone":       {},
			"deserialize": {},
			"reset":       {},
			"serialize":   {},
		},
		fields:        make(map[*protogen.Field]string, len(message.Fields)),
		fieldNumbers:  make(map[*protogen.Field]string, len(message.Fields)),
		defaults:      make(map[*protogen.Field]string),
		defaultMakers: make(map[*protogen.Field]string),
		oneofCases:    make(map[*protogen.Oneof]string, len(message.Oneofs)),
	}

	for _, oneof := range message.Oneofs {
		if oneof.Desc.IsSynthetic() {
			continue
		}
		names.oneofCases[oneof] = uniqueName(OneofCaseName(oneof), names.used)
	}
	for _, field := range message.Fields {
		names.fieldNumbers[field] = uniqueName(FieldNumberName(field), names.used)
	}
	for _, field := range message.Fields {
		if !field.Desc.HasDefault() {
			continue
		}
		names.defaults[field] = uniqueName(FieldDefaultName(field), names.used)
		if field.Desc.Kind() == protoreflect.BytesKind {
			names.defaultMakers[field] = uniqueName("makeDefault"+FieldNamePascal(field), names.used)
		}
	}
	for _, field := range message.Fields {
		names.fields[field] = uniqueName(FieldName(field), names.used)
	}

	return names
}

// Field returns the AS3 instance field name for field.
func (n *MessageNames) Field(field *protogen.Field) string {
	if name, ok := n.fields[field]; ok {
		return name
	}
	name := uniqueName(FieldName(field), n.used)
	n.fields[field] = name
	return name
}

// FieldNumber returns the AS3 field-number constant name for field.
func (n *MessageNames) FieldNumber(field *protogen.Field) string {
	if name, ok := n.fieldNumbers[field]; ok {
		return name
	}
	name := uniqueName(FieldNumberName(field), n.used)
	n.fieldNumbers[field] = name
	return name
}

// Default returns the AS3 declared-default constant name for field.
func (n *MessageNames) Default(field *protogen.Field) string {
	return n.defaults[field]
}

// DefaultMaker returns the builder function name for a bytes field's
// declared-default constant.
func (n *MessageNames) DefaultMaker(field *protogen.Field) string {
	return n.defaultMakers[field]
}

// OneofCase returns the AS3 oneof case field name for oneof.
func (n *MessageNames) OneofCase(oneof *protogen.Oneof) string {
	if name, ok := n.oneofCases[oneof]; ok {
		return name
	}
	name := uniqueName(OneofCaseName(oneof), n.used)
	n.oneofCases[oneof] = name
	return name
}

func uniqueName(name string, used map[string]struct{}) string {
	name = escapeReserved(name)
	if _, ok := used[name]; !ok {
		used[name] = struct{}{}
		return name
	}

	candidate := name + "_"
	if _, ok := used[candidate]; !ok {
		used[candidate] = struct{}{}
		return candidate
	}

	for i := 2; ; i++ {
		candidate := name + "_" + strconv.Itoa(i)
		if _, ok := used[candidate]; !ok {
			used[candidate] = struct{}{}
			return candidate
		}
	}
}
