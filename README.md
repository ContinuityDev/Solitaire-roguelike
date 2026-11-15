# President

You and **five AIs** play President (shedding). Last seat with HP wins the run.

Play in the browser once GitHub Pages is on: https://continuitydev.github.io/Solitaire-roguelike/

## How a round works

- 52-card deck, six seats. Rank order: **3 lowest … King, Ace, then 2s (bombs)**.
- Play **N of a kind** (single, pair, trips, four). Follow with the same count, equal or higher rank. Pass if you cannot or will not.
- When everyone else passes, the last player to play **leads** anything.
- **You lead round 1.** Later rounds, last round’s 1st place leads if they are still living; otherwise you do.
- First empty hand is 1st (President). Play continues until everyone is placed.
- 0 HP seats sit out the next deal.

### Your turn
**Yellow cards** are legal. Tap one to auto-select the required count (one on lead — tap extras of that rank to add copies; on follow, exactly the trick count). Then **Play**, or **double-tap** a yellow card to play immediately. **Pass** is always legal except on lead. A **YOUR TURN** banner means Play is live — if it is someone else’s turn, wait for the fly-in. Action cards in your tray fire on your turn. Opponents show a fan of card-backs and a large count of cards left.

## HP and gold

Everyone starts at **50 HP**. You do **not** die after round 1.

| Place | Gold (you) | HP |
|---|---|---|
| 1st | 4 | +stake |
| 2nd | 6 | +stake |
| 3rd | 8 | +half stake |
| 4th | 12 | −half stake |
| 5th | 16 | −stake |
| 6th | 22 | −stake |

Stake starts at 5 and climbs each round (`4 + round`). **Worse finish = more gold** so you can shop back in. Top half of *living* seats gain HP; bottom half lose it. At 0 HP you are out. Last living seat wins.

## The desk (shop)

After every round, spend gold:

**Upgrades (keep):** Packed Briefcase (more pairs), Favorite rank (2s / Aces / Kings), Deep Pockets (+10 max HP), Incumbent (+1 card from kitty), Whip Count (once per round: can that AI follow?).

**Action cards (one-shot):** Veto (skip next opponent), Filibuster (they must pass), Executive Order (any rank of the required count), Leak (peek a hand), Tax (steal from the current last-place AI), Rally (draw 2).

## AIs

The Speaker, The Whip, The Veep, The Justice, The General. They dump low cards, follow cheapest, and save 2s unless they are aggressive or about to go out.

## Run it

Godot 4.3. Open `project.godot`, press Play.

```bash
godot --headless --script tests/logic_test.gd   # ALL TESTS PASSED
cd docs && python3 -m http.server 8000          # web export
```

The web export is the no-threads template (plain HTTP, no COOP/COEP). GitHub Pages: Settings → Pages → Branch `main`, folder `/docs` → Save.
