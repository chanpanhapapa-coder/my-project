-- IzttNick Hub | Rayfield Edition (All Toggles Default OFF)
-- Press 'K' to Open / Close UI | 'Y' to Toggle Camera FOV | 'P' to Toggle Fullbright

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Stats = game:GetService("Stats")
local GuiService = game:GetService("GuiService")

local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera

if getgenv and getgenv().IzttNickHubRunning then
	warn("[IzttNick Hub] Already running. Execute only once.")
	return
end
if getgenv then
	getgenv().IzttNickHubRunning = true
end

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local function Notify(title, content, duration)
	task.spawn(function()
		pcall(function()
			Rayfield:Notify({
				Title = title or "IzttNick Hub",
				Content = content or "",
				Duration = duration or 3,
				Image = 4483362458
			})
		end)
	end)
end

-- =====================================================================
-- CONFIGURATION & WAYPOINTS SAVE / LOAD
-- =====================================================================
local WAYPOINTS_FILE = "IzttNickHub_Waypoints.json"

local keybinds = {
	Fly = Enum.KeyCode.T,
	Noclip = Enum.KeyCode.N
}

local savedWaypoints = {}

local function saveWaypoints()
	pcall(function()
		if writefile then
			local encoded = {}
			for name, cf in pairs(savedWaypoints) do
				encoded[name] = {cf:GetComponents()}
			end
			writefile(WAYPOINTS_FILE, HttpService:JSONEncode(encoded))
		end
	end)
end

local function loadWaypoints()
	pcall(function()
		if readfile and isfile and isfile(WAYPOINTS_FILE) then
			local decoded = HttpService:JSONDecode(readfile(WAYPOINTS_FILE))
			if type(decoded) == "table" then
				for name, comps in pairs(decoded) do
					if type(comps) == "table" and #comps == 12 then
						savedWaypoints[name] = CFrame.new(unpack(comps))
					end
				end
			end
		end
	end)
end

task.spawn(loadWaypoints)

-- =====================================================================
-- CREATE RAYFIELD WINDOW & TABS
-- =====================================================================
local Window = Rayfield:CreateWindow({
	Name = "IzttNick Hub | Rayfield",
	LoadingTitle = "IzttNick Hub",
	LoadingSubtitle = "Crafted for Performance",
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "IzttNickHub",
		FileName = "Config"
	},
	KeySystem = false,
	Keybind = "K"
})

local Main        = Window:CreateTab("Main", 4483362458)
local Combat      = Window:CreateTab("Combat", 4483362458)
local Visuals     = Window:CreateTab("Visuals", 4483362458)
local Perf        = Window:CreateTab("Performance", 4483362458)
local Cross       = Window:CreateTab("Crosshair", 4483362458)
local TeleportTab = Window:CreateTab("Teleport", 4483362458)
local WaypointTab = Window:CreateTab("Waypoints", 4483362458)
local KeybindTab  = Window:CreateTab("Keybinds", 4483362458)

-- =====================================================================
-- SCRIPT STATES & GAME LOGIC
-- =====================================================================
local character, humanoid, root
local flySpeed, flying = 50, false
local flyConnection, flyVelocity, flyGyro
local noclipEnabled = false
local normalGravity = workspace.Gravity

local noFallSlowEnabled = false
local fastVaultEnabled = false
local defaultWalkSpeed = 16
local fallStateConn = nil

local hitboxExpanderEnabled = false
local hitboxSize = 5

local snaplineEspEnabled = false
local rainbowCrosshair = false
local xrayEnabled = false
local touchImmunityEnabled = false

local fullbrightEnabled = false
local fullbrightToggle = nil
local originalLightingSettings = {
	Brightness = Lighting.Brightness,
	ClockTime = Lighting.ClockTime,
	GlobalShadows = Lighting.GlobalShadows,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	FogEnd = Lighting.FogEnd
}

local function applyFullbrightValues()
	Lighting.Brightness = 2
	Lighting.ClockTime = 14
	Lighting.GlobalShadows = false
	Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
	Lighting.FogEnd = 999999
end

local function restoreLightingValues()
	Lighting.Brightness = originalLightingSettings.Brightness
	Lighting.ClockTime = originalLightingSettings.ClockTime
	Lighting.GlobalShadows = originalLightingSettings.GlobalShadows
	Lighting.OutdoorAmbient = originalLightingSettings.OutdoorAmbient
	Lighting.FogEnd = originalLightingSettings.FogEnd
end

local function setFullbright(enabled)
	fullbrightEnabled = enabled and true or false
	if fullbrightEnabled then
		applyFullbrightValues()
	else
		restoreLightingValues()
	end
end

local fullbrightRefresh = 0
RunService.Heartbeat:Connect(function(dt)
	if not fullbrightEnabled then return end
	fullbrightRefresh += dt
	if fullbrightRefresh >= 0.5 then
		fullbrightRefresh = 0
		applyFullbrightValues()
	end
end)

-- =====================================================================
-- ASYMMETRIC / MAP ESP STATE & LOGIC
-- =====================================================================
local ESP = {
	Survivor = false,
	Killer = false,
	Generator = false,
	Pallet = false,
	Window = false,
	Distance = 1000
}

local TeamColors = {
	Killer = Color3.fromRGB(255, 60, 60),
	Survivor = Color3.fromRGB(60, 140, 255)
}

local GeneratorColor = Color3.fromRGB(60, 255, 120)
local PalletColor = Color3.fromRGB(255, 235, 0)
local WindowColor = Color3.fromRGB(255, 145, 0)

local function getRoot()
	if root and root.Parent then
		return root
	end
	if LP.Character then
		root = LP.Character:FindFirstChild("HumanoidRootPart")
		return root
	end
	return nil
end

