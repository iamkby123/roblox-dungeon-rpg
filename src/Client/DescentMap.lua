local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local DescentMap = {}

local player = Players.LocalPlayer

--------------------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------------------
local MINIMAP_SIZE = 175 -- px (smaller, compact)
local MINIMAP_PADDING = 7
local TITLE_HEIGHT = 20
local PLAYER_ICON_SIZE = 14
local DIRECTION_DOT_SIZE = 5
local CONNECTOR_THICKNESS = 3

-- Leather belt border config
local BELT_THICKNESS = 6
local BELT_CORNER_RADIUS = 14
local STITCH_SIZE = 3
local STITCH_SPACING = 12
local RIVET_SIZE = 8

-- Colors
local BELT_COLOR = Color3.fromRGB(65, 42, 22)
local BELT_DARK = Color3.fromRGB(45, 28, 14)
local BELT_HIGHLIGHT = Color3.fromRGB(90, 60, 32)
local STITCH_COLOR = Color3.fromRGB(140, 120, 80)
local RIVET_COLOR = Color3.fromRGB(165, 145, 90)
local RIVET_HIGHLIGHT = Color3.fromRGB(200, 180, 120)
local BUCKLE_COLOR = Color3.fromRGB(150, 135, 85)
local BUCKLE_DARK = Color3.fromRGB(110, 95, 60)
local MAP_BG = Color3.fromRGB(8, 8, 12)
local TITLE_COLOR = Color3.fromRGB(190, 165, 110)

local ROOM_COLORS = {
	start    = Color3.fromRGB(45, 106, 45),
	hall     = Color3.fromRGB(74, 74, 74),
	shrine   = Color3.fromRGB(212, 160, 23),
	vault    = Color3.fromRGB(200, 98, 26),
	warden   = Color3.fromRGB(139, 0, 0),
	sanctum  = Color3.fromRGB(80, 0, 0),
}

local UNDISCOVERED_COLOR = Color3.fromRGB(15, 15, 15)
local CLEARED_BRIGHTEN = 0.25

local TWEEN_REVEAL = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------
local grid = nil
local gridN = 0
local gridRows = 0
local gridCols = 0
local tileSize = 200
local startOffsetX = 0
local startOffsetZ = 0

local screenGui = nil
local minimapFrame = nil
local cellFrames = {}
local cellStates = {}
local connectorFrames = {}
local playerIcon = nil
local directionDot = nil
local heartbeatConn = nil

local corridors = nil

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------
local function brighten(color, amount)
	return Color3.new(
		math.clamp(color.R + amount, 0, 1),
		math.clamp(color.G + amount, 0, 1),
		math.clamp(color.B + amount, 0, 1)
	)
end

local function getRoomColor(roomType)
	return ROOM_COLORS[roomType] or ROOM_COLORS.hall
end

local function getCellSize()
	local usable = MINIMAP_SIZE - MINIMAP_PADDING * 2
	local maxDim = math.max(gridRows, gridCols)
	local cellPx = math.floor(usable / maxDim)
	return cellPx
end

local function getGridOffsets()
	local cellPx = getCellSize()
	local usable = MINIMAP_SIZE - MINIMAP_PADDING * 2
	local offsetX = math.floor((usable - gridCols * cellPx) / 2)
	local offsetY = math.floor((usable - gridRows * cellPx) / 2)
	return offsetX, offsetY
end

local function getCellPosition(row, col)
	local cellPx = getCellSize()
	local offsetX, offsetY = getGridOffsets()
	local flippedRow = gridRows - row + 1
	local x = MINIMAP_PADDING + offsetX + (col - 1) * cellPx
	local y = MINIMAP_PADDING + offsetY + (flippedRow - 1) * cellPx
	return x, y, cellPx
end

--------------------------------------------------------------------------------
-- UI CREATION
--------------------------------------------------------------------------------
local function createScreenGui()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DungeonHUD"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 5
	screenGui.Parent = player:WaitForChild("PlayerGui")
end

