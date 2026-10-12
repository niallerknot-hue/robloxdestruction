# Report 003: Keep walkable ground solid

**Result:** pass

## Files changed

- `src/server/VillageGenerator.luau`
- `AGENTS.md`
- `tasks/BOARD.md`
- `tasks/003-keep-walkable-ground-solid.md`
- `reports/003-keep-walkable-ground-solid.md`

## What was built

1. **Ground Helper Function (`createGround`)**:
   Added `createGround(parent, size, cf, color, material, name): Part` in `src/server/VillageGenerator.luau` (lines 37–57). It constructs parts with the exact same visual and collision properties (`Anchored = true`, `CanCollide = true`, smooth top/bottom surface) as `createPart`, but without calling `DestructionEngine.RegisterDestructiblePart` and without adding the `Destructible` tag.

2. **Converted Walkable Parts**:
   Converted all 4 walkable surface parts across the village to `createGround`, ensuring floors, foundations, and plazas remain permanent, solid ground that never takes damage or unanchors:
   - `Foundation` (cottage stone foundation): `src/server/VillageGenerator.luau`, lines 74–81
   - `WoodFloor` (cottage interior floor): `src/server/VillageGenerator.luau`, lines 84–91
   - `StoneBase` (shop foundation base): `src/server/VillageGenerator.luau`, lines 246–253
   - `TownSquareFloor` (spawn cobblestone plaza): `src/server/VillageGenerator.luau`, lines 604–611

   A complete audit of `VillageGenerator.luau` confirmed no other walkable surfaces (stairs, ramps, decks, landings) exist; walls, roofs, doors, the well (`VillageWellBasin`, `WellCanopy`), and props remain fully destructible via `createPart`.

3. **Code Rule Added to `AGENTS.md`**:
   Added the following rule under "Code rules":
   `- Surfaces players can walk on (floors, foundations, plazas) are never destructible. Create them without registering them with DestructionEngine.`

## Validation

- `scripts/validate.ps1` summary table:
```
== rojo build
Building project 'DestructionVillage'
Built project to game.rbxl
== stylua
== selene
Results:
0 errors
0 warnings
0 parse errors
== type check
Created sourcemap at build/sourcemap.json
[INFO] Loading definitions file: @roblox - build/globalTypes.d.luau
[WARN] client does not allow didChangeWatchedFiles registration - automatic updating on sourcemap changes disabled
== strict header
== tests
   no test runner set up yet (skipped, not counted)

== summary

Gate          Passed
----          ------
rojo build      True
stylua          True
selene          True
type check      True
strict header   True



ALL GATES PASSED
```

- Grep verification:
  Confirmed that `TownSquareFloor`, `Foundation`, `StoneBase`, and `WoodFloor` are created using `createGround`, and no walkable parts are registered with `createPart`.

## Studio test checklist (copy into the report)

The village is regenerated when the server starts. To test this change, press Stop and then Play, so the new code runs.

1. Stand on the Town Square. Hit the nearby buildings 20 or more times. The square's floor stays, and you stay standing.
2. Hit the walls of the cottage closest to spawn until some of them break. The cottage floor and foundation stay, and you can still walk inside.
3. Hit the walls of a shop until some of them break. The shop's base stays, and you can still walk in.
4. Output shows no errors while doing the above.

## Studio steps needed

- none

## Open questions

- none
