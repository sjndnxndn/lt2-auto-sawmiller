-- ============================================================
-- LT2 PLANK MOVER & AUTO-CUTTER - v2
-- Fixed: manual resize handles, reversible water stash
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Interaction = ReplicatedStorage:WaitForChild("Interaction")
local RemoteProxy = Interaction:WaitForChild("RemoteProxy")
local ClientIsDragging = Interaction:FindFirstChild("ClientIsDragging")

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG = {
    CUT_DELAY     = 1.0,
    CUT_HEIGHT    = 1,
    FACE_VECTOR   = Vector3.new(1, 0, 0),
    COOLDOWN      = 0.23737628459930421,
    SECTION_ID    = 1,
    HIT_POINTS    = 1.2,
    CUTTING_CLASS = "Axe",
    MAX_CUTS      = 80,
    MIN_HP        = 30,

    TP_SIDE       = 3,
    TP_SETTLE     = 0.25,
    TP_GROUND_GAP = 8,

    SAWMILL_LIMITS = {
        shabby    = 1.4,
        fair      = 1.6,
        sawmax01  = 2.0,
        sawmax02  = 2.6,
        sawmax02l = 2.6,
    },

    AUTO_INTERVAL = 2.0,
    MAX_QUEUE     = 2,
    GODMODE       = true,

    MIN_FRAME_W = 340,
    MIN_FRAME_H = 320,
}

-- ============================================================
-- STATE
-- ============================================================
local state = {
    selectedSawmill = nil,
    selectedPlank   = nil,
    waitingSawmill  = false,
    waitingPlank    = false,
    autoMode        = false,
    autoCut         = false,
    busy            = false,
    autoRunning     = false,
    processed       = setmetatable({}, {__mode = "k"}),
    waterStash      = {},   -- { {part=part, parent=originalParent}, ... }
}

-- ============================================================
-- GODMODE
-- ============================================================
local godConn
local function startGod()
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
if CONFIG.GODMODE then startGod() end
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if CONFIG.GODMODE then stopGod(); startGod() end
end)

-- ============================================================
-- REVERSIBLE WATER STASH
-- ============================================================
local function stashWater()
    if #state.waterStash > 0 then return 0 end  -- already stashed
    local terms = {"water","swamp","ocean","river","lake","sea","damagezone","hazard"}
    local snap = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        snap[d] = true
    end
    local n = 0
    for d in pairs(snap) do
        if d and d.Parent then
            local ok = d:IsA("BasePart") or d:IsA("Folder")
                    or d:IsA("Model") or d:IsA("TrussPart")
            if ok then
                local nm = d.Name:lower()
                for _, t in ipairs(terms) do
                    if nm:find(t) then
                        table.insert(state.waterStash, {part = d, parent = d.Parent})
                        d.Parent = nil
                        n = n + 1
                        break
                    end
                end
            end
        end
    end
    return n
end

local function restoreWater()
    local n = 0
    for _, entry in ipairs(state.waterStash) do
        if entry.part and entry.parent then
            pcall(function() entry.part.Parent = entry.parent end)
            n = n + 1
        end
    end
    state.waterStash = {}
    return n
end

-- ============================================================
-- GUI
-- ============================================================
local sg = Instance.new("ScreenGui")
sg.Name = "LT2_PlankMover"
sg.ResetOnSpawn = false
sg.Parent = LocalPlayer:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Name = "Main"
mainFrame.Size = UDim2.new(0, 460, 0, 480)
mainFrame.Position = UDim2.new(0.5, -230, 0.5, -240)
mainFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = sg
-- NOTE: Resizable is not a valid Frame property. Handled via handles below.

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 32)
titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
titleBar.BorderSizePixel = 0
titleBar.Active = true
titleBar.Parent = mainFrame

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -40, 1, 0)
titleLbl.Position = UDim2.new(0, 8, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "LT2 Plank Mover"
titleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLbl.TextSize = 15
titleLbl.Font = Enum.Font.SourceSansBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = titleBar

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 28, 0, 28)
toggleBtn.Position = UDim2.new(1, -32, 0, 2)
toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
toggleBtn.BorderSizePixel = 0
toggleBtn.Text = "X"
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.TextSize = 16
toggleBtn.Font = Enum.Font.SourceSansBold
toggleBtn.Parent = titleBar

