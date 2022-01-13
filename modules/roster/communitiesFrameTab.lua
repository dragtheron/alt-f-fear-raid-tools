function CommunitiesFrameTab_OnEnter(self)
  if self.tooltip then
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
    GameTooltip:SetText(self.tooltip);
    if self.tooltip2 then
      GameTooltip:AddLine(self.tooltip2, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, true);
    end
    GameTooltip:Show();
  end
end

function CommunitiesFrameTab_OnLeave(self)
  GameTooltip:Hide();
end

AFFRT.Roster.CommunitiesFrameTab = {}

function AFFRT.Roster.CommunitiesFrameTab.OnClick(frame)
	AFFRT.Roster.CommunitiesFrame.Show();
end

function AFFRT.Roster.CommunitiesFrameTab.IsGuildSelected()
	local clubId = CommunitiesFrame:GetSelectedClubId();
	if clubId then
		local clubInfo = C_Club.GetClubInfo(clubId);
		if clubInfo.clubType == Enum.ClubType.Guild then
			return true;
		end
	end
	return false;
end

-- briefly set display mode before switching club to prevent ui issues due to hidden frames
function AFFRT.Roster.CommunitiesFrameTab.OnClubSelected(self, clubId)
  local communityFrame = self:GetParent();
  if communityFrame.displayMode == "AFFRT_Roster" then
    communityFrame:SetDisplayMode(COMMUNITIES_FRAME_DISPLAY_MODES.ROSTER);
    communityFrame:SelectClub(clubId);
	else
		AFFRT.Roster.CommunitiesFrame.OnDisplayModeChanged(self);
  end
end
