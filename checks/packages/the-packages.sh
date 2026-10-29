#!/usr/bin/env bash
# The checks described by the-packages.std.md, one function per case.
# Every tree, build and program here is made in a temporary directory; nothing reaches a network.

pk_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# pk_tree <dir> — a tree of two skills.
pk_tree() {
  mkdir -p "$1/skills/one" "$1/skills/two"
  printf -- '---\nname: one\ndescription: the first\n---\n\n# One\n' > "$1/skills/one/SKILL.md"
  printf -- '---\nname: two\ndescription: the second\n---\n\n# Two\n' > "$1/skills/two/SKILL.md"
}

# std: yoke-ai-skill:the-packages.01
check_both_packages_carry_every_skill_as_the_source_has_it() {
  local tmp verdict=0; tmp="$(mktemp -d)"
  pk_tree "$tmp"
  mkdir -p "$tmp/antigravity/gone" && echo stray > "$tmp/antigravity/gone/SKILL.md"
  python3 "$pk_root/ci/package.py" --version 9.9.9 "$tmp" > /dev/null || { echo "the packages were not made"; rm -rf "$tmp"; return 1; }
  python3 - "$tmp" <<'PY' || verdict=1
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
market = json.loads((root / ".claude-plugin/marketplace.json").read_text())
if [(p["name"], p["source"], p["version"]) for p in market["plugins"]] != [("yoke", "./claude/yoke", "9.9.9")]:
    raise SystemExit(f"the marketplace lists {market['plugins']}")
plugin = json.loads((root / "claude/yoke/.claude-plugin/plugin.json").read_text())
if plugin.get("version") != "9.9.9" or plugin.get("license") != "CC-BY-4.0":
    raise SystemExit(f"the plugin's manifest is {plugin}")
for name in ("one", "two"):
    source = (root / "skills" / name / "SKILL.md").read_bytes()
    for copy in (root / "claude/yoke/skills" / name / "SKILL.md", root / "antigravity" / name / "SKILL.md"):
        if copy.read_bytes() != source:
            raise SystemExit(f"{copy} is not the source's")
if (root / "antigravity/gone/SKILL.md").exists():
    raise SystemExit("the stray file is still there")
PY
  rm -rf "$tmp"
  return "$verdict"
}

# std: yoke-ai-skill:the-packages.02
check_a_check_names_every_file_that_differs() {
  local tmp said status; tmp="$(mktemp -d)"
  pk_tree "$tmp"
  python3 "$pk_root/ci/package.py" --version 9.9.9 "$tmp" > /dev/null || { echo "the packages were not made"; rm -rf "$tmp"; return 1; }
  echo edited >> "$tmp/antigravity/one/SKILL.md"
  echo added > "$tmp/claude/yoke/skills/extra.md"
  echo changed >> "$tmp/skills/two/SKILL.md"
  (cd "$tmp" && find . -type f | sort | xargs sha256sum) > "$tmp.before"
  said="$(python3 "$pk_root/ci/package.py" --check --version 9.9.9 "$tmp")"; status=$?
  for named in antigravity/one/SKILL.md claude/yoke/skills/extra.md antigravity/two/SKILL.md claude/yoke/skills/two/SKILL.md; do
    [[ "$said" == *"$named"* ]] || { echo "exited $status without naming $named: $said"; rm -rf "$tmp" "$tmp.before"; return 1; }
  done
  [[ $status == 1 && "$said" != *marketplace* ]] || { echo "exited $status saying: $said"; rm -rf "$tmp" "$tmp.before"; return 1; }
  (cd "$tmp" && find . -type f | sort | xargs sha256sum) | cmp -s - "$tmp.before" || { echo "the check wrote the tree"; rm -rf "$tmp" "$tmp.before"; return 1; }
  said="$(python3 "$pk_root/ci/package.py" --check --version 9.9.8 "$tmp")"
  [[ "$said" == *marketplace.json* && "$said" == *plugin.json* ]] || { echo "at another release: $said"; rm -rf "$tmp" "$tmp.before"; return 1; }
  rm -rf "$tmp" "$tmp.before"
}

# std: yoke-ai-skill:the-packages.03
check_the_trees_packages_are_what_its_skills_make() {
  local version
  version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["plugins"][0]["version"])' "$pk_root/.claude-plugin/marketplace.json" 2>/dev/null)" \
    || { echo "the marketplace names no release"; return 1; }
  python3 "$pk_root/ci/package.py" --check --version "$version" "$pk_root"
}

# std: yoke-ai-skill:the-packages.04
check_every_link_answers_and_one_that_does_not_is_named() {
  local tmp said status; tmp="$(mktemp -d)"
  mkdir -p "$tmp/site/guide/here"
  printf '<article><h2 id="there">There</h2></article>\n' > "$tmp/site/guide/here/index.html"
  cat > "$tmp/SKILL.md" <<'MD'
https://docs.yoke-project.dev/9.9.9/guide/here/ and https://docs.yoke-project.dev/9.9.9/guide/here/#there,
https://docs.yoke-project.dev/9.9.9/guide/here/#nowhere and https://docs.yoke-project.dev/9.9.9/guide/gone/.
curl -fsSL "https://github.com/yoke-project/yoke/releases/download/v$version/x.tar.gz"
MD
  said="$(python3 "$pk_root/ci/links.py" --site "$tmp/site" "$tmp/SKILL.md")"; status=$?
  rm -rf "$tmp"
  [[ $status == 1 && "$said" == *"#nowhere has no element"* && "$said" == *"guide/gone/ not in the build"* ]] \
    || { echo "exited $status saying: $said"; return 1; }
  [[ "$(grep -c '^links: ' <<<"$said")" == 2 ]] || { echo "it named more than the two: $said"; return 1; }
}

# std: yoke-ai-skill:the-packages.05
check_every_command_a_skill_cites_exists_in_the_release() {
  local tmp said status; tmp="$(mktemp -d)"
  mkdir -p "$tmp/programs"
  printf '#!/bin/sh\necho "usage: yoke <subject> <operation>"\necho\necho "  yoke shell [--instance <name>]"\necho "  yoke app run <id> | --from <dir>"\necho "  yoke unit ask <unit> <type>"\n' > "$tmp/programs/yoke"
  printf '#!/bin/sh\necho "usage: yoke-compose <verb> [options]" >&2\necho >&2\necho "  check [--dir D]      run the gate" >&2\necho "  add unit <name> --kind K" >&2\necho "    a continuation line" >&2\n' > "$tmp/programs/yoke-compose"
  chmod +x "$tmp/programs/yoke" "$tmp/programs/yoke-compose"
  cat > "$tmp/SKILL.md" <<'MD'
Run `yoke app run --from hello`, the namespace `yoke app`, and `yoke shell`; the form is `yoke <subject> <operation>`.

```
echo -n x | yoke unit ask a b
yoke-compose add unit g --kind plugin
yoke-compose check --dir hello
yoke unit command a b
```

Then `yoke-compose add channel c`.
MD
  said="$(python3 "$pk_root/ci/commands.py" --programs "$tmp/programs" "$tmp/SKILL.md")"; status=$?
  rm -rf "$tmp"
  [[ $status == 1 && "$said" == *"yoke unit command"* && "$said" == *"yoke-compose add channel"* ]] \
    || { echo "exited $status saying: $said"; return 1; }
  [[ "$(grep -c '^commands: ' <<<"$said")" == 2 ]] || { echo "it named more than the two: $said"; return 1; }
}
