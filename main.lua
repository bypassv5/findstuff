-- Auto-reinject on teleport
local scriptURL = "https://raw.githubusercontent.com/bypassv5/findstuff/main/main.lua"
if queue_on_teleport then
    queue_on_teleport("loadstring(game:HttpGet('"..scriptURL.."'))()")
end

local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Single webhook for all notifications
local webhookURL = "https://discord.com/api/webhooks/1398765862835458110/yPDUCwGfwrDAkV9y1LwKDbawWTUWLE6810Y2Dh732FnKG1UiIgLnsMrSAJ3-opRkAAHu"

local function sendWebhook(url, embed, content)
    local payloadTable = { embeds = { embed } }
    if content and content ~= "" then
        payloadTable.content = content
    end
    local payload = HttpService:JSONEncode(payloadTable)

    local req = (syn and syn.request) or http_request or (fluxus and fluxus.request)
    if not req then
        warn("No HTTP request function found.")
        return
    end

    pcall(function()
        req({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = payload
        })
    end)
end

local function buildEmbed(nameText, baseOwner, mutationText, traitAmount, generationText, generationValue)
    local fields = {
        { name = "Name", value = nameText or "?", inline = true },
        { name = "Owner", value = baseOwner or "?", inline = true },
        { name = "Mutation", value = mutationText or "Normal", inline = true },
        { name = "Trait Count", value = tostring(traitAmount or 0), inline = true },
        { name = "Generation", value = generationText or "?", inline = true },
    }

    return {
        title = "SECRET BRAINROT FOUND!",
        color = 0xE74C3C,
        fields = fields,
        footer = { text = "Finder Script" }
    }
end

-- Helper: parse a string like "10M", "500K", "3B", "$10 M/s", "1000000" into a number
local function parseGenerationText(txt)
    if not txt then return 0, "?" end
    local s = tostring(txt)
    s = s:gsub("%$", ""):gsub("/s", ""):gsub("%s+", "")
    local multipliers = { K = 1_000, M = 1_000_000, B = 1_000_000_000 }
    local last = s:sub(-1):upper()
    local numberPart
    if multipliers[last] then
        numberPart = tonumber(s:sub(1, -2)) or 0
        return numberPart * multipliers[last], s
    else
        local n = tonumber(s)
        if n then
            return n, s
        else
            return 0, s
        end
    end
end

local function findAndNotifySecrets()
    if not workspace:FindFirstChild("Plots") then return end
    local PlayerName = LocalPlayer and LocalPlayer.DisplayName

    for _, plot in ipairs(workspace.Plots:GetChildren()) do
        local sign = plot:FindFirstChild("PlotSign")
        if not sign then continue end

        local surf = sign:FindFirstChild("SurfaceGui")
        if not surf then continue end

        local frame = surf:FindFirstChild("Frame")
        if not frame then continue end

        local label = frame:FindFirstChild("TextLabel")
        if not label then continue end

        if label.Text == "Empty Base" then continue end
        local baseOwner = string.split(label.Text, "'")[1]
        if baseOwner == PlayerName then continue end

        local podiums = plot:FindFirstChild("AnimalPodiums")
        if not podiums then continue end

        for _, podium in ipairs(podiums:GetChildren()) do
            local spawn = podium:FindFirstChild("Base") and podium.Base:FindFirstChild("Spawn")
            if not spawn then continue end

            local attach = spawn:FindFirstChild("Attatchment") or spawn:FindFirstChild("Attachment")
            if not attach then continue end

            local overhead = attach:FindFirstChild("AnimalOverhead")
            if not overhead then continue end

            local rarity = overhead:FindFirstChild("Rarity")
            local stolen = overhead:FindFirstChild("Stolen")
            if not rarity or not stolen then continue end

            -- Only look for SECRET rarities
            if rarity.Text == "Secret" and stolen.Text ~= "FUSING" then
                local mutation = overhead:FindFirstChild("Mutation")
                local generation = overhead:FindFirstChild("Generation") -- "money they make"
                local name = overhead:FindFirstChild("DisplayName")
                local traits = overhead:FindFirstChild("Traits")

                local mutationText = (mutation and mutation.Visible and mutation.Text) or "Normal"
                local generationText = generation and generation.Text or "?"
                local nameText = name and name.Text or "?"

                local traitAmount = 0
                if traits then
                    for _, n in ipairs(traits:GetChildren()) do
                        if n:IsA("ImageLabel") and n.Name == "Template" and n.Visible then
                            traitAmount = traitAmount + 1
                        end
                    end
                end

                local fullGenValue, rawGen = parseGenerationText(generationText)

                local embed = buildEmbed(nameText, baseOwner, mutationText, traitAmount, rawGen, fullGenValue)
                print("SECRET BRAINROT FOUND! Name:", nameText, "Owner:", baseOwner, "Generation:", fullGenValue)

                -- If generation is >= 10,000,000 (10M) then ping everyone and stop teleporting
                if fullGenValue >= 10_000_000 then
                    sendWebhook(webhookURL, embed, "@everyone")
                    -- Stop the hopping loop by flipping the running flag
                    running = false
                    teleporting = false
                    print("[ALERT] High-value secret (>=10M) found — pinged everyone and stopped server hopping.")
                    return true, fullGenValue -- signal caller that we should stop
                else
                    sendWebhook(webhookURL, embed, "") -- no ping for smaller ones
                end
            end
        end
    end

    return false, 0
