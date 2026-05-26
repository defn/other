#!/usr/bin/env bbs
#MISE description= "Depth-2 fertility test (AIDR-00150): lift defn -> other (defn's binary), then other -> another (other's OWN binary). Each lift bootstraps into an isolated temp dir outside m/ and runs `mise run hatch` only; the full `mise run check` runs cold on each published repo's GHA. Publishes both green forks (best-effort)."


;; Verify the kernel portability contract (AIDR-00138) AND fork
;; fertility (AIDR-00150) with a two-stage bootstrap, analogous to
;; GCC's 3-stage build:
;;
;;   Lift 1 (defn -> other): defn's binary bundles + rewrites + commits
;;     a fork whose CUE module is github.com/defn/other. Proves defn's
;;     generator works.
;;   Lift 2 (other -> another): fork_O's OWN binary (`mise run defn --
;;     bootstrap`, built from //tenant/other/go/cmd/other) lifts the
;;     shared substrate again and mints a NEW leaf tenant `another`.
;;     Proves other is FERTILE -- it can create a genuinely new tenant,
;;     not just rebuild a copy of itself. The rename is source-relative
;;     (AIDR-00150): the second lift detects its source as
;;     github.com/defn/other and moves *those* strings, so no `other`
;;     leaks into `another`.
;;
;; We stop at `another`; one self-application from a fork is the
;; fertility witness. Lift 2 is orchestrated HERE, not by other's CI --
;; if other's CI performed the lift, another's CI would lift
;; yet-another, ad infinitum (AIDR-00150 decision 1).
;;
;; Cost stance (AIDR-00150 decision 3): each lift does only enough
;; LOCALLY to produce a coherent, publishable tree -- bootstrap +
;; `mise run hatch` (regen seed outputs / build generated targets), NOT
;; the full `mise run check`. The full check (build + `bazel test
;; //...` + every spec check) runs FROM COLD on each repo's GitHub
;; Actions. Fertility is the observed conjunction of three green badges
;; (defn's CI, defn/other CI, defn/another CI); local responsibility is
;; only "both lifts hatch clean + both pushes succeed". The first hatch
;; is required because the bundled tenant-deps.bzl references the
;; source's tenant cmd, which the fork renames.
;;
;; Scope notes:
;;   * The fork modules are hardcoded (other, then another); a future
;;     spec AIDR will introduce a `forks: [string]:` catalog field so
;;     adding probes is a catalog edit.
;;   * Each fork runs from the deterministic-after-bootstrap state (no
;;     hatch outputs committed). Its first `mise run hatch` regenerates
;;     gen/lattice/manifest from the fork's actual tenant tree.
;;   * Teardown expunges each fork's bazel output base too, not just
;;     tmpdir. The base lives outside tmpdir (keyed by the fork path)
;;     so each run would otherwise orphan ~7 GB. See cleanup-all.


(require '[defn :refer :all])
(require '[clojure.string :as str])
(require '[babashka.fs :as fs])


;; Target modules for each lift. Lift 1 mints tenant `other`; lift 2
;; mints tenant `another` (the leaf is derived from the CUE module by
;; bootstrap, AIDR-00150 decision 4 -- one knob sets repo + module +
;; tenant + namesake CLI).
(def other-cue "github.com/defn/other")
(def other-go "github.com/defn/other/m")
(def another-cue "github.com/defn/another")
(def another-go "github.com/defn/another/m")


;; The defn source commit both lifts derive from. fork_O is unpushed
;; when fork_A publishes (its SHA is local-only), so defn-HEAD is the
;; stable provenance recorded in BOTH forks' PORTABILITY-SOURCE.md
;; (AIDR-00150 resolved Q2).
(def source-sha
  (str/trim (:out (sh!!? {:out :string} "git" "rev-parse" "HEAD"))))


(defn utc-now
  []
  (str (java.time.Instant/now)))


;; Every fork lifted this run: {:tmpdir t :fork f}. cleanup-all tears
;; down all of them (temp tree + bazel output base).
(def forks (atom []))


(defn fork-output-base
  "Derive a fork's bazel output base from the `bazel-out` convenience
  symlink hatch created (target: <output_base>/execroot/<ws>/bazel-out).
  Avoids invoking bazel. Returns nil if the symlink is absent."
  [fork-dir]
  (let [link (fs/path fork-dir "bazel-out")]
    (when (fs/exists? link {:nofollow-links true})
      (let [target (str (fs/read-link link))
            idx    (str/index-of target "/execroot/")]
        (when idx (subs target 0 idx))))))


(defn cleanup-all
  []
  ;; Expunge each fork's bazel output base. It lives under
  ;; ~/Library/Caches/bazel/_bazel_<user>/<md5-of-workspace-path>/ -- OUTSIDE
  ;; tmpdir, keyed by the fork path -- so deleting tmpdir alone orphans ~7 GB
  ;; per run (each run gets a fresh temp path => a fresh base). bazel marks
  ;; artifacts read-only, so chmod -R u+w before rm. The _bazel_ guard makes
  ;; an unexpected path a no-op. Derive before deleting tmpdir (the symlink
  ;; lives inside it).
  (doseq [{:keys [tmpdir fork]} @forks]
    (when-let [ob (try (fork-output-base fork) (catch Exception _ nil))]
      (when (and (seq ob) (str/includes? ob "_bazel_") (fs/exists? ob))
        (sh!!? {} "bash" "-c"
               (str "chmod -R u+w '" ob "' 2>/dev/null; rm -rf '" ob "'"))))
    (when (fs/exists? tmpdir)
      (fs/delete-tree tmpdir))))


(defn fork-env
  "Env for fork-side `mise` invocations. Empirically the inherited env
  works as long as PWD points at the fork and the fork's mise.toml is
  trusted in mise's user store. Aggressively scrubbing MISE_* / GIT_*
  breaks hatch (mise reads MISE_DATA_DIR etc. from the parent shell)."
  [fork-dir]
  (-> (into {} (System/getenv))
      (dissoc "OLDPWD")
      (assoc "PWD" fork-dir)
      (assoc "MISE_YES" "1")
      (assoc "MISE_TRUSTED_CONFIG_PATHS" fork-dir)))


(defn pre-trust!
  "Pre-trust every mise.toml in the fork. `mise run hatch` (and the
  subprocesses it spawns through bazel-runner) lose
  MISE_TRUSTED_CONFIG_PATHS via bin/bazel-runner's `env -i`, so
  transient env doesn't suffice -- the trust must be persistent in
  mise's user-level trust store. The glob `**/mise.toml` does NOT match
  the root mise.toml (** requires at least one path component), so trust
  the root explicitly, then walk the rest."
  [fork-dir]
  (let [env (fork-env fork-dir)]
    (sh!! {:dir fork-dir :extra-env env}
          "mise" "trust" "--quiet" (str fork-dir "/mise.toml"))
    (doseq [f (fs/glob fork-dir "**/mise.toml")
            :let [p (str f)]
            :when (not (str/includes? p "/bazel-"))]
      (sh!! {:dir fork-dir :extra-env env}
            "mise" "trust" "--quiet" p))))


(defn hatch!
  "First hatch: regenerates seed outputs (notably tenant-deps.bzl) with
  the fork's actual tenant set. Without this, bazel analysis fails
  because the bundled tenant-deps.bzl references the source's tenant cmd
  the fork renamed. On failure, tear everything down and exit 1."
  [fork-dir]
  (let [r (sh!!? {:dir fork-dir :extra-env (fork-env fork-dir)
                  :out :inherit :err :inherit}
                 "mise" "run" "hatch")]
    (when-not (zero? (:exit r))
      (cleanup-all)
      (log-err "fork hatch failed:" fork-dir "exit" (:exit r))
      (exit 1))))


(defn lift-and-build!
  "One bootstrap lift into a fresh isolated temp dir OUTSIDE m/, then
  pre-trust + hatch -- enough to make the fork a coherent, publishable
  tree. Does NOT run `mise run check` (AIDR-00150 decision 3 -- cold GHA
  validates).

  The fork MUST land outside m/ (fs/create-temp-dir -> /var/folders/...).
  This isolation is the test's validity, not a convenience (AIDR-00148):
  a fork nested under m/ sits in defn's config-inheritance cone -- mise
  walks up for config, bazel resolves the enclosing repo/.bazelrc/cache,
  git sees the ancestry -- so it would borrow defn's setup and could pass
  while a genuinely-lifted repo fails. Never `optimize` this into a
  subdir of m/.

  `run-bootstrap!` is (fn [fork-target cue-module go-module]) that runs
  the appropriate SOURCE's bootstrap binary (defn's for lift 1, fork_O's
  own for lift 2). Returns the fork dir."
  [label cue-module go-module run-bootstrap!]
  (let [tmpdir (str (fs/create-temp-dir {:prefix (str "defn-" label "-")}))
        fork   (str tmpdir "/m")]
    (swap! forks conj {:tmpdir tmpdir :fork fork})
    (println (str label ": bootstrap -> " fork))
    (println (str "  module " cue-module))
    (println)
    ;; git init the parent so `defn bootstrap` can commit there.
    (sh!! {:dir tmpdir} "git" "init" "-q" "-b" "main")
    (sh!! {:dir tmpdir} "git" "config" "user.email" "check-fork@defn.local")
    (sh!! {:dir tmpdir} "git" "config" "user.name" "check-fork")
    (run-bootstrap! fork cue-module go-module)
    (println)
    (println (str label ": pre-trust mise.toml files + hatch (regenerate seed outputs)"))
    (println)
    (pre-trust! fork)
    (hatch! fork)
    fork))


(defn bootstrap-from-defn!
  "Lift 1 source = the defn workspace this task runs in. defn-bin! runs
  the namesake CLI from the current cwd (defn root), so bootstrap
  detects its source as github.com/defn/defn."
  [fork cue-module go-module]
  (defn-bin! "bootstrap"
    (str "--target=" fork)
    (str "--cue-module=" cue-module)
    (str "--go-module=" go-module)))


(defn bootstrap-from-fork!
  "Lift 2 source = fork_O. Returns a run-bootstrap! that invokes
  fork_O's OWN binary via `mise run defn -- bootstrap` with cwd + env
  pinned to fork_O, so the bootstrap inside detects its source as
  github.com/defn/other (NOT defn) and mints `another` cleanly. This is
  what makes lift 2 a fertility test rather than a second defn lift
  (AIDR-00150 decision 2). fork_O must already be hatched (its CLI
  builds on first `mise run defn`)."
  [src-fork]
  (fn [fork cue-module go-module]
    (let [r (sh!!? {:dir src-fork :extra-env (fork-env src-fork)
                    :out :inherit :err :inherit}
                   "mise" "run" "defn" "--" "bootstrap"
                   (str "--target=" fork)
                   (str "--cue-module=" cue-module)
                   (str "--go-module=" go-module))]
      (when-not (zero? (:exit r))
        (cleanup-all)
        (log-err "second lift (fork_O bootstrap) failed: exit" (:exit r))
        (exit 1)))))


(def fork-check-workflow
  ;; CI proof (AIDR-00149 C): GitHub's runner shares none of the host's
  ;; state, so a green run here is the strongest evidence the fork builds
  ;; standalone. This is where the full `mise run check` runs (cold) --
  ;; AIDR-00150 decision 3 moved it off the local path. Injected on every
  ;; publish since publish rewrites main. Mirrors the in-fork local steps
  ;; (hatch to regen seed outputs) then runs the full check.
  (str "# Generated by defn check-fork publish (AIDR-00149/00150). Do not hand-edit.\n"
       "# Hardened per GitHub Actions security guidance: actions pinned to full\n"
       "# commit SHA, read-only token, no pull_request trigger (fork PRs can't\n"
       "# auto-run or poison the cache), concurrency cancellation.\n"
       "name: check\n"
       "on:\n"
       "  push:\n"
       "    branches: [main]\n"
       "  workflow_dispatch:\n"
       "permissions:\n"
       "  contents: read\n"
       "concurrency:\n"
       "  group: check-${{ github.ref }}\n"
       "  cancel-in-progress: true\n"
       "jobs:\n"
       "  check:\n"
       "    runs-on: ubuntu-latest\n"
       "    timeout-minutes: 120\n"
       "    env:\n"
       "      MISE_YES: \"1\"\n"
       "    steps:\n"
       "      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4\n"
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
       "      - uses: jdx/mise-action@c37c93293d6b742fc901e1406b8f764f6fb19dac # v2\n"
       "        with:\n"
       "          working_directory: m\n"
       "      - name: Put mise binary on the bazel action PATH (~/.local/bin)\n"
       "        # genrules resolve tools via `mise x <tool> --`, so the sandbox\n"
       "        # action PATH (~/.local/bin + shims) needs the mise binary itself.\n"
       "        run: |\n"
       "          mkdir -p ~/.local/bin\n"
       "          ln -sf \"$(command -v mise)\" ~/.local/bin/mise\n"
       "          ~/.local/bin/mise --version\n"
       "      - name: Trust fork mise configs (persistent; survives bazel-runner env -i)\n"
       "        # bazel-runner runs bazelisk under env -i (drops MISE_TRUSTED_CONFIG_PATHS),\n"
       "        # so trust must be persisted in the user store. Includes the global\n"
       "        # ~/.config/mise/config.toml (the toolset) that genrule `mise x` loads.\n"
       "        working-directory: m\n"
       "        run: |\n"
       "          mise trust --quiet ~/.config/mise/config.toml\n"
       "          mise trust --quiet \"$PWD/mise.toml\"\n"
       "          for f in $(find . -name mise.toml -not -path '*/bazel-*'); do mise trust --quiet \"$f\" || true; done\n"
       "      - name: hatch (regenerate seed outputs for this fork's tenant set)\n"
       "        working-directory: m\n"
       "        run: mise run hatch\n"
       "      - name: check\n"
       "        working-directory: m\n"
       "        # --ignore-unclean-workarea: a fresh fork regenerates volatile var/\n"
       "        # gen outputs (machine-specific lattice); the assert below is the\n"
       "        # real clean bar -- nothing OUTSIDE var/ may drift.\n"
       "        run: mise run check -- --ignore-unclean-workarea\n"
       "      - name: Assert workspace clean outside volatile var/\n"
       "        working-directory: m\n"
       "        run: |\n"
       "          root=\"$(git rev-parse --show-toplevel)\"\n"
       "          dirty=\"$(git -C \"$root\" status --porcelain | grep -vE ' m/var/' || true)\"\n"
       "          if [ -n \"$dirty\" ]; then\n"
       "            echo \"Unexpected changes outside var/ -- portability defect:\"; echo \"$dirty\"; exit 1\n"
       "          fi\n"
       "          echo \"clean outside var/ (var/ is volatile-by-design, AIDR-00145)\"\n"))


(defn publish-fork!
  "After a green lift, publish the fork tree to a GitHub repo as ONE
  commit. Delete-all + re-add (rsync the fork tree over an emptied clone)
  so the diff vs the previous publish shows the true magnitude of change
  -- file removals show as deletions, not silent drift. Records the defn
  source SHA + source-desc in PORTABILITY-SOURCE.md so each commit is
  tied to the defn commit that produced it.

  Best-effort: any failure (no network, no push rights, target repo
  absent -- e.g. defn/another not yet `gh repo create`d) logs and returns
  nil. The lift already succeeded; publishing is bookkeeping and must
  never flip check-fork's exit, so a missing repo degrades to fewer
  badges (AIDR-00150 part D). Returns the new repo SHA on a real publish,
  :unchanged when the tree matched the last publish, nil on skip."
  [fork-dir target-repo source-desc]
  (try
    (let [work  (str (fs/create-temp-dir {:prefix "defn-publish-"}))
          clone (str work "/fork")
          genv  (assoc (into {} (System/getenv))
                       "GIT_AUTHOR_NAME" "check-fork" "GIT_AUTHOR_EMAIL" "check-fork@defn.local"
                       "GIT_COMMITTER_NAME" "check-fork" "GIT_COMMITTER_EMAIL" "check-fork@defn.local")
          c (sh!!? {:out :string :err :string} "gh" "repo" "clone" target-repo clone)]
      (when-not (zero? (:exit c))
        (throw (ex-info (str "clone " target-repo " failed: " (:err c)) {})))
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
                 source-desc ", published by `mise run check-fork` after a green\n"
                 "depth-2 fertility lift (AIDR-00150). Generated, not hand-edited.\n\n"
                 "- defn source commit: `" source-sha "`\n"
                 "- published (UTC): `" (utc-now) "`\n"))
      (fs/create-dirs (str clone "/.github/workflows"))
      (spit (str clone "/.github/workflows/check.yml") fork-check-workflow)
      (sh!! {:dir clone} "git" "add" "-A")
      (if (zero? (:exit (sh!!? {:dir clone} "git" "diff" "--cached" "--quiet")))
        (do (log-ok "publish:" target-repo "tree unchanged since last publish -- no commit")
            (fs/delete-tree work)
            :unchanged)
        (let [msg (str "check-fork lift: defn@" (subs source-sha 0 (min 12 (count source-sha)))
                       " (" (utc-now) ")")]
          (sh!! {:dir clone :extra-env genv} "git" "commit" "-q" "-m" msg)
          (sh!! {:dir clone} "git" "push" "-q" "-u" "origin" "main")
          (let [sha (str/trim (:out (sh!!? {:dir clone :out :string} "git" "rev-parse" "HEAD")))]
            (log-ok "publish:" target-repo "<-" msg)
            (fs/delete-tree work)
            sha))))
    (catch Exception e
      (log-err "publish to" target-repo "skipped:" (.getMessage e))
      nil)))


