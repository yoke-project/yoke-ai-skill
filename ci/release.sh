#!/usr/bin/env bash
# The release verb. At a commit a release tag `vX.Y.Z` names, it waits for that release's documentation
# and programs to be published, checks the skills against them — the essentials against the pages, the
# packages against the skills, every link, every command — and emits one manifest line naming the tree at
# the tag. What is published is that tree: the plugin and the folders an agent installs. Everything but
# the line goes to the error stream.
#
# RELEASE_DOCS is the documentation's root (https://docs.yoke-project.dev/ unless set), RELEASE_SITE a
# build of the set to read in its place, RELEASE_PROGRAMS a directory already holding the release's `yoke`
# and `yoke-compose`; RELEASE_POLL and RELEASE_TRIES pace the wait.
# Usage: release.sh
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
say() { echo "release: $*" >&2; }
docs="${RELEASE_DOCS:-https://docs.yoke-project.dev/}"
poll="${RELEASE_POLL:-30}"
tries="${RELEASE_TRIES:-120}"

tag="$(git tag --points-at HEAD | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)"
if [[ -z "$tag" ]]; then
  say "nothing is published from this commit — no release tag names it"
  exit 0
fi
version="${tag#v}"

# waited <what> <command...>: runs the command until it succeeds, or says what never arrived.
waited() {
  local what="$1" try; shift
  for (( try = 0; try < tries; try++ )); do
    "$@" > /dev/null 2>&1 && return 0
    sleep "$poll"
  done
  say "$what is not published; the release of the skills waits for it"
  return 1
}

held="$(mktemp -d)"
trap 'rm -rf "$held"' EXIT
if [[ -n "${RELEASE_SITE:-}" ]]; then
  export SKILLS_SITE="$RELEASE_SITE"
else
  waited "the documentation of $version" curl -fsS "${docs%/}/$version/llms.txt" || exit 1
fi
programs="${RELEASE_PROGRAMS:-}"
if [[ -z "$programs" ]]; then
  programs="$held/programs"
  mkdir -p "$programs"
  base="https://github.com/yoke-project/yoke/releases/download/v$version"
  waited "the programs of $version" curl -fsSLo "$held/yoke.tar.gz" "$base/yoke-$version-linux-amd64.tar.gz" || exit 1
  waited "the composer of $version" curl -fsSLo "$held/conformance.tar.gz" "$base/yoke-conformance-$version-linux-amd64.tar.gz" || exit 1
  tar -xzf "$held/yoke.tar.gz" -C "$programs" yoke && tar -xzf "$held/conformance.tar.gz" -C "$programs" yoke-compose \
    || { say "the programs of $version could not be unpacked"; exit 1; }
fi
ci/published.sh "$version" "$programs" >&2 || { say "the skills at $tag do not hold against release $version"; exit 1; }
say "the skills at $tag hold against release $version"

commit="$(git rev-parse HEAD)"
digest="sha256:$(git archive --format=tar "$tag" | sha256sum | cut -d' ' -f1)"
python3 - "$version" "$commit" "$digest" <<'PY'
import datetime, json, sys
version, commit, digest = sys.argv[1:]
print(json.dumps({"line": "publication", "published": "yoke-ai-skill", "version": "v" + version, "commit": commit,
    "digests": [digest], "where": f"https://github.com/yoke-project/yoke-ai-skill/tree/v{version}",
    "authenticated": "https://github.com", "licence": "CC-BY-4.0", "notices": [],
    "day": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")}, separators=(",", ":")))
PY
