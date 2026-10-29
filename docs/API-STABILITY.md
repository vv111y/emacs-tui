# Public API and compatibility

emacs-tui 0.1.0-beta6 is an experimental community-testing release. Its release
ref and successful archive builds do not constitute a stable compatibility
freeze or MELPA acceptance. This policy defines how we work toward that contract.

## Supported application surface

Use the constructors, lifecycle functions, update/query/selection/mark/tree
commands, actions and keymap extension points documented in the
[README](../README.md) and their docstrings. `emacs-tui-layout-compute` is a
documented pure geometry helper. Examples demonstrate application policies;
their private helpers are not library APIs.

Session and view handles are opaque. Do not read or mutate `emacs-tui--*`
structures, row caches, overlays or ownership parameters in application code.
Internal names, cache strategies and buffer/window arrangements may change.
Tests may inspect these details to verify invariants; that does not make them
public extension points. Use named view IDs and public commands to address a
panel, including a hidden one, rather than retaining toolkit window positions.

Applications own objects, persistent effects and transaction policies. Selection
and explicit actions receive original source objects. Stable unique identities
allow selection, marks and tree expansion to survive replacement snapshots
according to the documented rules. Filtering, layout and focus do not implicitly
run an application action. A sequence of view updates is not a cross-view
transaction. Individual staged-update guarantees are documented per operation.

Pure projection, comparator, child-accessor and availability callbacks must
return promptly. Do not rely on undocumented invocation counts or use these
callbacks for side effects: optimizations can change evaluation strategies.
Keep effects in explicit action/change callbacks. Provider generations,
cancellation and close callbacks retain their documented lifecycle contracts.

## Changes during experimental development

Compatible additions should preserve existing calls and defaults. Incompatible
changes require release notes identifying the old behavior, the replacement and
a runnable migration example. Keep an alias or compatibility path where doing
so is practical and does not perpetuate a correctness defect. Bug fixes can
correct behavior that violated the documented contract; describe material
observable differences, including rendering changes.

For tagged 0.x releases, incompatible public API changes increment the minor
version; patch releases contain compatible fixes. Compatible additions may also
increment the minor version. Unreleased development commits must not be mistaken
for an independently tested release simply because they share a package header.
Reviewers must check the documented surface and installed-client tests when
changing a public signature, callback contract, identity rule or default.

There is no migration required for the recent additive title, bulk marking,
named selection and whole-tree expansion commands. Titles are literal strings,
including percent signs; mode-line formatting inside a title is not supported.

## Stable-release gate

A 1.0 release requires substantive application use, reviewed API documentation,
resolved readiness findings, supported-version/package/terminal validation and
release notes. Public maintenance duration and the human-review checkpoint in
[MELPA guidance](MELPA.md) remain separate gates. Neither elapsed time nor a
passing test suite establishes maturity on its own.

For a stable 1.x API, compatible additions belong in minor releases, compatible
fixes in patch releases, and incompatible public changes require a major
release with a migration guide. Backend selection remains capability-based.
Existing workspace presentations retain the documented ordinary-window fallback.
Source-preserving floating popups explicitly require native child frames and
reject unsupported displays; callers can check capability before activation.
Any change to the supported Emacs floor must be explicit in metadata and release
notes and validated with the resulting package artifact.
