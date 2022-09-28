
-- bosskill tracking das am mittwoch zurückgesetzt wird.
-- broker und optionpanel seite mit namen und orten wo die npcs zu finden sind.

local addon, ns = ...;
local L = ns.L;
ns.debugMode = "@project-version@"=="@".."project-version".."@";
LibStub("HizurosSharedTools").RegisterPrint(ns,addon,"LFRotp");

local ACD = LibStub("AceConfigDialog-3.0");
local LDB = LibStub("LibDataBroker-1.1");
local LDBIcon = LibStub("LibDBIcon-1.0", true);

local realm,character,faction = GetRealmName();
local buttons,hookedButton,died,NPC_ID,db = {},{},{},false,(UnitGUID("target"));
local name, typeID, subtypeID, minLevel, maxLevel, recLevel, minRecLevel, maxRecLevel, expansionLevel, groupID, texture = 1,2,3,4,5,6,7,8,9,10,11; -- GetLFGDungeonInfo
local difficulty, maxPlayers, description, isHoliday, bonusRepAmount, minPlayers, isTimeWalker, name2, minGearLevel = 12,13,14,15,16,17,18,19,20; -- GetLFGDungeonInfo
local iconTexCoords,killedEncounter,BossKillQueryUpdate,UpdateInstanceInfoLock,currentInstance = {},{},false,false,{};
local imgSize,imgPath,isImmersionFrameHookOnHide = 168,"Interface\\AddOns\\LFR_of_the_past\\media\\";
local pat = {
	RAID_INSTANCE_WELCOME = _G.RAID_INSTANCE_WELCOME_LOCKED:gsub("%%s","(.*)"),
	RAID_INSTANCE_WELCOME_LOCKED = _G.RAID_INSTANCE_WELCOME_LOCKED:gsub("%%s","(.*)")
};

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

local bossIs = {
	--dead="|Tinterface/minimap/ObjectIconsAtlas: |t "..C("gray","%s"),
	--alive="|Tinterface\\lfgframe\\ui-lfg-icon-heroic:12:12:0:0:32:32:0:16:0:16|t "..C("ltyellow","%s")
	dead="|Tinterface/questtypeicons:18:18:0:0:128:64:108:126:18:36|t"..C("gray","%s"),
	alive="|Tinterface/questtypeicons:18:18:0:0:128:64:0:18:36:54|t"..C("ltyellow","%s")
}


------------------------------------------------
-- GameTooltip to get localized names and other informations

ns.scanTT = CreateFrame("GameTooltip",addon.."_ScanTT",UIParent,"GameTooltipTemplate");
ns.scanTT:SetScale(0.0001); ns.scanTT:SetAlpha(0); ns.scanTT:Hide();
-- unset script functions shipped by GameTooltipTemplate to prevent errors
for _,v in ipairs({"OnLoad","OnHide","OnTooltipAddMoney","OnTooltipSetDefaultAnchor","OnTooltipCleared"})do ns.scanTT:SetScript(v,nil); end

function ns.scanTT:GetStringRegions(dataFunction,...)
	if type(self[dataFunction])~="function" then return false; end

	ns.scanTT:SetOwner(UIParent,"ANCHOR_NONE");
	self[dataFunction](self,...);
	ns.scanTT:Show();

	local regions,strs = {ns.scanTT:GetRegions()},{};
	for i=1,#regions do
		if (regions[i]~=nil) and (regions[i]:GetObjectType()=="FontString") then
			local str = (regions[i]:GetText() or ""):trim();
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
	faction = (UnitFactionGroup("player") or "neutral"):lower();
	if isNeutral then
		return faction=="neutral";
	end
	return faction;
end

local function IsInstance()
	local _, _, difficulty = GetInstanceInfo();
	return difficulty==7 or difficulty==17;
end

local function RequestRaidInfoUpdate()
	if BossKillQueryUpdate then
		RequestRaidInfo();
	end
end

local function ScanSavedInstances()
	for index=1, (GetNumSavedInstances()) do
		local tmp, instanceName, _, instanceReset, instanceDifficulty, _, _, _, isRaid, _, difficultyName, numEncounters, encounterProgress = {}, GetSavedInstanceInfo(index);
		if (instanceDifficulty==7 or instanceDifficulty==17) and encounterProgress>0 and instanceReset>0 then
			local encounters,strs = {},ns.scanTT:GetStringRegions("SetInstanceLockEncountersComplete",index);
			for i=2, #strs, 2 do
				encounters[strs[i]] = strs[i+1]==BOSS_DEAD;
			end
			killedEncounter[instanceName.."-"..instanceDifficulty] = encounters;
		end
	end
	UpdateInstanceInfoLock = false;
end

