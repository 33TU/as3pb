package internal

import (
	"reflect"
	"testing"

	"google.golang.org/protobuf/compiler/protogen"
)

func TestCommentLinesPreservesParagraphsAndIndentation(t *testing.T) {
	comments := protogen.Comments(" Heading\n\n Example:\n\n     first();\n       continued();\n")
	want := []string{
		"Heading",
		"",
		"Example:",
		"",
		"    first();",
		"      continued();",
	}

	if got := commentLines(comments); !reflect.DeepEqual(got, want) {
		t.Fatalf("commentLines() = %#v, want %#v", got, want)
	}
}

func TestCommentLinesLeavesGeneratedCommentsUnpadded(t *testing.T) {
	comments := protogen.Comments("Generated comment.\n@param value Description.")
	want := []string{"Generated comment.", "@param value Description."}

	if got := commentLines(comments); !reflect.DeepEqual(got, want) {
		t.Fatalf("commentLines() = %#v, want %#v", got, want)
	}
}
