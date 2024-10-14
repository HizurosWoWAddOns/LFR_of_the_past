
local addon, ns = ...;
local L = ns.L;
ns.debugMode = "@project-version@"=="@".."project-version".."@";
local HST = LibStub("HizurosSharedTools")
HST.RegisterPrint(ns,addon,"LFRotp");

local ACD = LibStub("AceConfigDialog-3.0");
local LDB = LibStub("LibDataBroker-1.1");
local LDBIcon = LibStub("LibDBIcon-1.0", true);

local buttons,hookedButton,NPC_ID,db = {},{};
local iconTexCoords,killedEncounter,BossKillQueryUpdate,UpdateInstanceInfoLock = {},{},false,false;
local imgSize,imgPath = 168,"Interface\\AddOns\\LFR_of_the_past\\media\\";

local LC = LibStub("LibColors-1.0");
local C = LC.color;
LC.colorset({
	["ltyellow"]	= "fff569",
	["dkyellow"]	= "ffcc00",
	["ltorange"]	= "ff9d6a",
	["dkorange"]	= "905d0a",
	["ltred"]		= "ff8080",
	["ltred2"]		= "ff4040",
	["dkred"]		= "800000",
	["violet"]		= "f000f0",
	["ltviolet"]	= "f060f0",
	["dkviolet"]	= "800080",
	["ltblue"]		= "69ccf0",
	["dkblue"]		= "000088",
	["dailyblue"]	= "00b3ff",
	["ltcyan"]		= "80ffff",
	["dkcyan"]		= "008080",
	["ltgreen"]		= "80ff80",
	["dkgreen"]		= "00aa00",
	["dkgray"]		= "404040",
	["gray2"]		= "A0A0A0",
	["ltgray"]		= "b0b0b0",
	["gold"]		= "ffd700",
	["silver"]		= "eeeeef",
	["copper"]		= "f0a55f",
	["unknown"]		= "ee0000",
});
local skull = "|T337496:12:12:0:0:32:32:0:16:0:16|t ";
local GossipTextPattern = {};
do
	local colors = {enemy="dkred",enemyClear="dkgreen",enemyDarkBG="ltred2",enemyClearDarkBG="green"}
	for k,v in pairs(colors)do
		GossipTextPattern[k] = "%s\n"..skull..C(v,"%d/%d");
	end
end
GossipTextPattern.raidWing = " "..C("dkgray","|| %s");
GossipTextPattern.raidWingDarkBG = " "..C("gray","|| %s");
GossipTextPattern.raidWingImmersion = "%1$s\n"..C("gray","%4$s").."\n"..skull..C("ltred2","%2$d/%3$d");
GossipTextPattern.raidWingImmersionClear = "%1$s\n"..C("gray","%4$s").."\n"..skull..C("green","%2$d/%3$d");


------------------------------------------------
-- GameTooltip to get localized names and other informations

ns.scanTT = CreateFrame("GameTooltip",addon.."_ScanTT",UIParent,"GameTooltipTemplate");
ns.scanTT:SetScale(0.0001); ns.scanTT:SetAlpha(0); ns.scanTT:Hide();
-- unset script functions shipped by GameTooltipTemplate to prevent errors
for _,v in ipairs({"OnLoad","OnHide","OnTooltipSetDefaultAnchor","OnTooltipCleared"})do ns.scanTT:SetScript(v,nil); end

function ns.scanTT:GetStringRegions(dataFunction,...)
	if type(self[dataFunction])~="function" then return false; end

	ns.scanTT:SetOwner(UIParent,"ANCHOR_NONE");
	self[dataFunction](self,...);
	ns.scanTT:Show();

	local regions,strs = {ns.scanTT:GetRegions()},{};
	for i=1,#regions do
		if (regions[i]~=nil) and (regions[i]:GetObjectType()=="FontString") then
			local str = strtrim(regions[i]:GetText() or "");
			if str~="" then
				tinsert(strs,str);
			end
		end
	end

	ns.scanTT:Hide();

	return strs;
end

------------------------------------------------

