-- ============================================================
-- LT2 PLANK MOVER & AUTO-CUTTER v7
-- Includes plank orientation (length→feed, height→up, width→side)
-- Size limits: W<=3.0, H<=2.6, L<=10.0
-- ============================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local LocalPlayer       = Players.LocalPlayer
local PlayerGui         = LocalPlayer:WaitForChild("PlayerGui")

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

    SAWMILL_MAX_WIDTH  = 3.0,
    SAWMILL_MAX_HEIGHT = 2.6,
    SAWMILL_MAX_LENGTH = 10.0,

    DEFAULT_FEED_DIR = Vector3.new(0, 0, 1),

    AUTO_INTERVAL = 2.0,
    MAX_QUEUE     = 2,
    GODMODE       = true,

    MIN_FRAME_W = 300,
    MIN_FRAME_H = 340,
    START_W     = 340,
    START_H     = 380,
}

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
    waterStash      = {},
}

-- ============================================================
-- GUI
-- ============================================================
local sg = Instance.new("ScreenGui")
sg.Name = "LT2_PlankMover"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.DisplayOrder = 999
sg.Parent = PlayerGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, CONFIG.START_W, 0, CONFIG.START_H)
mainFrame.Position = UDim2.new(0.5, -CONFIG.START_W/2, 0.5, -CONFIG.START_H/2)
mainFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = sg

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 28)
titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
titleBar.BorderSizePixel = 0
titleBar.Active = true
titleBar.Parent = mainFrame

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -36, 1, 0)
titleLbl.Position = UDim2.new(0, 8, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "LT2 Plank Mover"
titleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLbl.TextSize = 13
titleLbl.Font = Enum.Font.SourceSansBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -28, 0, 2)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 13
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.Parent = titleBar

local reopenBtn = Instance.new("TextButton")
reopenBtn.Size = UDim2.new(0, 44, 0, 44)
reopenBtn.Position = UDim2.new(0, 16, 0.5, -22)
reopenBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 100)
reopenBtn.BorderSizePixel = 0
reopenBtn.Text = "LT2"
reopenBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
reopenBtn.TextSize = 13
reopenBtn.Font = Enum.Font.SourceSansBold
reopenBtn.Visible = false
reopenBtn.Parent = sg

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -10, 0, 26)
statusLbl.Position = UDim2.new(0, 5, 0, 32)
statusLbl.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
statusLbl.BorderSizePixel = 0
statusLbl.Text = "Ready"
statusLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
statusLbl.TextSize = 11
statusLbl.Font = Enum.Font.SourceSans
statusLbl.Parent = mainFrame

