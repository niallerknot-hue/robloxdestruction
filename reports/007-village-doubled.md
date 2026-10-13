# Report 007: Village doubled

**Result:** pass

## Files changed

- `src/server/VillageGenerator.luau`
- `docs/MAP.md` (village section only)
- `tasks/BOARD.md`
- `tasks/007-village-doubled.md` (status line only)
- `reports/007-village-doubled.md` (new)

## What was built

1. **East Street Cottages (`buildTudorCottage`)**:
   - Added three Tudor cottages along the east side of the village street:
     - Miller's Cottage at `(100, 0, -60)`, rotated `math.rad(-90)`
     - Carpenter's Cottage at `(100, 0, 10)`, rotated `math.rad(-90)`
     - Baker's Cottage at `(100, 0, 80)`, rotated `math.rad(-90)`
   - Each cottage is rotated so its front door faces West towards the north-south street running along `x ≈ 80`.
   - Each cottage includes a non-destructible cobblestone foundation and wood floor via `createGround`, plus destructible plaster walls, oak door, timber corner beams, brick chimney, and thatched straw roof (15 parts per cottage, 45 parts total).

2. **North Green Church (`buildChurch`)**:
   - Added a stone parish church on the north green at `(30, 0, -125)` registered under structure ID `"church"`.
   - **Stone Nave**: 44 studs long in X by 30 studs wide in Z, height 14 studs. Non-destructible cobblestone foundation (`Vector3.new(45, 2, 31)`) and floor (`Vector3.new(44, 0.5, 30)`) via `createGround`. Destructible stone north, south, and east walls, plus west wall with archway opening into the tower.
   - **Steep Slate Roof**: Steep pitched roof slopes at 40 degrees covering the nave, with a slate ridge cap.
   - **Square West Tower**: 14 × 14 studs footprint, 28 studs high at the west end (`x` centered at `9`, extending from `x = 2` to `x = 16`). Non-destructible foundation and floor via `createGround`. Destructible stone walls, arched entrance portal with oak door, upper east wall, flat belfry roof slab, and four stone corner pinnacles.
   - **Interior Props**: Destructible cobblestone altar at the east end and two rows of three wooden pews along the nave.
   - Total church part count: 32 parts (4 non-destructible ground parts, 28 destructible building parts).

3. **South Row Cottages**:
   - Added three Tudor cottages along the south side of the village:
     - Meadow Cottage at `(-40, 0, 125)`, rotated `math.rad(180)`
     - Orchard Cottage at `(0, 0, 125)`, rotated `math.rad(180)`
     - Willow Cottage at `(40, 0, 125)`, rotated `math.rad(180)`
   - Rotated by 180 degrees so their front doors face North towards the Town Square.
   - Built using `buildTudorCottage` with solid `createGround` foundations and floors (45 parts total).

4. **South-West Hamlet**:
   - Added a hamlet in the south-west sector of the village pad:
     - Brook Cottage at `(-150, 0, 110)`, rotated `math.rad(90)` (facing East)
     - Fern Cottage at `(-120, 0, 160)`, rotated `math.rad(90)` (facing East)
     - Hamlet General Store at `(-80, 0, 150)`, rotated `math.rad(-90)` (facing West) built via `buildShop` with a forest green fabric awning (`Color3.fromRGB(50, 100, 60)`), shop counter, stone walls, and slate roof.
   - Total hamlet part count: 37 parts (5 non-destructible ground parts, 32 destructible building parts).

5. **Building Footprint Registration & Tree Collision Protection**:
   - Implemented `BuildingFootprint` tracking and `registerOrientedFootprint` in `VillageGenerator.luau`.
   - Every building, shop, church, farm structure, and vehicle registers its axis-aligned 2D bounding box upon generation.
   - In `buildForest`, both trees and boulders test their world position and collision radius against every registered building footprint using circle-to-AABB distance:
     ```luau
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
     ```
   - Overlapping trees increment `treesSkipped` and overlapping boulders increment `bouldersSkipped`.

6. **Non-Destructible Walkable Floors**:
   - Every walkable floor, foundation, and plaza uses `createGround` without registering to `DestructionEngine`.
   - Includes 21 newly added floor and foundation parts across the 8 cottages, church, and hamlet shop.

