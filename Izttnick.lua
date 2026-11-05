
--==================================================
-- IzttNick Hub V2.2
-- Roblox Studio Edition
-- Movement + Visuals + Utilities + Crosshair
--==================================================

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

--==================================================
-- SETTINGS
--==================================================

local Defaults = {
    WalkSpeed = 16,
    JumpPower = 50,
    SprintSpeed = 28,
    FlySpeed = 50,
    DashPower = 65,
    BlinkDistance = 25,
    MaxESPDistance = 250,
    FOV = 70,
    Gravity = workspace.Gravity,
}

local Settings = {
    WalkSpeed = Defaults.WalkSpeed,
    JumpPower = Defaults.JumpPower,
    SprintSpeed = Defaults.SprintSpeed,
    FlySpeed = Defaults.FlySpeed,
    DashPower = Defaults.DashPower,
    BlinkDistance = Defaults.BlinkDistance,
    MaxESPDistance = Defaults.MaxESPDistance,

    Sprint = false,
    Fly = false,
    Noclip = false,
    InfiniteJump = false,
    DoubleJump = false,
    LowGravity = false,
    AutoRun = false,

    ESPEnabled = false,
    OverheadEnabled = false,
    TeamColors = false,

    CrosshairEnabled = false,
    CrosshairSize = 10,
    CrosshairGap = 4,
    CrosshairThickness = 2,
    CrosshairColor = Color3.fromRGB(0, 255, 100),
}

local Keybinds = {
    Dash = Enum.KeyCode.Q,
    Blink = Enum.KeyCode.E,
    Sprint = Enum.KeyCode.LeftShift,
}

local running = true
local Connections = {}
local CharacterConnections = {}
local PlayerConnections = {}

local Character
local Humanoid
local Root

local originalFOV = workspace.CurrentCamera
    and workspace.CurrentCamera.FieldOfView or 70

local originalCollisions = {}
local jumpCount = 0
local dashReady = true
local flyVelocity
local flyConnection
local crosshairGui

--==================================================
-- HELPERS
--==================================================

local function connect(signal, callback, storage)
    local connection = signal:Connect(callback)
    table.insert(storage or Connections, connection)
    return connection
end

