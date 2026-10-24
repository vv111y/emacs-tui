EMACS ?= emacs

.PHONY: test compile checkdoc check clean demo async-demo dashboard panel composer tree filter-demo package-check tty-smoke benchmark benchmark-smoke
test:
	$(EMACS) -Q --batch -L . -L test -l test/run-tests.el
compile:
	$(EMACS) -Q --batch -L . --eval '(setq byte-compile-error-on-warn t)' -f batch-byte-compile emacs-tui-layout.el emacs-tui-table.el emacs-tui-tree.el emacs-tui-action.el emacs-tui.el examples/*.el
checkdoc:
	$(EMACS) -Q --batch -L . -l test/check-docs.el
check: test compile checkdoc
tty-smoke:
	EMACS=$(EMACS) python3 test/run-tty-smoke.py
	EMACS=$(EMACS) python3 test/run-tty-smoke.py test/tty-mount-smoke.el
	EMACS=$(EMACS) python3 test/run-tty-smoke.py test/tty-embed-smoke.el
	EMACS=$(EMACS) python3 test/run-tty-smoke.py test/tty-table-smoke.el
	EMACS=$(EMACS) python3 test/run-tty-smoke.py test/tty-input-smoke.el
	EMACS=$(EMACS) python3 test/run-tty-smoke.py test/tty-tree-smoke.el
clean:
	rm -f emacs-tui*.elc examples/*.elc bench/*.elc
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
tree:
	$(EMACS) -Q -nw -L . -l examples/emacs-tui-buffer-tree.el -f emacs-tui-buffer-tree
filter-demo:
	$(EMACS) -Q -nw -L . -l examples/emacs-tui-filter-demo.el -f emacs-tui-filter-demo
package-check:
	EMACS=$(EMACS) python3 test/run-package-check.py
benchmark:
	EMACS=$(EMACS) python3 bench/run.py --output .cache/benchmark.json $(BENCH_ARGS)
benchmark-smoke:
	$(EMACS) -Q --batch -L . --eval '(setq byte-compile-error-on-warn t)' -f batch-byte-compile bench/interactive.el
	EMACS=$(EMACS) python3 bench/run.py --sizes 100 --samples 6 --warmup 2 --output .cache/benchmark-smoke.json
