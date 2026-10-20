# Kanban moves: moving a card queues real work

## Goal
On an epic page, moving a ticket card between stage columns queues the matching workflow step for that epic's coordinator, which carries it out; the card follows the real stage events, not the drop.

## Why
The epic page shows stages but can't change them; moving work along means typing instructions into a coordinator by hand. The user wants to run an epic from its board: drag a card, and an agent does the step.

## Non-goals
- Relabelling a stage without the work behind it. A move never writes a stage event itself.
- The board running builds, reviews or commits directly. The epic coordinator does; it dispatches builds to pi as usual.
- Changing coordinator scope: one coordinator per epic, as built in fm-3c3.8.
- Moves on the Initiatives board or for tickets outside an epic.

## Decisions
1. **A move is a command** (user). Dropping a card (or choosing Move to…) creates a queued move. The card shows its pending move; the stage changes only when the real event (dispatch, request_changes, commit, close, abandon) arrives.
2. **Executor** (user). Moves go to the epic's coordinator session. If it has none, or it is ended or parked, the first move launches or relaunches it (fm-3c3.8 Launch/Relaunch).
3. **Allowed moves** (user). Every other drop is refused on the spot, with the reason.

   | From | To | Coordinator instruction |
   | --- | --- | --- |
   | Queued | In flight | dispatch the ticket |
   | Review | In flight | request changes, with the note the user types |
   | Review | Shipping | approve: commit it |
   | Shipping | Done | close the ticket (after merge or push where the forge requires it) |
   | any live column | Abandoned | abandon the ticket, stopping its build if one runs |

4. **Visible, cancellable queue** (user). Pending moves show on their cards and in a queue list on the epic page, oldest first. A move can be cancelled until it is delivered.
5. **Delivery** (user). The board types into the coordinator pane only when that session is idle (waiting after a turn, per the session machine), under the same screen check as Reply (Claude's empty idle input). All undelivered moves go as one message, in queue order, one line per move, naming the ticket and instruction (and the note).
6. **Move lifecycle** (agent call). A move is a record with its own state machine, in the house FSM DSL:

   | state | event | result |
   | --- | --- | --- |
   | queued | cancel | cancelled |
   | queued | deliver | delivered |
   | queued | refuse (ticket left the source column, or epic closed) | stale |
   | delivered | stage event matching the move | done |
   | delivered | contrary stage event, or ticket closed otherwise | superseded |

   Delivered moves stay visible until done or superseded. There is no timeout: a delivered move that never lands shows its age.
7. **Queued order** (user). Dragging within Queued sets a `rank` field in the ticket files. The coordinator dispatches the top-ranked ready tickets first. (Agent call: the board writes `rank` through the ticket store the CLI uses, leaving an uncommitted ticket change in the main checkout for the coordinator to commit, the same as any ticket edit.)
8. **Input** (user). Drag and drop on desktop, plus a Move to… menu on every card (and keyboard reachable) for phones and keyboards. Both create the same move.
9. **Coordinator side** (agent call). The epic coordinator prompt template (foreman skill) tells it how to read board move messages and to act through the normal skills (dispatch, review, commit, close). Board messages are instructions from the user.

## Acceptance checks
- On a scratch board with a launched stub epic coordinator, dragging a Queued card to In flight creates a queued move; when the stub session goes idle, its pane receives one board message naming that ticket; a recorded dispatch event moves the card and marks the move done.
- Two moves made while the coordinator is busy arrive as one message, in order, after its next idle stop. Cancelling a third before delivery removes it from the message.
- Each refused drop (for example Queued → Done) leaves the card in place and states why; no move record is created.
- A move on an epic with no coordinator launches one and delivers after its first idle stop.
- Reordering Queued writes `rank` to the ticket files; `foreman check` passes; the order on the page and in `foreman ready` matches.
- The Move to… menu creates the same moves at 390 px and by keyboard. Screenshots light and dark at 390 and 1440 px of the epic page with pending, delivered and refused moves are inspected.
- `mix precommit` green.

## Verification plan
Seams: the move machine (pure step table tests); delivery (session idle + screen check, against a scratch tmux pane with stub Claude, as for Reply); the epic LiveView (drag hook events and menu, LiveView tests plus Playwright for drag); the ticket store `rank` write. Final check by the coordinator on the live board with a real epic coordinator.

## Ask-first boundaries
- Any move the board would execute itself instead of through the coordinator.
- Typing into a pane outside the idle screen check.
- New move kinds beyond the table.

## Left to the builder
Exact queue UI placement; message wording; the drag library or hook (prefer a small LiveView hook over a dependency); how `rank` sorts against priority in `foreman ready`.
