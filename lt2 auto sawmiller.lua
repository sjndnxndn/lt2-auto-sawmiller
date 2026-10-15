-- ============================================================
-- LT2 PLANK MOVER & AUTO-CUTTER
-- Built on v7's proven cut method
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
    -- Cutting
    CUT_DELAY     = 1.0,
    CUT_HEIGHT    = 1,                    -- 1 stud from the end
    FACE_VECTOR   = Vector3.new(1, 0, 0),
    COOLDOWN      = 0.23737628459930421,
    SECTION_ID    = 1,
    HIT_POINTS    = 1.2,
    CUTTING_CLASS = "Axe",
    MAX_CUTS      = 80,
    MIN_HP        = 30,

    -- Teleport
    TP_SIDE        = 3,
    TP_UP          = 2,
    TP_SETTLE      = 0.25,
    TP_GROUND_GAP  = 8,                   -- if ground within this below plank base, stand

    -- Sawmill max log width (studs)
    SAWMILL_LIMITS = {
        shabby    = 1.4,
        fair      = 1.6,
        sawmax01  = 2.0,
        sawmax02  = 2.6,
        sawmax02l = 2.6,
    },

    -- Auto
    AUTO_INTERVAL = 2.0,
    MAX_QUEUE     = 2,                    -- max pieces exiting a sawmill before we stop feeding
    GODMODE       = true,
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
-- WATER REMOVAL
-- ============================================================
local function nukeWater()
    local n = 0
    local terms = {"water","swamp","ocean","river","lake","sea","damagezone","hazard"}
    local snap = {}
    for _, d in ipairs(workspace:GetDescendants()) do table.insert(snap, d) end
    for _, d in ipairs(snap) do
        if d and d.Parent then
            local ok = d:IsA("BasePart") or d:IsA("Folder")
                    or d:IsA("Model") or d:IsA("TrussPart")
            if ok then
                local nm = d.Name:lower()
                for _, t in ipairs(terms) do
                    if nm:find(t) then
                        pcall(function() d:Destroy() end)
                        n = n + 1
                        break
                    end
                end
            end
        end
    end
    return n
end
task.spawn(function()
    local n = nukeWater()
    print("[LT2] Water removed:", n)
end)

-- ============================================================
-- GUI — resizable + close/open toggle
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
mainFrame.Draggable = true
mainFrame.Resizable = true              -- <-- resizable
mainFrame.Parent = sg

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 32)
titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
titleBar.BorderSizePixel = 0
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

-- Close/Open toggle
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

-- Reopen button (shown when closed)
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

-- Content area
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -10, 1, -40)
content.Position = UDim2.new(0, 5, 0, 36)
content.BackgroundTransparency = 1
content.Parent = mainFrame

-- Status
local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, 0, 0, 34)
statusLbl.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
statusLbl.BorderSizePixel = 0
statusLbl.Text = "Ready"
statusLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
statusLbl.TextSize = 12
statusLbl.Font = Enum.Font.SourceSans
statusLbl.Parent = content

-- Button maker
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

-- Row: Select Sawmill / Select Plank
local selSawBtn = mkBtn("1. Select Sawmill", 0, 40, 165, 34, Color3.fromRGB(60, 120, 200))
local selPlkBtn = mkBtn("2. Select Plank",   172, 40, 165, 34, Color3.fromRGB(60, 180, 100))

-- Row: Move / Cut
local moveBtn = mkBtn("3. Move Plank",  0,   78, 165, 34, Color3.fromRGB(200, 150, 50))
local cutBtn  = mkBtn("Cut Plank 1x1",  172, 78, 165, 34, Color3.fromRGB(180, 80, 180))

-- Divider
local div = Instance.new("Frame")
div.Size = UDim2.new(1, 0, 0, 1)
div.Position = UDim2.new(0, 0, 0, 118)
div.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
div.BorderSizePixel = 0
div.Parent = content

