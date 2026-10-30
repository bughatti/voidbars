----------------------------------------------------------------------
-- VoidBars — your own damage per spell, for the suggested layout's order.
--
-- After each fight (out of combat: the meter is secret during combat) this reads
-- Blizzard's damage meter (C_DamageMeter, the official API -- no combat log) for
-- the player and keeps, per spec, a running score per spell name:
--     score = score * 0.9 + this fight's share of your damage
-- Spells that keep doing damage stay high; ones you stop using fade out.
-- Values that come back secret (some instanced groups) are skipped, never used.
-- Needs the game's damage meter on (Options -> Advanced -> Damage Meter); without
-- it the suggestion falls back to cooldown order.
----------------------------------------------------------------------
local _, VB = ...

local DECAY = 0.9
local MIN_FIGHT = 6   -- seconds; shorter fights say little

local function Secret(v) return issecretvalue and issecretvalue(v) end

local function SpecStore(create)
    if not VoidBarsCharDB then return nil end
    local si = GetSpecialization and GetSpecialization()
    local specID = si and GetSpecializationInfo(si)
    if not specID then return nil end
    local all = VoidBarsCharDB.spellDmg
    if not all then
        if not create then return nil end
        all = {}
        VoidBarsCharDB.spellDmg = all
    end
    if not all[specID] and create then all[specID] = {} end
    return all[specID]
end

-- score (share-weighted, 0..~10) and the number of fights it did damage in; nil if never seen.
function VB:SpellDamage(name)
    local t = name and SpecStore(false)
    local e = t and t[name]
    if e then return e.s, e.n end
end

local function Record()
    if InCombatLockdown() or not VoidBarsCharDB then return end
    if not (C_DamageMeter and C_DamageMeter.GetAvailableCombatSessions and C_DamageMeter.GetCombatSessionSourceFromID) then return end
    local ok, sessions = pcall(C_DamageMeter.GetAvailableCombatSessions)
    if not ok or type(sessions) ~= "table" then return end
    local newest, dur
    for _, s in ipairs(sessions) do
        local id = s.sessionID
        if type(id) == "number" and not Secret(id) and (not newest or id > newest) then
            newest, dur = id, s.durationSeconds
        end
    end
    if not newest or newest == VoidBarsCharDB.dmgLastSession then return end
    VoidBarsCharDB.dmgLastSession = newest
    if type(dur) ~= "number" or Secret(dur) or dur < MIN_FIGHT then return end

    local guid = UnitGUID("player")
    local ok2, src = pcall(C_DamageMeter.GetCombatSessionSourceFromID, newest, Enum.DamageMeterType.DamageDone, guid)
    if not ok2 or type(src) ~= "table" or type(src.combatSpells) ~= "table" then return end
    local byName, total = {}, 0
    for _, sp in ipairs(src.combatSpells) do
        local id, amt = sp.spellID, sp.totalAmount
        if type(id) == "number" and type(amt) == "number" and not Secret(id) and not Secret(amt) and amt > 0 then
            local name = C_Spell.GetSpellName(id)
            if name and not Secret(name) then
                byName[name] = (byName[name] or 0) + amt
                total = total + amt
            end
        end
    end
    if total <= 0 then return end

    local t = SpecStore(true)
    if not t then return end
    for _, e in pairs(t) do e.s = e.s * DECAY end
    for name, amt in pairs(byName) do
        local e = t[name] or { s = 0, n = 0 }
        e.s = e.s + amt / total
        e.n = e.n + 1
        t[name] = e
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function() C_Timer.After(1, Record) end)
