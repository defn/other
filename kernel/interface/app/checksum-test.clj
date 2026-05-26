#!/usr/bin/env bbs
;; Verify chart tarball sha256 matches expected checksum.
;; Usage: checksum-test.clj <tarball> <expected-sha256>

(require '[defn :refer :all])


(let [[tarball expected] *command-line-args*
      actual (-> (sh! "sha256sum" tarball)
                 (str/split #"\s+")
                 first)]
  (if (= actual expected)
    (log-ok (str tarball " checksum verified"))
    (do
      (log-err (str tarball " checksum mismatch"))
      (println (str "  expected: " expected))
      (println (str "  actual:   " actual))
      (exit 1))))
