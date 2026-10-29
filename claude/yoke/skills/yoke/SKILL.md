---
name: yoke
description: Use when building, composing, running or diagnosing a Yoke application — the concepts (the Core, units, Plugins, channels, the two deployment forms), the `yoke` and `yoke-compose` command lines, a project and its descriptor `yoke.yaml`, running it on a local Core, and reading what went wrong. For writing a Plugin use the yoke-plugin skill; for a panel, a browser back end or a tool that attaches to a channel, the yoke-ui skill.
---

# Yoke

Yoke runs an application made of separate processes — its **units** — under one supervisor, the **Core**,
and lets panels, browsers and tools reach it through declared **channels**. This skill is written for
Yoke 0.12.0; its pages are at https://docs.yoke-project.dev/0.12.0/, and an index a program can read is
https://docs.yoke-project.dev/0.12.0/llms.txt. Read a page there before relying on anything this skill
summarises.

## The model, in five sentences

- A **Plugin** is a program the Core launches, admits and holds a Session with; it declares what it does
  in its **Manifest** and does nothing it has not declared.
- **A declaration grants nothing.** What a unit may do is what it declared *and* what an operator granted,
  computed once, when it is admitted: a grant made while it runs reaches it at its next admission, so the
  unit is restarted.
- **The Core never reads a payload.** Questions, answers, commands and stream data are bytes to it; their
  meaning lives in the Plugin and its clients.
- An **interface client** reaches the application through a channel and speaks the interface contract; a
  tool that administers an instance speaks the administrative contract, which is what `yoke` does.
- An application ships in one of **two forms**: the **application form**, a package an account installs
  and its guardian runs, and the **service form**, a composition the init system starts on a device.

## The programs

A Linux host on `amd64` or `arm64`; nothing needs root. Two assets of the release:

```
version=0.12.0 arch=amd64
base=https://github.com/yoke-project/yoke/releases/download/v$version
mkdir -p ~/yoke/bin && cd ~/yoke/bin
curl -fsSL "$base/yoke-$version-linux-$arch.tar.gz" | tar -xz yoke yoke-core yoke-guardian yoke-auth
curl -fsSL "$base/yoke-conformance-$version-linux-$arch.tar.gz" | tar -xz yoke-compose
export PATH="$HOME/yoke/bin:$PATH"
```

`yoke-compose` is for the workstation and never goes on a device.

## A project

An application is written as a project: `yoke.yaml` (the descriptor, the only source of truth),
`manifests/` (one Manifest per Plugin) and `components/` (the executables). **Nothing in the descriptor is
typed by hand** — every field has an authoring verb, and a refusal names the field by the path `set` takes.

<!-- essentials: reference/the-composer/writing-a-description table -->
| Verb | Writes |
| --- | --- |
| `add unit` | a unit: its kind, its program, image or Plugin, its arguments in order, its dependencies, the binding each of its needs takes; for a program under `components/`, its digest beside it |
| `add channel` | a channel: its transport, its cardinality, the unit serving it, its address |
| `add parameter` | a parameter in a group: its type, its domain, whether it is required, its default, its label |
| `set` | any other field, of either document |
| `remove` | takes a unit, a channel, a parameter or any field away, addressed by the same path |
| `arbitrate` | one precedence relation: the first channel prevails over the others |
<!-- essentials end -->

```
yoke-compose init com.example.hello --dir hello --version 0.1.0 --arch x86_64 --core ">=0.12.0"
yoke-compose add unit greeter --dir hello --kind plugin --plugin com.example.greeter \
  --exec components/plugins/greeter
yoke-compose add channel cli --dir hello --transport local --clients multiple
yoke-compose check --dir hello
mkdir -p out && yoke-compose build --dir hello --out out
```

- **An executable is pinned by its digest.** After every rebuild of one, write the digest again with
  `yoke-compose set units.<unit>.digest "sha256:…"`; `check` and `build` refuse a component whose digest
  no longer matches, and so does the host.
- `check` runs the same gate a host runs; on a workstation it says `not run: host facts`, which is not a
  pass of those facts. Advice never stops anything; a refusal does.
