local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local StatsWindow = {}

local player = Players.LocalPlayer
local screenGui = nil
local mainFrame = nil
local isOpen = false
local isTweening = false
local connections = {}
local statValueLabels = {}

-- Theme colors
local STONE_BG = Color3.fromRGB(35, 32, 28)
local CHARCOAL = Color3.fromRGB(25, 23, 20)
local AMBER_GLOW = Color3.fromRGB(180, 120, 40)
local BLOOD_RED = Color3.fromRGB(180, 40, 30)
local PARCHMENT = Color3.fromRGB(220, 210, 190)
local AGED_GOLD = Color3.fromRGB(160, 140, 100)
local DIVIDER_AMBER = Color3.fromRGB(140, 95, 30)
local IRON_DARK = Color3.fromRGB(80, 70, 60)
local INNER_STROKE = Color3.fromRGB(20, 18, 15)

-- Positions for tween
local HIDDEN_POS = UDim2.new(0, -300, 0.5, 0)
local SHOWN_POS = UDim2.new(0, 20, 0.5, 0)

-- Stat display definitions: key, label, color
local STAT_DEFS = {
	{ key = "MaxHP",      label = "HP",   color = Color3.fromRGB(200, 60, 50) },
	{ key = "Mana",       label = "MP",   color = Color3.fromRGB(70, 130, 220) },
	{ key = "Strength",   label = "STR",  color = Color3.fromRGB(210, 160, 60) },
	{ key = "Defense",    label = "DEF",  color = Color3.fromRGB(140, 160, 180) },
	{ key = "Speed",      label = "SPD",  color = Color3.fromRGB(100, 200, 130) },
	{ key = "CritChance", label = "CRIT", color = Color3.fromRGB(230, 180, 50) },
	{ key = "CritDamage", label = "CDMG", color = Color3.fromRGB(220, 140, 60) },
	{ key = "Arcana",     label = "ARC",  color = Color3.fromRGB(160, 100, 220) },
}

local function createVignetteCorner(parent, anchorX, anchorY, posX, posY, rotAngle)
	local corner = Instance.new("Frame")
	corner.Name = "Vignette"
	corner.Size = UDim2.new(0, 20, 0, 20)
	corner.AnchorPoint = Vector2.new(anchorX, anchorY)
	corner.Position = UDim2.new(posX, 0, posY, 0)
	corner.BackgroundColor3 = Color3.fromRGB(10, 9, 7)
	corner.BackgroundTransparency = 0.6
	corner.BorderSizePixel = 0
	corner.Rotation = rotAngle
	corner.ZIndex = 5
	corner.Parent = parent
	return corner
end

local function createDividerLine(parent, yOffset)
	local line = Instance.new("Frame")
	line.Name = "Divider"
	line.Size = UDim2.new(1, -24, 0, 1)
	line.Position = UDim2.new(0, 12, 0, yOffset)
	line.BackgroundColor3 = DIVIDER_AMBER
	line.BackgroundTransparency = 0.4
	line.BorderSizePixel = 0
	line.Parent = parent
	return line
end

