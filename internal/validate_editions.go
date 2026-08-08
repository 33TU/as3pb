package internal

import (
	"fmt"

	"google.golang.org/protobuf/compiler/protogen"
	"google.golang.org/protobuf/reflect/protoreflect"
)

// validateEditionsFeatures rejects editions files whose resolved features
// fall outside the proto3 feature set the generator supports. Editions
// files that stick to proto3 semantics (implicit or explicit presence,
// open enums, length-prefixed messages) generate identically to proto3;
// declared defaults are additionally allowed and surface as DEFAULT_*
// constants since they never affect the wire.
// optionsExtendees are the descriptor option types that custom options
// extend. Such extend blocks are the one extension use proto3 allows;
// they are pure compile-time metadata and generate no code.
var optionsExtendees = map[protoreflect.FullName]struct{}{
	"google.protobuf.FileOptions":           {},
	"google.protobuf.MessageOptions":        {},
	"google.protobuf.FieldOptions":          {},
	"google.protobuf.OneofOptions":          {},
	"google.protobuf.EnumOptions":           {},
	"google.protobuf.EnumValueOptions":      {},
	"google.protobuf.ServiceOptions":        {},
	"google.protobuf.MethodOptions":         {},
	"google.protobuf.ExtensionRangeOptions": {},
}

func validateEditionsExtensions(extensions []*protogen.Extension) error {
	for _, extension := range extensions {
		if _, ok := optionsExtendees[extension.Desc.ContainingMessage().FullName()]; !ok {
			return fmt.Errorf("%s: extensions are not supported (except custom options)", extension.Desc.FullName())
		}
	}
	return nil
}

func validateEditionsFeatures(file *protogen.File) error {
	if err := validateEditionsExtensions(file.Extensions); err != nil {
		return err
	}
	for _, enum := range file.Enums {
		if err := validateEditionsEnum(enum); err != nil {
			return err
		}
	}
	for _, message := range file.Messages {
		if err := validateEditionsMessage(message); err != nil {
			return err
		}
	}
	return nil
}

func validateEditionsMessage(message *protogen.Message) error {
	if message.Desc.ExtensionRanges().Len() > 0 {
		return fmt.Errorf("%s: extensions are not supported", message.Desc.FullName())
	}
	if err := validateEditionsExtensions(message.Extensions); err != nil {
		return err
	}
	for _, field := range message.Fields {
		if field.Desc.Kind() == protoreflect.GroupKind {
			return fmt.Errorf("%s: delimited message encoding is not supported", field.Desc.FullName())
		}
		if field.Desc.Cardinality() == protoreflect.Required {
			return fmt.Errorf("%s: required fields are not supported", field.Desc.FullName())
		}
	}
	for _, enum := range message.Enums {
		if err := validateEditionsEnum(enum); err != nil {
			return err
		}
	}
	for _, nested := range message.Messages {
		if err := validateEditionsMessage(nested); err != nil {
			return err
		}
	}
	return nil
}

func validateEditionsEnum(enum *protogen.Enum) error {
	if enum.Desc.IsClosed() {
		return fmt.Errorf("%s: closed enums are not supported", enum.Desc.FullName())
	}
	return nil
}
