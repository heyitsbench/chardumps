local chardumps = chardumps;
local dumper = {
  -- each field are entity name
	dump = {},
	dynamicDump = {}, -- taxi, bank, quest, skillspell
};

---
-- @param table options What is saved
function dumper:Dump(options)
  local dump = {};
  local entities = chardumps.entityManager:GetEntities();
  local names = chardumps.entityManager:GetNames();

  local fun, functionName;
  for _, name in ipairs(names) do
    functionName = "Get" .. chardumps:Ucfirst(name) .. "Data";
    fun = self[functionName];
    if fun and options.entities[name] and entities[name] and not entities[name].disable then
      dump[name] = chardumps:TryCall(fun) or {};
    else
      dump[name] = {};
    end
  end

  local dynamicNames = chardumps.entityManager:GetDynamicNames();

  for _, name in ipairs(dynamicNames) do
    if options.entities[name] then
      dump[name] = self:GetDynamicData(name);
    else
      dump[name] = {};
    end
  end

  dump.CHD_FIELD_COUNT = self:GetCounts(dump);

  if options.crypt then
    local json = chardumps.encryption:toJson(dump);
    CHD_CLIENT = b64_encode(json);
  else
    CHD_CLIENT = dump;
  end
  self.dump = dump;

  self:UpdateAllFrames();
end

function dumper:UpdateAllFrames()
  local names = chardumps.entityManager:GetNames();
  for _, name in pairs(names) do
    self:UpdateFrame(name);
  end
end

function dumper:UpdateDynamicAllFrames()
  local names = chardumps.entityManager:GetDynamicNames();
  for _, name in pairs(names) do
    self:UpdateFrame(name);
  end
end

function dumper:UpdateFrame(name)
  local count = self:GetEntityCount(name);
  chardumps.mainFrame:UpdateEntityText(name, count);
  chardumps.mainFrame:UpdateEntityView(name);
end

function dumper:GetEntityCount(name)
	local count = 0;

	local entity = self.dump[name];
	local functionName = "Get" .. chardumps:Ucfirst(name) .. "ItemsCount";
	local fun = self[functionName];

  if type(fun) == "function" then
    count = fun(self);
	else
	  if entity == nil then -- dynamic data?
      local data = self:GetDynamicData(name);
      count = chardumps:GetTableLength(data);
    elseif type(entity) == "table" then
      count = chardumps:GetTableLength(entity);
    end
	end

	return count;
end

---
-- Get entity field
function dumper:GetEntity(name)
  if self.dump[name] ~= nil then
    return self.dump[name];
  end
end

function dumper:Clear()
  self.dump = {};
  self:UpdateAllFrames();
end

function dumper:DeleteEntityData(name)
  self.dump[name] = nil;
  if self.dynamicDump[name] then
    self.dynamicDump[name] = nil;
  end
  self:UpdateFrame(name);
end

function dumper:Init()
  self:Clear();

  local taxi = {};
  for i = 1, chardumps.MAX_NUM_CONTINENT do
    taxi[i] = {};
  end
  self.dynamicDump.taxi = taxi;
end

function dumper:GetAchievementData()
  local L = chardumps:GetLocale();
  local res = {};

  chardumps.log:Message(L.GetAchievement);

  local count = 0;
  local guildCount = 0;
  local personalCount = 0;

  local id, name, points, completed, month, day, year, description, flags, icon, rewardText, isGuildAch;
  local posixtime;

  for i = 1, 20000 do -- TODO: maximum value for 3.4
    status, id, _ --[[name]], _, completed, month, day, year, _ --[[description]], _, _, _, isGuildAch = pcall(GetAchievementInfo, i);

    if status then
      count = count + 1;
      if id and completed then
        if isGuildAch then
          guildCount = guildCount + 1;
        else
          posixtime = time({["year"] = 2000 + year, ["month"] = month, ["day"] = day});
          personalCount = personalCount + 1;
          if posixtime then
            table.insert(res, i, posixtime);
          end
        end
      end
    end
  end

  return res;
end

function dumper:GetActionData()
  local L = chardumps:GetLocale();
  local res = {};

  --[[
  0 Spell
  1 Click
  32 Eq set
  64 Macro
  65 Click macro
  128 Item
  
  companion, equipmentset, flyout, item, macro, spell
  ]]
  -- "equipmentset", "flyout"
  local arrType = {};
  arrType.companion = 0;
  arrType.spell = 0;
  arrType.macro = 64;
  arrType.item = 128;

  chardumps.log:Message(L.GetAction);
  for i = 1, 120 do -- (6 + 4) panels * 12 buttons
    local actionType, id, subType = GetActionInfo(i);
    if actionType and arrType[actionType] then
      local item = {};
      item.T = arrType[actionType];
      item.I = id;
      res[i] = item;
    end
  end

  return res;
