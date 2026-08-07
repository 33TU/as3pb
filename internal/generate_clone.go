package internal

import (
	"fmt"

	"google.golang.org/protobuf/compiler/protogen"
	"google.golang.org/protobuf/reflect/protoreflect"
)

func (g *Generator) generateCloneMethod(message *protogen.Message, names *MessageNames) {
	messageName := MessageClassName(message)
	currentPackage := string(message.Desc.ParentFile().Package())

	g.generateLeadingComment(protogen.Comments(
		"Creates a deep copy of a message.\n"+
			"@param src Message to clone.\n"+
			"@return A new deep copy, or null when src is null.",
	), false)
	g.w.Line("public static function clone(src:%s):%s", messageName, messageName)
	g.w.Line("{")
	g.w.Indent()
	g.w.Line("if (!src)")
	g.w.Indent()
	g.w.Line("return null;")
	g.w.Dedent()
	g.w.BlankLine()
	g.w.Line("const dst:%s = new %s();", messageName, messageName)

	for i, field := range message.Fields {
		if isRealOneof(field) {
			continue
		}
		g.generateCloneField(field, names, currentPackage, i)
	}

	for _, oneof := range message.Oneofs {
		if oneof.Desc.IsSynthetic() {
			continue
		}
		caseName := names.OneofCase(oneof)
		g.w.BlankLine()
		g.w.Line("dst.%s = src.%s;", caseName, caseName)
		g.w.Line("switch (src.%s)", caseName)
		g.w.Line("{")
		g.w.Indent()
		for _, field := range oneof.Fields {
			g.w.Line("case %s:", names.FieldNumber(field))
			g.w.Line("{")
			g.w.Indent()
			g.generateCloneSingularField(field, names, currentPackage)
			g.w.Line("break;")
			g.w.Dedent()
			g.w.Line("}")
		}
		g.w.Dedent()
		g.w.Line("}")
	}

	g.w.BlankLine()
	g.w.Line("dst.unknownFields = Buffers.cloneByteArray(src.unknownFields);")

	g.w.BlankLine()
	g.w.Line("return dst;")
	g.w.Dedent()
	g.w.Line("}")
}

func (g *Generator) generateCloneField(field *protogen.Field, names *MessageNames, currentPackage string, index int) {
	if !field.Desc.IsList() && !field.Desc.IsMap() {
		g.generateCloneSingularField(field, names, currentPackage)
		return
	}

	fieldName := names.Field(field)
	if is64BitInteger(field.Desc.Kind()) {
		g.w.Line("dst.%s.copyFrom(src.%s);", fieldName, fieldName)
		return
	}
	if field.Desc.Kind() != protoreflect.BytesKind && field.Desc.Kind() != protoreflect.MessageKind {
		g.w.Line("dst.%s = src.%s.concat();", fieldName, fieldName)
		return
	}

	sourceName := fmt.Sprintf("cloneSource%d", index)
	targetName := fmt.Sprintf("cloneTarget%d", index)
	indexName := fmt.Sprintf("cloneIndex%d", index)
	fieldType := AS3Type(field, currentPackage)
	g.w.Line("const %s:%s = src.%s;", sourceName, fieldType, fieldName)
	g.w.Line("const %s:%s = dst.%s;", targetName, fieldType, fieldName)
	g.w.Line("%s.length = %s.length;", targetName, sourceName)
	g.w.Line("for (var %s:uint = 0; %s < %s.length; %s++)", indexName, indexName, sourceName, indexName)
	g.w.Indent()
	switch field.Desc.Kind() {
	case protoreflect.BytesKind:
		g.w.Line("%s[%s] = Buffers.cloneByteArray(%s[%s]);", targetName, indexName, sourceName, indexName)
	case protoreflect.MessageKind:
		g.w.Line("%s[%s] = %s.clone(%s[%s]);", targetName, indexName, as3ElementType(field, currentPackage), sourceName, indexName)
	default:
		g.w.Line("%s[%s] = %s[%s];", targetName, indexName, sourceName, indexName)
	}
	g.w.Dedent()
}

func (g *Generator) generateCloneSingularField(field *protogen.Field, names *MessageNames, currentPackage string) {
	fieldName := names.Field(field)
	src := "src." + fieldName
	dst := "dst." + fieldName

	switch field.Desc.Kind() {
	case protoreflect.MessageKind:
		g.w.Line("%s = %s.clone(%s);", dst, as3ElementType(field, currentPackage), src)
	case protoreflect.BytesKind:
		if isRealOneof(field) {
			g.w.Line("if (%s)", src)
			g.w.Indent()
			g.w.Line("%s = Buffers.cloneByteArray(%s);", dst, src)
			g.w.Dedent()
		} else {
			g.w.Line("%s = Buffers.cloneByteArray(%s);", dst, src)
		}
	case protoreflect.Int64Kind, protoreflect.Sint64Kind, protoreflect.Sfixed64Kind,
		protoreflect.Uint64Kind, protoreflect.Fixed64Kind:
		if field.Desc.HasOptionalKeyword() {
			g.w.Line("%s = %s ? %s.clone() : null;", dst, src, src)
		} else if isRealOneof(field) {
			g.w.Line("if (%s)", src)
			g.w.Indent()
			g.w.Line("%s.copyFrom(%s);", dst, src)
			g.w.Dedent()
		} else {
			g.w.Line("%s.copyFrom(%s);", dst, src)
		}
	default:
		if field.Desc.HasOptionalKeyword() && field.Desc.Kind() != protoreflect.StringKind {
			g.w.Line("%s = %s ? %s.clone() : null;", dst, src, src)
		} else {
			g.w.Line("%s = %s;", dst, src)
		}
	}
}
