---
name: yoke-plugin
description: Use when writing a Yoke Plugin — a program the Core launches and supervises — in Go, Rust, Python, C or C++ — its declaration and Manifest, its capabilities, starting and registering, answering questions and acknowledging commands, reporting health, streams and occurrences, an orderly close, and putting it in a project. For the project, the command line and running it, use the yoke skill.
---

# A Yoke Plugin

A Plugin is a program the **Core** launches, admits and holds a **Session** with. It declares what it does
in its **Manifest** — the commands it accepts, the questions it answers, the streams and occurrences it
reports, and a capability governing each — and does nothing it has not declared. This skill is written for
Yoke 0.12.0; read https://docs.yoke-project.dev/0.12.0/building/a-plugin/ and the plugin surface's
reference, https://docs.yoke-project.dev/0.12.0/reference/plugin-surface/admission/, before relying on it.

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
(https://docs.yoke-project.dev/0.12.0/reference/plugin-surface/capabilities/).

## A Plugin, in Go

<!-- essentials: building/a-plugin#the-program code:go -->
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
	if len(os.Args) == 2 && os.Args[1] == "manifest" {
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

<!-- essentials: building/a-plugin#the-program table -->
| Part | What it does |
| --- | --- |
| `plugin.Declaration` | the identity and the four declared lists, each object governed by a capability — [the Manifest](https://docs.yoke-project.dev/0.12.0/reference/plugin-surface/the-manifest/), [capabilities](https://docs.yoke-project.dev/0.12.0/reference/plugin-surface/capabilities/) |
| `plugin.Start` | reads what the Core handed the process at launch, registers, and opens the Session — [what a unit arrives with](https://docs.yoke-project.dev/0.12.0/reference/plugin-surface/what-a-unit-arrives-with/), [the Session](https://docs.yoke-project.dev/0.12.0/reference/plugin-surface/the-session/) |
| `u.Health` | the first health report; liveness is reports arriving on the interval the Core assigned — [the families](https://docs.yoke-project.dev/0.12.0/reference/plugin-surface/the-families/) |
| `u.Events()` | what the Core sends: a `plugin.Question` to answer, a `plugin.Command` to acknowledge |
| `u.Answer` | the answer, correlated to its question; the payload is the Plugin's own bytes |
| `u.Close`, `u.Done` | an orderly end of the Session when the Core asks the process to stop |
<!-- essentials end -->

```
CGO_ENABLED=0 go build -o greeter .
./greeter manifest > com.example.greeter.yaml
```

A command arrives as an event too, and is acknowledged — accepted, done or failed; an acknowledgement
carries no result, since a result is an answer to a question. A stream is published only once the Core
has activated it, and stops when the Core stops it
(https://docs.yoke-project.dev/0.12.0/reference/plugin-surface/streams-and-transports/).

## In another language

<!-- essentials: building/a-plugin#in-another-language table -->
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
| Go | 0.6.1 | 16 cells, all pass | 7 cells, all pass | 6 cells, all pass |
| Rust | 0.5.0 | 16 cells, all pass | 7 cells, all pass | — |
| Python | 0.5.0 | 16 cells, all pass | 7 cells, all pass | — |
| C | 0.6.0 | 16 cells, all pass | 7 cells, all pass | — |
| C++ | 0.7.0 | 16 cells, all pass | 7 cells, all pass | — |
<!-- essentials end -->

`github.com/yoke-project/yoke-reference` holds a clock written as a Plugin in Go, Rust and Python, each
against its published library: start from the one in your language.

## Into a project, and running

```
mkdir -p hello/components/plugins
cp greeter/greeter hello/components/plugins/greeter
cp greeter/com.example.greeter.yaml hello/manifests/
yoke-compose add unit greeter --dir hello --kind plugin --plugin com.example.greeter \
  --exec components/plugins/greeter
yoke-compose check --dir hello
yoke app run --from hello
yoke plugin grant com.example.greeter query.hello.answer
yoke unit restart greeter
echo -n world | yoke unit ask greeter greeter.hello --input -
```

The yoke skill covers the rest of the project and the command line.

## Where the depth is

- The plugin surface: https://docs.yoke-project.dev/0.12.0/reference/plugin-surface/what-a-unit-arrives-with/
- The Session, health and liveness: https://docs.yoke-project.dev/0.12.0/reference/plugin-surface/the-session/
- Every page, with a line each: https://docs.yoke-project.dev/0.12.0/llms.txt
