-- Sets up every station tagged phase == 'packaging'. Same shared
-- Drugs.setupStation as processing.lua -- see growing.lua's header.

for drugName, drug in pairs(Config.drugs) do
    for stageName, station in pairs(drug.stations) do
        if station.phase == 'packaging' then
            Drugs.setupStation(drugName, stageName, station)
        end
    end
end
