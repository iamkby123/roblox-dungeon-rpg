local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local StatConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("StatConfig"))
local SkillConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SkillConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local CombatService = {}

local PlayerDataService -- set via Init to avoid circular require
local DungeonService -- set via Init
local CatacombsProgression -- set via Init

local cooldowns = {} -- [player][skillId] = expiryTime
local activeConnections = {} -- [player] = { connection1, connection2, ... }

-- Miniboss enemy IDs (drop keys; use keeper XP tier)
local KEEPER_IDS = {
	IronKeeper = true, GoldGuardian = true, CrimsonSentinel = true,
	EmeraldWarden = true, ShadowChampion = true,
}

function CombatService.Init(playerDataSvc, dungeonSvc, catacombsSvc)
	PlayerDataService = playerDataSvc
	DungeonService = dungeonSvc
	CatacombsProgression = catacombsSvc
end

local function trackConnection(player, conn)
	if not activeConnections[player] then
		activeConnections[player] = {}
	end
	table.insert(activeConnections[player], conn)
end

function CombatService.ProcessSkill(player, skillId, direction)
	local skillData = SkillConfig.Skills[skillId]
	if not skillData then return false end

	-- Check cooldown
	if not cooldowns[player] then
		cooldowns[player] = {}
	end
	if cooldowns[player][skillId] and os.clock() < cooldowns[player][skillId] then
		return false
	end

	-- Check mana
	if skillData.ManaCost > 0 then
		if not PlayerDataService.ConsumeMana(player, skillData.ManaCost) then
			return false
		end
	end

	-- Set cooldown
	cooldowns[player][skillId] = os.clock() + skillData.Cooldown

	-- Execute skill
	local character = player.Character
	if not character then return false end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return false end

	if skillData.Type == "MeleeAoE" then
		CombatService.ExecuteSlash(player, rootPart, skillData, direction)
	elseif skillData.Type == "Projectile" then
		CombatService.ExecuteFireball(player, rootPart, skillData, direction)
	elseif skillData.Type == "Self" then
		CombatService.ExecuteHeal(player, skillData)
	elseif skillData.Type == "Buff" then
		CombatService.ExecuteShield(player, skillData)
	end

	return true
end

function CombatService.ExecuteSlash(player, rootPart, skillData, direction)
	local stats = PlayerDataService.GetStats(player)
	if not stats then return end

	local pos = rootPart.Position
	local lookDir = direction and direction.Unit or rootPart.CFrame.LookVector

	-- Find enemies in range and cone
	local dungeonFolder = workspace:FindFirstChild("Dungeon")
	if not dungeonFolder then return end

	for _, enemyModel in ipairs(dungeonFolder:GetDescendants()) do
		if enemyModel:IsA("Model") and enemyModel:GetAttribute("IsEnemy") then
			local enemyRoot = enemyModel:FindFirstChild("HumanoidRootPart")
			if enemyRoot then
				local toEnemy = (enemyRoot.Position - pos)
				local distance = toEnemy.Magnitude
				if distance <= skillData.Range then
					-- Cone check: within 90 degrees of look direction
					local dot = lookDir:Dot(toEnemy.Unit)
					if dot > 0 then -- roughly 90 degree cone
						local damage, isCrit = StatConfig.CalculateDamage(
							stats.Strength,
							skillData.Multiplier,
							enemyModel:GetAttribute("Defense") or 0,
							stats.CritChance,
							stats.CritDamage
						)
						CombatService.DealDamageToEnemy(player, enemyModel, damage, isCrit)
					end
				end
			end
		end
	end
end

