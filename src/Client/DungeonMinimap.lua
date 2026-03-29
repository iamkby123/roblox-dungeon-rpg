local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local DungeonMinimap = {}

local player = Players.LocalPlayer

--------------------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------------------
local MINIMAP_SIZE = 250 -- px
local MINIMAP_PADDING = 8
local TITLE_HEIGHT = 22
local PLAYER_ICON_SIZE = 16
local DIRECTION_DOT_SIZE = 6
local CONNECTOR_THICKNESS = 4

local ROOM_COLORS = {
	start    = Color3.fromRGB(45, 106, 45),   -- #2d6a2d
	normal   = Color3.fromRGB(74, 74, 74),    -- #4a4a4a
	puzzle   = Color3.fromRGB(212, 160, 23),   -- #d4a017
	trap     = Color3.fromRGB(200, 98, 26),    -- #c8621a
	miniboss = Color3.fromRGB(139, 0, 0),      -- #8b0000
	boss     = Color3.fromRGB(80, 0, 0),       -- #500000
}

local UNDISCOVERED_COLOR = Color3.fromRGB(15, 15, 15)
local CLEARED_BRIGHTEN = 0.25 -- how much to brighten cleared rooms

local TWEEN_REVEAL = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------
local grid = nil        -- reference to the layout grid table
local gridN = 0         -- grid dimension
local tileSize = 200    -- world studs per tile
local startOffsetX = 0  -- world X origin of grid col 0
local startOffsetZ = 0  -- world Z origin of grid row 0

local screenGui = nil
local minimapFrame = nil
local cellFrames = {}   -- [row][col] = Frame
local cellStates = {}   -- [row][col] = "undiscovered" | "discovered" | "cleared"
local connectorFrames = {} -- list of connector frames
local playerIcon = nil
local directionDot = nil
local heartbeatConn = nil

-- Corridor data for connector rendering
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
	return ROOM_COLORS[roomType] or ROOM_COLORS.normal
end

local function getCellSize()
	local usable = MINIMAP_SIZE - MINIMAP_PADDING * 2
	local cellPx = math.floor(usable / gridN)
	return cellPx
end

local function getCellPosition(row, col)
	local cellPx = getCellSize()
	local x = MINIMAP_PADDING + (col - 1) * cellPx
	local y = MINIMAP_PADDING + (row - 1) * cellPx
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

local function createMinimapFrame()
	-- Container anchored top-right
	local container = Instance.new("Frame")
	container.Name = "MinimapContainer"
	container.Size = UDim2.new(0, MINIMAP_SIZE, 0, MINIMAP_SIZE + TITLE_HEIGHT + 4)
	container.Position = UDim2.new(1, -MINIMAP_SIZE - 12, 0, 10)
	container.BackgroundTransparency = 1
	container.Parent = screenGui

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, TITLE_HEIGHT)
	title.BackgroundTransparency = 1
	title.Text = "DUNGEON"
	title.TextColor3 = Color3.fromRGB(200, 180, 140)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = container

	-- Minimap frame
	minimapFrame = Instance.new("Frame")
	minimapFrame.Name = "MinimapFrame"
	minimapFrame.Size = UDim2.new(0, MINIMAP_SIZE, 0, MINIMAP_SIZE)
	minimapFrame.Position = UDim2.new(0, 0, 0, TITLE_HEIGHT + 4)
	minimapFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
	minimapFrame.BackgroundTransparency = 0.15
	minimapFrame.BorderSizePixel = 0
	minimapFrame.ClipsDescendants = true
	minimapFrame.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = minimapFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 55, 50)
	stroke.Thickness = 2
	stroke.Parent = minimapFrame
end