local function createLeatherBorder(parent)
	-- Total size includes belt border around the map area
	local totalW = MINIMAP_SIZE + BELT_THICKNESS * 2
	local totalH = MINIMAP_SIZE + BELT_THICKNESS * 2

	-- Outer leather belt frame
	local beltFrame = Instance.new("Frame")
	beltFrame.Name = "LeatherBelt"
	beltFrame.Size = UDim2.new(0, totalW, 0, totalH)
	beltFrame.Position = UDim2.new(0, -BELT_THICKNESS, 0, -BELT_THICKNESS)
	beltFrame.BackgroundColor3 = BELT_COLOR
	beltFrame.BorderSizePixel = 0
	beltFrame.ZIndex = 0
	beltFrame.Parent = parent

	local beltCorner = Instance.new("UICorner")
	beltCorner.CornerRadius = UDim.new(0, BELT_CORNER_RADIUS + 3)
	beltCorner.Parent = beltFrame

	-- Outer edge stroke (dark leather edge)
	local outerStroke = Instance.new("UIStroke")
	outerStroke.Color = BELT_DARK
	outerStroke.Thickness = 2
	outerStroke.Parent = beltFrame

	-- Inner highlight edge (worn leather shine)
	local innerHighlight = Instance.new("Frame")
	innerHighlight.Name = "InnerHighlight"
	innerHighlight.Size = UDim2.new(1, -4, 1, -4)
	innerHighlight.Position = UDim2.new(0, 2, 0, 2)
	innerHighlight.BackgroundTransparency = 1
	innerHighlight.BorderSizePixel = 0
	innerHighlight.ZIndex = 1
	innerHighlight.Parent = beltFrame

	local highlightCorner = Instance.new("UICorner")
	highlightCorner.CornerRadius = UDim.new(0, BELT_CORNER_RADIUS + 1)
	highlightCorner.Parent = innerHighlight

	local highlightStroke = Instance.new("UIStroke")
	highlightStroke.Color = BELT_HIGHLIGHT
	highlightStroke.Thickness = 1
	highlightStroke.Transparency = 0.5
	highlightStroke.Parent = innerHighlight

	-- Stitching dots along each edge
	local function addStitchRow(xStart, yStart, horizontal, length)
		local count = math.floor(length / STITCH_SPACING)
		for i = 0, count do
			local stitch = Instance.new("Frame")
			stitch.Name = "Stitch"
			stitch.Size = UDim2.new(0, STITCH_SIZE, 0, STITCH_SIZE)
			stitch.BackgroundColor3 = STITCH_COLOR
			stitch.BorderSizePixel = 0
			stitch.ZIndex = 2
			stitch.Parent = beltFrame

			local stitchCorner = Instance.new("UICorner")
			stitchCorner.CornerRadius = UDim.new(1, 0)
			stitchCorner.Parent = stitch

			if horizontal then
				stitch.Position = UDim2.new(0, xStart + i * STITCH_SPACING, 0, yStart)
			else
				stitch.Position = UDim2.new(0, xStart, 0, yStart + i * STITCH_SPACING)
			end
		end
	end

	-- Top and bottom stitch rows (inset from edges)
	local stitchInset = BELT_CORNER_RADIUS + 2
	local stitchLen = totalW - stitchInset * 2
	addStitchRow(stitchInset, 3, true, stitchLen)                   -- top outer
	addStitchRow(stitchInset, BELT_THICKNESS - 2, true, stitchLen)  -- top inner
	addStitchRow(stitchInset, totalH - 4, true, stitchLen)          -- bottom outer
	addStitchRow(stitchInset, totalH - BELT_THICKNESS + 1, true, stitchLen) -- bottom inner

	-- Left and right stitch columns
	local stitchLenV = totalH - stitchInset * 2
	addStitchRow(3, stitchInset, false, stitchLenV)                  -- left outer
	addStitchRow(BELT_THICKNESS - 2, stitchInset, false, stitchLenV) -- left inner
	addStitchRow(totalW - 4, stitchInset, false, stitchLenV)         -- right outer
	addStitchRow(totalW - BELT_THICKNESS + 1, stitchInset, false, stitchLenV) -- right inner

	-- Corner rivets (4 decorative metal studs)
	local rivetPositions = {
		{BELT_THICKNESS / 2, BELT_THICKNESS / 2},                         -- top-left
		{totalW - BELT_THICKNESS / 2, BELT_THICKNESS / 2},                -- top-right
		{BELT_THICKNESS / 2, totalH - BELT_THICKNESS / 2},                -- bottom-left
		{totalW - BELT_THICKNESS / 2, totalH - BELT_THICKNESS / 2},       -- bottom-right
	}

	for _, pos in ipairs(rivetPositions) do
		-- Rivet base (darker)
		local rivet = Instance.new("Frame")
		rivet.Name = "Rivet"
		rivet.Size = UDim2.new(0, RIVET_SIZE, 0, RIVET_SIZE)
		rivet.AnchorPoint = Vector2.new(0.5, 0.5)
		rivet.Position = UDim2.new(0, pos[1], 0, pos[2])
		rivet.BackgroundColor3 = RIVET_COLOR
		rivet.BorderSizePixel = 0
		rivet.ZIndex = 3
		rivet.Parent = beltFrame

		local rivetCorner = Instance.new("UICorner")
		rivetCorner.CornerRadius = UDim.new(1, 0)
		rivetCorner.Parent = rivet

		local rivetStroke = Instance.new("UIStroke")
		rivetStroke.Color = BELT_DARK
		rivetStroke.Thickness = 1
		rivetStroke.Parent = rivet

		-- Rivet highlight (inner shine)
		local rivetShine = Instance.new("Frame")
		rivetShine.Name = "Shine"
		rivetShine.Size = UDim2.new(0, RIVET_SIZE - 4, 0, RIVET_SIZE - 4)
		rivetShine.AnchorPoint = Vector2.new(0.5, 0.5)
		rivetShine.Position = UDim2.new(0.5, -1, 0.5, -1)
		rivetShine.BackgroundColor3 = RIVET_HIGHLIGHT
		rivetShine.BackgroundTransparency = 0.4
		rivetShine.BorderSizePixel = 0
		rivetShine.ZIndex = 4
		rivetShine.Parent = rivet

		local shineCorner = Instance.new("UICorner")
		shineCorner.CornerRadius = UDim.new(1, 0)
		shineCorner.Parent = rivetShine
	end

	-- Decorative buckle at top-center
	local buckleW, buckleH = 22, 10
	local buckle = Instance.new("Frame")
	buckle.Name = "Buckle"
	buckle.Size = UDim2.new(0, buckleW, 0, buckleH)
	buckle.AnchorPoint = Vector2.new(0.5, 0.5)
	buckle.Position = UDim2.new(0.5, 0, 0, 0)
	buckle.BackgroundColor3 = BUCKLE_COLOR
	buckle.BorderSizePixel = 0
	buckle.ZIndex = 4
	buckle.Parent = beltFrame

	local buckleCorner = Instance.new("UICorner")
	buckleCorner.CornerRadius = UDim.new(0, 3)
	buckleCorner.Parent = buckle

	local buckleStroke = Instance.new("UIStroke")
	buckleStroke.Color = BUCKLE_DARK
	buckleStroke.Thickness = 1
	buckleStroke.Parent = buckle

	-- Buckle prong (center bar)
	local prong = Instance.new("Frame")
	prong.Name = "Prong"
	prong.Size = UDim2.new(0, 2, 0, buckleH - 4)
	prong.AnchorPoint = Vector2.new(0.5, 0.5)
	prong.Position = UDim2.new(0.5, 0, 0.5, 0)
	prong.BackgroundColor3 = BUCKLE_DARK
	prong.BorderSizePixel = 0
	prong.ZIndex = 5
	prong.Parent = buckle

	return beltFrame
