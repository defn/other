#!/usr/bin/env bbs
#MISE description= "Run tofu commands in the current directory"
#MISE dir= "{{cwd}}"


;; tf.clj -- single tofu task with subcommands.
;; Usage: mise run tf <subcommand>
;; Subcommands:
;;   init      -- tofu init -reconfigure
;;   plan      -- tofu plan -no-color -out .plan, tee to .plan.txt
;;   apply     -- tofu apply .plan
;;   changes   -- check .plan.txt for pending changes
;;   bootstrap -- first-time apply for new accounts via OrganizationAccountAccessRole

(require '[defn :refer :all])


(let [;; Resolve workspace root (m/) via git
      ws-root      (str (sh! "git" "rev-parse" "--show-toplevel") "/m")
      cue-bin      (mise-bin "cue" "cue")
      tofu-version (-> (sh!!? {:dir ws-root}
                              cue-bin "export" "-e" "versions.opentofu.version"
                              "--out" "text" "./kernel/schema")
                       :out str/trim)
      tofu-spec    (str "opentofu@" tofu-version)
      tofu-bin     (mise-bin tofu-spec "tofu")
      subcommand   (first *command-line-args*)]
  (case subcommand
    "init"
    (sh!! tofu-bin "init" "-reconfigure")

    "plan"
    (let [{:keys [exit out err]} (sh!!? tofu-bin "plan" "-no-color" "-out" ".plan")
          combined (str out "\n" err)]
      (spit ".plan.txt" combined)
      (println out)
      (when-not (str/blank? err) (binding [*out* *err*] (println err)))
      ;; Fail-fast hint: if we hit "Cannot assume IAM Role" on an
      ;; <org>-ops-terraform role, the account almost certainly hasn't
      ;; been bootstrapped yet. Point the user at the one-shot command.
      (when (and (not (zero? exit))
                 (str/includes? combined "Cannot assume IAM Role")
                 (str/includes? combined "-ops-terraform"))
        (let [cwd-path (or (System/getenv "MISE_ORIGINAL_CWD") (System/getProperty "user.dir"))
              acct-key (when-let [m (re-find #"tenant/defn/infra/org/([^/]+)/([^/]+)$" (str cwd-path))]
                         (str (nth m 1) "/" (nth m 2)))]
          (binding [*out* *err*]
            (println)
            (log-err "this account has no <org>-ops-terraform role yet.")
            (println "   The account was probably just created and needs bootstrap.")
            (if acct-key
              (println (str "   Run: defn hatch onboardacc " acct-key))
              (println "   Run: defn hatch onboardacc <org>/<name>")))))
      (when-not (zero? exit) (exit exit)))

    "apply"
    (sh!! tofu-bin "apply" ".plan")

    "changes"
    (if (fs/exists? ".plan.txt")
      (let [content (slurp ".plan.txt")]
        (if (str/includes? content "No changes")
          (log-ok "no changes pending")
          (do (log-err "changes pending")
              (exit 1))))
      (do (log-err ".plan.txt not found -- run 'mise run tf plan' first")
          (exit 1)))

    "bootstrap"
    ;; Bootstrap a new account by temporarily overriding the provider to use
    ;; OrganizationAccountAccessRole (trusted by the org management account).
    ;; Uses OpenTofu's native *_override.tf mechanism -- no file patching.
    ;; Override content defined in interface/aws/templates.cue (bootstrap_override_tf).
    (let [main-tf      (slurp "main.tf")
          match        (re-find #"arn:aws:iam::(\d+):role/(\w+)-ops-terraform" main-tf)
          _            (when-not match
                         (log-err "cannot parse assume_role ARN from main.tf")
                         (System/exit 1))
          acc-id       (nth match 1)
          org-name     (nth match 2)
          ;; Pull the cloudtrail-alias region out of main.tf so the
          ;; override block can pin the second provider to the same
          ;; region. The alias block looks like:
          ;;   provider "aws" {
          ;;     alias  = "cloudtrail"
          ;;     region = "us-east-2"
          ;; If the stack predates the cloudtrail alias, fall back to
          ;; the state region (the override is harmless on stacks that
          ;; do not declare the alias).
          alias-region (or (some-> (re-find #"alias\s*=\s*\"cloudtrail\"[^}]*?region\s*=\s*\"([^\"]+)\"" main-tf)
                                   second)
                           "us-east-1")
          template     (str ws-root "/interface/aws/templates.cue")
          state-json   (-> (sh!!? {:dir ws-root}
                                  cue-bin "export" "-e" "aws_state" "--out" "json"
                                  "./kernel/catalog")
                           :out str/trim)
          state        (parse-json state-json true)
          override     (-> (sh!!? cue-bin "export" "-e" "bootstrap_override_tf"
                                  "--out" "text"
                                  (str "-t" "org_name=" org-name)
                                  (str "-t" "account_id=" acc-id)
                                  (str "-t" "state_region=" (:region state))
                                  (str "-t" "region=" alias-region)
                                  template)
                           :out str/trim)]
      (spit "provider_override.tf" (str override "\n"))
      (try
        (log-ok (str "bootstrap: using " org-name "-org → OrganizationAccountAccessRole"))
        ;; Init only when .terraform/ is missing. The bootstrap override
        ;; only changes the provider assume_role (not backend, not
        ;; required_providers), which tofu re-reads on every plan/apply,
        ;; so an already-initialized dir does not need a re-init.
        (if (fs/exists? ".terraform")
          (log-ok "bootstrap: .terraform already present, skipping init")
          (sh!! tofu-bin "init"))
        (sh!! tofu-bin "apply" "-auto-approve")
        (log-ok "bootstrap complete -- removing override")
        (finally
          ;; Delete the override file; no re-init needed because
          ;; provider config changes are picked up on the next plan.
          (fs/delete-if-exists "provider_override.tf"))))

    ;; unknown
    (do (log-err (str "unknown subcommand: " subcommand))
        (println "usage: mise run tf <init|plan|apply|changes|bootstrap>")
        (exit 1))))
