#!/usr/bin/env bbs
#MISE description= "Pull external images via crane and load into local Docker"


;; Pulls external OCI images and loads them into the local Docker daemon
;; with defn.dev/external/* tags. OCI digests in kernel/catalog/catalog.cue
;; are verified against the upstream registry before pulling.
;;
;; Images are pulled for the host platform (linux/arm64 or linux/amd64).
;; docker load from a multi-platform tarball picks the first manifest
;; (usually amd64), so we pull platform-specific to get the right one.
;;
;; Why tags, not digests: the Docker daemon re-wraps OCI manifests into
;; Docker manifest format on load, producing a local digest UNRELATED to
;; the source OCI digest. We use defn.dev/external/* tags in Dockerfiles
;; and docker-compose.yml because the tags are meaningful and stable.
;; Provenance is enforced HERE -- the OCI digest in
;; kernel/catalog/catalog.cue is verified against the upstream registry
;; before each pull.
;;
;; Updating an external image:
;;   1. crane digest <source> (e.g. index.docker.io/library/ubuntu:noble)
;;   2. Update oci_images[<name>].digest in kernel/catalog/catalog.cue
;;   3. mise run dev-pull -- verifies the new digest and reloads
;;
;; Source list lives in kernel/catalog/catalog.cue under oci_images.
;;
;; Concurrency: per-image work (verify + pull + load + tag) is fanned
;; out across futures so re-runs (where each image is already cached
;; locally and crane just re-checks the digest) finish in roughly the
;; time of the slowest image instead of the sum. Output is buffered
;; per image and printed atomically on completion to keep the log
;; readable; catalog mutation (digest drift) is rare and runs under a
;; lock so concurrent slurp+spit can't race.

(require '[defn :refer :all]
         '[babashka.process :as p])


(def catalog-path "kernel/catalog/catalog.cue")
(def print-lock (Object.))
(def catalog-lock (Object.))


(defn- run-captured!
  "Run cmd, append captured stdout/stderr to buf, throw on non-zero."
  [^StringBuilder buf cmd]
  (let [r (apply p/shell {:out :string :err :string :continue true} cmd)]
    (when (seq (:out r)) (.append buf (:out r)))
    (when (seq (:err r)) (.append buf (:err r)))
    (when-not (zero? (:exit r))
      (throw (ex-info (str "command failed: " (str/join " " cmd))
                      {:cmd cmd :exit (:exit r)})))))


(defn- pull-one!
  "Verify + pull + load + tag a single image. Buffers all log output
  and emits it atomically under print-lock on completion."
  [crane platform [_ {:keys [name source digest tag]}]]
  (let [buf (StringBuilder.)
        log #(.append buf (str "✓ " % "\n"))]
    (try
      (log (str "verifying " name))
      (let [actual (str/trim (:out (p/shell {:out :string :err :string}
                                            crane "digest" source)))]
        (when-not (= actual digest)
          (log (str name " digest changed, updating " catalog-path))
          (.append buf (str "  old: " digest "\n"))
          (.append buf (str "  new: " actual "\n"))
          (locking catalog-lock
            (spit catalog-path
                  (str/replace (slurp catalog-path) digest actual)))))

      (log (str "pulling " name " (" source " " platform ")"))
      (let [tarball (str "/tmp/defn-pull-" name ".tar")]
        (run-captured! buf [crane "pull" "--format=tarball"
                            (str "--platform=" platform) source tarball])
        (run-captured! buf ["docker" "load" "-i" tarball])
        (run-captured! buf ["docker" "tag" source tag])
        (fs/delete tarball)
        (log (str "loaded " tag)))
      (finally
        (locking print-lock
          (print (.toString buf))
          (flush))))))


;; Narrow the expression to lattice.oci_images: evaluating the full
;; lattice with -c (concrete) fails because other branches like
;; chart_versions.cluster_digests carry unresolved string fields
;; that aren't relevant here.
(let [images-json (run-tool-quiet "cue" "eval" "-c" "-e" "lattice.oci_images"
                                  "--out" "json" "./kernel/spec:spec")
      images      (parse-json images-json true)
      crane        (mise-bin "ubi:google/go-containerregistry@v0.21.1" "crane")
      arch         (str/trim (sh! "uname" "-m"))
      platform     (str "linux/" (case arch
                                   "x86_64"  "amd64"
                                   "aarch64" "arm64"
                                   "arm64"   "arm64"
                                   arch))
      sorted       (sort-by key images)]

  (log-ok (str (count images) " images to pull for " platform " (parallel)"))

  ;; Eager fan-out: all futures start immediately. Deref forces the
  ;; result and re-throws any exception from a worker so failure
  ;; isn't silently swallowed.
  (let [futs (mapv (fn [entry] (future (pull-one! crane platform entry))) sorted)]
    (doseq [f futs] @f))

  (log-ok "all external images pulled, verified, and loaded"))
