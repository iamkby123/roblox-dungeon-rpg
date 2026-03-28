local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SkillConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local UIController = {}

local hud -- the ScreenGui
local SkillController -- for cooldown display
local currentStats = nil
local dungeonStartTime = nil

function UIController.Init(mainHUD, skillCtrl)
	hud = mainHUD
	SkillController = skillCtrl

	-- Listen for stat updates
	local statsRemote = Remotes:GetEvent("StatsUpdated")
	if statsRemote then
		statsRemote.OnClientEvent:Connect(function(stats)
			currentStats = stats
			UIController.UpdateStatPanel(stats)
		end)
	end

	-- Listen for item pickups
	local itemRemote = Remotes:GetEvent("ItemPickup")
	if itemRemote then
		itemRemote.OnClientEvent:Connect(function(itemData)
			UIController.ShowItemNotification(itemData)
		end)
	end

	-- Listen for dungeon state changes
	local dungeonRemote = Remotes:GetEvent("DungeonStateChanged")
	if dungeonRemote then
		dungeonRemote.OnClientEvent:Connect(function(eventType, roomIndex, roomName, keyColor)
			UIController.ShowRoomNotification(eventType, roomIndex, roomName, keyColor)
			if eventType == "DungeonStarted" then
				dungeonStartTime = os.clock()
				local timerFrame = hud:FindFirstChild("TimerFrame")
				if timerFrame then timerFrame.Visible = true end
				-- Show key inventory HUD
				UIController.CreateKeyInventoryHUD()
			elseif eventType == "DungeonComplete" then
				dungeonStartTime = nil
				-- Hide key inventory
				local keyHud = hud:FindFirstChild("KeyInventory")
				if keyHud then keyHud.Visible = false end
			elseif eventType == "KeyPickedUp" then
				-- Light up the collected key in the HUD
				UIController.UpdateKeySlot(roomName, keyColor) -- roomName = key name, keyColor = {R,G,B}
			end
		end)
	end

	-- Listen for death/revive
	local diedRemote = Remotes:GetEvent("PlayerDied")
	if diedRemote then
		diedRemote.OnClientEvent:Connect(function(deathCount, respawnTime)
			UIController.ShowDeathOverlay(deathCount, respawnTime or 5)
		end)
	end

	local revivedRemote = Remotes:GetEvent("PlayerRevived")
	if revivedRemote then
		revivedRemote.OnClientEvent:Connect(function()
			UIController.HideDeathOverlay()
		end)
	end

	-- Listen for class selection
	local classRemote = Remotes:GetEvent("ClassSelected")
	if classRemote then
		classRemote.OnClientEvent:Connect(function(classId)
			UIController.ShowClassIndicator(classId)
		end)
	end

	-- Listen for dungeon score
	local scoreRemote = Remotes:GetEvent("DungeonScore")
	if scoreRemote then
		scoreRemote.OnClientEvent:Connect(function(scoreData)
			UIController.ShowScoreOverlay(scoreData)
		end)
	end

	-- Listen for boss phase changes
	local bossPhaseRemote = Remotes:GetEvent("BossPhaseChanged")
	if bossPhaseRemote then
		bossPhaseRemote.OnClientEvent:Connect(function(phaseName, hpFraction)
			UIController.ShowBossPhase(phaseName)
		end)
	end

	-- Listen for inventory updates
	local invRemote = Remotes:GetEvent("InventoryUpdated")
	if invRemote then
		invRemote.OnClientEvent:Connect(function(inventory)
			UIController.UpdateInventoryPanel(inventory)
		end)
	end

	-- Tab to toggle stat panel, E to toggle inventory
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.Tab then
			local statPanel = hud:FindFirstChild("StatPanel")
			if statPanel then
				statPanel.Visible = not statPanel.Visible
			end
		elseif input.KeyCode == Enum.KeyCode.E then
			local invPanel = hud:FindFirstChild("InventoryPanel")
			if invPanel then
				invPanel.Visible = not invPanel.Visible
			end
		end
	end)

	-- Update loop for health, mana, and cooldowns
	RunService.RenderStepped:Connect(function()
		UIController.UpdateHealthBar()
		UIController.UpdateManaBar()
		UIController.UpdateSkillCooldowns()
		UIController.UpdateTimer()
		UIController.UpdateBossBar()
	end)
