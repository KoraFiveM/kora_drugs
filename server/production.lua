-- The ONE generic stage-transition engine every drug in Config.drugs runs
-- through. Every function here branches on `station.type` (one of
-- Config.stationType's three generic roles) or on whether `Config.drugs[name]
-- .growth` exists -- NEVER on a drug or stage NAME. A new drug is added
-- entirely in config.lua/shared/items.lua; nothing in this file should ever
-- need to change for it.

Production = Production or {}

-- growState[src][drugName] = { readyAt: integer } (os.time() seconds). One
-- active grow per player per drug -- a second startGrow for the same drug
-- while one is already running is rejected, not queued or overwritten.
local growState = {}

---@param yieldCfg { min: integer, max: integer } | { [1]: integer, [2]: number }[]
---@return integer
function Production.rollYield(yieldCfg)
    if yieldCfg.min and yieldCfg.max then
        return math.random(yieldCfg.min, yieldCfg.max)
    end
    return QB.util.weightedChoice(yieldCfg)
end

---@param src integer
---@param drugName string
---@return boolean, string|nil
function Production.startGrow(src, drugName)
    local drug = Config.drugs[drugName]
    if not drug then return false, 'unknown drug' end
    local growth = drug.growth
    if not growth then return false, 'drug has no growth phase' end
    if growState[src] and growState[src][drugName] then return false, 'already growing' end

    local ok = exports.qbcore:removeItem(src, growth.seedItem, 1)
    if not ok then return false, 'missing seed item' end

    local totalMs = 0
    for _, stage in ipairs(growth.growthStages) do totalMs = totalMs + stage.duration end

    growState[src] = growState[src] or {}
    growState[src][drugName] = { readyAt = os.time() + math.ceil(totalMs / 1000) }
    return true
end

---@param src integer
---@param drugName string
---@return boolean
function Production.isReadyToHarvest(src, drugName)
    local state = growState[src] and growState[src][drugName]
    return state ~= nil and os.time() >= state.readyAt
end

---@param src integer
---@param drugName string
---@return boolean, string|nil, table|nil
function Production.completeHarvest(src, drugName)
    local drug = Config.drugs[drugName]
    if not drug then return false, 'unknown drug' end
    local growth = drug.growth
    if not growth then return false, 'drug has no growth phase' end

    local state = growState[src] and growState[src][drugName]
    if not state then return false, 'nothing planted' end
    if os.time() < state.readyAt then return false, 'not ready to harvest yet' end

    local amount = Production.rollYield(growth.harvestYield)
    local ok, err = exports.qbcore:addItem(src, growth.item, amount)
    if not ok then return false, err end

    growState[src][drugName] = nil
    return true, nil, { item = growth.item, amount = amount }
end

---@param src integer
---@param drugName string
---@param stageName string
---@return boolean, string|nil, table|nil
function Production.completeConvert(src, drugName, stageName)
    local drug = Config.drugs[drugName]
    if not drug then return false, 'unknown drug' end
    local station = drug.stations[stageName]
    if not station or station.type ~= 'convert' then return false, 'not a conversion station' end
    local recipe = station.recipe
    if not recipe then return false, 'station has no recipe' end

    if recipe.inputItem then
        if not exports.qbcore:hasItem(src, recipe.inputItem, recipe.inputAmount or 1) then
            return false, 'missing input item'
        end
        local ok, err = exports.qbcore:removeItem(src, recipe.inputItem, recipe.inputAmount or 1)
        if not ok then return false, err end
    end

    local ok, err = exports.qbcore:addItem(src, recipe.outputItem, recipe.outputAmount or 1)
    if not ok then
        if recipe.inputItem then
            local restored, restoreErr = exports.qbcore:addItem(src, recipe.inputItem, recipe.inputAmount or 1, nil, nil, 'drug-convert-rollback')
            if not restored then print(('^1[qbdrugs]^7 conversion rollback failed for %s: %s'):format(src, tostring(restoreErr))) end
        end
        return false, err
    end

    return true, nil, { item = recipe.outputItem, amount = recipe.outputAmount or 1 }
end

---Rolls this drug's per-stage cop-alert chance and, on a hit, routes it
---through exports.qbcore:alert -- the ONLY dispatch integration point this
---resource uses (that export fires the real `police:server:policeAlert`
---legacy event itself; qbdrugs never calls it directly).
---@param drugName string
---@param stageName string
---@param coords table|nil
---@return boolean fired
function Production.rollCopAlert(drugName, stageName, coords)
    local drug = Config.drugs[drugName]
    if not drug then return false end
    local alertCfg = drug.copAlerts and drug.copAlerts[stageName]
    if not alertCfg or not alertCfg.enabled then return false end
    if math.random() >= alertCfg.chance then return false end

    exports.qbcore:alert({
        jobs = Config.copAlertJobs,
        title = drug.label .. ' Activity',
        message = ('Suspected %s activity detected.'):format(drug.label),
        coords = coords,
        code = 'drugs',
    })
    return true
end

---The single entry point stations.lua calls for every stage of every drug.
---Dispatches purely on `station.type`.
---@param src integer
---@param drugName string
---@param stageName string
---@param coords table|nil
---@return boolean, string|nil, table|nil
function Production.completeStage(src, drugName, stageName, coords)
    local drug = Config.drugs[drugName]
    if not drug then return false, 'unknown drug' end
    local station = drug.stations[stageName]
    if not station or not Config.stationType[station.type] then return false, 'unknown station' end

    local ok, err, result
    if station.type == 'growStart' then
        ok, err = Production.startGrow(src, drugName)
    elseif station.type == 'harvest' then
        ok, err, result = Production.completeHarvest(src, drugName)
    elseif station.type == 'convert' then
        ok, err, result = Production.completeConvert(src, drugName, stageName)
    end

    if ok then
        Production.rollCopAlert(drugName, stageName, coords or station.coords)
    end

    return ok, err, result
end

-- Test-only introspection (never used by stations.lua/selling.lua). Kept
-- behind an underscore-prefixed name, matching this codebase's "internal,
-- not part of the public surface" convention.
function Production._growState() return growState end
