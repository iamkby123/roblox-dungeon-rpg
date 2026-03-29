local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local RunGrading = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("RunGrading"))

local PuzzleEncounters = {}

local HollowBuilder -- injected via Init

function PuzzleEncounters.Init(dungeonSvc)
	HollowBuilder = dungeonSvc
end

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------
local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = props.Size or Vector3.new(1, 1, 1)
	part.Position = props.Position or Vector3.new(0, 0, 0)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.BrickColor = props.BrickColor or BrickColor.new("Medium stone grey")
	part.CanCollide = props.CanCollide ~= false
	part.Transparency = props.Transparency or 0
	part.Name = props.Name or "Part"
	if props.Color then part.Color = props.Color end
	if props.CFrame then part.CFrame = props.CFrame end
	part.Parent = props.Parent
	return part
end

local function dealRawDamage(player, amount)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	humanoid:TakeDamage(amount)
	local remote = Remotes:GetEvent("TakeDamage")
	if remote then
		remote:FireClient(player, amount)
	end
end

local function playChimeSound(parent)
	local sound = Instance.new("Sound")
	sound.Name = "PuzzleChime"
	sound.SoundId = "rbxassetid://6042053626"
	sound.Volume = 1.5
	sound.PlayOnRemove = false
	sound.Parent = parent
	sound:Play()
	task.delay(3, function()
		if sound and sound.Parent then sound:Destroy() end
	end)
end