-- Auto buttons
local autoMoveBtn = mkBtn("Auto Move: OFF", 0,   126, 250, 32, Color3.fromRGB(90, 90, 90))
local autoCutBtn  = mkBtn("Auto Cut: OFF",  256, 126, 165, 32, Color3.fromRGB(90, 90, 90))

-- Utility row
local godBtn    = mkBtn("God: ON",   0,   164, 100, 28, Color3.fromRGB(60, 140, 100))
local listBtn   = mkBtn("List",      106, 164, 90,  28, Color3.fromRGB(60, 120, 200))
local copyBtn   = mkBtn("Copy Log",  200, 164, 100, 28, Color3.fromRGB(60, 180, 100))
local clearBtn  = mkBtn("Clear",     304, 164, 80,  28, Color3.fromRGB(150, 80, 80))

-- Log
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

-- Picker overlay
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
-- SMART TELEPORT (ground-aware)
-- ============================================================
local function teleportNear(plank)
    local c = LocalPlayer.Character
    if not c then return "fail" end
    local root = c:FindFirstChild("HumanoidRootPart")
    if not root then return "fail" end
    local ws = getWoodSection(plank)
    if not ws then return "fail" end

    -- Pick a free side (+X, -X, +Z, -Z)
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

    -- Find ground under target spot
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {c, plank, sg}
    local hit = workspace:Raycast(
        Vector3.new(tx, plankBottom + 2, tz),
        Vector3.new(0, -500, 0),
        params)

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
-- CUT (v7's proven method: equip → teleport → fire RemoteProxy)
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

--- Cut a plank down to 1x1 by firing one cut per second (v7-style).
local function cutTo1x1(plank, announceFn)
    if not plank or not plank.Parent then return false end

    -- Equip axe FIRST (v7 behaviour: tool must be in Character)
    local axe = findAxe()
    if not axe then
        if announceFn then announceFn("No axe found.") end
        return false
    end
    ensureEquipped(axe)

    -- Teleport near
    local mode = teleportNear(plank)
    if announceFn then announceFn("Teleport: " .. mode) end

    -- Re-fetch axe (equip + teleport can move it)
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
        -- Sort dims; smallest two should be ~1
        local d = {size.X, size.Y, size.Z}
        table.sort(d)
        if d[1] <= 1.05 and d[2] <= 1.05 then
            if announceFn then announceFn("Plank is 1x1 now (" .. cuts .. " cuts).") end
            return true
        end

        -- Ensure axe is still equipped
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
end

-- ============================================================
-- MOVE PLANK TO SAWMILL (teleport & release)
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

    -- Position player near the plank
    teleportNear(plank)
    grabOwnership(plank)
    task.wait(0.1)

    -- Target: sawmill's Loading part, or its pivot + up
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

--- Count planks currently sitting at the sawmill's output (within 15 studs).
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
-- AUTO MODE LOOP
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
                setStatus("Auto: sawmill queue full (" .. CONFIG.MAX_QUEUE .. ")")
                task.wait(CONFIG.AUTO_INTERVAL)
                continue
            end

            -- Find a suitable plank
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
                    log("Auto: cutting to 1x1")
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
            setStatus("Sawmill selected: " .. m.Name)
            log("Sawmill: " .. m.Name)
        else
            local near = findNearSawmill(hitPos, 15)
            if near then
                state.selectedSawmill = near
                state.waitingSawmill = false
                setStatus("Sawmill (nearby): " .. near.Name)
                log("Sawmill (nearby): " .. near.Name)
            else
                log("Not a sawmill. Tap your sawmill's conveyor.")
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
-- BUTTON WIRING
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
    if not state.selectedPlank.Parent then
        log("Selected plank no longer exists."); return end
    if not plankFitsSawmill(state.selectedPlank, state.selectedSawmill) then
        log("Plank too wide for this sawmill.")
        return
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
    if type(setclipboard) == "function" then
        pcall(function() setclipboard(table.concat(logBuffer, "\n")) end)
        log(">> Copied.")
    elseif type(toclipboard) == "function" then
        pcall(function() toclipboard(table.concat(logBuffer, "\n")) end)
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
log("1) Select sawmill, 2) select plank, 3) move or cut.")
log("Auto Move + Auto Cut run continuously.")
log("God mode keeps you alive during cuts.")-- LT2 Cut Diagnostic v15
-- Smart teleport (ground-aware), robust axe lookup, payload sweeps.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Interaction = ReplicatedStorage:WaitForChild("Interaction")
local RemoteProxy = Interaction:WaitForChild("RemoteProxy")

local CONFIG = {
    MIN_HP            = 40,
    TAP_RADIUS        = 8,
    BURST_DELAY       = 1.0,
    TELEPORT_SETTLE   = 0.35,
    TELEPORT_ENABLED  = true,
    TP_SIDE_OFFSET    = 4,     -- horizontal studs from plank center
    TP_GROUND_MARGIN  = 3,     -- how high above ground to stand
    TP_MAX_GROUND_GAP = 8,     -- if ground is farther than this below plank base, float instead
}

-- ============================================================
--  GODMODE
-- ============================================================
local godConn
local function applyGod()
    if godConn then return end
    godConn = RunService.Heartbeat:Connect(function()
        local c = LocalPlayer.Character
        if not c then return end
        local h = c:FindFirstChildOfClass("Humanoid")
        if h and h.Health < h.MaxHealth then h.Health = h.MaxHealth end
    end)
end
local function stopGod()
    if godConn then godConn:Disconnect(); godConn = nil end
end
applyGod()
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5); stopGod(); applyGod()
end)