function ns.faction(isNeutral)
	local faction = (UnitFactionGroup("player") or "neutral"):lower();
	if isNeutral then
		return faction=="neutral";
	end
	return faction;
end

local function GetInstanceDataByID(instanceID)
	local data = {
		groupName = false,
		instanceID = instanceID,
		instanceInfo = {},
		numEncounters = {0,0},
		encounters = {}
	};
	local info = {};
	info.name, info.typeID, info.subtypeID, info.minLevel, info.maxLevel, info.recLevel, info.minRecLevel, info.maxRecLevel, info.expansionLevel,
	info.groupID, info.textureFilename, info.difficulty, info.maxPlayers, info.description, info.isHoliday, info.bonusRepAmount, info.minPlayers,
	info.isTimeWalker, info.name2, info.minGearLevel, info.isScalingDungeon, info.lfgMapID = GetLFGDungeonInfo(instanceID);
	data.instanceInfo = info;

	if data.instanceInfo.name~=data.instanceInfo.name2 then
		data.groupName = data.instanceInfo.name2;
	end
	local bossIndexes = {};
	if ns.instance2bosses[instanceID] then
		bossIndexes = ns.instance2bosses[instanceID];
		data.numEncounters[2] = #ns.instance2bosses[instanceID];
	else
		data.numEncounters[2] = GetLFGDungeonNumEncounters(instanceID) or 0;
		for i=1, data.numEncounters[2] do
			tinsert(bossIndexes,i);
		end
	end
	for _,i in ipairs(bossIndexes) do
		local boss, _, isKilled = GetLFGDungeonEncounterInfo(instanceID,i);
		local n = (data.instanceInfo.name2 or data.instanceInfo.name).."-"..data.instanceInfo.difficulty;
		if not isKilled and killedEncounter[n] and killedEncounter[n][boss] then
			isKilled = true;
		end
		if isKilled then
			data.numEncounters[1] = data.numEncounters[1] + 1;
			tinsert(data.encounters,boss);
		end
	end
	return data;
end

local function RequestRaidInfoUpdate()
	if BossKillQueryUpdate then
		RequestRaidInfo();
	end
end

local function ScanSavedInstances()
	for index=1, (GetNumSavedInstances()) do
		local instanceName, _, instanceReset, instanceDifficulty, _, _, _, _, _, _, _, encounterProgress = GetSavedInstanceInfo(index);
		if (instanceDifficulty==7 or instanceDifficulty==17) and encounterProgress>0 and instanceReset>0 then
			local encounters,strs = {},ns.scanTT:GetStringRegions("SetInstanceLockEncountersComplete",index);
			if strs then
				for i=2, #strs, 2 do
					encounters[strs[i]] = strs[i+1]==BOSS_DEAD;
				end
				killedEncounter[instanceName.."-"..instanceDifficulty] = encounters;
			end
		end
	end
	UpdateInstanceInfoLock = false;
end

local function GetEncounterStatus(instanceID)
	local encounter,num = {},GetLFGDungeonNumEncounters(instanceID);
	local _, _, _, _, _, _, _, _, _, _, _, difficulty, _, _, _, _, _, _, name2 = GetLFGDungeonInfo(instanceID);
	local instanceTag = name2.."-"..difficulty;
	for i=1, num do
		local boss, _, isKilled = GetLFGDungeonEncounterInfo(instanceID,i);
		if not isKilled and killedEncounter[instanceTag] and killedEncounter[instanceTag][boss] then
			isKilled = true;
		end
		tinsert(encounter,{boss,isKilled});
	end
	return encounter;
end

local function UpdateNpcID()
	local id,_ = UnitGUID("npc");
	if id then
		_,_,_,_,_,id = strsplit('-',id);
	end
	NPC_ID = tonumber(id);
end

