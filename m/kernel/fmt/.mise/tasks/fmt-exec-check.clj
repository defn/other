#!/usr/bin/env bbs
#MISE hide=true


;; fmt-exec-check.clj -- verify a file has executable permission.
;; Usage: fmt-exec-check.clj <file>

(require '[defn :refer :all])


(let [[file] *command-line-args*]
  (if (sh? "test" "-x" file)
    (log-ok (str file " is executable"))
    (do (log-err (str file " is not executable"))
        (println "  Fix: chmod +x" file)
        (exit 1))))
