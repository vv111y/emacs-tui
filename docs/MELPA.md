# MELPA release gates

Verified against upstream on 2026-10-23; recheck before submission.

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
           :files ("emacs-tui*.el"))
```

Recheck recipe name availability. The existing
[tui.el](https://github.com/ebpa/tui.el) uses `tui-*`; this package uses
`emacs-tui-*`. Explain concrete differences from that package and from Helm,
Corfu/Posframe and ordinary window helpers rather than claiming they cannot
support rich interfaces.

Submission and acceptance are separate gates. MELPA maintainers control the
latter; pending review is not a completed release objective.
