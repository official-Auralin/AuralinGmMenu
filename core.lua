local ADDON, namespace = ...
local L = namespace.L or {}

local LibQTip = LibStub("LibQTip-1.0")
local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local iconLib = LibStub("LibDBIcon-1.0", true)

local floor = math.floor
local max = math.max
local min = math.min
local unpackValues = table.unpack or unpack
local MEDIA_PATH = "Interface\\AddOns\\" .. ADDON .. "\\media\\"
local BROKER_UPDATE_PERIOD = 1
local MIGRATION_VERSION = 1

local DEFAULTS = {
    showIcons = true,
    showKeys = false,
    maxAddons = 10,
    tooltipScale = 1,
    showMemoryDiagnostics = false,
    minimap = {
        hide = false,
        minimapPos = 225,
    },
    migrationVersion = MIGRATION_VERSION,
}

local db = {
    showIcons = true,
    showKeys = false,
    maxAddons = 10,
    tooltipScale = 1,
    showMemoryDiagnostics = false,
    minimap = { hide = false, minimapPos = 225 },
    migrationVersion = MIGRATION_VERSION,
}
local optionsPanel
local settingsCategory
local settingsCategoryID
local optionsWidgets = {}

local tooltipRows = {}
local brokerElapsed = 0
local activeTooltip
local activeTooltipOwner
local popupMenuFrame
local popupButtons = {}
local lastBrokerClickAt = 0

local LeftButtonIcon = " |TInterface\\TUTORIALFRAME\\UI-TUTORIAL-FRAME:13:11:0:-1:512:512:12:66:230:307|t "
local RightButtonIcon = " |TInterface\\TUTORIALFRAME\\UI-TUTORIAL-FRAME:13:11:0:-1:512:512:12:66:333:411|t "
local MiddleButtonIcon = " |TInterface\\TUTORIALFRAME\\UI-TUTORIAL-FRAME:13:11:0:-1:512:512:12:66:127:204|t "

local ICON_FALLBACK_BY_ENTRY = {
    character = MEDIA_PATH .. "green.tga",
    spells = MEDIA_PATH .. "spells.tga",
    professions = MEDIA_PATH .. "talents.tga",
    achievements = MEDIA_PATH .. "achievements.tga",
    questlog = MEDIA_PATH .. "quest.tga",
    guild = MEDIA_PATH .. "social.tga",
    groupfinder = MEDIA_PATH .. "lfg.tga",
    collections = MEDIA_PATH .. "mounts.tga",
    adventurejournal = MEDIA_PATH .. "journal.tga",
    store = MEDIA_PATH .. "social.tga",
    housing = MEDIA_PATH .. "journal.tga",
}

local function colorize(hex, text)
    return string.format("|cff%s%s|r", hex, tostring(text))
end

local function clamp(value, low, high)
    return min(max(value, low), high)
end

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local output = {}
    for key, subValue in pairs(value) do
        output[key] = deepCopy(subValue)
    end

    return output
end

local function mergeDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            mergeDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function showError(message)
    if type(message) ~= "string" or message == "" then
        return
    end

    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage(message, 1, 0.2, 0.2, 1)
    else
        print(string.format("%s: %s", ADDON, message))
    end
end

local function getGlobalText(globalName, fallback)
    local value = _G[globalName]
    if type(value) == "string" and value ~= "" then
        return value
    end
    return fallback
end

local function getBindingLabel(bindingNames)
    if type(GetBindingKey) ~= "function" or type(bindingNames) ~= "table" then
        return nil
    end

    for _, bindingName in ipairs(bindingNames) do
        local primary, secondary = GetBindingKey(bindingName)
        if primary then
            if secondary then
                return string.format("%s/%s", primary, secondary)
            end
            return primary
        end
    end

    return nil
end

local function getNumAddOnsCompat()
    if C_AddOns and type(C_AddOns.GetNumAddOns) == "function" then
        local ok, count = pcall(C_AddOns.GetNumAddOns)
        if ok and type(count) == "number" then
            return count
        end
    end

    if type(GetNumAddOns) == "function" then
        return GetNumAddOns()
    end

    return 0
end

local function getAddOnNameCompat(index)
    if C_AddOns and type(C_AddOns.GetAddOnInfo) == "function" then
        local ok, info1, info2 = pcall(C_AddOns.GetAddOnInfo, index)
        if ok then
            if type(info1) == "table" then
                return info1.name or info1.title or info1.displayName
            end
            if type(info1) == "string" and info1 ~= "" then
                return info1
            end
            if type(info2) == "string" and info2 ~= "" then
                return info2
            end
        end
    end

    if type(GetAddOnInfo) == "function" then
        local name = GetAddOnInfo(index)
        if type(name) == "string" and name ~= "" then
            return name
        end
    end

    return nil
end
local function getAddOnMetadataCompat(key)
    if type(key) ~= "string" or key == "" then
        return nil
    end

    if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
        local ok, value = pcall(C_AddOns.GetAddOnMetadata, ADDON, key)
        if ok and type(value) == "string" and value ~= "" then
            return value
        end
    end

    if type(GetAddOnMetadata) == "function" then
        local ok, value = pcall(GetAddOnMetadata, ADDON, key)
        if ok and type(value) == "string" and value ~= "" then
            return value
        end
    end

    return nil
end

local function isAddOnLoadedCompat(index, name)
    if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, index)
        if ok then
            return loaded and true or false
        end

        if name then
            ok, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
            if ok then
                return loaded and true or false
            end
        end
    end

    if type(IsAddOnLoaded) == "function" then
        local loaded = IsAddOnLoaded(index)
        if loaded then
            return true
        end
        if name then
            return IsAddOnLoaded(name) and true or false
        end
    end

    return false
end

local function updateAddOnMemoryUsageCompat()
    if C_AddOns and type(C_AddOns.UpdateAddOnMemoryUsage) == "function" then
        C_AddOns.UpdateAddOnMemoryUsage()
        return
    end

    if type(UpdateAddOnMemoryUsage) == "function" then
        UpdateAddOnMemoryUsage()
    end
end

local function getAddOnMemoryUsageCompat(index)
    if C_AddOns and type(C_AddOns.GetAddOnMemoryUsage) == "function" then
        return tonumber(C_AddOns.GetAddOnMemoryUsage(index)) or 0
    end

    if type(GetAddOnMemoryUsage) == "function" then
        return tonumber(GetAddOnMemoryUsage(index)) or 0
    end

    return 0
end