local function mkBtn(text, posX, posY, sizeX, sizeY, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(sizeX, 0, 0, sizeY)
    b.Position = UDim2.new(posX, 5, 0, posY)
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 11
    b.Font = Enum.Font.SourceSansBold
    b.TextWrapped = true
    b.Parent = mainFrame
    return b
end

local selSawBtn  = mkBtn("1. Select Sawmill",  0.00, 62,  0.49, 30, Color3.fromRGB(60, 120, 200))
local selPlkBtn  = mkBtn("2. Select Plank",    0.51, 62,  0.49, 30, Color3.fromRGB(60, 180, 100))
local moveBtn    = mkBtn("3. Move to Sawmill", 0.00, 96,  0.49, 30, Color3.fromRGB(200, 150, 50))
local cutBtn     = mkBtn("Cut Plank to 1x1",   0.51, 96,  0.49, 30, Color3.fromRGB(180, 80, 180))

local div = Instance.new("Frame")
div.Size = UDim2.new(1, -10, 0, 1)
div.Position = UDim2.new(0, 5, 0, 130)
div.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
div.BorderSizePixel = 0
div.Parent = mainFrame

local autoMoveBtn = mkBtn("Auto Move: OFF", 0.00, 136, 0.49, 28, Color3.fromRGB(90, 90, 90))
local autoCutBtn  = mkBtn("Auto Cut: OFF",  0.51, 136, 0.49, 28, Color3.fromRGB(90, 90, 90))

local orientBtn = mkBtn("Orient",  0.00, 168, 0.24, 26, Color3.fromRGB(140, 100, 200))
local godBtn    = mkBtn("God: ON", 0.25, 168, 0.24, 26, Color3.fromRGB(60, 140, 100))
local listBtn   = mkBtn("List",    0.50, 168, 0.24, 26, Color3.fromRGB(60, 120, 200))
local copyBtn   = mkBtn("Copy",    0.75, 168, 0.24, 26, Color3.fromRGB(60, 180, 100))

local clearBtn = mkBtn("Clear", 0.00, 198, 0.99, 22, Color3.fromRGB(150, 80, 80))

local logBox = Instance.new("ScrollingFrame")
logBox.Size = UDim2.new(1, -10, 1, -240)
logBox.Position = UDim2.new(0, 5, 0, 230)
logBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
logBox.BorderSizePixel = 0
logBox.ScrollBarThickness = 5
logBox.CanvasSize = UDim2.new(0, 0, 0, 0)
logBox.AutomaticCanvasSize = Enum.AutomaticSize.Y
logBox.Parent = mainFrame

local logLayout = Instance.new("UIListLayout")
logLayout.Padding = UDim.new(0, 2)
logLayout.SortOrder = Enum.SortOrder.LayoutOrder
logLayout.Parent = logBox

local picker = Instance.new("ScrollingFrame")
picker.Size = UDim2.new(1, -10, 0, 170)
picker.Position = UDim2.new(0, 5, 1, -178)
picker.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
picker.BorderSizePixel = 0
picker.ScrollBarThickness = 5
picker.Visible = false
picker.CanvasSize = UDim2.new(0, 0, 0, 0)
picker.AutomaticCanvasSize = Enum.AutomaticSize.Y
picker.ZIndex = 10
picker.Parent = mainFrame

local pickerLayout = Instance.new("UIListLayout")
pickerLayout.Padding = UDim.new(0, 2)
pickerLayout.SortOrder = Enum.SortOrder.LayoutOrder
pickerLayout.Parent = picker

-- ============================================================
-- RESIZE HANDLES
-- ============================================================
local function mkHandle(name, anchorX, anchorY)
    local h = Instance.new("TextButton")
    h.Name = name
    h.Size = UDim2.new(0, 12, 0, 12)
    h.AnchorPoint = Vector2.new(anchorX, anchorY)
    h.Position = UDim2.new(anchorX, 0, anchorY, 0)
    h.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
    h.BorderSizePixel = 0
    h.Text = ""
    h.AutoButtonColor = false
    h.ZIndex = 20
    h.Parent = mainFrame
    return h
end

local hBR = mkHandle("RB", 1, 1)
local hTR = mkHandle("RT", 1, 0)
local hBL = mkHandle("LB", 0, 1)
local hTL = mkHandle("LT", 0, 0)

local resizing, resizeStart, resizeStartSize, resizeCorner = false, nil, nil, nil

local function beginResize(corner, input)
    resizing = true
    resizeCorner = corner
    resizeStart = Vector2.new(input.Position.X, input.Position.Y)
    resizeStartSize = mainFrame.AbsoluteSize
end

local function updateResize(input)
    if not resizing then return end
    local mx = input.Position.X - resizeStart.X
    local my = input.Position.Y - resizeStart.Y
    local w, h = resizeStartSize.X, resizeStartSize.Y
    if resizeCorner == "RB" then w = w + mx; h = h + my
    elseif resizeCorner == "RT" then w = w + mx; h = h - my
    elseif resizeCorner == "LB" then w = w - mx; h = h + my
    elseif resizeCorner == "LT" then w = w - mx; h = h - my end
    w = math.max(CONFIG.MIN_FRAME_W, w)
    h = math.max(CONFIG.MIN_FRAME_H, h)
    mainFrame.Size = UDim2.new(0, w, 0, h)
end

local function endResize() resizing = false; resizeCorner = nil end

for _, pair in ipairs({{hBR,"RB"},{hTR,"RT"},{hBL,"LB"},{hTL,"LT"}}) do
    local h, corner = pair[1], pair[2]
    h.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            beginResize(corner, input)
        end
    end)
