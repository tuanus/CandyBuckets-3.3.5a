--[[
	CandyBuckets - 3.3.5a backport
	Original addon by Vladinator (retail/classic). This is a WotLK 3.3.5a rewrite
	that uses the old (pre-Legion) world map API instead of the modern C_Map pin system.

	Data lives in db\*.lua and is keyed by map name (what GetMapZones() returns),
	with a single { zone = "...", x = <0-100>, y = <0-100> } per objective.
]]

local addonName, ns = ...

ns.modules = ns.modules or {}
ns.QUESTS = {}
ns.FACTION = 0
ns.COMPLETED = {}
ns.SHOW_COMPLETED = false
ns.MINIMAP = true

local CHAT = DEFAULT_CHAT_FRAME

local function Print(fmt, ...)
	CHAT:AddMessage("|cffffff78CandyBuckets|r: " .. string.format(fmt, ...))
end

-- side: 1 = Alliance, 2 = Horde, 3 = Neutral
local SIDE_COLOR = {
	[1] = { 0.25, 0.50, 1.00 },
	[2] = { 1.00, 0.25, 0.25 },
	[3] = { 1.00, 0.85, 0.20 },
}
local SIDE_NAME = { [1] = "Alliance", [2] = "Horde", [3] = "Neutral" }

-- Some 3.3.5 maps are named differently in the game vs. the database.
-- Both sides are normalised through this table before comparing.
local ZONE_ALIAS = {
	["sunken temple"] = "the temple of atal'hakkar",
}
local function Canon(name)
	name = string.lower(name or "")
	return ZONE_ALIAS[name] or name
end

local WHITE = "Interface\\ChatFrame\\ChatFrameBackground"

--------------------------------------------------------------------------------
-- Saved variables / event selection
--------------------------------------------------------------------------------

local db

local function DateActiveEvents()
	local m = tonumber(date("%m"))
	local d = tonumber(date("%d"))
	local a = {}
	if (m == 10 and d >= 18) or (m == 11 and d <= 1) then a.hallow = true end
	if (m == 1 and d >= 14) or (m == 2 and d <= 20) then a.lunar = true end
	if (m == 6 and d >= 19) or (m == 7 and d <= 12) then a.midsummer = true end
	return a
end

local function InitDB()
	db = CandyBucketsDB
	if type(db) ~= "table" then db = {}; CandyBucketsDB = db end
	if type(db.events) ~= "table" then
		db.events = DateActiveEvents()
		if not next(db.events) then
			-- nothing on right now: show everything so the map is useful
			db.events = { hallow = true, lunar = true, midsummer = true }
		end
	end
	if db.showCompleted == nil then db.showCompleted = false end
	ns.SHOW_COMPLETED = db.showCompleted and true or false
	if db.minimap == nil then db.minimap = true end
	ns.MINIMAP = db.minimap and true or false
end

--------------------------------------------------------------------------------
-- Quest list (flattened, faction filtered)
--------------------------------------------------------------------------------

local function RebuildQuests()
	ns.QUESTS = {}
	local n = 0

	for event, mod in pairs(ns.modules) do
		if db.events[event] and type(mod) == "table" and type(mod.quests) == "table" then
			local texture = mod.texture or "Interface\\Icons\\INV_Misc_QuestionMark"
			local title = mod.title or "Event"
			for i = 1, #mod.quests do
				local q = mod.quests[i]
				if q.quest and q.zone and (q.side == 3 or q.side == ns.FACTION) then
					n = n + 1
					ns.QUESTS[n] = {
						quest = q.quest,
						zone = q.zone,
						key = Canon(q.zone),
						x = q.x,
						y = q.y,
						side = q.side,
						event = event,
						title = title,
						texture = texture,
						color = SIDE_COLOR[q.side] or SIDE_COLOR[3],
					}
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- World map
--------------------------------------------------------------------------------

local icons = {}
local mapHooked = false

