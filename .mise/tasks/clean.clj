#!/usr/bin/env bbs
#MISE description= "Reclaim disk: prune docker / bazel / mise / terraform / python / npm / go caches"


;; clean.clj -- reclaim disk by pruning every developer-tool cache:
;;
;;   1. docker:    `docker system prune -f` removes stopped containers,
;;                 unused networks, dangling images, and build cache.
;;                 Skipped (not failed) when docker is missing or its
;;                 daemon is not running.
;;   2. bazel:     `bazelisk clean --expunge` drops the entire output
;;                 base for the m/ workspace.
;;   3. mise:      `mise prune --tools --yes` deletes every installed
;;                 tool version that is not the latest specified in
;;                 any tracked config. The bare `mise prune` only
;;                 prunes config links; --tools is what removes old
;;                 tool versions from disk. Project versions are
;;                 pinned in kernel/schema/versions.cue.
;;   4. terraform: removes the global plugin cache
;;                 (~/.terraform.d/plugin-cache) and any per-workspace
;;                 .terraform/ directories under m/. `tofu init`
;;                 regenerates them from the lockfile.
;;   5. python:    `pip cache purge` and `uv cache clean`. pipx has no
;;                 separate package cache to clean (its venvs are the
;;                 install destination, not a cache).
;;   6. npm/pnpm:  `npm cache clean --force` and `pnpm store prune`.
;;   7. go:        `go clean -cache -modcache -fuzzcache -testcache`.
;;
;;  Each step is guarded so a missing tool yields a skip line instead
;;  of an error -- the task should make progress on every machine
;;  regardless of which toolchains are installed.

(require '[defn :refer :all]
         '[babashka.fs :as fs])


(defn- on-path?
  [bin]
  (sh? "sh" "-c" (str "command -v " bin " > /dev/null")))


(defn- step-skip
  [reason]
  (log-ok (str "skip -- " reason)))


;; ---------------------------------------------------------------------------
;; 1. docker
;; ---------------------------------------------------------------------------

(if (and (on-path? "docker") (sh? "docker" "info"))
  (do
    (log-ok "docker system prune -f")
    (sh!! "docker" "system" "prune" "-f"))
  (step-skip "docker not running"))


;; ---------------------------------------------------------------------------
;; 2. bazel (m/ workspace)
;; ---------------------------------------------------------------------------

(log-ok "bazelisk clean --expunge")
(sh!! "bazelisk" "clean" "--expunge")


;; ---------------------------------------------------------------------------
;; 3. mise -- prune unused tool versions
;; ---------------------------------------------------------------------------

(let [prunable (:out (sh!!? "mise" "ls" "--prunable"))
      lines (->> (str/split-lines prunable)
                 (remove str/blank?))]
  (if (empty? lines)
    (log-ok "mise: no prunable tool versions")
    (do
      (log-ok (str "mise prune --tools (" (count lines) " version(s) to remove)"))
      (sh!! "mise" "prune" "--tools" "--yes"))))


;; ---------------------------------------------------------------------------
;; 4. terraform / opentofu
;; ---------------------------------------------------------------------------

(let [plugin-cache (str (System/getenv "HOME") "/.terraform.d/plugin-cache")]
  (if (fs/exists? plugin-cache)
    (do
      (log-ok (str "rm -rf " plugin-cache "/*"))
      (doseq [child (fs/list-dir plugin-cache)]
        (fs/delete-tree child)))
    (step-skip "no ~/.terraform.d/plugin-cache")))


(let [workspace-tf (->> (sh!!? "find" "." "-maxdepth" "6" "-name" ".terraform"
                               "-type" "d" "-not" "-path" "*/bazel-*/*")
                        :out
                        str/split-lines
                        (remove str/blank?))]
  (if (empty? workspace-tf)
    (step-skip "no per-workspace .terraform/ dirs")
    (doseq [d workspace-tf]
      (log-ok (str "rm -rf " d))
      (fs/delete-tree d))))


;; ---------------------------------------------------------------------------
;; 5. python (pip + uv; pipx has no separate cache)
;; ---------------------------------------------------------------------------

(if (on-path? "pip")
  (do
    (log-ok "pip cache purge")
    (sh!! "pip" "cache" "purge"))
  (step-skip "pip not on PATH"))


(if (on-path? "uv")
  (do
    (log-ok "uv cache clean")
    (sh!! "uv" "cache" "clean"))
  (step-skip "uv not on PATH"))


;; ---------------------------------------------------------------------------
;; 6. npm / pnpm
;; ---------------------------------------------------------------------------

(if (on-path? "npm")
  (do
    (log-ok "npm cache clean --force")
    (sh!! "npm" "cache" "clean" "--force"))
  (step-skip "npm not on PATH"))


(if (on-path? "pnpm")
  (do
    (log-ok "pnpm store prune")
    (sh!! "pnpm" "store" "prune"))
  (step-skip "pnpm not on PATH"))


;; ---------------------------------------------------------------------------
;; 7. go (build + module + test + fuzz caches)
;; ---------------------------------------------------------------------------

(if (on-path? "go")
  (do
    (log-ok "go clean -cache -modcache -fuzzcache -testcache")
    (sh!! "go" "clean" "-cache" "-modcache" "-fuzzcache" "-testcache"))
  (step-skip "go not on PATH"))
