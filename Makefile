EMACS ?= emacs

.PHONY: test compile checkdoc check clean demo tty-smoke
test:
	$(EMACS) -Q --batch -L . -L test -l test/run-tests.el
compile:
	$(EMACS) -Q --batch -L . --eval '(setq byte-compile-error-on-warn t)' -f batch-byte-compile emacs-tui-layout.el emacs-tui.el
checkdoc:
	$(EMACS) -Q --batch -L . -l test/check-docs.el
check: test compile checkdoc
tty-smoke:
	EMACS=$(EMACS) python3 test/run-tty-smoke.py
clean:
	rm -f emacs-tui*.elc
demo:
	$(EMACS) -Q -nw -L . -l examples/emacs-tui-demo.el -f emacs-tui-demo
