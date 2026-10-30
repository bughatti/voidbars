----------------------------------------------------------------------
-- VoidBars — options panel: Esc -> Options -> AddOns -> VoidBars.
----------------------------------------------------------------------
local _, VB = ...

function VB:BuildOptions()
    if not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
    local category, layout = Settings.RegisterVerticalLayoutCategory("VoidBars")

    local function Check(key, label, tip)
        local s = Settings.RegisterProxySetting(category, "VOIDBARS_" .. key:upper(),
            Settings.VarType.Boolean, label, VB.DEFAULTS[key],
            function() return VB:Get(key) end, function(v) VB:Set(key, v) end)
        Settings.CreateCheckbox(category, s, tip)
    end

    -- Per-bar switches live in the character's layout.
    local function BarCheck(barKey, field, label, tip, default)
        local s = Settings.RegisterProxySetting(category, "VOIDBARS_" .. barKey:upper() .. "_" .. field:upper(),
            Settings.VarType.Boolean, label, default,
            function()
                local v = VB:BarConfig(barKey)[field]
                if v == nil then return default end
                return v
            end,
            function(v)
                VB:BarConfig(barKey)[field] = v
                if field == "enabled" then
                    VB:RunOutOfCombat("visibility", function()
                        VB:ApplyVisibility()
                        VB:ApplyBindings()
                        if VB.unlocked then VB:SetUnlocked(true) end
                    end)
                end
                if field == "inInstances" then   -- smart bar membership changes
                    VB:RunOutOfCombat("smartlayout", function() VB:RebuildSmartBars() end)
                end
            end)
        Settings.CreateCheckbox(category, s, tip)
    end

    local function Button(name, text, onClick, tip)
        if CreateSettingsButtonInitializer then
            layout:AddInitializer(CreateSettingsButtonInitializer(name, text, onClick, tip, true))
        end
    end

    Button("Move bars", "Unlock", function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        VB:SetUnlocked(true)
    end, "Show a handle on every bar so you can drag it. Click \"Lock VoidBars\" at the top of the screen when done.")
    Button("Bar settings", "Open", function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        VB:OpenBarSettings()
    end, "Per bar: on/off, fade, number of buttons, buttons per row, size, spacing, and when it shows (always, in combat, out of combat, or your own macro conditions). Also: move mode -> right-click a bar.")
    Button("Keybind mode", "Bind keys", function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        VB:SetKeybindMode(true)
    end, "Hover a button and press a key (Shift / Ctrl / Alt combos and mouse buttons work). Backspace clears a button's keys, Esc finishes. Same keys as Options -> Keybindings.")
    do
        local s = Settings.RegisterProxySetting(category, "VOIDBARS_PERSPEC",
            Settings.VarType.Boolean, "Separate layout for each specialization", false,
            function() return VB:PerSpecLayout() end,
            function(v) VB:SetPerSpecLayout(v) end)
        Settings.CreateCheckbox(category, s,
            "Each spec remembers its own bar positions, sizes and which bars show. Your spells are already per spec in the game.")
    end
    Button("Copy Blizzard layout", "Re-import", function()
        VB:RunOutOfCombat("import", function() VB:ImportBlizzardLayout(true) end)
    end, "Throw away VoidBars' positions and copy Blizzard's current Edit Mode layout again.")

    -- Profiles: whole bar setup (buttons + layout + keybinds), save / switch back.
    do
        local selected = "Default"
        local s = Settings.RegisterProxySetting(category, "VOIDBARS_PROFILE",
            Settings.VarType.String, "Profile", "Default",
            function() return selected end, function(v) selected = v end)
        local function Options()
            local c = Settings.CreateControlTextContainer()
            local names = {}
            for n in pairs(VB:Profiles()) do names[#names + 1] = n end
            table.sort(names)
            for _, n in ipairs(names) do c:Add(n, n) end
            return c:GetData()
        end
        Settings.CreateDropdown(category, s, Options,
            "Saved bar setups. \"Default\" is what you had when profiles were added.")
        Button("Restore this profile", "Restore", function()
            StaticPopup_Show("VOIDBARS_RESTORE", selected, nil, selected)
        end, "Put back every button, the bar layout and the action-bar keybinds from the selected profile.")
        Button("Save current bars as a profile", "Save as...", function()
            StaticPopup_Show("VOIDBARS_SAVEAS")
        end, "Snapshot what's on your bars right now under a new name (or an existing name to overwrite it).")
        Button("Delete this profile", "Delete", function()
            if selected == "Default" then VB:Print("\"Default\" can't be deleted.") return end
            VB:DeleteProfile(selected)
            VB:Print(("deleted profile \"%s\"."):format(selected))
            selected = "Default"
        end)
    end

    -- Copy another character's bar layout (e.g. make an alt look like your main)
    do
        local pick
        local s = Settings.RegisterProxySetting(category, "VOIDBARS_COPYFROM",
            Settings.VarType.String, "Copy layout from character", "",
            function() return pick or "" end, function(v) pick = v end)
        local function Options()
            local c = Settings.CreateControlTextContainer()
            local names = VB:SharedLayoutNames()
            if #names == 0 then c:Add("", "(log into another character once first)") end
            for _, n in ipairs(names) do c:Add(n, n) end
            return c:GetData()
        end
        Settings.CreateDropdown(category, s, Options,
            "Every character's bar layout is remembered when it logs out. Pick one to copy its positions, sizes and bars here (not its spells).")
        Button("Copy this character's layout", "Copy", function()
            if not pick or pick == "" then VB:Print("pick a character first.") return end
            StaticPopup_Show("VOIDBARS_COPYLAYOUT", pick, nil, pick)
        end)
    end

    Button("Layout: Naga 1-7 + Shift 1-7", "Apply", function()
        VB:ApplyPreset("naga7")
    end, "2x7 combat block at bottom center (keys 1-7 on top, Shift+1-7 below), Professions left with Consumables above them, Travel right. Turns off bars 3-8. Your current setup is saved as profile \"Before preset\" first.")

    Button("Suggested spells for the 14 keys", "Suggest...", function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        VB:ShowSuggestion()
    end, "Fills keys 1-7 and Shift+1-7 from your spells and talents: interrupt on 3, damage on the top row, then defensives, heals, stuns, escapes and mobility on Shift. With VoidSequencer, key 1 is left for it and everything it casts is skipped (and taken off your bars). Shows the plan first; your bars are saved as \"Before suggested\".")

    Check("showHotkeys",    "Show keybinds")
    Check("showCountdown",  "Show cooldown numbers")
    Check("rangeColor",     "Red when out of range")
    Check("resourceColor",  "Blue when out of resource", "Runic Power, Insanity, mana and so on.")
    Check("procGlow",       "Glow when a spell procs")
    Check("showMacroNames", "Show macro names")
    Check("showEmpty",      "Show empty slots", "Empty slots always show while you drag a spell.")
    Check("barOutline",     "Outline bars", "A faint line around each bar, so you can see where to drop spells and items.")
    Check("hideBlizzard",   "Hide Blizzard's action bars", "Takes effect after a /reload.")

    do
        local s = Settings.RegisterProxySetting(category, "VOIDBARS_FADEALPHA",
            Settings.VarType.Number, "Faded bar opacity", VB.DEFAULTS.fadeAlpha,
            function() return VB:Get("fadeAlpha") end, function(v) VB:Set("fadeAlpha", v) end)
        local o = Settings.CreateSliderOptions(0, 1, 0.05)
        o:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v)
            return math.floor(v * 100 + 0.5) .. "%"
        end)
        Settings.CreateSlider(category, s, o, "How visible a faded bar stays out of combat. 0% = hidden until you mouse over it.")
    end

    for _, def in ipairs(VB.BAR_DEFS) do
        BarCheck(def.key, "enabled", "Show " .. def.label, nil, def.key == "bar1")
        BarCheck(def.key, "fade", "Fade " .. def.label .. " out of combat", "Comes back in combat and on mouseover.", false)
    end

    -- Smart bars (fill themselves from your bags)
    local function SmartRefresh()
        VB:RunOutOfCombat("smartlayout", function() VB:RebuildSmartBars() end)
    end
    local function BarSlider(barKey, field, label, default, min, max, step, tip)
        local s = Settings.RegisterProxySetting(category, "VOIDBARS_" .. barKey:upper() .. "_" .. field:upper(),
            Settings.VarType.Number, label, default,
            function() return VB:BarConfig(barKey)[field] or default end,
            function(v) VB:BarConfig(barKey)[field] = v; SmartRefresh() end)
        local o = Settings.CreateSliderOptions(min, max, step)
        o:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        Settings.CreateSlider(category, s, o, tip)
    end
    BarCheck("consumables", "enabled", "Show the Consumables bar",
        "Healthstone, potions, flask, buff food, feast, oil, augment rune (vantus in raids): best current-expansion version of each, from your bags. While leveling also plain food and water, to recover between pulls. Plus a recovery spell you know (Cannibalize, Gift of the Naaru...)", true)
    BarCheck("consumables", "fade", "Fade the Consumables bar out of combat", nil, false)
    BarSlider("consumables", "size", "Consumables button size", 36, 20, 64, 1)
    BarSlider("consumables", "cols", "Consumables buttons per row", 12, 1, 12, 1)
    BarCheck("pets", "enabled", "Show the Pets bar",
        "Pet classes: hunter Call Pet for each stable slot with a pet, Revive / Mend / Dismiss Pet; warlock demon summons; Frost mage Water Elemental. Separate from Blizzard's pet bar (your pet's own abilities). Shift+right-click hides a button.", true)
    BarCheck("pets", "fade", "Fade the Pets bar out of combat", nil, false)
    BarSlider("pets", "size", "Pets button size", 36, 20, 64, 1)
    BarCheck("travel", "enabled", "Show the Travel bar",
        "Hearthstone, class teleport, Teleport Home, Switch Flight Style, random mount, plus your own mounts/toys/items/spells (drag them onto the bar; Shift+right-click removes).", true)
    BarCheck("travel", "fade", "Fade the Travel bar out of combat", nil, false)
    BarCheck("travel", "inInstances", "Show the Travel bar in dungeons and raids", nil, true)
    BarSlider("travel", "size", "Travel button size", 36, 20, 64, 1)
    BarSlider("travel", "cols", "Travel buttons per row", 12, 1, 12, 1)
    Button("Hidden travel buttons", "Show all again", function()
        VB.HiddenSet("travel"); VoidBarsDB.hiddenBy.travel = {}
        SmartRefresh()
    end, "Brings back the automatic travel buttons you Shift+right-clicked away.")
    BarCheck("professions", "enabled", "Show the Professions bar",
        "Your professions' abilities (craft window, Disenchant, Cooking Fire, Fishing...), profession gear in your bags, plus anything you drag onto it (Shift+right-click removes).", true)
    BarCheck("professions", "fade", "Fade the Professions bar out of combat", nil, false)
    BarCheck("professions", "inInstances", "Show the Professions bar in dungeons and raids", nil, true)
    BarSlider("professions", "size", "Professions button size", 36, 20, 64, 1)
    BarSlider("professions", "cols", "Professions buttons per row", 12, 1, 12, 1)
    Button("Hidden profession buttons", "Show all again", function()
        VB.HiddenSet("professions"); VoidBarsDB.hiddenBy.professions = {}
        SmartRefresh()
    end, "Brings back the automatic profession buttons you Shift+right-clicked away.")
    Button("Hidden consumables", "Show all again", function()
        VoidBarsDB.hiddenItems = {}
        VB:Print("all hidden items are back on the smart bars.")
        SmartRefresh()
    end, "Items you Shift+right-clicked off a smart bar come back.")

    Settings.RegisterAddOnCategory(category)
    VB.optionsCategory = category

    -- VoidHub entry (VoidBars has no minimap button of its own).
    -- Left-click: this panel. Right-click: quick menu (suggested keys, move, options).
    VoidHubLaunchers = VoidHubLaunchers or {}
    VoidHubLaunchers.VoidBars = {
        icon = "Interface\\Icons\\Spell_Shadow_Shadesofdarkness",
        onClick = function(button)
            if button == "RightButton" and MenuUtil and MenuUtil.CreateContextMenu then
                MenuUtil.CreateContextMenu(UIParent, function(_, root)
                    root:CreateTitle("VoidBars")
                    root:CreateButton("Suggested spells for my keys", function() VB:ShowSuggestion() end)
                    root:CreateButton(VB.unlocked and "Lock bars" or "Move bars", function() VB:SetUnlocked(not VB.unlocked) end)
                    root:CreateButton("Keybind mode", function() VB:SetKeybindMode(true) end)
                    root:CreateButton("Bar settings", function() VB:OpenBarSettings() end)
                    root:CreateButton("Options", function() VB:OpenOptions() end)
                end)
            else
                VB:OpenOptions()
            end
        end,
    }
end
