local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreatureConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CreatureConfig"))

local CreatureAI = {}

local CombatService -- set via Init
local HollowBuilder -- set via Init

local creatures = {} -- [creatureModel] = { config, state, lastAttack, ... }
local heartbeatConn = nil

function CreatureAI.Init(combatSvc, dungeonSvc)
	CombatService = combatSvc
	HollowBuilder = dungeonSvc
end

function CreatureAI.RegisterEnemy(creatureModel, configId)
	local config = CreatureConfig.Creatures[configId]
	if not config then return end

	creatures[creatureModel] = {
		Config = config,
		ConfigId = configId,
		State = "Idle",
		LastAttack = 0,
		LastSlamTime = 0,
		HasSummoned = false,
		Target = nil,
	}
end

function CreatureAI.UnregisterEnemy(creatureModel)
	creatures[creatureModel] = nil
end

function CreatureAI.StartLoop()
	if heartbeatConn then return end

	heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		for creatureModel, data in pairs(creatures) do
			if not creatureModel.Parent or creatureModel:GetAttribute("IsDead") then
				creatures[creatureModel] = nil
				continue
			end

			local rootPart = creatureModel:FindFirstChild("HumanoidRootPart")
			local humanoid = creatureModel:FindFirstChild("Humanoid")
			if not rootPart or not humanoid then continue end

			-- Find nearest player
			local nearestPlayer, nearestDist = CreatureAI.FindNearestPlayer(rootPart.Position, data.Config.DetectionRange)
			data.Target = nearestPlayer

			if data.Config.Behavior == "Boss" then
				CreatureAI.UpdateBoss(creatureModel, data, rootPart, humanoid, dt)
			elseif data.Config.Behavior == "Ranged" then
				CreatureAI.UpdateRanged(creatureModel, data, rootPart, humanoid, dt)
			else
				CreatureAI.UpdateMelee(creatureModel, data, rootPart, humanoid, dt)
			end
		end
	end)
end

function CreatureAI.StopLoop()
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
	creatures = {}
end

function CreatureAI.FindNearestPlayer(position, maxRange)
	local nearest = nil
	local nearestDist = maxRange

	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char then
			local humanoid = char:FindFirstChild("Humanoid")
			local rootPart = char:FindFirstChild("HumanoidRootPart")
			if humanoid and humanoid.Health > 0 and rootPart then
				local dist = (rootPart.Position - position).Magnitude
				if dist < nearestDist then
					nearest = player
					nearestDist = dist
				end
			end
		end
	end

	return nearest, nearestDist
end

function CreatureAI.UpdateMelee(creatureModel, data, rootPart, humanoid, dt)
	local config = data.Config
	local target = data.Target

	if not target then
		data.State = "Idle"
		humanoid:MoveTo(rootPart.Position) -- stop moving
		return
	end

	local targetChar = target.Character
	if not targetChar then return end
	local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end

	local distance = (targetRoot.Position - rootPart.Position).Magnitude

	if distance <= config.AttackRange then
		data.State = "Attack"
		-- Attack if cooldown ready
		if os.clock() - data.LastAttack >= config.AttackInterval then
			data.LastAttack = os.clock()
			CombatService.DealDamageToPlayer(target, config.Damage)
		end
		-- Face the player
		local lookCF = CFrame.lookAt(rootPart.Position, Vector3.new(targetRoot.Position.X, rootPart.Position.Y, targetRoot.Position.Z))
		rootPart.CFrame = lookCF
	else
		data.State = "Chase"
		humanoid.WalkSpeed = config.Speed
		humanoid:MoveTo(targetRoot.Position)
	end
end

