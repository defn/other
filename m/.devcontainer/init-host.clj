#!/usr/bin/env bbs
;; Host-side initialization -- runs on the developer's machine
;; before the devcontainer starts. Verifies the edge image is
;; built, builds any missing sidecar images, and ensures the
;; registry-tls-certs docker volume is populated. The same
;; sequence is invoked by `mise run dev-bootstrap` (macOS path).

(require '[defn :refer :all]
         '[devcontainer :as dc])


(dc/check-edge-image!)
(dc/ensure-sidecar-images!)
(dc/ensure-registry-tls-certs-volume!)


(log-ok "host init complete")