local function getObjectPosition(obj)
	if not obj or not obj.Parent then return nil end
	if obj:IsA("Model") then
		return obj:GetPivot().Position
	elseif obj:IsA("BasePart") then
		return obj.Position
	end
	return nil
end

local ESPObjects = {}

local function removeESP(obj)
	if ESPObjects[obj] then
		ESPObjects[obj]:Destroy()
		ESPObjects[obj] = nil
	end
end

local function createESP(obj, color)
	if not obj then return end

	if ESPObjects[obj] then
		ESPObjects[obj].FillColor = color
		ESPObjects[obj].OutlineColor = color
		return
	end

	local h = Instance.new("Highlight")
	h.FillColor = color
	h.OutlineColor = color
	h.FillTransparency = 0.9
	h.OutlineTransparency = 0.3
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = obj

	ESPObjects[obj] = h

	obj.AncestryChanged:Connect(function(_, parent)
		if not parent then
			removeESP(obj)
		end
	end)
end

local function GetGameValue(obj, name)
	if not obj then return nil end

	local attr = obj:GetAttribute(name)
	if attr ~= nil then return attr end

	local child = obj:FindFirstChild(name)
	if child then
		local ok, val = pcall(function() return child.Value end)
		if ok then return val end
	end

	return nil
end

local function ApplyGenHighlight(object, color)
	local h = object:FindFirstChild("GenHighlight") or Instance.new("Highlight")
	h.Name = "GenHighlight"
	h.Adornee = object
	h.FillColor = color
	h.OutlineColor = color
	h.FillTransparency = 0.9
	h.OutlineTransparency = 0.3
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = object
end

local function CreateBillboard(text, color)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GenESP"
	billboard.Size = UDim2.new(0, 100, 0, 30)
	billboard.AlwaysOnTop = true

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.Parent = billboard

	return billboard
end

local function UpdateGenerator(generator, currentRoot)
	if not generator or not generator.Parent then return end

	local pos = getObjectPosition(generator)
	local withinRange = (not currentRoot) or (not pos) or ((pos - currentRoot.Position).Magnitude <= ESP.Distance)

	if not ESP.Generator or not withinRange then
		local old = generator:FindFirstChild("GenESP")
		if old then old:Destroy() end

		local h = generator:FindFirstChild("GenHighlight")
		if h then h:Destroy() end
		return
	end

	local percent = GetGameValue(generator, "RepairProgress") or GetGameValue(generator, "Progress") or 0
	local billboard = generator:FindFirstChild("GenESP")

	if percent >= 100 then
		if billboard then billboard:Destroy() end
		return
	end

	local text = string.format("[%.0f%%]", percent)

	if not billboard then
		billboard = CreateBillboard(text, GeneratorColor)
		billboard.Adornee = generator
		billboard.Parent = generator
	else
		local lbl = billboard:FindFirstChildOfClass("TextLabel")
		if lbl then
			lbl.Text = text
			lbl.TextColor3 = GeneratorColor
		end
	end

	ApplyGenHighlight(generator, GeneratorColor)
end

local function UpdateMapESP(obj, currentRoot)
	if not obj or not currentRoot then return end
	local pos = getObjectPosition(obj)
	if not pos then return end

	local distance = (pos - currentRoot.Position).Magnitude

	if obj.Name == "Window" then
		if ESP.Window and distance <= ESP.Distance then
			createESP(obj, WindowColor)
		else
			removeESP(obj)
		end
	elseif obj.Name == "Pallet" or obj.Name == "Palletwrong" then
		if ESP.Pallet and distance <= ESP.Distance then
			createESP(obj, PalletColor)
		else
			removeESP(obj)
		end
	end
end

local Cached = {
	Generators = {},
	Windows = {},
	Pallets = {}
}

local function cacheObject(obj)
	if obj.Name == "Generator" then
		Cached.Generators[obj] = true
	elseif obj.Name == "Window" then
		Cached.Windows[obj] = true
	elseif obj.Name == "Pallet" or obj.Name == "Palletwrong" then
		Cached.Pallets[obj] = true
	end
end

local function removeCache(obj)
	Cached.Generators[obj] = nil
	Cached.Windows[obj] = nil
	Cached.Pallets[obj] = nil
end

task.spawn(function()
	local descendants = workspace:GetDescendants()
	for i, obj in ipairs(descendants) do
		cacheObject(obj)
		if i % 500 == 0 then
			task.wait()
		end
	end
end)

workspace.DescendantAdded:Connect(cacheObject)
workspace.DescendantRemoving:Connect(removeCache)

local lastESPUpdate = 0
RunService.RenderStepped:Connect(function()
	local currentRoot = getRoot()
	if not currentRoot then return end

	local now = tick()
	if now - lastESPUpdate >= 0.05 then
		lastESPUpdate = now

		for _, p in pairs(Players:GetPlayers()) do
			if p ~= LP and p.Character then
				local char = p.Character
				local hum = char:FindFirstChildOfClass("Humanoid")
				local hrp = char:FindFirstChild("HumanoidRootPart")

				if hum and hum.Health > 0 and hrp then
					local distance = (hrp.Position - currentRoot.Position).Magnitude
					if distance <= ESP.Distance then
						if ESP.Survivor and p.Team and p.Team.Name == "Survivors" then
							createESP(char, TeamColors.Survivor)
						elseif ESP.Killer and p.Team and p.Team.Name == "Killer" then
							createESP(char, TeamColors.Killer)
						else
							removeESP(char)
						end
					else
						removeESP(char)
					end
				else
					removeESP(char)
				end
			end
		end

		for gen in pairs(Cached.Generators) do
			UpdateGenerator(gen, currentRoot)
		end

		for obj in pairs(Cached.Windows) do
			UpdateMapESP(obj, currentRoot)
		end

		for obj in pairs(Cached.Pallets) do
			UpdateMapESP(obj, currentRoot)
		end
	end
end)

