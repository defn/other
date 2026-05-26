#!/usr/bin/env bbs
#MISE description= "Build (via bazel) and run the defn CLI; freshness-guaranteed alternative to a cached binary"


;; Why this task exists:
;;
;; `bin/defn` used to be a 138MB static binary produced by
;; `go build -o bin/defn ./go`. That gave
;; `defn ...` an always-available PATH entry, but also let the
;; artifact silently fall behind source whenever someone edited
;; the Go tree without remembering to rebuild. Twice during
;; AIDR-00135 development a stale binary masked a real behavior
;; change for hours.
;;
;; Now `bin/defn` is a babashka shim that calls `mise run defn`,
;; and this task is the canonical builder-and-runner. Bazel's
;; incremental cache makes the no-op rebuild path sub-second, so
;; the freshness guarantee is essentially free in steady state.
;;
;; Note: this file is intentionally library-free. Requiring `defn`
;; (kernel/lib/defn.clj) is unsafe here -- the bazel fmt_test
;; sandbox places this script's own dir on the classpath, so a
;; `(require '[defn :refer :all])` resolves to THIS file, recurses,
;; and overflows the stack. Inline shell calls via babashka.process
;; are sufficient.
;;
;; Usage:
;;   mise run defn -- dispatch --bricks=app--keda --worktree ...
;;   bin/defn dispatch --bricks=...                  ; same thing
;;
;; The `--` separator is mise's convention to mark the end of
;; mise's own flags; everything after it is forwarded to the
;; defn CLI.

(require '[babashka.process :as p]
         '[babashka.fs :as fs]
         '[clojure.string :as str]
         '[cheshire.core :as json])


;; Resolve the active tenant (AIDR-00141 Stage 3.5d). Each tenant has
;; its own namesake CLI at //tenant/<t>/go/cmd/<t>:<t>; this task
;; builds whichever tenant is active in this workspace.
;;
;; Anchors the lattice shard read to git-toplevel so the read works
;; from any cwd (e.g. a nested cluster brick). Validates the result
;; against the default_tenant catalog regex so a corrupted lattice
;; can't redirect to a foreign tenant. Hardened per AIDR-00144.
(defn- active-tenant
  []
  (let [root  (-> (p/shell {:out :string :err :string}
                           "git" "rev-parse" "--show-toplevel")
                  p/check :out str/trim
                  (str "/m"))
        ;; var/lattice/, NOT the pre-AIDR-00145 kernel/spec/lattice/.
        ;; This copy of active-tenant drifted from kernel/lib/defn.clj
        ;; when AIDR-00145 moved the shard to var/ (the two can't share:
        ;; this task is intentionally library-free, see header). The
        ;; stale path was masked in the defn repo -- the shard isn't
        ;; found, the fallback is "defn", and defn IS defn's active
        ;; tenant -- but in a fork (active tenant "other") the wrong
        ;; fallback builds the absent //tenant/defn/... and `mise run
        ;; defn` fails. Surfaced by the AIDR-00150 second lift, the first
        ;; `mise run defn` in a non-defn-tenant fork.
        shard (str root "/var/lattice/default_tenant.json")]
    (if-not (fs/exists? shard)
      "defn"
      (let [t (json/parse-string (slurp shard))]
        (when-not (and (string? t) (re-matches #"^[a-z_][a-z0-9_-]*$" t))
          (throw (ex-info "default_tenant.json: malformed contents"
                          {:value t :shard shard})))
        t))))


(let [tenant (active-tenant)
      target (str "//tenant/" tenant "/go/cmd/" tenant ":" tenant)
      binary (str "./bazel-bin/tenant/" tenant "/go/cmd/" tenant "/" tenant "_/" tenant)
      ;; Build the namesake binary. Bazel's UI is silenced so routine
      ;; cached builds don't spam every invocation; on failure we
      ;; print the captured streams and propagate the exit code.
      r (p/shell {:out :string :err :string :continue true}
                 "bazelisk" "build"
                 "--ui_event_filters=-info,-stdout"
                 "--show_result=0"
                 "--noshow_progress"
                 target)]
  (when-not (zero? (:exit r))
    (print (:out r))
    (binding [*out* *err*] (print (:err r)))
    (System/exit (:exit r)))
  ;; Replace this process with the freshly-built artifact. Args flow
  ;; through unchanged. `p/exec` is execve(2) -- no extra fork, no
  ;; stranded shell between the user and the CLI.
  (apply p/exec binary *command-line-args*))
