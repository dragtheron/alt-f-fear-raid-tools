local Core, Module = AFFRT.Core.InitModule("Attention", "A")

function Module.Broadcast.OnReceive(frame, sender, topic, ...)
  local characterName = sender
  if topic == "E" then
    Module.Log.Debug("Player Entered:", sender);
  elseif topic == "L" then
    Module.Log.Debug("Player Left:", sender);
  end
end

Module.Broadcast.Topics = {
  ["PLAYER_ENTERING"] = "E",        -- entered and available
  ["PLAYER_LEAVING"] = "L",         -- reload / logout / exit etc.
  ["PLAYER_AVAILABLE"] = "A",       -- response to a player entering, still active, nothing changed
}


-- frame scripts

function Module.OnEvent(frame, event, ...)
  Module = frame.Module
  if event == "ADDON_LOADED" then
    Module.OnEvent_AddonLoaded(frame, ...);
  elseif event == "PLAYER_ENTERING_WORLD" then
    Module.Broadcast.Send(Module.Broadcast.Topics.PLAYER_ENTERING);  
  elseif event == "PLAYER_LEAVING_WORLD" then
    Module.Broadcast.Send(Module.Broadcast.Topics.PLAYER_LEAVING);  
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
  Module.Log.Debug("ADDON_LOADED", "Happy Testing ^_^")
  frame:UnregisterEvent("ADDON_LOADED")
end

function Module.OnLoad(frame)
  frame.Module = Module;
  frame:RegisterEvent("ADDON_LOADED")
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  frame:RegisterEvent("PLAYER_LEAVING_WORLD")
end