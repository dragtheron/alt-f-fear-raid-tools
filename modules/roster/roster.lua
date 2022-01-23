local Core, Module = AFFRT.Core.InitModule("Roster", "R")

Module.Broadcast.Topics = {
  ItemlevelIncomingAll = "ID",
  ItemlevelIncomingPlayer = "IP",
  ItemlevelSyncRequest = "IR",
};

Module.PlayerEnteredWorldOnce = false
Module.PlayerInspectionReady = true
Module.ItemLevelRequestQueue = {}

function Module.GetRosterClubMembers(clubId)
  return Module.Database.Get({ "Roster", clubId, "ClubMembers" })
end

function Module.GetRosterMembers(clubId)
  local clubMembers = Module.GetRosterClubMembers(clubId)
  local externalMembers = Module.Database.Get({ "Roster", clubId, "ExternalMembers" })
  return clubMembers, externalMembers
end

function Module.GetPlayerData(guid)
  return Module.Database.Get({ "PlayerData", guid });
end

function Module.IsInRosterByClub(clubId, guid)
  local clubMembers = Module.GetRosterClubMembers(clubId)
  if not clubMembers or not clubMembers[guid] or not clubMembers[guid].enabled then
    return false
  end
  return true
end

function Module.IsInRoster(memberInfo)
  if memberInfo.guid then
    return Module.IsInRosterByClub(memberInfo.clubId, memberInfo.guid)
  end
  -- todo: external members by name
end

function Module.AddFromClub(clubId, guid)
  Module.Database.Update({ "Roster", clubId, "ClubMembers", guid, "enabled" }, true)
  Module.EventsMixin:TriggerEvent(Module.EventsMixin.Event.PlayerDataUpdated);
end

function Module.DisableClubMember(clubId, guid)
  Module.Database.Update({ "Roster", clubId, "ClubMembers", guid, "enabled" }, false)
  Module.EventsMixin:TriggerEvent(Module.EventsMixin.Event.PlayerDataUpdated);
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
    if result == false then
      Module.Log.Debug("Processing Failed. Requeue");
    else
      Module.ItemLevelRequestQueue[i] = nil;
    end
  end
  Module.ItemLevelRequestQueue = {};
end

function Module.Broadcast.OnReceive(frame, sender, topic, ...)
  if topic == Module.Broadcast.Topics.ItemlevelIncomingPlayer then
    local guid, itemLevel;
    local itemLevelColor = {};
    guid, itemLevel, itemLevelColor.r, itemLevelColor.g, itemLevelColor.b = ...
    Module.Log.Debug("New itemlevel", itemLevel, "from", sender);
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
  elseif event == "GROUP_JOINED" then
    Module.OnEvent_GroupJoined()
  elseif event == "INSPECT_READY" then
    Module.OnEvent_InspectReady()
  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
    Module.OnEvent_PlayerEquipmentChanged()
  elseif event == "PLAYER_ENTERING_WORLD" then
    Module.OnEvent_PlayerEnteringWorld()  
  elseif event == "CALENDAR_UPDATE_EVENT"
      or event == "CALENDAR_UPDATE_PENDING_INVITES"
      or event == "CALENDAR_UPDATE_INVITE_LIST" then
    Module.Log.Debug(event)
    Module.OnEvent_CalendarUpdate()
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
  Module.Log.Debug("ADDON_LOADED", "Happy Testing ^_^")
  frame:UnregisterEvent("ADDON_LOADED")
end

function Module.OnEvent_GroupJoined()
  Module.RequestItemLevelSync();
end

function Module.OnEvent_PlayerEnteringWorld()
  if not Module.PlayerEnteredWorldOnce then
    Module.PlayerEnteredWorldOnce = true
    Module.RequestItemLevelSync()
  end
end

function Module.OnEvent_CalendarUpdate()
  Module.Log.Debug("Received Calendar Update")
  if Module.LookupCharacter then
    for i = 1, C_Calendar.GetNumInvites() do
      local eventInfo = C_Calendar.EventGetInvite(i)
      if eventInfo.name == Module.LookupCharacter then
        Module.Log.Debug("Clas Name Found:", eventInfo.className)
      end
    end
  end
end

function Module.OnLoad(frame)
  frame.Module = Module;
  frame:RegisterEvent("ADDON_LOADED")
  frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
  frame:RegisterEvent("GROUP_JOINED")
  frame:RegisterEvent("INSPECT_READY")
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  frame:RegisterEvent("CALENDAR_UPDATE_EVENT")
  frame:RegisterEvent("CALENDAR_UPDATE_PENDING_INVITES")
  frame:RegisterEvent("CALENDAR_UPDATE_INVITE_LIST")
  
  -- Try to get another player's info by calendar
  Module.LookupCharacter = "Lycantheron"
  C_Calendar.CreatePlayerEvent()
  C_Calendar.EventInvite(Module.LookupCharacter)
  Module.Log.Debug("Invited", Module.LookupCharacter)
end

Module.EventsMixin = CreateFromMixins(CallbackRegistryMixin);
  
Module.EventsMixin:GenerateCallbackEvents({
  "PlayerDataUpdated",
});