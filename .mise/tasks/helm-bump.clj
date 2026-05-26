#!/usr/bin/env bbs
#MISE description= "Detect chart content changes and bump versions"


;; helm-bump -- compares per-cluster build_digest (from Bazel) against
;; published_digest (from last bump). When a cluster's digest differs,
;; that cluster's chart version is bumped independently of the others.
;;
;; Post AIDR-00072 the chart_versions value layer lives in tenant
;; overlays (tenant/<owner>/catalog/chart_versions.cue), and the
;; published-digests overlay sits alongside it
;; (tenant/<owner>/catalog/published-digests.cue). The cluster's owning
;; tenant is derived from its k3d_clusters[<id>].path field.
;;
;; Usage:
;;   mise run helm-bump          # check all apps
;;   mise run helm-bump argocd   # check specific app

(require '[defn :refer :all])


(defn bump-patch
  "Increment patch version: 0.0.1 -> 0.0.2"
  [version]
  (let [parts (str/split version #"\.")
        major (first parts)
        minor (second parts)
        patch (Integer/parseInt (nth parts 2))]
    (str major "." minor "." (inc patch))))


(defn update-cluster-version!
  "Update the per-cluster version inside chart_versions[app].cluster_digests[cluster]
   in tenant/<owner>/catalog/chart_versions.cue. Handles both the brace
   form used for multi-cluster tenants:
       \"<app>\": cluster_digests: { \"<cluster>\": version: \"<old>\" ... }
   and the flat shorthand used for single-cluster tenants:
       \"<app>\": cluster_digests: \"<cluster>\": version: \"<old>\""
  [tenant app-name cluster-name new-version]
  (let [overlay   (str "tenant/" tenant "/catalog/chart_versions.cue")
        content   (slurp overlay)
        qapp      (java.util.regex.Pattern/quote app-name)
        qcluster  (java.util.regex.Pattern/quote cluster-name)
        ;; Anchor on the app name; the cluster_digests body may be a
        ;; brace block (with up to ~400 chars of sibling clusters /
        ;; comments before this one) or the flat single-cluster
        ;; shorthand. Both forms end with `"<cluster>": version: "<old>"`.
        ver-pat   (re-pattern
                    (str "(\"?" qapp "\"?:\\s*cluster_digests:\\s*(?:\\{[^}]{0,400}?)?\""
                         qcluster "\":\\s*version:\\s*)\"[^\"]*\""))
        replaced  (str/replace content ver-pat
                               (str "$1\"" new-version "\""))]
    (when (= replaced content)
      (log-err (str "could not find version for " app-name "/" cluster-name
                    " in " overlay)))
    (spit overlay replaced)))


(defn write-published-digests!
  "Write per-tenant published-digests.cue overlays. all-published is
   keyed app -> cluster -> digest; entries are split by the cluster's
   owning tenant before write."
  [all-published]
  (let [by-tenant (atom {})]
    (doseq [[app-name cluster-map] all-published
            [cluster-name digest]  cluster-map
            :let [tenant (cluster-tenant cluster-name)]
            :when tenant]
      (swap! by-tenant assoc-in [tenant app-name cluster-name] digest))
    (doseq [[tenant apps] @by-tenant]
      (let [overlay (str "tenant/" tenant "/catalog/published-digests.cue")
            sb      (StringBuilder.)]
        (.append sb "@experiment(aliasv2,explicitopen,try)\n\n")
        (.append sb "// published-digests.cue -- managed by helm-bump.\n")
        (.append sb "// Records the build_digest at time of last version bump per app per cluster.\n")
        (.append sb "// DO NOT EDIT manually. Run: mise run helm-bump\n")
        (.append sb "package catalog\n\n")
        (doseq [[app-name cluster-map] (sort-by key apps)]
          (doseq [[cluster-name digest] (sort-by key cluster-map)]
            (.append sb (str "chart_versions: \"" app-name "\": cluster_digests: \""
                             cluster-name "\": published_digest: \"" digest "\"\n"))))
        (spit overlay (str sb))
        (sh!!? "mise" "x" "cue" "--" "cue" "fmt" overlay)))))


(let [filter-app    (first *command-line-args*)
      ;; Lattice-backed catalog reads via kernel-lib helpers (AIDR-00109).
      versions      (chart-versions)
      ;; Collect all published digests (existing + updated)
      all-published (atom {})
      bumped        (atom 0)]

  ;; Initialize all-published from current state
  (doseq [[app-key app] versions]
    (let [app-name (name app-key)]
      (doseq [[ck cv] (:cluster_digests app)]
        (let [cn (name ck)]
          (swap! all-published assoc-in [app-name cn]
                 (:published_digest cv))))))

  (doseq [[app-key app] (sort-by key versions)]
    (let [app-name         (name app-key)
          cluster-digests  (:cluster_digests app)]

      (when (or (nil? filter-app) (= filter-app app-name))
        (if (nil? cluster-digests)
          (log-err (str app-name ": missing cluster_digests -- run `mise run gen` first"))

          ;; Check each cluster's digest, bump that cluster's version
          ;; independently when it differs.
          (doseq [[ck cv] (sort-by key cluster-digests)]
            (let [cn               (name ck)
                  version          (:version cv)
                  build-digest     (:build_digest cv)
                  published-digest (:published_digest cv)]
              (cond
                (str/blank? build-digest)
                (log-err (str app-name " (" cn "): no build_digest -- run `mise run gen` first"))

                (str/blank? version)
                (log-err (str app-name " (" cn "): no version -- check catalog/catalog.cue"))

                (= build-digest published-digest)
                nil ; up to date, silent

                :else
                (let [new-version (bump-patch version)
                      tenant      (cluster-tenant cn)]
                  (cond
                    (nil? tenant)
                    (log-err (str app-name " (" cn "): no owning tenant in k3d_clusters lattice"))

                    :else
                    (do
                      (log-ok (str app-name " (" cn "): content changed, bumping v" version
                                   " -> v" new-version))
                      (update-cluster-version! tenant app-name cn new-version)
                      (swap! all-published assoc-in [app-name cn] build-digest)
                      (swap! bumped inc)))))))))))

  ;; Write all published digests
  (write-published-digests! @all-published)

  (println)
  (if (pos? @bumped)
    (do
      (log-ok (str "bumped " @bumped " (app, cluster) version(s). Run `mise run gen` to rebuild at new versions."))
      (log-ok "then run `mise run helm-publish` to push to registry."))
    (log-ok "all charts up to date -- no bumps needed.")))
