--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local WeaponData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponData"))
local ShopData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopData"))

local UIController = {}
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local inventoryData: Types.PlayerData? = nil
local activeTab = "Weapons"

local hudGui: ScreenGui
local dollarsLabel: TextLabel
local storeModal: Frame
local itemScrollList: ScrollingFrame

local function formatNumber(n: number): string
	local formatted = tostring(math.floor(n))
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			break
		end
	end
	return formatted
end

local function showNotification(msg: string, isError: boolean?)
	local notif = Instance.new("TextLabel")
	notif.Size = UDim2.fromOffset(320, 44)
	notif.Position = UDim2.new(0.5, -160, 0.15, 0)
	notif.BackgroundColor3 = if isError then Color3.fromRGB(180, 40, 40) else Color3.fromRGB(40, 150, 60)
	notif.TextColor3 = Color3.new(1, 1, 1)
	notif.Font = Enum.Font.GothamBold
	notif.TextSize = 14
	notif.Text = msg
	notif.Parent = hudGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = notif

	task.delay(2.5, function()
		local fade =
			TweenService:Create(notif, TweenInfo.new(0.5), { BackgroundTransparency = 1, TextTransparency = 1 })
		fade:Play()
		fade.Completed:Connect(function()
			notif:Destroy()
		end)
	end)
end