local reopenBtn = Instance.new("TextButton")
reopenBtn.Size = UDim2.new(0, 44, 0, 44)
reopenBtn.Position = UDim2.new(0, 20, 0.5, -22)
reopenBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 100)
reopenBtn.BorderSizePixel = 0
reopenBtn.Text = "LT2"
reopenBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
reopenBtn.TextSize = 14
reopenBtn.Font = Enum.Font.SourceSansBold
reopenBtn.Visible = false
reopenBtn.Parent = sg

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -10, 1, -40)
content.Position = UDim2.new(0, 5, 0, 36)
content.BackgroundTransparency = 1
content.Parent = mainFrame

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, 0, 0, 34)
statusLbl.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
statusLbl.BorderSizePixel = 0
statusLbl.Text = "Ready"
statusLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
statusLbl.TextSize = 12
statusLbl.Font = Enum.Font.SourceSans
statusLbl.Parent = content

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
    b.Parent = parent or content
    return b
end

local selSawBtn = mkBtn("1. Select Sawmill", 0, 40, 165, 34, Color3.fromRGB(60, 120, 200))
local selPlkBtn = mkBtn("2. Select Plank",   172, 40, 165, 34, Color3.fromRGB(60, 180, 100))
local moveBtn   = mkBtn("3. Move Plank",     0,   78, 165, 34, Color3.fromRGB(200, 150, 50))
local cutBtn    = mkBtn("Cut Plank 1x1",     172, 78, 165, 34, Color3.fromRGB(180, 80, 180))

local div = Instance.new("Frame")
div.Size = UDim2.new(1, 0, 0, 1)
div.Position = UDim2.new(0, 0, 0, 118)
div.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
div.BorderSizePixel = 0
div.Parent = content

local autoMoveBtn = mkBtn("Auto Move: OFF", 0,   126, 250, 32, Color3.fromRGB(90, 90, 90))
local autoCutBtn  = mkBtn("Auto Cut: OFF",  256, 126, 165, 32, Color3.fromRGB(90, 90, 90))

local godBtn   = mkBtn("God: ON",   0,   164, 100, 28, Color3.fromRGB(60, 140, 100))
local listBtn  = mkBtn("List",      106, 164, 90,  28, Color3.fromRGB(60, 120, 200))
local copyBtn  = mkBtn("Copy Log",  200, 164, 100, 28, Color3.fromRGB(60, 180, 100))
local clearBtn = mkBtn("Clear",     304, 164, 80,  28, Color3.fromRGB(150, 80, 80))

local logBox = Instance.new("ScrollingFrame")
logBox.Size = UDim2.new(1, 0, 1, -210)
logBox.Position = UDim2.new(0, 0, 0, 200)
logBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
logBox.BorderSizePixel = 0
logBox.ScrollBarThickness = 6
logBox.CanvasSize = UDim2.new(0, 0, 0, 0)
logBox.AutomaticCanvasSize = Enum.AutomaticSize.Y
logBox.Parent = content

local logLayout = Instance.new("UIListLayout")
logLayout.Padding = UDim.new(0, 2)
logLayout.SortOrder = Enum.SortOrder.LayoutOrder
logLayout.Parent = logBox

local picker = Instance.new("ScrollingFrame")
picker.Size = UDim2.new(1, -10, 0, 180)
picker.Position = UDim2.new(0, 5, 1, -190)
picker.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
picker.BorderSizePixel = 0
picker.ScrollBarThickness = 6
picker.Visible = false
picker.CanvasSize = UDim2.new(0, 0, 0, 0)
picker.AutomaticCanvasSize = Enum.AutomaticSize.Y
picker.Parent = mainFrame