pcall(function()
    local mt = getrawmetatable(game)
    local old = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local m = getnamecallmethod()
        if m == "TakeDamage" and self:IsA("Humanoid")
           and self:IsDescendantOf(LocalPlayer.Character) then
            return 0
        end
        return old(self, ...)
    end)
    setreadonly(mt, true)
end)

-- ============================================================
--  WATER REMOVAL
-- ============================================================
local function nukeWater()
    local count = 0
    local terms = {"water","swamp","ocean","river","lake","sea","damagezone","hazard"}
    local snap = {}
    for _, d in ipairs(workspace:GetDescendants()) do table.insert(snap, d) end
    for _, d in ipairs(snap) do
        if d and d.Parent then
            local kind = d:IsA("BasePart") or d:IsA("Folder")
                      or d:IsA("Model") or d:IsA("TrussPart")
            if kind then
                local n = d.Name:lower()
                for _, t in ipairs(terms) do
                    if n:find(t) then
                        pcall(function() d:Destroy() end)
                        count = count + 1
                        break
                    end
                end
            end
        end
    end
    return count
end

task.spawn(function()
    local n = nukeWater()
    print("[v15] Water removed:", n)
end)

-- ============================================================
--  GUI
-- ============================================================
local sg = Instance.new("ScreenGui")
sg.Name = "LT2_CutDiag15"
sg.ResetOnSpawn = false
sg.Parent = LocalPlayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 580, 0, 500)
frame.Position = UDim2.new(0.5, -290, 0.5, -250)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = sg

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
title.BorderSizePixel = 0
title.Text = "LT2 Cut Diagnostic v15 - smart teleport"
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
    b.TextSize = 11
    b.Font = Enum.Font.SourceSansBold
    b.TextWrapped = true
    b.Parent = frame
    return b
end

local listBtn   = mkBtn("List",      4,   32, 50, 30, Color3.fromRGB(60, 120, 200))
local copyBtn   = mkBtn("Copy",      58,  32, 50, 30, Color3.fromRGB(60, 180, 100))
local clearBtn  = mkBtn("Clear",     112, 32, 50, 30, Color3.fromRGB(150, 80, 80))
local waterBtn  = mkBtn("Nuke H2O",  166, 32, 70, 30, Color3.fromRGB(60, 160, 200))
local stopBtn   = mkBtn("STOP",      240, 32, 50, 30, Color3.fromRGB(200, 50, 50))
local tpBtn     = mkBtn("TP: ON",    294, 32, 60, 30, Color3.fromRGB(60, 140, 100))
local toBpBtn   = mkBtn("To BP",     358, 32, 55, 30, Color3.fromRGB(200, 140, 50))

