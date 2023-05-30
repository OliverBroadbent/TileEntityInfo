TileEntityInfo = {
    styler = {
        type = EXTENSION_TYPE.NBT_EDITOR_STYLE,
        recursive = true
    }
}

-- CUSTOM FUNCTIONS

function TileEntityInfo.styler:ticksToTime(ticks)
    local text = ""

    local secs = ticks/20
    local mins = (math.floor(secs))//60
    local hours = mins//60
    local days = hours//24

    if(days > 0) then text = text .. tostring(days) .. (days == 1 and " day, " or " days, ") end
    if(hours > 0) then text = text .. tostring(hours%24) .. (hours%24 == 1 and " hour, " or " hours, ") end
    if(mins > 0) then text = text .. tostring(mins%60) .. (mins%60 == 1 and " minute, " or " minutes, ") end
    if(secs > 0) then
        local secs_str = string.gsub(string.format("%.2f", math.abs(secs%60)), "0*$", "")
        if tonumber(secs_str) == math.floor(secs_str) then
            secs_str = string.gsub(secs_str, "%.", "")
        end
        text = text .. secs_str .. (secs%60 <= 1 and " second" or " seconds")
    end

    return text
end

function TileEntityInfo.styler:getCustomNameJava(tileEntity)
    
    if(tileEntity:contains("CustomName", TYPE.STRING)) then

        local customName = tileEntity.lastFound.value

        local jsonRoot = JSONValue.new()
        if(jsonRoot:parse(customName).type == JSON_TYPE.OBJECT) then
            local textOut = ""

            if(jsonRoot:contains("text", JSON_TYPE.STRING)) then
                textOut = jsonRoot.lastFound:getString()
            end

            if(jsonRoot:contains("extra", JSON_TYPE.ARRAY)) then
                local extraArray = jsonRoot.lastFound

                for j=0, extraArray.childCount-1 do
                    local extra = extraArray:child(j)
    
                    if(extra:contains("text", JSON_TYPE.STRING)) then
                        textOut = textOut .. extra.lastFound:getString()
                    end
                end
            end

            return textOut
        else
            return customName
        end
    end

    return ""
end

-- BASE TILE ENTITY

function TileEntityInfo.styler:main(root, context)
end

function TileEntityInfo.styler:recursion(root, target, context)
    
    if((context.type & FILE_TYPE.CHUNK) == 0) then return end

    if(target.type == TYPE.LIST and target.listType == TYPE.COMPOUND and (target.name == "block_entities" or target.name == "TileEntities")) then
        for i = 0, target.childCount-1 do self:ProcessTileEntity(target:child(i), context) end
    end
end

function TileEntityInfo.styler:ProcessTileEntity(tileEntity, context)
    
    tileEntity.info = {}
    self:NameAndIcon(tileEntity, context)
   
    if(tileEntity.info.baseName == nil) then return end -- temp fix for missing database entries like jigsaw
    self:CustomName(tileEntity, context)
    self:RunTileEntitySpecifics(tileEntity, context)

    self:BuildLabel(tileEntity, context)
end

function TileEntityInfo.styler:NameAndIcon(tileEntity, context)

    if((context.edition == EDITION.JAVA or context.edition == EDITION.CONSOLE) and tileEntity:contains("id", TYPE.STRING)) then

        local dbEntry = Database:find(context.edition, "tile_entities", tileEntity.lastFound.value)
        if(not dbEntry.valid) then return end
        local tileEntityName = dbEntry.name

        tileEntity.info.baseName = tileEntityName

        tileEntityName = tileEntityName:gsub("[^%w]+", "")
        tileEntity.info.iconPath = tileEntityName
    end

    if(context.edition == EDITION.BEDROCK) then

        local tileEntityid = ""

        if(tileEntity:contains("identifier", TYPE.STRING)) then
            tileEntityid = tileEntity.lastFound.value
        elseif(tileEntity:contains("id", TYPE.STRING)) then
            tileEntityid = tileEntity.lastFound.value
        elseif(tileEntity:contains("id", TYPE.INT)) then
            tileEntityid = tostring(tileEntity.lastFound.value & 255)
        else return end

        local dbEntry = Database:find(context.edition, "tile_entities", tileEntityid)
        if(not dbEntry.valid) then return end

        local tileEntityName = dbEntry.name
        tileEntity.info.baseName = tileEntityName

        tileEntityName = tileEntityName:gsub("%s+", "")
        tileEntity.info.iconPath = tileEntityName
    end
end

function TileEntityInfo.styler:CustomName(tileEntity, context)

    if((context.edition == EDITION.JAVA or context.edition == EDITION.CONSOLE)) then

        local customName = self:getCustomNameJava(tileEntity)
        if(customName ~= "") then
            tileEntity.info.customName = customName
        end

    elseif(context.edition == EDITION.BEDROCK) then

        if(tileEntity:contains("CustomName", TYPE.STRING)) then
            if(customName ~= "") then
                tileEntity.info.customName = tileEntity.lastFound.value
            end
        end
    end