-- =====================================================================
-- NO FALL SLOW & FAST VAULT (WINDOW & PALLET)
-- =====================================================================
local function applyNoFallSlow(hum)
	if not noFallSlowEnabled or not hum or hum.Health <= 0 then return end
	if hum.WalkSpeed < defaultWalkSpeed and not flying then
		hum.WalkSpeed = defaultWalkSpeed
	end
end

local function bindFallSlowHandler(hum)
	if fallStateConn then
		fallStateConn:Disconnect()
		fallStateConn = nil
	end
	if not hum then return end
	defaultWalkSpeed = hum.WalkSpeed > 0 and hum.WalkSpeed or 16
	fallStateConn = hum.StateChanged:Connect(function(_, newState)
		if not noFallSlowEnabled then return end
		if newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running then
			task.defer(function()
				applyNoFallSlow(hum)
			end)
		end
	end)
end

local function processFastVault(currentRoot)
	if not fastVaultEnabled or not currentRoot then return end

	local vaultCollections = {Cached.Windows, Cached.Pallets}
	for _, collection in ipairs(vaultCollections) do
		for vaultObj in pairs(collection) do
			local pos = getObjectPosition(vaultObj)
			if pos and (pos - currentRoot.Position).Magnitude <= 14 then
				for _, desc in ipairs(vaultObj:GetDescendants()) do
					if desc:IsA("ProximityPrompt") then
						if desc.HoldDuration > 0.02 then
							desc.HoldDuration = 0.02
						end
						if desc.Enabled and (desc.ObjectText ~= "" or desc.ActionText ~= "") then
							pcall(function()
								if fireproximityprompt then
									fireproximityprompt(desc)
								end
							end)
						end
					end
				end
				if character then
					for _, track in ipairs(character:GetDescendants()) do
						if track:IsA("AnimationTrack") then
							local lowerName = string.lower(track.Name)
							if string.find(lowerName, "vault", 1, true)
								or string.find(lowerName, "pallet", 1, true)
								or string.find(lowerName, "window", 1, true) then
								pcall(function()
									track:AdjustSpeed(2.2)
								end)
							end
						end
					end
				end
			end
		end
	end
end

RunService.Heartbeat:Connect(function()
	if noFallSlowEnabled and humanoid then
		applyNoFallSlow(humanoid)
	end
	if fastVaultEnabled then
		local currentRoot = getRoot()
		if currentRoot then
			processFastVault(currentRoot)
		end
	end
end)

-- =====================================================================
-- AUTO SKILL CHECK
-- =====================================================================
local autoSkillCheckEnabled = false
local skillCheckBusy = false
local skillCheckConnection = nil
local SkillCheckTouchID = 8822
local SkillCheckActionPath = "Survivor-mob.Controls.action.check"

local function pressSkillCheckSpace()
	VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
	task.wait()
	VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
end

local function getSkillCheckActionTarget()
	local playerGui = LP:FindFirstChild("PlayerGui")
	if not playerGui then return nil end

	local current = playerGui
	for segment in string.gmatch(SkillCheckActionPath, "[^%.]+") do
		current = current and current:FindFirstChild(segment)
	end
	return current
end

local function triggerSkillCheckMobileButton()
	local btn = getSkillCheckActionTarget()
	if btn and btn:IsA("GuiObject") then
		local pos = btn.AbsolutePosition
		local size = btn.AbsoluteSize
		local inset = GuiService:GetGuiInset()
		local cx = pos.X + (size.X / 2) + inset.X
		local cy = pos.Y + (size.Y / 2) + inset.Y

		pcall(function()
			VirtualInputManager:SendTouchEvent(SkillCheckTouchID, 0, cx, cy)
			task.wait(0.01)
			VirtualInputManager:SendTouchEvent(SkillCheckTouchID, 2, cx, cy)
		end)
	end
end

local function startSkillCheck()
	if skillCheckConnection then
		skillCheckConnection:Disconnect()
		skillCheckConnection = nil
	end

	skillCheckConnection = RunService.RenderStepped:Connect(function()
		if not autoSkillCheckEnabled or skillCheckBusy then return end

		local playerGui = LP:FindFirstChild("PlayerGui")
		if not playerGui then return end

		local prompt = playerGui:FindFirstChild("SkillCheckPromptGui")
		if not prompt then return end

		local check = prompt:FindFirstChild("Check")
		if not check or not check.Visible then return end

		local line = check:FindFirstChild("Line")
		local goal = check:FindFirstChild("Goal")
		if not line or not goal then return end

		local lr = line.Rotation % 360
		local gr = goal.Rotation % 360

		local startRange = (gr + 102) % 360
		local endRange = (gr + 116) % 360

		local success =
			(startRange > endRange and (lr >= startRange or lr <= endRange))
			or (lr >= startRange and lr <= endRange)

		if success then
			skillCheckBusy = true
			task.spawn(function()
				if UIS.TouchEnabled then
					triggerSkillCheckMobileButton()
				else
					pressSkillCheckSpace()
				end
				task.wait(0.05)
				skillCheckBusy = false
			end)
		end
	end)
end

local function stopSkillCheck()
	autoSkillCheckEnabled = false
	skillCheckBusy = false
	if skillCheckConnection then
		skillCheckConnection:Disconnect()
		skillCheckConnection = nil
	end
end

-- =====================================================================
-- ANTI-AFK & AUTO REJOIN
-- =====================================================================
local autoRejoinEnabled = false

LP.Idled:Connect(function()
	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.new())
end)

GuiService.ErrorMessageChanged:Connect(function()
	if autoRejoinEnabled then
		task.wait(2)
		TeleportService:Teleport(game.PlaceId, LP)
	end
end)

-- =====================================================================
-- CAMERA FOV & AIMBOT STATE
-- =====================================================================
local autoAimEnabled = false
local aimbotHold = false
local aimPart = "Head"
local fovRadius = 150
local showFOV = false
local aimSmoothness = 0.2
local teamCheck = false
local wallCheck = false