local function createCells()
	local cellPx = getCellSize()
	local gap = math.max(1, math.floor(cellPx * 0.08))
	local innerPx = cellPx - gap

	cellFrames = {}
	cellStates = {}

	for row = 1, gridN do
		cellFrames[row] = {}
		cellStates[row] = {}
		for col = 1, gridN do
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
			cellCorner.CornerRadius = UDim.new(0, 3)
			cellCorner.Parent = frame

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

		-- Both cells must exist
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

		-- Store metadata for discovery updates
		connector:SetAttribute("FromRow", fromRow)
		connector:SetAttribute("FromCol", fromCol)
		connector:SetAttribute("ToRow", toRow)
		connector:SetAttribute("ToCol", toCol)
		connector:SetAttribute("HasKey", corr.DoorKey ~= nil)
		if corr.DoorKey then
			connector:SetAttribute("DoorKey", corr.DoorKey)
		end

		if corr.Dir == "Right" then
			-- Horizontal connector between (fromRow, fromCol) and (fromRow, fromCol+1)
			connector.Size = UDim2.new(0, gap + 2, 0, CONNECTOR_THICKNESS)
			connector.Position = UDim2.new(0, fx + innerPx - 1, 0, fy + math.floor(innerPx / 2) - math.floor(CONNECTOR_THICKNESS / 2))
		elseif corr.Dir == "Down" then
			-- Vertical connector between (fromRow, fromCol) and (fromRow+1, fromCol)
			connector.Size = UDim2.new(0, CONNECTOR_THICKNESS, 0, gap + 2)
			connector.Position = UDim2.new(0, fx + math.floor(innerPx / 2) - math.floor(CONNECTOR_THICKNESS / 2), 0, fy + innerPx - 1)
		end

		local connCorner = Instance.new("UICorner")
		connCorner.CornerRadius = UDim.new(0, 2)
		connCorner.Parent = connector

		-- If locked, add a key icon
		if corr.DoorKey then
			local keyLabel = Instance.new("TextLabel")
			keyLabel.Name = "KeyIcon"
			keyLabel.Size = UDim2.new(1, 4, 1, 4)
			keyLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
			keyLabel.AnchorPoint = Vector2.new(0.5, 0.5)
			keyLabel.BackgroundTransparency = 1
			keyLabel.Text = ""  -- hidden until discovered
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
	-- Avatar headshot icon
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
	iconStroke.Thickness = 2
	iconStroke.Parent = playerIcon

	-- Load headshot async
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

	-- Direction dot
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
			-- Both rooms discovered: show connector
			local fromCell = grid[fr] and grid[fr][fc]
			local color = fromCell and getRoomColor(fromCell.RoomType) or ROOM_COLORS.normal
			conn.BackgroundColor3 = color
			conn.BackgroundTransparency = 0.2

			-- Show key icon if locked
			local keyIcon = conn:FindFirstChild("KeyIcon")
			if keyIcon and conn:GetAttribute("HasKey") then
				keyIcon.Text = "🔑"
			end
		elseif fromVisible or toVisible then
			-- One room discovered: show dim connector
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

	layoutGrid    : grid table — grid[row][col] = { RoomType, Name, RoomId }
	tileSizeParam : world studs between room centers (e.g. 180)
	corridorData  : (optional) corridors array
	                { FromRow, FromCol, ToRow, ToCol, Dir, DoorKey? }
	startOffset   : (optional) { X, Z } world origin of grid col=0, row=0
]]
function DungeonMinimap.Init(layoutGrid, tileSizeParam, corridorData, startOffset)
	-- Clean up any previous instance
	DungeonMinimap.Destroy()

	if not layoutGrid then
		warn("[DungeonMinimap] Init called with nil grid")
		return
	end

	grid = layoutGrid
	tileSize = tileSizeParam or 200
	corridors = corridorData
	if startOffset then
		startOffsetX = startOffset.X or 0
		startOffsetZ = startOffset.Z or 0
	end

	-- Determine grid dimension (find max row)
	gridN = 0
	for row, cols in pairs(grid) do
		if type(row) == "number" and row > gridN then
			gridN = row
		end
	end

	if gridN == 0 then
		warn("[DungeonMinimap] Grid is empty")
		return
	end

	-- Build UI
	createScreenGui()
	createMinimapFrame()
	createCells()
	createConnectors()
	createPlayerIcon()

	-- Pre-reveal the start room (1,1) and its immediate neighbors
	DungeonMinimap.RevealRoom(1, 1)
	-- Reveal adjacent rooms to start
	for _, offset in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
		local nr, nc = 1 + offset[1], 1 + offset[2]
		if nr >= 1 and nr <= gridN and nc >= 1 and nc <= gridN then
			if grid[nr] and grid[nr][nc] then
				DungeonMinimap.RevealRoom(nr, nc)
			end
		end
	end

	-- Start position update loop
	heartbeatConn = RunService.Heartbeat:Connect(function()
		local character = player.Character
		if not character then return end
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then return end
		DungeonMinimap.UpdatePlayerPosition(rootPart.Position)
	end)

	-- Listen for server events
	local discoverRemote = Remotes:GetEvent("RoomDiscovered")
	if discoverRemote then
		discoverRemote.OnClientEvent:Connect(function(row, col)
			DungeonMinimap.RevealRoom(row, col)
		end)
	end

	local clearRemote = Remotes:GetEvent("MinimapRoomCleared")
	if clearRemote then
		clearRemote.OnClientEvent:Connect(function(row, col)
			DungeonMinimap.ClearRoom(row, col)
		end)
	end