end

-- TILE ENTITY SPECIFIC

function TileEntityInfo.styler:RunTileEntitySpecifics(tileEntity, context)

    local entityName = ""

    if((context.edition == EDITION.JAVA or context.edition == EDITION.CONSOLE) and tileEntity:contains("id", TYPE.STRING)) then

        local dbEntry = Database:find(context.edition, "tile_entities", tileEntity.lastFound.value)
        if(not dbEntry.valid) then return end

        entityName = dbEntry.name:gsub("[^%w]+", "")
    end

    if(context.edition == EDITION.BEDROCK) then

        local tileEntityid = ""

        if(tileEntity:contains("identifier", TYPE.STRING)) then tileEntityid = tileEntity.lastFound.value
        elseif(tileEntity:contains("id", TYPE.STRING)) then tileEntityid = tileEntity.lastFound.value
        elseif(tileEntity:contains("id", TYPE.INT)) then tileEntityid = tostring(tileEntity.lastFound.value & 255)
        else return end

        local dbEntry = Database:find(context.edition, "tile_entities", tileEntityid)
        if(not dbEntry.valid) then return end

        entityName = dbEntry.name:gsub("%s+", "")
    end

    if(self[entityName] == nil) then return end
    self[entityName](self, tileEntity, context)
end

function TileEntityInfo.styler:Barrel(tileEntity, context)

    if(tileEntity:contains("Items", TYPE.LIST, TYPE.COMPOUND)) then
        local itemCount = tileEntity.lastFound.childCount

        if(itemCount == 0) then
            tileEntity.info.state = "Empty"
        elseif(itemCount == 1) then
            tileEntity.info.state = itemCount .. " item"
        elseif(itemCount > 1) then
            tileEntity.info.state = itemCount .. " items"
        end
    end
end

function TileEntityInfo.styler:Beacon(tileEntity, context) -- revise active effect lookup. 4x duplicate code. make a func?

    if(context.edition == EDITION.JAVA or context.edition == EDITION.CONSOLE) then

        if(tileEntity:contains("Primary", TYPE.INT)) then

            local effectId = tileEntity.lastFound

            if(effectId.value == -1) then
                Style:setLabel(effectId, "No effect")
            else
                local dbEntry = Database:find(context.edition, "active_effects", tostring(effectId.value))

                if(dbEntry.valid) then

                    local effectName = dbEntry.name
                    tileEntity.info.state = dbEntry.name

                    Style:setLabel(effectId, effectName)
                    effectName = effectName:gsub("[^%w]+", "")
                    Style:setIcon(effectId, "TileEntityInfo/images/effects/" .. effectName .. ".png")
                end
            end
        end

        if(tileEntity:contains("Secondary", TYPE.INT)) then

            local effectId = tileEntity.lastFound

            if(effectId.value == -1) then
                Style:setLabel(effectId, "No effect")
                
                if(tileEntity.info.state == nil) then
                    tileEntity.info.state = "No effects"
                end
            else
                local dbEntry = Database:find(context.edition, "active_effects", tostring(effectId.value))

                if(dbEntry.valid) then

                    local effectName = dbEntry.name

                    if(effectName == tileEntity.info.state) then
                        tileEntity.info.state = tileEntity.info.state .. " 2"
                    elseif(tileEntity.info.state ~= nil) then
                        tileEntity.info.state = tileEntity.info.state .. " & " .. effectName
                    else
                        tileEntity.info.state = effectName
                    end

                    Style:setLabel(effectId, effectName)
                    effectName = effectName:gsub("[^%w]+", "")
                    Style:setIcon(effectId, "TileEntityInfo/images/effects/" .. effectName .. ".png")
                end
            end
        end

    elseif(context.edition == EDITION.BEDROCK) then

        if(tileEntity:contains("primary", TYPE.INT)) then

            local effectId = tileEntity.lastFound

            if(effectId.value == 0) then
                Style:setLabel(effectId, "No effect")
            else
                local dbEntry = Database:find(context.edition, "active_effects", tostring(effectId.value))

                if(dbEntry.valid) then

                    local effectName = dbEntry.name
                    tileEntity.info.state = dbEntry.name

                    Style:setLabel(effectId, effectName)
                    effectName = effectName:gsub("[^%w]+", "")
                    Style:setIcon(effectId, "TileEntityInfo/images/effects/" .. effectName .. ".png")
                end
            end
        end

        if(tileEntity:contains("secondary", TYPE.INT)) then

            local effectId = tileEntity.lastFound

            if(effectId.value == 0) then
                Style:setLabel(effectId, "No effect")
            else
                local dbEntry = Database:find(context.edition, "active_effects", tostring(effectId.value))

                if(dbEntry.valid) then

                    local effectName = dbEntry.name

                    if(effectName == tileEntity.info.state) then
                        tileEntity.info.state = tileEntity.info.state .. " 2"
                    elseif(tileEntity.info.state ~= nil) then
                        tileEntity.info.state = tileEntity.info.state .. " & " .. effectName
                    else
                        tileEntity.info.state = effectName
                    end

                    Style:setLabel(effectId, effectName)
                    effectName = effectName:gsub("[^%w]+", "")
                    Style:setIcon(effectId, "TileEntityInfo/images/effects/" .. effectName .. ".png")
                end
            end
        end
    end
