
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
local ImmersionFrame = _G["ImmersionFrame"];
local TomTom = _G["TomTom"];
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

function ns.faction(isNeutral)
	local faction = (UnitFactionGroup("player") or "neutral"):lower();
	if isNeutral then
		return faction=="neutral";
	end
	return faction;
end

local function ScanSavedInstances()
	for index=1, (GetNumSavedInstances()) do
		local instanceName, _, instanceReset, instanceDifficulty, _, _, _, _, _, _, _, encounterProgress = GetSavedInstanceInfo(index);
		if (instanceDifficulty==7 or instanceDifficulty==17) and encounterProgress>0 and instanceReset>0 then
			local encounters,ttInfo = {}, C_TooltipInfo.GetInstanceLockEncountersComplete(index)
			if ttInfo and ttInfo.lines then
				for i=2, #ttInfo.lines, 2 do
					encounters[ttInfo.lines[i]] = ttInfo.lines[i+1]==BOSS_DEAD;
				end
				killedEncounter[instanceName.."-"..instanceDifficulty] = encounters;
			end
		end
	end
	UpdateInstanceInfoLock = false;
end

local function GetInstanceDataByID(instanceID)
	local data = {
		groupName = false,
		instanceID = instanceID,
		instanceInfo = {},
		encounters = {},
		numEncountersKilled=0,
	};
	local info = {};
	info.name, info.typeID, info.subtypeID, info.minLevel, info.maxLevel, info.recLevel, info.minRecLevel, info.maxRecLevel, info.expansionLevel,
	info.groupID, info.textureFilename, info.difficulty, info.maxPlayers, info.description, info.isHoliday, info.bonusRepAmount, info.minPlayers,
	info.isTimeWalker, info.name2, info.minGearLevel, info.isScalingDungeon, info.lfgMapID = GetLFGDungeonInfo(instanceID);
	data.instanceInfo = info;
	if info.name~=info.name2 or ns.instanceName2group[instanceID] then
		data.groupName = info.name2;
	end

	local encounters,list,killed = {},{},0
	if ns.instance2bosses[instanceID] then
		list = ns.instance2bosses[instanceID];
	else
		local num = GetLFGDungeonNumEncounters(instanceID) or 0;
		for i=1, num do
			tinsert(list,i);
		end
	end

	for _, index in ipairs(list)do
		local boss, _, isKilled = GetLFGDungeonEncounterInfo(instanceID,index);
		local n = (info.name2 or info.name).."-"..info.difficulty;
		if not isKilled and killedEncounter[n] and killedEncounter[n][boss] then -- from saved instances
			isKilled = true;
		end
		tinsert(encounters,{index=index,name=boss,isKilled=isKilled})
		if isKilled then
			killed=killed+1;
		end
	end

	data.encounters, data.numEncountersKilled = encounters, killed;

	return data;
end

local function RequestRaidInfoUpdate()
	if BossKillQueryUpdate then
		RequestRaidInfo();
	end
end

local function UpdateNpcID(dataTable)
	-- get npcID from creature guid string
	-- https://warcraft.wiki.gg/wiki/API_UnitGUID
	local npcGUID = UnitGUID("npc");
	if issecretvalue(npcGUID) and not canaccessvalue(npcGUID) then
		-- secret value is the biggest bullshit on earth. breaking 99.9% of the time non combat/non raid addons.
		NPC_ID = nil;
		return;
	end
	local _,_,_,_,_,npdId = strsplit('-',npcGUID);
	NPC_ID = tonumber(npdId);
	return (NPC_ID and ns.npcID[NPC_ID] and dataTable and not IsControlKeyDown() and db.profile.replaceOptions);
end

----------------------------------------------------
--- GossipFrame entries

