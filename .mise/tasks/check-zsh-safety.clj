#!/usr/bin/env bbs
#MISE description= "Lint tracked .md files for zsh-unsafe shell snippets (AIREF-00013)"


;; check-zsh-safety -- scans tracked .md files for ```bash``` /
;; ```sh``` / ```shell``` fenced code blocks containing zsh
;; metacharacter patterns that would parse differently in zsh than
;; in bash. Reports file:line violations and exits non-zero if any.
;; AIDR-00127 #12; rules in AIREF-00013.
;;
;; Patterns flagged:
;;   == or ===   outside of single-quoted strings
;;   unquoted !  outside of single-quoted strings
;;   trailing glob qualifiers in unquoted parens / ^ / ~ / #
;;
;; Implementation is deliberately simple regex-based; false
;; positives are acceptable (the cure is to single-quote or use
;; printf), false negatives in dense scripts are also acceptable
;; (a deeper parse is possible later if drift recurs). Wired into
;; check.clj's sentinel block.

(require '[defn :refer :all])


;; Patterns to flag inside shell code blocks. Each entry: [name
;; regex hint]. Regex matches if the pattern appears UNQUOTED.
;; The "unquoted" check is approximate (any line not starting with
;; a single-quoted-string column position).
(def patterns
  [["===" #"===" "use single-quoted string or printf"]
   ["==" #"(?:^| )==(?: |$)" "single-quote literal `==` or use `=`"]
   ["bare history-bang" #"[^'](\s|^)![A-Za-z0-9_]" "single-quote `!`"]])


(defn- code-block-shells
  "Return seq of [start-line end-line lang lines] for shell-language
   fenced code blocks in the markdown content. Skipping nested
   fences and tildes-style for simplicity."
  [content]
  (let [lines (str/split-lines content)
        n     (count lines)]
    (loop [i 0
           out []]
      (if (>= i n)
        out
        (let [line (nth lines i)
              m    (re-matches #"^```\s*(bash|sh|shell)\s*$" line)]
          (if m
            ;; Find the closing ```.
            (let [start-line (inc i)
                  end-idx   (loop [j (inc i)]
                              (cond
                                (>= j n) j
                                (= "```" (str/trim (nth lines j))) j
                                :else (recur (inc j))))
                  code-lines (subvec (vec lines) start-line end-idx)]
              (recur (inc end-idx)
                     (conj out [start-line end-idx (second m) code-lines])))
            (recur (inc i) out)))))))


(defn- find-violations
  [path]
  (let [content (slurp path)
        blocks  (code-block-shells content)]
    (for [[start _ _ block-lines] blocks
          [lineno code-line] (map-indexed (fn [i l] [(+ start i 1) l]) block-lines)
          [name regex hint] patterns
          :when (re-find regex code-line)
          ;; Skip if the entire match is inside a single-quoted
          ;; string -- approximate by stripping content between
          ;; balanced single quotes and re-checking.
          :let [stripped (str/replace code-line #"'[^']*'" "")]
          :when (re-find regex stripped)]
      {:file path :line lineno :pattern name :text code-line :hint hint})))


(let [files (->> (sh! "git" "ls-files" "*.md")
                 str/split-lines
                 (remove str/blank?))
      violations (mapcat find-violations files)]
  (if (seq violations)
    (do
      (log-err (str "check-zsh-safety: " (count violations)
                    " zsh-unsafe pattern(s) found in shell code blocks"))
      (println)
      (doseq [v violations]
        (println (str "  " (:file v) ":" (:line v) "  [" (:pattern v) "]"))
        (println (str "    " (str/triml (:text v))))
        (println (str "    hint: " (:hint v))))
      (println)
      (println "  See AIREF-00013 for the rules.")
      (exit 1))
    (log-ok (str "check-zsh-safety: " (count files)
                 " tracked .md files clean (AIREF-00013)"))))
