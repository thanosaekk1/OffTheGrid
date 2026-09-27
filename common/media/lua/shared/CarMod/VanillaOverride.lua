-- REPLACING TRASH CANS WITH ORIGINAL ITEMS UPON PICKUP --

-- straight up copying PZ code down here

function ISMoveableSpriteProps:pickUpMoveableInternal( _character, _square, _object, _sprInstance, _spriteName, _createItem, _rotating )
    --if _object and self:canPickUpMoveable( _character, _square, not _sprInstance and _object or nil ) then
    local objIsIsoWindow = self.type == "Window" and instanceof(_object,"IsoWindow");
    local item 	= self:instanceItem(_spriteName);

    if item or (objIsIsoWindow and _object:isDestroyed()) then      -- destroyed windows return nil for instanceItem()
        GameEntityFactory.TransferComponents(_object, item);

        local windowGotSmashed = false;
        if not objIsIsoWindow or not _object:isDestroyed() then     -- when its a destroyed window skip this
            if not _rotating and self:doBreakTest( _character ) then
                if self.type ~= "Window" then
                    self:playBreakSound( _character, _object );
                    self:addBreakDebris( _square );
                elseif objIsIsoWindow then
                    if not _object:isDestroyed() then               -- in case of a window, when it breaks and isnt broken yet smash it, leaves no debris.
                        _object:smashWindow();
                        windowGotSmashed = true;
                    end
                end
            elseif item then
                if instanceof(_object, "IsoThumpable") then
                    self:saveThumpableParameters(item:getModData(), _object);
                else
                    if _object:hasModData() and _object:getModData().movableData then
                        item:getModData().movableData = copyTable(_object:getModData().movableData)
                    end

                    for i = 0, _object:getContainerCount()-1 do
                        if _object:getContainerByIndex(i) and _object:getContainerByIndex(i):getCustomName() then
                            local cont = _object:getContainerByIndex(i)
                            local key = cont:getType() .. "_customContainerName"
                            item:getModData()[key] = _object:getContainerByIndex(i):getCustomName()
                        end
                    end

                    if _object:hasModData() and _object:getModData().itemCondition then
                        item:setConditionMax(_object:getModData().itemCondition.max);
                        item:setCondition(_object:getModData().itemCondition.value);
                    end

                    if instanceof(_object, "IsoStove") and _object:isBroken() then
                        item:setCondition(0);
                    end
                end
                if _createItem then
                    if self.isMultiSprite then
                        _square:AddWorldInventoryItem(item, ZombRandFloat(0.1,0.9), ZombRandFloat(0.1,0.9), 0);
                    else
                        
                        -- MODDED CODE HERE --

                        if item:getType() == "trashcontainers_01_16" then
                            item = instanceItem("Base.Mov_RecycleBin")
                        elseif item:getType() == "trashcontainers_01_17" then
                            item = instanceItem("Base.Mov_GreenGarbageBin")
                        elseif item:getType() == "trashcontainers_01_21" then
                            item = instanceItem("Base.Mov_PublicGarbageBin")
                        end

                        -- MODDED CODE ENDS HERE --

                        _character:getInventory():AddItem(item);        -- add the item if it aint got broken
                        sendAddItemToContainer(_character:getInventory(), item);
                    end
                end
            end
        end

        -- custom/modified light info (custom bulb, use battery etc) for the various lamps can by copied to movable item and retrieved uppon placing;
        if instanceof(_object,"IsoLightSwitch") and _sprInstance==nil then
            _object:setCustomSettingsToItem(item);
            --item:getLightSettings(obj);
        end

        if instanceof(_object, "IsoMannequin") then
            _object:setCustomSettingsToItem(item)
        end

        -- Remove stuff from the world
        if self.type == "WallOverlay" then
            -- A Mirror on the east or south edge of a square.
            if _object:getSprite() and _spriteName and (_object:getSprite():getName() == _spriteName) then
                triggerEvent("OnObjectAboutToBeRemoved", _object) -- Hack for RainCollectorBarrel, Trap, etc
                _square:transmitRemoveItemFromSquare(_object)
            elseif _sprInstance then
                local sprList = _object:getChildSprites();
                local sprIndex = sprList and sprList:indexOf(_sprInstance) or -1
                if sprIndex == -1 then
                else
                    _object:RemoveAttachedAnim(sprIndex)
                    if isClient() then _object:transmitUpdatedSpriteToServer() end
                    if isServer() then _object:transmitUpdatedSpriteToClients(); end
                end
            end
        elseif self.type == "FloorTile" then
            local moveableDefinitions = ISMoveableDefinitions:getInstance();
            if moveableDefinitions and moveableDefinitions.floorReplaceSprites then
                local repSprs = moveableDefinitions.floorReplaceSprites;
                local floor = _square:getFloor();
                local spr = getSprite( repSprs[ ZombRand(1,#repSprs) ] );
                if floor and spr then
                    floor:setSprite(spr);
                    if isClient() then floor:transmitUpdatedSpriteToServer(); end
                    if isServer() then floor:transmitUpdatedSpriteToClients(); end
                end
            end
        elseif self.isoType == "IsoBrokenGlass" then
            -- add random damage to hands if no gloves
            if not _character:getClothingItem_Hands() and ZombRand(3) == 0 then
                local handPart = _character:getBodyDamage():getBodyPart(BodyPartType.FromIndex(ZombRand(BodyPartType.ToIndex(BodyPartType.Hand_L),BodyPartType.ToIndex(BodyPartType.Hand_R) + 1)))
                handPart:setScratched(true, true);
                -- possible glass in hands
                if ZombRand(5) == 0 then
                    handPart:setHaveGlass(true);
                end
            end
            triggerEvent("OnObjectAboutToBeRemoved", _object)
            _square:transmitRemoveItemFromSquare(_object)
        elseif self.isoType == "IsoFeedingTrough" then
            triggerEvent("OnObjectAboutToBeRemoved", _object)
            _square:transmitRemoveItemFromSquare(_object)
        elseif self.type == "Window" then
            if objIsIsoWindow and not windowGotSmashed then
                _square:transmitRemoveItemFromSquare(_object)
            end
        elseif not _sprInstance then --Objects, Vegitation, WallObjects etc
            if self.isoType == "IsoRadio" or self.isoType == "IsoTelevision" then
                if instanceof(_object,"IsoWaveSignal") then
                    local deviceData = _object:getDeviceData();
                    if deviceData then
                        item:setDeviceData(deviceData);
                    else
                        print("Warning: device data missing?>?")
                    end
                end
            end

            if self.spriteProps and self.spriteProps:has(IsoFlagType.waterPiped) and _spriteName ~= "camping_01_16" then
                -- empty water on pickup
                if item:getFluidContainer() ~= nil then
                    item:getFluidContainer():Empty();
                end
            end

            triggerEvent("OnObjectAboutToBeRemoved", _object) -- Hack for RainCollectorBarrel, Trap, etc
            _square:transmitRemoveItemFromSquare(_object)
        end
        _square:RecalcProperties();
        _square:RecalcAllWithNeighbours(true);

        --ISMoveableCursor.clearCacheForAllPlayers();

        triggerEvent("OnContainerUpdate")

        IsoGenerator.updateGenerator(_square)
        return item;
    end
    --end
end