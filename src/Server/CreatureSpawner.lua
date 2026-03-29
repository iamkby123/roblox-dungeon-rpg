local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreatureConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CreatureConfig"))

local CreatureSpawner = {}

local HollowBuilder -- set via Init
local CreatureAI -- set via Init

--------------------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------------------
local SPAWN_POINT_TAG = "CreatureSpawnPoint"
local CLEAR_INDICATOR_TAG = "ClearIndicator"

-- Basic mob pool for normal rooms (weighted)
local BASIC_CREATURE_POOL = {
	{ Id = "Skeleton",       Weight = 5 },
	{ Id = "Zombie",         Weight = 4 },
	{ Id = "Bat",            Weight = 4 },
	{ Id = "Spider",         Weight = 3 },
	{ Id = "Archer",         Weight = 3 },
	{ Id = "Wraith",         Weight = 2 },
	{ Id = "Mage",           Weight = 2 },
	{ Id = "SkeletonKnight", Weight = 1 },
}

local BASIC_CREATURE_TOTAL_WEIGHT = 0
local BASIC_CREATURE_CUMULATIVE = {}
for _, entry in ipairs(BASIC_CREATURE_POOL) do
	BASIC_CREATURE_TOTAL_WEIGHT = BASIC_CREATURE_TOTAL_WEIGHT + entry.Weight
	table.insert(BASIC_CREATURE_CUMULATIVE, { Id = entry.Id, Cum = BASIC_CREATURE_TOTAL_WEIGHT })
end

-- Keeper (warden) enemies mapped by room template name
local WARDEN_MAP = {
	["Iron Keep"]   = "IronKeeper",
	["Gold Vault"]  = "GoldGuardian",
	["Blood Altar"] = "CrimsonSentinel",
	["Mage Tower"]  = "EmeraldWarden",
	["Bone Pit"]    = "ShadowChampion",
}

local NORMAL_CREATURE_MIN = 3
local NORMAL_CREATURE_MAX = 6

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------
-- Per-spawner instance state keyed by a session id
-- {
--   Rooms = { [roomKey] = RoomState },
--   WardensAlive = number,
--   BossRoomKey = string or nil,
-- }
--
-- RoomState:
-- {
--   RoomType    = string,
--   Enemies     = { Model, ... },
--   Cleared     = boolean,
--   Folder      = Instance,
--   TriggerConn = RBXScriptConnection or nil,
-- }

local sessions = {} -- [sessionId] = session

