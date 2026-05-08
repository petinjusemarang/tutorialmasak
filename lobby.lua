local CDID = 6911148748
local DDS  = 131378148336503

if game.PlaceId == DDS then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/petinjusemarang/tutorialmasak/refs/heads/main/braindds.lua"))()
elseif game.PlaceId == CDID then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/petinjusemarang/tutorialmasak/refs/heads/main/brain.lua"))()
else
    print("[LOBBY] Unknown game PlaceId: " .. tostring(game.PlaceId))
end