local pickerLayout = Instance.new("UIListLayout")
pickerLayout.Padding = UDim.new(0, 2)
pickerLayout.SortOrder = Enum.SortOrder.LayoutOrder
pickerLayout.Parent = picker

-- ============================================================
-- RESIZE HANDLES (manual resize since Frame.Resizable doesn't exist)
-- ============================================================
local function makeHandle(name, anchorX, anchorY, size)
    local h = Instance.new("TextButton")
    h.Name = name
    h.Size = UDim2.new(0, size, 0, size)
    h.AnchorPoint = Vector2.new(anchorX, anchorY)
    h.Position = UDim2.new(anchorX, 0, anchorY, 0)
    h.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    h.BackgroundTransparency = 0.3
    h.BorderSizePixel = 0
    h.Text = ""
    h.AutoButtonColor = false
    h.ZIndex = 5
    h.Parent = mainFrame
    return h
end

local handleSize = 12
local hBR = makeHandle("RB", 1, 1, handleSize)   -- bottom-right (main resize corner)
local hTR = makeHandle("RT", 1, 0, handleSize)
local hBL = makeHandle("LB", 0, 1, handleSize)
local hTL = makeHandle("LT", 0, 0, handleSize)

local resizing = false
local resizeStartMouse
local resizeStartSize
local resizeCorner

local function beginResize(corner, input)
    resizing = true
    resizeCorner = corner
    resizeStartMouse = Vector2.new(input.Position.X, input.Position.Y)
    resizeStartSize = mainFrame.AbsoluteSize
end

local function updateResize(input)
    if not resizing then return end
    local mx = input.Position.X - resizeStartMouse.X
    local my = input.Position.Y - resizeStartMouse.Y

    local w = resizeStartSize.X
    local h = resizeStartSize.Y

    if resizeCorner == "RB" then
        w = w + mx; h = h + my
    elseif resizeCorner == "RT" then
        w = w + mx; h = h - my
    elseif resizeCorner == "LB" then
        w = w - mx; h = h + my
    elseif resizeCorner == "LT" then
        w = w - mx; h = h - my
    end

    w = math.max(CONFIG.MIN_FRAME_W, w)
    h = math.max(CONFIG.MIN_FRAME_H, h)

    mainFrame.Size = UDim2.new(0, w, 0, h)
end

local function endResize()
    resizing = false
    resizeCorner = nil
end

local function wireHandle(h, corner)
    h.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            beginResize(corner, input)
        end
    end)
end
wireHandle(hBR, "RB")
wireHandle(hTR, "RT")
wireHandle(hBL, "LB")
wireHandle(hTL, "LT")

UserInputService.InputChanged:Connect(function(input)
    if resizing then
        if input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch then
            updateResize(input)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        endResize()
    end
end)

-- ============================================================
-- LOG
-- ============================================================
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
    logBox.CanvasPosition = Vector2.new(0, logLayout.AbsoluteContentSize.Y)
end
local function setStatus(txt) statusLbl.Text = txt end

-- ============================================================
-- HELPERS
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
    return string.format("(%.2f,%.2f,%.2f)", v.X, v.Y, v.Z)
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
    local order = {
        LocalPlayer:FindFirstChild("Backpack"),
        LocalPlayer:FindFirstChild("Tools"),
        LocalPlayer.Character,
    }
    for _, cont in ipairs(order) do
        if cont then
            for _, d in ipairs(cont:GetDescendants()) do
                if d:IsA("Tool") then
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
end

local function ensureEquipped(axe)
    if not axe or not axe.Parent then return false end
    local c = LocalPlayer.Character
    if not c then return false end
    if axe.Parent == c then return true end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h then return false end
    pcall(function() h:EquipTool(axe) end)
    task.wait(0.2)
    return axe.Parent == c
end

