-- WOOD GASIFIER --

local old_place_item = ISDropWorldItemAction.complete

function ISDropWorldItemAction:complete() --inject when placing item to add the Gasifier to the world gasifier list
    print("Hello there")
    local retval = old_place_item(self)
    if self.item:getFullType() == "OffTheGrid.WoodGasifier" then
        local gasifier_pos = {
            x = self.item:getWorldItem():getWorldPosX(),
            y = self.item:getWorldItem():getWorldPosY(),
            z = self.item:getWorldItem():getWorldPosZ()
        }
        print(gasifier_pos)
        --local gasifier_pos = Vector3f.new(self.item:getWorldItem():getWorldPosX(), self.item:getWorldItem():getWorldPosY(), self.item:getWorldItem():getWorldPosZ())
        if not gasifierExists(gasifier_pos) then
            print("Sending storage info")
            sendClientCommand(getPlayer(), "OffTheGrid", "StoreGasifierPosition", gasifier_pos)
        end
    end
    return retval
end

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
        sendClientCommand(getPlayer(), "OffTheGrid", "CarRunWood", {})
        --CarRunWood(getPlayer():getVehicle())
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