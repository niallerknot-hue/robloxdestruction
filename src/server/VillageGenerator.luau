--!strict
local Workspace = game:GetService("Workspace")

local DestructionEngine = require(script.Parent.DestructionEngine)

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

-- 1. Helper to build a Tudor-style Cottage
local function buildTudorCottage(origin: CFrame, cottageId: string, name: string)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = villageFolder
	DestructionEngine.RegisterStructure(cottageId, name, 35)

	local w, l, h = 18, 22, 10
	local wallColor = Color3.fromRGB(235, 230, 215) -- Tudor Plaster
	local beamColor = Color3.fromRGB(75, 45, 25) -- Dark Oak Timber
	local thatchColor = Color3.fromRGB(150, 115, 65) -- Thatched Straw
	local stoneColor = Color3.fromRGB(120, 120, 120) -- Foundation Stone

	-- Stone Foundation
	createPart(
		model,
		Vector3.new(w + 1, 2, l + 1),
		origin * CFrame.new(0, 1, 0),
		stoneColor,
		Enum.Material.Cobblestone,
		"Foundation",
		120,
		35,
		cottageId
	)

	-- Floor
	createPart(
		model,
		Vector3.new(w, 0.5, l),
		origin * CFrame.new(0, 2.25, 0),
		beamColor,
		Enum.Material.WoodPlanks,
		"WoodFloor",
		50,
		15,
		cottageId
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
	local stone = Color3.fromRGB(105, 105, 110)
	local wood = Color3.fromRGB(80, 50, 30)

	-- Base Foundation
	createPart(
		model,
		Vector3.new(w + 1, 2, l + 1),
		origin * CFrame.new(0, 1, 0),
		stone,
		Enum.Material.Cobblestone,
		"StoneBase",
		150,
		40,
		shopId
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

	-- Colorful Shop Awning (e.g. Tavern Red, Bakery Yellow, Blacksmith Charcoal)
	local awningColor = if shopType == "The Red Lion Tavern"
		then Color3.fromRGB(180, 30, 30)
		elseif shopType == "Village Bakery" then Color3.fromRGB(220, 180, 60)
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

-- 3. Helper to build Farm with Barn & Windmill
local function buildFarm(farmCenter: CFrame)
	local barnId = "farm_barn"
	local windmillId = "farm_windmill"

	-- The Big Red Barn
	local barnModel = Instance.new("Model")
	barnModel.Name = "Village Farm Barn"
	barnModel.Parent = villageFolder
	DestructionEngine.RegisterStructure(barnId, "Farm Barn", 40)

	local bw, bl, bh = 28, 36, 16
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

-- 4. Helper to build Dense Woods / Forest Area
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
		local canopySize = math.random(10, 16)
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
		createPart(
			woodsModel,
			Vector3.new(bSize, bSize * 0.6, bSize * 0.8),
			forestOrigin * CFrame.new(bx, bSize * 0.3, bz),
			Color3.fromRGB(95, 95, 100),
			Enum.Material.Slate,
			"ForestBoulder_" .. b,
			150,
			40,
			woodsId
		)
	end
end

-- 5. Helper to build Town Square (Well, Notice Board, Street Lamps)
local function buildTownSquare(squareOrigin: CFrame)
	local squareId = "town_square"
	local squareModel = Instance.new("Model")
	squareModel.Name = "Town Square"
	squareModel.Parent = villageFolder
	DestructionEngine.RegisterStructure(squareId, "Town Square", 30)

	-- Cobblestone Plaza Floor
	createPart(
		squareModel,
		Vector3.new(60, 1, 60),
		squareOrigin * CFrame.new(0, 0.5, 0),
		Color3.fromRGB(130, 130, 135),
		Enum.Material.Cobblestone,
		"TownSquareFloor",
		350,
		100,
		squareId
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

-- 6. Helper to build Vintage Delivery Van / Farm Wagon
local function buildVehicles(origin: CFrame)
	local vehicleId = "village_vehicles"
	local vehModel = Instance.new("Model")
	vehModel.Name = "Village Vehicles"
	vehModel.Parent = villageFolder
	DestructionEngine.RegisterStructure(vehicleId, "Village Vehicles", 35)

	-- Vintage Delivery Van
	local vanCF = origin * CFrame.new(12, 0, -18) * CFrame.Angles(0, math.rad(-25), 0)
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

	-- 4. The Farm (Barn, Windmill, Hay Bales, Fences)
	local farmOrigin = CFrame.new(0, 0, -75)
	buildFarm(farmOrigin)

	-- 5. Ancient Woods & Forest
	local woodsOrigin = CFrame.new(-95, 0, 0)
	buildForest(woodsOrigin)

	-- 6. Vehicles (Delivery Van & Wooden Wagon)
	buildVehicles(townCenter)

	print("[VillageGenerator] Old English Village generation complete! All structures registered.")
end

return VillageGenerator
