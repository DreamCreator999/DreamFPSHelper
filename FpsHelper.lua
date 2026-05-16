--[[
    DREAM TACTICAL: RAW AIM EDITION
    Focus: Absolute Raw Camera Snapping, No Interpolation, Zero Delay.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- ==========================================
-- 1. CONFIGURATION & STATE MANAGEMENT
-- ==========================================
local Config = {
    Icon = "rbxassetid://114662130912025",
    SettingsIcon = "rbxassetid://78494414238159",
    Theme = {
        Main = Color3.fromRGB(12, 12, 14),
        Accent = Color3.fromRGB(0, 255, 200),
        Button = Color3.fromRGB(25, 25, 28),
        ButtonHover = Color3.fromRGB(45, 45, 50),
        Active = Color3.fromRGB(50, 150, 100),
        Danger = Color3.fromRGB(150, 40, 40)
    }
}

local States = {
    isFollowing = false,
    isCamLocked = false,
    isHeadshotOnly = true,
    isEspEnabled = true,
    isFlying = false,
    isNoclipping = false,
    isSpeedHack = false,
    
    fovRadius = 150,
    espRange = 1000,
    flySpeed = 65,
    walkSpeedMod = 100
}

local targetPlayer = nil
local connections = {}

-- ==========================================
-- 2. ENGINE UTILITIES
-- ==========================================
local function getRoot(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
end

local function isEnemy(plr)
    if not plr or plr == LocalPlayer then return false end
    local char = plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 or not getRoot(char) then return false end
    
    if LocalPlayer.Team and plr.Team then
        if LocalPlayer.Team == plr.Team or LocalPlayer.TeamColor == plr.TeamColor then
            return false 
        end
    end
    return true
end

local function getHealthColor(hpPercent)
    return Color3.new(1 - hpPercent, hpPercent, 0)
end

-- ==========================================
-- 3. INTERFACE FRAMEWORK
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DreamRawAim"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999999999
pcall(function() screenGui.Parent = CoreGui end)
if not screenGui.Parent then screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local minBtn = Instance.new("ImageButton", screenGui)
minBtn.Size, minBtn.Visible = UDim2.new(0, 80, 0, 80), false
minBtn.Position = UDim2.new(0.5, -40, 0.4, 0)
minBtn.BackgroundColor3, minBtn.Image = Config.Theme.Main, Config.Icon
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0.5, 0)
local pulse = TweenService:Create(minBtn, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Size = UDim2.new(0, 85, 0, 85), ImageTransparency = 0.4})
pulse:Play()

local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size, mainFrame.Position = UDim2.new(0, 260, 0, 440), UDim2.new(0.5, -130, 0.3, 0)
mainFrame.BackgroundColor3 = Config.Theme.Main
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)
local mainStroke = Instance.new("UIStroke", mainFrame)
mainStroke.Color, mainStroke.Thickness = Config.Theme.ButtonHover, 2

local function makeDraggable(frame)
    local dragging, dragInput, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end
makeDraggable(mainFrame)
makeDraggable(minBtn)

local function toggleUI()
    if mainFrame.Visible then
        minBtn.Position = mainFrame.Position + UDim2.new(0, 90, 0, 180)
        mainFrame.Visible, minBtn.Visible = false, true
    else
        mainFrame.Position = minBtn.Position - UDim2.new(0, 90, 0, 180)
        mainFrame.Visible, minBtn.Visible = true, false
    end
end
minBtn.MouseButton1Click:Connect(toggleUI)

local function createInteractiveBtn(text, pos, parent)
    local btn = Instance.new("TextButton", parent)
    btn.Size, btn.Position = UDim2.new(0.9, 0, 0, 35), pos
    btn.BackgroundColor3, btn.AutoButtonColor = Config.Theme.Button, false
    btn.Text, btn.TextColor3, btn.Font, btn.TextSize = text, Color3.new(1,1,1), "GothamBold", 12
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Config.Theme.ButtonHover}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = btn:GetAttribute("ActiveColor") or Config.Theme.Button}):Play() end)
    return btn
end

local menuCon = Instance.new("Frame", mainFrame)
menuCon.Size, menuCon.Position, menuCon.BackgroundTransparency = UDim2.new(1,0,1,-60), UDim2.new(0,0,0,60), 1
local setCon = Instance.new("ScrollingFrame", mainFrame)
setCon.Size, setCon.Position, setCon.Visible = UDim2.new(1,0,1,-60), UDim2.new(0,0,0,60), false
setCon.BackgroundTransparency, setCon.ScrollBarThickness = 1, 0
setCon.CanvasSize = UDim2.new(0,0,2.5,0)