function CreatureAI.UpdateRanged(creatureModel, data, rootPart, humanoid, dt)
	local config = data.Config
	local target = data.Target

	if not target then
		data.State = "Idle"
		humanoid:MoveTo(rootPart.Position) -- stop moving
		return
	end

	local targetChar = target.Character
	if not targetChar then return end
	local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end

	local distance = (targetRoot.Position - rootPart.Position).Magnitude
	local preferred = config.PreferredDistance or 20

	if distance < preferred - 5 then
		-- Too close, back away
		data.State = "Chase"
		local awayDir = (rootPart.Position - targetRoot.Position).Unit
		humanoid:MoveTo(rootPart.Position + awayDir * 10)
	elseif distance > preferred + 10 then
		-- Too far, approach
		data.State = "Chase"
		humanoid:MoveTo(targetRoot.Position)
	else
		-- Good range, attack
		data.State = "Attack"
		-- Face target
		local lookCF = CFrame.lookAt(rootPart.Position, Vector3.new(targetRoot.Position.X, rootPart.Position.Y, targetRoot.Position.Z))
		rootPart.CFrame = lookCF

		if os.clock() - data.LastAttack >= config.AttackInterval then
			data.LastAttack = os.clock()
			CreatureAI.ShootArrow(rootPart, targetRoot, config)
		end
	end
end

function CreatureAI.ShootArrow(fromRoot, targetRoot, config)
	local startPos = fromRoot.Position + Vector3.new(0, 2, 0)
	local direction = (targetRoot.Position - startPos).Unit

	local arrow = Instance.new("Part")
	arrow.Name = "Arrow"
	arrow.Size = Vector3.new(0.3, 0.3, 2)
	arrow.BrickColor = BrickColor.new("Brown")
	arrow.Material = Enum.Material.Wood
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.CFrame = CFrame.lookAt(startPos, startPos + direction)
	arrow.Parent = workspace

	local speed = config.ProjectileSpeed or 60
	local startTime = os.clock()

	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if os.clock() - startTime > 3 then
			conn:Disconnect()
			arrow:Destroy()
			return
		end

		local newPos = arrow.Position + direction * speed * dt
		arrow.CFrame = CFrame.lookAt(newPos, newPos + direction)

		-- Check hit on players
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			if char then
				local playerRoot = char:FindFirstChild("HumanoidRootPart")
				local hum = char:FindFirstChild("Humanoid")
				if playerRoot and hum and hum.Health > 0 then
					if (playerRoot.Position - newPos).Magnitude < 4 then
						CombatService.DealDamageToPlayer(player, config.Damage)
						conn:Disconnect()
						arrow:Destroy()
						return
					end
				end
			end
		end
	end)
end

