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

Lycanthropy.transformCharacters = function()
    Lycanthropy.ongoing = true

    for _, pid in ipairs(Lycanthropy.activePids) do
        local ply = Players[pid]
        local isPlayerWerewolf = tes3mp.IsWerewolf(pid)
        local lycanthrope = Lycanthropy.data.lycanthropes[ply.name]
        
        if not isPlayerWerewolf then
            if lycanthrope ~= nil then
                ply:SetWerewolfState(true)
                ply:LoadShapeshift()
            end
        elseif lycanthrope == nil then -- Should we know the player is infected but not present in the database...
            Lycanthropy.data.lycanthropes[ply.name] = {}
            DataManager.saveData(Lycanthropy.scriptName, Lycanthropy.data)
        end
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
        if lycanthrope.deathTimeout then
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
        local targetPlayer = Players[tonumber(cmd[2])]

        Lycanthropy.data.lycanthropes[targetPlayer.name] = {
            deathTimeout = false,
            bloodlust = false
        }
        
        DataManager.saveData(Lycanthropy.scriptName, Lycanthropy.data)
    end
end

Lycanthropy.RemoveLycan = function(pid, cmd)
    if Players[pid]:IsAdmin() then
        local targetPlayer = Players[tonumber(cmd[2])]

        Lycanthropy.data.lycanthropes[targetPlayer.name] = nil
        DataManager.saveData(Lycanthropy.scriptName, Lycanthropy.data)
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
customEventHooks.registerHandler("OnPlayerDeath", function(pid)
    if Lycanthropy.ongoing == true then
        local lycan =  Lycanthropy.data.lycanthropes[Players[pid].name]

        lycan.deathTimeout = true
        lycan.bloodlust = false

        DataManager.saveData(Lycanthropy.scriptName, Lycanthropy.data)
    end
end)