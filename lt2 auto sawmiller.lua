-- LT2 Cut Diagnostic v8
-- Tap-to-pick OR list-pick, robust axe finding, auto-height option.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Interaction = ReplicatedStorage:WaitForChild("Interaction")
local RemoteProxy = Interaction:WaitForChild("RemoteProxy")

local CONFIG = {
    CUTS_PER_BURST = 10,
    BURST_DELAY    = 1.0,
    TELEPORT_OFFSET = Vector3.new(2, 2, 0),
    FACE_VECTOR    = Vector3.new(1, 0, 0),
    COOLDOWN       = 0.23737628459930421,
    SECTION_ID     = 1,
    HIT_POINTS     = 1.2,
    CUTTING_CLASS  = "Axe",
    MIN_HP         = 30,
}

local setClipboard = nil
if type(setclipboard) == "function" then setClipboard = setclipboard
elseif type(toclipboard) == "function" then setClipboard = toclipboard
elseif type(writeClipboard) == "function" then setClipboard = writeClipboard
end

-- ============================================================
--  GUI
-- ============================================================
local sg = Instance.new("ScreenGui")
sg.Name = "LT2_CutDiag8"
sg.ResetOnSpawn = false
sg.Parent = LocalPlayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 560, 0, 500)
frame.Position = UDim2.new(0.5, -280, 0.5, -250)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = sg

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
title.BorderSizePixel = 0
title.Text = "LT2 Cut Diagnostic v8 - tap a plank in world"
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
local scanBtn  = mkBtn("Scan Axe",   294, 32, 90, 30, Color3.fromRGB(120, 120, 200))

local axeInfo = Instance.new("TextLabel")
axeInfo.Size = UDim2.new(1, -390, 0, 30)
axeInfo.Position = UDim2.new(0, 390, 0, 32)
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
lbl2.Text = "Tap a plank in the world, OR use a button below:"
lbl2.TextColor3 = Color3.fromRGB(200, 200, 200)
lbl2.TextSize = 11
lbl2.Font = Enum.Font.SourceSansBold
lbl2.TextXAlignment = Enum.TextXAlignment.Left
lbl2.Parent = frame

local v_h1    = mkBtn("h=1",         4,   86, 90, 28, Color3.fromRGB(70, 90, 130))
local v_hAuto = mkBtn("h=auto",      98,  86, 90, 28, Color3.fromRGB(60, 140, 80))
local v_hHalf = mkBtn("h=half",      192, 86, 90, 28, Color3.fromRGB(70, 90, 130))
local v_test  = mkBtn("Test 1",      286, 86, 90, 28, Color3.fromRGB(140, 90, 130))

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
local p_10x05 = mkBtn("10x0.5", 182, 114, 80, 24, Color3.fromRGB(70, 90, 130))
local p_20x1  = mkBtn("20x1s",  264, 114, 80, 24, Color3.fromRGB(70, 90, 130))
local p_30x05 = mkBtn("30x0.5", 346, 114, 80, 24, Color3.fromRGB(70, 90, 130))

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
        local ok, v = pcall(function() return tn.Value end)
        if ok and v then return v end
    end
    return tool.Name
end

--- VERY thorough axe search. Checks Backpack, Tools folder, Character,
--- and even descendants of Player in case an executor moved it.
local function findAxe()
    local seen = {}
    local searchOrder = {
        LocalPlayer:FindFirstChild("Backpack"),
        LocalPlayer:FindFirstChild("Tools"),
        LocalPlayer.Character,
        LocalPlayer,
    }
    for _, container in ipairs(searchOrder) do
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

--- Debug: list every tool found anywhere.
local function debugListTools()
    local seen = {}
    local searchOrder = {
        ["Backpack"] = LocalPlayer:FindFirstChild("Backpack"),
        ["Tools"] = LocalPlayer:FindFirstChild("Tools"),
        ["Character"] = LocalPlayer.Character,
        ["Player"] = LocalPlayer,
    }
    for label, container in pairs(searchOrder) do
        if container then
            for _, d in ipairs(container:GetDescendants()) do
                if d:IsA("Tool") and not seen[d] then
                    seen[d] = true
                    log(("  [%s] obj=%s real=%s"):format(
                        label, d.Name, tostring(toolRealName(d))))
                end
            end
        end
    end
end

local function isPlank(model)
    if not model or not model:IsA("Model") then return false end
    if not ownerMatches(model, LocalPlayer) then return false end
    if not model:FindFirstChild("CutEvent") then return false end
    return true
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
    local char = LocalPlayer.Character
    if not char then return 100 end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health or 100
