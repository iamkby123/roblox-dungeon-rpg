local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

-- Wait for character to load
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
character:WaitForChild("HumanoidRootPart")

-- Force first person camera
player.CameraMode = Enum.CameraMode.LockFirstPerson
player.CameraMaxZoomDistance = 0.5

-- Require modules
local MainHUD = require(game:GetService("ReplicatedStorage"):WaitForChild("MainHUD"))
local SkillController = require(script.Parent:WaitForChild("SkillController"))
local InputController = require(script.Parent:WaitForChild("InputController"))
local DamageNumbers = require(script.Parent:WaitForChild("DamageNumbers"))
local CombatController = require(script.Parent:WaitForChild("CombatController"))
local UIController = require(script.Parent:WaitForChild("UIController"))
local ViewmodelController = require(script.Parent:WaitForChild("ViewmodelController"))
local FootstepController = require(script.Parent:WaitForChild("FootstepController"))

-- Create the HUD
local hud = MainHUD.Create()
hud.Parent = player:WaitForChild("PlayerGui")

-- Initialize all controllers
SkillController.Init()
InputController.Init(SkillController)
DamageNumbers.Init()
CombatController.Init(hud)
UIController.Init(hud, SkillController)
ViewmodelController.Init(SkillController)
FootstepController.Init()

-- Disable default Roblox health bar
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

print("[DungeonRPG] Client initialized!")
