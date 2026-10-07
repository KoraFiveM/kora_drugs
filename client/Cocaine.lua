if Config and Config.Cocaine and Config.Cocaine.disabled then
    print("Cocaine plants are disabled")
    return
end

local function setStage()
    CreateThread(function()
        if GetResourceState('bob74_ipl') ~= 'missing' then
            while GetResourceState('bob74_ipl') ~= 'started' do
                Wait(100)
            end
            BikerCocaine = exports['bob74_ipl']:GetBikerCocaineObject()
            BikerCocaine.Style.Set(BikerCocaine.Style.upgrade)
            BikerCocaine.Security.Set(BikerCocaine.Security.upgrade)
            BikerCocaine.Details.Enable({BikerCocaine.Details.cokeBasic1, BikerCocaine.Details.cokeBasic2, BikerCocaine.Details.cokeBasic3}, true)
        end
    end)
end

setStage()
local cuttingcoke = false
local baggingcoke = false

local function cutCoke(coords, offset, rotation)
    cuttingcoke = true

    local animDict, animName = "anim@amb@business@coc@coc_unpack_cut_left@", "coke_cut_v5_coccutter"
    QB.stream.loadAnimDict(animDict)

    local animDuration = GetAnimDuration(animDict, animName) * 1000
    local ped = PlayerPedId()
    local scenePos = vector3(coords.x + offset.x, coords.y + offset.y, coords.z + offset.z)
    local sceneRot = rotation
    local scenes = {{
        { hash = "bkr_prop_coke_bakingsoda_o", animName = "coke_cut_v5_bakingsoda" },
        { hash = "prop_cs_credit_card", animName = "coke_cut_v5_creditcard" },
        { hash = "prop_cs_credit_card", animName = "coke_cut_v5_creditcard^1" }
    }}

    local scenesList, entitiesList = {}, {}
    for i = 1, #scenes do
        local scene = NetworkCreateSynchronisedScene(
            scenePos.x, scenePos.y, scenePos.z,
            sceneRot.x, sceneRot.y, sceneRot.z,
            2, false, false, 1065353216, 0, 1.3
        )
        NetworkAddPedToSynchronisedScene(ped, scene, animDict, animName, 1.5, -4.0, 1, 16, 1148846080, 0)
        for j = 1, #scenes[i] do
            local s = scenes[i][j]
            QB.stream.loadModel(s.hash)
            local obj = CreateObjectNoOffset(
                s.hash,
                coords.x, coords.y, coords.z,
                true, true, true
            )
            SetModelAsNoLongerNeeded(s.hash)
            entitiesList[#entitiesList + 1] = obj
            NetworkAddEntityToSynchronisedScene(obj, scene, animDict, s.animName, 4.0, -8.0, 1)
        end
        scenesList[#scenesList + 1] = scene
    end
    DisableCamCollisionForEntity(ped)
    FreezeEntityPosition(ped, true)
    for i = 1, #scenesList do
        NetworkStartSynchronisedScene(scenesList[i])
    end
    Wait(animDuration - 11000)
    for i = 1, #scenesList do
        NetworkStopSynchronisedScene(scenesList[i])
    end
    for i = 1, #entitiesList do
        DeleteEntity(entitiesList[i])
    end
    RemoveAnimDict(animDict)
    FreezeEntityPosition(ped, false)
    cuttingcoke = false
end

local function bagCoke(coords, offset, rotation)
baggingcoke = true
    local ver = ""
	local animDict, animName = "anim@amb@business@meth@meth_smash_weight_check@", "break_weigh_"..ver.."char01"
	QB.stream.loadAnimDict(animDict)
	local animDuration = GetAnimDuration(animDict, animName) * 1000
	local ped = PlayerPedId()
	local scenePos, sceneRot = vector3(coords.x + offset.x, coords.y + offset.y,coords.z + offset.z +0.03), rotation
	local scenes = {
    	{
    		{	hash = "bkr_prop_coke_cutblock_01",	animName = "break_weigh_"..ver.."box01"},
    		{	hash = "bkr_prop_coke_fullmetalbowl_02",	animName = "break_weigh_"..ver.."box01^1"},
    		{	hash = "bkr_prop_coke_cutblock_01",	animName = "break_weigh_"..ver.."methbag01"}
    	},
    	{
    		{	hash = "xm3_prop_xm3_bag_coke_01a",	animName = "break_weigh_"..ver.."methbag01^1"},
    		{	hash = "xm3_prop_xm3_bag_coke_01a",	animName = "break_weigh_"..ver.."methbag01^2"},
    		{	hash = "xm3_prop_xm3_bag_coke_01a",	animName = "break_weigh_"..ver.."methbag01^3"}
    	},
    	{
    		{	hash = "bkr_prop_coke_fullscoop_01a",	animName = "break_weigh_"..ver.."scoop"},
    		{	hash = "bkr_prop_coke_scale_01",	animName = "break_weigh_"..ver.."scale"},
    		{	hash = "bkr_prop_fakeid_penclipboard",	animName = "break_weigh_"..ver.."pen"}
    	},
    	{
    		{	hash = "bkr_prop_fakeid_clipboard_01a",	animName = "break_weigh_"..ver.."clipboard"},
    	}
    }
    local scenesList, entitiesList = {}, {}
    for i=1, #scenes, 1 do
    	local scene = NetworkCreateSynchronisedScene(scenePos.x, scenePos.y, scenePos.z, sceneRot.x, sceneRot.y, sceneRot.z, 2, false, false, 1065353216, 0, 1.3)
    	NetworkAddPedToSynchronisedScene(ped, scene, animDict, animName, 1.5, -4.0, 1, 16, 1148846080, 0)
    	for j=1, #scenes[i], 1 do
    		local s = scenes[i][j]
            QB.stream.loadModel(s.hash)
    		local obj = CreateObjectNoOffset(s.hash, coords.x, coords.y, coords.z, true, true, true)
    		SetModelAsNoLongerNeeded(s.hash)
    		entitiesList[#entitiesList+1] = obj
    		NetworkAddEntityToSynchronisedScene(obj, scene, animDict, s.animName, 4.0, -8.0, 1)
    	end
    	scenesList[#scenesList+1] = scene
    end
    DisableCamCollisionForEntity(ped)
    FreezeEntityPosition(ped, true)
    for i=1, #scenesList, 1 do
    	NetworkStartSynchronisedScene(scenesList[i])
    end
    Wait(animDuration-11000)
    for i=1, #scenesList, 1 do
    	NetworkStopSynchronisedScene(scenesList[i])
    end
    for i=1, #entitiesList, 1 do
    	DeleteEntity(entitiesList[i])
    end
    RemoveAnimDict(animDict)
    FreezeEntityPosition(ped, false)
	baggingcoke = false
end
local powderZones, cuttingZones, baggingZones = {}, {}, {}

local function clearPowderZones()
    for _, id in ipairs(powderZones) do
        pcall(function() exports.qbtarget:removeZone(id) end)
    end
    powderZones = {}
end

local function clearCuttingZones()
    for id, d in ipairs(cuttingZones) do
        pcall(function() exports.qbtarget:removeZone(d) end)
    end
    cuttingZones = {}
end

local function clearBaggingZones()
    for id, d in ipairs(baggingZones) do
        pcall(function() exports.qbtarget:removeZone(d) end)
    end
    baggingZones = {}
end


local function buildPowder(entry)
    clearPowderZones()
    local recipe = Config.Cocaine.steps.powdering.recipe
    local powData = entry.data
    for key, data in ipairs(entry.locations) do
        powderZones[#powderZones + 1] = exports.qbtarget:addBoxZone({
            coords = vector3(data.coords.x, data.coords.y, data.coords.z),
            size = vector3(2, 2, 2),
            options = {
                {
                    label = entry.data.targetLabel or QB.lang('Cocaine.powder.target'),
                    icon = QB.lang('Cocaine.powder.icon'),
                    onSelect = function()
                        progressTrigger(recipe, powData, 'qb-drugs:server:powderCocaine', key)
                    end,
                }
            }
        })
    end
end

local function buildCutCoke(entry)
    clearCuttingZones()
    if not entry or not entry.locations or not entry.locations.coords then return end
    local data = entry.locations
    local targ = entry.data
    cuttingZones[#cuttingZones + 1] = exports.qbtarget:addBoxZone({
        coords = entry.locations.coords,
        size = vector3(1.5, 1.5, 1.5),
        rotation = 180.0,
        distance = 2.0,
        options = {
            {
                label = targ.targetLabel or QB.lang('Cocaine.cut.target'),
                icon = targ.targetIcon or QB.lang('Cocaine.cut.icon'),
                onSelect = function()
                    if cuttingcoke or baggingcoke then return end
                    if not itemCheck(Config.Cocaine.steps.cutting.recipe) then return end
                    cutCoke(data.coords, data.offset, data.rotation)
                    TriggerServerEvent('qb-drugs:server:cutCocaine')
                end,
                canInteract = function()
                    local isCut, isBag = cuttingcoke, baggingcoke
                    if isCut or isBag then
                        return false
                    end
                    return true
                end
            }
        },
    })
end

local function buildBagCoke(entry)
    clearBaggingZones()
    if not entry or not entry.locations or not entry.locations.coords then return end
    local data = entry.locations
    local targ = entry.data
    baggingZones[#baggingZones + 1] = exports.qbtarget:addBoxZone({
        coords = data.coords,
        size = vector3(1.5, 1.5, 1.5),
        rotation = 180.0,
        distance = 2.0,
        options = {
            {
                label = targ.targetLabel or QB.lang('Cocaine.bag.target'),
                icon = targ.targetIcon or QB.lang('Cocaine.bag.icon'),
                onSelect = function()
                    if cuttingcoke or baggingcoke then return end
                    if not itemCheck(Config.Cocaine.steps.bagging.recipe) then return end
                    bagCoke(data.coords, data.offset, data.rotation)
                    TriggerServerEvent('qb-drugs:server:bagCocaine')
                end,
                canInteract = function()
                    local isBag, isCut = baggingcoke, cuttingcoke
                    if isBag or isCut then
                        return false
                    end
                    return true
                end
            }
        },
    })
end

OnDrugs('Cocaine', 'lab', LabTeleport('cocaine', 'Cocaine'))
OnDrugs('Cocaine', 'powder', buildPowder)
OnDrugs('Cocaine', 'cutting', buildCutCoke)
OnDrugs('Cocaine', 'bagging', buildBagCoke)