end

local function createMinimapFrame()
	-- Container anchored top-right (extra space for belt border)
	local totalW = MINIMAP_SIZE + BELT_THICKNESS * 2
	local totalH = MINIMAP_SIZE + BELT_THICKNESS * 2
	local container = Instance.new("Frame")
	container.Name = "MinimapContainer"
	container.Size = UDim2.new(0, totalW, 0, totalH + TITLE_HEIGHT + 6)
	container.Position = UDim2.new(1, -totalW - 10, 0, 8)
	container.BackgroundTransparency = 1
	container.Parent = screenGui

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, TITLE_HEIGHT)
	title.BackgroundTransparency = 1
	title.Text = "THE HOLLOW"
	title.TextColor3 = TITLE_COLOR
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = container

	-- Title drop shadow
	local titleShadow = Instance.new("TextLabel")
	titleShadow.Name = "TitleShadow"
	titleShadow.Size = UDim2.new(1, 0, 0, TITLE_HEIGHT)
	titleShadow.Position = UDim2.new(0, 1, 0, 1)
	titleShadow.BackgroundTransparency = 1
	titleShadow.Text = "THE HOLLOW"
	titleShadow.TextColor3 = Color3.fromRGB(20, 15, 8)
	titleShadow.TextTransparency = 0.4
	titleShadow.TextScaled = true
	titleShadow.Font = Enum.Font.GothamBold
	titleShadow.ZIndex = 0
	titleShadow.Parent = container

	-- Minimap frame (inner map area)
	minimapFrame = Instance.new("Frame")
	minimapFrame.Name = "MinimapFrame"
	minimapFrame.Size = UDim2.new(0, MINIMAP_SIZE, 0, MINIMAP_SIZE)
	minimapFrame.Position = UDim2.new(0, BELT_THICKNESS, 0, TITLE_HEIGHT + 6 + BELT_THICKNESS)
	minimapFrame.BackgroundColor3 = MAP_BG
	minimapFrame.BackgroundTransparency = 0.1
	minimapFrame.BorderSizePixel = 0
	minimapFrame.ClipsDescendants = true
	minimapFrame.ZIndex = 1
	minimapFrame.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, BELT_CORNER_RADIUS)
	corner.Parent = minimapFrame

	-- Inner shadow vignette (dark border inside the map)
	local vignette = Instance.new("Frame")
	vignette.Name = "Vignette"
	vignette.Size = UDim2.new(1, 0, 1, 0)
	vignette.BackgroundTransparency = 1
	vignette.BorderSizePixel = 0
	vignette.ZIndex = 20
	vignette.Parent = minimapFrame

	local vignetteCorner = Instance.new("UICorner")
	vignetteCorner.CornerRadius = UDim.new(0, BELT_CORNER_RADIUS)
	vignetteCorner.Parent = vignette

	local vignetteStroke = Instance.new("UIStroke")
	vignetteStroke.Color = Color3.fromRGB(0, 0, 0)
	vignetteStroke.Thickness = 3
	vignetteStroke.Transparency = 0.3
	vignetteStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	vignetteStroke.Parent = vignette

	-- Leather belt border around the map frame
	createLeatherBorder(minimapFrame)
