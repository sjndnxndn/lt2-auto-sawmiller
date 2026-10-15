-- LT2 Cut Diagnostic v13
-- Uses Backpack tool (UNEQUIPPED) as the tool payload, like the game's own example.
-- No teleport. No equip.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Interaction = ReplicatedStorage:WaitForChild("Interaction")
local RemoteProxy = Interaction:WaitForChild("RemoteProxy")

local CONFIG = {
    CUTS_PER_BURST = 10,
    BURST_DELAY    = 1.0,
    MIN_HP         = 40,
    TAP_RADIUS     = 8,
    GODMODE        = true,
}

local setClipboard = nil
if type(setclipboard) == "function" then setClipboard = setclipboard
elseif type(toclipboard) == "function" then setClipboard = toclipboard
elseif type(writeClipboard) == "function" then setClipboard = writeClipboard
end

-- ============================================================
--  GODMODE
-- ============================================================
local godConn
local function applyGod()
    if godConn then return end
    godConn = RunService.Heartbeat:Connect(function()
        if not CONFIG.GODMODE then return end
        local c = LocalPlayer.Character
        if not c then return end
        local h = c:FindFirstChildOfClass("Humanoid")
        if h and h.Health < h.MaxHealth then h.Health = h.MaxHealth end
    end)
end
local function stopGod()
    if godConn then godConn:Disconnect(); godConn = nil end
end
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5); if CONFIG.GODMODE then stopGod(); applyGod() end
end)
if CONFIG.GODMODE then applyGod() end

-- ============================================================
--  GUI
-- ============================================================
local sg = Instance.new("ScreenGui")
sg.Name = "LT2_CutDiag13"
sg.ResetOnSpawn = false
sg.Parent = LocalPlayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 580, 0, 470)
frame.Position = UDim2.new(0.5, -290, 0.5, -235)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = sg

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
title.BorderSizePixel = 0
title.Text = "LT2 Cut Diagnostic v13 - backpack tool"
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

local listBtn  = mkBtn("List",      4,   32, 55, 30, Color3.fromRGB(60, 120, 200))
local copyBtn  = mkBtn("Copy",      62,  32, 55, 30, Color3.fromRGB(60, 180, 100))
local clearBtn = mkBtn("Clear",     120, 32, 55, 30, Color3.fromRGB(150, 80, 80))
local bpBtn    = mkBtn("To BP",     178, 32, 55, 30, Color3.fromRGB(200, 140, 50))
local stopBtn  = mkBtn("STOP",      236, 32, 55, 30, Color3.fromRGB(200, 50, 50))
local godBtn   = mkBtn("God: ON",   294, 32, 80, 30, Color3.fromRGB(60, 140, 100))
local dumpBtn  = mkBtn("Dump Tool", 378, 32, 90, 30, Color3.fromRGB(120, 120, 200))
local valBtn   = mkBtn("Dump Vals", 472, 32, 90, 30, Color3.fromRGB(120, 120, 200))

local axeInfo = Instance.new("TextLabel")
axeInfo.Size = UDim2.new(1, -100, 0, 30)
axeInfo.Position = UDim2.new(0, 4, 0, 66)
axeInfo.BackgroundTransparency = 1
axeInfo.Text = "axe: ?"
axeInfo.TextColor3 = Color3.fromRGB(255, 200, 100)
axeInfo.TextSize = 11
axeInfo.Font = Enum.Font.Code
axeInfo.TextXAlignment = Enum.TextXAlignment.Left
axeInfo.Parent = frame

local v_bp    = mkBtn("Test: BP Tool",      4,   92, 140, 28, Color3.fromRGB(60, 140, 80))
local v_bp2   = mkBtn("Test: BP Tool x5",   148, 92, 140, 28, Color3.fromRGB(70, 90, 130))
local v_both  = mkBtn("Test: BP + Equip",   292, 92, 140, 28, Color3.fromRGB(140, 90, 130))
local v_range = mkBtn("Test: h=Range",      436, 92, 120, 28, Color3.fromRGB(140, 100, 60))