local title = Instance.new("TextLabel", mainFrame)
title.Size, title.Position, title.Text = UDim2.new(1,-70,0,40), UDim2.new(0,15,0,10), "RAW AIM"
title.Font, title.TextColor3, title.TextSize, title.BackgroundTransparency, title.TextXAlignment = "GothamBlack", Config.Theme.Accent, 16, 1, Enum.TextXAlignment.Left

local hideBtn = Instance.new("TextButton", mainFrame)
hideBtn.Size, hideBtn.Position, hideBtn.Text = UDim2.new(0,30,0,30), UDim2.new(1,-40,0,10), "_"
hideBtn.BackgroundColor3, hideBtn.TextColor3, hideBtn.Font = Config.Theme.Button, Color3.new(1,1,1), "GothamBold"
Instance.new("UICorner", hideBtn)
hideBtn.MouseButton1Click:Connect(toggleUI)

local setToggle = Instance.new("ImageButton", mainFrame)
setToggle.Size, setToggle.Position, setToggle.Image, setToggle.BackgroundTransparency = UDim2.new(0,25,0,25), UDim2.new(1,-75,0,12), Config.SettingsIcon, 1
setToggle.MouseButton1Click:Connect(function() menuCon.Visible = not menuCon.Visible setCon.Visible = not setCon.Visible end)

-- Menu Elements
local statusBtn = createInteractiveBtn("SYSTEM: STANDBY", UDim2.new(0.05,0,0,5), menuCon)
local headBtn = createInteractiveBtn("Aim Focus: HEAD", UDim2.new(0.05,0,0,45), menuCon)
local lockBtn = createInteractiveBtn("Raw Lock: OFF [L]", UDim2.new(0.05,0,0,90), menuCon)
local followBtn = createInteractiveBtn("Follow: OFF [K]", UDim2.new(0.05,0,0,135), menuCon)
local flyBtn = createInteractiveBtn("Fly Mode: OFF [X]", UDim2.new(0.05,0,0,180), menuCon)
local speedBtn = createInteractiveBtn("Speed Hack: OFF [B]", UDim2.new(0.05,0,0,225), menuCon)
local killBtn = createInteractiveBtn("PURGE SYSTEM [DEL]", UDim2.new(0.05,0,0,320), menuCon)
killBtn:SetAttribute("ActiveColor", Config.Theme.Danger) killBtn.BackgroundColor3 = Config.Theme.Danger

-- Settings Elements
local function createLabel(text, pos, parent)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size, lbl.Position, lbl.TextColor3, lbl.BackgroundTransparency, lbl.Font = UDim2.new(1,0,0,30), pos, Color3.new(1,1,1), 1, "GothamBold"
    lbl.Text = text
    return lbl
end

local fovLbl = createLabel("FOV RADIUS: " .. States.fovRadius, UDim2.new(0,0,0,5), setCon)
local fovAdd = createInteractiveBtn("FOV +", UDim2.new(0.05,0,0,40), setCon)
local fovSub = createInteractiveBtn("FOV -", UDim2.new(0.05,0,0,80), setCon)

local rangeLbl = createLabel("ESP RANGE: " .. States.espRange, UDim2.new(0,0,0,125), setCon)
local rangeAdd = createInteractiveBtn("Range +", UDim2.new(0.05,0,0,160), setCon)
local rangeSub = createInteractiveBtn("Range -", UDim2.new(0.05,0,0,200), setCon)

local flyLbl = createLabel("FLY SPEED: " .. States.flySpeed, UDim2.new(0,0,0,245), setCon)
local flyAdd = createInteractiveBtn("Fly Speed +", UDim2.new(0.05,0,0,280), setCon)
local flySub = createInteractiveBtn("Fly Speed -", UDim2.new(0.05,0,0,320), setCon)

local backBtn = createInteractiveBtn("RETURN TO MENU", UDim2.new(0.05,0,0,380), setCon)
backBtn.MouseButton1Click:Connect(function() menuCon.Visible = true setCon.Visible = false end)

local function updateUI()
    statusBtn.Text = targetPlayer and "LOCKED: "..targetPlayer.Name:upper() or "SYSTEM: SCANNING"
    statusBtn.TextColor3 = targetPlayer and Config.Theme.Accent or Color3.new(1,1,1)
    
    fovLbl.Text, rangeLbl.Text, flyLbl.Text = "FOV RADIUS: "..States.fovRadius, "ESP RANGE: "..States.espRange, "FLY SPEED: "..States.flySpeed
    headBtn.Text = "Aim Focus: "..(States.isHeadshotOnly and "HEAD" or "BODY")
    
    local function setBtnState(btn, state, text)
        btn.Text = text
        local color = state and Config.Theme.Active or Config.Theme.Button
        btn:SetAttribute("ActiveColor", color)
        TweenService:Create(btn, TweenInfo.new(0.3), {BackgroundColor3 = color}):Play()
    end
    
    setBtnState(followBtn, States.isFollowing, "Follow: "..(States.isFollowing and "ON" or "OFF").." [K]")
    setBtnState(lockBtn, States.isCamLocked, "Raw Lock: "..(States.isCamLocked and "ON" or "OFF").." [L]")
    setBtnState(flyBtn, States.isFlying, "Fly Mode: "..(States.isFlying and "ON" or "OFF").." [X]")
    setBtnState(speedBtn, States.isSpeedHack, "Speed Hack: "..(States.isSpeedHack and "ON" or "OFF").." [B]")