local function collectAddOnMemoryStats()
    local records = {}
    local loadedCount = 0
    local totalMB = 0
    local totalAddOns = getNumAddOnsCompat()

    updateAddOnMemoryUsageCompat()

    for index = 1, totalAddOns do
        local name = getAddOnNameCompat(index)
        if name and isAddOnLoadedCompat(index, name) then
            local memoryKB = getAddOnMemoryUsageCompat(index)
            loadedCount = loadedCount + 1
            totalMB = totalMB + (memoryKB / 1024)
            records[#records + 1] = {
                name = name,
                memoryKB = memoryKB,
            }
        end
    end

    table.sort(records, function(a, b)
        if a.memoryKB == b.memoryKB then
            return a.name < b.name
        end
        return a.memoryKB > b.memoryKB
    end)

    return loadedCount, totalMB, records
end

local function formatLatency(value)
    if value <= 75 then
        return colorize("00ff00", value)
    end
    if value < 150 then
        return colorize("ffff00", value)
    end
    return colorize("ff0000", value)
end

local function formatFPS(value)
    if value <= 30 then
        return colorize("ff0000", value)
    end
    if value < 60 then
        return colorize("ffff00", value)
    end
    return colorize("00ff00", value)
end

local function formatMemory(valueMB)
    local formatted = string.format("%.2f mb", valueMB)
    if valueMB <= 2 then
        return colorize("00ff00", formatted)
    end
    if valueMB < 20 then
        return colorize("ffff00", formatted)
    end
    return colorize("ff0000", formatted)
end

local function updateBrokerText(dataobj)
    local homeLatency = 0
    local worldLatency = 0

    if type(GetNetStats) == "function" then
        local _, _, home, world = GetNetStats()
        homeLatency = floor(home or 0)
        worldLatency = floor(world or 0)
    end

    local fps = 0
    if type(GetFramerate) == "function" then
        fps = floor((GetFramerate() or 0) + 0.5)
    end

    dataobj.text = string.format(
        "H:%s W:%s F:%s",
        formatLatency(homeLatency),
        formatLatency(worldLatency),
        formatFPS(fps)
    )
end

local function isFeatureButton(frameName)
    local frame = _G[frameName]
    if type(frame) ~= "table" then
        return false
    end
    if type(frame.Click) ~= "function" then
        return false
    end
    if type(frame.IsForbidden) == "function" and frame:IsForbidden() then
        return false
    end
    return true
end

local function hasAnyButton(candidates)
    for _, frameName in ipairs(candidates) do
        if isFeatureButton(frameName) then
            return true
        end
    end
    return false
end

local function clickFirstButton(candidates)
    for _, frameName in ipairs(candidates) do
        local button = _G[frameName]
        if isFeatureButton(frameName) then
            if InCombatLockdown and InCombatLockdown() and type(button.IsProtected) == "function" and button:IsProtected() then
                return false, L["Unavailable in combat"]
            end
            button:Click()
            return true
        end
    end

    return nil
end

local function normalizeAnchor(anchor)
    if type(anchor) == "table" and type(anchor.GetCenter) == "function" then
        return anchor
    end

    return UIParent
end

local function setMinimapVisibility()
    if not iconLib or not db then
        return
    end

    if db.minimap.hide then
        iconLib:Hide(ADDON)
    else
        iconLib:Show(ADDON)
    end
end

local function openCharacter()
    if type(ToggleCharacter) == "function" then
        ToggleCharacter("PaperDollFrame")
        return true
    end

    local clicked, reason = clickFirstButton({ "CharacterMicroButton" })
    if clicked ~= nil then
        return clicked, reason
    end

    return false, L["Feature unavailable on this client"]
end

local function openPlayerSpells()
    local clicked, reason = clickFirstButton({ "PlayerSpellsMicroButton", "TalentMicroButton", "SpellbookMicroButton" })
    if clicked ~= nil then
        return clicked, reason
    end

    if type(PlayerSpellsUtil) == "table" and type(PlayerSpellsUtil.TogglePlayerSpellsFrame) == "function" then
        PlayerSpellsUtil.TogglePlayerSpellsFrame()
        return true
    end

    if type(ToggleTalentFrame) == "function" then
        ToggleTalentFrame()
        return true
    end

    if type(ToggleSpellBook) == "function" then
        if InCombatLockdown and InCombatLockdown() then
            return false, L["Unavailable in combat"]
        end
        ToggleSpellBook(BOOKTYPE_SPELL)
        return true
    end

    return false, L["Feature unavailable on this client"]
end

local function openProfessions()
    local clicked, reason = clickFirstButton({ "ProfessionsMicroButton", "ProfessionMicroButton" })
    if clicked ~= nil then
        return clicked, reason
    end

    if type(ToggleProfessionsBook) == "function" then
        ToggleProfessionsBook()
        return true
    end

    return false, L["Feature unavailable on this client"]
end

local function openAchievements()
    if type(ToggleAchievementFrame) == "function" then
        ToggleAchievementFrame()
        return true
    end

    local clicked, reason = clickFirstButton({ "AchievementMicroButton" })
    if clicked ~= nil then
        return clicked, reason
    end

    return false, L["Feature unavailable on this client"]
end

local function openQuestLog()
    if type(ToggleQuestLog) == "function" then
        ToggleQuestLog()
        return true
    end

    local clicked, reason = clickFirstButton({ "QuestLogMicroButton" })
    if clicked ~= nil then
        return clicked, reason
    end

    return false, L["Feature unavailable on this client"]
end

local function openGuild()
    if type(ToggleGuildFrame) == "function" then
        ToggleGuildFrame()
        return true
    end

    local clicked, reason = clickFirstButton({ "GuildMicroButton", "CommunitiesMicroButton" })
    if clicked ~= nil then
        return clicked, reason
    end

    return false, L["Feature unavailable on this client"]
end

local function openGroupFinder()
    local clicked, reason = clickFirstButton({ "LFDMicroButton", "GroupFinderMicroButton" })
    if clicked ~= nil then
        return clicked, reason
    end

    if type(PVEFrame_ToggleFrame) == "function" then
        PVEFrame_ToggleFrame()
        return true
    end

    return false, L["Feature unavailable on this client"]
end

local function openCollections()
    local clicked, reason = clickFirstButton({ "CollectionsMicroButton" })
    if clicked ~= nil then
        return clicked, reason
    end

    if type(ToggleCollectionsJournal) == "function" then
        if InCombatLockdown and InCombatLockdown() then
            return false, L["Unavailable in combat"]
        end
        ToggleCollectionsJournal(1)
        return true
    end

    return false, L["Feature unavailable on this client"]
end

local function openAdventureJournal()
    local clicked, reason = clickFirstButton({ "EJMicroButton", "AdventureJournalMicroButton" })
    if clicked ~= nil then
        return clicked, reason
    end

    if type(ToggleEncounterJournal) == "function" then
        ToggleEncounterJournal()
        return true
    end

    return false, L["Feature unavailable on this client"]
