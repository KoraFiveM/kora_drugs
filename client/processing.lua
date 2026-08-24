-- Sets up every station tagged phase == 'processing'. Reuses
-- Drugs.setupStation from growing.lua (fxmanifest.lua loads that file
-- first) -- this file adds no new interaction logic of its own, only a
-- different config filter, matching every other phase file.

for drugName, drug in pairs(Config.drugs) do
    for stageName, station in pairs(drug.stations) do
        if station.phase == 'processing' then
            Drugs.setupStation(drugName, stageName, station)
        end
    end
end