end

-- ==========================================
-- 4. RENDER LOOP & PHYSICS
-- ==========================================
local fovCircle
pcall(function()
    fovCircle = Drawing.new("Circle")
    fovCircle.Visible = true
    fovCircle.Thickness = 1.5
    fovCircle.Color = Config.Theme.Accent
end)

table.insert(connections, RunService.Heartbeat:Connect(function()
    if fovCircle then
        fovCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
        fovCircle.Radius = States.fovRadius
    end
    
    local char = LocalPlayer.Character
    local hrp = getRoot(char)
    if not hrp then return end

    if char:FindFirstChildOfClass("Humanoid") then
        char:FindFirstChildOfClass("Humanoid").WalkSpeed = States.isSpeedHack and States.walkSpeedMod or 16
    end

    -- TARGETING LOGIC
    if States.isCamLocked then
        if not isEnemy(targetPlayer) then
            States.isCamLocked = false
            targetPlayer = nil
            updateUI()
        end
    else
        local closest, minFov = nil, States.fovRadius
        for _, plr in pairs(Players:GetPlayers()) do
            if isEnemy(plr) then
                local tRoot = getRoot(plr.Character)
                local sPos, onScr = Camera:WorldToViewportPoint(tRoot.Position)
                if onScr then
                    local fDist = (Vector2.new(sPos.X, sPos.Y) - (fovCircle and fovCircle.Position or Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2))).Magnitude
                    if fDist < minFov then
                        minFov = fDist
                        closest = plr
                    end
                end
            end
        end
        if targetPlayer ~= closest then
            targetPlayer = closest
            updateUI()
        end
    end

    -- Fly Physics
    if States.isNoclipping then
        for _, v in pairs(char:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide = false end end
    end
    
    if States.isFlying then
        local move = Vector3.new(0,0,0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.new(0,1,0) end
        
        local targetVelocity = move * States.flySpeed
        hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity:Lerp(targetVelocity, 0.5) 
        hrp.Anchored = (move.Magnitude == 0 and hrp.AssemblyLinearVelocity.Magnitude < 1)
    else 
        hrp.Anchored = false 
    end

    if States.isFollowing and targetPlayer and targetPlayer.Character then
        char:PivotTo(getRoot(targetPlayer.Character).CFrame * CFrame.new(0, 8, 0))
    end
end))

-- RAW CAMERA SNAP
table.insert(connections, RunService.RenderStepped:Connect(function()
    if States.isCamLocked and targetPlayer and targetPlayer.Character then
        local aimPart = States.isHeadshotOnly and targetPlayer.Character:FindFirstChild("Head") or getRoot(targetPlayer.Character)
        if aimPart then
            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, aimPart.Position)
        end
    end
end))

