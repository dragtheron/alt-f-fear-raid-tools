local Core, Module = AFFRT.Core.InitModule("Roster", "R")

Module.Broadcast.Topics = {
  ItemlevelIncomingAll = "ID",
  ItemlevelIncomingPlayer = "IP",
  ItemlevelSyncRequest = "IR",
};

function Module.GetPlayerData(guid)
  Module.Log.Debug("Attempting to get player data:", guid);
  return Module.Database.Get({ "PlayerData", guid });
end

function Module.Broadcast.OnReceive(sender, topic, ...)
  Module.Log.Debug("inc", sender, topic);
  if topic == Module.Broadcast.Topics.ItemlevelIncomingPlayer then
    local guid, itemLevel;
    local itemLevelColor = {};
    guid, itemLevel, itemLevelColor.r, itemLevelColor.g, itemLevelColor.b = ...
    Module.Log.Debug("New itemlevel", ...);
    Module.Database.Update({ "PlayerData", guid, "itemLevel" }, itemLevel);
    Module.Database.Update({ "PlayerData", guid, "itemLevelColor" }, itemLevelColor);
  end
end

function Module.BroadcastItemLevel()
  local itemLevel = GetAverageItemLevel();
  local itemLevelColor = {};
  itemLevelColor.r, itemLevelColor.g, itemLevelColor.b = GetItemLevelColor();
  local guid = UnitGUID("player");
  local message = table.concat({ 
    guid, 
    itemLevel, 
    itemLevelColor.r, itemLevelColor.g, itemLevelColor.b 
  }, "\t");
  Module.Broadcast.Send(Module.Broadcast.Topics.ItemlevelIncomingPlayer, message, "GUILD");
end

-- frame scripts

function Module.OnEvent(frame, event, ...)
  Module = frame.Module
  if event == "ADDON_LOADED" then
    Module.OnEvent_AddonLoaded(frame, ...);
    Module.BroadcastItemLevel();
  elseif event == "PLAYER_AVG_ITEM_LEVEL_UPDATE" then
    Module.BroadcastItemLevel();
  else
    Module.Log.Debug("Unhandled Event", event)
  end
end

function Module.OnEvent_AddonLoaded(frame, ...)
  local addonName = ...
  if addonName ~= AddonName then
    Module.Log.Debug("addon name mismatch", addonName, AddonName)
    return
  end

  Module.Database.InitDatabase();
  Module.Database.Data = Module.Database.InitDatabase();

  Module.Log.Debug("ADDON_LOADED", "Happy Testing ^_^")
  frame:UnregisterEvent("ADDON_LOADED")
end

function Module.OnLoad(frame)
  frame.Module = Module;
  frame:RegisterEvent("ADDON_LOADED")
end