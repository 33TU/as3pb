package internal_test

import (
	"testing"

	"github.com/33TU/as3pb/internal"
	"google.golang.org/protobuf/compiler/protogen"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/descriptorpb"
	"google.golang.org/protobuf/types/pluginpb"
)

func TestIsAS3ReservedWord(t *testing.T) {
	if !internal.IsAS3ReservedWord("class") {
		t.Fatal("class should be reserved")
	}
	if internal.IsAS3ReservedWord("Class") {
		t.Fatal("Class should not be reserved")
	}
}

func TestMessageNames(t *testing.T) {
	message := testMessage(t)
	names := internal.NewMessageNames(message)

	oneof := message.Oneofs[0]
	resetField := message.Fields[0]
	actionCaseField := message.Fields[1]
	httpServerField := message.Fields[3]
	cloneField := message.Fields[4]

	if got, want := names.OneofCase(oneof), "actionCase"; got != want {
		t.Fatalf("OneofCase() = %q, want %q", got, want)
	}
	if got, want := names.Field(resetField), "reset_"; got != want {
		t.Fatalf("Field(reset) = %q, want %q", got, want)
	}
	if got, want := names.Field(actionCaseField), "actionCase_"; got != want {
		t.Fatalf("Field(action_case) = %q, want %q", got, want)
	}
	if got, want := names.FieldNumber(resetField), "FIELD_RESET"; got != want {
		t.Fatalf("FieldNumber(reset) = %q, want %q", got, want)
	}
	if got, want := names.Field(httpServerField), "httpServer"; got != want {
		t.Fatalf("Field(http_server) = %q, want %q", got, want)
	}
	if got, want := names.FieldNumber(httpServerField), "FIELD_HTTP_SERVER"; got != want {
		t.Fatalf("FieldNumber(http_server) = %q, want %q", got, want)
	}
	if got, want := names.Field(cloneField), "clone_"; got != want {
		t.Fatalf("Field(clone) = %q, want %q", got, want)
	}
	if got, want := names.Field(actionCaseField), "actionCase_"; got != want {
		t.Fatalf("Field(action_case) second call = %q, want %q", got, want)
	}
}

func testMessage(t *testing.T) *protogen.Message {
	t.Helper()

	req := &pluginpb.CodeGeneratorRequest{
		FileToGenerate: []string{"test.proto"},
		ProtoFile: []*descriptorpb.FileDescriptorProto{{
			Name:    new("test.proto"),
			Syntax:  new("proto3"),
			Package: new("test.v1"),
			Options: &descriptorpb.FileOptions{
				GoPackage: new("github.com/33TU/as3pb/internal/internaltest;internaltest"),
			},
			MessageType: []*descriptorpb.DescriptorProto{{
				Name: new("Example"),
				Field: []*descriptorpb.FieldDescriptorProto{
					{
						Name:   new("reset"),
						Number: proto.Int32(1),
						Label:  descriptorpb.FieldDescriptorProto_LABEL_OPTIONAL.Enum(),
						Type:   descriptorpb.FieldDescriptorProto_TYPE_INT32.Enum(),
					},
					{
						Name:   new("action_case"),
						Number: proto.Int32(2),
						Label:  descriptorpb.FieldDescriptorProto_LABEL_OPTIONAL.Enum(),
						Type:   descriptorpb.FieldDescriptorProto_TYPE_INT32.Enum(),
					},
					{
						Name:       new("move"),
						Number:     proto.Int32(3),
						Label:      descriptorpb.FieldDescriptorProto_LABEL_OPTIONAL.Enum(),
						Type:       descriptorpb.FieldDescriptorProto_TYPE_STRING.Enum(),
						OneofIndex: proto.Int32(0),
					},
					{
						Name:   new("http_server"),
						Number: proto.Int32(4),
						Label:  descriptorpb.FieldDescriptorProto_LABEL_OPTIONAL.Enum(),
						Type:   descriptorpb.FieldDescriptorProto_TYPE_STRING.Enum(),
					},
					{
						Name:   new("clone"),
						Number: proto.Int32(5),
						Label:  descriptorpb.FieldDescriptorProto_LABEL_OPTIONAL.Enum(),
						Type:   descriptorpb.FieldDescriptorProto_TYPE_STRING.Enum(),
					},
				},
				OneofDecl: []*descriptorpb.OneofDescriptorProto{{
					Name: new("action"),
				}},
			}},
		}},
	}

	plugin, err := protogen.Options{}.New(req)
	if err != nil {
		t.Fatalf("protogen plugin: %v", err)
	}
	if len(plugin.Files) != 1 || len(plugin.Files[0].Messages) != 1 {
		t.Fatalf("test descriptor produced unexpected file/message shape")
	}
	return plugin.Files[0].Messages[0]
}
