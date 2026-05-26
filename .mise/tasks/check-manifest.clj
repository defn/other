#!/usr/bin/env bbs
#MISE description= "Verify git-tracked files match CUE manifest (git + CUE only)"

(require '[defn :refer :all])


(defn walk-tree
  "Reconstruct file paths from a CUE manifest tree (JSON).
   Tree has 'files' (map of name -> {}) and 'dirs' (map of name -> subtree)."
  ([tree] (walk-tree tree ""))
  ([tree prefix]
   (let [files (for [[fname _] (get tree "files")]
                 (str prefix fname))
         dirs  (for [[dname subtree] (get tree "dirs")
                     path (walk-tree subtree (str prefix dname "/"))]
                 path)]
     (concat files dirs))))


(let [cue-json    (mise-x-quiet "cue" "cue" "eval" "-c" "-e" "repo" "--out" "json" "var/gen-manifest.cue" "kernel/manifest/manifest.cue")
      tree        (parse-json cue-json)
      cue-files   (set (walk-tree tree))
      git-files   (git-tracked-files)
      missing-cue (sort (difference git-files cue-files))
      extra-cue   (sort (difference cue-files git-files))]
  (cond
    (and (empty? missing-cue) (empty? extra-cue))
    (log-ok (format "all %d git-tracked files are in CUE manifest" (count git-files)))

    :else
    (do
      (when (seq missing-cue)
        (log-err "files in git but NOT in CUE manifest:")
        (doseq [f missing-cue] (println (str "  " f)))
        (println)
        (println "Fix: run 'mise run gen' to regenerate manifest/gen-manifest.cue"))
      (when (seq extra-cue)
        (log-err "files in CUE manifest but NOT in git:")
        (doseq [f extra-cue] (println (str "  " f)))
        (println)
        (println "Fix: run 'mise run gen' to regenerate manifest/gen-manifest.cue"))
      (exit 1))))