-- Astrolabe (bundled with TomTom, or the standalone !Astrolabe) can plot a zone's
-- point on whatever map is currently open - including the continent overview.
-- Resolved lazily because TomTom loads after this addon.
local astro
local function GetAstrolabe()
	if astro == nil then
		astro = false
		if _G.DongleStub then
			local ok, lib = pcall(_G.DongleStub, "Astrolabe-0.4")
			if ok and type(lib) == "table" and lib.PlaceIconOnWorldMap then
				astro = lib
			end
		end
	end
	return astro
end

local function GetViewedZoneName()
	-- inside an instance the map shows the instance itself
	if IsInInstance() then
		return GetRealZoneText()
	end

	local continent = GetCurrentMapContinent()
	local zone = GetCurrentMapZone()
	if not continent or continent == 0 then
		return nil
	end
	if zone and zone > 0 then
		local zones = { GetMapZones(continent) }
		return zones[zone]
	end
	-- zone == 0 and not an instance: continent overview, nothing to show
	return nil
end

-- Resolve a zone name to the continent/zone indices TomTom needs. Cached.
local czCache = {}
local function GetZoneCZ(zoneName)
	if czCache[zoneName] then
		return czCache[zoneName][1], czCache[zoneName][2]
	end
	local want = Canon(zoneName)
	local continents = { GetMapContinents() }
	for c = 1, #continents do
		local zones = { GetMapZones(c) }
		for z = 1, #zones do
			if Canon(zones[z]) == want then
				czCache[zoneName] = { c, z }
				return c, z
			end
		end
	end
	return nil
end

local function OnIconEnter(self)
	local q = self.entry
	if not q then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine(q.title, 1, 0.82, 0)
	GameTooltip:AddLine(string.format("%s (%.1f, %.1f)", q.zone, q.x, q.y), 1, 1, 1)
	GameTooltip:AddLine(SIDE_NAME[q.side] or "Neutral", 0.7, 0.7, 0.7)
	if ns.COMPLETED[q.quest] then
		GameTooltip:AddLine("Already completed", 0.2, 1, 0.2)
	end
	GameTooltip:AddLine("Quest ID: " .. q.quest, 0.6, 0.6, 0.6)
	if TomTom and TomTom.AddZWaypoint then
		GameTooltip:AddLine("|cff78ff78Click to set a TomTom waypoint|r")
	else
		GameTooltip:AddLine("|cffffff78Click to print the coordinates|r")
	end
	GameTooltip:Show()
end

local function OnIconClick(self)
	local q = self.entry
	if not q then return end
	local TT = TomTom
	if TT and TT.AddZWaypoint then
		local c, z = GetZoneCZ(q.zone)
		if c and z then
			TT:AddZWaypoint(c, z, q.x, q.y, q.title, nil, nil, nil)
			Print("Waypoint set: %s (%.1f, %.1f)", q.zone, q.x, q.y)
			return
		end
	end
	Print("%s - %s (%.1f, %.1f)  [quest %d]", q.title, q.zone, q.x, q.y, q.quest)
end

local function CreateIcon()
	local f = CreateFrame("Frame", nil, WorldMapDetailFrame)
	f:SetWidth(14)
	f:SetHeight(14)
	f:SetFrameLevel((WorldMapDetailFrame:GetFrameLevel() or 0) + 5)

	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetPoint("TOPLEFT", -1, 1)
	f.bg:SetPoint("BOTTOMRIGHT", 1, -1)
	f.bg:SetTexture(WHITE)

	f.tex = f:CreateTexture(nil, "ARTWORK")
	f.tex:SetAllPoints(f)
	f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	f:EnableMouse(true)
	f:SetScript("OnEnter", OnIconEnter)
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f:SetScript("OnMouseUp", OnIconClick)
	return f
end

local function StyleIcon(icon, q, completed)
	icon.entry = q
	icon.tex:SetTexture(q.texture)
	icon.tex:SetVertexColor(completed and 0.4 or 1, completed and 0.4 or 1, completed and 0.4 or 1)
	if icon.bg then
		icon.bg:SetVertexColor(q.color[1], q.color[2], q.color[3])
	end
end

local function AcquireIcon(index)
	local icon = icons[index]
	if not icon then
		icon = CreateIcon()
		icons[index] = icon
	end
	return icon