local cameraFovEnabled = false
local cameraFovValue = 120
local originalCameraFov = (workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView) or 70

UIS.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Y then
		cameraFovEnabled = not cameraFovEnabled
		local currentCamera = workspace.CurrentCamera
		if currentCamera then
			currentCamera.FieldOfView = cameraFovEnabled and cameraFovValue or originalCameraFov
		end
		Notify("Camera FOV", cameraFovEnabled and ("FOV ON — " .. tostring(cameraFovValue)) or "FOV OFF", 2)
	end
end)

local FOVCircle
pcall(function()
	if Drawing and Drawing.new then
		FOVCircle = Drawing.new("Circle")
		FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
		FOVCircle.Radius = fovRadius
		FOVCircle.Color = Color3.fromRGB(0, 255, 255)
		FOVCircle.Thickness = 1.5
		FOVCircle.Filled = false
		FOVCircle.Visible = false
	end
end)

local function stopFly()
	flying = false
	if flyConnection then flyConnection:Disconnect() flyConnection = nil end
	if flyVelocity then flyVelocity:Destroy() flyVelocity = nil end
	if flyGyro then flyGyro:Destroy() flyGyro = nil end
end

local function setupCharacter(char)
	task.spawn(function()
		character = char
		humanoid = char:WaitForChild("Humanoid", 15)
		root = char:WaitForChild("HumanoidRootPart", 15)
		if humanoid then
			bindFallSlowHandler(humanoid)
		end
	end)
end

if LP.Character then
	setupCharacter(LP.Character)
end

LP.CharacterAdded:Connect(function(char)
	stopFly()
	setupCharacter(char)
end)

RunService.Stepped:Connect(function()
	if noclipEnabled and character then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then part.CanCollide = false end
		end
	end
	if touchImmunityEnabled and character then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then part.CanTouch = false end
		end
	end
end)

RunService.Heartbeat:Connect(function()
	if hitboxExpanderEnabled then
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LP and player.Character then
				local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
				if rootPart then
					rootPart.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
					rootPart.Transparency = 0.7
					rootPart.CanCollide = false
				end
			end
		end
	end
end)

-- =====================================================================
-- MAIN TAB
-- =====================================================================
Main:CreateSection("Movement & Physics")
Main:CreateToggle({
	Name = "Noclip",
	CurrentValue = false,
	Flag = "NoclipToggle",
	Callback = function(value)
		noclipEnabled = value
	end
})

Main:CreateToggle({
	Name = "Low Gravity",
	CurrentValue = false,
	Flag = "LowGravityToggle",
	Callback = function(value)
		workspace.Gravity = value and 50 or normalGravity
	end
})

Main:CreateToggle({
	Name = "No Fall Slow",
	CurrentValue = false,
	Flag = "NoFallSlowToggle",
	Callback = function(value)
		noFallSlowEnabled = value
		if value and humanoid then
			applyNoFallSlow(humanoid)
		end
	end
})

Main:CreateToggle({
	Name = "Fast Vault Window & Pallet",
	CurrentValue = false,
	Flag = "FastVaultToggle",
	Callback = function(value)
		fastVaultEnabled = value
	end
})

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

Main:CreateSection("Flight & Camera")
Main:CreateSlider({
	Name = "Fly Speed",
	Range = {1, 500},
	Increment = 10,
	Suffix = " studs/s",
	CurrentValue = 50,
	Flag = "FlySpeedSlider",
	Callback = function(value)
		flySpeed = value
	end
})

Main:CreateToggle({
	Name = "Fly",
	CurrentValue = false,
	Flag = "FlyToggle",
	Callback = setFly
})

Main:CreateSlider({
	Name = "Camera FOV (Y Toggle)",
	Range = {70, 120},
	Increment = 1,
	Suffix = " FOV",
	CurrentValue = 120,
	Flag = "CameraFovSlider",
	Callback = function(value)
		cameraFovValue = value
		if cameraFovEnabled and workspace.CurrentCamera then
			workspace.CurrentCamera.FieldOfView = value
		end
	end
})

Main:CreateButton({
	Name = "Unlock Max Camera Zoom",
	Callback = function()
		LP.CameraMaxZoomDistance = 10000
		Notify("Zoom Unlocked", "You can now zoom out infinitely!", 3)
	end
})

Main:CreateSection("Skill Checks")
Main:CreateToggle({
	Name = "Auto Skill Check",
	CurrentValue = false,
	Flag = "AutoSkillCheckToggle",
	Callback = function(value)
		autoSkillCheckEnabled = value
		if value then
			startSkillCheck()
		else
			stopSkillCheck()
		end
	end
})

-- =====================================================================
-- COMBAT TAB
-- =====================================================================
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
		local targetPart = aimPart == "Random"
			and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
			or char:FindFirstChild(aimPart)
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

Combat:CreateSection("Auto Aim (Hold Right-Click)")
Combat:CreateToggle({
	Name = "Enable Auto Aim",
	CurrentValue = false,
	Flag = "AutoAimToggle",
	Callback = function(value) autoAimEnabled = value end
})

Combat:CreateDropdown({
	Name = "Target Part",
	Options = {"Head", "HumanoidRootPart", "Random"},
	CurrentOption = {"Head"},
	MultipleOptions = false,
	Flag = "AimPartDropdown",
	Callback = function(value)
		aimPart = type(value) == "table" and value[1] or value
	end
})

Combat:CreateSlider({
	Name = "Aim Smoothness",
	Range = {0.05, 1},
	Increment = 0.05,
	Suffix = "",
	CurrentValue = 0.2,
	Flag = "AimSmoothnessSlider",
	Callback = function(value) aimSmoothness = value end
})