local function populateStoreItems()
	for _, child in itemScrollList:GetChildren() do
		if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end

	local buyRemote = ReplicatedStorage:FindFirstChild(Constants.Remotes.BuyItem) :: RemoteFunction?
	local equipRemote = ReplicatedStorage:FindFirstChild(Constants.Remotes.EquipItem) :: RemoteEvent?

	if activeTab == "Weapons" then
		for _, weapon in WeaponData do
			local isOwned = inventoryData and inventoryData.OwnedWeapons[weapon.Id] or false
			local isEquipped = inventoryData and inventoryData.EquippedWeapon == weapon.Id or false

			local card = Instance.new("Frame")
			card.Size = UDim2.new(0.96, 0, 0, 75)
			card.BackgroundColor3 = Color3.fromRGB(35, 38, 48)
			card.BorderSizePixel = 0
			card.Parent = itemScrollList

			local cardCorner = Instance.new("UICorner")
			cardCorner.CornerRadius = UDim.new(0, 10)
			cardCorner.Parent = card

			local title = Instance.new("TextLabel")
			title.Size = UDim2.new(0.55, 0, 0, 24)
			title.Position = UDim2.fromOffset(12, 8)
			title.BackgroundTransparency = 1
			title.Text = weapon.Name
			title.TextColor3 = Color3.new(1, 1, 1)
			title.Font = Enum.Font.GothamBlack
			title.TextSize = 16
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.Parent = card

			local desc = Instance.new("TextLabel")
			desc.Size = UDim2.new(0.55, 0, 0, 36)
			desc.Position = UDim2.fromOffset(12, 32)
			desc.BackgroundTransparency = 1
			desc.Text = "DMG: " .. weapon.Damage .. " | Blast: " .. weapon.Radius .. " studs\n" .. weapon.Description
			desc.TextColor3 = Color3.fromRGB(180, 185, 200)
			desc.Font = Enum.Font.GothamMedium
			desc.TextSize = 11
			desc.TextWrapped = true
			desc.TextXAlignment = Enum.TextXAlignment.Left
			desc.Parent = card

			-- Dollar Action Button
			local hasRobuxOption = weapon.PriceRobux and weapon.PriceRobux > 0 and weapon.GamePassId and not isOwned
			local dollarBtn = Instance.new("TextButton")
			dollarBtn.Size = if hasRobuxOption then UDim2.fromOffset(105, 36) else UDim2.fromOffset(110, 36)
			dollarBtn.Position = if hasRobuxOption then UDim2.new(1, -230, 0.5, -18) else UDim2.new(1, -125, 0.5, -18)
			dollarBtn.Font = Enum.Font.GothamBold
			dollarBtn.TextSize = 13
			dollarBtn.BorderSizePixel = 0
			dollarBtn.Parent = card

			local btnCorner = Instance.new("UICorner")
			btnCorner.CornerRadius = UDim.new(0, 8)
			btnCorner.Parent = dollarBtn

			if isEquipped then
				dollarBtn.BackgroundColor3 = Color3.fromRGB(70, 75, 85)
				dollarBtn.TextColor3 = Color3.fromRGB(160, 165, 175)
				dollarBtn.Text = "EQUIPPED"
			elseif isOwned then
				dollarBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 230)
				dollarBtn.TextColor3 = Color3.new(1, 1, 1)
				dollarBtn.Text = "EQUIP"
				dollarBtn.MouseButton1Click:Connect(function()
					if equipRemote then
						equipRemote:FireServer("Weapon", weapon.Id)
					end
				end)
			else
				dollarBtn.BackgroundColor3 = Color3.fromRGB(45, 185, 75)
				dollarBtn.TextColor3 = Color3.new(1, 1, 1)
				dollarBtn.Text = "$" .. formatNumber(weapon.PriceDollars)
				dollarBtn.MouseButton1Click:Connect(function()
					if buyRemote then
						local res = buyRemote:InvokeServer("Weapon", weapon.Id)
						showNotification(res.Message, not res.Success)
					end
				end)
			end

			-- Robux Action Button
			if hasRobuxOption and weapon.GamePassId then
				local robuxBtn = Instance.new("TextButton")
				robuxBtn.Size = UDim2.fromOffset(100, 36)
				robuxBtn.Position = UDim2.new(1, -115, 0.5, -18)
				robuxBtn.BackgroundColor3 = Color3.fromRGB(20, 140, 75)
				robuxBtn.TextColor3 = Color3.new(1, 1, 1)
				robuxBtn.Font = Enum.Font.GothamBold
				robuxBtn.TextSize = 13
				robuxBtn.Text = "R$ " .. tostring(weapon.PriceRobux)
				robuxBtn.BorderSizePixel = 0
				robuxBtn.Parent = card

				local rCorner = Instance.new("UICorner")
				rCorner.CornerRadius = UDim.new(0, 8)
				rCorner.Parent = robuxBtn

				robuxBtn.MouseButton1Click:Connect(function()
					MarketplaceService:PromptGamePassPurchase(player, weapon.GamePassId)
				end)
			end
		end
	elseif activeTab == "Skins" then
		for _, skin in ShopData.Skins do
			local isOwned = inventoryData and inventoryData.OwnedSkins[skin.Id] or false
			local isEquipped = inventoryData and inventoryData.EquippedSkin == skin.Id or false

			local card = Instance.new("Frame")
			card.Size = UDim2.new(0.96, 0, 0, 70)
			card.BackgroundColor3 = Color3.fromRGB(35, 38, 48)
			card.BorderSizePixel = 0
			card.Parent = itemScrollList

			local cardCorner = Instance.new("UICorner")
			cardCorner.CornerRadius = UDim.new(0, 10)
			cardCorner.Parent = card

			local title = Instance.new("TextLabel")
			title.Size = UDim2.new(0.6, 0, 0, 24)
			title.Position = UDim2.fromOffset(12, 10)
			title.BackgroundTransparency = 1
			title.Text = skin.Name
			title.TextColor3 = skin.Color
			title.Font = Enum.Font.GothamBlack
			title.TextSize = 16
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.Parent = card

			local desc = Instance.new("TextLabel")
			desc.Size = UDim2.new(0.6, 0, 0, 24)
			desc.Position = UDim2.fromOffset(12, 34)
			desc.BackgroundTransparency = 1
			desc.Text = skin.Description
			desc.TextColor3 = Color3.fromRGB(180, 185, 200)
			desc.Font = Enum.Font.GothamMedium
			desc.TextSize = 12
			desc.TextXAlignment = Enum.TextXAlignment.Left
			desc.Parent = card

			local hasRobuxOption = skin.PriceRobux and skin.PriceRobux > 0 and skin.GamePassId and not isOwned
			local actionBtn = Instance.new("TextButton")
			actionBtn.Size = if hasRobuxOption then UDim2.fromOffset(105, 36) else UDim2.fromOffset(110, 36)
			actionBtn.Position = if hasRobuxOption then UDim2.new(1, -230, 0.5, -18) else UDim2.new(1, -125, 0.5, -18)
			actionBtn.Font = Enum.Font.GothamBold
			actionBtn.TextSize = 13
			actionBtn.BorderSizePixel = 0
			actionBtn.Parent = card

			local btnCorner = Instance.new("UICorner")
			btnCorner.CornerRadius = UDim.new(0, 8)
			btnCorner.Parent = actionBtn

			if isEquipped then
				actionBtn.BackgroundColor3 = Color3.fromRGB(70, 75, 85)
				actionBtn.TextColor3 = Color3.fromRGB(160, 165, 175)
				actionBtn.Text = "EQUIPPED"
			elseif isOwned then
				actionBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 230)
				actionBtn.TextColor3 = Color3.new(1, 1, 1)
				actionBtn.Text = "EQUIP"
				actionBtn.MouseButton1Click:Connect(function()
					if equipRemote then
						equipRemote:FireServer("Skin", skin.Id)
					end
				end)
			else
				actionBtn.BackgroundColor3 = Color3.fromRGB(45, 185, 75)
				actionBtn.TextColor3 = Color3.new(1, 1, 1)
				actionBtn.Text = "$" .. formatNumber(skin.PriceDollars)
				actionBtn.MouseButton1Click:Connect(function()
					if buyRemote then
						local res = buyRemote:InvokeServer("Skin", skin.Id)
						showNotification(res.Message, not res.Success)
					end
				end)
			end

			-- Robux Action Button
			if hasRobuxOption and skin.GamePassId then
				local robuxBtn = Instance.new("TextButton")
				robuxBtn.Size = UDim2.fromOffset(100, 36)
				robuxBtn.Position = UDim2.new(1, -115, 0.5, -18)
				robuxBtn.BackgroundColor3 = Color3.fromRGB(20, 140, 75)
				robuxBtn.TextColor3 = Color3.new(1, 1, 1)
				robuxBtn.Font = Enum.Font.GothamBold
				robuxBtn.TextSize = 13
				robuxBtn.Text = "R$ " .. tostring(skin.PriceRobux)
				robuxBtn.BorderSizePixel = 0
				robuxBtn.Parent = card

				local rCorner = Instance.new("UICorner")
				rCorner.CornerRadius = UDim.new(0, 8)
				rCorner.Parent = robuxBtn

				robuxBtn.MouseButton1Click:Connect(function()
					MarketplaceService:PromptGamePassPurchase(player, skin.GamePassId)
				end)
			end
		end
	elseif activeTab == "Auras" then
		for _, aura in ShopData.Auras do
			local isOwned = inventoryData and inventoryData.OwnedAuras[aura.Id] or false
			local isEquipped = inventoryData and inventoryData.EquippedAura == aura.Id or false

			local card = Instance.new("Frame")
			card.Size = UDim2.new(0.96, 0, 0, 70)
			card.BackgroundColor3 = Color3.fromRGB(35, 38, 48)
			card.BorderSizePixel = 0
			card.Parent = itemScrollList

			local cardCorner = Instance.new("UICorner")
			cardCorner.CornerRadius = UDim.new(0, 10)
			cardCorner.Parent = card

			local title = Instance.new("TextLabel")
			title.Size = UDim2.new(0.6, 0, 0, 24)
			title.Position = UDim2.fromOffset(12, 10)
			title.BackgroundTransparency = 1
			title.Text = aura.Name
			title.TextColor3 = aura.Color
			title.Font = Enum.Font.GothamBlack
			title.TextSize = 16
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.Parent = card

			local desc = Instance.new("TextLabel")
			desc.Size = UDim2.new(0.6, 0, 0, 24)
			desc.Position = UDim2.fromOffset(12, 34)
			desc.BackgroundTransparency = 1
			desc.Text = aura.Description
			desc.TextColor3 = Color3.fromRGB(180, 185, 200)
			desc.Font = Enum.Font.GothamMedium
			desc.TextSize = 12
			desc.TextXAlignment = Enum.TextXAlignment.Left
			desc.Parent = card

			local hasRobuxOption = aura.PriceRobux and aura.PriceRobux > 0 and aura.GamePassId and not isOwned
			local actionBtn = Instance.new("TextButton")
			actionBtn.Size = if hasRobuxOption then UDim2.fromOffset(105, 36) else UDim2.fromOffset(110, 36)
			actionBtn.Position = if hasRobuxOption then UDim2.new(1, -230, 0.5, -18) else UDim2.new(1, -125, 0.5, -18)
			actionBtn.Font = Enum.Font.GothamBold
			actionBtn.TextSize = 13
			actionBtn.BorderSizePixel = 0
			actionBtn.Parent = card

			local btnCorner = Instance.new("UICorner")
			btnCorner.CornerRadius = UDim.new(0, 8)
			btnCorner.Parent = actionBtn

			if isEquipped then
				actionBtn.BackgroundColor3 = Color3.fromRGB(70, 75, 85)
				actionBtn.TextColor3 = Color3.fromRGB(160, 165, 175)
				actionBtn.Text = "EQUIPPED"
			elseif isOwned then
				actionBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 230)
				actionBtn.TextColor3 = Color3.new(1, 1, 1)
				actionBtn.Text = "EQUIP"
				actionBtn.MouseButton1Click:Connect(function()
					if equipRemote then
						equipRemote:FireServer("Aura", aura.Id)
					end
				end)
			else
				actionBtn.BackgroundColor3 = Color3.fromRGB(45, 185, 75)
				actionBtn.TextColor3 = Color3.new(1, 1, 1)
				actionBtn.Text = "$" .. formatNumber(aura.PriceDollars)
				actionBtn.MouseButton1Click:Connect(function()
					if buyRemote then
						local res = buyRemote:InvokeServer("Aura", aura.Id)
						showNotification(res.Message, not res.Success)
					end
				end)
			end

			-- Robux Action Button
			if hasRobuxOption and aura.GamePassId then
				local robuxBtn = Instance.new("TextButton")
				robuxBtn.Size = UDim2.fromOffset(100, 36)
				robuxBtn.Position = UDim2.new(1, -115, 0.5, -18)
				robuxBtn.BackgroundColor3 = Color3.fromRGB(20, 140, 75)
				robuxBtn.TextColor3 = Color3.new(1, 1, 1)
				robuxBtn.Font = Enum.Font.GothamBold
				robuxBtn.TextSize = 13
				robuxBtn.Text = "R$ " .. tostring(aura.PriceRobux)
				robuxBtn.BorderSizePixel = 0
				robuxBtn.Parent = card

				local rCorner = Instance.new("UICorner")
				rCorner.CornerRadius = UDim.new(0, 8)
				rCorner.Parent = robuxBtn

				robuxBtn.MouseButton1Click:Connect(function()
					MarketplaceService:PromptGamePassPurchase(player, aura.GamePassId)
				end)
			end
		end
	elseif activeTab == "CashPacks" then
		for _, pack in ShopData.CurrencyPacks do
			local card = Instance.new("Frame")
			card.Size = UDim2.new(0.96, 0, 0, 65)
			card.BackgroundColor3 = Color3.fromRGB(35, 38, 48)
			card.BorderSizePixel = 0
			card.Parent = itemScrollList

			local cardCorner = Instance.new("UICorner")
			cardCorner.CornerRadius = UDim.new(0, 10)
			cardCorner.Parent = card

			local title = Instance.new("TextLabel")
			title.Size = UDim2.fromScale(0.6, 1)
			title.Position = UDim2.fromOffset(16, 0)
			title.BackgroundTransparency = 1
			title.Text = pack.Name
			title.TextColor3 = Color3.fromRGB(80, 230, 80)
			title.Font = Enum.Font.GothamBlack
			title.TextSize = 18
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.Parent = card

			local robuxBtn = Instance.new("TextButton")
			robuxBtn.Size = UDim2.fromOffset(110, 36)
			robuxBtn.Position = UDim2.new(1, -125, 0.5, -18)
			robuxBtn.BackgroundColor3 = Color3.fromRGB(20, 140, 75)
			robuxBtn.TextColor3 = Color3.new(1, 1, 1)
			robuxBtn.Font = Enum.Font.GothamBold
			robuxBtn.TextSize = 14
			robuxBtn.Text = "R$ " .. pack.Robux
			robuxBtn.BorderSizePixel = 0
			robuxBtn.Parent = card

			local rCorner = Instance.new("UICorner")
			rCorner.CornerRadius = UDim.new(0, 8)
			rCorner.Parent = robuxBtn

			robuxBtn.MouseButton1Click:Connect(function()
				MarketplaceService:PromptProductPurchase(player, pack.DevProductId)
			end)
		end
	end