end

local function openStore()
    local clicked, reason = clickFirstButton({ "StoreMicroButton" })
    if clicked ~= nil then
        return clicked, reason
    end

    return false, L["Feature unavailable on this client"]
end

local function openHousingDashboard()
    local clicked, reason = clickFirstButton({ "HousingMicroButton", "PlayerHousingMicroButton", "HousingDashboardMicroButton" })
    if clicked ~= nil then
        return clicked, reason
    end

    if type(TogglePlayerHousingFrame) == "function" then
        TogglePlayerHousingFrame()
        return true
    end

    return false, L["Feature unavailable on this client"]
end

local function hasHousingFeature()
    return hasAnyButton({ "HousingMicroButton", "PlayerHousingMicroButton", "HousingDashboardMicroButton" })
        or type(TogglePlayerHousingFrame) == "function"
end

local function hasStoreFeature()
    return hasAnyButton({ "StoreMicroButton" })
end

local function buildMenuEntries()
    local entries = {
        {
            id = "character",
            label = function() return getGlobalText("CHARACTER", "Character") end,
            icon = "green.tga",
            microButtons = { "CharacterMicroButton" },
            binding = { "TOGGLECHARACTER0" },
            isAvailable = function() return type(ToggleCharacter) == "function" or hasAnyButton({ "CharacterMicroButton" }) end,
            onClick = openCharacter,
            blockInCombat = true,
        },
        {
            id = "spells",
            label = function()
                return string.format("%s / %s", getGlobalText("SPELLBOOK", "Spellbook"), getGlobalText("TALENTS", "Talents"))
            end,
            icon = "spells.tga",
            microButtons = { "PlayerSpellsMicroButton", "TalentMicroButton", "SpellbookMicroButton" },
            binding = { "TOGGLETALENTS", "TOGGLESPELLBOOK" },
            isAvailable = function()
                return hasAnyButton({ "PlayerSpellsMicroButton", "TalentMicroButton", "SpellbookMicroButton" })
                    or type(ToggleTalentFrame) == "function"
                    or type(ToggleSpellBook) == "function"
                    or (type(PlayerSpellsUtil) == "table" and type(PlayerSpellsUtil.TogglePlayerSpellsFrame) == "function")
            end,
            onClick = openPlayerSpells,
            blockInCombat = true,
        },
        {
            id = "professions",
            label = function() return getGlobalText("PROFESSIONS", "Professions") end,
            icon = "talents.tga",
            microButtons = { "ProfessionsMicroButton", "ProfessionMicroButton" },
            binding = { "TOGGLEPROFESSIONBOOK" },
            isAvailable = function()
                return hasAnyButton({ "ProfessionsMicroButton", "ProfessionMicroButton" })
                    or type(ToggleProfessionsBook) == "function"
            end,
            onClick = openProfessions,
            blockInCombat = true,
        },
        {
            id = "achievements",
            label = function() return getGlobalText("ACHIEVEMENTS", "Achievements") end,
            icon = "achievements.tga",
            microButtons = { "AchievementMicroButton" },
            binding = { "TOGGLEACHIEVEMENT" },
            isAvailable = function() return type(ToggleAchievementFrame) == "function" or hasAnyButton({ "AchievementMicroButton" }) end,
            onClick = openAchievements,
            blockInCombat = true,
        },
        {
            id = "questlog",
            label = function() return getGlobalText("QUEST_LOG", "Quest Log") end,
            icon = "quest.tga",
            microButtons = { "QuestLogMicroButton" },
            binding = { "TOGGLEQUESTLOG" },
            isAvailable = function() return type(ToggleQuestLog) == "function" or hasAnyButton({ "QuestLogMicroButton" }) end,
            onClick = openQuestLog,
            blockInCombat = true,
        },
        {
            id = "guild",
            label = function() return getGlobalText("GUILD", "Guild") end,
            icon = "social.tga",
            microButtons = { "GuildMicroButton", "CommunitiesMicroButton" },
            binding = { "TOGGLEGUILDTAB" },
            isAvailable = function() return type(ToggleGuildFrame) == "function" or hasAnyButton({ "GuildMicroButton", "CommunitiesMicroButton" }) end,
            onClick = openGuild,
            blockInCombat = true,
        },
        {
            id = "groupfinder",
            label = function() return getGlobalText("GROUP_FINDER", "Group Finder") end,
            icon = "lfg.tga",
            microButtons = { "LFDMicroButton", "GroupFinderMicroButton" },
            binding = { "TOGGLEGROUPFINDER" },
            isAvailable = function() return type(PVEFrame_ToggleFrame) == "function" or hasAnyButton({ "LFDMicroButton", "GroupFinderMicroButton" }) end,
            onClick = openGroupFinder,
            blockInCombat = true,
        },
        {
            id = "collections",
            label = function() return getGlobalText("COLLECTIONS", "Collections") end,
            icon = "mounts.tga",
            microButtons = { "CollectionsMicroButton" },
            binding = { "TOGGLECOLLECTIONS" },
            isAvailable = function() return type(ToggleCollectionsJournal) == "function" or hasAnyButton({ "CollectionsMicroButton" }) end,
            onClick = openCollections,
            blockInCombat = true,
        },
        {
            id = "adventurejournal",
            label = function() return getGlobalText("ADVENTURE_JOURNAL", "Adventure Journal") end,
            icon = "journal.tga",
            microButtons = { "EJMicroButton", "AdventureJournalMicroButton" },
            binding = { "TOGGLEENCOUNTERJOURNAL" },
            isAvailable = function() return type(ToggleEncounterJournal) == "function" or hasAnyButton({ "EJMicroButton", "AdventureJournalMicroButton" }) end,
            onClick = openAdventureJournal,
            blockInCombat = true,
        },
    }

    if hasStoreFeature() then
        entries[#entries + 1] = {
            id = "store",
            label = function() return getGlobalText("BLIZZARD_STORE", "Shop") end,
            icon = nil,
            microButtons = { "StoreMicroButton" },
            binding = nil,
            isAvailable = hasStoreFeature,
            onClick = openStore,
            blockInCombat = true,
        }
    end

    if hasHousingFeature() then
        entries[#entries + 1] = {
            id = "housing",
            label = function() return getGlobalText("HOUSING", "Housing Dashboard") end,
            icon = nil,
            microButtons = { "HousingMicroButton", "PlayerHousingMicroButton", "HousingDashboardMicroButton" },
            binding = { "TOGGLEHOUSING", "TOGGLEHOUSINGDASHBOARD" },
            isAvailable = hasHousingFeature,
            onClick = openHousingDashboard,
            blockInCombat = true,
        }
    end

    return entries
