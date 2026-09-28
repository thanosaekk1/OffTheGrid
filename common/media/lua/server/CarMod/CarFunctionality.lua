-------------------
-- WOOD GASIFIER --
-------------------

--@type String[]
wood_items = {"Base.Twigs", "Base.Splinters", "Base.Charcoal", "Base.CharcoalCrafted", "Base.Plank_Broken", "Base.UnusableWood", "Base.TwigsBundle", "Base.TreeBranch2", "Base.Plank", "Base.FirewoodBundle", "Base.LargeBranch", "Base.Log", "Base.LogStacks2", "Base.LogStacks3", "Base.LogStacks4"}
--in the future try sorting them by weight on startup so I don't have
--to keep them properly ordered and can just chuck new ones at the end

local OTGData

function CarRunWood(car)
    local trunk_container = car:getTrunkPart():getItemContainer()
    local gas_tank = car:getPartById("GasTank")
    local gas_level = gas_tank:getContainerContentAmount()
    if not trunk_container:contains("OffTheGrid.WoodGasifier") then
        return false
    end
	local trunk_contents = trunk_container:getItems()
    local gasifier
	for i=0, trunk_contents:size()-1 do
        local trunk_item = trunk_contents:get(i)
		if trunk_item:getFullType() == "OffTheGrid.WoodGasifier" then
			gasifier = trunk_item:getInventory()
        end
	end
	if not gasifier then
		return false
	end
    --check if the Gasifier isn't clogged with ashes
    local ash_content = gasifier:getNumberOfItem("OffTheGrid.Ash")
    if ash_content > 10 then
        car:getDriver():addLineChatElement("The gasifier's totally clogged...")
        return false
    elseif ash_content > 5 then --close to max amount of ashes, some failures are possible
        local failure_roll = ZombRand(ash_content, 11)
        if failure_roll >= 10 then
            return false
        end
        car:getDriver():addLineChatElement("The gasifier's starting to clog...")
    end

	-- running out of gas, change to wood
    for i=1, #wood_items do
        if gasifier:contains(wood_items[i]) then
            local item_to_burn = getScriptManager():FindItem(wood_items[i])
            local power_generated = item_to_burn:getActualWeight() * SandboxVars.OffTheGrid.GasifierFuelEfficiency /10
            if item_to_burn:getFireFuelRatio() > 0 then
                power_generated = power_generated * item_to_burn:getFireFuelRatio()
            end

            gas_tank:setContainerContentAmount(gas_level + power_generated)
            car:transmitPartModData(gas_tank) --necessary?

            local wood_to_remove = gasifier:getFirstTypeRecurse(wood_items[i])
            gasifier:Remove(wood_to_remove)
            sendRemoveItemFromContainer(gasifier, wood_to_remove) -- FOR MP
            local ash_to_add = instanceItem("OffTheGrid.Ash")
            local ash_num = PZMath.roundToInt(power_generated * 5)
			gasifier:AddItems(ash_to_add, ash_num)
            sendAddItemToContainer(gasifier, ash_to_add) -- FOR MP
            car:playSound("CampfireLight")
            --car:setEngineFeature(car:getEngineQuality(), 40, car:getEnginePower())
            car:getModData().runningOnWood = true
            car:getModData().fuelFromWood = gas_tank:getContainerContentAmount()
            print("Found wood to burn...")
            car:transmitModData()
            break
        end
    end
end

