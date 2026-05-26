#!/usr/bin/env bbs
#MISE description= "Verify every git-tracked file is known to Bazel with format and tag coverage"

(require '[defn :refer :all])


(let [git-files    (git-tracked-files)
      bazel-files  (bazel-source-files)
      fmt-covered  (bazel-fmt-covered-files)
      mise-tagged  (bazel-tagged-files "mise-task")
      all-tagged   (bazel-tagged-files "tagged")

      ;; Check 1: all git files known to Bazel
      missing-bazel (sort (difference git-files bazel-files))

      ;; Check 2: all git files must have fmt_test coverage
      missing-fmt (sort (difference git-files fmt-covered))

      ;; Check 3: mise-task coverage for all .mise/tasks/*.clj (top-level and brick)
      mise-tasks (filter (fn [f]
                           (and (str/includes? f ".mise/tasks/")
                                (str/ends-with? f ".clj")))
                         git-files)
      missing-mise (sort (remove mise-tagged mise-tasks))

      ;; Check 4: all git files must have a tagged_file
      missing-tagged (sort (difference git-files all-tagged))

      errors? (or (seq missing-bazel) (seq missing-fmt)
                  (seq missing-mise) (seq missing-tagged))]

  ;; Report check 1
  (if (empty? missing-bazel)
    (log-ok (format "all %d git-tracked files are known to Bazel" (count git-files)))
    (do (log-err "the following git-tracked files are NOT registered with Bazel:")
        (println)
        (doseq [f missing-bazel] (println (str "  " f)))
        (println)
        (println "Fix: add them to exports_files([...]) in the appropriate BUILD.bazel")))

  ;; Report check 2
  (if (empty? missing-fmt)
    (log-ok (format "all %d git-tracked files have fmt_test coverage" (count git-files)))
    (do (log-err "the following files lack a fmt_test:")
        (println)
        (doseq [f missing-fmt] (println (str "  " f)))
        (println)
        (println "Fix: add fmt_test() for each file in the appropriate BUILD.bazel")))

  ;; Report check 3 -- subset of check 4; only emit on failure.
  (when (seq missing-mise)
    (log-err "the following mise tasks lack a tagged_file(tags=[\"mise-task\"]):")
    (println)
    (doseq [f missing-mise] (println (str "  " f)))
    (println)
    (println "Fix: add tagged_file() for each task in .mise/tasks/BUILD.bazel"))

  ;; Report check 4
  (if (empty? missing-tagged)
    (log-ok (format "all %d git-tracked files have tagged_file coverage" (count git-files)))
    (do (log-err "the following files lack a tagged_file:")
        (println)
        (doseq [f missing-tagged] (println (str "  " f)))
        (println)
        (println "Fix: add tagged_file() in the appropriate BUILD.bazel")))

  (exit (if errors? 1 0)))
