package internal

import (
	"google.golang.org/protobuf/compiler/protogen"
)

var as3ReservedWords = map[string]struct{}{
	"AS3":          {},
	"as":           {},
	"break":        {},
	"case":         {},
	"catch":        {},
	"class":        {},
	"const":        {},
	"continue":     {},
	"default":      {},
	"delete":       {},
	"do":           {},
	"dynamic":      {},
	"else":         {},
	"extends":      {},
	"false":        {},
	"final":        {},
	"finally":      {},
	"flash_proxy":  {},
	"for":          {},
	"function":     {},
	"get":          {},
	"if":           {},
	"implements":   {},
	"import":       {},
	"in":           {},
	"include":      {},
	"instanceof":   {},
	"interface":    {},
	"internal":     {},
	"is":           {},
	"label":        {},
	"namespace":    {},
	"native":       {},
	"new":          {},
	"null":         {},
	"object_proxy": {},
	"override":     {},
	"package":      {},
	"private":      {},
	"protected":    {},
	"public":       {},
	"return":       {},
	"set":          {},
	"static":       {},
	"super":        {},
	"switch":       {},
	"this":         {},
	"throw":        {},
	"true":         {},
	"try":          {},
	"typeof":       {},
	"use":          {},
	"var":          {},
	"void":         {},
	"while":        {},
	"with":         {},
}

// IsAS3ReservedWord reports whether word is reserved in ActionScript 3.
func IsAS3ReservedWord(word string) bool {
	_, ok := as3ReservedWords[word]
	return ok
}

// FieldName returns the AS3 field identifier for a protobuf field.
func FieldName(field *protogen.Field) string {
	return toCamelCase(string(field.Desc.Name()))
}

// FieldNamePascal returns the AS3 PascalCase identifier for a protobuf field.
func FieldNamePascal(field *protogen.Field) string {
	return toPascalCase(string(field.Desc.Name()))
}

// MessageClassName returns the AS3 class name for a protobuf message.
func MessageClassName(message *protogen.Message) string {
	return toPascalCase(message.GoIdent.GoName)
}

// QualifiedMessageClassName returns the package-qualified AS3 class name,
// used for every reference to the class (its declaration stays bare): a
// bare name is ambiguous whenever it collides with a global like Date,
// even inside the class's own file.
func QualifiedMessageClassName(message *protogen.Message) string {
	name := MessageClassName(message)
	if pkg := string(message.Desc.ParentFile().Package()); pkg != "" {
		return pkg + "." + name
	}
	return name
}

// FieldNumberName returns the AS3 field-number constant name for a protobuf field.
func FieldNumberName(field *protogen.Field) string {
	return "FIELD_" + toSnakeCase(string(field.Desc.Name()), true)
}

// FieldDefaultName returns the AS3 declared-default constant name for a field.
func FieldDefaultName(field *protogen.Field) string {
	return "DEFAULT_" + toSnakeCase(string(field.Desc.Name()), true)
}

// OneofCaseName returns the AS3 oneof case field name for a protobuf oneof.
func OneofCaseName(oneof *protogen.Oneof) string {
	return toCamelCase(string(oneof.Desc.Name())) + "Case"
}

// EnumName returns the AS3 enum value constant name for a protobuf enum value.
func EnumName(enum *protogen.EnumValue) string {
	return toSnakeCase(string(enum.Desc.Name()), true)
}

// EnumClassName returns the AS3 class name for a protobuf enum.
func EnumClassName(enum *protogen.Enum) string {
	return toPascalCase(enum.GoIdent.GoName)
}

// ServiceClassName returns the AS3 RPC client class name for a protobuf service.
func ServiceClassName(service *protogen.Service) string {
	return toPascalCase(service.GoName) + "RpcClient"
}

// RPCMethodName returns the AS3 method name for a protobuf RPC method.
func RPCMethodName(method *protogen.Method) string {
	return toCamelCase(string(method.Desc.Name()))
}
