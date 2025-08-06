-- shared.lua
DeriveGamemode("sandbox")

GM.Name    = "Evil Resident V"
GM.Author  = "Generated"
GM.Email   = ""
GM.Website = ""

-- Disable spawn and context menus on client
if CLIENT then
    hook.Add("SpawnMenuOpen", "ERV_DisableSpawnMenu", function() return false end)
    hook.Add("ContextMenuOpen", "ERV_DisableContextMenu", function() return false end)
end
