package internal_test

import (
	"testing"

	"github.com/33TU/as3pb/internal"
	"google.golang.org/protobuf/compiler/protogen"
	"google.golang.org/protobuf/encoding/protowire"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/descriptorpb"
	"google.golang.org/protobuf/types/pluginpb"
)

func TestFieldTypeInfo(t *testing.T) {
	fields := fieldsByName(typeTestMessage(t))

	tests := []struct {
		field       string
		as3Type     string
		defaultExpr string
		wireType    protowire.Type
	}{
		{"name", "String", "\"\"", protowire.BytesType},
		{"active", "Boolean", "false", protowire.VarintType},
		{"count", "int", "0", protowire.VarintType},
		{"fixed_count", "uint", "0", protowire.Fixed32Type},
		{"ratio", "Number", "0.0", protowire.Fixed64Type},
		{"amount", "Int64", "new Int64()", protowire.VarintType},
		{"unsigned_amount", "UInt64", "new UInt64()", protowire.VarintType},
		{"raw", "ByteArray", "Buffers.newByteArray()", protowire.BytesType},
		{"scores", "Vector.<int>", "new Vector.<int>()", protowire.BytesType},
		{"unpacked_scores", "Vector.<int>", "new Vector.<int>()", protowire.VarintType},
		{"signed_values", "Int64Vector", "new Int64Vector()", protowire.BytesType},
		{"unsigned_values", "UInt64Vector", "new UInt64Vector()", protowire.BytesType},
		{"child", "test.v1.ExampleChild", "null", protowire.BytesType},
		{"children", "Vector.<test.v1.ExampleChild>", "new Vector.<test.v1.ExampleChild>()", protowire.BytesType},
		{"labels", "Vector.<test.v1.ExampleLabelsEntry>", "new Vector.<test.v1.ExampleLabelsEntry>()", protowire.BytesType},
		{"external", "other.v1.External", "null", protowire.BytesType},
	}

	for _, tt := range tests {
		t.Run(tt.field, func(t *testing.T) {
			field := fields[tt.field]
			if field == nil {
				t.Fatalf("missing test field %q", tt.field)
			}
			if got := internal.AS3Type(field, "test.v1"); got != tt.as3Type {
				t.Fatalf("AS3Type() = %q, want %q", got, tt.as3Type)
			}
			if got := internal.AS3DefaultValue(field, "test.v1"); got != tt.defaultExpr {
				t.Fatalf("AS3DefaultValue() = %q, want %q", got, tt.defaultExpr)
			}
			if got := internal.WireTypeForField(field); got != tt.wireType {
				t.Fatalf("WireTypeForField() = %v, want %v", got, tt.wireType)
			}
		})
	}
}

func fieldsByName(message *protogen.Message) map[string]*protogen.Field {
	fields := make(map[string]*protogen.Field, len(message.Fields))
	for _, field := range message.Fields {
		fields[string(field.Desc.Name())] = field
	}
	return fields
}

