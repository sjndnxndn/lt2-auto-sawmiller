-- LT2 Cut Diagnostic v7
-- 10 cuts, 1 second apart. Cached axe reference. Safe teleport.

-- ============================================================
--  SERVICES
-- ============================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Interaction = ReplicatedStorage:WaitForChild("Interaction")
local RemoteProxy = Interaction:WaitForChild("RemoteProxy")

-- ============================================================
--  CONFIG
-- ============================================================
local CONFIG = {
    CUTS_PER_BURST = 10,
    BURST_DELAY    = 1.0,                        -- 1 second between cuts
    TELEPORT_OFFSET = Vector3.new(2, 2, 0),      -- closer, safer
    FACE_VECTOR    = Vector3.new(1, 0, 0),
    COOLDOWN       = 0.23737628459930421,
    SECTION_ID     = 1,
    HIT_POINTS     = 1.2,
    CUTTING_CLASS  = "Axe",
    MIN_HP_TO_CONTINUE = 30,                     -- stop burst if HP drops below
}

-- ============================================================
--  CLIPBOARD
-- ============================================================
local setClipboard = nil
if type(setclipboard) == "function" then
    setClipboard = setclipboard
elseif type(toclipboard) == "function" then
    setClipboard = toclipboard
elseif type(writeClipboard) == "function" then
    setClipboard = writeClipboard
end

-- ============================================================
--  GUI
-- ============================================================
local sg = Instance.new("ScreenGui")
sg.Name = "LT2_CutDiag7"
sg.ResetOnSpawn = false
sg.Parent = LocalPlayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 540, 0, 470)
frame.Position = UDim2.new(0.5, -270, 0.5, -235)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = sg

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
title.BorderSizePixel = 0
title.Text = "LT2 Cut Diagnostic v7 - 10 cuts @ 1s"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 14
title.Font = Enum.Font.SourceSansBold
title.Parent = frame

local function mkBtn(text, x, y, w, h, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, h)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 12
    b.Font = Enum.Font.SourceSansBold
    b.TextWrapped = true
    b.Parent = frame
    return b
end

local listBtn  = mkBtn("List Planks", 4,   32, 110, 30, Color3.fromRGB(60, 120, 200))
local copyBtn  = mkBtn("Copy Log",    118, 32, 90,  30, Color3.fromRGB(60, 180, 100))
local clearBtn = mkBtn("Clear",       212, 32, 70,  30, Color3.fromRGB(150, 80, 80))
local equipBtn = mkBtn("Equip Axe",   286, 32, 90,  30, Color3.fromRGB(200, 140, 50))
local stopBtn  = mkBtn("STOP",        380, 32, 60,  30, Color3.fromRGB(200, 50, 50))

local axeInfo = Instance.new("TextLabel")
axeInfo.Size = UDim2.new(1, -444, 0, 30)
axeInfo.Position = UDim2.new(0, 444, 0, 32)
axeInfo.BackgroundTransparency = 1
axeInfo.Text = "axe: ?"
axeInfo.TextColor3 = Color3.fromRGB(255, 200, 100)
axeInfo.TextSize = 11
axeInfo.Font = Enum.Font.Code
axeInfo.TextXAlignment = Enum.TextXAlignment.Left
axeInfo.Parent = frame

local lbl2 = Instance.new("TextLabel")
lbl2.Size = UDim2.new(1, -8, 0, 18)
lbl2.Position = UDim2.new(0, 4, 0, 66)
lbl2.BackgroundTransparency = 1
lbl2.Text = "Quick test (auto picks largest plank, teleports, fires burst):"
lbl2.TextColor3 = Color3.fromRGB(200, 200, 200)
lbl2.TextSize = 11
lbl2.Font = Enum.Font.SourceSansBold
lbl2.TextXAlignment = Enum.TextXAlignment.Left
lbl2.Parent = frame

local v_h1    = mkBtn("h=1",          4,   86, 100, 28, Color3.fromRGB(70, 90, 130))
local v_hHalf = mkBtn("h=half",       108, 86, 100, 28, Color3.fromRGB(70, 90, 130))
local v_h025  = mkBtn("h=0.25",       212, 86, 100, 28, Color3.fromRGB(70, 90, 130))
local v_test  = mkBtn("Test 1 cut",   316, 86, 100, 28, Color3.fromRGB(140, 90, 130))

local lbl3 = Instance.new("TextLabel")
lbl3.Size = UDim2.new(1, -8, 0, 18)
lbl3.Position = UDim2.new(0, 4, 0, 116)
lbl3.BackgroundTransparency = 1
lbl3.Text = "Burst preset:"
lbl3.TextColor3 = Color3.fromRGB(200, 200, 200)
lbl3.TextSize = 11
lbl3.Font = Enum.Font.SourceSansBold
lbl3.TextXAlignment = Enum.TextXAlignment.Left
lbl3.Parent = frame

