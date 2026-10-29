# The essentials

| | |
| --- | --- |
| **Feature** | a skill's essentials — the parts restating the documentation — are regenerated from the published pages of one release, each between two markers naming the page, the section and the kind; every link to the documentation names that release; a check says which skill differs, and writes nothing |
| **Planning item** | yoke-project/yoke-ai-skill#1 |

## yoke-ai-skill:essentials.01 — a marked region is filled from the section and the kind it names, and nothing else

| Field | Value |
| --- | --- |
| **Cites** | prj_structure/97 §The documentation, and the site · prj_structure/80 §The layout |
| **Level** | L1 |
| **Method** | check |
| **Not applicable in** | — |
| **Label** | blocking |
| **Precondition** | a build of a set holding one page whose article has a table before its first section, then a section with a block of text, a block of Go and a table with code, emphasis, a relative link and a bar in a cell, then a later section with its own table; a skill marking the page's first table, the section's table, its first code and its Go |
| **Action** | regenerate the skill at a release |
| **Expected** | each region holds what its marker names, as Markdown: the first table before any section, the section's table and never the later one, the text block, the Go block fenced as `go`; the bar is escaped, the relative link made absolute against the release's pages; the text outside the markers is unchanged |

## yoke-ai-skill:essentials.02 — every link to the documentation names the release

| Field | Value |
| --- | --- |
| **Cites** | prj_structure/97 §The documentation, and the site |
| **Level** | L1 |
| **Method** | check |
| **Not applicable in** | — |
| **Label** | blocking |
| **Precondition** | a skill written by hand linking a page of the documentation at an older release, and the documentation's root without a release |
| **Action** | regenerate it at a release |
| **Expected** | the link at the older release names the release regenerated at; the root without a release is left as it is |

## yoke-ai-skill:essentials.03 — a check names the skill that differs, and writes nothing

| Field | Value |
| --- | --- |
| **Cites** | prj_structure/97 §The documentation, and the site |
| **Level** | L1 |
| **Method** | check |
| **Not applicable in** | — |
| **Label** | blocking |
| **Precondition** | two skills, one regenerated at the release and one whose region was edited by hand |
| **Action** | check both at the release |
| **Expected** | it exits 1 naming the edited skill and not the other, and neither file changes; with both regenerated it exits 0 |

## yoke-ai-skill:essentials.04 — a section the page does not have is a fault naming it

| Field | Value |
| --- | --- |
| **Cites** | prj_structure/97 §The documentation, and the site |
| **Level** | L1 |
| **Method** | check |
| **Not applicable in** | — |
| **Label** | blocking |
| **Precondition** | a skill marking a section the page has no element of that kind in, then a section the page does not have |
| **Action** | regenerate it |
| **Expected** | it exits 2 naming the marker each time, and the skill is left as it was |

## yoke-ai-skill:essentials.05 — the three skills are written once, by role, in the open form

| Field | Value |
| --- | --- |
| **Cites** | prj_structure/80 §The layout |
| **Level** | L1 |
| **Method** | check |
| **Not applicable in** | — |
| **Label** | blocking |
| **Precondition** | the repository's `skills/` |
| **Action** | read each skill's head |
| **Expected** | there are exactly `yoke`, `yoke-plugin` and `yoke-ui`, each a `SKILL.md` opening with a head whose `name` is its directory's and whose `description` is not empty; every essentials marker is closed |
