
local addon, ns = ...;
local L = ns.L;
ns.debugMode = "@project-version@"=="@".."project-version".."@";
LibStub("HizurosSharedTools").RegisterPrint(ns,addon,"LFRotp");

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
		data.numEncounters[2] = GetLFGDungeonNumEncounters(instanceID);
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
	if not (NPC_ID and self.GetElementData) then return end
	local buttonID = self.GetElementData().index;
	if buttonID and buttons[buttonID] then
		GameTooltip:SetOwner(self,"ANCHOR_NONE");
		if ImmersionFrame then
			GameTooltip:SetPoint("RIGHT",self,"LEFT",-4,0)
		else
			GameTooltip:SetPoint("LEFT",GossipFrame,"RIGHT");
		end

		local showID = "";
		if false then -- TODO: Add db option to show instance id
			showID = " " .. C("ltblue","("..buttons[buttonID].instanceID..")");
		end

		-- instance name
		GameTooltip:AddLine(buttons[buttonID].instanceInfo.name.. showID);

		-- instance group name (for raids splitted into multible lfr instances)
		if not ns.noSubtitle[NPC_ID] and buttons[buttonID].instanceInfo.name~=buttons[buttonID].instanceInfo.name2 then
			GameTooltip:AddLine(C("gray",buttons[buttonID].instanceInfo.name2));
		end

		-- instance description
		if buttons[buttonID].instanceInfo.description and buttons[buttonID].instanceInfo.description~="" then
			GameTooltip:AddLine(" ");
			GameTooltip:AddLine(buttons[buttonID].instanceInfo.description,1,1,1,1);
		end

		-- instance encounter list
		local bosses = {};
		if ns.instance2bosses[buttons[buttonID].instanceID] then
			bosses = ns.instance2bosses[buttons[buttonID].instanceID];
		else
			local numBosses = GetLFGDungeonNumEncounters(buttons[buttonID].instanceID) or 0;
			for i=1, numBosses do
				tinsert(bosses,i);
			end
		end

		if #bosses>0 then
			GameTooltip:AddLine(" ");
			for i=1, #bosses do
				local boss, _, isKilled = GetLFGDungeonEncounterInfo(buttons[buttonID].instanceID,bosses[i]);
				local n = (buttons[buttonID].instanceInfo.name2 or buttons[buttonID].instanceInfo.name).."-"..buttons[buttonID].instanceInfo.difficulty;
				if not isKilled and killedEncounter[n] and killedEncounter[n][boss] then
					isKilled = true;
				end
				GameTooltip:AddDoubleLine(C("ltblue",boss),isKilled and C("red",BOSS_DEAD) or C("green",BOSS_ALIVE));
			end
		end

		GameTooltip:Show();
	end
end

local function buttonHook_OnLeave()
	GameTooltip:Hide();
end

GossipFrame:HookScript("OnShow",function()
	wipe(buttons);
	wipe(iconTexCoords);
	UpdateNpcID();
	if not (NPC_ID and ns.npcID[NPC_ID]) then
		return
	end
	ScanSavedInstances();
end);

GossipFrame:HookScript("OnHide",function()
	for icon, texCoord in pairs(iconTexCoords)do
		icon:SetTexCoord(unpack(texCoord));
		iconTexCoords[icon]=nil;
	end
end);

hooksecurefunc(GossipOptionButtonMixin,"Setup",function(self)
	if not self.GetElementData then return end
	local element = self:GetElementData();
	local buttonID, instanceID = element.index;
	if ns.gossip2instance[NPC_ID] and #ns.gossip2instance[NPC_ID]>0 then
		instanceID = ns.gossip2instance[NPC_ID][buttonID];
	end
	if instanceID then
		local data = GetInstanceDataByID(instanceID);
		local showID = "";
		if false then
			showID = " " .. C("blue","("..instanceID..")");
		end
		-- gossip text replacement
		self:SetText(
			data.instanceInfo.name..showID.."\n"..
			"|Tinterface\\lfgframe\\ui-lfg-icon-heroic:12:12:0:0:32:32:0:16:0:16|t "..C("dkred",_G["GENERIC_FRACTION_STRING"]:format(data.numEncounters[1],data.numEncounters[2])).. " || ".. C("dkgray",data.instanceInfo.name2)
		);
		-- gossip icon replacement
		iconTexCoords[self.Icon] = {self.Icon:GetTexCoord()};
		self.Icon:SetTexture("interface\\minimap\\raid");
		self.Icon:SetTexCoord(0.20,0.80,0.20,0.80);
		self:Resize();
		buttons[buttonID] = data;
		if not hookedButton["button"..buttonID] then
			self:HookScript("OnEnter",buttonHook_OnEnter);
			self:HookScript("OnLeave",buttonHook_OnLeave);
			hookedButton["button"..buttonID] = true;
		end
	end
end)

