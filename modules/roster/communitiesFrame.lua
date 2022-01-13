-- from Blizzard_Communities/CommunitiesMembersList.lua
local COMMUNITIES_MEMBER_LIST_EVENTS = {
	"CLUB_MEMBER_ADDED",
	"CLUB_MEMBER_REMOVED",
	"CLUB_MEMBER_UPDATED",
	"CLUB_MEMBER_PRESENCE_UPDATED",
	"CLUB_STREAMS_LOADED",
	"VOICE_CHAT_CHANNEL_ACTIVATED",
	"VOICE_CHAT_CHANNEL_DEACTIVATED",
	"VOICE_CHAT_CHANNEL_JOINED",
	"VOICE_CHAT_CHANNEL_REMOVED",
	"VOICE_CHAT_CHANNEL_MEMBER_ADDED",
	"VOICE_CHAT_CHANNEL_MEMBER_GUID_UPDATED",
	"CLUB_INVITATIONS_RECEIVED_FOR_CLUB",
	"CLUB_MEMBER_ROLE_UPDATED",
	"GUILD_ROSTER_UPDATE",
};

AFFRT.Roster.CommunitiesFrame = {}

-- update tab state and visibility when display mode changes (by original blizz events)
function AFFRT.Roster.CommunitiesFrame.OnDisplayModeChanged()
	if CommunitiesFrame.displayMode ~= "AFFRT_Roster" then
		CommunitiesFrame.AFFRT_MembersList:SetShown(false);
		CommunitiesFrame.AFFRT_RosterList:SetShown(false);
    CommunitiesFrame.AFFRT_RosterTab:SetChecked(false);
  else
		CommunitiesFrame.AFFRT_MembersList:SetShown(true);
		CommunitiesFrame.AFFRT_RosterList:SetShown(true);
    CommunitiesFrame.GuildMemberListDropDownMenu:SetShown(false);
    CommunitiesFrame.CommunityMemberListDropDownMenu:SetShown(false);

    -- hide blizzard stuff, but keep commmunity list
    local subframesToUpdate = {};
    for i, mode in pairs(COMMUNITIES_FRAME_DISPLAY_MODES) do
      for j, subframe in ipairs(mode) do
        CommunitiesFrame[subframe]:SetShown(false);
      end
    end
    CommunitiesFrame.CommunitiesList:SetShown(true);
    CommunitiesFrame.PostingExpirationText:Hide();

    CommunitiesFrameInset:Show(); 

    -- set checked state  on tabs
    CommunitiesFrame.ChatTab:SetChecked(false);
    CommunitiesFrame.RosterTab:SetChecked(false);
    CommunitiesFrame.GuildBenefitsTab:SetChecked(false);
    CommunitiesFrame.GuildInfoTab:SetChecked(false);
    CommunitiesFrame.AFFRT_RosterTab:SetChecked(true);
	end

	-- only guilds are supported. maye adding community support in the future.
  if AFFRT.Roster.CommunitiesFrameTab.IsGuildSelected() and CommunitiesFrame.displayMode ~= COMMUNITIES_FRAME_DISPLAY_MODES.MINIMIZED then
    CommunitiesFrame.AFFRT_RosterTab:SetShown(true);
  else
    CommunitiesFrame.AFFRT_RosterTab:SetShown(false);
  end
end

function AFFRT.Roster.CommunitiesFrame.Show()
  CommunitiesFrame.displayMode = "AFFRT_Roster";
  AFFRT.Roster.CommunitiesFrame.OnDisplayModeChanged();
end

function AFFRT.Roster.CommunitiesFrame.OnLoad(self)
  -- when reopening the original frame, after being left in the roster manager,
  -- we have to initialize the tab buttons. to avoid rendering issues, switch
  -- to the default roster briefly before changing back to the desired view.
  CommunitiesFrame:HookScript("OnShow", function(self)
    if CommunitiesFrame.displayMode == "AFFRT_Roster" then
      -- displayMode: AFFRT_Roster (uninitialized) -> Blizz Roster -> AFFRT_Roster (initialized by blizz)
      CommunitiesFrame:SetDisplayMode(COMMUNITIES_FRAME_DISPLAY_MODES.ROSTER);
      AFFRT.Roster.CommunitiesFrame.Show();
    end
  end)
end