end

---
-- @return #number
function dumper:GetBagItemsCount()
  local count = 0;
  local bagData = self.dump.bag;

  if bagData then
    for _, v in pairs(bagData) do
      count = count + #v;
    end
  end

  return count;
end

function dumper:GetBagData()
  local L = chardumps:GetLocale();
  local res = {};

  chardumps.log:Message(L.GetBag);

  for bag = 1, NUM_BAG_SLOTS do
    local nCount = 0;
    local tmpBag = {};
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local itemLink = C_Container.GetContainerItemLink(bag, slot);
      local info = C_Container.GetContainerItemInfo(bag, slot);
      if info then local count = info.stackCount; end

      if itemLink and count then
        local tmpItem = {};
        for id, enchant, gem1, gem2, gem3 in string.gmatch(itemLink,".-Hitem:(%d+):(%d+):(%d+):(%d+):(%d+)") do
          tmpItem = {
            ["I"] = tonumber(id)
          };
          if count > 1 then tmpItem["N"] = count end
          if tonumber(enchant) > 0 then tmpItem["H"] = tonumber(enchant) end
          if tonumber(gem1) > 0 then tmpItem["G1"] = tonumber(gem1) end
          if tonumber(gem2) > 0 then tmpItem["G2"] = tonumber(gem2) end
          if tonumber(gem3) > 0 then tmpItem["G3"] = tonumber(gem3) end
        end
        nCount = nCount + 1;
        table.insert(tmpBag, tmpItem);
      end
    end
    table.insert(res, tmpBag);

    chardumps.log:Message(string.format(L.ScaningBagTotal, bag, nCount));
  end

  return res;
end

---
-- @return #number
function dumper:GetBagItemsCount()
  local bagData = self.dump.bag;
  local count = 0;

  if bagData then
    for _, v in pairs(bagData) do
      count = count + table.getn(v);
    end
  end

  return count;
end

function dumper:GetBankData()
  local L = chardumps:GetLocale();
  local res = {};

  -- NUM_BAG_SLOTS+1 to NUM_BAG_SLOTS+NUM_BANKBAGSLOTS are your bank bags
  res.mainbank = {};
  local itemCount = 0;

  chardumps.log:Message(L.GetBank);
  for i = 40, 74 do -- main bank
    local itemLink = GetInventoryItemLink("player", i)
    if itemLink then
      local count = GetInventoryItemCount("player",i)
      for id, enchant, gem1, gem2, gem3 in string.gmatch(itemLink,".-Hitem:(%d+):(%d+):(%d+):(%d+):(%d+)") do
        local tmpItem = {
          ["I"] = tonumber(id)
        };
        if count > 1 then tmpItem["N"] = count end
        if tonumber(enchant) > 0 then tmpItem["H"] = tonumber(enchant) end
        if tonumber(gem1) > 0 then tmpItem["G1"] = tonumber(gem1) end
        if tonumber(gem2) > 0 then tmpItem["G2"] = tonumber(gem2) end
        if tonumber(gem3) > 0 then tmpItem["G3"] = tonumber(gem3) end

        res.mainbank[i] = tmpItem;
      end
      itemCount = itemCount + 1;
    end
  end
  chardumps.log:Message(string.format(L.ReadMainBankBag, itemCount));

  local j = 1;
  for i = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do -- and 7 bank bags
    res[j] = {};
    local bag = res[j];
    itemCount = 0;
    for slot = 1, C_Container.GetContainerNumSlots(i) do
      local itemLink = C_Container.GetContainerItemLink(i, slot)
      if itemLink then
        local info = C_Container.GetContainerItemInfo(i, slot);
        local count = info.stackCount;
        for id, enchant, gem1, gem2, gem3 in string.gmatch(itemLink, ".-Hitem:(%d+):(%d+):(%d+):(%d+):(%d+)") do
          local tmpItem = {
            ["I"] = tonumber(id)
          };
          if count > 1 then tmpItem["N"] = count end
          if tonumber(enchant) > 0 then tmpItem["H"] = tonumber(enchant) end
          if tonumber(gem1) > 0 then tmpItem["G1"] = tonumber(gem1) end
          if tonumber(gem2) > 0 then tmpItem["G2"] = tonumber(gem2) end
          if tonumber(gem3) > 0 then tmpItem["G3"] = tonumber(gem3) end

          bag[slot] = tmpItem;
        end
        itemCount = itemCount + 1;
      end
    end
    chardumps.log:Message(string.format(L.ScaningBankTotal, j, itemCount));
    i = i + 1;
    j = j + 1;
  end

  return res;
