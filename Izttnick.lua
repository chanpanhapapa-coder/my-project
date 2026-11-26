-- IzttNick Hub | Rayfield Edition
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

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local function Notify(title, content, duration)
	Rayfield:Notify({
		Title = title or "IzttNick Hub",
		Content = content or "",
		Duration = duration or 3,
		Image = 4483362458
	})
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

loadWaypoints()

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
local lowGravityEnabled = false
local normalGravity = workspace.Gravity

local hitboxExpanderEnabled = false
local hitboxSize = 5

local espEnabled = false
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

local function setFullbright(enabled)
	fullbrightEnabled = enabled and true or false
	if fullbrightEnabled then
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.GlobalShadows = false
		Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
		Lighting.FogEnd = 999999
	else
		Lighting.Brightness = originalLightingSettings.Brightness
		Lighting.ClockTime = originalLightingSettings.ClockTime
		Lighting.GlobalShadows = originalLightingSettings.GlobalShadows
		Lighting.OutdoorAmbient = originalLightingSettings.OutdoorAmbient
		Lighting.FogEnd = originalLightingSettings.FogEnd
	end
end

local fullbrightRefresh = 0
RunService.Heartbeat:Connect(function(dt)
	if not fullbrightEnabled then return end
	fullbrightRefresh += dt
	if fullbrightRefresh >= 0.5 then
		fullbrightRefresh = 0
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.GlobalShadows = false
		Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
		Lighting.FogEnd = 999999
	end
end)

local highlights = {}
local billboards = {}
local snaplineObjects = {}

local espColor = Color3.fromRGB(255, 40, 40)
local snaplineColor = Color3.fromRGB(255, 255, 255)

-- =====================================================================
-- ASYMMETRIC / MAP / STATUS ESP STATE & LOGIC
-- =====================================================================
local ESP = {
	Survivor = true,
	Killer = true,
	Generator = true,
	Pallet = true,
	Window = true,
	Distance = 1000
}

local ESPStatus = {
	Enabled = false,
	ShowName = true,
	ShowDistance = true,
	ShowHealth = false,
	Radius = 1000
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
		local success, val = pcall(function() return child.Value end)
		if success then return val end
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

	local pos
	if generator:IsA("Model") then
		pos = generator:GetPivot().Position
	elseif generator:IsA("BasePart") then
		pos = generator.Position
	end
	local withinRange = (not currentRoot) or (not pos) or ((pos - currentRoot.Position).Magnitude <= ESP.Distance)

	if not ESP.Generator or not withinRange then
		local old = generator:FindFirstChild("GenESP")
		if old then old:Destroy() end

		local h = generator:FindFirstChild("GenHighlight")
		if h then h:Destroy() end
		return
	end

	local percent =
		GetGameValue(generator, "RepairProgress") or
		GetGameValue(generator, "Progress") or 0

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

	local pos
	if obj:IsA("Model") then
		pos = obj:GetPivot().Position
	elseif obj:IsA("BasePart") then
		pos = obj.Position
	end

	if not pos then return end

	local distance = (pos - currentRoot.Position).Magnitude

	if obj.Name == "Window" then
		if ESP.Window and distance <= ESP.Distance then
			createESP(obj, WindowColor)
		else
			removeESP(obj)
		end
	end

	if obj.Name == "Pallet" or obj.Name == "Palletwrong" then
		if ESP.Pallet and distance <= ESP.Distance then
			createESP(obj, PalletColor)
		else
			removeESP(obj)
		end
	end
end

local StatusESP = {}

local function removeStatusESP(char)
	if StatusESP[char] then
		StatusESP[char]:Destroy()
		StatusESP[char] = nil
	end
end

local function createStatusESP(player, char, currentRoot)
	if not ESPStatus.Enabled then
		removeStatusESP(char)
		return
	end

	if not currentRoot then return end

	local head = char:FindFirstChild("Head")
	local hum = char:FindFirstChildOfClass("Humanoid")

	if not head or not hum then return end

	local isDown =
		hum.Health <= 0
		or hum.Health < 2
		or char:GetAttribute("Downed") == true
		or char:GetAttribute("IsDown") == true
		or char:GetAttribute("Knocked") == true

	local dist = (head.Position - currentRoot.Position).Magnitude

	if dist > ESPStatus.Radius then
		removeStatusESP(char)
		return
	end

	local text = ""
	if isDown then text = "🔻 DOWN\n" end
	if ESPStatus.ShowName then text = text .. player.Name .. "\n" end
	if ESPStatus.ShowDistance then text = text .. string.format("Dist: %.0f\n", dist) end
	if ESPStatus.ShowHealth then text = text .. string.format("HP: %.0f\n", hum.Health) end

	if text == "" then
		removeStatusESP(char)
		return
	end

	local teamColor = Color3.new(1, 1, 1)
	if player.Team then
		if player.Team.Name == "Killer" then
			teamColor = TeamColors.Killer
		elseif player.Team.Name == "Survivors" then
			teamColor = TeamColors.Survivor
		end
	end
	if isDown then
		teamColor = TeamColors.Killer
	end

	local billboard = StatusESP[char]
	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.new(0, 120, 0, 50)
		billboard.AlwaysOnTop = true

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = teamColor
		label.TextStrokeTransparency = 0
		label.Font = Enum.Font.GothamBold
		label.TextSize = 12
		label.Text = text
		label.Parent = billboard

		billboard.Adornee = head
		billboard.StudsOffset = Vector3.new(0, 2.5, 0)
		billboard.Parent = char
		StatusESP[char] = billboard
	else
		local label = billboard:FindFirstChildOfClass("TextLabel")
		if label then
			label.Text = text
			label.TextColor3 = teamColor
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

for _, obj in ipairs(workspace:GetDescendants()) do
	cacheObject(obj)
end

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

				if hum and hum.Health > 0 then
					local hrp = char:FindFirstChild("HumanoidRootPart")
					if hrp then
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
					end
					createStatusESP(p, char, currentRoot)
				else
					removeESP(char)
					removeStatusESP(char)
				end
			end
		end

		for gen in pairs(Cached.Generators) do
			UpdateGenerator(gen, currentRoot)
		end

		for obj in pairs(Cached.Windows) do UpdateMapESP(obj, currentRoot) end
		for obj in pairs(Cached.Pallets) do UpdateMapESP(obj, currentRoot) end
	end
end)

