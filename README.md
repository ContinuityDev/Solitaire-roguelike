# President

A cabinet shedding game with an **endless Balatro-style run**. **Title screen** first — pick a mode:

- **Solo / vs AIs** — you versus five cabinet AIs (endless ante climb).
- **Local Lobby** — host 2–6 seats. You are always **player one** (rename yourself). **Hotseat** still works on this device. The gold **4-letter table code** is how someone else sits down from another browser on this same page (WebRTC, peer-to-peer). Empty seats stay AIs.
- **Join Table** — your name + the host’s table code. Two phones, two tabs, or a friend on the same Wi-Fi. You take the next empty seat. Desktop Godot still also does classic **LAN by IP** (UDP 24567).

Play in the browser once GitHub Pages is on: https://continuitydev.github.io/Solitaire-roguelike/

### How to start
1. Open the game. You land on **PRESIDENT / THE CABINET**, not in a run. The title shows your **best round** reached.
2. **Solo / vs AIs** starts a 6-seat endless run immediately (you + five AIs). **Title** on the table (or game-over) returns to the menu. **New Run** restarts the same mode.
3. **Local Lobby** — table name, **your name** (player one), a **4-letter code**, **+/– seats** (2–6), each row **Human** or **AI**. Seat 1 is the host (always human). **Empty → AI** fills the rest. **Start** deals. Share the code; friends open this same page → **Join Table**. When another *local* human’s turn comes up, **Pass the device** covers the cards until they tap **I’m P#**. Remote joiners play on their own phone — they only see their own hand.
4. **Join Table** — your name, the host’s 4-letter code, **Sit down**. Wait for the host to Start. If they leave, you drop back to title. If you disconnect mid-run, the host turns your seat into an AI. Signaling uses a public MQTT broker; game traffic is peer-to-peer WebRTC (STUN). Strict mobile NATs may fail without a TURN server — same Wi-Fi is the reliable case.

There is **no win screen**. The run continues until every human hits 0 HP. Dead AI seats are revived between rounds so the cabinet never collapses into a last-seat finish. How far you got (round / ante) is the score; best round is saved locally.

## How a round works

- **54-card deck** (52 + **2 jokers**), six seats. Rank order: **3 lowest … King, Ace, then 2s (bombs)**, then uncapped **super ranks** (16, 17, …) once inflation / Incumbent climb past bombs.
- Each round applies **rank inflation** (`bonus = (r−1) + ⌊(r−1)² / 8⌋` where `r` is the round). Faces show compact labels at huge values (`1.2K`, `3.4M`, scientific past trillions).
- Play **N of a kind** (single, pair, trips, four). Follow with the same count, equal or **higher effective rank**. A blue value is the trick’s true rank: if someone plays a 5 that reads as a blue 6, the trick is a 6 — a printed 5 cannot follow. Pass if you cannot or will not.
- **Joker (instant round-ender):** a single joker is always legal on your turn (lead or follow, any count). Playing it dumps the rest of that seat’s hand to the kitty, that seat **finishes immediately** (President if they are first out), and the round is over. Remaining seats are ranked by **fewest cards left** (seat index breaks ties). Jokers have a purple **Jk / JOKER** face (red or black star).
- When everyone else passes, the last player to play **leads** anything.
- **Host leads round 1** (seat 0). Later rounds, last round’s 1st place leads if they are still living; otherwise the host does.
- First empty hand is 1st (**President**). Play continues until everyone is placed: VP, Neutral, Vice-Asshole, **Asshole**.
- After the next deal, classic **tribute**: Asshole gives their 2 highest cards to President, who returns any 2; Vice-Asshole gives 1 highest to VP, who returns 1. Dead seats skip. With 3 living only the 2-card trade runs; with 2, no trade.
- Human seats at 0 HP sit out (and end the run when every human is out). Dead **AI** seats are revived at the next round so the table stays full.

### Your turn
**Yellow cards** are legal. Tap one to auto-select the required count (one on lead — tap extras of that rank to add copies; on follow, exactly the trick count). Then **Play**, or **double-tap** a yellow card to play immediately. **Pass** is always legal except on lead. A **YOUR TURN** banner means Play is live — if it is someone else’s turn, wait for the fly-in. Action cards in your tray fire on your turn. Opponents show a fan of card-backs, a large count of cards left, and their gold.

The **odds line** under the trick is Hayden’s view of the rest of the table: unseen 2s / Aces / Kings (your copies subtracted, plus cards that already hit the table), then a guess at whether the next AI still holds a 2 or the current trick rank. Timid seats (Speaker persona 0) are biased toward *saving* bombs; aggressive seats toward dumping them. A pass on a trick they could have followed slashes those odds.

## HP, gold, and Survivor Chips

Everyone starts at **50 HP**. You do **not** die after round 1. **Every seat earns gold** — AIs shop and spend it.

**Survivor Chips (◈)** are a second wallet for humans only. Whenever an AI hits 0 HP (end-of-round payout or mid-round whip damage), each living human gains chips (`1 + Chip Magnet stacks` per KO). Spend chips at the desk on **rank customizations** and chip-priced economy upgrades. Gold still buys the classic desk row.

### Economy / synergy (first-pass)
| Id | Currency | Effect |
|---|---|---|
| Payroll | gold | +2 gold on every place payout (stacks) |
| Compound Interest | gold | Desk open: gain 10% gold (+5%/extra stack) |
| Chip Magnet | gold | +1◈ per AI knockout (stacks) |
| Gold Rush | gold | Rank-customization gold ×(1+stacks) |
| War Chest | chips | +1◈ at the start of each round (stacks) |
| Syndicate | chips | At payout, +1◈ per $5 you earned (stacks) |
| Patronage | chips | Rank-fx chip prices −1 (stacks, min 1) |
| Echo Chamber | chips | When a customized rank pays gold, also +1◈/stack |

