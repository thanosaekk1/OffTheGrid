local myDistribution = {
    CrateMagazines = {
        items = {
            "OffTheGrid.lowTechMag1", 0.1,
        },
    },
    GunStoreLiterature = {
        items = {
            "OffTheGrid.lowTechMag1", 2,
        },
    },
    GunStoreMagazineRack = {
        items = {
            "OffTheGrid.lowTechMag1", 2,
        },
    },
    Hobbies = {
        items = {
            "OffTheGrid.lowTechMag1", 1,
        },
    },
    Homesteading = {
        items = {
            "OffTheGrid.lowTechMag1", 1,
        },
    },
    LibraryMagazines = {
        items = {
            "OffTheGrid.lowTechMag1", 1,
        },
    },
    LivingRoomShelf = {
        items = {
            "OffTheGrid.lowTechMag1", 0.1,
        },
    },
    LivingRoomShelfClassy = {
        items = {
            "OffTheGrid.lowTechMag1", 0.05,
        },
    },
    LivingRoomShelfRedneck = {
        items = {
            "OffTheGrid.lowTechMag1", 0.1,
        },
    },
    LivingRoomSideTable = {
        items = {
            "OffTheGrid.lowTechMag1", 0.05,
        },
    },
    LivingRoomSideTableClassy = {
        items = {
            "OffTheGrid.lowTechMag1", 0.01,
        },
    },
    LivingRoomSideTableRedneck = {
        items = {
            "OffTheGrid.lowTechMag1", 0.05,
        },
    },
    LivingRoomWardrobe = {
        items = {
            "OffTheGrid.lowTechMag1", 0.01,
        },
    },
    MagazineRackMixed = {
        items = {
            "OffTheGrid.lowTechMag1", 1,
        },
    },
    PostOfficeMagazines = {
        items = {
            "OffTheGrid.lowTechMag1", 1,
        },
    },
    RecRoomShelf = {
        items = {
            "OffTheGrid.lowTechMag1", 1,
        },
    },
    SafehouseBookShelf = {
        items = {
            "OffTheGrid.lowTechMag1", 1,
        },
    },
    ShelfGeneric = {
        items = {
            "OffTheGrid.lowTechMag1", 0.1,
        },
    },
    SurvivalGear = {
        items = {
            "OffTheGrid.lowTechMag1", 2,
        },
    },
    ToolStoreBooks = {
        items = {
            "OffTheGrid.lowTechMag1", 2,
        },
    },
}

-- CODE TAKEN FROM PZWIKI.NET --

-- caching for performance reasons
local ProceduralDistributions_list = ProceduralDistributions.list
local table_insert = table.insert

---@param distrib table<string, {items: table<number, string|number>?, junk: table<number, string|number>?}>
local function insertInDistribution(distrib)
    -- iterate through every given distributions
    for k,v in pairs(distrib) do
        -- cache this distribution list
        local ProceduralDistributions_list_k = ProceduralDistributions_list[k]

        -- insert items
        local items = v.items
        local ProceduralDistributions_list_k_items = ProceduralDistributions_list_k.items
        if items then
            for i = 1,#items do
                ProceduralDistributions_list_k_items[#ProceduralDistributions_list_k_items+1] = items[i]
            end
        end

        -- insert junk
        local junk = v.junk
        local ProceduralDistributions_list_k_junk = ProceduralDistributions_list_k.junk
        if junk and ProceduralDistributions_list_k_junk then
            for i = 1,#junk do
                ProceduralDistributions_list_k_junk[#ProceduralDistributions_list_k_junk+1] = junk[i]
            end
        end
    end
end

insertInDistribution(myDistribution)