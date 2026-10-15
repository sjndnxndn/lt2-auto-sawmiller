-- LT2 Cut Diagnostic v3
-- Finds the axe via ToolName StringValue child, and logs a real cut.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local RemoteProxy = ReplicatedStorage:WaitForChild("Interaction"):WaitForChild("RemoteProxy")

local setClipboard =
    (type(setclipboard) == "function" and setclipboard)
    or (type(toclipboard) == "function" and toclipboard)
    or (type(writeClipboard) == "function" and writeClipboard)
    or nil

-- ============================================================
--  GUI
-- ============================================================
local sg = Instance.new("ScreenGui")
sg.Name = "LT2_CutDiag3"
sg.ResetOnSpawn = false
sg.Parent = LocalPlayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 500, 0, 400)
frame.Position = UDim2.new(0.5, -250, 0.5, -200)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = sg

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
title.BorderSizePixel = 0
title.Text = "LT2 Cut Diagnostic v3"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 14
title.Font = Enum.Font.SourceSansBold
title.Parent = frame

local function mkBtn(text, x, w, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, 32)
    b.Position = UDim2.new(0, x, 0, 32)
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 13
    b.Font = Enum.Font.SourceSansBold
    b.Parent = frame
    return b
end

local listBtn  = mkBtn("List My Planks", 4,   130, Color3.fromRGB(60, 120, 200))
local copyBtn  = mkBtn("Copy Log",       138, 100, Color3.fromRGB(60, 180, 100))
local clearBtn = mkBtn("Clear Log",      242, 100, Color3.fromRGB(150, 80, 80))

local axeInfo = Instance.new("TextLabel")
axeInfo.Size = UDim2.new(1, -350, 0, 32)
axeInfo.Position = UDim2.new(0, 348, 0, 32)
axeInfo.BackgroundTransparency = 1
axeInfo.Text = "axe: ?"
axeInfo.TextColor3 = Color3.fromRGB(255, 200, 100)
axeInfo.TextSize = 11
axeInfo.Font = Enum.Font.Code
axeInfo.TextXAlignment = Enum.TextXAlignment.Left
axeInfo.Parent = frame

local logBox = Instance.new("ScrollingFrame")
logBox.Size = UDim2.new(1, -10, 1, -110)
logBox.Position = UDim2.new(0, 5, 0, 68)
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

--- Return the "real" name of a tool: checks StringValue named "ToolName" first.
local function toolRealName(tool)
    local tn = tool:FindFirstChild("ToolName")
    if tn and tn:IsA("StringValue") then
        return tn.Value
    end
    return tool.Name
end

--- Search Player.Backpack, Player.Tools, and Character for tool-like objects.
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

--- Find an axe. Matches against real name (ToolName) AND the object's Name.
local function findAxe()
    for _, tool in ipairs(gatherTools()) do
        local realName = (toolRealName(tool) or ""):lower()
        local objName  = (tool.Name or ""):lower()
        local function matches(s)
            return s:find("axe") or s:find("hatchet") or s:find("saw")
                or s:find("chop") or s:find("gingerbread")
        end
        if matches(realName) or matches(objName) then
            return tool, toolRealName(tool)
        end
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

local function snapshot(model, tag)
    local ok, _, size = pcall(function() return model:GetBoundingBox() end)
    log(("[%s] name=%s"):format(tag, model.Name))
    if ok then log(("[%s] size=%s"):format(tag, fmtVec(size))) end
    log(("[%s] pivot=%s"):format(tag, fmtVec(model:GetPivot().Position)))
    local kids = {}
    for _, c in ipairs(model:GetChildren()) do
        if c.ClassName == "ObjectValue" or c.ClassName == "NumberValue"
            or c.ClassName == "StringValue" or c.Name == "CutEvent"
            or c.Name == "Owner" or c.Name == "WoodSection" then
            table.insert(kids, c.ClassName .. ":" .. c.Name)
        end
    end
    log(("[%s] key children: %s"):format(tag, table.concat(kids, ", ")))
    -- Also log WoodSection size (this is the actual wood part)
    local ws = model:FindFirstChild("WoodSection")
    if ws and ws:IsA("BasePart") then
        log(("[%s] WoodSection.Size=%s"):format(tag, fmtVec(ws.Size)))
        log(("[%s] WoodSection.CFrame.Pos=%s"):format(tag, fmtVec(ws.Position)))
    end
