-- LT2 Cut Diagnostic v4
-- Adds TestPing, tries multiple payloads, highlights big planks to test.

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
sg.Name = "LT2_CutDiag4"
sg.ResetOnSpawn = false
sg.Parent = LocalPlayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 560, 0, 460)
frame.Position = UDim2.new(0.5, -280, 0.5, -230)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = sg

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
title.BorderSizePixel = 0
title.Text = "LT2 Cut Diagnostic v4"
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

-- Payload variation row
local payloadLabel = Instance.new("TextLabel")
payloadLabel.Size = UDim2.new(1, -8, 0, 20)
payloadLabel.Position = UDim2.new(0, 4, 0, 66)
payloadLabel.BackgroundTransparency = 1
payloadLabel.Text = "Test payload:"
payloadLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
payloadLabel.TextSize = 11
payloadLabel.Font = Enum.Font.SourceSansBold
payloadLabel.TextXAlignment = Enum.TextXAlignment.Left
payloadLabel.Parent = frame

local h1Btn  = mkBtn("h=1",        4,   88, 80, 28, Color3.fromRGB(70, 90, 130))
local h2Btn  = mkBtn("h=1.5",      88,  88, 80, 28, Color3.fromRGB(70, 90, 130))
local h3Btn  = mkBtn("h=2",        172, 88, 80, 28, Color3.fromRGB(70, 90, 130))
local hHalf  = mkBtn("h=1/2 len",  256, 88, 100, 28, Color3.fromRGB(70, 90, 130))

local logBox = Instance.new("ScrollingFrame")
logBox.Size = UDim2.new(1, -10, 1, -230)
logBox.Position = UDim2.new(0, 5, 0, 124)
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
    if ok then return size end
end

local function snapshot(model, tag)
    log(("[%s] %s  pivot=%s"):format(tag, model.Name, fmtVec(model:GetPivot().Position)))
    local ws = model:FindFirstChild("WoodSection")
    if ws and ws:IsA("BasePart") then
        log(("[%s] WoodSection.Size=%s  Pos=%s"):format(
            tag, fmtVec(ws.Size), fmtVec(ws.Position)))
    end
end

-- ============================================================
--  CUT TEST
-- ============================================================
local busy = false

local function fireCut(plank, axe, height)
    local cutEvent = plank:FindFirstChild("CutEvent")
    if not cutEvent then
        log("!! No CutEvent child."); return false
    end

    local payload = {
        height = height,
        faceVector = Vector3.new(1, 0, 0),
        cooldown = 0.23737628459930421,
        sectionId = 1,
        hitPoints = 1.2,
        tool = axe,
        cuttingClass = "Axe",
    }
    log(("Firing: height=%s faceVector=(1,0,0) sectionId=1 hitPoints=1.2"):format(tostring(height)))
    local ok, err = pcall(function()
        RemoteProxy:FireServer(cutEvent, payload)
    end)
    if not ok then
        log("!! FireServer error: " .. tostring(err))
        return false
    end
    return true
end

local function runCutTest(plank, heightOverride)
    if busy then return end
    busy = true

    log("========== NEW TEST ==========")
    log("Time: " .. os.date("%H:%M:%S"))
    snapshot(plank, "BEFORE")

    local axe = findAxe()
    if not axe then
        log("!! No axe. Aborting."); busy = false; return
    end
    log("Axe: " .. toolRealName(axe))

    -- Watch workspace for new objects
    local before = {}
    for _, c in ipairs(workspace:GetChildren()) do before[c] = true end
    local watching = true
    task.spawn(function()
        local t0 = tick()
        while watching and tick() - t0 < 2.5 do
            for _, c in ipairs(workspace:GetChildren()) do
                if not before[c] then
                    before[c] = true
                    log("[NEW] " .. c.ClassName .. " : " .. c.Name)
                end
            end
            task.wait(0.1)
        end
    end)

    -- Determine height: use override, or 1/2 the longest dim if too long
    local size = plankSize(plank)
    local useHeight = heightOverride
    if not useHeight then
        useHeight = 1
        if size then
            local maxDim = math.max(size.X, size.Y, size.Z)
            if maxDim < 2 then
                log(("!! Plank longest axis = %.2f studs. Too small to cut. Try a bigger one."):format(maxDim))
                watching = false; busy = false; return
            end
            -- Use half the longest axis if it's very long
            if maxDim > 4 then
                useHeight = maxDim / 2
                log(("Plank is long (%.2f) — using half (%.2f) as height."):format(maxDim, useHeight))
            end
        end
    end

    if not fireCut(plank, axe, useHeight) then
        watching = false; busy = false; return
    end

    task.wait(2)

    if plank.Parent then
        snapshot(plank, "AFTER ")
    else
        log("Plank DESTROYED.")
    end

    watching = false
    log("========== DONE =========")
    busy = false
