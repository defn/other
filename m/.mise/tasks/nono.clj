#!/usr/bin/env bbs
#MISE description= "Run a command inside a named nono sandbox profile (profiles live in m/nono/)"

(require '[defn :refer :all])
(require '[babashka.fs :as fs])
(require '[babashka.process :as p])


;; Usage: mise run nono -- <profile> <command> [args...]
;;
;; Profiles are JSON files under m/nono/<profile>.json.
;; The sandbox workdir is set to the current directory so the profile's
;; workdir.access grant applies there.
;;
;; Examples:
;;   mise run nono -- npm npm install
;;   mise run nono -- npm npm ci


(let [[profile & cmd] *command-line-args*]
  (when (nil? profile)
    (binding [*out* *err*]
      (println "usage: mise run nono -- <profile> <command> [args...]"))
    (System/exit 1))
  (when (empty? cmd)
    (binding [*out* *err*]
      (println "usage: mise run nono -- <profile> <command> [args...]"))
    (System/exit 1))

  (let [profile-path (str (System/getProperty "user.dir") "/nono/" profile ".json")]
    (when-not (fs/exists? profile-path)
      (binding [*out* *err*]
        (println (str "nono: profile not found: " profile-path)))
      (System/exit 1))

    ;; --silent suppresses all nono output (banner, warnings, "does not exist"
    ;; lines) without piping stdout, so the full TTY is inherited and
    ;; interactive commands work correctly.
    (let [proc (apply p/process
                      {:in :inherit :out :inherit :err :inherit}
                      "mise" "x" "--" "nono" "run"
                      "--profile" profile-path
                      "--workdir" (System/getProperty "user.dir")
                      "--allow-cwd"
                      "--silent"
                      "--"
                      cmd)]
      (System/exit (:exit @proc)))))
