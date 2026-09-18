-------------------
-- WOOD GASIFIER --
-------------------

--@type String[]
wood_items = {"Base.Twigs", "Base.Splinters", "Base.Charcoal", "Base.CharcoalCrafted", "Base.Plank_Broken", "Base.UnusableWood", "Base.TwigsBundle", "Base.TreeBranch2", "Base.Plank", "Base.FirewoodBundle", "Base.LargeBranch", "Base.Log", "Base.LogStacks2", "Base.LogStacks3", "Base.LogStacks4"}
--in the future try sorting them by weight on startup so they don't have to be ordered manually

world_wood_gasifiers = {}

local OTGData

local function CarRunWood(car)
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
        getPlayer():addLineChatElement("The gasifier's totally clogged...")
        return false
    elseif ash_content > 5 then --close to max amount of ashes, some failures are possible
        local failure_roll = ZombRand(ash_content, 11)
        if failure_roll >= 10 then
            return false
        end
        getPlayer():addLineChatElement("The gasifier's starting to clog...")
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
            gasifier:RemoveOneOf(wood_items[i])
            local ash_to_add = instanceItem("OffTheGrid.Ash")
            local ash_num = PZMath.roundToInt(power_generated * 5)
			gasifier:AddItems(ash_to_add, ash_num)
            car:playSound("Fire")
            --car:setEngineFeature(car:getEngineQuality(), 40, car:getEnginePower())
            car:getModData().runningOnWood = true
            car:getModData().fuelFromWood = gas_tank:getContainerContentAmount()
            break
        end
    end
end

local function CarFuelCheck(player)
    local car = getPlayer():getVehicle()
    if not car or not getPlayer():isDriving() then
        return false
    else
        local carData = car:getModData()
        if not carData.fuelFromWood then
            carData.fuelFromWood = 0.0
        end
        if not carData.runningOnWood then --save the max theoretical speed and loudness
            carData.ratedSpeed = car:getMaxSpeed()
            carData.ratedLoudness = car:getEngineLoudness()
        end
        
        if car:getRemainingFuelPercentage()<0.01 and car:isEngineRunning() then
            CarRunWood(car)
        end

        if car:getPartById("GasTank"):getContainerContentAmount() > carData.fuelFromWood then
            -- external refill happened
            carData.runningOnWood = false
        end

        --set performance
        if carData.runningOnWood then
            car:setMaxSpeed(carData.ratedSpeed/2)
            carData.fuelFromWood = car:getPartById("GasTank"):getContainerContentAmount()
            --car:setEngineFeature(car:getEngineQuality(), round(carData.ratedLoudness/2), car:getEnginePower())
            --does nothing as loudness is 0
            --print("Speed: ", car:getMaxSpeed(), "Fuel: ", carData.fuelFromWood, "Loudness: ", car:getEngineLoudness())
        else
            car:setMaxSpeed(carData.ratedSpeed)
            --car:setEngineFeature(car:getEngineQuality(), carData.ratedLoudness, car:getEnginePower())
            --print("Speed: ", car:getMaxSpeed(), "Fuel: ", carData.fuelFromWood, "Loudness: ", car:getEngineLoudness())
        end
    end
end

local function GeneratorRunWood(gasifier_pos, generator)
    local gasifier_square = getSquare(gasifier_pos:x(), gasifier_pos:y(), gasifier_pos:z())
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
            gasifier:RemoveOneOf(wood_items[i])
            local ash_to_add = instanceItem("OffTheGrid.Ash")
            local ash_num = PZMath.roundToInt(power_generated * 5)
			gasifier:AddItems(ash_to_add, ash_num)
            gasifier_square:playSoundLocal("Fire")
            generator:getModData().fuelFromWood = generator:getFuelPercentage()
            break
        end
    end
end

local function GeneratorFuelCheck()
    for i=1, #world_wood_gasifiers do
        local gasifier_pos = world_wood_gasifiers[i]
        if gasifier_pos then
            for pos_x = gasifier_pos:x()-3, gasifier_pos:x()+3 do
                for pos_y = gasifier_pos:y()-3, gasifier_pos:y()+3 do
                    local obj_list = getSquare(pos_x,pos_y, gasifier_pos:z()):getLuaTileObjectList()
                    if not obj_list then return end
                    for j=1, #obj_list do
                        if obj_list[j]:getObjectName() == "IsoGenerator" then
                            local generator = obj_list[j]
                            if generator then
                                local generatorData = generator:getModData() 
                                if not generatorData.fuelFromWood then
                                    generatorData.fuelFromWood = 0.0
                                end
                                if generator:isActivated() and generator:getFuelPercentage()<0.01 then
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