- `build` refuses an output directory that does not exist.

## Running it on a local Core

The manager needs an install root it may write into, group-owned and set-group-id:

```
mkdir -p ~/yoke/apps && chmod 2775 ~/yoke/apps
mkdir -p ~/.config/yoke
echo "install_root: $HOME/yoke/apps" > ~/.config/yoke/manager.conf
```

Sockets go under `XDG_RUNTIME_DIR`; a socket path may not exceed 107 characters, so a runtime directory
set by hand has to be short.

```
yoke app run --from hello                         # run the working directory, until interrupted
yoke plugin grant com.example.greeter query.hello.answer
yoke unit restart greeter                         # the grant reaches the unit at its next admission
echo -n world | yoke unit ask greeter greeter.hello --input -
```

A run's grants last as long as the run. An instance that lasts:

```
yoke app install out/com.example.hello-0.1.0.yoke
yoke instance create com.example.hello --name dev
yoke instance start dev
yoke plugin grant com.example.greeter query.hello.answer --instance dev
yoke unit restart greeter --instance dev
```

A new version is a new package: install it, then `yoke instance set-version dev <version>`.

## The command line

`yoke` has lifecycle verbs, which act on declarations, and client verbs, which act on a running instance —
one per operation of the administrative contract: `yoke <subject> <operation> [--instance <name>]`.

<!-- essentials: reference/the-manager/the-command-line#the-namespaces table -->
| Namespace | Regime | Acts on |
| --- | --- | --- |
| `yoke app` | user | packages, bundles, the install root |
| `yoke instance` | user | instance records and the state beside them |
| `yoke service` | system | the one deployment the init system activates |
| `yoke log`, `plugin`, `unit`, `core`, `stream`, `shell` | either | what is inside a running instance |
<!-- essentials end -->