local function isPlank(model)
    if not model or not model:IsA("Model") then return false end
    if not ownerMatches(model, LocalPlayer) then return false end
    if not model:FindFirstChild("CutEvent") then return false end
    return true
end

local function isSawmill(model)
    if not model or not model:IsA("Model") then return false end
    if not ownerMatches(model, LocalPlayer) then return false end
    if not model:FindFirstChild("Conveyor") then return false end
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

local function findPlayerSawmill()
    local pm = workspace:FindFirstChild("PlayerModels")
    if not pm then return nil end
    for _, m in ipairs(pm:GetChildren()) do
        if isSawmill(m) then return m end
    end
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

local function getWoodType(plank)
    local tc = plank:FindFirstChild("TreeClass")
    if tc and tc:IsA("StringValue") then
        local ok, v = pcall(function() return tc.Value end)
        if ok and v then return v end
    end
    return "?"
end

-- ============================================================
-- TELEPORT
-- ============================================================
local function teleportNear(plank)
    local c = LocalPlayer.Character
    if not c then return "fail" end
    local root = c:FindFirstChild("HumanoidRootPart")
    if not root then return "fail" end
    local ws = getWoodSection(plank)
    if not ws then return "fail" end

    local sides = {
        Vector3.new(CONFIG.TP_SIDE, 0, 0),
        Vector3.new(-CONFIG.TP_SIDE, 0, 0),
        Vector3.new(0, 0, CONFIG.TP_SIDE),
        Vector3.new(0, 0, -CONFIG.TP_SIDE),
    }
    local side = sides[1]
    for _, s in ipairs(sides) do
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {c, plank, sg}
        local hit = workspace:Raycast(ws.Position, s, params)
        if not hit then side = s; break end
    end

    local tx = ws.Position.X + side.X
    local tz = ws.Position.Z + side.Z
    local plankBottom = ws.Position.Y - (ws.Size.Y / 2)

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {c, plank, sg}
    local hit = workspace:Raycast(
        Vector3.new(tx, plankBottom + 2, tz),
        Vector3.new(0, -500, 0), params)

    local goalY, mode
    if hit and (plankBottom - hit.Position.Y) <= CONFIG.TP_GROUND_GAP then
        goalY = hit.Position.Y + 3
        mode = "ground"
    else
        goalY = ws.Position.Y
        mode = "float"
    end

    root.CFrame = CFrame.new(Vector3.new(tx, goalY, tz),
                             Vector3.new(ws.Position.X, goalY, ws.Position.Z))
    root.AssemblyLinearVelocity = Vector3.zero
    task.wait(CONFIG.TP_SETTLE)
    return mode
end

-- ============================================================
-- CUT
-- ============================================================
local function fireCut(plank, axe, height)
    local cutEvent = plank:FindFirstChild("CutEvent")
    if not cutEvent or not axe then return false end
    local payload = {
        height      = height,
        faceVector  = CONFIG.FACE_VECTOR,
        cooldown    = CONFIG.COOLDOWN,
        sectionId   = CONFIG.SECTION_ID,
        hitPoints   = CONFIG.HIT_POINTS,
        tool        = axe,
        cuttingClass = CONFIG.CUTTING_CLASS,
    }
    return pcall(function() RemoteProxy:FireServer(cutEvent, payload) end)
end

