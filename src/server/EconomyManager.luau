--!strict
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local WeaponData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponData"))

local EconomyManager = {}

local DATA_KEY_PREFIX = "DestructionVillage_v1_"
local playerDataStore: DataStore? = nil

-- Attempt to connect to DataStore
pcall(function()
	playerDataStore = DataStoreService:GetDataStore("DestructionVillagePlayerData_v1")
end)

local sessionData: { [Player]: Types.PlayerData } = {}

local function getDefaultData(): Types.PlayerData
	return {
		Dollars = 0,
		EquippedWeapon = "sledgehammer",
		EquippedSkin = "default",
		EquippedAura = "none",
		OwnedWeapons = {
			sledgehammer = true,
		},
		OwnedSkins = {
			default = true,
		},
		OwnedAuras = {
			none = true,
		},
		Stats = {
			TotalDestroyed = 0,
			TotalEarnings = 0,
		},
	}
end

local function syncToClient(player: Player)
	local data = sessionData[player]
	if not data then return end

	local syncRemote = ReplicatedStorage:FindFirstChild(Constants.Remotes.SyncInventory) :: RemoteEvent?
	if syncRemote then
		syncRemote:FireClient(player, data)
	end

	local currRemote = ReplicatedStorage:FindFirstChild(Constants.Remotes.CurrencyChanged) :: RemoteEvent?
	if currRemote then
		currRemote:FireClient(player, data.Dollars)
	end

	-- Also update leaderstats for leaderboard display
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local dollarsVal = leaderstats:FindFirstChild("Dollars") :: IntValue?
		if dollarsVal then
			dollarsVal.Value = data.Dollars
		end
		local destroyedVal = leaderstats:FindFirstChild("Destroyed") :: IntValue?
		if destroyedVal then
			destroyedVal.Value = data.Stats.TotalDestroyed
		end
	end
end

function EconomyManager.Init()
	-- Create Leaderstats and load profile on player join
	local function onPlayerAdded(player: Player)
		local leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player

		local dollarsVal = Instance.new("IntValue")
		dollarsVal.Name = "Dollars"
		dollarsVal.Value = 0
		dollarsVal.Parent = leaderstats

		local destroyedVal = Instance.new("IntValue")
		destroyedVal.Name = "Destroyed"
		destroyedVal.Value = 0
		destroyedVal.Parent = leaderstats

		local loadedData: Types.PlayerData = getDefaultData()

		if playerDataStore then
			local key = DATA_KEY_PREFIX .. tostring(player.UserId)
			local success, result = pcall(function()
				return playerDataStore:GetAsync(key)
			end)
			if success and result and type(result) == "table" then
				-- Merge saved fields
				loadedData.Dollars = result.Dollars or loadedData.Dollars
				loadedData.EquippedWeapon = result.EquippedWeapon or loadedData.EquippedWeapon
				loadedData.EquippedSkin = result.EquippedSkin or loadedData.EquippedSkin
				loadedData.EquippedAura = result.EquippedAura or loadedData.EquippedAura
				if result.OwnedWeapons then
					loadedData.OwnedWeapons = result.OwnedWeapons
				end
				if result.OwnedSkins then
					loadedData.OwnedSkins = result.OwnedSkins
				end
				if result.OwnedAuras then
					loadedData.OwnedAuras = result.OwnedAuras
				end
				if result.Stats then
					loadedData.Stats = result.Stats
				end
			end
		end

		-- Ensure starter weapon is owned
		loadedData.OwnedWeapons["sledgehammer"] = true

		sessionData[player] = loadedData
		syncToClient(player)
	end

	local function onPlayerRemoving(player: Player)
		local data = sessionData[player]
		if data and playerDataStore then
			local key = DATA_KEY_PREFIX .. tostring(player.UserId)
			pcall(function()
				playerDataStore:SetAsync(key, data)
			end)
		end
		sessionData[player] = nil
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(function()
		for player, data in sessionData do
			if playerDataStore then
				local key = DATA_KEY_PREFIX .. tostring(player.UserId)
				pcall(function()
					playerDataStore:SetAsync(key, data)
				end)
			end
		end
	end)

	print("[EconomyManager] Economy and DataStore initialized.")
end

function EconomyManager.GetPlayerData(player: Player): Types.PlayerData?
	return sessionData[player]
end

function EconomyManager.AddDollars(player: Player, amount: number)
	local data = sessionData[player]
	if not data or amount <= 0 then return end

	data.Dollars += amount
	data.Stats.TotalEarnings += amount
	syncToClient(player)
end

function EconomyManager.SpendDollars(player: Player, amount: number): boolean
	local data = sessionData[player]
	if not data or data.Dollars < amount or amount < 0 then
		return false
	end

	data.Dollars -= amount
	syncToClient(player)
	return true
end

function EconomyManager.RecordDestroyedObject(player: Player, count: number?)
	local data = sessionData[player]
	if not data then return end
	data.Stats.TotalDestroyed += (count or 1)
	syncToClient(player)
end

function EconomyManager.UnlockWeapon(player: Player, weaponId: string): boolean
	local data = sessionData[player]
	if not data then return false end
	data.OwnedWeapons[weaponId] = true
	syncToClient(player)
	return true
end

function EconomyManager.UnlockSkin(player: Player, skinId: string): boolean
	local data = sessionData[player]
	if not data then return false end
	data.OwnedSkins[skinId] = true
	syncToClient(player)
	return true
end

function EconomyManager.UnlockAura(player: Player, auraId: string): boolean
	local data = sessionData[player]
	if not data then return false end
	data.OwnedAuras[auraId] = true
	syncToClient(player)
	return true
end

function EconomyManager.EquipWeapon(player: Player, weaponId: string): boolean
	local data = sessionData[player]
	if not data or not data.OwnedWeapons[weaponId] then return false end
	data.EquippedWeapon = weaponId
	syncToClient(player)
	return true
end

function EconomyManager.EquipSkin(player: Player, skinId: string): boolean
	local data = sessionData[player]
	if not data or not data.OwnedSkins[skinId] then return false end
	data.EquippedSkin = skinId
	syncToClient(player)
	return true
end

function EconomyManager.EquipAura(player: Player, auraId: string): boolean
	local data = sessionData[player]
	if not data or not data.OwnedAuras[auraId] then return false end
	data.EquippedAura = auraId
	syncToClient(player)
	return true
end

return EconomyManager
