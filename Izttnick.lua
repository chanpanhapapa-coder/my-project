--==================================================
-- IzttNick Hub V2.2 (Master Combined Edition)
-- Movement + Visuals + Utilities + Combat + Anti-Down
--==================================================

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

--==================================================
-- SETTINGS & KEYBINDS
--==================================================

local Defaults = {
    WalkSpeed = 16,
    JumpPower = 50,
    SprintSpeed = 28,
    FlySpeed = 50,
    DashPower = 65,
    BlinkDistance = 25,
    MaxESPDistance = 250,
    Gravity = workspace.Gravity,
}

local Settings = {
    -- Movement Settings
    WalkSpeed = Defaults.WalkSpeed,
    JumpPower = Defaults.JumpPower,
    SprintSpeed = Defaults.SprintSpeed,
    FlySpeed = Defaults.FlySpeed,
    DashPower = Defaults.DashPower,
    BlinkDistance = Defaults.BlinkDistance,

    Sprint = false,
    Fly = false,
    Noclip = false,
    InfiniteJump = false,
    DoubleJump = false,
    LowGravity = false,
    AutoRun = false,
    InstantHealOnDown = false,
    InstantHealHealth = 100,

    -- Visuals & ESP
    MaxESPDistance = Defaults.MaxESPDistance,
    ESPEnabled = false,
    ESPTracers = false,
    ESPBoxes = false,
    OverheadEnabled = false,
    TeamColors = false,
    TeamCheck = true,
    Fullbright = false,
    RainbowESP = false,
    RainbowSpeed = 1,

    -- Combat & Hitbox
    HitboxEnabled = false,
    HitboxSize = 4,
    HitboxTransparency = 0.7,
    SilentAim = false,
    ShowFOV = false,
    FOVRadius = 120,
    FOVColor = Color3.fromRGB(255, 255, 255),
    TargetPart = "Head",

    -- Proximity Knockdown
    ProximityKnockdown = false,
    KnockdownRadius = 15,
    KnockdownSoundEnabled = true,
    KnockdownSoundId = "rbxassetid://9114223177",
    KnockdownSoundVolume = 1,
    CircleIdleColor = Color3.fromRGB(255, 55, 85),
    CircleActiveColor = Color3.fromRGB(255, 255, 0),

    -- Crosshair
    CrosshairEnabled = false,
    CrosshairSize = 10,
    CrosshairGap = 4,
    CrosshairThickness = 2,
    CrosshairColor = Color3.fromRGB(0, 255, 100),
    TracerColor = Color3.fromRGB(255, 255, 255),
    BoxColor = Color3.fromRGB(0, 255, 100),
}

local Keybinds = {
    Dash = Enum.KeyCode.Q,
    Blink = Enum.KeyCode.E,
    Sprint = Enum.KeyCode.LeftShift,
    ToggleTargetPart = Enum.KeyCode.T,
}

local running = true
local listeningForKey = false
local isEnemyInRadius = false
local lastSoundPlay = 0
local soundCooldown = 1.5
local pulseAngle = 0

local Connections = {}
local PlayerConnections = {}
local drawingObjects = {}
local visualObjects = {}

local Character, Humanoid, Root
local flyVelocity, flyConnection, crosshairGui, knockdownCircle, fovCircle, currentTarget
local targetBtn

local originalFOV = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70
local originalLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    GlobalShadows = Lighting.GlobalShadows,
    OutdoorAmbient = Lighting.OutdoorAmbient,
}
local originalCollisions = {}
local jumpCount = 0
local dashReady = true

--==================================================
-- HELPERS & UI COMPONENTS
--==================================================

local function connect(signal, callback, storage)
    local connection = signal:Connect(callback)
    table.insert(storage or Connections, connection)
    return connection
end

local function notify(title, messageText)
    if not running then return end
    local gui = PlayerGui:FindFirstChild("IzttNickNotifications")
    if not gui then return end
    local label = gui:FindFirstChild("Message")
    if not label then return end

    label.Text = title .. "\n" .. messageText
    label.Visible = true

    task.delay(2.5, function()
        if label.Parent then label.Visible = false end
    end)
end

local function makeButton(parent, text, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -12, 0, 36)
    button.BackgroundColor3 = Color3.fromRGB(45, 48, 60)
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Text = text
    button.Font = Enum.Font.GothamMedium
    button.TextSize = 13
    button.BorderSizePixel = 0
    button.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = button

    connect(button.Activated, callback)
    return button
end