function AFFRT.Roster.CommunitiesFrame.RefreshListDisplay(frame)
  local offset = HybridScrollFrame_GetOffset(frame.ListScrollFrame);
  local memberList = frame.sortedMemberList;
  local usedHeight = 0;
  local height = frame.ListScrollFrame.buttons[1]:GetHeight();
  for i = 1, #frame.ListScrollFrame.buttons do
    local displayIndex = i + offset;
    local button = frame.ListScrollFrame.buttons[i];
    if displayIndex <= #memberList then
      local memberInfo = memberList[displayIndex];
      AFFRT.Roster.CommunitiesFrame.SetMemberButton(button, memberInfo);
      button:Show();
      usedHeight = usedHeight + height;
    else
      AFFRT.Roster.CommunitiesFrame.SetMemberButton(button, nil);
      button:Hide();
    end
  end
  HybridScrollFrame_Update(frame.ListScrollFrame, height * #memberList, usedHeight);
end

function AFFRT.Roster.CommunitiesFrame.RefreshLayout(frame)
  -- init data
  if not frame.ListScrollFrame.buttons then
    HybridScrollFrame_CreateButtons(frame.ListScrollFrame, "AFFRT_CommunitiesMemberListEntryTemplate", 0, 0);
  end
  for _, button in ipairs(frame.ListScrollFrame.buttons or {}) do
    button.expanded = frame.expanded;
  end
end

function AFFRT.Roster.CommunitiesFrame.MemberButtonSetExpanded(button, expanded)
  button.expanded = expanded;
  button.Attendance:SetShown(expanded);
  button.Class:SetShown(expanded);
  button.Itemlevel:SetShown(expanded);
  button.Rank:SetShown(expanded);
  button.RolesFrame:SetShown(expanded);
	AFFRT.Roster.CommunitiesFrame.SetMemberButton(button);
	AFFRT.Roster.CommunitiesFrame.UpdateMemberNameFrame(button);
end

function AFFRT.Roster.CommunitiesFrame.RefreshButton(button)
  local memberInfo = button.memberInfo or nil;
  local hasMemberInfo = memberInfo ~= nil;
  button.Attendance:SetShown(hasMemberInfo);
  button.Itemlevel:SetShown(hasMemberInfo);
  button.Rank:SetShown(hasMemberInfo);
  button.RolesFrame:SetShown(hasMemberInfo);
  if not button.expanded then
    return;
  end
	if not hasMemberInfo then
		return;
	end
  if memberInfo.itemLevel then
    button.Itemlevel:SetText(memberInfo.itemLevel);
  else
    button.Itemlevel:SetText(AFFRT.L["CHARACTER_ITEMLEVEL_NODATA_SHORT"]);
  end
  if memberInfo.itemLevelColor then
    button.Itemlevel:SetTextColor(memberInfo.itemLevelColor.r, memberInfo.itemLevelColor.g, memberInfo.itemLevelColor.b);
  else
    button.Itemlevel:SetTextColor(NORMAL_FONT_COLOR:GetRGB());
  end
  button.Class:Hide();
  if memberInfo.classID then
    local classInfo = C_CreatureInfo.GetClassInfo(memberInfo.classID);
    if classInfo then
      button.Class:SetTexCoord(unpack(CLASS_ICON_TCOORDS[classInfo.classFile]));
      button.Class:Show();
    end
  end
  button.Rank:SetText(memberInfo.guildRank or "Test");

end

function AFFRT.Roster.CommunitiesFrame.SetMemberButton(button, memberInfo)
  local hasMemberInfo = memberInfo ~= nil;
  button.Attendance:SetShown(hasMemberInfo and button.expanded);
  button.Class:SetShown(hasMemberInfo and button.expanded);
  button.Itemlevel:SetShown(hasMemberInfo and button.expanded);
  button.Rank:SetShown(hasMemberInfo and button.expanded);
  button.RolesFrame:SetShown(hasMemberInfo and button.expanded);
  if button.expanded then
    button:SetWidth(button:GetParent():GetWidth());
  end
  if memberInfo then
    button.memberInfo = memberInfo;
    button.NameFrame.Name:SetText(memberInfo.name or "");
    button.NameFrame.RankIcon:Show();
    
    if memberInfo.role == Enum.ClubRoleIdentifier.Owner or memberInfo.role == Enum.ClubRoleIdentifier.Leader then
      button.NameFrame.RankIcon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon");
    elseif memberInfo.role == Enum.ClubRoleIdentifier.Moderator then
      button.NameFrame.RankIcon:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon");
    else
      button.NameFrame.RankIcon:Hide();
    end

    if memberInfo.itemLevel then
      button.Itemlevel:SetText(memberInfo.itemLevel);
    else
      button.Itemlevel:SetText("");
    end
    
    if memberInfo.classID then
      local classInfo = C_CreatureInfo.GetClassInfo(memberInfo.classID);
      if classInfo then
        local color = RAID_CLASS_COLORS[classInfo.classFile] or NORMAL_FONT_COLOR;
        button.NameFrame.Name:SetTextColor(color.r, color.g, color.b);
      else
        button.NameFrame.Name:SetTextColor(DISABLED_FONT_COLOR:GetRGB());
      end
    end

  else
    button.memberInfo = nil;
    button.NameFrame.Name:SetText(nil);
    button.NameFrame.RankIcon:Hide();
  end

  AFFRT.Roster.CommunitiesFrame.RefreshButton(button);
  AFFRT.Roster.CommunitiesFrame.SetMemberNameFrame(button);
end

function AFFRT.Roster.CommunitiesFrame.SetMemberNameFrame(button)
  local frame = button.NameFrame;
  local frameWidth;
  local iconsWidth = 0;
  local nameOffset = 0;
  if button.expanded then
    if button.Class:IsShown() then
      frameWidth = 95;
    else
      frameWidth = 140;
    end
  else
    frameWidth = 130;
  end
  frame.Name:ClearAllPoints();
  frame.Name:SetPoint("LEFT", frame, "LEFT", 0, 0);
  if frame.RankIcon:IsShown() then
    iconsWidth = iconsWidth + 25;
  end
  local nameWidth = frameWidth - iconsWidth;
  frame.Name:SetWidth(nameWidth);
  frame:ClearAllPoints();
  if button.Class:IsShown() then
    frame:SetPoint("LEFT", button.Class, "RIGHT", 18, 0);
  else
    frame:SetPoint("LEFT", 4, 0);
  end
  frame:SetWidth(frameWidth);
  local nameStringWidth = frame.Name:GetStringWidth();
  local rankOffset = (frame.Name:IsTruncated() and nameWidth or nameStringWidth) + nameOffset;
  frame.RankIcon:ClearAllPoints();
  frame.RankIcon:SetPoint("LEFT", frame, "LEFT", rankOffset, 0);
end



AFFRT.Roster.CommunitiesFrame.MembersList = {};

-- load guild member info
function AFFRT.Roster.CommunitiesFrame.MembersList.UpdateList(frame)
  local clubId = CommunitiesFrame:GetSelectedClubId();
	frame.memberIds = CommunitiesUtil.GetMemberIdsSortedByName(clubId, nil);
	frame.allMemberList = CommunitiesUtil.GetMemberInfo(clubId, frame.memberIds);
	frame.allMemberInfoLookup = CommunitiesUtil.GetMemberInfoLookup(frame.allMemberList);
	frame.allMemberList = CommunitiesUtil.SortMemberInfo(clubId, frame.allMemberList);
  frame.sortedMemberList = frame.allMemberList;
  frame.sortedMemberLookup = frame.allMemberInfoLookup;
  
  -- inject item levels
  for i, member in ipairs(frame.allMemberList) do
    local playerData = AFFRT.Roster.GetPlayerData(member.guid);
    if playerData then
      member.itemLevel = playerData.itemLevel or nil;
      member.itemLevelColor = playerData.itemLevelColor or nil;
    end
  end

  AFFRT.Roster.CommunitiesFrame.MembersList.Update(frame);
end

function AFFRT.Roster.CommunitiesFrame.MembersList.Update(frame)
  AFFRT.Roster.CommunitiesFrame.RefreshLayout(frame);
  AFFRT.Roster.CommunitiesFrame.RefreshListDisplay(frame);
end

function AFFRT.Roster.CommunitiesFrame.MembersList.OnShow(frame)
  AFFRT.Roster.CommunitiesFrame.MembersList.UpdateList(frame);
end

function AFFRT.Roster.CommunitiesFrame.MembersList.OnLoad(frame)
  -- OnScroll
  frame.ListScrollFrame.update = function()
    AFFRT.Roster.CommunitiesFrame.MembersList.Update(frame);
  end;
	frame.ListScrollFrame.scrollBar.doNotHide = true;
	frame.ListScrollFrame.scrollBar:SetValue(0);
end


AFFRT.Roster.CommunitiesFrame.RosterList = {};

local columns = {
  [1] = {
    title = AFFRT.L["CHARACTER_CLASS"],
    width = 45,
  },
  [2] = { 
    title = AFFRT.L["CHARACTER_NAME"],
    width = 106,
  },
  [3] = {
    title = AFFRT.L["RANK"],
    width = 85,
  },
  [4] = {
    title = AFFRT.L["CHARACTER_ITEMLEVEL"],
    width = 60,
  },
  [5] = {
    title = AFFRT.L["ROLES"],
    width = 60,
  },
  [6] = {
    title = AFFRT.L["ATTENDANCE"],
    width = 85,
  },
}

function AFFRT.Roster.CommunitiesFrame.RosterList.OnShow(frame)
  AFFRT.Roster.CommunitiesFrame.MembersList.UpdateList(frame);
end

function AFFRT.Roster.CommunitiesFrame.RosterList.OnLoad(frame)
  -- OnScroll
  frame.ListScrollFrame.update = function()
    AFFRT.Roster.CommunitiesFrame.MembersList.Update(frame);
  end;
	frame.ListScrollFrame.scrollBar.doNotHide = true;
	frame.ListScrollFrame.scrollBar:SetValue(0);
  frame.ColumnDisplay:LayoutColumns(columns);
  frame.ColumnDisplay:Show();
end