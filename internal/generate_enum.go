package internal

import "google.golang.org/protobuf/compiler/protogen"

func (g *Generator) generateEnumFile(enum *protogen.Enum) error {
	filename, file, err := g.newGeneratedFile(string(enum.Desc.ParentFile().Package()), EnumClassName(enum))
	if err != nil {
		return err
	}
	g.w.Reset(file)

	if err := g.generateEnumClass(enum); err != nil {
		return err
	}
	if err := g.w.Err(); err != nil {
		return err
	}

	g.log.Debug("generated enum file", "path", filename)
	return nil
}

func (g *Generator) generateEnumClass(enum *protogen.Enum) error {
	packageName := string(enum.Desc.ParentFile().Package())

	g.generateFileHeaderComment(enum.Desc.ParentFile().Path())
	g.w.Line("package %s", packageName)
	g.w.Line("{")
	g.w.Indent()

	g.generateLeadingComment(enum.Comments.Leading, false)
	g.w.Line("public final class %s", EnumClassName(enum))
	g.w.Line("{")
	g.w.Indent()

	if g.generateTrailingComment(true, enum.Comments.Trailing) {
		g.w.BlankLine()
	}
	g.generateEnumFields(enum)

	g.w.Dedent()
	g.w.Line("}")
	g.w.Dedent()
	g.w.Line("}")
	return nil
}

func (g *Generator) generateEnumFields(enum *protogen.Enum) {
	// AS3 constant names are case-normalized, so allow_alias values such as MOO and
	// moo claim the same name and must collapse into one constant. Their numbers
	// always agree: protobuf rejects names that normalize alike unless they alias
	// the same number, and closed enums are rejected in validate_editions.go.
	emitted := make(map[string]struct{}, len(enum.Values))

	for i, value := range enum.Values {
		name := EnumName(value)
		if _, ok := emitted[name]; ok {
			g.log.Debug("skipping aliased enum value",
				"enum", enum.Desc.FullName(), "value", value.Desc.Name(), "constant", name)
			continue
		}
		emitted[name] = struct{}{}

		if value.Comments.Leading != "" && i > 0 {
			g.w.BlankLine()
		}
		g.generateLeadingComment(value.Comments.Leading, false)
		g.w.WriteIndent()
		g.w.Write("public static const %s:uint = %d;", name, value.Desc.Number())
		g.generateTrailingComment(false, value.Comments.Trailing)
		g.w.Write("\n")
	}
}