end

function TileEntityInfo.styler:BlastFurnace(tileEntity, context)

    if(context.edition == EDITION.JAVA or context.edition == EDITION.BEDROCK) then

        if(tileEntity:contains("BurnTime", TYPE.SHORT)) then

            local burnTime = tileEntity.lastFound

            if(burnTime.value > 0) then
                Style:setLabel(burnTime, "Current fuel depletes in " .. self:ticksToTime(burnTime.value))

                tileEntity.info.iconPath = "BlastFurnace/On"
                tileEntity.info.state = "Lit"
            end

        end

        if(tileEntity:contains("CookTime", TYPE.SHORT)) then

            local cookTime = tileEntity.lastFound

            if(cookTime.value > 0) then
                Style:setLabel(cookTime, "Smelts item in " .. self:ticksToTime(100 - cookTime.value))
            end

        end
    end
end

function TileEntityInfo.styler:Beehive(tileEntity, context)

    if(context.edition == EDITION.JAVA) then

        if(tileEntity:contains("Bees", TYPE.LIST, TYPE.COMPOUND)) then
            local beeList = tileEntity.lastFound
            local beeCount = beeList.childCount

            if(beeCount == 0) then
                tileEntity.info.state = "Vacant"
            elseif(beeCount == 1) then
                tileEntity.info.state = beeCount .. " Bee"
            elseif(beeCount > 1) then
                tileEntity.info.state = beeCount .. " Bees"
            end

            for i=0, beeList.childCount-1 do
                local beeContainer = beeList:child(i)
                local minTicks = nil

                if(beeContainer:contains("MinOccupationTicks", TYPE.INT)) then
                    minTicks = beeContainer.lastFound.value
                    Style:setLabel(beeContainer.lastFound, self:ticksToTime(minTicks))
                end

                if(beeContainer:contains("TicksInHive", TYPE.INT)) then
                    local hiveTicks = beeContainer.lastFound.value
                    local text = "Can exit hive"

                    if(minTicks > 0 and hiveTicks > 0 and minTicks > hiveTicks) then
                        text = text .. " in " .. self:ticksToTime(minTicks - hiveTicks)
                    end

                    Style:setLabel(beeContainer.lastFound, text)
                end
            end
        end

        if(tileEntity:contains("FlowerPos", TYPE.COMPOUND)) then

            if(tileEntity.lastFound.childCount == 3) then
                local pos = tileEntity.lastFound
    
                Style:setLabel(pos, "X:" .. tostring(math.floor(pos:child(0).value + 0.5)) .. ", Y:" .. tostring(math.floor(pos:child(1).value + 0.5)) .. ", Z:" .. tostring(math.floor(pos:child(2).value + 0.5)))
                Style:setLabelColor(pos, "#bfbfbf")
            end
        end

    elseif(context.edition == EDITION.BEDROCK) then

        if(tileEntity:contains("Occupants", TYPE.LIST, TYPE.COMPOUND)) then
            local beeList = tileEntity.lastFound
            local beeCount = beeList.childCount

            if(beeCount == 1) then
                tileEntity.info.state = beeCount .. " Bee"
            elseif(beeCount > 1) then
                tileEntity.info.state = beeCount .. " Bees"
            end

            for i=0, beeList.childCount-1 do
                local beeContainer = beeList:child(i)
                
                if(beeContainer:contains("TicksLeftToStay", TYPE.INT)) then
                    local ticksLeft = beeContainer.lastFound.value
                    local text = "Can exit hive"

                    if(ticksLeft > 0) then
                        text = text .. " in " .. self:ticksToTime(ticksLeft)
                    end

                    Style:setLabel(beeContainer.lastFound, text)
                end
            end
        end

    end
end

