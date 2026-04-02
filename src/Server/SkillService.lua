local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SkillConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local SkillService = {}

local CombatService -- set via Init

function SkillService.Init(combatSvc)
	CombatService = combatSvc

	local useSkillRemote = Remotes:GetEvent("UseSkill")
	if useSkillRemote then
		useSkillRemote.OnServerEvent:Connect(function(player, skillId, direction)
			-- Validate skillId
			if type(skillId) ~= "string" then return end
			if not SkillConfig.Skills[skillId] then return end

			-- Validate direction
			if direction then
				if typeof(direction) ~= "Vector3" then return end
				if direction.Magnitude < 0.1 then
					direction = nil
				else
					direction = direction.Unit
				end
			end

			CombatService.ProcessSkill(player, skillId, direction)
		end)
	end
end

return SkillService
