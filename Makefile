EMACS ?= emacs

.PHONY: test compile checkdoc check clean demo async-demo dashboard panel composer tty-smoke
test:
	$(EMACS) -Q --batch -L . -L test -l test/run-tests.el
compile:
	$(EMACS) -Q --batch -L . --eval '(setq byte-compile-error-on-warn t)' -f batch-byte-compile emacs-tui-layout.el emacs-tui-table.el emacs-tui.el examples/*.el
checkdoc:
	$(EMACS) -Q --batch -L . -l test/check-docs.el
check: test compile checkdoc
tty-smoke:
	EMACS=$(EMACS) python3 test/run-tty-smoke.py
	EMACS=$(EMACS) python3 test/run-tty-smoke.py test/tty-mount-smoke.el
	EMACS=$(EMACS) python3 test/run-tty-smoke.py test/tty-embed-smoke.el
	EMACS=$(EMACS) python3 test/run-tty-smoke.py test/tty-table-smoke.el
	EMACS=$(EMACS) python3 test/run-tty-smoke.py test/tty-input-smoke.el
clean:
	rm -f emacs-tui*.elc examples/*.elc
demo:
	$(EMACS) -Q -nw -L . -l examples/emacs-tui-demo.el -f emacs-tui-demo
async-demo:
	$(EMACS) -Q -nw -L . -l examples/emacs-tui-async-demo.el -f emacs-tui-async-demo
dashboard:
	$(EMACS) -Q -nw -L . -l examples/emacs-tui-dashboard.el -f emacs-tui-dashboard
panel:
	$(EMACS) -Q -nw -L . -l examples/emacs-tui-buffer-panel.el -f emacs-tui-buffer-panel
composer:
	$(EMACS) -Q -nw -L . -l examples/emacs-tui-composer.el -f emacs-tui-composer
