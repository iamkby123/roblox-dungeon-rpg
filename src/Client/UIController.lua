local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SkillConfig"))
local PotionConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("PotionConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local UIController = {}

local hud -- the ScreenGui
local SkillController -- for cooldown display
local currentStats = nil
local descentStartTime = nil
local shopOpen = false
local potionSlotData = {} -- [1-4] = { inventoryIndex = n, item = {...} } or nil
local currentInventory = {} -- latest inventory from server

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
	local dungeonRemote = Remotes:GetEvent("DescentStateChanged")
	if dungeonRemote then
		dungeonRemote.OnClientEvent:Connect(function(eventType, roomIndex, roomName, sealColor)
			UIController.ShowRoomNotification(eventType, roomIndex, roomName, sealColor)
			if eventType == "DescentStarted" then
				descentStartTime = os.clock()
				local timerFrame = hud:FindFirstChild("TimerFrame")
				if timerFrame then timerFrame.Visible = true end
				-- Show key inventory HUD
				UIController.CreateSealInventoryHUD()
			elseif eventType == "DescentComplete" then
				descentStartTime = nil
				-- Hide key inventory
				local keyHud = hud:FindFirstChild("SealInventory")
				if keyHud then keyHud.Visible = false end
			elseif eventType == "KeyPickedUp" then
				-- Light up the collected key in the HUD
				UIController.UpdateKeySlot(roomName, sealColor) -- roomName = key name, sealColor = {R,G,B}
			end
		end)
	end

	-- Listen for death/revive
	local diedRemote = Remotes:GetEvent("FallenState")
	if diedRemote then
		diedRemote.OnClientEvent:Connect(function(deathCount, respawnTime)
			UIController.ShowDeathOverlay(deathCount, respawnTime or 5)
		end)
	end

	local revivedRemote = Remotes:GetEvent("RevivePlayer")
	if revivedRemote then
		revivedRemote.OnClientEvent:Connect(function()
			UIController.HideDeathOverlay()
		end)
	end

	-- Listen for vocation selection
	local vocationRemote = Remotes:GetEvent("VocationSelected")
	if vocationRemote then
		vocationRemote.OnClientEvent:Connect(function(vocationId)
			UIController.ShowVocationIndicator(vocationId)
		end)
	end

	-- Listen for descent score
	local scoreRemote = Remotes:GetEvent("DescentScore")
	if scoreRemote then
		scoreRemote.OnClientEvent:Connect(function(scoreData)
			UIController.ShowScoreOverlay(scoreData)
		end)
	end

	-- Listen for Catacombs XP updates (XP bar at bottom of screen)
	local xpSyncRemote = Remotes:GetEvent("DelverXPSync")
	if xpSyncRemote then
		xpSyncRemote.OnClientEvent:Connect(function(data)
			UIController.UpdateXPBar(data)
		end)
	end

	-- Listen for level-up (full-screen overlay)
	local levelUpRemote = Remotes:GetEvent("RankUp")
	if levelUpRemote then
		levelUpRemote.OnClientEvent:Connect(function(data)
			UIController.ShowLevelUpOverlay(data)
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
			currentInventory = inventory
			UIController.UpdateInventoryPanel(inventory)
			UIController.UpdatePotionHotbar(inventory)
		end)
	end

	-- Wire potion hotbar click handlers
	task.defer(function()
		local potionBar = hud:FindFirstChild("PotionBar")
		if potionBar then
			for i = 1, 4 do
				local slot = potionBar:FindFirstChild("Potion" .. i)
				if slot then
					local slotIndex = i
					slot.MouseButton1Click:Connect(function()
						UIController.UsePotionSlot(slotIndex)
					end)
				end
			end
		end
	end)

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

	-- Listen for coin updates
	local coinsRemote = Remotes:GetEvent("CoinsUpdated")
	if coinsRemote then
		coinsRemote.OnClientEvent:Connect(function(coins)
			UIController.UpdateCoinDisplay(coins)
			-- Also update shop panel coin display if open
			local shopPanel = hud:FindFirstChild("PotionShopPanel")
			if shopPanel then
				local coinLabel = shopPanel:FindFirstChild("ShopCoins")
				if coinLabel then
					coinLabel.Text = "Coins: " .. tostring(coins)
				end
			end
		end)
	end

	-- Listen for potion shop open
	local shopRemote = Remotes:GetEvent("OpenPotionShop")
	if shopRemote then
		shopRemote.OnClientEvent:Connect(function()
			local panel = hud:FindFirstChild("PotionShopPanel")
			if not panel then
				UIController.CreatePotionShopUI()
				panel = hud:FindFirstChild("PotionShopPanel")
			end
			if panel then
				panel.Visible = not panel.Visible
				UIController.SetShopMouseFree(panel.Visible)
			end
		end)
	end

	-- Update loop for health, mana, and cooldowns
	RunService.RenderStepped:Connect(function()
		UIController.UpdateHealthBar()
		UIController.UpdateManaBar()
		UIController.UpdateSkillCooldowns()
		UIController.UpdateTimer()
		UIController.UpdateBossBar()

		-- Force mouse free every frame while shop is open (camera script fights back)
		if shopOpen then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
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

	local usePotionRemote = Remotes:GetFunction("UsePotion")

	for i, item in ipairs(inventory) do
		local isPotion = item.Type == "Potion"

		local itemFrame = Instance.new("TextButton")
		itemFrame.Name = "Item_" .. i
		itemFrame.Size = UDim2.new(1, -8, 0, isPotion and 58 or 45)
		itemFrame.BackgroundColor3 = isPotion and Color3.fromRGB(30, 25, 40) or Color3.fromRGB(35, 35, 45)
		itemFrame.BorderSizePixel = 0
		itemFrame.LayoutOrder = i
		itemFrame.Text = ""
		itemFrame.AutoButtonColor = false
		itemFrame.Parent = itemList

		local itemCorner = Instance.new("UICorner")
		itemCorner.CornerRadius = UDim.new(0, 4)
		itemCorner.Parent = itemFrame

		if isPotion then
			-- Potion item
			local potionColor = Color3.fromRGB(item.Color[1] or 255, item.Color[2] or 255, item.Color[3] or 255)

			local itemBorder = Instance.new("UIStroke")
			itemBorder.Color = potionColor
			itemBorder.Thickness = 1
			itemBorder.Transparency = 0.3
			itemBorder.Parent = itemFrame

			-- Color icon
			local icon = Instance.new("Frame")
			icon.Size = UDim2.new(0, 18, 0, 24)
			icon.Position = UDim2.new(0, 6, 0, 6)
			icon.BackgroundColor3 = potionColor
			icon.BorderSizePixel = 0
			icon.Parent = itemFrame

			local iconCorner = Instance.new("UICorner")
			iconCorner.CornerRadius = UDim.new(0, 3)
			iconCorner.Parent = icon

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(1, -35, 0, 18)
			nameLabel.Position = UDim2.new(0, 30, 0, 2)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = item.Name
			nameLabel.TextColor3 = potionColor
			nameLabel.TextScaled = true
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.Parent = itemFrame

			local descLabel = Instance.new("TextLabel")
			descLabel.Size = UDim2.new(1, -35, 0, 14)
			descLabel.Position = UDim2.new(0, 30, 0, 20)
			descLabel.BackgroundTransparency = 1
			descLabel.Text = item.Description or ""
			descLabel.TextColor3 = Color3.fromRGB(170, 170, 170)
			descLabel.TextScaled = true
			descLabel.TextXAlignment = Enum.TextXAlignment.Left
			descLabel.Font = Enum.Font.Gotham
			descLabel.Parent = itemFrame

			local hintLabel = Instance.new("TextLabel")
			hintLabel.Size = UDim2.new(1, -10, 0, 14)
			hintLabel.Position = UDim2.new(0, 5, 0, 38)
			hintLabel.BackgroundTransparency = 1
			hintLabel.Text = "(Right-click to use)"
			hintLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
			hintLabel.TextScaled = true
			hintLabel.TextXAlignment = Enum.TextXAlignment.Left
			hintLabel.Font = Enum.Font.Gotham
			hintLabel.Parent = itemFrame

			-- Right-click to use potion
			local inventoryIndex = i
			itemFrame.MouseButton2Click:Connect(function()
				if usePotionRemote then
					local result = usePotionRemote:InvokeServer(inventoryIndex)
					if result and result.success then
						-- Brief flash feedback
						itemFrame.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
						task.delay(0.3, function()
							if itemFrame.Parent then
								itemFrame.BackgroundColor3 = Color3.fromRGB(30, 25, 40)
							end
						end)
					end
				end
			end)
		else
			-- Regular equipment item
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
			if item.StatBoosts then
				for stat, value in pairs(item.StatBoosts) do
					if stat == "CritChance" or stat == "CritDamage" then
						table.insert(boostParts, "+" .. math.floor(value * 100) .. "% " .. stat)
					else
						table.insert(boostParts, "+" .. value .. " " .. stat)
					end
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
	end

	-- Calculate canvas size (potions are taller)
	local totalHeight = 0
	for _, item in ipairs(inventory) do
		totalHeight = totalHeight + (item.Type == "Potion" and 62 or 49)
	end

	itemList.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
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

function UIController.ShowRoomNotification(eventType, roomIndex, roomName, sealColor)
	local roomNotif = hud:FindFirstChild("RoomNotification")
	if not roomNotif then return end

	local text = ""
	local color = Color3.fromRGB(255, 200, 50)

	if eventType == "DescentStarted" then
		text = "Entering: " .. (roomName or "Room " .. roomIndex)
		color = Color3.fromRGB(100, 200, 255)
	elseif eventType == "RoomCleared" then
		text = "Room Cleared! " .. (roomName or "Room " .. roomIndex)
		color = Color3.fromRGB(50, 255, 50)
	elseif eventType == "DescentComplete" then
		text = "DESCENT COMPLETE!"
		color = Color3.fromRGB(255, 200, 50)
	elseif eventType == "KeySpawned" then
		local sealName = roomName or "A Key"
		text = sealName .. " dropped! Walk over it to pick up!"
		if sealColor and type(sealColor) == "table" then
			color = Color3.new(sealColor[1], sealColor[2], sealColor[3])
		else
			color = Color3.fromRGB(255, 220, 50)
		end
	elseif eventType == "KeyPickedUp" then
		local sealName = roomName or "Key"
		-- Add directional hint based on key type
		local hint = "Press E at the matching door to open it!"
		if sealName == "Iron Key" then
			hint = "Press E at the Iron Door (left branch)!"
		elseif sealName == "Gold Key" then
			hint = "Press E at the Gold Door (right branch)!"
		elseif sealName == "Crimson Key" then
			hint = "Press E at the Crimson Door to go deeper!"
		elseif sealName == "Emerald Key" then
			hint = "Press E at the Emerald Door to go deeper!"
		elseif sealName == "Shadow Key" then
			hint = "Collect both Shadow Keys to reach the BOSS!"
		end
		text = sealName .. " collected! " .. hint
		if sealColor and type(sealColor) == "table" then
			color = Color3.new(sealColor[1], sealColor[2], sealColor[3])
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

	-- Also show the stroke on fade-in
	local stroke = roomNotif:FindFirstChildWhichIsA("UIStroke")
	if stroke then stroke.Transparency = 0 end

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
		-- Fade the outline stroke too so it doesn't linger
		local s = roomNotif:FindFirstChildWhichIsA("UIStroke")
		if s then
			TweenService:Create(s, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end
	end)
end

function UIController.UpdateTimer()
	if not descentStartTime then return end
	local timerFrame = hud:FindFirstChild("TimerFrame")
	if not timerFrame then return end
	local timerText = timerFrame:FindFirstChild("TimerText")
	if not timerText then return end
	local elapsed = os.clock() - descentStartTime
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

function UIController.ShowVocationIndicator(vocationId)
	local indicator = hud:FindFirstChild("VocationIndicator")
	if not indicator then return end
	local label = indicator:FindFirstChild("VocationLabel")
	if label then
		label.Text = vocationId:upper()
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
	descentStartTime = nil

	-- Auto-hide after 7 seconds
	task.delay(7, function()
		if overlay then overlay.Visible = false end
	end)
end

function UIController.UpdateBossBar()
	local bossBar = hud:FindFirstChild("BossBar")
	if not bossBar then return end

	local dungeonFolder = workspace:FindFirstChild("ActiveHollow")
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

function UIController.CreateSealInventoryHUD()
	-- Remove existing
	local existing = hud:FindFirstChild("SealInventory")
	if existing then existing:Destroy() end

	local frame = Instance.new("Frame")
	frame.Name = "SealInventory"
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

function UIController.UpdateKeySlot(sealName, sealColorArr)
	local keyFrame = hud:FindFirstChild("SealInventory")
	if not keyFrame then return end

	-- Find matching slot by name
	for _, keyDef in ipairs(KEY_DEFS) do
		if keyDef.Name == sealName then
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

--------------------------------------------------------------------------------
-- CATACOMBS XP BAR (bottom-center, created lazily on first XP sync)
--------------------------------------------------------------------------------
function UIController.UpdateXPBar(data)
	local xpBar = hud:FindFirstChild("XPBar")
	if not xpBar then
		xpBar = Instance.new("Frame")
		xpBar.Name = "XPBar"
		xpBar.Size = UDim2.new(0.4, 0, 0, 16)
		xpBar.Position = UDim2.new(0.3, 0, 1, -20)
		xpBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
		xpBar.BorderSizePixel = 0
		xpBar.Parent = hud

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = xpBar

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.new(0, 0, 1, 0)
		fill.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
		fill.BorderSizePixel = 0
		fill.Parent = xpBar

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0, 4)
		fillCorner.Parent = fill

		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.ZIndex = 2
		label.Parent = xpBar

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(60, 60, 80)
		stroke.Thickness = 1
		stroke.Parent = xpBar
	end

	local fill = xpBar:FindFirstChild("Fill")
	local label = xpBar:FindFirstChild("Text")
	local fraction = data.XPRequired > 0 and data.XP / data.XPRequired or 0

	if fill then
		TweenService:Create(fill, TweenInfo.new(0.3), {
			Size = UDim2.new(math.clamp(fraction, 0, 1), 0, 1, 0),
		}):Play()
	end
	if label then
		label.Text = "Lv." .. data.Rank .. "  " .. data.XP .. " / " .. data.XPRequired .. " XP"
	end
end

--------------------------------------------------------------------------------
-- CATACOMBS LEVEL-UP OVERLAY
--------------------------------------------------------------------------------
function UIController.ShowLevelUpOverlay(data)
	local overlay = Instance.new("Frame")
	overlay.Name = "LevelUpOverlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	overlay.BackgroundTransparency = 0.85
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 10
	overlay.Parent = hud

	local function makeLabel(text, color, size, posY, fontSize)
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(size, 0, 0, fontSize or 50)
		lbl.Position = UDim2.new((1 - size) / 2, 0, 0, posY)
		lbl.BackgroundTransparency = 1
		lbl.Text = text
		lbl.TextColor3 = color
		lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		lbl.TextStrokeTransparency = 0
		lbl.TextScaled = true
		lbl.Font = Enum.Font.GothamBold
		lbl.ZIndex = 11
		lbl.Parent = overlay
		return lbl
	end

	local screenH = hud.AbsoluteSize.Y
	local midY = screenH * 0.3

	makeLabel("LEVEL UP!",  Color3.fromRGB(255, 215, 0), 0.5, midY)
	makeLabel("Level " .. data.Rank, Color3.new(1, 1, 1), 0.35, midY + 60, 40)

	local bonuses = data.Bonuses or { Health = 5, Defense = 2, Strength = 2 }
	makeLabel(
		string.format("+%d HP   +%d DEF   +%d STR", bonuses.Health, bonuses.Defense, bonuses.Strength),
		Color3.fromRGB(150, 255, 150), 0.5, midY + 110, 30
	)

	-- Flash in, hold, fade out
	TweenService:Create(overlay, TweenInfo.new(0.15), { BackgroundTransparency = 0.7 }):Play()

	task.delay(2.5, function()
		if not overlay or not overlay.Parent then return end
		TweenService:Create(overlay, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
		for _, child in ipairs(overlay:GetDescendants()) do
			if child:IsA("TextLabel") then
				TweenService:Create(child, TweenInfo.new(0.8), {
					TextTransparency = 1, TextStrokeTransparency = 1,
				}):Play()
			end
		end
		task.delay(0.8, function()
			if overlay and overlay.Parent then overlay:Destroy() end
		end)
	end)
end

-- ===== COIN DISPLAY =====

function UIController.UpdateCoinDisplay(coins)
	local coinDisplay = hud:FindFirstChild("CoinDisplay")
	if coinDisplay then
		local text = coinDisplay:FindFirstChild("Text")
		if text then
			text.Text = "Coins: " .. tostring(coins)
		end
	end
end

-- ===== POTION SHOP UI =====

function UIController.CreatePotionShopUI()
	local panel = Instance.new("Frame")
	panel.Name = "PotionShopPanel"
	panel.Size = UDim2.new(0, 320, 0, 400)
	panel.Position = UDim2.new(0.5, -160, 0.5, -200)
	panel.BackgroundColor3 = Color3.fromRGB(20, 15, 30)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 15
	panel.Parent = hud

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(180, 100, 255)
	stroke.Thickness = 2
	stroke.Parent = panel

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Text = "POTION STAND"
	title.TextColor3 = Color3.fromRGB(180, 100, 255)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.ZIndex = 16
	title.Parent = panel

	-- Coin balance
	local coinLabel = Instance.new("TextLabel")
	coinLabel.Name = "ShopCoins"
	coinLabel.Size = UDim2.new(1, -20, 0, 25)
	coinLabel.Position = UDim2.new(0, 10, 0, 40)
	coinLabel.BackgroundTransparency = 1
	coinLabel.Text = "Coins: 100"
	coinLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	coinLabel.TextScaled = true
	coinLabel.TextXAlignment = Enum.TextXAlignment.Left
	coinLabel.Font = Enum.Font.GothamBold
	coinLabel.ZIndex = 16
	coinLabel.Parent = panel

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 30, 0, 30)
	closeBtn.Position = UDim2.new(1, -35, 0, 5)
	closeBtn.BackgroundColor3 = Color3.fromRGB(150, 30, 30)
	closeBtn.BackgroundTransparency = 0.3
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.ZIndex = 17
	closeBtn.Parent = panel

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 6)
	closeBtnCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		panel.Visible = false
		UIController.SetShopMouseFree(false)
	end)

	-- Potion rows
	local buyPotionRemote = Remotes:GetFunction("BuyPotion")
	local yOffset = 75

	for _, potionId in ipairs(PotionConfig.DisplayOrder) do
		local potionData = PotionConfig.Potions[potionId]

		local row = Instance.new("Frame")
		row.Name = potionId
		row.Size = UDim2.new(1, -20, 0, 70)
		row.Position = UDim2.new(0, 10, 0, yOffset)
		row.BackgroundColor3 = Color3.fromRGB(35, 30, 45)
		row.BackgroundTransparency = 0.3
		row.BorderSizePixel = 0
		row.ZIndex = 16
		row.Parent = panel

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 6)
		rowCorner.Parent = row

		-- Color icon
		local icon = Instance.new("Frame")
		icon.Size = UDim2.new(0, 30, 0, 40)
		icon.Position = UDim2.new(0, 8, 0.5, -20)
		icon.BackgroundColor3 = potionData.Color
		icon.BorderSizePixel = 0
		icon.ZIndex = 17
		icon.Parent = row

		local iconCorner = Instance.new("UICorner")
		iconCorner.CornerRadius = UDim.new(0, 4)
		iconCorner.Parent = icon

		-- Name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0, 140, 0, 22)
		nameLabel.Position = UDim2.new(0, 48, 0, 8)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = potionData.Name
		nameLabel.TextColor3 = potionData.Color
		nameLabel.TextScaled = true
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.ZIndex = 17
		nameLabel.Parent = row

		-- Description
		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(0, 140, 0, 18)
		descLabel.Position = UDim2.new(0, 48, 0, 30)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = potionData.Description
		descLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
		descLabel.TextScaled = true
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.Font = Enum.Font.Gotham
		descLabel.ZIndex = 17
		descLabel.Parent = row

		-- Cost label
		local costLabel = Instance.new("TextLabel")
		costLabel.Size = UDim2.new(0, 50, 0, 16)
		costLabel.Position = UDim2.new(0, 48, 0, 50)
		costLabel.BackgroundTransparency = 1
		costLabel.Text = potionData.Cost .. " coins"
		costLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		costLabel.TextScaled = true
		costLabel.TextXAlignment = Enum.TextXAlignment.Left
		costLabel.Font = Enum.Font.Gotham
		costLabel.ZIndex = 17
		costLabel.Parent = row

		-- Buy button
		local buyBtn = Instance.new("TextButton")
		buyBtn.Name = "BuyBtn"
		buyBtn.Size = UDim2.new(0, 65, 0, 35)
		buyBtn.Position = UDim2.new(1, -75, 0.5, -17)
		buyBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 50)
		buyBtn.BackgroundTransparency = 0.15
		buyBtn.Text = "BUY"
		buyBtn.TextColor3 = Color3.new(1, 1, 1)
		buyBtn.TextScaled = true
		buyBtn.Font = Enum.Font.GothamBold
		buyBtn.ZIndex = 17
		buyBtn.Parent = row

		local buyBtnCorner = Instance.new("UICorner")
		buyBtnCorner.CornerRadius = UDim.new(0, 6)
		buyBtnCorner.Parent = buyBtn

		buyBtn.MouseButton1Click:Connect(function()
			if buyPotionRemote then
				local result = buyPotionRemote:InvokeServer(potionId)
				if result and result.success then
					-- Flash green briefly
					buyBtn.BackgroundColor3 = Color3.fromRGB(80, 255, 100)
					buyBtn.Text = "USED!"
					task.delay(0.5, function()
						buyBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 50)
						buyBtn.Text = "BUY"
					end)
				else
					-- Flash red
					buyBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
					buyBtn.Text = "NO $"
					task.delay(0.5, function()
						buyBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 50)
						buyBtn.Text = "BUY"
					end)
				end
			end
		end)

		yOffset = yOffset + 78
	end
