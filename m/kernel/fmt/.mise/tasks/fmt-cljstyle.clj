#!/usr/bin/env bbs
#MISE hide=true
#MISE description= "Run cljstyle formatter (JAR wrapper, downloads on first use)"

(require '[defn :refer :all])


(let [version (or (System/getenv "CLJSTYLE_VERSION") "0.17.642")
      cache-dir (str (System/getenv "HOME") "/.cache/cljstyle")
      jar (str cache-dir "/cljstyle-" version ".jar")
      url (str "https://github.com/greglook/cljstyle/releases/download/"
               version "/cljstyle-" version ".jar")
      java-ver (or (System/getenv "JAVA_VERSION") "graalvm-community-25.0.2")
      java-bin (mise-bin (str "java@" java-ver) "java")]
  (when-not (fs/exists? jar)
    (fs/create-dirs cache-dir)
    (log-ok (str "downloading cljstyle " version))
    ;; Download to a unique temp then atomic-rename. Bazel runs many .clj
    ;; fmt tests in PARALLEL; on a cold cache they would otherwise all
    ;; `curl -o jar` to the same path at once, interleaving writes / exposing
    ;; a partial jar to a concurrent `java -jar` -> non-deterministic Exit 1.
    ;; With per-process temp + atomic rename the jar is only ever observed
    ;; complete. Surfaced as a flaky cljstyle fmt failure on defn/other CI
    ;; (cold cache); the warm host -- and check-fork sharing its ~/.cache --
    ;; hid it. See AIREF-00019.
    (let [tmp (str jar "." (random-uuid) ".tmp")]
      (sh! "curl" "-fsSL" "-o" tmp url)
      (fs/move tmp jar {:replace-existing true :atomic-move true})))
  (apply sh!! java-bin "-jar" jar *command-line-args*))
