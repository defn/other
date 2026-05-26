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
    (sh! "curl" "-fsSL" "-o" jar url))
  (apply sh!! java-bin "-jar" jar *command-line-args*))
