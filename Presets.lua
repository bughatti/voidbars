----------------------------------------------------------------------
-- VoidBars — layout presets: one click arranges every bar for a way of
-- playing. Presets only change VoidBars' layout (which bars show, how many
-- buttons, where); they never touch what's in an action slot, so the
-- "Before preset" profile saved first puts everything back.
--
-- naga7: a 2x7 combat block at bottom center -- keys 1-7 on top (main bar),
-- Shift+1-7 below (bar 2) -- for a Naga-style thumb grid where only 1-7
-- are reachable. Professions left (Consumables above them), Travel right,
-- pet bar (and stance bar)
-- centered above the block. Bars 3-8 off: the
-- smart bars replace them.
----------------------------------------------------------------------
local _, VB = ...

local GAP = 14       -- space between groups
VB.GROUP_GAP = GAP   -- SmartBars keeps side bars this far from the action bars
local SPACING = 4    -- space between buttons in the combat block

local function RowOffsets(n, size, spacing)
    local o = {}
    for i = 1, n do o[i] = { (i - 1) * (size + spacing), 0 } end
    return o
end

-- Width/height a smart bar will have with its current contents.
local function SmartSize(key)
    local cfg = VB:BarConfig(key)
    local size, spacing = cfg.size or 36, cfg.spacing or 3
    local cols = math.max(1, cfg.cols or 12)
    local n = (VB.bars[key] and VB.bars[key].shownCount) or 0
    local usedCols = math.min(cols, math.max(n, 1))
    local rows = math.max(1, math.ceil(n / cols))
    return usedCols * (size + spacing) - spacing, rows * (size + spacing) - spacing
end

VB.PRESETS = {
    naga7 = { label = "Naga: 1-7 + Shift 1-7" },
}