local nextSessionId = 0

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------
local function randomBasicCreatureId()
	local roll = math.random() * BASIC_CREATURE_TOTAL_WEIGHT
	for _, entry in ipairs(BASIC_CREATURE_CUMULATIVE) do
		if roll <= entry.Cum then
			return entry.Id
		end
	end
	return BASIC_CREATURE_POOL[#BASIC_CREATURE_POOL].Id
end

-- Collect tagged SpawnPoint parts from a room instance, sorted by name for
-- deterministic ordering.
local function getSpawnPoints(roomInstance)
	local points = {}
	for _, desc in ipairs(roomInstance:GetDescendants()) do
		if desc:IsA("BasePart") and CollectionService:HasTag(desc, SPAWN_POINT_TAG) then
			table.insert(points, desc)
		end
	end
	table.sort(points, function(a, b) return a.Name < b.Name end)
	return points
end

-- Fallback: generate spawn positions in a circle around the room center
local function generateFallbackPositions(roomInstance, count)
	local positions = {}
	-- Try to find a floor part for center reference
	local floor = roomInstance:FindFirstChild("Floor")
	local center, roomSize
	if floor and floor:IsA("BasePart") then
		center = floor.Position + Vector3.new(0, floor.Size.Y / 2 + 3, 0)
		roomSize = floor.Size
	else
		-- Use bounding box
		local cf, size = roomInstance:GetBoundingBox()
		center = cf.Position + Vector3.new(0, 3, 0)
		roomSize = size
	end

	local radius = math.min(roomSize.X, roomSize.Z) * 0.3
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		table.insert(positions, center + offset)
	end
	return positions
end

-- Activate the clear indicator inside a room (green light + particles)
local function activateClearIndicator(roomInstance)
	for _, desc in ipairs(roomInstance:GetDescendants()) do
		if desc:IsA("BasePart") and CollectionService:HasTag(desc, CLEAR_INDICATOR_TAG) then
			-- Green glow
			local light = desc:FindFirstChildWhichIsA("PointLight")
			if not light then
				light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(50, 255, 80)
				light.Range = 25
				light.Brightness = 2
				light.Parent = desc
			else
				light.Color = Color3.fromRGB(50, 255, 80)
				light.Enabled = true
			end

			-- Particle burst
			local emitter = desc:FindFirstChildWhichIsA("ParticleEmitter")
			if not emitter then
				emitter = Instance.new("ParticleEmitter")
				emitter.Color = ColorSequence.new(Color3.fromRGB(50, 255, 80))
				emitter.Size = NumberSequence.new(0.4, 0)
				emitter.Lifetime = NumberRange.new(0.8, 1.5)
				emitter.Rate = 15
				emitter.Speed = NumberRange.new(2, 5)
				emitter.SpreadAngle = Vector2.new(360, 360)
				emitter.Parent = desc
			else
				emitter.Enabled = true
			end

			-- Make the part itself glow green
			desc.Material = Enum.Material.Neon
			desc.Color = Color3.fromRGB(50, 255, 80)
			return -- only activate the first indicator found
		end
	end

	-- No tagged indicator found — place one on the floor as fallback
	local floor = roomInstance:FindFirstChild("Floor")
	if floor and floor:IsA("BasePart") then
		local indicator = Instance.new("Part")
		indicator.Name = "ClearIndicator"
		indicator.Size = Vector3.new(4, 0.5, 4)
		indicator.Position = floor.Position + Vector3.new(0, floor.Size.Y / 2 + 0.3, 0)
		indicator.Anchored = true
		indicator.CanCollide = false
		indicator.Material = Enum.Material.Neon
		indicator.Color = Color3.fromRGB(50, 255, 80)
		indicator.Parent = roomInstance

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(50, 255, 80)
		light.Range = 25
		light.Brightness = 2
		light.Parent = indicator

		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(Color3.fromRGB(50, 255, 80))
		emitter.Size = NumberSequence.new(0.4, 0)
		emitter.Lifetime = NumberRange.new(0.8, 1.5)
		emitter.Rate = 15
		emitter.Speed = NumberRange.new(2, 5)
		emitter.SpreadAngle = Vector2.new(360, 360)
		emitter.Parent = indicator
	end
end

--------------------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------------------
function CreatureSpawner.Init(dungeonSvc, enemyAISvc)
	HollowBuilder = dungeonSvc
	CreatureAI = enemyAISvc
end

--------------------------------------------------------------------------------
-- CreateSession(rooms)
--
-- rooms: array of { RoomType, Folder, TemplateName, DropsKey? }
--   RoomType: "normal" | "trap" | "warden" | "boss"
--   Folder: the cloned room Instance in workspace
--   TemplateName: the room template name (e.g. "Iron Keep") for keeper lookup
--   DropsKey: (optional) key type string the keeper should drop
--
-- Returns a sessionId that can be used with other CreatureSpawner functions.
--------------------------------------------------------------------------------
function CreatureSpawner.CreateSession(rooms)
	nextSessionId = nextSessionId + 1
	local sessionId = nextSessionId

	local session = {
		Rooms = {},
		WardensAlive = 0,
		BossRoomKey = nil,
	}

	for i, roomDef in ipairs(rooms) do
		local roomKey = tostring(i)
		local roomState = {
			RoomType  = roomDef.RoomType,
			Enemies   = {},
			Cleared   = false,
			Folder    = roomDef.Folder,
			DropsKey  = roomDef.DropsKey,
			TemplateName = roomDef.TemplateName,
			TriggerConn = nil,
		}
		session.Rooms[roomKey] = roomState

		if roomDef.RoomType == "warden" then
			session.WardensAlive = session.WardensAlive + 1
		elseif roomDef.RoomType == "boss" then
			session.BossRoomKey = roomKey
		end
	end

	sessions[sessionId] = session
	return sessionId
end

--------------------------------------------------------------------------------
-- SpawnRoom(sessionId, roomIndex)
--
-- Spawns mobs for the given room based on its RoomType.
-- Normal: 3–6 random basic mobs at SpawnPoints (or fallback circle positions).
-- Trap: attaches a trigger — mobs spawn when a player touches a TrapTrigger part.
-- Warden: spawns one keeper enemy.
-- Boss: does nothing until ActivateBossRoom() is called.
--------------------------------------------------------------------------------
function CreatureSpawner.SpawnRoom(sessionId, roomIndex)
	local session = sessions[sessionId]
	if not session then return end

	local roomKey = tostring(roomIndex)
	local room = session.Rooms[roomKey]
	if not room then return end
	if room.Cleared then return end

	local roomType = room.RoomType
	local folder = room.Folder

	if roomType == "normal" or roomType == "puzzle" then
		CreatureSpawner._SpawnNormalRoom(session, room)
	elseif roomType == "trap" then
		CreatureSpawner._SetupTrapRoom(session, room, sessionId, roomKey)
	elseif roomType == "warden" then
		CreatureSpawner._SpawnWardenRoom(session, room)
	end
	-- boss: intentionally skipped — call ActivateBossRoom separately
end

--------------------------------------------------------------------------------
-- ActivateBossRoom(sessionId)
--
-- Called when all wardenes are dead. Spawns the boss in the boss room.
--------------------------------------------------------------------------------
function CreatureSpawner.ActivateBossRoom(sessionId)
	local session = sessions[sessionId]
	if not session or not session.BossRoomKey then return end

	local room = session.Rooms[session.BossRoomKey]
	if not room or room.Cleared then return end

	local folder = room.Folder
	local spawnPoints = getSpawnPoints(folder)
	local spawnPos
	if #spawnPoints > 0 then
		spawnPos = spawnPoints[1].Position + Vector3.new(0, 3, 0)
	else
		local positions = generateFallbackPositions(folder, 1)
		spawnPos = positions[1]
	end

	local model = HollowBuilder.SpawnSingleEnemy("BossGolem", spawnPos, folder)
	if model then
		table.insert(room.Enemies, model)
	end
end

--------------------------------------------------------------------------------
-- OnEnemyDied(sessionId, enemyModel)
--
-- Call this when an enemy dies to update per-room clear state.
-- Returns roomKey, isCleared, allWardenesDead
--------------------------------------------------------------------------------
function CreatureSpawner.OnEnemyDied(sessionId, enemyModel)
	local session = sessions[sessionId]
	if not session then return nil, false, false end

	for roomKey, room in pairs(session.Rooms) do
		for i, model in ipairs(room.Enemies) do
			if model == enemyModel then
				table.remove(room.Enemies, i)

				-- Track warden deaths
				if room.RoomType == "warden" then
					session.WardensAlive = math.max(0, session.WardensAlive - 1)
				end

				-- Check if room is now cleared
				if #room.Enemies <= 0 and not room.Cleared then
					room.Cleared = true
					activateClearIndicator(room.Folder)

					local allWardenesDead = session.WardensAlive <= 0
					return roomKey, true, allWardenesDead
				end

				return roomKey, false, session.WardensAlive <= 0
			end
		end
	end

	return nil, false, false
end

--------------------------------------------------------------------------------
-- IsRoomCleared(sessionId, roomIndex) → boolean
--------------------------------------------------------------------------------
function CreatureSpawner.IsRoomCleared(sessionId, roomIndex)
	local session = sessions[sessionId]
	if not session then return false end
	local room = session.Rooms[tostring(roomIndex)]
	return room and room.Cleared or false
end

--------------------------------------------------------------------------------
-- GetClearState(sessionId) → { [roomKey] = boolean }
--------------------------------------------------------------------------------
function CreatureSpawner.GetClearState(sessionId)
	local session = sessions[sessionId]
	if not session then return {} end
	local state = {}
	for key, room in pairs(session.Rooms) do
		state[key] = room.Cleared
	end
	return state
end

--------------------------------------------------------------------------------
-- AreAllWardenesDead(sessionId) → boolean
--------------------------------------------------------------------------------
function CreatureSpawner.AreAllWardenesDead(sessionId)
	local session = sessions[sessionId]
	return session and session.WardensAlive <= 0 or false
end

--------------------------------------------------------------------------------
-- CleanupSession(sessionId)
--------------------------------------------------------------------------------
function CreatureSpawner.CleanupSession(sessionId)
	local session = sessions[sessionId]
	if not session then return end

	for _, room in pairs(session.Rooms) do
		-- Disconnect trap triggers
		if room.TriggerConn then
			room.TriggerConn:Disconnect()
			room.TriggerConn = nil
		end

		-- Unregister surviving enemies
		for _, model in ipairs(room.Enemies) do
			if model and model.Parent then
				if CreatureAI then CreatureAI.UnregisterEnemy(model) end
				model:Destroy()
			end
		end
		room.Enemies = {}
	end

	sessions[sessionId] = nil
end

--------------------------------------------------------------------------------
-- INTERNAL: Spawn normal room mobs
--------------------------------------------------------------------------------
function CreatureSpawner._SpawnNormalRoom(session, room)
	local folder = room.Folder
	local spawnPoints = getSpawnPoints(folder)
	local count = math.random(NORMAL_CREATURE_MIN, NORMAL_CREATURE_MAX)

	local positions
	if #spawnPoints >= count then
		-- Use tagged spawn points (pick 'count' from available)
		positions = {}
		-- Shuffle a copy to pick random subset
		local indices = {}
		for i = 1, #spawnPoints do table.insert(indices, i) end
		for i = #indices, 2, -1 do
			local j = math.random(i)
			indices[i], indices[j] = indices[j], indices[i]
		end
		for i = 1, count do
			table.insert(positions, spawnPoints[indices[i]].Position + Vector3.new(0, 3, 0))
		end
	else
		positions = generateFallbackPositions(folder, count)
	end

	for i = 1, count do
		local mobId = randomBasicCreatureId()
		local model = HollowBuilder.SpawnSingleEnemy(mobId, positions[i], folder)
		if model then
			table.insert(room.Enemies, model)
		end
	end
end

--------------------------------------------------------------------------------
-- INTERNAL: Setup trap room with a trigger part
--------------------------------------------------------------------------------
function CreatureSpawner._SetupTrapRoom(session, room, sessionId, roomKey)
	local folder = room.Folder

	-- Look for a part named "TrapTrigger" inside the room
	local trigger = nil
	for _, desc in ipairs(folder:GetDescendants()) do
		if desc:IsA("BasePart") and desc.Name == "TrapTrigger" then
			trigger = desc
			break
		end
	end

	if not trigger then
		-- No trigger found — create an invisible trigger zone at the room entrance
		local floor = folder:FindFirstChild("Floor")
		if floor and floor:IsA("BasePart") then
			trigger = Instance.new("Part")
			trigger.Name = "TrapTrigger"
			trigger.Size = Vector3.new(floor.Size.X * 0.5, floor.Size.Y + 10, 10)
			trigger.Position = floor.Position + Vector3.new(0, 5, floor.Size.Z / 2 - 5)
			trigger.Anchored = true
			trigger.CanCollide = false
			trigger.Transparency = 1
			trigger.Parent = folder
		end
	end

	if not trigger then return end

	local triggered = false
	room.TriggerConn = trigger.Touched:Connect(function(hit)
		if triggered then return end
		local character = hit.Parent
		if not character then return end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end
		local player = game:GetService("Players"):GetPlayerFromCharacter(character)
		if not player then return end

		triggered = true
		-- Spawn mobs immediately at spawn points
		CreatureSpawner._SpawnNormalRoom(session, room)

		-- Disconnect so it only fires once
		if room.TriggerConn then
			room.TriggerConn:Disconnect()
			room.TriggerConn = nil
		end
	end)
end

--------------------------------------------------------------------------------
-- INTERNAL: Spawn warden keeper enemy
--------------------------------------------------------------------------------
function CreatureSpawner._SpawnWardenRoom(session, room)
	local folder = room.Folder
	local templateName = room.TemplateName or ""
	local keeperId = WARDEN_MAP[templateName]

	if not keeperId or not CreatureConfig.Creatures[keeperId] then
		-- Fallback: pick first available keeper
		for _, id in pairs(WARDEN_MAP) do
			if CreatureConfig.Creatures[id] then
				keeperId = id
				break
			end
		end
	end

	if not keeperId then
		warn("[CreatureSpawner] No keeper enemy found for room: " .. templateName)
		return
	end

	local spawnPoints = getSpawnPoints(folder)
	local spawnPos
	if #spawnPoints > 0 then
		spawnPos = spawnPoints[1].Position + Vector3.new(0, 3, 0)
	else
		local positions = generateFallbackPositions(folder, 1)
		spawnPos = positions[1]
	end

	local model = HollowBuilder.SpawnSingleEnemy(keeperId, spawnPos, folder)
	if model then
		if room.DropsKey then
			model:SetAttribute("DropsKey", room.DropsKey)
		end
		table.insert(room.Enemies, model)
	end
end

return CreatureSpawner
