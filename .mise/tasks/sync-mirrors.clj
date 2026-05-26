#!/usr/bin/env bbs
#MISE description= "Sync upstream container images to local OCI registry mirrors"
#MISE depends= ["aws-ecr-login"]


;; Syncs all upstream container images listed in the mirror catalog
;; (catalog/mirrors.cue) to the local OCI registry under the mirror/ prefix.
;;
;; The catalog is the single source of truth for which images need mirroring.
;;
;; Uses crane for all OCI operations. Multi-arch images are filtered to
;; linux/amd64 and linux/arm64 only via `crane index filter`, avoiding
;; rate limits from registries like ECR public that throttle when all
;; platforms (8+) are copied.
;;
;; Usage:
;;   mise run sync-mirrors              # sync all
;;   mise run sync-mirrors --dry-run    # show what would be synced

(require '[defn :refer :all])


(def mirror-registry "localhost:5000")


;; Platforms to mirror. Only these are kept from multi-arch manifest indexes.
(def mirror-platforms ["linux/amd64" "linux/arm64"])


;; ---------------------------------------------------------------------------
;; CLI args
;; ---------------------------------------------------------------------------

(def dry-run? (some #(= % "--dry-run") *command-line-args*))


;; ---------------------------------------------------------------------------
;; Image helpers
;; ---------------------------------------------------------------------------

(defn upstream-ref
  "Build the upstream pull reference from a catalog entry.
   When the catalog has a pinned digest, uses source@digest to guarantee
   we pull exactly what the catalog locked."
  [entry]
  (let [source (:source entry)
        tag    (:tag entry)
        digest (:digest entry)]
    (cond
      (and digest (not (str/blank? digest))) (str source "@" digest)
      (and tag (not (str/blank? tag)))       (str source ":" tag)
      :else                                  source)))


(defn display-ref
  "Human-readable image reference showing tag@digest when both are present."
  [entry]
  (let [source (:source entry)
        tag    (:tag entry)
        digest (:digest entry)]
    (cond
      (and (not (str/blank? tag)) (not (str/blank? digest)))
      (str source ":" tag "@" (subs digest 0 (min 19 (count digest))) "...")
      (not (str/blank? digest)) (str source "@" digest)
      (not (str/blank? tag))    (str source ":" tag)
      :else                     source)))


(defn mirror-ref
  "Local mirror reference for pushing: registry/mirror/source:tag."
  [entry]
  (let [source (:source entry)
        tag    (:tag entry)]
    (if (not (str/blank? tag))
      (str mirror-registry "/mirror/" source ":" tag)
      (str mirror-registry "/mirror/" source))))


(defn mirror-up-to-date?
  "Check if the local mirror has the image."
  [entry]
  (let [dst (mirror-ref entry)]
    (sh? "crane" "manifest" "--insecure" dst)))


(defn resolve-digest
  "Resolve the digest of an image in the local mirror registry."
  [entry]
  (let [dst    (mirror-ref entry)
        result (sh-result "crane" "digest" "--insecure" dst)]
    (when (zero? (:exit result))
      (:out result))))


(defn pin-empty-digests!
  "Resolve and write back digests for catalog entries that have empty digests.
   Updates catalog/mirrors.cue in place."
  [entries]
  (let [empty-entries (filter #(str/blank? (:digest %)) entries)]
    (when (seq empty-entries)
      (let [mirrors-path "catalog/mirrors.cue"
            content      (atom (slurp mirrors-path))
            pinned       (atom 0)]
        (doseq [entry empty-entries]
          (let [digest (resolve-digest entry)]
            (if digest
              (let [tag (:tag entry)
                    ;; Match: tag: "TAG"\n    digest: ""
                    pattern (re-pattern
                              (str "(?m)(tag:\\s+\""
                                   (java.util.regex.Pattern/quote tag)
                                   "\"\\s*\n\\s*digest:\\s+)\"\""))
                    replacement (str "$1\"" digest "\"")]
                (swap! content str/replace pattern replacement)
                (swap! pinned inc)
                (log-ok (str "[pin]  " (:source entry) ":" tag " -> "
                             (subs digest 0 (min 19 (count digest))) "...")))
              (log-err (str "[pin]  " (:source entry) ":" (:tag entry)
                            " -- failed to resolve digest")))))
        (when (pos? @pinned)
          (spit mirrors-path @content)
          (log-ok (str "pinned " @pinned " digest(s) in " mirrors-path)))))))


(defn is-multi-arch?
  "Check if upstream manifest is a multi-arch index.
   Accepts a tag-based reference (source:tag) to avoid digest-rotation failures."
  [tag-src]
  (let [result (sh-result "crane" "manifest" tag-src)]
    (when (zero? (:exit result))
      (let [parsed (parse-json (:out result) true)]
        (contains? parsed :manifests)))))


(defn- run-crane!
  "Run a crane command, return :synced on success or surface stderr
  and return :failed. crane writes progress and errors to stderr;
  silently swallowing it (the previous behavior) made transient ECR
  rate-limits look like permanent failures."
  [args entry success-msg]
  (let [r (apply sh-result args)]
    (if (zero? (:exit r))
      (do (log-ok success-msg)
          :synced)
      (do (log-err (str "[FAIL] " (display-ref entry)))
          (when-not (str/blank? (:err r))
            (doseq [line (str/split-lines (:err r))]
              (println (str "       " line))))
          :failed))))


(defn sync-image!
  "Sync a single catalog entry to the local mirror.
   For multi-arch images, uses crane index filter to copy only desired platforms.
   For single-arch, copies directly."
  [entry]
  (let [src (upstream-ref entry)
        ;; Tag-based ref for crane index filter: some registries (ECR) reject
        ;; pulling index manifests by digest, so use source:tag for multi-arch.
        tag-src (let [s (:source entry) t (:tag entry)]
                  (if (not (str/blank? t)) (str s ":" t) s))
        dst (mirror-ref entry)]
    (if (is-multi-arch? tag-src)
      ;; Multi-arch: filter to desired platforms (use tag ref for ECR compat)
      (let [platform-args (mapcat (fn [p] ["--platform" p]) mirror-platforms)
            args          (concat ["crane" "index" "filter" "--insecure"
                                   tag-src "-t" dst]
                                  platform-args)]
        (run-crane! args entry
                    (str "[ok]   " dst " (" (count mirror-platforms) " platforms)")))
      ;; Single-arch: simple copy
      (run-crane! ["crane" "copy" "--insecure" src dst]
                  entry
                  (str "[ok]   " dst)))))


;; ---------------------------------------------------------------------------
;; Main
;; ---------------------------------------------------------------------------

(log-ok "loading mirror image catalog...")


(let [catalog-json (run-tool-quiet "cue" "export" "-e" "mirror_images"
                                   "--out" "json" "./kernel/catalog")
      catalog      (parse-json catalog-json true)
      entries      (->> (vals catalog)
                        (sort-by :source)
                        vec)]

  (log-ok (str "catalog has " (count entries) " entries"))
  (log-ok (str "platforms: " (str/join ", " mirror-platforms)))
  (println)

  (if (empty? entries)
    (log-ok "catalog is empty, nothing to do")
    (do
      ;; Display the plan
      (println "Images to sync:")
      (doseq [entry entries]
        (println (str "  " (display-ref entry))))
      (println)

      (if dry-run?
        (log-ok (str "[dry-run] would check/sync " (count entries) " images"))

        (let [results (atom {:synced 0 :skipped 0 :failed 0 :failed-entries []})]
          (doseq [entry entries]
            (let [img-display (display-ref entry)]
              (if (mirror-up-to-date? entry)
                (do (log-ok (str "[skip] " img-display " (already mirrored)"))
                    (swap! results update :skipped inc))
                (do (log-ok (str "[sync] " img-display))
                    (let [result (sync-image! entry)]
                      (swap! results update result inc)
                      (when (= result :failed)
                        (swap! results update :failed-entries conj entry)))))))

          ;; Pin digests for any entries that have empty digests
          (println)
          (pin-empty-digests! entries)

          (println)
          (println "=== Sync Summary ===")
          (println (str "  Synced:  " (:synced @results)))
          (println (str "  Skipped: " (:skipped @results) " (already mirrored)"))
          (println (str "  Failed:  " (:failed @results)))
          (println (str "  Total:   " (count entries)))

          (when (pos? (:failed @results))
            (println)
            (println "Failed images:")
            (doseq [entry (:failed-entries @results)]
              (println (str "  " (display-ref entry))))
            (println)
            (println "Re-run 'mise run sync-mirrors' to retry; failures are")
            (println "often transient (registry rate-limit / network blip).")
            (exit 1)))))))
