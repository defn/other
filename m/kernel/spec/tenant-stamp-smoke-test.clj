#!/usr/bin/env bbs
;; Pin the universal-identity file set produced by
;; m/go/lib/stamp:StampTenant (run via `defn stamp tenant`).
;; A regression in the stamp's emitted file list -- whether dropping
;; a file or adding one -- shows up here as either a missing-file
;; failure or an unexpected-extras failure.
;;
;; This is the structural counterpart to fork_smoke (which proves
;; the catalog overlay unifies cleanly without defn). Together:
;;   - SPEC-00351 catches "tenant/defn" string literals in kernel/.
;;   - fork_smoke catches catalog-overlay structural regressions.
;;   - tenant_stamp_smoke (this test) catches stamp-set drift.
;;
;; See AIDR-00071.
;;
;; AIDR-00100 retired the dedicated stamptenant binary; this test
;; now drives the `defn stamp tenant --root SANDBOX NAME` subcommand.
;;
;; Args (positional, supplied by the sh_test rule):
;;   1. workspace path to //tenant/defn/go/cmd/defn:defn

(require '[defn :refer :all]
         '[babashka.fs :as fs])


(let [[defn-bin] *command-line-args*
      sandbox (str (System/getenv "TEST_TMPDIR") "/stamp-smoke/work")
      ;; The minimum-identity file set; if you change StampTenant's
      ;; output, mirror the change here.
      expected ["BUILD.bazel"
                "app/BUILD.bazel"
                "aws/BUILD.bazel"
                "bot/BUILD.bazel"
                "bot/.gitignore"
                "bot/mise.toml"
                "catalog/BUILD.bazel"
                "env/BUILD.bazel"
                "infra/BUILD.bazel"
                "infra/mise.toml"
                "infra/.mise/tasks/BUILD.bazel"
                "k3d/BUILD.bazel"
                "k8s/BUILD.bazel"]]

  (when (fs/exists? sandbox) (fs/delete-tree sandbox))
  (fs/create-dirs sandbox)
  (log-ok (str "tenant_stamp_smoke sandbox: " sandbox))

  ;; Run the stamp.
  (sh!! defn-bin "stamp" "tenant" "--root" sandbox "smoke")

  (let [tenant-root (str sandbox "/tenant/smoke")
        missing (vec (filter #(not (fs/exists? (str tenant-root "/" %))) expected))
        ;; Catch unexpected files too -- a stamp that grows silently
        ;; should fail the test until the expected list is updated.
        actual (->> (file-seq (fs/file tenant-root))
                    (filter (fn [f] (.isFile f)))
                    (map (fn [f] (str/replace (.getPath f) (str tenant-root "/") "")))
                    sort
                    vec)
        expected-sorted (vec (sort expected))
        extras (vec (filter #(not (some #{%} expected-sorted)) actual))]

    (when (seq missing)
      (log-err (str "stamp tenant smoke missing files: " missing))
      (System/exit 1))

    (when (seq extras)
      (log-err (str "stamp tenant smoke produced unexpected files: " extras))
      (log-err "(if intentional, update the expected list in tenant-stamp-smoke-test.clj)")
      (System/exit 1))

    (log-ok (str "stamp tenant emitted exactly the " (count expected)
                 "-file universal identity set"))

    ;; Re-running must be idempotent (create-if-missing).
    (let [{:keys [exit out]} (sh-result defn-bin "stamp" "tenant" "--root" sandbox "smoke")]
      (when-not (zero? exit)
        (log-err "re-stamp failed")
        (System/exit 1))
      (when-not (every? #(str/includes? out (str "preserved: tenant/smoke/" %))
                        expected)
        (log-err "re-stamp didn't preserve all files")
        (println out)
        (System/exit 1)))
    (log-ok "re-stamp is a no-op (every file preserved)"))

  (log-ok "tenant_stamp_smoke passed -- universal identity set is stable"))
