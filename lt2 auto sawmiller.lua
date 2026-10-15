-- LT2 Cut Diagnostic v12
-- Tries tool:Activate() instead of hand-firing the remote.
-- No teleport at all.

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
    task.wait(0.5)
    if CONFIG.GODMODE then stopGod(); applyGod() end
end)
if CONFIG.GODMODE then applyGod() end

-- ============================================================
--  GUI
-- ============================================================
local sg = Instance.new("ScreenGui")
sg.Name = "LT2_CutDiag12"
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
title.Text = "LT2 Cut Diagnostic v12 - activate test"
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

local listBtn  = mkBtn("List",       4,   32, 55, 30, Color3.fromRGB(60, 120, 200))
local copyBtn  = mkBtn("Copy",       62,  32, 55, 30, Color3.fromRGB(60, 180, 100))
local clearBtn = mkBtn("Clear",      120, 32, 55, 30, Color3.fromRGB(150, 80, 80))
local equipBtn = mkBtn("Equip",      178, 32, 55, 30, Color3.fromRGB(200, 140, 50))
local stopBtn  = mkBtn("STOP",       236, 32, 55, 30, Color3.fromRGB(200, 50, 50))
local godBtn   = mkBtn("God: ON",    294, 32, 80, 30, Color3.fromRGB(60, 140, 100))
local toolBtn  = mkBtn("Dump Tool",  378, 32, 90, 30, Color3.fromRGB(120, 120, 200))

local axeInfo = Instance.new("TextLabel")
axeInfo.Size = UDim2.new(1, -470, 0, 30)
axeInfo.Position = UDim2.new(0, 470, 0, 32)
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
lbl2.Text = "Pick a plank (list or tap). Script will NOT teleport you."
lbl2.TextColor3 = Color3.fromRGB(200, 200, 200)
lbl2.TextSize = 11
lbl2.Font = Enum.Font.SourceSansBold
lbl2.TextXAlignment = Enum.TextXAlignment.Left
lbl2.Parent = frame

local v_act   = mkBtn("Test: Activate",    4,   86, 140, 28, Color3.fromRGB(60, 140, 80))
local v_remote= mkBtn("Test: Remote",      148, 86, 140, 28, Color3.fromRGB(70, 90, 130))
local v_both  = mkBtn("Test: Both",        292, 86, 140, 28, Color3.fromRGB(140, 90, 130))
local v_bp    = mkBtn("Test: BP Remote",   436, 86, 120, 28, Color3.fromRGB(140, 100, 60))

local logBox = Instance.new("ScrollingFrame")
logBox.Size = UDim2.new(1, -10, 1, -250)
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
picker.Size = UDim2.new(1, -10, 0, 130)
picker.Position = UDim2.new(0, 5, 1, -138)
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

local function findAxe()
    local seen = {}
    local order = {
        LocalPlayer:FindFirstChild("Backpack"),
        LocalPlayer:FindFirstChild("Tools"),
        LocalPlayer.Character,
        LocalPlayer,
    }
    for _, container in ipairs(order) do
        if container then
            for _, d in ipairs(container:GetDescendants()) do
                if d:IsA("Tool") and not seen[d] then
                    seen[d] = true
                    local rn = (toolRealName(d) or ""):lower()
                    local on = (d.Name or ""):lower()
                    if rn:find("axe") or rn:find("hatchet")
                       or on:find("axe") or on:find("hatchet") then
                        return d
                    end
                end
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
    return nil
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

local function ensureEquipped(axe)
    if not axe or not axe.Parent then return false end
    local c = LocalPlayer.Character
    if not c then return false end
    if axe:IsDescendantOf(c) then return true end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h then return false end
    pcall(function() h:EquipTool(axe) end)
    task.wait(0.3)
    return axe:IsDescendantOf(c)
end

-- ============================================================
--  METHODS
-- ============================================================
local function methodActivate(axe, plank)
    -- Just call Tool:Activate(). The tool's own AxeClient script should fire the cut.
    if not axe then return false end
    if not axe:IsDescendantOf(LocalPlayer.Character) then
        return false, "not equipped"
    end
    local ok, err = pcall(function() axe:Activate() end)
    if not ok then return false, tostring(err) end
    return true
end

