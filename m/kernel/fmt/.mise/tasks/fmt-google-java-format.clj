#!/usr/bin/env bbs
#MISE hide=true
#MISE description= "Run google-java-format (JAR wrapper, downloads on first use)"

(require '[defn :refer :all])


(let [version (or (System/getenv "GOOGLE_JAVA_FORMAT_VERSION") "1.35.0")
      cache-dir (str (System/getenv "HOME") "/.cache/google-java-format")
      jar (str cache-dir "/google-java-format-" version "-all-deps.jar")
      url (str "https://github.com/google/google-java-format/releases/download/v"
               version "/google-java-format-" version "-all-deps.jar")
      java-ver (or (System/getenv "JAVA_VERSION") "graalvm-community-25.0.2")
      java-bin (mise-bin (str "java@" java-ver) "java")]
  ;; Shared parallel-safe download (atomic rename + retry); single fix
  ;; point in defn lib so the cold-cache fmt-flake hardening stays in
  ;; sync with fmt-check.clj + fmt-cljstyle.clj. See AIREF-00019.
  (download-jar! jar url)
  (apply sh!! java-bin "-jar" jar *command-line-args*))