end

local function releaseTooltip()
    if activeTooltip then
        LibQTip:Release(activeTooltip)
        activeTooltip = nil
    end

    activeTooltipOwner = nil
end

local function hideDefaultTooltipFrames()
    if _G.GameTooltip and _G.GameTooltip.Hide then
        _G.GameTooltip:Hide()
    end

    if _G.DataTextTooltip and _G.DataTextTooltip.Hide then
        _G.DataTextTooltip:Hide()
    end
end

local function hidePopupMenu()
    if popupMenuFrame and popupMenuFrame:IsShown() then
        popupMenuFrame:Hide()
    end
end

local function hideAllOverlays()
    releaseTooltip()
    hidePopupMenu()
    hideDefaultTooltipFrames()
end

local function resolveEntryIcon(iconName)
    if type(iconName) ~= "string" or iconName == "" then
        return nil
    end

    if iconName:find("\\", 1, true) then
        return iconName
    end

    return MEDIA_PATH .. iconName
end

local NON_ICON_NAME_HINTS = {
    "shadow",
    "highlight",
    "flash",
    "mask",
    "glow",
}

local ICON_FIELD_PRIORITY_BY_ENTRY = {
    character = { "Icon", "Background", "GetNormalTexture", "Portrait" },
    default = { "Icon", "Background", "Portrait", "GetNormalTexture" },
}

local function hasNameHint(value, hints)
    if type(value) ~= "string" then
        return false
    end

    local lowered = value:lower()
    for _, hint in ipairs(hints) do
        if lowered:find(hint, 1, true) then
            return true
        end
    end

    return false
end

local function isLikelyPlaceholderTexture(textureValue)
    if type(textureValue) ~= "string" then
        return false
    end

    local lowered = textureValue:lower()
    if lowered:find("white8x8", 1, true) then
        return true
    end

    if lowered:find("chatframebackground", 1, true) then
        return true
    end

    return false
end

local function getTexCoordArray(region)
    if type(region) ~= "table" or type(region.GetTexCoord) ~= "function" then
        return nil
    end

    local coords = { region:GetTexCoord() }
    if #coords < 4 then
        return nil
    end

    return coords
end

local function atlasExists(atlasName)
    if type(atlasName) ~= "string" or atlasName == "" then
        return false
    end

    if C_Texture and type(C_Texture.GetAtlasInfo) == "function" then
        local info = C_Texture.GetAtlasInfo(atlasName)
        return info ~= nil
    end

    return true
end

local function buildIconDescriptorFromRegion(region, sourceTag)
    if type(region) ~= "table" then
        return nil
    end

    if type(region.GetObjectType) ~= "function" or region:GetObjectType() ~= "Texture" then
        return nil
    end

    local regionName = nil
    if type(region.GetName) == "function" then
        regionName = region:GetName()
    end
    if hasNameHint(regionName, NON_ICON_NAME_HINTS) then
        return nil
    end

    local atlasName = nil
    if type(region.GetAtlas) == "function" then
        local value = region:GetAtlas()
        if type(value) == "string" and value ~= "" and atlasExists(value) and not hasNameHint(value, NON_ICON_NAME_HINTS) then
            atlasName = value
        end
    end

    if atlasName then
        return {
            mode = "atlas",
            atlas = atlasName,
            texCoords = getTexCoordArray(region),
            source = sourceTag,
        }
    end

    local textureValue = nil
    if type(region.GetTexture) == "function" then
        local value = region:GetTexture()
        if type(value) == "string" or type(value) == "number" then
            textureValue = value
        end
    end

    if not textureValue or isLikelyPlaceholderTexture(textureValue) or hasNameHint(textureValue, NON_ICON_NAME_HINTS) then
        return nil
    end

    return {
        mode = "texture",
        texture = textureValue,
        texCoords = getTexCoordArray(region),
        source = sourceTag,
    }
end

local function getButtonTextureField(button, fieldName)
    local candidate = button[fieldName]
    if type(candidate) ~= "table" then
        return nil
    end

    if type(candidate.GetObjectType) ~= "function" then
        return nil
    end

    if candidate:GetObjectType() ~= "Texture" then
        return nil
    end

    return candidate
end

local function getIconDescriptorFromButton(button, entryID)
    if type(button) ~= "table" then
        return nil
    end

    local priority = ICON_FIELD_PRIORITY_BY_ENTRY[entryID] or ICON_FIELD_PRIORITY_BY_ENTRY.default
    for _, fieldName in ipairs(priority) do
        local region = nil
        local sourceTag = "live_field"

        if fieldName == "GetNormalTexture" then
            if type(button.GetNormalTexture) == "function" then
                region = button:GetNormalTexture()
                sourceTag = "live_normal"
            end
        else
            region = getButtonTextureField(button, fieldName)
        end

        local descriptor = buildIconDescriptorFromRegion(region, sourceTag)
        if descriptor then
            return descriptor
        end
    end

    if type(button.GetRegions) == "function" then
        local regions = { button:GetRegions() }
        for _, region in ipairs(regions) do
            local descriptor = buildIconDescriptorFromRegion(region, "live_region")
            if descriptor then
                return descriptor
            end
        end
    end

    return nil
end

local function getStaticFallbackIconDescriptor(entry)
    if type(entry) ~= "table" then
        return nil
    end

    if entry.icon then
        local iconPath = resolveEntryIcon(entry.icon)
        if iconPath then
            return {
                mode = "texture",
                texture = iconPath,
                source = "fallback_static",
            }
        end
    end

    local fallbackPath = ICON_FALLBACK_BY_ENTRY[entry.id]
    if fallbackPath then
        return {
            mode = "texture",
            texture = fallbackPath,
            source = "fallback_static",
        }
    end

    return nil
end

local function buildTooltipIconMarkup(iconDescriptor)
    if type(iconDescriptor) ~= "table" then
        return nil
    end

    if iconDescriptor.mode == "atlas" and iconDescriptor.atlas then
        if type(CreateAtlasMarkup) == "function" then
            local ok, markup = pcall(CreateAtlasMarkup, iconDescriptor.atlas, 16, 16)
            if ok and type(markup) == "string" and markup ~= "" then
                return markup
            end
        end

        return string.format("|A:%s:16:16|a", iconDescriptor.atlas)
    end

    if iconDescriptor.mode == "texture" and iconDescriptor.texture and iconDescriptor.source == "fallback_static" then
        return string.format("|T%s:16:16:0:0|t", tostring(iconDescriptor.texture))
    end

    return nil
end

