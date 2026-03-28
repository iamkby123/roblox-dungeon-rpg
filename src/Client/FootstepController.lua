local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local FootstepController = {}

local player = Players.LocalPlayer

-- Heavy stone footstep sound IDs (Roblox library sounds)
local FOOTSTEP_SOUNDS = {
	"rbxassetid://9116367332", -- concrete/stone step 1
	"rbxassetid://9116367596", -- concrete/stone step 2
}

local WALK_INTERVAL = 0.38 -- seconds between steps while walking
local SPRINT_INTERVAL = 0.28 -- seconds between steps while sprinting
local VOLUME = 0.6
local BASE_PITCH_MIN = 0.85
local BASE_PITCH_MAX = 1.0

local lastStepTime = 0
local footstepSound = nil

function FootstepController.Init()
	-- Create the sound object attached to the character
	local function setupSound(character)
		if not character then return end
		local rootPart = character:WaitForChild("HumanoidRootPart", 5)
		if not rootPart then return end

		-- Remove old sound
		if footstepSound then
			footstepSound:Destroy()
		end

		footstepSound = Instance.new("Sound")
		footstepSound.Name = "HeavyFootstep"
		footstepSound.Volume = VOLUME
		footstepSound.RollOffMaxDistance = 50
		footstepSound.SoundId = FOOTSTEP_SOUNDS[1]
		footstepSound.Parent = rootPart

		-- Disable default footstep sounds
		local function muteDefault(char)
			for _, sound in ipairs(char:GetDescendants()) do
				if sound:IsA("Sound") and (sound.Name == "Running" or sound.Name == "Climbing") then
					sound.Volume = 0
				end
			end
		end
		muteDefault(character)
		character.DescendantAdded:Connect(function(desc)
			if desc:IsA("Sound") and (desc.Name == "Running" or desc.Name == "Climbing") then
				desc.Volume = 0
			end
		end)
	end

	-- Setup on current and future characters
	if player.Character then
		setupSound(player.Character)
	end
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("HumanoidRootPart")
		setupSound(char)
	end)

	-- Step loop
	RunService.RenderStepped:Connect(function(dt)
		FootstepController.Update(dt)
	end)
end

function FootstepController.Update(dt)
	if not footstepSound or not footstepSound.Parent then return end

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	-- Only play when moving on the ground
	local isMoving = humanoid.MoveDirection.Magnitude > 0.1
	local isOnGround = humanoid.FloorMaterial ~= Enum.Material.Air

	if not isMoving or not isOnGround then
		return
	end

	local now = os.clock()
	local isSprinting = humanoid.WalkSpeed > 20
	local interval = isSprinting and SPRINT_INTERVAL or WALK_INTERVAL

	if now - lastStepTime >= interval then
		lastStepTime = now

		-- Randomize pitch for variety
		local pitch = BASE_PITCH_MIN + math.random() * (BASE_PITCH_MAX - BASE_PITCH_MIN)
		footstepSound.PlaybackSpeed = pitch

		-- Alternate sound IDs for slight variation
		local idx = math.random(1, #FOOTSTEP_SOUNDS)
		footstepSound.SoundId = FOOTSTEP_SOUNDS[idx]

		-- Louder when sprinting
		footstepSound.Volume = isSprinting and VOLUME * 1.2 or VOLUME

		footstepSound:Play()
	end
end

return FootstepController