end

-- ============================================================
--  TELEPORT / EQUIP
-- ============================================================
local function teleportToPlank(plank)
    local char = LocalPlayer.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local ws = getWoodSection(plank)
    local targetPos = ws and ws.Position or plank:GetPivot().Position
    root.CFrame = CFrame.new(targetPos + CONFIG.TELEPORT_OFFSET, targetPos)
    root.AssemblyLinearVelocity = Vector3.zero
    task.wait(0.2)
    return true
end

local function ensureEquipped(axe)
    if not axe or not axe.Parent then return false end
    local char = LocalPlayer.Character
    if not char then return false end
    if axe:IsDescendantOf(char) then return true end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    pcall(function() hum:EquipTool(axe) end)
    task.wait(0.2)
    return axe:IsDescendantOf(char)
end

-- ============================================================
--  BURST
-- ============================================================
local function fireBurst(plank, height, cuts, delay)
    local cutEvent = plank:FindFirstChild("CutEvent")
    if not cutEvent then
        log("!! No CutEvent.")
        return 0
    end

    local fired = 0
    for i = 1, cuts do
        if not plank.Parent then
            log("  plank gone at " .. i)
            break
        end
        if getHP() < CONFIG.MIN_HP then
            log("  HP low (" .. math.floor(getHP()) .. "), abort")
            break
        end

        -- Refresh axe every cut
        local axe = findAxe()
        if not axe then
            log("  no axe at cut " .. i)
            break
        end
        ensureEquipped(axe)

        -- Use the tool object we found (may be in Character now)
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
            log(("  cut %d/%d  axe=%s"):format(i, cuts, toolRealName(axe)))
        else
            log(("  cut %d/%d FAILED"):format(i, cuts))
        end

        task.wait(delay)
    end
    return fired
end

-- ============================================================
--  TEST
-- ============================================================
local busy = false

local function autoHeightFor(plank)
    local s = getSize(plank)
    if not s then return 1 end
    -- Use half the longest axis, minus a bit, clamped to [0.5, 2.5]
    local maxDim = math.max(s.X, s.Y, s.Z)
    local h = maxDim / 2 - 0.5
    if h < 0.5 then h = 0.5 end
    if h > 2.5 then h = 2.5 end
    return h
end

local function testOne(plank, heightMode, cuts, delay)
    if busy then return end
    busy = true

    log("========== TEST ==========")
    log("Plank: " .. plank.Name)

    local sizeBefore = getSize(plank)
    log("BEFORE size=" .. (sizeBefore and fmtVec(sizeBefore) or "?"))

    local axe = findAxe()
    if not axe then
        log("!! No axe anywhere:")
        debugListTools()
        busy = false
        return
    end
    log("Axe: " .. toolRealName(axe))

    ensureEquipped(axe)
    teleportToPlank(plank)

    -- Resolve height
    local h
    if heightMode == "auto" then
        h = autoHeightFor(plank)
        log(("auto height = %.2f"):format(h))
    elseif heightMode == "half" then
        local s = sizeBefore
        h = s and math.max(s.X, s.Y, s.Z) / 2 or 1
        log(("half height = %.2f"):format(h))
    else
        h = heightMode or 1
    end

    local c = cuts or CONFIG.CUTS_PER_BURST
    local d = delay or CONFIG.BURST_DELAY
    log(("Firing %d cuts @ %.2fs, h=%s"):format(c, d, tostring(h)))

    local fired = fireBurst(plank, h, c, d)
    log(("Fired %d/%d"):format(fired, c))
    task.wait(1.0)

    if plank.Parent then
        local afterSize = getSize(plank)
        log("AFTER  size=" .. (afterSize and fmtVec(afterSize) or "?"))
        if sizeBefore and afterSize then
            local diff = (sizeBefore - afterSize).Magnitude
            if diff > 0.05 then
                log(("*** CUT WORKED (diff %.2f) ***"):format(diff))
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
    axeInfo.Text = axe and ("axe: " .. toolRealName(axe)) or "axe: NONE"
end

