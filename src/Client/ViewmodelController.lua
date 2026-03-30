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
local armParts = {}   -- all arm/hand/wrap parts for positioning
local gripPart = nil

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
local function mp(name, size, color, material, parent)
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
-- COLOR PALETTE — dungeon / assassin theme
----------------------------------------------------------------------
local SKIN           = Color3.fromRGB(215, 175, 135)
local LEATHER_DARK   = Color3.fromRGB(45, 30, 18)
local LEATHER_MED    = Color3.fromRGB(70, 48, 28)
local LEATHER_WORN   = Color3.fromRGB(90, 65, 38)
local WRAP_LINEN     = Color3.fromRGB(160, 145, 120)
local WRAP_DIRTY     = Color3.fromRGB(130, 118, 95)
local BUCKLE_IRON    = Color3.fromRGB(95, 90, 82)
local STITCH_DARK    = Color3.fromRGB(55, 40, 25)

----------------------------------------------------------------------
-- Build the arm + hand — Assassin's Creed inspired
----------------------------------------------------------------------
local function createArmModel(parent)
	local model = Instance.new("Model")
	model.Name = "Viewmodel"

	-- === FOREARM ===
	-- Main forearm (skin visible between wraps)
	armParts.Forearm = mp("Forearm", Vector3.new(0.95, 0.95, 2.8), SKIN, Enum.Material.SmoothPlastic, model)

	-- === LEATHER BRACER (upper forearm, AC-style vambrace) ===
	-- Main bracer shell — dark leather wrapping the upper forearm
	armParts.BracerBase = mp("BracerBase", Vector3.new(1.08, 1.08, 1.4), LEATHER_DARK, Enum.Material.Leather, model)
	-- Bracer top plate — slightly raised, worn leather
	armParts.BracerPlate = mp("BracerPlate", Vector3.new(0.9, 0.25, 1.2), LEATHER_MED, Enum.Material.Leather, model)
	-- Bracer stitching lines (thin strips across the bracer)
	armParts.BracerStitch1 = mp("BracerStitch1", Vector3.new(1.1, 0.06, 0.12), STITCH_DARK, Enum.Material.Fabric, model)
	armParts.BracerStitch2 = mp("BracerStitch2", Vector3.new(1.1, 0.06, 0.12), STITCH_DARK, Enum.Material.Fabric, model)
	armParts.BracerStitch3 = mp("BracerStitch3", Vector3.new(1.1, 0.06, 0.12), STITCH_DARK, Enum.Material.Fabric, model)
	-- Iron buckle/clasp on the bracer
	armParts.Buckle1 = mp("Buckle1", Vector3.new(0.35, 0.15, 0.2), BUCKLE_IRON, Enum.Material.Metal, model)
	armParts.Buckle2 = mp("Buckle2", Vector3.new(0.35, 0.15, 0.2), BUCKLE_IRON, Enum.Material.Metal, model)
	-- Thin leather strap loops through buckles
	armParts.Strap1 = mp("Strap1", Vector3.new(1.15, 0.08, 0.15), LEATHER_WORN, Enum.Material.Leather, model)
	armParts.Strap2 = mp("Strap2", Vector3.new(1.15, 0.08, 0.15), LEATHER_WORN, Enum.Material.Leather, model)

	-- === LINEN WRAPS (lower forearm to wrist, layered and crisscrossed) ===
	-- Multiple angled wrap strips for layered look
	armParts.WrapA = mp("WrapA", Vector3.new(1.02, 0.12, 0.7), WRAP_LINEN, Enum.Material.Fabric, model)
	armParts.WrapB = mp("WrapB", Vector3.new(1.02, 0.12, 0.6), WRAP_DIRTY, Enum.Material.Fabric, model)
	armParts.WrapC = mp("WrapC", Vector3.new(1.02, 0.12, 0.5), WRAP_LINEN, Enum.Material.Fabric, model)
	armParts.WrapD = mp("WrapD", Vector3.new(1.02, 0.12, 0.55), WRAP_DIRTY, Enum.Material.Fabric, model)
	-- Diagonal cross-wrap accent
	armParts.CrossWrap = mp("CrossWrap", Vector3.new(0.15, 1.05, 0.6), WRAP_DIRTY, Enum.Material.Fabric, model)

	-- === HAND ===
	armParts.Hand = mp("Hand", Vector3.new(0.95, 0.88, 0.85), SKIN, Enum.Material.SmoothPlastic, model)
	-- Fingerless glove layer on the hand
	armParts.GloveBase = mp("GloveBase", Vector3.new(0.98, 0.82, 0.6), LEATHER_DARK, Enum.Material.Leather, model)
	-- Exposed knuckles (skin showing through fingerless glove)
	armParts.Knuckles = mp("Knuckles", Vector3.new(0.85, 0.22, 0.15), SKIN, Enum.Material.SmoothPlastic, model)
	-- Knuckle wrap (thin linen over knuckles for protection)
	armParts.KnuckleWrap = mp("KnuckleWrap", Vector3.new(0.88, 0.1, 0.18), WRAP_LINEN, Enum.Material.Fabric, model)
	-- Thumb guard (small leather strip)
	armParts.ThumbGuard = mp("ThumbGuard", Vector3.new(0.2, 0.3, 0.4), LEATHER_MED, Enum.Material.Leather, model)

	-- === GRIP POINT (invisible) ===
	gripPart = Instance.new("Part")
	gripPart.Name = "Grip"
	gripPart.Size = Vector3.new(0.1, 0.1, 0.1)
	gripPart.Transparency = 1
	gripPart.Anchored = true
	gripPart.CanCollide = false
	gripPart.CanQuery = false
	gripPart.CanTouch = false
	gripPart.Parent = model

	model.PrimaryPart = armParts.Forearm
	model.Parent = parent
	return model
