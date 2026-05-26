#!/usr/bin/env bbs
#MISE description= "Run all Bazel tests and spec tests"

(require '[defn :refer :all])

(log-ok "testing all targets")


(let [r (sh!!? "mise" "exec" "--" "bazelisk" "test" "--test_output=errors" "//...")]
  ;; Always print INFO lines (target counts, timing, cache stats)
  ;; Match with or without ANSI color codes
  (doseq [line (clojure.string/split-lines (:err r))]
    (when (re-find #"INFO:" line)
      (println line)))
  (if (zero? (:exit r))
    (log-ok "all bazel tests passed")
    (do
      (println (:out r))
      (println (:err r))
      ;; Auto-fix formatting failures by copying formatted files from test outputs.
      (let [fixed (fix-fmt-from-testlogs "bazel-testlogs")]
        (if (pos? fixed)
          (do (log-ok (format "auto-fixed %d file(s), re-running tests" fixed))
              (run-tool! "bazelisk" "test" "--test_output=errors" "//..."))
          (exit 1))))))


(println)
(log-ok "running spec tests")
(sh!! "mise" "run" "spec-run")