end

function dumper:GetBindData()
  local L = chardumps:GetLocale();
  local res = {};
  local bindings = chardumps.bindings;

  chardumps.log:Message(L.GetBind);
  for i = 1, GetNumBindings() do
    local commandName, binding1, binding2 = GetBinding(i);
    if (binding1 or binding2) and (bindings[commandName]) then
      table.insert(res, {commandName, binding1, binding2});
    end
  end

  return res;
end

--[[
CanShowAchievementUI - Returns whether the Achievements UI should be enabled
GetAchievementCriteriaInfo - Gets information about criteria for an achievement or data for a statistic
GetAchievementInfo - Gets information about an achievement or statistic
GetAchievementLink - Returns a hyperlink representing the player's progress on an achievement
GetAchievementNumRewards - Returns the number of point rewards for an achievement (currently always 1)
GetAchievementReward - Returns the number of achievement points awarded for earning an achievement
GetCategoryInfo - Returns information about an achievement/statistic category
GetCategoryNumAchievements - Returns the number of achievements/statistics to display in a category
GetNumComparisonCompletedAchievements - Returns the number of achievements earned by the comparison unit
GetNumCompletedAchievements - Returns the number of achievements earned by the player
GetStatistic - Returns data for a statistic that can be shown on the statistics tab of the achievements window
GetStatisticsCategoryList - Returns a list of all statistic categories
GetTotalAchievementPoints - Returns the player's total achievement points earned
HasCompletedAnyAchievement - Checks if the player has completed at least 1 achievement
SetAchievementComparisonUnit - Enables comparing achievements/statistics with another player
--]]
function dumper:GetCriteriasData()
  local L = chardumps:GetLocale();
  local res = {};

  local categories = GetCategoryList(); --  A list of achievement category IDs (table)

  chardumps.log:Message(L.GetCriterias);
  for k, categoryId in ipairs(categories) do
    local numItems, numCompleted = GetCategoryNumAchievements(categoryId);
    for i = 1, numItems do
      -- achievementID, name, points, completed, Month, Day, Year, description, flags, _, rewardText, isGuildAch = GetAchievementInfo(categoryId, i);
      local achievementId, name, _, completed = GetAchievementInfo(categoryId, i);
      if achievementId then
        for j = 1, GetAchievementNumCriteria(achievementId) do
          -- description, type, completedCriteria, quantity, requiredQuantity, characterName,
          -- flags, assetID, quantityString, criteriaID = GetAchievementCriteriaInfo(achievementID, j);
          local _, _, _, quantity, _, _, _, _, _, criteriaID = GetAchievementCriteriaInfo(achievementId, j);
          if criteriaID and quantity > 0 then
            table.insert(res, criteriaID, quantity);
          end
        end
      end
    end
  end

  return res;
end

function dumper:GetCritterData()
  local L = chardumps:GetLocale();
  local res = {};

  chardumps.log:Message(L.GetCritter);
  for i = 1, C_PetJournal.GetNumPets() do
    local _, speciesID, owned = C_PetJournal.GetPetInfoByIndex(i);
    if owned == true then
      res[i] = speciesID;
    else
      break;
    end
  end
  table.sort(res);

  return res;
end

