local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local CombatController = {}

local hud -- set via Init

function CombatController.Init(mainHUD)
	hud = mainHUD

	-- Listen for damage taken
	local takeDamageRemote = Remotes:GetEvent("TakeDamage")
	if takeDamageRemote then
		takeDamageRemote.OnClientEvent:Connect(function(damage)
			CombatController.OnDamageTaken(damage)
		end)
	end

	-- Listen for enemy death
	local enemyDiedRemote = Remotes:GetEvent("EnemyDied")
	if enemyDiedRemote then
		enemyDiedRemote.OnClientEvent:Connect(function(enemyModel, position)
			CombatController.OnEnemyDied(enemyModel, position)
		end)
	end
end

function CombatController.OnDamageTaken(damage)
	if not hud then return end

	local flash = hud:FindFirstChild("DamageFlash")
	if flash then
		flash.BackgroundTransparency = 0.5

		local tween = TweenService:Create(flash, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		})
		tween:Play()
	end
end

function CombatController.OnEnemyDied(enemyModel, position)
	if not enemyModel or not enemyModel.Parent then return end

	-- Fade out enemy model
	for _, part in ipairs(enemyModel:GetDescendants()) do
		if part:IsA("BasePart") then
			local tween = TweenService:Create(part, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
				Transparency = 1,
			})
			tween:Play()
		end
	end
end

return CombatController
