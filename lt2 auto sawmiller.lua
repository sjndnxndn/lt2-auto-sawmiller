-- LT2 Cut Diagnostic v6
-- Fires a burst of cut remotes after teleporting to the plank.
-- Clean rewrite — no goto, no nested pcall issues.

-- ============================================================
--  SERVICES
-- ============================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Interaction = ReplicatedStorage:WaitForChild("Interaction")
local RemoteProxy = Interaction:WaitForChild("RemoteProxy")

-- ============================================================
--  CONFIG  (tweak here)
-- ============================================================
local CONFIG = {
    CUTS_PER_BURST = 20,        -- how many remote fires per test
    BURST_DELAY    = 0.06,      -- seconds between fires
    TELEPORT_OFFSET = Vector3.new(3, 2, 0), -- side+up from plank center
    FACE_VECTOR    = Vector3.new(1, 0, 0),
    COOLDOWN       = 0.23737628459930421,
    SECTION_ID     = 1,
    HIT_POINTS     = 1.2,
    CUTTING_CLASS  = "Axe",
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
sg.Name = "LT2_CutDiag6"
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
title.Text = "LT2 Cut Diagnostic v6"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 14
title.Font = Enum.Font.SourceSansBold
title.Parent = frame

local function mkBtn(text, x, y, w, h, color, parent)
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
    b.Parent = parent or frame
    return b
end

-- Row 1
local listBtn  = mkBtn("List Planks",   4,   32, 110, 30, Color3.fromRGB(60, 120, 200))
local copyBtn  = mkBtn("Copy Log",      118, 32, 90,  30, Color3.fromRGB(60, 180, 100))
local clearBtn = mkBtn("Clear",         212, 32, 70,  30, Color3.fromRGB(150, 80, 80))
local equipBtn = mkBtn("Equip Axe",     286, 32, 90,  30, Color3.fromRGB(200, 140, 50))
local stopBtn  = mkBtn("STOP",          380, 32, 60,  30, Color3.fromRGB(200, 50, 50))

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

-- Row 2 — quick tests
local lbl2 = Instance.new("TextLabel")
lbl2.Size = UDim2.new(1, -8, 0, 18)
lbl2.Position = UDim2.new(0, 4, 0, 66)
lbl2.BackgroundTransparency = 1
lbl2.Text = "Quick test on largest plank (teleport + burst):"
lbl2.TextColor3 = Color3.fromRGB(200, 200, 200)
lbl2.TextSize = 11
lbl2.Font = Enum.Font.SourceSansBold
lbl2.TextXAlignment = Enum.TextXAlignment.Left
lbl2.Parent = frame

local v_h1    = mkBtn("h=1",           4,   86, 90, 28, Color3.fromRGB(70, 90, 130))
local v_hHalf = mkBtn("h=half",        98,  86, 90, 28, Color3.fromRGB(70, 90, 130))
local v_h025  = mkBtn("h=0.25",        192, 86, 90, 28, Color3.fromRGB(70, 90, 130))
local v_sweep = mkBtn("sweep 0.2-2",   286, 86, 120, 28, Color3.fromRGB(140, 90, 130))

-- Row 3 — burst controls
local lbl3 = Instance.new("TextLabel")
lbl3.Size = UDim2.new(1, -8, 0, 18)
lbl3.Position = UDim2.new(0, 4, 0, 116)
lbl3.BackgroundTransparency = 1
lbl3.Text = "Cuts per burst:"
lbl3.TextColor3 = Color3.fromRGB(200, 200, 200)
lbl3.TextSize = 11
lbl3.Font = Enum.Font.SourceSansBold
lbl3.TextXAlignment = Enum.TextXAlignment.Left
lbl3.Parent = frame

local b5   = mkBtn("5",    120, 114, 50, 24, Color3.fromRGB(70, 90, 130))
local b10  = mkBtn("10",   174, 114, 50, 24, Color3.fromRGB(70, 90, 130))
local b20  = mkBtn("20",   228, 114, 50, 24, Color3.fromRGB(60, 140, 80))
local b40  = mkBtn("40",   282, 114, 50, 24, Color3.fromRGB(70, 90, 130))
local b80  = mkBtn("80",   336, 114, 50, 24, Color3.fromRGB(70, 90, 130))

-- Log
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

-- Picker
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
    if pm then
        table.insert(roots, pm)
    end
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
    if ws and ws:IsA("BasePart") then
        return ws
    end
    return nil
end

local function getSize(plank)
    local ws = getWoodSection(plank)
    if ws then return ws.Size end
    local ok, _, s = pcall(function() return plank:GetBoundingBox() end)
    if ok then return s end
    return nil
end

-- ============================================================
--  TELEPORT
-- ============================================================
local function teleportToPlank(plank)
    local char = LocalPlayer.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local ws = getWoodSection(plank)
    local targetPos = ws and ws.Position or plank:GetPivot().Position
    local goal = targetPos + CONFIG.TELEPORT_OFFSET
    root.CFrame = CFrame.new(goal, targetPos)
    task.wait(0.15)
    return true
end

-- ============================================================
--  BURST FIRE
-- ============================================================
local function fireBurst(plank, height)
    local axe = findAxe()
    if not axe then
        log("!! No axe.")
        return 0
    end

    local cutEvent = plank:FindFirstChild("CutEvent")
    if not cutEvent then
        log("!! No CutEvent on plank.")
        return 0
    end

    local fired = 0
    for i = 1, CONFIG.CUTS_PER_BURST do
        if not plank.Parent then break end

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
        end

        task.wait(CONFIG.BURST_DELAY)
    end
    return fired
end

-- ============================================================
--  TEST RUNNER
-- ============================================================
local busy = false

local function testOne(plank, heightOverride)
    if busy then return end
    busy = true

    log("========== TEST ==========")
    log("Plank: " .. plank.Name)

    local size = getSize(plank)
    log("BEFORE size=" .. (size and fmtVec(size) or "?"))

    local axe = findAxe()
    if not axe then
        log("!! No axe.")
        busy = false
        return
    end
    log("Axe: " .. toolRealName(axe))

    -- Equip
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and axe.Parent ~= char then
            pcall(function() hum:EquipTool(axe) end)
            task.wait(0.1)
        end
    end

    -- Teleport
    teleportToPlank(plank)

    -- Height
    local h = heightOverride
    if not h then
        h = 1
        if size then
            local maxDim = math.max(size.X, size.Y, size.Z)
            if maxDim > 4 then
                h = maxDim / 2
                log(("Long plank (%.2f) — using h=%.2f"):format(maxDim, h))
            end
        end
    end

    -- Burst
    log(("Firing %d cuts at h=%s ..."):format(CONFIG.CUTS_PER_BURST, tostring(h)))
    local fired = fireBurst(plank, h)
    log(("Fired %d remote(s)."):format(fired))

    -- Wait for server
    task.wait(1.0)

    -- Check result
    if plank.Parent then
        local afterSize = getSize(plank)
        log("AFTER  size=" .. (afterSize and fmtVec(afterSize) or "?"))
        if size and afterSize then
            local diff = (size - afterSize).Magnitude
            if diff > 0.05 then
                log(("*** SIZE CHANGED by %.2f — CUT WORKED! ***"):format(diff))
            else
                log("No size change.")
            end
        end
    else
        log("Plank DESTROYED — cut worked!")
    end

    log("========== DONE ==========")
    busy = false
end

-- ============================================================
--  SWEEP
-- ============================================================
local sweepRunning = false

local function runSweep()
    if sweepRunning then return end
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
    sweepRunning = true

    task.spawn(function()
        log("=== SWEEP 0.2..2.0 on " .. p.Name .. " ===")
        local h = 0.2
        while h <= 2.0 and sweepRunning do
            if not p.Parent then
                log("Plank gone during sweep.")
                break
            end
            local sizeBefore = getSize(p)
            teleportToPlank(p)
            local fired = fireBurst(p, h)
            task.wait(1.0)
            if not p.Parent then
                log(("h=%.2f  ->  PLANK DESTROYED (fired %d)"):format(h, fired))
                break
            end
            local sizeAfter = getSize(p)
            local changed = sizeBefore and sizeAfter
                and (sizeBefore - sizeAfter).Magnitude > 0.05
            log(("h=%.2f  before=%s  after=%s  %s"):format(
                h,
                sizeBefore and fmtVec(sizeBefore) or "?",
                sizeAfter and fmtVec(sizeAfter) or "?",
                changed and "<<< SUCCESS" or ""))
            if changed then
                log("SUCCESS at h=" .. h)
                break
            end
            h = h + 0.2
        end
        sweepRunning = false
        log("=== SWEEP DONE ===")
    end)
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
        if c:IsA("TextButton") then
            c:Destroy()
        end
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
        btn.Text = ("  #%d  size=%s%s"):format(
            i, s and fmtVec(s) or "?", isIdeal and " *" or "")
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
    local text = table.concat(logBuffer, "\n")
    local ok, err = pcall(function() setClipboard(text) end)
    if ok then
        log(">> Copied " .. #logBuffer .. " lines.")
    else
        log("!! Copy failed: " .. tostring(err))
    end
end)

clearBtn.Activated:Connect(function()
    logBuffer = {}
    for _, c in ipairs(logBox:GetChildren()) do
        if c:IsA("TextLabel") then
            c:Destroy()
        end
    end
end)

equipBtn.Activated:Connect(function()
    local axe = findAxe()
    if not axe then
        log("!! No axe.")
        return
    end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum:EquipTool(axe)
        log("Equipped: " .. toolRealName(axe))
    end
end)

stopBtn.Activated:Connect(function()
    busy = false
    sweepRunning = false
    log("Stopped.")
end)

-- Quick tests
local function pickBiggestAndTest(heightFn)
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
    testOne(p, h)
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

v_sweep.Activated:Connect(runSweep)

-- Burst size buttons
b5.Activated:Connect(function()
    CONFIG.CUTS_PER_BURST = 5
    log("Cuts per burst = 5")
end)
b10.Activated:Connect(function()
    CONFIG.CUTS_PER_BURST = 10
    log("Cuts per burst = 10")
end)
b20.Activated:Connect(function()
    CONFIG.CUTS_PER_BURST = 20
    log("Cuts per burst = 20")
end)
b40.Activated:Connect(function()
    CONFIG.CUTS_PER_BURST = 40
    log("Cuts per burst = 40")
end)
b80.Activated:Connect(function()
    CONFIG.CUTS_PER_BURST = 80
    log("Cuts per burst = 80")
end)

-- ============================================================
--  STARTUP
-- ============================================================
refreshAxeLabel()
log("v6 ready.")
log("Burst = 20 cuts per test by default.")
log("Tap 'h=1' to test on your largest plank.")
log("If no change, try 'sweep 0.2-2' or bump cuts per burst.")
