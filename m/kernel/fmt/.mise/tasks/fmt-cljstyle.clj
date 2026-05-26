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
  ;; Parallel-safe download (atomic rename + retry) shared with
  ;; fmt-check.clj and the gjf tasks -- single fix point in defn lib so
  ;; the cold-cache fmt-flake hardening can't drift across copies again
  ;; (AIDR-00150; the earlier bc4fccce fix lived only here, not on the
  ;; fmt-check.clj path bazel actually runs). See AIREF-00019.
  (download-jar! jar url)
  (apply sh!! java-bin "-jar" jar *command-line-args*))
