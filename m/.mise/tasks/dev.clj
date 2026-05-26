#!/usr/bin/env bbs
#MISE description= "Launch VS Code devcontainer (auto-bootstraps missing images)"


;; dev -- single entry point for launching the devcontainer. Idempotent;
;; from a wiped-out Docker state, detects each missing piece and runs
;; the minimal set of build tasks before launching VS Code.
;;
;; Dependency order (each step gated on image presence -- skipped if
;; already built, so re-runs are fast):
;;
;;   1. external images       (dev-pull)        -- defn.dev/external/*
;;   2. base devcontainer     (dev-base)        -- defn.dev/devcontainer/dev:base
;;   3. edge devcontainer     (dev-edge)        -- defn.dev/devcontainer/dev:edge
;;   4. sidecars              (dev-{redis,postgres,bazel-remote,registry})
;;   5. registry-tls-certs volume seeded from kernel/gross/
;;   6. stop any running compose stack from a previous launch
;;   7. open VS Code on the devcontainer URI
;;
;; Force-rebuild paths (when you actually want fresh layers, not just
;; "make sure something's there"): dev-rebase, dev-base, dev-edge,
;; dev-{redis,postgres,bazel-remote,registry}.

(require '[defn :refer :all])


(defn hex-encode
  "Hex-encode a string for vscode-remote URI."
  [s]
  (apply str (map #(format "%02x" (int %)) s)))


(defn find-code
  "Find the VS Code binary. Prefers VS Code desktop, falls back to code-server."
  []
  (let [vscode-mac "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"]
    (cond
      ;; Inside VS Code terminal -- use the active instance's binary
      (and (System/getenv "VSCODE_GIT_ASKPASS_MAIN")
           (str/starts-with? (System/getenv "VSCODE_GIT_ASKPASS_MAIN") "/Applications/Visual"))
      (str (str/replace (System/getenv "VSCODE_GIT_ASKPASS_MAIN") #"extensions/.*" "") "bin/code")

      ;; VS Code desktop installed on macOS
      (fs/exists? vscode-mac) vscode-mac

      ;; Fallback
      :else "code-server")))


(defn image-present?
  "True if a local Docker image with the given tag exists."
  [tag]
  (sh? "docker" "image" "inspect" tag))


;; ---- 1. external images: dev-pull if any are missing ---------------------
;; Tag list mirrors oci_images in kernel/catalog/catalog.cue. dev-pull is
;; the source of truth; this list only has to detect "anything missing."
(let [external-tags ["defn.dev/external/ubuntu:noble"
                     "defn.dev/external/golang:1.24-bookworm"
                     "defn.dev/external/bazel-remote:latest"
                     "defn.dev/external/registry:2"]]
  (when (some (complement image-present?) external-tags)
    (log-ok "external images missing -- running mise run dev-pull")
    (sh!! "mise" "run" "dev-pull")))


;; ---- 2. base devcontainer ------------------------------------------------
(when-not (image-present? "defn.dev/devcontainer/dev:base")
  (log-ok "defn.dev/devcontainer/dev:base missing -- running mise run dev-base")
  (sh!! "mise" "run" "dev-base"))


;; ---- 3. edge devcontainer ------------------------------------------------
(when-not (image-present? "defn.dev/devcontainer/dev:edge")
  (log-ok "defn.dev/devcontainer/dev:edge missing -- running mise run dev-edge")
  (sh!! "mise" "run" "dev-edge"))


;; ---- 4. sidecar images ---------------------------------------------------
(doseq [[image task] [["defn.dev/devcontainer/redis"        "dev-redis"]
                      ["defn.dev/devcontainer/postgres"     "dev-postgres"]
                      ["defn.dev/devcontainer/bazel-remote" "dev-bazel-remote"]
                      ["defn.dev/devcontainer/registry"     "dev-registry"]]]
  (when-not (image-present? image)
    (log-ok (str image " missing -- running mise run " task))
    (sh!! "mise" "run" task)))


;; ---- 5. TLS certs volume -------------------------------------------------
;; Ensure the registry-tls-certs docker volume exists with current certs.
;; The volume is referenced by docker-compose.yml for the registry service.
;; This is idempotent: creates the volume only if missing, always refreshes certs.
(let [vol-name  "registry-tls-certs"
      cert-dir  (str (System/getProperty "user.dir") "/kernel/gross")]
  (when-not (sh? "docker" "volume" "inspect" vol-name)
    (log-ok "creating docker volume for registry TLS certs")
    (sh!! "docker" "volume" "create" vol-name))
  ;; Clean any leftover tmp container from a previous interrupted run so
  ;; this step is idempotent across crashes.
  (sh? "docker" "rm" "-f" "tmp-reg-certs")
  (sh!! "docker" "create" "--name" "tmp-reg-certs"
        "-v" (str vol-name ":/certs") "alpine")
  (sh!! "docker" "cp" (str cert-dir "/registry-ca.pem") "tmp-reg-certs:/certs/registry-ca.pem")
  (sh!! "docker" "cp" (str cert-dir "/registry-key.pem") "tmp-reg-certs:/certs/registry-key.pem")
  (sh!! "docker" "rm" "tmp-reg-certs"))


;; Shut down existing containers (preserve data volumes).
;; Check if any containers exist first to avoid the "no resource found" warning.
(let [containers (str/trim (sh! "docker" "compose" "-f" ".devcontainer/docker-compose.yml" "ps" "-q"))]
  (when-not (blank? containers)
    (log-ok "stopping devcontainer services")
    (sh!! "docker" "compose" "-f" ".devcontainer/docker-compose.yml" "down")))


;; The vscode-remote URI encodes the folder containing .devcontainer/
;; as a hex string. On macOS this is the only way to launch a devcontainer.
(let [folder (System/getProperty "user.dir")
      hex-folder (hex-encode folder)
      workspace "/home/ubuntu/m"
      uri (str "vscode-remote://dev-container+" hex-folder workspace)
      code-bin (find-code)
      token (gh-token)]
  (log-ok (str "opening devcontainer from " folder))
  (log-ok (str "using: " code-bin))
  (sh!! {:extra-env {"GITHUB_TOKEN" token}}
        code-bin "--folder-uri" uri))


(log-ok "done")
