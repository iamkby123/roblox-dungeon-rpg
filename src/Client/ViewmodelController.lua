local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SkillConfig"))

local ViewmodelController = {}

local player = Players.LocalPlayer
local viewmodel = nil
local weaponModels = {}
local currentWeaponId = nil
local initialized = false

-- Direct part references (no FindFirstChild each frame)
local armPart = nil
local handPart = nil
local gripPart = nil
local wrap1Part = nil
local wrap2Part = nil
local knucklesPart = nil

-- Viewmodel offset from camera (right side, slightly down and forward)
local BASE_OFFSET = CFrame.new(1.5, -1.4, -2.2)

-- Walk bob
local bobTime = 0
local BOB_SPEED = 8
local BOB_AMOUNT_Y = 0.06
local BOB_AMOUNT_X = 0.03

-- Attack animation state
local swingAngle = 0
local swingTarget = 0
local swingSpeed = 12
local isSwinging = false

-- Idle sway
local idleTime = 0
local IDLE_SPEED = 1.5
local IDLE_AMOUNT = 0.015

----------------------------------------------------------------------
-- Helper: create a Part with common viewmodel properties
----------------------------------------------------------------------
local function makePart(name, size, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

----------------------------------------------------------------------
-- Build the arm + hand
----------------------------------------------------------------------
local function createArmModel(parent)
	local model = Instance.new("Model")
	model.Name = "Viewmodel"

	local skin = Color3.fromRGB(245, 205, 160)

	armPart = makePart("Arm", Vector3.new(1, 1, 2.8), skin, Enum.Material.SmoothPlastic, model)
	handPart = makePart("Hand", Vector3.new(1.0, 0.95, 0.9), skin, Enum.Material.SmoothPlastic, model)

	-- Bandage wraps around the fist (don't protrude above the arm)
	local wrap = Color3.fromRGB(220, 210, 185)
	wrap1Part = makePart("Wrap1", Vector3.new(1.05, 0.15, 0.95), wrap, Enum.Material.Fabric, model)
	wrap2Part = makePart("Wrap2", Vector3.new(1.05, 0.15, 0.95), wrap, Enum.Material.Fabric, model)
	knucklesPart = makePart("Knuckles", Vector3.new(1.02, 0.2, 0.15), Color3.fromRGB(235, 195, 150), Enum.Material.SmoothPlastic, model)

	gripPart = Instance.new("Part")
	gripPart.Name = "Grip"
	gripPart.Size = Vector3.new(0.1, 0.1, 0.1)
	gripPart.Transparency = 1
	gripPart.Anchored = true
	gripPart.CanCollide = false
	gripPart.CanQuery = false
	gripPart.CanTouch = false
	gripPart.Parent = model

	model.PrimaryPart = armPart
	model.Parent = parent
	return model
end

----------------------------------------------------------------------
-- Weapon builders — each returns { model, parts = {name=Part} }
----------------------------------------------------------------------
local function buildSword(parent)
	local m = Instance.new("Model"); m.Name = "Weapon_Sword"
	local parts = {}
	parts.Handle = makePart("Handle", Vector3.new(0.25, 0.25, 1.0), Color3.fromRGB(100, 60, 30), Enum.Material.Wood, m)
	parts.Guard = makePart("Guard", Vector3.new(0.3, 1.2, 0.2), Color3.fromRGB(180, 160, 50), Enum.Material.Metal, m)
	parts.Blade = makePart("Blade", Vector3.new(0.2, 0.3, 3.2), Color3.fromRGB(200, 200, 210), Enum.Material.Metal, m)
	m.PrimaryPart = parts.Handle
	m.Parent = parent
	return { model = m, parts = parts }
end

local function buildStaff(parent)
	local m = Instance.new("Model"); m.Name = "Weapon_Staff"
	local parts = {}
	parts.Shaft = makePart("Shaft", Vector3.new(0.3, 0.3, 4.0), Color3.fromRGB(80, 50, 30), Enum.Material.Wood, m)
	parts.Orb = makePart("Orb", Vector3.new(0.7, 0.7, 0.7), Color3.fromRGB(255, 120, 30), Enum.Material.Neon, m)
	parts.Orb.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 30)
	light.Brightness = 0.5; light.Range = 4
	light.Parent = parts.Orb
	parts._light = light
	m.PrimaryPart = parts.Shaft
	m.Parent = parent
	return { model = m, parts = parts }
end

local function buildWand(parent)
	local m = Instance.new("Model"); m.Name = "Weapon_Wand"
	local parts = {}
	parts.Stick = makePart("Stick", Vector3.new(0.2, 0.2, 2.2), Color3.fromRGB(230, 230, 240), Enum.Material.SmoothPlastic, m)
	parts.Crystal = makePart("Crystal", Vector3.new(0.35, 0.35, 0.5), Color3.fromRGB(50, 255, 100), Enum.Material.Neon, m)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(50, 255, 100)
	light.Brightness = 0.4; light.Range = 3
	light.Parent = parts.Crystal
	parts._light = light
	m.PrimaryPart = parts.Stick
	m.Parent = parent
	return { model = m, parts = parts }
end

local function buildShield(parent)
	local m = Instance.new("Model"); m.Name = "Weapon_Shield"
	local parts = {}
	parts.Handle = makePart("Handle", Vector3.new(0.3, 0.3, 0.8), Color3.fromRGB(100, 60, 30), Enum.Material.Wood, m)
	parts.Body = makePart("Body", Vector3.new(0.4, 2.2, 2.0), Color3.fromRGB(50, 100, 200), Enum.Material.Metal, m)
	parts.Emblem = makePart("Emblem", Vector3.new(0.45, 0.8, 0.8), Color3.fromRGB(255, 215, 0), Enum.Material.Metal, m)
	m.PrimaryPart = parts.Handle
	m.Parent = parent
	return { model = m, parts = parts }
end

local WEAPON_BUILDERS = {
	Sword = buildSword,
	Staff = buildStaff,
	Wand = buildWand,
	Shield = buildShield,
}

----------------------------------------------------------------------
-- Position weapon parts relative to grip
----------------------------------------------------------------------
local function positionWeapon(weaponId, gripCF)
	local data = weaponModels[weaponId]
	if not data then return end
	local p = data.parts

	if weaponId == "Sword" then
		-- Slight tilt for a natural forward hold
		local tilt = gripCF * CFrame.Angles(math.rad(-5), 0, 0)
		p.Handle.CFrame = tilt * CFrame.new(0, 0, -0.5)
		p.Guard.CFrame = tilt * CFrame.new(0, 0, -1.0)
		p.Blade.CFrame = tilt * CFrame.new(0, 0, -2.6)
	elseif weaponId == "Staff" then
		local tilt = gripCF * CFrame.Angles(math.rad(-5), 0, 0)
		p.Shaft.CFrame = tilt * CFrame.new(0, 0, -2.0)
		p.Orb.CFrame = tilt * CFrame.new(0, 0, -4.2)
	elseif weaponId == "Wand" then
		local tilt = gripCF * CFrame.Angles(math.rad(-5), 0, 0)
		p.Stick.CFrame = tilt * CFrame.new(0, 0, -1.1)
		p.Crystal.CFrame = tilt * CFrame.new(0, 0, -2.4)
	elseif weaponId == "Shield" then
		local shieldCF = gripCF * CFrame.new(-0.3, 0, -0.8)
		p.Handle.CFrame = shieldCF
		p.Body.CFrame = shieldCF * CFrame.new(-0.3, 0, 0)
		p.Emblem.CFrame = shieldCF * CFrame.new(-0.35, 0, 0)
	end
end

----------------------------------------------------------------------
-- Show/hide weapons
----------------------------------------------------------------------
local function setWeaponVisible(weaponId, visible)
	local data = weaponModels[weaponId]
	if not data then return end
	for name, part in pairs(data.parts) do
		if typeof(part) == "Instance" and part:IsA("BasePart") then
			part.Transparency = visible and 0 or 1
		elseif typeof(part) == "Instance" and part:IsA("PointLight") then
			part.Enabled = visible
		end
	end
end

local function switchWeapon(newId)
	if currentWeaponId then
		setWeaponVisible(currentWeaponId, false)
	end
	currentWeaponId = newId
	setWeaponVisible(currentWeaponId, true)
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------
function ViewmodelController.Init(skillController)
	if initialized then return end
	initialized = true

	-- Wait for camera to be available
	local cam = workspace.CurrentCamera
	while not cam do
		task.wait(0.1)
		cam = workspace.CurrentCamera
	end

	print("[ViewmodelController] Initializing viewmodel...")

	-- Build arm model
	viewmodel = createArmModel(cam)

	-- Build all weapon models
	for weaponId, builder in pairs(WEAPON_BUILDERS) do
		weaponModels[weaponId] = builder(cam)
	end

	-- Show initial weapon, hide others
	currentWeaponId = skillController.GetEquippedWeaponId() or "Sword"
	for weaponId, _ in pairs(weaponModels) do
		setWeaponVisible(weaponId, weaponId == currentWeaponId)
	end

	-- Main render loop
	RunService.RenderStepped:Connect(function(dt)
		local ok, err = pcall(ViewmodelController.Update, dt, skillController)
		if not ok then
			warn("[ViewmodelController] " .. tostring(err))
		end
	end)

	-- Hide player's real arms in first person
	local function hideBodyParts(char)
		if not char then return end
		for _, partName in ipairs({"Right Arm", "RightHand", "RightUpperArm", "RightLowerArm", "Left Arm", "LeftHand", "LeftUpperArm", "LeftLowerArm"}) do
			local part = char:FindFirstChild(partName)
			if part and part:IsA("BasePart") then
				part.LocalTransparencyModifier = 1
			end
		end
	end

	RunService.RenderStepped:Connect(function()
		hideBodyParts(player.Character)
	end)

	print("[ViewmodelController] Ready!")
end

function ViewmodelController.Update(dt, skillController)
	if not viewmodel then return end
	if not armPart or not armPart.Parent then return end

	local cam = workspace.CurrentCamera
	if not cam then return end

	-- Re-parent viewmodel if camera changed
	if viewmodel.Parent ~= cam then
		viewmodel.Parent = cam
		for _, data in pairs(weaponModels) do
			data.model.Parent = cam
		end
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChild("Humanoid")

	-- Detect weapon change
	local newWeaponId = skillController.GetEquippedWeaponId() or "Sword"
	if newWeaponId ~= currentWeaponId then
		switchWeapon(newWeaponId)
	end

	-- Walk bob
	if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
		bobTime = bobTime + dt * BOB_SPEED * (humanoid.WalkSpeed / 16)
	else
		bobTime = bobTime + dt * 0.5
	end

	local bobY = math.sin(bobTime) * BOB_AMOUNT_Y
	local bobX = math.cos(bobTime * 0.5) * BOB_AMOUNT_X

	local isMoving = humanoid and humanoid.MoveDirection.Magnitude > 0.1

	-- Idle sway
	local idleY, idleX = 0, 0
	if not isMoving then
		idleTime = idleTime + dt * IDLE_SPEED
		idleY = math.sin(idleTime) * IDLE_AMOUNT
		idleX = math.cos(idleTime * 0.7) * IDLE_AMOUNT * 0.5
	end

	-- Attack swing
	if isSwinging then
		swingAngle = swingAngle + (swingTarget - swingAngle) * math.min(1, dt * swingSpeed)
		if math.abs(swingAngle - swingTarget) < 0.02 then
			if swingTarget ~= 0 then
				swingTarget = 0
				swingSpeed = 8
			else
				isSwinging = false
				swingAngle = 0
			end
		end
	end

	-- Compose final CFrame
	local camCF = cam.CFrame
	local bobOffset = CFrame.new(bobX + idleX, bobY + idleY, 0)
	local swingRotation = CFrame.Angles(math.rad(swingAngle), 0, 0)
	local finalCF = camCF * BASE_OFFSET * bobOffset * swingRotation

	-- Position arm
	armPart.CFrame = finalCF
	local handCF = finalCF * CFrame.new(0, 0, -1.85)
	handPart.CFrame = handCF

	-- Position bandage wraps on the fist
	if wrap1Part then wrap1Part.CFrame = handCF * CFrame.new(0, 0.1, 0.1) end
	if wrap2Part then wrap2Part.CFrame = handCF * CFrame.new(0, -0.15, -0.05) end
	if knucklesPart then knucklesPart.CFrame = handCF * CFrame.new(0, 0.2, -0.35) end

	-- Grip at front of hand
	local gripCF = finalCF * CFrame.new(0, 0, -2.3)
	gripPart.CFrame = gripCF

	-- Position weapon
	positionWeapon(currentWeaponId, gripCF)
end

function ViewmodelController.PlayAttackAnimation()
	isSwinging = true

	if currentWeaponId == "Sword" then
		swingAngle = 0; swingTarget = -40; swingSpeed = 18
	elseif currentWeaponId == "Staff" then
		swingAngle = 0; swingTarget = -20; swingSpeed = 14
	elseif currentWeaponId == "Wand" then
		swingAngle = 0; swingTarget = -15; swingSpeed = 16
	elseif currentWeaponId == "Shield" then
		swingAngle = 0; swingTarget = -10; swingSpeed = 20
	else
		swingAngle = 0; swingTarget = -25; swingSpeed = 14
	end
end

function ViewmodelController.Destroy()
	if viewmodel then viewmodel:Destroy(); viewmodel = nil end
	for _, data in pairs(weaponModels) do
		data.model:Destroy()
	end
	weaponModels = {}
	initialized = false
end

return ViewmodelController