end

-- ============================================================
--  CUT TEST
-- ============================================================
local busy = false

local function runCutTest(plank)
    if busy then return end
    busy = true

    log("========== NEW TEST ==========")
    log("Time: " .. os.date("%Y-%m-%d %H:%M:%S"))
    snapshot(plank, "BEFORE")

    local axe, realName = findAxe()
    if not axe then
        log("!! Still no axe found. Tools currently visible:")
        local all = gatherTools()
        if #all == 0 then
            log("   (none — equip an axe so it appears in Backpack)")
        else
            for _, t in ipairs(all) do
                log(("   tool: obj=%s real=%s"):format(t.Name, tostring(toolRealName(t))))
            end
        end
        busy = false
        return
    end
    log("Using axe: " .. tostring(realName) .. "  (obj=" .. axe.Name .. ")")

    local cutEvent = plank:FindFirstChild("CutEvent")
    if not cutEvent then
        log("!! No CutEvent child.")
        busy = false
        return
    end
    log("CutEvent class: " .. cutEvent.ClassName)

    -- watch workspace
    local beforeChildren = {}
    for _, c in ipairs(workspace:GetChildren()) do
        beforeChildren[c] = true
    end
    local watching = true
    task.spawn(function()
        local t0 = tick()
        while watching and tick() - t0 < 3 do
            for _, c in ipairs(workspace:GetChildren()) do
                if not beforeChildren[c] then
                    beforeChildren[c] = true
                    log("[NEW in workspace] " .. c.ClassName .. " : " .. c.Name)
                end
            end
            task.wait(0.1)
        end
    end)

    local payload = {
        height = 1,
        faceVector = Vector3.new(1, 0, 0),
        cooldown = 0.23737628459930421,
        sectionId = 1,
        hitPoints = 1.2,
        tool = axe,
        cuttingClass = "Axe",
    }
    log("Firing with height=1 ...")

    local ok, err = pcall(function()
        RemoteProxy:FireServer(cutEvent, payload)
    end)
    if not ok then
        log("!! FireServer error: " .. tostring(err))
        watching = false
        busy = false
        return
    end
    log("Fired. Waiting 2s...")
    task.wait(2)

    if plank.Parent then
        snapshot(plank, "AFTER ")
        log("Original plank parent: " .. plank.Parent:GetFullName())
    else
        log("Original plank was DESTROYED.")
    end

    watching = false
    log("========== TEST DONE =========")
    busy = false
end

-- ============================================================
--  BUTTONS (use .Activated — fires once for mouse OR touch)
-- ============================================================
local function runListPlanks()
    for _, c in ipairs(picker:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end

    -- Refresh axe info too
    local axe, realName = findAxe()
    if axe then axeInfo.Text = "axe: " .. tostring(realName)
    else axeInfo.Text = "axe: NONE" end

    local planks = findAllPlanks()
    log(("Found %d plank(s) you own."):format(#planks))
    if #planks == 0 then picker.Visible = false return end

    -- Sort smallest first (so the small ones are easier to test)
    table.sort(planks, function(a, b)
        local _, sa = a:GetBoundingBox()
        local _, sb = b:GetBoundingBox()
        return sa.Magnitude < sb.Magnitude
    end)

    for i, p in ipairs(planks) do
        local ok, _, size = pcall(function() return p:GetBoundingBox() end)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -6, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        btn.BorderSizePixel = 0
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 12
        btn.Font = Enum.Font.Code
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Text = ("  #%d  size=%s"):format(i, ok and fmtVec(size) or "?")
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

-- ============================================================
--  STARTUP
-- ============================================================
do
    local axe, realName = findAxe()
    if axe then
        axeInfo.Text = "axe: " .. tostring(realName)
        log("Axe found: " .. tostring(realName) .. " (obj=" .. axe.Name .. ")")
    else
        local all = gatherTools()
        axeInfo.Text = "axe: NONE (" .. #all .. " tools)"
        log(("No axe detected. %d tool(s) visible in Backpack/Character."):format(#all))
        for _, t in ipairs(all) do
            log(("  - obj=%s  ToolName=%s"):format(t.Name, tostring(toolRealName(t))))
        end
    end
    log("Tap 'List My Planks' to start.")
end
