#!/usr/bin/env bbs
#MISE description= "Create k3d cluster with ArgoCD: tofu, gen, k3d, deploy apps"


;; create -- delegate to the typed Go subcommand `defn cluster
;; create`. The substantive orchestration lives there now (see
;; AIDR-00110..00115 for the migration trail). This wrapper exists
;; so operators keep typing `mise run create` from a brick dir
;; without having to learn the new binary's arg shape.

(require '[defn :refer :all])


(let [env-name (System/getenv "ENV_NAME")]
  (when (str/blank? env-name)
    (log-err "ENV_NAME not set -- run from a k3d cluster brick (e.g. cd tenant/<owner>/k3d/<name> && mise run create)")
    (exit 1))
  (defn-bin! "cluster" "create" env-name))