end

function UIController.UpdateHealthBar()
	local player = Players.LocalPlayer
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local healthBar = hud:FindFirstChild("HealthBar")
	if not healthBar then return end

	local fill = healthBar:FindFirstChild("Fill")
	local text = healthBar:FindFirstChild("Text")

	local fraction = humanoid.Health / humanoid.MaxHealth
	if fill then
		fill.Size = UDim2.new(math.clamp(fraction, 0, 1), 0, 1, 0)
		-- Color from green to red
		if fraction > 0.5 then
			fill.BackgroundColor3 = Color3.fromRGB(0, 200, 50)
		elseif fraction > 0.25 then
			fill.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
		else
			fill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
		end
	end
	if text then
		text.Text = math.floor(humanoid.Health) .. " / " .. math.floor(humanoid.MaxHealth)
	end
end

function UIController.UpdateManaBar()
	local player = Players.LocalPlayer
	local character = player.Character
	if not character then return end

	local currentMana = character:GetAttribute("CurrentMana") or 0
	local maxMana = character:GetAttribute("MaxMana") or 100

	local manaBar = hud:FindFirstChild("ManaBar")
	if not manaBar then return end

	local fill = manaBar:FindFirstChild("Fill")
	local text = manaBar:FindFirstChild("Text")

	local fraction = maxMana > 0 and currentMana / maxMana or 0
	if fill then
		fill.Size = UDim2.new(math.clamp(fraction, 0, 1), 0, 1, 0)
	end
	if text then
		text.Text = math.floor(currentMana) .. " / " .. math.floor(maxMana)
	end
end

function UIController.UpdateSkillCooldowns()
	if not SkillController then return end

	local skillBar = hud:FindFirstChild("SkillBar")
	if not skillBar then return end

	local equippedSlot = SkillController.GetEquippedSlot()

	for slot = 1, 4 do
		local weaponId = SkillConfig.KeyBindings[slot]
		if not weaponId then continue end

		local slotFrame = skillBar:FindFirstChild("Skill" .. slot)
		if not slotFrame then continue end

		local fraction = SkillController.GetCooldownFraction(weaponId)
		local remaining = SkillController.GetCooldownRemaining(weaponId)

		-- Update cooldown overlay
		local overlay = slotFrame:FindFirstChild("CooldownOverlay")
		if overlay then
			overlay.Size = UDim2.new(1, 0, math.clamp(fraction, 0, 1), 0)
		end

		local cdText = slotFrame:FindFirstChild("CooldownText")
		if cdText then
			if remaining > 0 then
				cdText.Text = string.format("%.1f", remaining)
			else
				cdText.Text = ""
			end
		end

		-- Update equipped indicator
		local isEquipped = (slot == equippedSlot)
		local glow = slotFrame:FindFirstChild("EquippedGlow")
		if glow then
			glow.BackgroundTransparency = isEquipped and 0.5 or 1
		end
		local border = slotFrame:FindFirstChild("Border")
		if border then
			border.Thickness = isEquipped and 3 or 1
		end
		local clickHint = slotFrame:FindFirstChild("ClickHint")
		if clickHint then
			clickHint.Text = isEquipped and "CLICK" or ""
		end
	end
end

function UIController.UpdateStatPanel(stats)
	local statPanel = hud:FindFirstChild("StatPanel")
	if not statPanel then return end

	local mapping = {
		Health = "Health",
		Mana = "Mana",
		Strength = "Strength",
		Defense = "Defense",
		Speed = "Speed",
		CritChance = "CritChance",
		CritDamage = "CritDamage",
	}

	local displayNames = {
		Health = "Health",
		Mana = "Mana",
		Strength = "Strength",
		Defense = "Defense",
		Speed = "Speed",
		CritChance = "Crit Chance",
		CritDamage = "Crit Damage",
	}

	for statKey, labelName in pairs(mapping) do
		local label = statPanel:FindFirstChild(labelName)
		if label and stats[statKey] then
			local value = stats[statKey]
			local displayName = displayNames[statKey] or statKey
			if statKey == "CritChance" then
				label.Text = displayName .. ": " .. math.floor(value * 100) .. "%"
			elseif statKey == "CritDamage" then
				label.Text = displayName .. ": " .. math.floor(value * 100) .. "%"
			else
				label.Text = displayName .. ": " .. math.floor(value)
			end
		end
	end