<!-- essentials: reference/the-manager/the-command-line#yoke-app table -->
| Verb | Does | Goes to |
| --- | --- | --- |
| `install <package>` | expands a package into a bundle and resolves what it references — [Installing](https://docs.yoke-project.dev/0.12.0/reference/the-package/installing/) | filesystem, engine |
| `list` | the applications and versions installed, each with its install state | filesystem |
| `show <id>` | one application: its versions, what each records, which any instance points at | filesystem |
| `remove <id> [--version <v>]` | removes bundles; refused while any instance points at a version being removed | filesystem |
| `prune [<id>]` | the one reclaiming verb — [Updating and removal](https://docs.yoke-project.dev/0.12.0/reference/the-manager/updating-and-removal/) | filesystem, engine |
| `run <id> [--version <v>]`, `run --from <dir>` | creates an ephemeral record and follows the run — [Instances](https://docs.yoke-project.dev/0.12.0/reference/the-manager/instances/#running-an-application-that-was-never-declared) | filesystem, guardian |
<!-- essentials end -->

<!-- essentials: reference/the-manager/the-command-line#yoke-instance table -->
| Verb | Does | Goes to |
| --- | --- | --- |
| `create <id> [--name <n>] [--version <v>] [--params <file>]` | writes a record, its values checked against the declarations | filesystem |
| `list` | this account's instances, each with the state derived for it | filesystem, guardian |
| `show <n>` | the record, and what the state occupies | filesystem |
| `start <n>`, `stop <n>`, `restart <n>` | writes the desired state, then asks for the record to be reconciled | filesystem, guardian |
| `enable <n>`, `disable <n>` | writes autostart — a second field, not the desired state | filesystem |
| `set-version <n> <v>` | re-points the record at an installed version | filesystem |
| `set-param <n> <group>.<key> <value>` | replaces one recorded value, checked as at creation | filesystem |
| `set-secret <n> <secret>` | reads a value without echoing it into the instance's state — [Secrets](https://docs.yoke-project.dev/0.12.0/reference/secrets/how-a-unit-gets-one/) | filesystem, operator projection |
| `copy <n> <path>`, `restore <path> <n>` | copies a stopped instance's state out, or back in | filesystem |
| `clear <n>` | removes the state; the instance stays declared | filesystem |
| `remove <n>` | removes the record and the state together | filesystem |
<!-- essentials end -->

<!-- essentials: reference/the-manager/the-command-line#yoke-service table -->
| Verb | Does | Goes to |
| --- | --- | --- |
| `start`, `restart` | runs the gate over the composition in force; a refusal is said, exits 1, and the init system is not asked — otherwise asks the init system, and starts nothing itself | filesystem, init system |
| `stop` | asks the init system | init system |
| `status` | what the init system reports, beside what the instance answers | init system, operator projection |
| `check` | runs the gate over the composition in force | filesystem |
| `set-secret <name>` | writes a secret into the deployment's own area | filesystem |
| `exec` | gates and then executes the Core, in one process | filesystem |
<!-- essentials end -->

<!-- essentials: reference/the-manager/the-command-line#what-it-reports table -->
| Exit status | Means |
| --- | --- |
| `0` | the verb did what it says |
| `1` | a refusal: the answer will not change until something is changed |
| `2` | a fault: the attempt failed, and the same attempt may succeed |
<!-- essentials end -->

## When something is wrong

<!-- essentials: building/running-it#when-something-is-wrong table -->
| Look at | With | It says |
| --- | --- | --- |
| the instances | `yoke instance list` | each with its state — `observable`, `stopped`, `refused`, `failed` |
| the units | `yoke unit list`, `yoke unit show greeter` | each unit's state, its condition, and what its plugin declared and was authorised |
| the log | `yoke log query --unit greeter`, `yoke log follow` | every event of the instance: states, admissions, grants, a unit's health and occurrences |
| what the Core publishes | `yoke core subscribe` | a snapshot of the records, then each change as it happens |
| the guardian | `$XDG_STATE_HOME/yoke/guardian.log` — `~/.local/state/yoke/guardian.log` by default | the gate's findings at a start, and every Core it ran |
| an interactive session | `yoke shell` | the same operations, typed one after another |
<!-- essentials end -->

- **A refusal is the model working, not a bug to route around.** `scope.withheld` means a capability was
  declared and not granted: grant it and restart the unit. Never widen a grant or disable a check to make
  a refusal go away without saying so.
- A line such as `confinement.no_cgroup_delegation` is the host saying what it could not do, not a refusal.
- A unit started by hand, under a debugger, is admitted only by `yoke app run --from <dir>
  --admit-unlaunched`.

## The two forms

<!-- essentials: building/shipping-it table -->
|  | The application form | The service form |
| --- | --- | --- |
| what is delivered | the package, `com.example.hello-0.1.0.yoke` | each Plugin's executable and Manifest, as the distribution's files, and a composition document |
| who starts it | the account's guardian, through `yoke instance` | the init system, through `yoke service` |
| where it fits | a laboratory host, a workstation, anything an account administers | a device that starts with nobody present |
<!-- essentials end -->

In the service form there is no package: a distribution installs each Plugin's Manifest under
`/etc/yoke/plugins.d/<plugin>/manifest.yaml` and its executable at `/usr/lib/yoke/plugins/<plugin>`, the
administrator writes the composition under `/etc/yoke/deployments/` and links `/etc/yoke/deployment.yaml`
to it, and `yoke service check`, `start` and `status` act on it. A device built with the Yocto Project
takes Yoke's layer, `meta-yoke`: https://docs.yoke-project.dev/0.12.0/integrating/an-image/.

## A Core on another host

This release covers a Core on the host the agent works on, in either form. Reaching a Core on another host
is not covered here: a channel on a routable address carries TLS and a credential
(https://docs.yoke-project.dev/0.12.0/reference/interface-surface/a-routable-channel/), and the
administrative surface is local by construction. A later release of these skills will say how.

## Where the depth is

- The guide, *Building an application*: https://docs.yoke-project.dev/0.12.0/building/
- The reference: https://docs.yoke-project.dev/0.12.0/reference/
- Every page, with a line each: https://docs.yoke-project.dev/0.12.0/llms.txt
