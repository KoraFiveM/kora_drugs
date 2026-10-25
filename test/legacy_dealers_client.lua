-- Plain Lua boundary/lifecycle checks; native target/progress UI still needs connected client testing.
local events, zones, calls, messages = {}, {}, {}, {}
local progress, activeResult, finishResult = true, nil, nil
local lastId=0
vector3=function(x,y,z) return {x=x,y=y,z=z} end
SetNewWaypoint=function() end
GetCurrentResourceName=function() return 'qbdrugs' end
LocalPlayer={state={isLoggedIn=false}}
RegisterNetEvent=function(name,fn) events[name]=fn end
AddEventHandler=RegisterNetEvent
CreateThread=function(fn) fn() end
TriggerServerEvent=function(...) calls[#calls+1]={...} end
local roster={ Test={coords={x=1,y=2,z=3}} }
local core={Functions={TriggerCallback=function(_,fn) fn(roster) end}}
exports={['qb-core']={GetCoreObject=function() return core end},qbtarget={
    addBoxZone=function(_,data) lastId=lastId+1;zones[lastId]=data;return lastId end,
    removeZone=function(_,id) zones[id]=nil end,
}}
QB={notify={send=function(data) messages[#messages+1]=data end},progressbar={start=function() if progress=='error' then error('progress failed') end; return progress end},
    callback={trigger=function(name,data) calls[#calls+1]={name,data};return name:find('finish',1,true) and finishResult or activeResult end}}
dofile('client/legacy_dealers.lua')
local checks=0
local function check(value,label) assert(value,label);checks=checks+1 end
local delivery={id=1,amount=2,itemData={item='weed_brick'},location={label='Taxi',coords={x=10,y=20,z=30}}}
source=1;events['qbdrugs:client:delivery'](delivery);check(next(zones)==nil,'local event cannot create authorized delivery UI')
source=65535;events['qbdrugs:client:delivery'](delivery);check(zones[1]~=nil,'server delivery creates target')
progress=false;zones[1].options[1].onSelect();check(#calls==0 and zones[1]~=nil,'cancel keeps delivery and sends no settlement')
progress='error';zones[1].options[1].onSelect();check(zones[1]~=nil,'progress error retains retryable delivery')
progress=true;finishResult={completed=true,id=1,cash=2000,dealerRep=1};zones[1].options[1].onSelect()
check(next(zones)==nil and calls[1][1]=='qbdrugs:server:finishDelivery' and calls[1][2].id==1,'finish sends session ID and clears only on success')
activeResult=delivery;events['QBCore:Client:OnPlayerLoaded']();check(zones[lastId]~=nil,'login resumes server active route')
events['QBCore:Client:OnPlayerUnload']();check(next(zones)==nil,'logout removes targets')
events['QBCore:Client:OnPlayerLoaded']();events.onResourceStop('qbdrugs');check(next(zones)==nil,'stop removes targets')
print(('qbdrugs dealer client: %d checks passed'):format(checks))
