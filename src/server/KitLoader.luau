--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DestructionEngine = require(script.Parent.DestructionEngine)

local KitLoader = {}

function KitLoader.Spawn(kitName: string, parent: Instance, origin: CFrame, structureId: string): Model?
	local templatesFolder = ReplicatedStorage:FindFirstChild("Templates")
	if not templatesFolder then
		warn(string.format("[KitLoader] Template '%s' not found", kitName))
		return nil
	end

	local template = templatesFolder:FindFirstChild(kitName)
	if not template or not template:IsA("Model") then
		warn(string.format("[KitLoader] Template '%s' not found", kitName))
		return nil
	end

	local clone = template:Clone()
	clone:PivotTo(origin)
	clone.Parent = parent

	DestructionEngine.RegisterStructure(structureId, clone.Name, 35)

	for _, desc in clone:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = true
			local prefix = string.sub(desc.Name, 1, 2)
			if prefix == "D_" then
				DestructionEngine.RegisterDestructiblePart(desc, 60, 10, structureId)
			elseif prefix == "S_" then
				desc.CanCollide = true
			else
				warn(
					string.format(
						"[KitLoader] Part '%s' in kit '%s' has unknown prefix (expected D_ or S_)",
						desc.Name,
						kitName
					)
				)
			end
		end
	end

	return clone
end

return KitLoader
