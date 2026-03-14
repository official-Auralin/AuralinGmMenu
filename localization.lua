-- Thanks to phanx for her excellent localization tutorial:
-- https://phanx.net/addons/tutorials/localize

local _, namespace = ...

local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        return v
    end,
})

namespace.L = L

local LOCALE = GetLocale()

if LOCALE == "enUS" then
    -- The EU English game client also uses enUS.
    return
end

if LOCALE == "itIT" then
    L["Total addon(s):"] = "Addon totali:"
    L["Total loaded AddOns:"] = "Addon caricati:"
    L["Number of addons to monitor:"] = "Numero di addon da monitorare:"
    L["Reset settings and reload UI"] = "Reset impostazioni e ricarica UI"
    L["Save settings and reload UI"] = "Salva impostazioni e ricarica UI"
    L["version"] = "versione"
    L["Show Icons"] = "Mostra icone"
    L["Show Bind Keys"] = "Mostra tasti associati"
    L["Show Minimap Icon"] = "Mostra icona minimappa"
    L["Show Memory Diagnostics"] = "Mostra diagnostica memoria"
    L["Tooltip Scale"] = "Scala tooltip"
    L["Open settings with /agmm"] = "Apri le impostazioni con /agmm"
    L["Right-click broker text to open settings."] = "Click destro sul broker per aprire le impostazioni."
    L["Current"] = "Attuale"
    L["Toggle tooltip"] = "Mostra/Nascondi tooltip"
    L["Open settings"] = "Apri impostazioni"
    L["Hide tooltip"] = "Nascondi tooltip"
    L["Unavailable in combat"] = "Non disponibile in combattimento"
    L["Feature unavailable on this client"] = "Funzione non disponibile su questo client"
    L["Action failed"] = "Azione fallita"
    L["positive number for nr.addons, 0 for only header, -1 to disable"] =
        "numero positivo per nr.addons, 0 per solo header, -1 per disabilitare"
    return
end

if LOCALE == "frFR" then
    L["Total addon(s):"] = "Addons charges:"
    L["Total loaded AddOns:"] = "Addons charges:"
    L["Number of addons to monitor:"] = "Nombre d addons a surveiller:"
    L["Reset settings and reload UI"] = "Reinitialiser et recharger l interface"
    L["Save settings and reload UI"] = "Enregistrer et recharger l interface"
    L["version"] = "version"
    L["Show Icons"] = "Afficher les icones"
    L["Show Bind Keys"] = "Afficher les raccourcis"
    L["Show Minimap Icon"] = "Afficher l icone minimap"
    L["Show Memory Diagnostics"] = "Afficher diagnostics memoire"
    L["Tooltip Scale"] = "Echelle de l infobulle"
    L["Open settings with /agmm"] = "Ouvrir les options avec /agmm"
    L["Right-click broker text to open settings."] = "Clic droit sur le broker pour ouvrir les options."
    L["Current"] = "Actuel"
    L["Toggle tooltip"] = "Basculer l infobulle"
    L["Open settings"] = "Ouvrir options"
    L["Hide tooltip"] = "Masquer l infobulle"
    L["Unavailable in combat"] = "Indisponible en combat"
    L["Feature unavailable on this client"] = "Fonction indisponible sur ce client"
    L["Action failed"] = "Action echouee"
    L["positive number for nr.addons, 0 for only header, -1 to disable"] =
        "nombre positif pour nr.addons, 0 pour l entete uniquement, -1 pour desactiver"
    return
end
