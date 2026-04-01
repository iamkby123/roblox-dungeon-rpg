local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ItemConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local PotionShopService = {}

local DelverDataService -- set via Init

function PotionShopService.Init(delverDataSvc)
	DelverDataService = delverDataSvc

	-- Handle shop purchase requests from clients
	local shopRemote = Remotes:GetEvent("ShopPurchase")
	if shopRemote then
		shopRemote.OnServerEvent:Connect(function(player, potionId)
			PotionShopService.HandlePurchase(player, potionId)
		end)
	end

	-- Handle potion use requests from clients
	local useRemote = Remotes:GetEvent("UsePotion")
	if useRemote then
		useRemote.OnServerEvent:Connect(function(player, potionId)
			DelverDataService.UsePotion(player, potionId)
		end)
	end
end

function PotionShopService.HandlePurchase(player, potionId)
	local potionData = ItemConfig.Potions[potionId]
	if not potionData then
		warn("[PotionShop] Unknown potion: " .. tostring(potionId))
		return
	end

	local price = potionData.Price
	if not DelverDataService.SpendCoins(player, price) then
		-- Not enough coins — client should have checked, but server validates
		return
	end

	DelverDataService.AddPotion(player, potionId)
end

return PotionShopService