local function createStatRow(parent, layoutOrder, def)
	local row = Instance.new("Frame")
	row.Name = "Stat_" .. def.key
	row.Size = UDim2.new(1, 0, 0, 30)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.LayoutOrder = layoutOrder
	row.Parent = parent

	-- Label (left side)
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(0, 50, 1, 0)
	label.Position = UDim2.new(0, 12, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = def.label
	label.TextColor3 = def.color
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row

	-- Value (right side)
	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.Size = UDim2.new(0, 80, 1, 0)
	value.Position = UDim2.new(1, -92, 0, 0)
	value.BackgroundTransparency = 1
	value.Text = "--"
	value.TextColor3 = PARCHMENT
	value.Font = Enum.Font.GothamBold
	value.TextSize = 14
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.Parent = row

	-- Thin divider below row
	local rowDivider = Instance.new("Frame")
	rowDivider.Name = "RowDivider"
	rowDivider.Size = UDim2.new(1, -24, 0, 1)
	rowDivider.Position = UDim2.new(0, 12, 1, -1)
	rowDivider.BackgroundColor3 = CHARCOAL
	rowDivider.BackgroundTransparency = 0.3
	rowDivider.BorderSizePixel = 0
	rowDivider.Parent = row

	statValueLabels[def.key] = value
	return row
end

local function buildGui()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "StatsWindowGui"
	screenGui.DisplayOrder = 10
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	-- Main frame
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "StatsFrame"
	mainFrame.Size = UDim2.new(0, 280, 0, 380)
	mainFrame.Position = HIDDEN_POS
	mainFrame.AnchorPoint = Vector2.new(0, 0.5)
	mainFrame.BackgroundColor3 = STONE_BG
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Parent = screenGui

	-- UICorner
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 8)
	uiCorner.Parent = mainFrame

	-- Outer UIStroke (amber glow)
	local outerStroke = Instance.new("UIStroke")
	outerStroke.Color = AMBER_GLOW
	outerStroke.Thickness = 2
	outerStroke.Transparency = 0.3
	outerStroke.Parent = mainFrame

	-- Inner border frame for depth
	local innerBorder = Instance.new("Frame")
	innerBorder.Name = "InnerBorder"
	innerBorder.Size = UDim2.new(1, -8, 1, -8)
	innerBorder.Position = UDim2.new(0, 4, 0, 4)
	innerBorder.BackgroundColor3 = CHARCOAL
	innerBorder.BackgroundTransparency = 0.5
	innerBorder.BorderSizePixel = 0
	innerBorder.Parent = mainFrame

	local innerCorner = Instance.new("UICorner")
	innerCorner.CornerRadius = UDim.new(0, 6)
	innerCorner.Parent = innerBorder

	local innerStroke = Instance.new("UIStroke")
	innerStroke.Color = INNER_STROKE
	innerStroke.Thickness = 1
	innerStroke.Transparency = 0.2
	innerStroke.Parent = innerBorder

	-- Vignette corners
	createVignetteCorner(mainFrame, 0, 0, 0, 0, 0)
	createVignetteCorner(mainFrame, 1, 0, 1, 0, 90)
	createVignetteCorner(mainFrame, 0, 1, 0, 1, -90)
	createVignetteCorner(mainFrame, 1, 1, 1, 1, 180)

	-- Content container (inside inner border)
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(1, -16, 1, -16)
	content.Position = UDim2.new(0, 8, 0, 8)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ZIndex = 2
	content.Parent = mainFrame

	-- Title banner
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 36)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "DELVER STATS"
	title.TextColor3 = BLOOD_RED
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.ZIndex = 2
	title.Parent = content

	-- Decorative divider below title
	local titleDivider = Instance.new("Frame")
	titleDivider.Name = "TitleDivider"
	titleDivider.Size = UDim2.new(1, -24, 0, 2)
	titleDivider.Position = UDim2.new(0, 12, 0, 38)
	titleDivider.BackgroundColor3 = DIVIDER_AMBER
	titleDivider.BackgroundTransparency = 0.2
	titleDivider.BorderSizePixel = 0
	titleDivider.ZIndex = 2
	titleDivider.Parent = content

	-- Close button (rusted iron X)
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 28, 0, 28)
	closeBtn.Position = UDim2.new(1, -32, 0, 4)
	closeBtn.AnchorPoint = Vector2.new(0, 0)
	closeBtn.BackgroundColor3 = Color3.fromRGB(50, 44, 38)
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "X"
	closeBtn.TextColor3 = IRON_DARK
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 16
	closeBtn.ZIndex = 3
	closeBtn.Parent = content

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 4)
	closeBtnCorner.Parent = closeBtn

	local closeBtnStroke = Instance.new("UIStroke")
	closeBtnStroke.Color = IRON_DARK
	closeBtnStroke.Thickness = 1
	closeBtnStroke.Transparency = 0.5
	closeBtnStroke.Parent = closeBtn

	table.insert(connections, closeBtn.Activated:Connect(function()
		StatsWindow.Toggle(false)
	end))

	-- Stats list container
	local statsList = Instance.new("Frame")
	statsList.Name = "StatsList"
	statsList.Size = UDim2.new(1, 0, 1, -50)
	statsList.Position = UDim2.new(0, 0, 0, 48)
	statsList.BackgroundTransparency = 1
	statsList.BorderSizePixel = 0
	statsList.ZIndex = 2
	statsList.Parent = content

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 2)
	listLayout.Parent = statsList

	-- Create stat rows
	for i, def in ipairs(STAT_DEFS) do
		createStatRow(statsList, i, def)
	end

	-- Vocation row (special - text label, not numeric)
	local vocationRow = Instance.new("Frame")
	vocationRow.Name = "Stat_Vocation"
	vocationRow.Size = UDim2.new(1, 0, 0, 30)
	vocationRow.BackgroundTransparency = 1
	vocationRow.BorderSizePixel = 0
	vocationRow.LayoutOrder = #STAT_DEFS + 1
	vocationRow.Parent = statsList

	local vocationLabel = Instance.new("TextLabel")
	vocationLabel.Name = "Label"
	vocationLabel.Size = UDim2.new(0, 80, 1, 0)
	vocationLabel.Position = UDim2.new(0, 12, 0, 0)
	vocationLabel.BackgroundTransparency = 1
	vocationLabel.Text = "VOCATION"
	vocationLabel.TextColor3 = AGED_GOLD
	vocationLabel.Font = Enum.Font.GothamBold
	vocationLabel.TextSize = 12
	vocationLabel.TextXAlignment = Enum.TextXAlignment.Left
	vocationLabel.Parent = vocationRow

	local vocationValue = Instance.new("TextLabel")
	vocationValue.Name = "Value"
	vocationValue.Size = UDim2.new(0, 120, 1, 0)
	vocationValue.Position = UDim2.new(1, -132, 0, 0)
	vocationValue.BackgroundTransparency = 1
	vocationValue.Text = "None"
	vocationValue.TextColor3 = PARCHMENT
	vocationValue.Font = Enum.Font.GothamBold
	vocationValue.TextSize = 14
	vocationValue.TextXAlignment = Enum.TextXAlignment.Right
	vocationValue.Parent = vocationRow

	statValueLabels["Vocation"] = vocationValue
