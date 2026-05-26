#!/usr/bin/env bbs
#MISE description= "Generate and sync without testing -- reach equilibrium after stamp changes"

(require '[defn :refer :all])


;; Build and run defn via the shared helper. defn-bin! handles the
;; bazel-build-then-run dance, with `go run ./go` fallback when the
;; bazel build fails (typical cause: a deps.cue change adding a new
;; Go import not yet stamped into BUILD.bazel deps -- the gen pipeline
;; will regenerate it and the next bazel build will succeed).
(defn-bin! "hatch")