--- Cut a plank to 1x1. Stashes water during cutting, restores it after.
local function cutTo1x1(plank, announceFn)
    if not plank or not plank.Parent then return false end

    -- Stash water while cutting (restore after)
    local stashed = stashWater()
    if stashed > 0 and announceFn then
        announceFn("Water stashed (" .. stashed .. ").")
    end

    local ok = (function()
        local axe = findAxe()
        if not axe then
            if announceFn then announceFn("No axe found.") end
            return false
        end
        ensureEquipped(axe)

        local mode = teleportNear(plank)
        if announceFn then announceFn("Teleport: " .. mode) end

        axe = findAxe()
        if not axe then
            if announceFn then announceFn("Axe lost after teleport.") end
            return false
        end

        local cuts = 0
        while cuts < CONFIG.MAX_CUTS do
            if not plank.Parent then
                if announceFn then announceFn("Plank destroyed.") end
                return true
            end
            if getHP() < CONFIG.MIN_HP then
                if announceFn then announceFn("HP low, abort.") end
                return false
            end

            local size = getSize(plank)
            if not size then break end
            local d = {size.X, size.Y, size.Z}
            table.sort(d)
            if d[1] <= 1.05 and d[2] <= 1.05 then
                if announceFn then announceFn("Plank is 1x1 now (" .. cuts .. " cuts).") end
                return true
            end

            if not axe or not axe.Parent then
                axe = findAxe()
                if not axe then break end
            end
            ensureEquipped(axe)

            fireCut(plank, axe, CONFIG.CUT_HEIGHT)
            cuts = cuts + 1
            if announceFn and cuts % 5 == 0 then
                announceFn("Cut " .. cuts .. " applied.")
            end
            task.wait(CONFIG.CUT_DELAY)
        end
        if announceFn then announceFn("Stopped after " .. cuts .. " cuts.") end
        return false
    end)()

    -- Always restore water after cutting is done
    if #state.waterStash > 0 then
        local n = restoreWater()
        if announceFn then announceFn("Water restored (" .. n .. ").") end
    end
    return ok
end

-- ============================================================
-- MOVE PLANK
-- ============================================================
local function grabOwnership(plank)
    if not ClientIsDragging then return false end
    local initial = plank:GetAttribute("LastInteraction")
    if not initial then
        local o = plank:FindFirstChild("LastInteraction")
        if o then initial = o.Value end
    end
    local t0 = tick()
    while tick() - t0 < 1.0 do
        ClientIsDragging:FireServer(plank)
        local cur = plank:GetAttribute("LastInteraction")
        if not cur then
            local o = plank:FindFirstChild("LastInteraction")
            if o then cur = o.Value end
        end
        if cur and cur ~= initial then return true end
        task.wait(0.05)
    end
    return false
end

local function movePlankToSawmill(plank, sawmill)
    if not plank or not sawmill then return false end
    teleportNear(plank)
    grabOwnership(plank)
    task.wait(0.1)

    local target
    local loadPart = sawmill:FindFirstChild("LoadingHole")
                  or sawmill:FindFirstChild("Loading")
    if loadPart then
        target = loadPart.Position
    else
        target = sawmill:GetPivot().Position + Vector3.new(0, 2, 0)
    end

    plank:PivotTo(CFrame.new(target))
    task.wait(0.05)
    task.wait(0.1)
    return true
end

-- ============================================================
-- SAWMILL CHECKS
-- ============================================================
local function getSawmillMaxSize(sawmill)
    if not sawmill then return nil end
    local n = sawmill.Name:lower()
    for key, val in pairs(CONFIG.SAWMILL_LIMITS) do
        if n:find(key) then return val end
    end
    return CONFIG.SAWMILL_LIMITS.shabby
end

local function plankFitsSawmill(plank, sawmill)
    if not plank or not sawmill then return false end
    local s = getSize(plank)
    if not s then return false end
    local dims = {s.X, s.Y, s.Z}
    table.sort(dims)
    return dims[1] <= getSawmillMaxSize(sawmill)
end

local function sawmillQueueFull(sawmill)
    if not sawmill then return false end
    local pos = sawmill:GetPivot().Position
    local count = 0
    for _, p in ipairs(findAllPlanks()) do
        local ws = getWoodSection(p)
        if ws and (ws.Position - pos).Magnitude < 15 then
            count = count + 1
        end
    end
    return count >= CONFIG.MAX_QUEUE
end

