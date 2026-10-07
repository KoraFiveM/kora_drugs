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
             exitLab = vector3(1066.4, -3183.36, -39.16),
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
                prop = 'v_ret_ml_tablea',
                coords = vector4(30.02, 3664.79, 40.20, 241.54),
                recipe = {
                    receive = {item = 'crack_rock', amount = 1},
                    give = {
                        {item = 'cut_coke', amount = 1},
                        {item = 'baking_soda', amount = 1}
                    }
                }
            },
            bagging = {
                prop = 'v_ret_ml_tablec',
                coords = vector4(24.8, 3662.6, 39.8, 241.27),
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
            give = {} -- reason nothing to give back, all ingredients are consumed in cook_recipe to ensure you dont get to the end without having completed the cookbook
        },
        Steps = { -- IF YOU DONT KNOW WHAT YOURE DOING DONT CHANGE THE COORDS FOR ANYTHING BESIDES TELE
            Pour = {
                coords = vector3(1006.09, -3200.59, -38.52),    
                offset = vec3(4.79, 2.13, -0.41),               
                rotation = vec3(0.0, 0.0, 0.0),                 
            },
            Heat = {
                coords = vector3(1007.89, -3201.17, -38.99),
                explosion = true,
            },
            Smash = {
                coords = vector3(1012.04, -3194.96, -38.99),
                bucket = vector4(1012.86, -3194.13, -39.20, 90.00),
                size = vector3(1.0, 1.0, 2.0),
                offset = vec3(-3.143311, -1.666748, -1.010128),
                rotation = vector3(0,0,0.0),
            },
            Bag = {
                coords =  vector3(1014.25, -3194.93, -38.99),
                size = vector3(1.0, 1.0, 2.0),
                offset = vec3(-4.9, -1.70, -1.01),
                rotation = vector3(0,0,0.0),
            }
        }
    }
}


ProgressDisableOptions = {
    { value = 'move', label = 'Movement' },
    { value = 'combat', label = 'Combat' },
    { value = 'car', label = 'Vehicle (car)' },
    { value = 'vehicle', label = 'Vehicle (vehicle)' },
}
