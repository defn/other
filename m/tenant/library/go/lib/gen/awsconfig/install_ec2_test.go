package awsconfig

import (
	"testing"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/cuecontext"
)

// TestImageBootstrapGate verifies that the absent-field gate in Run
// distinguishes "tenant declared image_bootstrap" from "schema slot
// exists but tenant omitted it". Per AIDR-00105 code-major #1: a
// top-level optional schema field reports Exists()==true on the
// concrete catalog because the schema field is part of the struct
// shape, so the gate must probe an inner path that only exists when
// the tenant declares a value.
func TestImageBootstrapGate(t *testing.T) {
	cctx := cuecontext.New()

	// Schema-shape only: tenant did NOT declare image_bootstrap. The
	// optional field is in the struct shape but has no concrete value.
	absent := cctx.CompileString(`
		#ImageBootstrap: zfs_docker: {bucket: !="", key: !=""}
		image_bootstrap?: #ImageBootstrap
	`)
	if err := absent.Err(); err != nil {
		t.Fatalf("compile absent: %v", err)
	}

	// Outer slot reports Exists() against the schema shape, so the
	// outer gate would falsely fire and downstream DecodeString fails.
	if !absent.LookupPath(cue.ParsePath("image_bootstrap")).Exists() {
		t.Logf("note: outer-path Exists()==false on absent optional; outer gate would skip correctly today, but inner-path is the durable idiom")
	}
	// Inner gate distinguishes correctly: zfs_docker is not in the
	// schema shape because the optional outer field has no value.
	if absent.LookupPath(cue.ParsePath("image_bootstrap.zfs_docker")).Exists() {
		t.Errorf("inner gate fired on absent image_bootstrap")
	}

	// Concrete: tenant declared image_bootstrap with valid values.
	present := cctx.CompileString(`
		#ImageBootstrap: zfs_docker: {bucket: !="", key: !=""}
		image_bootstrap?: #ImageBootstrap
		image_bootstrap: zfs_docker: {bucket: "b", key: "k"}
	`)
	if err := present.Err(); err != nil {
		t.Fatalf("compile present: %v", err)
	}
	if !present.LookupPath(cue.ParsePath("image_bootstrap.zfs_docker")).Exists() {
		t.Errorf("inner gate did not fire on present image_bootstrap")
	}
	bucket, err := present.LookupPath(cue.ParsePath("image_bootstrap.zfs_docker.bucket")).String()
	if err != nil || bucket != "b" {
		t.Errorf("decode bucket: got %q err %v", bucket, err)
	}
}