-- Pet and stance bars: smaller buttons, one row each, centered over the combat block
-- and ABOVE the Consumables row (the player, 2026-10-25: before VoidBars had its own
-- pet bar, Blizzard's sat higher and smaller; the preset had put ours at 34px on
-- Consumables' row). x0 / rowW = the block, consTop = Consumables' top edge.
local UTIL_SIZE = 28
local function PlaceUtilityRows(x0, rowW, consTop)
    local ps = UTIL_SIZE
    for i, key in ipairs({ "pet", "stance" }) do
        local c = VB:BarConfig(key)
        local n = #VB.bars[key].buttons
        c.enabled, c.num, c.size = true, n, ps
        c.offsets = RowOffsets(n, ps, 3)
        local w = n * (ps + 3) - 3
        c.x, c.y = math.floor(x0 + (rowW - w) / 2), consTop + i * (GAP + ps)
    end
end

-- One-time (2026-10-25): move pet / stance bars still on the old preset spot (34px,
-- on Consumables' row) to the new one. Bars moved by hand are left alone.
function VB:MigrateUtilityRows()
    if VoidBarsCharDB.utilRowsV2 then return end
    VoidBarsCharDB.utilRowsV2 = true
    local pet, cons, b1 = self:BarConfig("pet"), self:BarConfig("consumables"), self:BarConfig("bar1")
    if not (pet.y and cons.y and b1.x and b1.size and b1.num and self.bars.pet) then return end
    if pet.size ~= 34 or math.abs(pet.y - cons.y) > 10 then return end
    local rowW = b1.offsets and b1.offsets[b1.num] and (b1.offsets[b1.num][1] + b1.size)
        or (b1.num * b1.size + (b1.num - 1) * SPACING)
    PlaceUtilityRows(b1.x, rowW, cons.y)
end

function VB:ApplyPreset(name)
    if InCombatLockdown() then self:Print("can't change the layout in combat.") return end
    if name ~= "naga7" then self:Print(("unknown preset \"%s\"."):format(tostring(name))) return end

    -- Safety net first: the setup from BEFORE the first preset, restorable from
    -- Options. Kept once -- re-applying a preset must not overwrite it with an
    -- already-rearranged layout.
    if not self:Profiles()["Before preset"] then self:SaveProfile("Before preset", true) end
    self:RebuildSmartBars()   -- know how many buttons each smart bar has right now

    local W = UIParent:GetWidth()
    local size = math.max(36, math.min(56, self:BarConfig("bar1").size or 44))
    local rowW = 7 * size + 6 * SPACING
    local x0 = math.floor((W - rowW) / 2)
    local bottom = 40                                   -- bottom edge of the block
    local yTop = bottom + 2 * size + SPACING            -- TOPLEFT y of the top row

    local function Row(key, y)
        local c = self:BarConfig(key)
        c.enabled, c.num, c.size = true, 7, size
        c.offsets = RowOffsets(7, size, SPACING)
        c.cols, c.spacing = 7, SPACING   -- or Bar settings regrids from an old saved shape
        c.x, c.y = x0, y
    end
    Row("bar1", yTop)                     -- keys 1-7
    Row("bar2", yTop - size - SPACING)    -- Shift+1-7
    for _, k in ipairs({ "bar3", "bar4", "bar5", "bar7", "bar8" }) do
        self:BarConfig(k).enabled = false
    end

    -- Travel / Professions at 28px, the size the player picked (2026-10-23).
    self:BarConfig("travel").size = 28
    self:BarConfig("professions").size = 28
    self:RebuildSmartBars()   -- re-measure at the new size

    -- Professions: left of the block, top-aligned
    local pw = SmartSize("professions")
    local prof = self:BarConfig("professions")
    prof.enabled = true
    prof.x, prof.y = x0 - GAP - pw, yTop

    -- Consumables: above Professions (left side). Directly above the block is
    -- where Blizzard's pet bar usually sits, which VoidBars doesn't move yet.
    -- Right edge on the same line as Professions': everything lines up on the middle
    -- and stretches outward (the user, 2026-10-25).
    local cw, ch = SmartSize("consumables")
    local cons = self:BarConfig("consumables")
    cons.enabled = true
    cons.x, cons.y = x0 - GAP - cw, yTop + GAP + ch

    -- Travel: right of the block, top-aligned
    local trav = self:BarConfig("travel")
    trav.enabled = true
    trav.x, trav.y = x0 + rowW + GAP, yTop

    -- Pets (pet classes): above Travel on the right, mirroring Consumables on the left.
    -- Empty -- and hidden -- for classes without pet buttons.
    local _, petH = SmartSize("pets")
    local pets = self:BarConfig("pets")
    pets.enabled = true
    pets.x, pets.y = x0 + rowW + GAP, yTop + GAP + petH

    -- Random (whatever the player drags on): under Travel, mirroring the markers on the left.
    local _, travH = SmartSize("travel")
    local rnd = self:BarConfig("random")
    rnd.enabled, rnd.size = true, 28
    rnd.x, rnd.y = x0 + rowW + GAP, yTop - travH - GAP

    -- Pet bar one row above Consumables' row, stance bar (forms / stealth) above that.
    PlaceUtilityRows(x0, rowW, cons.y)
    VoidBarsCharDB.utilRowsV2 = true   -- already the new spot: no migration

    -- World markers: one row under Professions, right edge on the block's left edge.
    do
        local mk = self:BarConfig("markers")
        local ms = 28
        local n = #self.bars.markers.buttons
        mk.enabled, mk.num, mk.size = true, n, ms
        mk.offsets = RowOffsets(n, ms, 3)
        mk.cols, mk.spacing = n, 3
        local _, ph = SmartSize("professions")
        mk.x = math.floor(x0 - GAP - (n * (ms + 3) - 3))
        mk.y = math.floor(prof.y - ph - GAP)
    end

    -- Bar 6 (extra keybinds such as V) off too: the player plays from the 14
    -- keys only (2026-10-23). Re-enable it per bar in Options if wanted.
    self:BarConfig("bar6").enabled = false

    local bound = self:EnsureBlockBindings()
    self:ApplyAllLayouts()
    self:ApplyVisibility()
    self:ApplyBindings()
    self:RebuildSmartBars()
    self:QueueFullUpdate()
    self:Print(("applied the \"%s\" layout. Your previous setup is saved as profile \"Before preset\" (Options -> VoidBars -> Restore)."):format(
        self.PRESETS[name].label))
    if bound > 0 then
        self:Print(("set %d missing key(s) so 1-7 and Shift+1-7 press the block (Options -> Keybindings to change them)."):format(bound))
    end
end
