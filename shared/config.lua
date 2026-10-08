Config = {
    Cocaine = {
        plantTbl = {},
        steps = {
            powdering = {
                recipe = {
                    receive = {item = 'coke_powder', amount = 1 },
                    give = {
                        {item = 'coca_leaf', amount = 1}
                    }
                }
            },
            cutting = {
                recipe = {
                    receive = {item = 'cut_coke', amount = 1 },
                    give = {
                        {item = 'coke_powder', amount = 1},
                        {item = 'baking_soda', amount = 1}
                    }
                }
            },
            bagging = {
                recipe = {
                    receive = {item = 'cocaine_baggy', amount = 1 },
                    give = {
                        {item = 'cut_coke', amount = 1},
                        {item = 'gram_bag', amount = 1}
                    }
                }
            }
        }
    },
    Heroin = {
        plantTbl = {},
        steps = {
            drying = {
                recipe = {
                    receive = {item = 'heroin_powder', amount = 1},
                    give = {
                        {item = 'poppy_resin', amount = 1}
                    }
                }
            },
            vials = {
                recipe = {
                    receive = {item = 'heroin_vial', amount = 1},
                    give = {
                        {item = 'heroin_powder', amount = 1 },
                        {item = 'empty_vial', amount = 1},
                        {item = 'metal_spoon', amount = 1, keep = true}
                    }
                }
            },
            syringe = {
                recipe = {
                    receive = {item = 'heroin_syringe', amount = 1},
                    give = {
                        {item = 'heroin_vial', amount = 1 },
                        {item = 'syringe', amount = 1},
                    }
                }
            }
        }
    },
    Weed = {
        percents = {
            thc = { min = 10, max = 30 },
            cbd = { min = 5, max = 20 }
        },
        plantTbl = {},
        steps = {
            drying = {
                recipe = {
                    receive = {item = 'dried_cola', amount = 1},
                    give = {
                        {item = 'wet_cola', amount = 1}
                    }
                }
            },
        }
    },
    Crack = {
        steps = {
            cook = {
                recipe = {
                    receive = {item = 'crack_rock', amount = 1},
                    give = {
                        {item = 'cut_coke', amount = 1},
                        {item = 'baking_soda', amount = 1}
                    }
                }
            },
            bagging = {
                recipe = {
                    receive = {item = 'crack_bag', amount = 1},
                    give = {
                        {item = 'crack_rock', amount = 1},
                        {item = 'gram_bag',   amount = 1}
                    }
                }
            }
        }
    },
    Meth = {
        cook_recipe = {
            receive = {},
            give = {
                {item = 'ephedrine', amount = 1},
                {item = 'acetone', amount = 1},
                {item = 'gram_bag', amount = 5}
            }
        },
        bag_recipe = {
            receive = {item = 'meth_bag', amount = 5},
            give = {}
        },
    }
}


ProgressDisableOptions = {
    { value = 'move', label = 'Movement' },
    { value = 'combat', label = 'Combat' },
    { value = 'car', label = 'Vehicle (car)' },
    { value = 'vehicle', label = 'Vehicle (vehicle)' },
}

DefaultProgress = {
    time = 5000,
    anim = {dict = 'mp_arresting', clip = 'a_uncuff', flags = 17},
    disable = {move = true, combat = true, car = true}
}

Config = QB.config.adopt(Config)