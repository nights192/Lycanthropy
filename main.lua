-- TODO: Implement alternative werewolf scales.
-- TODO: Implement bloodlust mechanic.

-- DATA SETUP SECTION --
-- These must be global, as they are accessed asynchronously.
Lycanthropy = {}
Lycanthropy.scriptName = "Lycanthropy"

-- This DataManager instance tracks a list of the currently active werewolves in the game,
-- along with any miscellaneous per-character features.
Lycanthropy.defaultData = {
    lycanthropes = {}
}

Lycanthropy.data = DataManager.loadData("Lycanthropy", Lycanthropy.defaultData)
-- END DATA SETUP SECTION --

-- Time between werewolf transformation scans.
Lycanthropy.checkInterval = time.seconds(60)

Lycanthropy.ongoing = false
Lycanthropy.activePids = {}

Lycanthropy.genDefaultLycan = function()
    return {
        deathTimeout = false,
        bloodlust = false
    }
end

Lycanthropy.transformCharacters = function()
    local updatedCharacterFlags = false
    Lycanthropy.ongoing = true

    for _, pid in ipairs(Lycanthropy.activePids) do
        local ply = Players[pid]
        local isPlayerWerewolf = tes3mp.IsWerewolf(pid)
        local lycanthrope = Lycanthropy.data.lycanthropes[ply.name]
        
        if not isPlayerWerewolf then
            if lycanthrope ~= nil and not lycanthrope.deathTimeout then
                ply:SetWerewolfState(true)
                ply:LoadShapeshift()
            end
        elseif lycanthrope == nil then -- Should we know the player is infected but not present in the database...
            updatedCharacterFlags = true
            Lycanthropy.data.lycanthropes[ply.name] = Lycanthropy.genDefaultLycan()
        end
    end

    if updatedCharacterFlags then
        DataManager.saveData(Lycanthropy.scriptName, Lycanthropy.data)
    end
end

Lycanthropy.revertCharacters = function()
    local updatedCharacterFlags = false
    Lycanthropy.ongoing = false

    for _, pid in ipairs(Lycanthropy.activePids) do
        local ply = Players[pid]
        local lycanthrope = Lycanthropy.data.lycanthropes[ply.name]

        if tes3mp.IsWerewolf(pid) then
            if lycanthrope ~= nil then
                ply:SetWerewolfState(false)
                ply:LoadShapeshift()
            end
        end

        -- Updating werewolf flags.
        if lycanthrope ~= nil and lycanthrope.deathTimeout then
            updatedCharacterFlags = true
            lycanthrope.deathTimeout = false
        end

        -- TODO: Bloodlust logic!
    end

    if updatedCharacterFlags then
        DataManager.saveData(Lycanthropy.scriptName, Lycanthropy.data)
    end
end

function LycanthropeCheckTransformationTimes()
    local currentTime = WorldInstance.data.time.hour

    if (currentTime >= 6 and currentTime < 22) then -- Should we be human...
        Lycanthropy.revertCharacters()
    else
        Lycanthropy.transformCharacters()
    end

    tes3mp.RestartTimer(Lycanthropy.CheckTransformationTimer, Lycanthropy.checkInterval)
end

Lycanthropy.CheckTransformationTimer = tes3mp.CreateTimer("LycanthropeCheckTransformationTimes", Lycanthropy.checkInterval)
tes3mp.StartTimer(Lycanthropy.CheckTransformationTimer)

Lycanthropy.AddLycan = function(pid, cmd)
    if Players[pid]:IsAdmin() then
        if cmd[2] ~= nil then
            local targetPlayer = Players[tonumber(cmd[2])]

            Lycanthropy.data.lycanthropes[targetPlayer.name] = Lycanthropy.genDefaultLycan()
            DataManager.saveData(Lycanthropy.scriptName, Lycanthropy.data)
        else
            tes3mp.SendMessage(pid, "/addlycan (pid)\n", false)
        end
    end
end

Lycanthropy.RemoveLycan = function(pid, cmd)
    if Players[pid]:IsAdmin() then
        if cmd[2] ~= nil then
            local targetPlayer = Players[tonumber(cmd[2])]

            Lycanthropy.data.lycanthropes[targetPlayer.name] = nil
            DataManager.saveData(Lycanthropy.scriptName, Lycanthropy.data)
        else
            tes3mp.SendMessage(pid, "/removelycan (pid)\n", false)
        end
    end
end

customCommandHooks.registerCommand("addlycan", Lycanthropy.AddLycan)
customCommandHooks.registerCommand("removelycan", Lycanthropy.RemoveLycan)

customEventHooks.registerHandler("OnPlayerConnect", function(status, pid)
    table.insert(Lycanthropy.activePids, pid)
end)

customEventHooks.registerHandler("OnPlayerDisconnect", function(status, pid)
    for i, v in ipairs(Lycanthropy.activePids) do
        if v == pid then
            table.remove(Lycanthropy.activePids, i)

            break
        end
    end
end)    

-- Track whether or not a player has died as a werewolf, ensuring they do not shapeshift immediately in the default cell.
customEventHooks.registerHandler("OnPlayerDeath", function(event, pid)
    local lycan = Lycanthropy.data.lycanthropes[Players[pid].name]

    if Lycanthropy.ongoing == true and lycan ~= nil then
        lycan.deathTimeout = true
        lycan.bloodlust = false

        DataManager.saveData(Lycanthropy.scriptName, Lycanthropy.data)
    end
end)