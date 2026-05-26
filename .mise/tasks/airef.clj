#!/usr/bin/env bbs
#MISE description= "Create a new AI reference doc (cross-cutting advice)"


;; Creates a new airef entry with auto-incremented number.
;;
;; Usage:
;;   mise run airef -- "Topic title here"
;;
;; airef holds cross-cutting advice (how we do things). Counterpart
;; to aidr/ (chronological decisions). Naming:
;;   NNNNN-<topic-slug>.md
;; (no date or type prefix; entries are living advice updated over
;; time, with a **Last updated** line in the body.)


(require '[defn :refer :all])


(def usage-line
  (str/join "\n"
            ["usage: mise run airef -- \"topic\""
             "  e.g.: mise run airef -- \"workflow daily loop\""]))


(defn slugify
  "Convert title to a URL-friendly slug."
  [s]
  (-> s
      str/lower-case
      (str/replace #"[^a-z0-9\s-]" "")
      str/trim
      (str/replace #"\s+" "-")))


(defn next-airef-number
  "Find the highest airef number and return the next one."
  []
  (let [files   (fs/list-dir "airef")
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
      title (first args)]
  (when-not (= 1 (count args))
    (die-usage))
  (when (str/blank? title)
    (die-usage))

  (let [num   (next-airef-number)
        slug  (slugify title)
        _     (when (str/blank? slug)
                (println (str "error: title slugifies to empty string; use a title with [a-z0-9] characters."))
                (exit 1))
        date  (.format (java.time.LocalDate/now)
                       (java.time.format.DateTimeFormatter/ISO_LOCAL_DATE))
        fname (format "%05d-%s.md" num slug)
        path  (str "airef/" fname)
        body  (str "# AIREF-" (format "%05d" num) ": " title "\n"
                   "\n"
                   "**Last updated**: " date "\n"
                   "\n"
                   "## Rule\n"
                   "\n"
                   "\n"
                   "\n"
                   "## Why\n"
                   "\n"
                   "\n"
                   "\n"
                   "## How to apply\n"
                   "\n")
        f     (java.io.File. path)]

    (if-not (.createNewFile f)
      (do (println (str "error: " path " already exists. Pick a different title or update in place."))
          (exit 1))
      (do (spit f body)
          (sh! "chmod" "644" path)
          (log-ok (str "created " path))))))