local p_10x1  = mkBtn("10x1s",  100, 114, 80, 24, Color3.fromRGB(60, 140, 80))
local p_10x05 = mkBtn("10x0.5s",182, 114, 80, 24, Color3.fromRGB(70, 90, 130))
local p_20x1  = mkBtn("20x1s",  264, 114, 80, 24, Color3.fromRGB(70, 90, 130))
local p_30x05 = mkBtn("30x0.5s",346, 114, 80, 24, Color3.fromRGB(70, 90, 130))

local logBox = Instance.new("ScrollingFrame")
logBox.Size = UDim2.new(1, -10, 1, -310)
logBox.Position = UDim2.new(0, 5, 0, 148)
logBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
logBox.BorderSizePixel = 0
logBox.ScrollBarThickness = 6
logBox.CanvasSize = UDim2.new(0, 0, 0, 0)
logBox.AutomaticCanvasSize = Enum.AutomaticSize.Y
logBox.Parent = frame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 2)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = logBox

local picker = Instance.new("ScrollingFrame")
picker.Size = UDim2.new(1, -10, 0, 150)
picker.Position = UDim2.new(0, 5, 1, -158)
picker.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
picker.BorderSizePixel = 0
picker.ScrollBarThickness = 6
picker.Visible = false
picker.CanvasSize = UDim2.new(0, 0, 0, 0)
picker.AutomaticCanvasSize = Enum.AutomaticSize.Y
picker.Parent = frame

local pickerLayout = Instance.new("UIListLayout")
pickerLayout.Padding = UDim.new(0, 2)
pickerLayout.SortOrder = Enum.SortOrder.LayoutOrder
pickerLayout.Parent = picker

local logBuffer = {}

local function log(msg)
    table.insert(logBuffer, msg)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -6, 0, 18)
    l.BackgroundTransparency = 1
    l.Text = msg
    l.TextColor3 = Color3.fromRGB(220, 220, 220)
    l.TextSize = 11
    l.Font = Enum.Font.Code
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = logBox
    task.wait()
    logBox.CanvasPosition = Vector2.new(0, layout.AbsoluteContentSize.Y)
end

-- ============================================================
--  HELPERS
-- ============================================================
local function ownerMatches(model, who)
    if not model or not who then return false end
    local o = model:FindFirstChild("Owner")
    if not o then return false end
    local ok, v = pcall(function() return o.Value end)
    return ok and v == who
end

local function fmtVec(v)
    if not v then return "nil" end
    return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z)
end

local function toolRealName(tool)
    local tn = tool:FindFirstChild("ToolName")
    if tn and tn:IsA("StringValue") then
        return tn.Value
    end
    return tool.Name
end

local function gatherTools()
    local out = {}
    local containers = {
        LocalPlayer:FindFirstChild("Backpack"),
        LocalPlayer:FindFirstChild("Tools"),
        LocalPlayer.Character,
    }
    for _, c in ipairs(containers) do
        if c then
            for _, d in ipairs(c:GetChildren()) do
                if d:IsA("Tool") then
                    table.insert(out, d)
                end
            end
            for _, d in ipairs(c:GetDescendants()) do
                if d:IsA("Tool") then
                    table.insert(out, d)
                end
            end
        end
    end
    return out
end

local function findAxe()
    for _, tool in ipairs(gatherTools()) do
        local realName = (toolRealName(tool) or ""):lower()
        local objName  = (tool.Name or ""):lower()
        if realName:find("axe") or objName:find("axe") then
            return tool
        end
    end
    return nil
end

local function isPlank(model)
    if not model or not model:IsA("Model") then return false end
    if not ownerMatches(model, LocalPlayer) then return false end
    if not model:FindFirstChild("CutEvent") then return false end
    return true
end

local function findAllPlanks()
    local found = {}
    local seen = {}
    local pm = workspace:FindFirstChild("PlayerModels")
    local roots = { workspace }
    if pm then table.insert(roots, pm) end
    for _, root in ipairs(roots) do
        for _, m in ipairs(root:GetDescendants()) do
            if m:IsA("Model") and not seen[m] and isPlank(m) then
                seen[m] = true
                table.insert(found, m)
            end
        end
    end
    return found
end

local function getWoodSection(plank)
    local ws = plank:FindFirstChild("WoodSection")
    if ws and ws:IsA("BasePart") then return ws end
    return nil
end

local function getSize(plank)
    local ws = getWoodSection(plank)
    if ws then return ws.Size end
    local ok, _, s = pcall(function() return plank:GetBoundingBox() end)
    if ok then return s end
    return nil
end