local function applyIconDescriptorToTexture(textureRegion, iconDescriptor)
    if type(textureRegion) ~= "table" then
        return false
    end

    if type(textureRegion.SetTexture) == "function" then
        textureRegion:SetTexture(nil)
    end

    if type(textureRegion.SetTexCoord) == "function" then
        textureRegion:SetTexCoord(0, 1, 0, 1)
    end

    if type(iconDescriptor) ~= "table" then
        return false
    end

    if iconDescriptor.mode == "atlas" and iconDescriptor.atlas and type(textureRegion.SetAtlas) == "function" then
        if textureRegion:SetAtlas(iconDescriptor.atlas, true) then
            if type(textureRegion.SetTexCoord) == "function" then
                textureRegion:SetTexCoord(0, 1, 0, 1)
            end
            return true
        end
    end

    if iconDescriptor.mode == "texture" and iconDescriptor.texture and type(textureRegion.SetTexture) == "function" then
        textureRegion:SetTexture(iconDescriptor.texture)
        if type(textureRegion.SetTexCoord) == "function" then
            local coords = iconDescriptor.texCoords
            if type(coords) == "table" and #coords >= 4 then
                textureRegion:SetTexCoord(unpackValues(coords))
            else
                textureRegion:SetTexCoord(0, 1, 0, 1)
            end
        end
        return true
    end

    return false
end

local function resolveEntryDisplayIcon(entry)
    if not entry then
        return nil
    end

    if type(entry.microButtons) == "table" then
        for _, frameName in ipairs(entry.microButtons) do
            local button = _G[frameName]
            if type(button) == "table" then
                if not (type(button.IsForbidden) == "function" and button:IsForbidden()) then
                    local descriptor = getIconDescriptorFromButton(button, entry.id)
                    if descriptor then
                        return descriptor
                    end
                end
            end
        end
    end

    return getStaticFallbackIconDescriptor(entry)
end

local function collectVisibleMenuEntries()
    local visible = {}

    for _, entry in ipairs(buildMenuEntries()) do
        local showEntry = true
        if entry.isAvailable then
            showEntry = entry.isAvailable()
        end

        if showEntry then
            visible[#visible + 1] = entry
        end
    end

    return visible
end

local function canExecuteEntry(entry)
    if entry.blockInCombat and InCombatLockdown and InCombatLockdown() then
        return false, L["Unavailable in combat"]
    end

    return true
end

local function runEntryAction(entry)
    if not entry then
        return false
    end

    local enabled, reason = canExecuteEntry(entry)
    if not enabled then
        showError(reason or L["Unavailable in combat"])
        return false
    end

    local ok, result, actionReason = pcall(entry.onClick)
    if not ok then
        showError(string.format("%s: %s", L["Action failed"], tostring(result)))
        return false
    end

    if result == false then
        showError(actionReason or L["Feature unavailable on this client"])
        return false
    end

    return true
end

local function createPopupButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(24)
    button:RegisterForClicks("AnyUp")

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("LEFT", 8, 0)
    icon:SetSize(16, 16)
    button.icon = icon

    local text = button:CreateFontString(nil, "ARTWORK", "GameTooltipText")
    text:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    text:SetJustifyH("LEFT")
    button.text = text

    local keybind = button:CreateFontString(nil, "ARTWORK", "GameTooltipTextSmall")
    keybind:SetPoint("RIGHT", -8, 0)
    keybind:SetJustifyH("RIGHT")
    button.keybind = keybind

    button:SetScript("OnClick", function(self, buttonName)
        if buttonName == "MiddleButton" then
            hideAllOverlays()
            return
        end

        if runEntryAction(self.entry) then
            hidePopupMenu()
        end
    end)

    return button
end

local function ensurePopupMenuFrame()
    if popupMenuFrame then
        return popupMenuFrame
    end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    popupMenuFrame = CreateFrame("Frame", ADDON .. "PopupMenu", UIParent, template)
    popupMenuFrame:SetFrameStrata("TOOLTIP")
    popupMenuFrame:SetClampedToScreen(true)
    popupMenuFrame:EnableMouse(true)

    if popupMenuFrame.SetBackdrop then
        popupMenuFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        popupMenuFrame:SetBackdropColor(0.05, 0.05, 0.08, 0.96)
        popupMenuFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    end

    local title = popupMenuFrame:CreateFontString(nil, "ARTWORK", "GameTooltipHeaderText")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText(ADDON)
    popupMenuFrame.title = title

    return popupMenuFrame
end

local function showPopupMenu(anchor)
    local frame = ensurePopupMenuFrame()
    local entries = collectVisibleMenuEntries()
    local owner = normalizeAnchor(anchor)

    hideDefaultTooltipFrames()
    releaseTooltip()

    local width = 300
    local topOffset = -30
    local rowSpacing = 2

    for index, entry in ipairs(entries) do
        local button = popupButtons[index]
        if not button then
            button = createPopupButton(frame)
            popupButtons[index] = button
        end

        button.entry = entry
        button:ClearAllPoints()
        if index == 1 then
            button:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, topOffset)
        else
            button:SetPoint("TOPLEFT", popupButtons[index - 1], "BOTTOMLEFT", 0, -rowSpacing)
        end
        button:SetPoint("RIGHT", frame, "RIGHT", -6, 0)

        local enabled, reason = canExecuteEntry(entry)
        local iconDescriptor = resolveEntryDisplayIcon(entry)
        if applyIconDescriptorToTexture(button.icon, iconDescriptor) then
            button.icon:Show()
            button.text:ClearAllPoints()
            button.text:SetPoint("LEFT", button.icon, "RIGHT", 8, 0)
        else
            button.icon:SetTexture(nil)
            button.icon:Hide()
            button.text:ClearAllPoints()
            button.text:SetPoint("LEFT", button, "LEFT", 8, 0)
        end

        local label = entry.label()
        if not enabled and reason then
            label = string.format("%s [%s]", label, reason)
        end
        button.text:SetText(label)

        if enabled then
            button.text:SetTextColor(1, 1, 1)
            button.keybind:SetTextColor(0.95, 0.85, 0.3)
        else
            button.text:SetTextColor(0.6, 0.6, 0.6)
            button.keybind:SetTextColor(0.5, 0.5, 0.5)
        end

        if db.showKeys and entry.binding then
            button.keybind:SetText(getBindingLabel(entry.binding) or "-")
        else
            button.keybind:SetText("")
        end

        button:Show()
    end

    for index = #entries + 1, #popupButtons do
        popupButtons[index]:Hide()
    end

    frame:SetWidth(width)
    frame:SetHeight(40 + (#entries * 26))
    frame:ClearAllPoints()

    frame:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -4)
    frame:Show()

    if frame:GetBottom() and frame:GetBottom() < 4 then
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 4)
    end
end