end

local function createCells()
	local cellPx = getCellSize()
	local gap = math.max(1, math.floor(cellPx * 0.08))
	local innerPx = cellPx - gap

	cellFrames = {}
	cellStates = {}

	for row = 1, gridRows do
		cellFrames[row] = {}
		cellStates[row] = {}
		for col = 1, gridCols do
			local cell = grid[row] and grid[row][col]
			if not cell then
				cellStates[row][col] = "empty"
				continue
			end

			local x, y = getCellPosition(row, col)

			local frame = Instance.new("Frame")
			frame.Name = string.format("Cell_%d_%d", row, col)
			frame.Size = UDim2.new(0, innerPx, 0, innerPx)
			frame.Position = UDim2.new(0, x + math.floor(gap / 2), 0, y + math.floor(gap / 2))
			frame.BackgroundColor3 = UNDISCOVERED_COLOR
			frame.BorderSizePixel = 0
			frame.ZIndex = 2
			frame.Parent = minimapFrame

			local cellCorner = Instance.new("UICorner")
			cellCorner.CornerRadius = UDim.new(0, 4)
			cellCorner.Parent = frame

			-- Subtle inner glow stroke (hidden until discovered)
			local cellGlow = Instance.new("UIStroke")
			cellGlow.Name = "CellGlow"
			cellGlow.Color = Color3.fromRGB(255, 255, 255)
			cellGlow.Thickness = 1
			cellGlow.Transparency = 1
			cellGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			cellGlow.Parent = frame

			-- Checkmark label (hidden until cleared)
			local check = Instance.new("TextLabel")
			check.Name = "Checkmark"
			check.Size = UDim2.new(1, 0, 1, 0)
			check.BackgroundTransparency = 1
			check.Text = ""
			check.TextColor3 = Color3.new(1, 1, 1)
			check.TextScaled = true
			check.Font = Enum.Font.GothamBold
			check.ZIndex = 3
			check.Parent = frame

			-- Room type label (hidden until discovered, small text)
			local typeLabel = Instance.new("TextLabel")
			typeLabel.Name = "TypeLabel"
			typeLabel.Size = UDim2.new(1, 0, 0.4, 0)
			typeLabel.Position = UDim2.new(0, 0, 0.6, 0)
			typeLabel.BackgroundTransparency = 1
			typeLabel.Text = ""
			typeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
			typeLabel.TextTransparency = 1
			typeLabel.TextScaled = true
			typeLabel.Font = Enum.Font.Gotham
			typeLabel.ZIndex = 3
			typeLabel.Parent = frame

			cellFrames[row][col] = frame
			cellStates[row][col] = "undiscovered"
		end
	end
