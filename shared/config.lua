
Config = {
    Cocaine = {
        model = 'prop_plant_01a',
        item = 'coca_leaf',
        respawnTime = 1,
        maxGive = 2,
        icon = 'marijuana',
        locations = {
            { coords = vector3(1474.25, -2643.87, 42.88),  taken = false },
            { coords = vector3(1472.35, -2649.3, 41.87),    taken = false }, 
            { coords = vector3(1475.7, -2652.9, 40.8),      taken = false }, 
            { coords = vector3(1481.0, -2654.99, 39.86),    taken = false }, 
            { coords = vector3(1480.9, -2660.63, 38.68),    taken = false },
            { coords = vector3(1477.18, -2666.53, 38.19),   taken = false },
            { coords = vector3(1477.58, -2670.82, 37.73),   taken = false },
            { coords = vector3(1476.56, -2675.82, 37.46),   taken = false },
            { coords = vector3(1474.8, -2680.19, 37.03),    taken = false },
            { coords = vector3(1471.52, -2685.0, 36.82),    taken = false },
            { coords = vector3(1462.82, -2676.58, 38.83),   taken = false },
            { coords = vector3(1461.31, -2667.74, 39.67),   taken = false },
            { coords = vector3(1456.3, -2647.61, 43.39),    taken = false },
            { coords = vector3(1453.65, -2641.56, 45.0),    taken = false },
        },
        pickingData = {
            targetLabel = 'Pick Coca Leafs',
            targetIcon = 'marijuana',
            progressLabel = 'Picking Coca Leafs',
            progressTime = 5000,
            progressAnim = {dict = 'mp_arresting', clip = 'a_uncuff', flags = 17},
            progressDisable = {move = true, combat = true, car = true}
        },
        plantTbl = {},
        steps = {
            enterLab = {
                coords = vector3(743.89, -1905.91, 29.41),
                targetLabel = 'Enter Lab',
                targetIcon = 'marijuana',
            },
            exitLab = {
                coords = vector3(1088.81, -3187.57, -38.99),
                targetLabel = 'Exit Lab',
                targetIcon = 'marijuana',
            },
            powdering = {
                coords = vector3(1086.38, -3195.24, -39.5),
                targetLabel = 'Break Down Coca',
                targetIcon = 'marijuana',
                progressLabel = 'Breaking Down Coca Leaves',
                recipe = {
                    receive = {item = 'coke_powder', amount = 1 },
                    give = {
                        {item = 'coca_leaf', amount = 1}
                    }
                }
            },
            cutting = {
                coords = vector3(1095.61, -3195.62, -39.13),
                offset = vec3(-1.782227, 0.445068, -0.502701),
                rotation = vector3(0,0,0),
                targetLabel = 'Cut Cocaine',
                targetIcon = 'marijuana',
                progressLabel = 'Cutting Cocaine',
                recipe = {
                    receive = {item = 'cut_coke', amount = 1 },
                    give = {
                        {item = 'coke_powder', amount = 1},
                        {item = 'baking_soda', amount = 1}
                    }
                }
            },
            bagging = {
                coords = vector3(1093.16, -3195.78, -39.19),
                offset = vec3(4.515137, 2.542969, -0.814194),
                rotation = vector3(0,0,180.0),
                targetLabel = 'Bag Cocaine',
                targetIcon = 'marijuana',
                progressLabel = 'Bagging Cocaine',
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
        model = 'prop_plant_01b',
        item = 'poppy_resin',
        respawnTime = 1,
        maxGive = 2,
        icon = 'heroin',
        locations = {
            { coords = vector3(-2251.3, -99.18, 100.11), taken = false},
            { coords = vector3(-2249.63, -92.97, 101.8), taken = false},
            { coords = vector3(-2245.57, -85.12, 104.5), taken = false},
            { coords = vector3(-2240.81, -88.48, 105.88),taken = false},
            { coords = vector3(-2240.87, -93.36, 103.88),taken = false},
            { coords = vector3(-2236.0, -95.34, 102.55), taken = false},
            { coords = vector3(-2240.6, -100.01, 100.49),taken = false},
            { coords = vector3(-2246.29, -104.92, 99.27),taken = false},
            { coords = vector3(-2243.64, -107.99, 96.71),taken = false},
            { coords = vector3(-2254.22, -108.76, 97.25),taken = false},
            { coords = vector3(-2247.33, -108.92, 97.70),taken = false},
            { coords = vector3(-2250.96, -111.22, 97.50),taken = false},
            { coords = vector3(465.95, -1021.32, 31.78), taken = false},
        },
        pickingData = {
            targetLabel = 'Pick Poppies',
            targetIcon = 'heroin',
            progressLabel = 'Picking Poppies',
        },
        plantTbl = {},
        steps = {
            drying = {
                coords = vector3(1389.8, 3608.72, 38.94),
                targetLabel = 'Dry Poppies',
                targetIcon = 'heroin',
                progressLabel = 'Drying Poppies',
                recipe = {
                    receive = {item = 'heroin_powder', amount = 1},
                    give = {
                        {item = 'poppy_resin', amount = 1}
                    }
                }
            },
            vials = {
                coords = vector3(1391.86, 3605.92, 38.94),
                targetLabel = 'Make Heroin Vials',
                targetIcon = 'heroin',
                progressLabel = 'Making Heroin Vials',
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
                coords = vector3(1389.68, 3603.54, 38.92),
                targetLabel = 'Make Heroin Syringe',
                targetIcon = 'heroin',
                progressLabel = 'Making Heroin Syringe',
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
        model = 'bkr_prop_weed_lrg_01b',
        item = 'wet_cola',
        respawnTime = 1,
        maxGive = 2,
        icon = 'weed',
        locations = {
            { coords = vector3(-2176.29, 5216.6, 18.03), taken = false },
            { coords = vector3(-2177.4, 5221.56, 18.33), taken = false },
            { coords = vector3(-2181.86, 5220.79, 19.65), taken = false },
            { coords = vector3(-2187.78, 5224.84, 19.88), taken = false },
            { coords = vector3(-2190.08, 5230.31, 19.81), taken = false },
            { coords = vector3(-2185.22, 5213.29, 19.03), taken = false }
        },
        percents = {
            thc = { min = 10, max = 30 },
            cbd = { min = 5, max = 20 }
        },
        pickingData = {
            targetLabel = 'Pick Weed',
            targetIcon = 'weed',
            progressLabel = 'Picking Weed',
        },
        plantTbl = {},
        steps = {
            enterLab = {
                coords = vector3(861.59, 2174.34, 52.28),
                targetLabel = 'Enter Lab',
                targetIcon = 'marijuana',
            },
            exitLab = {
                coords = vector3(1066.4, -3183.36, -39.16),
                targetLabel = 'Exit Lab',
                targetIcon = 'marijuana',
            },
            drying = {
                coords = vector3(1035.85, -3203.81, -38.17),
                targetLabel = 'Dry Weed',
                targetIcon = 'weed',
                progressLabel = 'Drying Weed',
                recipe = {
                    receive = {item = 'dried_cola', amount = 1},
                    give = {
                        {item = 'wet_cola', amount = 1}
                    }
                }
            },
            breakNugs = {
                coords = vector3(1037.52, -3205.36, -38.17),
                targetLabel = 'Break Nugs',
                targetIcon = 'weed',
                progressLabel = 'Breaking Nugs',
            },
            bagWeed = {
                coords = vector3(1033.93, -3203.72, -38.18),
                targetLabel = 'Bag Weed',
                targetIcon = 'weed',
                progressLabel = 'Bagging Weed',
            }
        }
    }
}
DrugConfig = {
    Crack = {
        steps = {
            cook = {
                prop = 'v_ret_ml_tablea',
                coords = vector4(30.02, 3664.79, 40.20, 241.54),
                targetLabel = 'Cook Crack',
                targetIcon = 'fa-solid fa-tempature-high',
                progressLabel = 'Cooking Crack',
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
                targetLabel = 'Bag Crack',
                targetIcon = 'crack',
                progressLabel = 'Bagging Crack',
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
            Tele = {
                outside = vector3(981.07, -1805.58, 35.80),
                inside = vector3(996.91, -3200.83, -36.39),
                targetLabelIn = 'Exit Lab',
                targetLabelOut = 'Enter Lab',
                targetIconIn = 'fa-solid fa-arrow-right',
                targetIconOut = 'fa-solid fa-arrow-left',
            },
            Pour = {
                coords = vector3(1006.09, -3200.59, -38.52),
                offset = vec3(4.79, 2.13, -0.41),
                rotation = vec3(0.0, 0.0, 0.0),
                targetLabel = 'Pour Chemicals',
                targetIcon = 'fa-solid fa-flask',
                trayLabel = 'Grab Tray',
                trayIcon = 'fa-solid fa-hand-paper',
            },
            Heat = {
                coords = vector3(1007.89, -3201.17, -38.99),
                explosion = true,
                targetLabel = 'Heat Chemicals',
                targetIcon = 'fa-solid fa-fire',
            },
            Smash = {
                coords = vector3(1012.04, -3194.96, -38.99),
                bucket = vector4(1012.86, -3194.13, -39.20, 90.00),
                size = vector3(1.0, 1.0, 2.0),
                offset = vec3(-3.143311, -1.666748, -1.010128),
                rotation = vector3(0,0,0.0),
                targetLabel = 'Smash Meth',
                targetIcon = 'fa-solid fa-hammer',
            },
            Bag = {
                coords =  vector3(1014.25, -3194.93, -38.99),
                size = vector3(1.0, 1.0, 2.0),
                offset = vec3(-4.9, -1.70, -1.01),
                rotation = vector3(0,0,0.0),
                targetLabel = 'Bag Meth',
                targetIcon = 'fa-solid fa-bag-shopping',
            }
        }
    }
}

CornerSelling = {
    maxSell = 15, -- Maximum amount of drugs that can be sold at the corner at once
    ripOff = 0.2, -- Percentage of the price that the player gets ripped off when selling at the corner
    minPolice = 0, -- Minimum number of police required for corner selling
    weedPercentAdjustable = true, -- Whether the percentage of THC and CBD makes a difference on price
    weedPercentFlow = 0.2, -- the amount the price is affected by the THC and CBD percentage (e.g., 0.2 means a 20% change up or down)
    pricing = { -- Item | Price in cash 
        cocaine_baggy = 20,
        crack_bag = 15,
        heroin_vial = 20,
        ak47_1g = 15,
        amnesia_1g = 15,
        og_kush_1g = 15,
        blue_dream_1g = 15,
        purple_haze_1g = 15,
        skunk_1g = 15,
        ak47_joint = 20,
        amnesia_joint = 20,
        og_kush_joint = 20,
        blue_dream_joint = 20,
        purple_haze_joint = 20,
        skunk_joint = 20,
        white_widow_joint = 20
    }
}

DefaultProgress = {
    progressTime = 5000,
    progressAnim = {dict = 'mp_arresting', clip = 'a_uncuff', flags = 17},
    progressDisable = {move = true, combat = true, car = true}
}

-- DrugConfig and DefaultProgress are public legacy configuration tables.
-- Keep their aliases intact while registering their authored values with the
-- resource-owned qblib configuration bridge.
Config.DrugConfig = DrugConfig
Config.DefaultProgress = DefaultProgress
Config = QB.config.adopt(Config)
