;; publish.el --- Publish org-mode project on Gitlab Pages
;; Author: Rasmus

(package-initialize)
(require 'org)
(require 'ox-publish)
(setq org-publish-use-timestamps-flag nil)
(setq user-full-name "Oleg Pykhalov")
(setq user-mail-address "go.wigust@gmail.com")

(setq org-export-with-section-numbers nil
      org-export-with-smart-quotes t
      org-export-with-toc t
      org-html-validation-link nil)

(setq org-html-divs '((preamble "header" "top")
                      (content "main" "content")
                      (postamble "footer" "postamble"))
      org-html-container-element "section"
      org-html-metadata-timestamp-format "%Y-%m-%d"
      org-html-checkbox-type 'html
      org-html-html5-fancy t
      org-html-doctype "html5")
(defvar site-attachments (regexp-opt '("jpg" "jpeg" "gif" "png" "svg"
                                       "ico" "cur" "css" "js" "woff" "html" "pdf")))

(setq org-publish-project-alist
      (list
       (list "site-org"
             :base-directory "."
             :base-extension "org"
             :recursive t
             :publishing-function '(org-html-publish-to-html)
             :publishing-directory "./public"
             :exclude (regexp-opt '("README" "draft"))
             :auto-sitemap t
             :sitemap-filename "index.org"
             :sitemap-file-entry-format "%t"
             :html-head-extra "<link rel=\"icon\" type=\"image/x-icon\" href=\"/favicon.ico\"/>"
             :sitemap-style 'list)
       (list "site-static"
             :base-directory "."
             :exclude "public/"
             :base-extension site-attachments
             :publishing-directory "./public"
             :publishing-function 'org-publish-attachment
             :recursive t
             :email nil
             :creator nil
             :author nil)
       (list "site" :components '("site-org"))))