local function getHP()
    local char = LocalPlayer.Character
    if not char then return 100 end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return 100 end
    return hum.Health
end

-- ============================================================
--  TELEPORT (safe: keeps player right above plank)
-- ============================================================
local function teleportToPlank(plank)
    local char = LocalPlayer.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    local ws = getWoodSection(plank)
    local targetPos = ws and ws.Position or plank:GetPivot().Position

    -- Slight offset to the side so the plank is in front of the player
    local goal = targetPos + CONFIG.TELEPORT_OFFSET
    root.CFrame = CFrame.new(goal, targetPos)
    root.AssemblyLinearVelocity = Vector3.zero
    task.wait(0.2)
    return true
end

-- ============================================================
--  EQUIP
-- ============================================================
local function ensureEquipped(axe)
    if not axe or not axe.Parent then return false end
    local char = LocalPlayer.Character
    if not char then return false end
    if axe.Parent == char then return true end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    pcall(function() hum:EquipTool(axe) end)
    task.wait(0.15)
    return axe.Parent == char
end

-- ============================================================
--  BURST FIRE (uses cached axe)
-- ============================================================
local function fireBurst(plank, axe, height, burstCount, burstDelay)
    local cutEvent = plank:FindFirstChild("CutEvent")
    if not cutEvent then
        log("!! No CutEvent on plank.")
        return 0
    end

    local fired = 0
    for i = 1, burstCount do
        if not plank.Parent then
            log("  plank gone at cut " .. i)
            break
        end

        -- HP safety
        if getHP() < CONFIG.MIN_HP_TO_CONTINUE then
            log("  HP low (" .. math.floor(getHP()) .. "), aborting burst")
            break
        end

        -- Verify axe still valid
        if not axe or not axe.Parent then
            axe = findAxe()
            if not axe then
                log("  axe lost at cut " .. i)
                break
            end
            log("  re-resolved axe: " .. toolRealName(axe))
        end

        -- Make sure it's equipped
        ensureEquipped(axe)

        -- Fire
        local payload = {
            height = height,
            faceVector = CONFIG.FACE_VECTOR,
            cooldown = CONFIG.COOLDOWN,
            sectionId = CONFIG.SECTION_ID,
            hitPoints = CONFIG.HIT_POINTS,
            tool = axe,
            cuttingClass = CONFIG.CUTTING_CLASS,
        }
        local ok = pcall(function()
            RemoteProxy:FireServer(cutEvent, payload)
        end)
        if ok then
            fired = fired + 1
            log(("  cut %d/%d fired (h=%s)"):format(i, burstCount, tostring(height)))
        else
            log(("  cut %d/%d FAILED"):format(i, burstCount))
        end

        task.wait(burstDelay)
    end

    return fired
end

-- ============================================================
--  TEST RUNNER
-- ============================================================
local busy = false

local function testOne(plank, heightOverride, overrideCuts, overrideDelay)
    if busy then return end
    busy = true

    log("========== TEST ==========")
    log("Plank: " .. plank.Name)

    local sizeBefore = getSize(plank)
    log("BEFORE size=" .. (sizeBefore and fmtVec(sizeBefore) or "?"))

    local axe = findAxe()
    if not axe then
        log("!! No axe anywhere. Equip one first.")
        busy = false
        return
    end
    log("Axe: " .. toolRealName(axe))

    -- Equip FIRST (before teleport so the tool follows)
    ensureEquipped(axe)

    -- Teleport
    teleportToPlank(plank)

    -- Height
    local h = heightOverride
    if not h then
        h = 1
        if sizeBefore then
            local maxDim = math.max(sizeBefore.X, sizeBefore.Y, sizeBefore.Z)
            if maxDim > 4 then
                h = maxDim / 2
                log(("Long plank (%.2f) — using h=%.2f"):format(maxDim, h))
            end
        end
    end

    local cuts = overrideCuts or CONFIG.CUTS_PER_BURST
    local delay = overrideDelay or CONFIG.BURST_DELAY
    log(("Firing %d cuts, %.2fs apart, h=%s ..."):format(cuts, delay, tostring(h)))

    local fired = fireBurst(plank, axe, h, cuts, delay)
    log(("Fired %d/%d remote(s)."):format(fired, cuts))

    -- Wait for the server to process
    task.wait(1.0)

    if plank.Parent then
        local sizeAfter = getSize(plank)
        log("AFTER  size=" .. (sizeAfter and fmtVec(sizeAfter) or "?"))
        if sizeBefore and sizeAfter then
            local diff = (sizeBefore - sizeAfter).Magnitude
            if diff > 0.05 then
                log(("*** SIZE CHANGED by %.2f - CUT WORKED! ***"):format(diff))
            else
                log("No size change.")
            end
        end
    else
        log("Plank DESTROYED - cut worked!")
    end

    log("========== DONE ==========")
    busy = false
