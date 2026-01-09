--[[ 
  TOTAL LOADER - ONE FILE
  - Loads Main mode
  - Loads Sprint (with UI hide-on-death fix)
  - Loads custom entity Wh1t3 (A-200 removed)
  - Preloads A-60 spawner and runs safe random spawn loop
  - Protects against crashes with pcall and timeouts
--]]

-----------------------
-- CONFIG
-----------------------
local mainUrl = "https://raw.githubusercontent.com/GuestlyTheGreatestGuest/Modes/main/Hardcore-Mode-Re-Remastered-Made-By-Guestly-Vuivuiviu2-Nowhywhat-Voorpr0"
local sprintUrl = "https://raw.githubusercontent.com/Junbbinopro/Sprint-stamina-v3/refs/heads/main/Sprint"
local wh1t3Url = "https://raw.githubusercontent.com/Junbbinopro/Wh1t3/refs/heads/main/Entity"
local a60Url = "https://raw.githubusercontent.com/Idk-lol2/a-60aa/main/---======%20a-60%20agresiv%20spawner%20======---.txt"

-- SETTINGS
local WAIT_MAIN_READY_TIMEOUT = 30 -- seconds to wait for main ready signal
local A60_SPAWN_CHANCE = 1         -- numerator (chance 1 in A60_SPAWN_RANGE)
local A60_SPAWN_RANGE = 500       -- denominator (random 1..A60_SPAWN_RANGE)
local A60_INITIAL_DELAY = 9       -- initial delay before spawn loop starts
local A60_POST_WARNING_DELAY = 4  -- wait after warning sound before spawn
local A60_COOLDOWN = 25           -- cooldown after spawn (seconds)
local A60_WARNING_SOUND = "rbxassetid://78206015664727"

-- Safety globals / toggles
getgenv().BLOCK_A200_AUTOSPAWN = true -- ensure A-200 (if present) won't autospawn

-----------------------
-- UTIL: safe loader
-----------------------
local function safeHttpGet(url)
    local ok, res = pcall(function()
        return game:HttpGet(url, true)
    end)
    if not ok then
        return false, ("HttpGet failed: %s"):format(tostring(res))
    end
    if type(res) ~= "string" or #res == 0 then
        return false, "empty response"
    end
    return true, res
end

local function safeLoadAndRun(url, name)
    name = name or url
    local ok, code = safeHttpGet(url)
    if not ok then
        warn(("[Loader][%s] Error fetching: %s"):format(name, tostring(code)))
        return false, code
    end

    local fn, loadErr = loadstring(code)
    if not fn then
        warn(("[Loader][%s] loadstring error: %s"):format(name, tostring(loadErr)))
        return false, loadErr
    end

    local okExec, execErr = pcall(fn)
    if not okExec then
        warn(("[Loader][%s] runtime error: %s"):format(name, tostring(execErr)))
        return false, execErr
    end

    print(("[Loader][%s] Loaded successfully"):format(name))
    return true
end

-----------------------
-- 1) LOAD MAIN
-----------------------
local mainLoaded, mainErr = safeLoadAndRun(mainUrl, "MainMode")
if not mainLoaded then
    warn("[Loader] Main failed to load; continuing but behavior may break.")
else
    print("[Loader] Main loaded.")
end

-----------------------
-- 2) WAIT FOR MAIN READY
-----------------------
local function waitForMainReady(timeoutSeconds)
    timeoutSeconds = timeoutSeconds or WAIT_MAIN_READY_TIMEOUT
    local start = tick()
    while tick() - start < timeoutSeconds do
        -- common readiness signals (extend if your main exposes a different flag)
        if (type(getgenv) == "function" and getgenv().OVERDOORS_LOADED == true) then
            return true, "getgenv.OVERDOORS_LOADED"
        end
        if _G and _G.OVERDOORS_LOADED == true then
            return true, "_G.OVERDOORS_LOADED"
        end
        if shared and type(shared.CustomEntities) == "table" then
            return true, "shared.CustomEntities"
        end
        if (type(getgenv) == "function" and getgenv().DOORS_LOADED == true) then
            return true, "getgenv.DOORS_LOADED"
        end
        task.wait(0.4)
    end
    return false, "timeout"
end

