
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
		{80675,74,63.1,27.3,3,"LFR",imgs={"cata%d",4},indexOffset=1,patch="6.0.1",
			{416,42612,1,2,3,4,alt={843}},{417,42613,5,6,7,8,alt={844}}, -- dragon soul
		},

		-- mop (patch 6.0.1)
		{80633,390,83.16,30.56,4,"LFR",imgs={"mop%d",3},noSubtitle={[526]=true},patch="6.0.1",
			{527,42620,1,2,3,alt={830,2598}},{528,42621,4,5,6,alt={831,2597}},
			{529,42622,1,2,3,alt={832,2596}},{530,42623,4,5,6,alt={833,2595}},
			{526,42624,1,2,3,4,alt={834,2599}},
			{610,42625,1,2,3,alt={835,2594}},{611,42626,4,5,6,alt={836,2593}},{612,42627,7,8,9,alt={837,2592}},{613,42628,10,11,12,alt={838,2591}},
			{716,42629,1,2,4,alt={839,2590}},{717,42630,5,6,7,8,alt={840,2589}},{724,42631,9,10,11,alt={841,2588}},{725,42632,12,13,14,alt={842,2587}}
		},
		{78709,390,82.95,30.38,4,"SZN",addTo=2,order=2,noSubtitle=true,patch="6.0.1",
			{492,42511},{499,42512},{504,42513},{511,42514},{517,42515},{539,42516},{_(543,542),42517},{586,42519},{588,42523},{589,42520},{590,42522},{593,42518},{595,42521},{624,42524},{625,42525},{637,42526}
		},
		{78777,390,83.05,30.48,4,"SZHC",addTo=2,order=3,noSubtitle=true,patch="6.0.1",
			{639,42577},{646,42576},{647,42574},{648,42578},{649,42575},{652,42573}
		},

		-- WoD (patch 6.2.0) (same npc id and different location for alliance and horde)
		{_(94870,94870),_(582,590),_(33.2,41.5),_(37.2,47.0),5,"LFR",imgs={"wod%d_%s",3},indexOffset=1,patch="6.2.0",
			{849,44390,1,2,3,alt={1363}},{850,44391,4,5,6,alt={1364}},{851,44392,7,alt={1365}},
			{847,44393,1,2,7,alt={1359}},{846,44394,3,8,5,alt={1360}},{848,44395,4,6,9,alt={1361}},{823,44396,10,alt={1362}},
			{982,44397,1,2,3,alt={1366}},{983,44398,4,5,6,alt={1367}},{984,44399,7,8,11,alt={1368}},{985,44400,9,10,12,alt={1369}},{986,44401,13,alt={1370}},
		},

		-- legion (patch 7.0.3)
		{111246,627,63.6,55.6,6,"LFR",imgs={"legion%d",3},indexOffset=1,patch="7.0.3",
			{1287,37110,1,5,3,alt={1912,2844}},{1288,37111,2,4,6,alt={1927,2845}},{1289,37112,7,alt={1926,2846}},
			{1290,37113,1,2,3,alt={1925,2847}},{1291,37114,4,8,6,alt={1924,2848}},{1292,37115,5,7,9,alt={1923,2849}},{1293,37116,10,alt={1922,2850}},
			{1411,37117,1,2,3,alt={1921,2851}},
			{1494,37118,1,3,5,alt={1920,2835}},{1495,37119,2,4,6,alt={1919,2836}},{1496,37120,7,8,alt={1918,2848}},{1497,37121,9,alt={1917,2838}},
			{1610,37122,1,2,4,alt={1916,2821}},{1611,37123,5,3,6,alt={1915,2822}},{1612,37124,7,8,9,alt={1914,2823}},{1613,37125,10,11,alt={1913,2824}}
		},
		{31439,125,63.6,55.6,6,"LFR",addTo=6,order=2,imgs={"legion%d",3},info=L["TimearLegion"],indexOffset=1,patch="?",
			copyFrom = 111246
		},

		-- bfa (patch 9.0.5)
		{_(177193,177208),_(1161,1165),_(74.21,13.53),_(68.62,30.27),7,"LFR",imgs={"bfa%d_%s",3},indexOffset=false,patch="9.0.5",
			{1731,52303,1,2,3},{1732,52304,4,5,6},{1733,52305,7,8}, -- Uldir
			{_(1945,1948),_(52309,52306),1,2,3,name2group=true},{_(1946,1949),_(52310,52307),4,5,6},{_(1947,1950),_(52311,52308),7,8,9}, -- dazar'alor
			{1951,52312,1,2}, -- Crucible of Storms
			{2009,52313,1,3,2},{2010,52314,4,5,6},{2011,52315,7,8}, -- eternal palace
			{2036,52316,1,3,2},{2037,52317,4,6,5,7},{2038,52318,8,9,10},{2039,0,11,12}, -- ny'alotha (TODO: 2039 need check)
		},

		-- shadowlands (patch 10.1.5)
		{205959,1670,41.4,71.41,8,"LFR",imgs={"sl%d",2},patch="10.1.5",
			{2411,110020,2,4,6, alt={2090} },{2412,110037,3,5,7, alt={2091} },{2413,110036,1,8,9, alt={2092} },{2414,110035,10, alt={2096} }, -- castle nathria
			{2221,110034,1,2,3,alt={2341,2415}},{2222,110033,4,5,6,alt={2342,2416}},{2223,110032,7,8,9,alt={2343,2417}},{2224,110031,10,alt={2344,2418}}, -- Sanctum of Domination 9.1.0
			{2291,110030,2,4,7,alt={2345,2419}},{2292,110029,1,3,5,6,alt={2346,2420}},{2293,110028,8,9,10,alt={2347,2421}},{2294,110027,11,alt={2348,2422}}, -- Sepulcher of the First Ones 9.2.0
		},

		-- dragonflight (patch 12.0.5); why it was not added at 11.0.5 or 11.1.5?
		{262873, 2112, 58.48, 35.37, 9, "LFR",imgs={"df%d",3},patch="12.0.5",
			{2703,0,1,2,3,alt={2370}},{2705,1,4,5,6,alt={2371}},{2706,2,7,8,alt={2372}},
			{2704,3,1,2,3,alt={2399}},{2707,4,4,5,6,alt={2400}},{2708,5,7,8,alt={2401}},{2709,6,9, alt={2402}},
			{2710,7,1,2,3,alt={2466}},{2468,8,4,5,6,alt={2711}},{2712,9,7,8,alt={2467}},{2713,10,9,alt={2469}},
		},

		-- the war within (patch ??.??.??)
		-- still missing...
		{0, 0, 0, 0, 10, "LFR",imgs={"tww%d",3},patch="missing",
		 	{2649,0,1,2,3}, {2650,1,1,2,3}, {2651,2,1,2},
		 	{2780,3,1,2}, {2781,4,1,2}, {2782,5,1,2,3}, {2783,6,1},
		 	{2799,7,1,2,3}, {2800,8,1,2,3}, {2801,9,1,2,3},
		},

		-- midnight (patch ??.??.??)
		--{0, 0, 0, 0, 11, "LFR",imgs={"mn%d",3},patch="missing",
		-- 	{3126,0,1}, -- dream cut?
		-- 	{3156,1,1,2,3}, {3159,2,4,5,6}, {3160,3,7}, -- void spike
		-- 	{3155,4,1,2,3},
		--},

		-- last titan (patch ??.??.??)
		--{0, 0, 0, 0, 12, "LFR",imgs={"tlt%d",3},
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
				if e.alt then
					-- This part catching a problem with GetInstanceInfo() that could return a different instanceID than expected.
					local N = GetLFGDungeonNumEncounters(e[1])
					for a=1, #e.alt do
						local nAlt = GetLFGDungeonNumEncounters(e.alt[a])
						if nAlt<N then
							-- some lfr wings have multiple ids with different GetLFGDungeonNumEncounters() results.
							local b = {}
							for n=0, nAlt do
								tinsert(b,n)
							end
							ns.instance2bosses[e.alt] = b;
						else
							ns.instance2bosses[e.alt] = ns.instance2bosses[e[1]]
						end
					end
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
