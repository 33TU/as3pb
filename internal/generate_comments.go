package internal

import (
	"strings"
	"unicode"

	"google.golang.org/protobuf/compiler/protogen"
)

func (g *Generator) generateLeadingComment(comments protogen.Comments, trailingNewline bool) bool {
	lines := commentLines(comments)
	if len(lines) == 0 {
		return false
	}

	g.w.Line("/**")
	for _, line := range lines {
		g.w.Line(" * %s", line)
	}
	g.w.Line(" */")
	if trailingNewline {
		g.w.BlankLine()
	}
	return true
}

func (g *Generator) generateTrailingComment(indentFirstLine bool, comments protogen.Comments) bool {
	comment := strings.TrimRightFunc(comments.String(), unicode.IsSpace)
	if comment == "" {
		return false
	}

	lines := strings.Split(comment, "\n")
	line := strings.TrimSpace(lines[0])
	line = strings.TrimSpace(strings.TrimPrefix(line, "//"))
	if line == "" {
		return false
	}

	if indentFirstLine {
		g.w.WriteIndent()
	} else {
		g.w.Write(" ")
	}
	g.w.Write("// %s", line)
	return true
}

func commentLines(comments protogen.Comments) []string {
	raw := strings.TrimRightFunc(comments.String(), unicode.IsSpace)
	if raw == "" {
		return nil
	}

	var lines []string
	for _, line := range strings.Split(raw, "\n") {
		line = strings.TrimSpace(line)
		line = strings.TrimSpace(strings.TrimPrefix(line, "//"))
		if line != "" {
			lines = append(lines, line)
		}
	}
	return lines
}
