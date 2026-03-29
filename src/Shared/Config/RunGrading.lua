local RunGrading = {}

RunGrading.TimeBonus = 300 -- base score, lose points per second
RunGrading.DamagePerPoint = 50 -- every 50 damage = 1 point
RunGrading.ChamberClearBonus = 100 -- per chamber cleared
RunGrading.DeathPenalty = -150 -- per death (SoulToken lost)
RunGrading.PuzzleBonus = 200 -- per puzzle shrine solved

RunGrading.Grades = {
	{ Grade = "S", MinScore = 1200, Color = Color3.fromRGB(255, 215, 0) },
	{ Grade = "A", MinScore = 900, Color = Color3.fromRGB(50, 255, 50) },
	{ Grade = "B", MinScore = 600, Color = Color3.fromRGB(50, 150, 255) },
	{ Grade = "C", MinScore = 300, Color = Color3.fromRGB(200, 200, 200) },
	{ Grade = "D", MinScore = 0, Color = Color3.fromRGB(255, 50, 50) },
}

return RunGrading