local instanceGroupsBuild = false;
local InstanceGroups = setmetatable({},{
	__index = function(t,k)
		if not instanceGroupsBuild then -- build group list
			local current;
			for i=1, #ns.lfrID do
				local name, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, name2 = GetLFGDungeonInfo(ns.lfrID[i])
				if not rawget(t,name2) then
					rawset(t,name2,{});
					if name2==k then
						current = t[name2];
					end
				end
				tinsert(t[name2],{ns.lfrID[i],name});
			end
			instanceGroupsBuild = true;
			return current or false;
		end
		return false;
	end
});

----------------------------------------------------
--- GossipFrame entries

local function buttonHook_OnEnter(self)
	if not (NPC_ID and ns.gossip2instance[NPC_ID] and db.profile.replaceOptions) then return end
	local data
	if ImmersionFrame then
		data = self.data;
	elseif self.GetElementData then
		local option = self.GetElementData()
		if option.info and option.info.instanceID then
			data = GetInstanceDataByID(option.info.instanceID);
		elseif ns.gossip2instance[NPC_ID] and ns.gossip2instance[NPC_ID][option.info.gossipOptionID] then
			data = GetInstanceDataByID(ns.gossip2instance[NPC_ID][option.info.gossipOptionID]);
		else
			data = GetInstanceDataByID(option.index);
		end
	end
	if not data then
		return
	end
	-- prepare instance encounter list
	local bosses = {};
	if ns.instance2bosses[data.instanceID] then
		bosses = ns.instance2bosses[data.instanceID];
	else
		local numBosses = GetLFGDungeonNumEncounters(data.instanceID) or 0;
		for i=1, numBosses do
			tinsert(bosses,i);
		end
	end

	if data.instanceInfo.description=="" and #bosses==0 then
		return; -- don't display tooltip without more than the title (instance name)
	end

	-- set anchoring and ownership of the tooltip
	GameTooltip:SetOwner(self,"ANCHOR_NONE");
	if ImmersionFrame then
		GameTooltip:SetPoint("RIGHT",self,"LEFT",-4,0)
	else
		GameTooltip:SetPoint("LEFT",GossipFrame,"RIGHT");
	end

	local showID = "";
	if false then -- TODO: Add db option to show instance id
		showID = " " .. C("ltblue","("..data.instanceID..")");
	end

	-- instance name
	GameTooltip:AddLine(data.instanceInfo.name.. showID);

	-- instance group name (for raids splitted into multible lfr instances)
	local noSubtitle = (type(ns.noSubtitle[NPC_ID])=="table" and ns.noSubtitle[NPC_ID][data.instanceID]==true) or ns.noSubtitle[NPC_ID]==true;
	if (not noSubtitle) and data.instanceInfo.name~=data.instanceInfo.name2 then
		GameTooltip:AddLine(C("gray",data.instanceInfo.name2));
	end

	-- instance description
	if data.instanceInfo.description and data.instanceInfo.description~="" then
		GameTooltip:AddLine(" ");
		GameTooltip:AddLine(data.instanceInfo.description,1,1,1,1);
	end

	-- instance encounter list
	if #bosses>0 then
		GameTooltip:AddLine(" ");
		for i=1, #bosses do
			local boss, _, isKilled = GetLFGDungeonEncounterInfo(data.instanceID,bosses[i]);
			local n = (data.instanceInfo.name2 or data.instanceInfo.name).."-"..data.instanceInfo.difficulty;
			if not isKilled and killedEncounter[n] and killedEncounter[n][boss] then
				isKilled = true;
			end
			GameTooltip:AddDoubleLine(C("ltblue",boss),isKilled and C("red",BOSS_DEAD) or C("green",BOSS_ALIVE));
		end
	end

	GameTooltip:Show();
end

local function buttonHook_OnLeave()
	GameTooltip:Hide();
end

hooksecurefunc(GossipOptionButtonMixin, "Setup", function(self, optionInfo)
	if not hookedButton[self] then
		hookedButton[self] = true;
		self:HookScript("OnEnter",buttonHook_OnEnter);
		self:HookScript("OnLeave",buttonHook_OnLeave);
	end
	if optionInfo.name:match("T337496:12:12:0:0:32:32:0:16:0:16") and optionInfo.icon==1502548 then
		self.Icon:SetTexCoord(0.15,0.85,0.15,0.85); -- make raid icon a little bit bigger
	else
		self.Icon:SetTexCoord(0,1,0,1);
	end
end);

