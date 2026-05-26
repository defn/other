package hatch

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/cuecontext"
)

// DispatchPlan / BrickResult / BlockedOn are the Go projections of
// the kernel/spec/dispatch/dispatch_plan.cue schema. JSON tags drive
// both the CUE-side decode (cue.Value.Decode walks them) and the
// write side (we emit JSON, which is a CUE subset). The on-disk
// shape is a `*.cue` file that's also valid JSON; CUE readers can
// unify it against `dispatch.#DispatchPlan` / `dispatch.#BrickResult`
// to validate.

type DispatchPlan struct {
	Bricks map[string]BrickResult `json:"bricks"`
}

type BrickResult struct {
	Reads            []string    `json:"reads"`
	Writes           []string    `json:"writes"`
	Status           string      `json:"status,omitempty"`
	BlockedOn        []BlockedOn `json:"blockedOn,omitempty"`
	Fingerprint      string      `json:"fingerprint,omitempty"`
	SessionID        string      `json:"session_id,omitempty"`
	LogPath          string      `json:"log_path,omitempty"`
	OutOfLanePatch   string      `json:"out_of_lane_patch,omitempty"`
	TokensInput      int         `json:"tokens_input,omitempty"`
	TokensOutput     int         `json:"tokens_output,omitempty"`
	TokensCacheRead  int         `json:"tokens_cache_read,omitempty"`
	TokensCacheWrite int         `json:"tokens_cache_write,omitempty"`
	TokensThought    int         `json:"tokens_thought,omitempty"`
	TokensTotal      int         `json:"tokens_total,omitempty"`
	CostAmount       float64     `json:"cost_amount,omitempty"`
	CostCurrency     string      `json:"cost_currency,omitempty"`
}

type BlockedOn struct {
	Sibling string   `json:"sibling"`
	Paths   []string `json:"paths"`
}

// LoadDispatchPlan reads a CUE file and decodes it into a
// DispatchPlan. An empty / missing path returns the empty plan
// (the F1 self-check then trivially passes).
func LoadDispatchPlan(path string) (*DispatchPlan, error) {
	if path == "" {
		return &DispatchPlan{Bricks: map[string]BrickResult{}}, nil
	}
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return &DispatchPlan{Bricks: map[string]BrickResult{}}, nil
		}
		return nil, fmt.Errorf("read snapshot %s: %w", path, err)
	}
	v := cuecontext.New().CompileBytes(data, cue.Filename(path))
	if err := v.Err(); err != nil {
		return nil, fmt.Errorf("parse snapshot %s: %w", path, err)
	}
	plan := &DispatchPlan{}
	if err := v.Decode(plan); err != nil {
		return nil, fmt.Errorf("decode snapshot %s: %w", path, err)
	}
	if plan.Bricks == nil {
		plan.Bricks = map[string]BrickResult{}
	}
	return plan, nil
}

// LoadBrickResult reads a single-#BrickResult CUE file. The shape is
// a bare struct (no `bricks:` wrapper) because that's what
// `defn hatch --brick=<slug> --result-out=<f>` emits per agent.
func LoadBrickResult(path string) (BrickResult, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return BrickResult{}, fmt.Errorf("read result %s: %w", path, err)
	}
	v := cuecontext.New().CompileBytes(data, cue.Filename(path))
	if err := v.Err(); err != nil {
		return BrickResult{}, fmt.Errorf("parse result %s: %w", path, err)
	}
	var br BrickResult
	if err := v.Decode(&br); err != nil {
		return BrickResult{}, fmt.Errorf("decode result %s: %w", path, err)
	}
	return br, nil
}

// WriteResultCUE writes a #BrickResult to disk as CUE (we emit JSON,
// which CUE reads natively). Schema: dispatch.#BrickResult.
func WriteResultCUE(path string, r BrickResult) error {
	if r.Reads == nil {
		r.Reads = []string{}
	}
	if r.Writes == nil {
		r.Writes = []string{}
	}
	return writeJSON(path, r)
}

// WritePlanCUE writes a #DispatchPlan to disk as CUE/JSON.
func WritePlanCUE(path string, plan *DispatchPlan) error {
	if plan == nil {
		plan = &DispatchPlan{Bricks: map[string]BrickResult{}}
	}
	if plan.Bricks == nil {
		plan.Bricks = map[string]BrickResult{}
	}
	for k, b := range plan.Bricks {
		if b.Reads == nil {
			b.Reads = []string{}
		}
		if b.Writes == nil {
			b.Writes = []string{}
		}
		plan.Bricks[k] = b
	}
	return writeJSON(path, plan)
}

func writeJSON(path string, v any) error {
	data, err := json.MarshalIndent(v, "", "\t")
	if err != nil {
		return fmt.Errorf("marshal %s: %w", path, err)
	}
	if dir := filepath.Dir(path); dir != "." && dir != "" {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return fmt.Errorf("mkdir %s: %w", dir, err)
		}
	}
	if err := os.WriteFile(path, append(data, '\n'), 0o644); err != nil {
		return fmt.Errorf("write %s: %w", path, err)
	}
	return nil
}