end

local function UpdateMap()
	for i = 1, #icons do
		icons[i]:Hide()
		icons[i].entry = nil
	end

	if not WorldMapDetailFrame or not WorldMapDetailFrame:IsShown() then
		return
	end

	local width = WorldMapDetailFrame:GetWidth()
	local height = WorldMapDetailFrame:GetHeight()
	if not width or width <= 1 then
		return
	end

	-- Prefer Astrolabe, which plots any zone's point on the map that is open
	-- (both the zone view and the continent overview). Fall back to plain
	-- name matching when it isn't available.
	local Astrolabe = GetAstrolabe()
	local curC = GetCurrentMapContinent()
	local useAstrolabe = Astrolabe and curC and curC >= 1 and not IsInInstance()

	local zoneKey
	if not useAstrolabe then
		local zoneName = GetViewedZoneName()
		if not zoneName then
			return
		end
		zoneKey = Canon(zoneName)
	end

	local index = 0
	for i = 1, #ns.QUESTS do
		local q = ns.QUESTS[i]
		local completed = ns.COMPLETED[q.quest]
		if not completed or ns.SHOW_COMPLETED then
			if useAstrolabe then
				local c, z = GetZoneCZ(q.zone)
				if c then
					index = index + 1
					local icon = AcquireIcon(index)
					StyleIcon(icon, q, completed)
					local ok = pcall(Astrolabe.PlaceIconOnWorldMap, Astrolabe,
						WorldMapDetailFrame, icon, c, z, q.x / 100, q.y / 100)
					if not ok then
						icon:Hide()
					end
				end
			elseif q.key == zoneKey then
				index = index + 1
				local icon = AcquireIcon(index)
				StyleIcon(icon, q, completed)
				icon:ClearAllPoints()
				icon:SetPoint("CENTER", WorldMapDetailFrame, "TOPLEFT", q.x / 100 * width, -(q.y / 100 * height))
				icon:Show()
			end
		end
	end
end

local function HookMap()
	if mapHooked then return end
	mapHooked = true
	pcall(function()
		hooksecurefunc("WorldMapFrame_Update", UpdateMap)
		hooksecurefunc(WorldMapFrame, "Show", function() UpdateMap() end)
	end)
end

--------------------------------------------------------------------------------
-- Minimap
--------------------------------------------------------------------------------

local minimapPool = {}
local minimapUsed = 0

local function AcquireMinimapIcon(index)
	local icon = minimapPool[index]
	if not icon then
		icon = CreateFrame("Frame", nil, Minimap)
		icon:SetWidth(12)
		icon:SetHeight(12)

		icon.bg = icon:CreateTexture(nil, "BACKGROUND")
		icon.bg:SetPoint("TOPLEFT", -1, 1)
		icon.bg:SetPoint("BOTTOMRIGHT", 1, -1)
		icon.bg:SetTexture(WHITE)

		icon.tex = icon:CreateTexture(nil, "ARTWORK")
		icon.tex:SetAllPoints(icon)
		icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

		icon:EnableMouse(true)
		icon:SetScript("OnEnter", OnIconEnter)
		icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
		icon:SetScript("OnMouseUp", OnIconClick)

		minimapPool[index] = icon
	end
	return icon
end

local function ClearMinimapIcons()
	if minimapUsed == 0 then return end
	local Astrolabe = GetAstrolabe()
	for i = 1, minimapUsed do
		local icon = minimapPool[i]
		if icon then
			if Astrolabe then pcall(Astrolabe.RemoveIconFromMinimap, Astrolabe, icon) end
			icon:Hide()
			icon.entry = nil
		end
	end
	minimapUsed = 0
end