-- =====================================================================
-- AUTO SKILL CHECK
-- =====================================================================
local autoSkillCheckEnabled = true
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
local teamCheck = true
local wallCheck = false

local cameraFovEnabled = true
local cameraFovValue = 120
local originalCameraFov = (workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView) or 70
if workspace.CurrentCamera then
	workspace.CurrentCamera.FieldOfView = cameraFovValue
end

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

local FOVCircle = Drawing.new("Circle")
FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
FOVCircle.Radius = fovRadius
FOVCircle.Color = Color3.fromRGB(0, 255, 255)
FOVCircle.Thickness = 1.5
FOVCircle.Filled = false
FOVCircle.Visible = false

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
-- HEAL (E KEY) - uses a healing tool already available to the player
-- =====================================================================
local healKey = Enum.KeyCode.E
local healBusy = false

local function findHealingTool()
	local backpack = LP:FindFirstChildOfClass("Backpack")
	local containers = {character, backpack}
	local keywords = {"heal", "medkit", "med kit", "bandage", "firstaid", "first aid"}
	for _, container in ipairs(containers) do
		if container then
			for _, item in ipairs(container:GetChildren()) do
				if item:IsA("Tool") then
					local lowerName = string.lower(item.Name)
					for _, keyword in ipairs(keywords) do
						if string.find(lowerName, keyword, 1, true) then
							return item
						end
					end
				end
			end
		end
	end
	return nil
end

local function useHeal()
	if healBusy then return end
	if not character or not humanoid or humanoid.Health <= 0 then
		Notify("Heal", "Your character is not ready.", 2)
		return
	end
	if humanoid.Health >= humanoid.MaxHealth then
		Notify("Heal", "Your health is already full.", 2)
		return
	end
	local tool = findHealingTool()
	if not tool then
		Notify("Heal", "No healing tool found. Pick up a medkit or bandage first.", 3)
		return
	end
	healBusy = true
	task.spawn(function()
		local ok, err = pcall(function()
			if tool.Parent ~= character and humanoid then
				humanoid:EquipTool(tool)
				task.wait(0.15)
			end
			tool:Activate()
		end)
		if ok then
			Notify("Heal", "Healing item activated.", 2)
		else
			Notify("Heal", "Could not activate the healing item.", 2)
		end
		task.wait(0.5)
		healBusy = false
	end)
end

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
		lowGravityEnabled = value
		workspace.Gravity = value and 50 or normalGravity
	end
})

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

Main:CreateSection("Character Recovery")
Main:CreateButton({
	Name = "Heal (Press E)",
	Callback = useHeal
})

