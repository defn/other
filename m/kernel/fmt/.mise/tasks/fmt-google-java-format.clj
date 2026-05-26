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
  (when-not (fs/exists? jar)
    (fs/create-dirs cache-dir)
    (log-ok (str "downloading google-java-format " version))
    ;; Atomic download: per-process temp + atomic rename, so parallel cold-cache
    ;; fmt tests can't corrupt the shared jar via interleaved writes. Same race
    ;; (and fix) as fmt-cljstyle.clj; see AIREF-00019.
    (let [tmp (str jar "." (random-uuid) ".tmp")]
      (sh! "curl" "-fsSL" "-o" tmp url)
      (fs/move tmp jar {:replace-existing true :atomic-move true})))
  (apply sh!! java-bin "-jar" jar *command-line-args*))