(defn mark-stable!
  "Stable marker on the defn side: defn@source-sha is verified portable +
  fertile. Force-move the annotated tag `portability-green` to that SHA
  and push it. A moving tag (not a commit) records 'defn is stable here'
  without churning defn's tree or manifest each run; its message records
  the paired other SHA. Best-effort."
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


(println "check-fork: depth-2 fertility test (AIDR-00150)")
(println "  source defn@" (subs source-sha 0 (min 12 (count source-sha))))
(println)


;; Lift 1: defn -> other (defn's own binary).
(println "=== lift 1/2: defn -> other ===")
(def fork-o (lift-and-build! "check-fork" other-cue other-go bootstrap-from-defn!))


;; Lift 2: other -> another (fork_O's OWN binary -- the fertility step).
(println)
(println "=== lift 2/2: other -> another (fork_O's own binary) ===")


(def fork-a
  (lift-and-build! "check-fork-2" another-cue another-go
                   (bootstrap-from-fork! fork-o)))


;; Both lifts hatched clean. Publish each (best-effort), then mark defn
;; stable. Done BEFORE cleanup (publish reads the fork trees). The full
;; `mise run check` runs cold on each repo's GHA -- fertility is the
;; conjunction of three green badges, observed there, not gated here.
(println)
(println "=== publish (best-effort) ===")


(let [other-sha (publish-fork! fork-o "defn/other"
                               "Bootstrapped fork of github.com/defn/defn")]
  (publish-fork! fork-a "defn/another"
                 "Bootstrapped fork of github.com/defn/other (lifted by other's own binary)")
  (mark-stable! (when (string? other-sha) other-sha)))


(cleanup-all)
(log-ok "check-fork: both lifts hatched clean + published (full check runs cold on each repo's GHA)")
(exit 0)
