#!/usr/bin/env bbs
#MISE description= "Apply apps.yaml to register all apps with ArgoCD"


;; deploy-argocd -- applies the cluster brick's apps.yaml to the current cluster.
;;
;; Must be run from a k3d cluster directory (e.g. tenant/<owner>/k3d/<name>/)
;; where ENV_NAME is set in mise.toml and KUBECONFIG points to the cluster.
;;
;; apps.yaml is co-located with the cluster brick (gen-stamped from the
;; k3d generator's apps.yaml claim). This lets `mise run deploy-argocd`
;; re-apply the app-of-apps without rebuilding the cluster.

(require '[defn :refer :all])


(let [env-name   (System/getenv "ENV_NAME")
      caller-dir (or (System/getenv "MISE_ORIGINAL_CWD") (System/getProperty "user.dir"))]
  (when (str/blank? env-name)
    (log-err "ENV_NAME not set -- run this from a k3d cluster directory (e.g. cd tenant/<owner>/k3d/<name> && mise run deploy-argocd)")
    (exit 1))

  (let [apps-yaml (str caller-dir "/apps.yaml")
        sh-opts   {:dir caller-dir}]

    (when-not (fs/exists? apps-yaml)
      (log-err (str "apps.yaml not found at " apps-yaml))
      (log-err "run `mise run gen` first")
      (exit 1))

    (log-ok (str "applying " apps-yaml))
    (sh!! sh-opts "kubectl" "apply" "-f" apps-yaml)
    (println)
    (log-ok (str "apps deployed to " env-name))))