Main:CreateSection("Skill Checks")
Main:CreateToggle({
	Name = "Auto Skill Check",
	CurrentValue = true,
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
startSkillCheck()

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
	if cameraFovEnabled and workspace.CurrentCamera then
		workspace.CurrentCamera.FieldOfView = cameraFovValue
	end
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
	CurrentValue = true,
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
local function clearESP(player)
	if highlights[player] then highlights[player]:Destroy() highlights[player] = nil end
	if billboards[player] then billboards[player]:Destroy() billboards[player] = nil end
	if snaplineObjects[player] then snaplineObjects[player]:Remove() snaplineObjects[player] = nil end
end

local function updateESP()
	for _, player in ipairs(Players:GetPlayers()) do
		if player == LP or (not espEnabled and not snaplineEspEnabled) then
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
					if player.Team and player.Team.Name == "Killer" then
						snapLine.Color = Color3.fromRGB(255, 45, 45) -- Killer: red
					elseif player.Team and player.Team.Name == "Survivors" then
						snapLine.Color = Color3.fromRGB(45, 130, 255) -- Survivor: blue
					else
						snapLine.Color = snaplineColor
					end
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

Players.PlayerRemoving:Connect(clearESP)
RunService.RenderStepped:Connect(function()
	if espEnabled or snaplineEspEnabled then updateESP() end
end)

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

local function createESPControls(label, defaultColor, setter)
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
	CurrentValue = true,
	Flag = "TrackerLinesToggle",
	Callback = function(value)
		snaplineEspEnabled = value
		if not value then
			for _, line in pairs(snaplineObjects) do
				line.Visible = false
			end
		else
			updateESP()
		end
	end
})

Visuals:CreateSection("Killer, Survivor & Map Object ESP")
Visuals:CreateToggle({
	Name = "ESP Survivor",
	CurrentValue = true,
	Flag = "EspSurvivorToggle",
	Callback = function(v) ESP.Survivor = v end
})
createESPControls("Survivor", TeamColors.Survivor, function(c) TeamColors.Survivor = c end)

Visuals:CreateToggle({
	Name = "ESP Killer",
	CurrentValue = true,
	Flag = "EspKillerToggle",
	Callback = function(v) ESP.Killer = v end
})
createESPControls("Killer", TeamColors.Killer, function(c) TeamColors.Killer = c end)

Visuals:CreateToggle({
	Name = "Generator ESP",
	CurrentValue = true,
	Flag = "EspGenToggle",
	Callback = function(v) ESP.Generator = v end
})
createESPControls("Generator", GeneratorColor, function(c) GeneratorColor = c end)

Visuals:CreateToggle({
	Name = "Pallet ESP",
	CurrentValue = true,
	Flag = "EspPalletToggle",
	Callback = function(v) ESP.Pallet = v end
})
createESPControls("Pallet", PalletColor, function(c) PalletColor = c end)

Visuals:CreateToggle({
	Name = "Window ESP",
	CurrentValue = true,
	Flag = "EspWindowToggle",
	Callback = function(v) ESP.Window = v end
})
createESPControls("Window", WindowColor, function(c) WindowColor = c end)

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
			if object:IsA("BasePart") and LP.Character and not object:IsDescendantOf(LP.Character) and not object.Parent:FindFirstChildOfClass("Humanoid") then
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
local autoBrightEnabled = false
local showPerformanceOverlay = false

local function applyLightingOpts()
	if fpsBoostEnabled then
		Lighting.GlobalShadows = false
		Lighting.FogEnd = 100000
	else
		Lighting.GlobalShadows = originalLightingSettings.GlobalShadows
		Lighting.FogEnd = originalLightingSettings.FogEnd
	end
	if autoBrightEnabled then
		Lighting.Brightness = 3
		Lighting.ClockTime = 14
	else
		Lighting.Brightness = originalLightingSettings.Brightness
		Lighting.ClockTime = originalLightingSettings.ClockTime
	end
end

Perf:CreateSection("Optimization")
Perf:CreateToggle({
	Name = "FPS Boost",
	CurrentValue = false,
	Flag = "FpsBoostToggle",
	Callback = function(value)
		fpsBoostEnabled = value
		applyLightingOpts()
	end
})

Perf:CreateToggle({
	Name = "Auto Bright",
	CurrentValue = false,
	Flag = "AutoBrightToggle",
	Callback = function(value)
		autoBrightEnabled = value
		applyLightingOpts()
	end
})

local StatsGui = Instance.new("ScreenGui")
StatsGui.Name = "IzttNickStats"
StatsGui.ResetOnSpawn = false
StatsGui.Parent = LP:WaitForChild("PlayerGui")