local ready, reason = waitForMainReady(WAIT_MAIN_READY_TIMEOUT)
if ready then
    print(("[Loader] Main ready detected by: %s"):format(tostring(reason)))
else
    warn("[Loader] Main did NOT report ready within timeout ("..tostring(WAIT_MAIN_READY_TIMEOUT).."s). Proceeding anyway.")
end

-----------------------
-- 3) LOAD SPRINT (with UI fix)
-----------------------
task.spawn(function()
    task.wait(0.4)
    local okSprint, errSprint = safeLoadAndRun(sprintUrl, "Sprint-Stamina")
    if not okSprint then
        warn("[Loader] Sprint failed: "..tostring(errSprint))
        return
    end

    -- FIX: hide sprint UI when dead / show on respawn
    pcall(function()
        local Players = game:GetService("Players")
        local player = Players.LocalPlayer
        if not player then return end

        local function hideSprint()
            local gui = player:FindFirstChild("PlayerGui")
            if not gui then return end
            for _, v in pairs(gui:GetDescendants()) do
                if (v:IsA("TextButton") or v:IsA("ImageButton")) then
                    local n = (v.Name or ""):lower()
                    local txt = tostring(v.Text or ""):lower()
                    if n:find("sprint") or txt:find("sprint") or txt:find("chạy") then
                        v.Visible = false
                    end
                end
            end
        end

        local function showSprint()
            local gui = player:FindFirstChild("PlayerGui")
            if not gui then return end
            for _, v in pairs(gui:GetDescendants()) do
                if (v:IsA("TextButton") or v:IsA("ImageButton")) then
                    local n = (v.Name or ""):lower()
                    local txt = tostring(v.Text or ""):lower()
                    if n:find("sprint") or txt:find("sprint") or txt:find("chạy") then
                        v.Visible = true
                    end
                end
            end
        end

        player.CharacterAdded:Connect(function(char)
            local hum = char:WaitForChild("Humanoid", 5)
            if hum then
                hum.Died:Connect(function()
                    task.wait(0.1)
                    hideSprint()
                end)
            end
        end)

        -- loop to re-show sprint when alive
        task.spawn(function()
            while task.wait(1) do
                local char = player.Character
                if char then
                    local hum = char:FindFirstChild("Humanoid")
                    if hum and hum.Health > 0 then
                        showSprint()
                    end
                end
            end
        end)
    end)
end)

-----------------------
-- 4) LOAD CUSTOM ENTITY Wh1t3 (A-200 intentionally removed)
-----------------------
task.delay(1, function()
    local okWh, errWh = safeLoadAndRun(wh1t3Url, "Wh1t3-Entity")
    if not okWh then
        warn("[Loader] Wh1t3 failed: "..tostring(errWh))
    end
end)

-----------------------
-- 5) PRELOAD A-60 SPAWNER & SAFE RANDOM SPAWN LOOP
-----------------------
task.spawn(function()
    task.wait(A60_INITIAL_DELAY) -- initial delay

    -- preload script (only once)
    local ok, res = safeHttpGet(a60Url)
    if not ok then
        warn("[A-60] Preload failed: "..tostring(res))
        return
    end

    local a60Fn, a60LoadErr = loadstring(res)
    if not a60Fn then
        warn("[A-60] loadstring error: "..tostring(a60LoadErr))
        return
    end
    print("[A-60] Preloaded successfully")

    local Debris = game:GetService("Debris")
    local spawning = false

    while true do
        task.wait(1)
        -- random chance check
        if not spawning and math.random(1, A60_SPAWN_RANGE) == A60_SPAWN_CHANCE then
            spawning = true

            -- play warning sound once
            pcall(function()
                local s = Instance.new("Sound")
                s.SoundId = A60_WARNING_SOUND
                s.Volume = 1
                s.Parent = workspace
                s:Play()
                Debris:AddItem(s, A60_POST_WARNING_DELAY + 2)
            end)

            task.wait(A60_POST_WARNING_DELAY)

            -- call preloaded function (pcall to avoid crash)
            pcall(function()
                a60Fn()
            end)

            -- cooldown
            task.wait(A60_COOLDOWN)
            spawning = false
        end
    end
end)

-----------------------
-- DONE
-----------------------
print("[TOTAL LOADER] Setup complete. Main / Sprint / Wh1t3 loaded; A-60 spawn loop active (preloaded). A-200 disabled.")
