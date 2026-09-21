local config = DrugConfig.Meth
local step   = config.Steps

local stage = {
	idle    = 0, -- nothing started
	poured  = 1, -- chemicals in, cooker running
	heated  = 2, -- dials passed
	trayed  = 3, -- carrying the tray
	smashed = 4, -- tray smashed, bucket spawned
}

local state = {
	stage = stage.idle,
	busy  = false, -- an animation/callback is mid-flight
}

local trayObject   = nil
local bucketObject = nil

local sceneFlagStart = 1065353216
local sceneFlagAnim  = 1148846080
local defaultSize    = vector3(1.0, 1.0, 1.0)
local defaultHeading = 180.0
local defaultOffset  = vec3(0.0, 0.0, 0.0)
local defaultRot     = vector3(0.0, 0.0, 180.0)
local carryDict = 'anim@heists@box_carry@'
local cookDict  = 'anim@amb@business@meth@meth_monitoring_cooking@cooking@'
local smashDict = 'anim@amb@business@meth@meth_smash_weight_check@'

local function notify(message, type)
	QB.notify.send({ title = 'qb-drugs', message = message, type = type })
end

local function atStage(required)
	return state.stage == required and not state.busy
end

local function runStep(required, action)
	if not atStage(required) then return end
	state.busy = true

	local ok = action()
	if ok then state.stage = required + 1 end

	state.busy = false
end

local function resetCook()
	state.stage = stage.idle
	state.busy  = false

	if trayObject then
		DeleteEntity(trayObject)
		trayObject = nil
	end
	RemoveAnimDict(carryDict)
	if bucketObject then
		exports.qbtarget:removeEntity(bucketObject)
		DeleteEntity(bucketObject)
		bucketObject = nil
	end
end

local function spawnProp(hash, coords)
	QB.stream.loadModel(hash)
	local obj = CreateObjectNoOffset(hash, coords, true, true, true)
	SetModelAsNoLongerNeeded(hash)
	return obj
end

