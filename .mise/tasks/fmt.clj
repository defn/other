#!/usr/bin/env bbs
#MISE description= "Format all files in the workspace"


;; fmt.clj -- format all files via Bazel fmt tests with auto-fix.
;;
;; Runs fmt-tagged Bazel tests, then copies correctly-formatted files
;; back from test outputs. Cached by Bazel -- only re-formats changed files.

(require '[defn :refer :all])


(let [r (sh!!? "mise" "exec" "--" "bazelisk" "test"
               "--test_output=errors"
               "--build_tests_only"
               "//..." "--test_tag_filters=fmt")]
  (if (zero? (:exit r))
    (log-ok "all files correctly formatted")
    (let [fixed (fix-fmt-from-testlogs "bazel-testlogs")]
      (if (pos? fixed)
        (log-ok (format "auto-fixed %d file(s)" fixed))
        (do (log-err "formatting failed")
            (exit 1))))))
