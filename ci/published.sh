#!/usr/bin/env bash
# Runs every check of the skills against a published release: the essentials against its pages, the
# packages against the skills, every link over the network, and every command against its programs.
# It runs every check whatever the one before found, and fails if any did.
# SKILLS_SITE, where set, is a build of the set read in place of the published pages.
# Usage: published.sh <version> <directory holding that release's yoke and yoke-compose>
set -uo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${1:?usage: published.sh <version> <programs>}"
programs="${2:?usage: published.sh <version> <programs>}"
cd "$root"
site=()
[[ -n "${SKILLS_SITE:-}" ]] && site=(--site "$SKILLS_SITE")
status=0
python3 ci/essentials.py --check --version "$version" "${site[@]}" skills/*/SKILL.md || status=1
python3 ci/package.py --check --version "$version" || status=1
python3 ci/links.py "${site[@]}" skills/*/SKILL.md || status=1
python3 ci/commands.py --programs "$programs" skills/*/SKILL.md || status=1
exit "$status"
