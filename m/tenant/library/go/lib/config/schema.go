package config

import (
	"fmt"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/cuecontext"
)

// ValidateCUE validates a Go value against a CUE schema string.
func ValidateCUE(schema string, value any) error {
	ctx := cuecontext.New()

	compiled := ctx.CompileString(schema)
	if compiled.Err() != nil {
		return fmt.Errorf("compile schema: %w", compiled.Err())
	}

	goVal := ctx.Encode(value)
	if goVal.Err() != nil {
		return fmt.Errorf("encode value: %w", goVal.Err())
	}

	unified := compiled.Unify(goVal)
	if err := unified.Validate(cue.Concrete(true)); err != nil {
		return fmt.Errorf("validate: %w", err)
	}
	return nil
}
