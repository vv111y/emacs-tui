# Copyright (C) 2026 Willy Rempel
# Author: Willy Rempel <https://github.com/vv111y>
# Assisted-by: Codex:gpt-6.1-sol-wm
# SPDX-License-Identifier: GPL-3.0-or-later

"""Build the real candidate recipe and test installation outside the checkout."""
import hashlib
import os
import pathlib
import shutil
import subprocess
import tarfile
import tempfile

project = pathlib.Path(__file__).resolve().parent.parent
source = pathlib.Path(os.environ.get("EMACS_TUI_PACKAGE_SOURCE", project)).resolve()
tools = pathlib.Path(os.environ.get("EMACS_TUI_BUILD_TOOLS", project / ".build-tools")).resolve()
emacs = os.environ.get("EMACS", "emacs")
for library in (tools / "compat" / "compat.el", tools / "package-build" / "package-build.el"):
    if not library.is_file():
        raise SystemExit(f"Missing build dependency: {library}; see docs/PACKAGING.md")
sha = subprocess.check_output(["git", "-C", str(source), "rev-parse", "HEAD"], text=True).strip()
if os.environ.get("GITHUB_SHA") and sha != os.environ["GITHUB_SHA"]:
    raise SystemExit("Checkout HEAD does not match the CI commit")
with tempfile.TemporaryDirectory(prefix="emacs-tui-package-") as temporary:
    root = pathlib.Path(temporary)
    cache = root / "working" / "emacs-tui"
    cache.parent.mkdir()
    subprocess.run(["git", "clone", "--no-hardlinks", str(source), str(cache)], check=True)
    subprocess.run(["git", "-C", str(cache), "remote", "set-url", "origin",
                    "https://github.com/vv111y/emacs-tui"], check=True)
    env = dict(os.environ, EMACS_TUI_PACKAGE_ROOT=str(root), EMACS_TUI_PACKAGE_SHA=sha,
               EMACS_TUI_PACKAGE_RECIPE=str(project / "test" / "recipes" / "emacs-tui"))
    env.pop("EMACSLOADPATH", None)
    if env.get("EMACS_TUI_EXPECT_PACKAGE_VERSION"):
        subprocess.run([emacs, "-Q", "--batch", "-l",
                        str(project / "test" / "package-metadata-smoke.el")],
                       cwd=source, env=env, check=True)
    subprocess.run([emacs, "-Q", "--batch", "-L", str(tools / "compat"),
                    "-L", str(tools / "package-build"), "-l", str(project / "test" / "build-package.el")],
                   cwd=root, env=env, check=True)
    archive = pathlib.Path((root / "artifact-path.txt").read_text())
    with tarfile.open(archive) as package:
        names = {pathlib.PurePosixPath(member.name).name for member in package.getmembers()}
        required = {"emacs-tui.el", "emacs-tui-layout.el", "emacs-tui-table.el",
                    "emacs-tui-tree.el", "emacs-tui-action.el", "emacs-tui-completion.el",
                    "emacs-tui-pkg.el", "LICENSE"}
        if not required <= names:
            raise SystemExit(f"Archive missing required files: {required - names}")
        if any(".git" in pathlib.PurePosixPath(member.name).parts for member in package.getmembers()):
            raise SystemExit("Archive unexpectedly includes Git metadata")
    install_working = root / "install-working"
    install_working.mkdir()
    env.update(EMACS_TUI_PACKAGE_ARCHIVE=str(archive), EMACS_TUI_INSTALL_ROOT=str(root / "install"))
    subprocess.run([emacs, "-Q", "--batch", "-l", str(project / "test" / "package-install-smoke.el")],
                   cwd=install_working, env=env, check=True)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    print(f"PASS recipe build and clean install; source={sha}; artifact={archive.name}; sha256={digest}")
    if os.environ.get("EMACS_TUI_PACKAGE_OUTPUT"):
        output = pathlib.Path(os.environ["EMACS_TUI_PACKAGE_OUTPUT"]).resolve()
        output.mkdir(parents=True, exist_ok=True)
        saved = output / archive.name
        shutil.copy2(archive, saved)
        (output / "artifact-path.txt").write_text(str(saved))
        (output / "source-commit.txt").write_text(sha + "\n")
        (output / "SHA256SUMS").write_text(f"{digest}  {saved.name}\n")
