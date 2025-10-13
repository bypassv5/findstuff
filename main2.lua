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
        return { Success = false, Error = "No external HTTP function available." }
    end
    local ok, res = pcall(function() return req(reqParams) end)
    if not ok then return { Success = false, Error = res } end
    return { Success = true, Response = res }
end

local function sendWebhook(url, embed, content)
    local payloadTable = { embeds = { embed } }
    if content and content ~= "" then payloadTable.content = content end
    local payload = HttpService:JSONEncode(payloadTable)
    local result = safeRequest({
        Url = url,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = payload
    })
    if not result.Success then warn("Webhook send failed:", result.Error) end
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

                if fullGenValue >= 10_000_000 then
                    sendWebhook(webhookURL, embed, "@everyone")
                    running = false
                    teleporting = false
                    print("[ALERT] High-value secret (>=10M) found — pinged everyone and stopped server hopping.")
                    return true, fullGenValue
                else
                    sendWebhook(webhookURL, embed, "")
                end
            end
        end
    end

    return false, 0
end

-- hopping via Teleport (no external HTTP servers API calls)
running = true
local teleporting = false
local hopRequested = false

local lastTeleportTime = 0
local minTeleportInterval = 2.5 -- seconds between teleport attempts, increase to be safer

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

local function doTeleportToAnotherServer()
    -- ensure minimum spacing
    if tick() - lastTeleportTime < minTeleportInterval then
        local waitT = minTeleportInterval - (tick() - lastTeleportTime)
        task.wait(waitT)
    end

    teleporting = true
    local success, err = pcall(function()
        -- call Teleport with PlaceId only — Roblox chooses a destination server
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
    teleporting = false
    lastTeleportTime = tick()

    if not success then
        warn("[Teleport] failed:", err)
        return false
    end
    return true
end

function hopLoop()
    while running do
        local stopNow, foundValue = findAndNotifySecrets()
        if stopNow then break end

        -- attempt to teleport to another public server (Roblox picks)
        -- add a tiny random delay to avoid exact timing patterns
        task.wait(0.06 + math.random() * 0.18)

        if doTeleportToAnotherServer() then
            print("[HOP] Teleport requested (Roblox will pick a server).")
            break -- teleport started; auto-reinject on join
        else
            -- on failure, wait with jitter before retrying
            local waitT = 1.0 + math.random() * 1.5
            print("[HOP] Teleport request failed; waiting", string.format("%.2f", waitT), "s before retry.")
            local waited = 0
            while waited < waitT do
                task.wait(0.08)
                waited = waited + 0.08
                if hopRequested then
                    hopRequested = false
                    break
                end
            end
        end

        if hopRequested then
            hopRequested = false
        else
            task.wait(0.4 + math.random() * 0.6)
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
