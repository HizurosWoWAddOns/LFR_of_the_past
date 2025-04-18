
local addon,ns = ...;
local L=ns.L;
ns.npcID = {};
ns.npcs = {};

function ns.load_data()
	local Alliance = UnitFactionGroup("player")=="Alliance";
	local npc_wod = {94870,582,33.2,37.2,5,"LFR",imgs={"wod1_%s","wod2_%s","wod3_%s"}};
	local npc_bfa = {177193,1161,74.21,13.53,7,"LFR",imgs={"bfa1_%s","bfa2_%s","bfa3_%s"}};
	local theramores_fall = 543;
	if not Alliance then
		npc_wod[2],npc_wod[3],npc_wod[4] = 590,41.5,47.0;
		npc_bfa[1],npc_bfa[2],npc_bfa[3],npc_bfa[4] = 177208,1165,68.62,30.27;
		theramores_fall = 542;
	end

	-- {<npcis>, <zoneid>, <posX>, <posY>, <expansionNumber>, <instanceType>}
	-- expansionNumber is for _G["EXPANSION_NAME"..<expansionNumber>]
	ns.npcs = {
		-- cata
		{80675,74,63.1,27.3,3,"LFR",imgs={"cata1","cata2","cata3","cata4"}},
		-- mop
		{80633,390,83.16,30.56,4,"LFR",imgs={"mop1","mop2","mop3"}}, -- lfr
		{78709,390,82.95,30.38,4,"SZN",addTo=2,order=2}, -- szenarios
		{78777,390,83.05,30.48,4,"SZHC",addTo=2,order=3}, -- hc szenarios
		-- WoD, lfr (same npc id and different location for alliance and horde)
		npc_wod,
		-- legion
		{111246,627,63.6,55.6,6,"LFR",imgs={"legion1","legion2","legion3"}},
		-- bfa
		npc_bfa,
		-- shadowlands
		{205959,1670,41.4,71.41,8,"LFR",imgs={"sl1","sl2"}},
	};

	ns.instance2bosses = {
		-- cata
		[416]={1,2,3,4},[417]={5,6,7,8},
		-- mop
		[527]={1,2,3},[528]={4,5,6}, -- 1
		[529]={1,2,3},[530]={4,5,6}, -- 2
		[526]={1,2,3,4},
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
		[1731]={1,2,3},[1732]={4,5,6},[1733]={7,8}, -- Uldir
		[1945]={1,2,3},[1946]={4,5,6},[1947]={7,8,9}, -- dazar'alor // alliance
		[1948]={1,2,3},[1949]={4,5,6},[1950]={7,8,9}, -- dazar'alor // horde
		[1951]={1,2}, -- tiegel der stürme
		[2009]={1,3,2},[2010]={4,5,6},[2011]={7,8}, -- eternal palace
		[2036]={1,3,2},[2037]={4,6,5,7},[2038]={8,9,10},[2039]={11,12}, -- ny'alotha
		-- sl
		[2090]={2,4,6},[2091]={3,5,7},[2092]={1,8,9},[2096]={10}, -- castle nathria
		[2221]={1,2,3},[2222]={4,5,6},[2223]={7,8,9},[2224]={10}, -- Sanctum of Domination 9.1.0
		[2291]={2,4,7},[2292]={1,3,5,6},[2293]={8,9,10},[2294]={11}, -- Sepulcher of the First Ones 9.2.0
		-- df
	};

	ns.instance2bossesAlt = {
		[2090]={1,2,3},[2091]={1,2,3},[2092]={1,2,3},[2096]={1}, -- castle nathria
	}

	-- hide subtitle for szenario and single wing lfr
	ns.noSubtitle = {
		[78709]=true,
		[78777]=true,
		[80633] = {[526]=true},
	};

	ns.gossipOptionsOrderIndexOffset = {
		-- [<npcID>] = <number>
		-- cata
		[80675] = 1, -- lfr, working
		-- mop
		[78709] = 0, -- szenarios
		[78777] = 0, -- heroic szenarios
		[80633] = 0, -- lfr, working
		-- wod
		[94870] = 1, -- lfr, working
		-- legion
		[111246] = 1, -- lfr, working
		-- bfa
		[177193] = false,
		-- sl
		[205959] = 0,
	}

	ns.gossip2instance = {
		-- [<npcID>] = { <instanceIDs> }
		-- or [<npcID>] = { [<gossipOptionID>] = <instanceIDs> }
		-- cata
		[80675] = {[42612]=416,[42613]=417}, -- lfr
		-- mop
		[78709] = { -- szenarios
			[42511]=492,[42512]=499,[42513]=504,[42514]=511,[42515]=517,[42516]=539,[42517]=theramores_fall,
			[42518]=593,[42519]=586,[42520]=589,[42521]=595 --[[horde]],[42522]=590 --[[ally]],[42523]=588,
			[42524]=624,[42525]=625,[42526]=637
		},
		[78777] = { -- heroic szenarios
			[42573]=652,[42574]=647,[42575]=649,[42576]=646,[42577]=639,[42578]=648,
		},
		[80633] = { -- lfr
			[42620]=527,[42621]=528,[42622]=529,[42623]=530,[42624]=526,[42625]=610,[42626]=611,[42627]=612,[42628]=613,[42629]=716,[42630]=717,[42631]=724,[42632]=725
		},
		-- wod
		[94870] = { -- lfr
			[44390]=849,[44391]=850,[44392]=851,[44393]=847,[44394]=846,[44395]=848,[44396]=823,[44397]=982,[44398]=983,[44399]=984,[44400]=985,[44401]=986
		},
		-- legion
		[111246] = { -- lfr
			[37110]=1287,[37111]=1288,[37112]=1289,[37113]=1290,[37114]=1291,[37115]=1292,[37116]=1293,[37117]=1411,
			[37118]=1494,[37119]=1495,[37120]=1496,[37121]=1497,[37122]=1610,[37123]=1611,[37124]=1612,[37125]=1613
		},
		-- bfa
		[npc_bfa[1]] = { -- lfr
			[52303]=1731,[52304]=1732,[52305]=1733, -- uldir
			[52306]=1948,[52307]=1949,[52308]=1950, -- dazar'alor (horde)
			[52309]=1945,[52310]=1946,[52311]=1947, -- dazar'alor (alliance)
			[52312]=1951, -- Crucible of Storms
			[52313]=2009,[52314]=2010,[52315]=2011, -- The Eternal Palace
			[52316]=2036,[52317]=2037,[52318]=2038, -- ny'alotha
		},
		-- sl
		[205959] = {
			[110020]=2090,[110037]=2091,[110036]=2092,[110035]=2096, -- castle nathria 9.0
			[110034]=2221,[110033]=2222,[110032]=2223,[110031]=2224, -- Sanctum of Domination 9.1.0
			[110030]=2291,[110029]=2292,[110028]=2293,[110027]=2294, -- Sepulcher of the First Ones 9.2.0
		},
	};
	ns.idx2gossipOptionID = {
		[80675] = {42612,42613}, -- lfr
		-- mop
		[78709] = { -- szenarios
			42511,42512,42513,42514,42515,42516,42517,
			42518,42519,42520,42522,42523,
			42524,42525,42526
		},
		[78777] = { -- heroic szenarios
			42573,42574,42575,42576,42577,42578,
		},
		[80633] = { -- lfr
			42620,42621,42622,42623,42624,42625,42626,42627,42628,42629,42630,42631,42632
		},
		-- wod
		[94870] = { -- lfr
			44390,44391,44392,44393,44394,44395,44396,44397,44398,44399,44400,44401
		},
		-- legion
		[111246] = { -- lfr
			37110,37111,37112,37113,37114,37115,37116,37117,
			37118,37119,37120,37121,37122,37123,37124,37125
		},
		-- bfa
		[npc_bfa[1]] = { -- lfr
			52303,52304,52305, -- uldir
			52309,52310,52311, -- dazar'alor (alliance)
			52312, -- Crucible of Storms
			52313,52314,52315, -- The Eternal Palace
			52316,52317,52318, -- ny'alotha
		},
		[205959] = {
			110020,110037,110036,110035, -- castle nathria
			110034,110033,110032,110031, -- Sanctum of Domination 9.1.0
			110030,110029,110028,110027, -- Sepulcher of the First Ones 9.2.0
		},
	}
	if not Alliance then
		ns.idx2gossipOptionID[78709][11]=42521
		-- dazar'alor (horde)
		ns.idx2gossipOptionID[npc_bfa[1]][4]=52306
		ns.idx2gossipOptionID[npc_bfa[1]][5]=52307
		ns.idx2gossipOptionID[npc_bfa[1]][6]=52308
	end

	ns.lfrID = {
		416,417, -- cata
		527,528,529,530,526,610,611,612,613,716,717,724,725, -- mop
		849,850,851,847,846,848,823,982,983,984,985,986, -- wod
		1287,1288,1289,1411,1290,1291,1292,1293,1494,1495,1496,1497,1610,1611,1612,1613, -- legion
		1731,1732,1733, 1945,1946,1947, 1948,1949,1950, 1951, 2009,2010,2011, 2036,2037,2038, -- bfa
		2090,2091,2092,2096,2221,2222,2223,2224,2291,2292,2293,2294, -- sl
	}
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
				local spell = C_Spell.GetSpellInfo(224869);
				local _,target = strsplit(HEADER_COLON,spell.name,2);
				if target then
					mapInfo.name = target:trim(); -- replace "Dalaran" by "Dalaran - Broken Isles"
				end
			end
			ns.npcs[i].zoneName = mapInfo.name;
		end
	end
end
