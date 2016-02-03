local Addon = CreateFrame("FRAME", "Septuagint");
Addon.nameplateChecker = CreateFrame("FRAME", "SptNameplateChecker");


--NamePlate Table
--eg. key = nameplateFrame, v = guid
local nameplatesTable = {};

--"Localing" most used functions
local strfind = string.find;

--TODO
--For PvP, it's possible to "forget" GUIDs and simply use the player's name (CombatLogEvent vs Nameplate's name). So, there's no need to mouseover.
--make a "for" that runs every X seconds that checks party's/raid's targets, one by one. (Check if it's useful)


-------------------------------------
--
-- Returns the nameplate according with the GUID you give
-- @param #string guid: the guid that you want
-- @return #nameplate : the nameplate frame
--
-------------------------------------
local function getNameplate(guid)
    for frame, frameGUID in pairs(nameplatesTable) do
        if(guid == frameGUID) then
            return frame;
        end
    end
end


-------------------------------------
--
-- Creates/Shows/Edits an icon on the nameplate given using the spellID info.
-- @param #nameplate nameplateFrame: the nameplate
-- @param #integer spellID: the spellID
-- 
-------------------------------------
local function createSpellIcon(nameplateFrame, spellID)
    local name, _, icon, _, _, _, castingTime = GetSpellInfo(spellID);
    castingTime = castingTime/1000;

    if(not nameplateFrame.spellFrame) then
        nameplateFrame.spellFrame = CreateFrame("FRAME", nil, nameplateFrame);
        nameplateFrame.spellFrame.icon = nameplateFrame.spellFrame:CreateTexture();
        nameplateFrame.spellFrame.time = CreateFrame("Cooldown", "myCooldown", nameplateFrame.spellFrame);
    end

    local spellFrame = nameplateFrame.spellFrame;
    spellFrame:SetSize(40, 40)
    spellFrame:SetPoint("BOTTOMLEFT", -40, -20)
    spellFrame.icon:SetAllPoints()
    spellFrame.icon:SetTexture(icon)
    spellFrame.time:SetAllPoints()
    spellFrame.time:SetCooldown(GetTime(), castingTime);
    spellFrame:Show();

    local total = 0;
    spellFrame:SetScript("OnUpdate", function(self, elapsed)
        total = total + elapsed;
        if(total > castingTime) then
            spellFrame:Hide();
            spellFrame:SetScript("OnUpdate", nil);
        end
    end);
end


-------------------------------------
--
-- Removes the spell icon on the nameplate.
-- @param #nameplate nameplateFrame: the nameplate
-- 
-------------------------------------
local function removeSpellIcon(nameplateFrame)
    nameplateFrame.spellFrame:Hide();
end


-------------------------------------
--
-- Get the mouseovered nameplate.
-- @return #nameplate nameplateFrame: the nameplate mouseovered
-- 
-------------------------------------
local function getMouseOverNamePlate()
    local frameTable = {WorldFrame:GetChildren()}
    for num, frame in pairs(frameTable) do
        if strfind(frame:GetName() or "[NONE]", "NamePlate") and select(3, frame:GetRegions()):IsShown() then
            return frame;
        end
    end
end


-------------------------------------
--
-- Get the selected nameplate.
-- @return #nameplate nameplateFrame: the nameplate selected
-- 
-------------------------------------
local function getSelectedNamePlate()
    local frameTable = {WorldFrame:GetChildren()}
    for num, frame in pairs(frameTable) do
        if strfind(frame:GetName() or "[NONE]", "NamePlate") and frame:GetAlpha() == 1 then
            return frame;
        end
    end
end


-------------------------------------
--
-- Function that will be used on HookScript.
-- Hides the nameplate and sets its GUID to "-1".
-- @param #nameplate self: the nameplate
-- 
-------------------------------------
local function nameplateOnHide(self)
    if(self.spellFrame)then
        self.spellFrame:Hide();
    end
    nameplatesTable[self] = -1;
end


--local function searchNamePlates()
--    local frameTable = {WorldFrame:GetChildren()};
--    for num, frame in pairs(frameTable) do
--        if not nameplatesTable[frame] and strfind(frame:GetName() or "[NONE]", "NamePlate") then
--            frame:HookScript("OnHide", nameplateOnHide);
--            nameplatesTable[frame] = -1;
--        end
--    end
--end

--local numChildren = -1;
--AddonNameplateChecker:SetScript("OnUpdate", function(self, elapsed)
--    if(WorldFrame:GetNumChildren() ~= numChildren) then
--        numChildren = WorldFrame:GetNumChildren();
--        searchNamePlates(WorldFrame:GetChildren());
--    end
--end);



local timer = CreateFrame("FRAME");
timer.total = 0;

-------------------------------------
--
-- Addon.nameplateChecked SetScript
-- It checks the nameplates when the player mouseover one.
-- 
-- Handled events:
-- "UPDATE_MOUSEOVER_UNIT"
-- "PLAYER_TARGET_CHANGED"
-- 
-------------------------------------
Addon.nameplateChecker:SetScript("OnEvent", function(self, event, ...)
    if(event == "UPDATE_MOUSEOVER_UNIT" and GetMouseFocus() == WorldFrame) then
        local nameplateMouseOvered = getMouseOverNamePlate();
        local guid = UnitGUID("mouseover");
        if(nameplateMouseOvered and guid) then
            nameplateMouseOvered:HookScript("OnHide", nameplateOnHide);
            nameplatesTable[nameplateMouseOvered] = guid;
        end

    elseif(event == "PLAYER_TARGET_CHANGED" and UnitName("target")) then
        --creating a tiny timer because the alpha needs to be updated. it was giving the last target instead of the actual one
        timer:SetScript("OnUpdate", function(self, elapsed)
            timer.total = timer.total + elapsed;
            if(timer.total > 0.01) then
                timer.total = 0;
                timer:SetScript("OnUpdate", nil);
                local nameplateSelected = getSelectedNamePlate();
                local guid = UnitGUID("target");
                if(nameplateSelected and guid) then
                    nameplateSelected:HookScript("OnHide", nameplateOnHide);
                    nameplatesTable[nameplateSelected] = guid;
                end
            end
        end);
    end
end);

Addon.nameplateChecker:RegisterEvent("UPDATE_MOUSEOVER_UNIT");
Addon.nameplateChecker:RegisterEvent("PLAYER_TARGET_CHANGED");


-------------------------------------
--
-- Addon SetScript
-- It sets the spell icons on the nameplates.
-- 
-- Handled events:
-- "COMBAT_LOG_EVENT_UNFILTERED"
-- 
-------------------------------------
Addon:SetScript("OnEvent", function(self, event, ...)
    local time, type, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellID = ...;
    if(event == "COMBAT_LOG_EVENT_UNFILTERED" and (getNameplate(sourceGUID) or getNameplate(destGUID))) then
        local nameplate = getNameplate(sourceGUID);
        if(type == "SPELL_CAST_START" or type == "SPELL_CAST_SUCCESS") and nameplate then
            createSpellIcon(nameplate, spellID);
        elseif(type == "SPELL_INTERRUPT" and getNameplate(destGUID)) then
            removeSpellIcon(getNameplate(destGUID));
        elseif (type == "SPELL_CAST_FAILED") and nameplate then
            removeSpellIcon(nameplate);
        end
    end
end);

Addon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
