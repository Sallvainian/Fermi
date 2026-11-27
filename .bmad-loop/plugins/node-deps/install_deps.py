#!/usr/bin/env python3
"""node-deps hook: put a real node_modules inside a freshly created worktree.

Runs as a bmad-loop declarative hook at pre_worktree_setup (cwd = the worktree).
Standard library only. Contract with bmad-loop:
  * everything goes to stdout (bmad-loop appends stderr AFTER stdout, which would
    hide the control JSON), and
  * the LAST stdout line is a JSON object; on failure it carries a veto.
The script always exits 0 so the veto action comes from the on_failure setting
rather than bmad-loop's default "non-zero exit = defer".
"""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

MARKER = ".node-deps.json"  # written inside node_modules after a good install
LOCKFILES = ("pnpm-lock.yaml", "bun.lock", "bun.lockb", "yarn.lock", "package-lock.json")
STALE_CACHES = (".vite", ".cache", ".vitest", ".tmp")  # caches + tsbuildinfo that belong to the main checkout


def say(msg: str) -> None:
    print(f"[node-deps] {msg}", flush=True)


def finish(ok: bool, reason: str = "", **shared: object) -> None:
    action = os.environ.get("BMAD_LOOP_SETTING_ON_FAILURE", "pause")
    payload: dict = {"shared": {"node_deps": {"ok": ok, **shared}}}
    if not ok:
        say(f"FAILED: {reason}")
        if action in ("pause", "defer"):
            payload["veto"] = {"action": action, "reason": f"node-deps: {reason}"}
        else:
            say("on_failure = warn: continuing without dependencies")
    print(json.dumps(payload), flush=True)
    sys.exit(0)


def setting(key: str, default: str = "") -> str:
    return os.environ.get(f"BMAD_LOOP_SETTING_{key.upper()}", default).strip()


def lock_digest(project: Path) -> str:
    h = hashlib.sha256()
    for name in ("package.json", *LOCKFILES):
        p = project / name
        if p.is_file():
            h.update(name.encode() + b"\0" + p.read_bytes() + b"\0")
    return h.hexdigest()


def detect_command(project: Path) -> list[str]:
    """Frozen, offline-preferring install for whichever package manager the repo uses."""
    pm = ""
    try:
        pm = json.loads((project / "package.json").read_text()).get("packageManager", "")
    except (OSError, ValueError, AttributeError):
        pass
    name = pm.split("@", 1)[0] if pm else ""
    if not name:
        if (project / "pnpm-lock.yaml").exists():
            name = "pnpm"
        elif (project / "bun.lock").exists() or (project / "bun.lockb").exists():
            name = "bun"
        elif (project / "yarn.lock").exists():
            name = "yarn"
        else:
            name = "npm"
    if name == "pnpm":
        return ["pnpm", "install", "--frozen-lockfile", "--prefer-offline"]
    if name == "bun":
        return ["bun", "install", "--frozen-lockfile"]
    if name == "yarn":
        berry = (project / ".yarnrc.yml").exists() or (
            pm.startswith("yarn@") and not pm.startswith("yarn@1.")
        )
        return ["yarn", "install", "--immutable"] if berry else ["yarn", "install", "--frozen-lockfile"]
    if (project / "package-lock.json").exists() or (project / "npm-shrinkwrap.json").exists():
        return ["npm", "ci", "--prefer-offline", "--no-audit", "--no-fund"]
    return ["npm", "install", "--prefer-offline", "--no-audit", "--no-fund"]


def run(cmd: list[str] | str, cwd: Path) -> tuple[int, str]:
    env = dict(os.environ)
    env.setdefault("CI", "1")  # no interactive prompts, no progress bars
    try:
        proc = subprocess.run(
            cmd,
            cwd=cwd,
            env=env,
            shell=isinstance(cmd, str),
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            stdin=subprocess.DEVNULL,
            text=True,
            errors="replace",
        )
    except OSError as e:
        return 127, str(e)
    return proc.returncode, proc.stdout


def clone(src: Path, dst: Path) -> tuple[int, str]:
    """Copy-on-write clone that keeps symlinks as symlinks."""
    if sys.platform == "darwin":
        rc, out = run(["cp", "-cR", str(src), str(dst)], dst.parent)
        if rc == 0:
            return rc, out
        shutil.rmtree(dst, ignore_errors=True)
        say("cp -c failed (volume not APFS?), falling back to a plain copy")
    elif sys.platform.startswith("linux"):
        rc, out = run(["cp", "-a", "--reflink=auto", str(src), str(dst)], dst.parent)
        if rc == 0:
            return rc, out
        shutil.rmtree(dst, ignore_errors=True)
    try:
        shutil.copytree(src, dst, symlinks=True)
    except OSError as e:
        return 1, str(e)
    return 0, ""


def main() -> None:
    worktree = Path(os.environ.get("BMAD_LOOP_WORKTREE") or os.getcwd()).resolve()
    repo_root = Path(os.environ.get("BMAD_LOOP_REPO_ROOT") or worktree).resolve()
    if worktree == repo_root:
        say("not an isolated worktree (shared checkout): nothing to do")
        finish(True, skipped="shared")

    rel = setting("project_dir")
    project = (worktree / rel).resolve() if rel else worktree
    if worktree not in (project, *project.parents):
        finish(False, f"project_dir {rel!r} escapes the worktree")
    if not (project / "package.json").is_file():
        say(f"no package.json in {project}: nothing to do")
        finish(True, skipped="no-package-json")

    nm = project / "node_modules"
    digest = lock_digest(project)

    # A symlinked node_modules points back outside the worktree: the exact
    # condition behind TS2883. Unlinking removes only the link, never its target.
    if nm.is_symlink():
        say("replacing symlinked node_modules with a real one")
        nm.unlink()

    marker = nm / MARKER
    if nm.is_dir() and marker.is_file():
        try:
            if json.loads(marker.read_text()).get("digest") == digest:
                say("node_modules already current for this lockfile: skipping")
                finish(True, skipped="current")
        except (OSError, ValueError):
            pass

    strategy = setting("strategy", "install") or "install"
    if strategy == "clone":
        src_project = (repo_root / rel).resolve() if rel else repo_root
        src = src_project / "node_modules"
        if not src.is_dir():
            finish(False, f"clone strategy: {src} does not exist (install in the main checkout first)")
        if lock_digest(src_project) != digest:
            say("warning: main checkout lockfile differs from this worktree's branch")
        if nm.exists():
            shutil.rmtree(nm)
        say(f"cloning {src} -> {nm}")
        rc, out = clone(src, nm)
        for cache in STALE_CACHES:
            shutil.rmtree(nm / cache, ignore_errors=True)
        label = "clone"
    else:
        override = setting("install_command")
        cmd: list[str] | str = override or detect_command(project)
        label = cmd if isinstance(cmd, str) else " ".join(cmd)
        if not override and shutil.which(cmd[0]) is None:
            finish(False, f"{cmd[0]} not found on PATH (set install_command to override)")
        say(f"running `{label}` in {project}")
        rc, out = run(cmd, project)

    tail = "\n".join(out.strip().splitlines()[-25:])
    if tail:
        print(tail, flush=True)
    if rc != 0:
        finish(False, f"`{label}` exited {rc}")
    if not nm.is_dir():
        finish(False, f"`{label}` succeeded but {nm} was not created")

    marker.write_text(json.dumps({"digest": digest, "strategy": strategy}))
    say(f"node_modules ready ({strategy})")
    finish(True, strategy=strategy)


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as e:  # never let a traceback (stderr) bury the control JSON
        finish(False, f"{type(e).__name__}: {e}")
