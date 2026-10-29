# yoke-ai-skill

## What it is

The skills an AI agent reads to build an application with Yoke, written once by role in the open
`SKILL.md` form: `yoke` for the concepts, a local Core, the command line and the project; `yoke-plugin`
for writing a Plugin in any of the five languages; `yoke-ui` for an interface client. Their essentials —
the commands, the Manifest's form, the families' table — are regenerated from the documentation of the
release they describe, and everything else links to it.

The repository is tagged with every release of Yoke, at Yoke's own number: the skills at a tag describe
that release and link to its pages.

**In Claude Code**, add the marketplace this repository is and install the plugin from it:

```
/plugin install yoke --marketplace yoke-project/yoke-ai-skill
```

**In Antigravity**, copy the folders under `antigravity/` into the workspace's `.agents/skills/`, or into
`~/.gemini/config/skills/` for every workspace.

Both carry the same three skills, generated from one source; take the tag of the release you run.

## What is where

| Path | What it holds |
| --- | --- |
| `skills/yoke/`, `skills/yoke-plugin/`, `skills/yoke-ui/` | The one source of each skill, a `SKILL.md` whose marked regions are generated and whose rest is written by hand |
| `ci/essentials.py` | Regenerates the marked regions from the documentation of one release, published or built, and with `--check` says which skill differs |
| `.claude-plugin/`, `claude/yoke/` | The Claude Code marketplace, and the one plugin it lists — generated |
| `antigravity/` | The skills as Antigravity's folders — generated |
| `ci/package.py` | Generates both packages from `skills/`, and with `--check` names every file that differs |
| `ci/links.py`, `ci/commands.py`, `ci/published.sh` | Check every link a skill holds answers, and every command it cites exists in the release's programs; `ci/published.sh` runs every check against a published release |
| `checks/`, `ci/` | This repository's own checks, and the scripts continuous integration runs |

## Working on it

[`just`](https://just.systems) 1.58.0 or newer, and Python 3. `just develop` also puts the published
verification tool, `yoke-verify`, on the `PATH`, which `just test` needs. The `Containerfile` builds a
container with the runner.

| Command | What it does |
| --- | --- |
| `just build` | Says there is nothing to build: a skill is read as it is written |
| `just test` | Runs the checks, and checks each description against its tests |
| `just lint` | Parses every shell script and every Python script |
| `just fmt` | Says there is nothing to format yet |
| `just develop` | Verifies the installed `just` against a floor, given as `just develop 1.58.0`, and installs `yoke-verify` |
| `just release` | Says there is nothing to publish yet |

The essentials are regenerated with `python3 ci/essentials.py --version <version> skills/*/SKILL.md`,
which reads `https://docs.yoke-project.dev/<version>/`, or `--site <directory>` for a build of the set.

## Where the depth is

The documentation at [docs.yoke-project.dev](https://docs.yoke-project.dev/): the guide to
[building an application](https://docs.yoke-project.dev/building/), the
[reference](https://docs.yoke-project.dev/reference/), and the
[contributors' section](https://docs.yoke-project.dev/contributing/) for how the work is done.

## Licence

CC BY 4.0, in [`LICENSE`](LICENSE), as the documentation it restates carries.