end

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
-- LOG / STATUS
-- ============================================================
local logBuffer = {}
local function log(msg)
    table.insert(logBuffer, msg)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -6, 0, 16)
    l.BackgroundTransparency = 1
    l.Text = msg
    l.TextColor3 = Color3.fromRGB(220, 220, 220)
    l.TextSize = 10
    l.Font = Enum.Font.Code
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = logBox
    task.wait()
    logBox.CanvasPosition = Vector2.new(0, logLayout.AbsoluteContentSize.Y)
end
local function setStatus(txt) statusLbl.Text = txt end

closeBtn.Activated:Connect(function()
    mainFrame.Visible = false
    reopenBtn.Visible = true
end)
reopenBtn.Activated:Connect(function()
    mainFrame.Visible = true
    reopenBtn.Visible = false
end)

log("UI loaded.")

-- ============================================================
-- REMOTES
-- ============================================================
local Interaction = ReplicatedStorage:WaitForChild("Interaction")
local RemoteProxy = Interaction:WaitForChild("RemoteProxy")
local ClientIsDragging = Interaction:FindFirstChild("ClientIsDragging")

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
-- WATER STASH
-- ============================================================
local function stashWater()
    if #state.waterStash > 0 then return 0 end
    local terms = {"water","swamp","ocean","river","lake","sea","damagezone","hazard"}
    local snap = {}
    for _, d in ipairs(workspace:GetDescendants()) do snap[d] = true end
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
    for _, cont in ipairs({
        LocalPlayer:FindFirstChild("Backpack"),
        LocalPlayer:FindFirstChild("Tools"),
        LocalPlayer.Character,
    }) do
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
    return model:FindFirstChild("CutEvent") ~= nil
end

local function isSawmill(model)
    if not model or not model:IsA("Model") then return false end
    if not ownerMatches(model, LocalPlayer) then return false end
    return model:FindFirstChild("Conveyor") ~= nil
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
-- ORIENTATION
-- ============================================================
-- Roblox convention: XVector × YVector = ZVector (Right × Up = -Look)
-- We want the largest local axis along the feed direction,
-- the smallest along world up, and the middle along the side.
-- Given the ranking, this function returns the correct world
-- directions for the local X, Y, and Z axes with proper
-- handedness so a valid CFrame is produced.
local function computeTargetBasis(A_L, A_M, A_S, F, U)
    -- F = feed (unit), U = up (unit, always world up (0,1,0))
    -- S = U × F, but avoid normalizing a zero vector
    local S = U:Cross(F)
    if S.Magnitude < 0.01 then
        S = Vector3.new(1, 0, 0)
    end
    S = S.Unit

    local V = {}
    if A_L == "X" and A_M == "Y" and A_S == "Z" then
        V.X, V.Y, V.Z = F, S, U
    elseif A_L == "X" and A_M == "Z" and A_S == "Y" then
        V.X, V.Y, V.Z = F, U, -S
    elseif A_L == "Y" and A_M == "X" and A_S == "Z" then
        V.X, V.Y, V.Z = S, F, U
    elseif A_L == "Y" and A_M == "Z" and A_S == "X" then
        V.X, V.Y, V.Z = U, F, S
    elseif A_L == "Z" and A_M == "X" and A_S == "Y" then
        V.X, V.Y, V.Z = S, U, F
    elseif A_L == "Z" and A_M == "Y" and A_S == "X" then
        V.X, V.Y, V.Z = U, -S, F
    end
    return V.X, V.Y, V.Z
end

