package internal_test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/33TU/as3pb/internal"
)

func TestMemoryBackendOptions(t *testing.T) {
	for mask := 0; mask < 16; mask++ {
		t.Run(fmt.Sprintf("flags-%04b", mask), func(t *testing.T) {
			serialize := mask&1 != 0
			deserialize := mask&2 != 0
			pack := mask&4 != 0
			unpack := mask&8 != 0
			plugin := messagePlugin(t)
			generator := internal.NewGenerator(plugin, internal.Options{
				GenerateSerialize: &serialize, GenerateDeserialize: &deserialize,
				GenerateSerializeMemory: pack, GenerateDeserializeMemory: unpack,
			})
			if err := generator.GenerateFile(plugin.Files[0]); err != nil {
				t.Fatal(err)
			}
			for _, file := range plugin.Response().GetFile() {
				body := file.GetContent()
				if !strings.Contains(body, "public static function reset(") {
					continue
				}
				for _, check := range []struct {
					text    string
					present bool
				}{
					{"public static function serializeBytes(", serialize},
					{"public static function deserializeBytes(", deserialize},
					{"public static function serializeMemory(", pack},
					{"public static function deserializeMemory(", unpack},
					{"import as3pb.proto.PackContext;", pack},
					{"import as3pb.proto.UnpackContext;", unpack},
					{"AnyRegistry.register(", serialize && deserialize},
				} {
					if strings.Contains(body, check.text) != check.present {
						t.Errorf("%s: presence of %q: want %v", file.GetName(), check.text, check.present)
					}
				}
				if unpack {
					for _, want := range []string{"length:uint", "src.limit = end;", "src.limit = previousLimit;", "Unpack.readTag(src)"} {
						if !strings.Contains(body, want) {
							t.Errorf("missing %q", want)
						}
					}
				}
				if pack && strings.Contains(body, "messageStart = Pack.startMessage(dst);") && !strings.Contains(body, "Pack.endMessage(dst, messageStart);") {
					t.Error("nested memory message lacks length finalization")
				}
			}
		})
	}
}

func TestMemoryBackendsDefaultOff(t *testing.T) {
	plugin := messagePlugin(t)
	generator := internal.NewGenerator(plugin, internal.Options{})
	if err := generator.GenerateFile(plugin.Files[0]); err != nil {
		t.Fatal(err)
	}
	for _, file := range plugin.Response().GetFile() {
		for _, unwanted := range []string{"serializeMemory(", "deserializeMemory(", "as3pb.proto.Pack", "as3pb.proto.Unpack", "avm2.intrinsics"} {
			if strings.Contains(file.GetContent(), unwanted) {
				t.Errorf("default output includes %q", unwanted)
			}
		}
	}
}

func TestMemoryBackendsSkipBundledTypesUnlessExplicit(t *testing.T) {
	for _, options := range []internal.Options{
		{GenerateAlways: true, GenerateSerializeMemory: true},
		{GenerateAlways: true, GenerateDeserializeMemory: true},
	} {
		plugin := anyPlugin(t)
		generator := internal.NewGenerator(plugin, options)
		if err := generator.GenerateFile(plugin.Files[0]); err != nil {
			t.Fatal(err)
		}
		if files := plugin.Response().GetFile(); len(files) != 0 {
			t.Fatalf("generated bundled Any implicitly: %v", files)
		}
		plugin.Files[0].Generate = true
		if err := generator.GenerateFile(plugin.Files[0]); err != nil {
			t.Fatal(err)
		}
		files := plugin.Response().GetFile()
		if len(files) != 1 || files[0].GetName() != "google/protobuf/Any.as" {
			t.Fatalf("memory dependencies missing Any: %v", files)
		}
		if strings.Contains(files[0].GetContent(), "function serializeMemory(") != options.GenerateSerializeMemory ||
			strings.Contains(files[0].GetContent(), "function deserializeMemory(") != options.GenerateDeserializeMemory {
			t.Fatal("imported Any does not match selected memory backends")
		}
	}
}
