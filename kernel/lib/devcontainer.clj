(ns devcontainer
  "Devcontainer lifecycle helpers -- shared module for the host-side
   initializeCommand, the container-side postStartCommand /
   postAttachCommand, and the macOS-manual dev-bootstrap mise task.

   Every function is idempotent. Re-invoking a function whose target
   state already holds is a silent no-op.

   Usage:
     (require '[defn :refer :all]
              '[devcontainer :as dc])"
  (:require
    [babashka.fs :as fs]
    [clj-yaml.core :as yaml]
    [clojure.string :as str]
    [defn :refer :all]))


;; Constants

(def edge-image "defn.dev/devcontainer/dev:edge")


(def compose-path "/home/ubuntu/m/.devcontainer/docker-compose.yml")


(def workspace-root "/home/ubuntu/m")


(def cert-dir "/home/ubuntu/m/kernel/gross")


(def manual-only #{"terraform-operator"})


(def sidecar-images
  [["defn.dev/devcontainer/registry"     "dev-registry"]
   ["defn.dev/devcontainer/redis"        "dev-redis"]
   ["defn.dev/devcontainer/postgres"     "dev-postgres"]
   ["defn.dev/devcontainer/bazel-remote" "dev-bazel-remote"]])


;; Host-side helpers

(defn check-edge-image!
  "Verify the edge image exists; fail fast with a clear message if not."
  []
  (when-not (sh? "docker" "image" "inspect" edge-image)
    (log-err (str edge-image " is not built"))
    (println "  Fix: run `mise run dev-edge` first")
    (exit 1)))


(defn ensure-sidecar-images!
  "Build any missing sidecar images via their dev-<name> mise task.
   With no args, ensures ALL sidecars (Linux devcontainer init flow);
   with a names list, ensures only those (macOS targeted bring-up).
   AIDR-00127 #4."
  ([] (ensure-sidecar-images! nil))
  ([only-names]
   (let [only-set (when (seq only-names) (set only-names))
         filtered (if only-set
                    (filter (fn [[image _task]] (only-set (last (str/split image #"/"))))
                            sidecar-images)
                    sidecar-images)]
     (doseq [[image task] filtered]
       (when-not (sh? "docker" "image" "inspect" image)
         (log-ok (str "missing " image " -- running mise run " task))
         (sh!! "mise" "run" task))))))


(defn ensure-registry-tls-certs-volume!
  "Create the registry-tls-certs docker volume, sync current certs
   from kernel/gross/ into it, and signal whether the registry needs
   a restart by returning :updated when the volume content changed
   (or :unchanged when the volume already had matching files).

   The registry serves the leaf cert (registry-cert.pem) signed by
   the CA (registry-ca.pem). The volume is mounted read-only at
   /certs in the registry container. If git's cert files diverge
   from the volume's files (e.g. operator ran gen-registry-cert
   while the registry was up), the registry keeps serving the OLD
   leaf -- ArgoCD then can't validate the chain because the CA in
   argocd-tls-certs-cm doesn't match the (stale) leaf the registry
   is serving. Returning :updated lets the caller (dev-bootstrap)
   force-recreate the registry container so it re-mounts the
   refreshed volume and serves the new leaf.

   See AIDR-00126 (cert split design) and AIDR-00127 #0 (the
   volume-vs-git skew that this function now defends against).
   Returns :updated, :unchanged, or :created (volume newly made)."
  []
  (let [vol-name   "registry-tls-certs"
        cert-paths [(str cert-dir "/registry-ca.pem")
                    (str cert-dir "/registry-cert.pem")
                    (str cert-dir "/registry-key.pem")]
        ;; Hash of the on-disk cert triple. We pin the same hash
        ;; into the volume as a sentinel; mismatch == volume is stale.
        git-hash   (str/trim (:out (sh!!? "sh" "-c"
                                          (str "cat " (str/join " " cert-paths)
                                               " | shasum -a 256 | cut -d' ' -f1"))))
        seed!      (fn []
                     (sh? "docker" "rm" "-f" "tmp-reg-certs")
                     (sh!! "docker" "create" "--name" "tmp-reg-certs"
                           "-v" (str vol-name ":/certs") "alpine")
                     (doseq [src cert-paths]
                       (sh!! "docker" "cp" src
                             (str "tmp-reg-certs:/certs/" (last (str/split src #"/")))))
                     (let [sentinel-tmp (str (fs/create-temp-file {:prefix "cert-sha-" :suffix ".txt"}))]
                       (spit sentinel-tmp git-hash)
                       (sh!! "docker" "cp" sentinel-tmp "tmp-reg-certs:/certs/.cert-sha256")
                       (fs/delete-if-exists sentinel-tmp))
                     (sh!! "docker" "rm" "tmp-reg-certs"))
        read-vol   (fn []
                     (sh? "docker" "rm" "-f" "tmp-reg-certs")
                     (sh!! "docker" "create" "--name" "tmp-reg-certs"
                           "-v" (str vol-name ":/certs:ro") "alpine")
                     (let [out-tmp (str (fs/create-temp-file {:prefix "cert-sha-vol-" :suffix ".txt"}))
                           result  (sh!!? "docker" "cp" "tmp-reg-certs:/certs/.cert-sha256" out-tmp)
                           h       (if (zero? (:exit result))
                                     (str/trim (slurp out-tmp))
                                     "")]
                       (fs/delete-if-exists out-tmp)
                       (sh!! "docker" "rm" "tmp-reg-certs")
                       h))]
    (cond
      (not (sh? "docker" "volume" "inspect" vol-name))
      (do
        (log-ok "creating docker volume for registry TLS certs")
        (sh!! "docker" "volume" "create" vol-name)
        (seed!)
        :created)

      :else
      (let [vol-hash (read-vol)]
        (cond
          (= vol-hash git-hash)
          (do
            (log-ok "registry TLS cert volume already matches kernel/gross/")
            :unchanged)

          :else
          (do
            (log-ok (str "registry TLS cert volume out of date (volume sha "
                         (if (empty? vol-hash) "<empty>" (subs vol-hash 0 (min 12 (count vol-hash))))
                         ", git sha " (subs git-hash 0 12) ") -- re-seeding"))
            (seed!)
            :updated))))))


;; Container-side helpers

(defn home-named-volume-mounts
  "Parse docker-compose.yml and return target paths under /home/ubuntu/
   that are backed by named volumes (not bind mounts)."
  ([] (home-named-volume-mounts compose-path))
  ([path]
   (let [compose (yaml/parse-string (slurp path))
         vols   (get-in compose [:services :dev :volumes])]
     (keep (fn [v]
             (let [[src tgt] (str/split v #":" 2)]
               (when (and tgt
                          (str/starts-with? tgt "/home/ubuntu/")
                          (not (str/starts-with? src "/"))
                          (not (str/starts-with? src ".")))
                 tgt)))
           vols))))


(defn fix-volume-ownership!
  "chown the named-volume mount points (not recursively) to the current
   user so the ubuntu user can write to them. Idempotent: a no-op when
   ownership is already correct."
  []
  (log-ok "fixing volume ownership")
  (let [user  (sh! "id" "-un")
        group (sh! "id" "-gn")
        owner (str user ":" group)]
    (doseq [m (home-named-volume-mounts)]
      (sh! "sudo" "chown" owner m))))


(defn chown-docker-socket!
  "Grant access to the docker socket if mounted (needed for dev-sync
   image builds)."
  []
  (when (fs/exists? "/var/run/docker.sock")
    (log-ok "chowning docker socket")
    (sh! "sudo" "chown" "ubuntu" "/var/run/docker.sock")))


(defn trust-workspace-mise-configs!
  "mise trust every mise.toml under the workspace root. mise trust state
   lives in ~/.local/state/mise, which is NOT a persistent named volume,
   so it resets on container rebuild."
  ([] (trust-workspace-mise-configs! workspace-root))
  ([root]
   (log-ok "trusting workspace mise configs")
   (doseq [cfg (->> (fs/glob root "**/mise.toml")
                    (map str)
                    sort)]
     (sh! "mise" "trust" cfg))))


(defn setup-bazelrc-user!
  "Copy the DEVCONTAINER-aware variant of .bazelrc.user; create
   ~/.cache/bazel-repo when in devcontainer."
  []
  (log-ok "setting up .bazelrc.user")
  (let [bazelrc-user    "/home/ubuntu/m/.bazelrc.user"
        in-devcontainer (System/getenv "DEVCONTAINER")
        variant         (if in-devcontainer
                          "/home/ubuntu/m/.bazelrc.user-devcontainer"
                          "/home/ubuntu/m/.bazelrc.user-default")]
    (when (fs/exists? bazelrc-user)
      (fs/delete bazelrc-user))
    (fs/copy variant bazelrc-user)
    (when in-devcontainer
      (fs/create-dirs "/home/ubuntu/.cache/bazel-repo"))))


(defn run-bootstrap-bazelrc!
  "Generate .bazelrc.workspace from on-disk paths via the pure-bash
   bootstrap script."
  []
  (log-ok "running m/bin/bootstrap-bazelrc")
  (sh! "/home/ubuntu/m/bin/bootstrap-bazelrc"))


(defn ensure-pitchfork-supervisor!
  "Start the pitchfork supervisor in its own session if not already
   running. setsid lets the supervisor survive the postAttachCommand
   shell exiting."
  []
  (log-ok "ensuring pitchfork supervisor")
  (let [bin    (mise-bin "pitchfork" "pitchfork")
        status (sh!!? {:dir "/home/ubuntu"} bin "supervisor" "status")]
    (when-not (zero? (:exit status))
      (log-ok "starting pitchfork supervisor via setsid")
      (sh!! {:dir "/home/ubuntu"} "setsid" bin "supervisor" "start"))))


(defn- pitchfork-daemons
  "Return the set of daemon names defined in ~/pitchfork.toml by
   matching [daemons.NAME] headers. Avoids pulling in a TOML parser."
  [toml-path]
  (->> (str/split-lines (slurp toml-path))
       (keep #(second (re-matches #"^\[daemons\.([^\]]+)\]\s*$" %)))
       set))


(defn start-pitchfork-services!
  "Start every daemon in ~/pitchfork.toml except those in manual-only."
  []
  (log-ok "starting pitchfork services")
  (let [bin      (mise-bin "pitchfork" "pitchfork")
        defined  (pitchfork-daemons "/home/ubuntu/pitchfork.toml")
        to-start (sort (remove manual-only defined))]
    (when (seq to-start)
      (apply sh!! {:dir "/home/ubuntu"} bin "start" "-f" to-start))))
