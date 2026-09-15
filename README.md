# qb-drugs
Drugs Script For QB-Core
```lua
    { name = "baking_soda", label = "Baking soda", weight = 1000, type = "item", image = "baking_soda.png", unique = false, useable = false, shouldClose = true, description = "I can use this for cakes or maybe something else" },
    { name = "gram_bag", label = "Gram Bag", weight = 1, type = "item", image = "gram_bag.png", unique = false, useable = false, shouldClose = true, description = "A small bag containing a gram." },

    { name = "coca_leaf", label = "Coca leaf", weight = 1000, type = "item", image = "coca_leaf.png", unique = false, useable = false, shouldClose = true, description = "A plant that may give you a little rush when processed" },
    { name = "cocaine_baggy", label = "Cocaine baggy", weight = 1000, type = "item", image = "cocaine_baggy.png", unique = false, useable = false, shouldClose = true, description = "A 1g bag of cocaine" },
    { name = "coke_powder", label = "Coke powder", weight = 1000, type = "item", image = "coke_powder.png", unique = false, useable = false, shouldClose = true, description = "refined powder of the coca plant" },
    { name = "cut_coke", label = "Cut coke", weight = 1000, type = "item", image = "cut_coke.png", unique = false, useable = false, shouldClose = true, description = "cocaine ready to be bagged up" },

    { name = "crack_rock", label = "Crack Rock", weight = 1, type = "item", image = "crack_rock.png", unique = false, useable = false, shouldClose = true, description = "A small rock of crack." },
    { name = "crack_bag", label = "Bag of Crack", weight = 1, type = "item", image = "crack_bag.png", unique = false, useable = false, shouldClose = true, description = "A bag containing crack." },

    { name = "empty_vial", label = "Empty Vial", weight = 1, type = "item", image = "empty_vial.png", unique = false, useable = false, shouldClose = true, description = "An empty glass vial." },
    { name = "heroin_powder", label = "Heroin Powder", weight = 1, type = "item", image = "heroin_powder.png", unique = false, useable = false, shouldClose = true, description = "A small amount of heroin powder." },
    { name = "heroin_syringe", label = "Heroin Syringe", weight = 1, type = "item", image = "heroin_syringe.png", unique = false, useable = false, shouldClose = true, description = "A syringe containing heroin." },
    { name = "heroin_vial", label = "Heroin Vial", weight = 1, type = "item", image = "heroin_vial.png", unique = false, useable = false, shouldClose = true, description = "A vial containing heroin." },
    { name = "metal_spoon", label = "Metal Spoon", weight = 1, type = "item", image = "metal_spoon.png", unique = false, useable = false, shouldClose = true, description = "A small metal spoon." },
    { name = "poppy_resin", label = "Poppy Resin", weight = 1, type = "item", image = "poppy_resin.png", unique = false, useable = false, shouldClose = true, description = "Raw resin collected from poppies." },
    { name = "syringe", label = "Syringe", weight = 1, type = "item", image = "syringe.png", unique = false, useable = false, shouldClose = true, description = "A clean medical syringe." },

    { name = "ak47_1g", label = "AK47 1g", weight = 100, type = "item", image = "ak47_1g.png", unique = false, useable = false, shouldClose = true, description = "A sealed 1g bag of AK47 cannabis." },
    { name = "ak47_joint", label = "AK47 Joint", weight = 100, type = "item", image = "ak47_joint.png", unique = false, useable = true, shouldClose = true, description = "A hand-rolled joint containing AK47 cannabis." },
    { name = "ak47_weed", label = "AK47 Nug", weight = 100, type = "item", image = "ak47_weed.png", unique = false, useable = false, shouldClose = true, description = "A nug of dried AK47 cannabis." },
    { name = "amensia_weed", label = "Amensia Nug", weight = 100, type = "item", image = "amensia_weed.png", unique = false, useable = false, shouldClose = true, description = "A nug of dried Amensia cannabis." },
    { name = "amnesia_1g", label = "Amnesia 1g", weight = 100, type = "item", image = "amnesia_1g.png", unique = false, useable = false, shouldClose = true, description = "A sealed 1g bag of Amnesia cannabis." },
    { name = "amnesia_joint", label = "Amnesia Joint", weight = 100, type = "item", image = "amnesia_joint.png", unique = false, useable = true, shouldClose = true, description = "A hand-rolled joint containing Amnesia cannabis." },
    { name = "blue_dream_1g", label = "Blue Dream 1g", weight = 100, type = "item", image = "blue_dream_1g.png", unique = false, useable = false, shouldClose = true, description = "A sealed 1g bag of Blue Dream cannabis." },
    { name = "blue_dream_joint", label = "Blue Dream Joint", weight = 100, type = "item", image = "blue_dream_joint.png", unique = false, useable = true, shouldClose = true, description = "A hand-rolled joint containing Blue Dream cannabis." },
    { name = "blue_dream_weed", label = "Blue Dream Nug", weight = 100, type = "item", image = "blue_dream_weed.png", unique = false, useable = false, shouldClose = true, description = "A nug of dried Blue Dream cannabis." },
    { name = "dried_cola", label = "Dried Cola", weight = 100, type = "item", image = "dried_cola.png", unique = false, useable = false, shouldClose = true, description = "A dried cannabis cola ready for processing." },
    { name = "og_kush_1g", label = "OG Kush 1g", weight = 100, type = "item", image = "og_kush_1g.png", unique = false, useable = false, shouldClose = true, description = "A sealed 1g bag of OG Kush cannabis." },
    { name = "og_kush_joint", label = "OG Kush Joint", weight = 100, type = "item", image = "og_kush_joint.png", unique = false, useable = true, shouldClose = true, description = "A hand-rolled joint containing OG Kush cannabis." },
    { name = "og_kush_weed", label = "OG Kush Nug", weight = 100, type = "item", image = "og_kush_weed.png", unique = false, useable = false, shouldClose = true, description = "A nug of dried OG Kush cannabis." },
    { name = "purple_haze_1g", label = "Purple Haze 1g", weight = 100, type = "item", image = "purple_haze_1g.png", unique = false, useable = false, shouldClose = true, description = "A sealed 1g bag of Purple Haze cannabis." },
    { name = "purple_haze_joint", label = "Purple Haze Joint", weight = 100, type = "item", image = "purple_haze_joint.png", unique = false, useable = true, shouldClose = true, description = "A hand-rolled joint containing Purple Haze cannabis." },
    { name = "purple_haze_weed", label = "Purple Haze Nug", weight = 100, type = "item", image = "purple_haze_weed.png", unique = false, useable = false, shouldClose = true, description = "A nug of dried Purple Haze cannabis." },
    { name = "skunk_1g", label = "Skunk 1g", weight = 100, type = "item", image = "skunk_1g.png", unique = false, useable = false, shouldClose = true, description = "A sealed 1g bag of Skunk cannabis." },
    { name = "skunk_joint", label = "Skunk Joint", weight = 1000, type = "item", image = "skunk_joint.png", unique = false, useable = true, shouldClose = true, description = "A hand-rolled joint containing Skunk cannabis." },
    { name = "skunk_weed", label = "Skunk Nug", weight = 100, type = "item", image = "skunk_weed.png", unique = false, useable = false, shouldClose = true, description = "A nug of dried Skunk cannabis." },
    { name = "wet_cola", label = "Wet Cola", weight = 100, type = "item", image = "wet_cola.png", unique = false, useable = false, shouldClose = true, description = "A freshly harvested cannabis cola that has not been dried." },
    { name = "ephedrine", label = "Ephedrine", weight = 100, type = "item", image = "ephedrine.png", unique = false, useable = false, shouldClose = true, description = "Hmm toxic chemicals?" },
    { name = "acetone", label = "Acetone", weight = 100, type = "item", image = "acetone.png", unique = false, useable = false, shouldClose = true, description = "I use this to remove nail polish" },


```

# License

    QBCore Framework
    Copyright (C) 2021 Joshua Eger

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>
