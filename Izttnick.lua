-- IzttNick Hub | Fully Fixed & Complete Edition for Xeno
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()
local Camera = workspace.CurrentCamera

-- Rayfield UI
local Rayfield = loadstring(game:HttpGet(
    "https://sirius.menu/rayfield"
))()

local Window = Rayfield:CreateWindow({
    Name = "IzttNick Hub",
    LoadingTitle = "IzttNick Hub",
    LoadingSubtitle = "Made by IzttNick",
    ConfigurationSaving = {Enabled = false},
    KeySystem = false
})

local Main = Window:CreateTab("Main", 4483362458)
local Combat = Window:CreateTab("Combat", 4483362458)
local Visuals = Window:CreateTab("Visuals", 4483362458)
local Perf = Window:CreateTab("Performance", 4483362458)
local Cross = Window:CreateTab("Crosshair", 4483362458)
local KeybindTab = Window:CreateTab("Keybinds", 4483362458)

-- State Variables
local character, humanoid, root
local walkSpeedValue, jumpPowerValue = 16, 50
local flySpeed, flying = 50, false
local flyConnection, flyVelocity, flyGyro
local noclipEnabled = false
local noclipConnection

-- ESP States
local espEnabled = false
local skeletonEspEnabled = false
local snaplineEspEnabled = false

local highlights = {}
local billboards = {}
local skeletonLines = {}
local snaplineObjects = {}

-- Custom Colors State
local espColor = Color3.fromRGB(255, 40, 40)
local skeletonColor = Color3.fromRGB(0, 255, 255)
local snaplineColor = Color3.fromRGB(255, 255, 255)

-- Keybind Manager Config
local keybinds = {
    Fly = Enum.KeyCode.T,
    Noclip = Enum.KeyCode.N
}

-- Combat / Auto Aim State
local autoAimEnabled = false
local aimbotHold = false
local aimPart = "Head"
local fovRadius = 150
local showFOV = false
local aimSmoothness = 0.2
local teamCheck = true
local wallCheck = false

-- Drawing FOV Circle
local FOVCircle = Drawing.new("Circle")
FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
FOVCircle.Radius = fovRadius
FOVCircle.Color = Color3.fromRGB(0, 255, 255)
FOVCircle.Thickness = 1.5
FOVCircle.Filled = false
FOVCircle.Visible = false

-- Setup Character
local function setupCharacter(char)
    character = char
    humanoid = char:WaitForChild("Humanoid")
    root = char:WaitForChild("HumanoidRootPart")
end

if LP.Character then
    task.spawn(setupCharacter, LP.Character)
end

LP.CharacterAdded:Connect(function(char)
    if flyConnection then flyConnection:Disconnect() flyConnection = nil end
    if flyVelocity then flyVelocity:Destroy() flyVelocity = nil end
    if flyGyro then flyGyro:Destroy() flyGyro = nil end
    flying = false
    setupCharacter(char)
end)

-- Permanent Movement Enforcement
RunService.Heartbeat:Connect(function()
    if humanoid and humanoid.Parent then
        humanoid.UseJumpPower = true
        humanoid.WalkSpeed = walkSpeedValue
        humanoid.JumpPower = jumpPowerValue
    end
end)

-- Walk Speed
Main:CreateInput({
    Name = "Walk Speed (1-300)",
    PlaceholderText = "16",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        local value = tonumber(text)
        if not value then return end
        walkSpeedValue = math.clamp(math.floor(value), 1, 300)
        if humanoid and humanoid.Parent then
            humanoid.WalkSpeed = walkSpeedValue
        end
    end
})

-- Jump Power
Main:CreateInput({
    Name = "Jump Power (1-300)",
    PlaceholderText = "50",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        local value = tonumber(text)
        if not value then return end
        jumpPowerValue = math.clamp(math.floor(value), 1, 300)
        if humanoid and humanoid.Parent then
            humanoid.UseJumpPower = true
            humanoid.JumpPower = jumpPowerValue
        end
    end
})

