EMACS ?= emacs

.PHONY: test compile checkdoc check clean demo graph-demo gallery popup-demo completion-demo board-demo reader-demo snippet-demo catalog-demo stream-demo layout-demo async-demo dashboard panel composer tree filter-demo package-check tty-smoke benchmark benchmark-smoke
test:
	$(EMACS) -Q --batch -L . -L test -l test/run-tests.el
compile:
	$(EMACS) -Q --batch -L . --eval '(setq byte-compile-error-on-warn t)' -f batch-byte-compile emacs-tui-layout.el emacs-tui-table.el emacs-tui-tree.el emacs-tui-action.el emacs-tui.el emacs-tui-completion.el examples/*.el
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
	EMACS=$(EMACS) python3 test/run-tty-smoke.py test/tty-lifecycle-smoke.el
	EMACS=$(EMACS) python3 test/run-tty-smoke.py test/tty-demo-smoke.el
	EMACS=$(EMACS) python3 test/run-tty-smoke.py test/tty-showcase-smoke.el
	EMACS=$(EMACS) python3 test/run-tty-smoke.py test/tty-popup-smoke.el
	EMACS=$(EMACS) python3 test/run-tty-smoke.py test/tty-completion-smoke.el
	EMACS=$(EMACS) python3 test/check-reflow-smoke.py
	EMACS=$(EMACS) python3 test/run-clients-smoke.py
	EMACS=$(EMACS) python3 test/run-hangup-smoke.py
clean:
	rm -f emacs-tui*.elc examples/*.elc bench/*.elc
demo graph-demo:
	$(EMACS) -Q -nw -L . -l examples/emacs-tui-demo.el -f emacs-tui-demo
popup-demo:
	$(EMACS) -Q -nw -L . -l examples/emacs-tui-popup-demo.el -f emacs-tui-popup-demo-sample
completion-demo:
	$(EMACS) -Q -nw -L . -l examples/emacs-tui-completion-demo.el -f emacs-tui-completion-demo
gallery:
	$(EMACS) -Q -nw -L . -l examples/emacs-tui-gallery.el -f emacs-tui-gallery
board-demo:
	$(EMACS) -Q -nw -L . -l examples/emacs-tui-board-demo.el -f emacs-tui-board-demo
reader-demo:
	$(EMACS) -Q -nw -L . -l examples/emacs-tui-reader-demo.el -f emacs-tui-reader-demo
snippet-demo:
	$(EMACS) -Q -nw -L . -l examples/emacs-tui-snippet-demo.el -f emacs-tui-snippet-demo
catalog-demo:
	$(EMACS) -Q -nw -L . -l examples/emacs-tui-catalog-demo.el -f emacs-tui-catalog-demo
stream-demo:
	$(EMACS) -Q -nw -L . -l examples/emacs-tui-stream-demo.el -f emacs-tui-stream-demo
layout-demo:
	$(EMACS) -Q -nw -L . -l examples/emacs-tui-layout-demo.el -f emacs-tui-layout-demo
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
	python3 -m unittest discover -s test -p 'test_benchmark_driver.py'
	$(EMACS) -Q --batch -L . --eval '(setq byte-compile-error-on-warn t)' -f batch-byte-compile bench/interactive.el
	EMACS=$(EMACS) python3 bench/run.py --timeout 120 --sizes 100 --samples 6 --warmup 2 --output .cache/benchmark-smoke.json
	EMACS=$(EMACS) python3 bench/run.py --timeout 120 --load-mode bytecode --sizes 100 --samples 6 --warmup 2 --output .cache/benchmark-bytecode-smoke.json
	EMACS=$(EMACS) python3 bench/run.py --timeout 120 --filter-prefix 'row 日本語 ' --kinds filter-list filter-table --sizes 100 --samples 6 --warmup 2 --output .cache/benchmark-terms-smoke.json
	EMACS=$(EMACS) python3 bench/run.py --timeout 120 --load-mode bytecode --filter-prefix 'row 日本語 ' --kinds filter-list filter-table --sizes 100 --samples 6 --warmup 2 --output .cache/benchmark-terms-bytecode-smoke.json
