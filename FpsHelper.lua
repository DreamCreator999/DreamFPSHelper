local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Assets & Configuration
local ICON_ID = "rbxassetid://114662130912025"
local SETTINGS_ICON = "rbxassetid://78494414238159"
local FLY_SPEED = 60

-- Global States
local isFollowing, isCamLocked, isHeadshotOnly = false, false, true
local isEspEnabled, isSkeletonEnabled = true, true
local isFlying, isNoclipping = false, false
local fovRadius, espRange = 150, 1000
local targetPlayer = nil

local ESP_DATA = {}
local connections = {}

-- ==========================================
-- 1. UTILITIES & DRAG SYSTEM
-- ==========================================
local function isEnemy(p)
    if not p or p == LocalPlayer then return false end
    if LocalPlayer.Team and p.Team then return LocalPlayer.Team ~= p.Team end
    return true
end

local function makeDraggable(frame, callback)
    local dragging, dragStart, startPos, hasMoved
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging, hasMoved, dragStart, startPos = true, false, input.Position, frame.Position
            local moveConn
            moveConn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    moveConn:Disconnect()
                    if not hasMoved and callback then callback() end
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            if delta.Magnitude > 5 then hasMoved = true end
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- ==========================================
-- 2. GUI CONSTRUCTION
-- ==========================================
local screenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
screenGui.Name = "DreamMaster_V27"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999999

local minBtn = Instance.new("ImageButton", screenGui)
minBtn.Size, minBtn.Image, minBtn.Visible = UDim2.new(0, 80, 0, 80), ICON_ID, false
minBtn.BackgroundColor3 = Color3.fromRGB(15,15,15)
Instance.new("UICorner", minBtn)

