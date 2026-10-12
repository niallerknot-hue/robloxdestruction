--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

-- 1. Create and setup Remote Instances in ReplicatedStorage
local function ensureRemoteEvent(name: string): RemoteEvent
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local newEvent = Instance.new("RemoteEvent")
	newEvent.Name = name
	newEvent.Parent = ReplicatedStorage
	return newEvent
end

local function ensureRemoteFunction(name: string): RemoteFunction
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end
	local newFunc = Instance.new("RemoteFunction")
	newFunc.Name = name
	newFunc.Parent = ReplicatedStorage
	return newFunc
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
local function equipPlayer(player: Player)
	local char = player.Character
	if not char or not char:IsDescendantOf(workspace) then
		return
	end

	local backpack = player:WaitForChild("Backpack", 5)
	if not backpack then
		warn(string.format("[Server] Backpack missing for player %s (%d) after 5s timeout", player.Name, player.UserId))
		return
	end

	local playerData = EconomyManager.GetPlayerData(player)
	local equippedWeapon = if playerData then playerData.EquippedWeapon else "sledgehammer"
	ShopServer.GivePlayerWeaponTool(player, equippedWeapon)

	if playerData and playerData.EquippedAura ~= "none" then
		ShopServer.ApplyAura(player, playerData.EquippedAura)
	end
end

local function onCharacterSpawned(player: Player, character: Model)
	task.spawn(function()
		local startTime = os.clock()
		while not EconomyManager.IsLoaded(player) do
			if not player:IsDescendantOf(Players) or not character:IsDescendantOf(workspace) then
				return
			end
			if (os.clock() - startTime) >= 15 then
				warn(
					string.format(
						"[Server] Timeout waiting for data to load for %s (%d). Giving default sledgehammer.",
						player.Name,
						player.UserId
					)
				)
				if player:IsDescendantOf(Players) and character:IsDescendantOf(workspace) then
					ShopServer.GivePlayerWeaponTool(player, "sledgehammer")
				end
				return
			end
			task.wait(0.1)
		end

		if not player:IsDescendantOf(Players) or not character:IsDescendantOf(workspace) then
			return
		end

		equipPlayer(player)
	end)
end

-- C2: When a profile finishes loading, if the player's character is already in the world, give the saved weapon and aura
EconomyManager.ProfileLoaded:Connect(function(player: Player)
	if player.Character and player.Character:IsDescendantOf(workspace) then
		equipPlayer(player)
	end
end)

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