function CombatService.ExecuteFireball(player, rootPart, skillData, direction)
	local stats = PlayerDataService.GetStats(player)
	if not stats then return end

	local startPos = rootPart.Position + Vector3.new(0, 2, 0)
	local dir = direction and direction.Unit or rootPart.CFrame.LookVector

	-- Create projectile
	local fireball = Instance.new("Part")
	fireball.Name = "Fireball"
	fireball.Shape = Enum.PartType.Ball
	fireball.Size = Vector3.new(2, 2, 2)
	fireball.BrickColor = BrickColor.new("Bright orange")
	fireball.Material = Enum.Material.Neon
	fireball.Anchored = true
	fireball.CanCollide = false
	fireball.Position = startPos
	fireball.Parent = workspace

	-- Add light
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 0)
	light.Range = 15
	light.Brightness = 2
	light.Parent = fireball

	-- Add particle effect
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(Color3.fromRGB(255, 100, 0), Color3.fromRGB(255, 255, 0))
	particles.Size = NumberSequence.new(1, 0)
	particles.Lifetime = NumberRange.new(0.3, 0.5)
	particles.Rate = 50
	particles.Speed = NumberRange.new(2, 5)
	particles.Parent = fireball

	local startTime = os.clock()
	local maxDuration = 2.0
	local hasHit = false

	-- Move projectile each frame
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if hasHit or os.clock() - startTime > maxDuration then
			connection:Disconnect()
			fireball:Destroy()
			return
		end

		local newPos = fireball.Position + dir * skillData.Speed * dt
		fireball.Position = newPos

		-- Check for enemy hits via overlap (single pass)
		local dungeonFolder = workspace:FindFirstChild("Dungeon")
		if not dungeonFolder then return end

		-- Collect all living enemies once
		local enemiesInRange = {}
		local hitDetected = false

		for _, enemyModel in ipairs(dungeonFolder:GetDescendants()) do
			if enemyModel:IsA("Model") and enemyModel:GetAttribute("IsEnemy") then
				local enemyRoot = enemyModel:FindFirstChild("HumanoidRootPart")
				if enemyRoot then
					local dist = (enemyRoot.Position - newPos).Magnitude
					if dist <= skillData.AoERadius then
						if not hitDetected then
							hitDetected = true
						end
						table.insert(enemiesInRange, enemyModel)
					end
				end
			end
		end

		if hitDetected then
			hasHit = true

			-- Damage all enemies in AoE radius
			for _, enemyModel in ipairs(enemiesInRange) do
				local damage, isCrit = StatConfig.CalculateDamage(
					stats.Strength,
					skillData.Multiplier,
					enemyModel:GetAttribute("Defense") or 0,
					stats.CritChance,
					stats.CritDamage
				)
				CombatService.DealDamageToEnemy(player, enemyModel, damage, isCrit)
			end

			-- Explosion effect
			local TweenService = game:GetService("TweenService")
			local explosion = Instance.new("Part")
			explosion.Shape = Enum.PartType.Ball
			explosion.Size = Vector3.new(1, 1, 1)
			explosion.Position = newPos
			explosion.BrickColor = BrickColor.new("Bright orange")
			explosion.Material = Enum.Material.Neon
			explosion.Transparency = 0.3
			explosion.Anchored = true
			explosion.CanCollide = false
			explosion.Parent = workspace

			local tween = TweenService:Create(explosion, TweenInfo.new(0.5), {
				Size = Vector3.new(skillData.AoERadius * 2, skillData.AoERadius * 2, skillData.AoERadius * 2),
				Transparency = 1,
			})
			tween:Play()
			tween.Completed:Connect(function()
				explosion:Destroy()
			end)

			connection:Disconnect()
			fireball:Destroy()
			return
		end
	end)
	trackConnection(player, connection)
end

function CombatService.ExecuteHeal(player, skillData)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local healAmount = humanoid.MaxHealth * skillData.HealPercent
	humanoid.Health = math.min(humanoid.Health + healAmount, humanoid.MaxHealth)

	-- Green heal effect
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		local particles = Instance.new("ParticleEmitter")
		particles.Color = ColorSequence.new(Color3.fromRGB(0, 255, 100))
		particles.Size = NumberSequence.new(1, 0)
		particles.Lifetime = NumberRange.new(0.5, 1)
		particles.Rate = 30
		particles.Speed = NumberRange.new(3, 6)
		particles.Parent = rootPart

		task.delay(1, function()
			particles:Destroy()
		end)
	end
end

