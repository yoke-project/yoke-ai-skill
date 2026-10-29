#!/usr/bin/env bash
# The checks described by the-release-run.std.md, one function per case.
# A copy of this repository is made in a temporary directory, with its documentation a build under
# checks/skills/site and its programs two scripts; nothing here reaches a network.

rr_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# rr_copy <dir> [edit]: a copy of this repository's scripts with one skill regenerated and packaged at
# 9.9.9 and committed; with edit, its region is edited by hand before the commit. Tagging is the caller's.
rr_copy() {
  mkdir -p "$1/skills/one" "$1/programs"
  cp -R "$rr_root/ci" "$1/"
  cat > "$1/skills/one/SKILL.md" <<'MD'
---
name: one
description: the one skill
---

Read https://docs.yoke-project.dev/9.9.9/guide/a-page/ and run `yoke-compose check`.
<!-- essentials: guide/a-page#the-verbs table -->
<!-- essentials end -->
MD
  printf '#!/bin/sh\necho "  yoke app run <id>"\n' > "$1/programs/yoke"
  printf '#!/bin/sh\necho "  check [--dir D]" >&2\n' > "$1/programs/yoke-compose"
  chmod +x "$1/programs/yoke" "$1/programs/yoke-compose"
  (cd "$1" && python3 ci/essentials.py --version 9.9.9 --site "$rr_root/checks/skills/site" skills/one/SKILL.md > /dev/null \
    && python3 ci/package.py --version 9.9.9 > /dev/null) || return 1
  [[ -n "${2:-}" ]] && sed -i 's/builds a/edited by hand, builds a/' "$1/skills/one/SKILL.md"
  (cd "$1" && git init -q && git add -A && git -c user.name=check -c user.email=check@example.com commit -qm copy)
}

# rr_release <dir>: the verb, run in the copy against the fixture's build and programs.
rr_release() {
  (cd "$1" && RELEASE_SITE="$rr_root/checks/skills/site" RELEASE_PROGRAMS="$1/programs" RELEASE_POLL=0 RELEASE_TRIES=1 \
    bash ci/release.sh)
}

# std: yoke-ai-skill:the-release-run.01
check_an_untagged_commit_publishes_nothing() {
  local tmp out status; tmp="$(mktemp -d)"
  rr_copy "$tmp" || { echo "the copy could not be made"; rm -rf "$tmp"; return 1; }
  out="$(rr_release "$tmp" 2> "$tmp.said")"; status=$?
  [[ $status == 0 && -z "$out" ]] && grep -q 'no release tag names it' "$tmp.said" \
    || { echo "exited $status, printed '$out', said: $(cat "$tmp.said")"; rm -rf "$tmp" "$tmp.said"; return 1; }
  rm -rf "$tmp" "$tmp.said"
}

# std: yoke-ai-skill:the-release-run.02
check_a_release_tag_checks_the_skills_and_names_the_tree() {
  local tmp out status; tmp="$(mktemp -d)"
  rr_copy "$tmp" || { echo "the copy could not be made"; rm -rf "$tmp"; return 1; }
  git -C "$tmp" tag v9.9.9
  out="$(rr_release "$tmp" 2> "$tmp.said")"; status=$?
  [[ $status == 0 ]] || { echo "exited $status: $(cat "$tmp.said")"; rm -rf "$tmp" "$tmp.said"; return 1; }
  python3 - "$out" "$(git -C "$tmp" rev-parse HEAD)" "sha256:$(git -C "$tmp" archive --format=tar v9.9.9 | sha256sum | cut -d' ' -f1)" <<'PY' \
    || { rm -rf "$tmp" "$tmp.said"; return 1; }
import json, sys
out, commit, digest = sys.argv[1:]
lines = out.splitlines()
if len(lines) != 1:
    raise SystemExit(f"the output is {lines}")
line = json.loads(lines[0])
want = {"line": "publication", "published": "yoke-ai-skill", "version": "v9.9.9", "commit": commit,
        "digests": [digest], "where": "https://github.com/yoke-project/yoke-ai-skill/tree/v9.9.9", "licence": "CC-BY-4.0"}
wrong = {k: line.get(k) for k, v in want.items() if line.get(k) != v}
if wrong:
    raise SystemExit(f"the line holds {wrong}")
PY
  rm -rf "$tmp" "$tmp.said"
}

# std: yoke-ai-skill:the-release-run.03
check_a_tag_the_skills_do_not_hold_against_publishes_nothing() {
  local tmp out status; tmp="$(mktemp -d)"
  rr_copy "$tmp" edit || { echo "the copy could not be made"; rm -rf "$tmp"; return 1; }
  git -C "$tmp" tag v9.9.9
  out="$(rr_release "$tmp" 2> "$tmp.said")"; status=$?
  [[ $status == 1 && -z "$out" ]] && grep -q 'skills/one/SKILL.md' "$tmp.said" && grep -q 'do not hold against release 9.9.9' "$tmp.said" \
    || { echo "exited $status, printed '$out', said: $(cat "$tmp.said")"; rm -rf "$tmp" "$tmp.said"; return 1; }
  rm -rf "$tmp" "$tmp.said"
}

# std: yoke-ai-skill:the-release-run.04
check_a_release_tag_runs_the_verb_and_keeps_its_line() {
  local w="$rr_root/.github/workflows/release.yml"
  [[ -f "$w" ]] || { echo "no release workflow"; return 1; }
  grep -qE "tags: \['v\*'\]" "$w" || { echo "it does not run on a release tag"; return 1; }
  grep -q 'fetch-depth: 0' "$w" || { echo "the checkout does not carry the tags"; return 1; }
  grep -q 'just release > manifest-lines.jsonl' "$w" || { echo "it does not run the verb into manifest-lines.jsonl"; return 1; }
  grep -q 'name: manifest-lines' "$w" && grep -q 'path: manifest-lines.jsonl' "$w" || { echo "the line is not kept as manifest-lines"; return 1; }
  grep -q 'contents: read' "$w" && ! grep -q 'contents: write' "$w" || { echo "it may write"; return 1; }
}