-- ============================================================
-- AUTO MODE
-- ============================================================
local function startAutoLoop()
    if state.autoRunning then return end
    state.autoRunning = true
    task.spawn(function()
        while state.autoMode do
            local sawmill = findPlayerSawmill()
            if not sawmill then
                setStatus("Auto: no sawmill found")
                task.wait(CONFIG.AUTO_INTERVAL)
                continue
            end
            if sawmillQueueFull(sawmill) then
                setStatus("Auto: queue full")
                task.wait(CONFIG.AUTO_INTERVAL)
                continue
            end

            local target
            for _, p in ipairs(findAllPlanks()) do
                if not state.processed[p] and plankFitsSawmill(p, sawmill) then
                    target = p
                    break
                end
            end

            if not target then
                setStatus("Auto: no plank fits")
                task.wait(CONFIG.AUTO_INTERVAL)
                continue
            end

            setStatus("Auto: moving " .. getWoodType(target))
            if movePlankToSawmill(target, sawmill) then
                state.processed[target] = true
                if state.autoCut then
                    log("Auto: cutting " .. getWoodType(target))
                    cutTo1x1(target, function(m) log("  " .. m) end)
                end
            end
            task.wait(CONFIG.AUTO_INTERVAL)
        end
        state.autoRunning = false
        setStatus("Auto stopped")
    end)
end

-- ============================================================
-- TAP TO PICK
-- ============================================================
local function raycastScreen(pos)
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local ray = cam:ViewportPointToRay(pos.X, pos.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {sg, LocalPlayer.Character}
    local r = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
    return r and r.Instance, r and r.Position or nil
end

local function findNearPlank(worldPos, radius)
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
    if best and bestD <= radius then return best end
end

local function findNearSawmill(worldPos, radius)
    local pm = workspace:FindFirstChild("PlayerModels")
    if not pm then return nil end
    local best, bestD = nil, math.huge
    for _, m in ipairs(pm:GetChildren()) do
        if isSawmill(m) then
            local pv = m:GetPivot().Position
            local d = (pv - worldPos).Magnitude
            if d < bestD then bestD = d; best = m end
        end
    end
    if best and bestD <= radius then return best end
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

    local hit, hitPos = raycastScreen(pos)
    if not hit then return end

    if state.waitingSawmill then
        local m = hit:FindFirstAncestorOfClass("Model")
        if m and isSawmill(m) then
            state.selectedSawmill = m
            state.waitingSawmill = false
            setStatus("Sawmill: " .. m.Name)
            log("Sawmill: " .. m.Name)
        else
            local near = findNearSawmill(hitPos, 15)
            if near then
                state.selectedSawmill = near
                state.waitingSawmill = false
                setStatus("Sawmill (nearby): " .. near.Name)
                log("Sawmill (nearby): " .. near.Name)
            else
                log("Not a sawmill. Tap your sawmill.")
            end
        end
        return
    end

    if state.waitingPlank then
        local m = hit:FindFirstAncestorOfClass("Model")
        if m and isPlank(m) then
            state.selectedPlank = m
            state.waitingPlank = false
            setStatus("Plank: " .. getWoodType(m))
            log("Plank: " .. getWoodType(m))
        else
            local near = findNearPlank(hitPos, 8)
            if near then
                state.selectedPlank = near
                state.waitingPlank = false
                setStatus("Plank (nearby): " .. getWoodType(near))
                log("Plank (nearby): " .. getWoodType(near))
            else
                log("Not a plank. Tap on your plank.")
            end
        end
        return
    end
end)

-- ============================================================
-- BUTTONS
-- ============================================================
toggleBtn.Activated:Connect(function()
    mainFrame.Visible = false
    reopenBtn.Visible = true
end)
reopenBtn.Activated:Connect(function()
    mainFrame.Visible = true
    reopenBtn.Visible = false
end)

selSawBtn.Activated:Connect(function()
    state.waitingSawmill = true
    state.waitingPlank = false
    setStatus("Tap your sawmill...")
    log("Waiting for sawmill selection...")
end)

