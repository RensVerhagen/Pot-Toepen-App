# Pot Toepen — requirements

Updated 11 September 2026 after the first trial evening.
Source: [Pot-toepen feedback oppakken](chatgpt-conversation://6aa303ed-2ed4-83eb-8c3c-6615986d5c7f), plus the clarification that Toep-trek pays at most the remaining pot.

## Product and platform

An offline Android scorekeeper for 2–8 people at the same table. There is one active game, automatically saved locally in SQLite after each change. No account or network is required. Existing saved games remain readable. iOS remains a future target.

Names are trimmed, non-empty and unique. The roster stays fixed during a game; the table order can change. Previously used names remain available for subsequent games. Units are whole points, euros, dollars or pounds; decimals are not supported.

## Bookkeeping

- Every player starts at −1; the initial pot equals the player count.
- `pot = -sum(player scores)`. The pot must never become negative.
- Every player explicitly chooses a stake for a normal round. Untouched and zero are distinct states; zero means passing.
- Individual stakes may differ. Each stake is between zero and the pot at round start.
- Normal round: the winner gains their own stake; each other player loses their own stake. A player who passed cannot win that normal round.
- All amounts and scores are stored as integers. Records are compared only within the same unit.

Confirmed example: scores `[-2, -2, -3, -5]` imply a pot of 12. Stakes `[1, 1, 1, 5]` with the fourth player winning produce `[-3, -3, -4, 0]` and a pot of 10.

## Table order and dealer

The app randomly chooses the initial dealer once and persists the choice. A short visual roulette cycles through the names and slows to reveal that dealer. The player immediately after the dealer in the configured table order is seated to their left and stakes first; entry then wraps around the table, ending with the dealer.

The winner becomes the next dealer. For everyone-pass, the selected highest-hand player deals next; for Toep-trek, the recipient deals next. Contributions to the pot do not change the dealer or count as a played round.

The current dealer and last round winner remain visible below the pot. More (horizontal three-dot menu) → Spelers wijzigen opens the editable table order, with gently wiggling rows and drag handles. Saving preserves identities and scores. Reordering is blocked while stakes are entered, so an ongoing round cannot silently change order.

Legacy games without a recorded first dealer use the original list order for initial entry and do not replay the randomizer.

## Game setup and special amounts

At game start, enter both amounts with presets (1, 2, 3, 5, 10) or custom whole-number input:

- Toep-trek winnings.
- Everyone-pass / teruguittoepen penalty.

Suggested defaults are 2, but the user explicitly accepts or changes them. Before each subsequent normal round, the previous amounts are offered again for confirmation or adjustment. Once stakes are entered, amounts are locked for that round.

### Toep-trek

Before entering ordinary stakes, choose Toep-trek and select the recipient. Preview and confirm the payout. Only that player's score changes, by `min(agreed winnings, current pot)`.

**Acceptance example:** agreed winnings 10, pot 8 → recipient gains 8, pot becomes zero. No other player is charged. The game remains active until explicitly completed.

### Everyone passes

When every player explicitly passes, show “Iedereen heeft gepast” and explain teruguittoepen. The group selects the player with the highest hand. Preview and confirm the configured penalty; only that player loses the penalty and the pot grows by the same amount. No automatic contribution is charged to the other players.

The completed special round is recorded and can be undone.

## Round flow and presentation

1. The single prominent pot display sits above the players. Do not repeat a pot shortcut on each player row.
2. Press **Inzetten**. Offer the round amounts if needed, then enter stakes one player at a time in dealer-relative table order.
3. Quick choices: Pass (0), 1, 2, 3, 4, 5, 10, 15, 20 and 25, plus whole-pot and custom entry. Values above the pot remain visible but disabled.
4. Saving advances automatically. The current player's name slides out left and the next slides in from the right. A progress bar shows completed entries. A saved stake can be reopened to correct it.
5. Press **Ronde afronden**. Show every stake, then select an eligible winner, then preview all score changes and the projected pot.
6. Only **Uitkomst bevestigen** commits the outcome. Closing the review without confirmation leaves scores unchanged.
7. Celebrate the outcome and prepare a fresh round with the winner as dealer.

Use the existing dark green table, warm gold accents, readable signed scores, generous touch targets and haptics. Respect reduced-motion preferences for roulette, player transitions, row wiggle and celebrations. Content remains scrollable with a phone keyboard or enlarged text.

## Contributions, undo and records

**Pot bijspekken** offers 1, 2, 3 or 5 per player, before entering stakes. Always preview the multiplication and total (for example, 4 × 2 = 8). Confirmation subtracts the amount from every score atomically. It appears in the timeline and can be undone.

**Undo** always asks for confirmation. It reverses the most recent booked action or table/finale change. It may be repeated; arbitrary older actions cannot be selected. It restores scores, table order, dealer, entered stakes, settings and finale progress. There is no “ongedaan gemaakt” toast. Undo snapshots persist through app restart and store the round count instead of duplicating the entire prior round history.

Track the highest pot of the current game and across locally stored games with the same unit. A new game record gets a modest confetti celebration; a new all-time record gets a longer, larger celebration. Ordinary wins get a smaller celebration. Deleted games no longer contribute to records.

## Ending and optional finale

A game only ends through **Spel afronden**, with confirmation. Reaching zero — including the last finale payout — keeps it active and undoable. The final screen and chart are shown after explicit completion.

If a nonzero pot remains, the confirmation states the amount. The user can retain it in the completed snapshot or first use **Start finale** to pay it out. Finishing is blocked while normal stakes are pending.

The existing optional finale remains available:

- Choose 1 through P final rounds for a pot of P whole units.
- Each receives `floor(P/N)`, with the remainder distributed to the earliest rounds.
- Example: 80 / 3 → 27, 27, 26.
- Each winner gains that round's fixed payout; other scores stay unchanged.
- No individual stakes in finale rounds.
- The schedule can be changed before any payout. Later changes require undoing payouts first.
- The last payout leaves zero in the pot, but still requires manual game completion.

## Results, history and deletion

After completion, show final scores and one combined chart of the pot and cumulative score for each player. The horizontal axis starts with the initial state and then includes each booked round or contribution. The chart supports hiding/showing individual lines and selecting a step to read exact amounts. It is not shown during active play.

Completed and abandoned games remain stored locally. Final scores can still be shared through the platform share sheet, including WhatsApp.

**Spelgeschiedenis** is available from the three-dot menu on home and during play. Open an old game to inspect its final scores and timeline.

- Deleting one game asks for confirmation.
- Clearing history from the existing home overview removes historical games only.
- **Alle spelgegevens wissen** explicitly confirms that it removes historical games, the active game, records and remembered names. SQLite performs this as one transaction.

## Verification

Run `flutter analyze` and `flutter test`. Domain and widget tests cover bookkeeping, the 10/8 Toep-trek example, highest-hand penalties, repeated undo after serialization, table order, disabled stakes above the pot, explicit completion, cancellation of confirmations, storage failures, record deletion and enlarged phone text.

`flutter test --update-goldens tool/feedback_visual_test.dart` generates phone-size review images in the temporary `pot_toepen_feedback_visuals` directory, including a player transition and record celebration. This is an explicit visual QA tool, not a checked-in pixel baseline. The optional Windows Segoe UI font makes local previews readable; other systems use the default test font.
