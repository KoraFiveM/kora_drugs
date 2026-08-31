if Config and Config.Cocaine and Config.Cocaine.disabled then
    print("Cocaine plants are disabled")
    return
end

local function SetStage()
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

SetStage()
local cuttingcoke = false
local baggingcoke = false

local function CutCoke(coords, offset, rotation)
	cuttingcoke = true
	local animDict, animName = "anim@amb@business@coc@coc_unpack_cut_left@", "coke_cut_v5_coccutter"
	QB.stream.loadAnimDict(animDict)
	local animDuration = GetAnimDuration(animDict, animName) * 1000
	local ped = PlayerPedId()
	local scenePos, sceneRot = vector3(coords.x + offset.x, coords.y + offset.y,coords.z + offset.z), rotation
	local scenes = {
	{
		{	hash = "bkr_prop_coke_bakingsoda_o",	animName = "coke_cut_v5_bakingsoda"},
		{	hash = "prop_cs_credit_card",	animName = "coke_cut_v5_creditcard"},
		{	hash = "prop_cs_credit_card",	animName = "coke_cut_v5_creditcard^1"}
	},
}
	local scenesList, entitiesList = {}, {}
	for i=1, #scenes, 1 do
		local scene = NetworkCreateSynchronisedScene(scenePos, sceneRot, 2, false, false, 1065353216, 0, 1.3)
		NetworkAddPedToSynchronisedScene(ped, scene, animDict, animName, 1.5, -4.0, 1, 16, 1148846080, 0)
		for j=1, #scenes[i], 1 do
			local s = scenes[i][j]
			QB.stream.loadModel(s.hash)
			local obj = CreateObjectNoOffset(s.hash, coords, true, true, true)
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
	cuttingcoke = false
end

local function BagCoke(coords, offset, rotation)
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
    	local scene = NetworkCreateSynchronisedScene(scenePos, sceneRot, 2, false, false, 1065353216, 0, 1.3)
    	NetworkAddPedToSynchronisedScene(ped, scene, animDict, animName, 1.5, -4.0, 1, 16, 1148846080, 0)
    	for j=1, #scenes[i], 1 do
    		local s = scenes[i][j]
            QB.stream.loadModel(s.hash)
    		local obj = CreateObjectNoOffset(s.hash, coords, true, true, true)
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

local function returnTele(lab, coords)
    return {
        {
            label = lab.targetLabel,
            icon = lab.targetIcon,
            onSelect = function()
                QB.visuals.fade(coords, 500)
            end
        }
    }
end
if Config.Cocaine and Config.Cocaine.steps then
    local step = Config.Cocaine.steps
    if step.enterLab then
        local lab = Config.Cocaine.steps.enterLab
        exports.qbtarget:addBoxZone({
            coords = lab.coords,
            size = vector3(1.5, 1.5, 1.5),
            rotation = 180.0,
            distance = 2.0,
            options = returnTele(lab, step.exitLab.coords),
        })
    end
    if step.exitLab then
        local lab = step.exitLab
        exports.qbtarget:addBoxZone({
            coords = lab.coords,
            size = vector3(1.5, 1.5, 1.5),
            rotation = 180.0,
            distance = 2.0,
            options = returnTele(lab, step.enterLab.coords),
        })
    end
    if step.powdering then
        local data = step.powdering
         exports.qbtarget:addBoxZone({
            coords = data.coords,
            size = vector3(1.5, 1.5, 1.5),
            rotation = 180.0,
            distance = 2.0,
            options = returnBasicOption(data, "qb-drugs:server:powderCocaine")
        })
    end
    if step.cutting then
        local data = step.cutting
        exports.qbtarget:addBoxZone({
            coords = data.coords,
            size = vector3(1.5, 1.5, 1.5),
            rotation = 180.0,
            distance = 2.0,
            options = {
                {
                    label = data.targetLabel,
                    icon = data.targetIcon,
                    onSelect = function()
                        if cuttingcoke or baggingcoke then return end
                        if not itemCheck(data.recipe) then return end
                        CutCoke(data.coords, data.offset, data.rotation)
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
    if step.bagging then
        exports.qbtarget:addBoxZone({
            coords = step.bagging.coords,
            size = vector3(1.5, 1.5, 1.5),
            rotation = 180.0,
            distance = 2.0,
            options = {
                {
                    label = step.bagging.targetLabel,
                    icon = step.bagging.targetIcon,
                    onSelect = function()
                        if baggingcoke or cuttingcoke then return end
                        if not itemCheck(step.bagging.recipe) then return end
                        BagCoke(step.bagging.coords, step.bagging.offset, step.bagging.rotation)
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
end