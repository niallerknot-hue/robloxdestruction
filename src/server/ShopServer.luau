--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local WeaponData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponData"))
local ShopData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopData"))
local EconomyManager = require(script.Parent.EconomyManager)

local ShopServer = {}

function ShopServer.Init()
	-- Handle In-Game Currency purchases via RemoteFunction
	local buyRemote = ReplicatedStorage:FindFirstChild(Constants.Remotes.BuyItem) :: RemoteFunction?
	if buyRemote then
		buyRemote.OnServerInvoke = function(player: Player, itemCategory: string, itemId: string)
			return ShopServer.ProcessPurchase(player, itemCategory, itemId)
		end
	end

	-- Handle Equip requests via RemoteEvent
	local equipRemote = ReplicatedStorage:FindFirstChild(Constants.Remotes.EquipItem) :: RemoteEvent?
	if equipRemote then
		equipRemote.OnServerEvent:Connect(function(player: Player, itemCategory: string, itemId: string)
			ShopServer.ProcessEquip(player, itemCategory, itemId)
		end)
	end

	-- MarketplaceService ProcessReceipt for Robux purchases
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local userId = receiptInfo.PlayerId
		local productId = receiptInfo.ProductId
		local player = Players:GetPlayerByUserId(userId)

		if not player then
			-- Player left, try later
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local success = ShopServer.GrantRobuxPurchase(player, productId)
		if success then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		else
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end

	print("[ShopServer] Shop and Monetization server initialized.")
end

function ShopServer.ProcessPurchase(player: Player, category: string, itemId: string): { Success: boolean, Message: string }
	local playerData = EconomyManager.GetPlayerData(player)
	if not playerData then
		return { Success = false, Message = "Player data not loaded." }
	end

	if category == "Weapon" then
		local weapon = WeaponData[itemId]
		if not weapon then
			return { Success = false, Message = "Weapon does not exist." }
		end
		if playerData.OwnedWeapons[itemId] then
			return { Success = false, Message = "Weapon already owned." }
		end
		if not EconomyManager.SpendDollars(player, weapon.PriceDollars) then
			return { Success = false, Message = "Insufficient Dollars ($" .. tostring(weapon.PriceDollars) .. " needed)." }
		end

		EconomyManager.UnlockWeapon(player, itemId)
		EconomyManager.EquipWeapon(player, itemId)
		ShopServer.GivePlayerWeaponTool(player, itemId)
		return { Success = true, Message = "Successfully purchased " .. weapon.Name .. "!" }

	elseif category == "Skin" then
		local skin = ShopData.Skins[itemId]
		if not skin then
			return { Success = false, Message = "Skin does not exist." }
		end
		if playerData.OwnedSkins[itemId] then
			return { Success = false, Message = "Skin already owned." }
		end
		if not EconomyManager.SpendDollars(player, skin.PriceDollars) then
			return { Success = false, Message = "Insufficient Dollars ($" .. tostring(skin.PriceDollars) .. " needed)." }
		end

		EconomyManager.UnlockSkin(player, itemId)
		EconomyManager.EquipSkin(player, itemId)
		return { Success = true, Message = "Successfully purchased " .. skin.Name .. " skin!" }

	elseif category == "Aura" then
		local aura = ShopData.Auras[itemId]
		if not aura then
			return { Success = false, Message = "Aura does not exist." }
		end
		if playerData.OwnedAuras[itemId] then
			return { Success = false, Message = "Aura already owned." }
		end
		if not EconomyManager.SpendDollars(player, aura.PriceDollars) then
			return { Success = false, Message = "Insufficient Dollars ($" .. tostring(aura.PriceDollars) .. " needed)." }
		end

		EconomyManager.UnlockAura(player, itemId)
		EconomyManager.EquipAura(player, itemId)
		ShopServer.ApplyAura(player, itemId)
		return { Success = true, Message = "Successfully purchased " .. aura.Name .. " aura!" }
	end

	return { Success = false, Message = "Invalid item category." }
end

function ShopServer.ProcessEquip(player: Player, category: string, itemId: string)
	local playerData = EconomyManager.GetPlayerData(player)
	if not playerData then return end

	if category == "Weapon" and playerData.OwnedWeapons[itemId] then
		EconomyManager.EquipWeapon(player, itemId)
		ShopServer.GivePlayerWeaponTool(player, itemId)
	elseif category == "Skin" and playerData.OwnedSkins[itemId] then
		EconomyManager.EquipSkin(player, itemId)
		-- Re-equip current tool to apply new skin
		ShopServer.GivePlayerWeaponTool(player, playerData.EquippedWeapon)
	elseif category == "Aura" and playerData.OwnedAuras[itemId] then
		EconomyManager.EquipAura(player, itemId)
		ShopServer.ApplyAura(player, itemId)
	end
