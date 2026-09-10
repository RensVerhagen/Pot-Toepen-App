# Pot Toepen App — requirements

Status: implemented MVP baseline, 8 September 2026.

Source: [Pot Toepen App Requirements](chatgpt-conversation://6a789280-13c8-83eb-a372-c1ee2f0258f7)

This document records the latest conclusions from that conversation. Earlier ideas that conflict with the confirmed rules below are intentionally not treated as requirements.

## Product goal

Build a fast, simple, and reliable Pot Toepen scorekeeper for Android. During play, the scorekeeper records what happened in a round and performs the bookkeeping automatically. iPhone support is a future portability goal, not an MVP requirement.

The MVP is local-first and requires no user account, backend, or cloud synchronization. Games, players, active state, rounds, and history are stored only on the device and remain usable without an internet connection.

Previously used player names are remembered locally. When starting a later game, the scorekeeper can select those players quickly without retyping their names.

Only one game can be active at a time. Every change is automatically saved, and the active game is offered for resumption after the app restarts. Starting another game requires completing or explicitly abandoning the active game.

An active game can be abandoned after confirmation. It remains in history with the status `ABANDONED`, distinct from `COMPLETED`.

Completed and abandoned games are retained locally until the user deletes them. Completed games are read-only. The app supports deleting one historical game or clearing all history, with confirmation.

After a game is completed, its results can be shared through the phone's standard share sheet, including WhatsApp. The feature must not depend on a direct WhatsApp API integration. For the MVP, the shared message contains only the final player names and scores, ordered from highest to lowest and displayed with the selected unit.

## Confirmed game and score rules

- A game supports 2–8 players. Four players is the usual table size for standard Toepen.
- The score unit is selected when starting a game. It supports at least unitless points, euros, and US dollars; the UI uses the selected unit consistently for scores, stakes, and the pot.
- For the MVP, one score point always equals one selected unit. Custom conversion rates are not part of the MVP.
- Every player has an individual score.
- A player's score may be negative, zero, or positive. There is no confirmed per-player minimum or maximum.
- Scores are signed whole numbers. Every player starts a new game at `-1`.
- Stakes, pot values, and final-round payouts are non-negative whole numbers. Decimal values and negative stakes are not supported in the MVP.
- The pot is derived from the scores and is not an independently editable value:

  `pot = -1 × sum(all player scores)`

- The sum of all player scores may not be positive, because that would imply a negative pot.
- For every completed round, exactly one player is the winner.
- Every player explicitly declares an individual stake for every round.
- A stake of `0` is valid.
- There is no default stake. At the start of a round, every stake is in the distinct state `not entered` rather than implicitly being `0` or `1`.
- Different players may declare different stakes in the same round.
- A player's maximum stake is the value of the pot at the start of the round.
- The starting pot is fixed for validation throughout that round. Stakes or projected score changes within the round do not raise the maximum stake.
- When the round is processed:
  - the winner's new score is `old score + winner's stake`;
  - every loser's new score is `old score - that player's stake`.
- The pot after processing is recalculated from the resulting player scores.
- A player may use a one-tap `POT` action to set their stake to the complete pot-at-round-start value.
- The player roster is fixed after a game starts. Players cannot join, leave, or be replaced during an active game.
- Player names are trimmed, non-empty, and unique within a game. Remembered players may be renamed or removed without changing historical game snapshots.

### Confirmed example

Before the round:

| Player | Score |
|---|---:|
| Player 1 | -2 |
| Player 2 | -2 |
| Player 3 | -3 |
| Player 4 | -5 |

The sum is `-12`, so the pot is `12`.

For the next round, Players 1–3 each stake `1`, Player 4 stakes `5`, and Player 4 wins. The new scores are:

| Player | Score change | New score |
|---|---:|---:|
| Player 1 | -1 | -3 |
| Player 2 | -1 | -3 |
| Player 3 | -1 | -4 |
| Player 4 | +5 | 0 |

The new sum is `-10`, so the new pot is `10`.

## Core round-entry flow

1. Start a new round and snapshot the current pot as `potAtRoundStart`.
2. Show every player's name, current score, an unentered stake, and a per-player `POT` shortcut.
3. Require an explicit stake for every player, including an explicit `0` when applicable.
4. Select the winner.
5. Preview every score change and the projected new pot.
6. Process and persist the round as one atomic action.
7. Offer immediate undo.

A round cannot be processed until every player has explicitly entered a stake and a winner has been selected.

## UX requirements and proposals

### Required

- Keep the current pot prominently visible while entering a round.
- Make `not entered` visually different from a stake of `0`.
- Prevent selection or entry of a stake above `potAtRoundStart`.
- Provide a prominent one-tap `POT` choice for each player.
- Show the projected scores and projected pot before processing the round.
- Do not require a second confirmation dialog after the user deliberately presses the process/save button.
- Keep undo easy to reach after processing a round.

### Implemented interaction details

- Tapping any player's stake opens a mobile numeric bottom sheet with common exact amounts, decrement/increment controls, and the `POT` shortcut.
- After entering a stake, the app automatically advances to the next player whose stake is still unentered. The user can still tap any player row directly.
- Put a winner/trophy action directly on each player row instead of using a dropdown.
- Maintain a simple round history as an audit trail, showing the winner, all stakes, score changes, and pot before/after.

## Initial game setup

When a new game starts, every player automatically receives a score of `-1`. The initial pot therefore equals the number of players. This initial buy-in is fixed rather than manually entered or configured.

The 2–8 player range follows commonly published rules for standard Toepen; four is the usual number of players. Sources: [Het Spelenboek](https://www.spelenboek.nl/kaarten/toepen/), [CardgamesHub](https://cardgameshub.com/nl/kenniscentrum/spelregels-toepen/), and [Spel-regels.nl](https://www.spel-regels.nl/toepen-html/).

## Ending a game

- A game has no automatic score, pot, round, or time limit.
- The group decides when normal play ends.
- The group then chooses a number of final payout rounds in which the complete remaining pot will be emptied.
- The app calculates the payout for each final round from the pot at the moment the closing phase starts.
- Example: with `EUR 80` remaining and four final rounds, each final-round winner receives `EUR 20`.
- Players do not enter individual stakes during final payout rounds.
- Processing a final payout round adds that round's fixed payout to the winner's score. All losing-player scores remain unchanged.
- Final-round payouts use whole selected units and may differ because of rounding, but their sum must equal the complete pot exactly.
- For a pot `P` and `N` final rounds, every round first receives `floor(P / N)`. The remainder `P mod N` is distributed one unit at a time over the earliest rounds.
- Example: a pot of `80` over three rounds is paid out as `27`, `27`, and `26`.
- The chosen number of final rounds must be at least `1` and no greater than the number of whole units in the pot. This prevents zero-value final rounds.
- After all final payout rounds have been processed, the pot must be `0` and the game can be completed.
- If the pot is already `0` when the group ends normal play, the game can be completed immediately without final payout rounds.
- The closing phase can be cancelled or its round count changed until the first final payout round is processed.
- After the first final payout round is processed, the payout schedule is locked. Returning to normal play requires undoing all processed final payout rounds first.

## History and corrections

- Every processed normal round and final payout round is recorded in an audit history.
- Undo reverses the most recently processed round atomically, restoring player scores, the derived pot, and closing-phase progress.
- Undo can be repeated to walk backward through earlier rounds while the game remains active.
- Arbitrary editing or deletion of an older round is not supported in the MVP; the user must undo back to it.

## Data model implications

Suggested minimum domain concepts:

### Player

- `id`
- `name`

### Game

- `id`
- `createdAt`
- `finishedAt` (optional)
- `status`
- `scoreUnit` (for example `POINTS`, `EUR`, or `USD`)

### GamePlayer

- `gameId`
- `playerId`
- `displayName`
- `currentScore`
- `position`

### Round

- `id`
- `gameId`
- `createdAt`
- `potAtRoundStart`
- `winnerPlayerId`
- one explicit stake per participating player
- resulting score changes or enough immutable input data to reproduce them

The live pot should be calculated from current player scores rather than stored as independently mutable game state. `potAtRoundStart` belongs on the round so validation, history, and undo remain deterministic.

## Acceptance criteria for round processing

- A new game can only be started with 2–8 players.
- Starting a new game gives every player a score of `-1`; a four-player game therefore starts with a pot of `4`.
- With scores `[-2, -2, -3, -5]`, the displayed pot is `12`.
- Given stakes `[1, 1, 1, 5]` and Player 4 as winner, processing produces `[-3, -3, -4, 0]` and a displayed pot of `10`.
- A positive individual score is accepted when the total score still implies a non-negative pot.
- `0` is accepted only after the user explicitly enters it; an untouched stake remains incomplete.
- With a pot-at-round-start of `12`, a stake of `12` is accepted and a stake of `13` is rejected.
- Pressing a player's `POT` shortcut when the pot-at-round-start is `12` sets that player's stake to `12`.
- Changes to other stakes during entry do not change the round's maximum allowed stake.
- The round is rejected while any stake is unentered or no winner is selected.
- Processing a round updates all player scores and the derived pot atomically.
- Undo restores the complete previous score state and pot.
- Repeated undo restores earlier rounds one at a time.
- A negative player score is valid; a negative stake, pot, or payout is rejected.
- Decimal scores, stakes, pot values, and payouts are rejected in the MVP.

## Still open

- Final visual design details to validate during implementation and real-world use.

## Nice to have later

- Build, test, and publish the existing Flutter iOS target.
- Allow a configurable monetary value per score point, such as `1 point = EUR 0.50`.
- Cross-game player statistics.
- Payment-request integration.
- Backup, import/export, and transfer to another device.
- Multiple simultaneous active games.
