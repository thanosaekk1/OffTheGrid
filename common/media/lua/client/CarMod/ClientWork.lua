-- WOOD GASIFIER --

local function playerPressedKey(key)
    if not getPlayer() then
        return false
    end
    local playerCar = getPlayer():getVehicle()
    if playerCar and playerCar:getRemainingFuelPercentage()<0.01 and key == 17 then
        local carData = playerCar:getModData()
        if not carData.runningOnWood then --save the max theoretical speed (when starting)
            carData.ratedSpeed = playerCar:getMaxSpeed()
        end
        CarRunWood(getPlayer():getVehicle())
    end
end

Events.OnKeyStartPressed.Add(playerPressedKey)

-- COMPOSTER --

local function mixAshIntoComposter(composter, player)
    local compost_lvl = composter:getCompost()
    local player_inv = player:getInventory()
    local ash = player_inv:getFirstTypeRecurse("OffTheGrid.Ash")

    if not ash then return end
    if compost_lvl > 95.0 then return end

    player_inv:Remove(ash)
    sendRemoveItemFromContainer(player_inv, ash) --might be needed for MP
    composter:getSquare():playSound("DropSoilFromSandBag")
    composter:setCompost(compost_lvl + 5.0)
    composter:syncCompost()
end

local function preContextMenuFill(playerIndex, context, worldobjects, test)
    if test then return end
    if #worldobjects == 0 then return end

    local square = worldobjects[1]:getSquare()
    if not square then return end

    local composter

    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)

        if instanceof(object, "IsoCompost") then
            composter = object
            break
        end
    end

    if not composter then return end

    local player = getSpecificPlayer(playerIndex)
    local player_inv = player:getInventory()

    if not player_inv:getFirstTypeRecurse("OffTheGrid.Ash") then return end

    local mixAshOption = context:addOption(
        "Mix Ash into Compost",
        composter,
        mixAshIntoComposter,
        player
    )

    if composter:getCompost() > 95.0 then
        mixAshOption.notAvailable = true
    end
end

Events.OnPreFillWorldObjectContextMenu.Add(preContextMenuFill)