function CombatService.ExecuteShield(player, skillData)
	PlayerDataService.ApplyShieldBuff(player, skillData.DefenseBonus, skillData.Duration)

	-- Blue shield effect
	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local shield = Instance.new("Part")
	shield.Shape = Enum.PartType.Ball
	shield.Size = Vector3.new(8, 8, 8)
	shield.Position = rootPart.Position
	shield.BrickColor = BrickColor.new("Cyan")
	shield.Material = Enum.Material.ForceField
	shield.Transparency = 0.7
	shield.Anchored = true
	shield.CanCollide = false
	shield.Parent = workspace

	-- Follow player and fade
	local startTime = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if os.clock() - startTime > skillData.Duration then
			conn:Disconnect()
			shield:Destroy()
			return
		end
		if rootPart and rootPart.Parent then
			shield.Position = rootPart.Position
		else
			conn:Disconnect()
			shield:Destroy()
		end
	end)
	trackConnection(player, conn)
end

function CombatService.DealDamageToEnemy(player, enemyModel, damage, isCrit)
	local currentHP = enemyModel:GetAttribute("CurrentHP") or 0
	currentHP = currentHP - damage
	enemyModel:SetAttribute("CurrentHP", currentHP)

	-- Track total damage for score
	if DungeonService then
		DungeonService.AddDamageTracking(player, damage)
	end

	-- Update health bar
	local healthBar = enemyModel:FindFirstChild("HealthBar", true)
	if healthBar then
		local maxHP = enemyModel:GetAttribute("MaxHP") or 1
		local fill = healthBar:FindFirstChild("Fill")
		if fill then
			fill.Size = UDim2.new(math.clamp(currentHP / maxHP, 0, 1), 0, 1, 0)
		end
	end

	-- Notify clients for damage numbers
	local remote = Remotes:GetEvent("EnemyDamaged")
	if remote then
		local enemyRoot = enemyModel:FindFirstChild("HumanoidRootPart")
		local pos = enemyRoot and enemyRoot.Position or enemyModel:GetPivot().Position
		remote:FireAllClients(pos, damage, isCrit)
	end

	-- Check death
	if currentHP <= 0 then
		CombatService.OnEnemyDied(player, enemyModel)
	end
end

function CombatService.OnEnemyDied(player, enemyModel)
	enemyModel:SetAttribute("IsEnemy", false)
	enemyModel:SetAttribute("IsDead", true)

	-- Award Catacombs XP for the kill
	if CatacombsProgression then
		local enemyId = enemyModel:GetAttribute("EnemyId") or ""
		local dropsKey = enemyModel:GetAttribute("DropsKey")
		if dropsKey then
			CatacombsProgression.OnKeeperKill(player, enemyId)
		elseif not enemyModel:GetAttribute("IsBoss") then
			CatacombsProgression.OnMobKill(player, enemyId)
		end
		-- Boss XP is awarded via OnDungeonClear when the boss room clears
	end

	-- Notify clients
	local remote = Remotes:GetEvent("EnemyDied")
	if remote then
		local enemyRoot = enemyModel:FindFirstChild("HumanoidRootPart")
		local pos = enemyRoot and enemyRoot.Position or enemyModel:GetPivot().Position
		remote:FireAllClients(enemyModel, pos)
	end

	-- Notify dungeon service
	if DungeonService then
		DungeonService.OnEnemyDied(enemyModel)
	end

	-- Destroy after delay for death animation
	task.delay(1, function()
		if enemyModel and enemyModel.Parent then
			enemyModel:Destroy()
		end
	end)
end

function CombatService.DealDamageToPlayer(player, rawDamage)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local defense = PlayerDataService.GetEffectiveDefense(player)
	local reduction = defense / (defense + 100)
	local finalDamage = math.floor(rawDamage * (1 - reduction))

	humanoid:TakeDamage(finalDamage)

	-- Notify client
	local remote = Remotes:GetEvent("TakeDamage")
	if remote then
		remote:FireClient(player, finalDamage)
	end
end

function CombatService.CleanupPlayer(player)
	cooldowns[player] = nil
	-- Disconnect any active effect connections
	if activeConnections[player] then
		for _, conn in ipairs(activeConnections[player]) do
			if conn and conn.Connected then
				conn:Disconnect()
			end
		end
		activeConnections[player] = nil
	end
end

return CombatService