function CreatureAI.UpdateBoss(creatureModel, data, rootPart, humanoid, dt)
	local config = data.Config
	local target = data.Target

	if not target then
		data.State = "Idle"
		return
	end

	-- Check for summon at health threshold
	local currentHP = creatureModel:GetAttribute("CurrentHP") or 0
	local maxHP = creatureModel:GetAttribute("MaxHP") or 1
	if not data.HasSummoned and currentHP / maxHP <= config.SummonAtHealthPercent then
		data.HasSummoned = true
		CreatureAI.BossSummon(creatureModel, rootPart, config)
	end

	-- Phase transitions
	local hpFraction = currentHP / maxHP
	if config.Phases then
		local currentPhaseIndex = data.CurrentPhase or 0
		for i, phase in ipairs(config.Phases) do
			if i > currentPhaseIndex and hpFraction <= phase.Threshold then
				data.CurrentPhase = i
				-- Apply phase changes
				if phase.SpeedMultiplier then
					humanoid.WalkSpeed = config.Speed * phase.SpeedMultiplier
				end
				if phase.SlamCooldown then
					data.PhaseSlamCooldown = phase.SlamCooldown
					data.PhaseSlamDamage = phase.SlamDamage
				end
				-- Color change
				if phase.BodyColor then
					for _, part in ipairs(creatureModel:GetDescendants()) do
						if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
							part.BrickColor = phase.BodyColor
						end
					end
				end
				-- Phase summon
				if phase.SummonCount and phase.SummonType then
					for s = 1, phase.SummonCount do
						local offset = Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
						local spawnPos = rootPart.Position + offset
						local roomFolder = creatureModel.Parent
						if roomFolder and HollowBuilder then
							HollowBuilder.SpawnSingleEnemy(phase.SummonType, spawnPos, roomFolder)
						end
					end
				end
				-- Visual burst effect
				local burst = Instance.new("Part")
				burst.Shape = Enum.PartType.Ball
				burst.Size = Vector3.new(3, 3, 3)
				burst.Position = rootPart.Position
				burst.BrickColor = phase.BodyColor or BrickColor.new("Bright red")
				burst.Material = Enum.Material.Neon
				burst.Transparency = 0.3
				burst.Anchored = true
				burst.CanCollide = false
				burst.Parent = workspace
				local TweenService = game:GetService("TweenService")
				local tween = TweenService:Create(burst, TweenInfo.new(0.8), {
					Size = Vector3.new(30, 30, 30),
					Transparency = 1,
				})
				tween:Play()
				tween.Completed:Connect(function() burst:Destroy() end)

				-- Notify clients
				local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
				local remote = Remotes:GetEvent("BossPhaseChanged")
				if remote then
					remote:FireAllClients(phase.Name, hpFraction)
				end
				break
			end
		end
	end

	-- Ground slam on cooldown
	local slamCooldown = data.PhaseSlamCooldown or config.SlamCooldown
	if os.clock() - data.LastSlamTime >= slamCooldown then
		local targetChar = target.Character
		if targetChar then
			local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
			if targetRoot and (targetRoot.Position - rootPart.Position).Magnitude <= config.SlamRadius + 5 then
				data.LastSlamTime = os.clock()
				local slamDamage = data.PhaseSlamDamage or config.SlamDamage
				CreatureAI.BossGroundSlam(rootPart, config, slamDamage)
				return
			end
		end
	end

	-- Default melee behavior
	CreatureAI.UpdateMelee(creatureModel, data, rootPart, humanoid, dt)
end

function CreatureAI.BossGroundSlam(rootPart, config, overrideDamage)
	-- Warning indicator
	local warning = Instance.new("Part")
	warning.Shape = Enum.PartType.Cylinder
	warning.Size = Vector3.new(1, config.SlamRadius * 2, config.SlamRadius * 2)
	warning.CFrame = CFrame.new(rootPart.Position.X, rootPart.Position.Y - 2, rootPart.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
	warning.BrickColor = BrickColor.new("Bright red")
	warning.Material = Enum.Material.Neon
	warning.Transparency = 0.5
	warning.Anchored = true
	warning.CanCollide = false
	warning.Parent = workspace

	-- Pulse the warning
	task.delay(config.SlamWarningTime, function()
		-- Deal damage to all players in radius
		local slamPos = rootPart.Position
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			if char then
				local playerRoot = char:FindFirstChild("HumanoidRootPart")
				local hum = char:FindFirstChild("Humanoid")
				if playerRoot and hum and hum.Health > 0 then
					if (playerRoot.Position - slamPos).Magnitude <= config.SlamRadius then
						CombatService.DealDamageToPlayer(player, overrideDamage or config.SlamDamage)
					end
				end
			end
		end

		-- Visual slam effect
		local TweenService = game:GetService("TweenService")
		warning.BrickColor = BrickColor.new("Bright yellow")
		local tween = TweenService:Create(warning, TweenInfo.new(0.5), { Transparency = 1 })
		tween:Play()
		tween.Completed:Connect(function()
			warning:Destroy()
		end)
	end)
end

function CreatureAI.BossSummon(creatureModel, rootPart, config)
	if not HollowBuilder then return end

	for i = 1, config.SummonCount do
		local offset = Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
		local spawnPos = rootPart.Position + offset
		local roomFolder = creatureModel.Parent
		if roomFolder then
			HollowBuilder.SpawnSingleEnemy(config.SummonType, spawnPos, roomFolder)
		end
	end
end

return CreatureAI
