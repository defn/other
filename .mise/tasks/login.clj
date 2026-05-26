#!/usr/bin/env bbs
#MISE description= "Login to external services (GitHub, AWS SSO, etc.)"

(require '[defn :refer :all])


(def kernel-catalog "./kernel/catalog")


(defn tenant-catalog-dir
  [tenant]
  (str "./tenant/" tenant "/catalog"))


(defn cue-export-string
  "Run cue export -e EXPR for a catalog dir and return the trimmed
   string value. cue emits JSON-encoded strings; strip the surrounding
   quotes."
  [expr catalog-dir]
  (let [raw (run-tool-quiet "cue" "export" "-e" expr "--out" "json" catalog-dir)
        s   (str/trim raw)]
    (if (and (str/starts-with? s "\"") (str/ends-with? s "\""))
      (subs s 1 (dec (count s)))
      s)))


;; GitHub CLI
(if (gh-logged-in?)
  (log-ok "gh: already authenticated")
  (do
    (log-ok "gh: logging in")
    ;; Pass flags so gh skips the "Where do you use GitHub?" and
    ;; "preferred git protocol" prompts. --web triggers the device
    ;; flow; gh copies the one-time code to the system clipboard and
    ;; opens the verification URL in the browser after a single Enter.
    (sh!! "gh" "auth" "login"
          "--hostname" "github.com"
          "--git-protocol" "https"
          "--web")))


;; macOS: erase any stale github.com credential cached in osxkeychain.
;; Git's credential helper chain on macOS includes both osxkeychain
;; (global) and `gh auth git-credential` (per-host override). The
;; osxkeychain copy can be older than gh's fresh token; git push
;; consults osxkeychain first, gets a 401, and only sometimes invokes
;; the reject step that would clear the entry. Erasing proactively
;; here means the next git push falls through to the gh helper and
;; gets the fresh token. The osxkeychain re-caches that token on
;; the next successful push automatically. AIDR-00127 #6.
(when (str/includes? (System/getProperty "os.name") "Mac")
  (let [{:keys [exit]} (sh!!? {:in "host=github.com\nprotocol=https\n\n"}
                              "git" "credential-osxkeychain" "erase")]
    (if (zero? exit)
      (log-ok "github.com osxkeychain entry cleared (gh helper now sole source)")
      (log-ok "github.com osxkeychain erase exited non-zero (no stale entry?)"))))


;; AWS SSO -- master tofu profile from the tenant catalog (auth.tofu).
;; A fork retargets via tenant/<name>/catalog/auth.cue without editing
;; this script. Per AIDR-00101.
(let [tenant  (cue-export-string "default_tenant" kernel-catalog)
      profile (cue-export-string "auth.tofu" (tenant-catalog-dir tenant))]
  (if (aws-sso-valid? profile)
    (log-ok (str "aws: SSO session valid for profile " profile))
    (do
      (log-ok (str "aws: SSO session expired or missing -- running aws sso login --profile " profile))
      (sh!! "aws" "sso" "login" "--profile" profile))))


(log-ok "all logins complete")