local StatsLabel = Instance.new("TextLabel")
StatsLabel.Name = "StatsLabel"
StatsLabel.Size = UDim2.fromOffset(180, 26)
StatsLabel.Position = UDim2.fromScale(0.01, 0.01)
StatsLabel.BackgroundTransparency = 0.35
StatsLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
StatsLabel.TextColor3 = Color3.fromRGB(0, 255, 200)
StatsLabel.TextSize = 13
StatsLabel.Font = Enum.Font.Code
StatsLabel.Text = "FPS: -- | Ping: --ms"
StatsLabel.Visible = false
StatsLabel.Parent = StatsGui

local statsCorner = Instance.new("UICorner")
statsCorner.CornerRadius = UDim.new(0, 6)
statsCorner.Parent = StatsLabel

Perf:CreateToggle({
	Name = "Show FPS & Ping Overlay",
	CurrentValue = false,
	Flag = "PerfOverlayToggle",
	Callback = function(value)
		showPerformanceOverlay = value
		StatsLabel.Visible = value
	end
})

local frameCount = 0
local lastCheck = tick()
RunService.RenderStepped:Connect(function()
	frameCount += 1
	local now = tick()
	if now - lastCheck >= 1 then
		local fps = math.floor(frameCount / (now - lastCheck))
		frameCount = 0
		lastCheck = now
		local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
		if showPerformanceOverlay then
			StatsLabel.Text = string.format("FPS: %d | Ping: %dms", fps, ping)
		end
	end
end)

-- =====================================================================
-- CROSSHAIR TAB
-- =====================================================================
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
CrossLabel.Visible = false
CrossLabel.Parent = GUI

Cross:CreateSection("Crosshair Customization")
Cross:CreateToggle({
	Name = "Show Crosshair",
	CurrentValue = false,
	Flag = "ShowCrosshairToggle",
	Callback = function(value) CrossLabel.Visible = value end
})

Cross:CreateDropdown({
	Name = "Crosshair Style",
	Options = {"+", ".", "x", "o"},
	CurrentOption = {"+"},
	MultipleOptions = false,
	Flag = "CrosshairStyleDropdown",
	Callback = function(value)
		CrossLabel.Text = type(value) == "table" and value[1] or value
	end
})

Cross:CreateSlider({
	Name = "Crosshair Size",
	Range = {10, 60},
	Increment = 2,
	Suffix = " px",
	CurrentValue = 30,
	Flag = "CrosshairSizeSlider",
	Callback = function(value) CrossLabel.Size = UDim2.fromOffset(value, value) end
})

Cross:CreateDropdown({
	Name = "Crosshair Color",
	Options = {"Green", "Red", "White", "Cyan", "Yellow"},
	CurrentOption = {"Green"},
	MultipleOptions = false,
	Flag = "CrosshairColorDropdown",
	Callback = function(value)
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

RunService.RenderStepped:Connect(function()
	if rainbowCrosshair and CrossLabel then
		local hue = (tick() * 2) % 1
		CrossLabel.TextColor3 = Color3.fromHSV(hue, 1, 1)
	end
end)

-- =====================================================================
-- TELEPORT TAB
-- =====================================================================
local selectedPlayerName = nil
local followEnabled = false
local followConnection = nil
local spectateEnabled = false

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
		if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
			if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
				LP.Character.HumanoidRootPart.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
				Notify("Teleport Success", "Teleported to " .. selectedPlayerName, 3)
			end
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
		followEnabled = value
		if followConnection then followConnection:Disconnect() followConnection = nil end
		if followEnabled then
			followConnection = RunService.RenderStepped:Connect(function()
				if selectedPlayerName then
					local targetPlayer = Players:FindFirstChild(selectedPlayerName)
					if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") and root then
						root.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 4)
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
		spectateEnabled = value
		if spectateEnabled and selectedPlayerName then
			local targetPlayer = Players:FindFirstChild(selectedPlayerName)
			if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then
				Camera.CameraSubject = targetPlayer.Character.Humanoid
			end
		else
			if humanoid then Camera.CameraSubject = humanoid end
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
	for name, _ in pairs(savedWaypoints) do
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
		if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
			savedWaypoints[waypointNameToSave] = LP.Character.HumanoidRootPart.CFrame
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
		if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
			LP.Character.HumanoidRootPart.CFrame = savedWaypoints[selectedWaypointName]
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
	elseif input.KeyCode == healKey then
		useHeal()
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

Notify("IzttNick Hub Loaded", "Rayfield UI ready! K = Hub, E = Heal, Y = FOV, P = Fullbright.", 4)
