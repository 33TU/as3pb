package internal

import (
	"fmt"

	"google.golang.org/protobuf/compiler/protogen"
)

func (g *Generator) generateServiceFile(service *protogen.Service) error {
	filename, file, err := g.newGeneratedFile(string(service.Desc.ParentFile().Package()), ServiceClassName(service))
	if err != nil {
		return err
	}
	g.w.Reset(file)

	if err := g.generateServiceClass(service); err != nil {
		return err
	}
	if err := g.w.Err(); err != nil {
		return err
	}

	g.log.Debug("generated service file", "path", filename)
	return nil
}

func (g *Generator) generateServiceClass(service *protogen.Service) error {
	packageName := string(service.Desc.ParentFile().Package())
	serviceName := ServiceClassName(service)

	g.generateFileHeaderComment(service.Desc.ParentFile().Path())
	g.w.Line("package %s", packageName)
	g.w.Line("{")
	g.w.Indent()

	g.w.Line("import flash.utils.ByteArray;")
	g.w.Line("import as3pb.rpc.RpcClient;")
	g.w.Line("import as3pb.rpc.BufferPool;")
	g.w.Line("import as3pb.rpc.HttpTransport;")
	g.w.BlankLine()

	g.generateLeadingComment(service.Comments.Leading, false)
	g.w.Line("public final class %s extends RpcClient", serviceName)
	g.w.Line("{")
	g.w.Indent()

	g.generateServiceConstructor(serviceName)
	for _, method := range service.Methods {
		g.w.BlankLine()
		g.generateServiceMethod(packageName, service, method)
	}

	g.w.Dedent()
	g.w.Line("}")
	g.w.Dedent()
	g.w.Line("}")
	return nil
}

func (g *Generator) generateServiceConstructor(serviceName string) {
	g.generateLeadingComment(protogen.Comments(
		"@param baseUrl RPC server base URL.\n"+
			"@param contentType Request content type.\n"+
			"@param headers Optional HTTP headers.\n"+
			"@param transport Optional HTTP transport.",
	), false)
	g.w.Line(`public function %s(baseUrl:String, contentType:String = "application/proto", headers:Array = null, transport:HttpTransport = null)`, serviceName)
	g.w.Line("{")
	g.w.Indent()
	g.w.Line("super(baseUrl, contentType, headers, transport);")
	g.w.Dedent()
	g.w.Line("}")
}

func (g *Generator) generateServiceMethod(packageName string, service *protogen.Service, method *protogen.Method) {
	currentPackage := string(service.Desc.ParentFile().Package())
	methodName := RPCMethodName(method)
	inputType := as3MessageTypeName(method.Input, currentPackage)
	outputType := as3MessageTypeName(method.Output, currentPackage)
	path := fmt.Sprintf("/%s.%s/%s", packageName, service.Desc.Name(), method.Desc.Name())

	g.generateLeadingComment(serviceMethodComment(method, outputType), false)
	g.w.Line("public function %s(request:%s, onComplete:Function, onError:Function):void", methodName, inputType)
	g.w.Line("{")
	g.w.Indent()

	g.w.Line("const buffer:ByteArray = BufferPool.acquire();")
	g.w.Line("%s.serializeBytes(request, buffer);", inputType)
	g.w.BlankLine()

	g.w.Line("this.$callUnary(")
	g.w.Indent()
	g.w.Line(`"%s",`, path)
	g.w.Line("buffer,")
	g.w.Line("function(responseBytes:ByteArray):void")
	g.w.Line("{")
	g.w.Indent()
	g.w.Line("BufferPool.release(buffer);")
	g.w.Line("onComplete(%s.deserializeBytes(responseBytes));", outputType)
	g.w.Dedent()
	g.w.Line("},")
	g.w.Line("function(err:*):void")
	g.w.Line("{")
	g.w.Indent()
	g.w.Line("BufferPool.release(buffer);")
	g.w.Line("onError(err);")
	g.w.Dedent()
	g.w.Line("}")
	g.w.Dedent()
	g.w.Line(");")

	g.w.Dedent()
	g.w.Line("}")
}

func serviceMethodComment(method *protogen.Method, outputType string) protogen.Comments {
	comment := string(method.Comments.Leading)
	if comment != "" && comment[len(comment)-1] != '\n' {
		comment += "\n"
	}
	comment += "@param request The request message.\n"
	comment += "@param onComplete Called with the decoded " + outputType + ".\n"
	comment += "@param onError Called if the RPC request fails."
	return protogen.Comments(comment)
}