-- Show the objectives for the zone the player is actually standing in.
local function UpdateMinimap()
	local Astrolabe = GetAstrolabe()
	if not ns.MINIMAP or not Astrolabe then
		ClearMinimapIcons()
		return
	end

	local zone = GetRealZoneText()
	local zoneKey = zone and Canon(zone)
	if not zoneKey then
		ClearMinimapIcons()
		return
	end

	local wanted = {}
	for i = 1, #ns.QUESTS do
		local q = ns.QUESTS[i]
		if q.key == zoneKey then
			local completed = ns.COMPLETED[q.quest]
			if not completed or ns.SHOW_COMPLETED then
				local c, z = GetZoneCZ(q.zone)
				if c then
					wanted[#wanted + 1] = { q = q, c = c, z = z }
				end
			end
		end
	end

	for i = #wanted + 1, minimapUsed do
		local icon = minimapPool[i]
		if icon then
			pcall(Astrolabe.RemoveIconFromMinimap, Astrolabe, icon)
			icon:Hide()
			icon.entry = nil
		end
	end

	for i = 1, #wanted do
		local w = wanted[i]
		local icon = AcquireMinimapIcon(i)
		StyleIcon(icon, w.q, ns.COMPLETED[w.q.quest])
		local ok = pcall(Astrolabe.PlaceIconOnMinimap, Astrolabe, icon, w.c, w.z, w.q.x / 100, w.q.y / 100)
		if not ok then
			icon:Hide()
		end
	end

	minimapUsed = #wanted
end

--------------------------------------------------------------------------------
-- Slash command
--------------------------------------------------------------------------------

local function Status()
	local list = {}
	for _, ev in ipairs({ "hallow", "lunar", "midsummer" }) do
		if db.events[ev] then list[#list + 1] = ev end
	end
	Print("events: %s | minimap: %s | completed: %s",
		(#list > 0) and table.concat(list, ", ") or "none",
		ns.MINIMAP and "on" or "off",
		ns.SHOW_COMPLETED and "shown" or "hidden")
end

SLASH_CANDYBUCKETS1 = "/candybuckets"
SLASH_CANDYBUCKETS2 = "/cb"
SlashCmdList["CANDYBUCKETS"] = function(msg)
	msg = string.lower(msg or "")
	msg = string.gsub(msg, "^%s*(.-)%s*$", "%1")

	if msg == "" or msg == "help" then
		Print("commands: /cb all | none | hallow | lunar | midsummer | completed | minimap")
		Status()
		return
	elseif msg == "all" then
		for ev in pairs(ns.modules) do db.events[ev] = true end
	elseif msg == "none" then
		for ev in pairs(ns.modules) do db.events[ev] = false end
	elseif msg == "completed" then
		db.showCompleted = not db.showCompleted
		ns.SHOW_COMPLETED = db.showCompleted
	elseif msg == "minimap" then
		db.minimap = not db.minimap
		ns.MINIMAP = db.minimap
	elseif ns.modules[msg] then
		db.events[msg] = not db.events[msg]
	else
		Print("unknown option '%s', try /cb help", msg)
		return
	end

	RebuildQuests()
	UpdateMap()
	UpdateMinimap()
	Status()
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("QUEST_QUERY_COMPLETE")
-- these vary a little by client, register defensively
pcall(frame.RegisterEvent, frame, "QUEST_FINISHED")
pcall(frame.RegisterEvent, frame, "ZONE_CHANGED_NEW_AREA")
pcall(frame.RegisterEvent, frame, "ZONE_CHANGED")

frame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == addonName then
			InitDB()
			HookMap()
			self:UnregisterEvent("ADDON_LOADED")
		end

	elseif event == "PLAYER_LOGIN" then
		local faction = UnitFactionGroup("player")
		ns.FACTION = (faction == "Alliance" and 1) or (faction == "Horde" and 2) or 3
		QueryQuestsCompleted()
		RebuildQuests()
		UpdateMinimap()
		Status()

	elseif event == "QUEST_QUERY_COMPLETE" then
		ns.COMPLETED = GetQuestsCompleted() or {}
		UpdateMap()
		UpdateMinimap()

	elseif event == "QUEST_FINISHED" then
		QueryQuestsCompleted()

	elseif event == "PLAYER_ENTERING_WORLD" then
		UpdateMap()
		UpdateMinimap()

	elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" then
		UpdateMinimap()
	end
end)
