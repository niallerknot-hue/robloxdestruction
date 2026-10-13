# 006: Map plan and terrain

**Status:** review

**Goal:** Replace the flat village slab with a real map. Write down the map plan, then generate the terrain in code: a flat village pad, hills, a river, a lake and a raised castle plateau. This task only builds the landscape. It doesn't build the new houses, the castle or the boats. Those come in later tasks.

**Why terrain in code:** Roblox Terrain can hold hills and water, and terrain can't be destroyed, so it works as ground. Generating it in code means the map is repeatable and kept in version control, and the layout numbers stay in one place.

## Map plan (write this into `docs/MAP.md`)

All coordinates are in studs. The village stays where it is, on a flat pad at y = 0. The features below are proposals, and the numbers can change later.

| Zone | Shape and position | Notes |
|---|---|---|
| Village pad | x −220 to 140, z −150 to 190, flat at y = 0 | Doubles the old village footprint. Everything from the old village stays on this pad. Edges blend into the land outside over 20 studs. |
| River | Runs north to south along the west edge, centre x ≈ −280, width 24 | Outside the pad. Surface at y = −2, channel floor at y = −6. A dock will go on the pad edge at (−215, 40) in a later task. |
| North-east hills | Centre (250, −200), radius 130, height 40 above the land | Rolling hills. They can overlap the north-east corner of the pad, but the pad stays flat. |
| Castle plateau | Centre (400, 0), radius 70, top at y = 35 | Sloped sides, flat top. The castle and the second market town go here, in a later task. |
| Lake | Centre (180, 280), radius 70 | Surface at y = −2, basin floor at y = −10. A boathouse will go on the north shore in a later task. |

Overall map bounds: x −300 to 480, z −340 to 360.

## Files allowed to change

- `docs/MAP.md` (new)
- `src/server/TerrainGenerator.luau` (new)
- `src/server/VillageGenerator.luau`, only to remove the `VillageGround` slab call
- `src/server/init.server.luau`, only to call the terrain generator before the village is built
- `tasks/BOARD.md`
- `tasks/006-map-plan-and-terrain.md`, status line only
- `reports/006-map-plan-and-terrain.md` (new)

Don't change anything else.

## Work

1. **Write `docs/MAP.md`.** Put in the table above, plus the overall bounds and one line per zone saying which later task will build on it.
2. **Write `TerrainGenerator.luau`.** Generate the terrain with `workspace.Terrain:WriteVoxels`, using the 4-stud grid. Facts from Roblox's documentation:
   - The resolution must be exactly 4.
   - The region must line up with the grid, from `Region3:ExpandToGrid(4)`.
   - The material and occupancy arrays must match the region's voxel dimensions exactly.
   - A single call can't exceed 4,194,304 voxels, so write in slices of about 40 × 40 × 40 voxels, with `task.wait()` between slices so the server doesn't freeze.
3. **Shape the height.** Use one height function for the whole map:
   - On the village pad, the height is exactly 0. The pad edges blend over 20 studs.
   - Outside the pad, use gentle ground noise from `math.noise`, roughly 6 studs of variation.
   - Add the north-east hills and the castle plateau as smooth bumps, using the centres, radii and heights in the table.
   - Carve the river channel and the lake basin, using the positions in the table.
4. **Put water in the liquid channel.** Roblox's documentation says water is no longer a solid material. It's stored in the `LiquidOccupancy` channel, written with `WriteVoxelChannels` (set `SolidMaterial` to `Air` and `LiquidOccupancy` to the water amount). Use this for the river and the lake, at the surface levels in the table. If `WriteVoxelChannels` doesn't work as the reference describes, stop and say so in the report.
5. **Materials.** Use grass on the surface and dirt underneath. Use rock on steep slopes and sand at the water's edge. Keep it simple: a few materials are enough.
6. **Remove the old slab.** Remove the `VillageGround` call from `VillageGenerator.Generate`. The terrain replaces it.
7. **Call the generator first.** In `init.server.luau`, call `TerrainGenerator` before `VillageGenerator.Generate()`. Print one line with the time it took.

## Acceptance criteria