local function OnImmersionShow()
	wipe(buttons);
	wipe(iconTexCoords);
	UpdateNpcID();
	if not (NPC_ID and ns.npcID[NPC_ID] and not IsControlKeyDown()) then
		return;
	end
	ScanSavedInstances();
	local updated,instanceID,buttonID = false;
	for i,button in ipairs(ImmersionFrame.TitleButtons.Buttons)do
		updated,instanceID,buttonID = false;
		if button:IsShown() and button.type=="Gossip" then
			buttonID = button.idx;
			if ns.gossip2instance[NPC_ID] and #ns.gossip2instance[NPC_ID]>0 then
				instanceID = ns.gossip2instance[NPC_ID][buttonID];
			end
			if instanceID then
				local data = GetInstanceDataByID(instanceID)
				-- gossip text replacement
				local showID = "";
				if false then -- TODO: Add db option to show instance id
					showID = " " .. C("ltblue","("..buttons[buttonID].instanceID..")");
				end
				button:SetText(
					data.instanceInfo.name ..showID.."\n"..
					C("ltgray",data.instanceInfo.name2) .."\n"..
					"|Tinterface\\lfgframe\\ui-lfg-icon-heroic:12:12:0:0:32:32:0:16:0:16|t "..C("ltred",_G["GENERIC_FRACTION_STRING"]:format(data.numEncounters[1],data.numEncounters[2]))
				);
				-- gossip icon replacement
				iconTexCoords[button.Icon] = {button.Icon:GetTexCoord()};
				button.Icon:SetTexture("interface\\minimap\\raid");
				button.Icon:SetTexCoord(0.20,0.80,0.20,0.80);
				if not hookedButton["button"..buttonID] then
					button:HookScript("OnEnter",buttonHook_OnEnter);
					button:HookScript("OnLeave",buttonHook_OnLeave);
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

local function CreateEncounterTooltip(parent)
	if --[[IsInstance() or]] IsInRaid() then
		local instanceName, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceMapID, instanceGroupSize = GetInstanceInfo()
		if not (difficultyID==7 or difficultyID==17) then return end
		local data = InstanceGroups[instanceName];
		if data then
			GameTooltip:SetOwner(parent,"ANCHOR_NONE");
			local point,relPoint,y,rectLeft,rectBottom = "TOP","BOTTOM",-5,parent:GetRect();
			if GetScreenHeight()/2>rectBottom then
				point,relPoint,y = "BOTTOM","TOP",5
			end
			GameTooltip:SetPoint(point,parent,relPoint,0,y);
			GameTooltip:SetText(instanceName);
			GameTooltip:AddLine(difficultyName,1,1,1);

			for i=1, #data do
				GameTooltip:AddLine(" ");
				GameTooltip:AddLine(C("ltblue",data[i][2]));

				local encounter = GetEncounterStatus(data[i][1]);
				local i2b = ns.instance2bosses[data[i][1]];
				local more = IsControlKeyDown();
				if i2b then -- lfr
					for b=1, #i2b do
						GameTooltip:AddDoubleLine("|Tinterface/questtypeicons:14:14:0:0:128:64:0:18:36:54|t "..encounter[i2b[b]][1],encounter[i2b[b]][2] and C("red",BOSS_DEAD) or C("green",BOSS_ALIVE));
					end
				else -- normal raid
					for b=1, #encounter do
						GameTooltip:AddDoubleLine("|Tinterface/questtypeicons:14:14:0:0:128:64:0:18:36:54|t "..encounter[b][1],encounter[b][2] and C("red",BOSS_DEAD) or C("green",BOSS_ALIVE));
					end
				end
			end

			GameTooltip:Show();
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
			encounterTooltips = {
				type = "group", order = 3, inline = true,
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
	LibStub("HizurosSharedTools").BlizzOptions_ExpandOnShow(opts);
	LibStub("HizurosSharedTools").AddCredit(L[addon]); -- options.args.credits.args
end

local function updateOptions()
	local faction = ns.faction();

	options.args.neutral.hidden=true;

	for i=1, #ns.npcs do
		local npc = ns.npcs[i];
		local opt = {
			type = "group",order = 10+i;
			name = _G["EXPANSION_NAME"..npc[5]],
			args = {
				desc = {
					type = "description", order = 1, fontSize = "medium",
					name =
						C("dkyellow",NAME..CHAT_HEADER_SUFFIX) .. (npc[1]==0 and L["Currently unknown"] or L["NPC"..npc[1]])
						.. "|n" ..
						C("dkyellow",ZONE..CHAT_HEADER_SUFFIX) .. (npc[3]==false and L["Somewhere in"].." "..npc.zoneName.."?" or npc.zoneName)

						.. "|n" ..
						(npc[3] and C("dkyellow",L["Coordinates"]..CHAT_HEADER_SUFFIX) .. npc[3].." "..npc[4] or ""),
				}
			}
		}
		if TomTom then
			opt.args.tomtom = {
				type = "execute", order = 2,
				name = L["TomTomAdd"],
				func = function()
					--
				end
			}
		else
			opt.args.tomtom = {
				type = "description", order = 2,
				name = C("orange",L["TomTomMissing"])
			}
		end
		if npc.imgs then
			opt.args["pics_spacer"] = {
				type="description", order = 10, name= " "
			}
			for I=1, #npc.imgs do
				opt.args["pic"..I] = {
					type = "description", order = 10+I, width = "normal", name = "",
					image = imgPath..npc.imgs[I]:format(faction), imageWidth = imgSize, imageHeight = imgSize
				}
			end
		end
		options.args["entry"..i] = opt;
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
			tt:AddLine(L[addon]);
			for _,npc in ipairs(ns.npcs) do
				tt:AddLine(" ");
				if npc[3] then
					tt:AddLine(L["NPC"..npc[1]]..C("mage"," (".. _G["EXPANSION_NAME"..npc[5]]..")"),.3,1,.3);
					tt:AddLine(npc.zoneName..", "..npc[3]..", "..npc[4],.7,.7,.7);
				else
					tt:AddLine(L["Currently unknown"]..C("mage"," (".. _G["EXPANSION_NAME"..npc[5]]..")"),.3,1,.3);
					tt:AddLine(L["Somewhere in"].." "..npc.zoneName.."?",.7,.7,.7)
				end
			end
			tt:AddLine(" ");
			tt:AddLine(C("copper",L["Click"]).." || "..C("green",L["Open LFR [of the past] info panel"]));

			if db.profile.minimapButtonETT then
				CreateEncounterTooltip(tt);
			end
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
