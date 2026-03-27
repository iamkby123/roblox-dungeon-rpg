local StatConfig = {}

StatConfig.BaseStats = {
	Health = 100,
	Mana = 100,
	Strength = 10,
	Defense = 5,
	Speed = 16,
	CritChance = 0.05,
	CritDamage = 1.5,
}

StatConfig.ManaRegenPerSecond = 5

function StatConfig.CalculateDamage(attackerStrength, skillMultiplier, targetDefense, critChance, critDamage)
	local baseDamage = attackerStrength * (1 + skillMultiplier)
	local reduction = targetDefense / (targetDefense + 100)
	local finalDamage = baseDamage * (1 - reduction)

	local isCrit = false
	if math.random() < critChance then
		finalDamage = finalDamage * critDamage
		isCrit = true
	end

	return math.floor(finalDamage), isCrit
end

return StatConfig