Combat:CreateToggle({
	Name = "Show FOV Circle",
	CurrentValue = false,
	Flag = "ShowFovToggle",
	Callback = function(value) showFOV = value end
})

Combat:CreateSlider({
	Name = "FOV Radius",
	Range = {50, 500},
	Increment = 10,
	Suffix = " px",
	CurrentValue = 150,
	Flag = "FovRadiusSlider",
	Callback = function(value) fovRadius = value end
})

Combat:CreateToggle({
	Name = "Team Check",
	CurrentValue = false,
	Flag = "TeamCheckToggle",
	Callback = function(value) teamCheck = value end
})

Combat:CreateToggle({
	Name = "Wall Check",
	CurrentValue = false,
	Flag = "WallCheckToggle",
	Callback = function(value) wallCheck = value end
})

Combat:CreateSection("Hitbox Modification")
Combat:CreateToggle({
	Name = "Hitbox Expander",
	CurrentValue = false,
	Flag = "HitboxExpanderToggle",
	Callback = function(value) hitboxExpanderEnabled = value end
})

Combat:CreateSlider({
	Name = "Hitbox Size",
	Range = {2, 20},
	Increment = 1,
	Suffix = " studs",
	CurrentValue = 5,
	Flag = "HitboxSizeSlider",
	Callback = function(value) hitboxSize = value end
})

-- =====================================================================
-- VISUALS TAB
-- =====================================================================
local snaplineObjects = {}
local snaplineColor = Color3.fromRGB(255, 255, 255)

local function clearSnapline(player)
	if snaplineObjects[player] then
		snaplineObjects[player]:Remove()
		snaplineObjects[player] = nil
	end
end

local function updateSnaplines()
	for _, player in ipairs(Players:GetPlayers()) do
		if player == LP or not snaplineEspEnabled then
			clearSnapline(player)
			continue
		end
		local char = player.Character
		local rootPart = char and char:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			clearSnapline(player)
			continue
		end

		local snapLine = snaplineObjects[player]
		if not snapLine then
			local ok, line = pcall(function()
				if Drawing and Drawing.new then
					local obj = Drawing.new("Line")
					obj.Thickness = 1
					return obj
				end
			end)
			if ok and line then
				snapLine = line
				snaplineObjects[player] = snapLine
			else
				continue
			end
		end

		local screenPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
		if onScreen then
			snapLine.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
			snapLine.To = Vector2.new(screenPos.X, screenPos.Y)
			if player.Team and player.Team.Name == "Killer" then
				snapLine.Color = TeamColors.Killer
			elseif player.Team and player.Team.Name == "Survivors" then
				snapLine.Color = TeamColors.Survivor
			else
				snapLine.Color = snaplineColor
			end
			snapLine.Visible = true
		else
			snapLine.Visible = false
		end
	end
end

Players.PlayerRemoving:Connect(clearSnapline)

local ESPColorPresets = {
	Red = Color3.fromRGB(255, 45, 45),
	Blue = Color3.fromRGB(45, 130, 255),
	White = Color3.fromRGB(255, 255, 255),
	Green = Color3.fromRGB(45, 235, 110),
	Purple = Color3.fromRGB(180, 75, 255),
	Yellow = Color3.fromRGB(255, 220, 45),
	Cyan = Color3.fromRGB(0, 235, 220),
	Orange = Color3.fromRGB(255, 145, 35),
	Pink = Color3.fromRGB(255, 90, 190)
}

local function parseRGB(text)
	local r, g, b = text:match("(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")
	if r and g and b then
		return Color3.fromRGB(
			math.clamp(tonumber(r), 0, 255),
			math.clamp(tonumber(g), 0, 255),
			math.clamp(tonumber(b), 0, 255)
		)
	end
	return nil
end

local function createESPControls(label, setter)
	Visuals:CreateDropdown({
		Name = label .. " Color Preset",
		Options = {"Red", "Blue", "White", "Green", "Purple", "Yellow", "Cyan", "Orange", "Pink"},
		CurrentOption = {"Red"},
		MultipleOptions = false,
		Flag = label .. "PresetDropdown",
		Callback = function(preset)
			local choice = type(preset) == "table" and preset[1] or preset
			local color = ESPColorPresets[choice]
			if color then
				setter(color)
				Notify(label .. " Color", label .. " ESP set to " .. choice .. ".", 2)
			end
		end
	})

	Visuals:CreateInput({
		Name = label .. " Custom RGB (R,G,B)",
		CurrentValue = "",
		PlaceholderText = "255, 40, 40",
		RemoveTextAfterFocusLost = false,
		Flag = label .. "RGBInput",
		Callback = function(text)
			local parsed = parseRGB(text)
			if parsed then
				setter(parsed)
				Notify(label .. " Color", "Updated " .. label .. " RGB color.", 2)
			end
		end
	})
end

Visuals:CreateSection("Player Tracker Lines")
Visuals:CreateToggle({
	Name = "Enable Tracker Lines",
	CurrentValue = false,
	Flag = "TrackerLinesToggle",
	Callback = function(value)
		snaplineEspEnabled = value
		if not value then
			for _, line in pairs(snaplineObjects) do
				line.Visible = false
			end
		else
			updateSnaplines()
		end
	end
})

Visuals:CreateSection("Killer, Survivor & Map Object ESP")
Visuals:CreateToggle({
	Name = "ESP Survivor",
	CurrentValue = false,
	Flag = "EspSurvivorToggle",
	Callback = function(v) ESP.Survivor = v end
})
createESPControls("Survivor", function(c) TeamColors.Survivor = c end)

Visuals:CreateToggle({
	Name = "ESP Killer",
	CurrentValue = false,
	Flag = "EspKillerToggle",
	Callback = function(v) ESP.Killer = v end
})
createESPControls("Killer", function(c) TeamColors.Killer = c end)

