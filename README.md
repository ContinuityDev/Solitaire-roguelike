# Solitaire Roguelike

This here is a very small game with the purpose of helping me (a lowly developer ik) decide whether or not to actually follow through with this idea, whether it is a good one or just genuinely trash so I made a small game with ai to see if its worth investing time into




> **▶ Play in your browser:** https://continuitydev.github.io/Solitaire-roguelike/
>
> _One-time setup still needed (takes ~30 seconds): repo **Settings → Pages → Branch: `main`, folder: `/docs` → Save**. The link above goes live a few minutes after that — everything it needs is already pushed in `docs/`._

A Balatro-like roguelike built on Klondike solitaire, in **Godot 4.x** (developed against 4.3, no external assets — every card is drawn with code).

You start a run with a tiny deck of only **Aces through 5s**. Win blinds, pick upgrades in the shop, and escalate your deck through the court — Jacks, Queens, Kings — and then *past* them: **Emperors, Titans, Seraphs, Deities**, and beyond.

## The magician theme

The whole show is stage magic now — Balatro's circus energy, but top hats instead of clowns. Everything is still drawn in code (no external assets): a midnight-purple velvet stage with gold trim, cream card faces with gold/purple detailing, card backs bearing a top-hat, wand and sparkles, and grand-illusionist colouring (lavender tint, purple + gold, sparkles) for ranks past King. Grand Illusions (boss tricks) announce themselves in red.

### Terminology mapping (old -> stage)