end

-- Server hopping logic
running = true
local teleporting = false
local triedServers = {}
local hopRequested = false

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Q then
        if not running then
            -- Restart hopping when Q pressed after a stop
            print("[MANUAL] Q pressed — restarting server hop loop.")
            running = true
            -- restart the loop
            coroutine.wrap(hopLoop)()
        else
            -- while running, request an immediate hop attempt
            print("[MANUAL HOP] Q pressed, requesting hop retry.")
            hopRequested = true
        end
    end
end)

local function getSuitableServers()
    local ok, res = pcall(function()
        return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"))
    end)
    if not ok or not res or not res.data then return {} end

    local list = {}
    for _, server in ipairs(res.data) do
        if server.id ~= game.JobId then
            table.insert(list, server.id)
        end
    end
    return list
end

local function tryTeleport(serverId)
    if teleporting then return false end
    teleporting = true
    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, serverId, LocalPlayer)
    end)
    teleporting = false
    if not success then
        warn("[Teleport Error]", err)
    end
    return success
end

function hopLoop()
    while running do
        -- scan for secrets and notify; capture if a high value one was found
        local stopNow, foundValue = findAndNotifySecrets()
        if stopNow then
            -- we've already stopped running inside findAndNotifySecrets, break out
            break
        end

        local servers = getSuitableServers()
        if #servers == 0 then
            print("[HOP] No suitable servers found, retrying immediately...")
            task.wait(0.5)
        else
            if #triedServers == #servers then
                triedServers = {}
            end

            local serverToTry
            if #servers >= 30 and not table.find(triedServers, servers[30]) then
                serverToTry = servers[30]
            else
                local available = {}
                for _, sid in ipairs(servers) do
                    if not table.find(triedServers, sid) then
                        table.insert(available, sid)
                    end
                end
                if #available == 0 then
                    triedServers = {}
                    available = servers
                end
                serverToTry = available[math.random(#available)]
            end

            table.insert(triedServers, serverToTry)
            if tryTeleport(serverToTry) then
                print("[HOP] Teleporting to server:", serverToTry)
                break
            else
                print("[HOP] Failed to teleport to server:", serverToTry, "Trying again in 1 second...")
                local waited = 0
                while waited < 1 do
                    task.wait(0.1)
                    waited = waited + 0.1
                    if hopRequested then
                        print("[MANUAL HOP] Forced hop requested during wait.")
                        hopRequested = false
                        break
                    end
                end
            end
        end

        if hopRequested then
            print("[MANUAL HOP] Hop requested, restarting hop attempt.")
            hopRequested = false
        else
            task.wait(0.5)
        end
    end
    print("[HOP LOOP] Exited hop loop. Press Q to restart.")
end

TeleportService.TeleportInitFailed:Connect(function()
    print("[Teleport Failed] Rejoining current server...")
    pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
end)

-- start hopping
coroutine.wrap(hopLoop)()
