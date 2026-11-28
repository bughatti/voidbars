----------------------------------------------------------------------
-- VoidBars — suggested layout for the 14-key combat block (naga7).
--
-- Key 1 is VoidSequencer, which casts the whole damage rotation (and its
-- held-modifier spells). So the other 13 keys get what it DOESN'T press:
-- interrupt (always key 3), then stuns, heals, defensives, escapes, mobility
-- and group utility, in each class's order below. Only spells you actually
-- have count (talents + level), and anything VoidSequencer casts is skipped
-- and also cleared off your shown bars -- one press, one place.
--
-- Talented active abilities that aren't in a class list (e.g. a new talent)
-- are added too, so nothing you took gets lost. Spells are compared by
-- base spell id, so a talent override and its base never take two keys.
-- The class lists are English spell names (enUS client).
-- Your bars are saved as profile "Before suggested" first.
--
-- Order (2026-10-24): damage the rotation doesn't cast gets the best keys (2, 4-7),
-- ranked by YOUR damage per spell (SpellDamage.lua, Blizzard's damage meter), unmeasured
-- ones by shortest cooldown; then defensives / heals, crowd control, movement, utility
-- (class-list order inside each group). Spells already on one of the 14 keys keep that
-- key; new ones fill the free keys. "Re-sort all" ignores where spells sit now.
--
-- Without VoidSequencer (2026-10-28) VoidBars stands alone: key 1 is a normal key, your
-- spellbook's damage spells join the list (the rotation the class lists leave out), the
-- top row 1-7 gets damage and the Shift row the rest. The fixed spec layouts need
-- VoidSequencer's macros, so they're skipped.
----------------------------------------------------------------------
local _, VB = ...

local INTERRUPT_KEY = 3

-- Per class: interrupt candidates (first one you know wins), taunts (tanks only, go
-- right after the interrupt), then everything else most-important first. The first
-- five fill keys 2,4,5,6,7; the rest Shift+1..7. Names you don't know are skipped.
local CLASS = {
    ROGUE = {
        interrupt = { "Kick" },
        -- Shadowstep = Subtlety's gap closer (Grappling Hook is Outlaw's). Cheap Shot and
        -- Sap are left out: stealth-only openers that would push Shroud (M+ skips) off the
        -- 14 keys, since crowd control ranks above utility.
        list = { "Kidney Shot", "Crimson Vial", "Feint", "Evasion", "Vanish",
            "Stealth", "Sprint", "Shadowstep", "Grappling Hook", "Cloak of Shadows", "Blind", "Gouge",
            "Tricks of the Trade", "Shroud of Concealment", "Shiv", "Distract" },
    },
    DEATHKNIGHT = {
        interrupt = { "Mind Freeze" }, taunt = { "Dark Command" },
        list = { "Death Grip", "Death Strike", "Anti-Magic Shell", "Asphyxiate", "Death's Advance",
            "Icebound Fortitude", "Anti-Magic Zone", "Lichborne", "Raise Ally", "Chains of Ice",
            "Blinding Sleet", "Gorefiend's Grasp", "Vampiric Blood", "Wraith Walk", "Control Undead", "Path of Frost" },
    },
    DEMONHUNTER = {
        interrupt = { "Disrupt" }, taunt = { "Torment" },
        list = { "Chaos Nova", "Blur", "Fel Rush", "Vengeful Retreat", "Darkness", "Imprison",
            "Sigil of Misery", "Sigil of Silence", "Fiery Brand", "Demon Spikes", "Infernal Strike",
            "Netherwalk", "Consume Magic", "Spectral Sight" },
    },
    DRUID = {
        interrupt = { "Skull Bash", "Solar Beam" }, taunt = { "Growl" },
        list = { "Barkskin", "Frenzied Regeneration", "Regrowth", "Survival Instincts", "Dash",
            "Mighty Bash", "Incapacitating Roar", "Typhoon", "Ursol's Vortex", "Stampeding Roar",
            "Wild Charge", "Renewal", "Remove Corruption", "Nature's Cure", "Soothe", "Rebirth",
            "Innervate", "Cyclone", "Entangling Roots" },
    },
    EVOKER = {
        interrupt = { "Quell" },
        list = { "Obsidian Scales", "Hover", "Renewing Blaze", "Verdant Embrace", "Tail Swipe",
            "Wing Buffet", "Landslide", "Sleep Walk", "Cauterizing Flame", "Expunge", "Rescue",
            "Time Spiral", "Zephyr", "Oppressing Roar", "Source of Magic" },
    },
    HUNTER = {
        interrupt = { "Counter Shot", "Muzzle" },
        list = { "Exhilaration", "Disengage", "Aspect of the Turtle", "Freezing Trap", "Intimidation",
            "Binding Shot", "Feign Death", "Misdirection", "Survival of the Fittest", "Tar Trap",
            "Tranquilizing Shot", "Aspect of the Cheetah", "Concussive Shot" },
    },
    MAGE = {
        interrupt = { "Counterspell" },
        list = { "Blink", "Shimmer", "Ice Block", "Ice Barrier", "Blazing Barrier", "Prismatic Barrier",
            "Frost Nova", "Mirror Image", "Alter Time", "Greater Invisibility", "Invisibility",
            "Dragon's Breath", "Blast Wave", "Polymorph", "Ring of Frost", "Spellsteal",
            "Remove Curse", "Slow", "Mass Barrier" },
    },
    MONK = {
        interrupt = { "Spear Hand Strike" }, taunt = { "Provoke" },
        list = { "Leg Sweep", "Fortifying Brew", "Roll", "Chi Torpedo", "Expel Harm", "Vivify",
            "Touch of Karma", "Diffuse Magic", "Dampen Harm", "Paralysis", "Tiger's Lust",
            "Transcendence", "Transcendence: Transfer", "Ring of Peace", "Detox", "Life Cocoon" },
    },
    PALADIN = {
        interrupt = { "Rebuke" }, taunt = { "Hand of Reckoning" },
        list = { "Hammer of Justice", "Word of Glory", "Divine Shield", "Divine Steed",
            "Divine Protection", "Shield of Vengeance", "Ardent Defender", "Guardian of Ancient Kings",
            "Blessing of Freedom", "Blessing of Protection", "Lay on Hands", "Blessing of Sacrifice",
            "Cleanse Toxins", "Cleanse", "Blinding Light", "Repentance", "Intercession", "Turn Evil" },
    },
    PRIEST = {
        interrupt = { "Silence" },
        list = { "Desperate Prayer", "Power Word: Shield", "Fade", "Dispersion", "Psychic Scream",
            "Vampiric Embrace", "Angelic Feather", "Flash Heal", "Mass Dispel", "Purify Disease",
            "Purify", "Dispel Magic", "Leap of Faith", "Psychic Horror", "Mind Soothe",
            "Shackle Undead", "Mind Control" },
    },
    SHAMAN = {
        interrupt = { "Wind Shear" },
        list = { "Astral Shift", "Healing Surge", "Capacitor Totem", "Spirit Walk", "Gust of Wind",
            "Ghost Wolf", "Earth Elemental", "Thunderstorm", "Hex", "Tremor Totem", "Earthbind Totem",
            "Wind Rush Totem", "Poison Cleansing Totem", "Cleanse Spirit", "Purify Spirit", "Purge",
            "Spiritwalker's Grace" },
    },
    WARLOCK = {
        interrupt = { "Spell Lock", "Axe Toss" },
        list = { "Unending Resolve", "Mortal Coil", "Dark Pact", "Shadowfury", "Demonic Circle: Teleport",
            "Fear", "Howl of Terror", "Demonic Gateway", "Burning Rush", "Demonic Circle",
            "Create Healthstone", "Soulstone", "Banish", "Health Funnel" },
    },
    WARRIOR = {
        interrupt = { "Pummel" }, taunt = { "Taunt" },
        list = { "Impending Victory", "Victory Rush", "Storm Bolt", "Shockwave", "Charge", "Heroic Leap",
            "Rallying Cry", "Die by the Sword", "Enraged Regeneration", "Spell Reflection",
            "Shield Wall", "Last Stand", "Intimidating Shout", "Intervene", "Berserker Rage",
            "Piercing Howl", "Hamstring" },
    },
}