local axeInfo = Instance.new("TextLabel")
axeInfo.Size = UDim2.new(1, -420, 0, 30)
axeInfo.Position = UDim2.new(0, 420, 0, 32)
axeInfo.BackgroundTransparency = 1
axeInfo.Text = "axe: ?"
axeInfo.TextColor3 = Color3.fromRGB(255, 200, 100)
axeInfo.TextSize = 10
axeInfo.Font = Enum.Font.Code
axeInfo.TextXAlignment = Enum.TextXAlignment.Left
axeInfo.Parent = frame

local lbl2 = Instance.new("TextLabel")
lbl2.Size = UDim2.new(1, -8, 0, 18)
lbl2.Position = UDim2.new(0, 4, 0, 66)
lbl2.BackgroundTransparency = 1
lbl2.Text = "Payload tests (auto-teleports to plank unless TP is OFF):"
lbl2.TextColor3 = Color3.fromRGB(200, 200, 200)
lbl2.TextSize = 11
lbl2.Font = Enum.Font.SourceSansBold
lbl2.TextXAlignment = Enum.TextXAlignment.Left
lbl2.Parent = frame

local v_exact = mkBtn("Exact",     4,   86, 90, 26, Color3.fromRGB(70, 130, 90))
local v_sweep = mkBtn("Sweep h",   98,  86, 90, 26, Color3.fromRGB(70, 90, 130))
local v_dirs  = mkBtn("Face dirs", 192, 86, 90, 26, Color3.fromRGB(70, 90, 130))
local v_sect  = mkBtn("Sections",  286, 86, 90, 26, Color3.fromRGB(70, 90, 130))
local v_tp    = mkBtn("Just TP",   380, 86, 90, 26, Color3.fromRGB(200, 140, 60))
local v_all   = mkBtn("TRY ALL",   474, 86, 100, 26, Color3.fromRGB(200, 60, 60))

local logBox = Instance.new("ScrollingFrame")
logBox.Size = UDim2.new(1, -10, 1, -290)
logBox.Position = UDim2.new(0, 5, 0, 122)
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

--- Search broadly: Backpack, Tools folder, Character, and Player itself.
local function findAxe()
    local containers = {
        LocalPlayer:FindFirstChild("Backpack"),
        LocalPlayer:FindFirstChild("Tools"),
        LocalPlayer.Character,
        LocalPlayer,
    }
    local seen = {}
    for _, cont in ipairs(containers) do
        if cont then
            for _, d in ipairs(cont:GetDescendants()) do
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

local function moveAxeToBackpack()
    local c = LocalPlayer.Character
    if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid")
    if h then
        pcall(function() h:UnequipTools() end)
        task.wait(0.2)
    end
end

