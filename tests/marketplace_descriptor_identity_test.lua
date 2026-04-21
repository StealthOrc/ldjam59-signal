package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}

local ui = require("src.game.ui.screens")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %s but got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local marketplaceDescriptorGame = {
    levelSelectMode = "marketplace",
    levelSelectMarketplaceTab = "top",
    levelSelectMarketplaceSearchQuery = "",
    getMarketplaceFavoriteAnimation = function()
        return nil
    end,
    getMarketplaceEntries = function()
        return {
            {
                map_uuid = "shared-market-map",
                internal_identifier = "A1B2",
                creator_uuid = "creator-1",
                creator_display_name = "Creator",
                map_name = "Shared Map",
                map_category = "users",
                liked_by_player = false,
                favorite_count = 2,
                map = {
                    junctions = {},
                    trains = {},
                },
            },
            {
                map_uuid = "shared-market-map",
                internal_identifier = "C3D4",
                creator_uuid = "creator-1",
                creator_display_name = "Creator",
                map_name = "Shared Map Variant",
                map_category = "users",
                liked_by_player = true,
                favorite_count = 5,
                map = {
                    junctions = {},
                    trains = {},
                },
            },
        }
    end,
}

local descriptors = ui.getLevelSelectMapDescriptors(marketplaceDescriptorGame)
assertEqual(#descriptors, 2, "marketplace descriptor list keeps both entries with a shared map UUID")
assert(descriptors[1].id ~= descriptors[2].id, "marketplace descriptor ids stay unique for shared map UUID entries")

print("marketplace descriptor identity tests passed")


