--!strict
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local EconomyManager = {}

local DATA_KEY_PREFIX = "DestructionVillage_v1_"
local playerDataStore: DataStore? = nil

-- Attempt to connect to DataStore with warning on failure
local dataStoreSuccess, dataStoreResult = pcall(function()
	return DataStoreService:GetDataStore("DestructionVillagePlayerData_v1")
end)
if dataStoreSuccess and dataStoreResult then
	playerDataStore = dataStoreResult
else
	warn(string.format("[EconomyManager] Failed to get DataStore: %s", tostring(dataStoreResult)))
end

local sessionData: { [number]: Types.PlayerData } = {}
local loadedPlayers: { [number]: boolean } = {}
local inFlightPurchases: { [string]: boolean } = {}

local profileLoadedEvent = Instance.new("BindableEvent")
EconomyManager.ProfileLoaded = profileLoadedEvent.Event

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
		ProcessedReceipts = {},
	}
end

local function deepCopyPlayerData(data: Types.PlayerData): Types.PlayerData
	local copyReceipts: { [string]: boolean } = {}
	if data.ProcessedReceipts then
		for k, v in data.ProcessedReceipts do
			copyReceipts[k] = v
		end
	end

	local copy: Types.PlayerData = {
		Dollars = data.Dollars,
		EquippedWeapon = data.EquippedWeapon,
		EquippedSkin = data.EquippedSkin,
		EquippedAura = data.EquippedAura,
		OwnedWeapons = {},
		OwnedSkins = {},
		OwnedAuras = {},
		Stats = {
			TotalDestroyed = data.Stats.TotalDestroyed,
			TotalEarnings = data.Stats.TotalEarnings,
		},
		ProcessedReceipts = copyReceipts,
	}

	for k, v in data.OwnedWeapons do
		copy.OwnedWeapons[k] = v
	end
	for k, v in data.OwnedSkins do
		copy.OwnedSkins[k] = v
	end
	for k, v in data.OwnedAuras do
		copy.OwnedAuras[k] = v
	end

	return copy
end

local function retryOperation(userId: number, operationName: string, operation: () -> ...any): (boolean, any)
	local maxAttempts = 3
	local lastError: any = nil
	for attempt = 1, maxAttempts do
		local success, result = pcall(operation)
		if success then
			return true, result
		end
		lastError = result
		warn(
			string.format(
				"[EconomyManager] %s attempt %d/%d failed for UserId %d: %s",
				operationName,
				attempt,
				maxAttempts,
				userId,
				tostring(result)
			)
		)
		if attempt < maxAttempts then
			task.wait(attempt)
		end
	end
	warn(
		string.format(
			"[EconomyManager] %s final failure after %d attempts for UserId %d: %s",
			operationName,
			maxAttempts,
			userId,
			tostring(lastError)
		)
	)
	return false, nil
end

local function syncToClient(player: Player)
	local data = sessionData[player.UserId]
	if not data then
		return
	end

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
	if leaderstats and leaderstats:IsA("Folder") then
		local dollarsVal = leaderstats:FindFirstChild("Dollars")
		if dollarsVal and dollarsVal:IsA("IntValue") then
			dollarsVal.Value = data.Dollars
		end
		local destroyedVal = leaderstats:FindFirstChild("Destroyed")
		if destroyedVal and destroyedVal:IsA("IntValue") then
			destroyedVal.Value = data.Stats.TotalDestroyed
		end
	end
end

