local ScoreConfig = {}

ScoreConfig.TimeBonus = 300 -- base score, lose points per second
ScoreConfig.DamagePerPoint = 50 -- every 50 damage = 1 point
ScoreConfig.RoomClearBonus = 100 -- per room cleared
ScoreConfig.DeathPenalty = -150 -- per death
ScoreConfig.PuzzleBonus = 200 -- per puzzle room solved

ScoreConfig.Grades = {
	{ Grade = "S", MinScore = 1200, Color = Color3.fromRGB(255, 215, 0) },
	{ Grade = "A", MinScore = 900, Color = Color3.fromRGB(50, 255, 50) },
	{ Grade = "B", MinScore = 600, Color = Color3.fromRGB(50, 150, 255) },
	{ Grade = "C", MinScore = 300, Color = Color3.fromRGB(200, 200, 200) },
	{ Grade = "D", MinScore = 0, Color = Color3.fromRGB(255, 50, 50) },
}

return ScoreConfig