--- Rotate a plank so its largest dim → feed dir (horizontal),
--- smallest dim → up, and middle dim → side.
--- @param plank Model
--- @param feedDir Vector3|nil  Horizontal direction the length should point
--- @return boolean success, string reason
local function orientPlank(plank, feedDir)
    if not plank or not plank.Parent then return false, "no plank" end
    local ws = getWoodSection(plank)
    if not ws then return false, "no WoodSection" end

    feedDir = feedDir or CONFIG.DEFAULT_FEED_DIR
    local worldUp = Vector3.new(0, 1, 0)

    -- Flatten feed to horizontal
    local F = feedDir - feedDir:Dot(worldUp) * worldUp
    if F.Magnitude < 0.01 then
        F = CONFIG.DEFAULT_FEED_DIR
    end
    F = F.Unit

    -- Rank local axes by size
    local s = ws.Size
    local ranked = {
        {axis = "X", size = s.X},
        {axis = "Y", size = s.Y},
        {axis = "Z", size = s.Z},
    }
    table.sort(ranked, function(a, b) return a.size < b.size end)
    -- ranked[1] = smallest, [2] = middle, [3] = largest

    -- Skip if already oriented (avoids jitter)
    local curUp = ws.CFrame.UpVector
    if math.abs(curUp.Y) > 0.98 then
        -- already vertical for smallest axis? do a quick check that the
        -- axis which is currently vertical is the smallest one.
        local verticalLocal = "Y"
        if math.abs(ws.CFrame.RightVector.Y) > math.abs(curUp.Y) then
            verticalLocal = "X"
        elseif math.abs(ws.CFrame.LookVector.Y) > math.abs(curUp.Y) then
            verticalLocal = "Z"
        end
        if verticalLocal == ranked[1].axis then
            -- Already correct; still ensure the long axis points along feed
            local longAxisCur
            if ranked[3].axis == "X" then longAxisCur = ws.CFrame.RightVector
            elseif ranked[3].axis == "Y" then longAxisCur = ws.CFrame.UpVector
            else longAxisCur = ws.CFrame.LookVector end
            local horiz = Vector3.new(longAxisCur.X, 0, longAxisCur.Z)
            if horiz.Magnitude > 0.9 and horiz.Unit:Dot(F) > 0.98 then
                return true, "already oriented"
            end
        end
    end

    local vX, vY, vZ = computeTargetBasis(
        ranked[3].axis, ranked[2].axis, ranked[1].axis, F, worldUp)

    -- Preserve position, change rotation only
    local newCF = CFrame.fromMatrix(ws.CFrame.Position, vX, vY, vZ)
    ws.CFrame = newCF
    return true, "oriented"
end

--- Get the feed direction from a sawmill's Conveyor.
local function getSawmillFeedDir(sawmill)
    if not sawmill then return CONFIG.DEFAULT_FEED_DIR end
    local conv = sawmill:FindFirstChild("Conveyor")
    if conv and conv:IsA("BasePart") then
        local look = conv.CFrame.LookVector
        look = Vector3.new(look.X, 0, look.Z)
        if look.Magnitude > 0.01 then return look.Unit end
    end
    return CONFIG.DEFAULT_FEED_DIR
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
        height       = height,
        faceVector   = CONFIG.FACE_VECTOR,
        cooldown     = CONFIG.COOLDOWN,
        sectionId    = CONFIG.SECTION_ID,
        hitPoints    = CONFIG.HIT_POINTS,
        tool         = axe,
        cuttingClass = CONFIG.CUTTING_CLASS,
    }
    return pcall(function() RemoteProxy:FireServer(cutEvent, payload) end)
end

