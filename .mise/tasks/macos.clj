#!/usr/bin/env bbs
#MISE description= "Run macOS ansible playbook (home mount, virtual IP)"

(require '[defn :refer :all])


(let [cdup (str/trim (sh! "git" "rev-parse" "--show-cdup"))
      root (if (blank? cdup) "." cdup)
      playbook (str root "m/tenant/defn/playbook/macos.yaml")
      inventory (str root "m/tenant/defn/playbook/inventory")]
  (log-ok "running macOS playbook")
  (sh!! "mise" "exec" "--" "ansible-playbook" playbook "-i" inventory "--ask-become-pass"))
