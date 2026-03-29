local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SkillConfig"))

local ViewmodelController = {}

local player = Players.LocalPlayer
local viewmodel = nil
local weaponModels = {}
local currentWeaponId = nil
local initialized = false

-- Direct part references (no FindFirstChild each frame)
local armPart = nil
local handPart = nil
local gripPart = nil

-- Arm gear overlay parts
local armGearParts = {}

-- Viewmodel offset from camera (right side, slightly down and forward)
local BASE_OFFSET = CFrame.new(1.5, -1.4, -2.2)

-- Walk bob
local bobTime = 0
local BOB_SPEED = 8
local BOB_AMOUNT_Y = 0.06
local BOB_AMOUNT_X = 0.03

-- Attack animation state
local swingAngle = 0
local swingTarget = 0
local swingSpeed = 12
local isSwinging = false

-- Idle sway
local idleTime = 0
local IDLE_SPEED = 1.5
local IDLE_AMOUNT = 0.015

----------------------------------------------------------------------
-- Helper: create a Part with common viewmodel properties
----------------------------------------------------------------------
local function makePart(name, size, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

----------------------------------------------------------------------
-- Build the arm + hand
----------------------------------------------------------------------
local function createArmModel(parent)
	local model = Instance.new("Model")
	model.Name = "Viewmodel"

	local skin = Color3.fromRGB(245, 205, 160)
	local bandageColor = Color3.fromRGB(195, 180, 155)
	local bandageDirty = Color3.fromRGB(170, 155, 130)
	local leatherColor = Color3.fromRGB(75, 50, 30)
	local leatherDark = Color3.fromRGB(55, 35, 20)
	local metalColor = Color3.fromRGB(120, 110, 95)
	local stitchColor = Color3.fromRGB(100, 85, 65)

	-- Base arm and hand (same square shape)
	armPart = makePart("Arm", Vector3.new(1, 1, 2.8), skin, Enum.Material.SmoothPlastic, model)
	handPart = makePart("Hand", Vector3.new(1.1, 1.1, 0.9), skin, Enum.Material.SmoothPlastic, model)

	-- ===== ARM GEAR: Bandages, bracer, and wrappings =====
	armGearParts = {}

	-- Forearm bandage wraps (overlapping strips at slight angles)
	armGearParts.BandageWrap1 = makePart("BandageWrap1", Vector3.new(1.08, 1.08, 0.2), bandageColor, Enum.Material.Fabric, model)
	armGearParts.BandageWrap2 = makePart("BandageWrap2", Vector3.new(1.08, 1.08, 0.2), bandageDirty, Enum.Material.Fabric, model)
	armGearParts.BandageWrap3 = makePart("BandageWrap3", Vector3.new(1.08, 1.08, 0.2), bandageColor, Enum.Material.Fabric, model)
	armGearParts.BandageWrap4 = makePart("BandageWrap4", Vector3.new(1.08, 1.08, 0.2), bandageDirty, Enum.Material.Fabric, model)
	armGearParts.BandageWrap5 = makePart("BandageWrap5", Vector3.new(1.08, 1.08, 0.2), bandageColor, Enum.Material.Fabric, model)

	-- Loose bandage tail (hangs off the wrist area)
	armGearParts.BandageTail = makePart("BandageTail", Vector3.new(0.12, 0.08, 0.6), bandageColor, Enum.Material.Fabric, model)

	-- Leather bracer (worn arm guard over the bandages)
	armGearParts.Bracer = makePart("Bracer", Vector3.new(1.12, 1.12, 1.0), leatherColor, Enum.Material.Leather, model)
	-- Bracer edge trim (darker leather lip at each end)
	armGearParts.BracerTrimA = makePart("BracerTrimA", Vector3.new(1.15, 1.15, 0.08), leatherDark, Enum.Material.Leather, model)
	armGearParts.BracerTrimB = makePart("BracerTrimB", Vector3.new(1.15, 1.15, 0.08), leatherDark, Enum.Material.Leather, model)
	-- Bracer buckle strap
	armGearParts.BracerStrap = makePart("BracerStrap", Vector3.new(1.18, 0.08, 0.2), leatherDark, Enum.Material.Leather, model)
	-- Small metal buckle on the strap
	armGearParts.Buckle = makePart("Buckle", Vector3.new(1.2, 0.15, 0.15), metalColor, Enum.Material.Metal, model)

	-- Stitch detail lines on bracer (thin dark strips)
	armGearParts.Stitch1 = makePart("Stitch1", Vector3.new(1.13, 0.04, 0.04), stitchColor, Enum.Material.Fabric, model)
	armGearParts.Stitch2 = makePart("Stitch2", Vector3.new(1.13, 0.04, 0.04), stitchColor, Enum.Material.Fabric, model)

	-- ===== HAND GEAR: Fingerless glove wraps =====
	-- Knuckle guard (thin leather strip across top of hand)
	armGearParts.KnuckleGuard = makePart("KnuckleGuard", Vector3.new(0.06, 1.15, 0.35), leatherColor, Enum.Material.Leather, model)
	-- Hand bandage wraps (two crossing the palm area)
	armGearParts.HandWrap1 = makePart("HandWrap1", Vector3.new(1.15, 1.15, 0.12), bandageColor, Enum.Material.Fabric, model)
	armGearParts.HandWrap2 = makePart("HandWrap2", Vector3.new(1.15, 1.15, 0.12), bandageDirty, Enum.Material.Fabric, model)
	-- Wrist cuff (transition from arm to hand)
	armGearParts.WristCuff = makePart("WristCuff", Vector3.new(1.16, 1.16, 0.15), leatherDark, Enum.Material.Leather, model)
	-- Metal wrist stud (small decorative rivet)
	armGearParts.WristStud = makePart("WristStud", Vector3.new(1.18, 0.12, 0.12), metalColor, Enum.Material.Metal, model)

	gripPart = Instance.new("Part")
	gripPart.Name = "Grip"
	gripPart.Size = Vector3.new(0.1, 0.1, 0.1)
	gripPart.Transparency = 1
	gripPart.Anchored = true
	gripPart.CanCollide = false
	gripPart.CanQuery = false
	gripPart.CanTouch = false
	gripPart.Parent = model

	model.PrimaryPart = armPart
	model.Parent = parent
	return model
end

----------------------------------------------------------------------
-- Weapon builders — each returns { model, parts = {name=Part} }
----------------------------------------------------------------------
local function buildSword(parent)
	local m = Instance.new("Model"); m.Name = "Weapon_Sword"
	local parts = {}
	-- Pommel (rounded end-cap)
	parts.Pommel = makePart("Pommel", Vector3.new(0.35, 0.35, 0.25), Color3.fromRGB(160, 140, 40), Enum.Material.Metal, m)
	-- Leather-wrapped grip
	parts.Handle = makePart("Handle", Vector3.new(0.22, 0.22, 1.0), Color3.fromRGB(70, 40, 20), Enum.Material.Fabric, m)
	-- Leather wrapping strips (3 rings around the handle)
	parts.Wrap1 = makePart("Wrap1", Vector3.new(0.28, 0.28, 0.08), Color3.fromRGB(50, 30, 15), Enum.Material.Fabric, m)
	parts.Wrap2 = makePart("Wrap2", Vector3.new(0.28, 0.28, 0.08), Color3.fromRGB(50, 30, 15), Enum.Material.Fabric, m)
	parts.Wrap3 = makePart("Wrap3", Vector3.new(0.28, 0.28, 0.08), Color3.fromRGB(50, 30, 15), Enum.Material.Fabric, m)
	-- Crossguard (ornate, wider with swept ends)
	parts.Guard = makePart("Guard", Vector3.new(0.25, 1.4, 0.3), Color3.fromRGB(180, 160, 50), Enum.Material.Metal, m)
	parts.GuardTipL = makePart("GuardTipL", Vector3.new(0.2, 0.25, 0.2), Color3.fromRGB(200, 180, 60), Enum.Material.Metal, m)
	parts.GuardTipR = makePart("GuardTipR", Vector3.new(0.2, 0.25, 0.2), Color3.fromRGB(200, 180, 60), Enum.Material.Metal, m)
	-- Guard gem (small inset jewel)
	parts.GuardGem = makePart("GuardGem", Vector3.new(0.12, 0.12, 0.12), Color3.fromRGB(200, 40, 40), Enum.Material.Neon, m)
	-- Blade (main body, tapered feel via two overlapping parts)
	parts.Blade = makePart("Blade", Vector3.new(0.15, 0.35, 2.6), Color3.fromRGB(200, 200, 215), Enum.Material.Metal, m)
	-- Blade edge strips (thin bright edges on each side)
	parts.EdgeL = makePart("EdgeL", Vector3.new(0.08, 0.04, 2.4), Color3.fromRGB(230, 230, 240), Enum.Material.Metal, m)
	parts.EdgeR = makePart("EdgeR", Vector3.new(0.08, 0.04, 2.4), Color3.fromRGB(230, 230, 240), Enum.Material.Metal, m)
	-- Fuller (groove down center of blade)
	parts.Fuller = makePart("Fuller", Vector3.new(0.16, 0.08, 1.8), Color3.fromRGB(150, 150, 165), Enum.Material.Metal, m)
	-- Blade tip (narrower end piece)
	parts.BladeTip = makePart("BladeTip", Vector3.new(0.1, 0.25, 0.6), Color3.fromRGB(210, 210, 225), Enum.Material.Metal, m)
	m.PrimaryPart = parts.Handle
	m.Parent = parent
	return { model = m, parts = parts }
end

local function buildStaff(parent)
	local m = Instance.new("Model"); m.Name = "Weapon_Staff"
	local parts = {}
	-- Shaft base (darker wood at the bottom)
	parts.ShaftBase = makePart("ShaftBase", Vector3.new(0.35, 0.35, 1.2), Color3.fromRGB(60, 35, 20), Enum.Material.Wood, m)
	-- Main shaft
	parts.Shaft = makePart("Shaft", Vector3.new(0.28, 0.28, 3.0), Color3.fromRGB(80, 50, 30), Enum.Material.Wood, m)
	-- Decorative rings along the shaft
	parts.Ring1 = makePart("Ring1", Vector3.new(0.38, 0.38, 0.1), Color3.fromRGB(140, 100, 30), Enum.Material.Metal, m)
	parts.Ring2 = makePart("Ring2", Vector3.new(0.38, 0.38, 0.1), Color3.fromRGB(140, 100, 30), Enum.Material.Metal, m)
	parts.Ring3 = makePart("Ring3", Vector3.new(0.38, 0.38, 0.1), Color3.fromRGB(140, 100, 30), Enum.Material.Metal, m)
	-- Head cradle (twisted metal prongs holding the orb)
	parts.ProngL = makePart("ProngL", Vector3.new(0.08, 0.08, 0.7), Color3.fromRGB(120, 80, 25), Enum.Material.Metal, m)
	parts.ProngR = makePart("ProngR", Vector3.new(0.08, 0.08, 0.7), Color3.fromRGB(120, 80, 25), Enum.Material.Metal, m)
	parts.ProngF = makePart("ProngF", Vector3.new(0.08, 0.08, 0.7), Color3.fromRGB(120, 80, 25), Enum.Material.Metal, m)
	-- Main orb (fire element)
	parts.Orb = makePart("Orb", Vector3.new(0.7, 0.7, 0.7), Color3.fromRGB(255, 120, 30), Enum.Material.Neon, m)
	parts.Orb.Shape = Enum.PartType.Ball
	-- Inner orb core (brighter, smaller)
	parts.OrbCore = makePart("OrbCore", Vector3.new(0.35, 0.35, 0.35), Color3.fromRGB(255, 200, 80), Enum.Material.Neon, m)
	parts.OrbCore.Shape = Enum.PartType.Ball
	-- Particle ember ring around orb
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 30)
	light.Brightness = 0.8; light.Range = 6
	light.Parent = parts.Orb
	parts._light = light
	local fire = Instance.new("Fire")
	fire.Size = 1.5; fire.Heat = 3; fire.Color = Color3.fromRGB(255, 160, 40)
	fire.SecondaryColor = Color3.fromRGB(255, 80, 10)
	fire.Parent = parts.Orb
	parts._fire = fire
	m.PrimaryPart = parts.Shaft
	m.Parent = parent
	return { model = m, parts = parts }
