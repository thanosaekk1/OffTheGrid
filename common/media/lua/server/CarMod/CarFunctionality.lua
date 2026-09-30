-------------------
-- WOOD GASIFIER --
-------------------

--@type String[]
wood_items = {"Base.Twigs", "Base.Splinters", "Base.Charcoal", "Base.CharcoalCrafted", "Base.Plank_Broken", "Base.UnusableWood", "Base.TwigsBundle", "Base.TreeBranch2", "Base.Plank", "Base.FirewoodBundle", "Base.LargeBranch", "Base.Log", "Base.LogStacks2", "Base.LogStacks3", "Base.LogStacks4"}
--in the future try sorting them by weight on startup so I don't have
--to keep them properly ordered and can just chuck new ones at the end

local OTGData

--local wood_burn_cooldown = 1000
function CarRunWood(car, changeTank)
    local trunk_container = car:getTrunkPart():getItemContainer()
    local gas_tank = car:getPartById("GasTank")
    if not gas_tank then return 0 end
    local gas_level = gas_tank:getContainerContentAmount()
    print("CarRunWood executed - Gas: ", gas_level)
    -- client requests from tapping W cause weird executions where none of the car's data gets passed, leading to unnecessary wood burns
    if not trunk_container:contains("OffTheGrid.WoodGasifier") then
        return 0
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
		return 0
	end

    --check if the Gasifier isn't clogged with ashes
    local ash_content = gasifier:getNumberOfItem("OffTheGrid.Ash")
    if ash_content > 10 then
        car:getDriver():addLineChatElement("The gasifier's totally clogged...")
        return 0
    elseif ash_content > 5 then --close to max amount of ashes, some failures are possible
        local failure_roll = ZombRand(ash_content, 11)
        if failure_roll >= 10 then
            return 0
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
            
            if changeTank then
                gas_tank:setContainerContentAmount(gas_level + power_generated, true, true)
                car:transmitPartModData(gas_tank) --might be necessary for MP
                --print("-> Changed gas tank contents")
            end

            local wood_to_remove = gasifier:getFirstTypeRecurse(wood_items[i])
            gasifier:Remove(wood_to_remove)
            sendRemoveItemFromContainer(gasifier, wood_to_remove) -- FOR MP
            local ash_to_add = instanceItem("OffTheGrid.Ash")
            local ash_num = PZMath.roundToInt(power_generated * 5)
			gasifier:AddItems(ash_to_add, ash_num)
            sendAddItemToContainer(gasifier, ash_to_add) -- FOR MP
            if isServer() then
                sendServerCommand("OffTheGrid", "CarBurnSound", {vehicleId = car:getId()})
            else
                car:playSound("CampfireLight")
            end
            --car:setEngineFeature(car:getEngineQuality(), 40, car:getEnginePower())
            car:getModData().runningOnWood = true
            car:transmitModData()
            --print("Found wood to burn...")
            return power_generated
        end
    end
    return 0
end

local function onClientCommand(module, command, player, args)
    if module ~= "OffTheGrid" then return end

    if command == "CarRunWood" then
        local playerCar = player:getVehicle()
        if not playerCar then return end
        CarRunWood(playerCar, true)
    elseif command == "StoreGasifierPosition" then
        local Data = ModData.getOrCreate("OffTheGridData")
        if not gasifierExists(args) then
            table.insert(Data.gasifier_list, args)
        end
        ModData.transmit("OffTheGridData")
    end
end

Events.OnClientCommand.Add(onClientCommand)

local function CarFuelCheck(player)
    local car = player:getVehicle()
    if not car or not player:isDriving() then
        return false
    else
        --print("client tank", car:getPartById("GasTank"):getContainerContentAmount())
        local carData = car:getModData()
        --if carData.runningOnWood then --save the max theoretical speed and loudness
        --    carData.ratedSpeed = car:getMaxSpeed() * 2
        --    --carData.ratedLoudness = car:getEngineLoudness()
        --else
        --    carData.ratedSpeed = car:getMaxSpeed()
        --end
        
        -- BUSY WAIT CHECK, CHANGE LATER
        --if car:isEngineRunning() and car:getPartById('GasTank'):getContainerContentAmount() < 0.01 then
        --    sendClientCommand(getPlayer(), "OffTheGrid", "CarRunWood", {})
        --end

        -- CHECK FOR EXTERNAL REFILL - TEMPORARILY MOVED TO VANILLA OVERRIDE
        --if car:getPartById("GasTank"):getContainerContentAmount() > carData.fuelFromWood then
        --    -- external refill happened
        --    carData.runningOnWood = false
        --    print(car:getModData().runningOnWood, car:getPartById("GasTank"):getContainerContentAmount(), " ", car:getModData().fuelFromWood)
        --end
        
        --set performance
        -- RE-ADD LATER
        --if not carData.ratedSpeed then
        --    carData.ratedSpeed = car:getMaxSpeed()
        --end
        --if carData.runningOnWood then
        --    car:setMaxSpeed(carData.ratedSpeed * 0.5)
        --    --carData.fuelFromWood = car:getPartById("GasTank"):getContainerContentAmount()
        --    --print(car:getModData().runningOnWood, car:getPartById("GasTank"):getContainerContentAmount(), " ", car:getModData().fuelFromWood)
        --else
        --    --print("Performance set to original")
        --    car:setMaxSpeed(carData.ratedSpeed)
        --end
        car:transmitModData()
    end
