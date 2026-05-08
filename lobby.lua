local CDID     = 6911148748
local DDS_IDS  = {
    [131378148336503] = true,
    [114862923457266] = true,
}

if DDS_IDS[game.PlaceId] then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/petinjusemarang/tutorialmasak/refs/heads/main/braindds.lua"))()
elseif game.PlaceId == CDID then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/petinjusemarang/tutorialmasak/refs/heads/main/brain.lua"))()
else
    print("[LOBBY] Unknown game PlaceId: " .. tostring(game.PlaceId))
end