local function togglePopupMenu(anchor)
    if popupMenuFrame and popupMenuFrame:IsShown() then
        hidePopupMenu()
        return
    end

    showPopupMenu(anchor)
end

local function onTooltipLineClick(_, lineArgs, buttonName)
    if buttonName == "MiddleButton" then
        hideAllOverlays()
        return
    end

    if not lineArgs or not lineArgs.entry then
        return
    end

    if runEntryAction(lineArgs.entry) then
        hideAllOverlays()
    end
end

local function addMemoryDiagnosticsRows(tooltip)
    if not db.showMemoryDiagnostics then
        return
    end

    local loadedCount, totalMB, records = collectAddOnMemoryStats()
    tooltip:AddSeparator()
    tooltip:AddLine(
        colorize("6fe06f", L["Total loaded AddOns:"]),
        colorize("6fe06f", string.format("%d / %.2f mb", loadedCount, totalMB)),
        ""
    )

    if db.maxAddons > 0 then
        local displayCount = min(db.maxAddons, 10, #records)
        for index = 1, displayCount do
            local record = records[index]
            tooltip:AddLine(record.name, string.format("%.2f mb", record.memoryKB / 1024), "")
        end
    end
end

local function buildTooltip(anchor)
    local owner = normalizeAnchor(anchor)

    hidePopupMenu()
    releaseTooltip()
    wipe(tooltipRows)

    local tooltip = LibQTip:Acquire(ADDON .. "Tooltip", 3, "LEFT", "RIGHT", "LEFT")
    if not tooltip then
        return
    end

    activeTooltip = tooltip
    activeTooltipOwner = owner

    tooltip:SmartAnchorTo(owner)
    tooltip:EnableMouse(true)
    tooltip:SetAutoHideDelay(0.2, owner)
    tooltip.OnRelease = function()
        activeTooltip = nil
        activeTooltipOwner = nil
    end
    tooltip:SetScale((db and db.tooltipScale) or DEFAULTS.tooltipScale)

    tooltip:AddHeader(
        colorize("ffd200", ADDON),
        colorize("ffd200", L["Current"]),
        ""
    )
    tooltip:AddSeparator()

    local entries = collectVisibleMenuEntries()
    if #entries == 0 then
        tooltip:AddLine(L["Feature unavailable on this client"], "", "")
    else
        for _, entry in ipairs(entries) do
            local enabled, reason = canExecuteEntry(entry)
            local label = entry.label()
            local iconDescriptor = db.showIcons and resolveEntryDisplayIcon(entry) or nil
            local iconMarkup = buildTooltipIconMarkup(iconDescriptor)
            if not iconMarkup and iconDescriptor and iconDescriptor.source ~= "fallback_static" then
                iconMarkup = buildTooltipIconMarkup(getStaticFallbackIconDescriptor(entry))
            end
            if iconMarkup then
                label = string.format("%s %s", iconMarkup, label)
            end

            local bindText = ""
            if db.showKeys and entry.binding then
                bindText = getBindingLabel(entry.binding) or "-"
            end

            local statusText = ""
            if not enabled and reason then
                statusText = colorize("ff8080", reason)
                label = colorize("999999", label)
                bindText = colorize("999999", bindText)
            end

            local row = tooltip:AddLine(label, bindText, statusText)
            if enabled then
                tooltipRows[row] = {
                    entry = entry,
                    owner = owner,
                }
                tooltip:SetLineScript(row, "OnMouseDown", onTooltipLineClick, tooltipRows[row])
            end
        end
    end

    addMemoryDiagnosticsRows(tooltip)

    tooltip:AddSeparator()
    tooltip:AddLine(
        LeftButtonIcon .. L["Toggle popup menu"],
        RightButtonIcon .. L["Open settings"],
        MiddleButtonIcon .. L["Hide tooltip/menu"]
    )
    tooltip:AddLine(
        colorize("8fb3ff", "H") .. " = Home latency",
        colorize("8fb3ff", "W") .. " = World latency",
        colorize("8fb3ff", "F") .. " = FPS"
    )

    tooltip:Show()
end

local function tryOpenSettings(method, ...)
    if type(method) ~= "function" then
        return false
    end

    local ok = pcall(method, ...)
    return ok
end

local function tryOpenSettingsCategory(category)
    if category == nil then
        return false
    end

    if Settings and type(Settings.OpenToCategory) == "function" then
        if tryOpenSettings(Settings.OpenToCategory, category) then
            return true
        end
        if tryOpenSettings(Settings.OpenToCategory, Settings, category) then
            return true
        end
    end

    if C_Settings and type(C_Settings.OpenToCategory) == "function" then
        if tryOpenSettings(C_Settings.OpenToCategory, category) then
            return true
        end
        if tryOpenSettings(C_Settings.OpenToCategory, C_Settings, category) then
            return true
        end
    end

    return false
end

local function openOptionsPanel()
    if not optionsPanel then
        optionsPanel = _G[ADDON .. "OptionsPanel"]
    end

    if not optionsPanel then
        optionsPanel = CreateFrame("Frame", ADDON .. "OptionsPanel", UIParent)
        optionsPanel.name = ADDON

        local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText(ADDON)

        local notes = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        notes:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
        notes:SetText(getAddOnMetadataCompat("Notes") or "")
    end

    if not settingsCategory and Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, optionsPanel, optionsPanel.name)
        if ok and category then
            local registered = pcall(Settings.RegisterAddOnCategory, category)
            if registered then
                settingsCategory = category
                settingsCategoryID = (category.GetID and category:GetID()) or category.ID
            end
        end
    elseif not settingsCategory and InterfaceOptions_AddCategory and not optionsPanel.__AuralinLegacyCategoryRegistered then
        optionsPanel.__AuralinLegacyCategoryRegistered = true
        pcall(InterfaceOptions_AddCategory, optionsPanel)
    end

    local categoryID = settingsCategoryID
    if not categoryID and settingsCategory then
        categoryID = (settingsCategory.GetID and settingsCategory:GetID()) or settingsCategory.ID
        settingsCategoryID = categoryID
    end

    if categoryID and tryOpenSettingsCategory(categoryID) then
        tryOpenSettingsCategory(categoryID)
        return true
    end

    if settingsCategory and tryOpenSettingsCategory(settingsCategory) then
        return true
    end

    if optionsPanel.name and tryOpenSettingsCategory(optionsPanel.name) then
        return true
    end

    if tryOpenSettingsCategory(optionsPanel) then
        return true
    end

    if InterfaceOptionsFrame_OpenToCategory then
        local ok = pcall(InterfaceOptionsFrame_OpenToCategory, optionsPanel)
        if ok then
            pcall(InterfaceOptionsFrame_OpenToCategory, optionsPanel)
        end
        return ok
    end

    return false
