local DungeonConfig = {}

-- Grid-based dungeon with BRANCHING PATH layout (not fully connected)
-- Each cell = 180 studs apart (120 room + 60 corridor gap)
DungeonConfig.GridSpacing = 180
DungeonConfig.CorridorWidth = 16
DungeonConfig.CorridorHeight = 16
DungeonConfig.StartOffset = Vector3.new(-270, 5, -200)

-- Layout (branching path, NOT every adjacent room connected):
--
--            [Entrance]
--               |
--      C0      C1      C2      C3
-- R0          [Rm1]--[Rm2]              <- Rm2 is side room
--               |
-- R1  [Rm3]--[Rm4]--[Rm5]              <- Rm4 is hub, drops Iron+Gold
--      |🔒             |🔒
-- R2  [Rm6]--[Rm7]  [Rm8]--[Rm9]       <- Rm7,Rm9 are side rooms
--      |               |
-- R3 [Rm10]-[Rm11]-[Rm12]              <- branches merge at Rm11
--              |🔒🔒
-- R4         [BOSS]
--
-- LEFT BRANCH:  Rm4 → Rm3 → 🔒Iron → Rm6 → Rm7(side) → Rm10 → Rm11 [Shadow 1]
-- RIGHT BRANCH: Rm4 → Rm5 → 🔒Gold → Rm8 → Rm9(side) → Rm12 → Rm11 [Shadow 2]
-- CONVERGE:     Rm11 → 🔒Shadow×2 → BOSS

DungeonConfig.KeyTypes = {
	Iron    = { Name = "Iron Key",    Color = Color3.fromRGB(180, 180, 190), BrickColor = BrickColor.new("Medium stone grey") },
	Gold    = { Name = "Gold Key",    Color = Color3.fromRGB(255, 215, 0),   BrickColor = BrickColor.new("Bright yellow") },
	Shadow  = { Name = "Shadow Key",  Color = Color3.fromRGB(120, 50, 200),  BrickColor = BrickColor.new("Bright violet") },
}