function TileEntityInfo.styler:BrewingStand(tileEntity, context)

    if(context.edition == EDITION.JAVA) then

        if(tileEntity:contains("Fuel", TYPE.BYTE)) then
            local fuel = tileEntity.lastFound

            if(fuel.value > 0 and fuel.value <= 20) then
                Style:setLabel(fuel, fuel.value .. "/20 uses left")
            end
        end

        if(tileEntity:contains("BrewTime", TYPE.SHORT)) then
            local ticks = tileEntity.lastFound

            if(ticks.value > 0) then
                Style:setLabel(ticks, "Brews potion in " .. self:ticksToTime(ticks.value))
                tileEntity.info.state = "Lit"
            end
        end

    elseif(context.edition == EDITION.BEDROCK) then

        if(tileEntity:contains("FuelAmount", TYPE.SHORT)) then
            local fuel = tileEntity.lastFound

            if(fuel.value > 0 and fuel.value <= 20) then
                Style:setLabel(fuel, fuel.value .. "/20 uses left")
            end
        end

        if(tileEntity:contains("CookTime", TYPE.SHORT)) then
            local ticks = tileEntity.lastFound

            if(ticks.value > 0) then
                Style:setLabel(ticks, "Brews potion in " .. self:ticksToTime(ticks.value))
                tileEntity.info.state = "Lit"
            end
        end

    elseif(context.edition == EDITION.CONSOLE) then

        if(tileEntity:contains("Fuel", TYPE.SHORT)) then
            local fuel = tileEntity.lastFound

            if(fuel.value > 0 and fuel.value <= 20) then
                Style:setLabel(fuel, fuel.value .. "/20 uses left")
            end
        end

        if(tileEntity:contains("BrewTime", TYPE.SHORT)) then
            local ticks = tileEntity.lastFound

            if(ticks.value > 0) then
                Style:setLabel(ticks, "Brews potion in " .. self:ticksToTime(ticks.value))
                tileEntity.info.state = "Lit"
            end
        end

    end
end

function TileEntityInfo.styler:Campfire(tileEntity, context)

    if(context.edition == EDITION.JAVA) then

        if(tileEntity:contains("CookingTimes", TYPE.INT_ARRAY)) then
            local times = tileEntity.lastFound

            if(times.size == 16) then
                if(times:getInt(0) ~= 0) then times.a = self:ticksToTime(times:getInt(0)) else times.a = "Empty" end
                if(times:getInt(4) ~= 0) then times.b = self:ticksToTime(times:getInt(4)) else times.b = "Empty" end
                if(times:getInt(8) ~= 0) then times.c = self:ticksToTime(times:getInt(8)) else times.c = "Empty" end
                if(times:getInt(12) ~= 0) then times.d = self:ticksToTime(times:getInt(12)) else times.d = "Empty" end

                Style:setLabel(times, "Cooking for (" .. times.a .. " / " .. times.b .. " / " .. times.c .. " / " .. times.d .. ")")
                Style:setLabelColor(times, "#bfbfbf")
            end
        end

        if(tileEntity:contains("CookingTotalTimes", TYPE.INT_ARRAY)) then
            local times = tileEntity.lastFound

            if(times.size == 16) then
                if(times:getInt(0) ~= 0) then times.a = self:ticksToTime(times:getInt(0)) else times.a = "Empty" end
                if(times:getInt(4) ~= 0) then times.b = self:ticksToTime(times:getInt(4)) else times.b = "Empty" end
                if(times:getInt(8) ~= 0) then times.c = self:ticksToTime(times:getInt(8)) else times.c = "Empty" end
                if(times:getInt(12) ~= 0) then times.d = self:ticksToTime(times:getInt(12)) else times.d = "Empty" end

                Style:setLabel(times, "Cooks at (" .. times.a .. " / " .. times.b .. " / " .. times.c .. " / " .. times.d .. ")")
                Style:setLabelColor(times, "#bfbfbf")
            end
        end

    elseif(context.edition == EDITION.BEDROCK) then

        for i=1, 4 do
            if(tileEntity:contains("ItemTime" .. tostring(i), TYPE.INT)) then
                local ticks = tileEntity.lastFound.value

                if(ticks > 0) then
                    Style:setLabel(tileEntity.lastFound, "Cooking for " .. self:ticksToTime(ticks))
                end
            end
        end

    end
end

function TileEntityInfo.styler:Chest(tileEntity, context)

    if(tileEntity:contains("Items", TYPE.LIST, TYPE.COMPOUND)) then
        local itemCount = tileEntity.lastFound.childCount

        if(itemCount == 0) then
            tileEntity.info.state = "Empty"
        elseif(itemCount == 1) then
            tileEntity.info.state = itemCount .. " item"
        elseif(itemCount > 1) then
            tileEntity.info.state = itemCount .. " items"
        end
    end
end

function TileEntityInfo.styler:CommandBlock(tileEntity, context)

    if(context.edition == EDITION.JAVA or context.edition == EDITION.BEDROCK) then

        if(tileEntity:contains("Command", TYPE.STRING)) then
            local command = tileEntity.lastFound.value

            if(command ~= "") then
                tileEntity.info.state = command:gsub("(.)%s.*$","%1")
            end
            
        end

    end
