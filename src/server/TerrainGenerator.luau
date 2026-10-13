--!strict
local Workspace = game:GetService("Workspace")

local TerrainGenerator = {}

-- Overall map bounds (in studs)
local MAP_MIN_X = -300
local MAP_MAX_X = 480
local MAP_MIN_Z = -340
local MAP_MAX_Z = 360
local MAP_MIN_Y = -32
local MAP_MAX_Y = 56

-- Voxel resolution (Roblox smooth terrain requires resolution 4)
local RESOLUTION = 4

-- Slice dimensions in voxels (40x40 voxels = 160x160 studs)
local SLICE_VOXELS_X = 40
local SLICE_VOXELS_Z = 40

-- Village pad specification: x -220 to 140, z -150 to 190, flat at y = 0
local PAD_MIN_X = -220
local PAD_MAX_X = 140
local PAD_MIN_Z = -150
local PAD_MAX_Z = 190
local PAD_BLEND = 20

-- North-east hills specification: Centre (250, -200), radius 130, height 40 above land
local HILL_CENTER_X = 250
local HILL_CENTER_Z = -200
local HILL_RADIUS = 130
local HILL_HEIGHT = 40

-- Castle plateau specification: Centre (400, 0), radius 70, top at y = 35 (sloped sides, flat top)
local PLATEAU_CENTER_X = 400
local PLATEAU_CENTER_Z = 0
local PLATEAU_RADIUS = 70
local PLATEAU_INNER_RADIUS = 46
local PLATEAU_TOP_Y = 35

-- River specification: polyline route through 12 points
-- Width 24 (half-width 12, bank width 8)
-- Surface at y = -2, channel floor at y = -6
local RIVER_HALF_WIDTH = 12
local RIVER_BANK_WIDTH = 8
local RIVER_SURFACE_Y = -2
local RIVER_FLOOR_Y = -6

type RiverSegment = {
	AX: number,
	AZ: number,
	VX: number,
	VZ: number,
	LenSq: number,
}

local RIVER_POINTS = {
	{ -290, -330 },
	{ -285, -150 },
	{ -270, 0 },
	{ -250, 120 },
	{ -215, 230 },
	{ -120, 245 },
	{ 0, 245 },
	{ 120, 235 },
	{ 230, 150 },
	{ 300, 80 },
	{ 340, 120 },
	{ 300, 200 },
}

local RIVER_SEGMENTS: { RiverSegment } = {}
for i = 1, #RIVER_POINTS - 1 do
	local p1 = RIVER_POINTS[i]
	local p2 = RIVER_POINTS[i + 1]
	local vx = p2[1] - p1[1]
	local vz = p2[2] - p1[2]
	table.insert(RIVER_SEGMENTS, {
		AX = p1[1],
		AZ = p1[2],
		VX = vx,
		VZ = vz,
		LenSq = vx * vx + vz * vz,
	})
end

local function getDistanceToRiverPolyline(x: number, z: number): number
	local minDist = math.huge
	for _, seg in RIVER_SEGMENTS do
		local apX = x - seg.AX
		local apZ = z - seg.AZ
		local t = math.clamp((apX * seg.VX + apZ * seg.VZ) / seg.LenSq, 0, 1)
		local cX = seg.AX + t * seg.VX
		local cZ = seg.AZ + t * seg.VZ
		local dx = x - cX
		local dz = z - cZ
		local dist = math.sqrt(dx * dx + dz * dz)
		if dist < minDist then
			minDist = dist
		end
	end
	return minDist
end

-- Lake specification: Centre (300, 200), radius 70
-- Surface at y = -2, basin floor at y = -10
local LAKE_CENTER_X = 300
local LAKE_CENTER_Z = 200
local LAKE_RADIUS = 70
local LAKE_INNER_RADIUS = 46
local LAKE_SURFACE_Y = -2
local LAKE_FLOOR_Y = -10

type HeightSample = {
	GroundHeight: number,
	WaterSurface: number?,
	IsPlateauSlope: boolean,
}