end

-- CODE COPIED FROM VANILLA AND EDITED FOR OWN NEEDS
function Vehicles.Update.GasTank(vehicle, part, elapsedMinutes)
	local invItem = part:getInventoryItem();
	if not invItem then return; end
	local amount = part:getContainerContentAmount()
	if elapsedMinutes > 0 and amount > 0 and vehicle:isEngineRunning() then
		local amountOld = amount
		-- calcul how much gas is used, based mainly on engine speed, engine quality & mass.
		local gasMultiplier = 90000;
		-- heater consume more gas
		local heater = vehicle:getHeater();
		if heater and heater:getModData().active then
			gasMultiplier = gasMultiplier - 5000;
		end
		-- if quality is 60, we do: 100 - 60 = 40; 40/2 = 20; 20/100=0.2; 0.2+1 = 1.2 : our multiplier;
		local qualityMultiplier = ((100 - vehicle:getEngineQuality()) / 200) + 1;
		local massMultiplier =  ((math.abs(1000 - vehicle:getScript():getMass())) / 300) + 1;
		-- the closer we are to change shift, the less we consume gas
		local speedToNextTransmission = ((vehicle:getMaxSpeed() / vehicle:getScript():getGearRatioCount()) * 0.71) * vehicle:getTransmissionNumber();
		local speedMultiplier = (speedToNextTransmission - vehicle:getCurrentSpeedKmHour()) * 350;
		-- if vehicle is stopped, we half the value of gas consummed
		if math.floor(vehicle:getCurrentSpeedKmHour()) > 0 then
			gasMultiplier = gasMultiplier / qualityMultiplier / massMultiplier;
		else
			gasMultiplier = (gasMultiplier / qualityMultiplier) * 2;
			speedMultiplier = 1;
		end
		-- we're at max gear, cap general gas consumption
		if speedMultiplier < 800 and speedMultiplier ~= 1 then
			speedMultiplier = 800;
		end

        if speedMultiplier == 1 then -- we're idling, need to increase the fuel consumption still
            speedMultiplier = 300;
        end

		local newAmount = (speedMultiplier / gasMultiplier)  * SandboxVars.CarGasConsumption;
		newAmount =  newAmount * (vehicle:getEngineSpeed()/2500.0);
		amount = amount - elapsedMinutes * newAmount;
	
		-- if your gas tank is in bad condition, you can simply lose fuel
		if part:getCondition() < 70 then
			if ZombRand(part:getCondition() * 2) == 0 then
				amount = amount - 0.01;
			end
		end
        
        -- ############################
        -- OTG: the mod intervenes here

        print("Gas tank update: ", part:getContainerContentAmount(), " --> ", amount)
        while amount < 0.01 do --try to run wood
            local fuel_gained = CarRunWood(vehicle, false)
            amount = amount + fuel_gained
            print("Amount after OTG intervention: ", amount)
            if fuel_gained == 0 then
                break
            end
        end

        -- OTG: end of intervention
        -- ########################
        
		part:setContainerContentAmount(amount, false, true);

		amount = part:getContainerContentAmount();
		local precision = (amount < 0.5) and 2 or 1
		if VehicleUtils.compareFloats(amountOld, amount, precision) then
			vehicle:transmitPartModData(part)
		end
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

local function GeneratorFuelCheck() -- runs client-side
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

--Events.OnPlayerUpdate.Add(CarFuelCheck)

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
    --if newGame then -- NEEDS TO ONLY BE DONE AT THE START OF A SAVE
        OTGData.expirationDay = SandboxVars.OffTheGrid.GasolineExpirationDateStart + (SandboxVars.OffTheGrid.GasolineExpirationDateEnd-SandboxVars.OffTheGrid.GasolineExpirationDateStart) * ZombRandFloat(0, 1)
    --end
    ModData.transmit("OffTheGridData")
end

local function gameStartUtils()
    OTGData = ModData.getOrCreate("OffTheGridData")
    print("Fuel expires: ", OTGData.expirationDay)
end

Events.OnInitGlobalModData.Add(initUtils)
Events.OnGameStart.Add(gameStartUtils)

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