end

----------------------------------------------------------------------
-- Position arm parts relative to the base CFrame each frame
----------------------------------------------------------------------
local function positionArm(finalCF)
	local p = armParts

	-- Forearm
	p.Forearm.CFrame = finalCF

	-- Bracer (upper forearm area, z ~ +0.4 to +1.1 from center)
	local bracerCF = finalCF * CFrame.new(0, 0, 0.7)
	p.BracerBase.CFrame = bracerCF
	p.BracerPlate.CFrame = bracerCF * CFrame.new(0, 0.55, 0) -- on top
	p.BracerStitch1.CFrame = bracerCF * CFrame.new(0, 0, -0.4)
	p.BracerStitch2.CFrame = bracerCF * CFrame.new(0, 0, 0)
	p.BracerStitch3.CFrame = bracerCF * CFrame.new(0, 0, 0.4)
	p.Buckle1.CFrame = bracerCF * CFrame.new(0, 0.55, -0.3)
	p.Buckle2.CFrame = bracerCF * CFrame.new(0, 0.55, 0.3)
	p.Strap1.CFrame = bracerCF * CFrame.new(0, 0.42, -0.3)
	p.Strap2.CFrame = bracerCF * CFrame.new(0, 0.42, 0.3)

	-- Linen wraps (lower forearm, z ~ -0.2 to -1.0)
	local wristArea = finalCF * CFrame.new(0, 0, -0.5)
	p.WrapA.CFrame = wristArea * CFrame.new(0, 0.35, 0.15)
	p.WrapB.CFrame = wristArea * CFrame.new(0, -0.35, 0.05)
	p.WrapC.CFrame = wristArea * CFrame.new(0, 0.15, -0.2)
	p.WrapD.CFrame = wristArea * CFrame.new(0, -0.15, -0.35)
	p.CrossWrap.CFrame = wristArea * CFrame.Angles(0, 0, math.rad(35)) * CFrame.new(0.1, 0, -0.1)

	-- Hand
	local handCF = finalCF * CFrame.new(0, 0, -1.85)
	p.Hand.CFrame = handCF
	p.GloveBase.CFrame = handCF * CFrame.new(0, -0.02, 0.1)
	p.Knuckles.CFrame = handCF * CFrame.new(0, 0.25, -0.3)
	p.KnuckleWrap.CFrame = handCF * CFrame.new(0, 0.32, -0.3)
	p.ThumbGuard.CFrame = handCF * CFrame.new(0.45, 0, 0.05)
