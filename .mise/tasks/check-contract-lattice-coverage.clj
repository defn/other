#!/usr/bin/env bbs
#MISE description= "Verify every catalog field bound by `field: _` in any contract.cue has a corresponding lattice exposure (AIDR-00139 Tier 3)"


;; Field-must-have-shard policy enforcement.
;;
;; Per AIDR-00139 implementation observation 3 ("CUE bottom-value
;; propagation is silent and catastrophic"), every catalog field
;; that a generator's contract.cue binds via `<field>: _` must be
;; present in the lattice JSON, even if empty. The
;; tenant/library/go/lib/gen/lattice/lattice.go::buildLattice catalogFields
;; list enumerates the fields it exposes; this task asserts every
;; contract binding is covered.
;;
;; Failure mode without this guard: a new contract binds a field
;; that lattice.go doesn't expose. In defn the field happens to be
;; populated (so the lattice has it anyway) and tests pass. In a
;; fork without that field, the unbound `_` becomes `_|_` when
;; iterated, propagating into thousands of bogus orphans buried
;; 600+ stack frames deep in CUE evaluation -- the exact failure
;; the original AIDR-00139 session hunted for hours.
;;
;; This is a static (no-bazel) check: it greps contract.cue files
;; for the binding pattern and lattice.go for the catalogFields
;; string literal. Both files are stable shapes; both diffs land
;; in PRs that touch the same logical change.


(require '[defn :refer :all])
(require '[clojure.string :as str])
(require '[babashka.fs :as fs])


(def workspace-root
  ;; Workspace root is <git-toplevel>/m by convention (see
  ;; kernel/lib/defn.clj::workspace-root).
  (str (str/trim (:out (sh!!? "git" "rev-parse" "--show-toplevel"))) "/m"))


;; Gather every `<field>: _` binding in any contract.cue under
;; tenant/library/go/lib/gen/. Returns a sorted set.
(defn contract-bindings
  []
  (let [contracts (filter #(= "contract.cue" (fs/file-name %))
                          (fs/glob (str workspace-root "/tenant/library/go/lib/gen") "**/contract.cue"))
        pattern   #"(?m)^[a-z_][a-z0-9_]*:\s*_\s*$"]
    (->> contracts
         (mapcat (fn [path]
                   (let [content (slurp (str path))]
                     (->> (re-seq pattern content)
                          (map (fn [line]
                                 ;; "field_name: _" -> "field_name"
                                 (-> line
                                     (str/replace #":.*$" "")
                                     str/trim)))))))
         set
         sort)))


;; Parse lattice.go's catalogFields literal. Looking for:
;;   catalogFields := []string{
;;       "formatters", "apps", ...,
;;   }
;; and extracting every quoted string inside the braces.
(defn lattice-exposed-fields
  []
  (let [lattice-go (slurp (str workspace-root "/tenant/library/go/lib/gen/lattice/lattice.go"))
        ;; Match the declaration through to its closing brace.
        block-pat  #"(?s)catalogFields\s*:=\s*\[\]string\{(.*?)\}"
        block      (second (re-find block-pat lattice-go))]
    (when (nil? block)
      (log-err "could not find catalogFields := []string{...} in lattice.go")
      (exit 1))
    (->> (re-seq #"\"([a-z_][a-z0-9_]*)\"" block)
         (map second)
         set
         sort)))


(let [bound    (contract-bindings)
      exposed  (lattice-exposed-fields)
      bound-s  (set bound)
      exp-s    (set exposed)
      missing  (sort (clojure.set/difference bound-s exp-s))
      unused   (sort (clojure.set/difference exp-s bound-s))]

  (println "contracts <field>: _ bindings  (" (count bound) "):" (str/join " " bound))
  (println "lattice.go catalogFields list (" (count exposed) "):" (str/join " " exposed))
  (println)

  (when (seq unused)
    (println "(info) lattice exposes fields no contract.cue currently binds:")
    (doseq [f unused] (println " " f))
    (println " -- this is fine; future contracts can bind these without lattice changes."))

  (if (empty? missing)
    (do (log-ok "all" (count bound) "contract field bindings are exposed in the lattice")
        (exit 0))
    (do (log-err "the following contract.cue fields are NOT exposed in the lattice:")
        (println)
        (doseq [f missing] (println "  " f))
        (println)
        (println "Fix: add the field to catalogFields in")
        (println "  tenant/library/go/lib/gen/lattice/lattice.go::buildLattice")
        (println "so forks (or any workspace where the field is empty) get an")
        (println "empty-map value rather than `_|_` -- see AIDR-00139 observation 3.")
        (exit 1))))
