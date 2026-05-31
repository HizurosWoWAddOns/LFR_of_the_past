
local addon, ns = ...;
local L = ns.L;

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
L["MinimapETT"] = "Minimap button"
L["MinimapETTDesc"] = "Adds encounter tooltip to the addon own minimap button tooltip. Without a data broker panel addon like Titan Panel, you should enable \"Minimap icon\" to display the encounter tooltip."
L["InstanceEyeETT"] = "Instance eye"
L["InstanceEyeETTDesc"] = "Adds encounter tooltip to blizzards standard ui instance eye on minimap"
L["LFR NPCs"] = "LFR NSC's"
L["DarkBackground"] = "Dark background"
L["DarkBackgroundDesc"] = "With some add-ons you can remove the parchment background from the LFR NPC window. This option makes the text color lighter for better readability."

L["TimearLegion"] = "Timear in the old Dalaran (WotLK) also grants access to the Legion LFR"
L["TimearWotLK"] = "Timear in the legion Dalaran also grants access to the Legion LFR"

-- 2025-07-07
L["MapPin"] = "Map pin"
L["MapPinDesc"] = "Add map pin link to your chat. You must click on it to add it to your world map."

L["InfoMsg"] = "Blizzard added the LFR mode with Cataclysm. After Cataclysm, the NPCs that grant access to the older LFR wings were released. Therefore, this list starts with Cataclysm. There is no LFR mode for older raids like Icecrown Citadel or Molten Core."

if LOCALE_deDE then
	L["AddOnLoaded"] = "AddOn geladen..."
	L["DarkBackground"] = "Dunkler Hintergrund"
	L["DarkBackgroundDesc"] = "Mit einigen Add-ons können Sie den Pergament Hintergrund aus dem LFR-NPC-Fenster entfernen. Mit dieser Option wird die Textfarbe zur besseren Lesbarkeit heller dargestellt."

	L["TimearLegion"] = "Timear im alten Dalaran (WotLK) gewährt ebenfalls Zugang zum Legion-LFR."
	L["TimearWotLK"] = "Timear in Dalaran (Legion) gewährt ebenfalls Zugang zum Legion-LFR."

	L["InfoMsg"] = "Mit Cataclysm hat Blizzard den LFR Modus hinzugefügt. Nach Cataclysm erschienen dann die NPC's, die den Zugang zu den älteren LFR Flügel gewähren. Daher fängt die Liste auch erst mit Cataclysm an. Für ältere Schlachtzüge wie Eiskronenzitadelle oder Geschmolzener Kern gibt es keinen LFR Mode."

	--L["MapPinAdd"] = "Add map pin"
end