function EconomyManager.Init()
	-- Create Leaderstats and load profile on player join
	local function onPlayerAdded(player: Player)
		local existingFolder = player:FindFirstChild("leaderstats")
		local folder: Folder
		if existingFolder and existingFolder:IsA("Folder") then
			folder = existingFolder
		else
			folder = Instance.new("Folder")
			folder.Name = "leaderstats"
			folder.Parent = player
		end

		local dollarsObj = folder:FindFirstChild("Dollars")
		if not dollarsObj or not dollarsObj:IsA("IntValue") then
			local intVal = Instance.new("IntValue")
			intVal.Name = "Dollars"
			intVal.Value = 0
			intVal.Parent = folder
		end

		local destroyedObj = folder:FindFirstChild("Destroyed")
		if not destroyedObj or not destroyedObj:IsA("IntValue") then
			local intVal = Instance.new("IntValue")
			intVal.Name = "Destroyed"
			intVal.Value = 0
			intVal.Parent = folder
		end

		local ds = playerDataStore
		if not ds then
			warn(string.format("[EconomyManager] DataStore not available for UserId %d", player.UserId))
			return
		end

		local key = DATA_KEY_PREFIX .. tostring(player.UserId)
		local success, result = retryOperation(player.UserId, "GetAsync", function()
			return ds:GetAsync(key)
		end)

		-- Check if player left while loading yielded
		if not player:IsDescendantOf(Players) then
			return
		end

		if not success then
			warn(
				string.format(
					"[EconomyManager] Profile load failed for UserId %d; profile will not save",
					player.UserId
				)
			)
			return
		end

		local loadedData: Types.PlayerData = getDefaultData()
		if result and type(result) == "table" then
			loadedData.Dollars = result.Dollars or loadedData.Dollars
			loadedData.EquippedWeapon = result.EquippedWeapon or loadedData.EquippedWeapon
			loadedData.EquippedSkin = result.EquippedSkin or loadedData.EquippedSkin
			loadedData.EquippedAura = result.EquippedAura or loadedData.EquippedAura
			if result.OwnedWeapons and type(result.OwnedWeapons) == "table" then
				loadedData.OwnedWeapons = result.OwnedWeapons
			end
			if result.OwnedSkins and type(result.OwnedSkins) == "table" then
				loadedData.OwnedSkins = result.OwnedSkins
			end
			if result.OwnedAuras and type(result.OwnedAuras) == "table" then
				loadedData.OwnedAuras = result.OwnedAuras
			end
			if result.Stats and type(result.Stats) == "table" then
				loadedData.Stats = result.Stats
			end
			if result.ProcessedReceipts and type(result.ProcessedReceipts) == "table" then
				loadedData.ProcessedReceipts = result.ProcessedReceipts
			else
				loadedData.ProcessedReceipts = {}
			end
		end

		-- Ensure starter weapon is owned
		loadedData.OwnedWeapons["sledgehammer"] = true

		if not player:IsDescendantOf(Players) then
			return
		end

		sessionData[player.UserId] = loadedData
		loadedPlayers[player.UserId] = true
		syncToClient(player)
		profileLoadedEvent:Fire(player)
	end

	local function onPlayerRemoving(player: Player)
		local isLoaded = loadedPlayers[player.UserId] == true
		local data = sessionData[player.UserId]
		local ds = playerDataStore

		if isLoaded and data and ds then
			local key = DATA_KEY_PREFIX .. tostring(player.UserId)
			retryOperation(player.UserId, "SetAsync", function()
				ds:SetAsync(key, data)
			end)
		end

		sessionData[player.UserId] = nil
		loadedPlayers[player.UserId] = nil
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(function()
		local ds = playerDataStore
		if not ds then
			return
		end
		for userId, data in sessionData do
			if loadedPlayers[userId] == true then
				local key = DATA_KEY_PREFIX .. tostring(userId)
				retryOperation(userId, "SetAsync", function()
					ds:SetAsync(key, data)
				end)
			end
		end
	end)

	print("[EconomyManager] Economy and DataStore initialized.")
end

function EconomyManager.IsLoaded(player: Player): boolean
	return loadedPlayers[player.UserId] == true and sessionData[player.UserId] ~= nil
end

function EconomyManager.GetPlayerData(player: Player): Types.PlayerData?
	return sessionData[player.UserId]
end

function EconomyManager.AddDollars(player: Player, amount: number): boolean
	local data = sessionData[player.UserId]
	if not data or amount <= 0 then
		return false
	end

	data.Dollars += amount
	data.Stats.TotalEarnings += amount
	syncToClient(player)
	return true
end

function EconomyManager.SpendDollars(player: Player, amount: number): boolean
	local data = sessionData[player.UserId]
	if not data or data.Dollars < amount or amount < 0 then
		return false
	end

	data.Dollars -= amount
	syncToClient(player)
	return true
end

function EconomyManager.RecordDestroyedObject(player: Player, count: number?)
	local data = sessionData[player.UserId]
	if not data then
		return
	end
	data.Stats.TotalDestroyed += (count or 1)
	syncToClient(player)
end

function EconomyManager.UnlockWeapon(player: Player, weaponId: string): boolean
	local data = sessionData[player.UserId]
	if not data then
		return false
	end
	data.OwnedWeapons[weaponId] = true
	syncToClient(player)
	return true
