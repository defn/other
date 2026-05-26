#!/usr/bin/env bbs
;; Runs on every editor attach (postAttachCommand). The volume +
;; socket chown calls are repeated from post-start.clj because
;; stacks brought up via `mise run dev-bootstrap` (macOS) bypass
;; postStartCommand; the functions are idempotent no-ops when
;; ownership is already correct.

(require '[defn :refer :all]
         '[devcontainer :as dc])


(dc/fix-volume-ownership!)
(dc/chown-docker-socket!)
(dc/ensure-pitchfork-supervisor!)
(dc/start-pitchfork-services!)


(log-ok "post-attach complete")