-- Noclip System
noclipConnection = RunService.Stepped:Connect(function()
    if noclipEnabled and character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

Main:CreateToggle({
    Name = "Noclip",
    CurrentValue = false,
    Callback = function(value)
        noclipEnabled = value
    end
})

-- Fly System
local function stopFly()
    flying = false
    if flyConnection then flyConnection:Disconnect() flyConnection = nil end
    if flyVelocity then flyVelocity:Destroy() flyVelocity = nil end
    if flyGyro then flyGyro:Destroy() flyGyro = nil end
end

local function setFly(value)
    if not value then
        stopFly()
        return
    end

    if flying or not root or not root.Parent then return end
    flying = true

    flyVelocity = Instance.new("BodyVelocity")
    flyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    flyVelocity.Velocity = Vector3.zero
    flyVelocity.Parent = root

    flyGyro = Instance.new("BodyGyro")
    flyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    flyGyro.P = 10000
    flyGyro.Parent = root

    flyConnection = RunService.RenderStepped:Connect(function()
        if not flying or not root or not root.Parent then
            stopFly()
            return
        end

        local cam = workspace.CurrentCamera
        if not cam then return end

        local direction = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then direction += cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then direction -= cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then direction -= cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then direction += cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then direction += Vector3.yAxis end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then direction -= Vector3.yAxis end

        flyVelocity.Velocity = direction.Magnitude > 0 and direction.Unit * flySpeed or Vector3.zero
        flyGyro.CFrame = cam.CFrame
    end)
end

Main:CreateSlider({
    Name = "Fly Speed",
    Range = {10, 200},
    Increment = 10,
    CurrentValue = 50,
    Callback = function(value)
        flySpeed = value
    end
})

Main:CreateToggle({
    Name = "Fly",
    CurrentValue = false,
    Callback = setFly
})

-- Auto Aim & Wall Checks
local function isPartVisible(targetPart)
    if not wallCheck then return true end
    local origin = Camera.CFrame.Position
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {LP.Character, targetPart.Parent}
    raycastParams.IgnoreWater = true

    local result = workspace:Raycast(origin, targetPart.Position - origin, raycastParams)
    return result == nil
end

local function getTargetPlayer()
    local closestTarget = nil
    local shortestDistance = fovRadius
    local mousePos = UIS:GetMouseLocation()

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LP then continue end
        if teamCheck and LP.Team and player.Team == LP.Team then continue end

        local char = player.Character
        if not char then continue end

        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end

        local targetPart = aimPart == "Random" and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")) or char:FindFirstChild(aimPart)
        if not targetPart then continue end

        local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
        if onScreen then
            local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
            if dist < shortestDistance and isPartVisible(targetPart) then
                shortestDistance = dist
                closestTarget = targetPart
            end
        end
    end
    return closestTarget
end

RunService.RenderStepped:Connect(function()
    local mousePos = UIS:GetMouseLocation()
    FOVCircle.Position = mousePos
    FOVCircle.Radius = fovRadius
    FOVCircle.Visible = showFOV and autoAimEnabled

    if autoAimEnabled and aimbotHold then
        local target = getTargetPlayer()
        if target then
            local targetPosition = target.Position
            local currentCFrame = Camera.CFrame
            local newDirection = (targetPosition - currentCFrame.Position).Unit
            local newCFrame = CFrame.new(currentCFrame.Position, currentCFrame.Position + newDirection)
            Camera.CFrame = currentCFrame:Lerp(newCFrame, aimSmoothness)
        end
    end
end)

Combat:CreateToggle({
    Name = "Enable Auto Aim",
    CurrentValue = false,
    Callback = function(value)
        autoAimEnabled = value
    end
})

Combat:CreateDropdown({
    Name = "Target Part",
    Options = {"Head", "HumanoidRootPart", "Random"},
    CurrentOption = "Head",
    Callback = function(value)
        aimPart = typeof(value) == "table" and value[1] or value
    end
})

Combat:CreateSlider({
    Name = "Aim Smoothness",
    Range = {0.05, 1},
    Increment = 0.05,
    CurrentValue = 0.2,
    Callback = function(value)
        aimSmoothness = value
    end
})

Combat:CreateToggle({
    Name = "Show FOV Circle",
    CurrentValue = false,
    Callback = function(value)
        showFOV = value
    end
})

Combat:CreateSlider({
    Name = "FOV Radius",
    Range = {50, 500},
    Increment = 10,
    CurrentValue = 150,
    Callback = function(value)
        fovRadius = value
    end
})

Combat:CreateToggle({
    Name = "Team Check",
    CurrentValue = true,
    Callback = function(value)
        teamCheck = value
    end
})

Combat:CreateToggle({
    Name = "Wall Check",
    CurrentValue = false,
    Callback = function(value)
        wallCheck = value
    end
})

-- ESP Cleanup Logic
local function clearESP(player)
    if highlights[player] then
        highlights[player]:Destroy()
        highlights[player] = nil
    end
    if billboards[player] then
        billboards[player]:Destroy()
        billboards[player] = nil
    end
    if skeletonLines[player] then
        for _, line in pairs(skeletonLines[player]) do
            line:Remove()
        end
        skeletonLines[player] = nil
    end
    if snaplineObjects[player] then
        snaplineObjects[player]:Remove()
        snaplineObjects[player] = nil
    end
end

local bonePairs = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"}
}

