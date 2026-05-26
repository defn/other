#!/usr/bin/env bbs
;; AIDR-00100: production-side lattice-schema vet.
;;
;; Invokes `defn check latticeschema`, which internalizes the cue
;; vet pipeline that the previous .clj driver shelled out to. The
;; binary loads kernel/spec/lattice-schema.cue + the merged lattice
;; JSON in-process and runs val.Validate(cue.Concrete(true)). See
;; AIDR-00061 for the constraints encoded in the schema.
;;
;; Args (positional, matches //kernel/spec:lattice_schema_vet
;; sh_test):
;;   DEFN_BIN  -- workspace path to //tenant/defn/go/cmd/defn:defn

(require '[defn :refer :all])


(let [[defn-bin] *command-line-args*
      runfiles  (str (System/getenv "TEST_SRCDIR") "/"
                     (System/getenv "TEST_WORKSPACE"))
      {:keys [exit out err]}
      (sh-result defn-bin "check" "latticeschema" "--workdir" runfiles)]
  (when (not (zero? exit))
    (println "lattice-schema vet failed:")
    (when (seq out) (println out))
    (when (seq err) (println err))
    (System/exit 1))
  (println (str "vet lattice-schema: " (trim out))))
