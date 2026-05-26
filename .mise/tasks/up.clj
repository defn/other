#!/usr/bin/env bbs
#MISE description= "Start or create k3d cluster"

(require '[defn :refer :all])


;; Find k3d.yaml in the caller's directory (not the project root).
;; MISE_ORIGINAL_CWD is set by mise to the directory where `mise run` was invoked.
(let [cwd    (or (System/getenv "MISE_ORIGINAL_CWD") (System/getProperty "user.dir"))
      config (str cwd "/k3d.yaml")
      kube-dir (str cwd "/.kube")
      kubeconfig (str kube-dir "/config")]

  (when-not (fs/exists? config)
    (log-err (str "no k3d.yaml found in " cwd))
    (exit 1))

  ;; Ensure .kube directory exists
  (fs/create-dirs kube-dir)

  ;; Parse cluster name from the config
  (let [yaml-content (slurp config)
        cluster-name (second (re-find #"name:\s+(\S+)" yaml-content))]

    (if (sh? "k3d" "cluster" "get" cluster-name)

      ;; Cluster exists -- start it if stopped
      (do
        (log-ok (str "starting existing k3d cluster '" cluster-name "'"))
        (sh!! "k3d" "cluster" "start" cluster-name)

        ;; k3d injects host.k3d.internal into /etc/hosts on start, but
        ;; if the container was restarted outside k3d the entry may be
        ;; missing.  Verify it exists; fall back to the Docker gateway.
        (let [node-name (str "k3d-" cluster-name "-server-0")
              has-entry (sh? "docker" "exec" node-name
                             "grep" "-q" "host.k3d.internal" "/etc/hosts")]
          (if has-entry
            (log-ok (str "host.k3d.internal already in " node-name " /etc/hosts"))
            (let [gateway (str/trim (sh! "docker" "inspect" node-name
                                         "--format" "{{range .NetworkSettings.Networks}}{{.Gateway}}{{end}}"))]
              (when (seq gateway)
                (sh! "docker" "exec" node-name "sh" "-c"
                     (str "echo '" gateway " host.k3d.internal' >> /etc/hosts"))
                (log-ok (str "injected host.k3d.internal -> " gateway " in " node-name)))))))

      ;; Cluster does not exist -- create it
      (do
        (log-ok (str "creating k3d cluster '" cluster-name "'"))
        (sh!! "k3d" "cluster" "create"
              "--config" config
              "--kubeconfig-update-default=false")))

    ;; Write kubeconfig to local .kube/config
    (log-ok (str "writing kubeconfig to " kubeconfig))
    (spit kubeconfig (sh! "k3d" "kubeconfig" "get" cluster-name))
    (sh! "chmod" "600" kubeconfig)

    (log-ok (str "k3d cluster '" cluster-name "' is ready"))
    (log-ok (str "export KUBECONFIG=" kubeconfig))))