end

----------------------------------------------------------------------
-- WEAPON BUILDERS — detailed dungeon-themed models
----------------------------------------------------------------------

-- ======================== SWORD ========================
-- Worn iron longsword: leather-wrapped grip, iron crossguard, fuller in blade
local function buildSword(parent)
	local m = Instance.new("Model"); m.Name = "Weapon_Sword"
	local parts = {}

	-- Pommel (round iron cap at base)
	parts.Pommel = mp("Pommel", Vector3.new(0.35, 0.35, 0.25), Color3.fromRGB(80, 75, 68), Enum.Material.Metal, m)
	-- Grip (leather-wrapped handle)
	parts.Grip = mp("Grip", Vector3.new(0.22, 0.22, 1.1), LEATHER_DARK, Enum.Material.Leather, m)
	-- Grip wrap spirals (thin leather strips wound around grip)
	parts.GripWrap1 = mp("GripWrap1", Vector3.new(0.26, 0.08, 0.18), LEATHER_WORN, Enum.Material.Leather, m)
	parts.GripWrap2 = mp("GripWrap2", Vector3.new(0.26, 0.08, 0.18), LEATHER_WORN, Enum.Material.Leather, m)
	parts.GripWrap3 = mp("GripWrap3", Vector3.new(0.26, 0.08, 0.18), LEATHER_WORN, Enum.Material.Leather, m)
	parts.GripWrap4 = mp("GripWrap4", Vector3.new(0.26, 0.08, 0.18), LEATHER_WORN, Enum.Material.Leather, m)
	-- Crossguard (iron, slightly curved)
	parts.Guard = mp("Guard", Vector3.new(0.25, 1.4, 0.2), Color3.fromRGB(90, 85, 75), Enum.Material.Metal, m)
	-- Guard ends (flared tips)
	parts.GuardTipL = mp("GuardTipL", Vector3.new(0.2, 0.25, 0.25), Color3.fromRGB(85, 80, 72), Enum.Material.Metal, m)
	parts.GuardTipR = mp("GuardTipR", Vector3.new(0.2, 0.25, 0.25), Color3.fromRGB(85, 80, 72), Enum.Material.Metal, m)
	-- Blade (wide base, tapered)
	parts.Blade = mp("Blade", Vector3.new(0.12, 0.35, 3.0), Color3.fromRGB(180, 180, 190), Enum.Material.Metal, m)
	-- Fuller (groove running down the blade center)
	parts.Fuller = mp("Fuller", Vector3.new(0.14, 0.1, 2.4), Color3.fromRGB(140, 140, 155), Enum.Material.Metal, m)
	-- Blade tip (narrower point)
	parts.BladeTip = mp("BladeTip", Vector3.new(0.1, 0.2, 0.6), Color3.fromRGB(190, 190, 200), Enum.Material.Metal, m)
	-- Blood/rust stain near base (worn detail)
	parts.RustStain = mp("RustStain", Vector3.new(0.13, 0.15, 0.5), Color3.fromRGB(120, 70, 50), Enum.Material.CorrodedMetal, m)

	m.PrimaryPart = parts.Grip
	m.Parent = parent
	return { model = m, parts = parts }
end

