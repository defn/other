#!/usr/bin/env bbs
;; drift.sh -- compare a committed file against a generated file.
#MISE hide=true


;; Usage: drift.sh <committed> <generated>

(require '[defn :refer :all])


(let [[committed generated] *command-line-args*
      {:keys [exit out]} (sh-result "diff" "-u" committed generated)]
  (if (zero? exit)
    (log-ok "no drift detected")
    (do
      (println out)
      (println)
      (log-err "committed file has drifted from generated output.")
      (println (str "  committed: " committed))
      (println (str "  generated: " generated))
      (println "  To fix: bazelisk run the sync target, then commit.")
      (System/exit 1))))
