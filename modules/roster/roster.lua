local Core, Module = AFFRT.Core.InitModule("Roster", "R")

Module.Broadcast.Topics = {
  ItemlevelIncomingAll = "ID",
  ItemlevelIncomingPlayer = "IP",
  ItemlevelSyncRequest = "IR",
};

Module.PlayerInspectionReady = true;
Module.ItemLevelRequestQueue = {};

function Module.GetPlayerData(guid)
  return Module.Database.Get({ "PlayerData", guid });
end

function Module.QueueItemLevelRequest(channel, target)
  local request = {
    channel = channel,
    target = target
  }
  -- only send once if requested multiple times
  local requestIdentifier = table.concat({channel,target}, ":");
  Module.ItemLevelRequestQueue[requestIdentifier] = request;
  Module.Log.Debug("Enqueued Request", requestIdentifier);
  Module.InspectPlayer();
end

function Module.ProcessQueue()
  for i, request in pairs(Module.ItemLevelRequestQueue) do
    local result = Module.SendItemLevel(request.channel, request.target);
    Module.Log.Debug("Processing Request", request.channel, request.target);
    if result == false then
      Module.Log.Debug("Processing Failed. Requeue");
    else
      Module.ItemLevelRequestQueue[i] = nil;
    end
  end
  Module.ItemLevelRequestQueue = {};
end

function Module.Broadcast.OnReceive(frame, sender, topic, ...)
  Module.Log.Debug("inc", sender, topic);
  if topic == Module.Broadcast.Topics.ItemlevelIncomingPlayer then
    local guid, itemLevel;
    local itemLevelColor = {};
    guid, itemLevel, itemLevelColor.r, itemLevelColor.g, itemLevelColor.b = ...
    Module.Log.Debug("New itemlevel", ...);
    Module.Database.Update({ "PlayerData", guid, "itemLevel" }, itemLevel);
    Module.Database.Update({ "PlayerData", guid, "itemLevelColor" }, itemLevelColor);
    AFFRT.Roster.EventsMixin:TriggerEvent(AFFRT.Roster.EventsMixin.Event.PlayerDataUpdated);
  elseif topic == Module.Broadcast.Topics.ItemlevelSyncRequest then
    Module.QueueItemLevelRequest("WHISPER", sender);
  end
end

function Module.InspectPlayer()
  if not Module.PlayerInspectionInProgress then
    Module.PlayerInspectionInProgress = true;
    NotifyInspect("player");
    Module.Log.Debug("Triggered Inspection");
  end
end

function Module.SendItemLevel(channel, target)
  channel = channel or "GUILD"
  local itemLevel = C_PaperDollInfo.GetInspectItemLevel("player");
  if not itemLevel then
    return false
  end
  local itemLevelColor = {};
  itemLevelColor.r, itemLevelColor.g, itemLevelColor.b = GetItemLevelColor();
  itemLevelColor.r = math.floor(itemLevelColor.r * 100) / 100;
  itemLevelColor.g = math.floor(itemLevelColor.g * 100) / 100;
  itemLevelColor.b = math.floor(itemLevelColor.b * 100) / 100;
  local guid = UnitGUID("player");
  local message = table.concat({ 
    guid, 
    itemLevel, 
    itemLevelColor.r, itemLevelColor.g, itemLevelColor.b 
  }, "\t");
  Module.Broadcast.Send(Module.Broadcast.Topics.ItemlevelIncomingPlayer, message, channel, target);
  return true
end

function Module.RequestItemLevelSync()
  Module.Broadcast.Send(Module.Broadcast.Topics.ItemlevelSyncRequest, "", "GUILD");
  Module.Broadcast.Send(Module.Broadcast.Topics.ItemlevelSyncRequest, "", "RAID");
end

-- frame scripts

function Module.OnEvent(frame, event, ...)
  Module = frame.Module
  if event == "ADDON_LOADED" then
    Module.OnEvent_AddonLoaded(frame, ...);
  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
    Module.OnEvent_PlayerEquipmentChanged();
  elseif event == "GROUP_JOINED" then
    Module.OnEvent_GroupJoined()
  elseif event == "INSPECT_READY" then
    Module.OnEvent_InspectReady()
  else
    Module.Log.Debug("Unhandled Event", event)
  end
end

function Module.OnEvent_InspectReady()
  if Module.PlayerInspectionInProgress then
    Module.Log.Debug("Inspection Ready!");
    Module.ProcessQueue();
    ClearInspectPlayer();
    Module.PlayerInspectionInProgress = false;
  end
end

function Module.OnEvent_PlayerEquipmentChanged()
  Module.QueueItemLevelRequest("GUILD");
  Module.QueueItemLevelRequest("RAID");
end

function Module.OnEvent_AddonLoaded(frame, ...)
  local addonName = ...
  if addonName ~= AddonName then
    Module.Log.Debug("addon name mismatch", addonName, AddonName)
    return
  end
  Module.Database.InitDatabase();
  Module.Database.Data = Module.Database.InitDatabase();
  Module.RequestItemLevelSync();
  Module.Log.Debug("ADDON_LOADED", "Happy Testing ^_^")
  frame:UnregisterEvent("ADDON_LOADED")
end

function Module.OnEvent_GroupJoined()
  Module.RequestItemLevelSync();
end

function Module.OnLoad(frame)
  frame.Module = Module;
  frame:RegisterEvent("ADDON_LOADED")
  frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
  frame:RegisterEvent("GROUP_JOINED")
  frame:RegisterEvent("INSPECT_READY")
end