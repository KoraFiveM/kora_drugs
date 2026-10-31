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

local function stationRecipe(name)
	local entry = Drugs.Meth and Drugs.Meth[name]
	return stepRecipe('Meth:' .. name, entry and entry.data)
end

local function resetCook(source)
	cooking[source] = nil
end

local function nearStation(source, name)
	local entry = Drugs.Meth and Drugs.Meth[name]
	return isNear(source, entry and entry.locations and entry.locations.coords)
end

local function elapsedSince(session, stampField, gap)
	local stamp = session[stampField]
	return stamp ~= nil and (os.time() - stamp) >= gap
end

Kora.callback.register('qb-drugs:server:startCook', function(source)
	if cooking[source] then
		return false, "Cooking already started for this source"
	end
	if not nearStation(source, 'pour') then
		return false, "Player is too far from the heat source"
	end
	local recipe = stationRecipe('pour')
	if not recipe then
		return false, "No recipe is set for this step"
	end
	if not craft(source, recipe) then
		return false, "Missing ingredients"
	end

	local session = newCookState()
	session.pour = true
	cooking[source] = session

	return true
end)

Kora.callback.register('qb-drugs:server:runDials', function(source)
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
	if not nearStation(source, 'heat') then
		return false, "Player is too far from the heat source"
	end

	session.heated   = true
	session.heatedAt = os.time()
	return true
end)

Kora.callback.register('qb-drugs:server:smash', function(source)
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
	if not nearStation(source, 'smash') then
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
	if not nearStation(src, 'bag') then return end
    if os.time() < session.minTime then return end
	local recipe = stationRecipe('bag')
	if recipe then craft(src, recipe) end
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