local HollowConfig = {}

-- Grid-based hollow with BRANCHING PATH layout
-- Each cell = 180 studs apart (120 chamber + 60 corridor gap)
HollowConfig.GridSpacing = 180
HollowConfig.CorridorWidth = 16
HollowConfig.CorridorHeight = 16
HollowConfig.StartOffset = Vector3.new(-270, 5, -120)
HollowConfig.TileSize = 250 -- canonical tile size for procedural generation

-- Layout (branching paths, seal keys, E to unlock seals):
--
--            [Entrance]
--               |
--      C0      C1      C2      C3
-- R0 [Ch16]-[Ch1]--[Ch2]--[Ch14]
--               |
-- R1  [Ch3]--[Ch4]--[Ch5]--[Ch15]
--      |🔒Iron          |🔒Gold
-- R2  [Ch6]--[Ch7]  [Ch8]--[Ch9]
--      |🔒Crimson        |🔒Emerald
-- R3 [Ch10]-[Ch11]-[Ch12]
--              |🔒Shadow×2
-- R4         [Ch18]
--              |
-- R5         [SANCTUM]
--
-- Ch16,Ch14,Ch15 = side chambers
-- Warden in Ch3 drops Iron Seal → opens Ch3→Ch6 seal
-- Warden in Ch5 drops Gold Seal → opens Ch5→Ch8 seal
-- Warden in Ch6 drops Crimson Seal → opens Ch6→Ch10 seal
-- Warden in Ch8 drops Emerald Seal → opens Ch8→Ch12 seal
-- Warden in Ch10 drops Shadow Seal #1
-- Warden in Ch12 drops Shadow Seal #2
-- Both Shadow Seals → opens Ch11→Ch18 seal → Ch18 → SANCTUM

HollowConfig.SealTypes = {
	Iron    = { Name = "Iron Seal",    Color = Color3.fromRGB(180, 180, 190), BrickColor = BrickColor.new("Medium stone grey") },
	Gold    = { Name = "Gold Seal",    Color = Color3.fromRGB(255, 215, 0),   BrickColor = BrickColor.new("Bright yellow") },
	Crimson = { Name = "Crimson Seal", Color = Color3.fromRGB(200, 30, 30),   BrickColor = BrickColor.new("Bright red") },
	Emerald = { Name = "Emerald Seal", Color = Color3.fromRGB(30, 200, 60),   BrickColor = BrickColor.new("Dark green") },
	Shadow  = { Name = "Shadow Seal",  Color = Color3.fromRGB(120, 50, 200),  BrickColor = BrickColor.new("Bright violet") },
}