local logBox = Instance.new("ScrollingFrame")
logBox.Size = UDim2.new(1, -10, 1, -260)
logBox.Position = UDim2.new(0, 5, 0, 130)
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
picker.Size = UDim2.new(1, -10, 0, 140)
picker.Position = UDim2.new(0, 5, 1, -148)
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
        local ok, v = pcall(function() return tn.Value end)
        if ok and v then return v end
    end
    return tool.Name
end

--- Look for the tool ONLY in the Backpack (unequipped), like the game's example.
local function findBackpackTool()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return nil end
    for _, d in ipairs(bp:GetChildren()) do
        if d:IsA("Tool") then
            local rn = (toolRealName(d) or ""):lower()
            local on = (d.Name or ""):lower()
            if rn:find("axe") or rn:find("hatchet")
               or on:find("axe") or on:find("hatchet") then
                return d
            end
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

local function getWoodType(plank)
    local tc = plank:FindFirstChild("TreeClass")
    if tc and tc:IsA("StringValue") then
        local ok, v = pcall(function() return tc.Value end)
        if ok and v then return v end
    end
    return "?"
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

local function getWoodSection(plank)
    local ws = plank:FindFirstChild("WoodSection")
    if ws and ws:IsA("BasePart") then return ws end
end

local function getSize(plank)
    local ws = getWoodSection(plank)
    if ws then return ws.Size end
    local ok, _, s = pcall(function() return plank:GetBoundingBox() end)
    if ok then return s end
end

local function getHP()
    local c = LocalPlayer.Character
    if not c then return 100 end
    local h = c:FindFirstChildOfClass("Humanoid")
    return h and h.Health or 100
end

local function distanceToPlank(plank)
    local c = LocalPlayer.Character
    if not c then return -1 end
    local root = c:FindFirstChild("HumanoidRootPart")
    if not root then return -1 end
    local ws = getWoodSection(plank)
    local pos = ws and ws.Position or plank:GetPivot().Position
    return (root.Position - pos).Magnitude
end

--- Move the axe to Backpack (unequip it) if it's currently held.
local function moveAxeToBackpack()
    local c = LocalPlayer.Character
    if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid")
    if h then
        pcall(function() h:UnequipTools() end)
        task.wait(0.3)
    end
end

-- ============================================================
--  FIRE
-- ============================================================
local function fireOnce(plank, tool, height)
    local cutEvent = plank:FindFirstChild("CutEvent")
    if not cutEvent then return false, "no CutEvent" end
    if not tool then return false, "no tool" end

    local payload = {
        height = height or 1,
        faceVector = Vector3.new(1, 0, 0),
        cooldown = 0.23737628459930421,
        sectionId = 1,
        hitPoints = 1.2,
        tool = tool,
        cuttingClass = "Axe",
    }
    local ok, err = pcall(function()
        RemoteProxy:FireServer(cutEvent, payload)
    end)
    return ok, err
end

-- ============================================================
--  TEST
-- ============================================================
local busy = false

