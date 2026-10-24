# Candidate recipe and clean installation

`make package-check` runs real upstream package-build against the candidate
recipe in `test/recipes/emacs-tui`. CI pins these build-only dependencies:

- [package-build a0f92f5](https://github.com/melpa/package-build/commit/a0f92f5685fb6855bf1f09a39bea9d2185230e1c)
- [compat 90880f8](https://github.com/emacs-compat/compat/commit/90880f81419577e1d3f68424d2a3adf31e6d663e)

For local use, clone those repositories at those commits into
`.build-tools/package-build` and `.build-tools/compat`, or set
`EMACS_TUI_BUILD_TOOLS` to their parent directory. Use Emacs 29.1 or later for
the current package-build tool; the library itself still supports Emacs 28.1+.
The runner requires Git, Python 3, tar and a committed source checkout.

The runner seeds an isolated Git cache from the checkout, verifies the tested
commit and adds a test-only `:commit` constraint to the real GitHub recipe.
It uses package-build's documented no-fetch mode so a moving remote branch
cannot replace the code under test. The original checkout is never reset.
This tests recipe parsing, file selection, metadata, archive generation and
installation; it does not test network fetching or a live MELPA publication.
The unsubmitted recipe has no commit constraint and includes all five library
files plus LICENSE.

A separate Emacs process installs the tar into a fresh package directory, with
an empty working directory and no checkout or build-tool load path. It checks
library resolution and actual function definitions come from that installation,
then exercises table filtering, hidden marked actions, native input/undo, tree
navigation, maximization and disposal through public APIs. No archive server or
package dependency downloads are needed during installation.

CI builds/installs using Emacs 31.1, then installs the identical archive in a
second fresh directory using Emacs 28.1. Source SHA, artifact name and SHA256
are printed. Set `EMACS_TUI_PACKAGE_OUTPUT` to retain the tar, source-commit
record, checksum and artifact-path file after a local run. No tagged release,
stable API, MELPA submission or acceptance is implied by these checks.
