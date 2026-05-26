#!/usr/bin/env bbs
#MISE description= "Push helm charts to OCI registry"


;; helm-publish -- pushes built helm chart .tgz files to the OCI registry.
;;
;; Every chart is published per-cluster at oci://<registry>/rendered-manifests/<cluster>/<name>:<version>.
;; Push is always force (idempotent: same content produces same OCI digest;
;; the local registry is fast).
;;
;; Prerequisites:
;;   - `mise run gen` has been run (charts built in bazel-bin)
;;   - `mise run helm-bump` has been run if content changed
;;   - Registry is accessible (e.g. localhost:5000)
;;
;; Usage:
;;   mise run helm-publish          # publish all pending charts
;;   mise run helm-publish argocd   # publish specific app

(require '[defn :refer :all])


(let [filter-app    (first *command-line-args*)
      ;; Lattice-backed catalog reads via kernel-lib helpers (AIDR-00109).
      ;; chart_versions / k3d_clusters / apps live in tenant overlays
      ;; that cue export against kernel/catalog alone cannot resolve;
      ;; the lattice shards are built across all catalogs by `defn gen`.
      versions      (chart-versions)
      cluster-names (sort (map #(:cluster_name (val %)) (k3d-clusters)))
      ;; Registry: localhost because helm-publish runs from the devcontainer
      registry      "localhost:5000"
      published     (atom 0)]

  (doseq [[app-key app] (sort-by key versions)]
    (let [app-name        (name app-key)
          cluster-digests (:cluster_digests app)
          app-path        (brick-path app-name)]

      (when (or (nil? filter-app) (= filter-app app-name))
        (doseq [cluster-name cluster-names]
          (let [version   (:version (get cluster-digests (keyword cluster-name)))
                chart-tgz (str "bazel-bin/" app-path "/" cluster-name "-" app-name "-" version ".tgz")]
            (cond
              (str/blank? version)
              (log-err (str app-name " (" cluster-name "): no version -- check catalog/catalog.cue"))

              (str/blank? app-path)
              (log-err (str app-name " (" cluster-name "): no brick path in lattice apps.json"))

              (not (fs/exists? chart-tgz))
              (log-err (str app-name " v" version " (" cluster-name "): chart not found at " chart-tgz
                            " -- run `mise run gen` first"))

              :else
              (do
                (run-tool! "helm" "push" chart-tgz
                           (str "oci://" registry "/rendered-manifests/" cluster-name)
                           "--insecure-skip-tls-verify")
                (swap! published inc)
                (log-ok (str app-name " v" version " (" cluster-name "): pushed")))))))))

  (println)
  (if (pos? @published)
    (log-ok (str "published " @published " chart(s) to " registry))
    (log-ok "all charts already in registry -- nothing to publish.")))