Visuals:CreateToggle({
	Name = "Generator ESP",
	CurrentValue = false,
	Flag = "EspGenToggle",
	Callback = function(v) ESP.Generator = v end
})
createESPControls("Generator", function(c) GeneratorColor = c end)

Visuals:CreateToggle({
	Name = "Pallet ESP",
	CurrentValue = false,
	Flag = "EspPalletToggle",
	Callback = function(v) ESP.Pallet = v end
})
createESPControls("Pallet", function(c) PalletColor = c end)

Visuals:CreateToggle({
	Name = "Window ESP",
	CurrentValue = false,
	Flag = "EspWindowToggle",
	Callback = function(v) ESP.Window = v end
})
createESPControls("Window", function(c) WindowColor = c end)

Visuals:CreateSlider({
	Name = "ESP Radius",
	Range = {10, 1000},
	Increment = 10,
	Suffix = " studs",
	CurrentValue = 1000,
	Flag = "EspRadiusSlider",
	Callback = function(v) ESP.Distance = v end
})

Visuals:CreateSection("World & Environment")
fullbrightToggle = Visuals:CreateToggle({
	Name = "Auto Fullbright & Clear Fog (P)",
	CurrentValue = false,
	Flag = "FullbrightToggle",
	Callback = function(value)
		setFullbright(value)
	end
})

Visuals:CreateToggle({
	Name = "X-Ray Mode (Walls Transparency)",
	CurrentValue = false,
	Flag = "XrayToggle",
	Callback = function(value)
		xrayEnabled = value
		for _, object in ipairs(workspace:GetDescendants()) do
			if object:IsA("BasePart")
				and LP.Character
				and not object:IsDescendantOf(LP.Character)
				and not object.Parent:FindFirstChildOfClass("Humanoid") then
				object.LocalTransparencyModifier = xrayEnabled and 0.6 or 0
			end
		end
	end
})

Visuals:CreateToggle({
	Name = "Hazard Immunity (Disable Touch)",
	CurrentValue = false,
	Flag = "TouchImmunityToggle",
	Callback = function(value)
		touchImmunityEnabled = value
		if not touchImmunityEnabled and character then
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") then part.CanTouch = true end
			end
		end
	end
})

Visuals:CreateSlider({
	Name = "Custom Clock Time",
	Range = {0, 24},
	Increment = 1,
	Suffix = " hr",
	CurrentValue = 14,
	Flag = "ClockTimeSlider",
	Callback = function(value)
		Lighting.ClockTime = value
	end
})

-- =====================================================================
-- PERFORMANCE TAB
-- =====================================================================
local fpsBoostEnabled = false
local showPerformanceOverlay = false

Perf:CreateSection("Optimization")
Perf:CreateToggle({
	Name = "FPS Boost",
	CurrentValue = false,
	Flag = "FpsBoostToggle",
	Callback = function(value)
		fpsBoostEnabled = value
		if fpsBoostEnabled then
			Lighting.GlobalShadows = false
			Lighting.FogEnd = 100000
		elseif not fullbrightEnabled then
			Lighting.GlobalShadows = originalLightingSettings.GlobalShadows
			Lighting.FogEnd = originalLightingSettings.FogEnd
		end
	end
})

local StatsGui, StatsLabel

Perf:CreateToggle({
	Name = "Show FPS & Ping Overlay",
	CurrentValue = false,
	Flag = "PerfOverlayToggle",
	Callback = function(value)
		showPerformanceOverlay = value
		if value and not StatsLabel then
			task.spawn(function()
				local guiParent = LP:FindFirstChild("PlayerGui") or LP:WaitForChild("PlayerGui", 10)
				if not guiParent then return end
				StatsGui = Instance.new("ScreenGui")
				StatsGui.Name = "IzttNickStats"
				StatsGui.ResetOnSpawn = false
				StatsGui.Parent = guiParent

				StatsLabel = Instance.new("TextLabel")
				StatsLabel.Name = "StatsLabel"
				StatsLabel.Size = UDim2.fromOffset(180, 26)
				StatsLabel.Position = UDim2.fromScale(0.01, 0.01)
				StatsLabel.BackgroundTransparency = 0.35
				StatsLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
				StatsLabel.TextColor3 = Color3.fromRGB(0, 255, 200)
				StatsLabel.TextSize = 13
				StatsLabel.Font = Enum.Font.Code
				StatsLabel.Text = "FPS: -- | Ping: --ms"
				StatsLabel.Visible = showPerformanceOverlay
				StatsLabel.Parent = StatsGui

				local statsCorner = Instance.new("UICorner")
				statsCorner.CornerRadius = UDim.new(0, 6)
				statsCorner.Parent = StatsLabel
			end)
		elseif StatsLabel then
			StatsLabel.Visible = value
		end
	end
})

local frameCount = 0
local lastCheck = tick()
RunService.RenderStepped:Connect(function()
	if cameraFovEnabled and workspace.CurrentCamera then
		workspace.CurrentCamera.FieldOfView = cameraFovValue
	end

	local mousePos = UIS:GetMouseLocation()
	if FOVCircle then
		pcall(function()
			FOVCircle.Position = mousePos
			FOVCircle.Radius = fovRadius
			FOVCircle.Visible = showFOV and autoAimEnabled
		end)
	end

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

	if snaplineEspEnabled then
		updateSnaplines()
	end

	if rainbowCrosshair and CrossLabel then
		local hue = (tick() * 2) % 1
		CrossLabel.TextColor3 = Color3.fromHSV(hue, 1, 1)
	end

	frameCount += 1
	local now = tick()
	if now - lastCheck >= 1 then
		local fps = math.floor(frameCount / (now - lastCheck))
		frameCount = 0
		lastCheck = now
		if showPerformanceOverlay and StatsLabel then
			local ping = 0
			pcall(function()
				ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
			end)
			StatsLabel.Text = string.format("FPS: %d | Ping: %dms", fps, ping)
		end
	end
end)

