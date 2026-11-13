# VoidBars - Action Bars & Keybinds

**Works on:** WoW Midnight · WoW Forever

**Clean, fast action bars that take over Blizzard's in your current layout, plus bars that fill themselves with your consumables, travel, professions and pets.**

VoidBars replaces Blizzard's eight action bars with flat, readable buttons and copies where your bars already are, so nothing moves on day one. It adds a pet bar, stance bar and world-marker bar, smart bars that fill themselves from your bags, spellbook and stable, a hover-and-press keybind mode, and saved profiles you can switch between. Want a fresh start? One click sets up a 1-7 + Shift 1-7 combat block and puts the right spells for your spec on it.

---

## Features

### Action bars
- **Takes over your current layout** — the first time you log in, VoidBars copies where Blizzard's bars are (Edit Mode included), so your buttons and keys stay where they were
- **Readable buttons** — cooldown swipes and numbers, charges, item counts, keybinds and macro names, all working with Midnight's combat rules
- **Red when out of range, blue when out of resource** (Runic Power, Insanity, mana, ...)
- **Proc glow** when a spell lights up
- **Forms and stances page the main bar** — cat, bear, stealth and so on get their own keys 1-12, like Blizzard's; rogues page on real Stealth and Vanish only, so Shadow Dance never swaps your keys mid-fight
- **Vehicles, skyriding and quest bars** — the main bar pages like Blizzard's; when the game shows its own vehicle or quest bar, VoidBars steps aside until you leave, and a leave-vehicle button shows when you can exit
- **Pet bar and stance bar** in the same style, pinned where you put them (right-click a pet ability to toggle autocast)
- **World-marker bar** — place and clear all 8 world markers, plus a button that asks your group leader for assist

### Layout
- **Move any bar** — unlock, drag, lock
- **Per-bar settings** — on/off, number of buttons, buttons per row, size, spacing, and when it shows: always, in combat only, out of combat only, or your own macro conditions
- **Grows from the middle** — changing a bar's size keeps its inner edge, so bars left of center grow left and bars right of center grow right
- **Fade out of combat** — per bar, with your own opacity (0% = hidden until you mouse over it); bars come back in combat and on mouseover
- **Separate layout for each specialization** (optional) — each spec remembers its own bar positions, sizes and which bars show
- **Copy another character's layout** — make an alt look like your main in one click (positions and bars, not spells)

### Smart bars
These fill themselves and never use one of your action slots:
- **Consumables** — one button per job, best version you carry: healthstone, health potion, combat potion, flask or phial, food, feast, weapon oil or stone, augment rune, vantus rune (raids). Buff food is picked by what the buff does for you: your main stat first, a fishing or swim-speed buff last. It also adds plain food and water (mage food too) for topping off between pulls. On WoW Forever, where most cooked food makes you well fed, plain food keeps its own spot: raw fish that heal count, and when you carry none, the spot shows the vendor food for your level and a click walks you to the nearest vendor that sells it (with VoidGPS). It also holds your class's group buff (Mark of the Wild, Arcane Intellect, ...) and a recovery spell you know.
- **Travel** — hearthstone, class teleports, Switch Flight Style and a random mount, plus anything you drag on: mounts, toys, items, spells, macros
- **Professions** — every ability of each profession you have (crafting windows, Disenchant, Cooking Fire, Fishing, ...) and your profession gear
- **Pets** (pet classes) — hunters get a Call Pet button for each stable slot that holds a pet, plus Revive, Mend and Dismiss Pet; warlocks get their demon summons; Frost mages their Water Elemental. Separate from Blizzard's pet bar, which keeps your pet's own abilities
- **Random** — an empty bar for anything you like: drag on mounts, toys, items, spells or macros (macros are kept by name, so a renamed or deleted macro drops off the bar)
- **Every bar moves** — unlock in the options, drag any bar where you want it, and set its size and buttons per row
- **Shift + right-click** hides a button from a smart bar for good; "Show all again" in the options brings the automatic ones back (a button you dragged on yourself is removed, so drag it back to restore it)