end

function ShopServer.GrantRobuxPurchase(player: Player, productId: number): boolean
	-- Check Currency Packs
	for _, pack in ShopData.CurrencyPacks do
		if pack.DevProductId == productId then
			EconomyManager.AddDollars(player, pack.Dollars)
			return true
		end
	end

	-- Check Weapons
	for weaponId, weapon in WeaponData do
		if weapon.DevProductId == productId then
			EconomyManager.UnlockWeapon(player, weaponId)
			EconomyManager.EquipWeapon(player, weaponId)
			ShopServer.GivePlayerWeaponTool(player, weaponId)
			return true
		end
	end

	-- Check Skins
	for skinId, skin in ShopData.Skins do
		if skin.DevProductId == productId then
			EconomyManager.UnlockSkin(player, skinId)
			EconomyManager.EquipSkin(player, skinId)
			return true
		end
	end

	-- Check Auras
	for auraId, aura in ShopData.Auras do
		if aura.DevProductId == productId then
			EconomyManager.UnlockAura(player, auraId)
			EconomyManager.EquipAura(player, auraId)
			ShopServer.ApplyAura(player, auraId)
			return true
		end
	end

	return false
end

function ShopServer.GivePlayerWeaponTool(player: Player, weaponId: string)
	local char = player.Character
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	local weapon = WeaponData[weaponId] or WeaponData["sledgehammer"]
	local playerData = EconomyManager.GetPlayerData(player)
	local skinId = if playerData then playerData.EquippedSkin else "default"
	local skin = ShopData.Skins[skinId] or ShopData.Skins["default"]

	-- Remove existing weapons from backpack & character
	for _, item in backpack:GetChildren() do
		if item:IsA("Tool") and item:GetAttribute("IsDestructionWeapon") then
			item:Destroy()
		end
	end
	if char then
		for _, item in char:GetChildren() do
			if item:IsA("Tool") and item:GetAttribute("IsDestructionWeapon") then
				item:Destroy()
			end
		end
	end

	-- Create procedural weapon Tool
	local tool = Instance.new("Tool")
	tool.Name = weapon.Name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("IsDestructionWeapon", true)
	tool:SetAttribute("WeaponId", weaponId)
	tool:SetAttribute("Damage", weapon.Damage)
	tool:SetAttribute("Radius", weapon.Radius)
	tool:SetAttribute("Cooldown", weapon.Cooldown)

	-- Handle part (Grip shaft)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.6, 3.8, 0.6)
	handle.Color = Color3.fromRGB(110, 70, 40) -- Sturdy oak shaft
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	-- Hammer Head (Weld to Handle)
	local head = Instance.new("Part")
	head.Name = "HammerHead"
	head.Size = Vector3.new(2.2, 1.2, 1.2)
	head.Color = if skin.Id ~= "default" then skin.Color else (weapon.ModelColor or Color3.fromRGB(90, 90, 95))
	head.Material = if skin.Id ~= "default" then skin.Material else (weapon.HeadMaterial or Enum.Material.Metal)
	head.CanCollide = false
	head.Massless = true
	head.CFrame = handle.CFrame * CFrame.new(0, 1.6, 0)
	head.Parent = tool

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	weld.Parent = handle

	-- Grip CFrame adjustment so player holds handle properly
	tool.Grip = CFrame.new(0, -1.2, 0) * CFrame.Angles(0, math.rad(90), 0)

	tool.Parent = backpack
end

function ShopServer.ApplyAura(player: Player, auraId: string)
	local char = player.Character
	if not char then return end

	local rootPart = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return end

	-- Clean up existing aura
	local existingAura = rootPart:FindFirstChild("PlayerAuraAttachment")
	if existingAura then
		existingAura:Destroy()
	end

	if auraId == "none" then return end

	local auraInfo = ShopData.Auras[auraId]
	if not auraInfo then return end

	local attachment = Instance.new("Attachment")
	attachment.Name = "PlayerAuraAttachment"
	attachment.Parent = rootPart

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "AuraEmitter"
	emitter.Color = ColorSequence.new(auraInfo.Color, auraInfo.SecondaryColor or auraInfo.Color)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Rate = 25
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(45, 45)
	emitter.LightEmission = 0.8
	emitter.Parent = attachment
end

return ShopServer
