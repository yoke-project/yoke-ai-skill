#!/usr/bin/env bash
# The checks described by essentials.std.md, one function per case.
# The documentation is a build of one page under checks/skills/site; nothing here reaches a network.

es_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
es_site="$es_root/checks/skills/site"

# es_run <skill files...> — regenerates at 9.9.9 from the fixture's build.
es_run() { python3 "$es_root/ci/essentials.py" --version 9.9.9 --site "$es_site" "$@"; }

# std: yoke-ai-skill:essentials.01
check_a_region_is_filled_from_what_its_marker_names() {
  local tmp verdict=0; tmp="$(mktemp -d)"
  cat > "$tmp/SKILL.md" <<'MD'
Written by hand.
<!-- essentials: guide/a-page table -->
<!-- essentials end -->
<!-- essentials: guide/a-page#the-verbs table -->
stale
<!-- essentials end -->
<!-- essentials: guide/a-page#the-verbs code -->
<!-- essentials end -->
<!-- essentials: guide/a-page#the-verbs code:go -->
<!-- essentials end -->
Also by hand.
MD
  es_run "$tmp/SKILL.md" > /dev/null || { echo "the regeneration failed"; rm -rf "$tmp"; return 1; }
  python3 - "$tmp/SKILL.md" <<'PY' || verdict=1
import sys
text = open(sys.argv[1]).read()
want = """Written by hand.
<!-- essentials: guide/a-page table -->
| Before |
| --- |
| the first section's table |
<!-- essentials end -->
<!-- essentials: guide/a-page#the-verbs table -->
| Verb | Does |
| --- | --- |
| `build` | builds a **package** — [another page](https://docs.yoke-project.dev/9.9.9/guide/other/) |
| `a\\|b` | a cell with a bar |
<!-- essentials end -->
<!-- essentials: guide/a-page#the-verbs code -->
```text
mkdir out
```
<!-- essentials end -->
<!-- essentials: guide/a-page#the-verbs code:go -->
```go
package main
func main() {}
```
<!-- essentials end -->
Also by hand.
"""
if text != want:
    raise SystemExit("the skill reads:\n" + text)
PY
  rm -rf "$tmp"
  return "$verdict"
}

# std: yoke-ai-skill:essentials.02
check_every_link_to_the_documentation_names_the_release() {
  local tmp; tmp="$(mktemp -d)"
  printf 'See https://docs.yoke-project.dev/0.1.0/reference/ and https://docs.yoke-project.dev/.\n' > "$tmp/SKILL.md"
  es_run "$tmp/SKILL.md" > /dev/null || { echo "the regeneration failed"; rm -rf "$tmp"; return 1; }
  grep -qx 'See https://docs.yoke-project.dev/9.9.9/reference/ and https://docs.yoke-project.dev/.' "$tmp/SKILL.md" \
    || { echo "the skill reads: $(cat "$tmp/SKILL.md")"; rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
}

# std: yoke-ai-skill:essentials.03
check_a_check_names_the_skill_that_differs() {
  local tmp said status; tmp="$(mktemp -d)"
  mkdir -p "$tmp/kept" "$tmp/edited"
  printf '<!-- essentials: guide/a-page table -->\n<!-- essentials end -->\n' > "$tmp/kept/SKILL.md"
  es_run "$tmp/kept/SKILL.md" > /dev/null || { echo "the regeneration failed"; rm -rf "$tmp"; return 1; }
  sed 's/the first section/edited by hand/' "$tmp/kept/SKILL.md" > "$tmp/edited/SKILL.md"
  cp "$tmp/edited/SKILL.md" "$tmp/edited.before"
  said="$(es_run --check "$tmp/kept/SKILL.md" "$tmp/edited/SKILL.md" 2>&1)"; status=$?
  [[ $status == 1 && "$said" == *edited/SKILL.md* && "$said" != *kept/SKILL.md* ]] \
    || { echo "the check exited $status saying: $said"; rm -rf "$tmp"; return 1; }
  cmp -s "$tmp/edited/SKILL.md" "$tmp/edited.before" || { echo "the check wrote the skill"; rm -rf "$tmp"; return 1; }
  es_run --check "$tmp/kept/SKILL.md" > /dev/null || { echo "a regenerated skill is said to differ"; rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
}

# std: yoke-ai-skill:essentials.04
check_a_section_the_page_does_not_have_is_a_fault() {
  local tmp marker said status; tmp="$(mktemp -d)"
  for marker in "guide/a-page#later code" "guide/a-page#nowhere table"; do
    printf '<!-- essentials: %s -->\n<!-- essentials end -->\n' "$marker" > "$tmp/SKILL.md"
    cp "$tmp/SKILL.md" "$tmp/before"
    said="$(es_run "$tmp/SKILL.md" 2>&1)"; status=$?
    [[ $status == 2 && "$said" == *"${marker%% *}"* ]] || { echo "$marker: exited $status saying: $said"; rm -rf "$tmp"; return 1; }
    cmp -s "$tmp/SKILL.md" "$tmp/before" || { echo "$marker: the skill was written"; rm -rf "$tmp"; return 1; }
  done
  rm -rf "$tmp"
}

# std: yoke-ai-skill:essentials.05
check_the_three_skills_are_written_once_by_role() {
  python3 - "$es_root/skills" <<'PY'
import pathlib, re, sys
skills = pathlib.Path(sys.argv[1])
found = sorted(p.name for p in skills.iterdir() if p.is_dir())
if found != ["yoke", "yoke-plugin", "yoke-ui"]:
    raise SystemExit(f"the skills are {found}")
for name in found:
    text = (skills / name / "SKILL.md").read_text()
    head = re.match(r"---\n(.*?)\n---\n", text, re.S)
    if not head:
        raise SystemExit(f"{name}: no head")
    fields = dict(line.split(": ", 1) for line in head.group(1).splitlines() if ": " in line)
    if fields.get("name") != name or not fields.get("description", "").strip():
        raise SystemExit(f"{name}: the head is {fields}")
    if text.count("<!-- essentials: ") != text.count("<!-- essentials end -->"):
        raise SystemExit(f"{name}: a marker is not closed")
PY
}