local function testOne(plank, mode)
    if busy then return end
    busy = true

    log("========== TEST (" .. mode .. ") ==========")
    log("Plank: " .. plank.Name .. " wood=" .. getWoodType(plank))
    local before = getSize(plank)
    log("BEFORE size=" .. (before and fmtVec(before) or "?"))
    log(("Distance: %.2f  HP: %.0f"):format(distanceToPlank(plank), getHP()))

    -- Make sure axe is in Backpack
    moveAxeToBackpack()

    local tool = findBackpackTool()
    if not tool then
        log("!! No axe in Backpack.")
        busy = false
        return
    end
    log("Backpack tool: " .. toolRealName(tool) .. "  (obj=" .. tool.Name .. ")")

    -- Determine height
    local h = 1
    if mode == "h_range" then
        local rv = tool:FindFirstChild("Range")
        if rv and rv:IsA("NumberValue") then
            h = rv.Value
            log(("Range value = %.2f"):format(h))
        end
    end

    local cuts = (mode == "x5") and 5 or CONFIG.CUTS_PER_BURST
    local delay = CONFIG.BURST_DELAY

    for i = 1, cuts do
        if not plank.Parent then
            log("  plank gone at " .. i); break
        end
        if getHP() < CONFIG.MIN_HP then
            log(("  HP %.0f < %d, abort"):format(getHP(), CONFIG.MIN_HP))
            break
        end

        -- Re-read tool every cut (Backpack tool might have changed name/place)
        tool = findBackpackTool()
        if not tool then
            log("  no backpack tool at cut " .. i); break
        end

        local ok, err = fireOnce(plank, tool, h)
        if ok then
            log(("  cut %d/%d fired (h=%s) hp=%.0f"):format(i, cuts, tostring(h), getHP()))
        else
            log(("  cut %d/%d FAIL: %s"):format(i, cuts, tostring(err)))
        end

        task.wait(delay)
    end

    task.wait(1.0)
    if plank.Parent then
        local after = getSize(plank)
        log("AFTER size=" .. (after and fmtVec(after) or "?"))
        if before and after then
            local d = (before - after).Magnitude
            if d > 0.05 then
                log(("*** WORKED! diff=%.2f ***"):format(d))
            else
                log("No size change.")
            end
        end
    else
        log("Plank DESTROYED!")
    end
    log("========== DONE ==========")
    busy = false
end

-- ============================================================
--  BUTTONS
-- ============================================================
local function refreshAxeLabel()
    local bp = findBackpackTool()
    if bp then
        axeInfo.Text = "backpack axe: " .. toolRealName(bp)
        return
    end
    -- Check character
    local c = LocalPlayer.Character
    if c then
        for _, d in ipairs(c:GetChildren()) do
            if d:IsA("Tool") then
                axeInfo.Text = "axe is HELD: " .. toolRealName(d) .. " (unequip it)"
                return
            end
        end
    end
    axeInfo.Text = "axe: NONE"
end

