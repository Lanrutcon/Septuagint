local Addon = CreateFrame("FRAME", "Septuagint");
Addon.nameplateChecker = CreateFrame("FRAME", "SptNameplateChecker");


--NamePlate Table
--eg. key = nameplateFrame, v = guid
local nameplatesTable = {};

--"Localing" most used functions
local strfind = string.find;
local bitband = bit.band;

--TODO
--make a "for" that runs every X seconds that checks party's/raid's targets, one by one. (Check if it's useful)


-------------------------------------
--
-- Returns the nameplate according with the GUID you give
-- @param #string guid : the guid that you want
-- @return #nameplate frame : the nameplate frame
--
-------------------------------------
local function getNameplateByGUID(guid)
    for frame, frameGUID in pairs(nameplatesTable) do
        if(guid == frameGUID) then
            return frame;
        end
    end
end


-------------------------------------
--
-- Returns the nameplate according with the name you give
-- Useful for players because their names are unique
-- @param #string name : the name that you want
-- @return #nameplate frame : the nameplate frame
--
-------------------------------------
local function getNameplateByName(name)
    for frame, frameGUID in pairs(nameplatesTable) do
        local _, _, _, nameFont = frame:GetRegions();   --Is more efficient to use select?
        if(name == nameFont:GetText()) then
            return frame;
        end
    end
end


-------------------------------------
--
-- Creates/Shows/Edits a castbar on the nameplate given using the spellID info.
-- @param #nameplate nameplateFrame: the nameplate
-- @param #integer spellID: the spellID
--
-------------------------------------
local function createCastbar(nameplateFrame, spellID)
    local name, _, icon, _, _, _, castingTime = GetSpellInfo(spellID);
    castingTime = castingTime/1000;

    if(not nameplateFrame.castbar) then
        nameplateFrame.castbarFrame = CreateFrame("Frame", nil, nameplateFrame);
        local castbarFrame = nameplateFrame.castbarFrame;
        castbarFrame:SetSize(135, 16);
        castbarFrame:SetPoint("BOTTOM", 0, -15);
        castbarFrame:SetBackdrop({
            bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16,
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3, },
        })

        castbarFrame.castbar = CreateFrame("StatusBar", nil, castbarFrame);
        local castbar = castbarFrame.castbar;

        castbar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
        castbar:GetStatusBarTexture():SetHorizTile(false);
        castbar:SetHeight(10);
        castbar:SetPoint("TOPLEFT", 3, -3);
        castbar:SetPoint("TOPRIGHT", -3, -3);
        castbar:SetStatusBarColor(1,0,0);

        castbar.bg = castbar:CreateTexture(nil, "BACKGROUND");
        castbar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar");
        castbar.bg:SetAllPoints(true);
        castbar.bg:SetVertexColor(0.1, 0.1, 0.1);

        castbarFrame.iconFrame = castbarFrame:CreateTexture();
        castbarFrame.iconFrame:SetSize(20, 20);
        castbarFrame.iconFrame:SetPoint("LEFT", -20, 0);
    end

    nameplateFrame.castbarFrame.iconFrame:SetTexture(icon);

    local castbar = nameplateFrame.castbarFrame.castbar;
    castbar:SetMinMaxValues(0, castingTime);
    castbar:SetValue(0);
    castbar:Show();

    local total, throtle, interval = 0, 0, 0.02;
    nameplateFrame.castbarFrame:SetScript("OnUpdate", function(self, elapsed)
        total = total + elapsed;
        if(total > castingTime) then
            self:Hide();
            self:SetScript("OnUpdate", nil);
        end

        throtle = throtle + elapsed;
        if (throtle > interval) then
            throtle = 0;
            castbar:SetValue(total);
        end
    end);

end


-------------------------------------
--
-- Removes the castbar on the nameplate.
-- @param #nameplate nameplateFrame: the nameplate
--
-------------------------------------
local function removeCastbar(nameplateFrame)
    nameplateFrame.castbarFrame:Hide();
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
        if strfind(frame:GetName() or "[NONE]", "NamePlate") and frame:GetAlpha() == 1  and UnitName("target") then
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
    if(self.castbarFrame)then
        self.castbarFrame:Hide();
    end
    nameplatesTable[self] = -1;
end


-------------------------------------
--
-- Search for nameplates and stores in a table.
-- It's only purpose is to check for players' nameplates
--
-------------------------------------
local function searchNamePlates()
    local frameTable = {WorldFrame:GetChildren()};
    for num, frame in pairs(frameTable) do
        if not nameplatesTable[frame] and strfind(frame:GetName() or "[NONE]", "NamePlate") then
            frame:HookScript("OnHide", nameplateOnHide);
            nameplatesTable[frame] = -1;
        end
    end
end


local numChildren = -1;
-------------------------------------
--
-- Addon.nameplateChecked SetScript OnUpdate
-- Main-engine for nameplate searches.
--
-------------------------------------
Addon.nameplateChecker:SetScript("OnUpdate", function(self, elapsed)
    if(WorldFrame:GetNumChildren() ~= numChildren) then
        numChildren = WorldFrame:GetNumChildren();
        searchNamePlates(WorldFrame:GetChildren());
    end
end);



local timer = CreateFrame("FRAME");
timer.total = 0;
-------------------------------------
--
-- Addon.nameplateChecked SetScript OnEvent
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
-- Addon SetScript OnEvent
-- It sets the spell icons on the nameplates.
--
-- Handled events:
-- "COMBAT_LOG_EVENT_UNFILTERED"
--
-------------------------------------
Addon:SetScript("OnEvent", function(self, event, ...)
    local time, type, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags, _, spellID = ...;
    if(event == "COMBAT_LOG_EVENT_UNFILTERED") then
    
        local isPlayer = bitband(sourceFlags, 0x00000400) == 0x00000400;
        
        if(type == "SPELL_CAST_START" and UnitGUID("target") ~= sourceGUID) then --and nameplate and nameplate ~= getSelectedNamePlate() then
            if isPlayer and getNameplateByName(sourceName) then
                createCastbar(getNameplateByName(sourceName), spellID);
            elseif not isPlayer and getNameplateByGUID(sourceGUID) then
                createCastbar(getNameplateByGUID(sourceGUID), spellID);
            end
        elseif(type == "SPELL_INTERRUPT" and UnitGUID("target") ~= destGUID) then
            if isPlayer and getNameplateByName(destName) then
                removeCastbar(getNameplateByName(destName));
            elseif not isPlayer and getNameplateByGUID(destGUID) then
                removeCastbar(getNameplateByGUID(destGUID));
            end
        end
    end
end);

Addon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