-- ======================== STAFF ========================
-- Gnarled darkwood staff: twisted top cradling a fire orb, rune bands
local function buildStaff(parent)
	local m = Instance.new("Model"); m.Name = "Weapon_Staff"
	local parts = {}

	-- Main shaft (slightly tapered, dark wood)
	parts.Shaft = mp("Shaft", Vector3.new(0.3, 0.3, 4.2), Color3.fromRGB(55, 35, 20), Enum.Material.Wood, m)
	-- Bark texture rings (periodic knots in the wood)
	parts.Knot1 = mp("Knot1", Vector3.new(0.38, 0.38, 0.15), Color3.fromRGB(45, 28, 15), Enum.Material.Wood, m)
	parts.Knot2 = mp("Knot2", Vector3.new(0.36, 0.36, 0.15), Color3.fromRGB(48, 30, 18), Enum.Material.Wood, m)
	-- Rune band (iron ring with faint glow near top)
	parts.RuneBand = mp("RuneBand", Vector3.new(0.38, 0.38, 0.12), Color3.fromRGB(80, 75, 68), Enum.Material.Metal, m)
	parts.RuneGlow = mp("RuneGlow", Vector3.new(0.4, 0.4, 0.06), Color3.fromRGB(255, 100, 20), Enum.Material.Neon, m)
	-- Prong cradle (two twisted branches holding the orb)
	parts.ProngL = mp("ProngL", Vector3.new(0.12, 0.12, 0.9), Color3.fromRGB(50, 32, 18), Enum.Material.Wood, m)
	parts.ProngR = mp("ProngR", Vector3.new(0.12, 0.12, 0.9), Color3.fromRGB(50, 32, 18), Enum.Material.Wood, m)
	-- Fire orb (glowing magical core)
	parts.Orb = mp("Orb", Vector3.new(0.65, 0.65, 0.65), Color3.fromRGB(255, 110, 20), Enum.Material.Neon, m)
	parts.Orb.Shape = Enum.PartType.Ball
	local orbLight = Instance.new("PointLight")
	orbLight.Color = Color3.fromRGB(255, 120, 30); orbLight.Brightness = 0.5; orbLight.Range = 5
	orbLight.Parent = parts.Orb
	parts._orbLight = orbLight
	-- Inner ember (smaller bright core inside orb)
	parts.Ember = mp("Ember", Vector3.new(0.3, 0.3, 0.3), Color3.fromRGB(255, 200, 80), Enum.Material.Neon, m)
	parts.Ember.Shape = Enum.PartType.Ball
	-- Leather grip wrap at holding point
	parts.GripWrap = mp("GripWrap", Vector3.new(0.34, 0.34, 0.8), LEATHER_DARK, Enum.Material.Leather, m)
	-- Base cap (iron ferrule)
	parts.Ferrule = mp("Ferrule", Vector3.new(0.28, 0.28, 0.2), Color3.fromRGB(75, 70, 62), Enum.Material.Metal, m)

	m.PrimaryPart = parts.Shaft
	m.Parent = parent
	return { model = m, parts = parts }
end