HollowConfig.Chambers = {
	-- ============ ROW 0 ============
	{
		RoomId = 1, Grid = {1, 0}, Name = "Crypt Entrance",
		RoomType = "Hall", Size = Vector3.new(120, 22, 120),
		Enemies = {
			{ Id = "Skeleton", Count = 4 },
			{ Id = "Bat", Count = 3 },
			{ Id = "Zombie", Count = 2 },
		},
		FloorMaterial = Enum.Material.Cobblestone, WallMaterial = Enum.Material.Brick,
		FloorColor = BrickColor.new("Dark stone grey"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(200, 180, 150),
	},
	{
		RoomId = 2, Grid = {2, 0}, Name = "Forgotten Library",
		RoomType = "Hall", Size = Vector3.new(120, 22, 120),
		Enemies = {
			{ Id = "Wraith", Count = 3 },
			{ Id = "Mage", Count = 3 },
			{ Id = "Archer", Count = 2 },
		},
		FloorMaterial = Enum.Material.WoodPlanks, WallMaterial = Enum.Material.Brick,
		FloorColor = BrickColor.new("Brown"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(180, 160, 100),
	},
	{
		RoomId = 14, Grid = {3, 0}, Name = "Riddle Chamber",
		RoomType = "Shrine", PuzzleVariant = "Trivia",
		Size = Vector3.new(120, 22, 120),
		Enemies = {},
		FloorMaterial = Enum.Material.Slate, WallMaterial = Enum.Material.Brick,
		FloorColor = BrickColor.new("Dark stone grey"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(200, 180, 100),
	},
	{
		RoomId = 16, Grid = {0, 0}, Name = "Forgotten Catacombs",
		RoomType = "Hall", Size = Vector3.new(120, 22, 120),
		Enemies = {
			{ Id = "Skeleton", Count = 4 },
			{ Id = "Zombie", Count = 3 },
			{ Id = "Bat", Count = 2 },
		},
		FloorMaterial = Enum.Material.Cobblestone, WallMaterial = Enum.Material.Brick,
		FloorColor = BrickColor.new("Dark stone grey"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(160, 140, 100),
	},

	-- ============ ROW 1 ============
	{
		RoomId = 3, Grid = {0, 1}, Name = "Spider Nest",
		RoomType = "Ambush", Size = Vector3.new(120, 22, 120),
		Enemies = {
			{ Id = "Spider", Count = 3 },
			{ Id = "Bat", Count = 3 },
			{ Id = "Zombie", Count = 2 },
			{ Id = "IronKeeper", Count = 1, DropsKey = "Iron" }, -- WARDEN
		},
		FloorMaterial = Enum.Material.Slate, WallMaterial = Enum.Material.Brick,
		FloorColor = BrickColor.new("Dark stone grey"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(100, 180, 100),
	},
	{
		RoomId = 4, Grid = {1, 1}, Name = "Grand Hall",
		RoomType = "Hall", Size = Vector3.new(120, 22, 120),
		Enemies = {
			{ Id = "SkeletonKnight", Count = 3 },
			{ Id = "Archer", Count = 3 },
			{ Id = "Skeleton", Count = 2 },
		},
		FloorMaterial = Enum.Material.Cobblestone, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Medium stone grey"), WallColor = BrickColor.new("Black"),
		LightColor = Color3.fromRGB(200, 180, 150),
	},
	{
		RoomId = 5, Grid = {2, 1}, Name = "Armory",
		RoomType = "Ambush", Size = Vector3.new(120, 22, 120),
		Enemies = {
			{ Id = "SkeletonKnight", Count = 3 },
			{ Id = "Zombie", Count = 2 },
			{ Id = "Archer", Count = 2 },
			{ Id = "GoldGuardian", Count = 1, DropsKey = "Gold" }, -- WARDEN
		},
		FloorMaterial = Enum.Material.Cobblestone, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Medium stone grey"), WallColor = BrickColor.new("Black"),
		LightColor = Color3.fromRGB(200, 150, 120),
	},
	{
		RoomId = 15, Grid = {3, 1}, Name = "Cursed Chapel",
		RoomType = "Hall", Size = Vector3.new(120, 22, 120),
		Enemies = {
			{ Id = "Wraith", Count = 3 },
			{ Id = "Mage", Count = 3 },
			{ Id = "Skeleton", Count = 2 },
		},
		FloorMaterial = Enum.Material.Cobblestone, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Dark stone grey"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(160, 80, 200),
	},

	-- ============ ROW 2 ============
	{
		RoomId = 6, Grid = {0, 2}, Name = "Blood Altar",
		RoomType = "Ambush", Size = Vector3.new(120, 22, 120),
		Enemies = {
			{ Id = "Zombie", Count = 3 },
			{ Id = "Wraith", Count = 2 },
			{ Id = "Mage", Count = 2 },
			{ Id = "CrimsonSentinel", Count = 1, DropsKey = "Crimson" }, -- WARDEN
		},
		FloorMaterial = Enum.Material.Basalt, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Maroon"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(200, 30, 30),
	},
	{
		RoomId = 7, Grid = {1, 2}, Name = "Bomb Vault",
		RoomType = "Shrine", PuzzleVariant = "BombDefuse",
		Size = Vector3.new(120, 22, 120),
		Enemies = {},
		FloorMaterial = Enum.Material.Cobblestone, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Medium stone grey"), WallColor = BrickColor.new("Black"),
		LightColor = Color3.fromRGB(255, 100, 50),
	},
	{
		RoomId = 8, Grid = {2, 2}, Name = "Mage Tower",
		RoomType = "Ambush", Size = Vector3.new(120, 22, 120),
		Enemies = {
			{ Id = "Mage", Count = 3 },
			{ Id = "Wraith", Count = 2 },
			{ Id = "SkeletonKnight", Count = 2 },
			{ Id = "EmeraldWarden", Count = 1, DropsKey = "Emerald" }, -- WARDEN
		},
		FloorMaterial = Enum.Material.SmoothPlastic, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Dark indigo"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(100, 100, 255),
	},
	{
		RoomId = 9, Grid = {3, 2}, Name = "Frozen Passage",
		RoomType = "Shrine", PuzzleVariant = "IceWalk",
		Size = Vector3.new(120, 22, 120),
		Enemies = {},
		FloorMaterial = Enum.Material.Ice, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Cyan"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(100, 200, 255),
	},

	-- ============ ROW 3 ============
	{
		RoomId = 10, Grid = {0, 3}, Name = "Bone Pit",
		RoomType = "Ambush", Size = Vector3.new(120, 22, 120),
		Enemies = {
			{ Id = "Skeleton", Count = 3 },
			{ Id = "SkeletonKnight", Count = 2 },
			{ Id = "Zombie", Count = 2 },
			{ Id = "ShadowChampion", Count = 1, DropsKey = "Shadow" }, -- WARDEN
		},
		FloorMaterial = Enum.Material.Limestone, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Brick yellow"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(200, 200, 150),
	},
	{
		RoomId = 11, Grid = {1, 3}, Name = "Shadow Crypt",
		RoomType = "Hall", Size = Vector3.new(120, 22, 120),
		Enemies = {
			{ Id = "Wraith", Count = 4 },
			{ Id = "SkeletonKnight", Count = 3 },
			{ Id = "Mage", Count = 2 },
		},
		FloorMaterial = Enum.Material.Basalt, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Black"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(80, 50, 120),
	},
	{
		RoomId = 12, Grid = {2, 3}, Name = "Knight's Barracks",
		RoomType = "Ambush", Size = Vector3.new(120, 22, 120),
		Enemies = {
			{ Id = "SkeletonKnight", Count = 3 },
			{ Id = "Archer", Count = 2 },
			{ Id = "Mage", Count = 2 },
			{ Id = "ShadowChampion", Count = 1, DropsKey = "Shadow" }, -- WARDEN
		},
		FloorMaterial = Enum.Material.Cobblestone, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Medium stone grey"), WallColor = BrickColor.new("Black"),
		LightColor = Color3.fromRGB(200, 150, 150),
	},
	{
		RoomId = 17, Grid = {0, 4}, Name = "Infernal Pit",
		RoomType = "Vault", Size = Vector3.new(120, 22, 120),
		Enemies = {
			{ Id = "SkeletonKnight", Count = 3 },
			{ Id = "Zombie", Count = 3 },
			{ Id = "Wraith", Count = 2 },
		},
		FloorMaterial = Enum.Material.Basalt, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Really black"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(255, 80, 20),
	},

	-- ============ ROW 4 (pre-sanctum) ============
	{
		RoomId = 18, Grid = {1, 4}, Name = "Void Sanctum",
		RoomType = "Hall", Size = Vector3.new(120, 24, 120),
		Enemies = {
			{ Id = "SkeletonKnight", Count = 4 },
			{ Id = "Mage", Count = 3 },
			{ Id = "Wraith", Count = 2 },
		},
		FloorMaterial = Enum.Material.Basalt, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Really black"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(100, 50, 180),
	},

	-- ============ ROW 5 (SANCTUM BOSS) ============
	{
		RoomId = 13, Grid = {1, 5}, Name = "Golem's Throne",
		RoomType = "Sanctum", Size = Vector3.new(120, 28, 120),
		Enemies = {
			{ Id = "BossGolem", Count = 1 },
			{ Id = "SkeletonKnight", Count = 4 },
			{ Id = "Skeleton", Count = 4 },
		},
		FloorMaterial = Enum.Material.Basalt, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Black"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(255, 100, 50),
		IsBossRoom = true,
	},
}

-- CORRIDORS: Dir "Right" = +X, "Down" = -Z
HollowConfig.Corridors = {
	-- Row 0 connections
	{ FromRoom = 16, ToRoom = 1,  Dir = "Right" },
	{ FromRoom = 1,  ToRoom = 2,  Dir = "Right" },
	{ FromRoom = 2,  ToRoom = 14, Dir = "Right" },

	-- Row 0 → Row 1
	{ FromRoom = 1,  ToRoom = 4,  Dir = "Down" },

	-- Row 1 connections
	{ FromRoom = 3,  ToRoom = 4,  Dir = "Right" },
	{ FromRoom = 4,  ToRoom = 5,  Dir = "Right" },
	{ FromRoom = 5,  ToRoom = 15, Dir = "Right" },

	-- Row 1 → Row 2 (SEALED PASSAGES)
	{ FromRoom = 3,  ToRoom = 6,  Dir = "Down", DoorKey = "Iron" },
	{ FromRoom = 5,  ToRoom = 8,  Dir = "Down", DoorKey = "Gold" },

	-- Row 2 connections
	{ FromRoom = 6,  ToRoom = 7,  Dir = "Right" },
	{ FromRoom = 8,  ToRoom = 9,  Dir = "Right" },

	-- Row 2 → Row 3 (SEALED PASSAGES)
	{ FromRoom = 6,  ToRoom = 10, Dir = "Down", DoorKey = "Crimson" },
	{ FromRoom = 8,  ToRoom = 12, Dir = "Down", DoorKey = "Emerald" },

	-- Row 3 connections
	{ FromRoom = 10, ToRoom = 11, Dir = "Right" },
	{ FromRoom = 11, ToRoom = 12, Dir = "Right" },

	-- Row 3 → Row 4
	{ FromRoom = 10, ToRoom = 17, Dir = "Down" },

	-- Row 3 → Row 4 (SEALED - requires both Shadow Seals)
	{ FromRoom = 11, ToRoom = 18, Dir = "Down", DoorKey = "Shadow", RequiresBothShadow = true },

	-- Row 4 → Row 5 (Sanctum)
	{ FromRoom = 18, ToRoom = 13, Dir = "Down" },
}

HollowConfig.EntranceRoom = 1

HollowConfig.LobbySpawn = Vector3.new(0, 5, 0)
HollowConfig.PortalPosition = Vector3.new(0, 5, -30)

-- Descent settings
HollowConfig.MaxDescents = 6
HollowConfig.SoulTokens = 3
HollowConfig.MaxRank = 50
HollowConfig.DefaultGrid = 5

return HollowConfig
