-- TODO: HIRCINE'S RING SUPPORT.

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

-- CONSTANTS --
local RefIdHircine = "BM_ring_hircine"
local spellBloodLust = "werewolf hunger"

-- Time between werewolf transformation scans.
Lycanthropy.checkInterval = time.seconds(60)
-- END CONSTANTS --

Lycanthropy.ongoing = false
Lycanthropy.activePids = {}

Lycanthropy.genDefaultLycan = function()
    return {
        deathTimeout = false,
        bloodlust = false
    }
end

Lycanthropy.LycanthropeData = function(pid)
    return Lycanthropy.data.lycanthropes[Players[pid].name]
end

Lycanthropy.transformCharacters = function()
    local updatedCharacterFlags = false
    Lycanthropy.ongoing = true

    for _, pid in ipairs(Lycanthropy.activePids) do
        local ply = Players[pid]
        local isPlayerWerewolf = tes3mp.IsWerewolf(pid)
        local lycanthrope = Lycanthropy.LycanthropeData(pid)
        
        if not isPlayerWerewolf then
            if lycanthrope ~= nil then
                if not lycanthrope.deathTimeout then
                    ply:SetWerewolfState(true)
                    ply:LoadShapeshift()

                    -- TODO: Figure out a way to detect a Hircine's ring transformation. Apply the need for bloodlust.
                    updatedCharacterFlags = true
                    lycanthrope.bloodlust = true
                else
                    updatedCharacterFlags = true
                    lycanthrope.bloodlust = false
                    lycanthrope.deathTimeout = false
                end
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
        local lycanthrope = Lycanthropy.LycanthropeData(pid)

        if tes3mp.IsWerewolf(pid) then
            if lycanthrope ~= nil then
                ply:SetWerewolfState(false)
                ply:LoadShapeshift()
            end
        end

        if lycanthrope ~= nil then
            -- Applying bloodlust.
            if lycanthrope.bloodlust and not lycanthrope.deathTimeout then
                Lycanthropy.AddBL(pid)
            end
        end
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

Lycanthropy.CureAll = function()
    Lycanthropy.data.lycanthropes = {}

    for _, pid in ipairs(Lycanthropy.activePids) do
        local ply = Players[pid]

        ply:SetWerewolfState(false)
        ply:LoadShapeshift()
        Lycanthropy.RemoveBL(pid)
    end

    DataManager.saveData(Lycanthropy.scriptName, Lycanthropy.data)
end

Lycanthropy.AddBL = function(pid)
    if tableHelper.containsValue(Players[pid].data.spellbook, spellBloodLust) == false then
        table.insert(Players[pid].data.spellbook, spellBloodLust)

        tes3mp.ClearSpellbookChanges(pid)
        tes3mp.SetSpellbookChangesAction(pid, enumerations.spellbook.ADD)
        tes3mp.AddSpell(pid, spellBloodLust)
        tes3mp.SendSpellbookChanges(pid)

        tes3mp.MessageBox(pid, -1, "The wolf-blood stews in its languor; oh, how you hunger...")
    end
end

Lycanthropy.RemoveBL = function(pid)
    if tableHelper.containsValue(Players[pid].data.spellbook, spellBloodLust) == true then
        tableHelper.removeValue(Players[pid].data.spellbook, spellBloodLust)
        tableHelper.cleanNils(Players[pid].data.spellbook)

        tes3mp.ClearSpellbookChanges(pid)
        tes3mp.SetSpellbookChangesAction(pid, enumerations.spellbook.REMOVE)
        tes3mp.AddSpell(pid, spellBloodLust)
        tes3mp.SendSpellbookChanges(pid)
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

-- Simplified variant of bloodlust--player need merely be within the vicinity.
customEventHooks.registerHandler("OnActorDeath", function(eventStatus, pid, cellDescription, actors)
    for _, pid in ipairs(Lycanthropy.activePids) do
        local lycanthrope = Lycanthropy.LycanthropeData(pid)

        if lycanthrope ~= nil then
            for _, actor in pairs(actors) do
                if actor.killer.pid == pid then
                    lycanthrope.bloodlust = false
                    Lycanthropy.RemoveBL(pid)
                    DataManager.saveData(Lycanthropy.scriptName, Lycanthropy.data)

                    return
                end
            end
        end
    end
end)

-- Track whether or not a player has died as a werewolf, ensuring they do not shapeshift immediately in the default cell.
customEventHooks.registerHandler("OnPlayerDeath", function(event, pid)
    local lycan = Lycanthropy.data.lycanthropes[Players[pid].name]
    Lycanthropy.RemoveBL(pid)

    if lycan ~= nil then
        lycan.bloodlust = false

        if Lycanthropy.ongoing == true then
            lycan.deathTimeout = true
        end

        DataManager.saveData(Lycanthropy.scriptName, Lycanthropy.data)
    end
end)

-- Accounts for Bloodmoon question completion.
customEventHooks.registerHandler("OnPlayerJournal", function(eventStatus, pid, playerPacket)
    if config.shareJournal == true then
        for _, journalItem in ipairs(journal) do
            if journalItem.quest == "BM_WolfGiver" and journalItem.index == 120 then
                Lycanthropy.CureAll()
            end

            if journalItem.quest == "BM_Lycanthropycure" and journalItem.index == 20 then
                Lycanthropy.CureAll()
            end
        end
    end
end)

return Lycanthropy