local function runListPlanks()
    for _, c in ipairs(picker:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    refreshAxeLabel()

    local planks = findAllPlanks()
    log(("Found %d plank(s)."):format(#planks))
    if #planks == 0 then picker.Visible = false return end

    -- Show bigger planks first
    table.sort(planks, function(a, b)
        local sa, sb = getSize(a), getSize(b)
        return (sa and sa.Magnitude or 0) > (sb and sb.Magnitude or 0)
    end)

    for i, p in ipairs(planks) do
        local s = getSize(p)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -6, 0, 30)
        btn.BorderSizePixel = 0
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 12
        btn.Font = Enum.Font.Code
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        btn.Text = ("  #%d  size=%s"):format(i, s and fmtVec(s) or "?")
        btn.Parent = picker
        btn.Activated:Connect(function()
            picker.Visible = false
            log("Picked #" .. i)
            testOne(p, 1)
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
    local axe = findAxe()
    if not axe then log("!! No axe.") return end
    if ensureEquipped(axe) then
        log("Equipped: " .. toolRealName(axe))
    else
        log("!! Equip failed.")
    end
    refreshAxeLabel()
end)

scanBtn.Activated:Connect(function()
    log("=== SCAN ===")
    debugListTools()
    log("=== END SCAN ===")
    refreshAxeLabel()
end)

stopBtn.Activated:Connect(function()
    busy = false
    log("Stopped.")
end)

v_h1.Activated:Connect(function()
    local planks = findAllPlanks()
    if #planks == 0 then return end
    table.sort(planks, function(a,b)
        return (getSize(a) and getSize(a).Magnitude or 0) >
               (getSize(b) and getSize(b).Magnitude or 0)
    end)
    testOne(planks[1], 1)
end)

v_hAuto.Activated:Connect(function()
    local planks = findAllPlanks()
    if #planks == 0 then return end
    table.sort(planks, function(a,b)
        return (getSize(a) and getSize(a).Magnitude or 0) >
               (getSize(b) and getSize(b).Magnitude or 0)
    end)
    testOne(planks[1], "auto")
end)

v_hHalf.Activated:Connect(function()
    local planks = findAllPlanks()
    if #planks == 0 then return end
    table.sort(planks, function(a,b)
        return (getSize(a) and getSize(a).Magnitude or 0) >
               (getSize(b) and getSize(b).Magnitude or 0)
    end)
    testOne(planks[1], "half")
end)

v_test.Activated:Connect(function()
    local planks = findAllPlanks()
    if #planks == 0 then return end
    table.sort(planks, function(a,b)
        return (getSize(a) and getSize(a).Magnitude or 0) >
               (getSize(b) and getSize(b).Magnitude or 0)
    end)
    testOne(planks[1], 1, 1, 0)
end)

p_10x1.Activated:Connect(function()
    CONFIG.CUTS_PER_BURST = 10; CONFIG.BURST_DELAY = 1.0
    log("Preset: 10 @ 1s")
end)
p_10x05.Activated:Connect(function()
    CONFIG.CUTS_PER_BURST = 10; CONFIG.BURST_DELAY = 0.5
    log("Preset: 10 @ 0.5s")
end)
p_20x1.Activated:Connect(function()
    CONFIG.CUTS_PER_BURST = 20; CONFIG.BURST_DELAY = 1.0
    log("Preset: 20 @ 1s")
end)
p_30x05.Activated:Connect(function()
    CONFIG.CUTS_PER_BURST = 30; CONFIG.BURST_DELAY = 0.5
    log("Preset: 30 @ 0.5s")
end)

-- ============================================================
--  TAP IN WORLD TO PICK PLANK
-- ============================================================
local function raycastFromScreen(pos)
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local ray = cam:ViewportPointToRay(pos.X, pos.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { sg, LocalPlayer.Character }
    local result = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
    return result and result.Instance or nil
end

local function handleTap(screenPos, gameProcessed)
    if gameProcessed then return end
    -- Ignore taps inside our GUI
    local guiObjs = LocalPlayer.PlayerGui:GetGuiObjectsAtPosition(screenPos.X, screenPos.Y)
    for _, obj in ipairs(guiObjs) do
        if obj:IsDescendantOf(sg) then return end
    end

    local hit = raycastFromScreen(screenPos)
    if not hit then return end
    local model = hit:FindFirstAncestorOfClass("Model")
    if not model then return end

    if not isPlank(model) then
        log("Tapped " .. model.Name .. " - not a plank (no CutEvent or not yours).")
        return
    end

    log("Tapped plank: " .. model.Name)
    testOne(model, 1)
end

UserInputService.InputBegan:Connect(function(input, gp)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        handleTap(input.Position, gp)
    end
end)

-- ============================================================
--  STARTUP
-- ============================================================
refreshAxeLabel()
log("v8 ready.")
log("Tap a plank in the world to test it, OR use buttons.")
log("If 'No axe' appears, tap 'Scan Axe' to see what's found.")
