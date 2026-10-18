--[[
	Objectives that sit inside one faction's camp / enclave / inn.

	In 3.3.5 most Northrend (and the Dalaran) bucket quests have no faction flag,
	but several are physically inside an enemy base (e.g. Amberpine Lodge is an
	Alliance camp, the Silver Enclave is the Alliance half of Dalaran) - you get
	teleported out and there is no quest marker. Those are listed here so they can
	be hidden for the other faction.

	1 = Alliance area, 2 = Horde area.
	Derived from the 3.3.5 NPC factions (wotlkdb react values) around each spot.
]]

local _, ns = ...

ns.FACTION_AREA = {
	-- Grizzly Hills
	[12944] = 2, -- Conquest Hold
	[12945] = 2,
	[12946] = 1, -- Amberpine Lodge
	[12947] = 1, -- Westfall Brigade Encampment

	-- Howling Fjord
	[13433] = 1,
	[13434] = 1, -- Innkeeper Celeste Goodhutch
	[13435] = 1,
	[13466] = 2,
	[13467] = 2,
	[13468] = 2,

	-- Borean Tundra
	[13436] = 1, -- Fizzcrank Airstrip
	[13437] = 1,
	[13461] = 1,
	[13469] = 2,
	[13470] = 2, -- Taunka'le Village
	[13501] = 2,

	-- Dragonblight
	[13438] = 1, -- Stars' Rest
	[13439] = 1, -- Wintergarde Keep
	[13460] = 1,
	[13471] = 2, -- Agmar's Hammer

	-- The Storm Peaks
	[13448] = 1, -- Frosthold
	[13473] = 2, -- Grom'arsh Crash-Site

	-- Dalaran
	[13452] = 1, -- Silver Enclave
	[13465] = 1, -- Silver Enclave (confirms: no quest marker for Horde)
	[13474] = 2, -- Sunreaver's Sanctuary
}
