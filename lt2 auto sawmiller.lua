-- LT2 Cut Diagnostic v15
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