local function makeSlider(parent, labelText, min, max, initial, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -12, 0, 58)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 22)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.Text = labelText .. ": " .. initial
    label.Parent = frame

    local slider = Instance.new("TextButton")
    slider.Position = UDim2.new(0, 0, 0, 29)
    slider.Size = UDim2.new(1, 0, 0, 20)
    slider.BackgroundColor3 = Color3.fromRGB(55, 58, 70)
    slider.Text = ""
    slider.BorderSizePixel = 0
    slider.Parent = frame

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = Color3.fromRGB(255, 55, 85)
    fill.BorderSizePixel = 0
    fill.Parent = slider

    local value = initial
    local dragging = false

    local function setValue(v)
        value = math.clamp(math.floor(v), min, max)
        local percent = (value - min) / (max - min)
        fill.Size = UDim2.new(percent, 0, 1, 0)
        label.Text = labelText .. ": " .. value
        callback(value)
    end

    local function updateFromPosition(x)
        local percent = math.clamp((x - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
        setValue(min + percent * (max - min))
    end

    connect(slider.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromPosition(input.Position.X)
        end
    end)

    connect(UIS.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromPosition(input.Position.X)
        end
    end)

    connect(UIS.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    setValue(initial)
    return frame
end

local function makeToggle(parent, labelText, initial, callback)
    local button = makeButton(parent, "", function() end)
    local state = initial

    local function update()
        button.Text = labelText .. ": " .. (state and "ON" or "OFF")
        button.BackgroundColor3 = state and Color3.fromRGB(20, 130, 90) or Color3.fromRGB(45, 48, 60)
    end

    button.Activated:Connect(function()
        state = not state
        update()
        callback(state)
    end)

    update()
    return button
end

local function makeKeybindPicker(parent, labelText, keybindKey, onRebind)
    local defaultKey = Keybinds[keybindKey]
    local button = makeButton(parent, labelText .. ": " .. defaultKey.Name, function() end)

    button.Activated:Connect(function()
        if listeningForKey then return end
        listeningForKey = true
        button.Text = labelText .. ": Press any key..."
        button.BackgroundColor3 = Color3.fromRGB(200, 140, 20)

        local connection
        connection = UIS.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Keyboard then
                connection:Disconnect()
                listeningForKey = false

                local newKey = input.KeyCode
                Keybinds[keybindKey] = newKey
                button.Text = labelText .. ": " .. newKey.Name
                button.BackgroundColor3 = Color3.fromRGB(45, 48, 60)

                if onRebind then onRebind(newKey) end
                notify("Keybind Updated", labelText .. " set to " .. newKey.Name)
            end
        end)
    end)

    return button
end

--==================================================
-- UI FRAMEWORK SETUP
--==================================================

local Screen = Instance.new("ScreenGui")
Screen.Name = "IzttNickHubV22"
Screen.ResetOnSpawn = false
Screen.Parent = PlayerGui

local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(520, 440)
Main.Position = UDim2.new(0.5, -260, 0.5, -220)
Main.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
Main.BorderSizePixel = 0
Main.Parent = Screen

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 42)
Title.BackgroundColor3 = Color3.fromRGB(35, 38, 49)
Title.Text = "IzttNick Hub V2.2"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.Parent = Main

local Tabs = Instance.new("Frame")
Tabs.Position = UDim2.fromOffset(8, 50)
Tabs.Size = UDim2.new(0, 112, 1, -58)
Tabs.BackgroundTransparency = 1
Tabs.Parent = Main

local Content = Instance.new("Frame")
Content.Position = UDim2.fromOffset(128, 50)
Content.Size = UDim2.new(1, -136, 1, -58)
Content.BackgroundTransparency = 1
Content.Parent = Main

local Pages = {}
local currentPage

local function createTab(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.CanvasSize = UDim2.new()
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = Content

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 7)
    layout.Parent = page

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 5)
    padding.PaddingLeft = UDim.new(0, 5)
    padding.Parent = page

    local tabButton = makeButton(Tabs, name, function()
        if currentPage then currentPage.Visible = false end
        currentPage = page
        page.Visible = true
    end)

    tabButton.Size = UDim2.new(1, 0, 0, 34)
    Pages[name] = page

    if not currentPage then
        currentPage = page
        page.Visible = true
    end

    return page
end

local Movement = createTab("Movement")
local Visuals = createTab("Visuals")
local Combat = createTab("Combat")
local Utilities = createTab("Utilities")
local KeyPage = createTab("Keybinds")