-- =====================================================================
-- CROSSHAIR TAB
-- =====================================================================
local GUI, CrossLabel

task.spawn(function()
	local guiParent = LP:FindFirstChild("PlayerGui") or LP:WaitForChild("PlayerGui", 10)
	if not guiParent then return end
	GUI = Instance.new("ScreenGui")
	GUI.Name = "IzttNickCrosshair"
	GUI.ResetOnSpawn = false
	GUI.IgnoreGuiInset = true
	GUI.Parent = guiParent

	CrossLabel = Instance.new("TextLabel")
	CrossLabel.Name = "Crosshair"
	CrossLabel.Size = UDim2.fromOffset(30, 30)
	CrossLabel.Position = UDim2.fromScale(0.5, 0.5)
	CrossLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	CrossLabel.BackgroundTransparency = 1
	CrossLabel.Text = "+"
	CrossLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
	CrossLabel.TextScaled = true
	CrossLabel.Font = Enum.Font.Code
	CrossLabel.Visible = false
	CrossLabel.Parent = GUI
end)

Cross:CreateSection("Crosshair Customization")
Cross:CreateToggle({
	Name = "Show Crosshair",
	CurrentValue = false,
	Flag = "ShowCrosshairToggle",
	Callback = function(value)
		if CrossLabel then CrossLabel.Visible = value end
	end
})

Cross:CreateDropdown({
	Name = "Crosshair Style",
	Options = {"+", ".", "x", "o"},
	CurrentOption = {"+"},
	MultipleOptions = false,
	Flag = "CrosshairStyleDropdown",
	Callback = function(value)
		if CrossLabel then
			CrossLabel.Text = type(value) == "table" and value[1] or value
		end
	end
})

Cross:CreateSlider({
	Name = "Crosshair Size",
	Range = {10, 60},
	Increment = 2,
	Suffix = " px",
	CurrentValue = 30,
	Flag = "CrosshairSizeSlider",
	Callback = function(value)
		if CrossLabel then CrossLabel.Size = UDim2.fromOffset(value, value) end
	end
})

Cross:CreateDropdown({
	Name = "Crosshair Color",
	Options = {"Green", "Red", "White", "Cyan", "Yellow"},
	CurrentOption = {"Green"},
	MultipleOptions = false,
	Flag = "CrosshairColorDropdown",
	Callback = function(value)
		if not CrossLabel then return end
		local choice = type(value) == "table" and value[1] or value
		local colors = {
			Green = Color3.fromRGB(0, 255, 0),
			Red = Color3.fromRGB(255, 0, 0),
			White = Color3.fromRGB(255, 255, 255),
			Cyan = Color3.fromRGB(0, 255, 255),
			Yellow = Color3.fromRGB(255, 255, 0)
		}
		CrossLabel.TextColor3 = colors[choice] or colors.Green
	end
})

Cross:CreateToggle({
	Name = "Rainbow Crosshair",
	CurrentValue = false,
	Flag = "RainbowCrosshairToggle",
	Callback = function(value) rainbowCrosshair = value end
})

-- =====================================================================
-- TELEPORT TAB
-- =====================================================================
local selectedPlayerName = nil
local followConnection = nil

local function getPlayerList()
	local playerNames = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LP then
			table.insert(playerNames, player.Name)
		end
	end
	if #playerNames == 0 then table.insert(playerNames, "No Players") end
	return playerNames
end

TeleportTab:CreateSection("Player Teleport")
local PlayerDropdown = TeleportTab:CreateDropdown({
	Name = "Select Player",
	Options = getPlayerList(),
	CurrentOption = {},
	MultipleOptions = false,
	Flag = "SelectPlayerDropdown",
	Callback = function(Option)
		selectedPlayerName = type(Option) == "table" and Option[1] or Option
	end
})

TeleportTab:CreateButton({
	Name = "Refresh Player List",
	Callback = function()
		PlayerDropdown:Refresh(getPlayerList())
		Notify("Refreshed", "Player list updated.", 2)
	end
})

TeleportTab:CreateButton({
	Name = "Teleport to Player",
	Callback = function()
		if not selectedPlayerName or selectedPlayerName == "" or selectedPlayerName == "No Players" then
			Notify("Teleport Error", "Please select a player first.", 3)
			return
		end
		local targetPlayer = Players:FindFirstChild(selectedPlayerName)
		local targetRoot = targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
		local myRoot = getRoot()
		if targetRoot and myRoot then
			myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
			Notify("Teleport Success", "Teleported to " .. selectedPlayerName, 3)
		else
			Notify("Teleport Error", "Target player missing character.", 3)
		end
	end
})

TeleportTab:CreateToggle({
	Name = "Loop Attach to Selected Player",
	CurrentValue = false,
	Flag = "LoopAttachToggle",
	Callback = function(value)
		if followConnection then followConnection:Disconnect() followConnection = nil end
		if value then
			followConnection = RunService.RenderStepped:Connect(function()
				if selectedPlayerName then
					local targetPlayer = Players:FindFirstChild(selectedPlayerName)
					local targetRoot = targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
					local myRoot = getRoot()
					if targetRoot and myRoot then
						myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 4)
					end
				end
			end)
		end
	end
})

TeleportTab:CreateToggle({
	Name = "Spectate Selected Player",
	CurrentValue = false,
	Flag = "SpectateToggle",
	Callback = function(value)
		if value and selectedPlayerName then
			local targetPlayer = Players:FindFirstChild(selectedPlayerName)
			local targetHum = targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChildOfClass("Humanoid")
			if targetHum then
				Camera.CameraSubject = targetHum
			end
		elseif humanoid then
			Camera.CameraSubject = humanoid
		end
	end
})