end

function TileEntityInfo.styler:Comparator(tileEntity, context)

    if(tileEntity:contains("OutputSignal", TYPE.INT)) then
        local output = tileEntity.lastFound.value

        if(output > 0 and output <= 15) then
            tileEntity.info.state = "On"
            tileEntity.info.iconPath = "Comparator/On"
        end
    end
end

function TileEntityInfo.styler:Dispenser(tileEntity, context)

    if(tileEntity:contains("Items", TYPE.LIST, TYPE.COMPOUND)) then
        local itemCount = tileEntity.lastFound.childCount

        if(itemCount == 0) then
            tileEntity.info.state = "Empty"
        elseif(itemCount == 1) then
            tileEntity.info.state = itemCount .. " item"
        elseif(itemCount > 1) then
            tileEntity.info.state = itemCount .. " items"
        end
    end
end

function TileEntityInfo.styler:Dropper(tileEntity, context)

    if(tileEntity:contains("Items", TYPE.LIST, TYPE.COMPOUND)) then
        local itemCount = tileEntity.lastFound.childCount

        if(itemCount == 0) then
            tileEntity.info.state = "Empty"
        elseif(itemCount == 1) then
            tileEntity.info.state = itemCount .. " item"
        elseif(itemCount > 1) then
            tileEntity.info.state = itemCount .. " items"
        end
    end
end

function TileEntityInfo.styler:EndGateway(tileEntity, context)

    if(context.edition == EDITION.JAVA or context.edition == EDITION.CONSOLE) then

        if(tileEntity:contains("ExitPortal", TYPE.COMPOUND)) then

            if(tileEntity.lastFound.childCount == 3) then
                local pos = tileEntity.lastFound
    
                Style:setLabel(pos, "X:" .. tostring(math.floor(pos:child(0).value + 0.5)) .. ", Y:" .. tostring(math.floor(pos:child(1).value + 0.5)) .. ", Z:" .. tostring(math.floor(pos:child(2).value + 0.5)))
                Style:setLabelColor(pos, "#bfbfbf")
            end
        end

        if(tileEntity:contains("Age", TYPE.LONG)) then
            local age = tileEntity.lastFound.value

            if(age > 0) then
                Style:setLabel(tileEntity.lastFound, self:ticksToTime(age))
            end
        end

    elseif(context.edition == EDITION.BEDROCK) then

        if(tileEntity:contains("ExitPortal", TYPE.LIST, TYPE.INT)) then

            if(tileEntity.lastFound.childCount == 3) then
                local pos = tileEntity.lastFound
    
                Style:setLabel(pos, "X:" .. tostring(math.floor(pos:child(0).value + 0.5)) .. ", Y:" .. tostring(math.floor(pos:child(1).value + 0.5)) .. ", Z:" .. tostring(math.floor(pos:child(2).value + 0.5)))
                Style:setLabelColor(pos, "#bfbfbf")
            end
        end

        if(tileEntity:contains("Age", TYPE.INT)) then
            local age = tileEntity.lastFound.value

            if(age > 0) then
                Style:setLabel(tileEntity.lastFound, self:ticksToTime(age))
            end
        end

    end
end

function TileEntityInfo.styler:Furnace(tileEntity, context)

    if(tileEntity:contains("BurnTime", TYPE.SHORT)) then
        local burnTime = tileEntity.lastFound

        if(burnTime.value > 0) then
            Style:setLabel(burnTime, "Current fuel depletes in " .. self:ticksToTime(burnTime.value))

            tileEntity.info.iconPath = "Furnace/On"
            tileEntity.info.state = "Lit"
        end

    end

    if(tileEntity:contains("CookTime", TYPE.SHORT)) then
        local cookTime = tileEntity.lastFound

        if(cookTime.value > 0) then
            Style:setLabel(cookTime, "Smelts item in " .. self:ticksToTime(100 - cookTime.value))
        end
    end
end

function TileEntityInfo.styler:Hopper(tileEntity, context)

    if(tileEntity:contains("TransferCooldown", TYPE.INT)) then
        local ticks = tileEntity.lastFound

        if(ticks.value > 0) then
            Style:setLabel(ticks, self:ticksToTime(ticks.value))
        end
    end

    if(tileEntity:contains("Items", TYPE.LIST, TYPE.COMPOUND)) then
        local itemCount = tileEntity.lastFound.childCount

        if(itemCount == 0) then
            tileEntity.info.state = "Empty"
        elseif(itemCount == 1) then
            tileEntity.info.state = itemCount .. " item"
        elseif(itemCount > 1) then
            tileEntity.info.state = itemCount .. " items"
        end
    end

end

