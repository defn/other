#!/usr/bin/env bbs
;; sync.clj -- copy a generated file from bazel-bin back to the workspace.
#MISE hide=true


;; Usage (via bazelisk run): sync.clj <dest_relative_path> <generated_file> [mode]
;; $BUILD_WORKSPACE_DIRECTORY is set automatically by bazelisk run.

(require '[defn :refer :all])


(let [[dest src & opts] *command-line-args*
      ws-dir (System/getenv "BUILD_WORKSPACE_DIRECTORY")
      dest-path (str ws-dir "/" dest)
      mode (or (first opts) "644")]
  (create-dirs (parent dest-path))
  (copy-file src dest-path {:replace-existing true})
  (sh! "chmod" mode dest-path)
  (log-ok (str "synced: " dest)))
