# 007: Village doubled

**Status:** review

**Goal:** Fill the village pad with more of the village. The pad was already doubled in task 006 (x −220 to 140, z −150 to 190). Add an east street of cottages, a church on the north green, a row of cottages on the south side and a small hamlet in the south-west. Keep every existing building where it is.

**Why:** The village is still small, and the pad has room for the extra buildings. Trees in the woods also grow through building footprints, which task 004's review found. This task fixes that too.

## Existing footprints (from `VillageGenerator.luau`)

These stay where they are. Check the numbers against the code before you rely on them.

- Town Square at (0, 0).
- Shops: Blacksmith at (38, −10), Tavern at (38, 26), Bakery at (−38, −10).
- Cottages: Rose at (−38, 28), Weaver at (−16, 55), Thatcher at (20, 55).
- Farm centre at (0, −75), with the barn and windmill.
- Woods centre at (−95, 0), trees across roughly x −170 to −20 and z −75 to 75.
- Vehicles around the Town Square.

## Files allowed to change

- `src/server/VillageGenerator.luau`
- `docs/MAP.md`, the village section only
- `tasks/BOARD.md`
- `tasks/007-village-doubled.md`, status line only
- `reports/007-village-doubled.md` (new)

Don't change anything else. Don't change the terrain, the river, the lake or the pad.

## Work

1. **East street cottages.** Add three cottages with `buildTudorCottage`, at about (100, −60), (100, 10) and (100, 80). Choose each rotation so the front faces the street, which runs north to south along x ≈ 80. Keep the same wall and roof style as the existing cottages.
2. **North green church.** Add a new `buildChurch(origin)` at about (30, −125). It should have a stone nave about 30 × 44 studs, a square tower on the west end, and a steep slate roof. Walls, tower and roof are destructible, and each is registered as part of one structure, "church". The nave floor is a `createGround` part, so it isn't destructible. Keep the church inside the pad, and away from the farm barn at x −15 to 15.
3. **South row.** Add three cottages at about (−40, 125), (0, 125) and (40, 125), facing north towards the Town Square.
4. **South-west hamlet.** Add two cottages at about (−150, 110) and (−120, 160), facing east, plus one small shop built with `buildShop`, at about (−80, 150).
5. **Keep trees out of buildings.** Keep a list of every building footprint as a rectangle, in code. Before a tree or boulder is placed in `buildForest`, check that its position and radius don't overlap any footprint, and skip it if they do. Use the same check for any new prop you add.
6. **Floors.** Every walkable floor, foundation and shop base uses `createGround` (task 003). Don't make any walkable surface destructible.
7. **Footprint table.** In `docs/MAP.md`, add a village section with a table of every footprint: name, centre, size, and whether it's a building, a structure or a ground part. In the report, give the measured gaps between the new buildings and the pad edge, and confirm there are no overlaps.

## Acceptance criteria

- [ ] Three cottages on the east street, two in the south-west hamlet, three on the south row, one church and one shop. Each has the footprint in the table.
- [ ] The new buildings don't overlap each other, the existing buildings, the farm, or the pad edge. The report gives the closest gap.
- [ ] No tree or boulder overlaps a building footprint. The report gives the count of trees that were skipped.
- [ ] Walkable floors use `createGround`. Walls, roofs and the church tower are destructible and registered to a structure.
- [ ] `scripts/validate.ps1` passes all gates.
- [ ] The report gives the part count before and after, and the village generation time.

## Studio test checklist (copy into the report)

Press Stop, then Play, so the village is regenerated.

1. Walk the east street. You see three new cottages, and their doors face the street. You don't fall, and the floors are solid.
2. Go to the north green. The church stands, with its tower, and you can walk inside. Hit some of its walls until some break. The floor stays.
3. Walk the south row and the south-west hamlet. Nothing floats, and nothing sinks into the ground.
4. Look at the woods' east edge, near the Bakery and the cottages. No trees grow through a building.
5. The Output shows the part count and generation time, with no errors.

## Notes

- Don't commit or push. The orchestrator reviews and commits.
- Follow AGENTS.md: `--!strict` on line 1, `task.*` functions only, tabs for indentation.
- If you're blocked, finish the parts you can and explain the blocker in the report.
