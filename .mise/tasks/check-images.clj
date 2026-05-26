#!/usr/bin/env bbs
#MISE description= "Detect container images not mirrored or rewritten"


;; Scans all rendered app manifests (gen-app.cue) for container image
;; references and compares against the mirror catalog (mirrors.cue).
;;
;; The catalog is keyed by source:tag, so each image+version is a
;; separate entry. This supports multiple versions of the same image
;; across different apps.
;;
;; Reports:
;;   - Images in rendered manifests that have no catalog entry
;;   - Catalog entries with empty digests (need sync-mirrors)
;;
;; Usage:
;;   mise run check-images              # check all apps
;;   mise run check-images argocd       # check specific app


(require '[defn :refer :all])


;; ---------------------------------------------------------------------------
;; Image extraction
;; ---------------------------------------------------------------------------

(defn extract-manifest-images
  "Extract all image references from a rendered gen-app.cue file.
   Returns seq of {:image :rewritten?} maps where :image is the canonical
   upstream ref (mirror prefix stripped) and :rewritten? indicates if the
   image was served from the local mirror."
  [path]
  (when (fs/exists? path)
    (->> (str/split-lines (slurp (str path)))
         (keep #(second (re-find #"image:\s+\"([^\"]+)\"" %)))
         (map (fn [img]
                (let [rewritten? (str/starts-with? img "host.k3d.internal:5000/mirror/")
                      canonical  (str/replace img #"^host\.k3d\.internal:5000/mirror/" "")]
                  {:image canonical :rewritten? rewritten?})))
         vec)))


(defn parse-image-ref
  "Split an image reference into {:source :tag :digest}.
   Handles name:tag, name@sha256:..., name:tag@sha256:..., and bare name."
  [ref]
  (let [[base digest] (str/split ref #"@" 2)
        [source tag]  (let [parts (str/split base #":" 2)]
                        (if (and (second parts)
                                 (not (str/starts-with? (second parts) "/")))
                          parts
                          [base nil]))]
    {:source source
     :tag    (or tag "latest")
     :digest digest}))


;; ---------------------------------------------------------------------------
;; Main
;; ---------------------------------------------------------------------------

(let [filter-app (first *command-line-args*)

      ;; Load mirror catalog (keyed by source:tag)
      mirror-json    (run-tool-quiet "cue" "export" "-e" "mirror_images"
                                     "--out" "json" "./kernel/catalog")
      mirror-catalog (parse-json mirror-json true)

      ;; Load app catalog to get app paths
      apps-json   (run-tool-quiet "cue" "export" "-e" "apps" "--out" "json"
                                  "./kernel/catalog")
      apps        (parse-json apps-json true)

      ;; Collect all images from rendered manifests
      not-mirrored (atom [])
      all-images   (atom #{})]

  (doseq [[app-key app-info] (sort-by key apps)]
    (let [app-name (name app-key)
          app-path (get app-info :path)]
      (when (and app-path
                 (or (nil? filter-app) (= filter-app app-name)))
        (let [gen-app (str app-path "/gen-app.cue")
              entries (extract-manifest-images gen-app)]
          (when (seq entries)
            (swap! all-images into (map :image entries))
            (doseq [{:keys [image]} entries]
              (let [{:keys [source tag]} (parse-image-ref image)
                    catalog-key (keyword (str source ":" tag))]
                (when-not (get mirror-catalog catalog-key)
                  (swap! not-mirrored conj
                         {:app app-name :image image
                          :source source :tag tag})))))))))

  ;; Report
  (log-ok (str (count @all-images) " unique images across rendered manifests"))
  (println)

  ;; Check for empty digests in the mirror catalog
  (let [empty-digests (->> mirror-catalog
                           (filter (fn [[_k entry]]
                                     (or (nil? (:digest entry))
                                         (str/blank? (:digest entry)))))
                           (map (fn [[_k entry]]
                                  (str (:source entry) ":" (:tag entry))))
                           sort)]
    (when (seq empty-digests)
      (println (str "Mirror catalog MISSING DIGESTS (" (count empty-digests) "):"))
      (println)
      (doseq [ref empty-digests]
        (println (str "  " ref)))
      (println)
      (println "Fix: run `mise run sync-mirrors` to resolve and pin digests")
      (exit 1)))

  ;; Check for unmirrored images
  (if (empty? @not-mirrored)
    (log-ok "all images are in the mirror catalog")
    (do
      (println (str "Images NOT in mirror catalog (" (count @not-mirrored) "):"))
      (println)
      (doseq [[source entries] (->> @not-mirrored
                                    (group-by :source)
                                    (sort-by key))]
        (let [tags (sort (set (map :tag entries)))
              apps (sort (set (map :app entries)))]
          (doseq [t tags]
            (println (str "  " source ":" t))
            (println (str "    apps: " (str/join ", " apps))))))
      (println)
      (println "Fix:")
      (println "  1. Add entries to catalog/mirrors.cue (keyed by source:tag)")
      (println "  2. Run `mise run sync-mirrors`")
      (println "  3. Add kustomize image rewrites in the app's kustomization.yaml")
      (exit 1)))

  (log-ok "no image drift detected"))