local function updateESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LP or (not espEnabled and not skeletonEspEnabled and not snaplineEspEnabled) then
            clearESP(player)
            continue
        end

        local char = player.Character
        local head = char and char:FindFirstChild("Head")
        local myRoot = root

        if not char or not head or not myRoot then
            clearESP(player)
            continue
        end

        -- Handle Box Highlights & Distance
        if espEnabled then
            local h = highlights[player]
            if not h or h.Parent ~= char then
                if h then h:Destroy() end
                h = Instance.new("Highlight")
                h.Name = "IzttNickTeamESP"
                h.Adornee = char
                h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                h.FillTransparency = 0.65
                h.OutlineTransparency = 0
                h.Parent = char
                highlights[player] = h
            end
            h.FillColor = espColor
            h.OutlineColor = espColor

            local bb = billboards[player]
            local textLabel
            if not bb then
                bb = Instance.new("BillboardGui")
                bb.Name = "DistanceIndicator"
                bb.Size = UDim2.fromOffset(100, 40)
                bb.StudsOffset = Vector3.new(0, 3, 0)
                bb.AlwaysOnTop = true
                bb.Adornee = head

                textLabel = Instance.new("TextLabel")
                textLabel.Size = UDim2.fromScale(1, 1)
                textLabel.BackgroundTransparency = 1
                textLabel.TextScaled = true
                textLabel.Font = Enum.Font.Code
                textLabel.Parent = bb
                bb.Parent = head
                billboards[player] = bb
            else
                textLabel = bb:FindFirstChildOfClass("TextLabel")
            end

            if textLabel and char:FindFirstChild("HumanoidRootPart") then
                local distance = math.floor((char.HumanoidRootPart.Position - myRoot.Position).Magnitude)
                textLabel.Text = string.format("[%s] (%d studs)", player.Name, distance)
                textLabel.TextColor3 = espColor
            end
        else
            if highlights[player] then highlights[player]:Destroy() highlights[player] = nil end
            if billboards[player] then billboards[player]:Destroy() billboards[player] = nil end
        end

        -- Handle Skeleton Tracers
        if skeletonEspEnabled then
            if not skeletonLines[player] then
                skeletonLines[player] = {}
                for i = 1, #bonePairs do
                    local l = Drawing.new("Line")
                    l.Thickness = 1.5
                    l.Visible = false
                    skeletonLines[player][i] = l
                end
            end

            local lines = skeletonLines[player]
            for i, pair in ipairs(bonePairs) do
                local line = lines[i]
                local partA = char:FindFirstChild(pair[1])
                local partB = char:FindFirstChild(pair[2])

                if partA and partB then
                    local posA, visA = Camera:WorldToViewportPoint(partA.Position)
                    local posB, visB = Camera:WorldToViewportPoint(partB.Position)

                    if visA or visB then
                        line.From = Vector2.new(posA.X, posA.Y)
                        line.To = Vector2.new(posB.X, posB.Y)
                        line.Color = skeletonColor
                        line.Visible = true
                    else
                        line.Visible = false
                    end
                else
                    line.Visible = false
                end
            end
        else
            if skeletonLines[player] then
                for _, line in pairs(skeletonLines[player]) do
                    line:Remove()
                end
                skeletonLines[player] = nil
            end
        end

        -- Handle Snaplines
        if snaplineEspEnabled then
            local rootPart = char:FindFirstChild("HumanoidRootPart")
            if rootPart then
                local screenPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
                local snapLine = snaplineObjects[player]
                if not snapLine then
                    snapLine = Drawing.new("Line")
                    snapLine.Thickness = 1
                    snaplineObjects[player] = snapLine
                end

                if onScreen then
                    snapLine.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                    snapLine.To = Vector2.new(screenPos.X, screenPos.Y)
                    snapLine.Color = snaplineColor
                    snapLine.Visible = true
                else
                    snapLine.Visible = false
                end
            end
        else
            if snaplineObjects[player] then
                snaplineObjects[player]:Remove()
                snaplineObjects[player] = nil
            end
        end
    end
end

-- Visuals Tab UI Controls
Visuals:CreateToggle({
    Name = "Team ESP + Distance",
    CurrentValue = false,
    Callback = function(value)
        espEnabled = value
        if not espEnabled then
            for _, player in ipairs(Players:GetPlayers()) do
                clearESP(player)
            end
        end
    end
})

Visuals:CreateColorPicker({
    Name = "ESP Color",
    Color = Color3.fromRGB(255, 40, 40),
    Flag = "ESPColorFlag",
    Callback = function(value)
        espColor = value
    end
})

Visuals:CreateToggle({
    Name = "Skeleton Tracing ESP",
    CurrentValue = false,
    Callback = function(value)
        skeletonEspEnabled = value
    end
})

Visuals:CreateColorPicker({
    Name = "Skeleton Color",
    Color = Color3.fromRGB(0, 255, 255),
    Flag = "SkeletonColorFlag",
    Callback = function(value)
        skeletonColor = value
    end
})

Visuals:CreateToggle({
    Name = "Snaplines ESP",
    CurrentValue = false,
    Callback = function(value)
        snaplineEspEnabled = value
    end
})

