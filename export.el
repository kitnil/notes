(setq org-publish-project-alist
      '(("org-notes"
         :base-directory "~/src/org/"
         :base-extension "org"
         :publishing-directory "/var/www/org"
         :recursive t
         :publishing-function org-html-publish-to-html
         :headline-levels 4 ; Just the default for this project.
         :auto-preamble t
         :auto-sitemap t
         :sitemap-filename "index.org")))

(setq geiser-active-implementations '(guile))
(setq *scheme-use-r7rs* nil)

(require 'ox-publish)
(org-publish-all)
