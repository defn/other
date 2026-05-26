#!/usr/bin/env bbs
;; Fork-readiness smoke test (the structural counterpart to
;; SPEC-00351's string-based check in go/lib/spec/spec_test.go).
;;
;; Copies kernel/catalog/, kernel/schema/, tenant/library/catalog/,
;; tenant/boot/catalog/ into a sandbox alongside a stub `_smoke`
;; tenant overlay, then runs `cue eval` against the merged catalog.
;; Fails the test if:
;;   - the catalog overlay doesn't unify without defn,
;;   - the bricks comprehension in brick-_root.cue produces
;;     unification errors when only boot + library + _smoke are
;;     present, or
;;   - the _smoke overlay doesn't override default_tenant.
;;
;; This catches structural regressions that SPEC-00351 misses --
;; e.g. a kernel/.cue file accidentally referencing a defn-only
;; catalog field. See AIDR-00071 for the kernel/tenant decoupling
;; design.
;;
;; Args (positional, supplied by the sh_test rule):
;;   1. cue version (e.g. "0.16.1")

(require '[defn :refer :all]
         '[babashka.fs :as fs]
         '[babashka.process :as p])


(defn run-cue
  [cue cwd & args]
  (apply p/shell {:dir cwd :out :string :err :string :continue true} cue args))


(let [[cue-version] *command-line-args*

      runfiles  (str (System/getenv "TEST_SRCDIR") "/"
                     (System/getenv "TEST_WORKSPACE"))
      tmp       (str (System/getenv "TEST_TMPDIR") "/fork-smoke")
      sandbox   (str tmp "/work")
      smoke-dir (str sandbox "/tenant/_smoke/catalog")]

  (log-ok (str "fork-smoke sandbox: " sandbox))

  ;; Rebuild sandbox.
  (when (fs/exists? sandbox) (fs/delete-tree sandbox))
  (fs/create-dirs sandbox)

  ;; Stage the substrate. Bazel runfiles mirror the workspace tree
  ;; under $TEST_SRCDIR/$TEST_WORKSPACE/, so paths inside that root
  ;; are workspace-relative.
  ;;
  ;; CUE evaluates each command-line package dir independently --
  ;; passing kernel/catalog and tenant/library/catalog as separate
  ;; args would not unify them. We mimic the gen pipeline's
  ;; in-memory overlay (m/go/lib/gen/gen.go:178-217) by flat-
  ;; copying every .cue file from every catalog dir into a single
  ;; merged_catalog/ directory inside the sandbox. CUE then sees
  ;; one package with all sources and unifies normally.
  (let [copy (fn [rel]
               (let [src (str runfiles "/" rel)
                     dst (str sandbox "/" rel)]
                 (fs/create-dirs (fs/parent dst))
                 (sh!! "cp" "-R" src dst)))
        merged (str sandbox "/merged_catalog")
        flatten (fn [src-dir]
                  (doseq [f (filter #(let [n (fs/file-name %)]
                                       (and (str/ends-with? n ".cue")
                                            ;; Skip any default-tenant override
                                            ;; -- the smoke test installs its own
                                            ;; `_smoke` pin; a fork's pin would
                                            ;; conflict during unification.
                                            (not= n "default-tenant.cue")))
                                    (fs/list-dir src-dir))]
                    (let [dst (str merged "/"
                                   (str/replace
                                     (-> (str src-dir "/")
                                         (str/replace runfiles "")
                                         (str/replace #"^/+" "")
                                         (str/replace "/" "--"))
                                     #"--$" "--")
                                   (fs/file-name f))]
                      (fs/copy f dst))))]
    (copy "kernel/schema")
    ;; AIDR-00132: per-brick dispatch.cue files (now including
    ;; kernel/schema/dispatch.cue) import the dispatch protocol
    ;; schema. Stage it so brick imports resolve under fork.
    (copy "kernel/spec/dispatch")
    (copy "cue.mod")
    (fs/create-dirs merged)
    (flatten (str runfiles "/kernel/catalog"))
    ;; Flatten every tenant/<t>/catalog dir present in runfiles. Per
    ;; AIDR-00138 D5.3, kernel substrate has no hardcoded tenants;
    ;; flatten whatever ships with this workspace (defn has boot+library;
    ;; a fork might have just library+<fork>).
    (let [tenant-root (str runfiles "/tenant")]
      (when (fs/exists? tenant-root)
        (doseq [t (fs/list-dir tenant-root)
                :let [cat (str t "/catalog")]
                :when (fs/exists? cat)]
          (flatten cat)))))

  ;; Stub _smoke tenant overlay -- written into the same merged
  ;; package dir as kernel/catalog and tenant catalogs, so CUE
  ;; unifies the default_tenant override naturally. Filename must
  ;; not start with `_` or `.` -- CUE excludes hidden / underscore
  ;; files from package compilation.
  (let [merged (str sandbox "/merged_catalog")]
    (spit (str merged "/zzz-smoke-tenant-override.cue")
          (str "@experiment(aliasv2,explicitopen,try)\n\n"
               "package catalog\n\n"
               "// Synthesized by //kernel/spec/test:fork_smoke. The\n"
               "// presence of this file proves a fork can swap the\n"
               "// active tenant via a single catalog field.\n"
               "default_tenant: \"_smoke\"\n")))

  (let [cue (mise-bin (str "cue@" cue-version) "cue")
        cat-args ["./merged_catalog"]]

    ;; 1) default_tenant override.
    (let [{:keys [exit out err]} (apply run-cue cue sandbox
                                        "eval" "-e" "default_tenant"
                                        cat-args)]
      (when-not (zero? exit)
        (log-err "cue eval default_tenant FAILED")
        (println "stdout:" out)
        (println "stderr:" err)
        (System/exit 1))
      (when (not= (str/trim out) "\"_smoke\"")
        (log-err (str "default_tenant override failed: got "
                      (str/trim out) " want \"_smoke\""))
        (System/exit 1)))
    (log-ok "default_tenant overridden by _smoke tenant overlay")

    ;; 2) app_bricks comprehension unifies without defn.
    (let [{:keys [exit out err]} (apply run-cue cue sandbox
                                        "eval" "-e" "len(app_bricks)"
                                        cat-args)]
      (when-not (zero? exit)
        (log-err "cue eval app_bricks FAILED -- catalog overlay broken without defn")
        (println "stdout:" out)
        (println "stderr:" err)
        (System/exit 1))
      (let [n (Integer/parseInt (str/trim out))]
        (when (zero? n)
          (log-err "app_bricks is empty -- library overlay didn't contribute apps?")
          (System/exit 1))
        (log-ok (str "app_bricks length: " n
                     " (library apps registered without defn)")))))

  (log-ok "fork-smoke passed -- kernel + boot + library + fresh tenant overlay unifies cleanly"))