local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size, mainFrame.Position = UDim2.new(0, 260, 0, 400), UDim2.new(0.5, -130, 0.4, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
Instance.new("UICorner", mainFrame)

local function toggleUI()
    if mainFrame.Visible then
        minBtn.Position = mainFrame.Position + UDim2.new(0, 90, 0, 160)
        mainFrame.Visible = false minBtn.Visible = true
    else
        mainFrame.Position = minBtn.Position - UDim2.new(0, 90, 0, 160)
        minBtn.Visible = false mainFrame.Visible = true
    end
end
makeDraggable(mainFrame)
makeDraggable(minBtn, toggleUI)

local menuCon = Instance.new("Frame", mainFrame)
menuCon.Size, menuCon.Position, menuCon.BackgroundTransparency = UDim2.new(1,0,1,-60), UDim2.new(0,0,0,60), 1

local setCon = Instance.new("ScrollingFrame", mainFrame)
setCon.Size, setCon.Position = UDim2.new(1,0,1,-60), UDim2.new(0,0,0,60)
setCon.BackgroundTransparency, setCon.Visible, setCon.ScrollBarThickness = 1, false, 2
setCon.CanvasSize = UDim2.new(0,0,2.2,0)

-- Header
local hideBtn = Instance.new("TextButton", mainFrame)
hideBtn.Size, hideBtn.Position, hideBtn.Text = UDim2.new(0,30,0,30), UDim2.new(1,-35,0,5), "_"
hideBtn.BackgroundColor3, hideBtn.TextColor3 = Color3.fromRGB(25,25,25), Color3.new(1,1,1)
Instance.new("UICorner", hideBtn).CornerRadius = UDim.new(0, 8)
hideBtn.MouseButton1Click:Connect(toggleUI)

local setToggle = Instance.new("ImageButton", mainFrame)
setToggle.Size, setToggle.Position, setToggle.Image = UDim2.new(0,25,0,25), UDim2.new(1,-65,0,7), SETTINGS_ICON
setToggle.BackgroundTransparency = 1
setToggle.MouseButton1Click:Connect(function() menuCon.Visible = not menuCon.Visible setCon.Visible = not setCon.Visible end)

local function createBtn(text, pos, color, parent)
    local btn = Instance.new("TextButton", parent)
    btn.Size, btn.Position, btn.BackgroundColor3 = UDim2.new(0.9, 0, 0, 35), pos, color
    btn.Text, btn.TextColor3, btn.Font = text, Color3.new(1,1,1), "GothamMedium"
    Instance.new("UICorner", btn)
    return btn
end

-- Main Buttons
local status = createBtn("Target: Scanning...", UDim2.new(0.05,0,0,5), Color3.fromRGB(20,20,20), menuCon)
local headBtn = createBtn("Aim Part: HEAD", UDim2.new(0.05,0,0,45), Color3.fromRGB(80,30,120), menuCon)
local followBtn = createBtn("Follow: OFF [K]", UDim2.new(0.05,0,0,90), Color3.fromRGB(40,40,40), menuCon)
local lockBtn = createBtn("Cam Lock: OFF [L]", UDim2.new(0.05,0,0,135), Color3.fromRGB(40,40,40), menuCon)
local flyBtn = createBtn("Fly Mode: OFF [X]", UDim2.new(0.05,0,0,180), Color3.fromRGB(40,40,40), menuCon)
local killBtn = createBtn("KILL ALL [DEL]", UDim2.new(0.05,0,0,280), Color3.fromRGB(80,20,20), menuCon)

-- Settings Labels & Buttons
local fovLbl = Instance.new("TextLabel", setCon) fovLbl.Size, fovLbl.Position, fovLbl.TextColor3, fovLbl.BackgroundTransparency = UDim2.new(1,0,0,25), UDim2.new(0,0,0,10), Color3.new(1,1,1), 1
local fovPlus = createBtn("FOV Radius +", UDim2.new(0.05,0,0,40), Color3.fromRGB(45,45,45), setCon)
local fovMinus = createBtn("FOV Radius -", UDim2.new(0.05,0,0,80), Color3.fromRGB(45,45,45), setCon)

local rangeLbl = Instance.new("TextLabel", setCon) rangeLbl.Size, rangeLbl.Position, rangeLbl.TextColor3, rangeLbl.BackgroundTransparency = UDim2.new(1,0,0,25), UDim2.new(0,0,0,130), Color3.new(1,1,1), 1
local rangePlus = createBtn("ESP Range +", UDim2.new(0.05,0,0,160), Color3.fromRGB(45,45,45), setCon)
local rangeMinus = createBtn("ESP Range -", UDim2.new(0.05,0,0,200), Color3.fromRGB(45,45,45), setCon)

local ghostLbl = Instance.new("TextLabel", setCon) ghostLbl.Size, ghostLbl.Position, ghostLbl.Text, ghostLbl.TextColor3, ghostLbl.BackgroundTransparency = UDim2.new(1,0,0,25), UDim2.new(0,0,0,250), "GHOST OPTIONS", Color3.new(1,1,1), 1
local noclipBtn = createBtn("Noclip: OFF [N]", UDim2.new(0.05,0,0,280), Color3.fromRGB(45,45,45), setCon)
local backBtn = createBtn("BACK TO MENU", UDim2.new(0.05,0,0,330), Color3.fromRGB(30,30,30), setCon)
backBtn.MouseButton1Click:Connect(function() menuCon.Visible = true setCon.Visible = false end)

-- ==========================================
-- 3. CORE ENGINES (FLY, LOCK, TARGET)
-- ==========================================
local fovCircle = Drawing.new("Circle")
fovCircle.Visible, fovCircle.Thickness, fovCircle.Color = true, 2, Color3.fromRGB(0,255,200)

connections.Loops = RunService.Heartbeat:Connect(function(dt)
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    fovCircle.Radius = fovRadius

    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local hrp = char.HumanoidRootPart

    -- Targeting Logic
    local closest, dist = nil, math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if isEnemy(p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local tHrp = p.Character.HumanoidRootPart
            local sPos, onScr = Camera:WorldToViewportPoint(tHrp.Position)
            if onScr and (Vector2.new(sPos.X, sPos.Y) - fovCircle.Position).Magnitude <= fovRadius then
                local d = (hrp.Position - tHrp.Position).Magnitude
                if d < dist then dist = d closest = p end
            end
        end
    end
    targetPlayer = closest

    -- Fly & Noclip
    if isNoclipping then
        for _, v in pairs(char:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide = false end end
    end
    if isFlying then
        local move = Vector3.new(0,0,0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.new(0,1,0) end
        hrp.Velocity = move * FLY_SPEED
        hrp.Anchored = (move == Vector3.new(0,0,0))
    else hrp.Anchored = false end

    -- Follow
    if isFollowing and targetPlayer and targetPlayer.Character then
        char:PivotTo(targetPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, HEIGHT_ABOVE, 0))
    end
end)

connections.Render = RunService.RenderStepped:Connect(function()
    if isCamLocked and targetPlayer and targetPlayer.Character then
        local aim = isHeadshotOnly and targetPlayer.Character:FindFirstChild("Head") or targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if aim then Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, aim.Position) end
    end
    -- UI Refresh
    status.Text = "TARGET: " .. (targetPlayer and targetPlayer.Name:upper() or "SEARCHING...")
    fovLbl.Text = "FOV RADIUS: " .. fovRadius
    rangeLbl.Text = "ESP RANGE: " .. espRange
    followBtn.BackgroundColor3 = isFollowing and Color3.fromRGB(50,150,50) or Color3.fromRGB(150,40,40)
    lockBtn.BackgroundColor3 = isCamLocked and Color3.fromRGB(50,200,200) or Color3.fromRGB(40,80,150)
    flyBtn.BackgroundColor3 = isFlying and Color3.fromRGB(50,150,50) or Color3.fromRGB(150,40,40)
    noclipBtn.BackgroundColor3 = isNoclipping and Color3.fromRGB(50,150,50) or Color3.fromRGB(150,40,40)
end)

-- ==========================================
-- 4. INPUTS & ESP
-- ==========================================
local function kill() for _,c in pairs(connections) do c:Disconnect() end screenGui:Destroy() fovCircle:Remove() end
killBtn.MouseButton1Click:Connect(kill)
headBtn.MouseButton1Click:Connect(function() isHeadshotOnly = not isHeadshotOnly headBtn.Text = "Aim Part: "..(isHeadshotOnly and "HEAD" or "BODY") end)
fovPlus.MouseButton1Click:Connect(function() fovRadius += 25 end)
fovMinus.MouseButton1Click:Connect(function() fovRadius = math.max(25, fovRadius - 25) end)
rangePlus.MouseButton1Click:Connect(function() espRange += 250 end)
rangeMinus.MouseButton1Click:Connect(function() espRange = math.max(250, espRange - 250) end)

UserInputService.InputBegan:Connect(function(i, g)
    if g then return end
    if i.KeyCode == Enum.KeyCode.Delete then kill()
    elseif i.KeyCode == Enum.KeyCode.K then isFollowing = not isFollowing
    elseif i.KeyCode == Enum.KeyCode.L then isCamLocked = not isCamLocked
    elseif i.KeyCode == Enum.KeyCode.X then isFlying = not isFlying
    elseif i.KeyCode == Enum.KeyCode.N then isNoclipping = not isNoclipping
    elseif i.KeyCode == Enum.KeyCode.H then isEspEnabled = not isEspEnabled
    end
end)

local function setupESP(p)
    p.CharacterAdded:Connect(function(char)
        if not isEnemy(p) then return end
        local hl, bill = Instance.new("Highlight", char), Instance.new("BillboardGui", char:WaitForChild("Head", 5))
        bill.AlwaysOnTop, bill.Size = true, UDim2.new(0,120,0,45)
        local lbl = Instance.new("TextLabel", bill)
        lbl.Size, lbl.BackgroundTransparency, lbl.TextColor3, lbl.Font = UDim2.new(1,0,1,0), 1, Color3.new(1,1,1), "GothamBold"
        connections["ESP"..p.UserId] = RunService.RenderStepped:Connect(function()
            if not char or not char.Parent then connections["ESP"..p.UserId]:Disconnect() return end
            local d = (LocalPlayer.Character.HumanoidRootPart.Position - char.HumanoidRootPart.Position).Magnitude
            hl.Enabled = isEspEnabled and d <= espRange
            bill.Enabled = isEspEnabled and d <= espRange
            lbl.Text = p.Name .. "\n" .. math.floor(d) .. "m"
        end)
    end)
end
for _, p in pairs(Players:GetPlayers()) do setupESP(p) end
Players.PlayerAdded:Connect(setupESP)
