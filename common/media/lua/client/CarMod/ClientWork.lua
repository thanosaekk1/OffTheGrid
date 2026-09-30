-- WOOD GASIFIER --

local OTGData
local function playerPressedKey(key)
    if not getPlayer() then
        return false
    end
    local playerCar = getPlayer():getVehicle()
    if playerCar and playerCar:getSeat(getPlayer()) == 0 and key == 17 then --proceed regardless of amount in the gas tank
        local carData = playerCar:getModData()
        --if carData.runningOnWood then --save the max theoretical speed (when starting)
        --    carData.ratedSpeed = playerCar:getMaxSpeed() * 2
        --else
        --    carData.ratedSpeed = playerCar:getMaxSpeed()
        --end
        local fuel_lvl = playerCar:getPartById('GasTank'):getContainerContentAmount()
        --print(fuel_lvl)
        -- give the car a small amount so the engine can start and we'll see whether it keeps that
        --playerCar:getPartById('GasTank'):setContainerContentAmount(1.0)
        --playerCar:engineDoStarting()
        if fuel_lvl < 0.01 then
            sendClientCommand(getPlayer(), "OffTheGrid", "CarRunWood", {})
        end
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
    if OTGData.expirationDay <= getWorld():getWorldAgeDays() and car:getPartById("GasTank"):getContainerContentAmount() > 0.0 and not car:getModData().runningOnWood then
        character:addLineChatElement("The fuel in this has gone bad...")
        car:getPartById("GasTank"):setContainerContentAmount(0.0)
        car:transmitPartModData(car:getPartById("GasTank")) --might be necessary for MP

        --local carData = car:getModData()
        --if carData.runningOnWood then
        --    carData.ratedSpeed = car:getMaxSpeed() * 2
        --else
        --    carData.ratedSpeed = car:getMaxSpeed()
        --end
        --car:transmitModData()
    end
end

Events.OnEnterVehicle.Add(playerEnteredVehicle)

-- sound function for clients
Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "OffTheGrid" or command ~= "CarBurnSound" then return end
    local car = getVehicleById(args.vehicleId)
    if car then
        car:playSound("CampfireLight")
    end
end)

-- FUEL EXPIRATION --


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