GossipFrame:HookScript("OnShow",function(self)
	UpdateNpcID();
	if not (NPC_ID and ns.npcID[NPC_ID] and GossipFrame.gossipOptions and db.profile.replaceOptions) then
		return
	end

	wipe(buttons);
	wipe(iconTexCoords);
	ScanSavedInstances();

	-- update options before layout gossip buttons; very smart. ;-) Thanks at fuba82.
	for i,option in ipairs(GossipFrame.gossipOptions) do
		local index,data;
		if ns.gossip2instance[NPC_ID] and ns.gossip2instance[NPC_ID][option.gossipOptionID] then
			index = option.gossipOptionID;
		else
			index = option.orderIndex + (ns.gossipOptionsOrderIndexOffset[NPC_ID] or 0);
		end
		if ns.gossip2instance[NPC_ID][index] then
			data = GetInstanceDataByID(ns.gossip2instance[NPC_ID][index] or 0);
		end
		if data then
			option.nameOrig = option.name;
			option.instanceID = ns.gossip2instance[NPC_ID][index];

			local noSubtitle = (type(ns.noSubtitle[NPC_ID])=="table" and ns.noSubtitle[NPC_ID][option.instanceID]==true) or ns.noSubtitle[NPC_ID]==true;

			-- replace gossip icon (interface/minimap/raid)
			option.icon = 1502548;

			-- replcae gossip text
			if data.numEncounters[2]==0 then
				option.name = data.instanceInfo.name; -- mostly for szenarios
			else
				local dark = db.profile.darkBackground and "DarkBG" or "";
				local clear = data.numEncounters[1]==data.numEncounters[2] and "Clear" or "";
				local pattern = GossipTextPattern["enemy"..clear..dark];
				if (not noSubtitle) and data.instanceInfo.name~=data.instanceInfo.name2 then
					pattern = pattern .. GossipTextPattern["raidWing"..dark];
				end
				option.name = pattern:format(
					data.instanceInfo.name, -- instance wing name
					data.numEncounters[1], -- encounters killed this week
					data.numEncounters[2], -- number of encounters of the wing
					data.instanceInfo.name2
				);
			end
		end
	end
end);

GossipFrame:HookScript("OnHide",function()
	for icon, texCoord in pairs(iconTexCoords)do
		icon:SetTexCoord(unpack(texCoord));
		iconTexCoords[icon]=nil;
	end
end);

local function OnImmersionShow()
	wipe(buttons);
	wipe(iconTexCoords);
	UpdateNpcID();
	if not (NPC_ID and ns.npcID[NPC_ID] and not IsControlKeyDown() and db.profile.replaceOptions) then
		return;
	end
	ScanSavedInstances();
	local updated,instanceID,buttonID,gossipOptionID = false;
	for i,button in ipairs(ImmersionFrame.TitleButtons.Buttons)do
		updated,instanceID,buttonID,gossipOptionID = false;
		if button:IsShown() and button.type=="Gossip" then
			buttonID = button.idx
			if button.gossipOptionID then
				gossipOptionID = button.gossipOptionID
			elseif ns.idx2gossipOptionID[NPC_ID] and #ns.idx2gossipOptionID[NPC_ID]>0 then
				gossipOptionID = ns.idx2gossipOptionID[NPC_ID][buttonID]
			end
			if gossipOptionID then
				instanceID = ns.gossip2instance[NPC_ID][gossipOptionID];
			end
			if instanceID then
				local data = GetInstanceDataByID(instanceID)
				button.data = data;
				local noSubtitle = (type(ns.noSubtitle[NPC_ID])=="table" and ns.noSubtitle[NPC_ID][instanceID]==true) or ns.noSubtitle[NPC_ID]==true;
				-- gossip text replacement
				if data.numEncounters[2]==0 then
					button:SetText(data.instanceInfo.name)
				else
					local clear = data.numEncounters[1]==data.numEncounters[2] and "Clear" or "";
					local pattern = GossipTextPattern["enemy"..clear.."DarkBG"];
					if (not noSubtitle) and data.instanceInfo.name~=data.instanceInfo.name2 then
						pattern = GossipTextPattern["raidWingImmersion"..clear];
					end
					button:SetFormattedText(
						pattern,
						data.instanceInfo.name, -- name of instance wing
						data.numEncounters[1], -- killed  encounters
						data.numEncounters[2], -- number of encounters in this wing
						data.instanceInfo.name2 -- raid name
					)
				end

				-- gossip icon replacement
				iconTexCoords[button.Icon] = {button.Icon:GetTexCoord()};
				button.Icon:SetTexture(1502548); -- interface\\minimap\\raid
				button.Icon:SetTexCoord(0.20,0.80,0.20,0.80);

				if not hookedButton["button"..buttonID] then
					local fnc = (button:GetScript("OnEnter")==nil and "Set" or "Hook") .. "Script";
					button[fnc](button,"OnEnter",buttonHook_OnEnter);
					button[fnc](button,"OnLeave",buttonHook_OnLeave);
					hookedButton["button"..buttonID] = true;
				end
				buttons[buttonID] = data;
			end
		end
	end