---
-- @return #table
function dumper:GetCurrencyDataReal()
  local res = {};
  local i = 1;
  while true do
    local name, isHeader = GetCurrencyListInfo(i);
    if (not name) then
      break;
    end
    if isHeader then
      ExpandCurrencyList(i, 1);
    end
    i = i + 1;
  end

  local tCurrency = {};
  local patchVersion = chardumps:GetPatchVersion();
  if patchVersion == 3 then
    tCurrency = {
      121, 122, 103, 42, 241, 390, 81, 61, 384, 386, 221, 341, 101,
      301, 102, 123, 392, 321, 395, 161, 124, 385, 201, 125, 126
    };
  elseif patchVersion == 4 then
    tCurrency = {
      789, 241, 390, 61, 515, 398, 384, 697, 81, 615, 393, 392, 361,
      402, 395, 738, 754, 416, 677, 752, 614, 400, 394, 397, 676, 777,
      401, 391, 385, 396, 399, 776
    };
  end

  if patchVersion == 3 then
    for i = 1, GetCurrencyListSize() do
      -- name, isHeader, isExpanded, isUnused, isWatched, count, extraCurrencyType, icon, itemID = GetCurrencyListInfo(index)
      local _, isHeader, _, _, _, count, _, _, itemID = GetCurrencyListInfo(i);
      if (not isHeader) and itemID and (count > 0) then
        table.insert(res, itemID, count);
      end
    end
  elseif patchVersion == 4 then
    for _, currencyId in ipairs(tCurrency) do
      -- name, amount, texturePath, earnedThisWeek, weeklyMax, totalMax, isDiscovered = GetCurrencyInfo(id)
      local name, amount, _, _, _, _, isDiscovered = GetCurrencyInfo(currencyId);
      if name and isDiscovered and amount > 0 then
        table.insert(res, currencyId, amount);
      end
    end
  end

  return res;
end

function dumper:GetCurrencyData()
  local L = chardumps:GetLocale();

  chardumps.log:Message(L.GetCurrency);

  return dumper:GetCurrencyDataReal();
end

function dumper:GetGlobalData()
  local res = {};
  local L = chardumps:GetLocale();

  chardumps.log:Message(L.GetGlobal);

  res.locale       = GetLocale();
  res.realm        = GetRealmName();
  res.realmlist    = GetCVar("realmList");
  local _, build   = GetBuildInfo();
  res.clientbuild  = tonumber(build);
  res.addonversion = chardumps:GetVersion();
  res.createtime   = time();
  res.luaversion   = _VERSION;

  return res;
end

---
-- @return #number
function dumper:GetGlyphItemsCount()
  local glyphData = self.dump.glyph;
  local count = 0;

  if glyphData then
    count = count + chardumps:GetTableLength(glyphData[1]);
    count = count + chardumps:GetTableLength(glyphData[2]);
  end

  return count;
end

function dumper:GetGlyphData()
  local L = chardumps:GetLocale();
  local res = { {}, {} };
  local items = {};
  local numGlyphSlot = 0;
  --[[
  The major glyph at the top of the user interface (level 15)
  The minor glyph at the bottom of the user interface (level 15)
  The minor glyph at the top left of the user interface (level 30)
  The major glyph at the bottom right of the user interface (level 50)
  The minor glyph at the top right of the user interface (level 70)
  The major glyph at the bottom left of the user interface (level 80)
  --]]
  chardumps.log:Message(L.GetPlyph);

  local moreWow3 = chardumps:GetPatchVersion() > 3;
  if moreWow3 then
    for i = 1, GetNumGlyphs() do
      -- name, glyphType, isKnown, icon, castSpell = GetGlyphInfo(index);
      -- glyphType: 1 for minor glyphs, 2 for major glyphs, 3 for prime glyphs (number)
      local name, glyphType, isKnown, icon, castSpell = GetGlyphInfo(i);
      if isKnown and castSpell then
        table.insert(items, {["T"] = glyphType, ["I"] = castSpell});
      end
    end
    numGlyphSlot = NUM_GLYPH_SLOTS;
    res.items = items;
  else
    numGlyphSlot = 6; -- GetNumGlyphSockets always returns 6 in 3.3.5a?
  end

  for talentGroup = 1,2 do
    local glyphs = res[talentGroup];
    for socket = 1, numGlyphSlot do
      -- enabled, glyphType, glyphTooltipIndex, glyphSpell, icon = GetGlyphSocketInfo(socket, talentGroup)
      local enabled, glyphType, glyphSpell;
      if moreWow3 then
        enabled, glyphType, _, glyphSpell = GetGlyphSocketInfo(socket, talentGroup);
      else
        enabled, glyphType, glyphSpell = GetGlyphSocketInfo(socket, talentGroup);
      end
      if enabled and glyphType and glyphSpell then
        table.insert(glyphs, {["T"] = glyphType, ["I"] = glyphSpell});
      end
    end
  end

  return res;
end

