#!/usr/bin/env bbs
#MISE description= "Generate, build, test, and validate in one pass"

(require '[defn :refer :all])


;; Build //... to prime Bazel's analysis cache. Inherit IO so Bazel's
;; own progress/INFO/test summary lines flow straight to the terminal.
;; Blank lines before/after frame the Bazel block visually.
(println)


(let [r (sh!!? {:out :inherit :err :inherit} "bazel-runner" "build" "//...")]
  (println)
  (when-not (zero? (:exit r))
    (exit (:exit r))))


;; Run the gen pipeline (gen + build + test + validate + lattice).
;; defn-bin! resolves to the active tenant's namesake CLI via the
;; default_tenant lattice shard (AIDR-00141 Stage 3.5d).
(do (defn-bin! "pipeline") nil)