local function buttonHook_OnEnter(self)
	if not (NPC_ID and ns.npcID[NPC_ID] and db.profile.replaceOptions) then return end
	local instanceID
	if ImmersionFrame then
		instanceID = self.data.instanceID;
	elseif self.GetElementData then
		local option = self.GetElementData()
		if option.info and option.info.instanceID then
			instanceID = option.info.instanceID;
		elseif ns.npc2instance[NPC_ID] and ns.npc2instance[NPC_ID][option.info.gossipOptionID] then
			instanceID = ns.npc2instance[NPC_ID][option.info.gossipOptionID];
		else
			instanceID = option.index; --really? maybe deprecated
		end
	end

	ScanSavedInstances()
	local data = GetInstanceDataByID(instanceID);
	if not data then
		return
	end

	-- prepare instance encounter list
	--local bosses = GetInstanceBosses(data.instanceID); -- remove

	if data.instanceInfo.description=="" and #data.encounters==0 then
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
	if #data.encounters>0 then
		GameTooltip:AddLine(" ");
		for i, encounter in ipairs(data.encounters)do
			local info = C("ltgray"," (insId: ".. data.instanceID .." / lfrBoss: "..i.." / raidBoss: "..encounter.index..")");
			if encounter.name then
				GameTooltip:AddDoubleLine(C("ltblue",encounter.name)..(IsShiftKeyDown() and info or ""),encounter.isKilled and C("red",BOSS_DEAD) or C("green",BOSS_ALIVE));
			else
				GameTooltip:AddDoubleLine(C("ltred",_G["ERR_INTERNAL_ERROR"]),info);
			end
		end
	end

	if IsShiftKeyDown() then
		GameTooltip:AddLine(" ")
		GameTooltip:AddDoubleLine(C("ltgray","DebugMode"),C("ltgray","@project-version@ / "..GetLocale()))
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
	if not UpdateNpcID(type(GossipFrame.gossipOptions)=="table") then
		return
	end

	wipe(buttons);
	wipe(iconTexCoords);
	ScanSavedInstances();

	-- update options before layout gossip buttons; very smart. ;-) Thanks at fuba82.
	for i,option in ipairs(GossipFrame.gossipOptions) do
		local instanceID,data;
		if ns.npc2instance[NPC_ID] and ns.npc2instance[NPC_ID][option.gossipOptionID] then
			instanceID = ns.npc2instance[NPC_ID][option.gossipOptionID];
		else
			instanceID = ns.npc2instance[NPC_ID][option.orderIndex + (ns.gossipIndexOffset[NPC_ID] or 0)];
		end
		data = GetInstanceDataByID(instanceID);
		if data then
			option.nameOrig = option.name;
			option.instanceID = instanceID;

			local noSubtitle = (type(ns.noSubtitle[NPC_ID])=="table" and ns.noSubtitle[NPC_ID][option.instanceID]==true) or ns.noSubtitle[NPC_ID]==true;

			-- replace gossip icon (interface/minimap/raid)
			option.icon = 1502548;

			-- replcae gossip text
			if #data.encounters==0 then
				option.name = data.instanceInfo.name; -- mostly for szenarios
			else
				local dark = db.profile.darkBackground and "DarkBG" or "";
				local clear = #data.encounters==data.numEncountersKilled and "Clear" or "";
				local pattern = GossipTextPattern["enemy"..clear..dark];
				if (not noSubtitle) and data.instanceInfo.name~=data.instanceInfo.name2 then
					pattern = pattern .. GossipTextPattern["raidWing"..dark];
				end
				option.name = pattern:format(
					data.instanceInfo.name, -- instance wing name
					data.numEncountersKilled, -- encounters killed this week
					#data.encounters, -- number of encounters of the wing
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
	if not UpdateNpcID(type(ImmersionFrame.TitleButtons.Buttons)=="table") then
		return;
	end

	wipe(buttons);
	wipe(iconTexCoords);
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
				instanceID = ns.npc2instance[NPC_ID][gossipOptionID];
			end
			if instanceID then
				local data = GetInstanceDataByID(instanceID)
				button.data = data;
				local noSubtitle = (type(ns.noSubtitle[NPC_ID])=="table" and ns.noSubtitle[NPC_ID][instanceID]==true) or ns.noSubtitle[NPC_ID]==true;
				-- gossip text replacement
				if #data.encounters==0 then
					button:SetText(data.instanceInfo.name)
				else
					local clear = #data.encounters==data.numEncountersKilled and "Clear" or "";
					local pattern = GossipTextPattern["enemy"..clear.."DarkBG"];
					if (not noSubtitle) and (data.instanceInfo.name~=data.instanceInfo.name2 or ns.instanceName2group[instanceID]) then
						pattern = GossipTextPattern["raidWingImmersion"..clear];
					end
					button:SetFormattedText(
						pattern,
						data.instanceInfo.name, -- name of instance wing
						data.numEncountersKilled, -- killed  encounters
						#data.encounters, -- number of encounters in this wing
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
-- create info tooltip for raids

local function CreateEncounterTooltip(parent, append)
	if not IsInRaid() then
		return
	end
	ScanSavedInstances()
	local instanceName, _, difficultyID, difficultyName, _, _, _, instanceMapID, _, instanceID = GetInstanceInfo()
	local data
	if difficultyID==7 or difficultyID==17 then
		data = GetInstanceDataByID(instanceID)
	end
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

		GameTooltip:AddLine(" ");

		GameTooltip:AddLine(C("ltblue",data.instanceInfo.name));
		for _, encounter in ipairs(data.encounters)do
			GameTooltip:AddDoubleLine("|Tinterface/questtypeicons:14:14:0:0:128:64:0:18:36:54|t "..encounter.name,encounter.isKilled and C("red",BOSS_DEAD) or C("green",BOSS_ALIVE));
		end

		GameTooltip:Show();
		if append then
			return true;
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

local dbDefaults = {
	profile = {
		AddOnLoaded = true,
		minimap = {hide=false},
		minimapButtonETT = false,
		queueStatusFrameETT = true,
		darkBackground = false,
		replaceOptions = true,
--@do-not-package@
		debugMode = false,
--@end-do-not-package@
	}
};

local function getset(info,value)
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

local options = {
	type = "group",
	name = L[addon],
	get = getset,
	set = getset,
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
--@do-not-package@
		debugMode = {
			type = "toggle", order = 3,
			name = "Debug mode"
		},
--@end-do-not-package@
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
		info = {
			type = "description", order = 6, fontSize = "medium",
			name = L["InfoMsg"]
		},
		-- npcs added by function updateOptions
	}
};

local function RegisterOptions()
	db = LibStub("AceDB-3.0"):New("LFRotp_Options",dbDefaults,true);
	LibStub("AceConfig-3.0"):RegisterOptionsTable(L[addon], options);
	local opts = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(L[addon]);
	HST.BlizzOptions_ExpandOnShow(opts);
	HST.AddCredit(L[addon]); -- options.args.credits.args
	ACD:SetDefaultSize(L[addon],700,700)
end

local function createDescription(npc)
	if npc[1]==0 then
		return {
			type = "description", fontSize="large",
			name = L["StillMissingNPC"..npc[5]]
		};
	end
	local colon = CHAT_HEADER_SUFFIX:trim()
	local npcName = L["Currently unknown"];
	if rawget(L,"NPC"..npc[1]) then
		npcName = L["NPC"..npc[1]];
	end
	local lines = {
		C("dkyellow",NAME..colon) .." ".. npcName,
		C("dkyellow",ZONE..colon) .." ".. (npc[3]==false and L["Somewhere in"].." "..npc.zoneName.."?" or npc.zoneName),
	};
	if npc[3] and npc[4] then
		tinsert(lines,C("dkyellow",L["Coordinates"]..colon) .." ".. npc[3]..", "..npc[4]);
	end
	if type(npc.info)=="string" then
		tinsert(lines,C("dkyellow",INFO..colon).." "..C("ltgreen",npc.info))
	end
	return {
		type = "description", order = 1, fontSize = "medium", width="double",
		name = table.concat(lines,"|n")
	}
end

local function addWaypointToOpt(opt,npc)
	opt.args.TomTom = {
		type = "execute", order = 2, width="half",
		name = L["TomTom"],
		func = function()
			HST.AddWaypoint(npc[2],npc[3],npc[4],L["NPC"..npc[1]],addon,true,false)
		end,
		hidden =function() return TomTom and TomTom.AddWaypoint end
	}
	opt.args.MapPin = {
		type = "execute", order = 4, width="half",
		name = MAP_PIN, desc = L["MapPinDesc"],
		func = function()
			HST.AddWaypoint(npc[2],npc[3],npc[4],L["NPC"..npc[1]],addon,false,false)
		end
	}
end

local function updateOptions()
	local faction = ns.faction();

	options.args.neutral.hidden=true;
	ScanSavedInstances()

	for i=1, #ns.npcs do
		local npc = ns.npcs[i];
		if npc.addTo then
			local opt = {
				type="group", order=npc.order+1, inline=true,
				name="",
				args = {
					desc = createDescription(npc)
				}
			}
			if npc[3] and npc[4] then
				addWaypointToOpt(opt,npc);
			end
			options.args["entry"..npc.addTo].args.location.args["npc"..npc.order] = opt;
		else
			local opt = {
				type = "group",order = 10+i,
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
			if npc[1]>0 and npc[3] and npc[4] then
				addWaypointToOpt(opt.args.location.args.npc1,npc);
			end
			if npc.imgs then
				opt.args["pics_spacer"] = {
					type="description", order = 10, name= " "
				}
				for I=1, npc.imgs[2] do
					opt.args.location.args["pic"..I] = {
						type = "description", order = 10+I, width = "normal", name = "",
						image = imgPath..npc.imgs[1]:format(I,faction), imageWidth = imgSize, imageHeight = imgSize
					}
				end
			end
			local order = 1;
			for j=7, #npc do
				local instanceID = npc[j][1];
				local instanceData = GetInstanceDataByID(instanceID);
				if instanceData then
					local entry = {
						type = "group", order = order, inline=true,
						name = instanceData.instanceInfo.name
							.. (instanceData.groupName and " "..C("ltgray","("..instanceData.groupName..")") or "")
							--.. C("ltgray"," ("..instanceID..")")
							,
						args = {
						}
					}
					entry.args.desc = {
						type = "description", order=2, fontSize="medium",
						name = instanceData.instanceInfo.description
					}
					if instanceData.encounters then
						local encounterEntries = {}
						for _,encounter in ipairs(instanceData.encounters)do
							local color = "yellow";
							local name = UNKNOWN
							if encounter.name then
								color = encounter.isKilled and "red" or "green";
								name = "   |Tinterface\\lfgframe\\lfg:14:14:0:0:64:32:0:32:0:32|t"..encounter.name
							else
								ns:debug(instanceID)
							end
							tinsert(encounterEntries,C(color,name));
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
						tt:AddLine(L["NPC"..npc[1]].." "..C("mage","(".. _G["EXPANSION_NAME"..npc[5]]..")"),.3,1,.3);
						tt:AddLine(npc.zoneName..", "..npc[3]..", "..npc[4],.7,.7,.7);
						if type(npc.info)=="string" then
							tt:AddLine(npc.info,.7,.9,.9,true)
						end
					else
						tt:AddLine(L["Currently unknown"].." "..C("mage","(".. _G["EXPANSION_NAME"..npc[5]]..")"),.3,1,.3);
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