end

local function buildWand(parent)
	local m = Instance.new("Model"); m.Name = "Weapon_Wand"
	local parts = {}
	-- Handle grip (wrapped in cloth)
	parts.Grip = makePart("Grip", Vector3.new(0.18, 0.18, 0.7), Color3.fromRGB(60, 40, 80), Enum.Material.Fabric, m)
	-- Main stick body (bone-white with slight curve implied by taper)
	parts.Stick = makePart("Stick", Vector3.new(0.15, 0.15, 1.6), Color3.fromRGB(230, 230, 240), Enum.Material.SmoothPlastic, m)
	-- Decorative spiral wrap (thin dark vine around shaft)
	parts.Vine1 = makePart("Vine1", Vector3.new(0.2, 0.2, 0.06), Color3.fromRGB(40, 70, 35), Enum.Material.Grass, m)
	parts.Vine2 = makePart("Vine2", Vector3.new(0.2, 0.2, 0.06), Color3.fromRGB(40, 70, 35), Enum.Material.Grass, m)
	parts.Vine3 = makePart("Vine3", Vector3.new(0.2, 0.2, 0.06), Color3.fromRGB(40, 70, 35), Enum.Material.Grass, m)
	-- Crystal cradle (forked tip)
	parts.ForkL = makePart("ForkL", Vector3.new(0.06, 0.06, 0.4), Color3.fromRGB(200, 200, 215), Enum.Material.SmoothPlastic, m)
	parts.ForkR = makePart("ForkR", Vector3.new(0.06, 0.06, 0.4), Color3.fromRGB(200, 200, 215), Enum.Material.SmoothPlastic, m)
	-- Main crystal (emerald green, faceted look via wedge)
	parts.Crystal = makePart("Crystal", Vector3.new(0.3, 0.3, 0.5), Color3.fromRGB(50, 255, 100), Enum.Material.Neon, m)
	-- Crystal cap (smaller crystal shard on top)
	parts.CrystalShard = makePart("CrystalShard", Vector3.new(0.15, 0.15, 0.3), Color3.fromRGB(80, 255, 140), Enum.Material.Neon, m)
	-- Healing aura light
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(50, 255, 100)
	light.Brightness = 0.6; light.Range = 5
	light.Parent = parts.Crystal
	parts._light = light
	-- Sparkle particles
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = Color3.fromRGB(100, 255, 150)
	sparkle.Parent = parts.Crystal
	parts._sparkle = sparkle
	m.PrimaryPart = parts.Stick
	m.Parent = parent
	return { model = m, parts = parts }
