# Changelog

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