local function notify(title, message)
    if not running then return end

    local gui = PlayerGui:FindFirstChild("IzttNickNotifications")
    if not gui then return end

    local label = gui:FindFirstChild("Message")
    if not label then return end

    label.Text = title .. "\n" .. message
    label.Visible = true

    task.delay(2.5, function()
        if label.Parent then
            label.Visible = false
        end
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
        local percent = math.clamp(
            (x - slider.AbsolutePosition.X) / slider.AbsoluteSize.X,
            0, 1
        )
        setValue(min + percent * (max - min))
    end

    connect(slider.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromPosition(input.Position.X)
        end
    end)

    connect(UIS.InputChanged, function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        ) then
            updateFromPosition(input.Position.X)
        end
    end)

    connect(UIS.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
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
        button.BackgroundColor3 = state
            and Color3.fromRGB(20, 130, 90)
            or Color3.fromRGB(45, 48, 60)
    end

    button.Activated:Connect(function()
        state = not state
        update()
        callback(state)
    end)

    update()
    return button
end

--==================================================
-- UI
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
local Utilities = createTab("Utilities")
local KeyPage = createTab("Keybinds")

--==================================================
-- CHARACTER SETUP
--==================================================

local function stopFly()
    Settings.Fly = false

    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end

    if flyVelocity then
        flyVelocity:Destroy()
        flyVelocity = nil
    end

    if Humanoid and Humanoid.Parent then
        Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end

local function restoreNoclip()
    for part, oldValue in pairs(originalCollisions) do
        if part and part.Parent then
            part.CanCollide = oldValue
        end
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
end

connect(LP.CharacterAdded, setupCharacter)

if LP.Character then
    task.spawn(setupCharacter, LP.Character)
end

--==================================================
-- MOVEMENT
--==================================================

local function setFly(enabled)
    if enabled then
        if not Root or not Humanoid then
            notify("Fly", "Character is not ready.")
            return
        end

        stopFly()
        Settings.Fly = true

        flyVelocity = Instance.new("BodyVelocity")
        flyVelocity.Name = "IzttNickFlyVelocity"
        flyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        flyVelocity.Velocity = Vector3.zero
        flyVelocity.Parent = Root

        flyConnection = RunService.RenderStepped:Connect(function()
            if not Settings.Fly or not Root or not Root.Parent
                or not Humanoid or not Humanoid.Parent then
                stopFly()
                return
            end

            local camera = workspace.CurrentCamera
            if not camera then return end

            local direction = Vector3.zero
            local cf = camera.CFrame

            if UIS:IsKeyDown(Enum.KeyCode.W) then
                direction += cf.LookVector
            end
            if UIS:IsKeyDown(Enum.KeyCode.S) then
                direction -= cf.LookVector
            end
            if UIS:IsKeyDown(Enum.KeyCode.D) then
                direction += cf.RightVector
            end
            if UIS:IsKeyDown(Enum.KeyCode.A) then
                direction -= cf.RightVector
            end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then
                direction += Vector3.yAxis
            end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
                direction -= Vector3.yAxis
            end

            flyVelocity.Velocity =
                direction.Magnitude > 0
                and direction.Unit * Settings.FlySpeed
                or Vector3.zero
        end)

        notify("Fly", "Flight enabled.")
    else
        stopFly()
        notify("Fly", "Flight disabled.")
    end
end

local function setNoclip(enabled)
    Settings.Noclip = enabled

    if not enabled then
        restoreNoclip()
    end

    notify("Noclip", enabled and "Enabled" or "Disabled")
end

local function dash()
    if not dashReady or not Root or not Humanoid then return end

    local direction = Humanoid.MoveDirection
    if direction.Magnitude == 0 then
        direction = Root.CFrame.LookVector
    end

    dashReady = false
    Root.AssemblyLinearVelocity =
        direction.Unit * Settings.DashPower
        + Vector3.new(0, Root.AssemblyLinearVelocity.Y, 0)

    notify("Dash", "Dash activated.")

    task.delay(1, function()
        dashReady = true
    end)
end

local function blink()
    if not Root then return end

    Root.CFrame = Root.CFrame + Root.CFrame.LookVector * Settings.BlinkDistance
    notify("Blink", "Moved forward.")
end

connect(RunService.Heartbeat, function()
    if not running then return end

    if Humanoid and Humanoid.Parent then
        Humanoid.WalkSpeed = Settings.Sprint
            and Settings.SprintSpeed or Settings.WalkSpeed

        Humanoid.UseJumpPower = true
        Humanoid.JumpPower = Settings.JumpPower

        if Settings.AutoRun and not Settings.Fly then
            Humanoid:Move(Humanoid.MoveDirection.Magnitude > 0
                and Humanoid.MoveDirection
                or Root.CFrame.LookVector, false)
        end
    end

    if Settings.Noclip and Character then
        for _, part in ipairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then
                if originalCollisions[part] == nil then
                    originalCollisions[part] = part.CanCollide
                end
                part.CanCollide = false
            end
        end
    end
end)

connect(UIS.JumpRequest, function()
    if not Humanoid or not Humanoid.Parent then return end

    if Settings.InfiniteJump then
        Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    elseif Settings.DoubleJump then
        if Humanoid.FloorMaterial ~= Enum.Material.Air then
            jumpCount = 1
        elseif jumpCount < 2 then
            jumpCount += 1
            Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

connect(RunService.Heartbeat, function()
    if Humanoid and Humanoid.FloorMaterial ~= Enum.Material.Air then
        jumpCount = 0
    end
end)

--==================================================
-- VISUALS: CROSSHAIR
--==================================================

local function createCrosshair()
    if crosshairGui then
        crosshairGui:Destroy()
    end

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
    center.Size = UDim2.fromOffset(0, 0)
    center.BackgroundTransparency = 1
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

    local size = Settings.CrosshairSize
    local gap = Settings.CrosshairGap
    local thickness = Settings.CrosshairThickness
    local color = Settings.CrosshairColor

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
            line.BackgroundColor3 = color
        end
    end
end

createCrosshair()
updateCrosshair()

--==================================================
-- VISUALS: PLAYER HIGHLIGHTS & OVERHEAD
--==================================================

local visualObjects = {}

local function clearPlayerVisuals(player)
    local objects = visualObjects[player]
    if not objects then return end

    for _, object in ipairs(objects) do
        if object and object.Parent then
            object:Destroy()
        end
    end

    visualObjects[player] = nil
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
    highlight.OutlineTransparency = 0
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
    label.TextStrokeTransparency = 0.3
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.Parent = billboard

    local barBG = Instance.new("Frame")
    barBG.Position = UDim2.fromOffset(15, 23)
    barBG.Size = UDim2.new(1, -30, 0, 6)
    barBG.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    barBG.BorderSizePixel = 0
    barBG.Parent = billboard

    local bar = Instance.new("Frame")
    bar.Size = UDim2.fromScale(1, 1)
    bar.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
    bar.BorderSizePixel = 0
    bar.Parent = barBG

    local function updateHealth(health)
        local percent = math.clamp(health / math.max(humanoid.MaxHealth, 1), 0, 1)
        bar.Size = UDim2.fromScale(percent, 1)
        bar.BackgroundColor3 = percent > 0.5
            and Color3.fromRGB(0, 255, 100)
            or percent > 0.25
                and Color3.fromRGB(255, 200, 0)
                or Color3.fromRGB(255, 50, 50)
    end

    local healthConnection = humanoid.HealthChanged:Connect(updateHealth)
    table.insert(objects, {
        Destroy = function()
            healthConnection:Disconnect()
        end
    })

    updateHealth(humanoid.Health)
end

local function updateVisuals()
    if not Root then return end

    for player, objects in pairs(visualObjects) do
        local char = player.Character
        local targetRoot = char and char:FindFirstChild("HumanoidRootPart")
        local highlight = char and char:FindFirstChild("IzttNickHighlight")
        local billboard = char and char:FindFirstChild("IzttNickOverhead")

        local distance = targetRoot
            and (Root.Position - targetRoot.Position).Magnitude or math.huge

        local inRange = distance <= Settings.MaxESPDistance
        local sameTeam = player.Team ~= nil and player.Team == LP.Team

        local color = Settings.TeamColors and player.Team
            and player.Team.TeamColor.Color
            or sameTeam
                and Color3.fromRGB(0, 255, 100)
                or Color3.fromRGB(255, 60, 60)

        if highlight then
            highlight.Enabled = Settings.ESPEnabled and inRange
            highlight.FillColor = color
            highlight.OutlineColor = color
        end

        if billboard then
            billboard.Enabled = Settings.OverheadEnabled and inRange

            local label = billboard:FindFirstChild("NameLabel")
            if label then
                label.Text = string.format("%s [%d]", player.Name, math.floor(distance))
            end
        end
    end
end

local function watchPlayer(player)
    if player == LP then return end

    local function onCharacter(char)
        task.wait(0.5)
        if not running or not player.Parent then return end
        createPlayerVisuals(player, char)
    end

    if player.Character then
        task.spawn(onCharacter, player.Character)
    end

    connect(player.CharacterAdded, onCharacter, PlayerConnections)
end

for _, player in ipairs(Players:GetPlayers()) do
    watchPlayer(player)
end

connect(Players.PlayerAdded, watchPlayer)

connect(Players.PlayerRemoving, function(player)
    clearPlayerVisuals(player)
end)

connect(RunService.RenderStepped, updateVisuals)

--==================================================
-- UI CONTROLS
--==================================================

makeSlider(Movement, "Walk Speed", 1, 100, Settings.WalkSpeed, function(v)
    Settings.WalkSpeed = v
end)

makeSlider(Movement, "Jump Power", 1, 150, Settings.JumpPower, function(v)
    Settings.JumpPower = v
end)

makeSlider(Movement, "Sprint Speed", 16, 100, Settings.SprintSpeed, function(v)
    Settings.SprintSpeed = v
end)

makeSlider(Movement, "Fly Speed", 10, 150, Settings.FlySpeed, function(v)
    Settings.FlySpeed = v
end)

makeSlider(Movement, "Dash Power", 10, 150, Settings.DashPower, function(v)
    Settings.DashPower = v
end)

makeToggle(Movement, "Sprint", false, function(v)
    Settings.Sprint = v
end)

makeToggle(Movement, "Fly", false, setFly)
makeToggle(Movement, "Noclip", false, setNoclip)

makeToggle(Movement, "Infinite Jump", false, function(v)
    Settings.InfiniteJump = v
    if v then Settings.DoubleJump = false end
end)

makeToggle(Movement, "Double Jump", false, function(v)
    Settings.DoubleJump = v
    if v then Settings.InfiniteJump = false end
end)

makeToggle(Movement, "Low Gravity", false, function(v)
    Settings.LowGravity = v
    workspace.Gravity = v and 50 or Defaults.Gravity
end)

makeToggle(Movement, "Auto Run", false, function(v)
    Settings.AutoRun = v
end)

makeToggle(Visuals, "Player Highlights", false, function(v)
    Settings.ESPEnabled = v
end)

makeToggle(Visuals, "Name Tags & Health Bars", false, function(v)
    Settings.OverheadEnabled = v
end)

makeToggle(Visuals, "Team Colors", false, function(v)
    Settings.TeamColors = v
end)

makeSlider(Visuals, "ESP Max Distance", 50, 1000, Settings.MaxESPDistance, function(v)
    Settings.MaxESPDistance = v
end)

makeToggle(Visuals, "Crosshair", false, function(v)
    Settings.CrosshairEnabled = v
    updateCrosshair()
end)

makeSlider(Visuals, "Crosshair Size", 4, 25, Settings.CrosshairSize, function(v)
    Settings.CrosshairSize = v
    updateCrosshair()
end)

makeSlider(Visuals, "Crosshair Gap", 0, 15, Settings.CrosshairGap, function(v)
    Settings.CrosshairGap = v
    updateCrosshair()
end)

makeSlider(Visuals, "Crosshair Thickness", 1, 6, Settings.CrosshairThickness, function(v)
    Settings.CrosshairThickness = v
    updateCrosshair()
end)

makeButton(Utilities, "Dash", dash)
makeButton(Utilities, "Blink Forward", blink)

makeSlider(Utilities, "Blink Distance", 5, 100, Settings.BlinkDistance, function(v)
    Settings.BlinkDistance = v
end)

makeSlider(Utilities, "Camera FOV", 40, 120, originalFOV, function(v)
    if workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = v
    end
end)

makeButton(Utilities, "Restore Camera FOV", function()
    if workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = originalFOV
    end
end)

--==================================================
-- KEYBINDS
--==================================================

connect(UIS.InputBegan, function(input, processed)
    if processed then return end

    if input.KeyCode == Keybinds.Sprint then
        Settings.Sprint = true
    elseif input.KeyCode == Keybinds.Dash then
        dash()
    elseif input.KeyCode == Keybinds.Blink then
        blink()
    end
end)

connect(UIS.InputEnded, function(input)
    if input.KeyCode == Keybinds.Sprint then
        Settings.Sprint = false
    end
end)

makeButton(KeyPage, "Dash Key: Q", function()
    notify("Keybind", "Dash uses Q. Change it in the script Keybinds table.")
end)

makeButton(KeyPage, "Blink Key: E", function()
    notify("Keybind", "Blink uses E. Change it in the script Keybinds table.")
end)

makeButton(KeyPage, "Sprint Key: Left Shift", function()
    notify("Keybind", "Sprint uses Left Shift.")
end)

--==================================================
-- RESET / CLEANUP
--==================================================

local function resetHub()
    Settings.Sprint = false
    Settings.AutoRun = false
    Settings.InfiniteJump = false
    Settings.DoubleJump = false

    setFly(false)
    setNoclip(false)

    Settings.LowGravity = false
    workspace.Gravity = Defaults.Gravity

    Settings.ESPEnabled = false
    Settings.OverheadEnabled = false

    Settings.CrosshairEnabled = false
    updateCrosshair()

    Settings.WalkSpeed = Defaults.WalkSpeed
    Settings.JumpPower = Defaults.JumpPower
    Settings.SprintSpeed = Defaults.SprintSpeed
    Settings.FlySpeed = Defaults.FlySpeed
    Settings.DashPower = Defaults.DashPower
    Settings.BlinkDistance = Defaults.BlinkDistance
    Settings.MaxESPDistance = Defaults.MaxESPDistance

    if Humanoid and Humanoid.Parent then
        Humanoid.WalkSpeed = Defaults.WalkSpeed
        Humanoid.JumpPower = Defaults.JumpPower
    end

    if workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = originalFOV
    end

    notify("Reset", "Settings restored.")
end

makeButton(Utilities, "Reset All Settings", resetHub)

makeButton(Utilities, "Hide / Show Hub", function()
    Main.Visible = not Main.Visible
end)

makeButton(Utilities, "Close Hub", function()
    running = false

    setFly(false)
    restoreNoclip()

    workspace.Gravity = Defaults.Gravity

    if workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = originalFOV
    end

    for _, objects in pairs(visualObjects) do
        for _, object in ipairs(objects) do
            if object and object.Destroy then
                pcall(function() object:Destroy() end)
            end
        end
    end

    for _, connection in ipairs(Connections) do
        connection:Disconnect()
    end

    for _, connection in ipairs(PlayerConnections) do
        connection:Disconnect()
    end

    if crosshairGui then crosshairGui:Destroy() end
    Screen:Destroy()
end)

--==================================================
-- DRAG WINDOW
--==================================================

local dragging = false
local dragStart
local startPosition

connect(Title.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = Main.Position
    end
end)

connect(UIS.InputChanged, function(input)
    if dragging and (
        input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
    ) then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

connect(UIS.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

--==================================================
-- NOTIFICATION UI
--==================================================

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
message.TextWrapped = true
message.Font = Enum.Font.GothamBold
message.TextSize = 13
message.Visible = false
message.Parent = notificationGui

notify("IzttNick Hub V2.2", "Successfully loaded!")

print("IzttNick Hub V2.2 loaded successfully!")
