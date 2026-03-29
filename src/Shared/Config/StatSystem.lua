local StatSystem = {}

StatSystem.BaseStats = {
	MaxHP = 100,
	Mana = 100,
	Strength = 10,
	Defense = 5,
	Speed = 16,
	CritChance = 0.05,
	CritDamage = 1.5,
	Arcana = 0,
}

StatSystem.ManaRegenPerSecond = 5

function StatSystem.CalculateDamage(attackerStrength, skillMultiplier, targetDefense, critChance, critDamage)
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

return StatSystem
