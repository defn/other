#!/usr/bin/env bbs
#MISE description= "Open a URL in the default browser"


;; Usage: mise run open URL
;;
;; Detects the environment and uses the appropriate method:
;; - VSCode/code-server: browser.sh helper
;; - macOS: /usr/bin/open
;; - Linux with xdg-utils: xdg-open
;; - Fallback: print URL for manual opening

(require '[defn :refer :all])


(let [url (first *command-line-args*)
      vscode-main (System/getenv "VSCODE_GIT_ASKPASS_MAIN")]
  (when-not url
    (log-err "usage: mise run open URL")
    (exit 1))

  (cond
    ;; VSCode / code-server / remote
    (and vscode-main (not (str/blank? vscode-main)))
    (let [base (str/replace vscode-main #"/extensions/.*" "")
          helper (str base "/bin/helpers/browser.sh")]
      (if (fs/exists? helper)
        (sh!! helper url)
        (do (log-err "browser.sh not found, open manually:")
            (println url))))

    ;; macOS
    (sh? "which" "/usr/bin/open")
    (sh!! "/usr/bin/open" url)

    ;; Linux with xdg-open
    (sh? "which" "xdg-open")
    (sh!! "xdg-open" url)

    ;; Fallback
    :else
    (do (println "open this URL:")
        (println url))))
