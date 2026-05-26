#!/usr/bin/env bbs
#MISE description= "Stop k3d cluster"

(require '[defn :refer :all])


;; Find k3d.yaml in the caller's directory.
(let [cwd    (or (System/getenv "MISE_ORIGINAL_CWD") (System/getProperty "user.dir"))
      config (str cwd "/k3d.yaml")]

  (when-not (fs/exists? config)
    (log-err (str "no k3d.yaml found in " cwd))
    (exit 1))

  (let [yaml-content (slurp config)
        cluster-name (second (re-find #"name:\s+(\S+)" yaml-content))]

    (if (sh? "k3d" "cluster" "get" cluster-name)
      (do
        (log-ok (str "stopping k3d cluster '" cluster-name "'"))
        (sh!! "k3d" "cluster" "stop" cluster-name)
        (log-ok (str "k3d cluster '" cluster-name "' stopped")))
      (log-ok (str "k3d cluster '" cluster-name "' does not exist")))))