local function openExitDoor(doorPart)
	if not doorPart or not doorPart.Parent then return end
	doorPart.CanCollide = false
	local tween = TweenService:Create(doorPart, TweenInfo.new(1.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = doorPart.Position + Vector3.new(0, doorPart.Size.Y + 4, 0),
		Transparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		doorPart:Destroy()
	end)
end

local function getPlayersInRoom(roomFolder)
	local floor = roomFolder:FindFirstChild("Floor")
	if not floor then return {} end
	local roomPos = floor.Position
	local roomSize = floor.Size
	local halfX, halfZ = roomSize.X / 2 + 10, roomSize.Z / 2 + 10

	local result = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			local offset = root.Position - roomPos
			if math.abs(offset.X) < halfX and math.abs(offset.Z) < halfZ and math.abs(offset.Y) < 30 then
				table.insert(result, p)
			end
		end
	end
	return result
end

local function firePuzzleComplete(player)
	local remote = Remotes:GetEvent("PuzzleSolved")
	if remote then
		remote:FireAllClients(player.Name)
	end
end

local function awardPuzzleBonus(player)
	local data = HollowBuilder.GetActiveDungeon(player)
	if data then
		data.PuzzleScore = (data.PuzzleScore or 0) + (RunGrading.PuzzleBonus or 200)
	end
end

local function completePuzzle(puzzleFolder, dungeonData, roomIndex, player, awardBonus)
	puzzleFolder:SetAttribute("PuzzleSolved", true)

	-- Play chime
	playChimeSound(puzzleFolder)

	-- Open exit door
	local exitDoor = puzzleFolder:FindFirstChild("ExitDoor")
	if exitDoor then openExitDoor(exitDoor) end

	-- Award score bonus
	if awardBonus then
		awardPuzzleBonus(player)
	end

	-- Fire remote
	firePuzzleComplete(player)

	-- Mark room cleared in dungeon
	task.defer(function()
		HollowBuilder.RoomCleared(player, dungeonData, roomIndex)
	end)
end

local function checkFailCount(puzzleFolder, dungeonData, roomIndex, player)
	local fails = puzzleFolder:GetAttribute("FailCount") or 0
	fails = fails + 1
	puzzleFolder:SetAttribute("FailCount", fails)
	if fails >= 3 then
		completePuzzle(puzzleFolder, dungeonData, roomIndex, player, false)
		return true -- puzzle force-opened
	end
	return false
end

--------------------------------------------------------------------------------
-- TRIVIA PUZZLE
-- Board Part with SurfaceGui showing question, 4 ClickDetector answer parts.
-- Correct = open exit. Wrong = 500 damage.
--------------------------------------------------------------------------------
local TRIVIA_QUESTIONS = {
	{
		Question = "What creature lurks in the deepest crypts?",
		Answers = { "Skeleton", "Shadow Champion", "Bat", "Spider" },
		Correct = 2,
	},
	{
		Question = "How many keys are needed to reach the boss?",
		Answers = { "3", "4", "5", "6" },
		Correct = 3,
	},
	{
		Question = "Which key is the rarest in the dungeon?",
		Answers = { "Iron Key", "Gold Key", "Emerald Key", "Shadow Key" },
		Correct = 4,
	},
	{
		Question = "What material are dungeon floors made of?",
		Answers = { "Wood", "Cobblestone", "Diamond", "Glass" },
		Correct = 2,
	},
	{
		Question = "What guards the Gold Vault?",
		Answers = { "Iron Keeper", "Crimson Sentinel", "Gold Guardian", "Shadow Champion" },
		Correct = 3,
	},
	{
		Question = "How many Shadow Keys unlock the boss path?",
		Answers = { "1", "2", "3", "4" },
		Correct = 2,
	},
}

local ANSWER_COLORS = {
	Color3.fromRGB(220, 60, 60),   -- Red
	Color3.fromRGB(60, 120, 220),  -- Blue
	Color3.fromRGB(60, 200, 80),   -- Green
	Color3.fromRGB(220, 180, 40),  -- Yellow
}

local function buildTrivia(puzzleFolder, origin, roomSize, dungeonData, roomIndex, player)
	local typeVal = Instance.new("StringValue")
	typeVal.Name = "PuzzleType"
	typeVal.Value = "Trivia"
	typeVal.Parent = puzzleFolder

	local q = TRIVIA_QUESTIONS[math.random(#TRIVIA_QUESTIONS)]

	-- Board part on the back wall
	local boardPos = origin + Vector3.new(0, 8, -roomSize.Z / 2 + 2)
	local board = makePart({
		Name = "TriviaBoard",
		Size = Vector3.new(20, 10, 1),
		Position = boardPos,
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(30, 30, 40),
		Parent = puzzleFolder,
	})

	-- SurfaceGui on board (front face)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(800, 400)
	sg.Parent = board

	local questionLabel = Instance.new("TextLabel")
	questionLabel.Name = "QuestionLabel"
	questionLabel.Size = UDim2.new(0.9, 0, 0.35, 0)
	questionLabel.Position = UDim2.new(0.05, 0, 0.05, 0)
	questionLabel.BackgroundTransparency = 1
	questionLabel.Text = q.Question
	questionLabel.TextColor3 = Color3.fromRGB(255, 255, 200)
	questionLabel.TextScaled = true
	questionLabel.Font = Enum.Font.GothamBold
	questionLabel.TextWrapped = true
	questionLabel.Parent = sg

	-- Instruction label
	local instrLabel = Instance.new("TextLabel")
	instrLabel.Size = UDim2.new(0.9, 0, 0.12, 0)
	instrLabel.Position = UDim2.new(0.05, 0, 0.38, 0)
	instrLabel.BackgroundTransparency = 1
	instrLabel.Text = "Click the correct answer below!"
	instrLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	instrLabel.TextScaled = true
	instrLabel.Font = Enum.Font.Gotham
	instrLabel.Parent = sg

	-- 4 answer button parts on the floor in front of the board
	local answered = false
	for i = 1, 4 do
		local col = (i - 1) % 2
		local row = math.floor((i - 1) / 2)
		local btnPos = origin + Vector3.new(-5 + col * 10, 1.5, -roomSize.Z / 2 + 12 + row * 6)

		local btn = makePart({
			Name = "Answer_" .. i,
			Size = Vector3.new(8, 3, 4),
			Position = btnPos,
			Material = Enum.Material.SmoothPlastic,
			Color = ANSWER_COLORS[i],
			Parent = puzzleFolder,
		})

		-- Label on top face
		local btnGui = Instance.new("SurfaceGui")
		btnGui.Face = Enum.NormalId.Top
		btnGui.CanvasSize = Vector2.new(400, 200)
		btnGui.Parent = btn

		local btnLabel = Instance.new("TextLabel")
		btnLabel.Size = UDim2.new(0.9, 0, 0.9, 0)
		btnLabel.Position = UDim2.new(0.05, 0, 0.05, 0)
		btnLabel.BackgroundTransparency = 1
		btnLabel.Text = q.Answers[i]
		btnLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		btnLabel.TextScaled = true
		btnLabel.Font = Enum.Font.GothamBold
		btnLabel.TextWrapped = true
		btnLabel.Parent = btnGui

		-- Also show on front face for readability
		local btnGuiFront = Instance.new("SurfaceGui")
		btnGuiFront.Face = Enum.NormalId.Front
		btnGuiFront.CanvasSize = Vector2.new(400, 200)
		btnGuiFront.Parent = btn

		local btnLabelFront = Instance.new("TextLabel")
		btnLabelFront.Size = UDim2.new(0.9, 0, 0.9, 0)
		btnLabelFront.Position = UDim2.new(0.05, 0, 0.05, 0)
		btnLabelFront.BackgroundTransparency = 1
		btnLabelFront.Text = q.Answers[i]
		btnLabelFront.TextColor3 = Color3.fromRGB(255, 255, 255)
		btnLabelFront.TextScaled = true
		btnLabelFront.Font = Enum.Font.GothamBold
		btnLabelFront.TextWrapped = true
		btnLabelFront.Parent = btnGuiFront

		local cd = Instance.new("ClickDetector")
		cd.MaxActivationDistance = 20
		cd.Parent = btn

		cd.MouseClick:Connect(function(clickPlayer)
			if answered then return end
			if puzzleFolder:GetAttribute("PuzzleSolved") then return end

			if i == q.Correct then
				answered = true
				btn.Material = Enum.Material.Neon
				completePuzzle(puzzleFolder, dungeonData, roomIndex, clickPlayer, true)
			else
				-- Wrong answer: 500 damage
				dealRawDamage(clickPlayer, 500)
				btn.Transparency = 0.6
				btn.CanCollide = false

				-- Flash red on board
				local origColor = board.Color
				board.Color = Color3.fromRGB(180, 30, 30)
				task.delay(0.5, function()
					if board and board.Parent then board.Color = origColor end
				end)

				if checkFailCount(puzzleFolder, dungeonData, roomIndex, clickPlayer) then
					answered = true
				end
			end
		end)
	end
end

--------------------------------------------------------------------------------
-- BOMB DEFUSE PUZZLE
-- Glowing bomb Part with countdown SurfaceGui. 3 colored wires must be
-- clicked in the right (randomized) order before timer hits 0.
-- Failure = 1000 damage to all players in the room.
--------------------------------------------------------------------------------
local WIRE_COLORS = {
	{ Name = "Red",    Color = Color3.fromRGB(220, 40, 40) },
	{ Name = "Blue",   Color = Color3.fromRGB(40, 80, 220) },
	{ Name = "Green",  Color = Color3.fromRGB(40, 200, 60) },
	{ Name = "Yellow", Color = Color3.fromRGB(220, 200, 40) },
	{ Name = "Purple", Color = Color3.fromRGB(160, 50, 220) },
}

local function buildBombDefuse(puzzleFolder, origin, roomSize, dungeonData, roomIndex, player)
	local typeVal = Instance.new("StringValue")
	typeVal.Name = "PuzzleType"
	typeVal.Value = "BombDefuse"
	typeVal.Parent = puzzleFolder

	-- Pick 3 random wire colors for this run
	local available = {}
	for i, w in ipairs(WIRE_COLORS) do
		table.insert(available, i)
	end
	-- Shuffle and pick 3
	for i = #available, 2, -1 do
		local j = math.random(i)
		available[i], available[j] = available[j], available[i]
	end
	local chosenIndices = { available[1], available[2], available[3] }

	-- Randomize the correct order
	local correctOrder = { 1, 2, 3 }
	for i = 3, 2, -1 do
		local j = math.random(i)
		correctOrder[i], correctOrder[j] = correctOrder[j], correctOrder[i]
	end

	-- Bomb part (center of room, glowing)
	local bombPos = origin + Vector3.new(0, 3, 0)
	local bomb = makePart({
		Name = "Bomb",
		Size = Vector3.new(6, 6, 6),
		Position = bombPos,
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 80, 30),
		Parent = puzzleFolder,
	})

	local bombLight = Instance.new("PointLight")
	bombLight.Color = Color3.fromRGB(255, 80, 30)
	bombLight.Range = 30
	bombLight.Brightness = 3
	bombLight.Parent = bomb

	-- Pulsing glow effect
	local pulseUp = true
	local pulseConn
	pulseConn = RunService.Heartbeat:Connect(function()
		if not bomb or not bomb.Parent then
			pulseConn:Disconnect()
			return
		end
		if puzzleFolder:GetAttribute("PuzzleSolved") then
			pulseConn:Disconnect()
			return
		end
		local t = os.clock() * 3
		bombLight.Brightness = 2 + math.sin(t) * 1.5
	end)

	-- Timer SurfaceGui on bomb
	local BOMB_TIME = 30 -- seconds
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(400, 400)
	sg.Parent = bomb

	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "TimerLabel"
	timerLabel.Size = UDim2.new(0.9, 0, 0.5, 0)
	timerLabel.Position = UDim2.new(0.05, 0, 0.05, 0)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text = tostring(BOMB_TIME)
	timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	timerLabel.TextScaled = true
	timerLabel.Font = Enum.Font.Code
	timerLabel.Parent = sg

	-- Order hint label
	local hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "HintLabel"
	hintLabel.Size = UDim2.new(0.9, 0, 0.3, 0)
	hintLabel.Position = UDim2.new(0.05, 0, 0.55, 0)
	hintLabel.BackgroundTransparency = 1
	hintLabel.TextColor3 = Color3.fromRGB(200, 200, 150)
	hintLabel.TextScaled = true
	hintLabel.Font = Enum.Font.GothamBold
	hintLabel.TextWrapped = true
	hintLabel.Parent = sg

	-- Build the hint string showing correct wire order
	local orderNames = {}
	for _, idx in ipairs(correctOrder) do
		table.insert(orderNames, WIRE_COLORS[chosenIndices[idx]].Name)
	end
	hintLabel.Text = "Cut: " .. table.concat(orderNames, " > ")

	-- Wire parts arranged around the bomb
	local currentStep = 0
	local defused = false
	local exploded = false

	local wireAngles = { -1, 0, 1 } -- spread wires left/center/right

	for wireSlot = 1, 3 do
		local wireColorData = WIRE_COLORS[chosenIndices[wireSlot]]
		local xOffset = wireAngles[wireSlot] * 8
		local wirePos = origin + Vector3.new(xOffset, 1.5, 10)

		local wire = makePart({
			Name = "Wire_" .. wireColorData.Name,
			Size = Vector3.new(4, 1, 8),
			Position = wirePos,
			Material = Enum.Material.Neon,
			Color = wireColorData.Color,
			Parent = puzzleFolder,
		})

		-- Wire label
		local wsg = Instance.new("SurfaceGui")
		wsg.Face = Enum.NormalId.Top
		wsg.CanvasSize = Vector2.new(300, 150)
		wsg.Parent = wire

		local wLabel = Instance.new("TextLabel")
		wLabel.Size = UDim2.new(0.9, 0, 0.9, 0)
		wLabel.Position = UDim2.new(0.05, 0, 0.05, 0)
		wLabel.BackgroundTransparency = 1
		wLabel.Text = wireColorData.Name .. " Wire"
		wLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		wLabel.TextScaled = true
		wLabel.Font = Enum.Font.GothamBold
		wLabel.Parent = wsg

		local cd = Instance.new("ClickDetector")
		cd.MaxActivationDistance = 15
		cd.Parent = wire

		cd.MouseClick:Connect(function(clickPlayer)
			if defused or exploded then return end
			if puzzleFolder:GetAttribute("PuzzleSolved") then return end

			local expectedSlot = correctOrder[currentStep + 1]
			if wireSlot == expectedSlot then
				-- Correct wire
				currentStep = currentStep + 1
				wire.Material = Enum.Material.SmoothPlastic
				wire.Transparency = 0.5
				wire.CanCollide = false
				cd:Destroy()

				if currentStep >= 3 then
					-- Bomb defused!
					defused = true
					bomb.Color = Color3.fromRGB(50, 200, 50)
					bombLight.Color = Color3.fromRGB(50, 200, 50)
					timerLabel.Text = "DEFUSED"
					timerLabel.TextColor3 = Color3.fromRGB(50, 255, 50)
					completePuzzle(puzzleFolder, dungeonData, roomIndex, clickPlayer, true)
				end
			else
				-- Wrong wire order - reset progress, count as fail
				currentStep = 0
				-- Re-enable all wires
				for _, child in ipairs(puzzleFolder:GetChildren()) do
					if child.Name:sub(1, 5) == "Wire_" then
						child.Material = Enum.Material.Neon
						child.Transparency = 0
						child.CanCollide = true
					end
				end

				-- Flash bomb red
				bomb.Color = Color3.fromRGB(255, 0, 0)
				task.delay(0.5, function()
					if bomb and bomb.Parent and not defused then
						bomb.Color = Color3.fromRGB(255, 80, 30)
					end
				end)

				if checkFailCount(puzzleFolder, dungeonData, roomIndex, clickPlayer) then
					exploded = true
				end
			end
		end)
	end

	-- Countdown timer
	task.spawn(function()
		local startTime = os.clock()
		while not defused and not exploded do
			task.wait(0.5)
			if not bomb or not bomb.Parent then return end
			if puzzleFolder:GetAttribute("PuzzleSolved") then return end

			local elapsed = os.clock() - startTime
			local remaining = math.max(0, BOMB_TIME - math.floor(elapsed))
			timerLabel.Text = tostring(remaining)

			if remaining <= 10 then
				timerLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
			end

			if remaining <= 0 then
				-- BOOM! 1000 damage to all players in room
				exploded = true
				timerLabel.Text = "BOOM!"
				bomb.Color = Color3.fromRGB(255, 0, 0)

				local playersInRoom = getPlayersInRoom(puzzleFolder.Parent)
				for _, p in ipairs(playersInRoom) do
					dealRawDamage(p, 1000)
				end

				-- Explosion visual
				local explosion = Instance.new("Explosion")
				explosion.Position = bomb.Position
				explosion.BlastRadius = 0
				explosion.BlastPressure = 0
				explosion.Parent = bomb

				checkFailCount(puzzleFolder, dungeonData, roomIndex, player)
				return
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- ICE WALK PUZZLE
-- Grid of floor tiles, some weak. Brief reveal at start, then hidden.
-- Stepping on weak tile = 300 damage + teleport back to start.
--------------------------------------------------------------------------------
local ICE_GRID_COLS = 5
local ICE_GRID_ROWS = 8
local ICE_TILE_SIZE = 8
local ICE_TILE_GAP = 1
local ICE_REVEAL_TIME = 3 -- seconds to show weak tiles at start
local ICE_WEAK_RATIO = 0.35 -- ~35% of tiles are weak

local function buildIceWalk(puzzleFolder, origin, roomSize, dungeonData, roomIndex, player)
	local typeVal = Instance.new("StringValue")
	typeVal.Name = "PuzzleType"
	typeVal.Value = "IceWalk"
	typeVal.Parent = puzzleFolder

	local gridFolder = Instance.new("Folder")
	gridFolder.Name = "IceGrid"
	gridFolder.Parent = puzzleFolder

	local stride = ICE_TILE_SIZE + ICE_TILE_GAP
	local gridWidth = ICE_GRID_COLS * stride - ICE_TILE_GAP
	local gridDepth = ICE_GRID_ROWS * stride - ICE_TILE_GAP
	local gridStartX = origin.X - gridWidth / 2 + ICE_TILE_SIZE / 2
	local gridStartZ = origin.Z + roomSize.Z / 2 - 15 - gridDepth -- start near front, extend toward back
	local floorY = origin.Y - 1 -- tile surface level

	-- Start platform (safe zone at front)
	local startPos = Vector3.new(origin.X, floorY, origin.Z + roomSize.Z / 2 - 8)
	local startPlatform = makePart({
		Name = "StartPlatform",
		Size = Vector3.new(gridWidth + 4, 1, 8),
		Position = startPos,
		Material = Enum.Material.Cobblestone,
		Color = Color3.fromRGB(80, 80, 100),
		Parent = puzzleFolder,
	})

	-- End platform (safe zone at back, near exit)
	local endPos = Vector3.new(origin.X, floorY, gridStartZ - 4)
	local endPlatform = makePart({
		Name = "EndPlatform",
		Size = Vector3.new(gridWidth + 4, 1, 8),
		Position = endPos,
		Material = Enum.Material.Cobblestone,
		Color = Color3.fromRGB(80, 100, 80),
		Parent = puzzleFolder,
	})

	-- Pit beneath the grid
	local pitY = floorY - 20
	local pit = makePart({
		Name = "PitFloor",
		Size = Vector3.new(gridWidth + 10, 1, gridDepth + 10),
		Position = Vector3.new(origin.X, pitY, gridStartZ + gridDepth / 2),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(30, 20, 20),
		Parent = puzzleFolder,
	})

	-- Generate weak tile map (first and last rows always safe)
	local weakMap = {} -- [row][col] = true if weak
	for row = 1, ICE_GRID_ROWS do
		weakMap[row] = {}
		if row == 1 or row == ICE_GRID_ROWS then
			-- First and last row always safe
			for col = 1, ICE_GRID_COLS do
				weakMap[row][col] = false
			end
		else
			-- Ensure at least one safe tile per row so puzzle is solvable
			local safeCol = math.random(ICE_GRID_COLS)
			for col = 1, ICE_GRID_COLS do
				if col == safeCol then
					weakMap[row][col] = false
				else
					weakMap[row][col] = math.random() < ICE_WEAK_RATIO
				end
			end
		end
	end

	-- Create tiles
	local tiles = {} -- [row][col] = { Part = part, IsWeak = bool }
	local weakColor = Color3.fromRGB(180, 60, 60)
	local safeColor = Color3.fromRGB(180, 220, 255)
	local hiddenColor = Color3.fromRGB(200, 230, 255) -- all tiles look the same when hidden

	for row = 1, ICE_GRID_ROWS do
		tiles[row] = {}
		for col = 1, ICE_GRID_COLS do
			local isWeak = weakMap[row][col]
			local tileX = gridStartX + (col - 1) * stride
			local tileZ = gridStartZ + (ICE_GRID_ROWS - row) * stride -- row 1 closest to start

			local tile = makePart({
				Name = isWeak and "WeakTile" or "SafeTile",
				Size = Vector3.new(ICE_TILE_SIZE, 1, ICE_TILE_SIZE),
				Position = Vector3.new(tileX, floorY, tileZ),
				Material = Enum.Material.Ice,
				Color = isWeak and weakColor or safeColor, -- initially revealed
				Parent = gridFolder,
			})

			tiles[row][col] = { Part = tile, IsWeak = isWeak }

			-- Weak tile touch detection
			if isWeak then
				tile.Touched:Connect(function(hit)
					if puzzleFolder:GetAttribute("PuzzleSolved") then return end
					local character = hit.Parent
					local humanoid = character and character:FindFirstChild("Humanoid")
					if not humanoid then return end
					local touchPlayer = Players:GetPlayerFromCharacter(character)
					if not touchPlayer then return end

					-- Prevent repeated triggers
					local debounceKey = "IceDebounce_" .. touchPlayer.UserId
					if puzzleFolder:GetAttribute(debounceKey) then return end
					puzzleFolder:SetAttribute(debounceKey, true)

					-- Tile breaks
					tile.Transparency = 0.8
					tile.CanCollide = false

					-- Deal 300 damage
					dealRawDamage(touchPlayer, 300)

					-- Teleport back to start
					local rootPart = character:FindFirstChild("HumanoidRootPart")
					if rootPart then
						rootPart.CFrame = CFrame.new(startPos + Vector3.new(0, 3, 0))
					end

					-- Count as failure
					checkFailCount(puzzleFolder, dungeonData, roomIndex, touchPlayer)

					-- Restore tile after delay
					task.delay(2, function()
						if tile and tile.Parent then
							tile.Transparency = 0
							tile.CanCollide = true
						end
						puzzleFolder:SetAttribute(debounceKey, nil)
					end)
				end)
			end
		end
	end

	-- End platform touch = puzzle solved
	endPlatform.Touched:Connect(function(hit)
		if puzzleFolder:GetAttribute("PuzzleSolved") then return end
		local character = hit.Parent
		local humanoid = character and character:FindFirstChild("Humanoid")
		if not humanoid then return end
		local touchPlayer = Players:GetPlayerFromCharacter(character)
		if not touchPlayer then return end

		completePuzzle(puzzleFolder, dungeonData, roomIndex, touchPlayer, true)
	end)

	-- Reveal phase: show weak tiles briefly, then hide
	task.spawn(function()
		-- Tiles start revealed (set in creation loop above)
		task.wait(ICE_REVEAL_TIME)

		-- Hide all tiles to same color
		for row = 1, ICE_GRID_ROWS do
			for col = 1, ICE_GRID_COLS do
				local tileData = tiles[row][col]
				if tileData.Part and tileData.Part.Parent then
					tileData.Part.Color = hiddenColor
				end
			end
		end
	end)

	-- Info sign near start
	local sign = makePart({
		Name = "IceWalkSign",
		Size = Vector3.new(10, 5, 0.5),
		Position = startPos + Vector3.new(0, 5, 2),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(30, 30, 50),
		Parent = puzzleFolder,
	})

	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.CanvasSize = Vector2.new(400, 200)
	signGui.Parent = sign

	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.new(0.9, 0, 0.9, 0)
	signLabel.Position = UDim2.new(0.05, 0, 0.05, 0)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = "ICE WALK\nMemorize the safe path!\nWeak tiles crack beneath you."
	signLabel.TextColor3 = Color3.fromRGB(180, 220, 255)
	signLabel.TextScaled = true
	signLabel.Font = Enum.Font.GothamBold
	signLabel.TextWrapped = true
	signLabel.Parent = signGui
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------
local PUZZLE_BUILDERS = {
	Trivia = buildTrivia,
	BombDefuse = buildBombDefuse,
	IceWalk = buildIceWalk,
}

local PUZZLE_TYPES = { "Trivia", "BombDefuse", "IceWalk" }

--- Build a puzzle inside a room folder.
--- @param roomFolder Folder — the room's workspace folder (must have a Floor child)
--- @param origin Vector3 — center of the room floor
--- @param roomSize Vector3 — room dimensions
--- @param dungeonData table — the active dungeon data for this player
--- @param roomIndex number — room index in HollowConfig.Chambers
--- @param player Player — the dungeon owner
--- @param puzzleType string|nil — force a type, or nil for random
function PuzzleEncounters.BuildPuzzle(roomFolder, origin, roomSize, dungeonData, roomIndex, player, puzzleType)
	if not puzzleType then
		puzzleType = PUZZLE_TYPES[math.random(#PUZZLE_TYPES)]
	end

	local builder = PUZZLE_BUILDERS[puzzleType]
	if not builder then
		warn("[PuzzleEncounters] Unknown puzzle type: " .. tostring(puzzleType))
		return nil
	end

	-- Create puzzle container folder
	local puzzleFolder = Instance.new("Folder")
	puzzleFolder.Name = "Puzzle_" .. puzzleType
	puzzleFolder:SetAttribute("PuzzleSolved", false)
	puzzleFolder:SetAttribute("FailCount", 0)
	puzzleFolder.Parent = roomFolder

	-- Build exit door blocking the back wall opening
	local exitDoor = makePart({
		Name = "ExitDoor",
		Size = Vector3.new(16, 16, 4),
		Position = origin + Vector3.new(0, 8, -roomSize.Z / 2 - 2),
		Material = Enum.Material.DiamondPlate,
		Color = Color3.fromRGB(80, 60, 50),
		Parent = puzzleFolder,
	})

	-- Glow trim on exit door
	local doorTrim = makePart({
		Name = "ExitDoorTrim",
		Size = Vector3.new(16.5, 2, 4.5),
		Position = exitDoor.Position + Vector3.new(0, 7, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 200, 50),
		CanCollide = false,
		Parent = exitDoor,
	})

	local doorLight = Instance.new("PointLight")
	doorLight.Color = Color3.fromRGB(255, 200, 50)
	doorLight.Range = 15
	doorLight.Brightness = 2
	doorLight.Parent = exitDoor

	-- Build the specific puzzle
	builder(puzzleFolder, origin, roomSize, dungeonData, roomIndex, player)

	return puzzleFolder
end

--- Get available puzzle types.
function PuzzleEncounters.GetPuzzleTypes()
	return PUZZLE_TYPES
end

return PuzzleEncounters