local function runListPlanks()
    for _, c in ipairs(picker:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    refreshAxeLabel()
    local planks = findAllPlanks()
    log(("Found %d plank(s)."):format(#planks))
    if #planks == 0 then picker.Visible = false return end
    table.sort(planks, function(a, b)
        return (getSize(a) and getSize(a).Magnitude or 0) >
               (getSize(b) and getSize(b).Magnitude or 0)
    end)
    for i, p in ipairs(planks) do
        local s = getSize(p)
        local w = getWoodType(p)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -6, 0, 28)
        b.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        b.BorderSizePixel = 0
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.TextSize = 11
        b.Font = Enum.Font.Code
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.Text = ("  #%d [%s] %s"):format(i, w, s and fmtVec(s) or "?")
        b.Parent = picker
        b.Activated:Connect(function()
            picker.Visible = false
            testOne(p, "bp")
        end)
    end
    picker.Visible = true
end

listBtn.Activated:Connect(runListPlanks)

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

bpBtn.Activated:Connect(function()
    moveAxeToBackpack()
    refreshAxeLabel()
    log("Moved tools to Backpack.")
end)

stopBtn.Activated:Connect(function()
    busy = false
    log("Stopped.")
end)

godBtn.Activated:Connect(function()
    CONFIG.GODMODE = not CONFIG.GODMODE
    if CONFIG.GODMODE then
        godBtn.Text = "God: ON"
        godBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 100)
        applyGod(); log("Godmode ON.")
    else
        godBtn.Text = "God: OFF"
        godBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
        stopGod(); log("Godmode OFF.")
    end
end)

dumpBtn.Activated:Connect(function()
    local bp = findBackpackTool()
    local t = bp
    if not t then
        -- try held
        local c = LocalPlayer.Character
        if c then
            for _, d in ipairs(c:GetChildren()) do
                if d:IsA("Tool") then t = d; break end
            end
        end
    end
    if not t then log("!! No tool to dump.") return end
    log("=== TOOL DUMP: " .. t.Name .. " ===")
    for _, c in ipairs(t:GetDescendants()) do
        log(("  %s [%s]"):format(c.Name, c.ClassName))
    end
    log("=== END ===")
end)

valBtn.Activated:Connect(function()
    local bp = findBackpackTool()
    local t = bp
    if not t then
        local c = LocalPlayer.Character
        if c then
            for _, d in ipairs(c:GetChildren()) do
                if d:IsA("Tool") then t = d; break end
            end
        end
    end
    if not t then log("!! No tool.") return end
    log("=== VALUE DUMP: " .. t.Name .. " ===")
    for _, c in ipairs(t:GetDescendants()) do
        if c:IsA("StringValue") or c:IsA("NumberValue")
           or c:IsA("IntValue") or c:IsA("BoolValue")
           or c:IsA("ObjectValue") then
            local ok, v = pcall(function() return c.Value end)
            log(("  %s [%s] = %s"):format(c.Name, c.ClassName,
                ok and tostring(v) or "?"))
        end
    end
    log("=== END ===")
end)

-- Quick test buttons
local function pickBiggest(mode)
    local planks = findAllPlanks()
    if #planks == 0 then return end
    table.sort(planks, function(a, b)
        return (getSize(a) and getSize(a).Magnitude or 0) >
               (getSize(b) and getSize(b).Magnitude or 0)
    end)
    testOne(planks[1], mode)
end

v_bp.Activated:Connect(function() pickBiggest("bp") end)
v_bp2.Activated:Connect(function() pickBiggest("x5") end)
v_both.Activated:Connect(function() pickBiggest("bp") end)
v_range.Activated:Connect(function() pickBiggest("h_range") end)

-- ============================================================
--  TAP-TO-PICK
-- ============================================================
local function raycastFromScreen(pos)
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local ray = cam:ViewportPointToRay(pos.X, pos.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { sg, LocalPlayer.Character }
    local r = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
    return r and r.Instance, r and r.Position or nil
end

local function findPlankNear(worldPos, radius)
    local best, bestD = nil, math.huge
    for _, p in ipairs(findAllPlanks()) do
        local ws = getWoodSection(p)
        if ws then
            local lp = ws.CFrame:PointToObjectSpace(worldPos)
            local half = ws.Size / 2
            local cl = Vector3.new(
                math.clamp(lp.X, -half.X, half.X),
                math.clamp(lp.Y, -half.Y, half.Y),
                math.clamp(lp.Z, -half.Z, half.Z))
            local wp = ws.CFrame:PointToWorldSpace(cl)
            local d = (wp - worldPos).Magnitude
            if d < bestD then bestD = d; best = p end
        end
    end
    if best and bestD <= radius then return best, bestD end
    return nil, bestD
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
       and input.UserInputType ~= Enum.UserInputType.Touch then return end

    local pos = input.Position
    local guiObjs = LocalPlayer.PlayerGui:GetGuiObjectsAtPosition(pos.X, pos.Y)
    for _, obj in ipairs(guiObjs) do
        if obj:IsDescendantOf(sg) then return end
    end

    local hit, hitPos = raycastFromScreen(pos)
    if not hit then return end
    local model = hit:FindFirstAncestorOfClass("Model")
    if model and isPlank(model) then
        log("Tapped: " .. model.Name .. " [" .. getWoodType(model) .. "]")
        testOne(model, "bp")
        return
    end
    local nearby = findPlankNear(hitPos, CONFIG.TAP_RADIUS)
    if nearby then
        log("Nearby: " .. getWoodType(nearby))
        testOne(nearby, "bp")
    else
        log("No plank nearby.")
    end
end)

-- ============================================================
--  STARTUP
-- ============================================================
refreshAxeLabel()
log("v13 ready. NO teleport, NO equip.")
log("Uses the axe from your Backpack - like the game's own example.")
log("If your axe says 'HELD', press 'To BP' to unequip it.")
log("Then tap a plank or press 'Test: BP Tool'.")