Visuals:CreateColorPicker({
    Name = "Snapline Color",
    Color = Color3.fromRGB(255, 255, 255),
    Flag = "SnaplineColorFlag",
    Callback = function(value)
        snaplineColor = value
    end
})

Players.PlayerRemoving:Connect(clearESP)

RunService.RenderStepped:Connect(function()
    if espEnabled or skeletonEspEnabled or snaplineEspEnabled then
        updateESP()
    end
end)

-- Performance Tab
local originalLighting = {
    GlobalShadows = Lighting.GlobalShadows,
    FogEnd = Lighting.FogEnd,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime
}

local fpsBoostEnabled = false
local autoBrightEnabled = false

local function applyLighting()
    if fpsBoostEnabled then
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
    else
        Lighting.GlobalShadows = originalLighting.GlobalShadows
        Lighting.FogEnd = originalLighting.FogEnd
    end

    if autoBrightEnabled then
        Lighting.Brightness = 3
        Lighting.ClockTime = 14
    else
        Lighting.Brightness = originalLighting.Brightness
        Lighting.ClockTime = originalLighting.ClockTime
    end
end

Perf:CreateToggle({
    Name = "FPS Boost",
    CurrentValue = false,
    Callback = function(value)
        fpsBoostEnabled = value
        applyLighting()
    end
})

Perf:CreateToggle({
    Name = "Auto Bright",
    CurrentValue = false,
    Callback = function(value)
        autoBrightEnabled = value
        applyLighting()
    end
})

-- Crosshair Tab
local GUI = Instance.new("ScreenGui")
GUI.Name = "IzttNickCrosshair"
GUI.ResetOnSpawn = false
GUI.IgnoreGuiInset = true
GUI.Parent = LP:WaitForChild("PlayerGui")

local CrossLabel = Instance.new("TextLabel")
CrossLabel.Name = "Crosshair"
CrossLabel.Size = UDim2.fromOffset(30, 30)
CrossLabel.Position = UDim2.fromScale(0.5, 0.5)
CrossLabel.AnchorPoint = Vector2.new(0.5, 0.5)
CrossLabel.BackgroundTransparency = 1
CrossLabel.Text = "+"
CrossLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
CrossLabel.TextScaled = true
CrossLabel.Font = Enum.Font.Code
CrossLabel.Parent = GUI

Cross:CreateToggle({
    Name = "Show Crosshair",
    CurrentValue = true,
    Callback = function(value)
        CrossLabel.Visible = value
    end
})

Cross:CreateDropdown({
    Name = "Crosshair Style",
    Options = {"+", ".", "x", "o"},
    CurrentOption = "+",
    Callback = function(value)
        CrossLabel.Text = typeof(value) == "table" and value[1] or value
    end
})

Cross:CreateSlider({
    Name = "Crosshair Size",
    Range = {10, 60},
    Increment = 2,
    CurrentValue = 30,
    Callback = function(value)
        CrossLabel.Size = UDim2.fromOffset(value, value)
    end
})

Cross:CreateDropdown({
    Name = "Crosshair Color",
    Options = {"Green", "Red", "White", "Cyan", "Yellow"},
    CurrentOption = "Green",
    Callback = function(value)
        value = typeof(value) == "table" and value[1] or value
        local colors = {
            Green = Color3.fromRGB(0, 255, 0),
            Red = Color3.fromRGB(255, 0, 0),
            White = Color3.fromRGB(255, 255, 255),
            Cyan = Color3.fromRGB(0, 255, 255),
            Yellow = Color3.fromRGB(255, 255, 0)
        }
        CrossLabel.TextColor3 = colors[value] or colors.Green
    end
})

-- Keybind Manager Tab UI
KeybindTab:CreateDropdown({
    Name = "Fly Key",
    Options = {"T", "F", "E", "X", "V"},
    CurrentOption = "T",
    Callback = function(value)
        value = typeof(value) == "table" and value[1] or value
        keybinds.Fly = Enum.KeyCode[value]
    end
})

KeybindTab:CreateDropdown({
    Name = "Noclip Key",
    Options = {"N", "G", "H", "J"},
    CurrentOption = "N",
    Callback = function(value)
        value = typeof(value) == "table" and value[1] or value
        keybinds.Noclip = Enum.KeyCode[value]
    end
})

-- Global Keybind Input Handler
UIS.InputBegan:Connect(function(input, processed)
    if processed then return end

    if input.KeyCode == keybinds.Fly then
        setFly(not flying)
    elseif input.KeyCode == keybinds.Noclip then
        noclipEnabled = not noclipEnabled
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
        aimbotHold = true
    end
end)

UIS.InputEnded:Connect(function(input, processed)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aimbotHold = false
    end
end)

print("IzttNick Hub fully loaded and ready!")