- [ ] `docs/MAP.md` lists every zone with the coordinates above.
- [ ] `TerrainGenerator.luau` builds a flat village pad at y = 0, with the hills, the river, the lake and the castle plateau.
- [ ] The river and the lake are water, written through the liquid channel.
- [ ] The `VillageGround` slab is removed.
- [ ] Terrain is not destructible. It isn't a `BasePart`, so this holds by default. Check that no destruction code touches it.
- [ ] `scripts/validate.ps1` passes all gates.
- [ ] The report says which Roblox facts were used and which are still untested (replication and water).

## Studio test checklist (copy into the report)

Press Stop, then Play, so the terrain is generated when the server starts.

1. Walk across the village pad. You don't fall, and the ground is flat.
2. Walk up the north-east hills. The slopes are smooth, with no walls.
3. Find the river on the west edge and the lake in the south-east. Both show as water.
4. Look east at the castle plateau. It rises above the land, with a flat top.
5. In the Test tab, set the number of players to 2, if Studio offers that. The second player should see the same hills and water. This checks whether terrain written by the server replicates. Roblox's documentation doesn't settle this.
6. Output shows the terrain generation time, with no errors.

## Notes

- Don't commit or push. The orchestrator reviews and commits.
- Follow AGENTS.md: `--!strict` on line 1, `task.*` functions only, tabs for indentation.
- If you're blocked, finish the parts you can and explain the blocker in the report.

## Round 2 (after the Studio test)

Round 1 is accepted for the village pad, the hills, the castle plateau, the water in the liquid channel, and removing the slab. The changes below are required.

Files allowed in round 2: `docs/MAP.md`, `src/server/TerrainGenerator.luau`, `src/server/init.server.luau` (the character loading lines only), `reports/006-map-plan-and-terrain.md`, `tasks/BOARD.md`, and the status line of this spec.

- **R1. River route.** Replace the straight river with a river that follows this centreline. Visit these points in order, as x and z in studs:
  (−290, −330), (−285, −150), (−270, 0), (−250, 120), (−215, 230), (−120, 245), (0, 245), (120, 235), (230, 150), (300, 80), (340, 120), (300, 200).
  The last point is inside the lake. The river runs west of the village, along its south side, between the village and the castle, down the castle's south-west side, and into the lake.
  - Carve the channel using the distance from each column to the nearest segment of that polyline. Keep the half-width of 12 and the bank of 8. The channel floor is at y = −6. The water surface is at y = −2, wherever the channel ground is below it.
  - The channel must not cut into the village pad (x −220 to 140, z −150 to 190). Check this for every segment near the pad, and say in the report that you checked it.
- **R2. Move the lake.** Move the lake centre from (180, 280) to (300, 200). The radius stays at 70, the surface stays at −2, and the basin floor stays at −10. The river must end inside the lake, so the two are connected.
- **R3. Update `docs/MAP.md`.** Update the river and lake rows. Check that the overall bounds (x −300 to 480, z −340 to 360) still contain everything.
- **R4. Hold character loading until the terrain is ready.** In `init.server.luau`, before `TerrainGenerator.Generate()`, set `Players.CharacterAutoLoads = false`. When terrain generation finishes, set it back to `true`, and call `LoadCharacter()` for every player who doesn't have a character yet. Check Roblox's documentation for `CharacterAutoLoads` and `LoadCharacter` before you write this, and cite the source in the report. Change nothing else about spawning.

Round 2 acceptance criteria:

- [ ] The river follows all 12 points, in order, and its channel is carved along every segment.
- [ ] The lake is at (300, 200), and the river ends inside it.
- [ ] The channel doesn't cut into the village pad.
- [ ] Characters load only after the terrain is generated.
- [ ] `scripts/validate.ps1` passes all gates.

Round 2 Studio checklist (add to the report, after the round 1 checklist):

1. Walk the river from its north-west end down the west edge of the village. Water runs the whole way.
2. The river runs along the south side of the village, then turns east.
3. The river passes between the village and the castle, then down the castle's south-west side.
4. The river flows into the lake. The river and the lake share one water surface, with no step or gap.
5. Spawn while the map is generating. The character doesn't spawn before the terrain exists.
6. Two-player test: the second player sees the same river and lake.
