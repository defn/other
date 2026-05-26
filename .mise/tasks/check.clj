#!/usr/bin/env bbs
#MISE description= "Full validation: gen, build, test, verify clean workspace"

(require '[defn :refer :all])
(require '[clojure.string :as str])
(require '[babashka.fs :as fs])


(def ignore-unclean? (some #{"--ignore-unclean-workarea"} *command-line-args*))


;; Opt-in fork-portability gate: when `--with-fork` is passed, run
;; `mise run check-fork` after the host pipeline so a single command
;; validates BOTH repos (host + the bootstrapped fork). Off by default
;; because the fork-side hatch + check is ~20 min wall-clock from a
;; cold cache; routine `mise run check` runs should stay fast. CI and
;; pre-kernel-substrate-change manual runs are the intended callers.
;; AIDR-00140 Tier 1 carry-forward.
(def with-fork? (some #{"--with-fork"} *command-line-args*))


;; macOS sentinel: /home/ubuntu must be a symlink to $HOME. The macos
;; task creates it (along with the loopback alias and other setup);
;; without it, .bazelrc's hard-coded /home/ubuntu paths resolve to
;; nonexistent targets and the build fails. Run the macos task on
;; demand when the sentinel isn't satisfied.
(when (str/includes? (System/getProperty "os.name") "Mac")
  (let [home   (System/getenv "HOME")
        marker "/home/ubuntu"
        ok?    (and (fs/exists? marker {:nofollow-links true})
                    (fs/sym-link? marker)
                    (= (str (fs/read-link marker)) home))]
    (when-not ok?
      (println "macos sentinel: /home/ubuntu is not a symlink to" home "-- running `mise run macos`")
      (sh!! "mise" "run" "macos"))))


;; Cert sentinel: gen-registry-cert is idempotent (no-op when leaf
;; cert is valid >30 days from expiry, regen otherwise). Running it
;; in check ensures the registry CA + leaf are auto-rotated on
;; routine `mise run check` runs, so a cert that would otherwise
;; expire silently never makes it past the daily workflow gate. If
;; rotation happens, the volume coherence sentinel in
;; ensure-registry-tls-certs-volume! catches the skew at next
;; dev-bootstrap and force-recreates the registry. AIDR-00127 #8.
(sh!! "mise" "run" "gen-registry-cert")


;; Mode normalization sentinel: tools that emit tracked files
;; (tofu local_file, openssl cert-gen, ad-hoc operator edits) can
;; default to umask-derived modes (0600/0700) that don't match the
;; brick manifest's _#reg=0644 expectation. Manifest validation
;; would catch the drift later but doesn't auto-fix; running
;; normalize-modes here turns "you have to chmod manually" into
;; "the daily workflow handles it." Idempotent. AIDR-00127 #7.
(sh!! "mise" "run" "normalize-modes")


;; zsh-safety lint: scans tracked .md shell-fenced code blocks for
;; zsh-unsafe metacharacter patterns (==, ===, unquoted !, glob
;; qualifiers). Operators commonly paste example commands into
;; their interactive shell; snippets that work in bash but error
;; in zsh are a confusing failure mode. AIDR-00127 #12;
;; rules in AIREF-00013.
(sh!! "mise" "run" "check-zsh-safety")


;; Contract <-> lattice coverage: every `<field>: _` binding in
;; any contract.cue must have a corresponding entry in
;; tenant/library/go/lib/gen/lattice/lattice.go's catalogFields list. A
;; missing entry causes `_|_` propagation in forks where the field
;; is absent, producing thousands of bogus orphans. AIDR-00139
;; observation 3. Static / millisecond-fast, so cheap to run early.
(sh!! "mise" "run" "check-contract-lattice-coverage")


(defn tlog-ok
  [msg]
  (println (str "\u2713 " msg)))


(defn tlog-err
  [msg]
  (binding [*out* *err*] (println (str "\u2717 " msg))))


(defn check-clean
  [phase]
  (let [clean? (and (sh? "git" "diff" "--exit-code")
                    (sh? "git" "diff" "--cached" "--exit-code"))]
    (when-not clean?
      (if ignore-unclean?
        (tlog-ok (str "workspace has uncommitted changes after " phase " (--ignore-unclean-workarea)"))
        (do (tlog-err (str "workspace has uncommitted changes after " phase))
            (println)
            (println (sh! "git" "status" "--short"))
            (println)
            (println (sh! "git" "diff"))
            (exit 1))))))


;; Snapshot mtimes AND content hashes of all git-tracked files before
;; gen runs so we can detect silent mtime-only touches -- files whose
;; mtime bumped but whose content did not change. These touches
;; invalidate Bazel's fast-path cache and cascade into extra work on
;; every subsequent build. See AIDR-00058 for the catalog of
;; techniques that prevent them.
;;
;; Using git index/diff here would be wrong: the gen pipeline stages
;; its own output via `git add -A`, so `git diff --quiet` always
;; returns clean post-gen regardless of whether real content changed.
;; We snapshot content hashes directly and compare pre/post for any
;; file whose mtime advanced.
(defn- tracked-files
  []
  (->> (:out (sh!!? "git" "ls-files"))
       str/split-lines
       (filter (complement str/blank?))
       (filter #(fs/exists? (fs/path %)))))


(defn- hash-files
  "Returns {file -> git-blob-sha} for the given files. Batches through
   `git hash-object --stdin-paths` so the whole walk is a single
   subprocess. Writes the path list to a tempfile to avoid the stdin
   streaming dance (babashka's p/shell :in closes the stream early
   for large inputs, which surfaces as a noisy warning)."
  [files]
  (if (empty? files)
    {}
    (let [tmp (fs/create-temp-file {:prefix "check-hashfiles-" :suffix ".txt"})]
      (try
        (spit (str tmp) (str (str/join "\n" files) "\n"))
        (let [result (sh!!? "sh" "-c"
                            (str "git hash-object --stdin-paths < " (str tmp)))
              hashes (str/split-lines (:out result))]
          (zipmap files hashes))
        (finally
          (fs/delete-if-exists tmp))))))


(defn- snapshot-state
  []
  (let [files (tracked-files)]
    {:mtimes (into {}
                   (for [f files]
                     [f (fs/file-time->millis (fs/last-modified-time (fs/path f)))]))
     :hashes (hash-files files)}))


(def state-before (snapshot-state))


;; Gen pipeline: generates, syncs, validates, builds, AND tests in one pass.
;; If tests fail (e.g. formatting), try auto-fix and re-run.
;;
;; Bazel build/test output is inherited (streams straight to the terminal)
;; rather than captured: with `test --test_summary=short_uncached` in
;; .bazelrc, only uncached results print, so noise filtering buys little.
(let [gen-result (sh!!? {:out :inherit :err :inherit} "mise" "run" "gen")]
  (when-not (zero? (:exit gen-result))
    ;; Gen failed -- might be a fmt_test failure. Try auto-fix.
    (let [fixed (fix-fmt-from-testlogs "bazel-testlogs")]
      (if (pos? fixed)
        (do
          (tlog-ok (format "auto-fixed %d file(s), re-running gen" fixed))
          (let [r2 (sh!!? {:out :inherit :err :inherit} "mise" "run" "gen")]
            (when-not (zero? (:exit r2))
              (tlog-err "gen failed after auto-fix!")
              (exit 1))))
        (do (tlog-err "gen failed!")
            (exit 1))))))


;; Mtime idempotence guard: any file whose mtime bumped during gen
;; MUST also have a content change. A silent mtime touch -- bumped
;; mtime, identical bytes -- means a generator somewhere wrote
;; unconditionally. Catch it here so it doesn't slip back in.
;;
;; Compare content hashes directly rather than git diff: gen stages
;; its own output, so a WT-vs-index diff is always clean after gen
;; regardless of real changes.
(let [state-after (snapshot-state)
      bumped      (for [[f t] (:mtimes state-after)
                        :let [prev (get (:mtimes state-before) f)]
                        :when (and prev (> t prev))]
                    f)
      silent      (for [f bumped
                        :let [h-before (get (:hashes state-before) f)
                              h-after  (get (:hashes state-after) f)]
                        :when (and h-before h-after (= h-before h-after))]
                    f)]
  (if (seq silent)
    (do
      (tlog-err (format "%d file(s) had mtime bumps without content changes:" (count silent)))
      (doseq [f (take 20 silent)] (println "   " f))
      (when (> (count silent) 20) (println (format "    ... and %d more" (- (count silent) 20))))
      (println "  This invalidates Bazel's mtime cache. Find the generator that")
      (println "  wrote unconditionally and switch it to a content-hash compare.")
      (println "  See AIDR-00058 for the catalog of techniques.")
      (exit 1))
    (tlog-ok (format "mtime guard: %d file(s) bumped, 0 silent touches" (count bumped)))))


;; Final: workspace must be clean
(let [status (sh! "git" "status" "--porcelain")]
  (cond
    (blank? status)
    (tlog-ok "all checks passed -- workspace is clean")

    ignore-unclean?
    (do (tlog-ok "all checks passed -- workspace is dirty (--ignore-unclean-workarea)")
        (println)
        (println status))

    :else
    (do (println)
        (tlog-err "workspace is dirty after check:")
        (println)
        (println status)
        (exit 1))))


;; Fork-portability gate (opt-in via --with-fork). Runs after the host
;; workspace is confirmed green; a fork-side failure here means kernel
;; substrate quietly assumed defn's tenant set or module name. Inherit
;; stdout/stderr so the fork's progress (~20 min) is visible live.
(when with-fork?
  (println)
  (println "running mise run check-fork (--with-fork)...")
  (let [r (sh!!? {:out :inherit :err :inherit} "mise" "run" "check-fork")]
    (when-not (zero? (:exit r))
      (tlog-err "check-fork failed")
      (exit 1))))
