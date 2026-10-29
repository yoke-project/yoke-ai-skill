# The two packages

| | |
| --- | --- |
| **Feature** | the Claude Code plugin with its marketplace and Antigravity's skill folders are generated from the one source of the skills, each skill byte for byte, at the release's version; a check names every file that differs; every link a skill holds answers, and every command it cites exists in the release's programs |
| **Planning item** | yoke-project/yoke-ai-skill#2 |

## yoke-ai-skill:the-packages.01 — both packages carry every skill as the source has it, at the release, and nothing else

| Field | Value |
| --- | --- |
| **Cites** | prj_structure/97 §The documentation, and the site · prj_structure/80 §The layout |
| **Level** | L1 |
| **Method** | check |
| **Not applicable in** | — |
| **Label** | blocking |
| **Precondition** | a tree of two skills, and a file under `antigravity/` no skill accounts for |
| **Action** | generate the packages at a release |
| **Expected** | the marketplace lists one plugin at that release, its source the plugin's directory; the plugin's manifest names the release and the licence; each skill is under the plugin's `skills/` and under `antigravity/`, byte for byte the source's; the stray file is gone |

## yoke-ai-skill:the-packages.02 — a check names every file that differs, and writes nothing

| Field | Value |
| --- | --- |
| **Cites** | prj_structure/97 §The documentation, and the site |
| **Level** | L1 |
| **Method** | check |
| **Not applicable in** | — |
| **Label** | blocking |
| **Precondition** | packages generated at a release, then one skill's copy edited, a file added beside them, and the source of another skill changed |
| **Action** | check them at that release, then at another |
| **Expected** | it exits 1 naming the edited copy, the added file and both copies of the changed skill, and nothing changes; at another release it names both manifests too |

## yoke-ai-skill:the-packages.03 — the tree's packages are what its skills make, at the release its marketplace names

| Field | Value |
| --- | --- |
| **Cites** | prj_structure/97 §The documentation, and the site |
| **Level** | L1 |
| **Method** | check |
| **Not applicable in** | — |
| **Label** | blocking |
| **Precondition** | this repository's tree |
| **Action** | read the release the marketplace names, and check the packages at it |
| **Expected** | the marketplace names a release, and nothing differs |

## yoke-ai-skill:the-packages.04 — every link answers, its anchor included, and a link that does not is named

| Field | Value |
| --- | --- |
| **Cites** | prj_structure/97 §The documentation, and the site |
| **Level** | L1 |
| **Method** | check |
| **Not applicable in** | — |
| **Label** | blocking |
| **Precondition** | a build of a set holding one page with a section; a skill linking that page, its section, a section it does not have, a page the set does not have, and a command's URL holding a shell variable |
| **Action** | check the skill's links against the build |
| **Expected** | it exits 1 naming the missing section and the missing page, and neither the page, nor its section, nor the command's URL |

## yoke-ai-skill:the-packages.05 — every command a skill cites exists in the release's programs

| Field | Value |
| --- | --- |
| **Cites** | prj_structure/97 §The documentation, and the site |
| **Level** | L1 |
| **Method** | check |
| **Not applicable in** | — |
| **Label** | blocking |
| **Precondition** | programs listing `yoke app run`, `yoke unit ask` and `yoke shell`, and `yoke-compose` listing `check` and `add unit`; a skill citing in blocks of code and in spans `yoke app run --from hello`, `echo -n x \| yoke unit ask a b`, `yoke app`, `yoke shell`, `yoke <subject> <operation>`, `yoke-compose add unit g`, `yoke-compose check`, then `yoke unit command a b` and `yoke-compose add channel c` |
| **Action** | check the skill's commands against the programs |
| **Expected** | it exits 1 naming `yoke unit command` and `yoke-compose add channel`, and none of the others |
