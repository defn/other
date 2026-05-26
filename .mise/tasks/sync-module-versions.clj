#!/usr/bin/env bbs
#MISE description= "Sync tool versions to match what Bazel modules support"


;; sync-module-versions -- query Bazel module repos for the latest tool
;; versions they support, then update versions.cue to match.
;;
;; Checks twelve constrained relationships:
;;   uv        ← rules_uv (exact bundled version from uv.lock.json)
;;   python    ← rules_python (latest in TOOL_VERSIONS from versions.bzl)
;;   node      ← rules_nodejs (latest LTS with linux_arm64 from node_versions.bzl)
;;   crane     ← rules_oci (latest version key in CRANE_VERSIONS from versions.bzl)
;;   regctl    ← rules_oci (latest version key in REGCTL_VERSIONS from versions.bzl)
;;   java      ← rules_java (latest JDK version from repositories.bzl URL patterns)
;;   helm      ← helm/helm releases (latest GA, any major)
;;   kustomize ← kubernetes-sigs/kustomize releases (latest kustomize/vX.Y.Z tag)
;;   k3s       ← k3s v1.{minor} channel (minor from versions.cue, latest patch)
;;   kubectl   ← k3s (kubectl version matches k3s k8s version)
;;   k3s_b     ← k3s v1.{minor-1} channel (latest patch for n-1 minor)
;;   k3s_c     ← k3s v1.{minor-2} channel (latest patch for n-2 minor)
;;
;; Output is structured for both human and agent consumption.


