#!/usr/bin/env bbs
#MISE description= "macOS: bring up registry sidecar so dev-push / k3d create can reach localhost:5000"


;; macOS-only path. Linux uses VS Code's initializeCommand
;; (.devcontainer/init-host.clj) which brings up the full
;; devcontainer stack; macOS operators don't enter the dev
;; container, so this task targets only what `mise run dev-push`
;; and `defn cluster create` need: the local OCI registry.
;;
;; Skipped vs. the Linux devcontainer init:
;;   - dev:edge image check (operator never enters the dev
;;     container on macOS)
;;   - postgres / redis / bazel-remote sidecar builds (only
;;     used inside the devcontainer)
;;   - `docker compose up -d` of the full stack (only registry
;;     comes up here)
;; AIDR-00127 #4 + #5.

(require '[defn :refer :all]
         '[devcontainer :as dc])


;; Cert generation must run BEFORE the registry-tls-certs volume
;; gets seeded -- ensure-registry-tls-certs-volume! copies the
;; current files in kernel/gross/ into the volume. Both tasks
;; below are idempotent (no-op when already valid / matching).
(sh!! "mise" "run" "gen-registry-cert")
(sh!! "mise" "run" "trust-registry-cert")


;; Build only the registry image if missing -- skip edge / postgres
;; / redis / bazel-remote on macOS host.
(dc/ensure-sidecar-images! ["registry"])


(def cert-volume-state (dc/ensure-registry-tls-certs-volume!))


(log-ok "bringing up registry sidecar")


;; Bring up ONLY the registry service (not the full stack). Without
;; the macOS override the registry's `network_mode: service:dev`
;; would require dev to start first; the override puts registry on
;; its own bridge network, so it can come up standalone.
;;
;; If the cert volume was re-seeded (or freshly created), force-
;; recreate the registry container so it re-mounts the volume and
;; serves the fresh leaf. Closes AIDR-00127 #0 (volume-vs-git skew
;; that left ArgoCD unable to validate the chain).
(let [base-args ["docker" "compose"
                 "-f" ".devcontainer/docker-compose.yml"
                 "-f" ".devcontainer/docker-compose.macos.yml"]
      up-args   (if (contains? #{:updated :created} cert-volume-state)
                  ["up" "-d" "--force-recreate" "registry"]
                  ["up" "-d" "registry"])]
  (when (contains? #{:updated :created} cert-volume-state)
    (log-ok (str "cert volume " (name cert-volume-state)
                 " -- force-recreating registry to reload certs")))
  (apply sh!! (concat base-args up-args)))


(log-ok "dev-bootstrap complete -- registry is up at localhost:5000")