local function GetEncounterStatus(instanceID)
	local encounter,num = {},GetLFGDungeonNumEncounters(instanceID);
	local instanceInfo = {GetLFGDungeonInfo(instanceID)};
	local instanceTag = instanceInfo[name2].."-"..instanceInfo[difficulty];
	for i=1, num do
		local boss, _, isKilled = GetLFGDungeonEncounterInfo(instanceID,i);
		if not isKilled and killedEncounter[instanceTag] and killedEncounter[instanceTag][boss] then
			isKilled = true;
		end
		tinsert(encounter,{boss,isKilled});
	end
	return encounter;
end

local instanceGroupsBuild = false;
local InstanceGroups = setmetatable({},{
	__index = function(t,k)
		if not instanceGroupsBuild then -- build group list
			local current;
			for i=1, #ns.lfrID do
				local name, typeID, subtypeID, minLevel, maxLevel, recLevel, minRecLevel, maxRecLevel, expansionLevel, groupID, textureFilename, difficulty, maxPlayers, description, isHoliday, bonusRepAmount, minPlayers, isTimeWalker, name2, minGearLevel = GetLFGDungeonInfo(ns.lfrID[i])
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
	if not (NPC_ID and self.type=="Gossip") then return end
	local buttonID = self:GetID();
	if buttonID and buttons[buttonID] then
		GameTooltip:SetOwner(self,"ANCHOR_NONE");
		if ImmersionFrame then
			GameTooltip:SetPoint("RIGHT",self,"LEFT",-4,0)
		else
			GameTooltip:SetPoint("LEFT",GossipFrame,"RIGHT");
		end

		local showID = "";
		if false then
			showID = " " .. C("ltblue","("..buttons[buttonID].instanceID..")");
		end

		-- instance name
		GameTooltip:AddLine(buttons[buttonID].instance[name].. showID);

		-- instance group name (for raids splitted into multible lfr instances)
		if not ns.noSubtitle[NPC_ID] and buttons[buttonID].instance[name]~=buttons[buttonID].instance[name2] then
			GameTooltip:AddLine(C("gray",buttons[buttonID].instance[name2]));
		end

		-- instance description
		if buttons[buttonID].instance[description] and buttons[buttonID].instance[description]~="" then
			GameTooltip:AddLine(" ");
			GameTooltip:AddLine(buttons[buttonID].instance[description],1,1,1,1);
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
				local n = (buttons[buttonID].instance[name2] or buttons[buttonID].instance[name]).."-"..buttons[buttonID].instance[difficulty];
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
	if not NPC_ID then return end
	GameTooltip:Hide();
end

local function OnGossipShow()
	wipe(buttons); wipe(iconTexCoords);
	local id,_ = UnitGUID("npc");
	if id then
		_,_,_,_,_,id = strsplit('-',id);
		id = tonumber(id);
	end
	if id and ns.npcID[id] and not IsControlKeyDown() then
		ScanSavedInstances();
		NPC_ID = id;
		local Buttons,isImmersion = {},false;
		if ImmersionFrame then
			Buttons = ImmersionFrame.TitleButtons.Buttons;
			isImmersion = true;
		elseif GossipFrame.buttons then
			Buttons = GossipFrame.buttons;
		end
		for i,button in ipairs(Buttons)do
			if button:IsShown() and button.type=="Gossip" then
				local buttonID = button:GetID()
				local instanceID
				if ns.gossip2instance[NPC_ID] and #ns.gossip2instance[NPC_ID]>0 then
					instanceID = ns.gossip2instance[NPC_ID][buttonID];
				end
				if id and instanceID then
					local data = {
						groupName = false,
						instanceID = instanceID,
						instance = {GetLFGDungeonInfo(instanceID)},
						numEncounters = {0,0},
						encounters = {}
					};
					if data.instance[name]~=data.instance[name2] then
						data.groupName = data.instance[name2];
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
						local n = (data.instance[name2] or data.instance[name]).."-"..data.instance[difficulty];
						if not isKilled and killedEncounter[n] and killedEncounter[n][boss] then
							isKilled = true;
						end
						if isKilled then
							data.numEncounters[1] = data.numEncounters[1] + 1;
							tinsert(data.encounters,boss);
						end
					end
					local showID = "";
					if false then
						showID = " " .. C("blue","("..instanceID..")");
					end
					if isImmersion then
						-- gossip text replacement
						button:SetText(
							data.instance[name] ..showID.."\n"..
							C("ltgray",data.instance[name2]) .."\n"..
							"|Tinterface\\lfgframe\\ui-lfg-icon-heroic:12:12:0:0:32:32:0:16:0:16|t "..C("ltred",_G.GENERIC_FRACTION_STRING:format(data.numEncounters[1],data.numEncounters[2]))
						);
						-- gossip icon replacement
						iconTexCoords[button.Icon] = {button.Icon:GetTexCoord()};
						button.Icon:SetTexture("interface\\minimap\\raid");
						button.Icon:SetTexCoord(0.20,0.80,0.20,0.80);
					else -- GossipFrame
						-- gossip text replacement
						button:SetText(
							data.instance[name]..showID.."\n"..
							"|Tinterface\\lfgframe\\ui-lfg-icon-heroic:12:12:0:0:32:32:0:16:0:16|t "..C("dkred",_G.GENERIC_FRACTION_STRING:format(data.numEncounters[1],data.numEncounters[2])).. " || ".. C("dkgray",data.instance[name2])
						);
						-- gossip icon replacement
						iconTexCoords[button.Icon] = {button.Icon:GetTexCoord()};
						button.Icon:SetTexture("interface\\minimap\\raid");
						button.Icon:SetTexCoord(0.20,0.80,0.20,0.80);
						button:Resize();
					end
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
end

hooksecurefunc("GossipFrameUpdate",OnGossipShow)

local function OnGossipHide()
	for icon, texCoord in pairs(iconTexCoords)do
		icon:SetTexCoord(unpack(texCoord));
		iconTexCoords[icon]=nil;
	end
end

GossipFrame:HookScript("OnHide",OnGossipHide);

local function ImmersionFrame_GossipShow()
	C_Timer.After(0.1,OnGossipShow);
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
			GameTooltip:SetPoint("TOP",parent,"BOTTOM");
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

	--options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(db);
	--options.args.profiles.order=-1;

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
						C("dkyellow",NAME..CHAT_HEADER_SUFFIX) .. L["NPC"..npc[1]]
						.. "|n" ..
						C("dkyellow",ZONE..CHAT_HEADER_SUFFIX) .. npc.zoneName
						.. "|n" ..
						C("dkyellow",L["Coordinates"]..CHAT_HEADER_SUFFIX) .. npc[3].." "..npc[4],
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
				tt:AddLine(L["NPC"..npc[1]]..C("mage"," (".. _G["EXPANSION_NAME"..npc[5]]..")"),.3,1,.3);
				tt:AddLine(npc.zoneName..", "..npc[3]..", "..npc[4],.7,.7,.7);
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
			--self:UnregisterEvent("ADDON_LOADED");

			character = (UnitName("player")).."-"..realm;

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
			ImmersionFrame:HookScript("OnHide",OnGossipHide);
		end
	elseif not ns.faction(true) and (event=="PLAYER_LOGIN" or event=="NEUTRAL_FACTION_SELECT_RESULT") then
		RequestRaidInfo();
		ns.load_data();
		updateOptions();
	elseif event=="BOSS_KILL" then
		local encounterID,name = ...;
		BossKillQueryUpdate=true;
		C_Timer.After(0.16,RequestRaidInfoUpdate);
	elseif event=="UPDATE_INSTANCE_INFO" then
		BossKillQueryUpdate=false;
		if not UpdateInstanceInfoLock then
			UpdateInstanceInfoLock = true;
			C_Timer.After(0.3,ScanSavedInstances);
		end
	elseif event=="RAID_INSTANCE_WELCOME" then
		local dungeonName,lockExpireTime,locked,extended = ...;
		currentInstance.name = dungeonName;
		currentInstance.parts = false;
		currentInstance.isLFR = false;
		if dungeonName:find(PLAYER_DIFFICULTY3) then
			for k,v in pairs(InstanceGroups)do
				if dungeonName:find("^"..k) then
					currentInstance.parts = v;
					break;
				end
			end
			currentInstance.isLFR = true;
		end
--@do-not-package@
		--[[
		local pattern;
		local instance,timeout = msg:match(pat.RAID_INSTANCE_WELCOME);
		if not instance then
			instance,timeout = msg:match(pat.RAID_INSTANCE_WELCOME_LOCKED);
			pattern = "RAID_INSTANCE_WELCOME_LOCKED";
		else
			pattern = "RAID_INSTANCE_WELCOME";
		end
		if instance then
			ns:debug(pattern,instance,timeout);
		end
		--]]
		--  Willkommen in der Instanz "Terrasse des Endlosen Frühlings (Schlachtzugsbrowser)". Instanzzuordnungen laufen in 1 |4Tag:Tage; 20 |4Stunde:Stunden; aus.
		-- RAID_INSTANCE_WELCOME Willkommen in der Instanz "%s". Instanzzuordnungen laufen in %s aus. [Blizzard]
		-- RAID_INSTANCE_WELCOME_LOCKED Willkommen in der Instanz "%s". Eure Instanzzuordnung läuft in %s aus. [Blizzard]
		-- PLAYER_DIFFICULTY3
--@end-do-not-package@
	end
end);

frame:RegisterEvent("ADDON_LOADED");
frame:RegisterEvent("PLAYER_LOGIN");
frame:RegisterEvent("NEUTRAL_FACTION_SELECT_RESULT");
frame:RegisterEvent("BOSS_KILL");
frame:RegisterEvent("UPDATE_INSTANCE_INFO");
frame:RegisterEvent("RAID_INSTANCE_WELCOME");

-- function XXXXXX(id) local num = GetLFGDungeonNumEncounters(id); for i=1, num do local boss, _, isKilled = GetLFGDungeonEncounterInfo(id,i); print(id,i,boss); end end
