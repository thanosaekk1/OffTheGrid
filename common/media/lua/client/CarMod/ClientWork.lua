-- WOOD GASIFIER --

local OTGData
local function playerPressedKey(key)
    if not getPlayer() then
        return false
    end
    local playerCar = getPlayer():getVehicle()
    if playerCar and playerCar:getSeat(getPlayer()) == 0 and playerCar:getRemainingFuelPercentage()<0.01 and key == 17 then
        --("Trying to start car...", playerCar:getRemainingFuelPercentage())
        local carData = playerCar:getModData()
        if not carData.runningOnWood then --save the max theoretical speed (when starting)
            carData.ratedSpeed = playerCar:getMaxSpeed()
        end
        sendClientCommand(getPlayer(), "OffTheGrid", "CarRunWood", {max_speed=carData.ratedSpeed})
        --CarRunWood(getPlayer():getVehicle())
    end
end

Events.OnKeyStartPressed.Add(playerPressedKey)
function connectGasifierToGens(obj)
    local gasifier_pos = {
        x = obj:getWorldPosX(),
        y = obj:getWorldPosY(),
        z = obj:getWorldPosZ()
    }
    sendClientCommand(getPlayer(), "OffTheGrid", "StoreGasifierPosition", gasifier_pos)
end

local function playerEnteredVehicle(character)
    OTGData = ModData.getOrCreate("OffTheGridData")
    local car = character:getVehicle()
    if not car then return false end
    if OTGData.fuelExpired and car:getPartById("GasTank"):getContainerContentAmount() > 0.0 and not car:getModData().runningOnWood then
        character:addLineChatElement("The fuel in this has gone bad...")
        car:getPartById("GasTank"):setContainerContentAmount(0.0)
    end
end

Events.OnEnterVehicle.Add(playerEnteredVehicle)

--Events.OnReceiveGlobalModData.Add(function(key, data)
--    if key == "OffTheGridData" then
--        --print("Gasifier list received by client:", #((data and data.gasifier_list) or {}))
--        OTGData = data
--    end
--end)

-- FUEL EXPIRATION --

--local function ReceiveModData(key, data)
--    if key ~= "OffTheGridData" then return end
--
--end
--
--Events.OnReceiveGlobalModData.Add(ReceiveModData)

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

    local gasifier
    local composter

    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)

        if instanceof(object, "IsoWorldInventoryObject") then
            if object:getItem():getFullType() == "OffTheGrid.WoodGasifier" then
                gasifier = object
                break
            end
        end

        if instanceof(object, "IsoCompost") then
            composter = object
            break
        end
    end

    local player = getSpecificPlayer(playerIndex)
    if gasifier then
        local data = ModData.getOrCreate("OffTheGridData")
        local connectToGenerators = context:addOption(
            "Connect to Nearby Generators",
            gasifier,
            connectGasifierToGens,
            player
        )
        local obj_position = {
            x = gasifier:getWorldPosX(),
            y = gasifier:getWorldPosY(),
            z = gasifier:getWorldPosZ()
        }
        if gasifierExists(obj_position) then -- gasifier in that position already connected
            obj_position.notAvailable = true
        end
    elseif composter then
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
end

Events.OnPreFillWorldObjectContextMenu.Add(preContextMenuFill)