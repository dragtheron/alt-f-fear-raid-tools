AddonName, AFFRT = ...

AFFRT.Core = {}
AFFRT.L = {}

-- setup localization
local function L_Default(L, key)
  return "#" .. key;
end
setmetatable(AFFRT.L, { __index=L_Default });


AFFRT.Core.Broadcast = {}
AFFRT.Core.Broadcast.AllowedPrefixes = {
  ["AFFRT"] = true
}
AFFRT.Core.Broadcast.OnAddonMessage = {}

function AFFRT.Core.Broadcast.Register()
  AFFRT.Core.Broadcast.OnAddonMessage[self.name] = self
end

function AFFRT.Core.IsGuildMember(name)
  for i = 1, GetNumGuildMembers() or 0 do
    local guildMemberName = GetGuildRosterInfo(i)
    if guildMemberName and guildMemberName == name then
      return true
    end
  end
  return false
end

function AFFRT.Core.Broadcast.CheckChannelAndSender(channel, sender)
  -- safe channels
  if channel == "RAID" or channel == "GUILD" or channel == "INSTANCE_CHAT" or channel == "PARTY" then
    return true
  end
  -- whisper
  if channel == "WHISPER" then
    if AFFRT.Core.IsGuildMember(sender) then
      return true
    end
    AFFRT.Core.Log.Debug("Not in Guild", sender);
  end
  return false
end

function AFFRT.Core.Broadcast.CheckPrefix(prefix)
  return prefix and AFFRT.Core.Broadcast.AllowedPrefixes[prefix]
end

function AFFRT.Core.Broadcast.OnEvent(frame, ...)
  local prefix, message, channel, sender = ...
  if AFFRT.Core.Broadcast.CheckPrefix(prefix) and AFFRT.Core.Broadcast.CheckChannelAndSender(channel, sender) then
    AFFRT.Core.Broadcast.OnReceive(frame, sender, prefix, strsplit("\t", message))
  end
end

function AFFRT.Core.Broadcast.OnReceive(frame, sender, prefix, topic, ...)
  AFFRT.Core.Log.Debug("Received Message!", sender, prefix, topic)
  for name, module in pairs(AFFRT.Core.Broadcast.OnAddonMessage) do
    module.Broadcast.OnReceive(frame, sender, topic, ...)
  end
end

function AFFRT.Core.Broadcast.Send(prefix, topic, message, channel, target)
  message = message or ""
  channel = channel or "PARTY"
  topic = topic or ""
  message = topic .. "\t" .. message
  C_ChatInfo.SendAddonMessage(prefix, message, channel, target)
  AFFRT.Core.Log.Debug("Message Sent!", prefix, channel, topic)
end


-- Database
AFFRT.Core.Database = {
  ready = false,
};

function AFFRT.Core.Database.Init()
  if not AFFRT_SV then
    AFFRT_SV = {}
  end

  -- Database Version Fixation
  local version = GetAddOnMetadata("AFFRaidTools", "VERSION");
  local major, minor, patch = string.match(version, "(%d+).(%d+).(%d+)");
  if not AFFRT_SV.Version then
    AFFRT_SV.Version = {
      major = tonumber(major);
      minor = tonumber(minor);
      patch = tonumber(patch);
    }
  end

  if not AFFRT_SV.Data then
    AFFRT_SV.Data = {};
  end

  -- Database Version is now fixed.
  -- If any schematic changes occur, we can do migrations where the saved
  -- version has to be updated too finally.

  AFFRT.Core.Database.data = AFFRT_SV.Data;
  AFFRT.Core.Database.ready = true;
end

function AFFRT.Core.Database.InitModuleData(moduleName)
  if not AFFRT_SV.Data[moduleName] then
    AFFRT_SV.Data[moduleName] = {};
  end
  return AFFRT_SV.Data[moduleName]
end

function AFFRT.Core.Database.Update(database, path, value)
  for i, field in ipairs(path) do
    if i < #path and not database[field] then
      database[field] = {}
    end
    if i == #path then
      database[field] = value;
    end
    database = database[field]
  end
end

function AFFRT.Core.Database.Get(database, path)
  for i, field in ipairs(path) do
    if database == nil then
      return nil
    end
    if i == #path then
      return database[field];
    end
    database = database[field]
  end
end



-- Log
AFFRT.Core.Log = {}

-- debug logging disabled unless you are dev
function AFFRT.Core.Log.SendDebugMsg(moduleName, ...)
  return nil
end
if AFFRT_DEV then
  AFFRT.Core.Log.SendDebugMsg = function(moduleName, ...)
    print(string.format("[AFFRT.%s.Debug]", moduleName), ...)
  end
end

AFFRT.Core.Log.Debug = function(...)
  AFFRT.Core.Log.SendDebugMsg("Core", ...)
end


-- modules

function AFFRT.Core.InitModule(name, prefix)
  prefix = string.format("AFFRT/%s", prefix)
  assert(AFFRT[name] == nil, "Module Naming Conflict")
  assert(AFFRT.Core.Broadcast.AllowedPrefixes[prefix] == nil, "Module Prefix Conflict")
  AFFRT[name] = {}
  AFFRT.Core.Broadcast.AllowedPrefixes[prefix] = true
  local Module = AFFRT[name]
  Module.Log = {}
  Module.Log.Debug = function(...)
    AFFRT.Core.Log.SendDebugMsg(name, ...)
  end
  Module.Broadcast = {}
  Module.Broadcast.Send = function(...)
    AFFRT.Core.Broadcast.Send(prefix, ...)
  end
  Module.Broadcast.OnReceive = function(frame, sender, prefix, ...)
    return nil
  end
  Module.Database = {
    ready = false,
  };
  Module.Database.InitDatabase = function()
    Module.Database.ready = true;
    local database = AFFRT.Core.Database.InitModuleData(name);
      
    Module.Database.Update = function(path, value)
      return AFFRT.Core.Database.Update(database, path, value);
    end;
      
    Module.Database.Get = function(path, value)
      return AFFRT.Core.Database.Get(database, path, value);
    end;

    return database;
  end
  AFFRT.Core.Broadcast.OnAddonMessage[name] = Module
  Module.Log.Debug("Registered Module", name)
  return AFFRT.Core, Module
end


-- frame scripts

function AFFRT.Core.OnEvent(frame, event, ...)
  AFFRT = frame.AFFRT
  if event == "ADDON_LOADED" then
    AFFRT.Core.OnEvent_AddonLoaded(frame, ...)
  elseif event == "CHAT_MSG_ADDON" then
    AFFRT.Core.Broadcast.OnEvent(frame, ...)
  else
    AFFRT.Core.Log.Debug("Unhandled Event", event)
  end
end

function AFFRT.Core.OnEvent_AddonLoaded(frame, ...)
  local addonName = ...
  if addonName ~= AddonName then
    AFFRT.Core.Log.Debug("addon name mismatch", addonName, AddonName)
    return
  end
  for prefix, _ in pairs(AFFRT.Core.Broadcast.AllowedPrefixes) do
    AFFRT.Core.Log.Debug("Registering Prefix", prefix)
    C_ChatInfo.RegisterAddonMessagePrefix(prefix)
  end
  AFFRT.Core.Log.Debug("ADDON_LOADED", "Happy Testing ^_^")
  frame:UnregisterEvent("ADDON_LOADED")
end

function AFFRT.Core.OnLoad(frame)
  frame.AFFRT = AFFRT
  frame:RegisterEvent("ADDON_LOADED")
  frame:RegisterEvent("CHAT_MSG_ADDON")
end

AFFRT.Core.Database.Init();