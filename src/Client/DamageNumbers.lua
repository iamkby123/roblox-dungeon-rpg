local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local DamageNumbers = {}

local pool = {} -- reusable BillboardGuis
local POOL_SIZE = 20

function DamageNumbers.Init()
	-- Pre-create pool
	for i = 1, POOL_SIZE do
		local billboard = DamageNumbers.CreateBillboard()
		billboard.Enabled = false
		billboard.Parent = workspace
		table.insert(pool, billboard)
	end

	-- Listen for enemy damage events
	local remote = Remotes:GetEvent("EnemyDamaged")
	if remote then
		remote.OnClientEvent:Connect(function(position, damage, isCrit)
			DamageNumbers.Show(position, damage, isCrit)
		end)
	end
end

function DamageNumbers.CreateBillboard()
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DamageNumber"
	billboard.Size = UDim2.new(3, 0, 1.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 100

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 2
	stroke.Parent = label

	return billboard
end

function DamageNumbers.GetFromPool()
	for i, billboard in ipairs(pool) do
		if not billboard.Enabled then
			return billboard
		end
	end
	-- Pool full, create a new one
	local billboard = DamageNumbers.CreateBillboard()
	billboard.Parent = workspace
	table.insert(pool, billboard)
	return billboard
end

function DamageNumbers.Show(position, damage, isCrit)
	local billboard = DamageNumbers.GetFromPool()

	-- Create a temporary anchor part
	local anchor = Instance.new("Part")
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position = position + Vector3.new(math.random(-2, 2), 1, math.random(-2, 2))
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Parent = workspace

	billboard.Adornee = anchor
	billboard.StudsOffset = Vector3.new(0, 0, 0)

	local label = billboard:FindFirstChild("Text")
	if label then
		if isCrit then
			label.Text = "CRIT! " .. tostring(damage)
			label.TextColor3 = Color3.fromRGB(255, 255, 50)
			billboard.Size = UDim2.new(4, 0, 2, 0)
		else
			label.Text = tostring(damage)
			label.TextColor3 = Color3.new(1, 1, 1)
			billboard.Size = UDim2.new(3, 0, 1.5, 0)
		end
		label.TextTransparency = 0
	end

	billboard.Enabled = true

	-- Animate: float up and fade out
	local startY = anchor.Position.Y
	local duration = 0.8

	local moveTween = TweenService:Create(anchor, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = anchor.Position + Vector3.new(0, 3, 0),
	})

	local fadeTween = TweenService:Create(label, TweenInfo.new(duration * 0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, duration * 0.5), {
		TextTransparency = 1,
	})

	moveTween:Play()
	fadeTween:Play()

	fadeTween.Completed:Connect(function()
		billboard.Enabled = false
		billboard.Adornee = nil
		anchor:Destroy()
	end)
end

return DamageNumbers
