#!/usr/bin/env bbs
;; AIDR-00098 + AIDR-00099: production-side brick-collision check.
;;
;; Invokes `defn check brickcollision`, which internalizes the
;; CUE evaluation that the previous `checkbrickcollisions` internal
;; binary received as a JSON dump. The binary loads the contracts
;; package + per-generator contract.cue files + merged lattice
;; in-process, then runs //go/lib/spec/brickcollision.Check.
;; Exits non-zero on any non-ancestor brick pair sharing a write
;; path. See AIDR-00099 for the promotion to a `defn` subcommand.
;;
;; The runfiles tree at TEST_SRCDIR/TEST_WORKSPACE mirrors the
;; workspace layout for every CUE input the binary needs:
;; cue.mod/module.cue, kernel/spec/contracts-schema.cue +
;; known-shared.cue + manual-files / convention-contracts shards,
;; kernel/spec/lattice/ shards + _index.json, and every generator's
;; go/lib/gen/<name>/contract.cue. We pass that runfiles dir
;; via --workdir so the binary skips its cue.mod walk-up discovery
;; and reads exactly the runfiles we declared.
;;
;; Args (positional, matches //kernel/spec:brick_collision_vet
;; sh_test):
;;   DEFN_BIN  -- workspace path to //tenant/defn/go/cmd/defn:defn

(require '[defn :refer :all])


(let [[defn-bin] *command-line-args*
      runfiles  (str (System/getenv "TEST_SRCDIR") "/"
                     (System/getenv "TEST_WORKSPACE"))
      {:keys [exit out err]}
      (sh-result defn-bin "check" "brickcollision" "--workdir" runfiles)]
  (when (not (zero? exit))
    (println "brick-collision vet failed:")
    (when (seq out) (println out))
    (when (seq err) (println err))
    (System/exit 1))
  (println (str "vet brick-collision: " (trim out))))