end

function UIController.UpdateInventoryPanel(inventory)
	local invPanel = hud:FindFirstChild("InventoryPanel")
	if not invPanel then return end

	local itemList = invPanel:FindFirstChild("ItemList")
	if not itemList then return end

	local emptyText = invPanel:FindFirstChild("EmptyText")

	-- Clear existing items
	for _, child in ipairs(itemList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	if not inventory or #inventory == 0 then
		if emptyText then emptyText.Visible = true end
		itemList.CanvasSize = UDim2.new(0, 0, 0, 0)
		return
	end

	if emptyText then emptyText.Visible = false end

	local rarityColors = {
		Common = Color3.fromRGB(200, 200, 200),
		Uncommon = Color3.fromRGB(100, 255, 100),
		Rare = Color3.fromRGB(100, 150, 255),
		Legendary = Color3.fromRGB(255, 170, 0),
	}

	for i, item in ipairs(inventory) do
		local itemFrame = Instance.new("Frame")
		itemFrame.Name = "Item_" .. i
		itemFrame.Size = UDim2.new(1, -8, 0, 45)
		itemFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
		itemFrame.BorderSizePixel = 0
		itemFrame.LayoutOrder = i
		itemFrame.Parent = itemList

		local itemCorner = Instance.new("UICorner")
		itemCorner.CornerRadius = UDim.new(0, 4)
		itemCorner.Parent = itemFrame

		local color = rarityColors[item.Rarity] or Color3.new(1, 1, 1)

		local itemBorder = Instance.new("UIStroke")
		itemBorder.Color = color
		itemBorder.Thickness = 1
		itemBorder.Transparency = 0.5
		itemBorder.Parent = itemFrame

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -10, 0, 20)
		nameLabel.Position = UDim2.new(0, 5, 0, 2)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = item.Name
		nameLabel.TextColor3 = color
		nameLabel.TextScaled = true
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Parent = itemFrame

		-- Stat boosts text
		local boostParts = {}
		for stat, value in pairs(item.StatBoosts) do
			if stat == "CritChance" or stat == "CritDamage" then
				table.insert(boostParts, "+" .. math.floor(value * 100) .. "% " .. stat)
			else
				table.insert(boostParts, "+" .. value .. " " .. stat)
			end
		end

		local boostLabel = Instance.new("TextLabel")
		boostLabel.Size = UDim2.new(1, -10, 0, 16)
		boostLabel.Position = UDim2.new(0, 5, 0, 24)
		boostLabel.BackgroundTransparency = 1
		boostLabel.Text = table.concat(boostParts, ", ")
		boostLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
		boostLabel.TextScaled = true
		boostLabel.TextXAlignment = Enum.TextXAlignment.Left
		boostLabel.Font = Enum.Font.Gotham
		boostLabel.Parent = itemFrame
	end

	-- Update canvas size
	itemList.CanvasSize = UDim2.new(0, 0, 0, #inventory * 49)
end

function UIController.ShowItemNotification(itemData)
	local notifications = hud:FindFirstChild("Notifications")
	if not notifications then return end

	local notif = Instance.new("Frame")
	notif.Size = UDim2.new(1, 0, 0, 50)
	notif.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	notif.BackgroundTransparency = 0.2
	notif.BorderSizePixel = 0
	notif.Parent = notifications

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = notif

	local rarityColor = Color3.new(1, 1, 1)
	if itemData.Color then
		rarityColor = Color3.new(itemData.Color[1], itemData.Color[2], itemData.Color[3])
	end

	local border = Instance.new("UIStroke")
	border.Color = rarityColor
	border.Thickness = 2
	border.Parent = notif

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -10, 0.5, 0)
	nameLabel.Position = UDim2.new(0, 5, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = itemData.Name .. " (" .. itemData.Rarity .. ")"
	nameLabel.TextColor3 = rarityColor
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = notif

	-- Build stat text
	local statParts = {}
	for stat, value in pairs(itemData.StatBoosts) do
		local displayValue
		if stat == "CritChance" or stat == "CritDamage" then
			displayValue = "+" .. math.floor(value * 100) .. "%"
		else
			displayValue = "+" .. value
		end
		table.insert(statParts, displayValue .. " " .. stat)
	end

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Size = UDim2.new(1, -10, 0.45, 0)
	statsLabel.Position = UDim2.new(0, 5, 0.5, 0)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Text = table.concat(statParts, ", ")
	statsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	statsLabel.TextScaled = true
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.Parent = notif

	-- Fade out and destroy after 3 seconds
	task.delay(3, function()
		if notif and notif.Parent then
			local tween = TweenService:Create(notif, TweenInfo.new(0.5), {
				BackgroundTransparency = 1,
			})
			tween:Play()
			-- Also fade children
			for _, child in ipairs(notif:GetDescendants()) do
				if child:IsA("TextLabel") then
					TweenService:Create(child, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
				end
			end
			task.delay(0.5, function()
				if notif and notif.Parent then
					notif:Destroy()
				end
			end)
		end
	end)
end

function UIController.ShowRoomNotification(eventType, roomIndex, roomName, keyColor)
	local roomNotif = hud:FindFirstChild("RoomNotification")
	if not roomNotif then return end

	local text = ""
	local color = Color3.fromRGB(255, 200, 50)

	if eventType == "DungeonStarted" then
		text = "Entering: " .. (roomName or "Room " .. roomIndex)
		color = Color3.fromRGB(100, 200, 255)
	elseif eventType == "RoomCleared" then
		text = "Room Cleared! " .. (roomName or "Room " .. roomIndex)
		color = Color3.fromRGB(50, 255, 50)
	elseif eventType == "DungeonComplete" then
		text = "DUNGEON COMPLETE!"
		color = Color3.fromRGB(255, 200, 50)
	elseif eventType == "KeySpawned" then
		local keyName = roomName or "A Key"
		text = keyName .. " dropped! Walk over it to pick up!"
		if keyColor and type(keyColor) == "table" then
			color = Color3.new(keyColor[1], keyColor[2], keyColor[3])
		else
			color = Color3.fromRGB(255, 220, 50)
		end
	elseif eventType == "KeyPickedUp" then
		local keyName = roomName or "Key"
		-- Add directional hint based on key type
		local hint = "Press E at the matching door to open it!"
		if keyName == "Iron Key" then
			hint = "Press E at the Iron Door (left branch)!"
		elseif keyName == "Gold Key" then
			hint = "Press E at the Gold Door (right branch)!"
		elseif keyName == "Crimson Key" then
			hint = "Press E at the Crimson Door to go deeper!"
		elseif keyName == "Emerald Key" then
			hint = "Press E at the Emerald Door to go deeper!"
		elseif keyName == "Shadow Key" then
			hint = "Collect both Shadow Keys to reach the BOSS!"
		end
		text = keyName .. " collected! " .. hint
		if keyColor and type(keyColor) == "table" then
			color = Color3.new(keyColor[1], keyColor[2], keyColor[3])
		else
			color = Color3.fromRGB(100, 255, 100)
		end
	elseif eventType == "DoorLocked" then
		text = roomName or "You need the right key!"
		color = Color3.fromRGB(255, 80, 80)
	elseif eventType == "RoomActivated" then
		text = "New area unlocked: " .. (roomName or "Room " .. roomIndex)
		color = Color3.fromRGB(100, 200, 255)
	elseif eventType == "BossPhase" then
		text = roomName
		color = Color3.fromRGB(255, 80, 80)
	end

	roomNotif.Text = text
	roomNotif.TextColor3 = color
	roomNotif.TextTransparency = 0

	-- Fade in
	local fadeIn = TweenService:Create(roomNotif, TweenInfo.new(0.3), {
		TextTransparency = 0,
	})
	fadeIn:Play()

	-- Hold then fade out (shorter for room cleared, longer for key messages)
	local holdTime = (eventType == "KeySpawned" or eventType == "KeyPickedUp" or eventType == "DoorLocked") and 3 or 1.5
	task.delay(holdTime, function()
		local fadeOut = TweenService:Create(roomNotif, TweenInfo.new(0.5), {
			TextTransparency = 1,
		})
		fadeOut:Play()
	end)
end

function UIController.UpdateTimer()
	if not dungeonStartTime then return end
	local timerFrame = hud:FindFirstChild("TimerFrame")
	if not timerFrame then return end
	local timerText = timerFrame:FindFirstChild("TimerText")
	if not timerText then return end
	local elapsed = os.clock() - dungeonStartTime
	local minutes = math.floor(elapsed / 60)
	local seconds = math.floor(elapsed % 60)
	timerText.Text = string.format("%02d:%02d", minutes, seconds)
end

function UIController.ShowDeathOverlay(deathCount, respawnTime)
	local overlay = hud:FindFirstChild("DeathOverlay")
	if not overlay then return end
	overlay.Visible = true
	overlay.BackgroundTransparency = 0.7 -- more transparent so ghost can see

	local reviveText = overlay:FindFirstChild("ReviveText")
	local respawnBtn = overlay:FindFirstChild("RespawnButton")
	local totalTime = respawnTime or 5
	local earlyRespawnTime = 3 -- button appears after 3 seconds

	-- Hide respawn button initially
	if respawnBtn then
		respawnBtn.Visible = false
	end

	-- Wire up respawn button (reconnect each death)
	if respawnBtn then
		-- Clear old connections
		for _, conn in ipairs(respawnBtn:GetChildren()) do
			if conn:IsA("BindableEvent") then conn:Destroy() end
		end
		respawnBtn.MouseButton1Click:Once(function()
			local remote = Remotes:GetEvent("RequestRespawn")
			if remote then
				remote:FireServer()
			end
			respawnBtn.Visible = false
			if reviveText then
				reviveText.Text = "Respawning..."
			end
		end)
	end

	-- Countdown — player is a ghost and can roam freely
	if reviveText then
		for i = totalTime, 1, -1 do
			reviveText.Text = "Ghost Mode - Respawning in " .. i .. "..."
			-- Show respawn button after earlyRespawnTime
			if respawnBtn and i <= (totalTime - earlyRespawnTime) then
				respawnBtn.Visible = true
			end
			task.wait(1)
		end
		reviveText.Text = "Respawning..."
	end
end

function UIController.HideDeathOverlay()
	local overlay = hud:FindFirstChild("DeathOverlay")
	if not overlay then return end
	overlay.Visible = false
	local respawnBtn = overlay:FindFirstChild("RespawnButton")
	if respawnBtn then respawnBtn.Visible = false end
end

function UIController.ShowClassIndicator(classId)
	local indicator = hud:FindFirstChild("ClassIndicator")
	if not indicator then return end
	local label = indicator:FindFirstChild("ClassLabel")
	if label then
		label.Text = classId:upper()
	end
	indicator.Visible = true
end

function UIController.ShowScoreOverlay(data)
	local overlay = hud:FindFirstChild("ScoreOverlay")
	if not overlay then return end

	local gradeLabel = overlay:FindFirstChild("GradeLabel")
	if gradeLabel then
		gradeLabel.Text = data.Grade
		gradeLabel.TextColor3 = Color3.new(data.GradeColor[1], data.GradeColor[2], data.GradeColor[3])
	end

	local lines = {
		"Time: " .. math.floor(data.Time / 60) .. "m " .. (data.Time % 60) .. "s",
		"Damage Dealt: " .. data.DamageDealt,
		"Rooms Cleared: " .. data.RoomsCleared,
		"Deaths: " .. data.Deaths,
		"Total Score: " .. data.Score,
	}

	for i, text in ipairs(lines) do
		local lineLabel = overlay:FindFirstChild("ScoreLine" .. i)
		if lineLabel then lineLabel.Text = text end
	end

	overlay.Visible = true

	-- Hide timer
	local timerFrame = hud:FindFirstChild("TimerFrame")
	if timerFrame then timerFrame.Visible = false end
	dungeonStartTime = nil

	-- Auto-hide after 7 seconds
	task.delay(7, function()
		if overlay then overlay.Visible = false end
	end)
end

function UIController.UpdateBossBar()
	local bossBar = hud:FindFirstChild("BossBar")
	if not bossBar then return end

	local dungeonFolder = workspace:FindFirstChild("Dungeon")
	if not dungeonFolder then
		bossBar.Visible = false
		return
	end

	-- Find boss
	local foundBoss = false
	for _, desc in ipairs(dungeonFolder:GetDescendants()) do
		if desc:IsA("Model") and desc:GetAttribute("IsBoss") and not desc:GetAttribute("IsDead") then
			foundBoss = true
			local currentHP = desc:GetAttribute("CurrentHP") or 0
			local maxHP = desc:GetAttribute("MaxHP") or 1
			local fill = bossBar:FindFirstChild("Fill")
			if fill then
				fill.Size = UDim2.new(math.clamp(currentHP / maxHP, 0, 1), 0, 1, 0)
			end
			local nameLabel = bossBar:FindFirstChild("BossName")
			if nameLabel then
				nameLabel.Text = desc.Name .. " - " .. math.floor(currentHP) .. "/" .. math.floor(maxHP)
			end
			bossBar.Visible = true
			break
		end
	end

	if not foundBoss then
		bossBar.Visible = false
	end
end

function UIController.ShowBossPhase(phaseName)
	UIController.ShowRoomNotification("BossPhase", 0, phaseName)
end

-- Key Inventory HUD: 5 key slots at top-center of screen
local KEY_DEFS = {
	{ Id = "Iron",    Name = "Iron Key",    Color = Color3.fromRGB(180, 180, 190) },
	{ Id = "Gold",    Name = "Gold Key",    Color = Color3.fromRGB(255, 215, 0) },
	{ Id = "Crimson", Name = "Crimson Key", Color = Color3.fromRGB(200, 30, 30) },
	{ Id = "Emerald", Name = "Emerald Key", Color = Color3.fromRGB(30, 200, 60) },
	{ Id = "Shadow",  Name = "Shadow Key",  Color = Color3.fromRGB(120, 50, 200) },
}

function UIController.CreateKeyInventoryHUD()
	-- Remove existing
	local existing = hud:FindFirstChild("KeyInventory")
	if existing then existing:Destroy() end

	local frame = Instance.new("Frame")
	frame.Name = "KeyInventory"
	frame.Size = UDim2.new(0, 300, 0, 50)
	frame.Position = UDim2.new(0.5, -150, 0, 55)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.Parent = hud

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = frame

	for _, keyDef in ipairs(KEY_DEFS) do
		local slot = Instance.new("Frame")
		slot.Name = "KeySlot_" .. keyDef.Id
		slot.Size = UDim2.new(0, 45, 0, 40)
		slot.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		slot.BackgroundTransparency = 0.5
		slot.BorderSizePixel = 0
		slot.Parent = frame

		local slotCorner = Instance.new("UICorner")
		slotCorner.CornerRadius = UDim.new(0, 6)
		slotCorner.Parent = slot

		-- Key icon (greyed out initially)
		local icon = Instance.new("TextLabel")
		icon.Name = "Icon"
		icon.Size = UDim2.new(1, 0, 0.6, 0)
		icon.BackgroundTransparency = 1
		icon.Text = "🔑"
		icon.TextScaled = true
		icon.TextTransparency = 0.7
		icon.TextColor3 = keyDef.Color
		icon.Parent = slot

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.new(1, 0, 0.4, 0)
		label.Position = UDim2.new(0, 0, 0.6, 0)
		label.BackgroundTransparency = 1
		label.Text = keyDef.Id
		label.TextColor3 = keyDef.Color
		label.TextTransparency = 0.7
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Parent = slot

		-- Border stroke (greyed out)
		local stroke = Instance.new("UIStroke")
		stroke.Name = "Border"
		stroke.Thickness = 2
		stroke.Color = keyDef.Color
		stroke.Transparency = 0.7
		stroke.Parent = slot
	end
end

function UIController.UpdateKeySlot(keyName, keyColorArr)
	local keyFrame = hud:FindFirstChild("KeyInventory")
	if not keyFrame then return end

	-- Find matching slot by name
	for _, keyDef in ipairs(KEY_DEFS) do
		if keyDef.Name == keyName then
			local slot = keyFrame:FindFirstChild("KeySlot_" .. keyDef.Id)
			if slot then
				-- Light up the slot
				slot.BackgroundColor3 = keyDef.Color
				slot.BackgroundTransparency = 0.2
				local icon = slot:FindFirstChild("Icon")
				if icon then icon.TextTransparency = 0 end
				local label = slot:FindFirstChild("Label")
				if label then label.TextTransparency = 0; label.TextColor3 = Color3.new(1,1,1) end
				local stroke = slot:FindFirstChild("Border")
				if stroke then stroke.Transparency = 0 end

				-- Flash effect
				local flash = TweenService:Create(slot, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 2, true), {
					BackgroundTransparency = 0,
				})
				flash:Play()
			end
			break
		end
	end
end

return UIController
