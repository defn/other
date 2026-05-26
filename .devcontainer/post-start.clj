#!/usr/bin/env bbs
;; Container-side initialization -- runs once after the container
;; starts. Phases run in dependency order: ownership fixes first
;; (so subsequent file writes succeed), then mise trust, then
;; .bazelrc.user setup, then bootstrap-bazelrc. fix-volume-ownership!
;; and chown-docker-socket! are also called from post-attach.clj
;; to handle stacks brought up via `mise run dev-bootstrap` (macOS),
;; which bypasses postStartCommand entirely; the calls are
;; idempotent no-ops when ownership is already correct.

(require '[defn :refer :all]
         '[devcontainer :as dc])


(dc/fix-volume-ownership!)
(dc/chown-docker-socket!)
(dc/trust-workspace-mise-configs!)
(dc/setup-bazelrc-user!)
(dc/run-bootstrap-bazelrc!)


(log-ok "post-start complete")
