local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local FootstepController = {}

local player = Players.LocalPlayer

local VOLUME = 0.8
local WALK_PITCH = 0.6 -- lower pitch = heavier stone feel
local SPRINT_PITCH = 0.7
local runningSound = nil

local function setupFootsteps(character)
	if not character then return end
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end

	-- Find the default Running sound inside HumanoidRootPart
	local rootPart = character:WaitForChild("HumanoidRootPart", 5)
	if not rootPart then return end

	local function tweakRunning(sound)
		if sound:IsA("Sound") and sound.Name == "Running" then
			sound.Volume = VOLUME
			sound.PlaybackSpeed = WALK_PITCH
			runningSound = sound
		end
	end

	-- Tweak existing sounds
	for _, desc in ipairs(rootPart:GetDescendants()) do
		tweakRunning(desc)
	end

	-- Catch sounds added later (character respawn)
	rootPart.DescendantAdded:Connect(function(desc)
		tweakRunning(desc)
	end)
end

function FootstepController.Init()
	if player.Character then
		setupFootsteps(player.Character)
	end
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("HumanoidRootPart")
		setupFootsteps(char)
	end)

	-- Adjust pitch based on sprint speed
	RunService.RenderStepped:Connect(function()
		if not runningSound or not runningSound.Parent then return end
		local character = player.Character
		if not character then return end
		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid then return end

		local isSprinting = humanoid.WalkSpeed > 20
		runningSound.PlaybackSpeed = isSprinting and SPRINT_PITCH or WALK_PITCH
		runningSound.Volume = isSprinting and VOLUME * 1.3 or VOLUME
	end)
end

return FootstepController