end

-- ============================================================
--  BUTTONS
-- ============================================================
local function runListPlanks()
    for _, c in ipairs(picker:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end

    local axe = findAxe()
    axeInfo.Text = axe and ("axe: " .. toolRealName(axe)) or "axe: NONE"

    local planks = findAllPlanks()
    log(("Found %d plank(s)."):format(#planks))
    if #planks == 0 then picker.Visible = false; return end

    -- Sort so the middle-sized planks (2-8 studs) come first — those are ideal test targets
    local function score(p)
        local s = plankSize(p)
        if not s then return 9999 end
        local m = math.max(s.X, s.Y, s.Z)
        -- Distance from ideal = 4 studs
        return math.abs(m - 4)
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
        local tag = ideal and " *BEST*" or ""
        btn.Text = ("  #%d  size=%s%s"):format(i, s and fmtVec(s) or "?", tag)
        btn.Parent = picker
        btn.Activated:Connect(function()
            picker.Visible = false
            log("Picked plank #" .. i)
            runCutTest(p)
        end)
    end
    picker.Visible = true
end

listBtn.Activated:Connect(runListPlanks)

pingBtn.Activated:Connect(function()
    if not TestPing then
        log("!! TestPing not found in ReplicatedStorage.")
        return
    end
    local ok, result = pcall(function()
        return TestPing:InvokeServer()
    end)
    if ok then
        log("TestPing result: " .. tostring(result))
    else
        log("TestPing error: " .. tostring(result))
    end
end)

copyBtn.Activated:Connect(function()
    if not setClipboard then log("!! no clipboard") return end
    local ok, err = pcall(function() setClipboard(table.concat(logBuffer, "\n")) end)
    if ok then log(">> Copied " .. #logBuffer .. " lines.") else log("!! " .. tostring(err)) end
end)

clearBtn.Activated:Connect(function()
    logBuffer = {}
    for _, c in ipairs(logBox:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
end)

equipBtn.Activated:Connect(function()
    local axe = findAxe()
    if not axe then log("!! No axe found.") return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum:EquipTool(axe)
        log("Equipped: " .. toolRealName(axe))
    end
end)

-- Height variation buttons — after picking a plank, click one to test
local function pickAndCut(height)
    local planks = findAllPlanks()
    if #planks == 0 then log("No planks.") return end
    -- Pick the biggest one for testing
    table.sort(planks, function(a, b)
        local sa, sb = plankSize(a), plankSize(b)
        return (sa and sa.Magnitude or 0) > (sb and sb.Magnitude or 0)
    end)
    runCutTest(planks[1], height)
end

h1Btn.Activated:Connect(function() pickAndCut(1) end)
h2Btn.Activated:Connect(function() pickAndCut(1.5) end)
h3Btn.Activated:Connect(function() pickAndCut(2) end)
hHalf.Activated:Connect(function()
    local planks = findAllPlanks()
    if #planks == 0 then return end
    table.sort(planks, function(a, b)
        local sa, sb = plankSize(a), plankSize(b)
        return (sa and sa.Magnitude or 0) > (sb and sb.Magnitude or 0)
    end)
    local s = plankSize(planks[1])
    local h = s and math.max(s.X, s.Y, s.Z) / 2 or 1
    runCutTest(planks[1], h)
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
        log("No axe detected.")
    end
    log("--- HOW TO TEST ---")
    log("1. Tap 'Test Ping' - confirms server responds.")
    log("2. Tap 'List Planks' - green entries are good test targets (*BEST*).")
    log("3. Pick a GREEN plank to test cut with default payload (h=1).")
    log("4. Or use h=1.5 / h=2 / h=1/2 len buttons to try variations")
    log("   (these pick the LARGEST plank automatically).")
    log("5. Copy Log after each test.")
end
