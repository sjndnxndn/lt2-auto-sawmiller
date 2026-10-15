-- LT2 Cut Diagnostic v5
-- Teleports player next to plank before firing cut.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local RemoteProxy = ReplicatedStorage:WaitForChild("Interaction"):WaitForChild("RemoteProxy")
local TestPing = ReplicatedStorage:FindFirstChild("TestPing")

local setClipboard =
    (type(setclipboard) == "function" and setclipboard)
    or (type(toclipboard) == "function" and toclipboard)
    or (type(writeClipboard) == "function" and writeClipboard)
    or nil

-- ============================================================
--  GUI
-- ============================================================
local sg = Instance.new("ScreenGui")
sg.Name = "LT2_CutDiag5"
sg.ResetOnSpawn = false
sg.Parent = LocalPlayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 560, 0, 480)
frame.Position = UDim2.new(0.5, -280, 0.5, -240)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = sg

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
title.BorderSizePixel = 0
title.Text = "LT2 Cut Diagnostic v5 - teleport edition"
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

local listBtn  = mkBtn("List Planks",      4,   32, 110, 30, Color3.fromRGB(60, 120, 200))
local pingBtn  = mkBtn("Test Ping",        118, 32, 90,  30, Color3.fromRGB(140, 100, 200))
local copyBtn  = mkBtn("Copy Log",         212, 32, 90,  30, Color3.fromRGB(60, 180, 100))
local clearBtn = mkBtn("Clear",            306, 32, 60,  30, Color3.fromRGB(150, 80, 80))
local equipBtn = mkBtn("Equip Axe",        370, 32, 90,  30, Color3.fromRGB(200, 140, 50))

local axeInfo = Instance.new("TextLabel")
axeInfo.Size = UDim2.new(1, -464, 0, 30)
axeInfo.Position = UDim2.new(0, 462, 0, 32)
axeInfo.BackgroundTransparency = 1
axeInfo.Text = "axe: ?"
axeInfo.TextColor3 = Color3.fromRGB(255, 200, 100)
axeInfo.TextSize = 11
axeInfo.Font = Enum.Font.Code
axeInfo.TextXAlignment = Enum.TextXAlignment.Left
axeInfo.Parent = frame

-- Row 2: Test variants
local variantsLabel = Instance.new("TextLabel")
variantsLabel.Size = UDim2.new(1, -8, 0, 18)
variantsLabel.Position = UDim2.new(0, 4, 0, 66)
variantsLabel.BackgroundTransparency = 1
variantsLabel.Text = "Quick test (auto-picks largest plank, teleports, fires):"
variantsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
variantsLabel.TextSize = 11
variantsLabel.Font = Enum.Font.SourceSansBold
variantsLabel.TextXAlignment = Enum.TextXAlignment.Left
variantsLabel.Parent = frame

local function mkSmall(text, x, color)
    return mkBtn(text, x, 86, 108, 28, color)
end

local v_h1     = mkSmall("h=1",           4,   Color3.fromRGB(70, 90, 130))
local v_hHalf  = mkSmall("h=half len",    116, Color3.fromRGB(70, 90, 130))
local v_h025   = mkSmall("h=0.25",        228, Color3.fromRGB(70, 90, 130))
local v_sweep  = mkSmall("sweep 0.2-2",   340, Color3.fromRGB(140, 90, 130))

-- Row 3: Try cutting via all plank models in a loop
local loopBtn = mkBtn("Loop All Planks (h=1)", 4, 118, 250, 28, Color3.fromRGB(200, 100, 60))
local stopBtn = mkBtn("Stop",                   258, 118, 80, 28, Color3.fromRGB(150, 60, 60))
local teleportBtn = mkBtn("TP+Cut (h=1)",       342, 118, 140, 28, Color3.fromRGB(60, 140, 100))

local logBox = Instance.new("ScrollingFrame")
logBox.Size = UDim2.new(1, -10, 1, -270)
logBox.Position = UDim2.new(0, 5, 0, 152)
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
picker.Size = UDim2.new(1, -10, 0, 160)
picker.Position = UDim2.new(0, 5, 1, -168)
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
    if tn and tn:IsA("StringValue") then return tn.Value end
    return tool.Name
end

local function gatherTools()
    local out = {}
    for _, c in ipairs({
        LocalPlayer:FindFirstChild("Backpack"),
        LocalPlayer:FindFirstChild("Tools"),
        LocalPlayer.Character,
    }) do
        if c then
            for _, d in ipairs(c:GetDescendants()) do
                if d:IsA("Tool") then table.insert(out, d) end
            end
        end
    end
    return out
end

local function findAxe()
    for _, tool in ipairs(gatherTools()) do
        local rn = (toolRealName(tool) or ""):lower()
        local on = (tool.Name or ""):lower()
        if rn:find("axe") or on:find("axe") then return tool end
    end
    return nil
end

local function isPlank(model)
    if not model or not model:IsA("Model") then return false end
    if not ownerMatches(model, LocalPlayer) then return false end
    return model:FindFirstChild("CutEvent") ~= nil
end