-- WoW Forever runs Classic classes: Wind Shear / Rebuke / Skull Bash don't exist there, so
-- key 3 stayed empty. There these lists replace the class's interrupt list (first one you
-- know wins; empty = the class has none on Forever). Retail keeps the lists above.
-- (Forever audit, 2026-11-10)
local IS_FOREVER = (select(4, GetBuildInfo()) or 0) < 100000
local FOREVER_INTERRUPT = {
    SHAMAN = { "Earth Shock" },
    WARRIOR = { "Pummel", "Shield Bash" },
    ROGUE = { "Kick" },
    MAGE = { "Counterspell" },
    PRIEST = { "Silence" },
    WARLOCK = { "Spell Lock" },
    -- WoW Forever's paladin has Rebuke (it's in its spell lines); without it Hammer of Justice (a stun) is the
    -- interrupt (the user, 2026-11-26, tanking Vedi: "any interrupts should be on 1 through 7")
    PALADIN = { "Rebuke", "Hammer of Justice" }, DRUID = {}, HUNTER = {},
}

-- Never on the 14 combat keys (the user, 2026-11-26: "you keep putting buffs that last an hour or 30 minutes on my
-- Naga bars ... I don't need them on those bars", "I don't think things like buffs should be in the key bindings, I'd
-- rather just put them in another bar"): long buffs for any class (10 minutes or more by the tooltip), and on WoW
-- Forever the paladin's blessings, auras and Righteous Fury, plus Cleanse / Purify (they belong on the party
-- frames' click casting). Wherever you put them yourself, they stay.
-- WoW Forever paladin, most important first (the class list above holds retail names): the big defensive, the
-- short ones and the heals on the top row; group help and the rest on Shift (the user, 2026-11-26, tanking Vedi)
local FOREVER_LIST = {
    PALADIN = { "Exorcism", "Hammer of Wrath", "Templar's Bulwark", "Divine Protection", "Lay on Hands", "Holy Light",
        "Flash of Light", "Hammer of Justice", "Repentance", "Blessing of Protection", "Divine Shield",
        "Blessing of Sacrifice", "Blessing of Freedom", "Seal of Wisdom", "Turn Undead", "Divine Intervention" },
}

-- WoW Forever Rogue on the Subtlety daggers set (Hemorrhage known; the user, 2026-11-27: "build the forever sub list
-- for suggest"). Measured: the 32 level-60 Sub rogues in our battleground combat logs, what they cast by hand (key 1
-- already casts Premeditation, Cheap Shot, Hemorrhage, Ghostly Strike, Shank, Eviscerate, Blood Fury). Ordered by how
-- many of them used it (strong players breaking ties): Stealth 24, Kidney Shot 18, Vanish 16, Rupture 13, Sprint 12,
-- Evasion 9, Slice and Dice 8, Gouge 6, Cold Blood 5 (4 of them strong), Blind 4, Preparation 3, Expose Armor 2,
-- Feint 1. Kept in THIS order (not re-grouped by tooltip). Stealth-only openers go on the stealth page instead.
-- Feint and Expose Armor left out (the user, 2026-11-27: "i dont need feint or anything group dungeon based on my
-- bars"); the list is the whole set: no spellbook top-up after it, a spare key keeps what you put there.
-- Trimmed (the user, 2026-11-28: "yes trim it", fewest buttons outside key 1): the must-haves only. Cold Blood is key
-- 1's now; Rupture, Slice and Dice, Preparation, Garrote, Ambush, Distract are optional and left off, and the keys
-- nothing is planned for are EMPTIED on this set (not kept).
local FOREVER_SUB_ROGUE = { "Stealth", "Kidney Shot", "Vanish", "Sprint", "Evasion", "Gouge", "Blind" }
-- off the keys of the Sub (PvP) set only: group / dungeon tools (threat drop, the armor debuff for the group, traps).
-- The user: "i mean it from a pvp perspective, not all the time" -- the Combat (dungeon) set keeps them.
local FOREVER_SUB_OFF = { ["Feint"] = true, ["Expose Armor"] = true, ["Disarm Trap"] = true, ["Detect Traps"] = true }
-- keys 2-7 in Stealth (VoidBars pages a rogue's main bar to page 7 in real Stealth): Sap (6 players measured); key 3
-- stays Kick so the interrupt is the same key in and out of Stealth; the rest of the stealth page is emptied.
local FOREVER_SUB_STEALTH = { [2] = "Sap", [3] = "Kick" }   -- trimmed 2026-11-28: key 1 opens (Premeditation, Cheap Shot)
local STEALTH_PAGE = 7

local FOREVER_OFF_KEYS ={ ["Righteous Fury"] = true, ["Cleanse"] = true, ["Purify"] = true }
local KEEP_BLESSINGS = { ["Blessing of Protection"] = true, ["Blessing of Freedom"] = true, ["Blessing of Sacrifice"] = true }
local function OffKeys(id, name, class)
    if IS_FOREVER and class == "PALADIN" and name then
        if FOREVER_OFF_KEYS[name] or name:find(" Aura$") or name:find("^Greater Blessing") then return true end
        if name:find("^Blessing of ") and not KEEP_BLESSINGS[name] then return true end
    end
    local data = C_TooltipInfo and C_TooltipInfo.GetSpellByID and C_TooltipInfo.GetSpellByID(id)
    for _, l in ipairs(data and data.lines or {}) do
        local t = (type(l.leftText) == "string" and not VB.IsSecret(l.leftText)) and l.leftText:lower() or ""
        local n = t:match("for (%d+) min") or t:match("lasts (%d+) min") or t:match("(%d+) min duration")
        if n and tonumber(n) >= 10 then return true end
        if t:match("for (%d+) hour") or t:match("lasts (%d+) hour") then return true end
    end
    return false
end

-- Forever role (the spec API is a placeholder there and GetSpecializationRole doesn't
-- exist): the group role, else a tank stance / form / aura. nil when unknown.
-- (Forever audit, 2026-11-10)
local function ForeverRole()
    local r = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
    if r and r ~= "NONE" then return r end
    local _, class = UnitClass("player")
    if class == "WARRIOR" or class == "DRUID" then
        local idx = GetShapeshiftForm and GetShapeshiftForm()
        local sid = idx and idx > 0 and select(4, GetShapeshiftFormInfo(idx))
        local nm = sid and C_Spell.GetSpellName(sid)
        if nm == "Defensive Stance" or nm == "Bear Form" or nm == "Dire Bear Form" then return "TANK" end
    elseif class == "PALADIN" and C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
        local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", "Righteous Fury", "HELPFUL")
        if ok and aura then return "TANK" end
    end
    return nil
end

-- Same "do you have it" test VoidSequencer uses: known directly or via its base spell
-- (talent overrides).
local function KnownID(name)
    local info = C_Spell.GetSpellInfo(name)
    local id = info and info.spellID
    if not id then return nil end
    if C_SpellBook.IsSpellKnown(id) then return id end
    local base = C_Spell.GetBaseSpell and C_Spell.GetBaseSpell(id)
    if base and base ~= id and C_SpellBook.IsSpellKnown(base) then return base end
    return nil
end

-- Active (non-passive) abilities from your applied talents, hero tree included.
local function TalentedActives()
    local out = {}
    local cfg = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    local ci = cfg and C_Traits.GetConfigInfo(cfg)
    for _, treeID in ipairs(ci and ci.treeIDs or {}) do
        for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
            local n = C_Traits.GetNodeInfo(cfg, nodeID)
            if n and n.activeEntry and (n.activeRank or 0) > 0 and not (n.subTreeID and not n.subTreeActive) then
                local e = C_Traits.GetEntryInfo(cfg, n.activeEntry.entryID)
                local d = e and e.definitionID and C_Traits.GetDefinitionInfo(e.definitionID)
                local sid = d and d.spellID
                if sid and not C_Spell.IsSpellPassive(sid) and C_SpellBook.IsSpellKnown(sid) then
                    local nm = C_Spell.GetSpellName(sid)
                    if nm then out[#out + 1] = nm end
                end
            end
        end
    end
    table.sort(out)
    return out
end

-- One identity per ability: a talent override (Shimmer over Blink) and its base spell
-- compare equal, whichever name or slot id we start from.
local function Canon(id)
    if not id then return nil end
    local base = C_Spell.GetBaseSpell and C_Spell.GetBaseSpell(id)
    return base or id
end

local function CanonByName(name)
    local info = C_Spell.GetSpellInfo(name)
    return info and Canon(info.spellID)
end

-- VoidSequencer drives key 1 only when it's loaded AND switched on. Every VoidSequencer
-- branch below (key 1, skipped spells, fixed layouts, wording) asks this one question.
local function SeqActive()
    local api = VoidSequencerAPI
    if not (api ~= nil and (not api.IsEnabled or api.IsEnabled())) then return false end
    -- ...and only when it has a rotation for this character: a WoW Forever Hunter with
    -- VoidSequencer on had key 1 reserved and his spellbook ignored, so the clean layout
    -- emptied his bars (the user's son's PC, 2026-11-16)
    -- (HasRotation, not RotationSpells: that one is always empty on Forever, even for a Rogue
    -- with a working FOREVER_ROGUE rotation; an older VoidSequencer without it keeps key 1)
    if api.HasRotation then
        local ok, has = pcall(api.HasRotation)
        if ok and not has then return false end
    end
    return true
end
VB.SeqActive = SeqActive

-- Spells VoidSequencer already casts (rotation + held modifiers), as canonical ids.
-- Empty without it.
local function RotationSpells()
    local api = VoidSequencerAPI
    local out = {}
    if not (SeqActive() and api.RotationSpells) then return out end
    for name in pairs(api.RotationSpells() or {}) do
        local c = CanonByName(name)
        if c then out[c] = true end
    end
    return out
end

-- Active spells in your class and current spec spellbook tabs (General, off-spec and
-- passives skipped). Only used without VoidSequencer, to find the rotation.
local function SpellbookActives()
    local out = {}
    local bank = Enum.SpellBookSpellBank.Player
    for line = 2, C_SpellBook.GetNumSpellBookSkillLines() do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if info and not info.isGuild and not info.shouldHide and not info.offSpecID then
            for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local it = C_SpellBook.GetSpellBookItemInfo(i, bank)
                if it and it.itemType == Enum.SpellBookItemType.Spell and it.spellID
                    and not it.isPassive and not it.isOffSpec then
                    out[#out + 1] = C_Spell.GetSpellName(it.spellID) or it.name
                end
            end
        end
    end
    return out
end

local function KeyText(cmd, fallback)
    local key = GetBindingKey(cmd)
    return key and GetBindingText(key) or fallback
end

-- Canonical spell id in a slot (nil for empty / non-spell).
local function SpellAt(slot)
    local t, id = GetActionInfo(slot)
    if VB.IsSecret(t) or VB.IsSecret(id) or t ~= "spell" or not id then return nil end
    return Canon(id)
end

-- Tooltip text (lower case) and cooldown in seconds (0 = none) of a spell. The
-- tooltip is the one place both live (enUS: "30 sec cooldown", "2 min recharge").
local function SpellText(id)
    local data = C_TooltipInfo and C_TooltipInfo.GetSpellByID and C_TooltipInfo.GetSpellByID(id)
    local parts, cd = {}, 0
    for _, l in ipairs(data and data.lines or {}) do
        for _, txt in ipairs({ l.leftText or "", l.rightText or "" }) do
            if type(txt) == "string" and not VB.IsSecret(txt) and txt ~= "" then
                parts[#parts + 1] = txt:lower()
                local n, unit = txt:match("([%d%.]+) (%a+) cooldown")
                if not n then n, unit = txt:match("([%d%.]+) (%a+) recharge") end
                n = tonumber(n)
                if n and (unit == "sec" or unit == "min") then cd = unit == "min" and n * 60 or n end
            end
        end
    end
    return table.concat(parts, " "), cd
end

-- Groups, best keys first.
local DAMAGE, DEFENSIVE, CONTROL, MOVEMENT, UTILITY = 1, 2, 3, 4, 5
local function Has(text, list)
    for _, p in ipairs(list) do if text:find(p) then return true end end
end
-- escapes / threat drops count as defensive: Vanish was listed as "damage your rotation
-- doesn't cast" (2026-10-25) -- it must never go into the one-button rotation
local DEF_WORDS  = { "damage taken", "heal", "absorb", "immun", "dodge", "parry", "invulnerab", "reduces all damage",
    "vanish", "threat", "enters? stealth", "entering stealth", "drop%a* combat" }
local CC_WORDS   = { "stun", "incapacitat", "disorient", "fear", "silenc", "root", "knock", "blind", "sleep",
    "polymorph", "taunt", "slowing", "reduc%a* .-movement speed" }
-- (Classic wording on WoW Forever: Raptor Strike / Heroic Strike "increases melee damage by 5",
-- Auto Shot "automatically shoots the target"; both were left off a level-7 Hunter's keys)
local DMG_WORDS  = { "deals? [%d,%.]+", "dealing", "inflict", "[%d,%.]+ %a+ damage", "[%d,%.]+ damage",
    "damage by [%d,%.]+", "automatically shoots" }
local MOVE_WORDS = { "movement speed", "teleport", "leap", "charges? to", "jump", "dash", "grappl", "pull yourself" }

-- Without VoidSequencer the top row holds your main buttons. A spell is one if it does
-- damage (measured, or its tooltip says so even when it also slows or stuns), or, for a
-- healer, if it heals with a short cooldown (Tranquility-size cooldowns stay on Shift).
-- Returns its rank in the DAMAGE group, or nil.
local function MainRank(id, name, healer)
    local score, fights = VB:SpellDamage(name)
    if score and score >= 0.03 then return 1000 + score end
    local measuredLow = fights and fights >= 3
    local text, cd = SpellText(id)
    local rank = 100 - math.min(cd, 3600) / 3600
    if not measuredLow and Has(text, DMG_WORDS) then return rank end
    if healer and cd <= 30 and text:find("heal") then return rank end
    return nil
end

-- Group of one spell + its damage rank key (higher = better) for the DAMAGE group.
local function Classify(id, name)
    local score, fights = VB:SpellDamage(name)
    -- measured over a few fights: real damage, or (barely any) not a damage button
    local measuredLow = fights and fights >= 3 and score < 0.03
    if score and score >= 0.03 then return DAMAGE, 1000 + score end
    local text, cd = SpellText(id)
    if Has(text, DEF_WORDS) then return DEFENSIVE end
    if Has(text, CC_WORDS) then return CONTROL end
    -- unmeasured damage: shortest cooldown first (rank stays below any measured one)
    if not measuredLow and Has(text, DMG_WORDS) then return DAMAGE, 100 - math.min(cd, 3600) / 3600 end
    if Has(text, MOVE_WORDS) then return MOVEMENT end
    return UTILITY
end

-- The page keys 1-7 show while playing the current spec: Guardian lives in Bear Form
-- (page 9), Feral in Cat Form (page 7), as in PageDriver; everything else page 1.
local HOME_PAGE = { [103] = 7, [104] = 9 }
local function SpecID()
    local getSpec = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
    local getInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
    local si = getSpec and getSpec()
    return si and getInfo and getInfo(si)
end
function VB:HomePage()
    return HOME_PAGE[SpecID()] or 1
end

-- Fixed layouts for specs where the player agreed the keys (instead of the ranked
-- class list). Key -> spell name, a list of names (first one you know), or
-- { macro = spell } = VoidSequencer's healer macro for that spell (aimed at the hovered
-- frame / the tank), falling back to the plain spell without VoidSequencer.
local FIXED = {
    [105] = {   -- Restoration Druid (2026-10-27): key 1 = VoidSequencer heals by hover
        [2] = { macro = "Lifebloom" }, [3] = "Skull Bash", [4] = { macro = "Ironbark" },
        [5] = { macro = "Nature's Cure" }, [6] = "Nature's Swiftness", [7] = "Convoke the Spirits",
        s1 = "Tranquility", s2 = "Innervate", s3 = "Barkskin", s4 = { "Typhoon", "Ursol's Vortex" },
        s5 = "Soothe", s6 = "Stampeding Roar", s7 = { macro = "Rebirth" },
        -- Cat Form pages keys 1-7 to page 7 (the player's pick, 2026-10-27: "Mix"): key 1 =
        -- VoidSequencer's cat loop, cat finishers / AoE on 5-7, and the tank Lifebloom +
        -- Ironbark kept on 2 / 4 as emergencies (they pull you out of cat). The Shift row
        -- doesn't page, so it's the same in every form.
        pages = {
            [7] = { [2] = { macro = "Lifebloom" }, [3] = "Skull Bash", [4] = { macro = "Ironbark" },
                    [5] = "Swipe", [6] = "Rip", [7] = "Ferocious Bite" },
        },
    },
}

-- Name of the macro in an action slot (nil if it isn't a macro). GetActionInfo's id is
-- not reliably the macro index (a spell macro reports its spell), so match by name.
local function MacroAt(slot)
    local t = GetActionInfo(slot)
    if VB.IsSecret(t) or t ~= "macro" then return nil end
    local name = GetActionText(slot)
    if VB.IsSecret(name) then return nil end
    return name
end

local function FixedPlan(fixed, base)
    local api = VoidSequencerAPI
    local macros = (api and api.HealMacros and api.HealMacros()) or {}
    local plan = {}
    local function entry(slot, cmd, fallback, want)
        local p = { slot = slot, key = KeyText(cmd, fallback) }
        local names = (type(want) == "table" and not want.macro) and want or { want and (want.macro or want) }
        for _, nm in ipairs(names) do
            local id = KnownID(nm)
            if id then
                p.name, p.id = C_Spell.GetSpellName(id) or nm, id
                if type(want) == "table" and want.macro and macros[nm] then
                    p.macro = macros[nm]
                    p.name = p.name .. " (" .. macros[nm] .. ")"
                end
                break
            end
        end
        plan[#plan + 1] = p
    end
    for i = 2, 7 do entry(base + i, "ACTIONBUTTON" .. i, tostring(i), fixed[i]) end
    for i = 1, 7 do entry(60 + i, "MULTIACTIONBAR1BUTTON" .. i, "Shift-" .. i, fixed["s" .. i]) end
    -- extra form pages (Resto: Cat Form = page 7) with their own keys 2-7
    for pg, keys in pairs(fixed.pages or {}) do
        local pbase = (pg - 1) * 12
        if pbase ~= base then
            for i = 2, 7 do
                entry(pbase + i, "ACTIONBUTTON" .. i, tostring(i), keys[i])
                local p = plan[#plan]
                p.key = p.key .. " (cat)"
            end
        end
    end
    return plan
end

-- Slots on the shown bars; bar1 also counts the spec's home page.
function VB:ShownSlots()
    local slots = {}
    for _, def in ipairs(self.BAR_DEFS) do
        local cfg = def.page and self:BarConfig(def.key)
        local shown = cfg and cfg.enabled
        if cfg and shown == nil then shown = (def.key == "bar1") end   -- same default as Options
        if shown then
            local pages = { def.page }
            if def.key == "bar1" and self:HomePage() ~= def.page then pages[2] = self:HomePage() end
            for _, pg in ipairs(pages) do
                for i = 1, (cfg.num or 12) do slots[#slots + 1] = (pg - 1) * 12 + i end
            end
        end
    end
    return slots
end

-- Tracking (Track Beasts, Find Herbs...): Blizzard's minimap button does it, so never a key.
function VB.IsTracking(nm)
    return type(nm) == "string" and (nm:find("^Track") or nm:find("Tracking$") or nm:find("^Find ") or nm:find("^Sense ")) ~= nil
end

-- The plan: { {slot=, key=, name=, id=}, ... }, the spells left over, VoidSequencer's
-- spells, and the damage spells placed (not in the rotation). fresh = ignore where
-- spells sit now.
function VB:BuildSuggestion(fresh)
    local _, class = UnitClass("player")
    local def = CLASS[class] or { list = {} }
    if IS_FOREVER and FOREVER_LIST[class] then
        def = { interrupt = def.interrupt, taunt = def.taunt, list = FOREVER_LIST[class] }
    end
    -- the Subtlety daggers set: the measured list, in its own order, plus the stealth page
    -- only while VoidSequencer's PvP rotation runs key 1 (Codex 11-28: without it, or in dungeon mode, the trimmed
    -- list would clear the keys that hold Hemorrhage and Eviscerate with nothing casting them)
    local api = _G.VoidSequencerAPI
    local subRogue = IS_FOREVER and class == "ROGUE" and KnownID("Hemorrhage") ~= nil and SeqActive()
        and api and api.IsPvpMode and api.IsPvpMode() and true or false
    if subRogue then def = { interrupt = def.interrupt, list = FOREVER_SUB_ROGUE, ordered = true } end
    local skip = RotationSpells()
    local seq = SeqActive()
    local fixed = seq and FIXED[SpecID()]
    if fixed then return FixedPlan(fixed, (self:HomePage() - 1) * 12), {}, skip, {} end
    local taken = {}   -- canonical ids already planned
    -- spells a VoidBars smart bar already shows (the Pets bar's Call / Revive / Mend / Dismiss
    -- Pet): one press, one place (the user's son's Hunter had them twice, 2026-11-17)
    local onSmart = {}
    for id in pairs(self.SmartBarIDs and self:SmartBarIDs("spell") or {}) do onSmart[Canon(id)] = true end
    local function usable(name)
        local id = name and KnownID(name)
        local c = Canon(id)
        if not c or taken[c] or skip[c] or onSmart[c] then return nil end
        taken[c] = true
        return id
    end

    -- interrupt (always key 3); tanks: taunt first; then the class list and other talents,
    -- sorted into groups (damage by rank, the rest keep their list order)
    local role
    if IS_FOREVER then
        role = ForeverRole()   -- spec role is empty there (Forever audit, 2026-11-10)
    else
        local getSpec = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
        local getRole = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationRole) or GetSpecializationRole
        local si = getSpec and getSpec()
        role = si and getRole and getRole(si)
    end
    local interrupt
    local interrupts = def.interrupt or {}
    if IS_FOREVER and FOREVER_INTERRUPT[class] then   -- (Forever audit, 2026-11-10)
        interrupts = FOREVER_INTERRUPT[class]
        -- a Classic tank warrior sits in Defensive Stance, where Pummel can't be used
        if class == "WARRIOR" and role == "TANK" then interrupts = { "Shield Bash", "Pummel" } end
    end
    for _, nm in ipairs(interrupts) do
        local id = usable(nm)
        if id then interrupt = { name = C_Spell.GetSpellName(id) or nm, id = id } break end
    end
    local queue = {}
    -- mainOnly: a spellbook spell, kept only when it's a main (top-row) button.
    local function add(nm, group, mainOnly)
        local id = usable(nm)
        if not id then return end
        local name = C_Spell.GetSpellName(id) or nm
        if OffKeys(id, name, class) then return end   -- long buffs, auras, dispels: another bar / the frames
        local g, rank
        local main = not seq and MainRank(id, name, role == "HEALER")
        if main then
            g, rank = DAMAGE, main
        elseif mainOnly then
            taken[Canon(id)] = nil
            return
        else
            g, rank = Classify(id, name)
        end
        -- a given group (taunts, an ordered list) keeps its list order: no damage rank inside it (Codex 11-27: Rupture's
        -- tooltip damage would have jumped it ahead of Stealth in the Sub rogue's measured order)
        queue[#queue + 1] = { name = name, id = id, c = Canon(id), group = group or g, rank = group and 0 or (rank or 0), order = #queue }
    end
    if role == "TANK" then
        for _, nm in ipairs(def.taunt or {}) do add(nm, 0) end
    end
    -- the stealth page's openers: reserved first, so they don't also take a normal key (or show as "didn't fit")
    local stealthPicks = {}
    if subRogue and seq then
        for i = 2, 7 do
            local nm = FOREVER_SUB_STEALTH[i]
            local id = nm and ((interrupt and nm == interrupt.name and interrupt.id) or usable(nm))
            if id then stealthPicks[i] = { name = C_Spell.GetSpellName(id) or nm, id = id } end
        end
    end
    -- an ordered list (the Sub rogue's) keeps its own order ahead of the tooltip groups
    for _, nm in ipairs(def.list) do add(nm, def.ordered and 0.5 or nil) end
    -- an ordered list (the Sub rogue's) is the whole set: no talent / spellbook top-up after it
    if not def.ordered then
    for _, nm in ipairs(TalentedActives()) do add(nm) end
    end
    if (not seq or IS_FOREVER) and not def.ordered then
        -- WoW Forever: the class lists hold retail names, so the spellbook is the only source of a
        -- Classic character's utility (Aspect of the Monkey): it gets the Shift row there too,
        -- with VoidSequencer on as well (what its rotation casts is skipped by `usable`).
        -- Tracking stays off the keys (Blizzard's minimap button does it).
        for _, nm in ipairs(SpellbookActives()) do
            if not (IS_FOREVER and VB.IsTracking(nm)) then
                add(nm, nil, not IS_FOREVER)
            end
        end
    end
    table.sort(queue, function(a, b)
        if a.group ~= b.group then return a.group < b.group end
        if a.rank ~= b.rank then return a.rank > b.rank end
        return a.order < b.order
    end)

    -- keys: top row 2..7 (1..7 without VoidSequencer; 3 = interrupt) on the spec's home
    -- page, then Shift row 1..7 (bar 2 doesn't page, so it's the same in every form)
    local base = (self:HomePage() - 1) * 12
    -- key 3 is the interrupt key only when you have one (a Forever Hunter has none: key 3 kept
    -- whatever was on it, his bow, 2026-11-17); otherwise it's a normal key
    local INTERRUPT_KEY = interrupt and INTERRUPT_KEY or -1
    local keys = {}
    for i = seq and 2 or 1, 7 do
        keys[#keys + 1] = { slot = base + i, cmd = "ACTIONBUTTON" .. i, fallback = tostring(i), top = true }
    end
    for i = 1, 7 do
        keys[#keys + 1] = { slot = 60 + i, cmd = "MULTIACTIONBAR1BUTTON" .. i, fallback = "Shift-" .. i }
    end
    local free = #keys - (interrupt and 1 or 0)   -- minus the interrupt key
    local chosen = {}
    if seq then
        for i = 1, math.min(free, #queue) do chosen[queue[i].c] = queue[i] end
    else
        -- damage fills the 6 free top keys, the rest the 7 Shift keys; a row with room
        -- left takes the other kind
        local dmg, other = {}, {}
        for _, q in ipairs(queue) do
            if q.group == DAMAGE then dmg[#dmg + 1] = q else other[#other + 1] = q end
        end
        local topFree, shiftFree = free - 7, 7   -- (top row: 7 keys, 6 with an interrupt)
        for i = 1, math.min(#dmg, topFree + math.max(0, shiftFree - #other)) do chosen[dmg[i].c] = dmg[i] end
        for i = 1, math.min(#other, shiftFree + math.max(0, topFree - #dmg)) do chosen[other[i].c] = other[i] end
    end

    -- 1) spells already on one of these keys stay there (unless fresh); 2) the rest fill
    -- the free keys best-first, in queue order (without VoidSequencer: damage on the top
    -- row, the rest on Shift, either one when its own kind has run out)
    local pick, placed = {}, {}
    if not fresh then
        for _, k in ipairs(keys) do
            local cur = k.slot ~= base + INTERRUPT_KEY and SpellAt(k.slot)
            local q = cur and chosen[cur]
            -- without VoidSequencer a spell only stays put on its own row (main buttons on
            -- top, the rest on Shift); the fill below moves it otherwise
            if q and not placed[q] and (seq or (q.group == DAMAGE) == (k.top == true)) then
                pick[k.slot] = q; placed[q] = true
            end
        end
    end
    for _, k in ipairs(keys) do
        if k.slot ~= base + INTERRUPT_KEY and not pick[k.slot] then
            local best
            for _, q in ipairs(queue) do
                if chosen[q.c] == q and not placed[q] then
                    if seq or (q.group == DAMAGE) == (k.top == true) then best = q break end
                    best = best or q
                end
            end
            if best then pick[k.slot] = best; placed[best] = true end
        end
    end

    local plan, damage = {}, {}
    for _, k in ipairs(keys) do
        local p = (k.slot == base + INTERRUPT_KEY) and interrupt or pick[k.slot]
        -- the Sub (PvP) set's trimmed list: a key nothing is planned for is emptied (the user: fewest buttons)
        plan[#plan + 1] = { slot = k.slot, key = KeyText(k.cmd, k.fallback), name = p and p.name, id = p and p.id,
            clear = (subRogue and not p) or nil }
        if p and p.group == DAMAGE then damage[#damage + 1] = p.name end
    end
    -- the rogue's stealth page (keys 2-7 in Stealth): Sap, Kick; the rest emptied
    if subRogue and seq then
        for i = 2, 7 do
            local p = stealthPicks[i]
            plan[#plan + 1] = { slot = (STEALTH_PAGE - 1) * 12 + i, key = KeyText("ACTIONBUTTON" .. i, tostring(i)) .. " (stealth)",
                name = p and p.name, id = p and p.id, clear = (not p) or nil }
        end
    end
    local extra = {}
    for _, q in ipairs(queue) do
        if not placed[q] then extra[#extra + 1] = q.name end
    end
    return plan, extra, skip, damage
end

function VB:ApplySuggestion(fresh)
    if InCombatLockdown() then self:Print("can't change your bars in combat.") return end
    local plan, extra, skip = self:BuildSuggestion(fresh)
    -- nothing found to put on the keys (spells not read yet, a class the lists don't know):
    -- leave the bars as they are rather than clear them (2026-11-16, "0 placed" + empty bars)
    local anything = false
    for _, p in ipairs(plan) do if p.id or p.macro then anything = true break end end
    if not anything then
        self:Print("couldn't find your spells to suggest keys for yet, so your bars stay as they are.")
        return
    end
    self:SaveProfile("Before suggested", true)
    if self:EnsureBlockBindings() > 0 then self:ApplyBindings() end   -- keys the plan's labels promise

    ClearCursor()
    local placed = 0
    -- 1) key 1 stays empty while VoidSequencer drives it (caster page and the spec's home page)
    if SeqActive() then
        local key1 = { 1, (self:HomePage() - 1) * 12 + 1 }
        local fixed = FIXED[SpecID()]
        for pg in pairs(fixed and fixed.pages or {}) do key1[#key1 + 1] = (pg - 1) * 12 + 1 end
        for _, s in ipairs(key1) do
            if GetActionInfo(s) then PickupAction(s); ClearCursor() end
        end
    end
    -- 2) the 13 keys
    for _, p in ipairs(plan) do
        if p.macro then
            local idx = GetMacroIndexByName(p.macro)
            if idx and idx > 0 and MacroAt(p.slot) ~= p.macro then
                PickupMacro(idx)
                PlaceAction(p.slot)
                placed = placed + 1
            end
        elseif p.id then
            if SpellAt(p.slot) ~= Canon(p.id) and self.PickupEntry({ t = "spell", id = p.id }) then
                PlaceAction(p.slot)
                placed = placed + 1
            end
        elseif p.clear and GetActionInfo(p.slot) then
            PickupAction(p.slot)   -- the Sub (PvP) set's trimmed list: this key is meant to be empty
        end
        -- nothing suggested for this key: what's on it stays (it used to be emptied, which with
        -- an empty suggestion cleared every key, 2026-11-16)
        ClearCursor()
    end
    -- 2b) ...unless it's a copy of something that now has its own place: a spell the plan put on
    -- another key, or a spell / item a smart bar shows (Pets bar, food on Consumables). The
    -- son's Hunter kept Tough Jerky and Call Pet on his combat keys next to the same buttons
    -- on the bars beside them (2026-11-17: "i click suggested to clean it up why is it so messy").
    local tidied = 0
    for slot in pairs(self:SuggestLeftovers(plan)) do PickupAction(slot); ClearCursor(); tidied = tidied + 1 end
    -- 3) VoidSequencer's spells off every shown bar
    local cleared = 0
    for _, slot in ipairs(self:ShownSlots()) do
        local c = SpellAt(slot)
        if c and skip[c] then
            PickupAction(slot); ClearCursor()
            cleared = cleared + 1
        end
    end
    self:QueueFullUpdate()
    VoidBarsCharDB.suggestUsed = true   -- from now on, offer an update after talent changes
    local seqNote = SeqActive() and (", %d VoidSequencer spell(s) taken off your bars"):format(cleared) or ""
    if tidied > 0 then seqNote = seqNote .. (", %d leftover(s) removed (a spell now on another key or on a VoidBars bar)"):format(tidied) end
    self:Print(("suggested layout applied: %d placed%s. Undo: Options -> profile \"Before suggested\" -> Restore."):format(placed, seqNote))
    if #extra > 0 then
        self:Print("didn't fit on the 14 keys: " .. table.concat(extra, ", ") .. " (drag any you want onto the Travel bar).")
    end
end

-- Keys the plan leaves alone that hold only a leftover: a spell the plan put on another key, or a
-- spell / item a smart bar shows (Pets bar, food on Consumables), or tracking (Forever). The son's
-- Hunter kept Tough Jerky and Call Pet on his combat keys next to the same buttons on the bars
-- beside them (2026-11-17: "i click suggested to clean it up why is it so messy").
-- Returns { [slot] = true }; Apply empties them and the preview says so.
function VB:SuggestLeftovers(plan)
    local planned, smartSpell, out = {}, {}, {}
    for _, p in ipairs(plan) do if p.id then planned[Canon(p.id)] = true end end
    for id in pairs(self.SmartBarIDs and self:SmartBarIDs("spell") or {}) do smartSpell[Canon(id)] = true end
    local smartItem = self.SmartBarIDs and self:SmartBarIDs("item") or {}
    for _, p in ipairs(plan) do
        if not p.id and not p.macro then
            local t, id = GetActionInfo(p.slot)
            if not VB.IsSecret(t) and not VB.IsSecret(id) then
                local c = SpellAt(p.slot)
                local _, cls = UnitClass("player")
                local nm = c and C_Spell.GetSpellName(c)
                local api = _G.VoidSequencerAPI
                local subPvp = IS_FOREVER and cls == "ROGUE" and KnownID("Hemorrhage") ~= nil and SeqActive()
                    and api and api.IsPvpMode and api.IsPvpMode()
                if (c and (planned[c] or smartSpell[c]))
                    or (subPvp and nm and FOREVER_SUB_OFF[nm])   -- the PvP set: group / dungeon tools come off
                    or (c and IS_FOREVER and VB.IsTracking(C_Spell.GetSpellName(c)))
                    or (t == "item" and id and smartItem[id]) then
                    out[p.slot] = true
                end
            end
        end
    end
    return out
end

-- What sits on a key now, in words (the preview of a key the plan leaves alone)
local function ActionWords(slot)
    local t, id = GetActionInfo(slot)
    if not t or VB.IsSecret(t) or VB.IsSecret(id) then return nil end
    if t == "spell" then return C_Spell.GetSpellName(id) end
    if t == "item" then return (C_Item.GetItemNameByID(id)) end
    if t == "macro" then return GetActionText(slot) end
    return nil
end

-- Preview text for the confirm popup.
function VB:SuggestionText()
    local plan, extra, _, damage = self:BuildSuggestion()
    local leftovers = self:SuggestLeftovers(plan)
    local lines = {}
    for _, p in ipairs(plan) do
        local what = p.name
        if not what and p.clear then
            local now = ActionWords(p.slot)
            what = now and ("|cff888888(" .. now .. " comes off: left empty)|r") or "|cff888888(empty)|r"
        elseif not what then
            local now = ActionWords(p.slot)
            -- a key with nothing suggested keeps what's on it (Apply), unless it's only a leftover
            what = now and (leftovers[p.slot] and ("|cff888888(" .. now .. " comes off)|r") or ("|cff888888keeps " .. now .. "|r"))
                or "|cff888888(empty)|r"
        end
        lines[#lines + 1] = ("%s:  %s"):format(p.key, what)
    end
    local text = table.concat(lines, "\n")
    if #extra > 0 then text = text .. "\n\n|cff888888Didn't fit: " .. table.concat(extra, ", ") .. "|r" end
    if #damage > 0 and SeqActive() then
        text = text .. "\n\n|cffffd100Damage your rotation (key 1) doesn't cast: " .. table.concat(damage, ", ")
            .. ".|r Adding them to VoidSequencer frees these keys."
    end
    return text
end

StaticPopupDialogs.VOIDBARS_SUGGEST = {
    text = "%s\n\n%s\n\nSpells already on these keys stay put; \"Re-sort all\" re-orders every key.\nYour current bars are saved as \"Before suggested\" first.",
    button1 = "Apply", button2 = "Not now", button3 = "Re-sort all",
    OnAccept = function() VB:ApplySuggestion() end,
    OnAlt = function() VB:ApplySuggestion(true) end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

-- The plan lives on the main bar (keys 1-7) and Action Bar 2 (Shift+1-7): both must be on
-- with 7+ buttons, or half of it would land on buttons you can't see.
function VB:BlockReady()
    for _, key in ipairs({ "bar1", "bar2" }) do
        local cfg = self:BarConfig(key)
        local on = cfg.enabled
        if on == nil then on = (key == "bar1") end
        if not on or (cfg.num or 12) < 7 then return false end
    end
    return true
end

function VB:ShowSuggestion(intro)
    if InCombatLockdown() then self:Print("can't change your bars in combat.") return end
    if not self:BlockReady() then
        self:Print("suggested spells go on keys 1-7 (Action Bar 1) and Shift+1-7 (Action Bar 2). "
            .. "Turn both on with 7+ buttons (/vbars bar), or apply the clean layout: Options -> VoidBars -> Layout.")
        return
    end
    intro = intro or (SeqActive() and "Suggested layout (key 1 = VoidSequencer):"
        or "Suggested layout (damage on 1-7, interrupt on 3, the rest on Shift):")
    StaticPopup_Show("VOIDBARS_SUGGEST", intro, self:SuggestionText())
end

-- How many of the 14 keys (plus VoidSequencer spells on shown bars) would the
-- suggestion change right now? 0 = your bars already match your talents.
function VB:SuggestionChanges()
    local plan, _, skip = self:BuildSuggestion()
    local n = 0
    for _, p in ipairs(plan) do
        if p.macro then
            if MacroAt(p.slot) ~= p.macro then n = n + 1 end
        elseif p.id then
            if SpellAt(p.slot) ~= Canon(p.id) then n = n + 1 end
        elseif GetActionInfo(p.slot) then
            n = n + 1
        end
    end
    for _, slot in ipairs(self:ShownSlots()) do
        local c = SpellAt(slot)
        if c and skip[c] then n = n + 1 end
    end
    return n
end

-- The plan as text (slot = spell / macro / empty): two equal signatures = nothing new to suggest.
function VB:SuggestionSig()
    local plan = self:BuildSuggestion()
    local parts = {}
    for _, p in ipairs(plan) do
        parts[#parts + 1] = tostring(p.slot) .. "=" .. tostring(p.macro or (p.id and Canon(p.id)) or "")
    end
    table.sort(parts)
    return table.concat(parts, ";")
end

-- After talents change (or a level-up teaches something new), WoW drops spells onto your
-- bars and the plan shifts. On characters that use the suggested layout, offer the update
-- once things settle -- never in combat, never on characters that don't use it.
do
    local pending, waitCombat
    local function Check()
        pending = nil
        -- uses the suggested layout = applied it (flag, or its undo profile from before the flag)
        local used = VoidBarsCharDB and (VoidBarsCharDB.suggestUsed
            or (VoidBarsCharDB.profiles and VoidBarsCharDB.profiles["Before suggested"]))
        if not used then return end
        if InCombatLockdown() then waitCombat = true return end
        if StaticPopup_FindVisible and StaticPopup_FindVisible("VOIDBARS_SUGGEST") then return end
        -- Only when the plan itself changed since we last offered it (the user, 2026-11-27: "voidbars suggested bar
        -- layout keeps popping up when i enter in bgs"): WoW Forever fires the talent events on every battleground /
        -- instance zone-in, and after "Not now" the keys still differ, so it asked again each time. Same talents and
        -- spells = same plan = no question.
        local sig = VB:SuggestionSig()
        if sig == VoidBarsCharDB.suggestOffered then return end
        local n = VB:SuggestionChanges()
        if n > 0 then
            VoidBarsCharDB.suggestOffered = sig
            VB:ShowSuggestion(("Your talents or spells changed -- %d key(s) don't match the suggested layout any more. Update them?"):format(n))
        end
    end
    -- Only on a level-up while leveling (the user, 2026-11-27: "it should only popup on leveling and at max level
    -- stop"). Talent / spec events no longer ask (WoW Forever fires them on every battleground zone-in); the
    -- Suggest button still offers it any time.
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_LEVEL_UP")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", function(_, event, level)
        if event == "PLAYER_REGEN_ENABLED" then
            if not waitCombat then return end
            waitCombat = nil
        else
            local max = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()
            if max and (tonumber(level) or UnitLevel("player")) >= max then return end   -- max level: never asks
        end
        if not pending then pending = true; C_Timer.After(3, Check) end
    end)
end