(require '[defn :refer :all])


;; ---------------------------------------------------------------------------
;; Version helpers
;; ---------------------------------------------------------------------------

(defn parse-semver
  "Parse a version string into a vector of integers for comparison."
  [v]
  (mapv parse-long (str/split v #"\.")))


(defn semver-compare
  "Compare two version strings as semver. Returns negative, zero, or positive."
  [a b]
  (compare (parse-semver a) (parse-semver b)))


(defn latest-version
  "Return the latest version from a collection, by semver."
  [versions]
  (last (sort semver-compare versions)))


(defn even-major?
  "True if the version has an even major number (LTS for Node.js)."
  [v]
  (zero? (mod (first (parse-semver v)) 2)))


;; ---------------------------------------------------------------------------
;; Fetch helpers
;; ---------------------------------------------------------------------------

(defn fetch-url
  "Fetch a URL, returning {:ok body} or {:err message}."
  [url]
  (try
    {:ok (slurp url)}
    (catch Exception e
      {:err (str "fetch failed: " (.getMessage e))})))


(defn github-raw
  "Build a raw.githubusercontent.com URL."
  [org repo tag path]
  (str "https://raw.githubusercontent.com/" org "/" repo "/" tag "/" path))


;; ---------------------------------------------------------------------------
;; rules_uv: exact bundled uv version from uv.lock.json
;; ---------------------------------------------------------------------------

(defn detect-uv-version
  "Extract the bundled uv version from rules_uv's uv.lock.json."
  [rules-uv-version]
  (let [url (github-raw "theoremlp" "rules_uv"
                        (str "v" rules-uv-version)
                        "uv/private/uv.lock.json")
        result (fetch-url url)]
    (if-let [body (:ok result)]
      (let [data (parse-json body)
            urls (map #(get % "url")
                      (get-in data ["uv" "binaries"]))]
        (if-let [first-url (first urls)]
          ;; URL pattern: .../download/0.8.12/uv-aarch64-...
          (if-let [m (re-find #"/download/([^/]+)/" first-url)]
            {:ok (second m)}
            {:err "cannot-be-determined: uv version not found in download URL"})
          {:err "cannot-be-determined: no binaries in uv.lock.json"}))
      {:err (str "cannot-be-determined: " (:err result))})))


;; ---------------------------------------------------------------------------
;; rules_python: latest python version from TOOL_VERSIONS in versions.bzl
;; ---------------------------------------------------------------------------

(defn detect-python-version
  "Extract the latest Python version supported by rules_python.
   Uses MINOR_MAPPING to find the recommended patch version for each minor,
   then returns the latest."
  [rules-python-version]
  (let [url (github-raw "bazelbuild" "rules_python"
                        rules-python-version
                        "python/versions.bzl")
        result (fetch-url url)]
    (if-let [body (:ok result)]
      ;; Parse MINOR_MAPPING for the recommended versions
      (if-let [mapping-match (re-find #"MINOR_MAPPING\s*=\s*\{([^}]+)\}" body)]
        (let [mapping-body (second mapping-match)
              pairs (re-seq #"\"(\d+\.\d+)\":\s*\"(\d+\.\d+\.\d+)\"" mapping-body)
              stable-versions (->> pairs
                                   (map #(nth % 2))
                                   ;; Filter out pre-release (alpha, beta, rc)
                                   (filter #(re-matches #"\d+\.\d+\.\d+" %)))]
          (if (seq stable-versions)
            {:ok (latest-version stable-versions)}
            ;; Fallback: parse TOOL_VERSIONS keys directly
            (let [all-versions (->> (re-seq #"\"(\d+\.\d+\.\d+)\":\s*\{" body)
                                    (map second)
                                    distinct)]
              (if (seq all-versions)
                {:ok (latest-version all-versions)}
                {:err "cannot-be-determined: no versions found in versions.bzl"}))))
        ;; No MINOR_MAPPING, try TOOL_VERSIONS directly
        (let [all-versions (->> (re-seq #"\"(\d+\.\d+\.\d+)\":\s*\{" body)
                                (map second)
                                distinct)]
          (if (seq all-versions)
            {:ok (latest-version all-versions)}
            {:err "cannot-be-determined: no versions found in versions.bzl"})))
      {:err (str "cannot-be-determined: " (:err result))})))


;; ---------------------------------------------------------------------------
;; rules_nodejs: latest LTS node version with linux_arm64 support
;; ---------------------------------------------------------------------------

(defn detect-node-version
  "Extract the latest LTS (even-major) Node.js version with linux_arm64
   support from rules_nodejs."
  [rules-nodejs-version]
  (let [url (github-raw "bazelbuild" "rules_nodejs"
                        (str "v" rules-nodejs-version)
                        "nodejs/private/node_versions.bzl")
        result (fetch-url url)]
    (if-let [body (:ok result)]
      (let [arm64-versions (->> (re-seq #"\"(\d+\.\d+\.\d+)-linux_arm64\"" body)
                                (map second)
                                distinct
                                (filter even-major?))]
        (if (seq arm64-versions)
          {:ok (latest-version arm64-versions)}
          {:err "cannot-be-determined: no LTS versions with linux_arm64 in node_versions.bzl"}))
      {:err (str "cannot-be-determined: " (:err result))})))


;; ---------------------------------------------------------------------------
;; rules_oci: crane and regctl versions from versions.bzl
;; ---------------------------------------------------------------------------

(defn detect-oci-tool-version
  "Extract the latest version of a tool (crane or regctl) from rules_oci's
   oci/private/versions.bzl. dict-name is 'CRANE_VERSIONS' or 'REGCTL_VERSIONS'.
   Returns version with v prefix (e.g. 'v0.18.0')."
  [rules-oci-version dict-name]
  (let [url (github-raw "bazel-contrib" "rules_oci"
                        (str "v" rules-oci-version)
                        "oci/private/versions.bzl")
        result (fetch-url url)]
    (if-let [body (:ok result)]
      ;; Match the dict and its content up to the closing } at column 0
      (let [dict-re (re-pattern
                      (str "(?s)"
                           (java.util.regex.Pattern/quote dict-name)
                           "\\s*=\\s*\\{(.*?)\\n\\}"))
            dict-match (re-find dict-re body)]
        (if dict-match
          (let [dict-body (second dict-match)
                versions (->> (re-seq #"\"(v\d+\.\d+\.\d+)\":" dict-body)
                              (map second)
                              distinct)
                ;; Sort by semver (strip "v" for numeric comparison)
                latest (->> versions
                            (sort-by #(parse-semver (subs % 1)))
                            last)]
            (if latest
              {:ok latest}
              {:err (str "cannot-be-determined: no versions found in " dict-name)}))
          {:err (str "cannot-be-determined: " dict-name " not found in versions.bzl")}))
      {:err (str "cannot-be-determined: " (:err result))})))


(defn detect-crane-version
  "Extract the latest crane version supported by rules_oci."
  [rules-oci-version]
  (detect-oci-tool-version rules-oci-version "CRANE_VERSIONS"))


(defn detect-regctl-version
  "Extract the latest regctl version supported by rules_oci."
  [rules-oci-version]
  (detect-oci-tool-version rules-oci-version "REGCTL_VERSIONS"))


;; ---------------------------------------------------------------------------
;; rules_java: latest JDK version from repositories.bzl
;; ---------------------------------------------------------------------------

(defn detect-java-version
  "Extract the latest JDK version from rules_java's repositories.bzl.
   Returns the version as 'graalvm-community-X.Y.Z' to match mise format.
   Parses JDK version from Zulu download URL patterns like:
   zulu25.32.17-ca-jdk25.0.2-linux_x64.tar.gz"
  [rules-java-version]
  (let [url (github-raw "bazelbuild" "rules_java"
                        rules-java-version
                        "java/repositories.bzl")
        result (fetch-url url)]
    (if-let [body (:ok result)]
      (let [versions (->> (re-seq #"-jdk(\d+\.\d+\.\d+)-" body)
                          (map second)
                          distinct)]
        (if (seq versions)
          {:ok (str "graalvm-community-" (latest-version versions))}
          {:err "cannot-be-determined: no JDK versions found in repositories.bzl"}))
      {:err (str "cannot-be-determined: " (:err result))})))


;; ---------------------------------------------------------------------------
;; Helm + kustomize: track upstream releases directly.
;;
;; History: these used to derive from ArgoCD's hack/tool-versions.sh because
;; argocd-server embedded helm/kustomize binaries to render charts. Since the
;; platform no longer relies on argocd-server for rendering (2026-04-20), the
;; version pin has been decoupled from argocd -- we track latest upstream.
;; ---------------------------------------------------------------------------

(defn detect-helm-version
  "Latest helm release from helm/helm GitHub releases. Strips the leading v."
  [_]
  (let [result (fetch-url "https://api.github.com/repos/helm/helm/releases/latest")]
    (if-let [body (:ok result)]
      (if-let [m (re-find #"\"tag_name\"\s*:\s*\"v(\d+\.\d+\.\d+)\"" body)]
        {:ok (second m)}
        {:err "cannot-be-determined: tag_name not found in helm/helm latest release"})
      {:err (str "cannot-be-determined: " (:err result))})))


(defn detect-kustomize-version
  "Latest kustomize release from kubernetes-sigs/kustomize.
   Tags are of the form kustomize/vX.Y.Z; filter to kustomize-prefixed and
   pick the highest semver."
  [_]
  (let [result (fetch-url "https://api.github.com/repos/kubernetes-sigs/kustomize/releases?per_page=30")]
    (if-let [body (:ok result)]
      (let [tags (re-seq #"\"tag_name\"\s*:\s*\"kustomize/v(\d+\.\d+\.\d+)\"" body)
            versions (map second tags)]
        (if (seq versions)
          {:ok (latest-version versions)}
          {:err "cannot-be-determined: no kustomize/vX.Y.Z tags found"}))
      {:err (str "cannot-be-determined: " (:err result))})))


(defn detect-kubectl-version
  "Detect the kubectl version from the k3s stable channel.
   Queries https://update.k3s.io/v1-release/channels/stable and extracts
   the k8s version (stripping the +k3s suffix)."
  [k3s-version]
  ;; kubectl version matches k3s version directly (both are k8s semver)
  {:ok k3s-version})


(defn detect-k3s-version
  "Query the k3s release channel for the latest patch in the current minor family.
   The minor family is determined by the k3s version in versions.cue (e.g. 1.35),
   not the upstream stable channel (which may lag behind).
   Queries https://update.k3s.io/v1-release/channels/v1.{minor}."
  [current-minor]
  (let [url    (str "https://update.k3s.io/v1-release/channels/v1." current-minor)
        result (fetch-url url)]
    (if-let [body (:ok result)]
      (if-let [m (re-find #"v(\d+\.\d+\.\d+)" body)]
        {:ok (second m)}
        {:err (str "cannot-be-determined: no version found in k3s v1." current-minor " channel")})
      {:err (str "cannot-be-determined: " (:err result))})))


(defn k3s-minor
  "Extract the minor version number from a k3s version string."
  [version]
  (parse-long (second (re-find #"^\d+\.(\d+)\." version))))


(defn detect-k3s-prev-version
  "Find the latest patch release for a specific k3s minor version.
   Queries GitHub releases for k3s-io/k3s and filters to the target minor."
  [target-minor]
  (try
    (let [releases (sh! "gh" "api" "repos/k3s-io/k3s/releases"
                        "--jq" (str ".[] | select(.prerelease==false) | .tag_name"
                                    " | select(startswith(\"v1." target-minor ".\"))"))
          versions (->> (str/split-lines releases)
                        (filter #(not (str/blank? %)))
                        (map #(second (re-find #"v(\d+\.\d+\.\d+)" %)))
                        (filter some?))]
      (if (seq versions)
        {:ok (latest-version versions)}
        {:err (str "cannot-be-determined: no stable k3s 1." target-minor ".x releases found")}))
    (catch Exception e
      {:err (str "cannot-be-determined: " (.getMessage e))})))


;; ---------------------------------------------------------------------------
;; versions.cue patching
;; ---------------------------------------------------------------------------

(defn patch-cue-version
  "Replace the version string for a tool in versions.cue content.
   Matches:  \\ttool_name: #ToolVersion & {
                 version: \"old\"
   Replaces with the new version.
   Anchored with \\t to avoid matching e.g. rules_python when looking for python."
  [content tool-name new-version]
  (let [;; Handle both bare names and quoted names
        tool-pat (if (str/includes? tool-name "-")
                   (str "\"" (java.util.regex.Pattern/quote tool-name) "\"")
                   (java.util.regex.Pattern/quote tool-name))
        ;; Anchor to tab at start of line so "python" won't match "rules_python"
        pattern (re-pattern
                  (str "(\t" tool-pat ":\\s*#ToolVersion\\s*&\\s*\\{\\s*\n\\s*version:\\s*\")[^\"]*(\")"))
        replaced (str/replace content pattern (str "$1" new-version "$2"))]
    replaced))


(defn patch-cue-constraint
  "Update or add a constraint string for a tool in versions.cue content."
  [content tool-name new-constraint]
  (let [tool-pat (if (str/includes? tool-name "-")
                   (str "\"" (java.util.regex.Pattern/quote tool-name) "\"")
                   (java.util.regex.Pattern/quote tool-name))
        ;; Anchor to tab, match existing constraint line within the tool block
        pattern (re-pattern
                  (str "(\t" tool-pat ":\\s*#ToolVersion\\s*&\\s*\\{\\s*\n"
                       "\\s*version:\\s*\"[^\"]*\"\\s*\n"
                       "\\s*constraint:\\s*\")[^\"]*(\")"))
        replaced (str/replace content pattern (str "$1" new-constraint "$2"))]
    replaced))


;; ---------------------------------------------------------------------------
;; Frozen tools
;; ---------------------------------------------------------------------------

;; Tools deliberately held below their module-supported latest because the
;; latest is broken in our toolchain. Detection still runs (so the report
;; shows the gap), but the version in versions.cue is never patched -- the
;; pin in versions.cue wins. Delete an entry here once the upstream issue
;; is fixed, then re-run `mise run upgrade mise` to let it float again.
(def frozen-tools
  {"python" (str "mise 2026.3.9 mis-selects the freethreaded-stripped cpython "
                 "asset for 3.14.4 (install fails: missing lib/ dir); held at "
                 "3.14.2. See ~/TODO.md.")})


;; ---------------------------------------------------------------------------
;; Main
;; ---------------------------------------------------------------------------

(let [versions-json (run-tool-quiet "cue" "eval" "-e" "versions" "--out" "json"
                                    "./kernel/schema")
      versions      (parse-json versions-json)
      ver           (fn [k] (get-in versions [k "version"]))

      rules-uv-ver      (ver "rules_uv")
      rules-python-ver  (ver "rules_python")
      rules-nodejs-ver  (ver "rules_nodejs")
      rules-oci-ver     (ver "rules_oci")
      rules-java-ver    (ver "rules_java")
      k3s-ver           (ver "k3s")

      ;; Detect supported versions
      uv-result     (detect-uv-version rules-uv-ver)
      python-result (detect-python-version rules-python-ver)
      node-result   (detect-node-version rules-nodejs-ver)
      crane-result  (detect-crane-version rules-oci-ver)
      regctl-result (detect-regctl-version rules-oci-ver)
      java-result   (detect-java-version rules-java-ver)
      helm-result      (detect-helm-version nil)
      kustomize-result (detect-kustomize-version nil)
      ;; k3s family: the minor version in versions.cue is the anchor.
      ;; We query for the latest patch within that family and derive prev versions.
      k3s-primary-minor (k3s-minor k3s-ver)
      k3s-result       (detect-k3s-version k3s-primary-minor)
      kubectl-result   (detect-kubectl-version (or (:ok k3s-result) k3s-ver))
      k3s-prev1-result (detect-k3s-prev-version (dec k3s-primary-minor))
      k3s-prev2-result (detect-k3s-prev-version (- k3s-primary-minor 2))

      results {"uv"     {:module "rules_uv"
                         :module-version rules-uv-ver
                         :current (ver "uv")
                         :detected uv-result}
               "python" {:module "rules_python"
                         :module-version rules-python-ver
                         :current (ver "python")
                         :detected python-result}
               "node"   {:module "rules_nodejs"
                         :module-version rules-nodejs-ver
                         :current (ver "node")
                         :detected node-result}
               "crane"  {:module "rules_oci"
                         :module-version rules-oci-ver
                         :current (ver "crane")
                         :detected crane-result}
               "regctl" {:module "rules_oci"
                         :module-version rules-oci-ver
                         :current (ver "regctl")
                         :detected regctl-result}
               "java"   {:module "rules_java"
                         :module-version rules-java-ver
                         :current (ver "java")
                         :detected java-result}
               "helm"   {:module "helm/helm"
                         :module-version "latest"
                         :current (ver "helm")
                         :detected helm-result}
               "k3s"    {:module (str "k3s-v1." k3s-primary-minor "-channel")
                         :module-version k3s-ver
                         :current (ver "k3s")
                         :detected k3s-result}
               "kubectl" {:module "k3s"
                          :module-version k3s-ver
                          :current (ver "kubectl")
                          :detected kubectl-result}
               "k3s_b" {:module (str "k3s-v1." (dec k3s-primary-minor) "-channel")
                        :module-version (str "1." (dec k3s-primary-minor) ".x")
                        :current (ver "k3s_b")
                        :detected k3s-prev1-result}
               "k3s_c" {:module (str "k3s-v1." (- k3s-primary-minor 2) "-channel")
                        :module-version (str "1." (- k3s-primary-minor 2) ".x")
                        :current (ver "k3s_c")
                        :detected k3s-prev2-result}
               "kustomize" {:module "kubernetes-sigs/kustomize"
                            :module-version "latest"
                            :current (ver "kustomize")
                            :detected kustomize-result}}

      cue-path "kernel/schema/versions.cue"
      original (slurp cue-path)
      changed  (atom false)]

  ;; Print results
  (doseq [[tool {:keys [module module-version current detected]}]
          (sort-by key results)]
    (println (str "## " tool))
    (println (str "  module:   " module " " module-version))
    (println (str "  current:  " current))
    (if-let [v (:ok detected)]
      (do
        (println (str "  detected: " v))
        (cond
          (frozen-tools tool)
          (log-ok (str tool " FROZEN at " current " (would be " v "): " (frozen-tools tool)))

          (= v current)
          (log-ok (str tool " is in sync"))

          :else
          (println (str "  ACTION:   update " tool " from " current " to " v))))
      (println (str "  detected: " (:err detected))))
    (println))

  ;; Patch versions.cue
  (let [patched (reduce
                  (fn [content [tool {:keys [module module-version current detected]}]]
                    (if-let [v (:ok detected)]
                      (if (or (= v current) (frozen-tools tool))
                        content
                        (do
                          (reset! changed true)
                          (let [patched (patch-cue-version content tool v)]
                            ;; ArgoCD/k3s-constrained tools use CUE interpolation for constraints,
                            ;; so we only patch the version, not the constraint string.
                            (if (#{"helm" "kubectl" "kustomize" "k3s" "k3s_b" "k3s_c"} tool)
                              patched
                              (patch-cue-constraint patched tool
                                                    (case tool
                                                      "uv"     (str "pinned to match " module " " module-version " bundled version")
                                                      "python" (str "latest stable for " module " " module-version)
                                                      "node"   (str "LTS only (even-numbered); must be available in rules_nodejs for linux_arm64")
                                                      "crane"  (str "max version supported by " module " " module-version)
                                                      "regctl" (str "max version supported by " module " " module-version)
                                                      "java"   (str "max JDK version from " module " " module-version " (graalvm-community distribution)")))))))
                      content))
                  original
                  (sort-by key results))]

    (if @changed
      (do
        (spit cue-path patched)
        (sh! "chmod" "644" cue-path)
        (println "---")
        (log-ok "updated schema/versions.cue"))
      (do
        (println "---")
        (log-ok "all tool versions are in sync, no changes needed")))))
