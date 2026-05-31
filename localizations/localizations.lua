
local L, addon, ns = {}, ...;

ns.L = setmetatable(L,{__index=function(t,k)
	local v = tostring(k);
	rawset(t,k,v);
	return v;
end});

local v = GetBuildInfo()
local n = tonumber((v:gsub("%.","")))
local s = "It is Patch X and the location of the Storyteller of Y remains unknown."
local t = "He was expected with Patch Z."
L["StillMissingNPC10"] = s:gsub("X",v):gsub("Y","The War Within")
L["StillMissingNPC11"] = s:gsub("X",v):gsub("Y","Midnight")..(n>1305 and t:gsub("Z","13.0.5") or "")


-- Do you want to help localize this addon?
-- https://www.curseforge.com/wow/addons/@cf-project-name@/localization

--@localization(locale="enUS", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@

L["NPC80675"] = "Auridormi"
L["NPC80633"] = "Lorewalker Han"
L["NPC78709"] = "Lorewalker Fu"
L["NPC78777"] = "Lorewalker Shin"
L["NPC94870"] = "Seer Kazal"
L["NPC94870"] = "Seer Kazal"
L["NPC111246"] = "Archmage Timear"
L["NPC31439"] = "Archmage Timear"
L["NPC177193"] = "Kiku"
L["NPC177208"] = "Eppu"
L["NPC205959"] = "Ta'elfar"
L["NPC262873"] = "Luka Ferad"