local function methodRemote(axe, plank, toolSource)
    -- Original hand-fired remote.
    local tool = axe
    if toolSource == "backpack" then
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if bp then
            -- Temporarily unequip
            local c = LocalPlayer.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            if h and axe:IsDescendantOf(c) then
                pcall(function() h:UnequipTools() end)
                task.wait(0.1)
            end
            local bpTool = bp:FindFirstChild(axe.Name)
            if bpTool then tool = bpTool end
        end
    end
    local cutEvent = plank:FindFirstChild("CutEvent")
    if not cutEvent then return false, "no CutEvent" end
    local payload = {
        height = 1,
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
    if not ok then return false, tostring(err) end
    return true
end

-- ============================================================
--  TEST RUNNER
-- ============================================================
local busy = false

local function testOne(plank, method)
    if busy then return end
    busy = true

    log("========== TEST (" .. method .. ") ==========")
    log("Plank: " .. plank.Name .. "  wood=" .. getWoodType(plank))
    local before = getSize(plank)
    log("BEFORE size=" .. (before and fmtVec(before) or "?"))

    local axe = findAxe()
    if not axe then
        log("!! No axe."); busy = false; return
    end
    log("Axe: " .. toolRealName(axe))

    -- Equip the axe (needed for Activate; harmless for remote)
    ensureEquipped(axe)
    task.wait(0.3)

    -- Re-resolve the axe ref (equip can move it)
    axe = findAxe()
    if not axe then
        log("!! Axe vanished after equip."); busy = false; return
    end

    log(("Distance to plank: %.2f"):format(distanceToPlank(plank)))
    log(("HP: %.0f"):format(getHP()))

    local cuts = CONFIG.CUTS_PER_BURST
    local delay = CONFIG.BURST_DELAY

    for i = 1, cuts do
        if not plank.Parent then
            log("  plank gone at cut " .. i); break
        end
        if getHP() < CONFIG.MIN_HP then
            log(("  HP %.0f < %d, abort"):format(getHP(), CONFIG.MIN_HP))
            break
        end

        local ok, err
        if method == "activate" then
            ok, err = methodActivate(axe, plank)
        elseif method == "remote" then
            ok, err = methodRemote(axe, plank, "equipped")
        elseif method == "both" then
            local ok1 = methodActivate(axe, plank)
            task.wait(0.1)
            local ok2 = methodRemote(axe, plank, "equipped")
            ok = ok1 or ok2
        elseif method == "bp_remote" then
            ok, err = methodRemote(axe, plank, "backpack")
        end

        if ok then
            log(("  cut %d/%d  hp=%.0f"):format(i, cuts, getHP()))
        else
            log(("  cut %d/%d FAIL: %s"):format(i, cuts, tostring(err)))
        end

        task.wait(delay)
    end

    task.wait(1.0)
    if plank.Parent then
        local after = getSize(plank)
        log("AFTER  size=" .. (after and fmtVec(after) or "?"))
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
    local a = findAxe()
    axeInfo.Text = a and ("axe: " .. toolRealName(a)) or "axe: NONE"
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
            -- default: activate method
            testOne(p, "activate")
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

equipBtn.Activated:Connect(function()
    local a = findAxe()
    if not a then log("!! No axe.") return end
    if ensureEquipped(a) then log("Equipped: " .. toolRealName(a)) end
    refreshAxeLabel()
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

toolBtn.Activated:Connect(function()
    local a = findAxe()
    if not a then log("!! No axe.") return end
    log("=== TOOL DUMP: " .. a.Name .. " ===")
    for _, c in ipairs(a:GetDescendants()) do
        log(("  %s  [%s]"):format(c.Name, c.ClassName))
    end
    log("=== END DUMP ===")
end)

-- Quick test buttons — pick biggest plank
local function pickBiggest(method)
    local planks = findAllPlanks()
    if #planks == 0 then return end
    table.sort(planks, function(a, b)
        return (getSize(a) and getSize(a).Magnitude or 0) >
               (getSize(b) and getSize(b).Magnitude or 0)
    end)
    testOne(planks[1], method)
end

v_act.Activated:Connect(function() pickBiggest("activate") end)
v_remote.Activated:Connect(function() pickBiggest("remote") end)
v_both.Activated:Connect(function() pickBiggest("both") end)
v_bp.Activated:Connect(function() pickBiggest("bp_remote") end)

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
        testOne(model, "activate")
        return
    end
    local nearby = findPlankNear(hitPos, CONFIG.TAP_RADIUS)
    if nearby then
        log("Nearby: " .. getWoodType(nearby))
        testOne(nearby, "activate")
    else
        log("No plank nearby.")
    end
end)

-- ============================================================
--  STARTUP
-- ============================================================
refreshAxeLabel()
log("v12 ready. NO teleport. Godmode ON.")
log("Tests fire from wherever you are standing.")
log("'Test: Activate' calls axe:Activate() - the game's own cut path.")
log("'Dump Tool' lists everything inside the tool so we can see AxeClient.")
log("Tap a plank, or press a Test button.")
