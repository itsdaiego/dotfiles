(require 'package)
  (add-to-list 'package-archives '("melpa" . "http://melpa.org/packages/"))
  (package-initialize)

;;Personal config before
(setq evil-want-C-u-scroll t)

;;Evil
  (require 'evil)
  (evil-mode 1)

;;Neotree
(require 'neotree)
(global-set-key [f8] 'neotree-toggle)
(setq neo-smart-open t)


;;Fiplr
(setq fiplr-ignored-globs '((directories (".git" ".svn" "node_modules" "platforms" "plugins"))
                            (files ("*.jpg" "*.png" "*.zip" "*~"))))
(global-set-key (kbd "C-x f") 'fiplr-find-file)

;;Auto complete
(ac-config-default)

;;Flycheck
(global-flycheck-mode)

;;Keychord
(setq key-chord-two-keys-delay 1.5)
(key-chord-define evil-insert-state-map "jj" 'evil-normal-state)
(key-chord-mode 1)

;;Powerline
(require 'powerline)
(powerline-default-theme)

;;Autopairs
(require 'autopair)
(autopair-global-mode) ;; enable autopair in all buffersz


;;Linum-relative
(require 'linum-relative)
(linum-relative-on)

;;Evil-commentary
(require 'evil-commentary)
(evil-commentary-mode)

;;Magit	
(global-set-key (kbd "C-x g") 'magit-status)

;;Editor Config
(require 'editorconfig)
(editorconfig-mode 1)

;;Yasnippets
(require 'yasnippet)
(yas-global-mode 1)





;;Personal config after
;;(load-theme 'solarized- t)
(load-theme 'dracula t)
(global-linum-mode t)
(menu-bar-mode 0)
(tool-bar-mode 0)
;;(setq backup-directory-alist `(("." . "~/.saves")))
(setq make-backup-files nil)


;; Ctags
(require 'eproject)
(defun build-ctags ()
  (interactive)
  (message "building project tags")
  (let ((root (eproject-root)))
    (shell-command (concat "ctags -e -R --extra=+fq --exclude=db --exclude=test --exclude=platforms --exclude=plugins --exclude=node_modules --exclude=.git --exclude=public -f " root "TAGS " root)))
  (visit-project-tags)
  (message "tags built successfully"))
(defun visit-project-tags ()
  (interactive)
  (let ((tags-file (concat (eproject-root) "TAGS")))
    (visit-tags-table tags-file)
    (message (concat "Loaded " tags-file))))
(defun my-find-tag ()
  (interactive)
  (if (file-exists-p (concat (eproject-root) "TAGS"))
      (visit-project-tags)
    (build-ctags))
  (etags-select-find-tag-at-point))

(global-set-key (kbd "M-c") 'my-find-tag)


;;PDB
(defun add-py-debug ()  
      "add debug code and move line down"  
    (interactive)  
    (move-beginning-of-line 1)  
    (insert "import pdb; pdb.set_trace();\n"))  

(global-set-key (kbd "<f9>") 'add-py-debug)

(defun remove-py-debug ()  
  "remove py debug code, if found"  
  (interactive)  
  (let ((x (line-number-at-pos))  
    (cur (point)))  
    (search-forward-regexp "^[ ]*import pdb; pdb.set_trace();")  
    (if (= x (line-number-at-pos))  
    (let ()  
      (move-beginning-of-line 1)  
      (kill-line 1)  
      (move-beginning-of-line 1))  
      (goto-char cur))))  

(global-set-key (kbd "C-c <f9>") 'remove-py-debug)

(global-set-key (kbd "<f3>") '(lambda ()  
                                 (interactive)   
                                 (search-forward-regexp "^[ ]*import pdb; pdb.set_trace();")   
                                 (move-beginning-of-line 1)))



(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   (quote
    ("427fed191e7a766152e59ef0e2904283f436dbbe259b9ccc04989f3acde50a55" "8abee8a14e028101f90a2d314f1b03bed1cde7fd3f1eb945ada6ffc15b1d7d65" "a164837cd2821475e1099911f356ed0d7bd730f13fa36907895f96a719e5ac3e" "628278136f88aa1a151bb2d6c8a86bf2b7631fbea5f0f76cba2a0079cd910f7d" "a8245b7cc985a0610d71f9852e9f2767ad1b852c2bdea6f4aadc12cce9c4d6d0" "06f0b439b62164c6f8f84fdda32b62fb50b6d00e8b01c2208e55543a6337433a" "8aebf25556399b58091e533e455dd50a6a9cba958cc4ebb0aab175863c25b9a4" "d677ef584c6dfc0697901a44b885cc18e206f05114c8a3b7fde674fce6180879" default)))
 '(menu-bar-mode nil)
 '(tool-bar-mode nil))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(default ((t (:family "Consolas" :foundry "MS  " :slant normal :weight bold :height 113 :width normal)))))