function dumper:GetEquipmentData()
  local L = chardumps:GetLocale();
  local res = {};
  local equip;

  chardumps.log:Message(L.GetEquipment);
  for i = 0, C_EquipmentSet.GetNumEquipmentSets() do
    local name, icon = C_EquipmentSet.GetEquipmentSetInfo(i);
    if name then
      equip = {};
      equip["items"] = C_EquipmentSet.GetItemIDs(i); -- return table 1..19
      equip["name"] = name;
      res[i] = equip;
    end
  end

  return res;
end

function dumper:GetInventoryData()
  local L = chardumps:GetLocale();
  local res = {};
  local index = 24;

  chardumps.log:Message(L.GetInventory);
  -- 1..19 equipped items +
  -- 20-23 Equipped Bags +
  -- 24-39 Main Backpack +
  -- 40-67 Main Bank
  -- 68-74 Bank Bags
  -- 86-117 Keys in Keyring +

  local count = 0;

  for i = 1, 23 do
    local itemLink = GetInventoryItemLink("player", i);
    if itemLink then
      itemCount = GetInventoryItemCount("player", i);
      for id, enchant, gem1, gem2, gem3 in string.gmatch(itemLink,".-Hitem:(%d+):(%d+):(%d+):(%d+):(%d+)") do 
        local tmpItem = {
          ["I"] = tonumber(id)
        };
        if itemCount > 1 then tmpItem["N"] = itemCount end
        if tonumber(enchant) > 0 then tmpItem["H"] = tonumber(enchant) end
        if tonumber(gem1) > 0 then tmpItem["G1"] = tonumber(gem1) end
        if tonumber(gem2) > 0 then tmpItem["G2"] = tonumber(gem2) end
        if tonumber(gem3) > 0 then tmpItem["G3"] = tonumber(gem3) end

        res[i] = tmpItem;
      end
    end
  end

  local container = 0;
  for slot = 1, C_Container.GetContainerNumSlots(container) do
    local itemLink = C_Container.GetContainerItemLink(container, slot);
    if itemLink then
      local info = C_Container.GetContainerItemInfo(container, slot);
      local itemCount = info.stackCount;
      for id, enchant, gem1, gem2, gem3 in string.gmatch(itemLink, ".-Hitem:(%d+):(%d+):(%d+):(%d+):(%d+)") do 
        local tmpItem = {
          ["I"] = tonumber(id)
        };
        if itemCount > 1 then tmpItem["N"] = itemCount end
        if tonumber(enchant) > 0 then tmpItem["H"] = tonumber(enchant) end
        if tonumber(gem1) > 0 then tmpItem["G1"] = tonumber(gem1) end
        if tonumber(gem2) > 0 then tmpItem["G2"] = tonumber(gem2) end
        if tonumber(gem3) > 0 then tmpItem["G3"] = tonumber(gem3) end

        res[index] = tmpItem;
      end
    end
    index = index + 1;
  end

  container = -2;
  index = 86;
  for slot = 1, C_Container.GetContainerNumSlots(container) do
    local itemLink = C_Container.GetContainerItemLink(container, slot);
    if itemLink then
      local id = C_Container.GetContainerItemID(container, slot);
      local info = C_Container.GetContainerItemInfo(container, slot);
      local itemCount = info.stackCount;
      local tmpItem = {
        ["I"] = tonumber(id)
      };
      if itemCount > 1 then tmpItem["N"] = itemCount end
      res[index] = tmpItem;
    end
    index = index + 1;
  end

  -- Add main bank
  local bankData = dumper:GetDynamicData("bank");
  if bankData.mainbank then
    for i = 40, 74 do
      if bankData.mainbank[i] then
        res[i] = bankData.mainbank[i];
      end
    end
  end

  return res;
end

function dumper:GetMountData()
  local L = chardumps:GetLocale();
  local res = {};

  chardumps.log:Message(L.GetMount);

  local mountIDs = C_MountJournal.GetMountIDs();
  for i = 1, #mountIDs do
    local _, spellID, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(i);
    if isCollected == true then
      res[i] = spellID;
    end
  end
  table.sort(res);

  return res;
end

function dumper:GetPvpCurrency(currency)
  local currency = dumper:GetCurrencyDataReal();
  local res = {honor = 0, ap = 0, cp = 0};

  for id, count in pairs(currency) do
    if (id == 392) or (id == 43308) then -- 392 currency_id of honor, 43308 item_id of honor
      res.honor = count;
    elseif id == 43307 then -- 43307 arena points id
      res.ap = count;
    elseif id == 390 then -- 390 Conquest Points
      res.cp = count;
    end
  end

  return res;
