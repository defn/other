#!/usr/bin/env bbs
#MISE description= "artifact-fs wrapper -- deal in GitHub owner/repo shorthand"


;; artifact-fs wrapper. Takes GitHub owner/repo shorthand and manages the
;; local name transparently (replacing / with -- since artifact-fs names
;; cannot contain slashes).
;;
;; Usage:
;;   mise run afs add <owner/repo> [branch]    add + fetch + remount
;;   mise run afs rm <owner/repo>               unmount + remove-repo
;;   mise run afs status <owner/repo>           show status
;;   mise run afs fetch <owner/repo>            fetch remote updates
;;   mise run afs mount <owner/repo>            (re)mount
;;   mise run afs umount <owner/repo>           unmount (logical)
;;   mise run afs ls                            list all registered repos
;;   mise run afs path <owner/repo>             print local mount path
;;
;; Examples:
;;   mise run afs add cloudflare/workers-sdk
;;   mise run afs add kubernetes/kubernetes master
;;   ls "$(mise run afs path cloudflare/workers-sdk)"


(require '[defn :refer :all])


(def afs-mount-root "/home/ubuntu/afs")
(def afs-repo-root "/var/lib/artifact-fs/repos")


;; Configs applied to every new bare cache repo before the first fetch.
;; Why: these repos are read-only mirrors for FUSE mounts, so any background
;; or lazy work (gc, commit-graph, reflog, object explosion) is pure overhead
;; and was visibly stalling initial clones via "git gc --auto" repacks.
;; IMPORTANT: do NOT set fetch.showForcedUpdates=false here. Git emits a
;; warning on every subsequent invocation (including cat-file --batch-check),
;; and the artifact-fs daemon's batch parser trips on it ("exit status 128"),
;; falling back to zero-byte files. The other settings below are silent.
(def disable-lazy-git-config
  [["gc.auto" "0"]
   ["gc.autoPackLimit" "0"]
   ["gc.autoDetach" "false"]
   ["maintenance.auto" "false"]
   ["maintenance.strategy" "none"]
   ["fetch.writeCommitGraph" "false"]
   ["gc.writeCommitGraph" "false"]
   ["fetch.unpackLimit" "1"]
   ["transfer.unpackLimit" "1"]
   ["core.commitGraph" "false"]
   ["core.logAllRefUpdates" "false"]])


(defn git-dir
  [name]
  (str afs-repo-root "/" name "/git"))


(defn apply-disable-lazy-git-config!
  [name]
  (let [gd (git-dir name)]
    (doseq [[k v] disable-lazy-git-config]
      (sh!! "git" "-C" gd "config" k v))))


(defn to-local-name
  "Convert owner/repo to owner--repo (artifact-fs names cannot contain /)."
  [gh-name]
  (str/replace gh-name "/" "--"))


(defn to-remote
  "owner/repo -> https github clone URL."
  [gh-name]
  (str "https://github.com/" gh-name ".git"))


(defn mount-path
  [gh-name]
  (str afs-mount-root "/" (to-local-name gh-name)))


(defn require-name
  [gh-name subcommand]
  (when-not gh-name
    (println (str "afs " subcommand ": missing <owner/repo>"))
    (System/exit 1)))


(defn usage
  []
  (println "Usage: mise run afs <subcommand> [args]")
  (println)
  (println "Subcommands:")
  (println "  add <owner/repo> [branch]   add + fetch + remount (defaults branch=main)")
  (println "  rm <owner/repo>             unmount + remove-repo")
  (println "  status <owner/repo>         show repo status")
  (println "  fetch <owner/repo>          fetch remote updates")
  (println "  mount <owner/repo>          (re)mount")
  (println "  umount <owner/repo>         unmount (logical)")
  (println "  ls                          list all registered repos")
  (println "  path <owner/repo>           print local mount path")
  (System/exit 1))


(let [[subcommand gh-name & more] *command-line-args*
      name                        (when gh-name (to-local-name gh-name))
      remote                      (when gh-name (to-remote gh-name))]
  (case subcommand
    "add"
    (let [_      (require-name gh-name "add")
          branch (or (first more) "main")]
      (log-ok (str "adding " gh-name " (branch: " branch ")"))
      (sh!! "artifact-fs" "add-repo"
            "--name" name
            "--remote" remote
            "--branch" branch
            "--mount-root" afs-mount-root)
      (apply-disable-lazy-git-config! name)
      (sh!! "artifact-fs" "fetch" "--name" name)
      (sh!! "artifact-fs" "remount" "--name" name)
      (log-ok (str "mounted at " (mount-path gh-name))))

    "rm"
    (do
      (require-name gh-name "rm")
      (sh? "artifact-fs" "unmount" "--name" name)
      (sh!! "artifact-fs" "remove-repo" "--name" name)
      (log-ok (str "removed " gh-name)))

    "status"
    (do
      (require-name gh-name "status")
      (sh!! "artifact-fs" "status" "--name" name))

    "fetch"
    (do
      (require-name gh-name "fetch")
      (sh!! "artifact-fs" "fetch" "--name" name))

    "mount"
    (do
      (require-name gh-name "mount")
      (sh!! "artifact-fs" "remount" "--name" name))

    "umount"
    (do
      (require-name gh-name "umount")
      (sh!! "artifact-fs" "unmount" "--name" name))

    "ls"
    (sh!! "artifact-fs" "list-repos")

    "path"
    (do
      (require-name gh-name "path")
      (println (mount-path gh-name)))

    (usage)))