function TileEntityInfo.styler:Jukebox(tileEntity, context)

    if(context.edition == EDITION.JAVA or context.edition == EDITION.CONSOLE) then
        local totalTicks = nil

        if(tileEntity:contains("TickCount", TYPE.LONG)) then
            totalTicks = tileEntity.lastFound

            if(totalTicks.value > 0) then
                Style:setLabel(totalTicks, self:ticksToTime(totalTicks.value))
            end
        end

        if(tileEntity:contains("RecordStartTick", TYPE.LONG)) then
            ticks = tileEntity.lastFound

            if(totalTicks.value > 0) then
                Style:setLabel(ticks, self:ticksToTime(totalTicks.value - ticks.value))
            end
        end

    end
end

function TileEntityInfo.styler:MobHead(tileEntity, context)

    if(context.edition == EDITION.BEDROCK) then

        if(tileEntity:contains("Rotation", TYPE.FLOAT)) then

            local rot = tileEntity.lastFound
            local facing = nil

            if(rot.value > 337.5 or rot.value <= 22.5) then facing = "Facing North"
            elseif(rot.value > 22.5 and rot.value <= 67.5) then facing = "Facing North-East"
            elseif(rot.value > 67.5 and rot.value <= 112.5) then facing = "Facing East"
            elseif(rot.value > 112.5 and rot.value <= 157.5) then facing = "Facing South-East"
            elseif(rot.value > 157.5 and rot.value <= 202.5) then facing = "Facing South"
            elseif(rot.value > 202.5 and rot.value <= 247.5) then facing = "Facing South-West"
            elseif(rot.value > 247.5 and rot.value <= 292.5) then facing = "Facing West"
            elseif(rot.value > 292.5 and rot.value <= 337.5) then facing = "Facing North-West"
            end

            if(facing ~= nil) then
                Style:setLabel(rot, facing)
            end
            
        end

        if(tileEntity:contains("SkullType", TYPE.BYTE)) then
            local skull = tileEntity.lastFound
            local skullType = nil

            if(skull.value == 0) then skullType = "Skeleton"
            elseif(skull.value == 1) then skullType = "Wither Skeleton"
            elseif(skull.value == 2) then skullType = "Zombie"
            elseif(skull.value == 3) then skullType = "Steve"
            elseif(skull.value == 4) then skullType = "Creeper"
            elseif(skull.value == 5) then skullType = "Ender Dragon"
            elseif(skull.value == 6) then skullType = "Piglin"
            end

            if(skullType ~= nil) then
                tileEntity.info.state = skullType

                skullType = skullType:gsub("[^%w]+", "")
                tileEntity.info.iconPath = "Skull/" .. skullType
            end
        end

    end
end

function TileEntityInfo.styler:Spawner(tileEntity, context)

    if(context.edition == EDITION.JAVA or context.edition == EDITION.CONSOLE) then

        if(tileEntity:contains("MaxSpawnDelay", TYPE.SHORT)) then
            local ticks = tileEntity.lastFound

            if(ticks.value > 0) then
                Style:setLabel(ticks, self:ticksToTime(ticks.value))
            end
        end

        if(tileEntity:contains("MinSpawnDelay", TYPE.SHORT)) then
            local ticks = tileEntity.lastFound

            if(ticks.value > 0) then
                Style:setLabel(ticks, self:ticksToTime(ticks.value))
            end
        end

        if(tileEntity:contains("Delay", TYPE.SHORT)) then
            local ticks = tileEntity.lastFound

            if(ticks.value > 0) then
                Style:setLabel(ticks, "Spawns mobs in " .. self:ticksToTime(ticks.value))
            end
        end

        if(tileEntity:contains("SpawnData", TYPE.COMPOUND)) then
            local spawnData = tileEntity.lastFound

            if(spawnData:contains("entity", TYPE.COMPOUND)) then
                local entity = spawnData.lastFound
                
                if(entity:contains("id", TYPE.STRING)) then

                    local dbEntry = Database:find(context.edition, "entities", entity.lastFound.value)
                    if(not dbEntry.valid) then return end

                    tileEntity.info.state = dbEntry.name
                end
            end
        end

    elseif(context.edition == EDITION.BEDROCK) then

        if(tileEntity:contains("MaxSpawnDelay", TYPE.SHORT)) then
            local ticks = tileEntity.lastFound

            if(ticks.value > 0) then
                Style:setLabel(ticks, self:ticksToTime(ticks.value))
            end
        end

        if(tileEntity:contains("MinSpawnDelay", TYPE.SHORT)) then
            local ticks = tileEntity.lastFound

            if(ticks.value > 0) then
                Style:setLabel(ticks, self:ticksToTime(ticks.value))
            end
        end

        if(tileEntity:contains("Delay", TYPE.SHORT)) then
            local ticks = tileEntity.lastFound

            if(ticks.value > 0) then
                Style:setLabel(ticks, "Spawns mobs in " .. self:ticksToTime(ticks.value))
            end
        end

        if(tileEntity:contains("EntityIdentifier", TYPE.STRING)) then

            local dbEntry = Database:find(context.edition, "entities", tileEntity.lastFound.value)
            if(not dbEntry.valid) then return end

            tileEntity.info.state = dbEntry.name

        end

    end
