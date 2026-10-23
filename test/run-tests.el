;;; run-tests.el --- Run the test suite -*- lexical-binding: t; -*-
(require 'ert)
(setq load-prefer-newer t)
(dolist (file (directory-files "test" t "-test\\.el\\'"))
  (load file nil t))
(ert-run-tests-batch-and-exit)