selPlkBtn.Activated:Connect(function()
    state.waitingPlank = true
    state.waitingSawmill = false
    setStatus("Tap a plank...")
    log("Waiting for plank selection...")
end)

moveBtn.Activated:Connect(function()
    if state.busy then return end
    if not state.selectedSawmill then log("No sawmill selected."); return end
    if not state.selectedPlank then log("No plank selected."); return end
    if not state.selectedPlank.Parent then log("Plank gone."); return end
    if not plankFitsSawmill(state.selectedPlank, state.selectedSawmill) then
        log("Plank too wide for this sawmill."); return
    end
    state.busy = true
    setStatus("Moving plank...")
    if movePlankToSawmill(state.selectedPlank, state.selectedSawmill) then
        log("Plank moved.")
    else
        log("Move failed.")
    end
    setStatus("Ready")
    state.busy = false
end)

cutBtn.Activated:Connect(function()
    if state.busy then return end
    if not state.selectedPlank or not state.selectedPlank.Parent then
        log("No plank selected."); return end
    state.busy = true
    setStatus("Cutting to 1x1...")
    cutTo1x1(state.selectedPlank, function(m) log(m) end)
    setStatus("Ready")
    state.busy = false
end)

autoMoveBtn.Activated:Connect(function()
    state.autoMode = not state.autoMode
    if state.autoMode then
        autoMoveBtn.Text = "Auto Move: ON"
        autoMoveBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 100)
        log("Auto mode ON.")
        startAutoLoop()
    else
        autoMoveBtn.Text = "Auto Move: OFF"
        autoMoveBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
        log("Auto mode OFF.")
    end
end)

autoCutBtn.Activated:Connect(function()
    state.autoCut = not state.autoCut
    if state.autoCut then
        autoCutBtn.Text = "Auto Cut: ON"
        autoCutBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 100)
        log("Auto cut ON.")
    else
        autoCutBtn.Text = "Auto Cut: OFF"
        autoCutBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
        log("Auto cut OFF.")
    end
end)

godBtn.Activated:Connect(function()
    CONFIG.GODMODE = not CONFIG.GODMODE
    if CONFIG.GODMODE then
        godBtn.Text = "God: ON"
        godBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 100)
        startGod()
        log("Godmode ON.")
    else
        godBtn.Text = "God: OFF"
        godBtn.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
        stopGod()
        log("Godmode OFF.")
    end
end)

listBtn.Activated:Connect(function()
    for _, c in ipairs(picker:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local planks = findAllPlanks()
    log("Found " .. #planks .. " planks.")
    if #planks == 0 then picker.Visible = false return end
    for i, p in ipairs(planks) do
        local s = getSize(p)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -6, 0, 28)
        b.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        b.BorderSizePixel = 0
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.TextSize = 11
        b.Font = Enum.Font.Code
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.Text = ("  #%d [%s] %s"):format(i, getWoodType(p), s and fmtVec(s) or "?")
        b.Parent = picker
        b.Activated:Connect(function()
            picker.Visible = false
            state.selectedPlank = p
            setStatus("Plank: " .. getWoodType(p))
            log("Picked plank #" .. i)
        end)
    end
    picker.Visible = true
end)

copyBtn.Activated:Connect(function()
    local text = table.concat(logBuffer, "\n")
    if type(setclipboard) == "function" then
        pcall(function() setclipboard(text) end)
        log(">> Copied.")
    elseif type(toclipboard) == "function" then
        pcall(function() toclipboard(text) end)
        log(">> Copied.")
    else
        log("!! No clipboard function.")
    end
end)

clearBtn.Activated:Connect(function()
    logBuffer = {}
    for _, c in ipairs(logBox:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
end)

-- ============================================================
-- STARTUP
-- ============================================================
log("Script loaded.")
log("Resize: drag the gray corners of the window.")
log("Water is stashed during cuts and restored after.")
log("1) Select sawmill, 2) select plank, 3) move or cut.")