end

function TileEntityInfo.styler:Piston(tileEntity, context)

    if(context.edition == EDITION.JAVA) then

        if(tileEntity:contains("facing", TYPE.INT)) then
            local facing = tileEntity.lastFound.value
            local text = nil

            if(facing == 0) then text = "Down"
            elseif(facing == 1) then text = "Up"
            elseif(facing == 2) then text = "North"
            elseif(facing == 3) then text = "South"
            elseif(facing == 4) then text = "West"
            elseif(facing == 5) then text = "East"
            end

            if(text ~= nil) then
                Style:setLabel(tileEntity.lastFound, text)
            end
        end
    end
end

function TileEntityInfo.styler:ShulkerBox(tileEntity, context)

    if(tileEntity:contains("Items", TYPE.LIST, TYPE.COMPOUND)) then
        local itemCount = tileEntity.lastFound.childCount

        if(itemCount == 0) then
            tileEntity.info.state = "Empty"
        elseif(itemCount == 1) then
            tileEntity.info.state = itemCount .. " item"
        elseif(itemCount > 1) then
            tileEntity.info.state = itemCount .. " items"
        end
    else
        tileEntity.info.state = "Empty"
    end

    if(tileEntity:contains("facing", TYPE.BYTE)) then
        local facing = tileEntity.lastFound.value
        local text = nil

        if(facing == 0) then text = "Down"
        elseif(facing == 1) then text = "Up"
        elseif(facing == 2) then text = "North"
        elseif(facing == 3) then text = "South"
        elseif(facing == 4) then text = "West"
        elseif(facing == 5) then text = "East"
        end

        if(text ~= nil) then
            Style:setLabel(tileEntity.lastFound, "Opens " .. text)
        end
    end
end

function TileEntityInfo.styler:Smoker(tileEntity, context)

    if(context.edition == EDITION.JAVA or context.edition == EDITION.BEDROCK) then

        if(tileEntity:contains("BurnTime", TYPE.SHORT)) then

            local burnTime = tileEntity.lastFound

            if(burnTime.value > 0) then
                Style:setLabel(burnTime, "Current fuel depletes in " .. self:ticksToTime(burnTime.value))

                tileEntity.info.iconPath = "Smoker/On"
                tileEntity.info.state = "Lit"
            end

        end

        if(tileEntity:contains("CookTime", TYPE.SHORT)) then

            local cookTime = tileEntity.lastFound

            if(cookTime.value > 0) then
                Style:setLabel(cookTime, "Smelts item in " .. self:ticksToTime(100 - cookTime.value))
            end

        end
    end
end

function TileEntityInfo.styler:SoulCampfire(tileEntity, context)

    if(context.edition == EDITION.JAVA) then

        if(tileEntity:contains("CookingTimes", TYPE.INT_ARRAY)) then
            local times = tileEntity.lastFound

            if(times.size == 16) then
                if(times:getInt(0) ~= 0) then times.a = self:ticksToTime(times:getInt(0)) else times.a = "Empty" end
                if(times:getInt(4) ~= 0) then times.b = self:ticksToTime(times:getInt(4)) else times.b = "Empty" end
                if(times:getInt(8) ~= 0) then times.c = self:ticksToTime(times:getInt(8)) else times.c = "Empty" end
                if(times:getInt(12) ~= 0) then times.d = self:ticksToTime(times:getInt(12)) else times.d = "Empty" end

                Style:setLabel(times, "Cooking for (" .. times.a .. " / " .. times.b .. " / " .. times.c .. " / " .. times.d .. ")")
                Style:setLabelColor(times, "#bfbfbf")
            end
        end

        if(tileEntity:contains("CookingTotalTimes", TYPE.INT_ARRAY)) then
            local times = tileEntity.lastFound

            if(times.size == 16) then
                if(times:getInt(0) ~= 0) then times.a = self:ticksToTime(times:getInt(0)) else times.a = "Empty" end
                if(times:getInt(4) ~= 0) then times.b = self:ticksToTime(times:getInt(4)) else times.b = "Empty" end
                if(times:getInt(8) ~= 0) then times.c = self:ticksToTime(times:getInt(8)) else times.c = "Empty" end
                if(times:getInt(12) ~= 0) then times.d = self:ticksToTime(times:getInt(12)) else times.d = "Empty" end

                Style:setLabel(times, "Cooks at (" .. times.a .. " / " .. times.b .. " / " .. times.c .. " / " .. times.d .. ")")
                Style:setLabelColor(times, "#bfbfbf")
            end
        end

    elseif(context.edition == EDITION.BEDROCK) then

        for i=1, 4 do
            if(tileEntity:contains("ItemTime" .. tostring(i), TYPE.INT)) then
                local ticks = tileEntity.lastFound.value

                if(ticks > 0) then
                    Style:setLabel(tileEntity.lastFound, "Cooking for " .. self:ticksToTime(ticks))
                end
            end
        end

    end
