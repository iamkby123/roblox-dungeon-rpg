local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")

-- Wait for character to load
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
character:WaitForChild("HumanoidRootPart")

-- Force first person camera
player.CameraMode = Enum.CameraMode.LockFirstPerson
player.CameraMaxZoomDistance = 0.5

-- Require modules
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local MainHUD = require(ReplicatedStorage:WaitForChild("MainHUD"))
local SkillController = require(script.Parent:WaitForChild("SkillController"))
local InputController = require(script.Parent:WaitForChild("InputController"))
local DamageNumbers = require(script.Parent:WaitForChild("DamageNumbers"))
local CombatController = require(script.Parent:WaitForChild("CombatController"))
local UIController = require(script.Parent:WaitForChild("UIController"))
local ViewmodelController = require(script.Parent:WaitForChild("ViewmodelController"))
local FootstepController = require(script.Parent:WaitForChild("FootstepController"))
local DungeonMinimap = require(script.Parent:WaitForChild("DungeonMinimap"))

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

-- Boost gamma so dungeon rooms are more visible (not fullbright)
local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "DungeonGamma"
cc.Brightness = 0.08
cc.Contrast = 0.1
cc.Saturation = 0.05
cc.Parent = Lighting

-- Listen for dungeon minimap initialization from server
local minimapInitRemote = Remotes:GetEvent("MinimapInit")
if minimapInitRemote then
	minimapInitRemote.OnClientEvent:Connect(function(data)
		if data and data.Grid then
			DungeonMinimap.Init(data.Grid, data.TileSize, data.Corridors, data.StartOffset)
		end
	end)
end

-- Clean up minimap when dungeon ends
local dungeonStateRemote = Remotes:GetEvent("DungeonStateChanged")
if dungeonStateRemote then
	dungeonStateRemote.OnClientEvent:Connect(function(eventType)
		if eventType == "DungeonComplete" then
			DungeonMinimap.Destroy()
		end
	end)
end

-- Listen for puzzle completion
local puzzleCompleteRemote = Remotes:GetEvent("PuzzleComplete")
if puzzleCompleteRemote then
	puzzleCompleteRemote.OnClientEvent:Connect(function(solverName)
		-- Show puzzle complete banner
		local screenGui = Instance.new("ScreenGui")
		screenGui.Name = "PuzzleBanner"
		screenGui.ResetOnSpawn = false
		screenGui.Parent = player:WaitForChild("PlayerGui")

		local banner = Instance.new("TextLabel")
		banner.Size = UDim2.new(0.5, 0, 0.08, 0)
		banner.Position = UDim2.new(0.25, 0, 0.15, 0)
		banner.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
		banner.BackgroundTransparency = 0.3
		banner.BorderSizePixel = 0
		banner.Text = "PUZZLE SOLVED by " .. tostring(solverName) .. "!"
		banner.TextColor3 = Color3.fromRGB(80, 255, 120)
		banner.TextScaled = true
		banner.Font = Enum.Font.GothamBold
		banner.Parent = screenGui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = banner

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(80, 255, 120)
		stroke.Thickness = 2
		stroke.Parent = banner

		task.delay(3, function()
			if screenGui and screenGui.Parent then screenGui:Destroy() end
		end)
	end)
end

print("[DungeonRPG] Client initialized!")