local function sampleHeight(x: number, z: number): HeightSample
	-- 1. Base gentle ground noise outside the pad (roughly 6 studs variation)
	local groundNoise = math.noise(x * 0.012, z * 0.012, 1.25) * 6

	-- 2. North-east hills (rolling hills, bell curve with secondary noise)
	local dxHills = x - HILL_CENTER_X
	local dzHills = z - HILL_CENTER_Z
	local distHills = math.sqrt(dxHills * dxHills + dzHills * dzHills)
	local hillsHeight = 0
	if distHills < HILL_RADIUS then
		local t = distHills / HILL_RADIUS
		local bell = (1 + math.cos(math.pi * t)) * 0.5
		local rolling = 0.85 + 0.3 * math.noise(x * 0.025, z * 0.025, 2.5)
		hillsHeight = HILL_HEIGHT * bell * rolling
	end

	-- 3. Castle plateau (flat top at 35, sloped sides to 70)
	local dxPlateau = x - PLATEAU_CENTER_X
	local dzPlateau = z - PLATEAU_CENTER_Z
	local distPlateau = math.sqrt(dxPlateau * dxPlateau + dzPlateau * dzPlateau)
	local plateauHeight = 0
	local isPlateauSlope = false
	if distPlateau < PLATEAU_RADIUS then
		if distPlateau <= PLATEAU_INNER_RADIUS then
			plateauHeight = PLATEAU_TOP_Y
		else
			isPlateauSlope = true
			local t = (PLATEAU_RADIUS - distPlateau) / (PLATEAU_RADIUS - PLATEAU_INNER_RADIUS)
			local smoothSlope = t * t * (3 - 2 * t)
			plateauHeight = PLATEAU_TOP_Y * smoothSlope
		end
	end

	-- Land height before pad blending and water carving
	local landHeight = groundNoise + hillsHeight + plateauHeight

	-- 4. Village pad blending (flat at 0, edges blend over 20 studs)
	local dxPad = math.max(0, math.max(PAD_MIN_X - x, x - PAD_MAX_X))
	local dzPad = math.max(0, math.max(PAD_MIN_Z - z, z - PAD_MAX_Z))
	local distPad = math.sqrt(dxPad * dxPad + dzPad * dzPad)

	local padWeight = 0
	if distPad <= 0 then
		padWeight = 1
	elseif distPad < PAD_BLEND then
		local t = 1 - (distPad / PAD_BLEND)
		padWeight = t * t * (3 - 2 * t)
	end

	local groundHeight = landHeight * (1 - padWeight)

	-- 5. River channel carving and water surface
	local waterSurface: number? = nil
	local distRiver = getDistanceToRiverPolyline(x, z)
	if distRiver < (RIVER_HALF_WIDTH + RIVER_BANK_WIDTH) then
		local channelFactor = 0
		if distRiver <= RIVER_HALF_WIDTH then
			channelFactor = 1
		else
			local t = (RIVER_HALF_WIDTH + RIVER_BANK_WIDTH - distRiver) / RIVER_BANK_WIDTH
			channelFactor = t * t * (3 - 2 * t)
		end

		-- Ensure channel does not cut into village pad
		local effectiveChannel = channelFactor * (1 - padWeight)
		if effectiveChannel > 0 then
			groundHeight = (1 - effectiveChannel) * groundHeight + effectiveChannel * RIVER_FLOOR_Y

			if distRiver <= (RIVER_HALF_WIDTH + 2) and padWeight <= 0 and groundHeight < RIVER_SURFACE_Y then
				waterSurface = RIVER_SURFACE_Y
			end
		end
	end

	-- 6. Lake basin carving and water surface
	local dxLake = x - LAKE_CENTER_X
	local dzLake = z - LAKE_CENTER_Z
	local distLake = math.sqrt(dxLake * dxLake + dzLake * dzLake)
	if distLake < LAKE_RADIUS then
		local basinFactor = 0
		if distLake <= LAKE_INNER_RADIUS then
			basinFactor = 1
		else
			local t = (LAKE_RADIUS - distLake) / (LAKE_RADIUS - LAKE_INNER_RADIUS)
			basinFactor = t * t * (3 - 2 * t)
		end

		local effectiveBasin = basinFactor * (1 - padWeight)
		if effectiveBasin > 0 then
			groundHeight = (1 - effectiveBasin) * groundHeight + effectiveBasin * LAKE_FLOOR_Y

			if distLake <= (LAKE_RADIUS - 2) and groundHeight < LAKE_SURFACE_Y then
				waterSurface = LAKE_SURFACE_Y
			end
		end
	end

	-- Water exists only where ground is lower than water surface
	if waterSurface ~= nil and groundHeight >= waterSurface then
		waterSurface = nil
	end

	return {
		GroundHeight = groundHeight,
		WaterSurface = waterSurface,
		IsPlateauSlope = isPlateauSlope,
	}
end

local function determineVoxel(sample: HeightSample, voxelCenterY: number): (Enum.Material, number, number)
	local groundHeight = sample.GroundHeight
	local waterSurface = sample.WaterSurface
	local voxelBottom = voxelCenterY - 2
	local voxelTop = voxelCenterY + 2

	-- Solid ground occupancy
	local solidOcc = 0.0
	local material = Enum.Material.Air

	if voxelBottom >= groundHeight then
		solidOcc = 0.0
	elseif voxelTop <= groundHeight then
		solidOcc = 1.0
	else
		solidOcc = math.clamp((groundHeight - voxelBottom) / 4, 0.05, 1.0)
	end

	-- Material assignment for solid voxels
	if solidOcc > 0 then
		local depth = groundHeight - voxelCenterY
		if waterSurface ~= nil and math.abs(groundHeight - waterSurface) <= 3 then
			material = Enum.Material.Sand
		elseif depth > 20 or sample.IsPlateauSlope then
			material = Enum.Material.Rock
		elseif depth > 6 then
			material = Enum.Material.Ground
		else
			material = Enum.Material.Grass
		end
	end

	-- Liquid water occupancy
	local liquidOcc = 0.0
	if waterSurface ~= nil and voxelBottom < waterSurface and voxelTop > groundHeight then
		local waterTop = math.min(voxelTop, waterSurface)
		local waterBottom = math.max(voxelBottom, groundHeight)
		if waterTop > waterBottom then
			local rawLiquid = (waterTop - waterBottom) / 4
			liquidOcc = math.clamp(rawLiquid, 0.0, 1.0 - solidOcc)
		end
	end

	-- Pure water voxels use SolidMaterial = Air and LiquidOccupancy in WriteVoxelChannels
	if solidOcc <= 0.02 and liquidOcc > 0 then
		solidOcc = 0.0
		material = Enum.Material.Air
	end

	return material, solidOcc, liquidOcc
