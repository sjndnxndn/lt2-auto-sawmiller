-- ============================================================
-- GUI (built FIRST, before anything that could error)
-- ============================================================
local sg = Instance.new("ScreenGui")
sg.Name = "LT2_PlankMover"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.DisplayOrder = 999
sg.Parent = PlayerGui

-- Main window (smaller starting size)
local START_W = 340
local START_H = 380

local mainFrame = Instance.new("Frame")
mainFrame.Name = "Main"
mainFrame.Size = UDim2.new(0, START_W, 0, START_H)
mainFrame.Position = UDim2.new(0.5, -START_W/2, 0.5, -START_H/2)
mainFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Visible = true
mainFrame.Parent = sg

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 28)
titleBar.Position = UDim2.new(0, 0, 0, 0)
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

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -28, 0, 2)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 13
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.Parent = titleBar

-- Reopen button (appears when closed)
local reopenBtn = Instance.new("TextButton")
reopenBtn.Name = "ReopenBtn"
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

-- Status label
local statusLbl = Instance.new("TextLabel")
statusLbl.Name = "Status"
statusLbl.Size = UDim2.new(1, -10, 0, 26)
statusLbl.Position = UDim2.new(0, 5, 0, 32)
statusLbl.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
statusLbl.BorderSizePixel = 0
statusLbl.Text = "Ready"
statusLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
statusLbl.TextSize = 11
statusLbl.Font = Enum.Font.SourceSans
statusLbl.Parent = mainFrame

-- Button helper (scale-positioned so they fit any window size)
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
    b.AutoButtonColor = true
    b.Parent = mainFrame
    return b
end

-- Row 1: Select buttons (2 side-by-side, each ~half width)
local selSawBtn = mkBtn("1. Select Sawmill", 0.00, 62,  0.49, 30, Color3.fromRGB(60, 120, 200))
local selPlkBtn = mkBtn("2. Select Plank",   0.51, 62,  0.49, 30, Color3.fromRGB(60, 180, 100))

-- Row 2: Move / Cut
local moveBtn   = mkBtn("3. Move to Sawmill", 0.00, 96,  0.49, 30, Color3.fromRGB(200, 150, 50))
local cutBtn    = mkBtn("Cut Plank to 1x1",   0.51, 96,  0.49, 30, Color3.fromRGB(180, 80, 180))

-- Divider
local div = Instance.new("Frame")
div.Size = UDim2.new(1, -10, 0, 1)
div.Position = UDim2.new(0, 5, 0, 130)
div.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
div.BorderSizePixel = 0
div.Parent = mainFrame

-- Row 3: Auto
local autoMoveBtn = mkBtn("Auto Move: OFF", 0.00, 136, 0.49, 28, Color3.fromRGB(90, 90, 90))
local autoCutBtn  = mkBtn("Auto Cut: OFF",  0.51, 136, 0.49, 28, Color3.fromRGB(90, 90, 90))

-- Row 4: Utility (4 equal-width buttons)
local godBtn   = mkBtn("God: ON",    0.00,  168, 0.24, 26, Color3.fromRGB(60, 140, 100))
local listBtn  = mkBtn("List",       0.25,  168, 0.24, 26, Color3.fromRGB(60, 120, 200))
local copyBtn  = mkBtn("Copy",       0.50,  168, 0.24, 26, Color3.fromRGB(60, 180, 100))
local clearBtn = mkBtn("Clear",      0.75,  168, 0.24, 26, Color3.fromRGB(150, 80, 80))

-- Log box (fills remaining space)
local logBox = Instance.new("ScrollingFrame")
logBox.Name = "Log"
logBox.Size = UDim2.new(1, -10, 1, -210)
logBox.Position = UDim2.new(0, 5, 0, 200)
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

-- Plank picker (overlay, hidden by default)
local picker = Instance.new("ScrollingFrame")
picker.Name = "Picker"
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

local resizing = false
local resizeStart
local resizeStartSize
local resizeCorner

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

local function endResize()
    resizing = false
    resizeCorner = nil
end

for _, pair in ipairs({
    {hBR, "RB"}, {hTR, "RT"}, {hBL, "LB"}, {hTL, "LT"},
}) do
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

-- Close/Open wired
closeBtn.Activated:Connect(function()
    mainFrame.Visible = false
    reopenBtn.Visible = true
end)
reopenBtn.Activated:Connect(function()
    mainFrame.Visible = true
    reopenBtn.Visible = false
end)

log("UI loaded.")
log("Script starting...")