func typeTestMessage(t *testing.T) *protogen.Message {
	t.Helper()

	req := &pluginpb.CodeGeneratorRequest{
		FileToGenerate: []string{"test.proto"},
		ProtoFile: []*descriptorpb.FileDescriptorProto{
			{
				Name:    new("external.proto"),
				Syntax:  new("proto3"),
				Package: new("other.v1"),
				Options: &descriptorpb.FileOptions{
					GoPackage: new("github.com/33TU/as3pb/internal/typetest/other;other"),
				},
				MessageType: []*descriptorpb.DescriptorProto{{
					Name: new("External"),
				}},
			},
			{
				Name:       new("test.proto"),
				Syntax:     new("proto3"),
				Package:    new("test.v1"),
				Dependency: []string{"external.proto"},
				Options: &descriptorpb.FileOptions{
					GoPackage: new("github.com/33TU/as3pb/internal/typetest;typetest"),
				},
				MessageType: []*descriptorpb.DescriptorProto{{
					Name: new("Example"),
					Field: []*descriptorpb.FieldDescriptorProto{
						field("name", 1, descriptorpb.FieldDescriptorProto_TYPE_STRING),
						field("active", 2, descriptorpb.FieldDescriptorProto_TYPE_BOOL),
						field("count", 3, descriptorpb.FieldDescriptorProto_TYPE_INT32),
						field("fixed_count", 4, descriptorpb.FieldDescriptorProto_TYPE_FIXED32),
						field("ratio", 5, descriptorpb.FieldDescriptorProto_TYPE_DOUBLE),
						field("amount", 6, descriptorpb.FieldDescriptorProto_TYPE_INT64),
						field("unsigned_amount", 7, descriptorpb.FieldDescriptorProto_TYPE_UINT64),
						field("raw", 8, descriptorpb.FieldDescriptorProto_TYPE_BYTES),
						repeatedField("scores", 9, descriptorpb.FieldDescriptorProto_TYPE_INT32),
						unpackedRepeatedField("unpacked_scores", 10, descriptorpb.FieldDescriptorProto_TYPE_INT32),
						repeatedField("signed_values", 11, descriptorpb.FieldDescriptorProto_TYPE_INT64),
						repeatedField("unsigned_values", 12, descriptorpb.FieldDescriptorProto_TYPE_UINT64),
						messageField("child", 13, ".test.v1.Example.Child", false),
						messageField("children", 14, ".test.v1.Example.Child", true),
						messageField("labels", 15, ".test.v1.Example.LabelsEntry", true),
						messageField("external", 16, ".other.v1.External", false),
					},
					NestedType: []*descriptorpb.DescriptorProto{
						{Name: new("Child")},
						{
							Name: new("LabelsEntry"),
							Field: []*descriptorpb.FieldDescriptorProto{
								field("key", 1, descriptorpb.FieldDescriptorProto_TYPE_STRING),
								field("value", 2, descriptorpb.FieldDescriptorProto_TYPE_INT32),
							},
							Options: &descriptorpb.MessageOptions{
								MapEntry: proto.Bool(true),
							},
						},
					},
				}},
			},
		},
	}

	plugin, err := protogen.Options{}.New(req)
	if err != nil {
		t.Fatalf("protogen plugin: %v", err)
	}
	for _, file := range plugin.Files {
		if file.Desc.Path() == "test.proto" {
			return file.Messages[0]
		}
	}
	t.Fatal("test.proto not found")
	return nil
}

func field(name string, number int32, kind descriptorpb.FieldDescriptorProto_Type) *descriptorpb.FieldDescriptorProto {
	return &descriptorpb.FieldDescriptorProto{
		Name:   new(name),
		Number: new(number),
		Label:  descriptorpb.FieldDescriptorProto_LABEL_OPTIONAL.Enum(),
		Type:   kind.Enum(),
	}
}

func repeatedField(name string, number int32, kind descriptorpb.FieldDescriptorProto_Type) *descriptorpb.FieldDescriptorProto {
	return &descriptorpb.FieldDescriptorProto{
		Name:   new(name),
		Number: new(number),
		Label:  descriptorpb.FieldDescriptorProto_LABEL_REPEATED.Enum(),
		Type:   kind.Enum(),
	}
}

func unpackedRepeatedField(name string, number int32, kind descriptorpb.FieldDescriptorProto_Type) *descriptorpb.FieldDescriptorProto {
	field := repeatedField(name, number, kind)
	field.Options = &descriptorpb.FieldOptions{
		Packed: proto.Bool(false),
	}
	return field
}

func messageField(name string, number int32, typeName string, repeated bool) *descriptorpb.FieldDescriptorProto {
	label := descriptorpb.FieldDescriptorProto_LABEL_OPTIONAL
	if repeated {
		label = descriptorpb.FieldDescriptorProto_LABEL_REPEATED
	}
	return &descriptorpb.FieldDescriptorProto{
		Name:     new(name),
		Number:   new(number),
		Label:    label.Enum(),
		Type:     descriptorpb.FieldDescriptorProto_TYPE_MESSAGE.Enum(),
		TypeName: new(typeName),
	}
}
