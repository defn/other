#!/usr/bin/env bbs
#MISE description= "Create a new AI Decision Record"


;; Creates a new AIDR with auto-incremented number and date header.
;;
;; Usage:
;;   mise run aidr -- <type> "Topic title here"
;;
;; <type> is one of: spec | plan | options | decision | review
;;
;;   spec     -- design / what to build
;;   plan     -- how to build it (steps, ordering)
;;   options  -- side-by-side options, no recommendation yet
;;   decision -- a settled call (default body template)
;;   review   -- reserved for sp-review
;;
;; The task auto-injects today's date into both the filename
;; (NNNNN-YYYY-MM-DD-<type>-<topic-slug>.md) and the **Date** body
;; line, and renders the H1 as "<Type>: <Topic>".
;;
;; AIDRs are chronological, immutable history. They are NOT indexed in
;; AGENTS.md/CLAUDE.md (per the doc policy: AGENTS.md is repo-wide
;; orientation only, not an AIDR catalog). Cross-references to AIDRs
;; live in the content files they concern -- a comment in the brick
;; cites AIDR-NNNNN, the relevant generator's contract.cue lists
;; related_aidr, etc.


(require '[defn :refer :all])


(def allowed-types
  #{"spec" "plan" "options" "decision" "review"})


(def usage-line
  (str/join "\n"
            ["usage: mise run aidr -- <type> \"topic\""
             "  <type>: spec | plan | options | decision | review"
             "  e.g.:   mise run aidr -- review \"argocd rollout retry\""]))


(defn slugify
  "Convert title to a URL-friendly slug."
  [s]
  (-> s
      str/lower-case
      (str/replace #"[^a-z0-9\s-]" "")
      str/trim
      (str/replace #"\s+" "-")))


(defn next-aidr-number
  "Find the highest AIDR number and return the next one."
  []
  (let [files  (fs/list-dir "aidr")
        numbers (->> files
                     (map #(str (fs/file-name %)))
                     (keep #(second (re-find #"^(\d+)-" %)))
                     (map parse-long))]
    (if (seq numbers)
      (inc (apply max numbers))
      1)))


(defn die-usage
  []
  (println usage-line)
  (exit 1))


(let [args  *command-line-args*
      kind  (first args)
      title (second args)]
  (when-not (= 2 (count args))
    (die-usage))
  (when (or (not (allowed-types kind)) (str/blank? title))
    (die-usage))

  (let [num   (next-aidr-number)
        slug  (slugify title)
        _     (when (str/blank? slug)
                (println (str "error: title slugifies to empty string; use a title with [a-z0-9] characters."))
                (exit 1))
        date  (.format (java.time.LocalDate/now)
                       (java.time.format.DateTimeFormatter/ISO_LOCAL_DATE))
        fname (format "%05d-%s-%s-%s.md" num date kind slug)
        path  (str "aidr/" fname)
        h1    (str (str/capitalize kind) ": " title)
        body  (str "# AIDR-" (format "%05d" num) ": " h1 "\n"
                   "\n"
                   "**Date**: " date "\n"
                   "\n"
                   "## Context\n"
                   "\n"
                   "\n"
                   "\n"
                   "## Decision\n"
                   "\n"
                   "\n"
                   "\n"
                   "## Implementation\n"
                   "\n")
        f     (java.io.File. path)]

    (if-not (.createNewFile f)
      (do (println (str "error: " path " already exists (concurrent aidr creation?). Re-run."))
          (exit 1))
      (do (spit f body)
          (sh! "chmod" "644" path)
          (log-ok (str "created " path))))))
