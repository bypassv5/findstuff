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

local function safeRequest(reqParams)
    local req = (syn and syn.request) or http_request or (fluxus and fluxus.request)
    if not req then
        -- Fall back to Roblox http if enabled (game:HttpGet) -- but that has different interface
        if pcall(function() return game.HttpGet end) then
            local ok, res = pcall(function()
                return game:HttpGet(reqParams.Url)
            end)
            if ok then
                return { Success = true, Body = res }
            else
                return { Success = false, Error = res }
            end
        end
        return { Success = false, Error = "No HTTP request function found." }
    end

    local ok, res = pcall(function() return req(reqParams) end)
    if not ok then
        return { Success = false, Error = res }
    end

    -- syn.request / fluxus.request return a table; try to normalize
    return { Success = true, Response = res }
end

local function sendWebhook(url, embed, content)
    local payloadTable = { embeds = { embed } }
    if content and content ~= "" then
        payloadTable.content = content
    end
    local payload = HttpService:JSONEncode(payloadTable)

    local result = safeRequest({
        Url = url,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = payload
    })

    if not result.Success then
        warn("Webhook send failed:", result.Error)
    end
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
    if not workspace:FindFirstChild("Plots") then return false, 0 end
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

-- Server hopping logic with caching/backoff to reduce rate-limits
running = true
local teleporting = false
local triedServers = {}
local hopRequested = false

-- caching servers for short time to avoid spamming the API
local serverCache = { list = {}, ts = 0 }
local minCacheSeconds = 5 -- cache server list for 5 seconds

-- teleport pacing
local lastTeleportTime = 0
local minTeleportInterval = 2.0 -- seconds between Teleport attempts (tune up if you still hit limits)

-- exponential backoff state for API failures
local backoffBase = 0.5
local backoffMult = 1
local maxBackoff = 8

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Q then
        if not running then
            print("[MANUAL] Q pressed — restarting server hop loop.")
            running = true
            coroutine.wrap(hopLoop)()
        else
            print("[MANUAL HOP] Q pressed, requesting hop retry.")
            hopRequested = true
        end
    end
end)

local function getSuitableServers()
    -- return cached if recent
    if tick() - serverCache.ts < minCacheSeconds and #serverCache.list > 0 then
        return serverCache.list
    end

    local allServers = {}
    local cursor = nil
    local attempts = 0
    while true do
        attempts = attempts + 1
        if attempts > 8 then break end -- safety
        local url = "https://games.roblox.com/v1/games/"..tostring(game.PlaceId).."/servers/Public?sortOrder=Asc&limit=100"
        if cursor then
            url = url.."&cursor="..HttpService:UrlEncode(cursor)
        end

        local ok, res = pcall(function() return game:HttpGet(url) end)
        if not ok or not res then
            -- http failure: backoff with jitter
            local waitTime = math.min(maxBackoff, backoffBase * backoffMult) + math.random() * 0.5
            warn("[getSuitableServers] HttpGet failed. Backing off for", waitTime, "s")
            task.wait(waitTime)
            backoffMult = math.min(backoffMult * 2, maxBackoff)
            if attempts >= 3 then break end
        else
            -- try decode
            local decoded = nil
            local ok2, dec = pcall(function() return HttpService:JSONDecode(res) end)
            if ok2 and dec and dec.data then
                for _, server in ipairs(dec.data) do
                    if server.id and server.id ~= game.JobId then
                        table.insert(allServers, server.id)
                    end
                end
                if dec.nextPageCursor and dec.nextPageCursor ~= "" then
                    cursor = dec.nextPageCursor
                    -- small pause between pages to avoid rate-limits
                    task.wait(0.08 + math.random() * 0.05)
                    -- continue to next page
                else
                    break
                end
            else
                -- decode failed: backoff
                local waitTime = math.min(maxBackoff, backoffBase * backoffMult) + math.random() * 0.5
                warn("[getSuitableServers] JSON decode failed or no data. Backing off for", waitTime, "s")
                task.wait(waitTime)
                backoffMult = math.min(backoffMult * 2, maxBackoff)
                if attempts >= 3 then break end
            end
        end
    end

    -- reset backoff multiplier after a successful fetch
    backoffMult = 1

    -- dedupe/all done
    local unique = {}
    local final = {}
    for _, id in ipairs(allServers) do
        if not unique[id] and id ~= game.JobId then
            unique[id] = true
            table.insert(final, id)
        end
    end

    -- cache result
    serverCache.list = final
    serverCache.ts = tick()
    return final
end

local function tryTeleport(serverId)
    if teleporting then return false end

    -- respect a minimum interval between teleports
    if tick() - lastTeleportTime < minTeleportInterval then
        warn("[tryTeleport] Too soon since last teleport. Waiting briefly.")
        task.wait(minTeleportInterval - (tick() - lastTeleportTime))
    end

    teleporting = true
    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, serverId, LocalPlayer)
    end)
    teleporting = false
    lastTeleportTime = tick()

    if not success then
        warn("[Teleport Error]", err)
    end
    return success
end

function hopLoop()
    while running do
        local stopNow, foundValue = findAndNotifySecrets()
        if stopNow then break end

        local servers = getSuitableServers()
        if #servers == 0 then
            -- nothing found, wait a bit (randomized) to avoid hammering
            local waitT = 0.6 + math.random() * 0.6
            print("[HOP] No suitable servers found — waiting", string.format("%.2f", waitT), "s before retry.")
            task.wait(waitT)
        else
            -- pick random server excluding ones we've tried this cycle
            if #triedServers >= #servers then
                triedServers = {}
            end

            local choices = {}
            for _, sid in ipairs(servers) do
                if not table.find(triedServers, sid) then
                    table.insert(choices, sid)
                end
            end
            if #choices == 0 then
                triedServers = {}
                for _, sid in ipairs(servers) do table.insert(choices, sid) end
            end

            -- random selection to avoid patterns
            local serverToTry = choices[math.random(1, #choices)]
            table.insert(triedServers, serverToTry)

            -- small randomized pre-teleport delay to reduce patterning and rate-limit risk
            task.wait(0.05 + math.random() * 0.15)

            if tryTeleport(serverToTry) then
                print("[HOP] Teleporting to server:", serverToTry)
                break -- teleport initiated; script will auto-reinject on new server
            else
                print("[HOP] Failed to teleport to server:", serverToTry, " — will try another in a moment.")
                -- gentle wait with jitter and allow manual hop to interrupt
                local waited = 0
                local waitLimit = 0.8 + math.random() * 0.8
                while waited < waitLimit do
                    task.wait(0.07)
                    waited = waited + 0.07
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
            -- short randomized sleep to avoid consistent timing
            task.wait(0.35 + math.random() * 0.4)
        end
    end
    print("[HOP LOOP] Exited hop loop. Press Q to restart.")
end

TeleportService.TeleportInitFailed:Connect(function()
    print("[Teleport Failed] Attempting to rejoin current server job id...")
    pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
end)

-- start hopping
coroutine.wrap(hopLoop)()