end

local function createConnectors()
	if not corridors then return end

	local cellPx = getCellSize()
	local gap = math.max(1, math.floor(cellPx * 0.08))
	local innerPx = cellPx - gap

	connectorFrames = {}

	for _, corr in ipairs(corridors) do
		local fromRow, fromCol = corr.FromRow, corr.FromCol
		local toRow, toCol = corr.ToRow, corr.ToCol

		if not (grid[fromRow] and grid[fromRow][fromCol]) then continue end
		if not (grid[toRow] and grid[toRow][toCol]) then continue end

		local fx, fy = getCellPosition(fromRow, fromCol)
		local tx, ty = getCellPosition(toRow, toCol)

		fx = fx + math.floor(gap / 2)
		fy = fy + math.floor(gap / 2)
		tx = tx + math.floor(gap / 2)
		ty = ty + math.floor(gap / 2)

		local connector = Instance.new("Frame")
		connector.Name = string.format("Conn_%d%d_%d%d", fromRow, fromCol, toRow, toCol)
		connector.BorderSizePixel = 0
		connector.ZIndex = 1
		connector.BackgroundColor3 = UNDISCOVERED_COLOR
		connector.BackgroundTransparency = 0.3

		connector:SetAttribute("FromRow", fromRow)
		connector:SetAttribute("FromCol", fromCol)
		connector:SetAttribute("ToRow", toRow)
		connector:SetAttribute("ToCol", toCol)
		connector:SetAttribute("HasKey", corr.DoorKey ~= nil)
		if corr.DoorKey then
			connector:SetAttribute("DoorKey", corr.DoorKey)
		end

		if corr.Dir == "Right" then
			connector.Size = UDim2.new(0, gap + 2, 0, CONNECTOR_THICKNESS)
			connector.Position = UDim2.new(0, fx + innerPx - 1, 0, fy + math.floor(innerPx / 2) - math.floor(CONNECTOR_THICKNESS / 2))
		elseif corr.Dir == "Down" then
			connector.Size = UDim2.new(0, CONNECTOR_THICKNESS, 0, gap + 2)
			connector.Position = UDim2.new(0, fx + math.floor(innerPx / 2) - math.floor(CONNECTOR_THICKNESS / 2), 0, fy + innerPx - 1)
		end

		local connCorner = Instance.new("UICorner")
		connCorner.CornerRadius = UDim.new(0, 2)
		connCorner.Parent = connector

		if corr.DoorKey then
			local keyLabel = Instance.new("TextLabel")
			keyLabel.Name = "KeyIcon"
			keyLabel.Size = UDim2.new(1, 4, 1, 4)
			keyLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
			keyLabel.AnchorPoint = Vector2.new(0.5, 0.5)
			keyLabel.BackgroundTransparency = 1
			keyLabel.Text = ""
			keyLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
			keyLabel.TextScaled = true
			keyLabel.Font = Enum.Font.GothamBold
			keyLabel.ZIndex = 4
			keyLabel.Parent = connector
		end

		connector.Parent = minimapFrame
		table.insert(connectorFrames, connector)
	end
end