-- ==========================================
-- 5. DYNAMIC ESP MANAGER
-- ==========================================
local function createESP(p)
    p.CharacterAdded:Connect(function(char)
        if p == LocalPlayer then return end
        local head = char:WaitForChild("Head", 5)
        local hum = char:WaitForChild("Humanoid", 5)
        
        local hl = Instance.new("Highlight", char)
        hl.OutlineTransparency, hl.FillTransparency = 0.2, 0.6
        
        local bill = Instance.new("BillboardGui", head)
        bill.AlwaysOnTop, bill.Size, bill.ExtentsOffset = true, UDim2.new(0, 150, 0, 50), Vector3.new(0, 3, 0)
        
        local lbl = Instance.new("TextLabel", bill)
        lbl.Size, lbl.BackgroundTransparency, lbl.TextColor3, lbl.Font, lbl.TextSize = UDim2.new(1,0,0,30), 1, Color3.new(1,1,1), "GothamBold", 13
        
        local barBG = Instance.new("Frame", bill)
        barBG.Size, barBG.Position, barBG.BackgroundColor3, barBG.BorderSizePixel = UDim2.new(0.8, 0, 0, 4), UDim2.new(0.1, 0, 0, 32), Color3.new(0,0,0), 0
        local barFill = Instance.new("Frame", barBG)
        barFill.Size, barFill.BorderSizePixel = UDim2.new(1, 0, 1, 0), 0
        
        local espConn
        espConn = RunService.RenderStepped:Connect(function()
            if not char or not char.Parent or not isEnemy(p) or not States.isEspEnabled then
                hl.Enabled, bill.Enabled = false, false 
                if hum and hum.Health <= 0 then espConn:Disconnect() end
                return 
            end
            
            local myRoot = getRoot(LocalPlayer.Character)
            local tRoot = getRoot(char)
            if not myRoot or not tRoot then return end
            
            local dist = (myRoot.Position - tRoot.Position).Magnitude
            if dist <= States.espRange then
                hl.Enabled, bill.Enabled = true, true
                local hp = hum.Health / hum.MaxHealth
                local col = getHealthColor(hp)
                
                lbl.Text = string.format("%s\n[%dm]", p.Name, math.floor(dist))
                lbl.TextColor3 = col
                barFill.Size, barFill.BackgroundColor3 = UDim2.new(hp, 0, 1, 0), col
                hl.FillColor = col
                hl.OutlineColor = (States.isCamLocked and targetPlayer == p) and Config.Theme.Accent or Color3.new(1,1,1)
            else 
                hl.Enabled, bill.Enabled = false, false 
            end
        end)
        table.insert(connections, espConn)
    end)
end

-- ==========================================
-- 6. EVENT LISTENERS & PURGE
-- ==========================================
local function killScript()
    for _, c in pairs(connections) do pcall(function() c:Disconnect() end) end
    pcall(function() screenGui:Destroy() end)
    pcall(function() if fovCircle then fovCircle:Remove() end end)
    if LocalPlayer.Character then 
        local h = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = 16 end
    end
end

UserInputService.InputBegan:Connect(function(i, g)
    if i.UserInputType == Enum.UserInputType.MouseButton1 and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        pcall(function() LocalPlayer.Character:PivotTo(CFrame.new(Mouse.Hit.Position + Vector3.new(0,3,0))) end)
    end
    if g then return end
    
    local updated = false
    if i.KeyCode == Enum.KeyCode.Delete then killScript() return
    elseif i.KeyCode == Enum.KeyCode.K then States.isFollowing = not States.isFollowing; updated = true
    elseif i.KeyCode == Enum.KeyCode.L then 
        if States.isCamLocked then
            States.isCamLocked = false
            targetPlayer = nil
        else
            if targetPlayer then States.isCamLocked = true end
        end
        updated = true
    elseif i.KeyCode == Enum.KeyCode.X then States.isFlying = not States.isFlying; updated = true
    elseif i.KeyCode == Enum.KeyCode.B then States.isSpeedHack = not States.isSpeedHack; updated = true
    elseif i.KeyCode == Enum.KeyCode.N then States.isNoclipping = not States.isNoclipping; updated = true
    elseif i.KeyCode == Enum.KeyCode.H then States.isEspEnabled = not States.isEspEnabled; updated = true
    end
    
    if updated then updateUI() end
end)

headBtn.MouseButton1Click:Connect(function() States.isHeadshotOnly = not States.isHeadshotOnly updateUI() end)
followBtn.MouseButton1Click:Connect(function() States.isFollowing = not States.isFollowing updateUI() end)
lockBtn.MouseButton1Click:Connect(function() 
    if States.isCamLocked then
        States.isCamLocked = false
        targetPlayer = nil
    else
        if targetPlayer then States.isCamLocked = true end
    end
    updateUI() 
end)
flyBtn.MouseButton1Click:Connect(function() States.isFlying = not States.isFlying updateUI() end)
speedBtn.MouseButton1Click:Connect(function() States.isSpeedHack = not States.isSpeedHack updateUI() end)

fovAdd.MouseButton1Click:Connect(function() States.fovRadius += 25 updateUI() end)
fovSub.MouseButton1Click:Connect(function() States.fovRadius = math.max(25, States.fovRadius - 25) updateUI() end)
rangeAdd.MouseButton1Click:Connect(function() States.espRange += 250 updateUI() end)
rangeSub.MouseButton1Click:Connect(function() States.espRange = math.max(250, States.espRange - 250) updateUI() end)
flyAdd.MouseButton1Click:Connect(function() States.flySpeed += 10 updateUI() end)
flySub.MouseButton1Click:Connect(function() States.flySpeed = math.max(10, States.flySpeed - 10) updateUI() end)
killBtn.MouseButton1Click:Connect(killScript)

for _, p in pairs(Players:GetPlayers()) do createESP(p) end
Players.PlayerAdded:Connect(createESP)

updateUI()