end

local function ImmersionFrame_GossipShow()
	C_Timer.After(0.1,OnImmersionShow);
end

local function ImmersionFrame_OnHide()
	for icon, texCoord in pairs(iconTexCoords)do
		icon:SetTexCoord(unpack(texCoord));
		iconTexCoords[icon]=nil;
	end
end

----------------------------------------------------
-- create into tooltip for raids
local function GetEncounterInfo(instanceID,encounters,encounterIndex)
	return encounters[encounterIndex] or (ns.instance2bossesAlt[instanceID] and ns.instance2bossesAlt[instanceID][encounterIndex] and encounters[ns.instance2bossesAlt[instanceID][encounterIndex]]) or false;
end

local function CreateEncounterTooltip(parent, append)
	if --[[IsInstance() or]] IsInRaid() then
		local instanceName, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceMapID, instanceGroupSize = GetInstanceInfo()
		if not (difficultyID==7 or difficultyID==17) then return end
		local data = InstanceGroups[instanceName];
		if data then
			if not append then
				GameTooltip:SetOwner(parent,"ANCHOR_NONE");
				local point,relPoint,y,rectLeft,rectBottom = "TOP","BOTTOM",-5,parent:GetRect();
				if GetScreenHeight()/2>rectBottom then
					point,relPoint,y = "BOTTOM","TOP",5
				end
				GameTooltip:SetPoint(point,parent,relPoint,0,y);
			end
			GameTooltip:SetText(instanceName);
			GameTooltip:AddLine(difficultyName,1,1,1);

			for i=1, #data do
				GameTooltip:AddLine(" ");
				GameTooltip:AddLine(C("ltblue",data[i][2]));

				local encounter = GetEncounterStatus(data[i][1]);
				local i2b = ns.instance2bosses[data[i][1]];
				--local more = IsControlKeyDown();
				local encList = i2b or encounter
				for e=1, #encList do
					local enc = GetEncounterInfo(data[i][1],encList,encList[b])
				end
				if i2b then -- lfr
					for b=1, #i2b do
						local enc = GetEncounterInfo(data[i][1],encounter,i2b[b])
						GameTooltip:AddDoubleLine("|Tinterface/questtypeicons:14:14:0:0:128:64:0:18:36:54|t "..enc[1],enc[2] and C("red",BOSS_DEAD) or C("green",BOSS_ALIVE));
					end
				else -- normal raid
					for b=1, #encounter do
						local enc = GetEncounterInfo(data[i][1],encounter,b)
					end
				end
				if enc then
					GameTooltip:AddDoubleLine("|Tinterface/questtypeicons:14:14:0:0:128:64:0:18:36:54|t "..enc[1],enc[2] and C("red",BOSS_DEAD) or C("green",BOSS_ALIVE));
				end
			end

			GameTooltip:Show();
			if append then
				return true;
			end
		end
	end
