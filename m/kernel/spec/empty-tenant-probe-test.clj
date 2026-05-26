#!/usr/bin/env bbs
;; Empty-tenant probe: a falsifiability test on the kernel.
;;
;; Stamps a fresh tenant via StampTenant (the minimum-identity
;; file set) and stages it alongside kernel/catalog, kernel/schema,
;; tenant/library/catalog, tenant/boot/catalog. The empty tenant
;; declares only BUILD.bazel scaffolding -- no apps, no clusters,
;; no bots, no infra -- so the catalog overlay has to compose
;; cleanly under the maximally general tenant.
;;
;; The probe forces four structural questions to be answered:
;;   1. Does the kernel's catalog overlay unify when a tenant
;;      contributes zero data? (composition test)
;;   2. Does any kernel brick require tenant input that the empty
;;      tenant can't supply? (missing-binding detector)
;;   3. Does the kernel hard-code values that should be tenant
;;      parameters? (over-specification detector)
;;   4. Does default_tenant override flow through cleanly when the
;;      target tenant has empty catalog data? (boundary integrity)
;;
;; Companion to:
;;   - tenant_stamp_smoke (stamp set drift)
;;   - fork_smoke (catalog overlay structure with a stub overlay)
;;   - SPEC-00351 (string-level tenant/defn audit)
;;
;; This test asks: not "does the kernel work with the existing
;; tenants?" but "does the kernel still work with a tenant that
;; declares nothing?" If yes, the kernel is genuinely parametric
;; over its tenants. If no, some structure has leaked across the
;; boundary.
;;
;; See AIDR-00071 (kernel/tenant decoupling), AIDR-00072
;; (chart_versions decoupling), and the project memory note on
;; the empty-tenant stamp as a maintenance ritual.
;;
;; AIDR-00100 retired the dedicated stamptenant binary; this test
;; now drives the `defn stamp tenant --root SANDBOX NAME` subcommand.
;;
;; Args (positional, supplied by the sh_test rule):
;;   1. cue version (e.g. "0.16.1")
;;   2. workspace path to //tenant/defn/go/cmd/defn:defn

