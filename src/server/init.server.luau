--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

-- 1. Create and setup Remote Instances in ReplicatedStorage
local function ensureRemoteEvent(name: string): RemoteEvent
	local event = ReplicatedStorage:FindFirstChild(name) :: RemoteEvent?
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = ReplicatedStorage
	end
	return event
end

local function ensureRemoteFunction(name: string): RemoteFunction
	local func = ReplicatedStorage:FindFirstChild(name) :: RemoteFunction?
	if not func then
		func = Instance.new("RemoteFunction")
		func.Name = name
		func.Parent = ReplicatedStorage
	end
	return func
end

ensureRemoteEvent(Constants.Remotes.RequestAttack)
ensureRemoteEvent(Constants.Remotes.DamageDealt)
ensureRemoteEvent(Constants.Remotes.CurrencyChanged)
ensureRemoteEvent(Constants.Remotes.EquipItem)
ensureRemoteEvent(Constants.Remotes.SyncInventory)
ensureRemoteEvent(Constants.Remotes.PlayDestructionFX)
ensureRemoteEvent(Constants.Remotes.NotifyMessage)
ensureRemoteFunction(Constants.Remotes.BuyItem)

-- 2. Require and initialize Subsystems
local CollisionManager = require(script.CollisionManager)
local EconomyManager = require(script.EconomyManager)
local DestructionEngine = require(script.DestructionEngine)
local ShopServer = require(script.ShopServer)
local VillageGenerator = require(script.VillageGenerator)

CollisionManager.Init()
EconomyManager.Init()
DestructionEngine.Init()
ShopServer.Init()

-- 3. Procedurally generate the Old English Village
VillageGenerator.Generate()

-- 4. Equip players with starting weapons when they spawn
local function onCharacterSpawned(player: Player, character: Model)
	task.wait(0.2)
	local playerData = EconomyManager.GetPlayerData(player)
	local equippedWeapon = if playerData then playerData.EquippedWeapon else "sledgehammer"
	ShopServer.GivePlayerWeaponTool(player, equippedWeapon)

	if playerData and playerData.EquippedAura ~= "none" then
		ShopServer.ApplyAura(player, playerData.EquippedAura)
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterSpawned(player, character)
	end)
	if player.Character then
		onCharacterSpawned(player, player.Character)
	end
end)

for _, player in Players:GetPlayers() do
	if player.Character then
		onCharacterSpawned(player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		onCharacterSpawned(player, character)
	end)
end

print("[Server] Destruction Village Server systems fully running!")
