-- LT2 Cut Diagnostic (with Copy Log) - Mobile + PC compatible
-- Taps/clicks a plank, fires ONE cut, logs everything, and can copy the log.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local RemoteProxy = ReplicatedStorage:WaitForChild("Interaction"):WaitForChild("RemoteProxy")

-- ============================================================
--  CLIPBOARD HELPER
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
sg.Name = "LT2_CutDiag"
sg.ResetOnSpawn = false
sg.Parent = LocalPlayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 460, 0, 320)
frame.Position = UDim2.new(0.5, -230, 0.5, -160)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = sg

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -200, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
title.BorderSizePixel = 0
title.Text = "Cut Diag - tap a plank"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 14
title.Font = Enum.Font.SourceSansBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local copyBtn = Instance.new("TextButton")
copyBtn.Size = UDim2.new(0, 95, 0, 30)
copyBtn.Position = UDim2.new(1, -100, 0, 0)
copyBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
copyBtn.BorderSizePixel = 0
copyBtn.Text = "Copy Log"
copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
copyBtn.TextSize = 13
copyBtn.Font = Enum.Font.SourceSansBold
copyBtn.Parent = frame

local logBox = Instance.new("ScrollingFrame")
logBox.Size = UDim2.new(1, -10, 1, -40)
logBox.Position = UDim2.new(0, 5, 0, 35)
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

copyBtn.MouseButton1Click:Connect(function()
    if not setClipboard then
        log("!! No clipboard function available in this executor.")
        return
    end
    local text = table.concat(logBuffer, "\n")
    local ok, err = pcall(function() setClipboard(text) end)
    if ok then
        log(">> Copied " .. #logBuffer .. " lines to clipboard.")
    else
        log("!! Copy failed: " .. tostring(err))
    end
end)
-- Also support touch taps on the copy button
copyBtn.TouchTap:Connect(function()
    if not setClipboard then
        log("!! No clipboard function available in this executor.")
        return
    end
    local text = table.concat(logBuffer, "\n")
    local ok, err = pcall(function() setClipboard(text) end)
    if ok then
        log(">> Copied " .. #logBuffer .. " lines to clipboard.")
    else
        log("!! Copy failed: " .. tostring(err))
    end
end)

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
    return string.format("(%.3f, %.3f, %.3f)", v.X, v.Y, v.Z)
end

local function findAxe()
    local pack = LocalPlayer:FindFirstChild("Backpack")
    if pack then
        for _, item in ipairs(pack:GetChildren()) do
            if item:IsA("Tool") and item.Name:lower():find("axe") then
                return item
            end
        end
    end
    local char = LocalPlayer.Character
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") and item.Name:lower():find("axe") then
                return item
            end
        end
    end
    return nil
end

local function snapshot(model, tag)
    local ok, cf, size = pcall(function() return model:GetBoundingBox() end)
    log(("[%s] name=%s"):format(tag, model.Name))
    if ok then
        log(("[%s] size=%s"):format(tag, fmtVec(size)))
    end
    log(("[%s] pivot=%s"):format(tag, fmtVec(model:GetPivot().Position)))
    local kids = {}
    for _, c in ipairs(model:GetChildren()) do
        table.insert(kids, c.ClassName .. ":" .. c.Name)
    end
    log(("[%s] children: %s"):format(tag, table.concat(kids, ", ")))
    local attrs = {}
    for k, v in pairs(model:GetAttributes()) do
        table.insert(attrs, k .. "=" .. tostring(v))
    end
    if #attrs > 0 then
        log(("[%s] attrs: %s"):format(tag, table.concat(attrs, ", ")))
    end
end

-- ============================================================
--  RAYCAST FROM SCREEN POSITION (works for mouse AND touch)
-- ============================================================
local function raycastFromScreen(pos)
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local ray = cam:ViewportPointToRay(pos.X, pos.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { sg, LocalPlayer.Character }
    local result = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
    if result then return result.Instance end
    return nil
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
        log("!! No axe found in backpack or character.")
        busy = false
        return
    end
    log("Using axe: " .. axe.Name)

    local cutEvent = plank:FindFirstChild("CutEvent")
    if not cutEvent then
        log("!! Plank has no 'CutEvent' child. See children above ^")
        busy = false
        return
    end
    log("CutEvent class: " .. cutEvent.ClassName .. " name: " .. cutEvent.Name)

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
                    log("[NEW] " .. c.ClassName .. " : " .. c.Name)
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
    log("Firing RemoteProxy with payload:")
    log(("   height       = %s"):format(tostring(payload.height)))
    log(("   faceVector   = %s"):format(fmtVec(payload.faceVector)))
    log(("   cooldown     = %s"):format(tostring(payload.cooldown)))
    log(("   sectionId    = %s"):format(tostring(payload.sectionId)))
    log(("   hitPoints    = %s"):format(tostring(payload.hitPoints)))
    log(("   tool         = %s"):format(tostring(payload.tool)))
    log(("   cuttingClass = %s"):format(tostring(payload.cuttingClass)))

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
        if plank:IsDescendantOf(workspace) then
            log("Original plank still in workspace.")
        elseif plank:IsDescendantOf(LocalPlayer.Character) then
            log("Original plank moved to character.")
        else
            log("Original plank now parented to: " .. plank.Parent:GetFullName())
        end
    else
        log("Original plank was DESTROYED.")
    end

    watching = false
    log("========== TEST DONE =========")
    busy = false
end

-- ============================================================
--  INPUT HANDLER (mouse + touch, on both mouse and touch devices)
-- ============================================================
local function handleTap(screenPos, gameProcessed)
    if gameProcessed then return end

    -- Ignore taps inside our own GUI
    local guiObjects = LocalPlayer.PlayerGui:GetGuiObjectsAtPosition(screenPos.X, screenPos.Y)
    for _, obj in ipairs(guiObjects) do
        if obj:IsDescendantOf(sg) then return end
    end

    local hit = raycastFromScreen(screenPos)
    if not hit then
        log("Raycast hit nothing.")
        return
    end
    local model = hit:FindFirstAncestorOfClass("Model")
    if not model then
        log("Hit " .. hit.Name .. " - no model ancestor.")
        return
    end

    if not ownerMatches(model, LocalPlayer) then
        log("Tapped " .. model.Name .. " - not yours.")
        return
    end

    log("Tapped plank: " .. model.Name)
    runCutTest(model)
end

UserInputService.InputBegan:Connect(function(input, gp)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        handleTap(input.Position, gp)
    elseif input.UserInputType == Enum.UserInputType.Touch then
        handleTap(input.Position, gp)
    end
end)

log("Ready. Tap one of your planks to test a single cut.")
log("Use 'Copy Log' to copy everything above to clipboard.")
