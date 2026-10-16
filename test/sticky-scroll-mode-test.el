;;; sticky-scroll-mode-test.el --- Sticky scrolling regressions -*- lexical-binding: t -*-
;;; Commentary:
;; Run: emacs -Q --batch -L . -l test/sticky-scroll-mode-test.el -f ert-run-tests-batch-and-exit
;;; Code:
(require 'ert)
(require 'cl-lib)
(require 'subr-x)
(require 'sticky-scroll-mode)

(ert-deftest sticky-scroll/handles-blank-lines-with-one-backward-scan ()
  (require 'sticky-scroll-mode)
  (save-window-excursion
    (with-temp-buffer
      (insert "module Outer\n\n  class Child < Parent\n\n    def call(arg, option: nil)\n")
      (dotimes (_ 500) (insert "      work(arg)\n\n      more_work\n  \t \n"))
      (switch-to-buffer (current-buffer))
      (goto-char (point-min))
      (forward-line 1800)
      (set-window-start (selected-window) (point) t)
      (let* ((calls 0)
             (bound-scan
              (lambda (original &rest args)
                (when (> (cl-incf calls) 2500)
                  (ert-fail "Sticky context repeatedly rescanned the same lines"))
                (apply original args))))
        (advice-add 'sticky-scroll--collect-lines :around bound-scan)
        (unwind-protect
            (dolist (line '(1805 1806 1808))
              (setq calls 0)
              (goto-char (point-min))
              (forward-line line)
              (let ((point-before (point)))
                (should
                 (equal (mapcar #'substring-no-properties
                                (sticky-scroll--collect-lines))
                        '("module Outer" "  class Child < Parent"
                          "    def call(arg, option: nil)")))
                (should (= (point) point-before))))
          (advice-remove 'sticky-scroll--collect-lines bound-scan))))))

(ert-deftest sticky-scroll/displays-only-three-innermost-headers ()
  (require 'sticky-scroll-mode)
  (save-window-excursion
    (with-temp-buffer
      (insert (make-string 100 ?\n))
      (switch-to-buffer (current-buffer))
      (setq-local header-line-format '("existing LSP breadcrumbs"))
      (let ((source-window (selected-window))
            (source-point (point))
            (sticky-scroll-max-window-height 3))
        (unwind-protect
            (progn
              (sticky-scroll--window '("module Outer" "  class Child < Parent"
                                       "    def call(arg)" "      if enabled"
                                       "        items.each do |item|"))
              (let* ((buffer (cdr (assq (current-buffer) sticky-scroll--buffer-alist)))
                     (window (get-buffer-window buffer)))
                (should (= (window-body-height window) 3))
                (should (buffer-local-value 'header-line-format buffer))
                (should (eq (window-parameter source-window 'header-line-format) 'none))
                (should (equal (with-current-buffer buffer (buffer-string))
                               "    def call(arg)\n      if enabled\n        items.each do |item|\n")))
              (should (eq (selected-window) source-window))
              (should (= (point) source-point))
              (should (equal header-line-format '("existing LSP breadcrumbs"))))
          (sticky-scroll-close-buffer))
        (should-not (window-parameter source-window 'header-line-format)))))
)

(provide 'sticky-scroll-mode-test)
;;; sticky-scroll-mode-test.el ends here