DungeonConfig.Rooms = {
	{
		RoomId = 1, Grid = {1, 0}, Name = "Crypt Entrance",
		RoomType = "Combat", Size = Vector3.new(120, 22, 120),
		DropsKeys = {},
		Enemies = { { Id = "Skeleton", Count = 3 }, { Id = "Bat", Count = 3 } },
		FloorMaterial = Enum.Material.Cobblestone, WallMaterial = Enum.Material.Brick,
		FloorColor = BrickColor.new("Dark stone grey"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(200, 180, 150),
	},
	{
		RoomId = 2, Grid = {2, 0}, Name = "Forgotten Library",
		RoomType = "Combat", Size = Vector3.new(120, 22, 120),
		DropsKeys = {},
		Enemies = { { Id = "Wraith", Count = 2 }, { Id = "Mage", Count = 1 } },
		FloorMaterial = Enum.Material.WoodPlanks, WallMaterial = Enum.Material.Brick,
		FloorColor = BrickColor.new("Brown"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(180, 160, 100),
	},
	{
		RoomId = 3, Grid = {0, 1}, Name = "Spider Nest",
		RoomType = "Combat", Size = Vector3.new(120, 22, 120),
		DropsKeys = {},
		Enemies = { { Id = "Spider", Count = 5 }, { Id = "Bat", Count = 3 } },
		FloorMaterial = Enum.Material.Slate, WallMaterial = Enum.Material.Brick,
		FloorColor = BrickColor.new("Dark stone grey"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(100, 180, 100),
	},
	{
		RoomId = 4, Grid = {1, 1}, Name = "Grand Hall",
		RoomType = "Combat", Size = Vector3.new(120, 22, 120),
		DropsKeys = { "Iron", "Gold" }, -- hub room drops both keys!
		Enemies = { { Id = "SkeletonKnight", Count = 2 }, { Id = "Archer", Count = 2 }, { Id = "Skeleton", Count = 2 } },
		FloorMaterial = Enum.Material.Cobblestone, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Medium stone grey"), WallColor = BrickColor.new("Black"),
		LightColor = Color3.fromRGB(200, 180, 150),
	},
	{
		RoomId = 5, Grid = {2, 1}, Name = "Armory",
		RoomType = "Combat", Size = Vector3.new(120, 22, 120),
		DropsKeys = {},
		Enemies = { { Id = "SkeletonKnight", Count = 3 }, { Id = "Zombie", Count = 2 } },
		FloorMaterial = Enum.Material.Cobblestone, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Medium stone grey"), WallColor = BrickColor.new("Black"),
		LightColor = Color3.fromRGB(200, 150, 120),
	},
	{
		RoomId = 6, Grid = {0, 2}, Name = "Blood Altar",
		RoomType = "Combat", Size = Vector3.new(120, 22, 120),
		DropsKeys = {},
		Enemies = { { Id = "Zombie", Count = 3 }, { Id = "Wraith", Count = 2 }, { Id = "Mage", Count = 1 } },
		FloorMaterial = Enum.Material.Basalt, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Maroon"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(200, 30, 30),
	},
	{
		RoomId = 7, Grid = {1, 2}, Name = "Haunted Gallery",
		RoomType = "Combat", Size = Vector3.new(120, 22, 120),
		DropsKeys = {},
		Enemies = { { Id = "Wraith", Count = 3 }, { Id = "Archer", Count = 2 } },
		FloorMaterial = Enum.Material.Cobblestone, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Medium stone grey"), WallColor = BrickColor.new("Black"),
		LightColor = Color3.fromRGB(150, 100, 200),
	},
	{
		RoomId = 8, Grid = {2, 2}, Name = "Mage Tower",
		RoomType = "Combat", Size = Vector3.new(120, 22, 120),
		DropsKeys = {},
		Enemies = { { Id = "Mage", Count = 3 }, { Id = "Wraith", Count = 2 } },
		FloorMaterial = Enum.Material.SmoothPlastic, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Dark indigo"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(100, 100, 255),
	},
	{
		RoomId = 9, Grid = {3, 2}, Name = "Crystal Cavern",
		RoomType = "Combat", Size = Vector3.new(120, 22, 120),
		DropsKeys = {},
		Enemies = { { Id = "Spider", Count = 3 }, { Id = "Mage", Count = 2 } },
		FloorMaterial = Enum.Material.Ice, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Cyan"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(100, 200, 255),
	},
	{
		RoomId = 10, Grid = {0, 3}, Name = "Bone Pit",
		RoomType = "Combat", Size = Vector3.new(120, 22, 120),
		DropsKeys = { "Shadow" }, -- left branch Shadow key
		Enemies = { { Id = "Skeleton", Count = 4 }, { Id = "SkeletonKnight", Count = 2 } },
		FloorMaterial = Enum.Material.Limestone, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Brick yellow"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(200, 200, 150),
	},
	{
		RoomId = 11, Grid = {1, 3}, Name = "Shadow Crypt",
		RoomType = "Combat", Size = Vector3.new(120, 22, 120),
		DropsKeys = {},
		Enemies = { { Id = "Wraith", Count = 4 }, { Id = "SkeletonKnight", Count = 2 } },
		FloorMaterial = Enum.Material.Basalt, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Black"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(80, 50, 120),
	},
	{
		RoomId = 12, Grid = {2, 3}, Name = "Knight's Barracks",
		RoomType = "Combat", Size = Vector3.new(120, 22, 120),
		DropsKeys = { "Shadow" }, -- right branch Shadow key
		Enemies = { { Id = "SkeletonKnight", Count = 3 }, { Id = "Archer", Count = 2 }, { Id = "Mage", Count = 1 } },
		FloorMaterial = Enum.Material.Cobblestone, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Medium stone grey"), WallColor = BrickColor.new("Black"),
		LightColor = Color3.fromRGB(200, 150, 150),
	},
	{
		RoomId = 13, Grid = {1, 4}, Name = "Golem's Throne",
		RoomType = "Combat", Size = Vector3.new(120, 28, 120),
		DropsKeys = {},
		Enemies = { { Id = "BossGolem", Count = 1 } },
		FloorMaterial = Enum.Material.Basalt, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Black"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(255, 100, 50),
		IsBossRoom = true,
	},
}

-- ONLY these specific connections exist (branching path, NOT full grid)
-- Dir: "Right" = +X (col increases), "Down" = -Z (row increases)
DungeonConfig.Corridors = {
	-- Top: Rm1 with side room Rm2
	{ FromRoom = 1,  ToRoom = 2,  Dir = "Right" },               -- side branch

	-- Rm1 down to hub Rm4
	{ FromRoom = 1,  ToRoom = 4,  Dir = "Down" },                -- main path

	-- Hub row: Rm3 - Rm4 - Rm5
	{ FromRoom = 3,  ToRoom = 4,  Dir = "Right" },               -- left branch entrance
	{ FromRoom = 4,  ToRoom = 5,  Dir = "Right" },               -- right branch entrance

	-- LEFT BRANCH: Rm3 down to Rm6 (locked with Iron)
	{ FromRoom = 3,  ToRoom = 6,  Dir = "Down", DoorKey = "Iron" },

	-- Left path continues: Rm6-Rm7 side room, Rm6 down to Rm10
	{ FromRoom = 6,  ToRoom = 7,  Dir = "Right" },               -- side branch
	{ FromRoom = 6,  ToRoom = 10, Dir = "Down" },                -- left path continues

	-- RIGHT BRANCH: Rm5 down to Rm8 (locked with Gold)
	{ FromRoom = 5,  ToRoom = 8,  Dir = "Down", DoorKey = "Gold" },

	-- Right path continues: Rm8-Rm9 side room, Rm8 down to Rm12
	{ FromRoom = 8,  ToRoom = 9,  Dir = "Right" },               -- side branch
	{ FromRoom = 8,  ToRoom = 12, Dir = "Down" },                -- right path continues

	-- CONVERGENCE ROW: Rm10 - Rm11 - Rm12
	{ FromRoom = 10, ToRoom = 11, Dir = "Right" },               -- branches merge
	{ FromRoom = 11, ToRoom = 12, Dir = "Right" },               -- branches merge

	-- BOSS: Rm11 down to Boss (needs both Shadow keys)
	{ FromRoom = 11, ToRoom = 13, Dir = "Down", DoorKey = "Shadow", RequiresBothShadow = true },
}

DungeonConfig.EntranceRoom = 1

DungeonConfig.LobbySpawn = Vector3.new(0, 5, 0)
DungeonConfig.PortalPosition = Vector3.new(0, 5, -30)

return DungeonConfig
