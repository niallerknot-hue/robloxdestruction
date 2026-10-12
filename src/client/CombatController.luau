--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local CombatController = {}
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local attackRemote: RemoteEvent
local activeTool: Tool? = nil
local isAttacking = false
local lastAttackTime = 0
local connectedTools: { [Tool]: boolean } = (setmetatable({}, { __mode = "k" }) :: any) :: { [Tool]: boolean }

local function screenShake(intensity: number, duration: number)
	task.spawn(function()
		local startTime = os.clock()
		while (os.clock() - startTime) < duration do
			local elapsed = os.clock() - startTime
			local damp = 1 - (elapsed / duration)
			local offsetX = (math.random() - 0.5) * intensity * damp
			local offsetY = (math.random() - 0.5) * intensity * damp
			if camera then
				camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(offsetX), math.rad(offsetY), 0)
			end
			RunService.RenderStepped:Wait()
		end
	end)
end

local function onToolActivated()
	if not activeTool or isAttacking then
		return
	end

	local cooldown: number = (activeTool:GetAttribute("Cooldown") :: number?) or 0.65
	local now = os.clock()
	if (now - lastAttackTime) < cooldown then
		return
	end
	lastAttackTime = now
	isAttacking = true

	local char = player.Character
	if not char then
		isAttacking = false
		return
	end

	local rootPart = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		isAttacking = false
		return
	end

	-- Raycast from mouse to find hit position
	local hitPosition = mouse.Hit.Position
	local reach: number = ((activeTool:GetAttribute("Radius") :: number?) or 5) + 8
	local dist = (hitPosition - rootPart.Position).Magnitude

	local impactCF: CFrame
	if dist > reach then
		-- Clamp to max reach direction
		local dir = (hitPosition - rootPart.Position).Unit
		impactCF = CFrame.new(rootPart.Position + dir * reach)
	else
		impactCF = CFrame.new(hitPosition)
	end

	-- Trigger swing animation via Humanoid if animator is present
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- Subtle arm swing
		local handle = activeTool:FindFirstChild("Handle") :: BasePart?
		if handle then
			task.spawn(function()
				local originalGrip = activeTool.Grip
				activeTool.Grip = originalGrip * CFrame.Angles(math.rad(-60), 0, 0)
				task.wait(0.12)
				screenShake(0.65, 0.15)
				activeTool.Grip = originalGrip * CFrame.Angles(math.rad(45), 0, 0)
				task.wait(0.15)
				activeTool.Grip = originalGrip
			end)
		end
	end

	-- Send attack request to server
	attackRemote:FireServer(impactCF)

	task.delay(cooldown, function()
		isAttacking = false
	end)
end

function CombatController.Init()
	attackRemote = ReplicatedStorage:WaitForChild(Constants.Remotes.RequestAttack) :: RemoteEvent

	local function setupTool(tool: Tool)
		if tool:GetAttribute("IsDestructionWeapon") then
			activeTool = tool
			if not connectedTools[tool] then
				connectedTools[tool] = true
				tool.Activated:Connect(onToolActivated)
			end
		end
	end

	local function onCharacter(char: Model)
		char.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				setupTool(child)
			end
		end)
		char.ChildRemoved:Connect(function(child)
			if child == activeTool then
				activeTool = nil
				isAttacking = false
			end
		end)

		for _, child in char:GetChildren() do
			if child:IsA("Tool") then
				setupTool(child)
			end
		end
	end

	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)

	print("[CombatController] Combat and weapon swing controller initialized.")
end

return CombatController