TeleportTab:CreateSection("Server Utilities")
TeleportTab:CreateToggle({
	Name = "Auto Rejoin on Kick / Disconnect",
	CurrentValue = false,
	Flag = "AutoRejoinToggle",
	Callback = function(value) autoRejoinEnabled = value end
})

TeleportTab:CreateButton({
	Name = "Rejoin Server",
	Callback = function()
		Notify("Server Utility", "Rejoining current server...", 3)
		TeleportService:Teleport(game.PlaceId, LP)
	end
})

TeleportTab:CreateButton({
	Name = "Server Hop",
	Callback = function()
		Notify("Server Utility", "Searching for a new server...", 3)
		task.spawn(function()
			local success, servers = pcall(function()
				return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/0?sortOrder=Asc&limit=100"))
			end)
			if success and servers and servers.data then
				for _, s in ipairs(servers.data) do
					if s.playing < s.maxPlayers and s.id ~= game.JobId then
						TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LP)
						return
					end
				end
			end
			Notify("Server Hop Failed", "Could not find an available server.", 3)
		end)
	end
})

Players.PlayerAdded:Connect(function()
	PlayerDropdown:Refresh(getPlayerList())
end)
Players.PlayerRemoving:Connect(function(player)
	if player.Name == selectedPlayerName then selectedPlayerName = nil end
	PlayerDropdown:Refresh(getPlayerList())
end)

-- =====================================================================
-- WAYPOINTS TAB
-- =====================================================================
local waypointNameToSave = ""
local selectedWaypointName = nil

local function getWaypointList()
	local names = {}
	for name in pairs(savedWaypoints) do
		table.insert(names, name)
	end
	if #names == 0 then table.insert(names, "No Waypoints Saved") end
	return names
end

WaypointTab:CreateSection("Custom Waypoints")
WaypointTab:CreateInput({
	Name = "Waypoint Name",
	CurrentValue = "",
	PlaceholderText = "Base, Shop...",
	RemoveTextAfterFocusLost = false,
	Flag = "WaypointNameInput",
	Callback = function(text)
		waypointNameToSave = text
	end
})

local WaypointDropdown
WaypointTab:CreateButton({
	Name = "Save Current Position",
	Callback = function()
		if not waypointNameToSave or waypointNameToSave == "" then
			Notify("Waypoint Error", "Type a name first.", 3)
			return
		end
		local myRoot = getRoot()
		if myRoot then
			savedWaypoints[waypointNameToSave] = myRoot.CFrame
			WaypointDropdown:Refresh(getWaypointList())
			saveWaypoints()
			Notify("Waypoint Saved", "Saved as '" .. waypointNameToSave .. "'", 3)
		end
	end
})

WaypointDropdown = WaypointTab:CreateDropdown({
	Name = "Select Saved Waypoint",
	Options = getWaypointList(),
	CurrentOption = {getWaypointList()[1]},
	MultipleOptions = false,
	Flag = "SelectWaypointDropdown",
	Callback = function(Option)
		selectedWaypointName = type(Option) == "table" and Option[1] or Option
	end
})

WaypointTab:CreateButton({
	Name = "Teleport to Selected Waypoint",
	Callback = function()
		if not selectedWaypointName or selectedWaypointName == "No Waypoints Saved" or not savedWaypoints[selectedWaypointName] then
			Notify("Teleport Error", "Select a valid waypoint first.", 3)
			return
		end
		local myRoot = getRoot()
		if myRoot then
			myRoot.CFrame = savedWaypoints[selectedWaypointName]
			Notify("Teleport Success", "Teleported to: " .. selectedWaypointName, 3)
		end
	end
})

WaypointTab:CreateButton({
	Name = "Delete Selected Waypoint",
	Callback = function()
		if selectedWaypointName and savedWaypoints[selectedWaypointName] then
			savedWaypoints[selectedWaypointName] = nil
			WaypointDropdown:Refresh(getWaypointList())
			saveWaypoints()
			Notify("Waypoint Deleted", "Removed waypoint.", 3)
		end
	end
})

-- =====================================================================
-- KEYBINDS TAB
-- =====================================================================
KeybindTab:CreateSection("Interactive Keybind Manager")

KeybindTab:CreateButton({
	Name = "Change Fly Key (Current: " .. tostring(keybinds.Fly.Name) .. ")",
	Callback = function()
		Notify("Keybind Listener", "Press any key now...", 2)
		local conn
		conn = UIS.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Keyboard then
				keybinds.Fly = input.KeyCode
				Notify("Keybind Bound", "Fly is now bound to " .. tostring(input.KeyCode.Name), 3)
				conn:Disconnect()
			end
		end)
	end
})

KeybindTab:CreateButton({
	Name = "Change Noclip Key (Current: " .. tostring(keybinds.Noclip.Name) .. ")",
	Callback = function()
		Notify("Keybind Listener", "Press any key now...", 2)
		local conn
		conn = UIS.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Keyboard then
				keybinds.Noclip = input.KeyCode
				Notify("Keybind Bound", "Noclip is now bound to " .. tostring(input.KeyCode.Name), 3)
				conn:Disconnect()
			end
		end)
	end
})

-- =====================================================================
-- GLOBAL KEYBIND & MOUSE HANDLERS
-- =====================================================================
UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == keybinds.Fly then
		setFly(not flying)
	elseif input.KeyCode == keybinds.Noclip then
		noclipEnabled = not noclipEnabled
	elseif input.KeyCode == Enum.KeyCode.P then
		setFullbright(not fullbrightEnabled)
		if fullbrightToggle then fullbrightToggle:Set(fullbrightEnabled) end
		Notify("Fullbright", fullbrightEnabled and "ON (P to turn off)" or "OFF (P to turn on)", 2)
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		aimbotHold = true
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		aimbotHold = false
	end
end)

Notify("IzttNick Hub Loaded", "Rayfield UI ready! All toggles OFF by default.", 4)