end

--[[
	RevealRoom(row, col)
	Transitions a cell from undiscovered to discovered with a tween.
]]
function DungeonMinimap.RevealRoom(row, col)
	if not cellFrames[row] or not cellFrames[row][col] then return end
	if not cellStates[row] or cellStates[row][col] ~= "undiscovered" then return end

	local frame = cellFrames[row][col]
	local cell = grid[row] and grid[row][col]
	if not cell then return end

	local targetColor = getRoomColor(cell.RoomType)
	cellStates[row][col] = "discovered"

	-- Tween from black to room color
	TweenService:Create(frame, TWEEN_REVEAL, {
		BackgroundColor3 = targetColor,
	}):Play()

	-- Show type label for special rooms
	local typeLabel = frame:FindFirstChild("TypeLabel")
	if typeLabel then
		local abbrev = {
			start = "S", boss = "B", miniboss = "M",
			puzzle = "?", trap = "!", normal = "",
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
	Brightens the cell and adds a checkmark.
]]
function DungeonMinimap.ClearRoom(row, col)
	if not cellFrames[row] or not cellFrames[row][col] then return end
	local state = cellStates[row] and cellStates[row][col]
	if state == "cleared" or state == "empty" then return end

	-- If undiscovered, reveal first
	if state == "undiscovered" then
		DungeonMinimap.RevealRoom(row, col)
	end

	local frame = cellFrames[row][col]
	local cell = grid[row] and grid[row][col]
	if not cell then return end

	cellStates[row][col] = "cleared"

	-- Brighten color
	local baseColor = getRoomColor(cell.RoomType)
	local clearedColor = brighten(baseColor, CLEARED_BRIGHTEN)

	TweenService:Create(frame, TWEEN_REVEAL, {
		BackgroundColor3 = clearedColor,
	}):Play()

	-- Show checkmark
	local check = frame:FindFirstChild("Checkmark")
	if check then
		check.Text = utf8.char(0x2714) -- ✔
		check.TextTransparency = 0
	end
end

--[[
	UpdatePlayerPosition(worldPos)
	Maps world position to minimap pixel coordinates and moves the player icon.
]]
function DungeonMinimap.UpdatePlayerPosition(worldPos)
	if not minimapFrame or not playerIcon then return end

	-- Convert world position to grid coordinates
	-- Server formula: worldX = startOffsetX + col0 * tileSize
	--                 worldZ = startOffsetZ - row0 * tileSize
	local col = (worldPos.X - startOffsetX) / tileSize + 1
	local row = (startOffsetZ - worldPos.Z) / tileSize + 1

	-- Convert grid coordinates to minimap pixel position
	local cellPx = getCellSize()
	local gap = math.max(1, math.floor(cellPx * 0.08))
	local innerPx = cellPx - gap

	local px = MINIMAP_PADDING + (col - 1) * cellPx + math.floor(gap / 2) + innerPx / 2
	local py = MINIMAP_PADDING + (row - 1) * cellPx + math.floor(gap / 2) + innerPx / 2

	-- Clamp to minimap bounds
	px = math.clamp(px, 0, MINIMAP_SIZE)
	py = math.clamp(py, 0, MINIMAP_SIZE)

	playerIcon.Position = UDim2.new(0, px, 0, py)

	-- Update direction dot based on camera Y rotation
	local camera = workspace.CurrentCamera
	if camera and directionDot then
		local lookVector = camera.CFrame.LookVector
		-- Project onto XZ plane, get angle
		-- Negate Z because world -Z maps to minimap +Y (down)
		local angle = math.atan2(lookVector.X, -lookVector.Z)
		local dotDist = PLAYER_ICON_SIZE / 2 + DIRECTION_DOT_SIZE / 2 + 2
		local dotOffX = math.sin(angle) * dotDist
		local dotOffY = math.cos(angle) * dotDist

		directionDot.Position = UDim2.new(0, px + dotOffX, 0, py + dotOffY)
	end
end

--[[
	Destroy()
	Tears down all UI and disconnects the heartbeat loop.
]]
function DungeonMinimap.Destroy()
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
	startOffsetX = 0
	startOffsetZ = 0
end

return DungeonMinimap