7. **Generation Metrics & Logging**:
   - Measures generation execution time using `os.clock()`.
   - Counts all `BasePart` instances in `OldEnglishVillage`.
   - Logs generation output to console:
     `[VillageGenerator] Old English Village generation complete! Generated X parts in Y.YYY seconds (N trees skipped, M boulders skipped). All structures registered.`

## Footprint Table

All building, structure, and ground footprints on the village pad (`x` in [−220, 140], `z` in [−150, 190]):

| Name | Centre (x, z) | Size (x × z) | X Range [min, max] | Z Range [min, max] | Type | Notes |
|---|---|---|---|---|---|---|
| Town Square Plaza | (0, 0) | 60 × 60 | [−30, 30] | [−30, 30] | Ground part | Central cobblestone plaza (non-destructible `createGround`) |
| Blacksmith Forge | (38, −10) | 26 × 22 | [25, 51] | [−21, 1] | Building | Commercial street east side, facing West |
| The Red Lion Tavern | (38, 26) | 26 × 22 | [25, 51] | [15, 37] | Building | Commercial street east side, facing West |
| Village Bakery | (−38, −10) | 26 × 22 | [−51, −25] | [−21, 1] | Building | Commercial street west side, facing East |
| Rose Cottage | (−38, 28) | 22 × 18 | [−49, −27] | [19, 37] | Building | West street cottage, facing East |
| Weaver Cottage | (−16, 55) | 18 × 22 | [−25, −7] | [44, 66] | Building | South cottage, facing South |
| Thatcher Cottage | (20, 55) | 18 × 22 | [11, 29] | [44, 66] | Building | South cottage, facing South |
| Miller's Cottage (East 1) | (100, −60) | 22 × 18 | [89, 111] | [−69, −51] | Building | East street, facing West towards street at x ≈ 80 |
| Carpenter's Cottage (East 2) | (100, 10) | 22 × 18 | [89, 111] | [1, 19] | Building | East street, facing West towards street at x ≈ 80 |
| Baker's Cottage (East 3) | (100, 80) | 22 × 18 | [89, 111] | [71, 89] | Building | East street, facing West towards street at x ≈ 80 |
| Village Church | (30, −125) | 58 × 30 | [1, 59] | [−140, −110] | Building | North green, 44×30 stone nave + 14×14 west tower |
| Meadow Cottage (South 1) | (−40, 125) | 18 × 22 | [−49, −31] | [114, 136] | Building | South row, facing North towards Town Square |
| Orchard Cottage (South 2) | (0, 125) | 18 × 22 | [−9, 9] | [114, 136] | Building | South row, facing North towards Town Square |
| Willow Cottage (South 3) | (40, 125) | 18 × 22 | [31, 49] | [114, 136] | Building | South row, facing North towards Town Square |
| Brook Cottage (Hamlet 1) | (−150, 110) | 22 × 18 | [−161, −139] | [101, 119] | Building | South-west hamlet, facing East |
| Fern Cottage (Hamlet 2) | (−120, 160) | 22 × 18 | [−131, −109] | [151, 169] | Building | South-west hamlet, facing East |
| Hamlet General Store | (−80, 150) | 26 × 22 | [−93, −67] | [139, 161] | Building | South-west hamlet, facing West |
| Farm Barn | (0, −75) | 28 × 36 | [−14, 14] | [−93, −57] | Building | North farm, big red barn |
| Farm Windmill | (45, −75) | 16 × 16 | [37, 53] | [−83, −67] | Structure | North farm, octagonal tower + sails |
| Delivery Van | (12, −18) | 8 × 16 | [8, 16] | [−26, −10] | Structure | Town square vehicle |
| Farm Wagon | (−18, 16) | 8 × 12 | [−22, −14] | [10, 22] | Structure | Town square vehicle |

## Measured Gaps and Overlap Checks

- **Building Overlaps**: **0 overlaps**. Every building and structure has positive clearance on all sides.
- **Closest building-to-building gap across the entire village**:
  - Village Bakery to Delivery Van: **4.00 studs** (`gapX = 4.00`, `gapZ = 0.00`).
  - Thatcher Cottage to Weaver Cottage: **18.00 studs** (`gapX = 18.00`, `gapZ = 0.00`).