end

function TerrainGenerator.Generate()
	local terrain = Workspace.Terrain
	terrain:Clear()

	local totalVoxelsX = math.floor((MAP_MAX_X - MAP_MIN_X) / RESOLUTION)
	local totalVoxelsZ = math.floor((MAP_MAX_Z - MAP_MIN_Z) / RESOLUTION)
	local totalVoxelsY = math.floor((MAP_MAX_Y - MAP_MIN_Y) / RESOLUTION)

	local slicesX = math.ceil(totalVoxelsX / SLICE_VOXELS_X)
	local slicesZ = math.ceil(totalVoxelsZ / SLICE_VOXELS_Z)

	for sx = 1, slicesX do
		local vxStart = (sx - 1) * SLICE_VOXELS_X + 1
		local vxEnd = math.min(sx * SLICE_VOXELS_X, totalVoxelsX)
		local countX = vxEnd - vxStart + 1

		local minX = MAP_MIN_X + (vxStart - 1) * RESOLUTION
		local maxX = MAP_MIN_X + vxEnd * RESOLUTION

		for sz = 1, slicesZ do
			local vzStart = (sz - 1) * SLICE_VOXELS_Z + 1
			local vzEnd = math.min(sz * SLICE_VOXELS_Z, totalVoxelsZ)
			local countZ = vzEnd - vzStart + 1

			local minZ = MAP_MIN_Z + (vzStart - 1) * RESOLUTION
			local maxZ = MAP_MIN_Z + vzEnd * RESOLUTION

			local minCorner = Vector3.new(minX, MAP_MIN_Y, minZ)
			local maxCorner = Vector3.new(maxX, MAP_MAX_Y, maxZ)
			local region = Region3.new(minCorner, maxCorner):ExpandToGrid(RESOLUTION)

			local materials: { { { Enum.Material } } } = {}
			local solidOccupancy: { { { number } } } = {}
			local liquidOccupancy: { { { number } } } = {}
			local hasWaterInSlice = false

			for xIdx = 1, countX do
				materials[xIdx] = {}
				solidOccupancy[xIdx] = {}
				liquidOccupancy[xIdx] = {}
				for yIdx = 1, totalVoxelsY do
					materials[xIdx][yIdx] = {}
					solidOccupancy[xIdx][yIdx] = {}
					liquidOccupancy[xIdx][yIdx] = {}
				end

				local wx = minX + (xIdx - 0.5) * RESOLUTION

				for zIdx = 1, countZ do
					local wz = minZ + (zIdx - 0.5) * RESOLUTION
					local sample = sampleHeight(wx, wz)

					for yIdx = 1, totalVoxelsY do
						local wy = MAP_MIN_Y + (yIdx - 0.5) * RESOLUTION
						local mat, sOcc, lOcc = determineVoxel(sample, wy)

						materials[xIdx][yIdx][zIdx] = mat
						solidOccupancy[xIdx][yIdx][zIdx] = sOcc
						liquidOccupancy[xIdx][yIdx][zIdx] = lOcc

						if lOcc > 0 then
							hasWaterInSlice = true
						end
					end
				end
			end

			if hasWaterInSlice then
				local channels = {
					SolidMaterial = materials,
					SolidOccupancy = solidOccupancy,
					LiquidOccupancy = liquidOccupancy,
				}
				local success, err = pcall(function()
					terrain:WriteVoxelChannels(region, RESOLUTION, channels)
				end)

				if not success then
					warn(
						string.format(
							"[TerrainGenerator] WriteVoxelChannels failed, falling back to WriteVoxels: %s",
							tostring(err)
						)
					)
					-- Fallback to standard WriteVoxels with Enum.Material.Water
					for vx = 1, countX do
						for vy = 1, totalVoxelsY do
							for vz = 1, countZ do
								if liquidOccupancy[vx][vy][vz] > 0 and solidOccupancy[vx][vy][vz] == 0 then
									materials[vx][vy][vz] = Enum.Material.Water
									solidOccupancy[vx][vy][vz] = liquidOccupancy[vx][vy][vz]
								end
							end
						end
					end
					terrain:WriteVoxels(region, RESOLUTION, materials, solidOccupancy)
				end
			else
				terrain:WriteVoxels(region, RESOLUTION, materials, solidOccupancy)
			end

			task.wait()
		end
	end
end

return TerrainGenerator
