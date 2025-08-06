-- shared.lua
DeriveGamemode("sandbox")

GM.Name = "Evil Resident V"
GM.Author = "Generated"
GM.Email = ""
GM.Website = ""

-- Called on gamemode initialization
function GM:Initialize()
    print("Evil Resident V initialized on map: " .. game.GetMap())
    -- TODO: Add map-specific setup for erv_ maps
end
