local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local InputController = {}

local SkillController -- set via Init

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

		-- Scroll wheel to cycle weapons
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			-- Handled via InputChanged instead
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
		local direction = (targetPos - rootPart.Position)
		if direction.Magnitude > 0.1 then
			return direction.Unit
		end
	end

	return rootPart.CFrame.LookVector
end

return InputController