local function onClientCommand(module, command, player, args)
    print("Command called server-side")
    if module ~= "OffTheGrid" then return end

    if command == "CarRunWood" then
        local playerCar = player:getVehicle()
        print("kicking off with wood power...")
        CarRunWood(playerCar)
    elseif command == "StoreGasifierPosition" then
        print("storing gasifier position...")
        local Data = ModData.getOrCreate("OffTheGridData")
        if not gasifierExists(args) then
            table.insert(Data.gasifier_list, args)
        end
        print("Gasifiers: ", #Data.gasifier_list)
        ModData.transmit("OffTheGridData")
    end
end

Events.OnClientCommand.Add(onClientCommand)

local function CarFuelCheck(player)
    local car = player:getVehicle()
    if not car or not player:isDriving() then
        return false
    else
        local carData = car:getModData()
        print(carData.runningOnWood)
        if not carData.fuelFromWood then
            carData.fuelFromWood = 0.0
        end
        if not carData.runningOnWood then --save the max theoretical speed and loudness
            carData.ratedSpeed = car:getMaxSpeed()
            carData.ratedLoudness = car:getEngineLoudness()
        end
        
        if car:getRemainingFuelPercentage()<0.01 and car:isEngineRunning() then
            print("running out of wood mid-road...")
            CarRunWood(car)
        end

        -- CHECK FOR EXTERNAL REFILL - TEMPORARILY MOVED TO VANILLA OVERRIDE
        --if car:getPartById("GasTank"):getContainerContentAmount() > carData.fuelFromWood then
        --    -- external refill happened
        --    carData.runningOnWood = false
        --    print(car:getModData().runningOnWood, car:getPartById("GasTank"):getContainerContentAmount(), " ", car:getModData().fuelFromWood)
        --end
        
        --set performance
        if carData.runningOnWood then
            -- constantly fails to implement on MP
            car:setMaxSpeed(carData.ratedSpeed/2)
            print("Limited speed: ", car:getMaxSpeed())
            --print(car:getMaxSpeed())
            carData.fuelFromWood = car:getPartById("GasTank"):getContainerContentAmount()
            --print(car:getModData().runningOnWood, car:getPartById("GasTank"):getContainerContentAmount(), " ", car:getModData().fuelFromWood)
        else
            --print("Performance set to original")
            car:setMaxSpeed(carData.ratedSpeed)
            print("Full speed: ", car:getMaxSpeed())
        end
        --carData.transmit()
    end
end

function GeneratorRunWood(gasifier_pos, generator)
    local gasifier_square = getSquare(gasifier_pos.x, gasifier_pos.y, gasifier_pos.z)
    local obj_list = gasifier_square:getLuaTileObjectList()
    local gasifier
    for i=1, #obj_list do
        if instanceof(obj_list[i], "IsoWorldInventoryObject") and obj_list[i]:getItem():getFullType() == "OffTheGrid.WoodGasifier" then
            gasifier = obj_list[i]:getItem():getInventory() --need to specify to grab its container
        end
    end
    if not gasifier then
		return false
	end
    --check if the Gasifier isn't clogged with ashes
    local ash_content = gasifier:getNumberOfItem("OffTheGrid.Ash")
    if ash_content > 10 then
        --need to make it so that the hint doesn't trigger when far away from the gasifier
        --getPlayer():addLineChatElement("The gasifier's totally clogged...")
        return false
    elseif ash_content > 5 then --close to max amount of ashes, some failures are possible
        local failure_roll = ZombRand(ash_content, 11)
        if failure_roll >= 10 then
            return false
        end
        --getPlayer():addLineChatElement("The gasifier's starting to clog...")
    end

	-- running out of gas, change to wood
    for i=1, #wood_items do
        if gasifier:contains(wood_items[i]) then
            local item_to_burn = getScriptManager():FindItem(wood_items[i])
            local power_generated = item_to_burn:getActualWeight() * SandboxVars.OffTheGrid.GasifierFuelEfficiency /10
            if item_to_burn:getFireFuelRatio() > 0 then
                power_generated = power_generated * item_to_burn:getFireFuelRatio()
            end
            local gas_level = generator:getFuel()
            generator:setFuel(gas_level + power_generated)
            local wood_to_remove = gasifier:getFirstTypeRecurse(wood_items[i])
            gasifier:RemoveOneOf(wood_items[i])
            local ash_to_add = instanceItem("OffTheGrid.Ash")
            local ash_num = PZMath.roundToInt(power_generated * 5)
			gasifier:AddItems(ash_to_add, ash_num)
            gasifier_square:playSoundLocal("FireplaceAddFuel")
            local genCondition = generator:getCondition()
            generator:setCondition(genCondition - 2) -- burning wood causes condition to deteriorate faster
            generator:getModData().fuelFromWood = generator:getFuelPercentage()
            break
        end
    end
end

local function GeneratorFuelCheck() -- def runs client-side hence why it doesn't detect any gasifiers
    local data = ModData.getOrCreate("OffTheGridData")
    if not data then return end
    local gasifiers = data.gasifier_list
    for i=1, #gasifiers do
        local gasifier_pos = gasifiers[i]
        if gasifier_pos then
            for pos_x = gasifier_pos.x-3, gasifier_pos.x+3 do
                for pos_y = gasifier_pos.y-3, gasifier_pos.y+3 do
                    local target_square = getSquare(pos_x,pos_y, gasifier_pos.z)
                    if target_square then
                        local obj_list = target_square:getLuaTileObjectList()
                        if obj_list then
                            for j=1, #obj_list do
                                if obj_list[j]:getObjectName() == "IsoGenerator" then
                                    local generator = obj_list[j]
                                    if generator then
                                        local generatorData = generator:getModData() 
                                        if not generatorData.fuelFromWood then
                                            generatorData.fuelFromWood = 0.0
                                        end
                                        if generator:isConnected() and generator:getFuelPercentage()<0.01 then
                                            -- will burn wood without being turned on
                                            GeneratorRunWood(gasifier_pos, generator)
                                        end
                                        if generator:getFuelPercentage() > generatorData.fuelFromWood then
                                            -- external refill happened
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

Events.EveryOneMinute.Add(GeneratorFuelCheck)

Events.OnPlayerUpdate.Add(CarFuelCheck)

function gasifierExists (pos)
    local data = ModData.getOrCreate("OffTheGridData")
    local gasifiers = data.gasifier_list or {}
    for _, existing in ipairs(gasifiers) do
        if existing.x == pos.x
        and existing.y == pos.y
        and existing.z == pos.z then
            return true 
        end
    end
    return false
end

function arrayContains(arr, key)
    local found = false
    for i=1, #arr do
        if arr[i] == key then found = true end
    end
    return found
end

-------------------------
-- GASOLINE EXPIRATION --
-------------------------

local function initUtils(newGame)
    OTGData = ModData.getOrCreate("OffTheGridData")
    if not OTGData.gasifier_list then
        OTGData.gasifier_list = {}
    end
    if newGame then
        OTGData.currentDay = 0
        OTGData.fuelExpired = false
        OTGData.fuelExpirationStart = SandboxVars.OffTheGrid.GasolineExpirationDateStart
        OTGData.fuelExpirationEnd = SandboxVars.OffTheGrid.GasolineExpirationDateEnd
        OTGData.fuelExpirationRoll = ZombRandFloat(0, 1)
    end
    ModData.transmit("OffTheGridData")
end

local function gameStartUtils()
    OTGData = ModData.getOrCreate("OffTheGridData")
    print("Gasifiers: ",#OTGData.gasifier_list)
    print("Fuel expires: ", OTGData.fuelExpirationRoll)
end

local function dailyUpdate()
    OTGData = ModData.getOrCreate("OffTheGridData")
    OTGData.currentDay = OTGData.currentDay or 0
    OTGData.currentDay = OTGData.currentDay + 1
    if OTGData.currentDay >= OTGData.fuelExpirationStart then
        if OTGData.fuelExpirationEnd == OTGData.fuelExpirationStart then-- avoid dividing by zero
            if OTGData.currentDay == OTGData.fuelExpirationEnd then
                OTGData.fuelExpired = true
            end
        elseif (OTGData.currentDay - OTGData.fuelExpirationStart)/(OTGData.fuelExpirationEnd - OTGData.fuelExpirationStart) > OTGData.fuelExpirationRoll then
            OTGData.fuelExpired = true
        end
    end
    print("Current day: ", OTGData.currentDay)
    ModData.transmit("OffTheGridData")
end

Events.OnInitGlobalModData.Add(initUtils)
Events.OnGameStart.Add(gameStartUtils)

Events.EveryDays.Add(dailyUpdate)

--local function carsHourUpdate()
--    --clear wood gas from cars that aren't running
--    local car_list = getWorld():getCell():getVehicles()
--    print(car_list)
--
--    -- getVehicles was borked by 42.17
--
--    for i=0, car_list:size() - 1 do
--        if (car_list:get(i):getModData()).runningOnWood then
--            if not car_list:get(i):isEngineWorking() then
--                (car_list:get(i):getPartById("GasTank")):setContainerContentAmount(0.0)
--            end
--        end
--    end
--end

--Events.EveryHours.Add(carsHourUpdate)


--local old_activate_generator = ISActivateGenerator.isValid
--local old_take_generator = ISTakeGenerator.isValid
--local old_fix_generator = ISFixGenerator.isValid
--
--function resetExpiredFuel(IsoGen)
--    if fuelExpired then
--        if not IsoGen:getModData().fuelFromWood then
--            IsoGen:getModData().fuelFromWood = 0.0
--        end
--        IsoGen:setFuel(IsoGen:getModData().fuelFromWood)
--    end
--end
--
--function ISActivateGenerator:isValid()
--    resetExpiredFuel(self.generator)
--    return old_activate_generator(self)
--end
--
--function ISTakeGenerator:isValid()
--    resetExpiredFuel(self.generator)
--    return old_take_generator(self)
--end
--
--function ISFixGenerator:isValid()
--    resetExpiredFuel(self.generator)
--    return old_fix_generator(self)
--end

-- OVERRIDE HOOK TO DETECT ENGINE STARTING - DEPRECATED, ONLY SEEMS TO WORK WITH ENGINE BUTTON ON DASHBOARD

--local old_start_vehicle_engine = ISStartVehicleEngine.isValid
--
--function ISStartVehicleEngine:isValid() --need to account for fuel running out while in the middle of a trip too
--    local characterCar = self.character:getVehicle()
--    if characterCar and characterCar:getRemainingFuelPercentage()<0.01 then
--        local carData = characterCar:getModData()
--        if not carData.runningOnWood then --save the max theoretical speed (when starting)
--            carData.ratedSpeed = characterCar:getMaxSpeed()
--        end
--        CarRunWood(characterCar)
--        return true --should it always return true?
--    else
--        return old_start_vehicle_engine(self)
--    end
--end