#!/usr/bin/env bbs
#MISE description= "Re-apply Phase 3b CRDs to a running cluster (folds AIREF-00015)"


;; sync-crds -- delegate to the typed Go subcommand `defn cluster
;; sync-crds`. Run from a k3d cluster brick dir after stamping a new
;; -crds app to install its CRDs without re-running the full create
;; flow. Idempotent (kubectl apply --server-side --force-conflicts).
;; Folds AIREF-00015 into the brick layer.

(require '[defn :refer :all])


(let [env-name (System/getenv "ENV_NAME")]
  (when (str/blank? env-name)
    (log-err "ENV_NAME not set -- run from a k3d cluster brick (e.g. cd tenant/<owner>/k3d/<name> && mise run sync-crds)")
    (exit 1))
  (defn-bin! "cluster" "sync-crds" env-name))