### Keys and setup
- **Keybind mode** — hover a button, press a key. Shift, Ctrl, Alt, mouse buttons and the wheel all work; Backspace clears; Esc finishes. Uses Blizzard's own keybindings, so your keys survive turning VoidBars off.
- **One-click combat layout** — keys 1-7 on top and Shift 1-7 below at the bottom center, with Consumables, Professions and Travel around it. Built for a thumb grid (side-button mice), and it works fine on a keyboard too. Any of those 14 keys that has nothing bound gets bound for you.
- **Suggested spells** — fills those 14 keys from your spells and talents: interrupt on 3, damage on the top row (healers: your main heals), then defensives, heals, stuns, escapes and movement on the Shift row. Damage is ranked by what actually does the most damage for you (read from Blizzard's damage meter after each fight). Shows the plan first, and offers an update when your talents change.
- **Profiles** — save every button, the layout and your action-bar keys under a name, and restore them any time. VoidBars saves your original bars as "Default", your setup before the first preset as "Before preset", and your bars before each suggestion as "Before suggested", so you can always go back. (Smart-bar contents aren't part of a profile.)

---

## Slash Commands

| Command | What it does |
|---|---|
| `/vbars` | Open the VoidBars options |
| `/vbars move` | Unlock the bars so you can drag them (`/vbars lock` to finish) |
| `/vbars bar` | Open the per-bar settings window |
| `/vbars bind` | Keybind mode: hover a button and press a key |
| `/vbars suggest` | Show suggested spells for keys 1-7 and Shift 1-7 |
| `/vbars preset naga7` | Apply the 1-7 + Shift 1-7 combat layout |
| `/vbars save <name>` | Save your bars as a profile |
| `/vbars restore <name>` | Restore a saved profile |
| `/vbars import` | Copy Blizzard's current bar layout again |
| `/vm` | Show or hide the world-marker bar |

---

## Getting Started

1. Install with the CurseForge app, or copy the `VoidBars` folder into `World of Warcraft/_retail_/Interface/AddOns/` (WoW Forever: `_forever_/Interface/AddOns/`).
2. Restart WoW or `/reload`.
3. VoidBars copies your current bars and asks if you'd like the clean layout instead. Pick **Keep my bars** to stay as you are, or **Use the clean layout** for the 1-7 + Shift 1-7 block with suggested spells.
4. Type `/vbars` (or Esc → Options → AddOns → VoidBars) for everything else.

---

## Good to Know

- **Settings are per character.** Each character keeps its own VoidBars settings, and a new character starts with the settings of the one you played last, so nothing resets when you update. Right-click the Void hub icon by your minimap and pick **Copy settings from...** to take another character's settings for one Void addon or all of them. That now includes the look (keybinds shown, colors, glow, fade opacity).
- **Bars only move, change size or swap spells out of combat** — that's the game's rule for action bars. Settings changed mid-fight are applied as soon as combat ends; presets, profiles and suggestions just ask you to try again after combat.
- **Logging in or reloading mid-fight** — Blizzard's bars show until combat ends (a pet that's still fighting counts), then VoidBars takes over. It tells you so in chat.
- **After every fight** VoidBars checks its bars are still in charge and puts them back if something in the fight knocked them loose.
- **Your spells are saved by the game, per spec** — VoidBars arranges the bars around them. Profiles snapshot the spells too, so restoring one puts every button back.
- **Hiding Blizzard's bars** (on by default) takes effect after a `/reload` when you change it.
- **Made for English game clients.** Suggested spells and the smart bars (which potions, food and profession tools go where) read English spell names and tooltips. On other languages the bars work normally, but suggestions and smart-bar sorting may miss things, so arrange those yourself.
- **Damage ranking needs the game's damage meter** (Options → Advanced → Damage Meter). Without it, suggestions fall back to cooldown order.
- Layout, per-bar settings, and what you've added to or hidden from the Travel, Professions and Random bars are saved per character too.

---

## Compatibility

- **WoW Midnight** 12.1.5 (Season 2)
- **WoW Forever**
- Standalone — nothing else to install
- Turn off any other action bar addon first, so two addons aren't fighting over the same bars

---

*Part of the Void addon family by Vede · MIT licensed · [Source & bug reports](https://github.com/bughatti/voidbars) · [All Void addons](https://www.curseforge.com/members/bughatti/projects) · free M+ & raid player lookups at [voidscout.io](https://voidscout.io) · more at [tinkerline.io](https://tinkerline.io/addons/voidbars/) · [Discord](https://discord.gg/7ZHmx7zMDh)*
