#!/usr/bin/env bbs
;; AIDR-00100: production-side contracts vet.
;;
;; Invokes `defn check contracts`, which internalizes the cue vet
;; pipeline that the previous .clj driver shelled out to. The binary
;; loads kernel/spec/contracts-schema.cue + known-shared +
;; manual-files / convention-contracts shards + every per-generator
;; contract.cue + the merged lattice JSON in-process and runs
;; val.Validate(cue.Concrete(true)). See AIDR-00062 for the
;; orphans / missingClaims / manualClaimed / unannouncedShared
;; constraints encoded in the schema.
;;
;; Args (positional, matches //kernel/spec:contracts_vet sh_test):
;;   DEFN_BIN  -- workspace path to //tenant/defn/go/cmd/defn:defn

(require '[defn :refer :all])


(let [[defn-bin] *command-line-args*
      runfiles  (str (System/getenv "TEST_SRCDIR") "/"
                     (System/getenv "TEST_WORKSPACE"))
      {:keys [exit out err]}
      (sh-result defn-bin "check" "contracts" "--workdir" runfiles)]
  (when (not (zero? exit))
    (println "contracts vet failed:")
    (when (seq out) (println out))
    (when (seq err) (println err))
    (System/exit 1))
  (println (str "vet contracts: " (trim out))))
