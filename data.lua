
local addon,ns = ...;
local L=ns.L;
ns.npcID = {};
ns.npcs = {};
ns.instance2bosses = {} -- -GetInstanceDataByID
ns.gossipIndexOffset = {} -- GossipFrame.OnShow
ns.npc2instance = {} -- buttonHook_OnEnter, GossipFrame.OnShow, OnImmersionShow
ns.idx2gossipOptionID = {} -- OnImmersionShow
ns.instanceName2group = {} -- GetInstanceDataByID
ns.noSubtitle = {}; -- buttonHook_OnEnter, GossipFrame.OnShow, OnImmersionShow

local function UpdateNpcData(entry)
	if not entry then
		wipe(ns.npcID);
		for i=1, #ns.npcs do
			UpdateNpcData(ns.npcs[i])
		end
		return
	end
	ns.npcID[entry[1]]=1;
	local mapInfo = C_Map.GetMapInfo(entry[2]);
	if mapInfo then
		if  mapInfo.name == DUNGEON_FLOOR_DALARANCITY1 then
			local spell = C_Spell.GetSpellInfo((entry[2]==627 and 224869) or (entry[2]==125 and 53140));
			local _,target = strsplit(HEADER_COLON,spell.name,2);
			if target then
				mapInfo.name = target:trim(); -- replace "Dalaran" by "Dalaran - Broken Isles"
			end
		end
		entry.zoneName = mapInfo.name;
	end

	if type(entry.alt)=="table" then
		UpdateNpcData(entry.alt)
	end
end

