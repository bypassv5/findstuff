-- Auto reinject with job cache persistence
local scriptURL = "https://raw.githubusercontent.com/bypassv5/findstuff/main4.lua"

if queue_on_teleport then
    -- persist job ID cache between teleports
    if getgenv().SavedJobIds and type(getgenv().SavedJobIds) == "table" then
        queue_on_teleport([[
            getgenv().SavedJobIds = ]] .. game:GetService("HttpService"):JSONEncode(getgenv().SavedJobIds) .. [[
            loadstring(game:HttpGet("]]..scriptURL..[["))()
        ]])
    else
        queue_on_teleport("loadstring(game:HttpGet('"..scriptURL.."'))()")
    end
end

---------------------------------------------------------------------
-- Services
---------------------------------------------------------------------
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

---------------------------------------------------------------------
-- Config
---------------------------------------------------------------------
local webhookURL = "https://discord.com/api/webhooks/1398765862835458110/yPDUCwGfwrDAkV9y1LwKDbawWTUWLE6810Y2Dh732FnKG1UiIgLnsMrSAJ3-opRkAAHu"
local hopInterval = 2.5           -- seconds between hops
local refreshEvery = 5            -- only hit Roblox servers API once every 5 hops
local minWaitBetweenRequests = 10 -- safety for rate limiting

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
running = true
local hopCount = 0
local teleporting = false
local lastAPIRequest = 0
getgenv().SavedJobIds = getgenv().SavedJobIds or {}
local jobCache = getgenv().SavedJobIds

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function safeRequest(reqParams)
    local req = (syn and syn.request) or http_request or (fluxus and fluxus.request)
    if not req then return {Success = false, Error = "no executor request"} end
    local ok, res = pcall(function() return req(reqParams) end)
    if not ok then return {Success = false, Error = res} end
    return {Success = true, Response = res}
end

local function sendWebhook(url, embed, content)
    local payload = HttpService:JSONEncode({
        content = content or "",
        embeds = {embed}
    })
    safeRequest({
        Url = url,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = payload
    })
end

local function buildEmbed(name, owner, mutation, traits, genText, genVal)
    return {
        title = "SECRET BRAINROT FOUND!",
        color = 0xE74C3C,
        fields = {
            {name="Name",value=name or "?",inline=true},
            {name="Owner",value=owner or "?",inline=true},
            {name="Mutation",value=mutation or "Normal",inline=true},
            {name="Traits",value=tostring(traits or 0),inline=true},
            {name="Generation",value=genText or "?",inline=true},
        },
        footer={text="Finder Script"}
    }
end

local function parseGenerationText(txt)
    if not txt then return 0,"?" end
    local s = tostring(txt):gsub("%$", ""):gsub("/s", ""):gsub("%s+", "")
    local multipliers = {K=1e3,M=1e6,B=1e9}
    local last = s:sub(-1):upper()
    if multipliers[last] then
        return (tonumber(s:sub(1,-2)) or 0)*multipliers[last], s
    else
        return tonumber(s) or 0, s
    end
end