-- ============================================================
--  SMART TELEPORT (ground-aware)
-- ============================================================
--- Teleports the player right beside the plank.
--- Checks for ground under the target spot; stands on it if close,
--- otherwise floats at plank-center height.
--- @return string "ground" or "float" or "fail"
local function teleportNear(plank)
    local c = LocalPlayer.Character
    if not c then return "fail" end
    local root = c:FindFirstChild("HumanoidRootPart")
    if not root then return "fail" end
    local ws = getWoodSection(plank)
    if not ws then return "fail" end

    -- Side offset (perpendicular to plank axis; planks are usually Y-up, so use X)
    local sideX, sideZ = CONFIG.TP_SIDE_OFFSET, 0

    -- Try +X, then -X, then +Z, then -Z for an unobstructed side
    local sides = {
        Vector3.new(sideX, 0, 0),
        Vector3.new(-sideX, 0, 0),
        Vector3.new(0, 0, sideX),
        Vector3.new(0, 0, -sideX),
    }

    local chosenSide = sides[1]
    for _, s in ipairs(sides) do
        -- Raycast horizontally from plank to check for obstructions at mid-height
        local origin = ws.Position
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { c, plank, sg }
        local hit = workspace:Raycast(origin, s, params)
        if not hit then
            chosenSide = s
            break
        end
    end

    local targetX = ws.Position.X + chosenSide.X
    local targetZ = ws.Position.Z + chosenSide.Z

    -- Raycast down from above the plank bottom to find ground
    local plankBottom = ws.Position.Y - (ws.Size.Y / 2)
    local castOrigin = Vector3.new(targetX, plankBottom + 2, targetZ)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { c, plank, sg }
    local hit = workspace:Raycast(castOrigin, Vector3.new(0, -500, 0), params)

    local goalY, mode
    if hit and (plankBottom - hit.Position.Y) <= CONFIG.TP_MAX_GROUND_GAP then
        -- Ground is close to plank base — stand on it
        goalY = hit.Position.Y + CONFIG.TP_GROUND_MARGIN
        mode = "ground"
    else
        -- No ground, or too far below — float at plank center
        goalY = ws.Position.Y
        mode = "float"
    end

    local goalPos = Vector3.new(targetX, goalY, targetZ)
    local lookAt = Vector3.new(ws.Position.X, goalY, ws.Position.Z)

    root.CFrame = CFrame.new(goalPos, lookAt)
    root.AssemblyLinearVelocity = Vector3.zero
    task.wait(CONFIG.TELEPORT_SETTLE)
    return mode
end

-- ============================================================
--  FIRE CORE
-- ============================================================
local function fire(plank, tool, height, faceVector, sectionId, cooldown, hitPoints)
    local cutEvent = plank:FindFirstChild("CutEvent")
    if not cutEvent or not tool then return false end
    local payload = {
        height = height,
        faceVector = faceVector or Vector3.new(1, 0, 0),
        cooldown = cooldown or 0.23737628459930421,
        sectionId = sectionId or 1,
        hitPoints = hitPoints or 1.2,
        tool = tool,
        cuttingClass = "Axe",
    }
    return pcall(function() RemoteProxy:FireServer(cutEvent, payload) end)
end

--- Full test: teleport, re-find tool, fire, measure.
local function tryFire(plank, height, faceVector, sectionId)
    if CONFIG.TELEPORT_ENABLED then
        local mode = teleportNear(plank)
        log(("  teleport=%s  dist=%.2f"):format(mode,
            (LocalPlayer.Character.HumanoidRootPart.Position
             - (getWoodSection(plank) and getWoodSection(plank).Position
                or plank:GetPivot().Position)).Magnitude))
    end

    moveAxeToBackpack()
    local tool = findAxe()
    if not tool then return false, "no axe" end

    local before = getSize(plank)
    fire(plank, tool, height, faceVector, sectionId)
    task.wait(1.0)
    local after = getSize(plank)
    if not plank.Parent then return true, "destroyed" end
    if not before or not after then return false, "no size" end
    local diff = (before - after).Magnitude
    if diff > 0.05 then
        return true, string.format("size %.2f->%.2f", before.Y, after.Y)
    end
    return false, "no change"
end

-- ============================================================
--  TESTS
-- ============================================================
local busy = false
local function pickBiggest()
    local planks = findAllPlanks()
    if #planks == 0 then return nil end
    table.sort(planks, function(a, b)
        return (getSize(a) and getSize(a).Magnitude or 0) >
               (getSize(b) and getSize(b).Magnitude or 0)
    end)
    return planks[1]
end

local function testExact()
    if busy then return end
    busy = true
    local p = pickBiggest()
    if not p then log("No planks"); busy = false return end
    log("=== EXACT payload on " .. getWoodType(p) .. " " .. fmtVec(getSize(p)) .. " ===")
    local ok, why = tryFire(p, 1.5217468291521072, Vector3.new(1,0,0), 1)
    log("  result: " .. (ok and "WORKED" or "no") .. " (" .. tostring(why) .. ")")
    busy = false
end

