# MELPA release gates

Verified against upstream on 2026-10-24; recheck before submission. The checked
PR-template blob was `80f2e31cdfbb65fb9c0bf04b093e0e4adad84bfe`;
CONTRIBUTING.org was `1c5c09605cbe26c8279d0efa83375ef3c679077d`.

- [PR template](https://github.com/melpa/melpa/blob/master/.github/PULL_REQUEST_TEMPLATE.md)
  requires at least one month of maintenance in a public repository.
- [Contribution guidance](https://github.com/melpa/melpa/blob/master/CONTRIBUTING.org)
  expects innovative, mature, actively maintained software. It requests an
  `Assisted-by` header and says the human author should be the first and most
  thorough reviewer of AI-assisted output. Autonomous development does not
  satisfy that human-review expectation. Discuss any alternative with MELPA
  maintainers honestly; never check a false attestation.
- GPL-compatible license, lexical binding, package metadata, latest
  package-lint, checkdoc and clean byte compilation are expected.
- Build the actual recipe using package-build and install/test its output in a
  clean Emacs. A source checkout test is not a package installation test.

Candidate recipe, not yet submitted:

```elisp
(emacs-tui :fetcher github :repo "vv111y/emacs-tui"
           :files ("emacs-tui*.el" "LICENSE"))
```

The executable candidate is in `test/recipes/emacs-tui`. See
[PACKAGING.md](PACKAGING.md) for exact-checkout package-build and clean-install
validation. This does not submit a recipe or test a live MELPA publication.

On 2026-10-24, the upstream `recipes/emacs-tui` path returned 404. This is
current absence, not a reservation or acceptance; recheck name availability
before submission. The existing
[tui.el](https://github.com/ebpa/tui.el) uses `tui-*`; this package uses
`emacs-tui-*`. Explain concrete differences from that package and from Helm,
Corfu/Posframe and ordinary window helpers rather than claiming they cannot
support rich interfaces.

Submission and acceptance are separate gates. MELPA maintainers control the
latter; pending review is not a completed release objective.