---------------------------------------------------------------------
-- Finder
---------------------------------------------------------------------
local function findAndNotifySecrets()
    local plots = workspace:FindFirstChild("Plots")
    if not plots or #plots:GetChildren() == 0 then return false,0 end

    local pname = LocalPlayer and LocalPlayer.DisplayName
    for _, plot in ipairs(plots:GetChildren()) do
        local sign = plot:FindFirstChild("PlotSign")
        if not sign then continue end
        local surf = sign:FindFirstChild("SurfaceGui")
        if not surf then continue end
        local frame = surf:FindFirstChild("Frame")
        if not frame then continue end
        local label = frame:FindFirstChild("TextLabel")
        if not label or label.Text == "Empty Base" then continue end
        local baseOwner = string.split(label.Text, "'")[1]
        if baseOwner == pname then continue end

        local podiums = plot:FindFirstChild("AnimalPodiums")
        if not podiums then continue end

        for _, podium in ipairs(podiums:GetChildren()) do
            local spawn = podium:FindFirstChild("Base") and podium.Base:FindFirstChild("Spawn")
            if not spawn then continue end
            local attach = spawn:FindFirstChild("Attachment") or spawn:FindFirstChild("Attatchment")
            if not attach then continue end
            local overhead = attach:FindFirstChild("AnimalOverhead")
            if not overhead then continue end

            local rarity = overhead:FindFirstChild("Rarity")
            local stolen = overhead:FindFirstChild("Stolen")
            if not rarity or not stolen then continue end
            if rarity.Text ~= "Secret" or stolen.Text == "FUSING" then continue end

            local mutation = overhead:FindFirstChild("Mutation")
            local generation = overhead:FindFirstChild("Generation")
            local name = overhead:FindFirstChild("DisplayName")
            local traits = overhead:FindFirstChild("Traits")

            local mutationText = (mutation and mutation.Visible and mutation.Text) or "Normal"
            local generationText = generation and generation.Text or "?"
            local nameText = name and name.Text or "?"
            local traitCount = 0
            if traits then
                for _, t in ipairs(traits:GetChildren()) do
                    if t:IsA("ImageLabel") and t.Visible then
                        traitCount += 1
                    end
                end
            end

            local genVal, genTxt = parseGenerationText(generationText)
            local embed = buildEmbed(nameText, baseOwner, mutationText, traitCount, genTxt, genVal)
            print("SECRET FOUND!", nameText, baseOwner, genVal)

            if genVal >= 10_000_000 then
                sendWebhook(webhookURL, embed, "@everyone")
                running = false
                return true, genVal
            else
                sendWebhook(webhookURL, embed, "")
            end
        end
    end
    return false, 0
end

---------------------------------------------------------------------
-- Server fetch (called rarely)
---------------------------------------------------------------------
local function refreshJobIds()
    if tick() - lastAPIRequest < minWaitBetweenRequests then return end
    lastAPIRequest = tick()

    local ok, body = pcall(function()
        return game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100")
    end)

    if not ok or not body then
        warn("[JOB REFRESH] Failed to fetch server list.")
        return
    end

    local data = HttpService:JSONDecode(body)
    if not data or not data.data then return end

    local list = {}
    for _, server in ipairs(data.data) do
        if server.id ~= game.JobId then
            table.insert(list, server.id)
        end
    end

    if #list > 0 then
        jobCache = list
        getgenv().SavedJobIds = list
        print("[JOB REFRESH] Got", #list, "servers from Roblox.")
    else
        warn("[JOB REFRESH] No servers returned.")
    end
end

---------------------------------------------------------------------
-- Teleport
---------------------------------------------------------------------
local function tryTeleport()
    if teleporting then return false end
    teleporting = true

    hopCount += 1
    if hopCount % refreshEvery == 0 or #jobCache == 0 then
        refreshJobIds()
    end

    local targetId
    for i = 1, 10 do
        if #jobCache == 0 then break end
        local sid = jobCache[math.random(1, #jobCache)]
        if sid ~= game.JobId then
            targetId = sid
            break
        end
    end

    if targetId then
        print("[HOP] Teleporting to cached server:", targetId)
        pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, targetId, LocalPlayer) end)
    else
        print("[HOP] No cached job found; using random Teleport() fallback.")
        pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
    end

    task.wait(hopInterval)
    teleporting = false
end

---------------------------------------------------------------------
-- Main loop
---------------------------------------------------------------------
function hopLoop()
    while running do
        local stop, _ = findAndNotifySecrets()
        if stop then break end

        tryTeleport()
        task.wait(0.5)
    end
end

TeleportService.TeleportInitFailed:Connect(function()
    print("[Teleport Failed] Rejoining current server...")
    pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
end)

coroutine.wrap(hopLoop)()
