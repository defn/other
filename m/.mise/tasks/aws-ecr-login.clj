#!/usr/bin/env bbs
#MISE description= "Authenticate crane to AWS public ECR via tenant auth.oci profile"


;; Authenticates the local crane/docker auth cache to AWS public ECR
;; using the tenant's auth.oci profile (defaults to auth.tofu when
;; oci is not declared). Tasks that pull from public ECR (e.g.
;; sync-mirrors) declare this as a depends-prerequisite so the
;; cached login is always fresh before the pull loop starts.
;;
;; Why: anonymous pulls from public ECR are throttled to ~1 req/s,
;; which causes flaky failures in sync-mirrors. Authenticated pulls
;; raise the limit substantially. See AIDR-00101.
;;
;; Logs in to BOTH endpoints AWS exposes for public ECR: the
;; canonical `public.ecr.aws` host and the alternate
;; `ecr-public.aws.com` host. crane's auth cache is keyed by host,
;; so both must be primed independently or pulls against the
;; non-cached host fall back to anonymous + rate-limit.
;;
;; Token cache: ~/.docker/config.json (or
;; ~/.config/containers/auth.json); valid 12h. Re-running this task
;; refreshes the cache.

(require '[defn :refer :all])


(def kernel-catalog "./kernel/catalog")


;; Both public ECR hostnames; crane caches auth per host.
(def ecr-hosts ["public.ecr.aws" "ecr-public.aws.com"])


(defn tenant-catalog-dir
  [tenant]
  (str "./tenant/" tenant "/catalog"))


(defn cue-export-string
  "Run cue export -e EXPR for a catalog dir and return the trimmed
   string value. cue emits JSON-encoded strings ('foo' becomes
   \"\\\"foo\\\"\"); strip the surrounding quotes."
  [expr catalog-dir]
  (let [raw (run-tool-quiet "cue" "export" "-e" expr "--out" "json" catalog-dir)
        s   (str/trim raw)]
    (if (and (str/starts-with? s "\"") (str/ends-with? s "\""))
      (subs s 1 (dec (count s)))
      s)))


(defn crane-login!
  "Authenticate crane to a single ECR public host using a pre-fetched
   ecr-public token. Exits the process on failure."
  [pw host]
  (let [r (sh!!? {:in pw}
                 "crane" "auth" "login"
                 "-u" "AWS"
                 "--password-stdin"
                 host)]
    (if (zero? (:exit r))
      (log-ok (str "crane authenticated to " host))
      (do
        (log-err (str "crane auth login failed for " host))
        (when-not (str/blank? (:err r))
          (println (:err r)))
        (exit 1)))))


(let [tenant  (cue-export-string "default_tenant" kernel-catalog)
      profile (cue-export-string "auth.oci" (tenant-catalog-dir tenant))]
  (log-ok (str "tenant=" tenant " profile=" profile))
  (let [pw (run-tool-quiet "aws" "--profile" profile
                           "ecr-public" "get-login-password"
                           "--region" "us-east-1")]
    (doseq [host ecr-hosts]
      (crane-login! pw host))))