end

function dumper:GetPlayerData()
  local res  = {};
  local L = chardumps:GetLocale();
  local pvpCurrency = dumper:GetPvpCurrency();
  local currentMap = C_Map.GetBestMapForUnit("player");
  local currentPosition = C_Map.GetPlayerMapPosition(currentMap, "player");

  chardumps.log:Message(L.GetPlayer);

  res.name             = UnitName("player");
  local _, class       = UnitClass("player");
  res.class            = class;
  res.level            = UnitLevel("player");
  local _, race        = UnitRace("player");
  res.race             = race;
  res.gender           = UnitSex("player");
  local honorableKills = GetPVPLifetimeStats()
  res.kills            = honorableKills;
  res.money            = GetMoney(); -- convert to gold
  if type(GetNumTalentGroups) == "function" then
    res.specs            = GetNumTalentGroups();
  end
  if type(GetActiveSpecGroup) == "function" then
    res.active_spec = GetActiveSpecGroup();
  end
  res.health           = UnitHealth("player");
  res.mana             = UnitPower("player", 0);
  res.honor            = pvpCurrency.honor;
  res.ap               = pvpCurrency.ap;
  res.cp               = pvpCurrency.cp;
  res.hearth           = GetBindLocation();
  res.map              = currentMap;
  res.position         = currentPosition;
  res.orientation      = GetPlayerFacing();

  return res;
end

function dumper:GetPetData()

end

function dumper:GetPMacroData()
  local L = chardumps:GetLocale();
  local res = {};

  chardumps.log:Message(L.GetMacro);
  local count = 1;
  local _, numCharacterMacros = GetNumMacros();
  local nIconPos = string.len("Interface\\Icons\\") + 1;
  for i = 36 + 1, 36 + numCharacterMacros do
    local name, texture, body = GetMacroInfo(i);
    texture = string.sub(texture, nIconPos);
    res[count] = {["N"] = name, ["T"] = texture, ["B"] = body};
    count = count + 1;
  end

  return res;
end

---
-- For patch < 5.0.4 call QueryQuestsCompleted before
-- @return #table
function dumper:GetQuestDataReal()
  local L = chardumps:GetLocale();
  local questIds = self:GetDynamicData("quest");
  GetQuestsCompleted(questIds);
  self:SetDynamicData("quest", questIds);

  chardumps.log:Message(L.GetQuest);
  chardumps.log:Message(chardumps:GetTableLength(questIds));

  return questIds;
end

function dumper:GetQuestData()
  local L = chardumps:GetLocale();
  local res = {};
  local questIds = dumper:GetDynamicData("quest");

  chardumps.log:Message(L.GetQuest);

  for k, _ in pairs(questIds) do
    table.insert(res, k);
  end
  sort(res);

  return res;
end

function dumper:GetQuestlogData()
  local L = chardumps:GetLocale();
  local res = {};
  local numEntries, numQuests = GetNumQuestLogEntries();

  chardumps.log:Message(L.GetQuestlog);
  local j = 1;
  for i = 1, numEntries do
    local _, _, _, _, isHeader, isCollapsed, isComplete, isDaily, questID = GetQuestLogTitle(i);
    local link, _, charges = GetQuestLogSpecialItemInfo(i);
    -- - 1 - The quest was failed
    --   1 - The quest was completed
    -- nil - The quest has yet to reach a conclusion
    -- questID, isComplete, itemID
    if isHeader == nil then
      if isComplete ~= 1 then
        isComplete = 0;
      end
      local itemID = 0;
      if link then
        itemID = tonumber(strmatch(link, "Hitem:(%d+)"));
      end
      res[j] = {["Q"] = questID, ["B"] = isComplete, ["I"] = itemID};
      j = j + 1;
    end
  end
  table.sort(res, function(e1, e2) return e1.Q < e2.Q end);

  return res;
end

function dumper:GetReputationData()
  local L = chardumps:GetLocale();
  local res = {};
  local tblRep = {};

  chardumps.log:Message(L.GetReputation);

  ExpandAllFactionHeaders();
  for i = 1, GetNumFactions() do
    local name = GetFactionInfo(i);
    tblRep[name] = true;
  end

  for i = 1, 1160 do -- TODO: maximum 1160 for 3.3.5a
    local name, _, _, _, _, barValue, atWarWith, canToggleAtWar, isHeader, _, _, isWatched = GetFactionInfoByID(i);
    if name and tblRep[name] then
      local flags = 1;
      if canToggleAtWar and atWarWith then
        flags = bit.bor(1, 2);
      end
      table.insert(res, {["I"] = i, ["V"] = barValue, ["F"] = flags});
    end
  end

  return res;
