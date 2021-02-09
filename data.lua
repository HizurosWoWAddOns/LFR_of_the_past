
local addon,ns = ...;
local L=ns.L;
ns.npcID = {};
ns.npcs = {};

function ns.npcs_update()
	local faction = ns.faction(); --UnitFactionGroup("player")=="Alliance";

	-- {<npcis>, <zoneid>, <posX>, <posY>, <expansionNumber>, <instanceType>}
	-- expansionNumber is for _G["EXPANSION_NAME"..<expansionNumber>]
	ns.npcs = {
		-- cata
		{80675,74,63.1,27.3,3,"LFR",imgs={"cata1","cata2","cata3","cata4"}},
		-- mop
		--{78709,390,82.95,30.38,4,"SZN"}, -- szenarios
		--{78777,390,83.05,30.48,4,"SZHC"}, -- hc szenarios
		{80633,390,83.16,30.56,4,"LFR",imgs={"mop1","mop2","mop3"}}, -- lfr
		-- WoD, lfr (same npc id and different location for alliance and horde)
		faction=="alliance"
			and {94870,582,33.2,37.2,5,"LFR",imgs={"wod1_"..faction,"wod2_"..faction,"wod3_"..faction}}
			or {94870,590,41.5,47.0,5,"LFR",imgs={"wod1_"..faction,"wod2_"..faction,"wod3_"..faction}},
		-- legion
		{111246,627,63.6,55.6,6,"LFR",imgs={"legion1","legion2","legion3"}},
		-- bfa // coming soon // 9.1 ?
		--[[
		faction=="alliance"
			and {144383,1161,74.10,14.16,7,"LFR"}
			or {144384,1165,56.63,88.58,7,"LFR"},
		]]
	};

	wipe(ns.npcID);

	for i=1, #ns.npcs do
		local strs = ns.scanTT:GetStringRegions("SetHyperlink","unit:Creature-0-0-0-0-"..ns.npcs[i][1].."-0");
		ns.npcID[ns.npcs[i][1]]=1;
		if strs[1] and strs[1]~="" then
			L["NPC"..ns.npcs[i][1]] = strs[1];
		end

		local mapInfo = C_Map.GetMapInfo(ns.npcs[i][2]);
		if mapInfo then
			if mapInfo.name == DUNGEON_FLOOR_DALARANCITY1 then
				local spell = GetSpellInfo(224869);
				local _,target = strsplit(HEADER_COLON,spell,2);
				if target then
					mapInfo.name = target:trim(); -- replace "Dalaran" by "Dalaran - Broken Isles"
				end
			end
			ns.npcs[i].zoneName = mapInfo.name;
		end
	end
end

ns.instance2bosses = {
	-- cata
	[416]={1,2,3,4},[417]={5,6,7,8},
	-- mop
	[527]={1,2,3},[528]={4,5,6}, -- 1
	[529]={1,2,3},[530]={4,5,6}, -- 2
	[610]={1,2,3},[611]={4,5,6},[612]={7,8,9},[613]={10,11,12}, -- 3
	[716]={1,2,4},[717]={5,6,7,8},[724]={9,10,11},[725]={12,13,14}, -- 4
	-- wod
	[849]={1,2,3},[850]={4,5,6},[851]={7},  -- 1
	[847]={1,2,7},[846]={3,8,5},[848]={4,6,9},[823]={10}, -- 2
	[982]={1,2,3},[983]={4,5,6},[984]={7,8,11},[985]={9,10,12},[986]={13}, -- 3
	-- legion
	[1287]={1,5,3},[1288]={2,4,6},[1289]={7}, -- 1
	[1290]={1,2,3},[1291]={4,8,6},[1292]={5,7,9},[1293]={10}, -- 2
	[1411]={1,2,3}, -- 3
	[1494]={1,3,5},[1495]={2,4,6},[1496]={7,8},[1497]={9}, -- 4
	[1610]={1,2,4},[1611]={5,3,6},[1612]={7,8,9},[1613]={10,11}, -- 5
	-- bfa
	--[1731]={1,2,4},[1732]={3,5,6},[1733]={7,8}, -- Uldir
	--[1945]={1,2,3},[1946]={4,5,6},[1947]={7,8}, -- dazar'alor
	-- eternal palace
	-- ny'alotha
};

ns.noSubtitle = { -- by npc id
	[78709]=1,
	[78777]=1,
};

ns.gossip2instance = {
	-- [<npcID>] = { <instanceIDs> }
	-- cata
	[80675] = {416,417}, -- lfr
	-- mop
	[78709] = {492,499,504,511,517,539,542,593,586,589,590,588,624,625,637}, -- szenarios (not lfr but usefull for somebody ^_^)
	[78777] = {652,647,649,646,639,648}, -- heroic szenarios (not lfr but usefull for somebody ^_^)
	[80633] = {527,528,529,530,526,610,611,612,613,716,717,724,725}, -- lfr
	-- wod
	[94870] = {849,850,851,847,846,848,823,982,983,984,985,986}, -- lfr
	-- legion
	[111246] = {1287,1288,1289,1290,1291,1292,1293,1411,1494,1495,1496,1497,1610,1611,1612,1613}, -- lfr
	-- bfa
	--[0] = {1731,1732,1733,1945,1946,1947,1951},
};

ns.lfrID = {
	416,417, -- cata
	527,528,529,530,526,610,611,612,613,716,717,724,725, -- mop
	849,850,851,847,846,848,823,982,983,984,985,986, -- wod
	1287,1288,1289,1411,1290,1291,1292,1293,1494,1495,1496,1497,1610,1611,1612,1613, -- legion
	-- 1731,1732,1733,1945,1946,1947,1951, -- bfa
}

