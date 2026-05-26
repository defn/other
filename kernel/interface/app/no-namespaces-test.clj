#!/usr/bin/env bbs
;; Verify rendered kustomize YAML contains no Namespace resources.
;; Namespaces are managed exclusively by capsule-tenants -- including
;; them in app manifests causes ownership conflicts where ArgoCD
;; deletes the namespace if removed from the chart, breaking all
;; resources in that namespace.
;; Usage: no-namespaces-test.clj <rendered.yaml>

(require '[defn :refer :all])


(let [yaml-path (first *command-line-args*)
      content   (slurp yaml-path)
      ;; Split into YAML documents
      docs      (str/split content #"\n---\n")
      ;; Find Namespace resources
      bad       (filter (fn [doc]
                          (re-find #"(?m)^kind: Namespace" doc))
                        docs)]
  (if (seq bad)
    (do
      (log-err (str "found " (count bad) " Namespace resource(s) in rendered YAML"))
      (doseq [doc bad]
        (println (re-find #"(?m)^  name: .*" doc)))
      (exit 1))
    (log-ok "no Namespace resources in rendered YAML")))
