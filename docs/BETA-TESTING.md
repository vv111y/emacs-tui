# Community beta testing

Try one workflow you would actually use. A short report of a concrete failure,
or a successful run on an untested display, is more useful than running every
demo. The API is experimental; this guide is a human-use checklist, not a claim
that these environments have passed.

## Choose a matching checkout

The reproducible community snapshot is `release/0.1.0-beta4`. It contains the
runtime and all twelve matching gallery entries. The examples are not installed
by the straight.el runtime recipe; run them from a checkout:

```sh
git clone --branch release/0.1.0-beta4 https://github.com/vv111y/emacs-tui.git emacs-tui-beta4
cd emacs-tui-beta4
git rev-parse HEAD
make gallery
```

Use `make gallery EMACS=/path/to/emacs` if the shell's Emacs differs from your
usual one. Make targets start a fresh `emacs -Q -nw`, avoiding mixed loaded
versions. To test graphical Emacs, from the same checkout run:

```sh
emacs -Q -L . -l examples/emacs-tui-gallery.el -f emacs-tui-gallery
```

For development fixes and newer controls, use a separate main checkout and
record its exact `git rev-parse HEAD`. Do not load main examples into an already
running beta4 runtime. Main includes Details pinning (`C-c C-d`) and horizontal
panning (`C-c <` / `C-c >`); fixed beta4 does not. See [DEMOS.md](DEMOS.md) for
the full tour and the [API policy](API-STABILITY.md) for compatibility limits.

Ordinary-window demos support Emacs 28.1+. Floating examples require graphical
child frames or `(featurep 'tty-child-frames)` in the actual Emacs build. On an
unsupported terminal, the gallery should report that requirement and remain
open without splitting your source window. A version number alone does not
establish native terminal child-frame support.

## Three short checks

Use disposable sample buffers. These checks exercise different application
policies; opening a demo, explicitly accepting text, and copying to the kill
ring have different effects.

| Workflow | Try | Expected result |
| --- | --- | --- |
| Several floating displays | `make multi-popup-demo`; type a short note, undo it, toggle each of `C-c 1/2/3` off and back on, then `C-c 0` twice | Typing and undo stay in the source; individual toggles leave siblings alone; all-toggle hides visible panels, then shows all |
| Placement and reading | In that demo, move each with `C-c p 1/2/3`, scroll Details with `C-c [ / ]`, resize it with `C-c C-e`, then resize the terminal | Source window/buffer and typing focus remain; each requested position and size survive hide/show. Near edges positions can coincide or overlap; there is no collision avoidance |
| Persistent form | `make form-demo`; edit Name, use TAB to Retries, replace it with `11` and try Apply (`C-c C-c`); change to `3` and Apply again, edit again and Revert with `C-c C-r` | Invalid input cannot apply; valid Apply keeps the form open; Revert restores session-local saved settings. It writes no preference files |

In the form's editable fields, paste a short multiline or Unicode sample,
use your normal input method, and undo. Resize before and after committing an
input-method composition. Report lost characters, duplicated text, unexpected preview changes, cursor
jumps or broken undo separately from the expected
single-line Name validation. Revert intentionally resets undo for changed fields.

On main only, pin Details with `C-c C-d`, browse with `M-n`, then release the
pin. The pinned object's text should stay until release; source typing remains
independent. Horizontal panning should survive movement/resizing and reset
when the displayed text changes.

For explicit text insertion, try `make completion-demo`: type `ca` after the
initial `(map`, choose a candidate with `M-n`/`M-p`, accept with TAB, then undo
with `C-/`. Selection alone must not insert anything. This demo invokes a real
completion provider but does not evaluate the sample Lisp. The completion demo
opens its initial popup on launch; use `C-M-i` to start another. Ordinary CAPF
activation is manual. The separate `popup-demo` begins filtering automatically
as you type.

Close the form, multi-popup or literal-word popup demo with `C-c C-q`.
For the native completion demo, `C-g` dismisses the current popup; run
`M-x emacs-tui-completion-mode` to disable its frontend, or kill its disposable
source buffer. It does not bind `C-c C-q`. Floating panels should disappear
and ordinary source editing should work. In the multi-popup demo, `C-g` only hides panels;
it deliberately keeps its toggle bindings active. Hiding and reopening resets
Details' reading position but retains its requested size/placement.

## Report the smallest useful reproduction

[Open a bug report](https://github.com/vv111y/emacs-tui/issues/new?template=bug_report.yml)
for incorrect behavior. [Share a beta experience](https://github.com/vv111y/emacs-tui/issues/new?template=beta_feedback.yml)
for successful display coverage or API/usability feedback. Include:

- The exact checkout commit or installed package revision, and whether the
  problem reproduces in the clean matching checkout above.
- Emacs version (`M-x emacs-version`), operating system and terminal emulator
  or graphical build. For tmux/zellij, give its version and whether it also
  happens outside the multiplexer. Unknown is an acceptable answer.
- The demo or a small self-contained application, exact keys, expected result
  and observed result. Include terminal dimensions if placement is involved.
- Whether source text changed, undo recovered it, or closing left resources
  visible. Include the error text if any; screenshots are optional.

To check the actual display capability, evaluate with `M-:`:

```elisp
(list :emacs emacs-version :system system-type
      :graphical (display-graphic-p)
      :tty-child-frames (featurep 'tty-child-frames))
```

For an error, enable `M-x toggle-debug-on-error` in the disposable demo Emacs,
reproduce once and copy the relevant backtrace. Turn it off afterward. Review
reports before posting: omit private buffer contents, filenames and credentials.
There is no need to upload your init file or entire session.

## What a report establishes

A successful Ghostty/iTerm2, tmux/zellij, graphical build or input-method report
establishes that specific revision, environment and workflow. It does not prove
all builds or all application lifetimes. Hosted PTY/tmux and GTK/Xvfb checks are
complementary evidence; human visual and API-usability feedback is still needed.
Beta acceptance and [MELPA review](MELPA.md) remain separate milestones.
