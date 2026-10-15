-- LT2 Cut Diagnostic v2 - Mobile friendly
-- Buttons to list your planks, pick one, cut it, and log everything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local RemoteProxy = ReplicatedStorage:WaitForChild("Interaction"):WaitForChild("RemoteProxy")

-- ============================================================
--  CLIPBOARD
-- ============================================================
local setClipboard =
    (type(setclipboard) == "function" and setclipboard)
    or (type(toclipboard) == "function" and toclipboard)
    or (type(writeClipboard) == "function" and writeClipboard)
    or nil

-- ============================================================
--  GUI
-- ============================================================
local sg = Instance.new("ScreenGui")
sg.Name = "LT2_CutDiag2"
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
title.Text = "LT2 Cut Diagnostic v2"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 14
title.Font = Enum.Font.SourceSansBold
title.Parent = frame

-- Button row
local function mkBtn(text, x, w, color, parent)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, 32)
    b.Position = UDim2.new(0, x, 0, 32)
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 13
    b.Font = Enum.Font.SourceSansBold
    b.Parent = parent
    return b
end

local listBtn = mkBtn("List My Planks", 4, 130, Color3.fromRGB(60, 120, 200), frame)
local copyBtn = mkBtn("Copy Log", 138, 100, Color3.fromRGB(60, 180, 100), frame)
local clearBtn = mkBtn("Clear Log", 242, 100, Color3.fromRGB(150, 80, 80), frame)
local axeInfo = Instance.new("TextLabel")
axeInfo.Size = UDim2.new(1, -350, 0, 32)
axeInfo.Position = UDim2.new(0, 348, 0, 32)
axeInfo.BackgroundTransparency = 1
axeInfo.Text = "axe: ?"
axeInfo.TextColor3 = Color3.fromRGB(255, 200, 100)
axeInfo.TextSize = 12
axeInfo.Font = Enum.Font.Code
axeInfo.TextXAlignment = Enum.TextXAlignment.Left
axeInfo.Parent = frame

-- Log
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

-- Plank picker (overlay list)
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

--- Search the whole game for tools that could be an axe/hatchet.
local function findAllTools()
    local list = {}
    local pack = LocalPlayer:FindFirstChild("Backpack")
    if pack then
        for _, i in ipairs(pack:GetChildren()) do
            if i:IsA("Tool") then table.insert(list, i) end
        end
    end
    local char = LocalPlayer.Character
    if char then
        for _, i in ipairs(char:GetChildren()) do
            if i:IsA("Tool") then table.insert(list, i) end
        end
    end
    return list
end

local function findAxe()
    for _, item in ipairs(findAllTools()) do
        local n = item.Name:lower()
        if n:find("axe") or n:find("hatchet") or n:find("saw") or n:find("chop") then
            return item
        end
    end
    return nil
end

--- A plank is a Model that: is owned by us AND has a CutEvent child AND is NOT the plot.
local function isPlank(model)
    if not model or not model:IsA("Model") then return false end
    if not ownerMatches(model, LocalPlayer) then return false end
    return model:FindFirstChild("CutEvent") ~= nil
end

--- Find every plank we own, anywhere in the game.
local function findAllPlanks()
    local found = {}
    local seen = {}
    -- Planes: workspace.PlayerModels usually contains all player objects
    local roots = { workspace }
    local pm = workspace:FindFirstChild("PlayerModels")
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
    -- Only show interesting children
    local kids = {}
    for _, c in ipairs(model:GetChildren()) do
        if c.ClassName == "ObjectValue"
           or c.ClassName == "NumberValue"
           or c.ClassName == "StringValue"
           or c.Name == "CutEvent"
           or c.Name == "Owner" then
            table.insert(kids, c.ClassName .. ":" .. c.Name)
        end
    end
    log(("[%s] key children: %s"):format(tag, table.concat(kids, ", ")))
    local attrs = {}
    for k, v in pairs(model:GetAttributes()) do
        table.insert(attrs, k .. "=" .. tostring(v))
    end
    if #attrs > 0 then
        log(("[%s] attrs: %s"):format(tag, table.concat(attrs, ", ")))
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

    local axe = findAxe()
    if not axe then
        log("!! No axe/hatchet/saw found. Tools in backpack:")
        local tools = findAllTools()
        if #tools == 0 then
            log("   (backpack empty — equip an axe and try again)")
        else
            for _, t in ipairs(tools) do
                log("   tool: " .. t.Name)
            end
        end
        busy = false
        return
    end
    log("Using tool: " .. axe.Name)

    local cutEvent = plank:FindFirstChild("CutEvent")
    if not cutEvent then
        log("!! No CutEvent child on this model.")
        busy = false
        return
    end
    log("CutEvent class: " .. cutEvent.ClassName)

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
    log("Firing with height=1, faceVector=(1,0,0)...")

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
--  BUTTON WIRING
-- ============================================================
local function runListPlanks()
    -- Clear picker
    for _, c in ipairs(picker:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end

    local planks = findAllPlanks()
    log(("Found %d plank(s) you own."):format(#planks))

    if #planks == 0 then
        log("No planks with a CutEvent found. Make sure you own one.")
        picker.Visible = false
        return
    end

    for i, p in ipairs(planks) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -6, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        btn.BorderSizePixel = 0
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 12
        btn.Font = Enum.Font.Code
        btn.TextXAlignment = Enum.TextXAlignment.Left
        local ok, _, size = pcall(function() return p:GetBoundingBox() end)
        local sizeStr = ok and fmtVec(size) or "?"
        btn.Text = ("  #%d %s  size=%s"):format(i, p.Name, sizeStr)
        btn.Parent = picker
        btn.MouseButton1Click:Connect(function()
            picker.Visible = false
            log("Picked plank #" .. i .. " (" .. p.Name .. ")")
            runCutTest(p)
        end)
        btn.TouchTap:Connect(function()
            picker.Visible = false
            log("Picked plank #" .. i .. " (" .. p.Name .. ")")
            runCutTest(p)
        end)
    end

    picker.Visible = true
end

local function doCopy()
    if not setClipboard then
        log("!! No clipboard function available.")
        return
    end
    local ok, err = pcall(function() setClipboard(table.concat(logBuffer, "\n")) end)
    if ok then log(">> Copied " .. #logBuffer .. " lines to clipboard.")
    else log("!! Copy failed: " .. tostring(err)) end
end

listBtn.MouseButton1Click:Connect(runListPlanks)
listBtn.TouchTap:Connect(runListPlanks)
copyBtn.MouseButton1Click:Connect(doCopy)
copyBtn.TouchTap:Connect(doCopy)
clearBtn.MouseButton1Click:Connect(function()
    logBuffer = {}
    for _, c in ipairs(logBox:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
end)
clearBtn.TouchTap:Connect(function()
    logBuffer = {}
    for _, c in ipairs(logBox:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
end)

-- ============================================================
--  STARTUP
-- ============================================================
do
    local tools = findAllTools()
    local axe = findAxe()
    if axe then
        axeInfo.Text = "axe: " .. axe.Name
    elseif #tools == 0 then
        axeInfo.Text = "axe: NONE (equip one!)"
    else
        axeInfo.Text = "axe: " .. #tools .. " tools, none match"
    end
    log("Ready.")
    log("1) Equip or hold an axe so it's in your Backpack.")
    log("2) Tap 'List My Planks'.")
    log("3) Pick a plank from the list.")
end
