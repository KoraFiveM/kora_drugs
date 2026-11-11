WeedPercents = {
    thc = { min = 10, max = 30 },
    cbd = { min = 5, max = 20 }
}

ProgressDisableOptions = {
    { value = 'move', label = 'Movement' },
    { value = 'combat', label = 'Combat' },
    { value = 'car', label = 'Vehicle (car)' },
    { value = 'vehicle', label = 'Vehicle (vehicle)' },
}

DefaultProgress = {
    time = 5000,
    anim = {dict = 'mp_arresting', clip = 'a_uncuff', flag = 17},
    disable = {move = true, combat = true, car = true}
}