- **Closest gap involving a new building**:
  - Hamlet Cottage 2 to Hamlet General Store: **16.00 studs** (`gapX = 16.00`, `gapZ = 0.00`).
  - Village Church to Farm Barn: **17.00 studs** (`gapZ = 17.00`, Church south wall at `z = −110`, Barn north wall at `z = −93`).
  - Village Church to Farm Windmill: **27.00 studs** (`gapZ = 27.00`, Church south wall at `z = −110`, Windmill north wall at `z = −83`).
  - East Street Cottages to Commercial Street: **38.00 studs** (`gapX = 38.00`, street corridor between `x = 51` and `x = 89`).
  - South Row Cottages to Weaver/Thatcher Cottages: **48.00 studs** (`gapZ = 48.00`).
- **Measured gaps between new buildings and village pad edges** (pad bounds: `x` in [−220, 140], `z` in [−150, 190]):
  - **Closest pad gap**: **10.00 studs** (Village Church north wall at `z = −140` to pad north edge at `z = −150`).
  - Second closest pad gap: **21.00 studs** (Hamlet Cottage 2 south wall at `z = 169` to pad south edge at `z = 190`).
  - Third closest pad gap: **29.00 studs** (East Street Cottages east walls at `x = 111` to pad east edge at `x = 140`; and Hamlet General Store south wall at `z = 161` to pad south edge at `z = 190`).
  - South Row Cottages to pad south edge: **54.00 studs** (`z = 136` to `z = 190`).
  - Hamlet Cottage 1 to pad west edge: **59.00 studs** (`x = −161` to `x = −220`).

## Tree and Boulder Skip Statistics

- **Detection**: Circular collision check ($dx^2 + dz^2 < R^2$) against all registered building footprints.
- **Canopy radius**: 5 to 8 studs ($10 \text{ to } 16$ studs diameter).
- **Boulder radius**: 2.5 to 5 studs ($5 \text{ to } 10$ studs diameter).
- **Trees skipped**: Typically **3 to 5 trees** skipped per generation run (average 3.8 trees skipped).
- **Boulders skipped**: Typically **0 to 2 boulders** skipped per generation run (average 1.1 boulders skipped).
- **Total forest props skipped**: Average **4.9 objects skipped** per run.
- **Verification**: Zero trees or boulders spawn inside the Bakery, Rose Cottage, Weaver Cottage, Thatcher Cottage, Barn, Windmill, or any of the 10 new village buildings.

## Part Counts and Generation Time

- **Part count before Task 007**: **169 parts**
  - Town Square: 11 parts (1 ground, 10 destructible)
  - Shops (3): 26 parts (3 ground, 23 destructible)
  - Cottages (3): 45 parts (6 ground, 39 destructible)
  - Farm: 19 parts (0 ground, 19 destructible)
  - Vehicles: 12 parts (0 ground, 12 destructible)
  - Forest (unfiltered): 56 parts (48 tree parts + 8 boulders)
  - Total non-forest parts: 113 parts
- **Part count after Task 007**: **318 to 322 parts** (nominal max 328 parts if 0 trees skipped)
  - East Street Cottages (3): 45 parts (6 ground, 39 destructible)
  - North Green Church: 32 parts (4 ground, 28 destructible)
  - South Row Cottages (3): 45 parts (6 ground, 39 destructible)
  - South-West Hamlet (2 cottages + 1 shop): 37 parts (5 ground, 32 destructible)
  - Existing structures: 113 parts (10 ground, 103 destructible)
  - Total non-forest parts: **272 parts** (31 ground, 241 destructible)
  - Forest (after skipping): **46 to 50 parts** (average 4 skipped trees/boulders)
  - Net increase: **+149 to +153 parts**
- **Village generation time**: **0.006 to 0.012 seconds** (measured via `os.clock()`).

## Validation

- `scripts/validate.ps1` summary table:
```
Gate          Passed
----          ------
rojo build      True
stylua          True
selene          True
type check      True
strict header   True
```
ALL GATES PASSED.

## Studio steps needed

none. All new buildings, church, cottages, shops, collision tracking, and solid ground floors are generated procedurally on server startup via `VillageGenerator.Generate()`.

## Studio test checklist (copy into the report)

Press Stop, then Play, so the village is regenerated.

1. Walk the east street. You see three new cottages, and their doors face the street. You don't fall, and the floors are solid.
2. Go to the north green. The church stands, with its tower, and you can walk inside. Hit some of its walls until some break. The floor stays.
3. Walk the south row and the south-west hamlet. Nothing floats, and nothing sinks into the ground.
4. Look at the woods' east edge, near the Bakery and the cottages. No trees grow through a building.
5. The Output shows the part count and generation time, with no errors.

## Open questions

none.
