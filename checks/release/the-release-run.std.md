# The release run

| | |
| --- | --- |
| **Feature** | at a release tag the release verb checks the skills against that release — the essentials against its pages, the packages against the skills, every link, every command against its programs — and emits one manifest line naming the tree at the tag; at a commit no release tag names it publishes nothing; a release tag runs the verb and keeps its line |
| **Planning item** | yoke-project/yoke-ai-skill#5 |

## yoke-ai-skill:the-release-run.01 — at a commit no release tag names, the verb publishes nothing and says so

| Field | Value |
| --- | --- |
| **Cites** | prj_structure/85 §The acts · prj_structure/95 §The verbs |
| **Level** | L1 |
| **Method** | check |
| **Not applicable in** | — |
| **Label** | blocking |
| **Precondition** | a copy of this repository at a commit no tag names |
| **Action** | run the release verb |
| **Expected** | it exits 0, its output holds no line, and it says that no release tag names the commit |

## yoke-ai-skill:the-release-run.02 — at a release tag the skills are checked against the release, and one line names the tree

| Field | Value |
| --- | --- |
| **Cites** | prj_structure/85 §The acts · prj_structure/97 §The documentation, and the site |
| **Level** | L1 |
| **Method** | check |
| **Not applicable in** | — |
| **Label** | blocking |
| **Precondition** | a copy of this repository whose one skill was regenerated and packaged at a release from a build of its documentation, tagged with that release; the build and programs that list every command the skill cites given in place of the published ones |
| **Action** | run the release verb |
| **Expected** | it exits 0 and its output is one manifest line: `publication`, `yoke-ai-skill`, the release's tag as its version, the tagged commit, the digest of the tree at the tag, the tree at the tag as where it is, CC BY 4.0 |

## yoke-ai-skill:the-release-run.03 — at a release tag the skills do not hold against, nothing is published

| Field | Value |
| --- | --- |
| **Cites** | prj_structure/85 §The acts |
| **Level** | L1 |
| **Method** | check |
| **Not applicable in** | — |
| **Label** | blocking |
| **Precondition** | the copy of .02, its skill's region edited by hand before the commit is tagged |
| **Action** | run the release verb |
| **Expected** | it exits 1 naming the skill that differs and saying the skills do not hold against the release, and its output holds no line |

## yoke-ai-skill:the-release-run.04 — a release tag runs the verb, and the run keeps its line

| Field | Value |
| --- | --- |
| **Cites** | prj_structure/85 §The acts · prj_structure/95 §The release command |
| **Level** | L1 |
| **Method** | check |
| **Not applicable in** | — |
| **Label** | blocking |
| **Precondition** | this repository's release workflow |
| **Action** | read it |
| **Expected** | it runs on a pushed tag `v*`, checks the commit out with its tags, runs `just release` into `manifest-lines.jsonl` and keeps that file as the artifact `manifest-lines`, with no write permission |
