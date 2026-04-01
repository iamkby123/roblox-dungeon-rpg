local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local InputController = {}

local SkillController -- set via Init
local isSprinting = false
local WALK_SPEED = 16
local SPRINT_SPEED = 24

local keyMap = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
}

function InputController.Init(skillCtrl)
	SkillController = skillCtrl

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		-- Number keys to switch weapon
		local slot = keyMap[input.KeyCode]
		if slot then
			SkillController.EquipSlot(slot)
			return
		end

		-- Left click = use equipped weapon
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local direction = InputController.GetAimDirection()
			SkillController.UseEquippedWeapon(direction)
			return
		end

		-- Shift to sprint
		if input.KeyCode == Enum.KeyCode.LeftShift then
			isSprinting = true
			local character = Players.LocalPlayer.Character
			local humanoid = character and character:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = SPRINT_SPEED
			end
			return
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			isSprinting = false
			local character = Players.LocalPlayer.Character
			local humanoid = character and character:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = WALK_SPEED
			end
		end
	end)

	-- Scroll wheel for weapon cycling
	UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local delta = input.Position.Z
			if delta > 0 then
				SkillController.CycleWeapon(-1)
			else
				SkillController.CycleWeapon(1)
			end
		end
	end)
end

function InputController.GetAimDirection()
	local player = Players.LocalPlayer
	local character = player.Character
	if not character then return nil end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end

	local mouse = player:GetMouse()
	if mouse.Hit then
		local targetPos = mouse.Hit.Position
		local spawnPos = rootPart.Position + Vector3.new(0, 2, 0)
		local direction = (targetPos - spawnPos)
		if direction.Magnitude > 0.1 then
			return direction.Unit
		end
	end

	return rootPart.CFrame.LookVector
end

return InputController
