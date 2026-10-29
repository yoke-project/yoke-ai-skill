#!/usr/bin/env python3
"""Generates the two packages from the one source of the skills, and checks they are equal to it.

From `skills/<name>/SKILL.md`, the source, it writes:

    .claude-plugin/marketplace.json           the marketplace Claude Code reads, naming one plugin
    claude/yoke/.claude-plugin/plugin.json    that plugin, at the release's version
    claude/yoke/skills/<name>/SKILL.md        each skill, as the source has it
    antigravity/<name>/SKILL.md               each skill, as Antigravity's folders take it

A skill is copied byte for byte into both: the open form is the same file for both agents, and a package
that rewrote it would be a second source. Nothing else is written, and a file the packages hold that no
skill accounts for is removed.

Usage: package.py --version <version> [--check] [<root>]
With --check nothing is written, and every file that differs from what the source makes is named.
"""
import argparse
import json
import pathlib
import re
import sys

PLUGIN = "yoke"
DESCRIPTION = ("Skills for building an application with Yoke: the concepts and the command line, a Plugin in "
               "any of five languages, and an interface client.")
HOMEPAGE = "https://docs.yoke-project.dev/"
REPOSITORY = "https://github.com/yoke-project/yoke-ai-skill"


def made(root: pathlib.Path, version: str) -> dict:
    """Every file the packages hold, by its path under the root, as the source makes it."""
    skills = sorted(p.parent.name for p in (root / "skills").glob("*/SKILL.md"))
    files = {}
    plugin = {"name": PLUGIN, "version": version, "description": DESCRIPTION,
              "author": {"name": "The Yoke project"}, "homepage": HOMEPAGE, "repository": REPOSITORY,
              "license": "CC-BY-4.0"}
    files[".claude-plugin/marketplace.json"] = json.dumps({
        "name": PLUGIN, "owner": {"name": "The Yoke project"}, "description": DESCRIPTION,
        "plugins": [{"name": PLUGIN, "source": f"./claude/{PLUGIN}", "description": DESCRIPTION, "version": version}],
    }, indent=2) + "\n"
    files[f"claude/{PLUGIN}/.claude-plugin/plugin.json"] = json.dumps(plugin, indent=2) + "\n"
    for name in skills:
        text = (root / "skills" / name / "SKILL.md").read_text()
        files[f"claude/{PLUGIN}/skills/{name}/SKILL.md"] = text
        files[f"antigravity/{name}/SKILL.md"] = text
    return files


def held(root: pathlib.Path) -> dict:
    """Every file the packages hold now."""
    found = {}
    for top in (".claude-plugin", "claude", "antigravity"):
        for p in (root / top).rglob("*"):
            if p.is_file():
                found[p.relative_to(root).as_posix()] = p.read_text()
    return found


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--version", required=True)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("root", nargs="?", default=".")
    o = parser.parse_args()
    if not re.fullmatch(r"\d+\.\d+\.\d+", o.version):
        print(f"package: {o.version!r} is not a release's version", file=sys.stderr)
        return 1
    root = pathlib.Path(o.root)
    want, have = made(root, o.version), held(root)
    differ = sorted(p for p in set(want) | set(have) if want.get(p) != have.get(p))
    if o.check:
        if differ:
            print("package: these differ from what the skills make at " + o.version + ": " + ", ".join(differ))
            return 1
        return 0
    for path in differ:
        target = root / path
        if path in want:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(want[path])
        else:
            target.unlink()
    print(f"package: {len(differ)} files written or removed, at {o.version}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