-- ======================== WAND ========================
-- Carved bone wand: etched handle, caged crystal tip, sinew wraps
local function buildWand(parent)
	local m = Instance.new("Model"); m.Name = "Weapon_Wand"
	local parts = {}

	-- Main shaft (carved bone)
	parts.Shaft = mp("Shaft", Vector3.new(0.18, 0.18, 2.0), Color3.fromRGB(220, 215, 200), Enum.Material.Marble, m)
	-- Bone ridges (carved notches along the shaft)
	parts.Ridge1 = mp("Ridge1", Vector3.new(0.22, 0.22, 0.08), Color3.fromRGB(200, 195, 180), Enum.Material.Marble, m)
	parts.Ridge2 = mp("Ridge2", Vector3.new(0.22, 0.22, 0.08), Color3.fromRGB(200, 195, 180), Enum.Material.Marble, m)
	parts.Ridge3 = mp("Ridge3", Vector3.new(0.22, 0.22, 0.08), Color3.fromRGB(200, 195, 180), Enum.Material.Marble, m)
	-- Sinew wrap at grip (dried gut wrapping for hold)
	parts.SinewWrap = mp("SinewWrap", Vector3.new(0.22, 0.22, 0.6), Color3.fromRGB(145, 120, 85), Enum.Material.Fabric, m)
	-- Cage prongs (bone fingers cradling the crystal)
	parts.CageA = mp("CageA", Vector3.new(0.06, 0.06, 0.5), Color3.fromRGB(210, 205, 190), Enum.Material.Marble, m)
	parts.CageB = mp("CageB", Vector3.new(0.06, 0.06, 0.5), Color3.fromRGB(210, 205, 190), Enum.Material.Marble, m)
	parts.CageC = mp("CageC", Vector3.new(0.06, 0.06, 0.5), Color3.fromRGB(210, 205, 190), Enum.Material.Marble, m)
	-- Crystal (healing energy core)
	parts.Crystal = mp("Crystal", Vector3.new(0.3, 0.3, 0.45), Color3.fromRGB(40, 255, 90), Enum.Material.Neon, m)
	local crystalLight = Instance.new("PointLight")
	crystalLight.Color = Color3.fromRGB(50, 255, 100); crystalLight.Brightness = 0.4; crystalLight.Range = 4
	crystalLight.Parent = parts.Crystal
	parts._crystalLight = crystalLight
	-- Crystal haze (faint glow shell)
	parts.CrystalHaze = mp("CrystalHaze", Vector3.new(0.5, 0.5, 0.5), Color3.fromRGB(40, 255, 90), Enum.Material.Neon, m)
	parts.CrystalHaze.Shape = Enum.PartType.Ball
	parts.CrystalHaze.Transparency = 0.75
	-- Base end cap
	parts.EndCap = mp("EndCap", Vector3.new(0.22, 0.22, 0.1), Color3.fromRGB(180, 175, 160), Enum.Material.Marble, m)

	m.PrimaryPart = parts.Shaft
	m.Parent = parent
	return { model = m, parts = parts }
end

