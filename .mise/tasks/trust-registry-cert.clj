#!/usr/bin/env bbs
#MISE description= "Install registry CA into Docker daemon trust path (idempotent)"


;; trust-registry-cert -- copies kernel/gross/registry-ca.pem to the
;; per-host docker certs.d path so `docker push localhost:5000/...`
;; trusts the leaf cert served by the registry. Idempotent: skips
;; when target already matches source byte-for-byte.
;;
;; Path: ~/.docker/certs.d/<host:port>/ca.crt is honored by both
;; macOS Docker Desktop and Linux Docker daemons. We register both
;; addresses operators reach the registry by:
;;   - localhost:5000        (dev-push, manual docker push)
;;   - host.k3d.internal:5000 (k3d cluster pulls; uses
;;                             insecure_skip_verify but cert trust
;;                             still helps for tooling that hits
;;                             this address)
;;
;; Tools that DON'T use docker's certs.d:
;;   - crane: needs SSL_CERT_FILE or system keychain. Use --insecure
;;     for localhost (already in sync-mirrors.clj).
;;   - helm: same. Use --insecure-skip-tls-verify (already in
;;     helm-publish.clj).
;; These tools all communicate with localhost only, so skipping
;; verification on those connections is the pragmatic call.
;;
;; This task is invoked at the top of dev-bootstrap; operators
;; don't normally run it directly.

(require '[defn :refer :all]
         '[babashka.fs :as fs])


(def ca-pem "kernel/gross/registry-ca.pem")


(def docker-trust-dirs
  ;; Each entry becomes ~/.docker/certs.d/<dir>/ca.crt.
  ["localhost:5000"
   "host.k3d.internal:5000"])


(when-not (fs/exists? ca-pem)
  (log-err (str ca-pem " missing -- run `mise run gen-registry-cert` first"))
  (System/exit 1))


(let [home  (System/getenv "HOME")
      src   (slurp ca-pem)
      total (count docker-trust-dirs)]
  (loop [[d & rest] docker-trust-dirs
         changed   0]
    (let [dir-path  (str home "/.docker/certs.d/" d)
          dst       (str dir-path "/ca.crt")
          dst-bytes (when (fs/exists? dst) (slurp dst))]
      (cond
        (= src dst-bytes)
        (do
          (log-ok (str d ": ca.crt already matches"))
          (if (seq rest) (recur rest changed) changed))

        :else
        (do
          (fs/create-dirs dir-path)
          (spit dst src)
          (log-ok (str d ": installed ca.crt"))
          (if (seq rest) (recur rest (inc changed)) (inc changed))))))

  (log-ok (str "trust-registry-cert: " total " entries up to date")))
