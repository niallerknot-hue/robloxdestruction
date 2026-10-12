--!strict
export type DestructibleConfig = {
	MaxHealth: number,
	CurrentHealth: number,
	DollarReward: number,
	RespawnTime: number?,
	ParentModel: Model?,
	OriginalCFrame: CFrame?,
	OriginalSize: Vector3?,
	OriginalColor: Color3?,
	OriginalMaterial: Enum.Material?,
	OriginalTransparency: number?,
}

export type WeaponInfo = {
	Id: string,
	Name: string,
	Damage: number,
	Radius: number,
	Cooldown: number,
	PriceDollars: number,
	PriceRobux: number?,
	DevProductId: number?,
	Description: string,
	ModelColor: Color3?,
	HeadMaterial: Enum.Material?,
}

export type AuraInfo = {
	Id: string,
	Name: string,
	PriceDollars: number,
	PriceRobux: number?,
	DevProductId: number?,
	Color: Color3,
	SecondaryColor: Color3?,
	ParticleType: string,
	Description: string,
}

export type SkinInfo = {
	Id: string,
	Name: string,
	PriceDollars: number,
	PriceRobux: number?,
	DevProductId: number?,
	Color: Color3,
	Material: Enum.Material,
	Description: string,
}

export type PlayerData = {
	Dollars: number,
	EquippedWeapon: string,
	EquippedSkin: string,
	EquippedAura: string,
	OwnedWeapons: { [string]: boolean },
	OwnedSkins: { [string]: boolean },
	OwnedAuras: { [string]: boolean },
	Stats: {
		TotalDestroyed: number,
		TotalEarnings: number,
	},
	ProcessedReceipts: { [string]: boolean }?,
}

return {}