-- ======================== SHIELD ========================
-- Battle-worn iron round shield: riveted rim, center boss, leather face
local function buildShield(parent)
	local m = Instance.new("Model"); m.Name = "Weapon_Shield"
	local parts = {}

	-- Grip bar (behind shield)
	parts.GripBar = mp("GripBar", Vector3.new(0.25, 1.0, 0.25), LEATHER_DARK, Enum.Material.Leather, m)
	-- Shield body (main disc — layered wood and iron)
	parts.Body = mp("Body", Vector3.new(0.3, 2.4, 2.4), Color3.fromRGB(65, 55, 45), Enum.Material.Wood, m)
	-- Iron face plate (front of shield)
	parts.FacePlate = mp("FacePlate", Vector3.new(0.08, 2.2, 2.2), Color3.fromRGB(100, 95, 85), Enum.Material.Metal, m)
	-- Rim (iron band around edge)
	-- Using 4 strips to approximate a circular rim
	parts.RimTop = mp("RimTop", Vector3.new(0.15, 0.2, 2.5), Color3.fromRGB(80, 75, 68), Enum.Material.Metal, m)
	parts.RimBot = mp("RimBot", Vector3.new(0.15, 0.2, 2.5), Color3.fromRGB(80, 75, 68), Enum.Material.Metal, m)
	parts.RimL = mp("RimL", Vector3.new(0.15, 2.5, 0.2), Color3.fromRGB(80, 75, 68), Enum.Material.Metal, m)
	parts.RimR = mp("RimR", Vector3.new(0.15, 2.5, 0.2), Color3.fromRGB(80, 75, 68), Enum.Material.Metal, m)
	-- Center boss (raised dome in center)
	parts.Boss = mp("Boss", Vector3.new(0.35, 0.7, 0.7), Color3.fromRGB(110, 105, 95), Enum.Material.Metal, m)
	-- Boss spike
	parts.Spike = mp("Spike", Vector3.new(0.5, 0.2, 0.2), Color3.fromRGB(120, 115, 105), Enum.Material.Metal, m)
	-- Cross bands (iron straps across shield face in X pattern)
	parts.BandH = mp("BandH", Vector3.new(0.1, 0.15, 2.0), Color3.fromRGB(75, 70, 62), Enum.Material.Metal, m)
	parts.BandV = mp("BandV", Vector3.new(0.1, 2.0, 0.15), Color3.fromRGB(75, 70, 62), Enum.Material.Metal, m)
	-- Rivets (small studs where bands meet rim)
	for i = 1, 4 do
		parts["Rivet"..i] = mp("Rivet"..i, Vector3.new(0.12, 0.12, 0.12), Color3.fromRGB(90, 85, 78), Enum.Material.Metal, m)
		parts["Rivet"..i].Shape = Enum.PartType.Ball
	end
	-- Leather arm strap (behind, for holding)
	parts.ArmStrap = mp("ArmStrap", Vector3.new(0.12, 0.6, 0.2), LEATHER_WORN, Enum.Material.Leather, m)
	-- Battle damage (dent/scratch mark)
	parts.Scratch = mp("Scratch", Vector3.new(0.09, 0.08, 0.8), Color3.fromRGB(60, 55, 48), Enum.Material.CorrodedMetal, m)

	m.PrimaryPart = parts.GripBar
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
		local tilt = gripCF * CFrame.Angles(math.rad(-5), 0, 0)
		-- Pommel at base
		p.Pommel.CFrame = tilt * CFrame.new(0, 0, 0.1)
		-- Grip
		p.Grip.CFrame = tilt * CFrame.new(0, 0, -0.5)
		-- Grip wrap spirals along the handle
		p.GripWrap1.CFrame = tilt * CFrame.new(0, 0, -0.15)
		p.GripWrap2.CFrame = tilt * CFrame.new(0, 0, -0.4)
		p.GripWrap3.CFrame = tilt * CFrame.new(0, 0, -0.65)
		p.GripWrap4.CFrame = tilt * CFrame.new(0, 0, -0.9)
		-- Crossguard
		p.Guard.CFrame = tilt * CFrame.new(0, 0, -1.1)
		p.GuardTipL.CFrame = tilt * CFrame.new(0, -0.7, -1.1)
		p.GuardTipR.CFrame = tilt * CFrame.new(0, 0.7, -1.1)
		-- Blade
		p.Blade.CFrame = tilt * CFrame.new(0, 0, -2.7)
		p.Fuller.CFrame = tilt * CFrame.new(0, 0, -2.5)
		p.BladeTip.CFrame = tilt * CFrame.new(0, 0, -4.4)
		-- Rust stain near guard
		p.RustStain.CFrame = tilt * CFrame.new(0, 0.05, -1.6)

	elseif weaponId == "Staff" then
		local tilt = gripCF * CFrame.Angles(math.rad(-5), 0, 0)
		-- Leather grip at hold point
		p.GripWrap.CFrame = tilt * CFrame.new(0, 0, -0.2)
		-- Main shaft
		p.Shaft.CFrame = tilt * CFrame.new(0, 0, -2.1)
		-- Bark knots
		p.Knot1.CFrame = tilt * CFrame.new(0, 0, -1.2)
		p.Knot2.CFrame = tilt * CFrame.new(0, 0, -2.8)
		-- Rune band
		p.RuneBand.CFrame = tilt * CFrame.new(0, 0, -3.4)
		p.RuneGlow.CFrame = tilt * CFrame.new(0, 0, -3.4)
		-- Prongs (angled outward to cradle orb)
		p.ProngL.CFrame = tilt * CFrame.new(0.2, 0, -4.0) * CFrame.Angles(0, 0, math.rad(12))
		p.ProngR.CFrame = tilt * CFrame.new(-0.2, 0, -4.0) * CFrame.Angles(0, 0, math.rad(-12))
		-- Orb
		p.Orb.CFrame = tilt * CFrame.new(0, 0, -4.5)
		p.Ember.CFrame = tilt * CFrame.new(0, 0, -4.5)
		-- Ferrule at base
		p.Ferrule.CFrame = tilt * CFrame.new(0, 0, 0.5)

	elseif weaponId == "Wand" then
		local tilt = gripCF * CFrame.Angles(math.rad(-5), 0, 0)
		-- Main shaft
		p.Shaft.CFrame = tilt * CFrame.new(0, 0, -1.0)
		-- Bone ridges along shaft
		p.Ridge1.CFrame = tilt * CFrame.new(0, 0, -0.5)
		p.Ridge2.CFrame = tilt * CFrame.new(0, 0, -1.0)
		p.Ridge3.CFrame = tilt * CFrame.new(0, 0, -1.5)
		-- Sinew grip wrap
		p.SinewWrap.CFrame = tilt * CFrame.new(0, 0, -0.2)
		-- Cage prongs (fanned out around crystal)
		p.CageA.CFrame = tilt * CFrame.new(0, 0.12, -2.1) * CFrame.Angles(math.rad(-8), 0, 0)
		p.CageB.CFrame = tilt * CFrame.new(0.1, -0.06, -2.1) * CFrame.Angles(math.rad(4), 0, math.rad(-8))
		p.CageC.CFrame = tilt * CFrame.new(-0.1, -0.06, -2.1) * CFrame.Angles(math.rad(4), 0, math.rad(8))
		-- Crystal
		p.Crystal.CFrame = tilt * CFrame.new(0, 0, -2.35)
		p.CrystalHaze.CFrame = tilt * CFrame.new(0, 0, -2.35)
		-- End cap
		p.EndCap.CFrame = tilt * CFrame.new(0, 0, 0.55)

	elseif weaponId == "Shield" then
		-- Shield held to the left, face outward
		local shieldCF = gripCF * CFrame.new(-0.3, 0, -0.8)
		-- Grip bar (behind, in hand)
		p.GripBar.CFrame = shieldCF
		-- Body & face
		p.Body.CFrame = shieldCF * CFrame.new(-0.25, 0, 0)
		p.FacePlate.CFrame = shieldCF * CFrame.new(-0.42, 0, 0)
		-- Rim
		p.RimTop.CFrame = shieldCF * CFrame.new(-0.42, 1.2, 0)
		p.RimBot.CFrame = shieldCF * CFrame.new(-0.42, -1.2, 0)
		p.RimL.CFrame = shieldCF * CFrame.new(-0.42, 0, -1.2)
		p.RimR.CFrame = shieldCF * CFrame.new(-0.42, 0, 1.2)
		-- Boss and spike (center front)
		p.Boss.CFrame = shieldCF * CFrame.new(-0.5, 0, 0)
		p.Spike.CFrame = shieldCF * CFrame.new(-0.7, 0, 0)
		-- Cross bands
		p.BandH.CFrame = shieldCF * CFrame.new(-0.44, 0, 0)
		p.BandV.CFrame = shieldCF * CFrame.new(-0.44, 0, 0)
		-- Rivets at band-rim intersections
		p.Rivet1.CFrame = shieldCF * CFrame.new(-0.46, 1.0, 0)
		p.Rivet2.CFrame = shieldCF * CFrame.new(-0.46, -1.0, 0)
		p.Rivet3.CFrame = shieldCF * CFrame.new(-0.46, 0, 0.9)
		p.Rivet4.CFrame = shieldCF * CFrame.new(-0.46, 0, -0.9)
		-- Arm strap behind
		p.ArmStrap.CFrame = shieldCF * CFrame.new(0.05, 0.3, 0)
		-- Battle scratch
		p.Scratch.CFrame = shieldCF * CFrame.new(-0.44, 0.4, -0.3) * CFrame.Angles(0, 0, math.rad(25))
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
			-- Preserve special transparency for haze parts
			if name == "CrystalHaze" then
				part.Transparency = visible and 0.75 or 1
			else
				part.Transparency = visible and 0 or 1
			end
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
	if not armParts.Forearm or not armParts.Forearm.Parent then return end

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

	-- Position arm and all wrap/bracer parts
	positionArm(finalCF)

	-- Grip at front of hand
	local gripCF = finalCF * CFrame.new(0, 0, -2.3)
	gripPart.CFrame = gripCF

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
