local Busy = false

local function getItemLabel(item)
    local itemData = exports.qbcore:getShared('items', item)
    return itemData and itemData.label or item
end

function itemCheck(recipe)
    local missing = {}
    for _, v in pairs(recipe.give) do
        if not exports['qb-inventory']:HasItem(v.item, v.amount) then
            missing[#missing + 1] = {title = 'qb-drugs', message = 'You Need ' .. v.amount .. ' ' .. getItemLabel(v.item), type = 'error'}
        end
    end
    if #missing > 0 then
        for _, notify in pairs(missing) do
            QB.notify.send(notify)
        end
        return
    end
    return true
end


function returnBasicOption(step, event, key)
    return {
        {
            label = QB.lang(key .. '.target'),
            icon = QB.lang(key .. '.icon'),
            onSelect = function()
                if Busy then return end
                if not itemCheck(step.recipe) then return end
                Busy = true
                local progress = QB.progressbar.start({
                    label = QB.lang(key .. '.progress') or "Missing Text, IDK What youre doing",
                    duration = step.progress and step.progress.time or DefaultProgress.time,
                    disable = step.progress and step.progress.disable or DefaultProgress.disable,
                    anim = step.progress and step.progress.anim or DefaultProgress.anim
                })
                if progress then
                    TriggerServerEvent(event)
                end
                Busy = false
            end,
            canInteract = function()
                return not Busy
            end
        }
    }
end
function basicTarget(coords, rotation, step, event, key)
    exports.qbtarget:addBoxZone({
        coords = coords,
        size = vector3(2,2,2),
        rotation = rotation,
        options = returnBasicOption(step, event, key)
    })
end