end

local function buildShield(parent)
	local m = Instance.new("Model"); m.Name = "Weapon_Shield"
	local parts = {}
	-- Handle (grip bar behind the shield)
	parts.Handle = makePart("Handle", Vector3.new(0.25, 0.25, 0.9), Color3.fromRGB(100, 60, 30), Enum.Material.Wood, m)
	-- Arm strap
	parts.Strap = makePart("Strap", Vector3.new(0.3, 0.6, 0.15), Color3.fromRGB(80, 45, 20), Enum.Material.Fabric, m)
	-- Shield body (main face, kite-shaped via stacked parts)
	parts.Body = makePart("Body", Vector3.new(0.35, 2.4, 2.2), Color3.fromRGB(45, 90, 180), Enum.Material.Metal, m)
	-- Shield border rim (raised metal edge all around)
	parts.RimTop = makePart("RimTop", Vector3.new(0.4, 2.5, 0.12), Color3.fromRGB(160, 150, 130), Enum.Material.Metal, m)
	parts.RimBot = makePart("RimBot", Vector3.new(0.4, 2.5, 0.12), Color3.fromRGB(160, 150, 130), Enum.Material.Metal, m)
	parts.RimL = makePart("RimL", Vector3.new(0.4, 0.12, 2.2), Color3.fromRGB(160, 150, 130), Enum.Material.Metal, m)
	parts.RimR = makePart("RimR", Vector3.new(0.4, 0.12, 2.2), Color3.fromRGB(160, 150, 130), Enum.Material.Metal, m)
	-- Center boss (raised dome in the middle)
	parts.Boss = makePart("Boss", Vector3.new(0.5, 0.7, 0.7), Color3.fromRGB(200, 190, 160), Enum.Material.Metal, m)
	-- Emblem (golden crest)
	parts.Emblem = makePart("Emblem", Vector3.new(0.42, 0.6, 0.6), Color3.fromRGB(255, 215, 0), Enum.Material.Metal, m)
	-- Diagonal reinforcement straps (cross pattern)
	parts.CrossA = makePart("CrossA", Vector3.new(0.38, 0.1, 2.8), Color3.fromRGB(140, 130, 110), Enum.Material.Metal, m)
	parts.CrossB = makePart("CrossB", Vector3.new(0.38, 2.8, 0.1), Color3.fromRGB(140, 130, 110), Enum.Material.Metal, m)
	-- Corner rivets (4 decorative bolts)
	parts.Rivet1 = makePart("Rivet1", Vector3.new(0.42, 0.15, 0.15), Color3.fromRGB(180, 170, 140), Enum.Material.Metal, m)
	parts.Rivet2 = makePart("Rivet2", Vector3.new(0.42, 0.15, 0.15), Color3.fromRGB(180, 170, 140), Enum.Material.Metal, m)
	parts.Rivet3 = makePart("Rivet3", Vector3.new(0.42, 0.15, 0.15), Color3.fromRGB(180, 170, 140), Enum.Material.Metal, m)
	parts.Rivet4 = makePart("Rivet4", Vector3.new(0.42, 0.15, 0.15), Color3.fromRGB(180, 170, 140), Enum.Material.Metal, m)
	-- Battle damage scratch (dark streak across face)
	parts.Scratch = makePart("Scratch", Vector3.new(0.37, 0.04, 1.6), Color3.fromRGB(30, 28, 25), Enum.Material.Metal, m)
	m.PrimaryPart = parts.Handle
	m.Parent = parent
	return { model = m, parts = parts }
