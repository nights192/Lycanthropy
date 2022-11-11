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
Lycanthropy.checkInterval = time.seconds(5)

Lycanthropy.activePids = {}

Lycanthropy.transformCharacters = function()
    for _, pid in ipairs(Lycanthropy.activePids) do
        local ply = Players[pid]
        
        if not tes3mp.IsWerewolf(pid) then
            -- hash lookups are comparatively more expensive than this; hence, we lead with a check
            -- to ensure the operation remains necessary.
            local lycanthrope = Lycanthropy.data.lycanthropes[ply.name]

            if lycanthrope ~= nil then
                tes3mp.LogAppend(enumerations.log.INFO, "They are, transforming!")
                ply:SetWerewolfState(true)
                ply:LoadShapeshift()
            end
        end
    end
end

Lycanthropy.revertCharacters = function()
    for _, pid in ipairs(Lycanthropy.activePids) do
        local ply = Players[pid]

        if tes3mp.IsWerewolf(pid) then
            -- hash lookups are comparatively more expensive than this; hence, we lead with a check
            -- to ensure the operation remains necessary.
            local lycanthrope = Lycanthropy.data.lycanthropes[ply.name]
            
            if lycanthrope ~= nil then
                ply:SetWerewolfState(false)
                ply:LoadShapeshift()
            end
        end
    end
end

function LycanthropeCheckTransformationTimes()
    local currentTime = WorldInstance.data.time.hour

    if (currentTime >= 6 and currentTime < 22) then -- Should we be human...
        Lycanthropy.revertCharacters()
    else
        Lycanthropy.transformCharacters()
    end

    tes3mp.LogAppend(enumerations.log.INFO, currentTime)
    tes3mp.RestartTimer(Lycanthropy.CheckTransformationTimer, Lycanthropy.checkInterval)
end

Lycanthropy.CheckTransformationTimer = tes3mp.CreateTimer("LycanthropeCheckTransformationTimes", Lycanthropy.checkInterval)
tes3mp.StartTimer(Lycanthropy.CheckTransformationTimer)

Lycanthropy.AddLycan = function(pid, cmd)
    if Players[pid]:IsAdmin() then
        tes3mp.LogAppend(enumerations.log.INFO, cmd[2])
        local targetPlayer = Players[tonumber(cmd[2])]

        Lycanthropy.data.lycanthropes[targetPlayer.name] = {}
        DataManager.saveData(Lycanthropy.scriptName, Lycanthropy.data)
    end
end

Lycanthropy.RemoveLycan = function(pid, cmd)
    if Players[pid]:IsAdmin() then
        tes3mp.LogAppend(enumerations.log.INFO, cmd[2])
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