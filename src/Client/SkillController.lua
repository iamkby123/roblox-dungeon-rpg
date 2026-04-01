local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SkillConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local SkillController = {}

local cooldowns = {} -- [weaponId] = expiryTime
local equippedSlot = 1 -- start with sword

function SkillController.Init()
	for weaponId, _ in pairs(SkillConfig.Weapons) do
		cooldowns[weaponId] = 0
	end
end

function SkillController.EquipSlot(slot)
	if slot >= 1 and slot <= 4 then
		equippedSlot = slot
	end
end

function SkillController.GetEquippedSlot()
	return equippedSlot
end

function SkillController.GetEquippedWeaponId()
	return SkillConfig.SlotToWeapon[equippedSlot]
end

function SkillController.CycleWeapon(delta)
	equippedSlot = ((equippedSlot - 1 + delta) % 4) + 1
end

function SkillController.UseEquippedWeapon(direction)
	local weaponId = SkillConfig.SlotToWeapon[equippedSlot]
	if not weaponId then return end

	-- Check local cooldown
	if os.clock() < (cooldowns[weaponId] or 0) then
		return
	end

	-- Set local cooldown (optimistic)
	local weaponData = SkillConfig.Weapons[weaponId]
	if not weaponData then return end
	cooldowns[weaponId] = os.clock() + weaponData.Cooldown

	-- Trigger viewmodel attack animation
	local ok, vmc = pcall(require, script.Parent:FindFirstChild("ViewmodelController"))
	if ok and vmc and vmc.PlayAttackAnimation then
		vmc.PlayAttackAnimation()
	end

	-- Fire to server (still uses "UseSkill" remote, sends weaponId)
	local remote = Remotes:GetEvent("UseSkill")
	if remote then
		remote:FireServer(weaponId, direction)
	end
end

-- Legacy support for direct slot use
function SkillController.UseSkill(slot, direction)
	SkillController.EquipSlot(slot)
	SkillController.UseEquippedWeapon(direction)
end

function SkillController.GetCooldownRemaining(weaponId)
	local expiry = cooldowns[weaponId] or 0
	local remaining = expiry - os.clock()
	return math.max(0, remaining)
end

function SkillController.GetCooldownFraction(weaponId)
	local weaponData = SkillConfig.Weapons[weaponId]
	if not weaponData then return 0 end

	local remaining = SkillController.GetCooldownRemaining(weaponId)
	if remaining <= 0 then return 0 end

	return remaining / weaponData.Cooldown
end

return SkillController
