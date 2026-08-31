# qb-drugs
Drugs Script For QB-Core
```lua
-- many drugs

baking_soda = { name = "baking_soda", label = "Baking soda", weight = 1000, type = "item", image = "baking_soda.png", unique = false, useable = false, shouldClose = true, description = "I can use this for cakes or maybe something else" },
gram_bag = { name = "gram_bag", label = "Gram Bag", weight = 1, type = "item", image = "gram_bag.png", unique = false, useable = false, shouldClose = true, description = "A small bag containing a gram." },
-- cocaine
coca_leaf = { name = "coca_leaf", label = "Coca leaf", weight = 1000, type = "item", image = "coca_leaf.png", unique = false, useable = false, shouldClose = true, description = "A plant that may give you a little rush when processed" },
cocaine_baggy = { name = "cocaine_baggy", label = "Cocaine baggy", weight = 1000, type = "item", image = "cocaine_baggy.png", unique = false, useable = false, shouldClose = true, description = "A 1g bag of cocaine" },
coke_powder = { name = "coke_powder", label = "Coke powder", weight = 1000, type = "item", image = "coke_powder.png", unique = false, useable = false, shouldClose = true, description = "refined powder of the coca plant" },
cut_coke = { name = "cut_coke", label = "Cut coke", weight = 1000, type = "item", image = "cut_coke.png", unique = false, useable = false, shouldClose = true, description = "cocaine ready to be bagged up" },

--- Crack
 crack_rock = { name = "crack_rock", label = "Crack Rock", weight = 1, type = "item", image = "crack_rock.png", unique = false, useable = false, shouldClose = true, description = "A small rock of crack." },
crack_bag = { name = "crack_bag", label = "Bag of Crack", weight = 1, type = "item", image = "crack_bag.png", unique = false, useable = false, shouldClose = true, description = "A bag containing crack." },

--- Heroin
 empty_vial = { name = "empty_vial", label = "Empty Vial", weight = 1, type = "item", image = "empty_vial.png", unique = false, useable = false, shouldClose = true, description = "An empty glass vial." },
heroin_powder = { name = "heroin_powder", label = "Heroin Powder", weight = 1, type = "item", image = "heroin_powder.png", unique = false, useable = false, shouldClose = true, description = "A small amount of heroin powder." },
heroin_syringe = { name = "heroin_syringe", label = "Heroin Syringe", weight = 1, type = "item", image = "heroin_syringe.png", unique = false, useable = false, shouldClose = true, description = "A syringe containing heroin." },
heroin_vial = { name = "heroin_vial", label = "Heroin Vial", weight = 1, type = "item", image = "heroin_vial.png", unique = false, useable = false, shouldClose = true, description = "A vial containing heroin." },
metal_spoon = { name = "metal_spoon", label = "Metal Spoon", weight = 1, type = "item", image = "metal_spoon.png", unique = false, useable = false, shouldClose = true, description = "A small metal spoon." },
poppy_resin = { name = "poppy_resin", label = "Poppy Resin", weight = 1, type = "item", image = "poppy_resin.png", unique = false, useable = false, shouldClose = true, description = "Raw resin collected from poppies." },
syringe = { name = "syringe", label = "Syringe", weight = 1, type = "item", image = "syringe.png", unique = false, useable = false, shouldClose = true, description = "A clean medical syringe." },

-- Weed
ak47_1g = { name = "ak47_1g", label = "AK47 1g", weight = 100, type = "item", image = "ak47_1g.png", unique = false, useable = false, shouldClose = true, description = "A sealed 1g bag of AK47 cannabis." },
ak47_joint = { name = "ak47_joint", label = "AK47 Joint", weight = 100, type = "item", image = "ak47_joint.png", unique = false, useable = true, shouldClose = true, description = "A hand-rolled joint containing AK47 cannabis." },
ak47_weed = { name = "ak47_weed", label = "AK47 Nug", weight = 100, type = "item", image = "ak47_weed.png", unique = false, useable = false, shouldClose = true, description = "A nug of dried AK47 cannabis." },
amensia_weed = { name = "amensia_weed", label = "Amensia Nug", weight = 100, type = "item", image = "amensia_weed.png", unique = false, useable = false, shouldClose = true, description = "A nug of dried Amensia cannabis." },
amnesia_1g = { name = "amnesia_1g", label = "Amnesia 1g", weight = 100, type = "item", image = "amnesia_1g.png", unique = false, useable = false, shouldClose = true, description = "A sealed 1g bag of Amnesia cannabis." },
amnesia_joint = { name = "amnesia_joint", label = "Amnesia Joint", weight = 100, type = "item", image = "amnesia_joint.png", unique = false, useable = true, shouldClose = true, description = "A hand-rolled joint containing Amnesia cannabis." },
blue_dream_1g = { name = "blue_dream_1g", label = "Blue Dream 1g", weight = 100, type = "item", image = "blue_dream_1g.png", unique = false, useable = false, shouldClose = true, description = "A sealed 1g bag of Blue Dream cannabis." },
blue_dream_joint = { name = "blue_dream_joint", label = "Blue Dream Joint", weight = 100, type = "item", image = "blue_dream_joint.png", unique = false, useable = true, shouldClose = true, description = "A hand-rolled joint containing Blue Dream cannabis." },
blue_dream_weed = { name = "blue_dream_weed", label = "Blue Dream Nug", weight = 100, type = "item", image = "blue_dream_weed.png", unique = false, useable = false, shouldClose = true, description = "A nug of dried Blue Dream cannabis." },
dried_cola = { name = "dried_cola", label = "Dried Cola", weight = 100, type = "item", image = "dried_cola.png", unique = false, useable = false, shouldClose = true, description = "A dried cannabis cola ready for processing." },
og_kush_1g = { name = "og_kush_1g", label = "OG Kush 1g", weight = 100, type = "item", image = "og_kush_1g.png", unique = false, useable = false, shouldClose = true, description = "A sealed 1g bag of OG Kush cannabis." },
og_kush_joint = { name = "og_kush_joint", label = "OG Kush Joint", weight = 100, type = "item", image = "og_kush_joint.png", unique = false, useable = true, shouldClose = true, description = "A hand-rolled joint containing OG Kush cannabis." },
og_kush_weed = { name = "og_kush_weed", label = "OG Kush Nug", weight = 100, type = "item", image = "og_kush_weed.png", unique = false, useable = false, shouldClose = true, description = "A nug of dried OG Kush cannabis." },
purple_haze_1g = { name = "purple_haze_1g", label = "Purple Haze 1g", weight = 100, type = "item", image = "purple_haze_1g.png", unique = false, useable = false, shouldClose = true, description = "A sealed 1g bag of Purple Haze cannabis." },
purple_haze_joint = { name = "purple_haze_joint", label = "Purple Haze Joint", weight = 100, type = "item", image = "purple_haze_joint.png", unique = false, useable = true, shouldClose = true, description = "A hand-rolled joint containing Purple Haze cannabis." },
purple_haze_weed = { name = "purple_haze_weed", label = "Purple Haze Nug", weight = 100, type = "item", image = "purple_haze_weed.png", unique = false, useable = false, shouldClose = true, description = "A nug of dried Purple Haze cannabis." },
skunk_1g = { name = "skunk_1g", label = "Skunk 1g", weight = 100, type = "item", image = "skunk_1g.png", unique = false, useable = false, shouldClose = true, description = "A sealed 1g bag of Skunk cannabis." },
skunk_joint = { name = "skunk_joint", label = "Skunk Joint", weight = 1000, type = "item", image = "skunk_joint.png", unique = false, useable = true, shouldClose = true, description = "A hand-rolled joint containing Skunk cannabis." },
skunk_weed = { name = "skunk_weed", label = "Skunk Nug", weight = 100, type = "item", image = "skunk_weed.png", unique = false, useable = false, shouldClose = true, description = "A nug of dried Skunk cannabis." },
wet_cola = { name = "wet_cola", label = "Wet Cola", weight = 100, type = "item", image = "wet_cola.png", unique = false, useable = false, shouldClose = true, description = "A freshly harvested cannabis cola that has not been dried." },
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
