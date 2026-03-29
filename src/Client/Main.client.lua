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
local HollowHUD = require(ReplicatedStorage:WaitForChild("HollowHUD"))
local SkillController = require(script.Parent:WaitForChild("SkillController"))
local InputController = require(script.Parent:WaitForChild("InputController"))
local DamageNumbers = require(script.Parent:WaitForChild("DamageNumbers"))
local CombatController = require(script.Parent:WaitForChild("CombatController"))
local UIController = require(script.Parent:WaitForChild("UIController"))
local ViewmodelController = require(script.Parent:WaitForChild("ViewmodelController"))
local FootstepController = require(script.Parent:WaitForChild("FootstepController"))
local DescentMap = require(script.Parent:WaitForChild("DescentMap"))
local StatsWindow = require(script.Parent:WaitForChild("StatsWindow"))

-- Create the HUD
local hud = HollowHUD.Create()
hud.Parent = player:WaitForChild("PlayerGui")

-- Initialize all controllers
SkillController.Init()
InputController.Init(SkillController)
DamageNumbers.Init()
CombatController.Init(hud)
UIController.Init(hud, SkillController)
ViewmodelController.Init(SkillController)
FootstepController.Init()
StatsWindow.Init()

-- Disable default Roblox health bar
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

-- Client-side gamma lift so geometry stays readable in dark areas
local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "HollowGamma"
cc.Brightness = 0.05
cc.Contrast = 0.08
cc.Saturation = -0.05   -- slightly muted to match torch-lit stone look
cc.Parent = Lighting

-- Listen for descent minimap initialization from server
local minimapInitRemote = Remotes:GetEvent("MinimapInit")
if minimapInitRemote then
	minimapInitRemote.OnClientEvent:Connect(function(data)
		if data and data.Grid then
			DescentMap.Init(data.Grid, data.TileSize, data.Corridors, data.StartOffset)
		end
	end)
end

-- Clean up minimap when descent ends
local descentStateRemote = Remotes:GetEvent("DescentStateChanged")
if descentStateRemote then
	descentStateRemote.OnClientEvent:Connect(function(eventType)
		if eventType == "DescentComplete" then
			DescentMap.Destroy()
		end
	end)
end

-- Listen for puzzle completion
local puzzleSolvedRemote = Remotes:GetEvent("PuzzleSolved")
if puzzleSolvedRemote then
	puzzleSolvedRemote.OnClientEvent:Connect(function(solverName)
		-- Show puzzle solved banner
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

-- Listen for secret discoveries
local secretFoundRemote = Remotes:GetEvent("SecretFound")
if secretFoundRemote then
	secretFoundRemote.OnClientEvent:Connect(function(secretName, points, description)
		local sg = Instance.new("ScreenGui")
		sg.Name = "SecretBanner"
		sg.ResetOnSpawn = false
		sg.Parent = player:WaitForChild("PlayerGui")

		local banner = Instance.new("Frame")
		banner.Size = UDim2.new(0, 320, 0, 70)
		banner.Position = UDim2.new(0.5, -160, 0.2, 0)
		banner.BackgroundColor3 = Color3.fromRGB(30, 25, 18)
		banner.BackgroundTransparency = 0.15
		banner.BorderSizePixel = 0
		banner.Parent = sg

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = banner

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(200, 170, 50)
		stroke.Thickness = 2
		stroke.Transparency = 0.3
		stroke.Parent = banner

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0, 28)
		title.Position = UDim2.new(0, 0, 0, 6)
		title.BackgroundTransparency = 1
		title.Text = "SECRET FOUND: " .. tostring(secretName)
		title.TextColor3 = Color3.fromRGB(255, 215, 0)
		title.TextScaled = true
		title.Font = Enum.Font.GothamBold
		title.Parent = banner

		local desc = Instance.new("TextLabel")
		desc.Size = UDim2.new(1, 0, 0, 18)
		desc.Position = UDim2.new(0, 0, 0, 34)
		desc.BackgroundTransparency = 1
		desc.Text = tostring(description or "")
		desc.TextColor3 = Color3.fromRGB(200, 190, 160)
		desc.TextScaled = true
		desc.Font = Enum.Font.Gotham
		desc.Parent = banner

		local pts = Instance.new("TextLabel")
		pts.Size = UDim2.new(1, 0, 0, 16)
		pts.Position = UDim2.new(0, 0, 0, 52)
		pts.BackgroundTransparency = 1
		pts.Text = "+" .. tostring(points) .. " Descent Score"
		pts.TextColor3 = Color3.fromRGB(100, 255, 100)
		pts.TextScaled = true
		pts.Font = Enum.Font.GothamBold
		pts.Parent = banner

		task.delay(4, function()
			if sg and sg.Parent then sg:Destroy() end
		end)
	end)
end

print("[The Hollow] Client initialized!")
