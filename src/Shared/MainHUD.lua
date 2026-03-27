local MainHUD = {}

function MainHUD.Create()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MainHUD"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- ===== HEALTH BAR (bottom-left) =====
	local healthFrame = Instance.new("Frame")
	healthFrame.Name = "HealthBar"
	healthFrame.Size = UDim2.new(0, 250, 0, 30)
	healthFrame.Position = UDim2.new(0, 20, 1, -80)
	healthFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	healthFrame.BorderSizePixel = 0
	healthFrame.Parent = screenGui

	local healthCorner = Instance.new("UICorner")
	healthCorner.CornerRadius = UDim.new(0, 6)
	healthCorner.Parent = healthFrame

	local healthFill = Instance.new("Frame")
	healthFill.Name = "Fill"
	healthFill.Size = UDim2.new(1, 0, 1, 0)
	healthFill.BackgroundColor3 = Color3.fromRGB(0, 200, 50)
	healthFill.BorderSizePixel = 0
	healthFill.Parent = healthFrame

	local healthFillCorner = Instance.new("UICorner")
	healthFillCorner.CornerRadius = UDim.new(0, 6)
	healthFillCorner.Parent = healthFill

	local healthText = Instance.new("TextLabel")
	healthText.Name = "Text"
	healthText.Size = UDim2.new(1, 0, 1, 0)
	healthText.BackgroundTransparency = 1
	healthText.Text = "100 / 100"
	healthText.TextColor3 = Color3.new(1, 1, 1)
	healthText.TextScaled = true
	healthText.Font = Enum.Font.GothamBold
	healthText.ZIndex = 2
	healthText.Parent = healthFrame

	local healthIcon = Instance.new("TextLabel")
	healthIcon.Name = "Icon"
	healthIcon.Size = UDim2.new(0, 25, 0, 25)
	healthIcon.Position = UDim2.new(0, 20, 1, -110)
	healthIcon.BackgroundTransparency = 1
	healthIcon.Text = "HP"
	healthIcon.TextColor3 = Color3.fromRGB(255, 80, 80)
	healthIcon.TextScaled = true
	healthIcon.Font = Enum.Font.GothamBold
	healthIcon.Parent = screenGui

	-- ===== MANA BAR (below health) =====
	local manaFrame = Instance.new("Frame")
	manaFrame.Name = "ManaBar"
	manaFrame.Size = UDim2.new(0, 250, 0, 22)
	manaFrame.Position = UDim2.new(0, 20, 1, -45)
	manaFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	manaFrame.BorderSizePixel = 0
	manaFrame.Parent = screenGui

	local manaCorner = Instance.new("UICorner")
	manaCorner.CornerRadius = UDim.new(0, 6)
	manaCorner.Parent = manaFrame

	local manaFill = Instance.new("Frame")
	manaFill.Name = "Fill"
	manaFill.Size = UDim2.new(1, 0, 1, 0)
	manaFill.BackgroundColor3 = Color3.fromRGB(50, 100, 255)
	manaFill.BorderSizePixel = 0
	manaFill.Parent = manaFrame

	local manaFillCorner = Instance.new("UICorner")
	manaFillCorner.CornerRadius = UDim.new(0, 6)
	manaFillCorner.Parent = manaFill

	local manaText = Instance.new("TextLabel")
	manaText.Name = "Text"
	manaText.Size = UDim2.new(1, 0, 1, 0)
	manaText.BackgroundTransparency = 1
	manaText.Text = "100 / 100"
	manaText.TextColor3 = Color3.new(1, 1, 1)
	manaText.TextScaled = true
	manaText.Font = Enum.Font.GothamBold
	manaText.ZIndex = 2
	manaText.Parent = manaFrame

	-- ===== SKILL BAR (bottom-center) =====
	local skillBar = Instance.new("Frame")
	skillBar.Name = "SkillBar"
	skillBar.Size = UDim2.new(0, 280, 0, 65)
	skillBar.Position = UDim2.new(0.5, -140, 1, -80)
	skillBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	skillBar.BackgroundTransparency = 0.3
	skillBar.BorderSizePixel = 0
	skillBar.Parent = screenGui

	local skillBarCorner = Instance.new("UICorner")
	skillBarCorner.CornerRadius = UDim.new(0, 8)
	skillBarCorner.Parent = skillBar

	local skillLayout = Instance.new("UIListLayout")
	skillLayout.FillDirection = Enum.FillDirection.Horizontal
	skillLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	skillLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	skillLayout.Padding = UDim.new(0, 8)
	skillLayout.Parent = skillBar

	local weaponNames = { "Sword", "Staff", "Wand", "Shield" }
	local weaponLabels = { "Iron Sword", "Fire Staff", "Heal Wand", "Shield" }
	local weaponColors = {
		Color3.fromRGB(200, 200, 200),
		Color3.fromRGB(255, 120, 30),
		Color3.fromRGB(50, 255, 100),
		Color3.fromRGB(50, 150, 255),
	}

	for i, name in ipairs(weaponNames) do
		local slot = Instance.new("Frame")
		slot.Name = "Skill" .. i
		slot.Size = UDim2.new(0, 58, 0, 58)
		slot.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		slot.BorderSizePixel = 0
		slot.LayoutOrder = i
		slot.Parent = skillBar

		local slotCorner = Instance.new("UICorner")
		slotCorner.CornerRadius = UDim.new(0, 6)
		slotCorner.Parent = slot

		local border = Instance.new("UIStroke")
		border.Name = "Border"
		border.Color = weaponColors[i]
		border.Thickness = 2
		border.Parent = slot

		-- Equipped indicator (bright glow behind slot)
		local equippedGlow = Instance.new("Frame")
		equippedGlow.Name = "EquippedGlow"
		equippedGlow.Size = UDim2.new(1, 6, 1, 6)
		equippedGlow.Position = UDim2.new(0.5, 0, 0.5, 0)
		equippedGlow.AnchorPoint = Vector2.new(0.5, 0.5)
		equippedGlow.BackgroundColor3 = weaponColors[i]
		equippedGlow.BackgroundTransparency = i == 1 and 0.5 or 1 -- first slot equipped by default
		equippedGlow.BorderSizePixel = 0
		equippedGlow.ZIndex = 0
		equippedGlow.Parent = slot

		local glowCorner = Instance.new("UICorner")
		glowCorner.CornerRadius = UDim.new(0, 8)
		glowCorner.Parent = equippedGlow

		local weaponLabel = Instance.new("TextLabel")
		weaponLabel.Name = "Label"
		weaponLabel.Size = UDim2.new(1, 0, 0.5, 0)
		weaponLabel.Position = UDim2.new(0, 0, 0.05, 0)
		weaponLabel.BackgroundTransparency = 1
		weaponLabel.Text = weaponLabels[i]
		weaponLabel.TextColor3 = weaponColors[i]
		weaponLabel.TextScaled = true
		weaponLabel.Font = Enum.Font.GothamBold
		weaponLabel.Parent = slot

		local keyLabel = Instance.new("TextLabel")
		keyLabel.Name = "Key"
		keyLabel.Size = UDim2.new(1, 0, 0.25, 0)
		keyLabel.Position = UDim2.new(0, 0, 0.55, 0)
		keyLabel.BackgroundTransparency = 1
		keyLabel.Text = "[" .. i .. "]"
		keyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		keyLabel.TextScaled = true
		keyLabel.Font = Enum.Font.Gotham
		keyLabel.Parent = slot

		-- "CLICK" hint for equipped weapon
		local clickHint = Instance.new("TextLabel")
		clickHint.Name = "ClickHint"
		clickHint.Size = UDim2.new(1, 0, 0.2, 0)
		clickHint.Position = UDim2.new(0, 0, 0.78, 0)
		clickHint.BackgroundTransparency = 1
		clickHint.Text = i == 1 and "CLICK" or ""
		clickHint.TextColor3 = Color3.fromRGB(255, 255, 100)
		clickHint.TextScaled = true
		clickHint.Font = Enum.Font.GothamBold
		clickHint.Parent = slot

		-- Cooldown overlay (fills from top down)
		local cooldownOverlay = Instance.new("Frame")
		cooldownOverlay.Name = "CooldownOverlay"
		cooldownOverlay.Size = UDim2.new(1, 0, 0, 0)
		cooldownOverlay.Position = UDim2.new(0, 0, 0, 0)
		cooldownOverlay.AnchorPoint = Vector2.new(0, 0)
		cooldownOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		cooldownOverlay.BackgroundTransparency = 0.4
		cooldownOverlay.BorderSizePixel = 0
		cooldownOverlay.ZIndex = 3
		cooldownOverlay.Parent = slot

		local cdCorner = Instance.new("UICorner")
		cdCorner.CornerRadius = UDim.new(0, 6)
		cdCorner.Parent = cooldownOverlay

		local cdText = Instance.new("TextLabel")
		cdText.Name = "CooldownText"
		cdText.Size = UDim2.new(1, 0, 1, 0)
		cdText.BackgroundTransparency = 1
		cdText.Text = ""
		cdText.TextColor3 = Color3.new(1, 1, 1)
		cdText.TextScaled = true
		cdText.Font = Enum.Font.GothamBold
		cdText.ZIndex = 4
		cdText.Parent = slot
	end

	-- ===== STAT PANEL (top-right, toggleable) =====
	local statPanel = Instance.new("Frame")
	statPanel.Name = "StatPanel"
	statPanel.Size = UDim2.new(0, 200, 0, 250)
	statPanel.Position = UDim2.new(1, -220, 0, 60)
	statPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	statPanel.BackgroundTransparency = 0.2
	statPanel.BorderSizePixel = 0
	statPanel.Visible = false
	statPanel.Parent = screenGui

	local statCorner = Instance.new("UICorner")
	statCorner.CornerRadius = UDim.new(0, 8)
	statCorner.Parent = statPanel

	local statTitle = Instance.new("TextLabel")
	statTitle.Name = "Title"
	statTitle.Size = UDim2.new(1, 0, 0, 30)
	statTitle.BackgroundTransparency = 1
	statTitle.Text = "STATS [TAB]"
	statTitle.TextColor3 = Color3.fromRGB(255, 200, 50)
	statTitle.TextScaled = true
	statTitle.Font = Enum.Font.GothamBold
	statTitle.Parent = statPanel

	local statNames = { "Health", "Mana", "Strength", "Defense", "Speed", "Crit Chance", "Crit Damage" }
	for i, statName in ipairs(statNames) do
		local label = Instance.new("TextLabel")
		label.Name = statName:gsub(" ", "")
		label.Size = UDim2.new(1, -20, 0, 28)
		label.Position = UDim2.new(0, 10, 0, 30 + (i - 1) * 30)
		label.BackgroundTransparency = 1
		label.Text = statName .. ": --"
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextScaled = true
		label.Font = Enum.Font.Gotham
		label.Parent = statPanel
	end

	-- ===== INVENTORY PANEL (left side, toggle with E) =====
	local invPanel = Instance.new("Frame")
	invPanel.Name = "InventoryPanel"
	invPanel.Size = UDim2.new(0, 250, 0, 350)
	invPanel.Position = UDim2.new(0, 20, 0.5, -175)
	invPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	invPanel.BackgroundTransparency = 0.15
	invPanel.BorderSizePixel = 0
	invPanel.Visible = false
	invPanel.Parent = screenGui

	local invCorner = Instance.new("UICorner")
	invCorner.CornerRadius = UDim.new(0, 8)
	invCorner.Parent = invPanel

	local invStroke = Instance.new("UIStroke")
	invStroke.Color = Color3.fromRGB(100, 80, 50)
	invStroke.Thickness = 2
	invStroke.Parent = invPanel

	local invTitle = Instance.new("TextLabel")
	invTitle.Name = "Title"
	invTitle.Size = UDim2.new(1, 0, 0, 35)
	invTitle.BackgroundTransparency = 1
	invTitle.Text = "INVENTORY [E]"
	invTitle.TextColor3 = Color3.fromRGB(255, 200, 50)
	invTitle.TextScaled = true
	invTitle.Font = Enum.Font.GothamBold
	invTitle.Parent = invPanel

	local invEmpty = Instance.new("TextLabel")
	invEmpty.Name = "EmptyText"
	invEmpty.Size = UDim2.new(1, -20, 0, 30)
	invEmpty.Position = UDim2.new(0, 10, 0, 40)
	invEmpty.BackgroundTransparency = 1
	invEmpty.Text = "No items yet. Kill enemies to get loot!"
	invEmpty.TextColor3 = Color3.fromRGB(150, 150, 150)
	invEmpty.TextScaled = true
	invEmpty.TextWrapped = true
	invEmpty.Font = Enum.Font.Gotham
	invEmpty.Parent = invPanel

	-- Scrolling frame for items
	local invScroll = Instance.new("ScrollingFrame")
	invScroll.Name = "ItemList"
	invScroll.Size = UDim2.new(1, -10, 1, -45)
	invScroll.Position = UDim2.new(0, 5, 0, 40)
	invScroll.BackgroundTransparency = 1
	invScroll.BorderSizePixel = 0
	invScroll.ScrollBarThickness = 4
	invScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	invScroll.Parent = invPanel

	local invListLayout = Instance.new("UIListLayout")
	invListLayout.FillDirection = Enum.FillDirection.Vertical
	invListLayout.Padding = UDim.new(0, 4)
	invListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	invListLayout.Parent = invScroll

	-- ===== DAMAGE FLASH (full screen) =====
	local damageFlash = Instance.new("Frame")
	damageFlash.Name = "DamageFlash"
	damageFlash.Size = UDim2.new(1, 0, 1, 0)
	damageFlash.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	damageFlash.BackgroundTransparency = 1
	damageFlash.BorderSizePixel = 0
	damageFlash.ZIndex = 10
	damageFlash.Parent = screenGui

	-- ===== NOTIFICATION AREA (right side) =====
	local notifications = Instance.new("Frame")
	notifications.Name = "Notifications"
	notifications.Size = UDim2.new(0, 300, 0, 400)
	notifications.Position = UDim2.new(1, -320, 0.5, -200)
	notifications.BackgroundTransparency = 1
	notifications.BorderSizePixel = 0
	notifications.Parent = screenGui

	local notifLayout = Instance.new("UIListLayout")
	notifLayout.FillDirection = Enum.FillDirection.Vertical
	notifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	notifLayout.Padding = UDim.new(0, 5)
	notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
	notifLayout.Parent = notifications

	-- ===== ROOM NOTIFICATION (center) =====
	local roomNotif = Instance.new("TextLabel")
	roomNotif.Name = "RoomNotification"
	roomNotif.Size = UDim2.new(0, 500, 0, 60)
	roomNotif.Position = UDim2.new(0.5, -250, 0.2, 0)
	roomNotif.BackgroundTransparency = 1
	roomNotif.Text = ""
	roomNotif.TextColor3 = Color3.fromRGB(255, 200, 50)
	roomNotif.TextScaled = true
	roomNotif.Font = Enum.Font.GothamBold
	roomNotif.TextTransparency = 1
	roomNotif.ZIndex = 5
	roomNotif.Parent = screenGui

	local roomStroke = Instance.new("UIStroke")
	roomStroke.Color = Color3.fromRGB(0, 0, 0)
	roomStroke.Thickness = 2
	roomStroke.Parent = roomNotif

	-- ===== DUNGEON TIMER (top-center) =====
	local timerFrame = Instance.new("Frame")
	timerFrame.Name = "TimerFrame"
	timerFrame.Size = UDim2.new(0, 130, 0, 38)
	timerFrame.Position = UDim2.new(0.5, -65, 0, 10)
	timerFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	timerFrame.BackgroundTransparency = 0.3
	timerFrame.BorderSizePixel = 0
	timerFrame.Visible = false
	timerFrame.Parent = screenGui

	local timerCorner = Instance.new("UICorner")
	timerCorner.CornerRadius = UDim.new(0, 8)
	timerCorner.Parent = timerFrame

	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "TimerText"
	timerLabel.Size = UDim2.new(1, 0, 1, 0)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text = "00:00"
	timerLabel.TextColor3 = Color3.new(1, 1, 1)
	timerLabel.TextScaled = true
	timerLabel.Font = Enum.Font.GothamBold
	timerLabel.Parent = timerFrame

	-- ===== DEATH OVERLAY =====
	local deathOverlay = Instance.new("Frame")
	deathOverlay.Name = "DeathOverlay"
	deathOverlay.Size = UDim2.new(1, 0, 1, 0)
	deathOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	deathOverlay.BackgroundTransparency = 0.3
	deathOverlay.BorderSizePixel = 0
	deathOverlay.Visible = false
	deathOverlay.ZIndex = 20
	deathOverlay.Parent = screenGui

	local deathText = Instance.new("TextLabel")
	deathText.Name = "DeathText"
	deathText.Size = UDim2.new(1, 0, 0.3, 0)
	deathText.Position = UDim2.new(0, 0, 0.25, 0)
	deathText.BackgroundTransparency = 1
	deathText.Text = "YOU DIED"
	deathText.TextColor3 = Color3.fromRGB(255, 50, 50)
	deathText.TextScaled = true
	deathText.Font = Enum.Font.GothamBold
	deathText.ZIndex = 21
	deathText.Parent = deathOverlay

	local deathStroke = Instance.new("UIStroke")
	deathStroke.Color = Color3.fromRGB(100, 0, 0)
	deathStroke.Thickness = 3
	deathStroke.Parent = deathText

	local reviveText = Instance.new("TextLabel")
	reviveText.Name = "ReviveText"
	reviveText.Size = UDim2.new(1, 0, 0.1, 0)
	reviveText.Position = UDim2.new(0, 0, 0.55, 0)
	reviveText.BackgroundTransparency = 1
	reviveText.Text = "Reviving in 3..."
	reviveText.TextColor3 = Color3.fromRGB(255, 200, 100)
	reviveText.TextScaled = true
	reviveText.Font = Enum.Font.Gotham
	reviveText.ZIndex = 21
	reviveText.Parent = deathOverlay

	local respawnBtn = Instance.new("TextButton")
	respawnBtn.Name = "RespawnButton"
	respawnBtn.Size = UDim2.new(0, 200, 0, 50)
	respawnBtn.Position = UDim2.new(0.5, -100, 0.68, 0)
	respawnBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
	respawnBtn.BackgroundTransparency = 0.2
	respawnBtn.Text = "RESPAWN"
	respawnBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	respawnBtn.TextScaled = true
	respawnBtn.Font = Enum.Font.GothamBold
	respawnBtn.ZIndex = 22
	respawnBtn.Visible = false
	respawnBtn.Parent = deathOverlay

	local respawnCorner = Instance.new("UICorner")
	respawnCorner.CornerRadius = UDim.new(0, 8)
	respawnCorner.Parent = respawnBtn

	local respawnStroke = Instance.new("UIStroke")
	respawnStroke.Color = Color3.fromRGB(100, 255, 100)
	respawnStroke.Thickness = 2
	respawnStroke.Parent = respawnBtn

	-- ===== CLASS INDICATOR (top-left) =====
	local classIndicator = Instance.new("Frame")
	classIndicator.Name = "ClassIndicator"
	classIndicator.Size = UDim2.new(0, 150, 0, 35)
	classIndicator.Position = UDim2.new(0, 20, 0, 10)
	classIndicator.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	classIndicator.BackgroundTransparency = 0.3
	classIndicator.BorderSizePixel = 0
	classIndicator.Visible = false
	classIndicator.Parent = screenGui

	local classCorner = Instance.new("UICorner")
	classCorner.CornerRadius = UDim.new(0, 8)
	classCorner.Parent = classIndicator

	local classLabel = Instance.new("TextLabel")
	classLabel.Name = "ClassLabel"
	classLabel.Size = UDim2.new(1, 0, 1, 0)
	classLabel.BackgroundTransparency = 1
	classLabel.Text = ""
	classLabel.TextColor3 = Color3.new(1, 1, 1)
	classLabel.TextScaled = true
	classLabel.Font = Enum.Font.GothamBold
	classLabel.Parent = classIndicator

	-- ===== SCORE OVERLAY =====
	local scoreOverlay = Instance.new("Frame")
	scoreOverlay.Name = "ScoreOverlay"
	scoreOverlay.Size = UDim2.new(0, 350, 0, 300)
	scoreOverlay.Position = UDim2.new(0.5, -175, 0.5, -150)
	scoreOverlay.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	scoreOverlay.BackgroundTransparency = 0.1
	scoreOverlay.BorderSizePixel = 0
	scoreOverlay.Visible = false
	scoreOverlay.ZIndex = 25
	scoreOverlay.Parent = screenGui

	local scoreCorner = Instance.new("UICorner")
	scoreCorner.CornerRadius = UDim.new(0, 12)
	scoreCorner.Parent = scoreOverlay

	local scoreStroke = Instance.new("UIStroke")
	scoreStroke.Color = Color3.fromRGB(255, 215, 0)
	scoreStroke.Thickness = 2
	scoreStroke.Parent = scoreOverlay

	local gradeLabel = Instance.new("TextLabel")
	gradeLabel.Name = "GradeLabel"
	gradeLabel.Size = UDim2.new(1, 0, 0, 80)
	gradeLabel.Position = UDim2.new(0, 0, 0, 10)
	gradeLabel.BackgroundTransparency = 1
	gradeLabel.Text = "S"
	gradeLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	gradeLabel.TextScaled = true
	gradeLabel.Font = Enum.Font.GothamBold
	gradeLabel.ZIndex = 26
	gradeLabel.Parent = scoreOverlay

	local scoreTitle = Instance.new("TextLabel")
	scoreTitle.Name = "ScoreTitle"
	scoreTitle.Size = UDim2.new(1, 0, 0, 30)
	scoreTitle.Position = UDim2.new(0, 0, 0, 90)
	scoreTitle.BackgroundTransparency = 1
	scoreTitle.Text = "DUNGEON COMPLETE"
	scoreTitle.TextColor3 = Color3.fromRGB(255, 200, 50)
	scoreTitle.TextScaled = true
	scoreTitle.Font = Enum.Font.GothamBold
	scoreTitle.ZIndex = 26
	scoreTitle.Parent = scoreOverlay

	local scoreLines = {"Time: --", "Damage: --", "Rooms: --", "Deaths: --", "Total: --"}
	for i, line in ipairs(scoreLines) do
		local lineLabel = Instance.new("TextLabel")
		lineLabel.Name = "ScoreLine" .. i
		lineLabel.Size = UDim2.new(1, -30, 0, 25)
		lineLabel.Position = UDim2.new(0, 15, 0, 125 + (i - 1) * 30)
		lineLabel.BackgroundTransparency = 1
		lineLabel.Text = line
		lineLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
		lineLabel.TextScaled = true
		lineLabel.TextXAlignment = Enum.TextXAlignment.Left
		lineLabel.Font = Enum.Font.Gotham
		lineLabel.ZIndex = 26
		lineLabel.Parent = scoreOverlay
	end

	-- ===== BOSS HP BAR (top-center) =====
	local bossBarFrame = Instance.new("Frame")
	bossBarFrame.Name = "BossBar"
	bossBarFrame.Size = UDim2.new(0.4, 0, 0, 35)
	bossBarFrame.Position = UDim2.new(0.3, 0, 0, 55)
	bossBarFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	bossBarFrame.BorderSizePixel = 0
	bossBarFrame.Visible = false
	bossBarFrame.ZIndex = 5
	bossBarFrame.Parent = screenGui

	local bossBarCorner = Instance.new("UICorner")
	bossBarCorner.CornerRadius = UDim.new(0, 6)
	bossBarCorner.Parent = bossBarFrame

	local bossBarFill = Instance.new("Frame")
	bossBarFill.Name = "Fill"
	bossBarFill.Size = UDim2.new(1, 0, 1, 0)
	bossBarFill.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
	bossBarFill.BorderSizePixel = 0
	bossBarFill.ZIndex = 6
	bossBarFill.Parent = bossBarFrame

	local bossBarFillCorner = Instance.new("UICorner")
	bossBarFillCorner.CornerRadius = UDim.new(0, 6)
	bossBarFillCorner.Parent = bossBarFill

	local bossNameLabel = Instance.new("TextLabel")
	bossNameLabel.Name = "BossName"
	bossNameLabel.Size = UDim2.new(1, 0, 1, 0)
	bossNameLabel.BackgroundTransparency = 1
	bossNameLabel.Text = "BOSS"
	bossNameLabel.TextColor3 = Color3.new(1, 1, 1)
	bossNameLabel.TextScaled = true
	bossNameLabel.Font = Enum.Font.GothamBold
	bossNameLabel.ZIndex = 7
	bossNameLabel.Parent = bossBarFrame

	return screenGui
end

return MainHUD