local function carsHourUpdate()
    --clear wood gas from cars that aren't running
    local car_list = getWorld():getCell():getVehicles()

    -- getVehicles was borked by 42.17

    --for i=0, car_list:size() - 1 do
    --    if (car_list:get(i):getModData()).runningOnWood then
    --        if not car_list:get(i):isEngineWorking() then
    --            (car_list:get(i):getPartById("GasTank")):setContainerContentAmount(0.0)
    --        end
    --    end
    --end
end

Events.OnKeyStartPressed.Add(playerPressedKey)

Events.OnPlayerUpdate.Add(CarFuelCheck)
Events.OnPlayerUpdate.Add(GeneratorFuelCheck)

Events.EveryHours.Add(carsHourUpdate)

local old_place_item = ISDropWorldItemAction.complete

function ISDropWorldItemAction:complete() --inject when placing item to add the Gasifier to the world gasifier list
    old_place_item(self)
    if self.item:getFullType() == "OffTheGrid.WoodGasifier" then
        local gasifier_pos = Vector3f.new(self.item:getWorldItem():getWorldPosX(), self.item:getWorldItem():getWorldPosY(), self.item:getWorldItem():getWorldPosZ())
        if not arrayContains(world_wood_gasifiers, gasifier_pos) then
            table.insert(world_wood_gasifiers, gasifier_pos)
            
            --save the gasifier position to mod data
            --local data = ModData.getOrCreate("OffTheGridData")
            if OTGData then
                OTGData.gasifier_list = world_wood_gasifiers
                print("Gasifiers: ", #OTGData.gasifier_list)
                ModData.transmit("OffTheGridData")
            end
        end
    end
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

fuelExpired = false
fuelExpirationStart = SandboxVars.OffTheGrid.GasolineExpirationDateStart
fuelExpirationEnd = SandboxVars.OffTheGrid.GasolineExpirationDateEnd
fuelExpirationRoll = 0.0
currentDay = 0

local function initUtils(newGame)
    OTGData = ModData.getOrCreate("OffTheGridData")
    if OTGData.gasifier_list then
        world_wood_gasifiers = OTGData.gasifier_list
    end
    if newGame then
        fuelExpirationRoll = ZombRandFloat(0, 1)
    end
end

local function gameStartUtils()
    print("Gasifiers: ", #world_wood_gasifiers)
    print("Fuel expires: ", fuelExpirationRoll)
end

local function dailyUpdate()
    currentDay = currentDay + 1
    if currentDay >= fuelExpirationStart then
        if fuelExpirationEnd == fuelExpirationStart then-- avoid dividing by zero
            if currentDay == fuelExpirationEnd then
                fuelExpired = true
            end
        elseif (currentDay - fuelExpirationStart)/(fuelExpirationEnd - fuelExpirationStart) > fuelExpirationRoll then
            fuelExpired = true
        end
    end
end

local function playerEnteredVehicle(character)
    local car = character:getVehicle()
    if not car then return false end
    if fuelExpired and car:getPartById("GasTank"):getContainerContentAmount() > 0.0 and not car.runningOnWood then
        character:addLineChatElement("The fuel in this has gone bad...")
        car:getPartById("GasTank"):setContainerContentAmount(0.0)
    end
end

local old_refuel_valid = ISRefuelFromGasPump.isValid
local old_take_gas_valid = ISTakeGasolineFromVehicle.isValid
local old_add_gas_valid = ISAddGasolineToVehicle.isValid
local old_take_gas_pump_valid = ISTakeFuel.isValid

function ISRefuelFromGasPump:isValid()
    if fuelExpired then
        if not self._printed then
            getPlayer():addLineChatElement("This fuel has gone bad...")
            self._printed = true
        end
        return false
    else
        return old_refuel_valid(self)
    end
end

function ISTakeGasolineFromVehicle:isValid()
    if fuelExpired then
        if not self._printed then
            getPlayer():addLineChatElement("This fuel has gone bad...")
            self._printed = true
        end
        return false
    else
        return old_take_gas_valid(self)
    end
end

function ISAddGasolineToVehicle:isValid()
    if fuelExpired then
        if not self._printed then
            getPlayer():addLineChatElement("This fuel has gone bad...")
            self._printed = true
        end
        return false
    else
        return old_add_gas_valid(self)
    end
end

function ISTakeFuel:isValid()
    if fuelExpired then
        if not self._printed then
            getPlayer():addLineChatElement("This fuel has gone bad...")
            self._printed = true
        end
        return false
    else
        return old_take_gas_pump_valid(self)
    end
end

Events.OnInitGlobalModData.Add(initUtils)
Events.OnGameStart.Add(gameStartUtils)

Events.OnEnterVehicle.Add(playerEnteredVehicle)

Events.EveryDays.Add(dailyUpdate)

local function testFunction()
    print(#world_wood_gasifiers)
    dailyUpdate()
    print(fuelExpired)
end