----------------------------------------------------------------------
-- VoidBars — world-marker bar (replaces the standalone VoidMarkers addon,
-- same behaviour): /wm 1-8 toggle buttons, clear-all, and a "request assist"
-- button that whispers the group leader. Placing/clearing world markers is
-- hardware-event protected, so the buttons are secure "worldmarker" actions.
-- /vm toggles the bar.
----------------------------------------------------------------------
local _, VB = ...

local NUM = 8
-- World markers use the "GM-raidMarkerN" atlas set, and the /wm index is NOT
-- the atlas index: Blizzard maps them through WORLD_RAID_MARKER_ORDER (icon K
-- is placed by PlaceRaidMarker(WORLD_RAID_MARKER_ORDER[K])). Inverted here so
-- a /wm N button shows the marker it actually drops; refined from the global
-- when the raid-frame code is loaded.
local iconForWM = { 3, 5, 6, 2, 8, 7, 4, 1 }

local function Tip(self, title, cmd, note, checkPlace)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(title)
    if cmd then GameTooltip:AddLine("|cff00ff00" .. cmd .. "|r", 1, 1, 1) end
    if note then GameTooltip:AddLine(note, 0.7, 0.7, 0.7, true) end
    if checkPlace and VB.CanPlaceMarkers then
        local ok, why = VB.CanPlaceMarkers()
        if not ok then GameTooltip:AddLine(why, 1, 0.4, 0.4, true) end
    end
    GameTooltip:Show()
end

----------------------------------------------------------------------
-- Request assist (markers in a group need lead or assist)
----------------------------------------------------------------------
local lastAssistReq = 0

local function GroupLeaderName()
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, rank = GetRaidRosterInfo(i)
            if rank == 2 then return name end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            local u = "party" .. i
            if UnitExists(u) and UnitIsGroupLeader(u) then return GetUnitName(u, true) end
        end
    end
end

local function RequestAssist()
    if not IsInGroup() then VB:Print("you're not in a group.") return end
    if UnitIsGroupLeader("player") then VB:Print("you're the leader -- you can place markers already.") return end
    if IsInRaid() and UnitIsRaidOfficer and UnitIsRaidOfficer("player") then VB:Print("you already have assist.") return end
    if GetTime() - lastAssistReq < 30 then VB:Print("hold on -- you just asked.") return end
    local leader = GroupLeaderName()
    if not leader then VB:Print("couldn't find the group leader.") return end
    lastAssistReq = GetTime()
    SendChatMessage("Could I get raid assist for world markers? (VoidBars)", "WHISPER", nil, leader)
    VB:Print("asked |cffffd700" .. leader .. "|r for assist.")
end

----------------------------------------------------------------------
-- Buttons
----------------------------------------------------------------------
local function Base(bar, name, secure)
    local b = CreateFrame("CheckButton", name, bar,
        secure and "ActionButtonTemplate, SecureActionButtonTemplate" or "ActionButtonTemplate")
    VB.Button.Style(b)
    b.ApplySize = VB.Button.ApplySize
    b.vbEmpty:Hide()
    b.HotKey:SetText("")
    b:HookScript("PostClick", function(self) self:SetChecked(false) end)
    b:HookScript("OnLeave", GameTooltip_Hide)
    return b
end

function VB:CreateMarkerButton(bar, i)
    if type(WORLD_RAID_MARKER_ORDER) == "table" then
        for atlasIdx, wm in pairs(WORLD_RAID_MARKER_ORDER) do iconForWM[wm] = atlasIdx end
    end
    local b
    if i <= NUM then
        b = Base(bar, "VoidBarsMarker" .. i, true)
        b:RegisterForClicks("AnyDown", "AnyUp")
        b:SetAttribute("type", "worldmarker")
        b:SetAttribute("marker", i)
        b:SetAttribute("action", "toggle")   -- place if absent, clear if present
        b.icon:SetAtlas("GM-raidMarker" .. iconForWM[i])
        b.Count:SetText(i)
        b:HookScript("OnEnter", function(self)
            Tip(self, "World Marker " .. i, "/wm " .. i, "Click: place / remove on the ground.", true)
        end)
    elseif i == NUM + 1 then
        b = Base(bar, "VoidBarsMarkerClear", true)
        b:RegisterForClicks("AnyDown", "AnyUp")
        b:SetAttribute("type", "worldmarker")
        b:SetAttribute("action", "clear")   -- no "marker" => clears every world marker
        b.icon:SetAtlas("GM-raidMarker-remove")
        b:HookScript("OnEnter", function(self) Tip(self, "Clear all markers", "/cwm", "Removes every world marker.", true) end)
    else
        b = Base(bar, "VoidBarsMarkerAssist", false)   -- whispering isn't protected
        b:SetScript("OnClick", function(self) self:SetChecked(false) RequestAssist() end)
        b.icon:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon")
        b.icon:SetTexCoord(0, 1, 0, 1)
        b:HookScript("OnEnter", function(self)
            Tip(self, "Request raid assist", nil, "Whispers the leader for assist so you can place world markers.")
        end)
    end
    b.icon:Show()
    return b
end

----------------------------------------------------------------------
-- Dim the marker buttons when the game won't place markers. WoW refuses
-- silently (seen live 2026-10-23: /wm 1 solo did nothing, no error). Rule:
-- in a group, and in a raid also lead or assist. (Party rule to be confirmed
-- in a group test.) Visual only, so it's fine in combat.
----------------------------------------------------------------------
local function CanPlaceMarkers()
    if not IsInGroup() then return false, "Join a group to place world markers." end
    if IsInRaid() and not (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
        return false, "Needs raid lead or assist (use the assist button)."
    end
    return true
end
VB.CanPlaceMarkers = CanPlaceMarkers

function VB:UpdateMarkerUsable()
    local bar = self.bars and self.bars.markers
    if not bar then return end
    local ok = CanPlaceMarkers()
    for i = 1, NUM + 1 do
        local b = bar.buttons[i]
        if b then
            b.icon:SetDesaturated(not ok)
            b.icon:SetAlpha(ok and 1 or 0.4)
        end
    end
end

local usable = CreateFrame("Frame")
for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "PLAYER_ENTERING_WORLD" }) do
    usable:RegisterEvent(e)
end
usable:SetScript("OnEvent", function() VB:UpdateMarkerUsable() end)

-- First time the bar exists: one row, placed where the old VoidMarkers bar was.
function VB:InitMarkersConfig(def)
    local cfg = self:BarConfig(def.key)
    local size, spacing = 28, 3
    cfg.enabled, cfg.num, cfg.size = true, def.count, size
    cfg.offsets = {}
    for i = 1, def.count do cfg.offsets[i] = { (i - 1) * (size + spacing), 0 } end
    local old = _G.VoidMarkersBar
    if old and old:GetLeft() then
        cfg.x, cfg.y = old:GetLeft(), old:GetTop()
    end
end

-- /vm keeps working (show/hide the bar) once the old addon is gone.
function VB:RegisterMarkerSlash()
    if SlashCmdList.VOIDMARKERS then return end   -- old addon still loaded
    SLASH_VOIDBARSMARKERS1 = "/vm"
    SlashCmdList.VOIDBARSMARKERS = function()
        local cfg = VB:BarConfig("markers")
        cfg.enabled = not cfg.enabled
        VB:RunOutOfCombat("visibility", function() VB:ApplyVisibility() end)
        VB:Print("world markers " .. (cfg.enabled and "shown." or "hidden."))
    end
end
