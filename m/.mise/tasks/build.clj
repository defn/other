#!/usr/bin/env bbs
#MISE description= "Build all Bazel targets"

(require '[defn :refer :all])

(log-ok "building all targets")
(run-tool! "bazelisk" "build" "//...")