end

local function formatStatValue(key, value)
	if key == "CritChance" then
		return string.format("%.1f%%", (tonumber(value) or 0) * 100)
	elseif key == "CritDamage" then
		return string.format("%.1fx", tonumber(value) or 0)
	else
		local num = tonumber(value)
		if num then
			return tostring(math.floor(num))
		end
		return tostring(value or "--")
	end
end

function StatsWindow.UpdateStats(statsTable)
	if not statsTable then return end

	for _, def in ipairs(STAT_DEFS) do
		local label = statValueLabels[def.key]
		if label then
			local raw = statsTable[def.key]
			label.Text = formatStatValue(def.key, raw)
		end
	end

	-- Update vocation
	local vocLabel = statValueLabels["Vocation"]
	if vocLabel then
		vocLabel.Text = tostring(statsTable.Vocation or "None")
	end
end

function StatsWindow.Toggle(forceState)
	if isTweening then return end

	local shouldOpen = forceState
	if shouldOpen == nil then
		shouldOpen = not isOpen
	end

	if shouldOpen == isOpen then return end

	isTweening = true

	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	if shouldOpen then
		mainFrame.Position = HIDDEN_POS
		mainFrame.Visible = true
		local tween = TweenService:Create(mainFrame, tweenInfo, { Position = SHOWN_POS })
		tween:Play()
		tween.Completed:Once(function()
			isOpen = true
			isTweening = false
		end)
	else
		local tween = TweenService:Create(mainFrame, tweenInfo, { Position = HIDDEN_POS })
		tween:Play()
		tween.Completed:Once(function()
			mainFrame.Visible = false
			isOpen = false
			isTweening = false
		end)
	end
end

function StatsWindow.Init()
	buildGui()

	-- Keybind: C to toggle
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.C then
			StatsWindow.Toggle()
		end
	end))

	-- Listen for StatsUpdated remote
	local statsEvent = Remotes:GetEvent("StatsUpdated")
	if statsEvent then
		table.insert(connections, statsEvent.OnClientEvent:Connect(function(statsTable)
			StatsWindow.UpdateStats(statsTable)
		end))
	end

	-- Fetch initial stats
	local getStats = Remotes:GetFunction("GetStats")
	if getStats then
		task.spawn(function()
			local ok, result = pcall(function()
				return getStats:InvokeServer()
			end)
			if ok and result then
				StatsWindow.UpdateStats(result)
			end
		end)
	end
end

function StatsWindow.Destroy()
	for _, conn in ipairs(connections) do
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end
	connections = {}
	statValueLabels = {}

	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end

	mainFrame = nil
	isOpen = false
	isTweening = false
end

return StatsWindow