local function cutTo1x1(plank, announceFn)
    if not plank or not plank.Parent then return false end

    local stashed = stashWater()
    if stashed > 0 and announceFn then
        announceFn("Water stashed (" .. stashed .. ").")
    end

    local ok = (function()
        local axe = findAxe()
        if not axe then
            if announceFn then announceFn("No axe.") end
            return false
        end
        ensureEquipped(axe)

        local mode = teleportNear(plank)
        if announceFn then announceFn("TP: " .. mode) end

        axe = findAxe()
        if not axe then
            if announceFn then announceFn("Axe lost.") end
            return false
        end

        local cuts = 0
        while cuts < CONFIG.MAX_CUTS do
            if not plank.Parent then
                if announceFn then announceFn("Plank destroyed.") end
                return true
            end
            if getHP() < CONFIG.MIN_HP then
                if announceFn then announceFn("HP low.") end
                return false
            end
            local size = getSize(plank)
            if not size then break end
            local d = {size.X, size.Y, size.Z}
            table.sort(d)
            if d[1] <= 1.05 and d[2] <= 1.05 then
                if announceFn then announceFn("1x1 done (" .. cuts .. " cuts).") end
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
                announceFn("Cut " .. cuts .. ".")
            end
            task.wait(CONFIG.CUT_DELAY)
        end
        if announceFn then announceFn("Stopped after " .. cuts .. ".") end
        return false
    end)()

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
    if not plank or not sawmill then return false, "missing arg" end

    -- 1) Orient the plank at its current location (using sawmill feed dir)
    local feedDir = getSawmillFeedDir(sawmill)
    orientPlank(plank, feedDir)

    -- 2) Teleport player near (unchanged position after rotation)
    teleportNear(plank)

    -- 3) Grab ownership
    grabOwnership(plank)
    task.wait(0.1)

    -- 4) Find the target position
    local loadPart = sawmill:FindFirstChild("LoadingHole")
                  or sawmill:FindFirstChild("Loading")
    local target
    if loadPart then target = loadPart.Position
    else target = sawmill:GetPivot().Position + Vector3.new(0, 2, 0) end

    -- 5) Move the plank but PRESERVE its rotation
    local curPivot = plank:GetPivot()
    local newPivot = CFrame.new(target) * curPivot.Rotation
    plank:PivotTo(newPivot)

    -- 6) Re-orient at the sawmill position (belt and braces)
    task.wait(0.05)
    orientPlank(plank, feedDir)

    task.wait(0.1)
    return true, "moved"
end

-- ============================================================
-- SAWMILL SIZE
-- ============================================================
local function plankFitsSawmill(plank, sawmill)
    if not plank then return false, "no plank" end
    local s = getSize(plank)
    if not s then return false, "no size" end

    local dims = {s.X, s.Y, s.Z}
    table.sort(dims)
    local smallest, middle, largest = dims[1], dims[2], dims[3]

    if smallest > CONFIG.SAWMILL_MAX_HEIGHT then
        return false, string.format("height %.2f > %.2f", smallest, CONFIG.SAWMILL_MAX_HEIGHT)
    end
    if middle > CONFIG.SAWMILL_MAX_WIDTH then
        return false, string.format("width %.2f > %.2f", middle, CONFIG.SAWMILL_MAX_WIDTH)
    end
    if largest > CONFIG.SAWMILL_MAX_LENGTH then
        return false, string.format("length %.2f > %.2f", largest, CONFIG.SAWMILL_MAX_LENGTH)
    end
    return true, "fits"
end