local function findAllPlanks()
    local found, seen = {}, {}
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

local function plankSize(p)
    local ok, _, size = pcall(function() return p:GetBoundingBox() end)
    return ok and size or nil
end

-- ============================================================
--  TELEPORT
-- ============================================================
local function teleportToPlank(plank)
    local char = LocalPlayer.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not root then return false end

    local ws = plank:FindFirstChild("WoodSection")
    local targetPos = (ws and ws:IsA("BasePart") and ws.Position) or plank:GetPivot().Position

    -- Land 3 studs to the side and 2 studs above the plank center
    local offset = Vector3.new(3, 2, 0)
    local goal = targetPos + offset
    root.CFrame = CFrame.new(goal, targetPos) -- face the plank
    task.wait(0.15) -- let the server see us move
    return true
end

local function distanceToPlank(plank)
    local char = LocalPlayer.Character
    if not char then return -1 end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return -1 end
    local ws = plank:FindFirstChild("WoodSection")
    local targetPos = (ws and ws:IsA("BasePart") and ws.Position) or plank:GetPivot().Position
    return (root.Position - targetPos).Magnitude
end

-- ============================================================
--  CUT
-- ============================================================
local function fireCut(plank, axe, height, sectionId, faceVector)
    local cutEvent = plank:FindFirstChild("CutEvent")
    if not cutEvent then log("!! No CutEvent"); return false end

    local payload = {
        height = height or 1,
        faceVector = faceVector or Vector3.new(1, 0, 0),
        cooldown = 0.23737628459930421,
        sectionId = sectionId or 1,
        hitPoints = 1.2,
        tool = axe,
        cuttingClass = "Axe",
    }
    local ok, err = pcall(function()
        RemoteProxy:FireServer(cutEvent, payload)
    end)
    if not ok then log("!! FireServer error: " .. tostring(err)) return false end
    return true
end

local busy = false

local function testOne(plank, heightOverride)
    if busy then return end
    busy = true

    local axe = findAxe()
    if not axe then log("!! No axe."); busy = false; return end

    log(("---- TEST on %s ----"):format(plank.Name))
    local ws = plank:FindFirstChild("WoodSection")
    if ws then log(("BEFORE WoodSection.Size=%s"):format(fmtVec(ws.Size))) end

    -- 1) Teleport near plank
    local dBefore = distanceToPlank(plank)
    teleportToPlank(plank)
    local dAfter = distanceToPlank(plank)
    log(("Distance before=%.2f  after=%.2f"):format(dBefore, dAfter))

    -- 2) Equip the axe
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and axe.Parent ~= char then
        pcall(function() hum:EquipTool(axe) end)
        task.wait(0.1)
    end

    -- 3) Determine height
    local size = plankSize(plank)
    local useHeight = heightOverride
    if not useHeight then
        useHeight = 1
        if size then
            local maxDim = math.max(size.X, size.Y, size.Z)
            if maxDim < 1.5 then
                log(("Plank too small (max=%.2f). Skipping."):format(maxDim))
                busy = false; return
            end
            if maxDim > 4 then
                useHeight = maxDim / 2
                log(("Plank long (%.2f) — using h=%.2f"):format(maxDim, useHeight))
            end
        end
    end

    log(("Firing cut: h=%s"):format(tostring(useHeight)))
    fireCut(plank, axe, useHeight)

    task.wait(1.5)

    if ws and ws.Parent then
        log(("AFTER  WoodSection.Size=%s"):format(fmtVec(ws.Size)))
        local s = plankSize(plank)
        log(("AFTER  bbox=%s"):format(s and fmtVec(s) or "?"))
    else
        log("Plank gone.")
    end
    log("---- DONE ----")

    busy = false
end