end

-- ============================================================
--  BUTTONS
-- ============================================================
local function refreshAxeLabel()
    local axe = findAxe()
    if axe then
        axeInfo.Text = "axe: " .. toolRealName(axe)
    else
        axeInfo.Text = "axe: NONE"
    end
end

local function runListPlanks()
    for _, c in ipairs(picker:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end

    refreshAxeLabel()

    local planks = findAllPlanks()
    log(("Found %d plank(s)."):format(#planks))
    if #planks == 0 then
        picker.Visible = false
        return
    end

    local function score(p)
        local s = getSize(p)
        if not s then return 9999 end
        return math.abs(math.max(s.X, s.Y, s.Z) - 4)
    end
    table.sort(planks, function(a, b) return score(a) < score(b) end)

    for i, p in ipairs(planks) do
        local s = getSize(p)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -6, 0, 30)
        btn.BorderSizePixel = 0
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 12
        btn.Font = Enum.Font.Code
        btn.TextXAlignment = Enum.TextXAlignment.Left
        local maxDim = s and math.max(s.X, s.Y, s.Z) or 0
        local isIdeal = maxDim >= 2 and maxDim <= 10
        if isIdeal then
            btn.BackgroundColor3 = Color3.fromRGB(60, 140, 80)
        else
            btn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        end
        btn.Text = ("  #%d  size=%s%s"):format(i, s and fmtVec(s) or "?", isIdeal and " *" or "")
        btn.Parent = picker
        btn.Activated:Connect(function()
            picker.Visible = false
            log("Picked #" .. i)
            testOne(p)
        end)
    end
    picker.Visible = true
end

listBtn.Activated:Connect(runListPlanks)

copyBtn.Activated:Connect(function()
    if not setClipboard then
        log("!! No clipboard function in this executor.")
        return
    end
    local ok, err = pcall(function() setClipboard(table.concat(logBuffer, "\n")) end)
    if ok then
        log(">> Copied " .. #logBuffer .. " lines.")
    else
        log("!! Copy failed: " .. tostring(err))
    end
end)

clearBtn.Activated:Connect(function()
    logBuffer = {}
    for _, c in ipairs(logBox:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
end)

equipBtn.Activated:Connect(function()
    local axe = findAxe()
    if not axe then
        log("!! No axe.")
        return
    end
    if ensureEquipped(axe) then
        log("Equipped: " .. toolRealName(axe))
    else
        log("!! Equip failed.")
    end
end)

stopBtn.Activated:Connect(function()
    busy = false
    log("Stopped.")
end)

local function pickBiggestAndTest(heightFn, cuts, delay)
    local planks = findAllPlanks()
    if #planks == 0 then
        log("No planks.")
        return
    end
    table.sort(planks, function(a, b)
        local sa, sb = getSize(a), getSize(b)
        return (sa and sa.Magnitude or 0) > (sb and sb.Magnitude or 0)
    end)
    local p = planks[1]
    local h = heightFn and heightFn(p) or 1
    testOne(p, h, cuts, delay)
end

v_h1.Activated:Connect(function()
    pickBiggestAndTest(function() return 1 end)
end)

v_hHalf.Activated:Connect(function()
    pickBiggestAndTest(function(p)
        local s = getSize(p)
        if s then return math.max(s.X, s.Y, s.Z) / 2 end
        return 1
    end)
end)

v_h025.Activated:Connect(function()
    pickBiggestAndTest(function() return 0.25 end)
end)

v_test.Activated:Connect(function()
    pickBiggestAndTest(function() return 1 end, 1, 0) -- one cut, no delay
end)

-- Burst preset buttons
p_10x1.Activated:Connect(function()
    CONFIG.CUTS_PER_BURST = 10
    CONFIG.BURST_DELAY = 1.0
    log("Preset: 10 cuts @ 1s")
end)
p_10x05.Activated:Connect(function()
    CONFIG.CUTS_PER_BURST = 10
    CONFIG.BURST_DELAY = 0.5
    log("Preset: 10 cuts @ 0.5s")
end)
p_20x1.Activated:Connect(function()
    CONFIG.CUTS_PER_BURST = 20
    CONFIG.BURST_DELAY = 1.0
    log("Preset: 20 cuts @ 1s")
end)
p_30x05.Activated:Connect(function()
    CONFIG.CUTS_PER_BURST = 30
    CONFIG.BURST_DELAY = 0.5
    log("Preset: 30 cuts @ 0.5s")
end)

-- ============================================================
--  STARTUP
-- ============================================================
refreshAxeLabel()
log("v7 ready.")
log("Default: 10 cuts @ 1s between.")
log("Pick a green plank from 'List Planks', or tap 'h=1'.")
