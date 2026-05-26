#!/usr/bin/env bbs
#MISE hide=true


;; fmt-check.clj -- verify a file is correctly formatted.
;; Usage: fmt-check.clj <tool> <version> <file>
;; Runs formatter via mise on a copy, diffs against original.
;;
;; To add a new formatter:
;;   1. Add a case branch below with the formatter command
;;   2. Add VERSION constant to tools.bzl
;;   3. Add entry to fmt.bzl _TOOL_VERSIONS
;;   4. Add tool to mise.toml

(require '[defn :refer :all])


(let [[tool version original] *command-line-args*
      ;; Copy next to original so formatters like cue can find cue.mod/ in parent dirs.
      ;; Preserve extension so formatters recognize the file type.
      has-ext? (str/includes? (fs/file-name original) ".")
      copy-path (if has-ext?
                  (let [fname (fs/file-name original)
                        ;; Preserve compound extensions like .pkr.hcl
                        dot-idx (str/index-of fname ".")
                        ext (subs fname dot-idx)
                        base (subs (str original) 0 (- (count original) (count ext)))]
                    (str base "_fmtcheck" ext))
                  (str original "_fmtcheck"))
      mise-spec (str tool "@" version)]
  (try
    (copy-file original copy-path)
    ;; Bazel sandbox inputs are read-only; ensure the copy is writable.
    (sh! "chmod" "u+w" copy-path)
    (case tool
      "biome"      (mise-x! mise-spec "biome" "format" "--write" copy-path)
      "buildifier" (mise-x! mise-spec "buildifier" copy-path)
      "cljstyle"   (let [java-ver (or (System/getenv "JAVA_VERSION") "graalvm-community-25.0.2")
                         java-bin (mise-bin (str "java@" java-ver) "java")
                         cache-dir (str (System/getenv "HOME") "/.cache/cljstyle")
                         jar (str cache-dir "/cljstyle-" version ".jar")
                         url (str "https://github.com/greglook/cljstyle/releases/download/"
                                  version "/cljstyle-" version ".jar")]
                     (when-not (fs/exists? jar)
                       (fs/create-dirs cache-dir)
                       (sh! "curl" "-fsSL" "-o" jar url))
                     (sh!! java-bin "-jar" jar "fix" copy-path))
      "google-java-format" (let [java-ver (or (System/getenv "JAVA_VERSION") "graalvm-community-25.0.2")
                                 java-bin (mise-bin (str "java@" java-ver) "java")
                                 cache-dir (str (System/getenv "HOME") "/.cache/google-java-format")
                                 jar (str cache-dir "/google-java-format-" version "-all-deps.jar")
                                 url (str "https://github.com/google/google-java-format/releases/download/v"
                                          version "/google-java-format-" version "-all-deps.jar")]
                             (when-not (fs/exists? jar)
                               (fs/create-dirs cache-dir)
                               (sh! "curl" "-fsSL" "-o" jar url))
                             (sh!! java-bin "-jar" jar "--replace" copy-path))
      "cue"      (mise-x! mise-spec "cue" "fmt" copy-path)
      "dprint"   (let [bin    (mise-bin mise-spec "dprint")
                       ;; Find dprint.json by walking up from the file's directory.
                       config (loop [dir (fs/parent (fs/absolutize copy-path))]
                                (when dir
                                  (let [f (str dir "/dprint.json")]
                                    (if (fs/exists? f) f (recur (fs/parent dir))))))
                       input  (slurp copy-path)
                       args   (cond-> [bin "fmt"]
                                config (into ["--config" (str config)])
                                true   (into ["--stdin" (fs/file-name original)]))
                       result (apply sh-pipe! input args)]
                   (spit copy-path result))
      "yae"      (let [lines   (str/split-lines (slurp copy-path))
                       header  (take-while #(str/starts-with? % "#") lines)
                       body    (drop-while #(str/starts-with? % "#") lines)
                       tmp     (str copy-path ".body.go")
                       _       (spit tmp (str/join "\n" body))
                       _       (mise-x! (str "go@" version) "gofmt" "-w" tmp)
                       result  (str (str/join "\n" header) "\n" (slurp tmp))]
                   (spit copy-path result)
                   (fs/delete-if-exists tmp))
      "gofmt"    (mise-x! (str "go@" version) "gofmt" "-w" copy-path)
      "packer"   (mise-x! mise-spec "packer" "fmt" copy-path)
      "prettier" (mise-x! mise-spec "prettier" "--write" "--prose-wrap" "preserve" copy-path)
      "ruff"     (mise-x! mise-spec "ruff" "format" copy-path)
      "shfmt"    (let [install-dir (sh! "mise" "where" "github:mvdan/sh")
                       ;; Binary is named shfmt_v<version> in github:mvdan/sh installs
                       bin (str install-dir "/shfmt_v" version)]
                   (sh!! bin "-w" copy-path))
      "binary"   nil ; binary/vendored files -- no formatting
      "taplo"    (mise-x! mise-spec "taplo" "format" copy-path)
      "tofu"     (mise-x! (str "opentofu@" version) "tofu" "fmt" copy-path)
      "textfmt"  (let [content (slurp copy-path)
                       ;; Strip trailing whitespace from each line, ensure single trailing newline.
                       cleaned (-> content
                                   (str/replace #"(?m)[^\S\n]+$" "")
                                   (str/replace #"\n+$" "")
                                   (str "\n"))]
                   (spit copy-path cleaned))
      "yq"       (mise-x! mise-spec "yq" "-i" "." copy-path)
      (do (log-err (str "unknown formatter: " tool)) (exit 1)))
    (let [{rc :exit out :out} (sh-result "diff" "-u" original copy-path)]
      (if (zero? rc)
        (log-ok (str original " is correctly formatted (" mise-spec ")"))
        (do
          ;; Save formatted file to TEST_UNDECLARED_OUTPUTS_DIR for auto-fix.
          (when-let [outputs-dir (System/getenv "TEST_UNDECLARED_OUTPUTS_DIR")]
            (let [dest (str outputs-dir "/" (fs/file-name original))]
              (copy-file copy-path dest)
              ;; Write workspace-relative path so check can copy it back.
              (spit (str outputs-dir "/DEST") original)))
          (println out)
          (println)
          (log-err (str original " is not correctly formatted."))
          (println (str "  formatter: " mise-spec))
          (exit 1))))
    (finally
      (fs/delete-if-exists copy-path))))
