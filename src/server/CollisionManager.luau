--!strict
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local CollisionManager = {}

local function safeRegisterCollisionGroup(name: string)
	local success, err = pcall(function()
		PhysicsService:RegisterCollisionGroup(name)
	end)
	if not success then
		-- In case group is already registered
		-- warn("[CollisionManager] Note on registering group:", name, err)
	end
end

function CollisionManager.Init()
	-- Register Collision Groups
	safeRegisterCollisionGroup(Constants.CollisionGroups.Players)
	safeRegisterCollisionGroup(Constants.CollisionGroups.Debris)
	safeRegisterCollisionGroup(Constants.CollisionGroups.Destructibles)

	-- Collision rules
	-- 1. Debris does NOT collide with Players (prevents flinging / trapping)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(
			Constants.CollisionGroups.Debris,
			Constants.CollisionGroups.Players,
			false
		)
	end)

	-- 2. Debris does NOT collide with other Debris (prevents physics solver bottlenecks)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(
			Constants.CollisionGroups.Debris,
			Constants.CollisionGroups.Debris,
			false
		)
	end)

	-- 3. Debris DOES collide with Default (ground / baseplate / terrain)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(
			Constants.CollisionGroups.Debris,
			Constants.CollisionGroups.Default,
			true
		)
	end)

	-- 4. Destructibles collide with Players normally while standing
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(
			Constants.CollisionGroups.Destructibles,
			Constants.CollisionGroups.Players,
			true
		)
	end)

	-- Assign character parts to Players collision group
	local function onCharacterAdded(character: Model)
		for _, child in character:GetDescendants() do
			if child:IsA("BasePart") then
				CollisionManager.SetPartCollisionGroup(child, Constants.CollisionGroups.Players)
			end
		end

		character.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("BasePart") then
				CollisionManager.SetPartCollisionGroup(descendant, Constants.CollisionGroups.Players)
			end
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		if player.Character then
			onCharacterAdded(player.Character)
		end
		player.CharacterAdded:Connect(onCharacterAdded)
	end)

	for _, player in Players:GetPlayers() do
		if player.Character then
			onCharacterAdded(player.Character)
		end
		player.CharacterAdded:Connect(onCharacterAdded)
	end

	print("[CollisionManager] Zero-collision debris physics initialized successfully.")
end

function CollisionManager.SetPartCollisionGroup(part: BasePart, groupName: string)
	pcall(function()
		part.CollisionGroup = groupName
	end)
end

return CollisionManager
