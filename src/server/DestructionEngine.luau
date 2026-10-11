--!strict
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local WeaponData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponData"))
local CollisionManager = require(script.Parent.CollisionManager)
local EconomyManager = require(script.Parent.EconomyManager)

local DestructionEngine = {}

type PartRecord = {
	Part: BasePart,
	MaxHealth: number,
	CurrentHealth: number,
	DollarReward: number,
	OriginalCFrame: CFrame,
	OriginalSize: Vector3,
	OriginalColor: Color3,
	OriginalMaterial: Enum.Material,
	OriginalTransparency: number,
	OriginalCanCollide: boolean,
	StructureId: string?,
}

type StructureRecord = {
	Id: string,
	Name: string,
	Parts: { [BasePart]: PartRecord },
	TotalParts: number,
	DestroyedParts: number,
	RespawnTime: number,
	IsRespawning: boolean,
}

local registeredParts: { [BasePart]: PartRecord } = (shared :: any).DestructionRegisteredParts or {}
(shared :: any).DestructionRegisteredParts = registeredParts

local registeredStructures: { [string]: StructureRecord } = (shared :: any).DestructionRegisteredStructures or {}
(shared :: any).DestructionRegisteredStructures = registeredStructures

local playerCooldowns: { [Player]: number } = (shared :: any).DestructionPlayerCooldowns or {}
(shared :: any).DestructionPlayerCooldowns = playerCooldowns

-- Spatial query parameters to optimize part searching
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include
overlapParams.MaxParts = 120

function DestructionEngine.Init()
	-- Listen for Destruction Remote
	local attackRemote = ReplicatedStorage:FindFirstChild(Constants.Remotes.RequestAttack) :: RemoteEvent?
	if attackRemote then
		attackRemote.OnServerEvent:Connect(function(player: Player, impactCFrame: CFrame)
			DestructionEngine.ProcessAttack(player, impactCFrame)
		end)
	end

	print("[DestructionEngine] Destruction Engine initialized.")
end

function DestructionEngine.RegisterStructure(structureId: string, name: string, respawnTime: number?): string
	local record: StructureRecord = {
		Id = structureId,
		Name = name,
		Parts = {},
		TotalParts = 0,
		DestroyedParts = 0,
		RespawnTime = respawnTime or Constants.Settings.StructureRespawnTime,
		IsRespawning = false,
	}
	registeredStructures[structureId] = record
	return structureId
end

function DestructionEngine.RegisterDestructiblePart(
	part: BasePart,
	health: number?,
	dollarReward: number?,
	structureId: string?
)
	local hp = health or Constants.Settings.DefaultPartHealth
	local dollars = dollarReward or math.max(5, math.floor(hp / 2))

	local record: PartRecord = {
		Part = part,
		MaxHealth = hp,
		CurrentHealth = hp,
		DollarReward = dollars,
		OriginalCFrame = part.CFrame,
		OriginalSize = part.Size,
		OriginalColor = part.Color,
		OriginalMaterial = part.Material,
		OriginalTransparency = part.Transparency,
		OriginalCanCollide = part.CanCollide,
		StructureId = structureId,
	}

	registeredParts[part] = record
	part.Anchored = true
	CollectionService:AddTag(part, Constants.Tags.Destructible)
	CollisionManager.SetPartCollisionGroup(part, Constants.CollisionGroups.Destructibles)

	if structureId and registeredStructures[structureId] then
		local struct = registeredStructures[structureId]
		struct.Parts[part] = record
		struct.TotalParts += 1
	end
end

