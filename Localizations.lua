
local addon, ns = ...

local L = {};
ns.L = setmetatable(L,{__index=function(t,k)
	local v = tostring(k);
	rawset(t,k,v);
	return v
end});

-- Do you want to help localize this addon?
-- https://www.curseforge.com/wow/addons/lfr-of-the-past/localization

--@do-not-package@
L["LFR_of_the_past"] = "LFR [of the past]"
L["AddOnLoaded"] = "AddOn loaded..."
L["AddOnLoadedDesc"] = "Display 'AddOn loaded...' message on login"
L["MinimapIcon"] = "Minimap icon"
L["MinimapIconDesc"] = "Show icon on minimap"
L["TomTomMissing"] = "Missing addon TomTom"
L["TomTomAdd"] = "Add to tomtom"
L["PlayerNeutral"] = "You are faction neutral. This addon required a choosen faction to work."
L["Coordinates"] = "Coordinates"
L["Click"] = "Click"
L["Open LFR [of the past] info panel"] = "Open LFR [of the past] info panel"
--@end-do-not-package@

--@localization(locale="enUS", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@

if LOCALE_deDE then
--@do-not-package@
--@end-do-not-package@
--@localization(locale="deDE", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
end

if LOCALE_esES then
--@localization(locale="esES", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
end

if LOCALE_esMX then
--@localization(locale="esMX", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
end

if LOCALE_frFR then
--@localization(locale="frFR", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
end

if LOCALE_itIT then
--@localization(locale="itIT", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
end

if LOCALE_koKR then
--@localization(locale="koKR", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
end

if LOCALE_ptBR or LOCALE_ptPT then
--@localization(locale="ptBR", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
end

if LOCALE_ruRU then
--@localization(locale="ruRU", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
end

if LOCALE_zhCN then
--@localization(locale="zhCN", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
end

if LOCALE_zhTW then
--@localization(locale="zhTW", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
end
