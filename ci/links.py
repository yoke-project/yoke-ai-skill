#!/usr/bin/env python3
"""Checks that every link a skill holds answers, its anchor included.

Every `http` or `https` link in the files given is asked for, and one that does not answer — or answers
without the element its `#anchor` names — is named. A link holding a shell variable is a command's, not a
link, and is left alone.

With --site, a link into the documentation, https://docs.yoke-project.dev/<version>/..., is read from a
build of the set instead: the page's `index.html` under the directory given, or the file a link with an
extension names. Every other link is still
asked for over the network.

Usage: links.py [--site <directory>] <file>...
"""
import argparse
import pathlib
import re
import sys
import urllib.error
import urllib.request

LINK = re.compile(r"https?://[^\s)<>`\"'|]+")
DOCS = re.compile(r"^https://docs\.yoke-project\.dev/(?:\d+\.\d+\.\d+/)?(.*)$")


def page(url: str, site: str):
    """The text the link answers with, or why it does not answer."""
    found = DOCS.match(url)
    if site and found:
        path = pathlib.Path(site) / found.group(1).split("#")[0]
        if not path.suffix:
            path = path / "index.html"
        return (path.read_text(), "") if path.is_file() else ("", "not in the build")
    request = urllib.request.Request(url.split("#")[0], headers={"User-Agent": "yoke-ai-skill links"})
    try:
        with urllib.request.urlopen(request, timeout=30) as answer:
            return answer.read().decode(errors="replace"), ""
    except urllib.error.HTTPError as failed:
        return "", f"answers {failed.code}"
    except (urllib.error.URLError, TimeoutError) as failed:
        return "", f"does not answer: {failed}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--site")
    parser.add_argument("files", nargs="+")
    o = parser.parse_args()
    links = sorted({link.rstrip(".,;:") for f in o.files for link in LINK.findall(pathlib.Path(f).read_text())
                    if "$" not in link})
    failed = []
    for link in links:
        text, why = page(link, o.site)
        if not why and "#" in link:
            anchor = link.split("#", 1)[1]
            if f'id="{anchor}"' not in text:
                why = f"has no element #{anchor}"
        if why:
            failed.append(f"{link} {why}")
    for line in failed:
        print(f"links: {line}")
    if failed:
        return 1
    print(f"links: every one of {len(links)} links answers")
    return 0


if __name__ == "__main__":
    sys.exit(main())