local function breakPart(part: BasePart, record: PartRecord, attacker: Player?, hitCenter: Vector3)
	-- Switch collision group immediately to Debris (NO collision with players or other debris)
	CollisionManager.SetPartCollisionGroup(part, Constants.CollisionGroups.Debris)
	CollectionService:RemoveTag(part, Constants.Tags.Destructible)
	CollectionService:AddTag(part, Constants.Tags.Debris)

	part.Anchored = false
	part.CanCollide = true -- will only collide with default terrain / ground floor

	-- Calculate directional impulse away from impact point
	local partCenter = part.Position
	local direction = (partCenter - hitCenter).Unit
	if direction.Magnitude < 0.01 then
		direction = Vector3.new(0, 1, 0)
	else
		-- Add upward pop for realistic rubble flight
		direction = (direction + Vector3.new(0, 0.45, 0)).Unit
	end

	local impulseMagnitude = math.random(
		Constants.Settings.MinImpulseForce,
		Constants.Settings.MaxImpulseForce
	) * (part:GetMass() ^ 0.75)
	
	pcall(function()
		part:ApplyImpulse(direction * impulseMagnitude)
		part:ApplyAngularImpulse(Vector3.new(
			math.random(-15, 15),
			math.random(-15, 15),
			math.random(-15, 15)
		))
	end)

	-- Fire visual effect to clients
	local fxRemote = ReplicatedStorage:FindFirstChild(Constants.Remotes.PlayDestructionFX) :: RemoteEvent?
	if fxRemote then
		fxRemote:FireAllClients(part.Position, part.Color, part.Material)
	end

	-- Award dollars to player
	if attacker then
		EconomyManager.AddDollars(attacker, record.DollarReward)
		EconomyManager.RecordDestroyedObject(attacker, 1)

		local damageRemote = ReplicatedStorage:FindFirstChild(Constants.Remotes.DamageDealt) :: RemoteEvent?
		if damageRemote then
			damageRemote:FireClient(attacker, part.Position, record.DollarReward, true)
		end
	end

	-- Update structure counter
	if record.StructureId and registeredStructures[record.StructureId] then
		local struct = registeredStructures[record.StructureId]
		struct.DestroyedParts += 1
		if struct.DestroyedParts >= math.max(1, math.floor(struct.TotalParts * 0.75)) and not struct.IsRespawning then
			DestructionEngine.ScheduleStructureRespawn(struct)
		end
	end

	-- Smooth fade out and cleanup
	task.delay(Constants.Settings.DebrisLifetime - Constants.Settings.DebrisFadeTime, function()
		if part and part.Parent then
			local tweenInfo = TweenInfo.new(Constants.Settings.DebrisFadeTime, Enum.EasingStyle.Linear)
			local fadeTween = TweenService:Create(part, tweenInfo, { Transparency = 1 })
			fadeTween:Play()
			fadeTween.Completed:Connect(function()
				part.Transparency = 1
				part.Anchored = true
				part.CanCollide = false
				part.CFrame = record.OriginalCFrame + Vector3.new(0, -500, 0) -- store out of view
			end)
		end
	end)
end

function DestructionEngine.ScheduleStructureRespawn(struct: StructureRecord)
	struct.IsRespawning = true
	task.delay(struct.RespawnTime, function()
		print("[DestructionEngine] Respawning structure:", struct.Name)
		for part, record in struct.Parts do
			if part and part.Parent then
				part.Anchored = true
				part.CFrame = record.OriginalCFrame
				part.Size = record.OriginalSize
				part.Color = record.OriginalColor
				part.Material = record.OriginalMaterial
				part.Transparency = record.OriginalTransparency
				part.CanCollide = record.OriginalCanCollide
				record.CurrentHealth = record.MaxHealth

				CollectionService:AddTag(part, Constants.Tags.Destructible)
				CollectionService:RemoveTag(part, Constants.Tags.Debris)
				CollisionManager.SetPartCollisionGroup(part, Constants.CollisionGroups.Destructibles)
				registeredParts[part] = record
			end
		end
		struct.DestroyedParts = 0
		struct.IsRespawning = false
	end)
end

function DestructionEngine.ProcessAttack(player: Player, impactCFrame: CFrame)
	local char = player.Character
	if not char then return end

	local rootPart = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return end

	-- Get player's equipped weapon
	local playerData = EconomyManager.GetPlayerData(player)
	local weaponId = if playerData then playerData.EquippedWeapon else "sledgehammer"
	local weapon = WeaponData[weaponId] or WeaponData["sledgehammer"]

	-- Rate limiting check
	local now = os.clock()
	local lastAttack = playerCooldowns[player] or 0
	if (now - lastAttack) < (weapon.Cooldown * 0.85) then
		return
	end
	playerCooldowns[player] = now

	-- Sanity check distance between player and impact point to prevent exploitation
	local distance = (rootPart.Position - impactCFrame.Position).Magnitude
	local maxReach = weapon.Radius + 15
	if distance > maxReach then
		return
	end

	-- Find all destructible parts in weapon blast/swing radius
	local destructibleList = CollectionService:GetTagged(Constants.Tags.Destructible)
	if #destructibleList == 0 then return end

	overlapParams.FilterDescendantsInstances = destructibleList
	local hitParts = workspace:GetPartBoundsInRadius(impactCFrame.Position, weapon.Radius, overlapParams)

	for _, part in hitParts do
		local record = registeredParts[part]
		if record and record.CurrentHealth > 0 then
			record.CurrentHealth -= weapon.Damage

			if record.CurrentHealth <= 0 then
				breakPart(part, record, player, impactCFrame.Position)
			else
				-- Partial damage: send hit feedback
				local damageRemote = ReplicatedStorage:FindFirstChild(Constants.Remotes.DamageDealt) :: RemoteEvent?
				if damageRemote then
					damageRemote:FireClient(player, part.Position, weapon.Damage, false)
				end
			end
		end
	end
end

return DestructionEngine