end

local function getClickType(...)
    local totalArgs = select("#", ...)
    for index = 1, totalArgs do
        local arg = select(index, ...)
        if type(arg) == "string" then
            local buttonText = arg:lower()
            if buttonText:find("right", 1, true) then
                return "right"
            end
            if buttonText:find("left", 1, true) then
                return "left"
            end
            if buttonText:find("middle", 1, true) then
                return "middle"
            end
            if buttonText == "2" then
                return "right"
            end
            if buttonText == "1" then
                return "left"
            end
            if buttonText == "3" then
                return "middle"
            end
        elseif type(arg) == "number" then
            if arg == 2 then
                return "right"
            end
            if arg == 1 then
                return "left"
            end
            if arg == 3 then
                return "middle"
            end
        end
    end

    return nil
end

local function shouldIgnoreDuplicateBrokerClick()
    local now = nil
    if type(GetTimePreciseSec) == "function" then
        now = GetTimePreciseSec()
    elseif type(GetTime) == "function" then
        now = GetTime()
    end

    if type(now) ~= "number" then
        return false
    end

    if (now - lastBrokerClickAt) < 0.05 then
        return true
    end

    lastBrokerClickAt = now
    return false
end

local dataobj = ldb:NewDataObject(ADDON, {
    type = "data source",
    icon = MEDIA_PATH .. "icon.tga",
    text = "-",
})

dataobj.OnEnter = function(self)
    local ok, err = pcall(buildTooltip, normalizeAnchor(self))

    if not ok then
        showError("Tooltip error: " .. tostring(err))
    end
end

dataobj.OnLeave = function(self)
    if popupMenuFrame and popupMenuFrame:IsShown() then
        return
    end

    releaseTooltip()
end

dataobj.OnClick = function(...)
    if shouldIgnoreDuplicateBrokerClick() then
        return
    end

    local clickType = getClickType(...)

    local anchor = normalizeAnchor(select(1, ...))

    if clickType == "middle" then
        hideAllOverlays()
        return
    end

    if clickType == "right" then
        hideAllOverlays()
        if not openOptionsPanel() then
            showError("Unable to open settings panel")
        end
        return
    end

    togglePopupMenu(anchor)
end

dataobj.OnMouseUp = dataobj.OnClick

local function refreshOptionsPanel()
    if not db or not optionsWidgets.showIcons then
        return
    end

    optionsWidgets.showIcons:SetChecked(db.showIcons)
    optionsWidgets.showKeys:SetChecked(db.showKeys)
    optionsWidgets.showMinimap:SetChecked(not db.minimap.hide)
    optionsWidgets.showMemoryDiagnostics:SetChecked(db.showMemoryDiagnostics)
    optionsWidgets.maxAddons:SetText(tostring(db.maxAddons))
    optionsWidgets.maxAddons:SetCursorPosition(0)
    optionsWidgets.tooltipScale:SetValue(db.tooltipScale)

    local sliderText = _G[optionsWidgets.tooltipScale:GetName() .. "Text"]
    if sliderText then
        sliderText:SetText(string.format("%s: %.2f", L["Tooltip Scale"], db.tooltipScale))
    end
end

local function sanitizeDatabase()
    db.showIcons = db.showIcons and true or false
    db.showKeys = db.showKeys and true or false
    db.maxAddons = floor(tonumber(db.maxAddons) or DEFAULTS.maxAddons)
    db.maxAddons = clamp(db.maxAddons, -1, 40)
    db.tooltipScale = tonumber(db.tooltipScale) or DEFAULTS.tooltipScale
    db.tooltipScale = clamp(db.tooltipScale, 0.75, 1.5)
    db.showMemoryDiagnostics = db.showMemoryDiagnostics and true or false

    if type(db.minimap) ~= "table" then
        db.minimap = deepCopy(DEFAULTS.minimap)
    end

    if type(db.minimap.hide) ~= "boolean" then
        db.minimap.hide = DEFAULTS.minimap.hide
    end

    if type(db.minimap.minimapPos) ~= "number" then
        db.minimap.minimapPos = DEFAULTS.minimap.minimapPos
    end

    db.migrationVersion = MIGRATION_VERSION
end

local function migrateLegacySettings()
    if type(GMMENU_CFG) ~= "table" then
        return
    end

    if type(GMMENU_CFG.SHOWICON) == "boolean" then
        db.showIcons = GMMENU_CFG.SHOWICON
    end
    if type(GMMENU_CFG.SHOWKEYS) == "boolean" then
        db.showKeys = GMMENU_CFG.SHOWKEYS
    end
    if type(GMMENU_CFG.MAXADDS) == "number" then
        db.maxAddons = floor(GMMENU_CFG.MAXADDS)
    end
    if type(GMMENU_CFG.SCALE) == "number" then
        db.tooltipScale = GMMENU_CFG.SCALE
    end

    db.migrationVersion = MIGRATION_VERSION

    GMMENU_CFG = nil
    GMMENU = nil
end

local function initDatabase()
    AuralinGmMenuDB = AuralinGmMenuDB or {}
    db = AuralinGmMenuDB

    if db.migrationVersion ~= MIGRATION_VERSION and type(GMMENU_CFG) == "table" then
        migrateLegacySettings()
    end

    mergeDefaults(db, deepCopy(DEFAULTS))
    sanitizeDatabase()
end

local function setCheckButtonLabel(checkButton, label)
    if checkButton.Text then
        checkButton.Text:SetText(label)
        return
    end

    local textRegion = _G[checkButton:GetName() .. "Text"]
    if textRegion then
        textRegion:SetText(label)
    end
end

