#!/usr/bin/env bbs
#MISE description= "Generate registry CA + leaf TLS cert (idempotent)"


;; gen-registry-cert -- mints the registry CA + leaf TLS cert under
;; kernel/gross/, using openssl. Idempotent: skips when the leaf
;; cert exists and is valid >30 days from expiry.
;;
;; Outputs:
;;   kernel/gross/registry-ca.pem      -- CA cert (tracked; trust anchor for clients)
;;   kernel/gross/registry-cert.pem    -- leaf TLS cert (tracked; served by registry)
;;   kernel/gross/registry-key.pem     -- leaf private key (tracked; loaded by registry)
;;   kernel/gross/registry-ca-key.pem  -- CA private key (gitignored; only used here)
;;
;; Why a CA + leaf split rather than a single self-signed cert:
;; Go's x509 strict mode (used by crane, helm, and macOS Apple TLS
;; policy) rejects a self-signed cert with CA:TRUE being served as
;; the TLS leaf. The compliant shape is "CA signs leaf; leaf is
;; the server cert." See AIDR-00126.
;;
;; Validity is 825 days (max Apple TLS policy allows for certs
;; issued after 2020-09-01). Longer validity is rejected by Go on
;; macOS as "not standards compliant" even when the chain and
;; extensions are otherwise correct.
;;
;; This task is invoked at the top of dev-bootstrap; operators
;; don't normally run it directly. Re-run after a manual delete to
;; rotate. The 30-day expiry-skew check below means any pass within
;; 30 days of expiry triggers a regen.

(require '[defn :refer :all]
         '[babashka.fs :as fs])


(def gross-dir "kernel/gross")
(def ca-cert    (str gross-dir "/registry-ca.pem"))
(def ca-key     (str gross-dir "/registry-ca-key.pem"))
(def leaf-cert  (str gross-dir "/registry-cert.pem"))
(def leaf-key   (str gross-dir "/registry-key.pem"))


(defn- min-days-remaining
  "Days until the cert expires; -1 if openssl can't read it."
  [pem-path]
  (if-not (fs/exists? pem-path)
    -1
    (let [{:keys [exit out]} (sh!!? "openssl" "x509" "-in" pem-path
                                    "-noout" "-checkend" "2592000")] ; 30 days in seconds
      (if (zero? exit) 31 0))))


(when (and (fs/exists? leaf-cert)
           (fs/exists? leaf-key)
           (fs/exists? ca-cert)
           (pos? (min-days-remaining leaf-cert))
           (pos? (min-days-remaining ca-cert)))
  (log-ok "registry cert pair already valid -- skipping regen")
  (System/exit 0))


(log-ok "generating registry CA + leaf TLS cert under kernel/gross/")


;; Use a temp dir for openssl scratch (CSR + config); the only
;; long-lived outputs are the four .pem files above.
(let [tmp (str (fs/create-temp-dir {:prefix "gen-registry-cert-"}))]
  (try
    (let [ca-cnf  (str tmp "/ca.cnf")
          ext-cnf (str tmp "/ext.cnf")
          csr     (str tmp "/leaf.csr")
          ca-srl  (str tmp "/ca.srl")]

      ;; CA config: self-signed, CA:TRUE, 10y validity.
      (spit ca-cnf
            (str "[req]\n"
                 "distinguished_name = dn\n"
                 "x509_extensions = ext\n"
                 "prompt = no\n"
                 "[dn]\n"
                 "CN = defn registry CA\n"
                 "[ext]\n"
                 "basicConstraints = critical, CA:TRUE\n"
                 "keyUsage = critical, keyCertSign, cRLSign\n"
                 "subjectKeyIdentifier = hash\n"))

      ;; Leaf extensions: NOT a CA, serverAuth EKU, full SAN list.
      (spit ext-cnf
            (str "basicConstraints = critical, CA:FALSE\n"
                 "keyUsage = critical, digitalSignature, keyEncipherment\n"
                 "extendedKeyUsage = serverAuth\n"
                 "subjectKeyIdentifier = hash\n"
                 "authorityKeyIdentifier = keyid:always\n"
                 "subjectAltName = @alt\n"
                 "[alt]\n"
                 "DNS.1 = host.k3d.internal\n"
                 "DNS.2 = localhost\n"
                 "IP.1 = 127.0.0.1\n"))

      ;; CA: 4096-bit key + self-signed cert, 10y.
      (sh!! "openssl" "req" "-x509" "-new" "-newkey" "rsa:4096"
            "-keyout" ca-key "-out" ca-cert
            "-days" "825" "-sha256" "-nodes"
            "-config" ca-cnf)

      ;; Leaf: 4096-bit key + CSR + cert signed by CA, 10y.
      (sh!! "openssl" "req" "-new" "-newkey" "rsa:4096"
            "-keyout" leaf-key "-out" csr
            "-nodes" "-subj" "/CN=registry")

      ;; -CAserial points the .srl file at the temp dir so it
      ;; doesn't pollute kernel/gross/ (the .srl is openssl's
      ;; signed-cert serial-number tracker; safe to discard since
      ;; we always start from a fresh CA on rotation).
      (sh!! "openssl" "x509" "-req" "-in" csr
            "-CA" ca-cert "-CAkey" ca-key "-CAserial" ca-srl "-CAcreateserial"
            "-out" leaf-cert "-days" "825" "-sha256"
            "-extfile" ext-cnf)

      ;; Permissions: 0644 for all four files. The brick manifest
      ;; expects _#reg (0644) for tracked .pem files; openssl's
      ;; default umask varies. Normalize so manifest validation
      ;; passes.
      (sh!! "chmod" "0644" leaf-key ca-key leaf-cert ca-cert))

    (finally
      (fs/delete-tree tmp))))


(log-ok (str "wrote " ca-cert " (CA), " leaf-cert " (leaf), keys"))