| Was | Now |
|---|---|
| Ante | **Act** |
| Blind | **Trick** |
| Boss Blind | **Grand Illusion** (Sawed in Half / No Safety Net / Death-Defying Encore) |
| Shop | **The Prop Table** |
| Relic / Upgrade | **Prop** (collected in your prop case) |
| Chips / Score / points | **Applause** |
| Mult | **Flair** |
| Combo (chain) | **Encore** |
| Foundation pile | **Finale pile** (in messages; the solitaire term survives in code) |
| Enhancement | **Enchantment** (Gilded / Sparkle / Wild / Rabbit's Foot / Crystal) |
| Complete Blind button | **Take a Bow** |
| Win / lose | "The crowd goes wild!" / "The trick falls flat..." |

Internal code names (`ante`, `combo_chain`, upgrade ids, `kind: "relic"`, ...) are deliberately unchanged — only player-facing text, names and descriptions were renamed, so saves/logic/tests are unaffected.

## Play it

- **Hosted web version:** https://continuitydev.github.io/Solitaire-roguelike/ — served from the `docs/` folder once GitHub Pages is enabled (see *Hosting* below).
- **Local web version (no Godot needed):**

  ```bash
  cd docs
  python3 -m http.server 8000
  # open http://localhost:8000  (or http://<this-machine-ip>:8000 from a phone on the same network)
  ```

  The export must be served over HTTP — opening `docs/index.html` via `file://` will not work. It is the Godot **no-threads** web template (`variant/thread_support=false` in `export_presets.cfg`), so a plain static server is fine and no COOP/COEP headers are required.

## Hosting (GitHub Pages)

The web export is committed under `docs/` so GitHub Pages can serve it with no build step:

1. This repo is already pushed to GitHub (`main` contains `project.godot` and `docs/index.html`).
2. Repo **Settings → Pages → Build and deployment → Source: Deploy from a branch → Branch: `main`, folder: `/docs`** → Save.
3. The game appears at **https://continuitydev.github.io/Solitaire-roguelike/** (GitHub shows the exact URL on that Settings page once deployed, usually within a few minutes).

`docs/.nojekyll` is included so Pages serves the Godot files (including the `.wasm`/`.pck`) as-is.

## Repository layout

```
project.godot          # Godot 4.3 project (main scene: scenes/main.tscn)
scenes/  scripts/      # game code (see Project structure below)
tests/logic_test.gd    # headless logic smoke test
docs/                  # committed Godot web export — this is what gets hosted
export_presets.cfg     # Web (no-threads) + Android export presets
```

To rebuild the web export after changing the game, re-export the **Web** preset in Godot (it writes to `../web-build/` relative to the project; copy the result over `docs/`, keeping `docs/.nojekyll`), then commit and push — Pages republishes automatically.

## How to open and run

1. Install [Godot 4.x](https://godotengine.org/download) (4.3 or newer recommended).
2. Open Godot → **Import** → select this folder's `project.godot` → **Import & Edit**.
3. Press **▶ Play** (F5). The main scene is `scenes/main.tscn`.

Headless validation (no editor needed):

```bash
godot --headless --import            # import / script check
godot --headless --script tests/logic_test.gd   # logic smoke test: prints ALL TESTS PASSED
```

## Controls

| Action | Input |
|---|---|
| Draw from stock / recycle waste | Click the stock (top-left) |
| Select a card or stack | Click it |
| Move selected card(s) | Click the destination pile (tableau column or foundation) |
| Send top card to foundation | **Double-click** the card |
| Deselect | Click the selected card again |
| Finish a trick | Click **Take a Bow** once your applause meets the target |
| Hint / Restart Run | Buttons in the top bar |

Click-to-move is used instead of drag-and-drop: on a tableau column, clicking any face-up card selects that card *and every card on top of it* as a stack.

## How a run works

- **Acts & tricks:** A run is 8 acts. Each act is one trick with an applause target (shown top-left; it grows roughly as `240 × act^1.45`).
- **Winning a round:** Clear the whole board onto the finale piles (big clear bonus), *or* reach the applause target and press **Take a Bow**. You can keep playing after hitting the target to farm applause — but if you run out of moves, you lose.
- **Losing:** If no legal moves remain (stock empty, no redeals, nothing placeable) and the round isn't won, the run ends. **Restart Run** starts over at A–5.
- **Shop:** After each trick, visit **The Prop Table** and pick **1 of 3** props (or skip). One slot is (almost) always **Raise the Curtain Cast**, which grows your deck.
- **Endless:** Beat Act 8 and you can continue into endless acts (endless encores) with ever-higher targets and ranks.

### Prototype solitaire rules (deliberate simplifications)

- Tableau builds **descending in alternating colours**, at any rank.
- An **empty tableau column accepts any card/stack** (not just Kings) — this keeps the small starter deck playable.
- Stock draws **1** card; you get **1 waste redeal** per round by default.
- Foundations build **ascending by suit from Ace**, up to whatever your deck's current max rank is.

Table size scales with your deck: a 20-card starter deck deals 4 tableau columns, growing to the familiar 7 columns at a full 52-card deck.

## Scoring

- **To a finale pile:** the card's applause value × current Flair. Applause = `rank × 10`, plus an ascension bonus past King (`+(rank − 13) × 15`), so an Emperor is worth more than a King and a Deity much more.
- **Reveal a tableau card:** 15 applause. **Move between piles:** 5 applause.
- **Streaks:** consecutive finale plays build a streak; every 4 streak adds **+0.5 Flair**. Anything that isn't a finale play (or a reveal) resets the streak. Numbers snowball Balatro-style as Flair, streak, and card values grow together.

## The rank escalation system

Ranks are **plain integers** — there is no enum to exhaust (`scripts/rank.gd`):

| Rank | Name | Short |
|---:|---|---|
| 1 | Ace | A |
| 2–10 | face value | 2–10 |
| 11 | Jack | J |
| 12 | Queen | Q |
| 13 | King | K |
| 14 | Emperor | EMP |
| 15 | Empress | EMS |
| 16 | Titan | TTN |
| 17 | Leviathan | LEV |
| 18 | Seraph | SER |
| 19 | Sovereign | SOV |
| 20 | Deity | GOD |
| 21+ | Transcendent *n* (generated) | the number itself |

- A run starts at max rank **5** (20 cards). Each **Raise the Curtain Cast** prop adds the next 2 ranks (8 cards). Picking it every time, you'll hold Kings after Ante 3 and your first **Emperors (14)** after Ante 4 — ascended cards are reachable in a normal prototype run, and their borders turn purple on the table.
- Foundations simply keep ascending: …, Q, K, Emperor, Empress, … — nothing caps at King.
- **Extending it:** add an entry to `NAMES`/`SHORT` in `scripts/rank.gd` to name a new tier. Only `RunManager.PROTOTYPE_MAX_RANK` (= 20) gates how far the *shop* offers; raise that one constant to let runs escalate further.

## Props (upgrades / relics)

Defined data-driven in `scripts/upgrade_db.gd` (`UpgradeDB.UPGRADES`). Included: **White Gloves** (+1 Flair), **House Tithe** (Flair per finale card), **Second Wind (Vanish & Return)** (+1 redeal), **Sprouting Wand** (Aces/2s wild on tableau), **Metronome** (+10 applause per move), **Wider Stage** (+1 tableau column), **Sleight Specs** (peek top 3 of stock), **Grand Showman** (J-or-higher finale plays score double), **Quick-Change Coat** (bigger reveal bonus), **Stardust Oil** (faster streak Flair) — plus the repeatable **Raise the Curtain Cast** rank reward.

**Adding a prop:** append one dictionary to `UPGRADES` (`id`, `name`, `icon`, `desc`, `unique`, `kind`), then read the id where its effect belongs: scoring in `RunManager.score_for_event()`, placement rules in `SolitaireBoard`, round setup in `Main._start_round()`. No shop code changes needed — it will start appearing as an offer automatically.

**Adding cards/ranks:** nothing to add per-card — the deck is generated as *4 suits × ranks 1..max_rank* in `scripts/deck.gd`. New named ranks only need the `rank.gd` table entries described above.

## Project structure

```
project.godot
scenes/main.tscn        # single main scene (UI is built in code)
scripts/
  main.gd               # UI, input (click-to-move), round/shop flow
  card_view.gd          # one card, drawn with code — no textures
  solitaire_board.gd    # pure Klondike logic: piles, legal moves, win check
  card_data.gd          # one card: integer rank + suit
  deck.gd               # deck generation for any max rank
  rank.gd               # the extensible rank system (names, chips, tiers)
  run_manager.gd        # ante/target/score/Mult/streak, run state
  upgrade_db.gd         # data-driven upgrade definitions + shop generation
  shop.gd               # pick-1-of-3 reward screen
tests/logic_test.gd     # headless logic smoke test
```

## Known limitations / ideas for next steps

- Click-to-move only (no drag), waste shows only its top card, stock draws 1 (no draw-3 mode yet).
- One blind per ante (no Small/Big/Boss choice, no gold or priced shop — rewards are free picks).
- Seeded shuffling exists in the logic layer, but there's no run-seed UI or save/persistence yet.
- Card faces for ascended ranks are named labels rather than unique art — a natural place for generated card art later.

## Mobile & web (added in the phone/web pass)

- **Touch:** every interaction is tap-based (tap card → tap destination, tap stock to draw, double-tap a card to send it to its foundation). No hover, drag, or right-click is used anywhere. `project.godot` enables emulate-mouse-from-touch, and `CardView` also handles raw `InputEventScreenTouch` with de-duplication and manual double-tap detection (touch double-click reporting varies by browser).
- **Responsive layout:** the project base size is a portrait phone (390×844) with `canvas_items` stretch + `expand` aspect (desktop launches at 1280×800 via the window-size override). `Main._apply_responsive_layout()` sizes cards from the live viewport: card width is driven by the widest row, clamped to ≈38–92 px (≈52 px wide at 390 px, a comfortable tap target), the HUD switches to compact 2-column text and the buttons wrap on narrow screens, and shop buttons shrink to phone width. Suits are drawn from circles/polygons rather than font glyphs, which are missing in web exports.
- **Exports:** `export_presets.cfg` contains **Web** and **Android** presets. The Web preset uses the no-threads template variant, so a plain static server works (below). The Android preset (package placeholder `com.hayden.solitaire.roguelike`, arm64, sensor orientation, immersive) is configured but **no APK was built in this environment — there is no Android SDK/keystore here**; build it from a machine with the Android SDK installed via Godot's Android export.

### Play the web build

The exported game lives in `docs/` in this repo. It must be served over HTTP — `file://` will not work:

```bash
cd docs
python3 -m http.server 8000
# then open http://localhost:8000 on this machine,
# or http://<this-machine-ip>:8000 on a phone on the same network
```

On a phone, tap cards to select/move and double-tap to send a card to its foundation.

## Rank polish, encores & enchantments (feature pass 2)

### Rank levels and the encore

Every rank has a **level**, starting at Lv1 (tracked per rank in `RunManager.rank_levels`, shown as the **Ranks:** line under the HUD, and as gold pips + an `Lv` badge on cards of upgraded ranks). Shop rewards can raise levels (see below).

Playing a card to a foundation scores:

```
base_chips  = chip_value(rank)              # rank*10, +15 per rank past King
            + (rank_level - 1) * 10
            + enchantment applause        # Gilded +30, Crystal +20, Rabbit's Foot proc +50
            + prop applause               # charms +15, Gold-Leaf Press +20, ...
encore_bonus = combo_chain * rank_level * 5  # x2 with Echoing Hall (internal var: combo_chain)
applause    = round((base_chips + encore_bonus) * Flair)
```

**Encore:** consecutive finale plays of the *same rank* build the chain (`combo_chain` internally). The HUD shows e.g. `Encore: 5 x3 (Lv3) +45 applause`. A finale play of a different rank **breaks** the chain (announced in the message bar if it was x2 or more) and starts a new one; tableau moves do not break it. **Crystal** cards add 2 to the chain. Example snowball: four Lv3 Kings in a row score encore bonuses of 15/30/45/60 applause on top of 150 base applause each, before Flair.

### Enchantments (per card, permanent for the run)

Granted by the Prop Table's *Enchantment: Random Charm* reward to a random deck card; stored in `RunManager.enhancement_assignments` and applied to every round's deck. Shown as a coloured border + badge on the card (`scripts/enhancement_db.gd`):

| Enchantment | Badge | Effect |
|---|---|---|
| Gilded | `+C` gold | +30 applause on finale play |
| Sparkle | `+M` pink | +0.5 Flair on finale play |
| Wild | `W` green | Counts as any colour for tableau building |
| Rabbit's Foot | `L` green | 25% on finale play: +50 applause and +0.5 Flair |
| Crystal | `P2` cyan | +20 applause; counts double for the encore chain |

### New shop content

The Prop Table now always shows a spread: a deck/rank slot (**Raise the Curtain Cast**, or **Polish: \<rank\>** at the rank cap), an **enchantment slot**, and a mixed slot. New items: **Polish: \<rank\>** (one rank +1 level), **Fast Study** (a low rank +2), **Court Rehearsal** (J/Q/K +1 each), **Enchantment: Random Charm**, and 9 more props (19 total): Safety Line (encore survives one off-rank play), Echoing Hall (encore bonus x2), Gold-Leaf Press (+20 applause for enchanted cards), Crystal Lens (Crystal also +0.5 Flair), Hearts/Spades Charms (+15 applause for that suit), Maestro Mentor (rank polish grants +1 extra level), Stagehand Tutor (moves no longer reset streak), Magic Bean Dust (Wild cards +15 applause).

### Grand Illusions (boss tricks)

Every 3rd act is a **Grand Illusion** (shown in red in the HUD), cycling three stage-villain twists: **Sawed in Half** (Act 3: Hearts finale plays earn half applause), **No Safety Net** (Act 6: no redeals), **Death-Defying Encore** (Act 9, 12, ...: encore bonus only pays at chain 3+).