--==================================================
-- CHARACTER & MOVEMENT LOGIC
--==================================================

local function stopFly()
    Settings.Fly = false
    if flyConnection then flyConnection:Disconnect() flyConnection = nil end
    if flyVelocity then flyVelocity:Destroy() flyVelocity = nil end
    if Humanoid and Humanoid.Parent then Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
end

local function restoreNoclip()
    for part, oldValue in pairs(originalCollisions) do
        if part and part.Parent then part.CanCollide = oldValue end
    end
    table.clear(originalCollisions)
end

local function setupCharacter(char)
    stopFly()
    restoreNoclip()

    Character = char
    Humanoid = char:WaitForChild("Humanoid")
    Root = char:WaitForChild("HumanoidRootPart")

    Humanoid.UseJumpPower = true
    Humanoid.WalkSpeed = Settings.WalkSpeed
    Humanoid.JumpPower = Settings.JumpPower

    jumpCount = 0

    connect(Humanoid.HealthChanged, function()
        if Settings.InstantHealOnDown and Humanoid and Humanoid.Health < 20 then
            Humanoid.Health = math.max(Humanoid.MaxHealth, Settings.InstantHealHealth)
            Humanoid.PlatformStand = false
            Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end)
end

connect(LP.CharacterAdded, setupCharacter)
if LP.Character then task.spawn(setupCharacter, LP.Character) end

local function setFly(enabled)
    if enabled then
        if not Root or not Humanoid then return end
        stopFly()
        Settings.Fly = true

        flyVelocity = Instance.new("BodyVelocity")
        flyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        flyVelocity.Velocity = Vector3.zero
        flyVelocity.Parent = Root

        flyConnection = RunService.RenderStepped:Connect(function()
            if not Settings.Fly or not Root or not Root.Parent or not Humanoid or not Humanoid.Parent then
                stopFly()
                return
            end

            local camera = workspace.CurrentCamera
            if not camera then return end

            local direction = Vector3.zero
            local cf = camera.CFrame

            if UIS:IsKeyDown(Enum.KeyCode.W) then direction += cf.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then direction -= cf.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then direction += cf.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then direction -= cf.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then direction += Vector3.yAxis end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then direction -= Vector3.yAxis end

            flyVelocity.Velocity = direction.Magnitude > 0 and direction.Unit * Settings.FlySpeed or Vector3.zero
        end)
        notify("Fly", "Flight enabled.")
    else
        stopFly()
        notify("Fly", "Flight disabled.")
    end
end

local function setNoclip(enabled)
    Settings.Noclip = enabled
    if not enabled then restoreNoclip() end
    notify("Noclip", enabled and "Enabled" or "Disabled")
end

local function setFullbright(enabled)
    Settings.Fullbright = enabled
    if enabled then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        notify("Fullbright", "Enabled.")
    else
        Lighting.Brightness = originalLighting.Brightness
        Lighting.ClockTime = originalLighting.ClockTime
        Lighting.GlobalShadows = originalLighting.GlobalShadows
        Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
        notify("Fullbright", "Disabled.")
    end
end

local function dash()
    if not dashReady or not Root or not Humanoid then return end
    local direction = Humanoid.MoveDirection.Magnitude > 0 and Humanoid.MoveDirection or Root.CFrame.LookVector
    dashReady = false
    Root.AssemblyLinearVelocity = direction.Unit * Settings.DashPower + Vector3.new(0, Root.AssemblyLinearVelocity.Y, 0)
    notify("Dash", "Dash activated.")
    task.delay(1, function() dashReady = true end)
end

local function blink()
    if not Root then return end
    Root.CFrame = Root.CFrame + Root.CFrame.LookVector * Settings.BlinkDistance
    notify("Blink", "Moved forward.")
end

--==================================================
-- INSTANT HEAL & PROXIMITY KNOCKDOWN
--==================================================