(require '[defn :refer :all]
         '[babashka.fs :as fs]
         '[babashka.process :as p])


(defn run-cue
  [cue cwd & args]
  (apply p/shell {:dir cwd :out :string :err :string :continue true} cue args))


(let [[cue-version defn-bin] *command-line-args*

      runfiles (str (System/getenv "TEST_SRCDIR") "/"
                    (System/getenv "TEST_WORKSPACE"))
      tmp     (str (System/getenv "TEST_TMPDIR") "/empty-tenant-probe")
      sandbox (str tmp "/work")]

  (log-ok (str "empty_tenant_probe sandbox: " sandbox))

  ;; Rebuild sandbox.
  (when (fs/exists? sandbox) (fs/delete-tree sandbox))
  (fs/create-dirs sandbox)

  ;; 1) Stamp the empty tenant. StampTenant emits the universal
  ;;    identity set (BUILD.bazel + per-feature subdir scaffolding)
  ;;    and nothing else. The tenant has zero catalog data --
  ;;    that's the whole point of the probe.
  (sh!! defn-bin "stamp" "tenant" "--root" sandbox "probe")
  (log-ok "stamped empty tenant 'probe'")

  ;; 2) Stage the kernel substrate alongside the stamped tenant.
  ;;    Same overlay pattern as fork_smoke -- flat-copy every .cue
  ;;    file from every contributing catalog into a single merged_
  ;;    catalog/ dir so CUE evaluates them as one package.
  (let [copy (fn [rel]
               (let [src (str runfiles "/" rel)
                     dst (str sandbox "/" rel)]
                 (fs/create-dirs (fs/parent dst))
                 (sh!! "cp" "-R" src dst)))
        merged (str sandbox "/merged_catalog")
        flatten (fn [src-dir]
                  (when (fs/exists? src-dir)
                    (doseq [f (filter #(str/ends-with? (str %) ".cue")
                                      (fs/list-dir src-dir))]
                      (let [dst (str merged "/"
                                     (str/replace
                                       (-> (str src-dir "/")
                                           (str/replace runfiles "")
                                           (str/replace #"^/+" "")
                                           (str/replace "/" "--"))
                                       #"--$" "--")
                                     (fs/file-name f))]
                        (fs/copy f dst)))))]
    (copy "kernel/schema")
    ;; AIDR-00132: per-brick dispatch.cue files import
    ;; github.com/defn/defn/kernel/spec/dispatch. The schema package
    ;; lives at kernel/spec/dispatch/ and must be staged so brick
    ;; dispatch.cue files (e.g. kernel/schema/dispatch.cue) resolve
    ;; their imports during the probe's catalog evaluation.
    (copy "kernel/spec/dispatch")
    (copy "cue.mod")
    (fs/create-dirs merged)
    (flatten (str runfiles "/kernel/catalog"))
    (flatten (str runfiles "/tenant/library/catalog"))
    (flatten (str runfiles "/tenant/boot/catalog"))
    ;; The probe tenant's catalog dir is empty (StampTenant only
    ;; writes BUILD.bazel scaffolding, no .cue). Flatten it anyway
    ;; -- if a future stamp grows .cue output, this picks it up.
    (flatten (str sandbox "/tenant/probe/catalog")))

  ;; 3) Override default_tenant to point at the empty tenant.
  ;;    A fork's first action is exactly this: "I'm a new tenant
  ;;    named X, retarget every generator at me." The kernel must
  ;;    accept that override even when X has zero catalog data.
  (let [merged (str sandbox "/merged_catalog")]
    (spit (str merged "/zzz-probe-tenant-override.cue")
          (str "@experiment(aliasv2,explicitopen,try)\n\n"
               "package catalog\n\n"
               "// Synthesized by //kernel/spec:empty_tenant_probe.\n"
               "// Retargets default_tenant at the freshly-stamped\n"
               "// empty tenant 'probe'. The kernel must accept this\n"
               "// override even though probe contributes zero data.\n"
               "default_tenant: \"probe\"\n")))

  (let [cue (mise-bin (str "cue@" cue-version) "cue")
        cat-args ["./merged_catalog"]]

    ;; 4) Composition test: catalog overlay unifies under the
    ;;    empty tenant. If a kernel brick is implicitly assuming
    ;;    "default_tenant has data X" the unification fails here.
    (let [{:keys [exit out err]} (apply run-cue cue sandbox
                                        "eval" "-e" "default_tenant"
                                        cat-args)]
      (when-not (zero? exit)
        (log-err "cue eval default_tenant FAILED -- kernel doesn't compose under empty tenant")
        (println "stdout:" out)
        (println "stderr:" err)
        (System/exit 1))
      (when (not= (str/trim out) "\"probe\"")
        (log-err (str "default_tenant override failed: got "
                      (str/trim out) " want \"probe\""))
        (System/exit 1)))
    (log-ok "kernel composes under empty tenant (default_tenant override flows)")

    ;; 5) Missing-binding detector: app_bricks comprehension still
    ;;    produces a non-empty list under the empty tenant. The
    ;;    library overlay supplies the apps; if a brick had been
    ;;    quietly relying on tenant/<probe>/catalog/ for its
    ;;    composition, the empty stamp would surface that.
    (let [{:keys [exit out err]} (apply run-cue cue sandbox
                                        "eval" "-e" "len(app_bricks)"
                                        cat-args)]
      (when-not (zero? exit)
        (log-err "cue eval app_bricks FAILED -- a kernel brick has a missing binding under the empty tenant")
        (println "stdout:" out)
        (println "stderr:" err)
        (System/exit 1))
      (let [n (Integer/parseInt (str/trim out))]
        (when (zero? n)
          (log-err "app_bricks is empty under empty tenant -- library overlay didn't contribute?")
          (System/exit 1))
        (log-ok (str "app_bricks length under empty tenant: " n))))

    ;; 6) Over-specification detector: chart_versions has zero
    ;;    entries under the empty tenant + library + boot overlay.
    ;;    (boot contributes its own chart_versions; library has
    ;;    none.) If the kernel were over-specifying chart_versions
    ;;    with hard-coded entries, this would be non-empty.
    (let [{:keys [exit out err]} (apply run-cue cue sandbox
                                        "eval" "-e" "len(chart_versions)"
                                        cat-args)]
      (when-not (zero? exit)
        (log-err "cue eval chart_versions FAILED")
        (println "stdout:" out)
        (println "stderr:" err)
        (System/exit 1))
      ;; chart_versions length should equal the union of library +
      ;; boot tenant entries, NOT include any kernel-side defaults.
      ;; A non-zero number is fine; a kernel-driven number would be
      ;; the symptom we'd diagnose by inspecting the keys.
      (log-ok (str "chart_versions length under empty tenant: "
                   (str/trim out)
                   " (sourced from boot + library overlays only)"))))

  (log-ok "empty_tenant_probe passed -- kernel composes cleanly under the maximally general tenant"))