end

function UIController.Init()
	hudGui = Instance.new("ScreenGui")
	hudGui.Name = "DestructionHUD"
	hudGui.ResetOnSpawn = false
	hudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	hudGui.Parent = playerGui

	-- Top Dollars Card
	local dollarsCard = Instance.new("Frame")
	dollarsCard.Name = "DollarsCard"
	dollarsCard.Size = UDim2.fromOffset(210, 52)
	dollarsCard.Position = UDim2.fromOffset(24, 24)
	dollarsCard.BackgroundColor3 = Color3.fromRGB(25, 27, 34)
	dollarsCard.BorderSizePixel = 0
	dollarsCard.Parent = hudGui

	local dCardCorner = Instance.new("UICorner")
	dCardCorner.CornerRadius = UDim.new(0, 12)
	dCardCorner.Parent = dollarsCard

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(50, 180, 80)
	stroke.Thickness = 2
	stroke.Parent = dollarsCard

	dollarsLabel = Instance.new("TextLabel")
	dollarsLabel.Name = "DollarsLabel"
	dollarsLabel.Size = UDim2.new(1, -20, 1, 0)
	dollarsLabel.Position = UDim2.fromOffset(10, 0)
	dollarsLabel.BackgroundTransparency = 1
	dollarsLabel.Text = "$ 0"
	dollarsLabel.TextColor3 = Color3.fromRGB(80, 240, 80)
	dollarsLabel.Font = Enum.Font.GothamBlack
	dollarsLabel.TextSize = 22
	dollarsLabel.TextXAlignment = Enum.TextXAlignment.Left
	dollarsLabel.Parent = dollarsCard

	-- Open Store Button
	local storeBtn = Instance.new("TextButton")
	storeBtn.Name = "StoreButton"
	storeBtn.Size = UDim2.fromOffset(130, 48)
	storeBtn.Position = UDim2.fromOffset(24, 88)
	storeBtn.BackgroundColor3 = Color3.fromRGB(240, 150, 20)
	storeBtn.TextColor3 = Color3.new(1, 1, 1)
	storeBtn.Font = Enum.Font.GothamBlack
	storeBtn.TextSize = 16
	storeBtn.Text = "🛒 STORE"
	storeBtn.BorderSizePixel = 0
	storeBtn.Parent = hudGui

	local sBtnCorner = Instance.new("UICorner")
	sBtnCorner.CornerRadius = UDim.new(0, 12)
	sBtnCorner.Parent = storeBtn

	-- Store Modal Frame
	storeModal = Instance.new("Frame")
	storeModal.Name = "StoreModal"
	storeModal.Size = UDim2.fromOffset(560, 460)
	storeModal.Position = UDim2.new(0.5, -280, 0.5, -230)
	storeModal.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
	storeModal.BorderSizePixel = 0
	storeModal.Visible = false
	storeModal.Parent = hudGui

	local modalCorner = Instance.new("UICorner")
	modalCorner.CornerRadius = UDim.new(0, 16)
	modalCorner.Parent = storeModal

	local modalStroke = Instance.new("UIStroke")
	modalStroke.Color = Color3.fromRGB(60, 65, 80)
	modalStroke.Thickness = 2
	modalStroke.Parent = storeModal

	-- Store Header
	local headerTitle = Instance.new("TextLabel")
	headerTitle.Size = UDim2.new(0.5, 0, 0, 45)
	headerTitle.Position = UDim2.fromOffset(20, 5)
	headerTitle.BackgroundTransparency = 1
	headerTitle.Text = "VILLAGE ARMORY & SHOP"
	headerTitle.TextColor3 = Color3.new(1, 1, 1)
	headerTitle.Font = Enum.Font.GothamBlack
	headerTitle.TextSize = 18
	headerTitle.TextXAlignment = Enum.TextXAlignment.Left
	headerTitle.Parent = storeModal

	-- Close Button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.fromOffset(36, 36)
	closeBtn.Position = UDim2.new(1, -48, 0, 10)
	closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.Font = Enum.Font.GothamBlack
	closeBtn.TextSize = 16
	closeBtn.Text = "✕"
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = storeModal

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 8)
	cCorner.Parent = closeBtn

	local function toggleStore()
		storeModal.Visible = not storeModal.Visible
	end

	closeBtn.MouseButton1Click:Connect(function()
		storeModal.Visible = false
	end)

	storeBtn.MouseButton1Click:Connect(toggleStore)

	storeModal:GetPropertyChangedSignal("Visible"):Connect(function()
		if storeModal.Visible then
			populateStoreItems()
		end
	end)

	-- Press B to open/close Store
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.B then
			toggleStore()
		end
	end)

	-- Tabs Frame
	local tabsFrame = Instance.new("Frame")
	tabsFrame.Name = "TabsFrame"
	tabsFrame.Size = UDim2.new(1, -40, 0, 36)
	tabsFrame.Position = UDim2.fromOffset(20, 55)
	tabsFrame.BackgroundTransparency = 1
	tabsFrame.Parent = storeModal

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.Parent = tabsFrame

	local tabs = {
		{ Id = "Weapons", Label = "WEAPONS" },
		{ Id = "Skins", Label = "SKINS" },
		{ Id = "Auras", Label = "AURAS" },
		{ Id = "CashPacks", Label = "BUY CASH" },
	}

	for _, tab in tabs do
		local tabBtn = Instance.new("TextButton")
		tabBtn.Size = UDim2.new(0, 115, 1, 0)
		tabBtn.BackgroundColor3 = Color3.fromRGB(35, 38, 48)
		tabBtn.TextColor3 = Color3.fromRGB(200, 205, 215)
		tabBtn.Font = Enum.Font.GothamBold
		tabBtn.TextSize = 12
		tabBtn.Text = tab.Label
		tabBtn.BorderSizePixel = 0
		tabBtn.Parent = tabsFrame

		local tCorner = Instance.new("UICorner")
		tCorner.CornerRadius = UDim.new(0, 8)
		tCorner.Parent = tabBtn

		tabBtn.MouseButton1Click:Connect(function()
			activeTab = tab.Id
			populateStoreItems()
		end)
	end

	-- Scrolling Item List
	itemScrollList = Instance.new("ScrollingFrame")
	itemScrollList.Name = "ItemList"
	itemScrollList.Size = UDim2.new(1, -40, 1, -115)
	itemScrollList.Position = UDim2.fromOffset(20, 100)
	itemScrollList.BackgroundTransparency = 1
	itemScrollList.BorderSizePixel = 0
	itemScrollList.ScrollBarThickness = 6
	itemScrollList.Parent = storeModal

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 10)
	listLayout.Parent = itemScrollList

	local listPad = Instance.new("UIPadding")
	listPad.PaddingTop = UDim.new(0, 5)
	listPad.PaddingBottom = UDim.new(0, 10)
	listPad.Parent = itemScrollList

	-- Network Event Listeners
	local currRemote = ReplicatedStorage:WaitForChild(Constants.Remotes.CurrencyChanged) :: RemoteEvent
	local syncRemote = ReplicatedStorage:WaitForChild(Constants.Remotes.SyncInventory) :: RemoteEvent
	local checkPassRemote = ReplicatedStorage:WaitForChild(Constants.Remotes.CheckGamePass) :: RemoteEvent

	currRemote.OnClientEvent:Connect(function(dollars: number)
		dollarsLabel.Text = "$ " .. formatNumber(dollars)

		-- Pulse green stroke
		local pulse = TweenService:Create(stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = Color3.fromRGB(150, 255, 150),
			Thickness = 4,
		})
		pulse:Play()
		task.delay(0.25, function()
			TweenService:Create(stroke, TweenInfo.new(0.3), {
				Color = Color3.fromRGB(50, 180, 80),
				Thickness = 2,
			}):Play()
		end)
	end)

	syncRemote.OnClientEvent:Connect(function(data: Types.PlayerData)
		inventoryData = data
		if storeModal.Visible then
			populateStoreItems()
		end
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(purchasedPlayer: Player, passId: number, wasPurchased: boolean)
			if purchasedPlayer == player and wasPurchased then
				checkPassRemote:FireServer(passId)
			end
		end
	)

	print("[UIController] HUD and Store UI initialized.")
end

return UIController