local function sawmillLimitString()
    return string.format("W<=%.1f H<=%.1f L<=%.1f",
        CONFIG.SAWMILL_MAX_WIDTH,
        CONFIG.SAWMILL_MAX_HEIGHT,
        CONFIG.SAWMILL_MAX_LENGTH)
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
                setStatus("Auto: no sawmill")
                task.wait(CONFIG.AUTO_INTERVAL); continue
            end
            if sawmillQueueFull(sawmill) then
                setStatus("Auto: queue full")
                task.wait(CONFIG.AUTO_INTERVAL); continue
            end
            local target
            for _, p in ipairs(findAllPlanks()) do
                if not state.processed[p] and plankFitsSawmill(p, sawmill) then
                    target = p; break
                end
            end
            if not target then
                setStatus("Auto: no plank fits (" .. sawmillLimitString() .. ")")
                task.wait(CONFIG.AUTO_INTERVAL); continue
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
-- TAP / PICK
-- ============================================================
local function raycastScreen(vpPos)
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local ray = cam:ViewportPointToRay(vpPos.X, vpPos.Y)
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
            local d = (m:GetPivot().Position - worldPos).Magnitude
            if d < bestD then bestD = d; best = m end
        end
    end
    if best and bestD <= radius then return best end
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
       and input.UserInputType ~= Enum.UserInputType.Touch then return end

    local screenPos = input.Position
    local guiObjs = PlayerGui:GetGuiObjectsAtPosition(screenPos.X, screenPos.Y)
    for _, obj in ipairs(guiObjs) do
        if obj:IsDescendantOf(sg) then return end
    end

    local vp = UserInputService:GetMouseLocation()
    local hit, hitPos = raycastScreen(vp)
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
                setStatus("Sawmill: " .. near.Name)
                log("Sawmill (nearby): " .. near.Name)
            else
                log("Not a sawmill.")
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
                setStatus("Plank: " .. getWoodType(near))
                log("Plank (nearby): " .. getWoodType(near))
            else
                log("Not a plank. (hit " .. hit.Name .. ")")
            end
        end
        return
    end
end)

-- ============================================================
-- BUTTON ACTIONS
-- ============================================================
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

    local size = getSize(state.selectedPlank)
    local fits, reason = plankFitsSawmill(state.selectedPlank, state.selectedSawmill)
    if not fits then
        log(string.format("Warning: %s (%s) - moving anyway.",
            size and fmtVec(size) or "?", reason))
    end

    state.busy = true
    setStatus("Moving plank...")
    local ok = movePlankToSawmill(state.selectedPlank, state.selectedSawmill)
    if ok then log("Plank moved and oriented.") else log("Move failed.") end
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

orientBtn.Activated:Connect(function()
    if not state.selectedPlank or not state.selectedPlank.Parent then
        log("No plank selected."); return
    end
    local feedDir = CONFIG.DEFAULT_FEED_DIR
    if state.selectedSawmill then
        feedDir = getSawmillFeedDir(state.selectedSawmill)
    end
    local ok, reason = orientPlank(state.selectedPlank, feedDir)
    log("Orient: " .. tostring(reason))
    local s = getSize(state.selectedPlank)
    if s then log("New size: " .. fmtVec(s)) end
end)

autoMoveBtn.Activated:Connect(function()
    state.autoMode = not state.autoMode
    if state.autoMode then
        autoMoveBtn.Text = "Auto Move: ON"
        autoMoveBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 100)
        log("Auto mode ON. Limits: " .. sawmillLimitString())
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
        startGod(); log("Godmode ON.")
    else
        godBtn.Text = "God: OFF"
        godBtn.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
        stopGod(); log("Godmode OFF.")
    end
end)

listBtn.Activated:Connect(function()
    for _, c in ipairs(picker:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local planks = findAllPlanks()
    log("Found " .. #planks .. " planks. Limits: " .. sawmillLimitString())
    if #planks == 0 then picker.Visible = false return end
    for i, p in ipairs(planks) do
        local s = getSize(p)
        local fits, reason = plankFitsSawmill(p, nil)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -6, 0, 26)
        b.BackgroundColor3 = fits and Color3.fromRGB(60, 120, 80) or Color3.fromRGB(70, 70, 70)
        b.BorderSizePixel = 0
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.TextSize = 10
        b.Font = Enum.Font.Code
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.ZIndex = 11
        b.Text = ("  #%d [%s] %s %s"):format(
            i, getWoodType(p), s and fmtVec(s) or "?",
            fits and "" or ("- " .. reason))
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
        pcall(function() setclipboard(text) end); log(">> Copied.")
    elseif type(toclipboard) == "function" then
        pcall(function() toclipboard(text) end); log(">> Copied.")
    else
        log("!! No clipboard.")
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
log("Ready.")
log("Limits: " .. sawmillLimitString())
log("Move & Auto orient planks: length→feed, height→up.")
log("'Orient' button rotates the selected plank in place.")