end

-- 1.20

function TileEntityInfo.styler:ChiseledBookshelf(tileEntity, context)

    if(context.edition == EDITION.JAVA) then

        if(tileEntity:contains("Items", TYPE.LIST, TYPE.COMPOUND)) then
            local items = tileEntity.lastFound.childCount

            if(items == 1) then
                tileEntity.info.state = items .. " Book"
                tileEntity.info.iconPath = "ChiseledBookshelf/" .. items
            elseif(items > 1 and items <= 6) then
                tileEntity.info.iconPath = "ChiseledBookshelf/" .. items
                tileEntity.info.state = items .. " Books"
            end
        end

    elseif(context.edition == EDITION.BEDROCK) then

        if(tileEntity:contains("Items", TYPE.LIST, TYPE.COMPOUND)) then
            local items = tileEntity.lastFound
            local itemCount = 0

            for i=0, items.childCount-1 do
                local item = items:child(i)

                if(item:contains("Count", TYPE.BYTE) and item.lastFound.value > 0) then itemCount = itemCount+1 end
            end

            if(itemCount == 1) then
                tileEntity.info.state = itemCount .. " Book"
                tileEntity.info.iconPath = "ChiseledBookshelf/" .. itemCount
            elseif(itemCount > 1 and itemCount <= 6) then
                tileEntity.info.iconPath = "ChiseledBookshelf/" .. itemCount
                tileEntity.info.state = itemCount .. " Books"
            end
        end
    end
end

function TileEntityInfo.styler:BrushableBlock(tileEntity, context)

    if(context.edition == EDITION.BEDROCK) then

        if(tileEntity:contains("type", TYPE.STRING)) then
            local Type = tileEntity.lastFound.value
            local block = ""

            if(Type == "minecraft:suspicious_sand") then block = "Sand"
            elseif(Type == "minecraft:suspicious_gravel") then block = "Gravel"
            end

            if(block ~= "") then
                tileEntity.info.baseName = "Suspicious " .. block
                tileEntity.info.iconPath = "BrushableBlock/" .. block
            end
        end

        if(tileEntity:contains("brush_direction", TYPE.BYTE)) then
            local directionIndex = tileEntity.lastFound.value
            local direction = ""

            if(directionIndex == 0) then direction = "Down"
            elseif(directionIndex == 1) then direction = "Up"
            elseif(directionIndex == 2) then direction = "North"
            elseif(directionIndex == 3) then direction = "South"
            elseif(directionIndex == 4) then direction = "West"
            elseif(directionIndex == 5) then direction = "East"
            elseif(directionIndex == 6) then direction = "Inactive"
            end

            if(direction ~= "") then
                Style:setLabel(tileEntity.lastFound, direction)
            end
        end
    end
end

function TileEntityInfo.styler:DecoratedPot(tileEntity, context)

    if(tileEntity:contains("sherds", TYPE.LIST, TYPE.STRING)) then
        local sherds = tileEntity.lastFound
        for i=0, sherds.childCount-1 do
            local sherd = sherds:child(i).value
            
            if(sherd == "") then sherd = "minecraft:brick" end
            if(sherd:find("^minecraft:")) then sherd = sherd:sub(11) end
            sherd = string.gsub(sherd, "_pottery_sherd", "")

            Style:setIcon(sherds:child(i), "TileEntityInfo/images/DecoratedPot/" .. sherd .. ".png")
        end
    end
end

-- FINALIZE

function TileEntityInfo.styler:BuildLabel(tileEntity, context)

    --[[
    tileEntity.info.baseName
    tileEntity.info.customName
    tileEntity.info.state
    ]]

    local text = tileEntity.info.baseName

    if(tileEntity.info.state ~= nil) then
        text = text .. " (" .. tileEntity.info.state .. ")"
    end

    if(tileEntity.info.customName ~= nil and tileEntity.info.customName:len() > 0) then
        text = text .. " \"" .. tileEntity.info.customName .. "\""
    end
    
    Style:setLabel(tileEntity, text)
    Style:setLabelColor(tileEntity, "#bfbfbf")
    Style:setIcon(tileEntity, "TileEntityInfo/images/" .. tileEntity.info.iconPath .. ".png")
end

return TileEntityInfo