-- Combined Server Hopper + Finder + Webhook
-- Auto-reinjects on teleport and stops when a high-value secret (>=10M) is found.

local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Auto-reinject finder/main script on teleport (adjust URL if needed)
local finderURL = "https://raw.githubusercontent.com/bypassv5/findstuff/main/main.lua"
if queue_on_teleport then
    queue_on_teleport("loadstring(game:HttpGet('"..finderURL.."'))()")
end

-- Webhook helper (supports syn.request, http_request, fluxus.request)
local webhookURL = "https://discord.com/api/webhooks/1398765862835458110/yPDUCwGfwrDAkV9y1LwKDbawWTUWLE6810Y2Dh732FnKG1UiIgLnsMrSAJ3-opRkAAHu"
local function sendWebhook(url, embed, content)
    local payloadTable = { embeds = { embed } }
    if content and content ~= "" then payloadTable.content = content end
    local payload = HttpService:JSONEncode(payloadTable)

    local req = (syn and syn.request) or http_request or (fluxus and fluxus.request)
    if not req then
        warn("No HTTP request function found for webhook.")
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
    return {
        title = "SECRET BRAINROT FOUND!",
        color = 0xE74C3C,
        fields = {
            { name = "Name", value = nameText or "?", inline = true },
            { name = "Owner", value = baseOwner or "?", inline = true },
            { name = "Mutation", value = mutationText or "Normal", inline = true },
            { name = "Trait Count", value = tostring(traitAmount or 0), inline = true },
            { name = "Generation", value = generationText or "?", inline = true },
        },
        footer = { text = "Finder Script" }
    }
end

-- parse "10M", "500K", "3B", "$10 M/s", "1000000"
local function parseGenerationText(txt)
    if not txt then return 0, "?" end
    local s = tostring(txt):gsub("%$", ""):gsub("/s", ""):gsub("%s+", "")
    local multipliers = { K = 1_000, M = 1_000_000, B = 1_000_000_000 }
    local last = s:sub(-1):upper()
    if multipliers[last] then
        local num = tonumber(s:sub(1, -2)) or 0
        return num * multipliers[last], s
    else
        local n = tonumber(s)
        if n then return n, s end
        return 0, s
    end
end

-- Finder: scans workspace.Plots and notifies webhook on found secrets.
local function findAndNotifySecrets()
    if not workspace:FindFirstChild("Plots") then return false, 0 end
    local PlayerName = LocalPlayer and (LocalPlayer.DisplayName or LocalPlayer.Name)

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
        local baseOwner = string.split(label.Text, "'")[1] or "?"

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

            if rarity.Text == "Secret" and stolen.Text ~= "FUSING" then
                local mutation = overhead:FindFirstChild("Mutation")
                local generation = overhead:FindFirstChild("Generation")
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

                -- If generation >= 10M, ping everyone and stop hopping
                if fullGenValue >= 10_000_000 then
                    sendWebhook(webhookURL, embed, "@everyone")
                    return true, fullGenValue
                else
                    sendWebhook(webhookURL, embed, "")
                end
            end
        end
    end

    return false, 0
end

-- Server-hopping logic (ascending player count)
local running = true
local teleporting = false
local triedServers = {}
local hopRequested = false

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Q then
        if not running then
            print("[MANUAL] Q pressed — restarting server hop loop.")
            running = true
            coroutine.wrap(hopLoop)() -- hopLoop will be defined below
        else
            print("[MANUAL HOP] Q pressed, requesting hop retry.")
            hopRequested = true
        end
    end
end)

local function getAscendingServers()
    local url = "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
    local ok, res = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    if not ok or not res or not res.data then
        return {}
    end

    local list = {}
    for _, server in ipairs(res.data) do
        if server.id ~= game.JobId and server.playing and server.playing < (server.maxPlayers or 0) then
            table.insert(list, { id = server.id, players = server.playing })
        end
    end

    table.sort(list, function(a,b) return a.players < b.players end)
    return list
end

local function tryTeleport(serverId)
    if teleporting then return false end
    teleporting = true
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, serverId, LocalPlayer)
    end)
    teleporting = false
    if not ok then
        warn("[Teleport Error]", err)
        return false
    end
    return true
end

-- hopLoop defined here so the Q handler can call it
function hopLoop()
    while running do
        -- 1) scan current server for secrets repeatedly a few times before hopping
        local scans = 3
        for i = 1, scans do
            if not running then break end
            local stopNow, foundValue = findAndNotifySecrets()
            if stopNow then
                print("[FOUND] High-value secret found! Stopping all hopping. Value:", foundValue)
                running = false
                return
            end
            -- small delay between scans so game can fully load UIs
            task.wait(0.7)
        end

        -- 2) get ascending servers and try them in order
        local servers = getAscendingServers()
        if #servers == 0 then
            print("[HOP] No servers found; retrying shortly...")
            task.wait(2)
            continue
        end

        -- Reset triedServers if we've tried them all
        if #triedServers >= #servers then triedServers = {} end

        local triedOne = false
        for idx, s in ipairs(servers) do
            if not table.find(triedServers, s.id) then
                triedOne = true
                table.insert(triedServers, s.id)
                print(("[HOP] Trying server %d/%d — %d players — id: %s"):format(idx, #servers, s.players, s.id))
                local success = tryTeleport(s.id)
                if success then
                    print("[HOP] Teleport requested — breaking hop loop to let teleport occur.")
                    return -- Let teleport happen; the script will reinject on the new server
                else
                    print("[HOP] Teleport to "..s.id.." failed — trying next after delay.")
                    local waited = 0
                    while waited < 1 do
                        task.wait(0.1); waited = waited + 0.1
                        if hopRequested then
                            hopRequested = false
                            break
                        end
                    end
                end
            end
        end

        if not triedOne then
            -- fallback: clear tried and retry
            triedServers = {}
            print("[HOP] No new servers to try; clearing tried list.")
        end

        task.wait(1)
    end

    print("[HOP LOOP] Exited. Press Q to restart.")
end

-- Teleport error fallback: try rejoining current server JobId
TeleportService.TeleportInitFailed:Connect(function()
    warn("[Teleport Failed] TeleportInitFailed fired. Attempting to rejoin current server.")
    pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
end)

-- start the loop
print("[HOP] Starting ascending server hop + finder.")
coroutine.wrap(hopLoop)()
