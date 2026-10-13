--!strict
local Constants = {
	CollisionGroups = {
		Default = "Default",
		Players = "Players",
		Debris = "Debris",
		Destructibles = "Destructibles",
	},
	Tags = {
		Destructible = "Destructible",
		Debris = "Debris",
		VillageStructure = "VillageStructure",
	},
	Remotes = {
		RequestAttack = "RequestAttack",
		DamageDealt = "DamageDealt",
		CurrencyChanged = "CurrencyChanged",
		BuyItem = "BuyItem",
		EquipItem = "EquipItem",
		SyncInventory = "SyncInventory",
		PlayDestructionFX = "PlayDestructionFX",
		NotifyMessage = "NotifyMessage",
		CheckGamePass = "CheckGamePass",
	},
	Settings = {
		DebrisLifetime = 3.0,
		DebrisFadeTime = 0.8,
		StructureRespawnTime = 35.0,
		DefaultPartHealth = 50,
		MinImpulseForce = 25,
		MaxImpulseForce = 65,
	},
}

return Constants
