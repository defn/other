(ns defn
  "defn mono-namespace: shared utilities for babashka scripts.

   Usage:
     #!/usr/bin/env bbs
     (require '[defn :refer :all])
  "
  (:require
    [babashka.fs :as fs]
    [babashka.process :as p]
    [cheshire.core :as json]
    [clojure.set :as set]
    [clojure.string :as str]))


;; Shell helpers

(defn sh!
  "Run shell command, throw on non-zero exit, return trimmed stdout"
  [& args]
  (-> (apply p/shell {:out :string :err :string} args)
      p/check :out str/trim))


(defn sh!!
  "Run shell command with inherited IO (streams to terminal), throw on non-zero exit.
   First arg may be an opts map (merged with {:out :inherit :err :inherit})."
  [& args]
  (let [[opts cmd-args] (if (map? (first args))
                          [(first args) (rest args)]
                          [{} args])]
    (-> (apply p/shell (merge {:out :inherit :err :inherit} opts) cmd-args)
        p/check :exit)))


(defn sh?
  "Run shell command, return true if successful"
  [& args]
  (try (-> (apply p/shell {:out :string :err :string :continue true} args)
           :exit zero?)
       (catch Exception _ false)))


(defn sh!!?
  "Run shell command with opts, capture output, return {:exit :out :err}.
   First arg may be an opts map (merged with capture defaults).
   Does not throw on non-zero exit."
  [& args]
  (let [[opts cmd-args] (if (map? (first args))
                          [(first args) (rest args)]
                          [{} args])
        r (apply p/shell (merge {:out :string :err :string :continue true} opts) cmd-args)]
    {:exit (:exit r) :out (str (:out r)) :err (str (:err r))}))


(defn sh-result
  "Run shell command, return {:exit :out :err} without throwing"
  [& args]
  (let [r (apply p/shell {:out :string :err :string :continue true} args)]
    {:exit (:exit r) :out (str/trim (:out r)) :err (str/trim (:err r))}))


(defn sh-pipe!
  "Run shell command with string input on stdin, return trimmed stdout.
   Usage: (sh-pipe! input-string \"cmd\" \"arg1\" \"arg2\")"
  [input & args]
  (-> (apply p/shell {:in input :out :string :err :inherit} args)
      p/check :out))


(defn sh-bg
  "Start a background shell command with inherited IO. Returns a map with
   :proc (the java.lang.Process) and :deref (deref to wait for exit).
   Call (.destroy (:proc result)) to kill it."
  [opts & args]
  (let [proc (apply p/process (merge {:out :inherit :err :inherit} opts) args)]
    {:proc (:proc proc) :deref proc}))


(defn gh-token
  "Return a GitHub token: prefer the GITHUB_TOKEN env var, fall back to
   `gh auth token`. Throws if neither is available."
  []
  (or (some-> (System/getenv "GITHUB_TOKEN") str/trim not-empty)
      (str/trim (sh! "gh" "auth" "token"))))


(defn gh-logged-in?
  "Check if gh CLI has a *working* token for github.com -- validates
   against the GitHub API, not just keyring presence.

   Previous version (`gh auth token --hostname github.com`) only
   checked that a token ENTRY existed in the keyring. A revoked or
   expired token still satisfied that check, so `mise run login` would
   declare success while the next `git push` / `gh pr create` failed
   with Bad credentials.

   `gh api user --silent` makes one cheap GET /user call; exit 0 only
   when the token authenticates. GH_HOST env var scopes the call to
   github.com in case the user has multiple hosts configured. Note:
   `gh auth status --hostname github.com` is NOT a reliable validator
   either -- on broken creds it prints X markers to stderr but still
   exits 0."
  []
  (zero? (:exit (sh!!? {:extra-env {"GH_HOST" "github.com"}}
                       "gh" "api" "user" "--silent"))))


(defn aws-sso-valid?
  "Check if the AWS SSO session can mint creds. With no args, uses the
   ambient AWS_PROFILE; with a profile, scopes the probe to it.
   sts get-caller-identity is the cheapest call that exercises the
   chained-SSO -> assume-role flow end to end."
  ([] (sh? "aws" "sts" "get-caller-identity"))
  ([profile] (sh? "aws" "--profile" profile "sts" "get-caller-identity")))


;; defn binary runner

(defonce ^:private defn-built? (atom false))


(defn- active-tenant
  "Read the active default_tenant from the lattice JSON shard,
  anchored to git-toplevel so the read works from any cwd (e.g. a
  nested cluster brick under tenant/defn/k3d/a/). Falls back to
  'defn' if the shard is absent (workspace pre-hatch). Validates
  the result against the default_tenant catalog regex; throws on a
  malformed shard so a corrupted lattice can't redirect defn-bin!
  to a foreign tenant. Per AIDR-00141 Stage 3.5d; hardened per
  AIDR-00144 code/security review (m-root anchor, JSON parse,
  regex assertion)."
  []
  (let [root  (str (sh! "git" "rev-parse" "--show-toplevel") "/m")
        shard (str root "/var/lattice/default_tenant.json")]
    (if-not (fs/exists? shard)
      "defn"
      (let [t (json/parse-string (slurp shard))]
        (when-not (and (string? t) (re-matches #"^[a-z_][a-z0-9_-]*$" t))
          (throw (ex-info "default_tenant.json: malformed contents"
                          {:value t :shard shard})))
        t))))


(defn defn-bin!
  "Build //tenant/<t>/go/cmd/<t>:<t> (once per script run, where t is
   the active default_tenant) and invoke its built binary with the
   given args. Throws on non-zero exit. If the bazel build fails --
   typical cause is a deps.cue change adding a new Go import that
   hasn't been stamped into the corresponding BUILD.bazel deps yet --
   fall back to `go run ./tenant/<t>/go/cmd/<t>` so the gen pipeline
   can regenerate BUILD.bazel + deps.

   This is the canonical way to invoke the namesake CLI from babashka
   tasks. Calling the bazel-bin path directly risks running a stale
   binary that predates recent generator/schema changes (a stale
   binary will overwrite the workspace with content the new schema
   rejects, breaking the next gen)."
  [& args]
  (let [tenant (active-tenant)
        target (str "//tenant/" tenant "/go/cmd/" tenant ":" tenant)
        binary (str "bazel-bin/tenant/" tenant "/go/cmd/" tenant "/" tenant "_/" tenant)
        srcdir (str "./tenant/" tenant "/go/cmd/" tenant)]
    (if @defn-built?
      (apply sh!! binary args)
      (let [r (sh!!? "bazel-runner" "build" target)
            info-lines (filter #(re-find #"INFO:" %) (str/split-lines (str (:err r))))]
        (doseq [line info-lines] (println line))
        (when (seq info-lines) (println))
        (if (zero? (:exit r))
          (do (reset! defn-built? true)
              (apply sh!! binary args))
          (do (println (str "WARN: bazel build " target " failed; "
                            "bootstrapping via `go run " srcdir "` to regenerate "
                            "BUILD.bazel + deps. The next invocation should "
                            "succeed via bazel."))
              (println (:err r))
              (apply sh!! "go" "run" srcdir args)))))))


;; Tool runners (via mise)

(defn mise-bin
  "Resolve the absolute path of a tool binary via mise.
   Usage: (mise-bin \"cue@0.16.0\" \"cue\") => \"/...mise/installs/cue/0.16.0/cue\"
   Uses `mise which` to handle tools with non-standard install layouts."
  [spec cmd]
  (let [env-key (str "MISE_" (-> spec (str/split #"@") first str/upper-case) "_VERSION")
        version (second (str/split spec #"@"))]
    (-> (p/shell {:out :string :err :string
                  :extra-env {env-key version}}
                 "mise" "which" cmd)
        p/check :out str/trim)))


(defn mise-x!
  "Run a tool via mise with explicit version spec and inherited IO.
   Uses mise-bin to resolve the absolute path, avoiding PATH conflicts.
   Usage: (mise-x! \"cue@0.16.0\" \"cue\" \"fmt\" file)"
  [spec & cmd-args]
  (let [bin (mise-bin spec (first cmd-args))]
    (-> (apply p/shell {:out :inherit :err :inherit} bin (rest cmd-args))
        p/check :exit)))


(defn mise-x-quiet
  "Run a tool via mise with explicit version spec, capture output.
   Uses mise-bin to resolve the absolute path, avoiding PATH conflicts."
  [spec & cmd-args]
  (let [bin (mise-bin spec (first cmd-args))]
    (-> (apply p/shell {:out :string :err :string} bin (rest cmd-args))
        p/check :out str/trim)))


(defn mise-x-quiet-in
  "Like mise-x-quiet but runs from cwd `dir`. Lets callers pin cue
   export against relative catalog paths (./kernel/catalog,
   ./tenant/<t>/catalog) from the workspace root regardless of
   where the script was invoked."
  [dir spec & cmd-args]
  (let [bin (mise-bin spec (first cmd-args))]
    (-> (apply p/shell {:out :string :err :string :dir dir} bin (rest cmd-args))
        p/check :out str/trim)))


(defn run-tool!
  "Run a CLI tool via mise with inherited IO"
  [cmd & args]
  (apply mise-x! cmd cmd args))


(defn run-tool-quiet
  "Run a CLI tool via mise, capture stdout and stderr"
  [cmd & args]
  (apply mise-x-quiet cmd cmd args))


(defn run-tool-quiet-in
  "Like run-tool-quiet but runs from cwd `dir`."
  [dir cmd & args]
  (apply mise-x-quiet-in dir cmd cmd args))


(defn bazel-query
  "Query bazel, return results as lines"
  [query]
  (-> (run-tool-quiet "bazelisk" "query" query) str/split-lines))


;; Filesystem (from babashka.fs)

(def copy-file fs/copy)
(def create-dirs fs/create-dirs)
(def create-temp-dir fs/create-temp-dir)
(def delete-tree fs/delete-tree)
(def exists? fs/exists?)
(def parent fs/parent)


;; JSON (from cheshire)

(def parse-json json/parse-string)
(def emit-json json/generate-string)


;; String / set re-exports

(def blank? str/blank?)
(def split-lines str/split-lines)
(def trim str/trim)
(def join-str str/join)
(def difference set/difference)


(defn lines
  [s]
  (str/split-lines s))


;; Manifest helpers

(defn label->path
  "Convert a Bazel label like //pkg:file to a workspace-relative path."
  [label]
  (when (str/starts-with? label "//")
    (let [no-slashes (subs label 2)
          [pkg file] (str/split no-slashes #":" 2)]
      (if (str/blank? pkg) file (str pkg "/" file)))))


(defn git-tracked-files
  "Return set of workspace-relative paths for all git-tracked files in m/."
  []
  (let [cdup  (sh! "git" "rev-parse" "--show-cdup")
        m-dir (str cdup "m")]
    (->> (sh! "git" "ls-files" m-dir)
         str/split-lines
         (map #(str/replace-first % (re-pattern (str "^" (java.util.regex.Pattern/quote (str m-dir "/")))) ""))
         (remove str/blank?)
         set)))


(defn bazel-source-files
  "Return set of workspace-relative paths for all Bazel source files."
  []
  (->> (bazel-query "kind(\"source file\", //...:*)")
       (keep label->path)
       set))


(defn bazel-fmt-covered-files
  "Return set of workspace-relative paths covered by fmt-tagged tests."
  []
  (->> (bazel-query "labels(data, attr(tags, \"\\bfmt\\b\", tests(//...)))")
       (keep label->path)
       set))


(defn bazel-tagged-files
  "Return set of workspace-relative paths for files with the given tag."
  [tag]
  (->> (bazel-query (format "labels(srcs, attr(tags, \"\\b%s\\b\", //...))" tag))
       (keep label->path)
       set))


;; CUE catalog query (direct, no caching -- Go gen handles catalog in-memory)

(defn catalog-query
  "Query the CUE catalog via `cue export -e <expr> --out json ./catalog`.
   Returns keyword-keyed maps."
  [expr]
  (parse-json
    (run-tool-quiet "cue" "export" "-e" expr "--out" "json" "./catalog")
    true))


;; Lattice shard readers
;;
;; The lattice (var/lattice/<name>.json) is the gen-resolved
;; view of the catalog across all tenants. Babashka tasks use it as
;; the canonical "read the catalog" substrate because cue export
;; against ./kernel/catalog alone misses tenant overlay data
;; (chart_versions, app_bricks, etc). See AIDR-00109.
;;
;; Reads are memoized per-process (the lattice is immutable for the
;; duration of a script run; gen rewrites it before any task runs).

(defonce ^:private lattice-cache (atom {}))


(defonce ^:private m-root-cache (atom nil))


(defn- m-root
  "Resolve the workspace root (`<git-toplevel>/m`) once per process.
   Lattice helpers anchor their reads here so a task invoked from a
   nested cluster brick (e.g. tenant/defn/k3d/a/) still finds the
   shards."
  []
  (or @m-root-cache
      (let [r (str (sh! "git" "rev-parse" "--show-toplevel") "/m")]
        (reset! m-root-cache r)
        r)))


(defn lattice-shard
  "Parse and return the gen-resolved lattice shard at
   <m-root>/var/lattice/<name>.json. Result is keyword-keyed
   and memoized for the process lifetime. Throws if the shard is
   missing (run `mise run gen` first)."
  [name]
  (or (get @lattice-cache name)
      (let [path (str (m-root) "/var/lattice/" name ".json")
            v    (parse-json (slurp path) true)]
        (swap! lattice-cache assoc name v)
        v)))


(defn apps
  "Return the gen-resolved apps map (name -> {kind, path, ...})."
  []
  (lattice-shard "apps"))


(defn chart-versions
  "Return the gen-resolved chart_versions map
   (app -> {cluster_digests: {cluster -> {version, build_digest, published_digest}}})."
  []
  (lattice-shard "chart_versions"))


(defn k3d-clusters
  "Return the gen-resolved k3d_clusters map (id -> {cluster_name, path, ...})."
  []
  (lattice-shard "k3d_clusters"))


(defn brick-path
  "Return the workspace-relative brick directory for an app name (e.g.
   \"argocd\" -> \"tenant/library/app/argocd\"). Nil if the app isn't
   in the lattice."
  [app-name]
  (:path (get (apps) (keyword app-name))))


(defn cluster-tenant
  "Return the owning tenant for a cluster name, parsed from its
   k3d_clusters[<id>].path = tenant/<owner>/k3d/<x>. Nil when the
   cluster is unknown or its path doesn't match the expected shape."
  [cluster-name]
  (let [match (->> (k3d-clusters)
                   vals
                   (filter #(= cluster-name (:cluster_name %)))
                   first)
        path  (:path match)
        parts (str/split (or path "") #"/")]
    (when (and (>= (count parts) 2) (= (first parts) "tenant"))
      (second parts))))


;; CUE template stamping

(defn stamp-from-cue!
  "Evaluate CUE template fields with tags, write files to dir.
   files: [{:field \"build_bazel\" :filename \"BUILD.bazel\"} ...]
   tags: {:name \"foo\"}"
  [template-path dir-path tags files]
  (fs/create-dirs dir-path)
  (let [tag-args (mapcat (fn [[k v]] ["-t" (str (name k) "=" v)]) tags)]
    (doseq [{:keys [field filename]} files]
      (let [content (apply run-tool-quiet "cue" "export"
                           "-e" field "--out" "text"
                           (concat tag-args [template-path]))]
        (spit (str dir-path "/" filename) (str content "\n"))
        (sh! "chmod" "644" (str dir-path "/" filename))))))


;; Auto-fix

(defn fix-fmt-from-testlogs
  "Scan bazel-testlogs for formatted files saved by fmt_check.clj and copy
   them back to the workspace. Returns the number of files fixed."
  [testlogs-dir]
  (let [dest-files (fs/glob testlogs-dir "**/test.outputs/DEST" {:follow-links true :hidden true})]
    (reduce (fn [n dest-file]
              (let [dest    (str/trim (slurp (str dest-file)))
                    outputs (fs/parent dest-file)
                    src     (first (remove #(= (str (fs/file-name %)) "DEST")
                                           (fs/list-dir outputs)))]
                (if src
                  (let [orig-mode (fs/posix-file-permissions dest)]
                    (copy-file (str src) dest {:replace-existing true})
                    (fs/set-posix-file-permissions dest orig-mode)
                    (println (str "  fixed: " dest))
                    (inc n))
                  n)))
            0 dest-files)))


;; Output

(defn log-ok
  [& msgs]
  (let [line (str "✓ " (str/join " " msgs) "\n")]
    (.write *out* line)
    (.flush *out*)))


(defn log-err
  [& msgs]
  (let [line (str "✗ " (str/join " " msgs) "\n")]
    (.write *err* line)
    (.flush *err*)))


(defn exit
  ([] (System/exit 0))
  ([code] (System/exit code)))
