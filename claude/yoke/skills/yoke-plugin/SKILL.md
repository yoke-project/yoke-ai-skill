---
name: yoke-plugin
description: Use when writing a Yoke Plugin — a program the Core launches and supervises — in Go, Rust, Python, C or C++ — its declaration and Manifest, its capabilities, starting and registering, answering questions and acknowledging commands, reporting health, streams and occurrences, an orderly close, and putting it in a project. For the project, the command line and running it, use the yoke skill.
---

# A Yoke Plugin

A Plugin is a program the **Core** launches, admits and holds a **Session** with. It declares what it does
in its **Manifest** — the commands it accepts, the questions it answers, the streams and occurrences it
reports, and a capability governing each — and does nothing it has not declared. This skill is written for
Yoke 0.13.0; read https://docs.yoke-project.dev/0.13.0/building-a-plugin/ and the plugin surface's
reference, https://docs.yoke-project.dev/0.13.0/reference/plugin-surface/admission/, before relying on it.

## The rules that explain most surprises

- **A declaration grants nothing.** What a unit may do is its declaration intersected with an operator's
  grants, computed **once, at admission**. A capability granted while the unit runs reaches it when it is
  restarted.
- **The Core never reads a payload.** A question, an answer, a command and stream data are the Plugin's
  own bytes; choose their encoding with the clients that read them.
- **A Plugin started by hand is not admitted**: it has no token, because the Core did not launch it. Run
  it through the Core — `yoke app run --from <project>` — and, under a debugger,
  `yoke app run --from <project> --admit-unlaunched`.
- **Generate the Manifest from the declaration** the program registers with, so the two cannot disagree;
  admission refuses a process whose claims differ from its Manifest.
- **An executable is pinned by digest in the project.** After every rebuild, write the digest again.

## The Manifest

<!-- essentials: reference/plugin-surface/the-manifest#the-document code -->
```yaml
manifest: 1
id: com.yoke.station.acquire
protocol: 1

needs:
  - device:instrument

streams:
  - id: station.spectra
  - id: station.preview
    tolerates_loss: true
    tolerates_reorder: true

commands:
  - id: calibrate
  - id: set-range

queries:
  - id: head-status

occurrences:
  - id: calibration.drift

capabilities:
  - name: stream.spectra.publish
    governs: { stream: station.spectra }
  - name: command.calibrate.accept
    governs: { command: calibrate }
  - name: query.head-status.answer
    governs: { query: head-status }
  - name: event.calibration-drift.report
    governs: { occurrence: calibration.drift }
```
<!-- essentials end -->

<!-- essentials: reference/plugin-surface/the-manifest#the-document table -->
| Key | Type | Required | Holds |
| --- | --- | --- | --- |
| `manifest` | integer | yes | the version of the Manifest model the document is written against; read first |
| `id` | namespaced identifier | yes | the Plugin's identity |
| `protocol` | integer | yes | the version of the plugin surface the binary speaks |
| `needs` | list | — | the classes of thing the Plugin must reach |
| `streams` | list | — | the streams it may publish |
| `commands` | list | — | the command types it accepts |
| `queries` | list | — | the query types it answers |
| `occurrences` | list | — | the classes of occurrence it may report |
| `capabilities` | list | — | what an operator may grant, each governing one object |
<!-- essentials end -->

