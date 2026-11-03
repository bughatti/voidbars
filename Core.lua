----------------------------------------------------------------------
-- VoidBars — Core: bar definitions, saved settings, colors, shared helpers.
--
-- Written from scratch for 12.x. Our buttons are SecureActionButtonTemplate
-- + Blizzard's VISUAL ActionButtonTemplate only; all update logic is ours and
-- uses display-safe calls: cooldowns go through duration objects
-- (GetActionCooldownDuration -> SetCooldownFromDurationObject), counts go
-- straight into SetText, range/usable arrive as events. Nothing secret is
-- compared or branched on in Lua, so the bars keep working in M+ and raids.
----------------------------------------------------------------------
local ADDON, VB = ...
_G.VoidBars = VB

-- Blizzard's eight action bars. `page` is the fixed 12-slot block each bar
-- uses (slots (page-1)*12+1 .. page*12), so taking a bar over keeps every
-- spell exactly where it already is. `bind` is the Blizzard binding command
-- prefix -- we route whatever key the player bound there to our button.
VB.BAR_DEFS = {
    { key = "bar1", label = "Action Bar 1 (main)", blizz = "MainActionBar",       prefix = "ActionButton",              bind = "ACTIONBUTTON",          page = 1, paging = true },
    { key = "bar2", label = "Action Bar 2",        blizz = "MultiBarBottomLeft",  prefix = "MultiBarBottomLeftButton",  bind = "MULTIACTIONBAR1BUTTON", page = 6 },
    { key = "bar3", label = "Action Bar 3",        blizz = "MultiBarBottomRight", prefix = "MultiBarBottomRightButton", bind = "MULTIACTIONBAR2BUTTON", page = 5 },
    { key = "bar4", label = "Action Bar 4",        blizz = "MultiBarRight",       prefix = "MultiBarRightButton",       bind = "MULTIACTIONBAR3BUTTON", page = 3 },
    { key = "bar5", label = "Action Bar 5",        blizz = "MultiBarLeft",        prefix = "MultiBarLeftButton",        bind = "MULTIACTIONBAR4BUTTON", page = 4 },
    { key = "bar6", label = "Action Bar 6",        blizz = "MultiBar5",           prefix = "MultiBar5Button",           bind = "MULTIACTIONBAR5BUTTON", page = 13 },
    { key = "bar7", label = "Action Bar 7",        blizz = "MultiBar6",           prefix = "MultiBar6Button",           bind = "MULTIACTIONBAR6BUTTON", page = 14 },
    { key = "bar8", label = "Action Bar 8",        blizz = "MultiBar7",           prefix = "MultiBar7Button",           bind = "MULTIACTIONBAR7BUTTON", page = 15 },
    -- Pet and stance bars: 10 buttons each, their own button types (PetStance.lua)
    { key = "pet",    label = "Pet bar",    blizz = "PetActionBar", prefix = "PetActionButton", bind = "BONUSACTIONBUTTON", kind = "pet",    count = 10 },
    { key = "stance", label = "Stance bar", blizz = "StanceBar",    prefix = "StanceButton",    bind = "SHAPESHIFTBUTTON",  kind = "stance", count = 10 },
    -- World markers 1-8 + clear + request assist (Markers.lua; was the VoidMarkers addon)
    { key = "markers", label = "World markers", kind = "markers", count = 10 },
}

-- Look & behaviour (per character since 1.0.5, see the CharSettings note below). Layout (which bars, where, how big) is per
-- character in VoidBarsCharDB because every character's bars differ.
VB.DEFAULTS = {
    hideBlizzard   = true,   -- hide Blizzard's 8 action bars while VoidBars is on
    showEmpty      = false,  -- draw empty slots (they always show while dragging a spell)
    barOutline     = true,   -- faint outline around each bar section (where to drop things)
    showHotkeys    = true,
    showMacroNames = false,
    showCountdown  = true,   -- cooldown numbers on the buttons
    rangeColor     = true,   -- red icon when the target is out of range
    resourceColor  = true,   -- blue icon when you lack the resource
    procGlow       = true,
    fadeAlpha      = 0,      -- alpha of a faded bar (0 = invisible until mouseover)
}

