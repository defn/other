#!/usr/bin/env bbs
#MISE description= "Rename AWS account root emails to normalized pattern"
#MISE hide=true


;; rename-account-email -- update AWS account root emails via Account Management API.
;;
;; Usage:
;;   mise run rename-account-email plan            -- show what would change
;;   mise run rename-account-email apply           -- start email updates (sends OTP to new email)
;;   mise run rename-account-email confirm ACC OTP -- confirm with OTP code from email
;;   mise run rename-account-email status          -- check pending verifications
;;   mise run rename-account-email apply-catalog   -- update catalog/aws.cue after verification
;;
;; The normalized email pattern is: aws-ORGNAME--ACCOUNTNAME@defn.us
;;
;; Constraints:
;;   - Must be called from the org management account (via SSO profile)
;;   - Email change sends an OTP code to the NEW email address
;;   - OTP must be confirmed via `confirm` subcommand
;;   - Only processes accounts whose email doesn't match the target pattern
;;
;; Flow:
;;   1. `plan` to review changes
;;   2. `apply` to start updates (sends OTP to new email addresses)
;;   3. `confirm <account-key> <otp>` for each OTP received
;;   4. `status` to verify all confirmed
;;   5. `apply-catalog` to update catalog/aws.cue with new emails

(require '[defn :refer :all])


(def email-domain "defn.us")


(defn target-email
  "Compute the normalized email for an account."
  [org-name account-name]
  (str "aws-" org-name "--" account-name "@" email-domain))


(defn load-accounts
  "Load aws_accounts and aws_orgs from CUE catalog."
  []
  (let [cue-bin   (mise-bin "cue" "cue")
        accs-json (-> (sh!!? cue-bin "export" "-e" "aws_accounts" "--out" "json" "./kernel/catalog")
                      :out str/trim)
        orgs-json (-> (sh!!? cue-bin "export" "-e" "aws_orgs" "--out" "json" "./kernel/catalog")
                      :out str/trim)]
    {:accounts (parse-json accs-json true)
     :orgs     (parse-json orgs-json true)}))


(defn compute-changes
  "Return list of {:key :org :name :id :current-email :target-email} for accounts
   whose email doesn't match the target pattern."
  [{:keys [accounts]}]
  (->> accounts
       (map (fn [[acc-key acc]]
              (let [org-name     (:org acc)
                    account-name (:name acc)
                    current      (:email acc)
                    target       (target-email org-name account-name)]
                {:key           (name acc-key)
                 :org           org-name
                 :name          account-name
                 :id            (:id acc)
                 :current-email current
                 :target-email  target
                 :needs-change  (not= current target)})))
       (filter :needs-change)
       (sort-by :key)
       vec))


(defn org-profile
  "Return the SSO profile name for an org's management account."
  [org-name]
  (str org-name "-org"))


(defn find-account
  "Look up account by key from loaded data."
  [data acc-key]
  (let [acc (get (:accounts data) (keyword acc-key))]
    (when acc
      {:key  acc-key
       :org  (:org acc)
       :name (:name acc)
       :id   (:id acc)})))


(let [subcommand (first *command-line-args*)
      ;; Optional filter: org name or account key
      filter-arg (second *command-line-args*)]
  (case subcommand
    "plan"
    (let [data    (load-accounts)
          changes (cond->> (compute-changes data)
                    filter-arg (filter #(or (= (:org %) filter-arg)
                                            (= (:key %) filter-arg))))]
      (if (empty? changes)
        (log-ok "all emails already match target pattern")
        (do
          (println (format "%-25s %-35s → %s" "ACCOUNT" "CURRENT" "TARGET"))
          (println (apply str (repeat 90 "-")))
          (doseq [c changes]
            (println (format "%-25s %-35s → %s"
                             (:key c) (:current-email c) (:target-email c))))
          (println)
          (println (str (count changes) " account(s) to update")))))

    "apply"
    (let [data    (load-accounts)
          changes (cond->> (compute-changes data)
                    filter-arg (filter #(or (= (:org %) filter-arg)
                                            (= (:key %) filter-arg))))
          by-org  (group-by :org changes)]
      (if (empty? changes)
        (log-ok "all emails already match target pattern")
        (doseq [[org-name org-changes] (sort-by key by-org)]
          (let [profile (org-profile org-name)]
            (println (str "=== " org-name " (via " profile ") ==="))
            (doseq [c org-changes]
              (let [result (sh!!? "aws" "account" "start-primary-email-update"
                                  "--profile" profile
                                  "--account-id" (:id c)
                                  "--primary-email" (:target-email c)
                                  "--region" "us-east-1"
                                  "--output" "json")]
                (if (zero? (:exit result))
                  (let [resp (parse-json (:out result) true)]
                    (log-ok (str (:key c) " → " (:target-email c) " [" (:Status resp) "]")))
                  (log-err (str (:key c) " FAILED: " (str/trim (:err result)))))))
            (println)))))

    "confirm"
    ;; Confirm an email update with the OTP code received at the new address.
    ;; Usage: mise run rename-account-email confirm <account-key> <otp>
    (let [acc-key  filter-arg
          otp      (nth *command-line-args* 2 nil)
          _        (when (or (nil? acc-key) (nil? otp))
                     (log-err "usage: mise run rename-account-email confirm <account-key> <otp>")
                     (System/exit 1))
          data     (load-accounts)
          acc-info (find-account data acc-key)
          _        (when-not acc-info
                     (log-err (str "account not found: " acc-key))
                     (System/exit 1))
          profile  (org-profile (:org acc-info))
          target   (target-email (:org acc-info) (:name acc-info))
          result   (sh!!? "aws" "account" "accept-primary-email-update"
                          "--profile" profile
                          "--account-id" (:id acc-info)
                          "--otp" otp
                          "--primary-email" target
                          "--region" "us-east-1"
                          "--output" "json")]
      (if (zero? (:exit result))
        (let [resp (parse-json (:out result) true)]
          (log-ok (str acc-key " confirmed → " target " [" (:Status resp) "]")))
        (log-err (str acc-key " confirm FAILED: " (str/trim (:err result))))))

    "status"
    (let [data    (load-accounts)
          changes (cond->> (compute-changes data)
                    filter-arg (filter #(or (= (:org %) filter-arg)
                                            (= (:key %) filter-arg))))
          by-org  (group-by :org changes)]
      (if (empty? changes)
        (log-ok "all emails already match target pattern")
        (doseq [[org-name org-changes] (sort-by key by-org)]
          (let [profile (org-profile org-name)]
            (println (str "=== " org-name " ==="))
            (doseq [c org-changes]
              (let [result (sh!!? "aws" "account" "get-primary-email"
                                  "--profile" profile
                                  "--account-id" (:id c)
                                  "--region" "us-east-1"
                                  "--output" "json")]
                (if (zero? (:exit result))
                  (let [resp    (parse-json (:out result) true)
                        current (:PrimaryEmail resp)
                        done?   (= current (:target-email c))]
                    (if done?
                      (log-ok (str (:key c) " ✓ " current))
                      (println (str "  ⏳ " (:key c) " still " current
                                    " (target: " (:target-email c) ")"))))
                  (log-err (str (:key c) " check failed: " (str/trim (:err result)))))))
            (println)))))

    "apply-catalog"
    ;; Update catalog/aws.cue email fields for verified accounts.
    ;; Only updates accounts whose email has actually changed on AWS side.
    (let [data     (load-accounts)
          changes  (cond->> (compute-changes data)
                     filter-arg (filter #(or (= (:org %) filter-arg)
                                             (= (:key %) filter-arg))))
          by-org   (group-by :org changes)
          catalog  (slurp "catalog/aws.cue")
          updated  (atom catalog)
          applied  (atom 0)]
      (doseq [[org-name org-changes] (sort-by key by-org)]
        (let [profile (org-profile org-name)]
          (doseq [c org-changes]
            (let [result (sh!!? "aws" "account" "get-primary-email"
                                "--profile" profile
                                "--account-id" (:id c)
                                "--region" "us-east-1"
                                "--output" "json")]
              (when (zero? (:exit result))
                (let [resp    (parse-json (:out result) true)
                      current (:PrimaryEmail resp)]
                  (when (= current (:target-email c))
                    ;; Replace in catalog
                    (swap! updated str/replace
                           (str "email: \"" (:current-email c) "\"")
                           (str "email: \"" (:target-email c) "\""))
                    (swap! applied inc)
                    (log-ok (str (:key c) " → " (:target-email c))))))))))
      (if (pos? @applied)
        (do
          (spit "catalog/aws.cue" @updated)
          (log-ok (str "updated " @applied " email(s) in catalog/aws.cue"))
          (println "run: mise run gen && mise run check -- --ignore-unclean-workarea"))
        (log-ok "no verified changes to apply")))

    ;; unknown
    (do (log-err (str "unknown subcommand: " subcommand))
        (println "usage: mise run rename-account-email <plan|apply|confirm|status|apply-catalog> [org-or-account]")
        (System/exit 1))))
