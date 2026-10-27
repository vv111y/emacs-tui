# XOB adapter boundary

Source inspection on 2026-10-27 used the owner's
[org-xob repository at b097f5e](https://github.com/vv111y/org-xob/tree/b097f5e255f7cc0a9950c059c81df90eca95795b),
whose commit is dated 2026-10-22. This is an integration assessment, not a new
XOB release or an executed adapter test. No XOB startup, user files or data were
touched. emacs-tui remains independent of Org and XOB.

## Existing entry points

- `org-xob-map-all-nodes` in
  [org-xob-core.el](https://github.com/vv111y/org-xob/blob/b097f5e255f7cc0a9950c059c81df90eca95795b/org-xob-core.el)
  selects nodes from `org-xob-buffers`. Its name does not establish a catalogue
  of every original node in the knowledge base; these are the active XOB buffers.
- `org-xob-visit-nodes` visits a supplied file list with `find-file`, changes the
  selected buffer during traversal and uses an internal deep node predicate.
  It is not an appropriate implicit per-keystroke preview provider.
- `org-xob-get-node`, `org-xob-insert-link` and `org-xob-show-backlinks` in
  [org-xob.el](https://github.com/vv111y/org-xob/blob/b097f5e255f7cc0a9950c059c81df90eca95795b/org-xob.el)
  are application commands. They open/select/edit or populate contextual data;
  they are not pure node snapshots. Link insertion has XOB-specific placeholder,
  backlink and logging behavior that a generic Org-link insertion would lose.
- Direct content and forward/backlink collection helpers in
  [org-xob-backend.el](https://github.com/vv111y/org-xob/blob/b097f5e255f7cc0a9950c059c81df90eca95795b/org-xob-backend.el)
  use the private `org-xob--` prefix. Do not silently turn those internals into
  a stable dependency of this toolkit.

## Constraints on the first optional adapter

Loading XOB core changes Org link handlers and org-super-links settings.
Starting XOB selects a repository, loads/rebuilds state, opens a day node and
installs hooks and a midnight timer. Therefore opening a TUI preview must not
implicitly load/start XOB. An adapter should require an explicitly initialized
XOB application and keep that dependency outside the core package.

The next useful integration unit is a documented, read-only snapshot contract
for IDs/titles, content and forward/backlinks, plus a separate explicit action
for insertion or opening. Establish it with the XOB application before promising
a complete knowledge-base browser. A narrower prototype over active XOB buffers
must label that scope honestly. Preview must preserve source text, point,
narrowing, user data and window ownership; actions retain XOB's own link policy.

Validate against a disposable knowledge base with duplicate titles, missing IDs,
unsaved edits, cycles, repository switching and stale callbacks. Ordinary-window
and floating presentations should consume the same snapshot. No user knowledge
base should be used as a test fixture, and no API stability is claimed here.
