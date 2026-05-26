#!/usr/bin/env bbs
#MISE description= "Bootstrap a throwaway fork from current HEAD into an isolated temp dir (outside m/, so it can't inherit defn's mise/bazel/git config) and run mise run check there -- fork-portability regression guard (AIDR-00139 Tier 1, AIDR-00148)"


;; Verify the kernel portability contract (AIDR-00138) end-to-end:
;;
;;   1. Make a fresh temp dir, git init the parent.
;;   2. `defn bootstrap --target=<tmpdir>/m` bundles + rewrites + commits.
;;   3. Pre-trust every mise.toml in the fork (necessary because the
;;      fork is a fresh untrusted workspace from mise's perspective).
;;   4. `mise run hatch` inside the fork regenerates seed outputs
;;      (notably kernel/spec/tenant-deps.bzl with the fork's actual
;;      tenant set). This is required before bazel can analyze
;;      kernel/spec/BUILD.bazel -- the upstream's tenant-deps.bzl
;;      bundled in step 2 references //tenant/defn/... which the
;;      fork doesn't have.
;;   5. `mise run check` inside the fork must pass all checks.
;;
;; This is the permanent regression guard described in AIDR-00139
;; Tier 1: any change in kernel/ that quietly assumes defn's tenant
;; set (catalog defaults, hardcoded paths, defn-specific assertions)
;; will be caught here because the fork has a different tenant set
;; and a different module name. Run before / after any kernel change.
;;
;; Scope notes:
;;   * The fork list is hardcoded to "other" with default modules; a
;;     future spec AIDR will introduce a `forks: [string]:` catalog
;;     field so adding probes is a catalog edit.
;;   * The fork runs from the deterministic-after-bootstrap state
;;     (no hatch outputs committed). Its first `mise run hatch`
;;     regenerates gen/lattice/manifest from the fork's actual
;;     tenant tree.
;;   * Teardown expunges the fork's bazel output base too, not just
;;     tmpdir. The base lives outside tmpdir (keyed by the fork path)
;;     so each run would otherwise orphan ~7 GB. See cleanup.


(require '[defn :refer :all])
(require '[clojure.string :as str])
(require '[babashka.fs :as fs])


;; The fork MUST land outside m/ (fs/create-temp-dir -> /var/folders/...).
;; This isolation is the test's validity, not a convenience (AIDR-00148):
;; a fork nested under m/ sits in defn's config-inheritance cone -- mise
;; walks up for config, bazel resolves the enclosing repo/.bazelrc/cache,
;; git sees the ancestry -- so it would borrow defn's setup and could pass
;; while a genuinely-lifted repo fails. The /var/folders temp dir has no
;; defn ancestor: a clean root. Never "optimize" this into a subdir of m/.
(def tmpdir
  (str (fs/create-temp-dir {:prefix "defn-check-fork-"})))


(def fork-target (str tmpdir "/m"))


;; The defn source commit this run bootstraps from. On a green check we tie
;; this SHA to the published defn/other state (the stable marker): defn@SHA
;; is portable, producing the fork tree we commit to defn/other.
(def source-sha
  (str/trim (:out (sh!!? {:out :string} "git" "rev-parse" "HEAD"))))


(defn utc-now
  []
  (str (java.time.Instant/now)))


(defn fork-output-base
  "Derive the fork's bazel output base from the `bazel-out` convenience
  symlink hatch created (target: <output_base>/execroot/<ws>/bazel-out).
  Avoids invoking bazel. Returns nil if the symlink is absent."
  []
  (let [link (fs/path fork-target "bazel-out")]
    (when (fs/exists? link {:nofollow-links true})
      (let [target (str (fs/read-link link))
            idx    (str/index-of target "/execroot/")]
        (when idx (subs target 0 idx))))))


(defn cleanup
  []
  ;; Expunge the fork's bazel output base. It lives under
  ;; ~/Library/Caches/bazel/_bazel_<user>/<md5-of-workspace-path>/ -- OUTSIDE
  ;; tmpdir, keyed by the fork path -- so deleting tmpdir alone orphans ~7 GB
  ;; per run (each run gets a fresh temp path => a fresh base). bazel marks
  ;; artifacts read-only, so chmod -R u+w before rm. The _bazel_ guard makes
  ;; an unexpected path a no-op. Derive before deleting tmpdir (the symlink
  ;; lives inside it).
  (when-let [ob (try (fork-output-base) (catch Exception _ nil))]
    (when (and (seq ob) (str/includes? ob "_bazel_") (fs/exists? ob))
      (sh!!? {} "bash" "-c"
             (str "chmod -R u+w '" ob "' 2>/dev/null; rm -rf '" ob "'"))))
  (when (fs/exists? tmpdir)
    (fs/delete-tree tmpdir)))


(defn publish-to-other!
  "After a green check, publish the fork tree to the defn/other GitHub repo
  as ONE commit. Delete-all + re-add (rsync the fork tree over an emptied
  clone) so the diff vs the previous publish shows the true magnitude of
  change between successful checks -- file removals show as deletions, not
  silent drift. Records the source defn SHA in PORTABILITY-SOURCE.md so each
  commit is tied to the defn commit that produced it.

  Best-effort: any failure (no network, no push rights) logs and returns nil
  -- the portability verdict already passed; publishing is bookkeeping and
  must never flip check-fork's exit. Returns the new other SHA on a real
  publish, :unchanged when the tree matched the last publish, nil on skip."
  [fork-dir]
  (try
    (let [work  (str (fs/create-temp-dir {:prefix "defn-other-publish-"}))
          clone (str work "/other")
          genv  (assoc (into {} (System/getenv))
                       "GIT_AUTHOR_NAME" "check-fork" "GIT_AUTHOR_EMAIL" "check-fork@defn.local"
                       "GIT_COMMITTER_NAME" "check-fork" "GIT_COMMITTER_EMAIL" "check-fork@defn.local")
          c (sh!!? {:out :string :err :string} "gh" "repo" "clone" "defn/other" clone)]
      (when-not (zero? (:exit c))
        (throw (ex-info (str "clone defn/other failed: " (:err c)) {})))
      ;; Empty-on-first-run repo: ensure a main branch exists to commit on.
      (sh!!? {:dir clone} "git" "checkout" "-q" "-B" "main")
      ;; Delete every tracked path (keep .git) so re-adding yields a real diff.
      (doseq [p (fs/list-dir clone) :when (not= ".git" (fs/file-name p))]
        (fs/delete-tree p))
      ;; Copy the fork tree (sans its own .git) UNDER m/, mirroring defn/defn's
      ;; layout (git root contains m/, the monorepo lives in m/). bin/bbs bakes
      ;; in ${CDUP}m/kernel/lib, so a flat publish (content at root) breaks the
      ;; babashka classpath -- defn/other CI surfaced this. CI infra
      ;; (.github/workflows, PORTABILITY-SOURCE.md) stays at the repo root.
      (fs/create-dirs (str clone "/m"))
      (sh!! {} "rsync" "-a" "--exclude" ".git" (str fork-dir "/") (str clone "/m/"))
      (spit (str clone "/PORTABILITY-SOURCE.md")
            (str "# Portability source\n\n"
                 "Bootstrapped fork of github.com/defn/defn, published by `mise run\n"
                 "check-fork` after a green portability check. Generated, not hand-edited.\n\n"
                 "- defn source commit: `" source-sha "`\n"
                 "- published (UTC): `" (utc-now) "`\n"))
      ;; CI proof (AIDR-00149 C): GitHub's runner shares none of the host's
      ;; state, so a green run here is the strongest evidence the fork builds
      ;; standalone. Injected on every publish since publish rewrites main.
      ;; Mirrors check-fork's in-fork steps: hatch (regen this fork's seed
      ;; outputs) then check.
      (fs/create-dirs (str clone "/.github/workflows"))
      (spit (str clone "/.github/workflows/check.yml")
            (str "# Generated by defn check-fork publish (AIDR-00149). Do not hand-edit.\n"
                 "name: check\n"
                 "on:\n"
                 "  push:\n"
                 "    branches: [main]\n"
                 "  workflow_dispatch:\n"
                 "permissions:\n"
                 "  contents: read\n"
                 "jobs:\n"
                 "  check:\n"
                 "    runs-on: ubuntu-latest\n"
                 "    timeout-minutes: 120\n"
                 "    env:\n"
                 "      MISE_YES: \"1\"\n"
                 "    steps:\n"
                 "      - uses: actions/checkout@v4\n"
                 "      - name: Free disk space for bazel\n"
                 "        run: |\n"
                 "          sudo rm -rf /usr/share/dotnet /opt/ghc /usr/local/lib/android /opt/hostedtoolcache/CodeQL /usr/local/share/boost\n"
                 "          sudo docker image prune --all --force || true\n"
                 "          df -h /\n"
                 "      - name: Surface the fork's mise toolset as global config\n"
                 "        # defn keeps dotfiles in root/; the dev environment links\n"
                 "        # ~/.config/mise/config.toml -> root/.config/mise/config.toml (the\n"
                 "        # [tools] set). A fresh runner has no such link, so mise install\n"
                 "        # would find no tools. Reproduce the link the devcontainer makes.\n"
                 "        run: |\n"
                 "          mkdir -p ~/.config/mise\n"
                 "          ln -sf \"$PWD/m/root/.config/mise/config.toml\" ~/.config/mise/config.toml\n"
                 "      - name: Generate machine-specific .bazelrc.workspace for this runner\n"
                 "        # .bazelrc.workspace is per-machine + gitignored (bazel action_env\n"
                 "        # HOME/PATH/mise paths). The bundled one carries the publisher's host\n"
                 "        # paths; regenerate from this runner's $HOME + git root. Pure bash+git.\n"
                 "        working-directory: m\n"
                 "        run: ./bin/bootstrap-bazelrc\n"
                 "      - uses: jdx/mise-action@v2\n"
                 "        with:\n"
                 "          working_directory: m\n"
                 "      - name: hatch (regenerate seed outputs for this fork's tenant set)\n"
                 "        working-directory: m\n"
                 "        run: mise run hatch\n"
                 "      - name: check\n"
                 "        working-directory: m\n"
                 "        run: mise run check\n"))
      (sh!! {:dir clone} "git" "add" "-A")
      (if (zero? (:exit (sh!!? {:dir clone} "git" "diff" "--cached" "--quiet")))
        (do (log-ok "publish: fork tree unchanged since last publish -- no commit")
            (fs/delete-tree work)
            :unchanged)
        (let [msg (str "check-fork green: defn@" (subs source-sha 0 (min 12 (count source-sha)))
                       " (" (utc-now) ")")]
          (sh!! {:dir clone :extra-env genv} "git" "commit" "-q" "-m" msg)
          (sh!! {:dir clone} "git" "push" "-q" "-u" "origin" "main")
          (let [other-sha (str/trim (:out (sh!!? {:dir clone :out :string} "git" "rev-parse" "HEAD")))]
            (log-ok "publish: defn/other <-" msg)
            (fs/delete-tree work)
            other-sha))))
    (catch Exception e
      (log-err "publish to defn/other skipped:" (.getMessage e))
      nil)))


(defn mark-stable!
  "Stable marker on the defn side: defn@source-sha is verified portable. Force-
  move the annotated tag `portability-green` to that SHA and push it. A moving
  tag (not a commit) records 'defn is stable here' without churning defn's tree
  or manifest each run; its message records the paired other SHA. Best-effort."
  [other-sha]
  (try
    (let [m (str "portability green: defn@" (subs source-sha 0 12)
                 (when (string? other-sha) (str " -> other@" (subs other-sha 0 (min 12 (count other-sha)))))
                 " (" (utc-now) ")")]
      (sh!! {} "git" "tag" "-f" "-a" "portability-green" "-m" m source-sha)
      (sh!! {} "git" "push" "-f" "-q" "origin" "portability-green")
      (log-ok "marked defn stable:" m))
    (catch Exception e
      (log-err "mark-stable skipped:" (.getMessage e)))))


(println "check-fork:")
(println "  tmpdir   " tmpdir)
(println "  fork at  " fork-target)
(println)


;; 1. git init the parent so `defn bootstrap` can commit there.
(sh!! {:dir tmpdir} "git" "init" "-q" "-b" "main")
(sh!! {:dir tmpdir} "git" "config" "user.email" "check-fork@defn.local")
(sh!! {:dir tmpdir} "git" "config" "user.name" "check-fork")


;; 2. Run `defn bootstrap` against the temp target. The module defaults
;; (cue=github.com/defn/other, go=github.com/defn/other/m) define the
;; "other" probe fork; only --target is overridden so the fork lands in
;; the isolated temp dir rather than the bootstrap default (other/m).
;; The persistent m/other checkout that default once referred to was
;; retired (AIDR-00148) -- check-fork is the sole portability probe.
(println "step 1/3: bootstrap into" fork-target)
(println)
(defn-bin! "bootstrap" (str "--target=" fork-target))


;; 3. Build the env for fork-side `mise` invocations.
;;
;; Empirically: the inherited env works as long as PWD points at
;; the fork and the fork's mise.toml is trusted in mise's
;; user-level store. Aggressively scrubbing MISE_* / GIT_* (the
;; first thing I tried) breaks hatch in non-obvious ways
;; (probably because mise itself reads MISE_DATA_DIR etc. from
;; the parent shell). Keep the inherited env, just re-anchor
;; PWD and ensure trust is auto-accepted.
(def fork-env
  (let [base (into {} (System/getenv))]
    (-> base
        (dissoc "OLDPWD")
        (assoc "PWD" fork-target)
        (assoc "MISE_YES" "1")
        (assoc "MISE_TRUSTED_CONFIG_PATHS" fork-target))))


;; Pre-trust every mise.toml in the fork. `mise run check` (and
;; the subprocesses it spawns through bazel-runner) lose
;; MISE_TRUSTED_CONFIG_PATHS via bin/bazel-runner's `env -i`, so
;; transient env doesn't suffice -- the trust must be persistent
;; in mise's user-level trust store (~/.local/state/mise/...).
;;
;; The glob `**/mise.toml` from fork-target does NOT match the
;; root mise.toml -- ** requires at least one path component.
;; Trust the root explicitly, then walk the rest.
(println "step 1.5/3: pre-trust mise.toml files in fork")


(sh!! {:dir fork-target :extra-env fork-env}
      "mise" "trust" "--quiet" (str fork-target "/mise.toml"))


(doseq [f (fs/glob fork-target "**/mise.toml")
        :let [p (str f)]
        :when (not (str/includes? p "/bazel-"))]
  (sh!! {:dir fork-target :extra-env fork-env}
        "mise" "trust" "--quiet" p))


;; First hatch: regenerates seed outputs (notably tenant-deps.bzl)
;; with the fork's actual tenant set. Without this, bazel analysis
;; in the next step fails because the bundled tenant-deps.bzl
;; references upstream tenants the fork doesn't have.
(println)
(println "step 2/3: mise run hatch inside fork (regenerate seed outputs)")
(println)


(let [r (sh!!? {:dir fork-target :extra-env fork-env
                :out :inherit :err :inherit}
               "mise" "run" "hatch")]
  (when-not (zero? (:exit r))
    (cleanup)
    (log-err "fork hatch failed:" (:exit r))
    (exit 1)))


(println)
(println "step 3/3: mise run check inside fork")
(println)


(let [r (sh!!? {:dir fork-target :extra-env fork-env
                :out :inherit :err :inherit}
               "mise" "run" "check" "--" "--ignore-unclean-workarea")]
  (if (zero? (:exit r))
    (do
      (log-ok "fork portability check passed:" fork-target "-> mise run check green")
      ;; AIDR-00149: record this green run. Publish the fork tree to
      ;; defn/other (one commit per real change, tied to defn@source-sha),
      ;; then mark defn stable. Done BEFORE cleanup (publish reads the fork
      ;; tree). Best-effort -- bookkeeping must not flip the verdict.
      (let [other-sha (publish-to-other! fork-target)]
        (mark-stable! (when (string? other-sha) other-sha)))
      (cleanup)
      (exit 0))
    (do
      (cleanup)
      (log-err "fork portability check failed: mise run check returned" (:exit r))
      (exit 1))))
