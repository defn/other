package dispatchworker

import (
	"strings"
	"testing"
)

// AIDR-00132 OQ7 step 2: smoke-test the renderDispatchCUE body
// shape. The package-name detection helpers it uses live in
// m/go/lib/brickpkg and are tested there.

func TestRenderDispatchCUE_ContainsExpectedShape(t *testing.T) {
	body := renderDispatchCUE("foo")
	for _, want := range []string{
		"package foo",
		`import "github.com/defn/other/kernel/spec/dispatch"`,
		"worker: dispatch.#BrickResult",
		"reads: []",
		"writes: []",
	} {
		if !strings.Contains(body, want) {
			t.Errorf("body missing %q:\n%s", want, body)
		}
	}
}