end

function EconomyManager.UnlockSkin(player: Player, skinId: string): boolean
	local data = sessionData[player.UserId]
	if not data then
		return false
	end
	data.OwnedSkins[skinId] = true
	syncToClient(player)
	return true
end

function EconomyManager.UnlockAura(player: Player, auraId: string): boolean
	local data = sessionData[player.UserId]
	if not data then
		return false
	end
	data.OwnedAuras[auraId] = true
	syncToClient(player)
	return true
end

function EconomyManager.EquipWeapon(player: Player, weaponId: string): boolean
	local data = sessionData[player.UserId]
	if not data or not data.OwnedWeapons[weaponId] then
		return false
	end
	data.EquippedWeapon = weaponId
	syncToClient(player)
	return true
end

function EconomyManager.EquipSkin(player: Player, skinId: string): boolean
	local data = sessionData[player.UserId]
	if not data or not data.OwnedSkins[skinId] then
		return false
	end
	data.EquippedSkin = skinId
	syncToClient(player)
	return true
end

function EconomyManager.EquipAura(player: Player, auraId: string): boolean
	local data = sessionData[player.UserId]
	if not data or not data.OwnedAuras[auraId] then
		return false
	end
	data.EquippedAura = auraId
	syncToClient(player)
	return true
end

function EconomyManager.HasProcessedReceipt(player: Player, purchaseId: string): boolean
	local data = sessionData[player.UserId]
	if not data or not data.ProcessedReceipts then
		return false
	end
	return data.ProcessedReceipts[purchaseId] == true
end

function EconomyManager.IsPurchaseInFlight(purchaseId: string): boolean
	return inFlightPurchases[purchaseId] == true
end

function EconomyManager.SaveRobuxPurchase(
	player: Player,
	purchaseId: string,
	applyGrant: (data: Types.PlayerData) -> boolean
): boolean
	if not EconomyManager.IsLoaded(player) then
		warn(
			string.format(
				"[EconomyManager] Cannot save Robux purchase: profile not loaded for UserId %d",
				player.UserId
			)
		)
		return false
	end

	if inFlightPurchases[purchaseId] then
		return false
	end
	inFlightPurchases[purchaseId] = true

	local success: boolean, result: any = pcall(function(): boolean
		local data = sessionData[player.UserId]
		if not data then
			warn(
				string.format(
					"[EconomyManager] Cannot save Robux purchase: no session data for UserId %d",
					player.UserId
				)
			)
			return false
		end

		local ds = playerDataStore
		if not ds then
			warn(
				string.format(
					"[EconomyManager] Cannot save Robux purchase: DataStore unavailable for UserId %d",
					player.UserId
				)
			)
			return false
		end

		local copy = deepCopyPlayerData(data)
		local grantOk = applyGrant(copy)
		if not grantOk then
			warn(string.format("[EconomyManager] Grant failed for UserId %d, purchaseId %s", player.UserId, purchaseId))
			return false
		end

		local copyReceipts: { [string]: boolean } = copy.ProcessedReceipts or {}
		copyReceipts[purchaseId] = true
		copy.ProcessedReceipts = copyReceipts

		local key = DATA_KEY_PREFIX .. tostring(player.UserId)
		local saveSuccess = retryOperation(player.UserId, "SetAsync", function()
			ds:SetAsync(key, copy)
		end)

		if not saveSuccess then
			warn(
				string.format(
					"[EconomyManager] Failed to save Robux purchase %s for UserId %d after retries",
					purchaseId,
					player.UserId
				)
			)
			return false
		end

		-- R2: Apply grant to live profile without replacing sessionData
		local liveData = sessionData[player.UserId]
		if liveData then
			applyGrant(liveData)
			local liveReceipts: { [string]: boolean } = liveData.ProcessedReceipts or {}
			liveReceipts[purchaseId] = true
			liveData.ProcessedReceipts = liveReceipts
			syncToClient(player)
		end

		return true
	end)

	inFlightPurchases[purchaseId] = nil

	if not success then
		warn(
			string.format(
				"[EconomyManager] Unexpected error during SaveRobuxPurchase for %s: %s",
				purchaseId,
				tostring(result)
			)
		)
		return false
	end

	return result == true
end

return EconomyManager