function ns.load_data()
	local faction = UnitFactionGroup("player");
	local Alliance = faction=="Alliance";
	local function _(a,h)
		return Alliance and a or h;
	end

	-- {<npcid>, <zoneid>, <posX>, <posY>, <expansionNumber>, <instanceType>, <instances[...]>}
	-- expansionNumber is for _G["EXPANSION_NAME"..<expansionNumber>]
	local data = {
		-- cata (patch 6.0.1)
		{80675,74,63.1,27.3,3,"LFR",imgs={"cata1","cata2","cata3","cata4"},indexOffset=1,patch="6.0.1",
			{416,42612,1,2,3,4},{417,42613,5,6,7,8}, -- dragon soul
		},

		-- mop (patch 6.0.1)
		{80633,390,83.16,30.56,4,"LFR",imgs={"mop1","mop2","mop3"},noSubtitle={[526]=true},patch="6.0.1",
			{527,42620,1,2,3},{528,42621,4,5,6},
			{529,42622,1,2,3},{530,42623,4,5,6},
			{526,42624,1,2,3,4},
			{610,42625,1,2,3},{611,42626,4,5,6},{612,42627,7,8,9},{613,42628,10,11,12},
			{716,42629,1,2,4},{717,42630,5,6,7,8},{724,42631,9,10,11},{725,42632,12,13,14}
		},
		{78709,390,82.95,30.38,4,"SZN",addTo=2,order=2,noSubtitle=true,patch="6.0.1",
			{492,42511},{499,42512},{504,42513},{511,42514},{517,42515},{539,42516},{_(543,542),42517},{586,42519},{588,42523},{589,42520},{590,42522},{593,42518},{595,42521},{624,42524},{625,42525},{637,42526}
		},
		{78777,390,83.05,30.48,4,"SZHC",addTo=2,order=3,noSubtitle=true,patch="6.0.1",
			{639,42577},{646,42576},{647,42574},{648,42578},{649,42575},{652,42573}
		},

		-- WoD (patch 6.2.0) (same npc id and different location for alliance and horde)
		{_(94870,94870),_(582,590),_(33.2,41.5),_(37.2,47.0),5,"LFR",imgs={"wod1_"..faction,"wod2_"..faction,"wod3_"..faction},indexOffset=1,patch="6.2.0",
			{849,44390,1,2,3},{850,44391,4,5,6},{851,44392,7},
			{847,44393,1,2,7},{846,44394,3,8,5},{848,44395,4,6,9},{823,44396,10},
			{982,44397,1,2,3},{983,44398,4,5,6},{984,44399,7,8,11},{985,44400,9,10,12},{986,44401,13},
		},

		-- legion (patch 7.0.3)
		{111246,627,63.6,55.6,6,"LFR",imgs={"legion1","legion2","legion3"},indexOffset=1,patch="7.0.3",
			{1287,37110,1,5,3},{1288,37111,2,4,6},{1289,37112,7},
			{1290,37113,1,2,3},{1291,37114,4,8,6},{1292,37115,5,7,9},{1293,37116,10},
			{1411,37117,1,2,3},
			{1494,37118,1,3,5},{1495,37119,2,4,6},{1496,37120,7,8},{1497,37121,9},
			{1610,37122,1,2,4},{1611,37123,5,3,6},{1612,37124,7,8,9},{1613,37125,10,11}
		},
		{31439,125,63.6,55.6,6,"LFR",addTo=6,order=2,imgs={"legion1","legion2","legion3"},info=L["TimearLegion"],indexOffset=1,patch="?",
			copyFrom = 111246
		},

		-- bfa (patch 9.0.5)
		{_(177193,177208),_(1161,1165),_(74.21,13.53),_(68.62,30.27),7,"LFR",imgs={"bfa1_"..faction,"bfa2_"..faction,"bfa3_"..faction},indexOffset=false,patch="9.0.5",
			{1731,52303,1,2,3},{1732,52304,4,5,6},{1733,52305,7,8}, -- Uldir
			{_(1945,1948),_(52309,52306),1,2,3,name2group=true},{_(1946,1949),_(52310,52307),4,5,6},{_(1947,1950),_(52311,52308),7,8,9}, -- dazar'alor
			{1951,52312,1,2}, -- Crucible of Storms
			{2009,52313,1,3,2},{2010,52314,4,5,6},{2011,52315,7,8}, -- eternal palace
			{2036,52316,1,3,2},{2037,52317,4,6,5,7},{2038,52318,8,9,10},{2039,0,11,12}, -- ny'alotha (TODO: 2039 need check)
		},

		-- shadowlands (patch 10.1.5)
		{205959,1670,41.4,71.41,8,"LFR",imgs={"sl1","sl2"},patch="10.1.5",
			{2090,110020,1,2,3},{2091,110037,1,2,3},{2092,110036,1,2,3},{2096,110035,1}, -- castle nathria
			{2221,110034,1,2,3},{2222,110033,4,5,6},{2223,110032,7,8,9},{2224,110031,10}, -- Sanctum of Domination 9.1.0
			{2291,110030,2,4,7},{2292,110029,1,3,5,6},{2293,110028,8,9,10},{2294,110027,11}, -- Sepulcher of the First Ones 9.2.0
		},

		-- dragonflight (patch 12.0.5); why it was not added at 11.0.5 or 11.1.5?
		{262873, 2112, 58.48, 35.37, 9, "LFR",imgs={"df1","df2","df3"},patch="12.0.5",
			{2703,0,1,2,3},{2705,1,4,5,6},{2706,2,7,8},
			{2704,3,1,2,3},{2707,4,4,5,6},{2708,5,7,8},{2709,6,9},
			{2710,7,1,2,3},{2468,8,4,5,6},{2712,9,7,8},{2713,10,9},
		},

		-- the war within (patch ??.??.??)
		-- still missing...
		{0, 0, 0, 0, 10, "LFR",imgs={"tww1","tww2","tww3"},patch="missing",
		 	{2649,0,1,2,3}, {2650,1,1,2,3}, {2651,2,1,2},
		 	{2780,3,1,2}, {2781,4,1,2}, {2782,5,1,2,3}, {2783,6,1},
		 	{2799,7,1,2,3}, {2800,8,1,2,3}, {2801,9,1,2,3},
		},

		-- midnight (patch ??.??.??)
		--{0, 0, 0, 0, 11, "LFR",imgs={"mn1","mn2","mn3"},patch="missing",
		-- 	{3126,0,1}, -- dream cut?
		-- 	{3156,1,1,2,3}, {3159,2,4,5,6}, {3160,3,7}, -- void spike
		-- 	{3155,4,1,2,3},

		--},

		-- last titan (patch ??.??.??)
		--{0, 0, 0, 0, 12, "LFR",imgs={"tlt1","tlt2","tlt3"},
		--},
	};

	local npcID2Index = {}

	for i=1, #data do
		local npcID,npcID2 = data[i][1];
		if data[i].altNPC then
			npcID2 = data[i].altNPC[1];
		end
		tinsert(ns.npcs,data[i])
		local npcIndex = #ns.npcs;
		npcID2Index[npcID] = npcIndex;
		for j=7, #data[i] do
			local e = data[i][j];
			--
			if not ns.idx2gossipOptionID[npcID] then
				ns.idx2gossipOptionID[npcID]={};
			end
			tinsert(ns.idx2gossipOptionID[npcID],e[2]);
			if npcID2 then
				ns.idx2gossipOptionID[npcID2] = ns.idx2gossipOptionID[npcID];
			end
			--
			if not ns.npc2instance[npcID] then
				ns.npc2instance[npcID] = {}
			end
			ns.npc2instance[npcID][e[2]] = e[1];
			if npcID2 then
				ns.npc2instance[npcID2] = ns.npc2instance[npcID];
			end
			--
			if e.name2group then
				ns.instanceName2group[e[1]] = e.name2group;
			end
			--
			if e[3] then
				ns.instance2bosses[e[1]] = {}
				for k=3, #e do
					tinsert(ns.instance2bosses[e[1]],e[k]);
				end
			end
			--
			ns.gossipIndexOffset[npcID] = data[i].indexOffset==nil and 0 or data[i].indexOffset;
			--
			if data[i].noSubtitle then
				ns.noSubtitle[npcID] = data[i].noSubtitle;
			end
		end

		if data[i].copyFrom and npcID2Index[data[i].copyFrom] then
			local d = ns.npcs[npcID2Index[data[i].copyFrom]];
			for j=7, #d do
				tinsert(data,d[j]);
			end
		end
	end

	UpdateNpcData()
end
