#!/usr/bin/env python3
"""Checks that every command a skill cites exists in the release's programs.

A command is cited where a line of a block of code, or a span of code, begins with `yoke` or
`yoke-compose` — after a prompt, a pipe or a `&&` too. For `yoke`, what is checked is the subject and the
operation, against the listing `yoke --help` prints; for `yoke-compose`, the verb and, for `add` and
`block`, what it adds, against the listing `yoke-compose` prints with no verb. A subject named alone exists
where the program has it. A word in angle brackets is a placeholder and ends what is checked.

Usage: commands.py --programs <directory holding yoke and yoke-compose> <file>...
"""
import argparse
import pathlib
import re
import subprocess
import sys

FENCE = re.compile(r"```[^\n]*\n(.*?)```", re.S)
SPAN = re.compile(r"`([^`\n]+)`")
START = re.compile(r"(?:^|\$ |\| |&& |; )((?:yoke-compose|yoke)(?: [^\s|;&]+)*)")
TWO = {"add", "block"}


def listing(programs: pathlib.Path) -> tuple:
    """What each program says it takes: yoke's subject and operation, yoke-compose's verbs."""
    said = subprocess.run([str(programs / "yoke"), "--help"], capture_output=True, text=True)
    yoke = set()
    for line in (said.stdout + said.stderr).splitlines():
        words = line.split()
        if len(words) >= 2 and words[0] == "yoke":
            yoke.add(tuple(w for w in words[1:3] if not w.startswith(("<", "[", "-"))))
    said = subprocess.run([str(programs / "yoke-compose")], capture_output=True, text=True)
    compose = set()
    for line in (said.stdout + said.stderr).splitlines():
        if line.startswith("  ") and line.strip() and not line.startswith("   "):
            words = line.split()
            compose.add(tuple(words[:2]) if words[0] in TWO else (words[0],))
    return yoke, compose


def cited(text: str) -> set:
    """Every command the text cites, as the words that are checked."""
    places = [line for block in FENCE.findall(text) for line in block.splitlines()]
    places += SPAN.findall(FENCE.sub("", text))
    found = set()
    for place in places:
        for command in START.findall(place.strip()):
            words = command.split()
            program, rest = words[0], []
            for w in words[1:]:
                if w.startswith(("<", "[", "-", '"', "$")) or "=" in w:
                    break
                rest.append(w)
            if program == "yoke":
                found.add((program, tuple(rest[:2]) if rest[:1] != ["shell"] else ("shell",)))
            elif rest:
                found.add((program, tuple(rest[:2]) if rest[0] in TWO else (rest[0],)))
    return found


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--programs", required=True)
    parser.add_argument("files", nargs="+")
    o = parser.parse_args()
    yoke, compose = listing(pathlib.Path(o.programs))
    if not yoke or not compose:
        print("commands: the programs listed nothing they take", file=sys.stderr)
        return 2
    missing = []
    for f in o.files:
        for program, words in sorted(cited(pathlib.Path(f).read_text())):
            if not words:
                continue
            known = yoke if program == "yoke" else compose
            # A subject named alone, as a namespace is, exists where the program has it.
            if words not in known and not (len(words) == 1 and any(k[:1] == words for k in known)):
                missing.append(f"{f}: {program} {' '.join(words)}")
    for line in missing:
        print(f"commands: the release has no {line.split(': ', 1)[1]}, cited in {line.split(': ', 1)[0]}")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