local function buildPropScene(ped, animDict, pedAnimName, scenePos, sceneRot, propDefs, propCoords)
	local scene = NetworkCreateSynchronisedScene(scenePos, sceneRot, 2, false, false, sceneFlagStart, 0, 1.3)
	NetworkAddPedToSynchronisedScene(ped, scene, animDict, pedAnimName, 1.5, -4.0, 1, 16, sceneFlagAnim, 0)

	local props = {}
	for _, def in ipairs(propDefs) do
		local obj = spawnProp(def.hash, propCoords)
		NetworkAddEntityToSynchronisedScene(obj, scene, animDict, def.animName, 4.0, -8.0, 1)
		props[#props + 1] = obj
	end

	return scene, props
end

local function deleteAll(entities)
	for _, obj in ipairs(entities) do
		DeleteEntity(obj)
	end
end

local function sceneOrigin(coords, offset)
	offset = offset or defaultOffset
	return vector3(coords.x + offset.x, coords.y + offset.y, coords.z + offset.z)
end

local function runScene(opts)
	local ped = PlayerPedId()

	QB.stream.loadAnimDict(opts.animDict)
	SetEntityCoords(ped, opts.coords)
	Wait(1)
	FreezeEntityPosition(ped, true)

	local duration = GetAnimDuration(opts.animDict, opts.animName) * (opts.durationScale or 800)
	local scene, props = buildPropScene(
		ped, opts.animDict, opts.animName,
		sceneOrigin(opts.coords, opts.offset), opts.rotation or defaultRot,
		opts.props, opts.propCoords or opts.coords
	)

	NetworkStartSynchronisedScene(scene)
	Wait(duration)
	NetworkStopSynchronisedScene(scene)

	deleteAll(props)
	RemoveAnimDict(opts.animDict)
	FreezeEntityPosition(ped, false)
end

local function addStepZone(cfg, options)
	exports.qbtarget:addBoxZone({
		coords   = cfg.coords,
		size     = cfg.size or defaultSize,
		rotation = cfg.heading or defaultHeading,
		options  = options,
	})
end


local pourProps = {
	{ hash = "bkr_prop_meth_sacid",   animName = "chemical_pour_short_sacid" },
	{ hash = "bkr_prop_meth_ammonia", animName = "chemical_pour_short_ammonia" },
}

local smashProps = {
	{ hash = "w_me_hammer",                        animName = "break_weigh_hammer" },
	{ hash = "bkr_Prop_Meth_SmashedTray_01_frag_", animName = "break_weigh_tray01" },
	{ hash = "bkr_Prop_Meth_Tray_02a",             animName = "break_weigh_tray01^1" },
	{ hash = "bkr_Prop_Meth_Tray_02a",             animName = "break_weigh_tray01^2" },
	{ hash = "bkr_Prop_Meth_SmashedTray_01_frag_", animName = "break_weigh_tray01^3" },
}

local bagPropGroups = {
	{
		{ hash = "bkr_prop_meth_bigbag_04a", animName = "break_weigh_box01" },
		{ hash = "bkr_prop_meth_bigbag_03a", animName = "break_weigh_box01^1" },
		{ hash = "bkr_prop_meth_openbag_02", animName = "break_weigh_methbag01" },
	},
	{
		{ hash = "bkr_prop_meth_openbag_02", animName = "break_weigh_methbag01^1" },
		{ hash = "bkr_prop_meth_openbag_02", animName = "break_weigh_methbag01^2" },
		{ hash = "bkr_prop_meth_openbag_02", animName = "break_weigh_methbag01^3" },
	},
	{
		{ hash = "bkr_prop_meth_openbag_02", animName = "break_weigh_methbag01^4" },
		{ hash = "bkr_prop_meth_openbag_02", animName = "break_weigh_methbag01^5" },
		{ hash = "bkr_prop_meth_openbag_02", animName = "break_weigh_methbag01^6" },
	},
	{
		{ hash = "bkr_prop_meth_scoop_01a",      animName = "break_weigh_scoop" },
		{ hash = "bkr_prop_coke_scale_01",       animName = "break_weigh_scale" },
		{ hash = "bkr_prop_fakeid_penclipboard", animName = "break_weigh_pen" },
	},
	{
		{ hash = "bkr_prop_fakeid_clipboard_01a", animName = "break_weigh_clipboard" },
		{ hash = "bkr_Prop_Meth_Tray_02a",        animName = "break_weigh_tray01^5" },
	},
}
local function loadParticle(dict)
    if not HasNamedPtfxAssetLoaded(dict) then
        RequestNamedPtfxAsset(dict)
    end
    while not HasNamedPtfxAssetLoaded(dict) do
        Wait(0)
    end
    SetPtfxAssetNextCall(dict)
end

local function heatingMeth(coords)
	QB.stream.loadModel('hei_prop_heist_thermite')
	loadParticle('scr_ornate_heist')
	local thermite = CreateObject('hei_prop_heist_thermite', coords.x - 0.5, coords.y - 0.5, coords.z -0.5, true, false, false)
	SetModelAsNoLongerNeeded(`hei_prop_heist_thermite`)
	FreezeEntityPosition(thermite, true)
	SetEntityVisible(thermite, false)
	Wait(1000)
	local therm = StartParticleFxLoopedOnEntity('scr_heist_ornate_thermal_burn', thermite, 0.0, 1.4, 0.0, 0.0, 0.0, 0.0, 1.5, false, false, false)
	Wait(math.random(10000, 20000))
	StopParticleFxLooped(therm, true)
	DeleteObject(thermite)
	RemoveNamedPtfxAsset('scr_ornate_heist')
end

local function methCooking(coords, offset, rotation)
	runScene({
		animDict = cookDict,
		animName = "chemical_pour_short_cooker",
		coords   = coords,
		offset   = offset,
		rotation = rotation,
		props    = pourProps,
	})
end

local function smashMeth(coords, offset, rotation)
	runScene({
		animDict = smashDict,
		animName = "break_weigh_char02",
		coords   = coords,
		offset   = offset,
		rotation = rotation,
		props    = smashProps,
	})
end

local function bagMeth(coords, offset, rotation)
	local animName = "break_weigh_char01"
	local ped = PlayerPedId()

	QB.stream.loadAnimDict(smashDict)
	SetEntityCoords(ped, coords)

	local duration = GetAnimDuration(smashDict, animName) * 1000
	local scenePos = sceneOrigin(coords, offset)
	local scenes, props = {}, {}

	for _, group in ipairs(bagPropGroups) do
		local scene, groupProps = buildPropScene(ped, smashDict, animName, scenePos, rotation or defaultRot, group, coords)
		scenes[#scenes + 1] = scene
		for _, obj in ipairs(groupProps) do
			props[#props + 1] = obj
		end
	end

	DisableCamCollisionForEntity(ped)
	FreezeEntityPosition(ped, true)

	for _, scene in ipairs(scenes) do NetworkStartSynchronisedScene(scene) end
	Wait(duration - 11000)
	for _, scene in ipairs(scenes) do NetworkStopSynchronisedScene(scene) end

	deleteAll(props)
	RemoveAnimDict(smashDict)
	FreezeEntityPosition(ped, false)
end


-- ----------------------------------------------------------------------------

local function startCook(coords, offset, rotation)
	if not QB.callback.trigger('qb-drugs:server:startCook') then return false end
	methCooking(coords, offset, rotation)
	return true
end

local function runDials(coords)
	if not exports['qb-minigames']:Lockpick() then
		if step.Heat.explosion then
			AddExplosion(coords.x, coords.y, coords.z, 49, 10, true, false, true)
		end
		TriggerServerEvent('qb-drugs:server:explosion')
		resetCook()
		return false
	end

	if not QB.callback.trigger('qb-drugs:server:runDials') then
		notify('Failed to run dials', 'error')
		resetCook()
		return false
	end

	heatingMeth(config.Steps.Pour.coords)
	notify('You Have Heated the Meth', 'success')
	return true
end

local function pickUpTray()
	local ped = PlayerPedId()
	local pos = GetEntityCoords(ped, true)

	QB.stream.loadAnimDict(carryDict)
	TaskPlayAnim(ped, carryDict, 'idle', 5.0, -1, -1, 50, 0, false, false, false)

	trayObject = spawnProp('bkr_prop_meth_tray_02a', pos)
	AttachEntityToEntity(trayObject, ped, GetPedBoneIndex(ped, 28422), 0.01, -0.2, -0.2, 20.0, 0.0, 0.0, true, true, false, true, 1, true)
	return true
end

local function bagUp()
	exports.qbtarget:removeEntity(bucketObject)
	DeleteEntity(bucketObject)
	bucketObject = nil

	bagMeth(step.Bag.coords, step.Bag.offset or defaultOffset, step.Bag.rotation or defaultRot)
	TriggerServerEvent('qb-drugs:server:getMeth')
	resetCook()
	return false
end

local function attachBucketTarget(bucket)
	exports.qbtarget:addEntity(bucket, {
		{
			label       = step.Bag.targetLabel,
			icon        = step.Bag.targetIcon,
			canInteract = function() return atStage(stage.smashed) end,
			onSelect    = function() runStep(stage.smashed, bagUp) end,
		},
	})
end

local function smash(coords, offset, rotation)
	if not QB.callback.trigger('qb-drugs:server:smash') then
		notify('You need to heat the meth first', 'error')
		return false
	end

	DeleteEntity(trayObject)
	trayObject = nil

	local bucketCoords = step.Smash.bucket
	bucketObject = CreateObject("bkr_prop_meth_bigbag_03a", bucketCoords.x, bucketCoords.y, bucketCoords.z, true, true, true)
	FreezeEntityPosition(bucketObject, true)
	SetEntityHeading(bucketObject, bucketCoords.w or defaultHeading)

	smashMeth(coords, offset, rotation)
	Wait(100)
	attachBucketTarget(bucketObject)
	return true
end



if step.Tele then
	addStepZone({ coords = step.Tele.outside, size = step.Tele.size, heading = step.Tele.heading }, {
		{
			label    = step.Tele.targetLabelOut,
			icon     = step.Tele.targetIconOut,
			onSelect = function() QB.visuals.fade(step.Tele.inside) end,
		},
	})
	addStepZone({ coords = step.Tele.inside, size = step.Tele.size, heading = step.Tele.heading }, {
		{
			label    = step.Tele.targetLabelIn,
			icon     = step.Tele.targetIconIn,
			onSelect = function() QB.visuals.fade(step.Tele.outside) end,
		},
	})
end

if step.Pour then
	addStepZone(step.Pour, {
		{
			label       = step.Pour.targetLabel,
			icon        = step.Pour.targetIcon,
			canInteract = function() return atStage(stage.idle) end,
			onSelect    = function()
				runStep(stage.idle, function()
					return startCook(step.Pour.coords, step.Pour.offset or defaultOffset, step.Pour.rotation or defaultRot)
				end)
			end,
		},
		{
			label       = step.Pour.trayLabel,
			icon        = step.Pour.trayIcon,
			canInteract = function() return atStage(stage.heated) end,
			onSelect    = function() runStep(stage.heated, pickUpTray) end,
		},
	})
end

if step.Heat then
	addStepZone(step.Heat, {
		{
			label       = step.Heat.targetLabel,
			icon        = step.Heat.targetIcon,
			canInteract = function() return atStage(stage.poured) end,
			onSelect    = function()
				runStep(stage.poured, function() return runDials(step.Heat.coords) end)
			end,
		},
	})
end

if step.Smash then
	addStepZone(step.Smash, {
		{
			label       = step.Smash.targetLabel,
			icon        = step.Smash.targetIcon,
			canInteract = function() return atStage(stage.trayed) end,
			onSelect    = function()
				runStep(stage.trayed, function()
					return smash(step.Smash.coords, step.Smash.offset or defaultOffset, step.Smash.rotation or defaultRot)
				end)
			end,
		},
	})
end


AddEventHandler('onResourceStop', function(resource)
	if resource ~= GetCurrentResourceName() then return end
	resetCook()
end)

CreateThread(function()
    if GetResourceState('bob74_ipl') ~= 'missing' then return end
    repeat Wait(100) until GetResourceState('bob74_ipl') == 'started'
	local lab = exports['bob74_ipl']:GetBikerMethLabObject()
	lab.Style.Set(lab.Style.upgrade)
	lab.Security.Set(lab.Security.upgrade)
	lab.Details.Enable(lab.Details.production, true)
	RefreshInterior(lab.interiorId)
end)