local function createPlayerIcon()
	playerIcon = Instance.new("ImageLabel")
	playerIcon.Name = "PlayerIcon"
	playerIcon.Size = UDim2.new(0, PLAYER_ICON_SIZE, 0, PLAYER_ICON_SIZE)
	playerIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	playerIcon.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
	playerIcon.BackgroundTransparency = 0
	playerIcon.BorderSizePixel = 0
	playerIcon.ZIndex = 10
	playerIcon.Parent = minimapFrame

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(1, 0)
	iconCorner.Parent = playerIcon

	local iconStroke = Instance.new("UIStroke")
	iconStroke.Color = Color3.new(1, 1, 1)
	iconStroke.Thickness = 1.5
	iconStroke.Parent = playerIcon

	task.spawn(function()
		local success, content = pcall(function()
			return Players:GetUserThumbnailAsync(
				player.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size48x48
			)
		end)
		if success and content and playerIcon and playerIcon.Parent then
			playerIcon.Image = content
			playerIcon.BackgroundTransparency = 1
		end
	end)

	directionDot = Instance.new("Frame")
	directionDot.Name = "DirectionDot"
	directionDot.Size = UDim2.new(0, DIRECTION_DOT_SIZE, 0, DIRECTION_DOT_SIZE)
	directionDot.AnchorPoint = Vector2.new(0.5, 0.5)
	directionDot.BackgroundColor3 = Color3.new(1, 1, 1)
	directionDot.BorderSizePixel = 0
	directionDot.ZIndex = 11
	directionDot.Parent = minimapFrame

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = directionDot
end

--------------------------------------------------------------------------------
-- CONNECTOR VISIBILITY
--------------------------------------------------------------------------------
local function updateConnectorVisibility()
	for _, conn in ipairs(connectorFrames) do
		local fr = conn:GetAttribute("FromRow")
		local fc = conn:GetAttribute("FromCol")
		local tr = conn:GetAttribute("ToRow")
		local tc = conn:GetAttribute("ToCol")

		local fromState = cellStates[fr] and cellStates[fr][fc]
		local toState = cellStates[tr] and cellStates[tr][tc]

		local fromVisible = fromState == "discovered" or fromState == "cleared"
		local toVisible = toState == "discovered" or toState == "cleared"

		if fromVisible and toVisible then
			local fromCell = grid[fr] and grid[fr][fc]
			local color = fromCell and getRoomColor(fromCell.RoomType) or ROOM_COLORS.hall
			conn.BackgroundColor3 = color
			conn.BackgroundTransparency = 0.2

			local keyIcon = conn:FindFirstChild("KeyIcon")
			if keyIcon and conn:GetAttribute("HasKey") then
				keyIcon.Text = "🔑"
			end
		elseif fromVisible or toVisible then
			conn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
			conn.BackgroundTransparency = 0.5
		end
	end
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--[[
	Init(layoutGrid, tileSizeParam, corridorData, startOffset)
]]
function DescentMap.Init(layoutGrid, tileSizeParam, corridorData, startOffset)
	DescentMap.Destroy()

	if not layoutGrid then
		warn("[DescentMap] Init called with nil grid")
		return
	end

	grid = layoutGrid
	tileSize = tileSizeParam or 200
	corridors = corridorData
	if startOffset then
		startOffsetX = startOffset.X or 0
		startOffsetZ = startOffset.Z or 0
	end

	gridRows = 0
	gridCols = 0
	for row, cols in pairs(grid) do
		if type(row) == "number" then
			if row > gridRows then gridRows = row end
			if type(cols) == "table" then
				for col, _ in pairs(cols) do
					if type(col) == "number" and col > gridCols then
						gridCols = col
					end
				end
			end
		end
	end
	gridN = math.max(gridRows, gridCols)

	if gridRows == 0 then
		warn("[DescentMap] Grid is empty")
		return
	end

	createScreenGui()
	createMinimapFrame()
	createCells()
	createConnectors()
	createPlayerIcon()

	DescentMap.RevealRoom(1, 1)
	for _, offset in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
		local nr, nc = 1 + offset[1], 1 + offset[2]
		if nr >= 1 and nr <= gridRows and nc >= 1 and nc <= gridCols then
			if grid[nr] and grid[nr][nc] then
				DescentMap.RevealRoom(nr, nc)
			end
		end
	end

	heartbeatConn = RunService.Heartbeat:Connect(function()
		local character = player.Character
		if not character then return end
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then return end
		DescentMap.UpdatePlayerPosition(rootPart.Position)
	end)

	local discoverRemote = Remotes:GetEvent("RoomDiscovered")
	if discoverRemote then
		discoverRemote.OnClientEvent:Connect(function(row, col)
			DescentMap.RevealRoom(row, col)
		end)
	end

	local clearRemote = Remotes:GetEvent("MinimapRoomCleared")
	if clearRemote then
		clearRemote.OnClientEvent:Connect(function(row, col)
			DescentMap.ClearRoom(row, col)
		end)
	end
end