-- ============================================================
--  BUTTON WIRING
-- ============================================================
local function runListPlanks()
    for _, c in ipairs(picker:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end

    local axe = findAxe()
    axeInfo.Text = axe and ("axe: " .. toolRealName(axe)) or "axe: NONE"

    local planks = findAllPlanks()
    log(("Found %d plank(s)."):format(#planks))
    if #planks == 0 then picker.Visible = false return end

    local function score(p)
        local s = plankSize(p)
        if not s then return 9999 end
        return math.abs(math.max(s.X, s.Y, s.Z) - 4)
    end
    table.sort(planks, function(a, b) return score(a) < score(b) end)

    for i, p in ipairs(planks) do
        local s = plankSize(p)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -6, 0, 30)
        btn.BorderSizePixel = 0
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 12
        btn.Font = Enum.Font.Code
        btn.TextXAlignment = Enum.TextXAlignment.Left
        local maxDim = s and math.max(s.X, s.Y, s.Z) or 0
        local ideal = (maxDim >= 2 and maxDim <= 10)
        btn.BackgroundColor3 = ideal and Color3.fromRGB(60, 140, 80)
                                       or Color3.fromRGB(70, 70, 70)
        btn.Text = ("  #%d  size=%s%s"):format(i, s and fmtVec(s) or "?", ideal and " *" or "")
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

pingBtn.Activated:Connect(function()
    if not TestPing then log("!! No TestPing"); return end
    local ok, r = pcall(function() return TestPing:InvokeServer() end)
    log("Ping: " .. (ok and tostring(r) or ("err " .. tostring(r))))
end)

copyBtn.Activated:Connect(function()
    if not setClipboard then log("!! no clipboard") return end
    pcall(function() setClipboard(table.concat(logBuffer, "\n")) end)
    log(">> Copied " .. #logBuffer .. " lines.")
end)

clearBtn.Activated:Connect(function()
    logBuffer = {}
    for _, c in ipairs(logBox:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
end)

equipBtn.Activated:Connect(function()
    local axe = findAxe()
    if not axe then log("!! No axe.") return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum:EquipTool(axe)
        log("Equipped: " .. toolRealName(axe))
    end
end)

--- Pick the largest plank and test with a specific height.
local function pickBiggestAndTest(height)
    local planks = findAllPlanks()
    if #planks == 0 then log("No planks.") return end
    table.sort(planks, function(a, b)
        local sa, sb = plankSize(a), plankSize(b)
        return (sa and sa.Magnitude or 0) > (sb and sb.Magnitude or 0)
    end)
    testOne(planks[1], height)
end

v_h1.Activated:Connect(function()    pickBiggestAndTest(1) end)
v_hHalf.Activated:Connect(function()
    local planks = findAllPlanks()
    if #planks == 0 then return end
    table.sort(planks, function(a, b)
        local sa, sb = plankSize(a), plankSize(b)
        return (sa and sa.Magnitude or 0) > (sb and sb.Magnitude or 0)
    end)
    local s = plankSize(planks[1])
    testOne(planks[1], s and (math.max(s.X, s.Y, s.Z) / 2) or 1)
end)
v_h025.Activated:Connect(function()  pickBiggestAndTest(0.25) end)

--- Sweep: try h from 0.2 to 2 in small steps on the biggest plank.
v_sweep.Activated:Connect(function()
    local planks = findAllPlanks()
    if #planks == 0 then return end
    table.sort(planks, function(a, b)
        local sa, sb = plankSize(a), plankSize(b)
        return (sa and sa.Magnitude or 0) > (sb and sb.Magnitude or 0)
    end)
    local p = planks[1]
    log("=== SWEEP h=0.2..2 on " .. p.Name .. " ===")
    task.spawn(function()
        local h = 0.2
        while h <= 2.0 do
            local axe = findAxe()
            if not axe then break end
            teleportToPlank(p)
            local ws = p:FindFirstChild("WoodSection")
            local beforeSize = ws and ws.Size
            fireCut(p, axe, h)
            task.wait(1.2)
            local afterSize = ws and ws.Parent and ws.Size or nil
            local changed = beforeSize and afterSize and
                (beforeSize - afterSize).Magnitude > 0.01
            log(("  h=%.2f  before=%s  after=%s  %s"):format(
                h,
                beforeSize and fmtVec(beforeSize) or "?",
                afterSize and fmtVec(afterSize) or "gone",
                changed and "<== CUT!" or ""))
            if changed then
                log("SUCCESS at h=" .. h)
                return
            end
            h = h + 0.2
        end
        log("Sweep done — no height produced a cut.")
    end)
end)

--- Loop through every plank once, teleport + cut.
local loopRunning = false
loopBtn.Activated:Connect(function()
    if loopRunning then return end
    loopRunning = true
    local planks = findAllPlanks()
    log(("=== LOOP over %d planks ==="):format(#planks))
    task.spawn(function()
        for i, p in ipairs(planks) do
            if not loopRunning then break end
            local axe = findAxe()
            if not axe then break end
            if not p.Parent then goto continue end

            local ws = p:FindFirstChild("WoodSection")
            local beforeSize = ws and ws.Size
            local s = plankSize(p)
            if s and math.max(s.X, s.Y, s.Z) < 1.5 then
                -- skip tiny planks
                goto continue
            end
            teleportToPlank(p)
            fireCut(p, axe, 1)
            task.wait(1.0)
            local afterSize = ws and ws.Parent and ws.Size
            local changed = beforeSize and afterSize and
                (beforeSize - afterSize).Magnitude > 0.01
            if changed then
                log(("#%d CUT! %s -> %s"):format(i, fmtVec(beforeSize), fmtVec(afterSize)))
            end
            ::continue::
        end
        loopRunning = false
        log("=== LOOP done ===")
    end)
end)

stopBtn.Activated:Connect(function()
    loopRunning = false
    busy = false
    log("Stopped.")
end)

teleportBtn.Activated:Connect(function()
    pickBiggestAndTest(1)
end)

-- ============================================================
--  STARTUP
-- ============================================================
do
    local axe = findAxe()
    if axe then
        axeInfo.Text = "axe: " .. toolRealName(axe)
        log("Axe: " .. toolRealName(axe))
    else
        axeInfo.Text = "axe: NONE"
    end
    log("Teleport-before-cut is now enabled.")
    log("Try: 'h=1' on a green plank, or 'sweep 0.2-2' to brute-force the height.")
end
