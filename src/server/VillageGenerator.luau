--!strict
local Workspace = game:GetService("Workspace")

local DestructionEngine = require(script.Parent.DestructionEngine)
local KitLoader = require(script.Parent.KitLoader)

local VillageGenerator = {}

local villageFolder: Folder

local function createPart(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	name: string,
	hp: number,
	reward: number,
	structureId: string?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent

	DestructionEngine.RegisterDestructiblePart(part, hp, reward, structureId)
	return part
end

local function createGround(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	name: string
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent

	return part
end

type BuildingFootprint = {
	name: string,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
}

local buildingFootprints: { BuildingFootprint } = {}
local treesSkipped = 0
local bouldersSkipped = 0

local function registerFootprint(name: string, minX: number, maxX: number, minZ: number, maxZ: number)
	table.insert(buildingFootprints, {
		name = name,
		minX = minX,
		maxX = maxX,
		minZ = minZ,
		maxZ = maxZ,
	})
end

local function registerOrientedFootprint(name: string, origin: CFrame, halfWidth: number, halfLength: number)
	local corners = {
		origin * Vector3.new(-halfWidth, 0, -halfLength),
		origin * Vector3.new(halfWidth, 0, -halfLength),
		origin * Vector3.new(-halfWidth, 0, halfLength),
		origin * Vector3.new(halfWidth, 0, halfLength),
	}
	local minX, maxX = math.huge, -math.huge
	local minZ, maxZ = math.huge, -math.huge
	for _, c in corners do
		minX = math.min(minX, c.X)
		maxX = math.max(maxX, c.X)
		minZ = math.min(minZ, c.Z)
		maxZ = math.max(maxZ, c.Z)
	end
	registerFootprint(name, minX, maxX, minZ, maxZ)
end

local function overlapsAnyBuilding(x: number, z: number, radius: number): boolean
	for _, fp in buildingFootprints do
		local closestX = math.clamp(x, fp.minX, fp.maxX)
		local closestZ = math.clamp(z, fp.minZ, fp.maxZ)
		local dx = x - closestX
		local dz = z - closestZ
		if (dx * dx + dz * dz) < (radius * radius) then
			return true
		end
	end
	return false
end

-- 1. Helper to build a Tudor-style Cottage
local function buildTudorCottage(origin: CFrame, cottageId: string, name: string)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = villageFolder
	DestructionEngine.RegisterStructure(cottageId, name, 35)

	local w, l, h = 18, 22, 10
	registerOrientedFootprint(name, origin, (w + 1) / 2, (l + 1) / 2)
	local wallColor = Color3.fromRGB(235, 230, 215) -- Tudor Plaster
	local beamColor = Color3.fromRGB(75, 45, 25) -- Dark Oak Timber
	local thatchColor = Color3.fromRGB(150, 115, 65) -- Thatched Straw
	local stoneColor = Color3.fromRGB(120, 120, 120) -- Foundation Stone

	-- Stone Foundation
	createGround(
		model,
		Vector3.new(w + 1, 2, l + 1),
		origin * CFrame.new(0, 1, 0),
		stoneColor,
		Enum.Material.Cobblestone,
		"Foundation"
	)

	-- Floor
	createGround(
		model,
		Vector3.new(w, 0.5, l),
		origin * CFrame.new(0, 2.25, 0),
		beamColor,
		Enum.Material.WoodPlanks,
		"WoodFloor"
	)

	-- 4 Plaster Walls
	local wallY = 2 + h / 2
	-- Front Wall (split for door)
	createPart(
		model,
		Vector3.new((w - 4) / 2, h, 1),
		origin * CFrame.new(-(w / 4 + 1), wallY, l / 2),
		wallColor,
		Enum.Material.Concrete,
		"FrontWallLeft",
		70,
		20,
		cottageId
	)
	createPart(
		model,
		Vector3.new((w - 4) / 2, h, 1),
		origin * CFrame.new((w / 4 + 1), wallY, l / 2),
		wallColor,
		Enum.Material.Concrete,
		"FrontWallRight",
		70,
		20,
		cottageId
	)
	createPart(
		model,
		Vector3.new(4, 2, 1),
		origin * CFrame.new(0, 2 + h - 1, l / 2),
		beamColor,
		Enum.Material.Wood,
		"DoorHeader",
		40,
		12,
		cottageId
	)
	-- Wooden Door
	createPart(
		model,
		Vector3.new(3.8, 7.8, 0.4),
		origin * CFrame.new(0, 2 + 3.9, l / 2),
		Color3.fromRGB(90, 50, 30),
		Enum.Material.WoodPlanks,
		"OakDoor",
		40,
		15,
		cottageId
	)

	-- Back Wall
	createPart(
		model,
		Vector3.new(w, h, 1),
		origin * CFrame.new(0, wallY, -l / 2),
		wallColor,
		Enum.Material.Concrete,
		"BackWall",
		90,
		25,
		cottageId
	)
	-- Left & Right Walls
	createPart(
		model,
		Vector3.new(1, h, l),
		origin * CFrame.new(-w / 2, wallY, 0),
		wallColor,
		Enum.Material.Concrete,
		"LeftWall",
		80,
		22,
		cottageId
	)
	createPart(
		model,
		Vector3.new(1, h, l),
		origin * CFrame.new(w / 2, wallY, 0),
		wallColor,
		Enum.Material.Concrete,
		"RightWall",
		80,
		22,
		cottageId
	)

	-- Exposed Tudor Vertical & Cross Beams
	for _, xOffset in { -w / 2, w / 2 } do
		for _, zOffset in { -l / 2, l / 2 } do
			createPart(
				model,
				Vector3.new(1.2, h, 1.2),
				origin * CFrame.new(xOffset, wallY, zOffset),
				beamColor,
				Enum.Material.Wood,
				"CornerBeam",
				60,
				18,
				cottageId
			)
		end
	end

	-- Thatched Roof (Pitched Gable Roof)
	local roofSlopeY = 2 + h + 3.5
	createPart(
		model,
		Vector3.new(w / 2 + 2, 1.5, l + 3),
		origin * CFrame.new(-w / 4, roofSlopeY, 0) * CFrame.Angles(0, 0, math.rad(35)),
		thatchColor,
		Enum.Material.WoodPlanks,
		"ThatchRoofLeft",
		95,
		30,
		cottageId
	)
	createPart(
		model,
		Vector3.new(w / 2 + 2, 1.5, l + 3),
		origin * CFrame.new(w / 4, roofSlopeY, 0) * CFrame.Angles(0, 0, math.rad(-35)),
		thatchColor,
		Enum.Material.WoodPlanks,
		"ThatchRoofRight",
		95,
		30,
		cottageId
	)

	-- Stone Chimney
	createPart(
		model,
		Vector3.new(3, h + 8, 3),
		origin * CFrame.new(w / 2 - 2, (h + 8) / 2, -l / 4),
		Color3.fromRGB(140, 70, 60),
		Enum.Material.Brick,
		"BrickChimney",
		140,
		45,
		cottageId
	)
end

-- 2. Helper to build Village Shop (Blacksmith, Tavern, Bakery)
local function buildShop(origin: CFrame, shopId: string, shopType: string)
	local model = Instance.new("Model")
	model.Name = shopType .. " Shop"
	model.Parent = villageFolder
	DestructionEngine.RegisterStructure(shopId, shopType, 40)

	local w, l, h = 22, 26, 12
	registerOrientedFootprint(shopType .. " Shop", origin, (w + 1) / 2, (l + 1) / 2)
	local stone = Color3.fromRGB(105, 105, 110)
	local wood = Color3.fromRGB(80, 50, 30)

	-- Base Foundation
	createGround(
		model,
		Vector3.new(w + 1, 2, l + 1),
		origin * CFrame.new(0, 1, 0),
		stone,
		Enum.Material.Cobblestone,
		"StoneBase"
	)

	-- Main Walls
	createPart(
		model,
		Vector3.new(w, h, 1),
		origin * CFrame.new(0, 2 + h / 2, -l / 2),
		stone,
		Enum.Material.Cobblestone,
		"BackWall",
		120,
		30,
		shopId
	)
	createPart(
		model,
		Vector3.new(1, h, l),
		origin * CFrame.new(-w / 2, 2 + h / 2, 0),
		wood,
		Enum.Material.WoodPlanks,
		"SideWallL",
		100,
		25,
		shopId
	)
	createPart(
		model,
		Vector3.new(1, h, l),
		origin * CFrame.new(w / 2, 2 + h / 2, 0),
		wood,
		Enum.Material.WoodPlanks,
		"SideWallR",
		100,
		25,
		shopId
	)

	-- Shop Counter & Open Facade
	createPart(
		model,
		Vector3.new(w - 6, 3.5, 2.5),
		origin * CFrame.new(0, 2 + 1.75, l / 2 - 2),
		Color3.fromRGB(100, 65, 40),
		Enum.Material.WoodPlanks,
		"ShopCounter",
		60,
		20,
		shopId
	)

	-- Colorful Shop Awning (e.g. Tavern Red, Bakery Yellow, General Store Green, Blacksmith Charcoal)
	local awningColor = if shopType == "The Red Lion Tavern"
		then Color3.fromRGB(180, 30, 30)
		elseif shopType == "Village Bakery" then Color3.fromRGB(220, 180, 60)
		elseif shopType == "Hamlet General Store" then Color3.fromRGB(50, 100, 60)
		else Color3.fromRGB(45, 45, 50)

	createPart(
		model,
		Vector3.new(w + 2, 1, 6),
		origin * CFrame.new(0, 2 + 8, l / 2 + 1) * CFrame.Angles(math.rad(15), 0, 0),
		awningColor,
		Enum.Material.Fabric,
		"FabricAwning",
		40,
		15,
		shopId
	)

	-- Tiled Roof
	createPart(
		model,
		Vector3.new(w + 2, 2, l + 2),
		origin * CFrame.new(0, 2 + h + 1, 0),
		Color3.fromRGB(70, 70, 75),
		Enum.Material.Slate,
		"SlateRoof",
		130,
		35,
		shopId
	)

	-- Specific Props inside shop
	if shopType == "Blacksmith Forge" then
		-- Anvil & Forge
		createPart(
			model,
			Vector3.new(4, 5, 4),
			origin * CFrame.new(-w / 4, 2 + 2.5, 0),
			Color3.fromRGB(130, 40, 20),
			Enum.Material.Brick,
			"ForgeHearth",
			180,
			50,
			shopId
		)
		createPart(
			model,
			Vector3.new(2, 2.5, 3),
			origin * CFrame.new(0, 2 + 1.25, 0),
			Color3.fromRGB(30, 30, 35),
			Enum.Material.Metal,
			"HeavyIronAnvil",
			250,
			75,
			shopId
		)
	elseif shopType == "The Red Lion Tavern" then
		-- Ale Barrels
		for i = -2, 2, 2 do
			createPart(
				model,
				Vector3.new(2.5, 3.5, 2.5),
				origin * CFrame.new(w / 4, 2 + 1.75, i * 2.5),
				Color3.fromRGB(90, 55, 30),
				Enum.Material.Wood,
				"AleBarrel",
				45,
				15,
				shopId
			)
		end
	end
end

-- 3. Helper to build the North Green Village Church
local function buildChurch(origin: CFrame)
	local churchId = "church"
	local model = Instance.new("Model")
	model.Name = "Village Church"
	model.Parent = villageFolder
	DestructionEngine.RegisterStructure(churchId, "Village Church", 50)

	-- Nave: length 44 in X, width 30 in Z, height 14 in Y
	-- Tower: width 14 in X, length 14 in Z, height 28 in Y on west end
	-- Nave center is at origin * CFrame.new(7, 0, 0)
	-- Tower center is at origin * CFrame.new(-21, 0, 0)
	-- Combined footprint bounds: X in [origin.X - 28.5, origin.X + 29.5], Z in [origin.Z - 15.5, origin.Z + 15.5]
	registerFootprint(
		"Village Church",
		origin.Position.X - 28.5,
		origin.Position.X + 29.5,
		origin.Position.Z - 15.5,
		origin.Position.Z + 15.5
	)

	local stoneColor = Color3.fromRGB(125, 125, 130)
	local trimColor = Color3.fromRGB(150, 150, 155)
	local slateColor = Color3.fromRGB(60, 60, 65)
	local woodColor = Color3.fromRGB(80, 50, 30)

	local naveLength = 44
	local naveWidth = 30
	local naveHeight = 14
	local naveY = 2 + naveHeight / 2 -- 9

	-- 1. Foundations & Floors (Non-destructible via createGround)
	-- Nave Foundation & Floor
	createGround(
		model,
		Vector3.new(naveLength + 1, 2, naveWidth + 1),
		origin * CFrame.new(7, 1, 0),
		Color3.fromRGB(105, 105, 110),
		Enum.Material.Cobblestone,
		"NaveFoundation"
	)
	createGround(
		model,
		Vector3.new(naveLength, 0.5, naveWidth),
		origin * CFrame.new(7, 2.25, 0),
		Color3.fromRGB(120, 120, 125),
		Enum.Material.Cobblestone,
		"NaveFloor"
	)

	-- Tower Foundation & Floor
	createGround(
		model,
		Vector3.new(15, 2, 15),
		origin * CFrame.new(-21, 1, 0),
		Color3.fromRGB(105, 105, 110),
		Enum.Material.Cobblestone,
		"TowerFoundation"
	)
	createGround(
		model,
		Vector3.new(14, 0.5, 14),
		origin * CFrame.new(-21, 2.25, 0),
		Color3.fromRGB(120, 120, 125),
		Enum.Material.Cobblestone,
		"TowerFloor"
	)

	-- 2. Nave Walls (Destructible, stone)
	-- North Wall
	createPart(
		model,
		Vector3.new(naveLength, naveHeight, 1.5),
		origin * CFrame.new(7, naveY, -naveWidth / 2),
		stoneColor,
		Enum.Material.Cobblestone,
		"NaveNorthWall",
		160,
		40,
		churchId
	)
	-- South Wall
	createPart(
		model,
		Vector3.new(naveLength, naveHeight, 1.5),
		origin * CFrame.new(7, naveY, naveWidth / 2),
		stoneColor,
		Enum.Material.Cobblestone,
		"NaveSouthWall",
		160,
		40,
		churchId
	)
	-- East Wall (Altar wall)
	createPart(
		model,
		Vector3.new(1.5, naveHeight, naveWidth),
		origin * CFrame.new(7 + naveLength / 2, naveY, 0),
		stoneColor,
		Enum.Material.Cobblestone,
		"NaveEastWall",
		180,
		45,
		churchId
	)
	-- West Wall (archway connecting nave to west tower)
	createPart(
		model,
		Vector3.new(1.5, naveHeight, (naveWidth - 10) / 2),
		origin * CFrame.new(7 - naveLength / 2, naveY, -naveWidth / 4 - 2.5),
		stoneColor,
		Enum.Material.Cobblestone,
		"NaveWestWallLeft",
		100,
		25,
		churchId
	)
	createPart(
		model,
		Vector3.new(1.5, naveHeight, (naveWidth - 10) / 2),
		origin * CFrame.new(7 - naveLength / 2, naveY, naveWidth / 4 + 2.5),
		stoneColor,
		Enum.Material.Cobblestone,
		"NaveWestWallRight",
		100,
		25,
		churchId
	)
	createPart(
		model,
		Vector3.new(1.5, 4, 10),
		origin * CFrame.new(7 - naveLength / 2, 2 + naveHeight - 2, 0),
		trimColor,
		Enum.Material.Cobblestone,
		"NaveArchHeader",
		80,
		20,
		churchId
	)

	-- 3. Square West Tower (Destructible, stone)
	local towerWidth = 14
	local towerHeight = 28
	local towerWallY = 2 + towerHeight / 2 -- 16

	-- North & South Tower Walls
	createPart(
		model,
		Vector3.new(towerWidth, towerHeight, 1.5),
		origin * CFrame.new(-21, towerWallY, -towerWidth / 2),
		stoneColor,
		Enum.Material.Cobblestone,
		"TowerNorthWall",
		200,
		50,
		churchId
	)
	createPart(
		model,
		Vector3.new(towerWidth, towerHeight, 1.5),
		origin * CFrame.new(-21, towerWallY, towerWidth / 2),
		stoneColor,
		Enum.Material.Cobblestone,
		"TowerSouthWall",
		200,
		50,
		churchId
	)

	-- West Tower Wall (Entrance Portal & Oak Door)
	createPart(
		model,
		Vector3.new(1.5, towerHeight, (towerWidth - 6) / 2),
		origin * CFrame.new(-21 - towerWidth / 2, towerWallY, -(towerWidth / 4 + 1.5)),
		stoneColor,
		Enum.Material.Cobblestone,
		"TowerPortalLeft",
		120,
		30,
		churchId
	)
	createPart(
		model,
		Vector3.new(1.5, towerHeight, (towerWidth - 6) / 2),
		origin * CFrame.new(-21 - towerWidth / 2, towerWallY, (towerWidth / 4 + 1.5)),
		stoneColor,
		Enum.Material.Cobblestone,
		"TowerPortalRight",
		120,
		30,
		churchId
	)
	createPart(
		model,
		Vector3.new(1.5, towerHeight - 8, 6),
		origin * CFrame.new(-21 - towerWidth / 2, 2 + 8 + (towerHeight - 8) / 2, 0),
		trimColor,
		Enum.Material.Cobblestone,
		"TowerPortalHeader",
		100,
		25,
		churchId
	)
	createPart(
		model,
		Vector3.new(0.6, 7.8, 5.8),
		origin * CFrame.new(-21 - towerWidth / 2, 2 + 3.9, 0),
		woodColor,
		Enum.Material.WoodPlanks,
		"ChurchOakDoor",
		50,
		15,
		churchId
	)

	-- Tower Upper East Wall (above nave roof)
	createPart(
		model,
		Vector3.new(1.5, 14, towerWidth),
		origin * CFrame.new(-21 + towerWidth / 2, 2 + 14 + 7, 0),
		stoneColor,
		Enum.Material.Cobblestone,
		"TowerEastUpperWall",
		150,
		35,
		churchId
	)

	-- Tower Belfry Roof
	createPart(
		model,
		Vector3.new(towerWidth + 1, 1.5, towerWidth + 1),
		origin * CFrame.new(-21, 2 + towerHeight + 0.75, 0),
		slateColor,
		Enum.Material.Slate,
		"TowerBelfryRoof",
		130,
		35,
		churchId
	)

	-- Tower Pinnacles (4 corners)
	local pinnacleOffsets = {
		Vector3.new(-6, 0, -6),
		Vector3.new(6, 0, -6),
		Vector3.new(-6, 0, 6),
		Vector3.new(6, 0, 6),
	}
	for idx, pOff in pinnacleOffsets do
		createPart(
			model,
			Vector3.new(2, 3.5, 2),
			origin * CFrame.new(-21 + pOff.X, 2 + towerHeight + 1.5 + 1.75, pOff.Z),
			trimColor,
			Enum.Material.Cobblestone,
			"TowerPinnacle_" .. idx,
			40,
			10,
			churchId
		)
	end

	-- 4. Steep Slate Roof over Nave (Pitched Gable Roof)
	local roofSlopeY = 2 + naveHeight + 4.5
	createPart(
		model,
		Vector3.new(naveLength + 2, 1.5, 19.5),
		origin * CFrame.new(7, roofSlopeY, -naveWidth / 4) * CFrame.Angles(math.rad(-40), 0, 0),
		slateColor,
		Enum.Material.Slate,
		"NaveRoofSlopeN",
		140,
		35,
		churchId
	)
	createPart(
		model,
		Vector3.new(naveLength + 2, 1.5, 19.5),
		origin * CFrame.new(7, roofSlopeY, naveWidth / 4) * CFrame.Angles(math.rad(40), 0, 0),
		slateColor,
		Enum.Material.Slate,
		"NaveRoofSlopeS",
		140,
		35,
		churchId
	)
	createPart(
		model,
		Vector3.new(naveLength + 2, 1.5, 2),
		origin * CFrame.new(7, 2 + naveHeight + 9.5, 0),
		Color3.fromRGB(50, 50, 55),
		Enum.Material.Slate,
		"NaveRoofRidgeCap",
		90,
		25,
		churchId
	)

	-- 5. Interior Church Props (Destructible)
	-- Stone Altar
	createPart(
		model,
		Vector3.new(4, 3.5, 10),
		origin * CFrame.new(7 + naveLength / 2 - 5, 2 + 1.75, 0),
		Color3.fromRGB(140, 140, 145),
		Enum.Material.Cobblestone,
		"ChurchAltar",
		120,
		30,
		churchId
	)

	-- Wooden Pews
	for _, zSide in { -6, 6 } do
		for row = 1, 3 do
			local pewX = -5 + (row * 8)
			createPart(
				model,
				Vector3.new(3, 2.5, 7),
				origin * CFrame.new(pewX, 2 + 1.25, zSide),
				Color3.fromRGB(90, 55, 30),
				Enum.Material.Wood,
				"ChurchPew_" .. row .. "_" .. (if zSide < 0 then "N" else "S"),
				35,
				10,
				churchId
			)
		end
	end
end

-- 4. Helper to build Farm with Barn & Windmill
local function buildFarm(farmCenter: CFrame)
	local barnId = "farm_barn"
	local windmillId = "farm_windmill"

	-- The Big Red Barn
	local barnModel = Instance.new("Model")
	barnModel.Name = "Village Farm Barn"
	barnModel.Parent = villageFolder
	DestructionEngine.RegisterStructure(barnId, "Farm Barn", 40)

	local bw, bl, bh = 28, 36, 16
	registerOrientedFootprint("Farm Barn", farmCenter, (bw + 2) / 2, (bl + 2) / 2)
	local barnRed = Color3.fromRGB(165, 35, 30)
	local whiteTrim = Color3.fromRGB(240, 240, 245)

	-- Barn Walls
	createPart(
		barnModel,
		Vector3.new(bw, bh, 1),
		farmCenter * CFrame.new(0, bh / 2, -bl / 2),
		barnRed,
		Enum.Material.WoodPlanks,
		"BarnBackWall",
		140,
		40,
		barnId
	)
	createPart(
		barnModel,
		Vector3.new(1, bh, bl),
		farmCenter * CFrame.new(-bw / 2, bh / 2, 0),
		barnRed,
		Enum.Material.WoodPlanks,
		"BarnLeftWall",
		130,
		35,
		barnId
	)
	createPart(
		barnModel,
		Vector3.new(1, bh, bl),
		farmCenter * CFrame.new(bw / 2, bh / 2, 0),
		barnRed,
		Enum.Material.WoodPlanks,
		"BarnRightWall",
		130,
		35,
		barnId
	)

	-- Barn Doors
	createPart(
		barnModel,
		Vector3.new(bw / 3, bh * 0.7, 0.6),
		farmCenter * CFrame.new(-bw / 6, (bh * 0.7) / 2, bl / 2),
		whiteTrim,
		Enum.Material.WoodPlanks,
		"BarnDoorL",
		60,
		20,
		barnId
	)
	createPart(
		barnModel,
		Vector3.new(bw / 3, bh * 0.7, 0.6),
		farmCenter * CFrame.new(bw / 6, (bh * 0.7) / 2, bl / 2),
		whiteTrim,
		Enum.Material.WoodPlanks,
		"BarnDoorR",
		60,
		20,
		barnId
	)

	-- Gambrel Barn Roof
	createPart(
		barnModel,
		Vector3.new(bw + 2, 2, bl + 2),
		farmCenter * CFrame.new(0, bh + 1, 0),
		Color3.fromRGB(50, 50, 55),
		Enum.Material.Slate,
		"BarnRoof",
		180,
		55,
		barnId
	)

	-- Hay Bales around Barn
	for _idx = 1, 5 do
		local xOff = math.random(-bw / 2 - 8, -bw / 2 - 2)
		local zOff = math.random(-bl / 2, bl / 2)
		createPart(
			barnModel,
			Vector3.new(4, 3, 3),
			farmCenter * CFrame.new(xOff, 1.5, zOff),
			Color3.fromRGB(220, 185, 80),
			Enum.Material.Fabric,
			"HayBale",
			35,
			10,
			barnId
		)
	end

	-- The Old Windmill
	local wmOrigin = farmCenter * CFrame.new(45, 0, 0)
	registerOrientedFootprint("Farm Windmill", wmOrigin, 9, 9)
	local wmModel = Instance.new("Model")
	wmModel.Name = "Village Windmill"
	wmModel.Parent = villageFolder
	DestructionEngine.RegisterStructure(windmillId, "Village Windmill", 45)

	-- Octagonal Stone Tower Segments
	for tier = 0, 3 do
		local radius = 8 - (tier * 1.2)
		local y = tier * 7 + 3.5
		createPart(
			wmModel,
			Vector3.new(radius * 2, 7, radius * 2),
			wmOrigin * CFrame.new(0, y, 0),
			Color3.fromRGB(160, 155, 145),
			Enum.Material.Cobblestone,
			"WindmillTowerTier" .. tier,
			180,
			45,
			windmillId
		)
	end

	-- Windmill 4 Lattice Sails
	local rotorCenter = wmOrigin * CFrame.new(0, 28, 5)
	for i = 0, 3 do
		local angle = math.rad(i * 90)
		createPart(
			wmModel,
			Vector3.new(2, 14, 0.4),
			rotorCenter * CFrame.Angles(0, 0, angle) * CFrame.new(0, 7, 0),
			Color3.fromRGB(230, 220, 200),
			Enum.Material.WoodPlanks,
			"WindmillSail" .. i,
			50,
			18,
			windmillId
		)
	end
end

-- 5. Helper to build Dense Woods / Forest Area
local function buildForest(forestOrigin: CFrame)
	local woodsId = "village_woods"
	local woodsModel = Instance.new("Model")
	woodsModel.Name = "Ancient Woods"
	woodsModel.Parent = villageFolder
	DestructionEngine.RegisterStructure(woodsId, "Ancient Woods", 30)

	local woodColor = Color3.fromRGB(90, 55, 30)
	local leafColors = {
		Color3.fromRGB(45, 95, 35),
		Color3.fromRGB(55, 115, 45),
		Color3.fromRGB(35, 75, 25),
	}

	-- Generate 25 trees across the woods zone
	for i = 1, 24 do
		local x = math.random(-75, 75)
		local z = math.random(-75, 75)
		local treeCF = forestOrigin * CFrame.new(x, 0, z)
		local canopySize = math.random(10, 16)
		local treeRadius = canopySize / 2

		if overlapsAnyBuilding(treeCF.Position.X, treeCF.Position.Z, treeRadius) then
			treesSkipped += 1
			continue
		end

		local trunkHeight = math.random(12, 18)
		local trunkWidth = math.random(2, 4)

		-- Trunk
		createPart(
			woodsModel,
			Vector3.new(trunkWidth, trunkHeight, trunkWidth),
			treeCF * CFrame.new(0, trunkHeight / 2, 0),
			woodColor,
			Enum.Material.Wood,
			"TreeTrunk_" .. i,
			75,
			20,
			woodsId
		)

		-- Canopy (Stacked Spheres/Boxes)
		local leafColor = leafColors[math.random(1, #leafColors)]
		createPart(
			woodsModel,
			Vector3.new(canopySize, canopySize * 0.75, canopySize),
			treeCF * CFrame.new(0, trunkHeight + canopySize * 0.35, 0),
			leafColor,
			Enum.Material.Grass,
			"TreeCanopy_" .. i,
			50,
			15,
			woodsId
		)
	end

	-- Boulders and Fallen Logs
	for b = 1, 8 do
		local bx = math.random(-70, 70)
		local bz = math.random(-70, 70)
		local bSize = math.random(5, 10)
		local boulderRadius = bSize / 2
		local boulderCF = forestOrigin * CFrame.new(bx, bSize * 0.3, bz)

		if overlapsAnyBuilding(boulderCF.Position.X, boulderCF.Position.Z, boulderRadius) then
			bouldersSkipped += 1
			continue
		end

		createPart(
			woodsModel,
			Vector3.new(bSize, bSize * 0.6, bSize * 0.8),
			boulderCF,
			Color3.fromRGB(95, 95, 100),
			Enum.Material.Slate,
			"ForestBoulder_" .. b,
			150,
			40,
			woodsId
		)
	end
end

-- 6. Helper to build Town Square (Well, Notice Board, Street Lamps)
local function buildTownSquare(squareOrigin: CFrame)
	local squareId = "town_square"
	local squareModel = Instance.new("Model")
	squareModel.Name = "Town Square"
	squareModel.Parent = villageFolder
	DestructionEngine.RegisterStructure(squareId, "Town Square", 30)

	registerOrientedFootprint("Town Square", squareOrigin, 30, 30)

	-- Cobblestone Plaza Floor
	createGround(
		squareModel,
		Vector3.new(60, 1, 60),
		squareOrigin * CFrame.new(0, 0.5, 0),
		Color3.fromRGB(130, 130, 135),
		Enum.Material.Cobblestone,
		"TownSquareFloor"
	)

	-- Village Stone Well in Center
	createPart(
		squareModel,
		Vector3.new(8, 3.5, 8),
		squareOrigin * CFrame.new(0, 2.75, 0),
		Color3.fromRGB(110, 110, 115),
		Enum.Material.Cobblestone,
		"VillageWellBasin",
		160,
		45,
		squareId
	)
	-- Well Wooden Canopy
	createPart(
		squareModel,
		Vector3.new(9, 1.2, 9),
		squareOrigin * CFrame.new(0, 7.5, 0),
		Color3.fromRGB(90, 55, 30),
		Enum.Material.WoodPlanks,
		"WellCanopy",
		60,
		20,
		squareId
	)

	-- Street Lamps on 4 corners
	local offsets = {
		Vector3.new(24, 0, 24),
		Vector3.new(-24, 0, 24),
		Vector3.new(24, 0, -24),
		Vector3.new(-24, 0, -24),
	}
	for idx, offset in offsets do
		createPart(
			squareModel,
			Vector3.new(1.2, 11, 1.2),
			squareOrigin * CFrame.new(offset.X, 5.5, offset.Z),
			Color3.fromRGB(30, 30, 35),
			Enum.Material.Metal,
			"StreetLampPost_" .. idx,
			60,
			18,
			squareId
		)
		createPart(
			squareModel,
			Vector3.new(2, 2, 2),
			squareOrigin * CFrame.new(offset.X, 11, offset.Z),
			Color3.fromRGB(255, 230, 140),
			Enum.Material.Neon,
			"StreetLampLantern_" .. idx,
			30,
			10,
			squareId
		)
	end
end

-- 7. Helper to build Vintage Delivery Van / Farm Wagon
local function buildVehicles(origin: CFrame)
	local vehicleId = "village_vehicles"
	local vehModel = Instance.new("Model")
	vehModel.Name = "Village Vehicles"
	vehModel.Parent = villageFolder
	DestructionEngine.RegisterStructure(vehicleId, "Village Vehicles", 35)

	-- Vintage Delivery Van
	local vanCF = origin * CFrame.new(12, 0, -18) * CFrame.Angles(0, math.rad(-25), 0)
	registerOrientedFootprint("Delivery Van", vanCF, 4, 8)
	-- Van Chassis & Body
	createPart(
		vehModel,
		Vector3.new(7, 3, 14),
		vanCF * CFrame.new(0, 2.5, 0),
		Color3.fromRGB(45, 75, 120),
		Enum.Material.Metal,
		"VanChassis",
		160,
		50,
		vehicleId
	)
	createPart(
		vehModel,
		Vector3.new(6.8, 3.5, 9),
		vanCF * CFrame.new(0, 5.5, -2),
		Color3.fromRGB(230, 225, 210),
		Enum.Material.Metal,
		"VanCargoBox",
		120,
		35,
		vehicleId
	)
	-- Windshield
	createPart(
		vehModel,
		Vector3.new(6.4, 2.8, 0.4),
		vanCF * CFrame.new(0, 5, 3.2),
		Color3.fromRGB(180, 220, 240),
		Enum.Material.Glass,
		"VanWindshield",
		25,
		10,
		vehicleId
	)
	-- 4 Wheels
	for _, xOff in { -3.6, 3.6 } do
		for _, zOff in { -4.5, 4.5 } do
			createPart(
				vehModel,
				Vector3.new(0.8, 2.8, 2.8),
				vanCF * CFrame.new(xOff, 1.4, zOff),
				Color3.fromRGB(25, 25, 25),
				Enum.Material.Rubber,
				"VanWheel",
				40,
				12,
				vehicleId
			)
		end
	end

	-- Wooden Farm Wagon
	local wagonCF = origin * CFrame.new(-18, 0, 16) * CFrame.Angles(0, math.rad(40), 0)
	registerOrientedFootprint("Farm Wagon", wagonCF, 4, 6)
	createPart(
		vehModel,
		Vector3.new(6, 2.5, 10),
		wagonCF * CFrame.new(0, 2, 0),
		Color3.fromRGB(90, 55, 30),
		Enum.Material.WoodPlanks,
		"WagonBody",
		70,
		20,
		vehicleId
	)
	for _, xOff in { -3.2, 3.2 } do
		for _, zOff in { -3.5, 3.5 } do
			createPart(
				vehModel,
				Vector3.new(0.5, 3, 3),
				wagonCF * CFrame.new(xOff, 1.5, zOff),
				Color3.fromRGB(60, 40, 20),
				Enum.Material.Wood,
				"WagonWheel",
				30,
				10,
				vehicleId
			)
		end
	end
end

function VillageGenerator.Generate()
	local startTime = os.clock()
	buildingFootprints = {}
	treesSkipped = 0
	bouldersSkipped = 0

	-- Create or clean up Village container
	local existing = Workspace:FindFirstChild("OldEnglishVillage")
	if existing then
		existing:Destroy()
	end

	villageFolder = Instance.new("Folder")
	villageFolder.Name = "OldEnglishVillage"
	villageFolder.Parent = Workspace

	print("[VillageGenerator] Generating Old English Village...")

	-- 1. Central Town Square
	local townCenter = CFrame.new(0, 0, 0)
	buildTownSquare(townCenter)

	-- 2. Commercial Street Shops
	buildShop(CFrame.new(38, 0, -10) * CFrame.Angles(0, math.rad(-90), 0), "shop_blacksmith", "Blacksmith Forge")
	buildShop(CFrame.new(38, 0, 26) * CFrame.Angles(0, math.rad(-90), 0), "shop_tavern", "The Red Lion Tavern")
	buildShop(CFrame.new(-38, 0, -10) * CFrame.Angles(0, math.rad(90), 0), "shop_bakery", "Village Bakery")

	-- 3. Traditional Thatched Tudor Cottages
	buildTudorCottage(CFrame.new(-38, 0, 28) * CFrame.Angles(0, math.rad(90), 0), "cottage_1", "Rose Cottage")
	buildTudorCottage(CFrame.new(-16, 0, 55), "cottage_2", "Weaver Cottage")
	buildTudorCottage(CFrame.new(20, 0, 55), "cottage_3", "Thatcher Cottage")

	-- 4. East Street Cottages (facing West towards street at x ≈ 80)
	buildTudorCottage(CFrame.new(100, 0, -60) * CFrame.Angles(0, math.rad(-90), 0), "cottage_east_1", "Millers Cottage")
	buildTudorCottage(
		CFrame.new(100, 0, 10) * CFrame.Angles(0, math.rad(-90), 0),
		"cottage_east_2",
		"Carpenters Cottage"
	)
	buildTudorCottage(CFrame.new(100, 0, 80) * CFrame.Angles(0, math.rad(-90), 0), "cottage_east_3", "Bakers Cottage")

	-- 5. North Green Church
	buildChurch(CFrame.new(30, 0, -125))

	-- 6. South Row Cottages (facing North towards Town Square)
	buildTudorCottage(CFrame.new(-40, 0, 125) * CFrame.Angles(0, math.rad(180), 0), "cottage_south_1", "Meadow Cottage")
	buildTudorCottage(CFrame.new(0, 0, 125) * CFrame.Angles(0, math.rad(180), 0), "cottage_south_2", "Orchard Cottage")
	buildTudorCottage(CFrame.new(40, 0, 125) * CFrame.Angles(0, math.rad(180), 0), "cottage_south_3", "Willow Cottage")

	-- 7. South-West Hamlet (2 cottages facing East, 1 shop facing West)
	buildTudorCottage(CFrame.new(-150, 0, 110) * CFrame.Angles(0, math.rad(90), 0), "cottage_hamlet_1", "Brook Cottage")
	buildTudorCottage(CFrame.new(-120, 0, 160) * CFrame.Angles(0, math.rad(90), 0), "cottage_hamlet_2", "Fern Cottage")
	buildShop(CFrame.new(-80, 0, 150) * CFrame.Angles(0, math.rad(-90), 0), "shop_hamlet", "Hamlet General Store")

	-- 8. The Farm (Barn, Windmill, Hay Bales)
	local farmOrigin = CFrame.new(0, 0, -75)
	buildFarm(farmOrigin)

	-- 9. Vehicles (Delivery Van & Wooden Wagon)
	buildVehicles(townCenter)

	-- 10. Blender Pilot Cottage Kit
	local pilotModel = KitLoader.Spawn("cottage_tudor", villageFolder, CFrame.new(-195, 0, -120), "pilot_cottage")
	if pilotModel then
		registerOrientedFootprint("Pilot Cottage", CFrame.new(-195, 0, -120), 9, 11)
	end

	-- 11. Ancient Woods & Forest (skips trees/boulders that overlap registered footprints)
	local woodsOrigin = CFrame.new(-95, 0, 0)
	buildForest(woodsOrigin)

	local generationTime = os.clock() - startTime
	local partCount = 0
	for _, desc in villageFolder:GetDescendants() do
		if desc:IsA("BasePart") then
			partCount += 1
		end
	end

	print(
		string.format(
			"[VillageGenerator] Old English Village generation complete! Generated %d parts in %.3f seconds (%d trees skipped, %d boulders skipped). All structures registered.",
			partCount,
			generationTime,
			treesSkipped,
			bouldersSkipped
		)
	)
end

return VillageGenerator