end

-- ===== POTION HOTBAR =====

function UIController.UpdatePotionHotbar(inventory)
	local potionBar = hud:FindFirstChild("PotionBar")
	if not potionBar then return end

	-- Gather potions from inventory with their indices
	local potions = {}
	for i, item in ipairs(inventory) do
		if item.Type == "Potion" then
			table.insert(potions, { inventoryIndex = i, item = item })
		end
	end

	-- Assign first 4 potions to hotbar slots
	for i = 1, 4 do
		local slot = potionBar:FindFirstChild("Potion" .. i)
		if not slot then continue end

		local icon = slot:FindFirstChild("Icon")
		local label = slot:FindFirstChild("Label")
		local border = slot:FindFirstChild("Border")
		local keyLabel = slot:FindFirstChild("Key")

		local potionEntry = potions[i]

		if potionEntry then
			potionSlotData[i] = potionEntry
			local item = potionEntry.item
			local color = Color3.fromRGB(item.Color[1] or 255, item.Color[2] or 255, item.Color[3] or 255)

			if icon then
				icon.BackgroundColor3 = color
				icon.BackgroundTransparency = 0
			end
			if label then
				-- Short name (e.g., "Health" from "Health Potion")
				local shortName = string.gsub(item.Name, " Potion", "")
				label.Text = shortName
				label.TextColor3 = color
			end
			if border then
				border.Color = color
				border.Thickness = 2
			end
			if keyLabel then
				keyLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
			end
			slot.BackgroundColor3 = Color3.fromRGB(35, 30, 48)
		else
			-- Empty slot
			potionSlotData[i] = nil

			if icon then
				icon.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
				icon.BackgroundTransparency = 0.6
			end
			if label then
				label.Text = ""
				label.TextColor3 = Color3.fromRGB(150, 150, 150)
			end
			if border then
				border.Color = Color3.fromRGB(80, 70, 100)
				border.Thickness = 1
			end
			if keyLabel then
				keyLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
			end
			slot.BackgroundColor3 = Color3.fromRGB(40, 35, 50)
		end
	end
end

function UIController.UsePotionSlot(slotIndex)
	local data = potionSlotData[slotIndex]
	if not data then return end

	local usePotionRemote = Remotes:GetFunction("UsePotion")
	if not usePotionRemote then return end

	local result = usePotionRemote:InvokeServer(data.inventoryIndex)
	if result and result.success then
		-- Flash the slot green briefly
		local potionBar = hud:FindFirstChild("PotionBar")
		if potionBar then
			local slot = potionBar:FindFirstChild("Potion" .. slotIndex)
			if slot then
				slot.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
				task.delay(0.3, function()
					if slot.Parent then
						slot.BackgroundColor3 = Color3.fromRGB(40, 35, 50)
					end
				end)
			end
		end
		-- Inventory update will come from server via InventoryUpdated remote
	end
end

-- ===== SHOP MOUSE UNLOCK =====

function UIController.SetShopMouseFree(free)
	local player = Players.LocalPlayer
	shopOpen = free
	if free then
		-- Must leave LockFirstPerson AND allow zoom so camera releases the mouse
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 10
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	else
		-- Restore first-person lock
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 0.5
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	end
end

return UIController