end

local WEAPON_BUILDERS = {
	Sword = buildSword,
	Staff = buildStaff,
	Wand = buildWand,
	Shield = buildShield,
}

----------------------------------------------------------------------
-- Position weapon parts relative to grip
----------------------------------------------------------------------
local function positionWeapon(weaponId, gripCF)
	local data = weaponModels[weaponId]
	if not data then return end
	local p = data.parts

	if weaponId == "Sword" then
		-- Pommel at the very end of the handle
		p.Pommel.CFrame = gripCF * CFrame.new(0, 0, 0.4)
		-- Handle (grip area)
		p.Handle.CFrame = gripCF * CFrame.new(0, 0, -0.2)
		-- Leather wraps spaced along the handle
		p.Wrap1.CFrame = gripCF * CFrame.new(0, 0, 0.1)
		p.Wrap2.CFrame = gripCF * CFrame.new(0, 0, -0.2)
		p.Wrap3.CFrame = gripCF * CFrame.new(0, 0, -0.5)
		-- Crossguard at handle-blade junction
		p.Guard.CFrame = gripCF * CFrame.new(0, 0, -0.8)
		p.GuardTipL.CFrame = gripCF * CFrame.new(0, -0.7, -0.8)
		p.GuardTipR.CFrame = gripCF * CFrame.new(0, 0.7, -0.8)
		p.GuardGem.CFrame = gripCF * CFrame.new(0, 0, -0.8)
		-- Main blade
		p.Blade.CFrame = gripCF * CFrame.new(0, 0, -2.2)
		-- Sharp edges on each side of the blade
		p.EdgeL.CFrame = gripCF * CFrame.new(0, -0.18, -2.1)
		p.EdgeR.CFrame = gripCF * CFrame.new(0, 0.18, -2.1)
		-- Fuller groove down center
		p.Fuller.CFrame = gripCF * CFrame.new(0, 0, -1.9)
		-- Tapered tip
		p.BladeTip.CFrame = gripCF * CFrame.new(0, 0, -3.6)

	elseif weaponId == "Staff" then
		-- Thicker base at bottom of shaft
		p.ShaftBase.CFrame = gripCF * CFrame.new(0, 0, 0.4)
		-- Main shaft body
		p.Shaft.CFrame = gripCF * CFrame.new(0, 0, -1.5)
		-- Decorative metal rings spaced along shaft
		p.Ring1.CFrame = gripCF * CFrame.new(0, 0, -0.2)
		p.Ring2.CFrame = gripCF * CFrame.new(0, 0, -1.4)
		p.Ring3.CFrame = gripCF * CFrame.new(0, 0, -2.6)
		-- Metal prongs cradling the orb (angled outward)
		p.ProngL.CFrame = gripCF * CFrame.new(0, -0.2, -3.3) * CFrame.Angles(0, 0, math.rad(15))
		p.ProngR.CFrame = gripCF * CFrame.new(0, 0.2, -3.3) * CFrame.Angles(0, 0, math.rad(-15))
		p.ProngF.CFrame = gripCF * CFrame.new(0, 0, -3.3) * CFrame.Angles(math.rad(15), 0, 0)
		-- Main orb
		p.Orb.CFrame = gripCF * CFrame.new(0, 0, -3.8)
		-- Bright inner core
		p.OrbCore.CFrame = gripCF * CFrame.new(0, 0, -3.8)

	elseif weaponId == "Wand" then
		-- Cloth grip at the base
		p.Grip.CFrame = gripCF * CFrame.new(0, 0, 0.1)
		-- Main wand body
		p.Stick.CFrame = gripCF * CFrame.new(0, 0, -0.8)
		-- Vine wraps spiraling up
		p.Vine1.CFrame = gripCF * CFrame.new(0.05, 0.05, -0.3) * CFrame.Angles(0, 0, math.rad(20))
		p.Vine2.CFrame = gripCF * CFrame.new(-0.05, 0.05, -0.8) * CFrame.Angles(0, 0, math.rad(-20))
		p.Vine3.CFrame = gripCF * CFrame.new(0.05, -0.05, -1.3) * CFrame.Angles(0, 0, math.rad(20))
		-- Forked tips holding the crystal
		p.ForkL.CFrame = gripCF * CFrame.new(0, -0.1, -1.8) * CFrame.Angles(0, 0, math.rad(12))
		p.ForkR.CFrame = gripCF * CFrame.new(0, 0.1, -1.8) * CFrame.Angles(0, 0, math.rad(-12))
		-- Main crystal in the fork
		p.Crystal.CFrame = gripCF * CFrame.new(0, 0, -2.1)
		-- Small crystal shard pointing forward
		p.CrystalShard.CFrame = gripCF * CFrame.new(0, 0, -2.5) * CFrame.Angles(0, 0, math.rad(45))

	elseif weaponId == "Shield" then
		local shieldCF = gripCF * CFrame.new(-0.3, 0, -0.8)
		-- Handle behind the shield
		p.Handle.CFrame = shieldCF
		-- Arm strap above handle
		p.Strap.CFrame = shieldCF * CFrame.new(0.05, 0, 0.25)
		-- Main shield face
		p.Body.CFrame = shieldCF * CFrame.new(-0.3, 0, 0)
		-- Metal rim edges
		local bCF = shieldCF * CFrame.new(-0.3, 0, 0)
		p.RimTop.CFrame = bCF * CFrame.new(0, 0, 1.1)
		p.RimBot.CFrame = bCF * CFrame.new(0, 0, -1.1)
		p.RimL.CFrame = bCF * CFrame.new(0, -1.2, 0)
		p.RimR.CFrame = bCF * CFrame.new(0, 1.2, 0)
		-- Center boss dome
		p.Boss.CFrame = bCF * CFrame.new(-0.1, 0, 0)
		-- Gold emblem on boss
		p.Emblem.CFrame = bCF * CFrame.new(-0.15, 0, 0)
		-- Cross reinforcement
		p.CrossA.CFrame = bCF * CFrame.Angles(0, 0, math.rad(45))
		p.CrossB.CFrame = bCF * CFrame.Angles(0, 0, math.rad(45))
		-- Corner rivets
		p.Rivet1.CFrame = bCF * CFrame.new(0, -0.85, 0.8)
		p.Rivet2.CFrame = bCF * CFrame.new(0, 0.85, 0.8)
		p.Rivet3.CFrame = bCF * CFrame.new(0, -0.85, -0.8)
		p.Rivet4.CFrame = bCF * CFrame.new(0, 0.85, -0.8)
		-- Battle scar
		p.Scratch.CFrame = bCF * CFrame.new(-0.02, 0.3, 0.2) * CFrame.Angles(0, 0, math.rad(-15))
	end