local function testSweep()
    if busy then return end
    busy = true
    local p = pickBiggest()
    if not p then log("No planks"); busy = false return end
    log("=== SWEEP heights on " .. getWoodType(p) .. " " .. fmtVec(getSize(p)) .. " ===")
    if CONFIG.TELEPORT_ENABLED then
        local mode = teleportNear(p)
        log("  teleported: " .. mode)
    end
    local heights = {0.5, 1, 1.5, 2, 3, 4, 5, 8, 12, 20, 30}
    for _, h in ipairs(heights) do
        if getHP() < CONFIG.MIN_HP then log("  HP low, stop"); break end
        if not p.Parent then log("  plank gone"); break end
        local before = getSize(p)
        local tool = findAxe()
        if not tool then
            log("  no axe, searching...")
            moveAxeToBackpack()
            tool = findAxe()
            if not tool then log("  still none, stop"); break end
        end
        fire(p, tool, h, Vector3.new(1,0,0), 1)
        task.wait(1.0)
        local after = getSize(p)
        if not p.Parent then log(("  h=%.2f -> DESTROYED"):format(h)); break end
        if before and after then
            local d = (before - after).Magnitude
            log(("  h=%.2f  %s"):format(h, d > 0.05
                and ("<<< WORKED " .. fmtVec(before) .. "->" .. fmtVec(after))
                or "no"))
            if d > 0.05 then log("  SUCCESS at h=" .. h); break end
        end
    end
    log("=== SWEEP DONE ===")
    busy = false
end

local function testDirs()
    if busy then return end
    busy = true
    local p = pickBiggest()
    if not p then log("No planks"); busy = false return end
    log("=== FACE VECTORS on " .. getWoodType(p) .. " ===")
    if CONFIG.TELEPORT_ENABLED then teleportNear(p) end
    local dirs = {
        {"+X", Vector3.new(1,0,0)},
        {"-X", Vector3.new(-1,0,0)},
        {"+Y", Vector3.new(0,1,0)},
        {"-Y", Vector3.new(0,-1,0)},
        {"+Z", Vector3.new(0,0,1)},
        {"-Z", Vector3.new(0,0,-1)},
    }
    for _, entry in ipairs(dirs) do
        if not p.Parent then break end
        local name, dir = entry[1], entry[2]
        local before = getSize(p)
        local tool = findAxe() or (moveAxeToBackpack() or findAxe())
        if not tool then break end
        fire(p, tool, 1.5217468291521072, dir, 1)
        task.wait(1.0)
        local after = getSize(p)
        if not p.Parent then log("  dir=" .. name .. " DESTROYED"); break end
        local d = (before and after) and (before - after).Magnitude or 0
        log(("  dir=%s  %s"):format(name, d > 0.05 and "<<< WORKED" or "no"))
        if d > 0.05 then log("  SUCCESS dir=" .. name); break end
    end
    log("=== DIRS DONE ===")
    busy = false
end

local function testSections()
    if busy then return end
    busy = true
    local p = pickBiggest()
    if not p then log("No planks"); busy = false return end
    log("=== SECTION IDS on " .. getWoodType(p) .. " ===")
    if CONFIG.TELEPORT_ENABLED then teleportNear(p) end
    for s = 1, 6 do
        if not p.Parent then break end
        local before = getSize(p)
        local tool = findAxe() or (moveAxeToBackpack() or findAxe())
        if not tool then break end
        fire(p, tool, 1.5217468291521072, Vector3.new(1,0,0), s)
        task.wait(1.0)
        local after = getSize(p)
        if not p.Parent then log("  sect=" .. s .. " DESTROYED"); break end
        local d = (before and after) and (before - after).Magnitude or 0
        log(("  sect=%d  %s"):format(s, d > 0.05 and "<<< WORKED" or "no"))
        if d > 0.05 then log("  SUCCESS sect=" .. s); break end
    end
    log("=== SECTIONS DONE ===")
    busy = false
end

local function testJustTP()
    if busy then return end
    busy = true
    local p = pickBiggest()
    if not p then log("No planks"); busy = false return end
    log("=== TELEPORT TEST on " .. getWoodType(p) .. " ===")
    local mode = teleportNear(p)
    log("  mode: " .. mode)
    local c = LocalPlayer.Character
    if c then
        local root = c:FindFirstChild("HumanoidRootPart")
        if root then log("  final pos: " .. fmtVec(root.Position)) end
    end
    busy = false
