local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local PotionConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("PotionConfig"))

local PotionShopService = {}

local DataService -- reference to DelverDataService

function PotionShopService.Init(delverDataService)
	DataService = delverDataService

	local buyPotionRemote = Remotes:GetFunction("BuyPotion")
	if buyPotionRemote then
		buyPotionRemote.OnServerInvoke = function(player, potionId)
			return PotionShopService.HandlePurchase(player, potionId)
		end
	end
end

function PotionShopService.HandlePurchase(player, potionId)
	-- Validate potion exists
	local potionData = PotionConfig.Potions[potionId]
	if not potionData then
		return { success = false, reason = "Invalid potion" }
	end

	-- Check and deduct coins
	local cost = potionData.Cost
	if not DataService.SpendCoins(player, cost) then
		return { success = false, reason = "Not enough coins" }
	end

	-- Add potion to inventory (player uses it later via right-click)
	DataService.AddPotionToInventory(player, potionId)

	return { success = true, potionId = potionId, potionName = potionData.Name }
end

return PotionShopService