end

----------------------------------------------------------------------
-- Show/hide weapons
----------------------------------------------------------------------
local function setWeaponVisible(weaponId, visible)
	local data = weaponModels[weaponId]
	if not data then return end
	for name, part in pairs(data.parts) do
		if typeof(part) == "Instance" and part:IsA("BasePart") then
			part.Transparency = visible and 0 or 1
		elseif typeof(part) == "Instance" and part:IsA("PointLight") then
			part.Enabled = visible
		end
	end
end

local function switchWeapon(newId)
	if currentWeaponId then
		setWeaponVisible(currentWeaponId, false)
	end
	currentWeaponId = newId
	setWeaponVisible(currentWeaponId, true)
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------
function ViewmodelController.Init(skillController)
	if initialized then return end
	initialized = true

	-- Wait for camera to be available
	local cam = workspace.CurrentCamera
	while not cam do
		task.wait(0.1)
		cam = workspace.CurrentCamera
	end

	print("[ViewmodelController] Initializing viewmodel...")

	-- Build arm model
	viewmodel = createArmModel(cam)

	-- Build all weapon models
	for weaponId, builder in pairs(WEAPON_BUILDERS) do
		weaponModels[weaponId] = builder(cam)
	end

	-- Show initial weapon, hide others
	currentWeaponId = skillController.GetEquippedWeaponId() or "Sword"
	for weaponId, _ in pairs(weaponModels) do
		setWeaponVisible(weaponId, weaponId == currentWeaponId)
	end

	-- Main render loop
	RunService.RenderStepped:Connect(function(dt)
		local ok, err = pcall(ViewmodelController.Update, dt, skillController)
		if not ok then
			warn("[ViewmodelController] " .. tostring(err))
		end
	end)

	-- Hide player's real arms in first person
	local function hideBodyParts(char)
		if not char then return end
		for _, partName in ipairs({"Right Arm", "RightHand", "RightUpperArm", "RightLowerArm", "Left Arm", "LeftHand", "LeftUpperArm", "LeftLowerArm"}) do
			local part = char:FindFirstChild(partName)
			if part and part:IsA("BasePart") then
				part.LocalTransparencyModifier = 1
			end
		end
	end

	RunService.RenderStepped:Connect(function()
		hideBodyParts(player.Character)
	end)

	print("[ViewmodelController] Ready!")