end

local function testAll()
    if busy then return end
    log("################ TRY ALL ################")
    testExact();  task.wait(0.5)
    testSweep();  task.wait(0.5)
    testDirs();   task.wait(0.5)
    testSections()
    log("################ TRY ALL DONE ################")
end

-- ============================================================
--  BUTTONS
-- ============================================================
local function refreshAxeLabel()
    local a = findAxe()
    if a then
        axeInfo.Text = "axe: " .. toolRealName(a) .. " (" .. a.Parent.Name .. ")"
    else
        axeInfo.Text = "axe: NONE"
    end
end

local function runList()
    for _, c in ipairs(picker:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    refreshAxeLabel()
    local planks = findAllPlanks()
    log(("Found %d planks."):format(#planks))
    if #planks == 0 then picker.Visible = false return end
    table.sort(planks, function(a, b)
        return (getSize(a) and getSize(a).Magnitude or 0) >
               (getSize(b) and getSize(b).Magnitude or 0)
    end)
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
            log("Picked #" .. i)
            if busy then return end
            busy = true
            log("=== Exact payload on picked plank ===")
            local ok, why = tryFire(p, 1.5217468291521072, Vector3.new(1,0,0), 1)
            log("  result: " .. (ok and "WORKED" or "no") .. " (" .. tostring(why) .. ")")
            busy = false
        end)
    end
    picker.Visible = true
end

listBtn.Activated:Connect(runList)

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

waterBtn.Activated:Connect(function()
    local n = nukeWater()
    log("Water removed: " .. n .. " objects")
end)

stopBtn.Activated:Connect(function()
    busy = false
    log("Stopped.")
end)

tpBtn.Activated:Connect(function()
    CONFIG.TELEPORT_ENABLED = not CONFIG.TELEPORT_ENABLED
    if CONFIG.TELEPORT_ENABLED then
        tpBtn.Text = "TP: ON"
        tpBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 100)
        log("Teleport ON.")
    else
        tpBtn.Text = "TP: OFF"
        tpBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
        log("Teleport OFF.")
    end
end)

toBpBtn.Activated:Connect(function()
    moveAxeToBackpack()
    refreshAxeLabel()
    log("Moved to Backpack.")
end)

v_exact.Activated:Connect(testExact)
v_sweep.Activated:Connect(testSweep)
v_dirs.Activated:Connect(testDirs)
v_sect.Activated:Connect(testSections)
v_tp.Activated:Connect(testJustTP)
v_all.Activated:Connect(testAll)

-- ============================================================
--  TAP-TO-PICK
-- ============================================================
local function raycast(pos)
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local ray = cam:ViewportPointToRay(pos.X, pos.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { sg, LocalPlayer.Character }
    local r = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
    return r and r.Instance, r and r.Position or nil
end

local function findNear(worldPos, radius)
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
    local hit, hitPos = raycast(pos)
    if not hit then return end
    local model = hit:FindFirstAncestorOfClass("Model")
    local target
    if model and isPlank(model) then
        log("Tapped: " .. getWoodType(model))
        target = model
    else
        local near = findNear(hitPos, CONFIG.TAP_RADIUS)
        if near then
            log("Nearby: " .. getWoodType(near))
            target = near
        end
    end
    if not target then return end
    if busy then return end
    busy = true
    local ok, why = tryFire(target, 1.5217468291521072, Vector3.new(1,0,0), 1)
    log("  result: " .. (ok and "WORKED" or "no") .. " (" .. tostring(why) .. ")")
    busy = false
end)

-- ============================================================
--  STARTUP
-- ============================================================
refreshAxeLabel()
log("v15 ready. Water auto-removed. TP: " .. (CONFIG.TELEPORT_ENABLED and "ON" or "OFF"))
log("TP walks to the plank's side and finds the ground.")
log("Try 'Just TP' first to see where you land.")