end

-- QueueStatusFrame hook to add tooltip to the QueueStatusFrame tooltip
QueueStatusFrame:HookScript("OnShow",function(parent)
	if db.profile.queueStatusFrameETT then
		CreateEncounterTooltip(parent);
	end
end);

QueueStatusFrame:HookScript("OnHide",function(parent)
	GameTooltip:Hide();
end);

----------------------------------------------------
-- addon option panel

local dbDefaults,options = {
	profile = {
		AddOnLoaded = true,
		minimap = {hide=false},
		minimapButtonETT = false,
		queueStatusFrameETT = true,
		darkBackground = false,
		replaceOptions = true,
	}
};

local function RegisterOptions()
	options = {
		type = "group",
		name = L[addon],
		childGroups = "tab",
		args = {
			AddOnLoaded = {
				type = "toggle", order = 1,
				name = L["AddOnLoaded"], desc = L["AddOnLoadedDesc"].."|n|n|cff44ff44"..L["AddOnLoadedDescAlt"].."|r"
			},
			minimap = {
				type = "toggle", order = 2,
				name = L["MinimapIcon"], desc = L["MinimapIconDesc"]
			},
			npcOptions = {
				type = "group", order = 3, inline = true,
				name = L["LFR NPCs"],
				args = {
					replaceOptions = {
						type = "toggle", order = 1,
						name = L["Replace options"], desc = L["Replace text of option entries on lfr npcs"]
					},
					darkBackground = {
						type = "toggle", order = 2,
						name = L["DarkBackground"], desc = L["DarkBackgroundDesc"],
						disabled = function()
							return not db.profile.replaceOptions
						end
					},
				},
			},
			encounterTooltips = {
				type = "group", order = 4, inline = true,
				name = L["EncounterTooltip"],
				args = {
					minimapButtonETT = {
						type = "toggle", order = 3,
						name = L["MinimapETT"], desc = L["MinimapETTDesc"],
					},
					queueStatusFrameETT = {
						type = "toggle", order = 4,
						name = L["InstanceEyeETT"], desc = L["InstanceEyeETTDesc"],
					},
				}
			},
			neutral = {
				type = "description", order = 5, fontSize = "large",
				name = L["PlayerNeutral"],
			},
			-- npcs added by function updateOptions
		}
	};

	function options.get(info,value)
		local key = info[#info];
		if value~=nil then
			if key=="minimap" then
				db.profile[key].hide = not value;
				LDBIcon:Refresh(addon);
				return;
			end
			db.profile[key] = value;
			return;
		end
		if key=="minimap" then
			return not db.profile[key].hide;
		end
		return db.profile[key];
	end

	options.set = options.get;

	db = LibStub("AceDB-3.0"):New("LFRotp_Options",dbDefaults,true);

	LibStub("AceConfig-3.0"):RegisterOptionsTable(L[addon], options);
	local opts = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(L[addon]);
	HST.BlizzOptions_ExpandOnShow(opts);
	HST.AddCredit(L[addon]); -- options.args.credits.args
end

local function createDescription(npc)
	local coords
	if npc[3] then
		coords = C("dkyellow",L["Coordinates"]..CHAT_HEADER_SUFFIX) .. npc[3].." "..npc[4]
	end
	return {
		type = "description", order = 1, fontSize = "medium", width="double",
		name = table.concat({
			C("dkyellow",NAME..CHAT_HEADER_SUFFIX) .. (npc[1]==0 and L["Currently unknown"] or L["NPC"..npc[1]]),
			C("dkyellow",ZONE..CHAT_HEADER_SUFFIX) .. (npc[3]==false and L["Somewhere in"].." "..npc.zoneName.."?" or npc.zoneName),
			coords,
		},"|n")
	}
end

local function addTomTom(opt,npc)
	local key = "tomtom";
	opt.args[key] = {
		type = "execute", order = 2,
		name = L["TomTomAdd"],
		func = function()
			if not (npc and TomTom.AddWaypoint) then return end
			TomTom:AddWaypoint(npc[2],npc[3]/100,npc[4]/100,{
				title = L["NPC"..npc[1]],
				from = addon,
				persistent = nil,
				minimap = true,
				world = true
			});
			-- Thanks @ fuba82@github for reminding me. i've forgot to add this function content. :-)
		end
	}
	if not (TomTom and TomTom.AddWaypoint) then
		opt.args[key].name = L["TomTomMissing"];
		opt.args[key].disabled = true;
	end
end

local function updateOptions()
	local faction = ns.faction();

	options.args.neutral.hidden=true;

	for i=1, #ns.npcs do
		local npc = ns.npcs[i];
		if rawget(L,"NPC"..npc[1]) then
			if npc.addTo then
				local opt = {
					type="group", order=npc.order+1, inline=true,
					name="", --L["NPC"..npc[1]],
					args = {
						desc = createDescription(npc)
					}
				}
				if npc[3] and npc[4] then
					addTomTom(opt,npc);
				end
				options.args["entry"..npc.addTo].args.location.args["npc"..npc.order] = opt;
			else
				local opt = {
					type = "group",order = 10+i;
					name = _G["EXPANSION_NAME"..npc[5]],
					childGroups="tab",
					args = {
						location = {
							type="group", order=1,
							name=LOCATION_COLON:gsub(HEADER_COLON,""),
							args= {
								npc1 = {
									type="group", order=2, inline=true,
									name="", --L["NPC"..npc[1]],
									args = {
										desc = createDescription(npc)
									}
								}
							}
						},
						info = {
							type ="group", order = 2, hidden=true,
							name = INFO,
							args = {
							}
						}
					}
				}
				if npc[3] and npc[4] then
					addTomTom(opt.args.location.args.npc1,npc);
				end
				if npc.imgs then
					opt.args["pics_spacer"] = {
						type="description", order = 10, name= " "
					}
					for I=1, #npc.imgs do
						opt.args.location.args["pic"..I] = {
							type = "description", order = 10+I, width = "normal", name = "",
							image = imgPath..npc.imgs[I]:format(faction), imageWidth = imgSize, imageHeight = imgSize
						}
					end
				end
				local order = 1;
				for _,gossipOptionID in ipairs(ns.idx2gossipOptionID[npc[1]])do
					-- gossip option order
					local instanceID = ns.gossip2instance[npc[1]][gossipOptionID];
					local instanceData = instanceID and GetInstanceDataByID(instanceID) or false;
					if instanceData then
						local entry = {
							type = "group", order = order, inline=true,
							name = instanceData.instanceInfo.name
								.. (instanceData.groupName and C("ltgray"," ("..instanceData.groupName..")") or "")
								--.. C("ltgray"," ("..instanceID..")")
								,
							args = {
							}
						}
						--[[
						if instanceData.groupName then
							entry.args.instanceGroup = {
								type = "description", order= 1, fontSize="medium",
								name = C("ltgray",instanceData.groupName)
							}
						end
						--]]
						entry.args.desc = {
							type = "description", order=2, fontSize="medium",
							name = instanceData.instanceInfo.description
						}
						if ns.instance2bosses[instanceID] then
							local encounters = GetEncounterStatus(instanceID);
							local encounterEntries = {}
							for index,encounterIndex in ipairs(ns.instance2bosses[instanceID])do
								local enc = GetEncounterInfo(instanceID,encounters,encounterIndex)
								if enc and enc[1] then
									tinsert(encounterEntries,C(enc[2] and "red" or "green","   |Tinterface\\lfgframe\\lfg:14:14:0:0:64:32:0:32:0:32|t"..enc[1]));
								end
							end
							entry.args.encounters = {
								type = "description", order=2, fontSize="medium",
								name = table.concat(encounterEntries,"|n")
							}
						end

						opt.args.info.args["instance-"..instanceID] = entry;
						opt.args.info.hidden=false;
						order=order+1;
					end
				end
				options.args["entry"..i] = opt;
			end
		end
	end
end

----------------------------------------------------
-- LibDataBroker

--local function LDBObject_OnEnter(self)end
--local function LDBObject_OnLeave(self)end

local function LDBObject_OnClick(self,button)
	--if button=="LeftButton" then
	--else
		if ACD.OpenFrames[L[addon]]~=nil then
			ACD:Close(L[addon]);
		else
			ACD:Open(L[addon]);
			ACD.OpenFrames[L[addon]]:SetStatusText(GAME_VERSION_LABEL..CHAT_HEADER_SUFFIX.."@project-version@");
		end
	--end
end

local function RegisterDataBroker()
	if not LDB then return end

	local LDBObject = LDB:NewDataObject(addon,{
		type		= "data source",
		icon		= "interface\\lfgframe\\ui-lfg-icon-heroic",
		iconCoords	= {0,0.55,0,0.55},
		label		= L[addon],
		text		= L[addon],
		OnTooltipShow = function(tt)
			if db.profile.minimapButtonETT and CreateEncounterTooltip(tt,true) then
				return;
			end

			tt:AddLine(L[addon]);
			for _,npc in ipairs(ns.npcs) do
				if rawget(L,"NPC"..npc[1]) then
					tt:AddLine(" ");
					if npc[3] then
						tt:AddLine(L["NPC"..npc[1]]..C("mage"," (".. _G["EXPANSION_NAME"..npc[5]]..")"),.3,1,.3);
						tt:AddLine(npc.zoneName..", "..npc[3]..", "..npc[4],.7,.7,.7);
					else
						tt:AddLine(L["Currently unknown"]..C("mage"," (".. _G["EXPANSION_NAME"..npc[5]]..")"),.3,1,.3);
						tt:AddLine(L["Somewhere in"].." "..npc.zoneName.."?",.7,.7,.7)
					end
				end
			end
			tt:AddLine(" ");
			tt:AddLine(C("copper",L["Click"]).." || "..C("green",L["Open LFR [of the past] info panel"]));
		end,
		--OnEnter = LDBObject_OnEnter,
		--OnLeave = LDBObject_OnLeave,
		OnClick = LDBObject_OnClick
	});

	if LDBIcon then
		LDBIcon:Register(addon, LDBObject, db.profile.minimap);
	end
end

----------------------------------------------------
-- event frame

local immersionHook,frame = false,CreateFrame("frame");

frame:SetScript("OnEvent",function(self,event,...)
	if event=="ADDON_LOADED" then
		if addon==... then
			if LFRotp_Options==nil then
				LFRotp_Options = {};
			end

			RegisterOptions();

			RegisterDataBroker();

			if db.profile.AddOnLoaded or IsShiftKeyDown() then
				ns:print(L["AddOnLoaded"]);
			end
		elseif (...=="Immersion" or ImmersionFrame) and not immersionHook then
			immersionHook = true;
			hooksecurefunc(ImmersionFrame,"GOSSIP_SHOW",ImmersionFrame_GossipShow);
			ImmersionFrame:HookScript("OnHide",ImmersionFrame_OnHide);
		end
	elseif not ns.faction(true) and (event=="PLAYER_LOGIN" or event=="NEUTRAL_FACTION_SELECT_RESULT") then
		RequestRaidInfo();
		ns.load_data();
		updateOptions();
	elseif event=="BOSS_KILL" then
		BossKillQueryUpdate=true;
		C_Timer.After(0.16,RequestRaidInfoUpdate);
	elseif event=="UPDATE_INSTANCE_INFO" then
		BossKillQueryUpdate=false;
		if not UpdateInstanceInfoLock then
			UpdateInstanceInfoLock = true;
			C_Timer.After(0.3,ScanSavedInstances);
		end
	end
end);

frame:RegisterEvent("ADDON_LOADED");
frame:RegisterEvent("PLAYER_LOGIN");
frame:RegisterEvent("NEUTRAL_FACTION_SELECT_RESULT");
frame:RegisterEvent("BOSS_KILL");
frame:RegisterEvent("UPDATE_INSTANCE_INFO");
frame:RegisterEvent("RAID_INSTANCE_WELCOME");