local function checkInstantHealOnDown()
    if not Settings.InstantHealOnDown or not Humanoid or not Root or not running then return end
    local state = Humanoid:GetState()
    local isDownState = (state == Enum.HumanoidStateType.FallingDown) 
                     or (state == Enum.HumanoidStateType.Ragdoll) 
                     or (state == Enum.HumanoidStateType.Physics)
                     or Humanoid.PlatformStand or Humanoid.Sit

    if isDownState or Humanoid.Health <= 15 then
        pcall(function()
            Humanoid.Health = math.max(Humanoid.MaxHealth, Settings.InstantHealHealth)
            Humanoid.PlatformStand = false
            Humanoid.Sit = false
            Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            Root.AssemblyLinearVelocity = Vector3.zero
            Root.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

local function playKnockdownSound()
    if not Settings.KnockdownSoundEnabled then return end
    local currentTime = os.clock()
    if currentTime - lastSoundPlay >= soundCooldown then
        lastSoundPlay = currentTime
        local sound = Instance.new("Sound")
        sound.SoundId = Settings.KnockdownSoundId
        sound.Volume = Settings.KnockdownSoundVolume
        sound.Parent = SoundService
        sound:Play()
        sound.Ended:Connect(function() sound:Destroy() end)
    end
end

local function updateProximityKnockdown()
    if not Settings.ProximityKnockdown or not Root or not running then 
        isEnemyInRadius = false
        return 
    end

    local foundTarget = false
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LP then
            local char = player.Character
            local targetRoot = char and char:FindFirstChild("HumanoidRootPart")
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")

            if targetRoot and humanoid and humanoid.Health > 0 then
                local distance = (Root.Position - targetRoot.Position).Magnitude
                local sameTeam = player.Team ~= nil and player.Team == LP.Team
                local shouldTarget = not (Settings.TeamCheck and sameTeam)

                if distance <= Settings.KnockdownRadius and shouldTarget then
                    foundTarget = true
                    playKnockdownSound()
                    pcall(function()
                        humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
                        humanoid.PlatformStand = true
                        task.delay(0.5, function()
                            if humanoid and humanoid.Parent then humanoid.PlatformStand = false end
                        end)
                    end)
                end
            end
        end
    end
    isEnemyInRadius = foundTarget
end

local function createKnockdownCircle()
    if knockdownCircle then knockdownCircle:Destroy() end
    knockdownCircle = Instance.new("CylinderHandleAdornment")
    knockdownCircle.Name = "IzttNickKnockdownCircle"
    knockdownCircle.Height = 0.2
    knockdownCircle.Color3 = Settings.CircleIdleColor
    knockdownCircle.Transparency = 0.5
    knockdownCircle.AlwaysOnTop = false
    knockdownCircle.ZIndex = 1
end

local function updateKnockdownCircle()
    if not Root then return end
    if Settings.ProximityKnockdown then
        if not knockdownCircle or not knockdownCircle.Parent then
            createKnockdownCircle()
            knockdownCircle.Adornee = Root
            knockdownCircle.Parent = Root
        end
        knockdownCircle.Radius = Settings.KnockdownRadius
        knockdownCircle.CFrame = CFrame.new(0, -2.8, 0) * CFrame.Angles(math.rad(90), 0, 0)
        knockdownCircle.Visible = true

        if isEnemyInRadius then
            pulseAngle = (pulseAngle + 0.2) % (math.pi * 2)
            knockdownCircle.Color3 = Settings.CircleActiveColor
            knockdownCircle.Transparency = 0.2 + (math.sin(pulseAngle) * 0.2)
        else
            knockdownCircle.Color3 = Settings.CircleIdleColor
            knockdownCircle.Transparency = 0.5
        end
    else
        if knockdownCircle then knockdownCircle.Visible = false end
    end
end

--==================================================
-- HITBOX EXTENDER & SILENT AIM
--==================================================

local function updateHitboxes()
    if not running then return end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LP then
            local char = player.Character
            local rootPart = char and char:FindFirstChild("HumanoidRootPart")
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")

            if rootPart and humanoid and humanoid.Health > 0 then
                local sameTeam = player.Team ~= nil and player.Team == LP.Team
                local shouldTarget = Settings.HitboxEnabled and not (Settings.TeamCheck and sameTeam)

                if shouldTarget then
                    if not rootPart:FindFirstChild("OriginalSize") then
                        local origSize = Instance.new("Vector3Value")
                        origSize.Name = "OriginalSize"
                        origSize.Value = rootPart.Size
                        origSize.Parent = rootPart
                    end
                    rootPart.Size = Vector3.new(Settings.HitboxSize, Settings.HitboxSize, Settings.HitboxSize)
                    rootPart.Transparency = Settings.HitboxTransparency
                    rootPart.CanCollide = false
                else
                    local origSize = rootPart:FindFirstChild("OriginalSize")
                    if origSize then
                        rootPart.Size = origSize.Value
                        rootPart.Transparency = 1
                        rootPart.CanCollide = true
                        origSize:Destroy()
                    end
                end
            end
        end
    end
end

local function createFOVCircle()
    if fovCircle then pcall(function() fovCircle:Remove() end) end
    fovCircle = Drawing.new("Circle")
    fovCircle.Visible = false
    fovCircle.Thickness = 1.5
    fovCircle.NumSides = 60
    fovCircle.Radius = Settings.FOVRadius
    fovCircle.Filled = false
    fovCircle.Transparency = 1
    fovCircle.Color = Settings.FOVColor
end
createFOVCircle()

local function getClosestPlayerInFOV()
    if not workspace.CurrentCamera or not Root then return nil end
    local camera = workspace.CurrentCamera
    local mousePos = UIS:GetMouseLocation()
    local closestPlayer = nil
    local shortestDistance = Settings.FOVRadius

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LP then
            local char = player.Character
            local targetPart = char and char:FindFirstChild(Settings.TargetPart)
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")

            if targetPart and humanoid and humanoid.Health > 0 then
                local sameTeam = player.Team ~= nil and player.Team == LP.Team
                local shouldTarget = not (Settings.TeamCheck and sameTeam)

                if shouldTarget then
                    local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                    if onScreen then
                        local distanceToMouse = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        if distanceToMouse < shortestDistance then
                            shortestDistance = distanceToMouse
                            closestPlayer = player
                        end
                    end
                end
            end
        end
    end
    return closestPlayer
end

local function toggleTargetPart()
    if Settings.TargetPart == "Head" then
        Settings.TargetPart = "HumanoidRootPart"
        if targetBtn then targetBtn.Text = "Target Part: Torso" end
        notify("Target Part", "Switched to Torso")
    else
        Settings.TargetPart = "Head"
        if targetBtn then targetBtn.Text = "Target Part: Head" end
        notify("Target Part", "Switched to Head")
    end
end

--==================================================
-- VISUALS: CROSSHAIR & DRAWING SUITE
--==================================================

local function createCrosshair()
    if crosshairGui then crosshairGui:Destroy() end
    crosshairGui = Instance.new("ScreenGui")
    crosshairGui.Name = "IzttNickCrosshair"
    crosshairGui.IgnoreGuiInset = true
    crosshairGui.ResetOnSpawn = false
    crosshairGui.Enabled = Settings.CrosshairEnabled
    crosshairGui.Parent = PlayerGui

    local center = Instance.new("Frame")
    center.Name = "Center"
    center.AnchorPoint = Vector2.new(0.5, 0.5)
    center.Position = UDim2.fromScale(0.5, 0.5)
    center.Parent = crosshairGui

    for _, name in ipairs({"Top", "Bottom", "Left", "Right"}) do
        local line = Instance.new("Frame")
        line.Name = name
        line.BorderSizePixel = 0
        line.Parent = center
    end
end

local function updateCrosshair()
    if not crosshairGui then return end
    crosshairGui.Enabled = Settings.CrosshairEnabled
    local center = crosshairGui:FindFirstChild("Center")
    if not center then return end

    local size, gap, thickness = Settings.CrosshairSize, Settings.CrosshairGap, Settings.CrosshairThickness
    local positions = {
        Top = {UDim2.fromOffset(-thickness/2, -gap-size), UDim2.fromOffset(thickness, size)},
        Bottom = {UDim2.fromOffset(-thickness/2, gap), UDim2.fromOffset(thickness, size)},
        Left = {UDim2.fromOffset(-gap-size, -thickness/2), UDim2.fromOffset(size, thickness)},
        Right = {UDim2.fromOffset(gap, -thickness/2), UDim2.fromOffset(size, thickness)},
    }
    for name, data in pairs(positions) do
        local line = center:FindFirstChild(name)
        if line then
            line.Position = data[1]
            line.Size = data[2]
            line.BackgroundColor3 = Settings.CrosshairColor
        end
    end
end
createCrosshair()

local function clearPlayerVisuals(player)
    if visualObjects[player] then
        for _, obj in ipairs(visualObjects[player]) do
            if obj and obj.Destroy then pcall(function() obj:Destroy() end) end
        end
        visualObjects[player] = nil
    end
    if drawingObjects[player] then
        for _, drw in pairs(drawingObjects[player]) do pcall(function() drw:Remove() end) end
        drawingObjects[player] = nil
    end
end

local function createPlayerVisuals(player, char)
    if player == LP then return end
    clearPlayerVisuals(player)

    local head = char:WaitForChild("Head", 5)
    local humanoid = char:WaitForChild("Humanoid", 5)
    if not head or not humanoid then return end

    local objects = {}
    visualObjects[player] = objects

    local highlight = Instance.new("Highlight")
    highlight.Name = "IzttNickHighlight"
    highlight.Adornee = char
    highlight.FillTransparency = 0.65
    highlight.Parent = char
    table.insert(objects, highlight)

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "IzttNickOverhead"
    billboard.Size = UDim2.fromOffset(150, 38)
    billboard.StudsOffset = Vector3.new(0, 2.7, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = head
    table.insert(objects, billboard)

    local label = Instance.new("TextLabel")
    label.Name = "NameLabel"
    label.Size = UDim2.new(1, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.Parent = billboard

    drawingObjects[player] = {
        Tracer = Drawing.new("Line"),
        Box = Drawing.new("Square"),
        DistanceText = Drawing.new("Text"),
        NameText = Drawing.new("Text"),
        HealthBarBG = Drawing.new("Square"),
        HealthBar = Drawing.new("Square"),
    }
    drawingObjects[player].Box.Filled = false
    drawingObjects[player].HealthBarBG.Filled = true
    drawingObjects[player].HealthBar.Filled = true
end

local function updateVisuals()
    if not Root or not workspace.CurrentCamera then return end
    local camera = workspace.CurrentCamera
    local viewportSize = camera.ViewportSize
    local rainbowColor = Color3.fromHSV((tick() * Settings.RainbowSpeed) % 5 / 5, 1, 1)

    for player, objects in pairs(visualObjects) do
        local char = player.Character
        local targetRoot = char and char:FindFirstChild("HumanoidRootPart")
        local highlight = char and char:FindFirstChild("IzttNickHighlight")
        local billboard = char and char:FindFirstChild("IzttNickOverhead")

        local distance = targetRoot and (Root.Position - targetRoot.Position).Magnitude or math.huge
        local shouldShow = distance <= Settings.MaxESPDistance and not (Settings.TeamCheck and player.Team == LP.Team)
        local color = Settings.TeamColors and player.Team and player.Team.TeamColor.Color or Color3.fromRGB(0, 255, 100)

        if highlight then
            highlight.Enabled = Settings.ESPEnabled and shouldShow
            highlight.FillColor = color
        end
        if billboard then
            billboard.Enabled = Settings.OverheadEnabled and shouldShow
            local label = billboard:FindFirstChild("NameLabel")
            if label then label.Text = string.format("%s [%d]", player.Name, math.floor(distance)) end
        end
    end

    for player, drawings in pairs(drawingObjects) do
        local char = player.Character
        local targetRoot = char and char:FindFirstChild("HumanoidRootPart")
        if char and targetRoot and Root then
            local distance = (Root.Position - targetRoot.Position).Magnitude
            local shouldShow = distance <= Settings.MaxESPDistance and not (Settings.TeamCheck and player.Team == LP.Team)
            local pos, onScreen = camera:WorldToViewportPoint(targetRoot.Position)

            if Settings.ESPTracers and shouldShow and onScreen then
                drawings.Tracer.From = Vector2.new(viewportSize.X / 2, viewportSize.Y)
                drawings.Tracer.To = Vector2.new(pos.X, pos.Y)
                drawings.Tracer.Color = Settings.RainbowESP and rainbowColor or Settings.TracerColor
                drawings.Tracer.Visible = true
            else drawings.Tracer.Visible = false end

            if Settings.ESPBoxes and shouldShow and onScreen then
                local head = char:FindFirstChild("Head")
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if head and humanoid then
                    local headPos = camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                    local legPos = camera:WorldToViewportPoint(targetRoot.Position - Vector3.new(0, 3, 0))
                    local height = math.abs(headPos.Y - legPos.Y)
                    local width = height / 2
                    local boxPos = Vector2.new(pos.X - width / 2, pos.Y - height / 2)

                    drawings.Box.Size = Vector2.new(width, height)
                    drawings.Box.Position = boxPos
                    drawings.Box.Color = Settings.RainbowESP and rainbowColor or Settings.BoxColor
                    drawings.Box.Visible = true

                    drawings.NameText.Text = player.DisplayName or player.Name
                    drawings.NameText.Position = Vector2.new(pos.X, boxPos.Y - 30)
                    drawings.NameText.Visible = true

                    drawings.DistanceText.Text = string.format("[%d studs]", math.floor(distance))
                    drawings.DistanceText.Position = Vector2.new(pos.X, boxPos.Y - 15)
                    drawings.DistanceText.Visible = true
                end
            else
                drawings.Box.Visible = false
                drawings.NameText.Visible = false
                drawings.DistanceText.Visible = false
            end
        else
            drawings.Tracer.Visible = false
            drawings.Box.Visible = false
        end
    end
end

--==================================================
-- MAIN LOOPS & EVENT CONNECTIONS
--==================================================

connect(RunService.Heartbeat, function()
    if not running then return end

    if Humanoid and Humanoid.Parent then
        Humanoid.WalkSpeed = Settings.Sprint and Settings.SprintSpeed or Settings.WalkSpeed
        Humanoid.JumpPower = Settings.JumpPower
        if Settings.AutoRun and not Settings.Fly then
            Humanoid:Move(Humanoid.MoveDirection.Magnitude > 0 and Humanoid.MoveDirection or Root.CFrame.LookVector, false)
        end
    end

    if Settings.Fullbright then
        Lighting.Brightness = 2
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
    end

    if Settings.Noclip and Character then
        for _, part in ipairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then
                if originalCollisions[part] == nil then originalCollisions[part] = part.CanCollide end
                part.CanCollide = false
            end
        end
    end

    checkInstantHealOnDown()
    updateProximityKnockdown()
    updateHitboxes()
end)

connect(RunService.RenderStepped, function()
    updateVisuals()
    updateKnockdownCircle()

    local mousePos = UIS:GetMouseLocation()
    if fovCircle then
        fovCircle.Position = mousePos
        fovCircle.Radius = Settings.FOVRadius
        fovCircle.Color = Settings.RainbowESP and Color3.fromHSV((tick() * Settings.RainbowSpeed) % 5 / 5, 1, 1) or Settings.FOVColor
        fovCircle.Visible = Settings.ShowFOV
    end

    if Settings.SilentAim then
        currentTarget = getClosestPlayerInFOV()
        if currentTarget and currentTarget.Character then
            local targetPart = currentTarget.Character:FindFirstChild(Settings.TargetPart)
            if targetPart and workspace.CurrentCamera then
                workspace.CurrentCamera.CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position, targetPart.Position)
            end
        end
    end
end)

local function watchPlayer(player)
    if player == LP then return end
    local function onCharacter(char)
        task.wait(0.5)
        if running and player.Parent then createPlayerVisuals(player, char) end
    end
    if player.Character then task.spawn(onCharacter, player.Character) end
    connect(player.CharacterAdded, onCharacter, PlayerConnections)
end

for _, player in ipairs(Players:GetPlayers()) do watchPlayer(player) end
connect(Players.PlayerAdded, watchPlayer)
connect(Players.PlayerRemoving, clearPlayerVisuals)

--==================================================
-- UI CONTROL BINDINGS
--==================================================

-- Movement Tab
makeSlider(Movement, "Walk Speed", 1, 100, Settings.WalkSpeed, function(v) Settings.WalkSpeed = v end)
makeSlider(Movement, "Jump Power", 1, 150, Settings.JumpPower, function(v) Settings.JumpPower = v end)
makeSlider(Movement, "Sprint Speed", 16, 100, Settings.SprintSpeed, function(v) Settings.SprintSpeed = v end)
makeSlider(Movement, "Fly Speed", 10, 150, Settings.FlySpeed, function(v) Settings.FlySpeed = v end)
makeSlider(Movement, "Dash Power", 10, 150, Settings.DashPower, function(v) Settings.DashPower = v end)
makeToggle(Movement, "Instant Down Heal & Move", false, function(v) Settings.InstantHealOnDown = v end)
makeToggle(Movement, "Sprint", false, function(v) Settings.Sprint = v end)
makeToggle(Movement, "Fly", false, setFly)
makeToggle(Movement, "Noclip", false, setNoclip)
makeToggle(Movement, "Auto Run", false, function(v) Settings.AutoRun = v end)

-- Visuals Tab
makeToggle(Visuals, "Player Highlights", false, function(v) Settings.ESPEnabled = v end)
makeToggle(Visuals, "Name Tags", false, function(v) Settings.OverheadEnabled = v end)
makeToggle(Visuals, "Tracers", false, function(v) Settings.ESPTracers = v end)
makeToggle(Visuals, "Bounding Boxes", false, function(v) Settings.ESPBoxes = v end)
makeToggle(Visuals, "Fullbright", false, setFullbright)
makeToggle(Visuals, "Rainbow ESP", false, function(v) Settings.RainbowESP = v end)
makeSlider(Visuals, "Rainbow Speed", 1, 10, Settings.RainbowSpeed, function(v) Settings.RainbowSpeed = v end)
makeToggle(Visuals, "Crosshair", false, function(v) Settings.CrosshairEnabled = v updateCrosshair() end)

-- Combat Tab
makeToggle(Combat, "Silent Aim", false, function(v) Settings.SilentAim = v end)
makeToggle(Combat, "Show FOV Circle", false, function(v) Settings.ShowFOV = v end)
makeSlider(Combat, "FOV Radius", 30, 300, Settings.FOVRadius, function(v) Settings.FOVRadius = v end)
targetBtn = makeButton(Combat, "Target Part: Head", toggleTargetPart)
makeToggle(Combat, "Hitbox Extender", false, function(v) Settings.HitboxEnabled = v end)
makeSlider(Combat, "Hitbox Size", 2, 20, Settings.HitboxSize, function(v) Settings.HitboxSize = v end)

-- Utilities Tab
makeToggle(Utilities, "Proximity Body Down", false, function(v) Settings.ProximityKnockdown = v updateKnockdownCircle() end)
makeSlider(Utilities, "Knockdown Radius", 5, 50, Settings.KnockdownRadius, function(v) Settings.KnockdownRadius = v end)
makeToggle(Utilities, "Knockdown Sound", true, function(v) Settings.KnockdownSoundEnabled = v end)
makeButton(Utilities, "Dash", dash)
makeButton(Utilities, "Blink Forward", blink)

-- Keybinds Tab
makeKeybindPicker(KeyPage, "Dash Key", "Dash")
makeKeybindPicker(KeyPage, "Blink Key", "Blink")
makeKeybindPicker(KeyPage, "Sprint Key", "Sprint")
makeKeybindPicker(KeyPage, "Target Part Key", "ToggleTargetPart")

--==================================================
-- CLEANUP & KEY LISTENERS
--==================================================

local function resetHub()
    Settings.Sprint = false
    Settings.AutoRun = false
    Settings.InstantHealOnDown = false
    Settings.HitboxEnabled = false
    Settings.SilentAim = false
    Settings.ShowFOV = false
    Settings.ProximityKnockdown = false
    setFly(false)
    setNoclip(false)
    setFullbright(false)

    if knockdownCircle then knockdownCircle.Visible = false end
    if fovCircle then fovCircle.Visible = false end
    updateHitboxes()
    notify("Reset", "All hub settings restored.")
end

makeButton(Utilities, "Reset All Settings", resetHub)
makeButton(Utilities, "Close Hub", function()
    running = false
    setFly(false)
    restoreNoclip()
    setFullbright(false)

    if knockdownCircle then knockdownCircle:Destroy() end
    if fovCircle then pcall(function() fovCircle:Remove() end) end
    if crosshairGui then crosshairGui:Destroy() end

    for player, _ in pairs(drawingObjects) do clearPlayerVisuals(player) end
    for _, connection in ipairs(Connections) do connection:Disconnect() end
    Screen:Destroy()
end)

connect(UIS.InputBegan, function(input, processed)
    if processed or listeningForKey then return end
    if input.KeyCode == Keybinds.Sprint then Settings.Sprint = true
    elseif input.KeyCode == Keybinds.Dash then dash()
    elseif input.KeyCode == Keybinds.Blink then blink()
    elseif input.KeyCode == Keybinds.ToggleTargetPart then toggleTargetPart() end
end)

connect(UIS.InputEnded, function(input)
    if input.KeyCode == Keybinds.Sprint then Settings.Sprint = false end
end)

-- Notifications Display
local notificationGui = Instance.new("ScreenGui")
notificationGui.Name = "IzttNickNotifications"
notificationGui.ResetOnSpawn = false
notificationGui.Parent = PlayerGui

local message = Instance.new("TextLabel")
message.Name = "Message"
message.AnchorPoint = Vector2.new(1, 0)
message.Position = UDim2.new(1, -20, 0, 20)
message.Size = UDim2.fromOffset(260, 60)
message.BackgroundColor3 = Color3.fromRGB(35, 38, 49)
message.TextColor3 = Color3.new(1, 1, 1)
message.Font = Enum.Font.GothamBold
message.TextSize = 13
message.Visible = false
message.Parent = notificationGui

notify("IzttNick Hub V2.2", "Full Combined Edition Loaded!")
print("IzttNick Hub V2.2 fully compiled.")
