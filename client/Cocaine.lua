
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
local function cutCoke(coords, offset, rotation)
    local animDict, animName = "anim@amb@business@coc@coc_unpack_cut_left@", "coke_cut_v5_coccutter"
    Kora.stream.loadAnimDict(animDict)

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
            Kora.stream.loadModel(s.hash)
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
end

local function bagCoke(coords, offset, rotation)
    local ver = ""
	local animDict, animName = "anim@amb@business@meth@meth_smash_weight_check@", "break_weigh_"..ver.."char01"
	Kora.stream.loadAnimDict(animDict)
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
            Kora.stream.loadModel(s.hash)
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
end
stepHooks['Cocaine:cutting'] = {
    run = function(_, location)
        cutCoke(location.coords, location.offset, location.rotation)
        return true
    end,
}

stepHooks['Cocaine:bagging'] = {
    run = function(_, location)
        bagCoke(location.coords, location.offset, location.rotation)
        return true
    end,
}

OnDrugs('Cocaine', 'lab', LabTeleport('cocaine', 'Cocaine'))