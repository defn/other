#!/usr/bin/env bbs
;; AIDR-00102 / SPEC-00352: production-side cross-tenant literal vet.
;;
;; Invokes `defn check crosstenantlit`, which walks every leaf
;; tenant's source tree and forbids string literals naming any other
;; leaf tenant or any other leaf tenant's auth profile values. The
;; binary internalizes the CUE evaluation that supplies the
;; brick_io.writes union (the generator-output skip set) and reads
;; tenant/<T>/catalog/auth.cue directly for profile discovery.
;;
;; The runfiles tree at TEST_SRCDIR/TEST_WORKSPACE mirrors the
;; workspace layout for every input the binary needs:
;; cue.mod/module.cue, kernel/spec/contracts-schema.cue +
;; known-shared.cue + manual-files / convention-contracts shards,
;; kernel/spec/lattice/ shards + _index.json, every generator's
;; go/lib/gen/<name>/contract.cue, and the leaf tenants'
;; catalog/auth.cue + source trees. We pass that runfiles dir via
;; --workdir so the binary skips its cue.mod walk-up discovery and
;; reads exactly the runfiles we declared.
;;
;; Args (positional, matches //kernel/spec:cross_tenant_lit_vet
;; sh_test):
;;   DEFN_BIN  -- workspace path to //tenant/defn/go/cmd/defn:defn

(require '[defn :refer :all])


(let [[defn-bin] *command-line-args*
      runfiles  (str (System/getenv "TEST_SRCDIR") "/"
                     (System/getenv "TEST_WORKSPACE"))
      {:keys [exit out err]}
      (sh-result defn-bin "check" "crosstenantlit" "--workdir" runfiles)]
  (when (not (zero? exit))
    (println "cross-tenant-lit vet failed:")
    (when (seq out) (println out))
    (when (seq err) (println err))
    (System/exit 1))
  (println (str "vet cross-tenant-lit: " (trim out))))