end

function dumper:GetSkillData()
  local L = chardumps:GetLocale();
  local res = {};

  if chardumps:GetPatchVersion() > 3 then
    return res;
  end

  local i = 1;
  while true do
    local name, isHeader = GetSkillLineInfo(i);
    if not name then
      break;
    end
    if isHeader then
      ExpandSkillHeader(i, 1);
    end
    i = i + 1;
  end

  chardumps.log:Message(L.GetSkill);
  for i = 1, GetNumSkillLines() do
    local skillName, _, _, skillRank, _, _, skillMaxRank = GetSkillLineInfo(i);
    if skillName and (skillRank > 0) and (skillMaxRank > 0) then
      table.insert(res, {["N"] = skillName, ["R"] = skillRank, ["M"] = skillMaxRank});
    end
  end
  table.sort(res, function(e1, e2) return e1.N < e2.N end);

  return res;
end

function dumper:GetSkillspellData()

end

function dumper:GetSpellData()
  local L = chardumps:GetLocale();
  local res = {};

  chardumps.log:Message(L.GetSpell);

  for i = 1, MAX_SKILLLINE_TABS do
    local name, _, offset, numSpells = GetSpellTabInfo(i);
    if not name then
      break
    end
    for j = offset + 1, offset + numSpells do
      local spellLink = GetSpellLink(j, BOOKTYPE_SPELL);
      if spellLink then
        local spellid = tonumber(strmatch(spellLink, "Hspell:(%d+)"));
        if spellid > 0 then
          table.insert(res, spellid, i);
        end
      end
    end
  end
  table.sort(res, function (v1, v2) return v1[1] < v2[1] end);

  return res;
end

function dumper:GetStatisticData()
  local L = chardumps:GetLocale();
  local res = {};
  local categories = GetStatisticsCategoryList();

  chardumps.log:Message(L.GetStatistic);
  for _, categoryId in ipairs(categories) do
    -- numItems, numCompleted = GetCategoryNumAchievements(categoryId);
    local numItems = GetCategoryNumAchievements(categoryId);
    for i = 1, numItems do
      -- statisticID, name, points, completed, Month, Day, Year,
      -- description, flags, _, rewardText, isGuildAch = GetAchievementInfo(categoryId, i);
      local statisticID, name, points, completed = GetAchievementInfo(categoryId, i);
      local criteriaCount = GetAchievementNumCriteria(statisticID);
      if criteriaCount > 0 then
        local _, _, completedCriteria, quantity, _, _, _, _, _, criteriaID = GetAchievementCriteriaInfo(statisticID, 1);
        if criteriaID and completedCriteria and quantity > 0 then
          table.insert(res, criteriaID, quantity);
        end
      end
    end
  end

  return res;
end

---
-- @return #number
function dumper:GetTalentItemsCount()
	local count = 0;
	local talentData = self.dump.talent;

  if talentData then
	  count = count + chardumps:GetTableLength(talentData[1]);
	  count = count + chardumps:GetTableLength(talentData[2]);
	end

	return count;
end

function dumper:GetTalentData()
  local L = chardumps:GetLocale();
  local res = {};
  local specTalentSpell, numTalents;
  local name, _, tier, column, rank, maxRank;
  local talentLink;
  local specTalent;

  chardumps.log:Message(L.GetTalent);
  for specNum = 1,2 do
    specTalent = {};
    for tabIndex = 1,5 do -- GetNumTalentTabs() always return  3???
      if type(GetNumTalents) ~= "function" then
        break;
      end
      numTalents = GetNumTalents(tabIndex, false, false);
      if (numTalents == nil) or (numTalents == 0) then
        break
      end
      -- name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq, previewRank, meetsPreviewPrereq = GetTalentInfo(tabIndex, talentIndex, inspect, pet, talentGroup);
      for i = 1, numTalents do
        name, _, tier, column, rank, maxRank = GetTalentInfo(tabIndex, i, false, false, specNum);
      -- link = GetTalentLink(tabIndex, talentIndex, inspect, pet, talentGroup)
      talentLink = GetTalentLink(tabIndex, i, false, false, specNum);

      local talentId = tonumber(strmatch(talentLink, "Htalent:(%d+)"));
      if (rank ~= nil) and (rank > 0) and (talentId > 0) then
        table.insert(specTalent, talentId, rank);
      end

      end
    end

    table.sort(specTalent, function (v1, v2) return v1.I < v2.I end);

    res[specNum] = specTalent;
  end

  return res;
