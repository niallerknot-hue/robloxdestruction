# 003: Keep walkable ground solid

**Status:** review

**Goal:** Stop players' ground from being destroyed. Floors, foundations and plazas must never be destructible, so hitting a nearby building can't remove the ground under someone's feet.

**Bug:** In a playtest, the wooden platform the player stood on broke after a nearby building was hit. Nothing was left to stand on. The cause is in `src/server/VillageGenerator.luau`. The `createPart` helper always calls `DestructionEngine.RegisterDestructiblePart`, so walkable parts get the `Destructible` tag and take blast damage like walls do. Four walkable parts are affected:

- `TownSquareFloor` (60×1×60, 350 HP). This is the Town Square and the spawn area.
- `Foundation` (cottage base, 120 HP).
- `StoneBase` (shop base, 150 HP).
- `WoodFloor` (cottage floor, 50 HP).

Walls, roofs, doors and props should stay destructible.

## Files allowed to change

- `src/server/VillageGenerator.luau`
- `AGENTS.md`, one rule line only (see step 4)
- `tasks/BOARD.md`
- `tasks/003-keep-walkable-ground-solid.md`, status line only
- `reports/003-keep-walkable-ground-solid.md` (new)

Don't change anything else. In particular, don't change `DestructionEngine.luau`, the purchase or save code, or the client files.

## Work

1. **Add a ground helper.** In `VillageGenerator.luau`, add `createGround(parent, size, cf, color, material, name)`. It should build the same part `createPart` builds: same name, size, CFrame, colour, material, `Anchored = true`, `CanCollide = true`, and the same surface settings. Don't call `DestructionEngine.RegisterDestructiblePart`, and don't add the `Destructible` tag. Keep the code style of `createPart`.
2. **Switch the four walkable parts to `createGround`.** Change `TownSquareFloor`, `Foundation`, `StoneBase` and `WoodFloor`. Change nothing else about those parts: same size, position, colour and material.
3. **Look for others.** Check the rest of `VillageGenerator.luau` for any other part a player can walk on, such as stairs, ramps, plazas, decks or landings. Convert any you find, and list each one in the report. The well (`VillageWellBasin`, `WellCanopy`) and the walls stay destructible.
4. **Add one rule to `AGENTS.md`.** Under "Code rules", add: "Surfaces players can walk on (floors, foundations, plazas) are never destructible. Create them without registering them with DestructionEngine." Don't change anything else in AGENTS.md.
5. **Check the result with grep.** Confirm that `createGround` is used for the four named parts, and that no walkable part name still goes through `createPart`.
6. **Run `scripts/validate.ps1`** with the Rokit tools on the PATH for that process only:
   `$env:Path = "$env:USERPROFILE\.rokit\bin;" + $env:Path`
   Then: `powershell -ExecutionPolicy Bypass -File scripts/validate.ps1`
   All gates must pass.

## Acceptance criteria

- [ ] No part a player can walk on is registered with DestructionEngine or tagged `Destructible`.
- [ ] Walls, roofs, doors, the well and props are still destructible.
- [ ] The four named parts keep the same size, position, colour and material as before.
- [ ] `scripts/validate.ps1` passes all gates.
- [ ] The report lists each walkable part you converted, with its file and line.

## Studio test checklist (copy into the report)

The village is regenerated when the server starts. To test this change, press Stop and then Play, so the new code runs.

1. Stand on the Town Square. Hit the nearby buildings 20 or more times. The square's floor stays, and you stay standing.
2. Hit the walls of the cottage closest to spawn until some of them break. The cottage floor and foundation stay, and you can still walk inside.
3. Hit the walls of a shop until some of them break. The shop's base stays, and you can still walk in.
4. Output shows no errors while doing the above.

## Notes

- Don't commit or push. The orchestrator reviews and commits.
- Follow AGENTS.md: `--!strict` on line 1, `task.*` functions only, tabs for indentation.
- If you're blocked, finish the parts you can and explain the blocker in the report.
