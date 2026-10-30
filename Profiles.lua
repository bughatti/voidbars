----------------------------------------------------------------------
-- VoidBars — profiles: snapshot + restore of a whole bar setup.
--
-- A profile holds three things:
--   layout   - VoidBars' bar positions/sizes/on-off (copy of VoidBarsCharDB.bars)
--   actions  - what sits in every action slot (spells, macros, items, toys,
--              mounts, pets, equipment sets, flyouts). These live on Blizzard's
--              servers, so restoring places each one back with Pickup*/PlaceAction.
--   binds    - the keys on every action-bar binding command
--
-- Slots saved: 1-120 and 145-180. 121-144 are the skyriding/vehicle pages the
-- game fills itself. Action bars are per specialization, so a profile records
-- the spec it was taken on and warns when restored on another.
-- Restore is out of combat only (picking up / placing actions is protected).
----------------------------------------------------------------------
local _, VB = ...

local IsSecret = VB.IsSecret
local C_ActionBar = C_ActionBar
local MOUNT_RANDOM_FAVORITE = 268435455

local function SlotList()
    local s = {}
    for i = 1, 120 do s[#s + 1] = i end
    for i = 145, 180 do s[#s + 1] = i end
    return s
end

local function BindCommands()
    local c = {}
    for i = 1, 12 do
        c[#c + 1] = "ACTIONBUTTON" .. i
        for bar = 1, 7 do c[#c + 1] = "MULTIACTIONBAR" .. bar .. "BUTTON" .. i end
    end
    for i = 1, 10 do
        c[#c + 1] = "BONUSACTIONBUTTON" .. i
        c[#c + 1] = "SHAPESHIFTBUTTON" .. i
    end
    return c
end

local function CurrentSpec()
    local get = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
    local idx = get and get()
    if not idx then return nil, nil end
    local infoFn = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
    local _, name = infoFn(idx)
    return idx, name
end

local function DeepCopy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = DeepCopy(v) end
    return o
end

-- All macros (account + character) with this name: { {index=, body=}, ... }
local function MacrosNamed(name)
    local out = {}
    local acct, char = GetNumMacros()
    local maxAcct = (Constants.MacroConsts and Constants.MacroConsts.MAX_ACCOUNT_MACROS) or 120
    local function scan(from, to)
        for i = from, to do
            local n, _, body = GetMacroInfo(i)
            if n == name then out[#out + 1] = { index = i, body = body } end
        end
    end
    scan(1, acct or 0)
    scan(maxAcct + 1, maxAcct + (char or 0))
    return out
end

-- What's in a slot, in a form we can put back later. Returns nil for an empty
-- slot, or { skip = true } for one the game manages (never touched on restore).
local function Describe(slot)
    local t, id, sub = GetActionInfo(slot)
    if not t then return nil end
    if IsSecret(t) or IsSecret(id) then return { skip = true } end
    if t == "spell" and sub == "assistedcombat" then
        return { skip = true }   -- Blizzard's one-button rotation slot: game-managed
    end
    local e = { t = t, id = id, sub = sub }
    if t == "macro" then
        -- 12.x reports the macro's shown spell/item as `id`; the macro itself
        -- is identified by its name (the slot's action text) + body, so two
        -- macros sharing a name still restore the right one.
        e.name = C_ActionBar.GetActionText(slot)
        e.id = nil
        local found = e.name and MacrosNamed(e.name) or {}
        if #found == 1 then e.body = found[1].body end
    elseif t == "item" then
        e.toy = (PlayerHasToy and PlayerHasToy(id)) or nil
    end
    return e
end

local function Same(a, b)
    if not a or not b then return a == b end
    if a.t ~= b.t then return false end
    if a.t == "macro" then return a.name == b.name end
    return a.id == b.id
end

local function PickupMacroEntry(e)
    local found = MacrosNamed(e.name)
    if #found == 0 then return end
    local pick = found[1]
    if #found > 1 and e.body then   -- duplicate names: match the saved body
        for _, m in ipairs(found) do
            if m.body == e.body then pick = m break end
        end
    end
    PickupMacro(pick.index)
end

-- Through the mount's spell: the journal list is filtered by the player's
-- search/source filters, so an owned mount can be missing from it.
local function PickupMount(id)
    if id == MOUNT_RANDOM_FAVORITE then C_MountJournal.Pickup(0) return end
    local _, spellID = C_MountJournal.GetMountInfoByID(id)
    if spellID then C_Spell.PickupSpell(spellID) end
    if GetCursorInfo() then return end
    for i = 1, C_MountJournal.GetNumDisplayedMounts() do
        if C_MountJournal.GetDisplayedMountID(i) == id then
            C_MountJournal.Pickup(i)
            return
        end
    end
end

local function PickupFlyout(flyoutID)
    local bank = Enum.SpellBookSpellBank.Player
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
        for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
            local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
            if item and item.itemType == Enum.SpellBookItemType.Flyout and item.actionID == flyoutID then
                C_SpellBook.PickupSpellBookItem(slot, bank)
                return
            end
        end
    end
end

-- Put a described action on the cursor. Returns true if something got there.
local function Pickup(e)
    ClearCursor()
    local ok = pcall(function()
        if e.t == "spell" then
            C_Spell.PickupSpell(e.id)
            -- Talent overrides (Death Charge 444347 over Death's Advance 48265)
            -- can't be picked up themselves: place the base spell, which shows
            -- as the override on the bar (seen live 2026-10-23).
            if not GetCursorInfo() and C_Spell.GetBaseSpell then
                local base = C_Spell.GetBaseSpell(e.id)
                if base and base ~= e.id then C_Spell.PickupSpell(base) end
            end
        elseif e.t == "macro" then
            if e.name then PickupMacroEntry(e) end
        elseif e.t == "item" then
            if e.toy then C_ToyBox.PickupToyBoxItem(e.id) else C_Item.PickupItem(e.id) end
        elseif e.t == "summonmount" then
            PickupMount(e.id)
        elseif e.t == "summonpet" then
            C_PetJournal.PickupPet(e.id)
        elseif e.t == "equipmentset" then
            local setID = type(e.id) == "number" and e.id or C_EquipmentSet.GetEquipmentSetID(e.id)
            if setID then C_EquipmentSet.PickupEquipmentSet(setID) end
        elseif e.t == "flyout" then
            PickupFlyout(e.id)
        elseif e.t == "outfit" then
            C_TransmogOutfitInfo.PickupOutfit(e.id)
        end
    end)
    return ok and GetCursorInfo() ~= nil
end

VB.PickupEntry = Pickup   -- shared with Suggest.lua

local function Label(e)
    if not e then return "empty" end
    if e.t == "macro" then return "macro " .. tostring(e.name) end
    if e.t == "spell" then return (C_Spell.GetSpellName(e.id) or ("spell " .. e.id)) end
    if e.t == "item" then return (C_Item.GetItemNameByID(e.id) or ("item " .. e.id)) end
    return e.t .. " " .. tostring(e.id)
end

----------------------------------------------------------------------
-- Public
----------------------------------------------------------------------
function VB:Profiles()
    VoidBarsCharDB.profiles = VoidBarsCharDB.profiles or {}
    return VoidBarsCharDB.profiles
end

function VB:SaveProfile(name, quiet)
    local p = { saved = time(), layout = DeepCopy(VoidBarsCharDB.bars or {}), actions = {}, binds = {} }
    p.specIndex, p.specName = CurrentSpec()
    local n = 0
    for _, slot in ipairs(SlotList()) do
        local e = Describe(slot)
        if e then p.actions[slot] = e; n = n + 1 end
    end
    for _, cmd in ipairs(BindCommands()) do
        local keys = { GetBindingKey(cmd) }
        if #keys > 0 then p.binds[cmd] = keys end
    end
    self:Profiles()[name] = p
    if not quiet then
        self:Print(("saved profile \"%s\": %d buttons, %s layout, keybinds%s."):format(
            name, n, VoidBarsCharDB.bars and "bar" or "no", p.specName and (", " .. p.specName) or ""))
    end
    return p
end

function VB:RestoreProfile(name)
    local p = self:Profiles()[name]
    if not p then   -- forgive capitalization ("default" -> "Default")
        for n, v in pairs(self:Profiles()) do
            if n:lower() == (name or ""):lower() then name, p = n, v break end
        end
    end
    if not p then self:Print(("no profile \"%s\"."):format(name)) return end
    if InCombatLockdown() then self:Print("can't restore bars in combat.") return end
    local specIndex, specName = CurrentSpec()
    if p.specIndex and specIndex and p.specIndex ~= specIndex then
        self:Print(("note: \"%s\" was saved on %s; you're on %s. Restoring onto this spec's bars."):format(
            name, p.specName or "another spec", specName or "this spec"))
    end

    -- 1) actions: only touch slots that differ
    local placed, cleared, failed = 0, 0, {}
    ClearCursor()   -- never start with something on the cursor (it would land in a slot)
    for _, slot in ipairs(SlotList()) do
        local want, have = p.actions[slot], Describe(slot)
        -- Game-managed slots (one-button assist) are left alone either way.
        local skip = (want and want.skip) or (have and have.skip)
        if not skip and not Same(want, have) then
            if want then
                if Pickup(want) then
                    PlaceAction(slot)
                    placed = placed + 1
                else
                    failed[#failed + 1] = Label(want)
                end
            elseif have then
                ClearCursor()
                PickupAction(slot)
                cleared = cleared + 1
            end
            ClearCursor()
        end
    end

    -- 2) keybinds for the action-bar commands
    for _, cmd in ipairs(BindCommands()) do
        for _, key in ipairs({ GetBindingKey(cmd) }) do SetBinding(key) end
    end
    for cmd, keys in pairs(p.binds or {}) do
        for _, key in ipairs(keys) do SetBinding(key, cmd) end
    end
    SaveBindings(GetCurrentBindingSet())

    -- 3) layout
    if p.layout and next(p.layout) then
        VoidBarsCharDB.bars = DeepCopy(p.layout)
        -- smart bars refill from the restored settings (in-instance rules, sizes) first
        if self.RebuildSmartBars then self:RebuildSmartBars() end
        self:ApplyAllLayouts()
        self:ApplyVisibility()
    end
    self:ApplyBindings()
    self:QueueFullUpdate()

    self:Print(("restored \"%s\": %d placed, %d cleared%s."):format(name, placed, cleared,
        #failed > 0 and (", couldn't place " .. #failed .. ": " .. table.concat(failed, ", ")) or ""))
end

function VB:DeleteProfile(name)
    self:Profiles()[name] = nil
end

-- First run with profiles: keep what the player has right now as "Default".
function VB:EnsureDefaultProfile()
    if not self:Profiles().Default then
        self:SaveProfile("Default", true)
        self:Print("your current bars, layout and keybinds are saved as profile \"Default\" (Options -> VoidBars to restore).")
    end
end

----------------------------------------------------------------------
-- Popups (12.x: popup edit box via GetEditBox())
----------------------------------------------------------------------
----------------------------------------------------------------------
-- Layouts shared across characters: every character's bar LAYOUT
-- (positions, sizes, which bars are on, smart-bar settings -- not the
-- spells in the slots) is remembered account-wide, so any character can
-- copy another's ("make my rogue look like my main").
----------------------------------------------------------------------
local function CharKey()
    return UnitName("player") .. "-" .. (GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName())
end

function VB:PublishLayout()
    if not (VoidBarsCharDB and VoidBarsCharDB.bars) then return end
    VoidBarsDB.layouts = VoidBarsDB.layouts or {}
    VoidBarsDB.layouts[CharKey()] = {
        bars = DeepCopy(VoidBarsCharDB.bars),
        class = select(2, UnitClass("player")),
        saved = time(),
    }
end

function VB:SharedLayoutNames()
    local names, me = {}, CharKey()
    for k in pairs(VoidBarsDB.layouts or {}) do
        if k ~= me then names[#names + 1] = k end
    end
    table.sort(names)
    return names
end

function VB:CopyLayoutFrom(key)
    local src = VoidBarsDB.layouts and VoidBarsDB.layouts[key]
    if not src then self:Print(("no layout saved for %s."):format(tostring(key))) return end
    if InCombatLockdown() then self:Print("can't change the layout in combat.") return end
    -- safety net: this character's own setup first
    self:SaveProfile("Before copy", true)
    VoidBarsCharDB.bars = DeepCopy(src.bars)
    self:ApplyAllLayouts()
    self:ApplyVisibility()
    self:ApplyBindings()
    self:RebuildSmartBars()
    self:QueueFullUpdate()
    self:PublishLayout()
    self:Print(("copied the bar layout from %s. Your previous setup is saved as profile \"Before copy\"."):format(key))
end

local publisher = CreateFrame("Frame")
publisher:RegisterEvent("PLAYER_LOGOUT")
publisher:SetScript("OnEvent", function() VB:PublishLayout() end)

----------------------------------------------------------------------
-- Layout per specialization (option, off by default): each spec keeps its own
-- bar LAYOUT (positions, sizes, which bars, show rules). Spells need nothing --
-- Blizzard already keeps action slots per spec. On a spec change the outgoing
-- spec's layout is stored and the incoming spec's, if it has one, applied. A spec
-- seen for the first time starts from the current layout.
----------------------------------------------------------------------
function VB:PerSpecLayout() return VoidBarsCharDB.perSpecLayout and true or false end

function VB:SetPerSpecLayout(on)
    VoidBarsCharDB.perSpecLayout = on and true or nil
    VoidBarsCharDB.specLayouts = on and (VoidBarsCharDB.specLayouts or {}) or nil
    local idx = CurrentSpec()
    VoidBarsCharDB.layoutSpec = idx
    if on and idx then VoidBarsCharDB.specLayouts[idx] = DeepCopy(VoidBarsCharDB.bars or {}) end
end

-- Out of combat (callers queue it). Also called after login, in case the spec
-- changed while VoidBars wasn't loaded.
function VB:CheckSpecLayout()
    if not VoidBarsCharDB.perSpecLayout then return end
    local idx, name = CurrentSpec()
    local was = VoidBarsCharDB.layoutSpec
    if not idx or idx == was then return end
    local store = VoidBarsCharDB.specLayouts or {}
    VoidBarsCharDB.specLayouts = store
    if was then store[was] = DeepCopy(VoidBarsCharDB.bars or {}) end
    VoidBarsCharDB.layoutSpec = idx
    local saved = store[idx]
    if saved and next(saved) then
        VoidBarsCharDB.bars = DeepCopy(saved)
        self:ApplyAllLayouts()
        self:ApplyVisibility()
        self:ApplyBindings()
        if self.RebuildSmartBars then self:RebuildSmartBars() end
        self:QueueFullUpdate()
        self:Print(("%s bar layout loaded."):format(name or "this spec's"))
    else
        store[idx] = DeepCopy(VoidBarsCharDB.bars or {})
    end
end

local specWatch = CreateFrame("Frame")
for _, e in ipairs({ "ACTIVE_PLAYER_SPECIALIZATION_CHANGED", "PLAYER_SPECIALIZATION_CHANGED" }) do
    pcall(specWatch.RegisterEvent, specWatch, e)
end
specWatch:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then return end
    if not VB.bars or not VB.bars.bar1 then return end   -- not set up yet (TakeOver checks)
    C_Timer.After(0.5, function()
        VB:RunOutOfCombat("speclayout", function() VB:CheckSpecLayout() end)
    end)
end)

StaticPopupDialogs.VOIDBARS_COPYLAYOUT = {
    text = "Copy the bar layout from %s?\n\nPositions, sizes and which bars are on. The spells on your buttons stay as they are.",
    button1 = YES, button2 = NO,
    OnAccept = function(_, data) VB:CopyLayoutFrom(data) end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs.VOIDBARS_RESTORE = {
    text = "Restore VoidBars profile \"%s\"?\n\nThis puts back every button, the bar layout and the action-bar keybinds saved in it.",
    button1 = YES, button2 = NO,
    OnAccept = function(_, data) VB:RestoreProfile(data) end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}
StaticPopupDialogs.VOIDBARS_SAVEAS = {
    text = "Save your current bars as a profile named:",
    button1 = SAVE, button2 = CANCEL,
    hasEditBox = true,
    OnAccept = function(self)
        local eb = self.GetEditBox and self:GetEditBox() or self.editBox
        local name = eb and strtrim(eb:GetText() or "")
        if name and name ~= "" then VB:SaveProfile(name) end
    end,
    EditBoxOnEnterPressed = function(eb)
        local popup = eb:GetParent()
        local name = strtrim(eb:GetText() or "")
        if name ~= "" then VB:SaveProfile(name) end
        popup:Hide()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}
