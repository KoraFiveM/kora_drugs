-- Run from qbdrugs: lua test/legacy_dealers.lua. Exercises state and reward boundaries, not connected gameplay.
local function clone(value)
    if type(value) ~= 'table' then return value end
    local out = {}; for k,v in pairs(value) do out[k] = clone(v) end; return out
end
local encoded, nextEncoded = {}, 0
json = { encode = function(value) nextEncoded = nextEncoded + 1; encoded[tostring(nextEncoded)] = clone(value); return tostring(nextEncoded) end,
    decode = function(value) return clone(encoded[value]) end }
copyTable = clone
decodeJson = function(raw, fallback) return encoded[raw] and clone(encoded[raw]) or fallback end
inRange = function(v, minimum, maximum, whole) v = tonumber(v); if v and v == v and v >= minimum and v <= maximum then return whole and math.floor(v) or v end end
cleanVec = function(v) return type(v) == 'table' and v.x and v.y and v.z and v or nil end
cleanName = function(v) return type(v) == 'string' and v:match('^[%w _%-]+$') and v or nil end
local clock, near, bucket, admin = 1000, true, 0, false
local realTime = os.time; os.time = function() return clock end
GetCurrentResourceName = function() return 'kora_drugs' end
GetGameTimer = function() return clock * 1000 end
GetResourceState = function() return 'started' end
GetPlayerRoutingBucket = function() return bucket end
isNear = function() return near end
isAdmin = function() return admin end
GlobalState = { qbweathersync = { hour = 12 } }
GetPlayerPed = function(src) return src end
GetEntityCoords = function() return { x=1, y=2, z=3 } end
SetEntityCoords = function() end
local function read(path) local f=assert(io.open(path)); local s=f:read('*a'); f:close(); return s end
LoadResourceFile = function(_, path) return read(path) end
local handlers, callbacks, commands, registered, sent, hooks = {}, {}, {}, {}, {}, {}
RegisterNetEvent = function(name, fn) handlers[name] = fn end
AddEventHandler = RegisterNetEvent
TriggerClientEvent = function(...) sent[#sent+1] = {...} end
local data = { citizenid='A', metadata={rep={dealer=0}} }
local current = { PlayerData=data, Functions={GetRep=function() return data.metadata.rep.dealer end} }
local core = { Functions = { GetPlayer=function() return current end, GetDutyCount=function() return 0 end,
    CreateCallback=function(name, fn) callbacks[name]=fn end }, Commands={Add=function(name, _, _, _, fn) commands[name]=fn end} }
local mails = {}
local rosterRows = { { id=1, name='Test', coords=json.encode({x=1,y=2,z=3}), time=json.encode({min=0,max=23}) } }
local rows, receipts, items, cash, exchanges, failUpdate, exchangeFailure = {}, {}, {}, 0, 0, false, false
local function sql(query, args)
    args=args or {}
    if query:match('^CREATE TABLE') then return {} end
    if query == 'SELECT * FROM `dealers`' then return clone(rosterRows) end
    if query:match('^INSERT INTO `dealers`') then rosterRows[#rosterRows+1]={id=#rosterRows+1,name=args[1],coords=args[2],time=args[3],createdby=args[4]};return {} end
    if query:match('^DELETE FROM `dealers`') then for i,row in ipairs(rosterRows) do if row.id==args[1] then table.remove(rosterRows,i);break end end;return {} end
    if query:find('WHERE `id` = ?',1,true) and query:match('^SELECT') then
        local row=rows[args[1]]
        return row and row.citizenid==args[2] and row.status==args[3] and {clone(row)} or {}
    end
    if query:match('^SELECT %* FROM `qbdrugs_deliveries`') then
        for _, row in ipairs(rows) do if row.active_citizenid==args[1] then return {clone(row)} end end
        return {}
    end
    if query:match('^INSERT INTO `qbdrugs_deliveries`') then
        for _, row in ipairs(rows) do assert(row.active_citizenid ~= args[1], 'duplicate active CID') end
        rows[#rows+1]={id=#rows+1,citizenid=args[1],active_citizenid=args[2],status=args[3],data=args[4],created_at=args[5]}; return {}
    end
    if query:match('^UPDATE `qbdrugs_deliveries`') then
        if failUpdate then failUpdate=false; return nil,'simulated ack failure' end
        if query:find('`settlement`',1,true) then rows[args[3]].status=args[1]; rows[args[3]].settlement=args[2]
        elseif query:find('`completed_at`',1,true) then rows[args[3]].status=args[1]; rows[args[3]].active_citizenid=nil
        else rows[args[2]].status=args[1] end
        return {}
    end
    error('unexpected SQL '..query)
end
local inv = {
    CreateShop = function(_, spec) registered[spec.name]=spec; return spec.name end,
    GetInventory = function() return nil end,
    RegisterHook = function(_, name, fn) hooks[name]=fn end,
    OpenShop = function(_, src, name) assert(registered[name].access(src)) end,
    GetItemCount = function(_, _, name) return items[name] or 0 end,
    ExecutePlayerExchange = function(_, src, key, terms)
        assert(terms.citizenid==current.PlayerData.citizenid, 'source identity must match')
        if receipts[key] then return clone(receipts[key]) end
        if exchangeFailure then return nil,'capacity' end
        for _, item in ipairs(terms.take) do if (items[item.name] or 0)<item.amount then return nil,'missing_items' end end
        for _, item in ipairs(terms.take) do items[item.name]=items[item.name]-item.amount end
        for _, item in ipairs(terms.give) do items[item.name]=(items[item.name] or 0)+item.amount end
        cash=cash+terms.cash; data.metadata.rep.dealer=math.max(0,data.metadata.rep.dealer+terms.dealerRep)
        exchanges=exchanges+1; receipts[key]={citizenid=terms.citizenid,terms=clone(terms)}; return clone(receipts[key])
    end,
}
exports=setmetatable({ ['qb-core']={GetCoreObject=function() return core end}, ['qb-inventory']=inv, kora_inventory=inv, ['qb-phone']={sendNewMailToOffline=function(_,cid,mail) mails[#mails+1]={cid=cid,mail=mail} end} }, {
    __call=function(_, name, fn) registered[name]=fn end,
})
QB={sql={query=sql},compat={provideExport=function(_,name,fn) registered['legacy:'..name]=fn end},
    callback={register=function(name,fn) callbacks[name]=fn end},notify={send=function() end}}
dofile('shared/legacy_dealers.lua')
dofile('server/legacy_dealers.lua')
local total=0
local function check(value, label) assert(value, label); total=total+1 end
local begin=callbacks['qbdrugs:server:beginDelivery']; local settle=callbacks['qbdrugs:server:finishDelivery']; local resume=callbacks['qbdrugs:server:resumeDelivery']
check(registered.GetDealers().Test.products[1].name=='weed_whitewidow','real legacy roster')
local detached=registered.GetDealers(); detached.Test.coords.x=99
check(registered.GetDealers().Test.coords.x==1,'roster detached')
near=false; check(begin(1,'Test')==nil,'distant issue denied'); near=true
bucket=1; check(begin(1,'Test')==nil,'routing bucket denied'); bucket=0
GlobalState.qbweathersync.hour=nil; check(begin(1,'Test')==nil,'missing clock fails closed'); GlobalState.qbweathersync.hour=12
check(hooks.buyItem({shopId='qbdrugs-dealer-1',itemName='weed_skunk'},1)==false,'shop reputation enforced')
check(hooks.buyItem({shopId='qbdrugs-dealer-1',itemName='weed_whitewidow'},1)==true,'eligible shop item')
check(begin(1,{dealer='Test',item=1,amount=99,coords=LegacyDealerConfig.DeliveryLocations[1].coords})==nil,'legacy oversized quantity denied')
check(begin(1,{dealer='Test',item=1,amount=1,coords={x=999,y=999,z=999}})==nil,'legacy arbitrary destination denied')
local delivery=assert(begin(1,{dealer='Test',amount=999,itemData={item='cash',payout=999999},coords={x=999}}))
check(delivery.amount<=3 and delivery.itemData.payout==1000 and delivery.itemData.item~='cash','client cannot choose grant/pricing')
check(#rows==1 and exchanges==1,'persist and issue once')
check(#mails==1 and mails[1].cid=='A' and mails[1].mail.button.buttonEvent=='qb-drugs:client:setLocation','route mail addressed to authoritative citizen with one-use phone action')
local again=assert(begin(1,'Test')); check(again.id==delivery.id and exchanges==1,'duplicate issue resumes')
near=false; check(settle(1,{id=delivery.id})==nil,'distant settlement denied'); near=true
check(settle(1,{id=delivery.id+1})==nil,'wrong session denied')
local result=assert(settle(1,{id=delivery.id,payout=999999,inTime=true})); local paid=cash
check(result.cash==delivery.amount*1000 and cash==result.cash and data.metadata.rep.dealer==1,'server computes exact cash and reputation')
check(settle(1,{id=delivery.id}).completed and cash==paid,'completed session receipt replay cannot pay twice')
-- A DB acknowledgement may fail after inventory committed. Retrying the same durable exchange key must not grant twice.
failUpdate=true; check(begin(1,'Test')==nil,'issue acknowledgement failure exposed')
local afterIssue=exchanges; delivery=assert(resume(1)); check(exchanges==afterIssue and delivery.status=='issued','issue recovery reuses receipt')
failUpdate=true; check(settle(1,{id=delivery.id})==nil,'settlement snapshot failure grants nothing')
local beforeSettle=exchanges
local oldSql=QB.sql.query
QB.sql.query=function(query,args)
    if query:find('`completed_at`',1,true) then QB.sql.query=oldSql; return nil,'simulated completion ack failure' end
    return oldSql(query,args)
end
check(settle(1,{id=delivery.id})==nil and exchanges==beforeSettle+1,'completion ack failure after exactly one exchange')
paid=cash; result=assert(settle(1,{id=delivery.id})); check(cash==paid and exchanges==beforeSettle+1,'settlement replay cannot duplicate reward')
-- Late and short packages use server clock and actual held quantity, not caller flags.
delivery=assert(begin(1,'Test')); items[delivery.itemData.item]=math.max(0,delivery.amount-1); clock=clock+301
result=assert(settle(1,{id=delivery.id,inTime=true})); check(result.cash==math.floor(1000*(delivery.amount-1)/4) and result.dealerRep==-1,'server deadline and partial penalty')
LegacyDealerConfig.UseMarkedBills=true; delivery=assert(begin(1,{dealer='Test',item=1,amount=2,coords={x=223.980001,y=121.53,z=102.76},itemData={payout=999999}}));
check(delivery.item==1 and delivery.amount==2 and delivery.location.label=='Vinewood Video' and delivery.itemData.payout==1000,'valid legacy choice kept with canonical price'); result=assert(settle(1,{id=delivery.id}))
check(result.cash==0 and result.marked==delivery.amount*1000 and items.markedbills==1,'marked bills preserve worth metadata')
exchangeFailure=true; check(begin(1,'Test')==nil,'full inventory issue remains recoverable'); local prepared=#rows
exchangeFailure=false; delivery=assert(resume(1)); check(#rows==prepared and delivery.status=='issued','failed issue resumes same session')
-- Session is keyed by character, not recycled source number.
data.citizenid='B'; check(resume(1)==nil and settle(1,{id=delivery.id})==nil,'new character cannot claim old session'); data.citizenid='A'
handlers.onResourceStop('kora_inventory'); check(registered['qbdrugs-dealer-1'].access(1)==false and resume(1)==nil,'dependency stop closes policy')
handlers['qbinventory:server:ready'](); check(registered['qbdrugs-dealer-1'].access(1)==true,'ready event restores policy')
commands.newdealer(1,{'Denied',0,23});check(#rosterRows==1,'nonadmin roster mutation denied')
admin=true;commands.newdealer(1,{'Added',0,23});check(#rosterRows==2 and registered.GetDealers().Added~=nil,'admin dealer persisted and published')
commands.newdealer(1,{'Added',0,23});check(#rosterRows==2,'duplicate admin dealer rejected')
commands.deletedealer(1,{'Added'});check(#rosterRows==1 and not registered.GetDealers().Added,'admin dealer deletion persisted')
os.time=realTime
print(('qbdrugs legacy dealers: %d checks passed'):format(total))