### Rank customizations
Chip offers bind an effect to a **deal-face** (3…K, A, 2). Inflation / Incumbent change the printed number, but the customization still fires. Effects (level by rebuying): **gold**, **chips**, **power**, **damage** (weakest AI), **heal**, **always legal**, **buff hand** (promote lowest). Teal ribbon on the card shows the active effects.

| Place | Gold | HP |
|---|---|---|
| 1st | 2 | +stake |
| 2nd | 3 | +stake |
| 3rd | 4 | +half stake |
| 4th | 5 | −half stake |
| 5th | 7 | −stake |
| 6th | 9 | −stake |

**Ante** advances every 3 rounds. **Stake** = `5 + round + (ante−1)×3 + ⌊(round−1)/5⌋×2` (late tax so snowballs eventually lose). Rank inflation = `(r−1) + ⌊(r−1)²/6⌋`. AI revive HP scales with ante so knockouts (and chips) slow late while stake keeps climbing. Every seat also gets `ante−1` bonus gold. **Worse finish = more gold** so you can shop back in. Top half of *living* seats gain HP; bottom half lose it. At 0 HP a human is out — when all humans are out, the run ends.

## The desk (shop)

After every round, spend gold. The Desk shows **4 random offers** (a mix of upgrades, rank binds, actions, and enhancements) — not the whole catalog. **Reroll** redraws the stock for `$2 + $2 × rerolls this visit` (Lobbyist still discounts). Maxed copies do not restock.

**Upgrades (keep):** Packed Briefcase **$12**, Favorite rank (2s **$16** / Aces **$14** / Kings **$12**), Deep Pockets **$14**, Incumbent **$10** (promote your lowest card one rank after each deal), Whip Count **$8**, Lobbyist **$18**, Populist Wave **$11**, Oval Office **$15**, Majority Whip **$10**, Safe Seat **$16**.

**Rank binds (seat-scoped):** Gold Fives / Threes / Tens, Ace Authority, Kingmaker, Heavier Bombs, Strong Fives, Ace Privilege, Bomb Privilege. These only affect *your* plays — your 5s can pay gold or beat a 6; the Whip’s 5s do not.

**Enhancements:** Steel Card **$13**, Gilded Seal **$11**, Union Deal **$12**, Wax Seal **$10**, Lucky Draw **$9** (swap your lowest card with a random kitty card — does not add a card).

**Action cards (one-shot):** Veto **$10**, Filibuster **$12**, Executive Order **$16**, Leak **$8**, Tax **$14**, Rally **$11** (promote two lowest cards), **Forge Bomb $10** (replace your lowest non-2 with a 2), plus role cards — **Uprising $15**, **Just Say No $13**, Impeach **$12**, Pardon **$14**, Coup **$18**, Recess **$16**.

Nothing on the desk grants extra shop items or extra cards from the kitty. Transforms stay in-place.

### Role streak
Finishing in the **same role** consecutive rounds pays bonus gold: streak 1 is base only; streak 2 is **+3**; streak 3 is **+6**; in general **`3 × (streak − 1)`**. It resets when your role changes. Every seat is tracked; results show e.g. `President ×3 · streak bonus +6`.

## AIs

The Speaker, The Whip, The Veep, The Justice, The General (or whoever occupies an AI seat). They dump low cards, follow cheapest, and save 2s unless they are aggressive or about to go out. Empty lobby seats can be kicked to AI.

Each AI starts with a **personal rank specialty** (Speaker: stronger 2s, Whip: gold on 5s, Veep: Aces always legal, Justice: stronger Kings, General: gold on 3s). They **use** turn actions (Veto, Filibuster, Tax, Rally, Forge, …) and role cards (Uprising, Just Say No, …). **AIs only buy upgrades during the shop round**, after the desk opens, spending their own gold on 0–1 item from a 2-offer personal desk. They do not shop before the desk is open and they do not buy mid-round. Purchases and uses land in the round log so you can see them.

## Personal rank effects

Shop **rank binds** (or an AI specialty) attach an effect to one rank for **one seat**:

- `gold_play` — +1 gold when that seat plays the rank
- `power` — +1 follow power when that seat plays the rank (your 5s can equal a 6; theirs do not)
- `always_legal` — that rank is always a legal follow of the matching count for that seat (Ace Privilege can follow a bomb)

When a card’s **effective follow value is higher than its printed rank**, the face keeps the **printed rank in red/black** and adds the true value **in blue** (`5 → 6`, with a blue badge). Unbuffed cards are unchanged. **That blue number is the trick rank** if the card is played — other seats must follow the effective value, not the printed face. This fires for seat-scoped `power` binds (Strong Fives: 5 + blue 6; Ace Authority: A + blue 2; Kingmaker: K + blue A; Heavier Bombs: 2 + blue 2+), **Incumbent** / **Rally** promotions (3 + blue 4), and **Forge Bomb** (printed origin + blue 2). `gold_play` and `always_legal` do not recolor — they are not a higher value. Playing a `gold_play` rank pops a **gold coin** (`$+1`) over the trick.

A large hand **reflows** (tighter overlap, then a second row, then scale) so cards stay on-screen on phone and desktop.

## Run it

Godot 4.3. Open `project.godot`, press Play.

```bash
godot --headless --import
godot --headless --script tests/logic_test.gd   # ALL TESTS PASSED
cd docs && python3 -m http.server 8000          # web export
```

The web export is the no-threads template (plain HTTP, no COOP/COEP). GitHub Pages: Settings → Pages → Branch `main`, folder `/docs` → Save.