An unknown key is refused at any level, never ignored. Every declared stream, command, query and
occurrence needs a capability governing it, and the name of a capability is the author's: what matters is
that the Manifest declares it and an operator grants it
(https://docs.yoke-project.dev/0.13.0/reference/plugin-surface/capabilities/).

## Starting one

A Plugin is a project of its own, made from its family's template. The template comes from the composer's
own release, so the composer and the library were released together:

```
yoke-compose new plugin com.example.greeter --language go
```

`--language` is `go`, `rust`, `c` or `cpp`. Python has no template in this release: a Python Plugin is
started by hand, as the end of each page of
https://docs.yoke-project.dev/0.13.0/building-a-plugin/starting-it/ shows. A composer built from source is
no release's and refuses: name one with `--release <version>`, or an archive with `--template <file>`.

The project holds `yoke-plugin.yaml`, which states the build and no version; `plugin/`, the source and the
Manifest; and `try/`, the smallest application around it.

## A Plugin, in Go

<!-- essentials: building-a-plugin/the-program code:go -->
```go
// Command greeter is a Plugin that answers one question: who it is greeting.
package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/yoke-project/yoke-sdk-go/plugin"
)

func declaration() plugin.Declaration {
	return plugin.Declaration{
		ID:      "com.example.greeter",
		Queries: []string{"greeter.hello"},
		Capabilities: []plugin.Capability{
			{Name: "query.hello.answer", Governs: plugin.Object{Query: "greeter.hello"}},
		},
	}
}

func main() {
	// The Manifest is generated from the declaration, so the two cannot disagree.
	if len(os.Args) == 2 && os.Args[1] == "--manifest" {
		os.Stdout.Write(declaration().Manifest())
		return
	}
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, os.Interrupt)
	defer stop()
	u, err := plugin.Start(ctx, declaration())
	if err != nil {
		fmt.Fprintln(os.Stderr, "greeter:", err)
		os.Exit(1)
	}
	u.Health(0, "ready to greet")
	for {
		select {
		case event, open := <-u.Events():
			if !open {
				return
			}
			if q, ok := event.(plugin.Question); ok && q.Type == "greeter.hello" {
				u.Answer(q, []byte("hello, "+string(q.Payload)))
			}
		case <-ctx.Done():
			// Asked to stop: close the Session in order, and leave once it has ended.
			u.Close()
			<-u.Done()
			return
		}
	}
}
```
<!-- essentials end -->

<!-- essentials: building-a-plugin/the-program#what-each-part-does table -->
| Part | What it does |
| --- | --- |
| **the declaration** | the identity, the question the Plugin answers, and the capability that governs it. Everything a Plugin may be asked or may send is declared, and each object is governed by exactly one capability ([the Manifest](https://docs.yoke-project.dev/0.13.0/reference/plugin-surface/the-manifest/), [capabilities](https://docs.yoke-project.dev/0.13.0/reference/plugin-surface/capabilities/)) |
| **`--manifest`** | prints the Manifest the declaration generates. The program is the only source of it, so the file shipped beside the program cannot disagree with what the program registers |
| **the start** | reads what the Core handed the process at launch, binds the unit's own socket, registers, and opens the Session. A refusal is returned or thrown, and nothing is tried again ([what a unit arrives with](https://docs.yoke-project.dev/0.13.0/reference/plugin-surface/what-a-unit-arrives-with/), [admission](https://docs.yoke-project.dev/0.13.0/reference/plugin-surface/admission/)) |
| **the first health report** | a grade on the scale an event's severity uses, 0 to 99 and higher more serious, and a line for a person. The library repeats the last report at every beat and sends none before the first, so a Plugin that never reports loses its liveness and is ended ([the families](https://docs.yoke-project.dev/0.13.0/reference/plugin-surface/the-families/)) |
| **the events** | what the Core sends, in the order it sent it: a question to answer, a command to acknowledge, a stream to start or stop, a refusal, and the end of the Session |
| **the answer** | correlated to its question by the library. The payload is the Plugin's own bytes: the Core carries it and never reads it |
| **the close** | on `SIGTERM`, the Core's way of asking a unit to stop: the Plugin closes the Session, waits for its end, and exits. A unit still running when the deployment's stop window has passed is killed ([the Session](https://docs.yoke-project.dev/0.13.0/reference/plugin-surface/the-session/)) |
<!-- essentials end -->

From the Plugin project, the composer runs the build `yoke-plugin.yaml` states, and leaves the executable
in `build/<arch>/`. The Manifest is kept in the source, printed by the program:

```
yoke-compose build
build/x86_64/greeter --manifest > plugin/com.example.greeter.yaml
```

A command arrives as an event too, and is acknowledged — accepted, done or failed; an acknowledgement
carries no result, since a result is an answer to a question. **A question the Plugin cannot answer is
failed, never answered with an error dressed as a payload**: the unit answers it with an error carrying
a code and a message in its own terms, and the caller is refused with `unit.failed` carrying them — Go `u.Fail(q.ID,
code, message)`, Rust `unit.fail(&q.id, code, message).await`, C `yoke_fail`, C++ `unit.fail`. The Python
family has no such act yet. A stream is published only once the Core
has activated it, and stops when the Core stops it
(https://docs.yoke-project.dev/0.13.0/reference/plugin-surface/streams-and-transports/).

## In another language

<!-- essentials: plugins-and-applications/a-plugin#the-declaration-in-five-languages table -->
| Family | The library | A Plugin imports |
| --- | --- | --- |
| Go | the module `github.com/yoke-project/yoke-sdk-go` | `plugin` |
| Rust | the crate `yoke-sdk` | `yoke_sdk::plugin` |
| Python | the package `yoke-sdk` | `yoke_sdk.plugin` |
| C | `yoke-sdk-c`, released as its source | `yoke/plugin.h` |
| C++ | `yoke-sdk-cpp`, released as its source | `yoke/plugin.hpp` |
<!-- essentials end -->

The model is the same in each — a declaration, a start that registers, events to answer, an orderly close
— and only the spelling changes. Which contracts each family covers, read from the release's conformance
report:

<!-- essentials: reference/the-libraries/what-each-family-offers table -->
| Family | Version | Plugin library | Interface library | Administrative library |
| --- | --- | --- | --- | --- |
| Go | 0.7.0 | 16 cells, all pass | 7 cells, all pass | 6 cells, all pass |
| Rust | 0.6.0 | 16 cells, all pass | 7 cells, all pass | — |
| Python | 0.5.0 | 16 cells, all pass | 7 cells, all pass | — |
| C | 0.7.0 | 16 cells, all pass | 7 cells, all pass | — |
| C++ | 0.8.0 | 16 cells, all pass | 7 cells, all pass | — |
<!-- essentials end -->

`github.com/yoke-project/yoke-reference` holds a clock written as a Plugin in Go, Rust and Python, each
against its published library: start from the one in your language.

## Trying it, and handing it on

`try/` is an application that takes the Plugin, and it holds the program the template wrote. After replacing
that program, and printing its Manifest again, take the new one in its place, from `try/`:

```
yoke-compose update plugin com.example.greeter
```

A Plugin taken from a path is built from the path again and replaces the two files, the digest and the
record. Taking a Plugin runs its author's build, so the composer shows the source, the commit and the
command, and asks. Then, from the Plugin project, run it, grant what it declared, and ask it:

```
yoke app run --from try
yoke plugin grant com.example.greeter query.hello.answer
yoke unit restart greeter
echo -n world | yoke unit ask greeter greeter.hello --input -
```

A Plugin is published as its source, at a tag `vX.Y.Z`, and the tag is its version. An application takes it
by the repository and the tag, and `try/` never travels with it:

```
yoke-compose add plugin <repository url>@v0.1.0
yoke-compose update plugin com.example.greeter --to v0.2.0
```

The yoke skill covers the rest of the project and the command line.

## Where the depth is

- Building a Plugin, every step in each language: https://docs.yoke-project.dev/0.13.0/building-a-plugin/
- The plugin surface: https://docs.yoke-project.dev/0.13.0/reference/plugin-surface/what-a-unit-arrives-with/
- The Session, health and liveness: https://docs.yoke-project.dev/0.13.0/reference/plugin-surface/the-session/
- Every page, with a line each: https://docs.yoke-project.dev/0.13.0/llms.txt
