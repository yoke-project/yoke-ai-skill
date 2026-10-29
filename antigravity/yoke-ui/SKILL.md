---
name: yoke-ui
description: Use when writing a Yoke interface client — a panel on a device, a browser's back end, or a command-line tool — that attaches to a channel of a running Yoke application to ask questions, give commands, read, subscribe and receive streams, in Go, Rust, Python, C or C++. For declaring the channel and running the application, use the yoke skill.
---

# A Yoke interface client

An interface client is anything that reaches an application from outside it, and it reaches it through a
**channel** the application's description declares. It speaks the **interface contract**, and nothing it
holds gives it administrative reach. This skill is written for Yoke 0.12.0; read
https://docs.yoke-project.dev/0.12.0/building/an-interface-client/ and the interface surface's reference,
https://docs.yoke-project.dev/0.12.0/reference/interface-surface/channels/, before relying on it.

<!-- essentials: building/an-interface-client table -->
|  | A managed interface | An attached client |
| --- | --- | --- |
| started by | the Core, as a unit of kind `interface` | whoever runs it |
| finds its channel | in `YOKE_SOCKET`, which the Core hands it | from the instance's name and the channel's |
| example | a device's own panel | the tool on this page |
<!-- essentials end -->

## The rules that explain most surprises

- **A client never polls.** It subscribes: a snapshot, then each change as it happens. A client that asks
  the same thing again and again is the defect the contract exists to prevent.
- **The library never retries and never reconnects.** An attachment that ended has ended; a client that
  wants another attaches again.
- **A channel can be suspended**, when another channel the deployment declares to prevail takes control.
  The connection stays up; a read-only channel keeps receiving and may not command, a dark one receives
  nothing. A client learns it from its own subscription and shows it — it never shows a stale picture as
  if it were live.
- **A channel holds as many clients as it declares**: one declared `single` refuses a second client with a
  reason, and does not displace the first.
- **The Core never reads a payload.** What a question, an answer or a command means is agreed with the
  Plugin that answers it.

## A client, in Go

<!-- essentials: building/an-interface-client#the-program code:go -->
```go
// Command ask is an interface client: it attaches to a channel of a running instance and asks one question.
package main

import (
	"context"
	"fmt"
	"os"
	"time"

	"github.com/yoke-project/yoke-sdk-go/iface"
)

func main() {
	if len(os.Args) != 4 {
		fmt.Fprintln(os.Stderr, "usage: ask <instance> <channel> <name>")
		os.Exit(2)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	// In an application instance a channel's socket derives from the instance's name.
	address, err := iface.Application(os.Args[1], os.Args[2], os.Getenv)
	if err != nil {
		fmt.Fprintln(os.Stderr, "ask:", err)
		os.Exit(1)
	}
	a, err := iface.Attach(ctx, address)
	if err != nil {
		fmt.Fprintln(os.Stderr, "ask:", err)
		os.Exit(1)
	}
	defer a.Close()
	answer, err := a.Ask(ctx, "greeter", "greeter.hello", []byte(os.Args[3]))
	if err != nil {
		fmt.Fprintln(os.Stderr, "ask:", err)
		os.Exit(1)
	}
	fmt.Println(string(answer))
}
```
<!-- essentials end -->

<!-- essentials: building/an-interface-client#the-program table -->
| Call | What it does |
| --- | --- |
| `iface.Application` | the channel's socket in an application instance; `iface.Service` is the service form's, `iface.Managed` a managed interface's |
| `iface.Attach` | attaches, and waits for the opening: what the channel may address and observe — [attaching](https://docs.yoke-project.dev/0.12.0/reference/interface-surface/attaching/) |
| `a.Ask` | asks a unit a question and returns its answer; `Command`, `Read`, `Subscribe` and the stream calls are the other operations — [the operations](https://docs.yoke-project.dev/0.12.0/reference/interface-surface/the-operations/) |
| `a.Close` | ends the attachment in order |
<!-- essentials end -->

## The operations

<!-- essentials: reference/interface-surface/the-operations#the-eleven table -->
| Operation | Subject | The Core | Answers with |
| --- | --- | --- | --- |
| `authenticate` | the channel | establishes the caller, where the address class requires one | accepted, or a refusal |
| `read` | a subject this channel may address | derives the current record | the same record the opening picture carries |
| `subscribe` | a filter on four axes | takes a subscription on the client's behalf | a snapshot at a sequence, then the changes |
| `confirm` | a subscription | records the position | nothing further — it is the live shape in the client's direction |
| `command` | a unit and a command type | issues a **control** message on that unit's Session | the unit's acknowledgement, correlated, or a refusal |
| `query` | a unit and a query type | issues a **query** message on that unit's Session | the unit's answer, correlated, or a refusal |
| `stream.start` | a unit and a stream | creates the transport, then activates the stream on the Session | the acknowledgement; `unit.stream.activated` follows as an event |
| `stream.stop` | a unit and a stream | instructs the unit, then removes the transport | the acknowledgement |
| `stream.subscribe` | a unit and a stream | grants a delivery and creates what carries it | **where the data will arrive** ([streams to clients](https://docs.yoke-project.dev/0.12.0/reference/interface-surface/streams-to-clients/)) |
| `stream.unsubscribe` | a delivery | releases it, and removes what carried it | acknowledged |
| `reclaim` | the channel | recomputes arbitration in this channel's favour, where it may ([arbitration](https://docs.yoke-project.dev/0.12.0/reference/interface-surface/arbitration/)) | the channel's state after the recomputation |
<!-- essentials end -->

## The channel it attaches to

The channel is declared in the project, with its transport and its cardinality: `local` for a client on
the same host, `http+ws` for a browser.

```
yoke-compose add channel cli --dir hello --transport local --clients multiple
```

A channel on a routable address carries TLS and a credential establishing the caller
(https://docs.yoke-project.dev/0.12.0/reference/interface-surface/a-routable-channel/). In the service form
a client finds its channel with `iface.Service` instead of `iface.Application`.

## In another language

<!-- essentials: building/an-interface-client#in-another-language table -->
| Family | A client imports |
| --- | --- |
| Go | `iface`, in `github.com/yoke-project/yoke-sdk-go` |
| Rust | `yoke_sdk::interface` |
| Python | `yoke_sdk.interface` |
| C | `yoke/interface.h` |
| C++ | `yoke/interface.hpp` |
<!-- essentials end -->

`github.com/yoke-project/yoke-reference` holds clients written with four of them: a terminal client in
Rust and in Python, and an instrument's panel in C++ with Qt and in C with LVGL.

## Where the depth is

- Attaching, and what a channel sees: https://docs.yoke-project.dev/0.12.0/reference/interface-surface/attaching/
- Arbitration: https://docs.yoke-project.dev/0.12.0/reference/interface-surface/arbitration/
- The interface library: https://docs.yoke-project.dev/0.12.0/reference/the-libraries/the-interface-library/
- Every page, with a line each: https://docs.yoke-project.dev/0.12.0/llms.txt