-- The look above is per character too (CharSettings.lua), like the layout in
-- VoidBarsCharDB. Shared layouts stay account-wide so any character can copy them.
do
    local keys = {}
    for k in pairs(VB.DEFAULTS) do keys[#keys + 1] = k end
    VB.CharSettings.Register(ADDON, "VoidBarsDB", keys)
end

VB.COLOR = {
    accent     = CreateColor(0.00, 0.78, 1.00),  -- Void cyan
    border     = CreateColor(0.00, 0.00, 0.00),
    empty      = CreateColor(0.08, 0.08, 0.10),
    outOfRange = CreateColor(0.95, 0.28, 0.28),
    noResource = CreateColor(0.35, 0.45, 1.00),
    unusable   = CreateColor(0.40, 0.40, 0.40),
    glow       = CreateColor(1.00, 0.85, 0.20),
    hotkey     = CreateColor(0.92, 0.92, 0.95),
}

VB.TEX  = "Interface\\Buttons\\WHITE8X8"
VB.FONT = STANDARD_TEXT_FONT

-- 12.x hands some values back as "secret" in instances; never branch on one.
function VB.IsSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

function VB:Get(key)
    local v = VoidBarsDB and VoidBarsDB[key]
    if v == nil then return self.DEFAULTS[key] end
    return v
end

function VB:Set(key, value)
    VoidBarsDB[key] = value
    if self.RefreshAllButtons then self:RefreshAllButtons() end
    if key == "barOutline" and self.Outline then
        for _, bar in ipairs(self.bars or {}) do self:Outline(bar) end
    end
end

-- Per-character bar config: { enabled, fade, x, y, size, num, offsets = {{x,y}...} }
function VB:BarConfig(key)
    VoidBarsCharDB.bars = VoidBarsCharDB.bars or {}
    VoidBarsCharDB.bars[key] = VoidBarsCharDB.bars[key] or {}
    return VoidBarsCharDB.bars[key]
end

-- Per-bar show rule (cfg.show), applied on top of the hides every bar has (pet
-- battle, vehicle UI). "custom" takes macro conditions, e.g. "[mod:shift] show; hide".
-- Move mode shows every enabled bar so it can be placed.
VB.SHOW_RULES = {
    { value = "always",   label = "Always" },
    { value = "combat",   label = "In combat only" },
    { value = "nocombat", label = "Out of combat only" },
    { value = "custom",   label = "Custom conditions" },
}
function VB:ShowRule(cfg)
    local rule = "show"
    local r = cfg.show
    if r == "combat" then
        rule = "[combat] show; hide"
    elseif r == "nocombat" then
        rule = "[combat] hide; show"
    elseif r == "custom" and type(cfg.showCustom) == "string" and cfg.showCustom:find("%S") then
        rule = cfg.showCustom
    end
    -- Move mode and keybind mode show every bar, but only out of combat: if combat
    -- starts first, the driver falls back to the real rule by itself (drivers can't
    -- be swapped in combat).
    if self.unlocked or self.keybinding then rule = "[nocombat] show; " .. rule end
    return rule
end

function VB:Print(msg)
    print("|cff00c7ffVoidBars|r: " .. msg)
end

-- Work that touches protected frames (positions, visibility, bindings) can't
-- run in combat; queue it for when combat ends.
local afterCombat = {}
function VB:RunOutOfCombat(key, fn)
    if InCombatLockdown() then
        afterCombat[key] = fn
        return false
    end
    fn()
    return true
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        VoidBarsDB = VoidBarsDB or {}
        VoidBarsCharDB = VoidBarsCharDB or {}
        VB:MigrateSmartLists()   -- smart bar lists: account-wide -> per character (SmartBars.lua)
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not VB.initDone then
            VB.initDone = true
            -- Secure buttons can't be created in combat (a /reload mid-fight):
            -- wait for combat to end.
            VB:WaitNote()
            VB:RunOutOfCombat("init", function() VB:Init() end)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        for k, fn in pairs(afterCombat) do
            afterCombat[k] = nil
            fn()
        end
        if VB.Recheck then VB:Recheck() end   -- anything a fight knocked loose goes back
    end
end)

function VB:Init()
    self:CreateBars()
    if self.CreateSmartBars then self:CreateSmartBars() end
    if self.BuildOptions then self:BuildOptions() end
    -- Edit Mode lays Blizzard's bars out during login; read that layout once it
    -- has settled, then take over (first run only -- after that it's ours).
    C_Timer.After(1, function()
        self:WaitNote()
        self:RunOutOfCombat("takeover", function() self:TakeOver() end)
    end)
end

-- Loading in combat leaves Blizzard's bars up until combat ends, which looked like a
-- broken addon (2026-10-29: a hunter's pet still fighting kept him "in combat" with
-- nothing on him). Say so once.
function VB:WaitNote()
    if not InCombatLockdown() or self.waitNoted then return end
    self.waitNoted = true
    self:Print("in combat: your bars switch on when combat ends"
        .. ((UnitExists("pet") and UnitAffectingCombat("pet")) and " (your pet is still fighting)." or "."))
end

-- Backup slash command (the options panel is the main UI): /vbars
SLASH_VOIDBARS1 = "/vbars"
SlashCmdList.VOIDBARS = function(raw)
    raw = strtrim(raw or "")
    local msg = raw:lower()   -- commands are case-insensitive; profile names keep their case
    if msg == "unlock" or msg == "move" then
        VB:SetUnlocked(true)
    elseif msg == "lock" then
        VB:SetUnlocked(false)
    elseif msg == "import" then
        VB:RunOutOfCombat("import", function() VB:ImportBlizzardLayout(true) end)
    elseif msg:match("^save ") then
        VB:SaveProfile(strtrim(raw:sub(6)))
    elseif msg:match("^restore ") then
        VB:RestoreProfile(strtrim(raw:sub(9)))
    elseif msg:match("^preset ") then
        VB:ApplyPreset(strtrim(msg:sub(8)))
    elseif msg == "suggest" then
        VB:ShowSuggestion()
    elseif msg == "bind" or msg == "kb" then
        VB:SetKeybindMode(not VB:IsKeybindMode())
    elseif msg == "bar" or msg == "bars" or msg == "config" then
        VB:OpenBarSettings()
    elseif VB.optionsCategory then
        VB:OpenOptions()
    end
end

-- The game blocks opening the settings window in combat (ADDON_ACTION_BLOCKED from the
-- hub button mid-fight, 2026-10-29): wait, and open it when combat ends.
function VB:OpenOptions()
    if not self.optionsCategory then return end
    if InCombatLockdown() then self:Print("options open when combat ends.") end
    self:RunOutOfCombat("openoptions", function() Settings.OpenToCategory(self.optionsCategory:GetID()) end)
end