end

function ViewmodelController.Update(dt, skillController)
	if not viewmodel then return end
	if not armPart or not armPart.Parent then return end

	local cam = workspace.CurrentCamera
	if not cam then return end

	-- Re-parent viewmodel if camera changed
	if viewmodel.Parent ~= cam then
		viewmodel.Parent = cam
		for _, data in pairs(weaponModels) do
			data.model.Parent = cam
		end
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChild("Humanoid")

	-- Detect weapon change
	local newWeaponId = skillController.GetEquippedWeaponId() or "Sword"
	if newWeaponId ~= currentWeaponId then
		switchWeapon(newWeaponId)
	end

	-- Walk bob
	if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
		bobTime = bobTime + dt * BOB_SPEED * (humanoid.WalkSpeed / 16)
	else
		bobTime = bobTime + dt * 0.5
	end

	local bobY = math.sin(bobTime) * BOB_AMOUNT_Y
	local bobX = math.cos(bobTime * 0.5) * BOB_AMOUNT_X

	local isMoving = humanoid and humanoid.MoveDirection.Magnitude > 0.1

	-- Idle sway
	local idleY, idleX = 0, 0
	if not isMoving then
		idleTime = idleTime + dt * IDLE_SPEED
		idleY = math.sin(idleTime) * IDLE_AMOUNT
		idleX = math.cos(idleTime * 0.7) * IDLE_AMOUNT * 0.5
	end

	-- Attack swing
	if isSwinging then
		swingAngle = swingAngle + (swingTarget - swingAngle) * math.min(1, dt * swingSpeed)
		if math.abs(swingAngle - swingTarget) < 0.02 then
			if swingTarget ~= 0 then
				swingTarget = 0
				swingSpeed = 8
			else
				isSwinging = false
				swingAngle = 0
			end
		end
	end

	-- Compose final CFrame
	local camCF = cam.CFrame
	local bobOffset = CFrame.new(bobX + idleX, bobY + idleY, 0)
	local swingRotation = CFrame.Angles(math.rad(swingAngle), 0, 0)
	local finalCF = camCF * BASE_OFFSET * bobOffset * swingRotation

	-- Position arm
	armPart.CFrame = finalCF
	handPart.CFrame = finalCF * CFrame.new(0, 0, -1.85)

	-- Grip at front of hand
	local gripCF = finalCF * CFrame.new(0, 0, -2.3)
	gripPart.CFrame = gripCF

	-- Position arm gear overlays
	local handCF = finalCF * CFrame.new(0, 0, -1.85)
	local g = armGearParts

	-- Bandage wraps spaced along the forearm (Z offsets from arm center)
	g.BandageWrap1.CFrame = finalCF * CFrame.new(0, 0, 0.9) * CFrame.Angles(0, 0, math.rad(3))
	g.BandageWrap2.CFrame = finalCF * CFrame.new(0, 0, 0.5) * CFrame.Angles(0, 0, math.rad(-2))
	g.BandageWrap3.CFrame = finalCF * CFrame.new(0, 0, 0.1) * CFrame.Angles(0, 0, math.rad(4))
	g.BandageWrap4.CFrame = finalCF * CFrame.new(0, 0, -0.3) * CFrame.Angles(0, 0, math.rad(-3))
	g.BandageWrap5.CFrame = finalCF * CFrame.new(0, 0, -0.7) * CFrame.Angles(0, 0, math.rad(2))

	-- Loose bandage tail dangling from wrist
	g.BandageTail.CFrame = finalCF * CFrame.new(-0.45, -0.3, -1.1) * CFrame.Angles(math.rad(15), 0, math.rad(20))

	-- Leather bracer on mid-forearm
	g.Bracer.CFrame = finalCF * CFrame.new(0, 0, -0.1)
	-- Bracer trim at each edge
	g.BracerTrimA.CFrame = finalCF * CFrame.new(0, 0, 0.4)
	g.BracerTrimB.CFrame = finalCF * CFrame.new(0, 0, -0.6)
	-- Strap across outer bracer
	g.BracerStrap.CFrame = finalCF * CFrame.new(0, 0.52, -0.1) * CFrame.Angles(0, 0, math.rad(5))
	-- Buckle on strap
	g.Buckle.CFrame = finalCF * CFrame.new(0, 0.56, -0.1)

	-- Stitch lines on bracer
	g.Stitch1.CFrame = finalCF * CFrame.new(0, 0, 0.15)
	g.Stitch2.CFrame = finalCF * CFrame.new(0, 0, -0.35)

	-- Wrist cuff (transition between arm and hand)
	g.WristCuff.CFrame = finalCF * CFrame.new(0, 0, -1.35)

	-- Knuckle guard across top of hand
	g.KnuckleGuard.CFrame = handCF * CFrame.new(0, 0.55, -0.1)
	-- Hand bandage wraps
	g.HandWrap1.CFrame = handCF * CFrame.new(0, 0, 0.15) * CFrame.Angles(0, 0, math.rad(5))
	g.HandWrap2.CFrame = handCF * CFrame.new(0, 0, -0.2) * CFrame.Angles(0, 0, math.rad(-3))
	-- Metal wrist stud
	g.WristStud.CFrame = finalCF * CFrame.new(0, 0.56, -1.35)

	-- Position weapon
	positionWeapon(currentWeaponId, gripCF)
end

function ViewmodelController.PlayAttackAnimation()
	isSwinging = true

	if currentWeaponId == "Sword" then
		swingAngle = 0; swingTarget = -40; swingSpeed = 18
	elseif currentWeaponId == "Staff" then
		swingAngle = 0; swingTarget = -20; swingSpeed = 14
	elseif currentWeaponId == "Wand" then
		swingAngle = 0; swingTarget = -15; swingSpeed = 16
	elseif currentWeaponId == "Shield" then
		swingAngle = 0; swingTarget = -10; swingSpeed = 20
	else
		swingAngle = 0; swingTarget = -25; swingSpeed = 14
	end
end

function ViewmodelController.Destroy()
	if viewmodel then viewmodel:Destroy(); viewmodel = nil end
	for _, data in pairs(weaponModels) do
		data.model:Destroy()
	end
	weaponModels = {}
	initialized = false
end

return ViewmodelController
