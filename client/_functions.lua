local notifyIngridents = {}
local items = exports['qb-core']:GetShared('Items')
local Busy = false
local function getItemLabel(item)
    return items[item] and items[item].label or item
end

function itemCheck(recipe)
    local need, has = 0, 0
    for k, v in pairs(recipe.give) do
        if exports['qb-inventory']:HasItem(v.item, v.amount) then
            has = has + 1
        else
            table.insert(notifyIngridents, {title = 'qb-drugs', message = 'You Need ' .. v.amount .. ' ' .. getItemLabel(v.item), type = 'error'})
        end
        need = need + 1
    end
    if has ~= need then
        for _, notify in pairs(notifyIngridents) do
            QB.notify.send(notify)
        end
        notifyIngridents = {}
        return
    end
    return true
end


function returnBasicOption(step, event)
    return {
        {
            label = step.targetLabel,
            icon = step.targetIcon,
            onSelect = function()
                if Busy then return end
                if not itemCheck(step.recipe) then return end
                Busy = true
                local progress = QB.progressbar.start({
                    label = step.progressLabel or "Missing Text, IDK What youre doing",
                    duration = step.progressTime or Config.DefaultProgress.progressTime,
                    disable = step.progressDisable or Config.DefaultProgress.progressDisable,
                    anim = step.progressAnim or Config.DefaultProgress.progressAnim
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