--[[
	RevealRoom(row, col)
]]
function DescentMap.RevealRoom(row, col)
	if not cellFrames[row] or not cellFrames[row][col] then return end
	if not cellStates[row] or cellStates[row][col] ~= "undiscovered" then return end

	local frame = cellFrames[row][col]
	local cell = grid[row] and grid[row][col]
	if not cell then return end

	local targetColor = getRoomColor(cell.RoomType)
	cellStates[row][col] = "discovered"

	TweenService:Create(frame, TWEEN_REVEAL, {
		BackgroundColor3 = targetColor,
	}):Play()

	-- Subtle glow on discovered rooms
	local cellGlow = frame:FindFirstChild("CellGlow")
	if cellGlow then
		TweenService:Create(cellGlow, TWEEN_REVEAL, {
			Transparency = 0.6,
			Color = brighten(targetColor, 0.3),
		}):Play()
	end

	local typeLabel = frame:FindFirstChild("TypeLabel")
	if typeLabel then
		local abbrev = {
			start = "S", sanctum = "B", warden = "M",
			shrine = "?", vault = "!", hall = "",
		}
		local label = abbrev[cell.RoomType] or ""
		if label ~= "" then
			typeLabel.Text = label
			TweenService:Create(typeLabel, TWEEN_REVEAL, {
				TextTransparency = 0.3,
			}):Play()
		end
	end

	updateConnectorVisibility()
end

--[[
	ClearRoom(row, col)
]]
function DescentMap.ClearRoom(row, col)
	if not cellFrames[row] or not cellFrames[row][col] then return end
	local state = cellStates[row] and cellStates[row][col]
	if state == "cleared" or state == "empty" then return end

	if state == "undiscovered" then
		DescentMap.RevealRoom(row, col)
	end

	local frame = cellFrames[row][col]
	local cell = grid[row] and grid[row][col]
	if not cell then return end

	cellStates[row][col] = "cleared"

	local baseColor = getRoomColor(cell.RoomType)
	local clearedColor = brighten(baseColor, CLEARED_BRIGHTEN)

	TweenService:Create(frame, TWEEN_REVEAL, {
		BackgroundColor3 = clearedColor,
	}):Play()

	local check = frame:FindFirstChild("Checkmark")
	if check then
		check.Text = utf8.char(0x2714)
		check.TextTransparency = 0
	end
end

--[[
	UpdatePlayerPosition(worldPos)
]]
function DescentMap.UpdatePlayerPosition(worldPos)
	if not minimapFrame or not playerIcon then return end

	local col = (worldPos.X - startOffsetX) / tileSize + 1
	local row = (startOffsetZ - worldPos.Z) / tileSize + 1

	local cellPx = getCellSize()
	local gap = math.max(1, math.floor(cellPx * 0.08))
	local innerPx = cellPx - gap
	local offsetX, offsetY = getGridOffsets()

	local flippedRow = gridRows - row + 1

	local px = MINIMAP_PADDING + offsetX + (col - 1) * cellPx + math.floor(gap / 2) + innerPx / 2
	local py = MINIMAP_PADDING + offsetY + (flippedRow - 1) * cellPx + math.floor(gap / 2) + innerPx / 2

	px = math.clamp(px, 0, MINIMAP_SIZE)
	py = math.clamp(py, 0, MINIMAP_SIZE)

	playerIcon.Position = UDim2.new(0, px, 0, py)

	local camera = workspace.CurrentCamera
	if camera and directionDot then
		local lookVector = camera.CFrame.LookVector
		local angle = math.atan2(lookVector.X, -lookVector.Z)
		local dotDist = PLAYER_ICON_SIZE / 2 + DIRECTION_DOT_SIZE / 2 + 2
		local dotOffX = math.sin(angle) * dotDist
		local dotOffY = math.cos(angle) * dotDist

		directionDot.Position = UDim2.new(0, px + dotOffX, 0, py + dotOffY)
	end
end

--[[
	Destroy()
]]
function DescentMap.Destroy()
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end

	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end

	minimapFrame = nil
	cellFrames = {}
	cellStates = {}
	connectorFrames = {}
	playerIcon = nil
	directionDot = nil
	grid = nil
	corridors = nil
	gridN = 0
	gridRows = 0
	gridCols = 0
	startOffsetX = 0
	startOffsetZ = 0
end

return DescentMap
