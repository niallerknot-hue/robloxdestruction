--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local VFXController = {}

local function createFloatingText(position: Vector3, text: string, color: Color3)
	local part = Instance.new("Part")
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Position = position + Vector3.new(math.random(-1, 1), 1.5, math.random(-1, 1))
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(140, 45)
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Parent = billboard

	-- Float up and fade
	local moveTween = TweenService:Create(
		part,
		TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = part.Position + Vector3.new(0, 3.5, 0) }
	)
	local fadeTween = TweenService:Create(
		label,
		TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)

	moveTween:Play()
	fadeTween:Play()

	task.delay(1.1, function()
		part:Destroy()
	end)
end

local function spawnDestructionDust(position: Vector3, color: Color3, _material: Enum.Material)
	local emitterPart = Instance.new("Part")
	emitterPart.Size = Vector3.new(0.5, 0.5, 0.5)
	emitterPart.Position = position
	emitterPart.Transparency = 1
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.Parent = workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Speed = NumberRange.new(8, 20)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Rate = 200
	emitter.Parent = emitterPart

	emitter:Emit(15)

	-- Impact sound
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/action_impact_wood.mp3"
	sound.Volume = 0.6
	sound.PlaybackSpeed = math.random(85, 115) / 100
	sound.Parent = emitterPart
	sound:Play()

	task.delay(1.0, function()
		emitterPart:Destroy()
	end)
end

function VFXController.Init()
	local damageRemote = ReplicatedStorage:WaitForChild(Constants.Remotes.DamageDealt) :: RemoteEvent
	local fxRemote = ReplicatedStorage:WaitForChild(Constants.Remotes.PlayDestructionFX) :: RemoteEvent

	damageRemote.OnClientEvent:Connect(function(position: Vector3, amount: number, isKill: boolean)
		if isKill then
			createFloatingText(position, "+$" .. tostring(amount), Color3.fromRGB(80, 240, 80))
		else
			createFloatingText(position, "-" .. tostring(amount), Color3.fromRGB(255, 120, 60))
		end
	end)

	fxRemote.OnClientEvent:Connect(function(position: Vector3, color: Color3, material: Enum.Material)
		spawnDestructionDust(position, color, material)
	end)

	print("[VFXController] Destruction VFX and Floating Text controller initialized.")
end

return VFXController