local function createOptionsPanel()
    if optionsPanel then
        return
    end

    optionsPanel = CreateFrame("Frame", ADDON .. "OptionsPanel", UIParent)
    optionsPanel.name = ADDON

    local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(ADDON)

    local subtitle = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetWidth(640)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText(getAddOnMetadataCompat("Notes") or "")

    local showIcons = CreateFrame("CheckButton", ADDON .. "ShowIconsCheck", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    showIcons:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -16)
    setCheckButtonLabel(showIcons, L["Show Icons"])
    showIcons:SetScript("OnClick", function(self)
        db.showIcons = self:GetChecked() and true or false
    end)
    optionsWidgets.showIcons = showIcons

    local showKeys = CreateFrame("CheckButton", ADDON .. "ShowKeysCheck", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    showKeys:SetPoint("TOPLEFT", showIcons, "BOTTOMLEFT", 0, -8)
    setCheckButtonLabel(showKeys, L["Show Bind Keys"])
    showKeys:SetScript("OnClick", function(self)
        db.showKeys = self:GetChecked() and true or false
    end)
    optionsWidgets.showKeys = showKeys

    local showMinimap = CreateFrame("CheckButton", ADDON .. "ShowMinimapCheck", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    showMinimap:SetPoint("TOPLEFT", showKeys, "BOTTOMLEFT", 0, -8)
    setCheckButtonLabel(showMinimap, L["Show Minimap Icon"])
    showMinimap:SetScript("OnClick", function(self)
        db.minimap.hide = not self:GetChecked()
        setMinimapVisibility()
    end)
    optionsWidgets.showMinimap = showMinimap

    local showMemoryDiagnostics = CreateFrame("CheckButton", ADDON .. "ShowMemoryDiagnosticsCheck", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    showMemoryDiagnostics:SetPoint("TOPLEFT", showMinimap, "BOTTOMLEFT", 0, -8)
    setCheckButtonLabel(showMemoryDiagnostics, L["Show Memory Diagnostics"])
    showMemoryDiagnostics:SetScript("OnClick", function(self)
        db.showMemoryDiagnostics = self:GetChecked() and true or false
    end)
    optionsWidgets.showMemoryDiagnostics = showMemoryDiagnostics

    local addonsLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    addonsLabel:SetPoint("TOPLEFT", showMemoryDiagnostics, "BOTTOMLEFT", 4, -20)
    addonsLabel:SetText(colorize("ffff00", L["Number of addons to monitor:"]))

    local maxAddons = CreateFrame("EditBox", ADDON .. "MaxAddonsEditBox", optionsPanel, "InputBoxTemplate")
    maxAddons:SetPoint("TOPLEFT", addonsLabel, "BOTTOMLEFT", 0, -8)
    maxAddons:SetAutoFocus(false)
    maxAddons:SetSize(55, 20)
    maxAddons:SetMaxLetters(3)
    maxAddons:SetScript("OnEnterPressed", function(self)
        local value = tonumber(self:GetText())
        if not value then
            value = db.maxAddons
        end
        value = floor(value)
        value = clamp(value, -1, 40)
        db.maxAddons = value
        self:SetText(tostring(value))
        self:ClearFocus()
    end)
    optionsWidgets.maxAddons = maxAddons

    local addonsHelp = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    addonsHelp:SetPoint("TOPLEFT", maxAddons, "BOTTOMLEFT", 0, -8)
    addonsHelp:SetText(colorize("ffff00", L["positive number for nr.addons, 0 for only header, -1 to disable"]))

    local tooltipScale = CreateFrame("Slider", ADDON .. "TooltipScaleSlider", optionsPanel, "OptionsSliderTemplate")
    tooltipScale:SetPoint("TOPLEFT", addonsHelp, "BOTTOMLEFT", 0, -28)
    tooltipScale:SetWidth(240)
    tooltipScale:SetMinMaxValues(0.75, 1.50)
    tooltipScale:SetValueStep(0.05)
    tooltipScale:SetObeyStepOnDrag(true)
    _G[tooltipScale:GetName() .. "Low"]:SetText("0.75")
    _G[tooltipScale:GetName() .. "High"]:SetText("1.50")
    tooltipScale:SetScript("OnValueChanged", function(self, value)
        value = floor((value * 100) + 0.5) / 100
        db.tooltipScale = value
        local text = _G[self:GetName() .. "Text"]
        if text then
            text:SetText(string.format("%s: %.2f", L["Tooltip Scale"], value))
        end
    end)
    optionsWidgets.tooltipScale = tooltipScale

    local resetButton = CreateFrame("Button", ADDON .. "ResetButton", optionsPanel, "UIPanelButtonTemplate")
    resetButton:SetSize(180, 30)
    resetButton:SetPoint("BOTTOMLEFT", 12, 16)
    resetButton:SetText(_G.RESET_TO_DEFAULT or "Reset to Default")
    resetButton:SetScript("OnClick", function()
        AuralinGmMenuDB = deepCopy(DEFAULTS)
        db = AuralinGmMenuDB
        sanitizeDatabase()
        setMinimapVisibility()
        refreshOptionsPanel()
        ReloadUI()
    end)

    local reloadButton = CreateFrame("Button", ADDON .. "ReloadButton", optionsPanel, "UIPanelButtonTemplate")
    reloadButton:SetSize(180, 30)
    reloadButton:SetPoint("LEFT", resetButton, "RIGHT", 12, 0)
    reloadButton:SetText(_G.RELOADUI or "Reload UI")
    reloadButton:SetScript("OnClick", function()
        ReloadUI()
    end)

    local slashHint = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    slashHint:SetPoint("BOTTOMRIGHT", -16, 20)
    slashHint:SetText(colorize("aaaaaa", L["Open settings with /agmm"]))

    optionsPanel:SetScript("OnShow", refreshOptionsPanel)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(optionsPanel, optionsPanel.name)
        Settings.RegisterAddOnCategory(category)
        settingsCategory = category
        if type(category.GetID) == "function" then
            settingsCategoryID = category:GetID()
        else
            settingsCategoryID = category.ID
        end
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(optionsPanel)
    end
end

local function registerMinimapIcon()
    if not iconLib then
        return
    end

    if iconLib.IsRegistered and iconLib:IsRegistered(ADDON) then
        setMinimapVisibility()
        return
    end

    local ok, err = pcall(iconLib.Register, iconLib, ADDON, dataobj, db.minimap)
    if not ok then
        showError(string.format("LibDBIcon register failed: %s", tostring(err)))
        return
    end

    setMinimapVisibility()
end

local function handleSlashCommand(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    if msg == "reload" then
        ReloadUI()
        return
    end

    if msg == "minimap" then
        db.minimap.hide = not db.minimap.hide
        setMinimapVisibility()
        return
    end

    openOptionsPanel()
end

SLASH_AURALINGMMENU1 = "/agmm"
SLASH_AURALINGMMENU2 = "/auralingmmenu"
SlashCmdList.AURALINGMMENU = handleSlashCommand

local startupFrame = CreateFrame("Frame")
startupFrame:RegisterEvent("PLAYER_LOGIN")
startupFrame:SetScript("OnEvent", function(_, event)
    if event ~= "PLAYER_LOGIN" then
        return
    end

    initDatabase()
    createOptionsPanel()
    registerMinimapIcon()
    refreshOptionsPanel()
    updateBrokerText(dataobj)
end)

local brokerUpdateFrame = CreateFrame("Frame")
brokerUpdateFrame:SetScript("OnUpdate", function(_, elapsed)
    brokerElapsed = brokerElapsed + elapsed
    if brokerElapsed < BROKER_UPDATE_PERIOD then
        return
    end

    brokerElapsed = 0
    updateBrokerText(dataobj)
end)
















