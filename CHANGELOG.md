# Changelog

## [1.1.0] — 2026-11-13

- **WoW Forever: plain food keeps its own spot on the consumables bar.** On Forever most cooked food makes you well fed (Mithril Head Trout: +20 attack power), and that's the food you eat once for the buff, not between pulls. The bar now keeps a separate spot for plain food:
  - **Raw fish that heal count as plain food** (Raw Sunscale Salmon, Raw Rockscale Cod...). The game files them as cooking materials, so the bar used to skip them.
  - **Carrying none?** The spot shows the vendor food for your level, greyed out (at 35: Cured Ham Steak, Soft Banana Bread or Fine Aged Cheddar, 1,338 health). Click it for the way to the nearest vendor that sells it (with VoidGPS). Casters get the same for water.

## [1.0.13] — 2026-11-12

- **Fixed: a side of a box could be missing**, e.g. the right line of the recipes box and its buttons when the game window is an odd number of pixels wide. Every Void box now always shows all four border lines.

## [1.0.12] — 2026-11-12

- **Bandages on the consumables bar.** The best bandage you can use (your First Aid skill is high enough for it) gets a button right after the health potion.
- **The bar settings window can be dragged and stays where you put it**, even after a restart.
- **Void hub button:** left-click opens one panel with all your Void addons by name, grouped, each with its own on/off switches (it replaces the ring of icons), with a background slider. The hub's info window now stays where you put it.

## [1.0.11] — 2026-11-10

### Fixed (WoW Forever)
- **Key 3 interrupt** with Classic spells (Earth Shock, Pummel / Shield Bash, Kick, Counterspell ...), and tank / healer suggestions follow your group role or stance.

## [1.0.10] — 2026-11-09

- **Fixed: box borders missing a side.** Depending on where a window sat on screen, its left, right or bottom line could vanish. Borders are now exactly one screen pixel and can't round away.

## [1.0.9] — 2026-11-07

- **Fixed: your bars vanished after a /reload in the middle of a fight** (Blizzard's bar showed until the fight ended). The game allows setting up bars while the UI loads, even mid-fight, and only locks that down right after the loading screen. VoidBars waited one extra second before taking over and landed in that lock. It now takes over at once (the wait is only needed the first time, when it copies Blizzard's layout). Tested with two reloads in a fight: the bars stayed.
- **Fixed: the key-routing setup is safe when the UI loads under combat lockdown.**

## [1.0.8] — 2026-11-07

### Fixed
- **WoW Forever: the food button picked the fishing fish again.** Forever's spec data is a placeholder that reports every character as an intellect caster, so attack power food stopped counting as your main stat. On Forever, VoidBars now goes by your class. On retail, a spec answer your class can't have is ignored.

## [1.0.7] — 2026-11-06

### Fixed
- **The food button picks the useful buff food.** It went by item level and stack size, so a fishing-skill fish could take the button over an attack power one. Buff food is now ranked by what the buff does for your character: your main stat (strength, agility or intellect, from your spec or class) first, then other combat stats, then stamina or spirit, and fishing or swim-speed buffs last.

### Added
- **WoW Forever** support.

## [1.0.6] — 2026-11-03

### Added
- **Macros on the Random, Travel and Professions bars.** Drag a macro from the macro window onto the bar. It shows the macro's icon, and for a `#showtooltip` macro the cooldown and tooltip of the spell or item it would cast. Macros are kept by name, so a renamed or deleted macro drops off the bar.

## [1.0.5] — 2026-11-02

### Changed
- **Settings are per character.** Each character keeps its own VoidBars settings, and a new character starts with the settings of the one you played last, so nothing resets when you update. Right-click the Void hub icon by your minimap and pick **Copy settings from...** to take another character's settings for one Void addon or all of them. That now includes the look (keybinds shown, colors, glow, fade opacity).

## [1.0.4] — 2026-11-02

### Changed
- **Each character keeps its own smart bars.** Mounts, toys and items you drag onto the Travel, Professions or Random bar, and buttons you Shift+right-click away, now stay with that character instead of showing on all of them. Nothing disappears when you update: each character starts with what it showed before, so remove anything that belonged to another character once and it stays gone.

## [1.0.3] — 2026-11-02

### Changed
- **Void hub icon:** your Void addons now pop out in rings around the hub icon, fanning away from the minimap, instead of one long column. The pop-up also works while another addon moves or fades the minimap.

## [1.0.2] — 2026-11-01

### Changed
- **Void hub icon:** the list of Void addons is up to date (adds VoidGather and VoidSweep, refreshed descriptions).

## [1.0.1] — 2026-10-30
- The Consumables bar keeps plain food and water at max level, not only while leveling, so you can top off between pulls without spending buff food. Mage food (Conjured Mana Bun) counts as well. They sit at the end of the bar.

## [1.0.0] — 2026-10-30

First public release.

### Action bars
- Takes over Blizzard's 8 action bars and copies your current layout (Edit Mode included) on first login.
- Cooldown swipes and numbers, charges, item counts, keybinds and macro names that work with Midnight's combat rules.
- Red when out of range, blue when out of resource, proc glow.
- The main bar pages for forms, stances and stealth (rogues: real Stealth and Vanish only, never Shadow Dance), vehicles and skyriding. Steps aside while the game shows its own vehicle or quest bar. Has its own leave-vehicle button.
- Pet bar, stance bar and a world-marker bar (`/vm`).

### Layout
- Move mode, per-bar settings (buttons, per row, size, spacing, when it shows) and fade out of combat with your own opacity.
- Optional separate layout for each specialization.
- Copy another character's layout.

### Smart bars
- Consumables, Travel and Professions bars that fill themselves from your bags and spellbook. Shift + right-click hides a button.
- Pets bar for pet classes: hunter Call Pet per stable slot, Revive / Mend / Dismiss Pet; warlock demon summons; Frost mage Water Elemental. It starts above the Travel bar.
- Random bar: an empty bar for anything you drag onto it (mounts, toys, items, spells). It starts under the Travel bar.

### Keys and setup
- Keybind mode: hover a button, press a key.
- One-click 1-7 + Shift 1-7 combat layout, offered on first login.
- Suggested spells for those 14 keys, ranked by your own damage from Blizzard's damage meter.
- Profiles: save and restore every button, the layout and your keys.

### Combat
- Loaded mid-fight, VoidBars says it's waiting for combat to end (including a pet still fighting) instead of silently showing Blizzard's bars.
- After every fight it checks its bars are in charge and puts them back if something knocked them loose.
- The options window opens when combat ends if you click for it mid-fight.
