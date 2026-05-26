#!/usr/bin/env bbs
;; Verify rendered kustomize YAML contains no Secret resources with data.
;; Empty Secrets (no data/stringData) are allowed -- they're chart stubs
;; that controllers populate at runtime (e.g. webhook TLS certs).
;; Usage: no-secrets-test.clj <rendered.yaml>

(require '[defn :refer :all])


(let [yaml-path (first *command-line-args*)
      content   (slurp yaml-path)
      ;; Split into YAML documents
      docs      (str/split content #"\n---\n")
      ;; Find Secrets that have data or stringData
      bad       (filter (fn [doc]
                          (and (str/includes? doc "kind: Secret")
                               (or (re-find #"(?m)^data:" doc)
                                   (re-find #"(?m)^stringData:" doc))))
                        docs)]
  (if (seq bad)
    (do
      (log-err (str "found " (count bad) " Secret resource(s) with data in rendered YAML"))
      (doseq [doc bad]
        (println (re-find #"(?m)^  name: .*" doc)))
      (exit 1))
    (log-ok "no Secret resources with data in rendered YAML")))
