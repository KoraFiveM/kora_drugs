local config = Config.Meth
local cooking = {}

RegisterLabTeleport('meth', 'Meth', 'tele')

local minStageGap = {
	toHeat  = 5,
	toSmash = 5,
	toBag   = 5,
}

local function newCookState()
	local now = os.time()
	return {
		pour      = false,
		heated    = false,
		smashed   = false,
		pourAt    = now,
		heatedAt  = nil,
		smashedAt = nil,
        minTime = os.time() + 25
	}
end

-- The recipe picked for a station on the creator's events page; the config one if none.
local function stationRecipe(name, fallback)
	local entry = Drugs.Meth and Drugs.Meth[name]
	return stepRecipe('Meth:' .. name, entry and entry.data) or fallback
end

local function resetCook(source)
	cooking[source] = nil
end

-- Station positions come from the saved Meth rows (the creator), not the config.
local function stationCoords(name)
	local entry = Drugs.Meth and Drugs.Meth[name]
	local c = entry and entry.locations and entry.locations.coords
	if not (c and tonumber(c.x) and tonumber(c.y) and tonumber(c.z)) then return nil end
	return vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0)
end

local function withinRange(source, coords, radius)
	if not coords then return false end
	return QB.distance.player(source, coords, radius or 5)
end

local function elapsedSince(session, stampField, gap)
	local stamp = session[stampField]
	return stamp ~= nil and (os.time() - stamp) >= gap
end

QB.callback.register('qb-drugs:server:startCook', function(source)
	if cooking[source] then
		return false, "Cooking already started for this source"
	end
	if not withinRange(source, stationCoords('pour')) then
		return false, "Player is too far from the heat source"
	end
	if not craft(source, stationRecipe('pour', config.cook_recipe)) then
		return false, "Missing ingredients"
	end

	local session = newCookState()
	session.pour = true
	cooking[source] = session

	return true
end)

QB.callback.register('qb-drugs:server:runDials', function(source)
	local session = cooking[source]
	if not session then
		return false, "No active cooking session for this source"
	end
	if not session.pour then
		return false, "Player has not poured the chemicals yet"
	end
	if session.heated then
		return false, "Player has already heated this cook"
	end
	if not elapsedSince(session, 'pourAt', minStageGap.toHeat) then
		return false, "Moving too fast"
	end
	if not withinRange(source, stationCoords('heat')) then
		return false, "Player is too far from the heat source"
	end

	session.heated   = true
	session.heatedAt = os.time()
	return true
end)

QB.callback.register('qb-drugs:server:smash', function(source)
	local session = cooking[source]
	if not session then
		return false, "No active cooking session for this source"
	end
	if not (session.pour and session.heated) then
		return false, "Player has not heated this cook yet"
	end
	if session.smashed then
		return false, "Player has already smashed this cook"
	end
	if not elapsedSince(session, 'heatedAt', minStageGap.toSmash) then
		return false, "Moving too fast"
	end
	if not withinRange(source, stationCoords('smash')) then
		return false, "Player is too far from the smash station"
	end

	session.smashed   = true
	session.smashedAt = os.time()
	return true
end)

RegisterNetEvent('qb-drugs:server:getMeth', function()
	local src     = source
	local session = cooking[src]

	if not session then return end
	if not (session.pour and session.heated and session.smashed) then return end
	if not elapsedSince(session, 'smashedAt', minStageGap.toBag) then return end
	if not withinRange(src, stationCoords('bag')) then return end
    if os.time() < session.minTime then return end
	craft(src, stationRecipe('bag', config.bag_recipe))
	resetCook(src)
end)

RegisterNetEvent('qb-drugs:server:explosion', function()
	local source = source
	resetCook(source)
end)

AddEventHandler('playerDropped', function()
	local source = source
	resetCook(source)
end)