end

function dumper:GetTaxiData()

end

function dumper:GetTitleData()
  local L = chardumps:GetLocale();
  local res = {};

  chardumps.log:Message(L.GetTitles);
  for i = 1, GetNumTitles() do
    if IsTitleKnown(i) == true then
      table.insert(res, i);
    end
  end

  return res;
end

function dumper:GetProfessionData()
  local L = chardumps:GetLocale();
	local res = {};

  if chardumps:GetPatchVersion() < 4 then
    return res;
  end

  chardumps.log:Message(L.GetProfessions);

  local prof1, prof2, archaeology, fishing, cooking, firstAid = GetProfessions();
  local indexes = {prof1, prof2, archaeology, fishing, cooking, firstAid};
  for i = 1,6 do
    -- name, texture, rank, maxRank, numSpells, spelloffset, skillLine, rankModifier, specializationIndex, specializationOffset = GetProfessionInfo(index)
    if indexes[i] then
      local name, _, rank, maxRank, numSpells, spelloffset, skillLine = GetProfessionInfo(indexes[i]);
      if rank then
        -- TODO: name delete
        table.insert(res, {["N"] = name, ["R"] = rank, ["M"] = maxRank, ["K"] = skillLine});
      end
    end
  end

  return res;
end

function dumper:SetDynamicData(name, value)
  self.dynamicDump[name] = value;
end

function dumper:GetDynamicData(name)
  return self.dynamicDump[name] or {};
end

function dumper:GetDynamicDataAll()
  return self.dynamicDump;
end

function dumper:SetDynamicDataAll(data)
  self.dynamicDump = data or {};
end

---
--@return #table
function dumper:GetBankItemsCount()
  local count = 0;
  local mainbankCount = 0;
  local bankData = self.dynamicDump["bank"];

  if bankData then
    mainbankCount = chardumps:GetTableLength(bankData.mainbank);
    for _, v in pairs(bankData) do
      count = count + chardumps:GetTableLength(v);
    end
    count = count - mainbankCount;
  end

  return mainbankCount + count;
end

function dumper:GetSkillspellItemsCount()
  local count = 0;

  local data = self:GetDynamicData("skillspell");
  for k, v in pairs(data) do
    count = count + #v;
  end

  return count;
end

---
-- @return #number
function dumper:GetTaxiItemsCount()
  local taxiData = self:GetDynamicData("taxi");
  local count = 0;

  for i = 1, chardumps.MAX_NUM_CONTINENT do
    if taxiData[i] then
      count = count + #taxiData[i];
    end
  end

	return count;
end

function dumper:GetCounts(dump)
  dump = dump or self.dump;
  local res = {};
	if chardumps:GetTableLength(dump) == 0 then
    return res;
  end

  res.achievement = chardumps:GetTableLength(dump.achievement);
  res.action = chardumps:GetTableLength(dump.action);
  res.bag = self:GetBagItemsCount();
  res.bank = self:GetBankItemsCount();
  res.bind = #dump.bind;
  res.criterias = chardumps:GetTableLength(dump.criterias);
  res.critter = #dump.critter;
  res.currency = chardumps:GetTableLength(dump.currency);
  res.equipment = #dump.equipment;
  res.glyph = self:GetGlyphItemsCount();
  res.global = chardumps:GetTableLength(dump.global);
  res.inventory = chardumps:GetTableLength(dump.inventory);
  res.quest = chardumps:GetTableLength(dump.quest);
  res.questlog = #dump.questlog;
  res.pet = 0;
  res.player = chardumps:GetTableLength(dump.player);
  res.pmacro = #dump.pmacro;
  res.reputation = #dump.reputation;
  res.mount = #dump.mount;
  res.talent = self:GetTalentItemsCount();
  res.taxi = self:GetTaxiItemsCount();
  res.title = #dump.title;
  res.spell = chardumps:GetTableLength(dump.spell);
  res.skill = #dump.skill;
  res.skillspell = self:GetSkillspellItemsCount();
  res.statistic = chardumps:GetTableLength(dump.statistic);

  return res;
end

chardumps.dumper = dumper;
