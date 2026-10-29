#!/usr/bin/env python3
"""Fills the essentials of each skill from the documentation of one release.

A skill is written once, by hand, and the parts of it that restate the documentation — the commands, the
Manifest's form, the families' table — are not: each sits between two markers naming the page and the
section it comes from, and this regenerates it from that page of the release.

    <!-- essentials: reference/the-manager/the-command-line#yoke-app table -->
    ...generated...
    <!-- essentials end -->

The kind is `table` (the first table of the section), `code` (its first block of code) or `code:<language>`
(its first block in that language). A page with no
`#section` gives the first of the page. Every link to the documentation, in what is generated and in what
is written by hand, is made to name the release, so a skill read beside a release reads that release.

The documentation is read where it is published, https://docs.yoke-project.dev/<version>/, or from a
directory holding a build of the set, given as --site.

Usage: essentials.py --version <version> [--site <url or directory>] [--check] <SKILL.md>...
With --check nothing is written, and a skill whose essentials differ from the documentation is named.
"""
import argparse
import html
import html.parser
import pathlib
import re
import sys
import urllib.parse
import urllib.request

PUBLISHED = "https://docs.yoke-project.dev/"
BLOCK = re.compile(r"(<!-- essentials: (\S+) (table|code(?::\w+)?) -->\n)(.*?)(<!-- essentials end -->)", re.S)
VERSIONED = re.compile(re.escape(PUBLISHED) + r"\d+\.\d+\.\d+/")


class Article(html.parser.HTMLParser):
    """The elements of a page's article this reads: headings with their identifiers, tables and code."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.inside = 0
        self.elements = []  # ("heading", id) | ("table", rows) | ("code", language, text)
        self.table = None
        self.row = None
        self.cell = None
        self.code = None
        self.language = ""
        self.link = None

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "article":
            self.inside += 1
        if not self.inside:
            return
        if tag in ("h2", "h3") and a.get("id"):
            self.elements.append(("heading", a["id"]))
        elif tag == "div" and self.code is None:
            found = re.search(r"\blanguage-(\w+)", a.get("class", ""))
            if found:
                self.language = found.group(1)
        elif tag == "pre":
            self.code = []
        elif tag == "br" and self.code is not None:
            self.code.append("\n")
        elif tag == "table":
            self.table = []
        elif tag == "tr" and self.table is not None:
            self.row = []
        elif tag in ("td", "th") and self.row is not None:
            self.cell = []
        elif self.cell is not None:
            if tag == "code":
                self.cell.append("`")
            elif tag == "strong":
                self.cell.append("**")
            elif tag == "em":
                self.cell.append("*")
            elif tag == "a":
                self.link = a.get("href", "")
                self.cell.append("[")

    def handle_endtag(self, tag):
        if not self.inside:
            return
        if tag == "article":
            self.inside -= 1
        elif tag == "pre" and self.code is not None:
            self.elements.append(("code", self.language, "".join(self.code).rstrip("\n")))
            self.code, self.language = None, ""
        elif tag == "table" and self.table is not None:
            self.elements.append(("table", self.table))
            self.table = None
        elif tag == "tr" and self.row is not None:
            self.table.append(self.row)
            self.row = None
        elif tag in ("td", "th") and self.cell is not None:
            self.row.append("".join(self.cell).strip())
            self.cell = None
        elif self.cell is not None:
            if tag == "code":
                self.cell.append("`")
            elif tag == "strong":
                self.cell.append("**")
            elif tag == "em":
                self.cell.append("*")
            elif tag == "a":
                self.cell.append(f"]({self.link})")
                self.link = None

    def handle_data(self, data):
        if self.code is not None:
            self.code.append(data)
        elif self.cell is not None:
            self.cell.append(" ".join(data.split("\n")))


def read(site: str, page: str) -> str:
    """The HTML of a page of the set, from the published site or from a build of it."""
    if re.match(r"^https?://", site):
        with urllib.request.urlopen(site.rstrip("/") + "/" + page + "/") as answer:
            return answer.read().decode()
    return (pathlib.Path(site) / page / "index.html").read_text()


def absolute(link: str, page: str, version: str) -> str:
    """A link of the page made absolute against the release's pages; an anchor or another site is kept."""
    if not link or link.startswith("#") or re.match(r"^[a-z]+:", link):
        return link
    base = PUBLISHED + version + "/" + page + "/"
    if link.startswith("/"):
        return urllib.parse.urljoin(PUBLISHED + version + "/", link.lstrip("/"))
    return urllib.parse.urljoin(base, link)


def markdown(element, page: str, version: str) -> str:
    if element[0] == "code":
        return f"```{element[1]}\n{element[2]}\n```\n"
    rows = element[1]
    fix = lambda cell: re.sub(r"\]\(([^)]*)\)", lambda m: "](" + absolute(m.group(1), page, version) + ")",
                              cell.replace("|", "\\|"))
    lines = ["| " + " | ".join(fix(c) for c in rows[0]) + " |", "| " + " | ".join("---" for _ in rows[0]) + " |"]
    lines += ["| " + " | ".join(fix(c) for c in row) + " |" for row in rows[1:]]
    return "\n".join(lines) + "\n"


def essential(site: str, version: str, where: str, kind: str) -> str:
    page, _, section = where.partition("#")
    kind, _, language = kind.partition(":")
    parsed = Article()
    parsed.feed(read(site, page))
    inside = not section
    for element in parsed.elements:
        if element[0] == "heading":
            if inside and section:
                break
            inside = inside or element[1] == section
            continue
        if inside and element[0] == kind and (not language or element[1] == language):
            return markdown(element, page, version)
    raise LookupError(f"{where} has no {kind}" + ("" if inside or not section else f": no section {section}"))


def regenerate(text: str, site: str, version: str) -> str:
    text = VERSIONED.sub(PUBLISHED + version + "/", text)
    return BLOCK.sub(lambda m: m.group(1) + essential(site, version, m.group(2), m.group(3)) + m.group(5), text)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--version", required=True)
    parser.add_argument("--site", help="the set's pages for that release: a URL, or a directory holding a build")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("skills", nargs="+")
    o = parser.parse_args()
    if not re.fullmatch(r"\d+\.\d+\.\d+", o.version):
        print(f"essentials: {o.version!r} is not a release's version", file=sys.stderr)
        return 1
    site = o.site or PUBLISHED + o.version + "/"
    differ = []
    for path in map(pathlib.Path, o.skills):
        before = path.read_text()
        try:
            after = regenerate(before, site, o.version)
        except (OSError, LookupError) as failed:
            print(f"essentials: {path}: {failed}", file=sys.stderr)
            return 2
        if o.check:
            if after != before:
                differ.append(str(path))
        elif after != before:
            path.write_text(after)
            print(f"essentials: {path} regenerated from {o.version}")
    if differ:
        print("essentials: these differ from the documentation of " + o.version + ": " + ", ".join(differ))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
