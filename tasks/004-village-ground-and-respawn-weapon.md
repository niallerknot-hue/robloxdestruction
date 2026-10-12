# 004: Village ground and respawn weapon

**Status:** review

**Goal:** Give the whole village solid ground so players don't fall off the edge, and make sure the sledgehammer is always in the backpack after a spawn or respawn.

**Bug 1: no ground in most of the village.** `src/server/VillageGenerator.luau` builds ground only for the Town Square (`TownSquareFloor`), the cottage foundations and floors, and the shop bases. The farm (centre around z = -75, with the barn and windmill), the woods (centre around x = -95, with the trees) and the vehicle area have no floor at all. Players walk off the edge and fall.

**Bug 2: sledgehammer missing after a respawn.** After a respawn, the player had no hammer. `src/server/init.server.luau` gives the tool with `equipPlayer`, which calls `player:WaitForChild("Backpack", 5)` and then `ShopServer.GivePlayerWeaponTool`. Nothing checks afterwards that the tool is really in the current backpack. The cause hasn't been confirmed yet. One likely explanation is that the tool goes into a backpack that Roblox replaces during the respawn.

## Files allowed to change

- `src/server/VillageGenerator.luau`
- `src/server/init.server.luau`
- `tasks/BOARD.md`
- `tasks/004-village-ground-and-respawn-weapon.md`, status line only
- `reports/004-village-ground-and-respawn-weapon.md` (new)

Don't change anything else.

## Work

1. **Add one large ground slab for the village.** Use `createGround` from task 003, so the ground isn't destructible. Name it `VillageGround`. Make it grass-coloured with `Enum.Material.Grass`. Its top surface should sit at y = 0. Cover a rectangle that includes the Town Square, the shops, the cottages, the farm, the woods and the vehicle area. A rectangle from about x = -190 to x = 90 and z = -130 to z = 90 should do it, but check the builder extents and adjust if needed. Parent it to `villageFolder`, and build it inside `VillageGenerator.Generate` before the other buildings.
2. **Check nothing sinks into the slab.** The Town Square floor, the cottage foundations and the shop bases should still sit on top of it. Walls, roofs and props should keep their current positions. Make no other geometry changes.
3. **Make sure the weapon is in the backpack.** In `equipPlayer`, after giving the weapon, check that the tool's parent is the current backpack, and that the backpack is the one parented to the player. If the tool is missing, wait one frame with `task.wait()`, then give it again. If it's still missing, log a `warn` with the player's name and UserId. Keep the existing aura handling.
4. **Log the backpack wait.** If `WaitForChild("Backpack", 5)` times out, the existing warn stays. Don't add any other logging.

## Acceptance criteria

- [ ] One `VillageGround` slab is created with `createGround`, so it isn't destructible.
- [ ] The Town Square, cottages, shops and walls keep their positions, and nothing sinks into the slab.
- [ ] `equipPlayer` checks the tool after giving it, retries once, and warns if the tool is still missing.
- [ ] `scripts/validate.ps1` passes all gates.
- [ ] The report lists what changed, with file and line for each change.

## Studio test checklist (copy into the report)

The village is regenerated when the server starts, so press Stop and then Play before testing.

1. Walk from the Town Square to the farm, the woods and the vehicle area. You don't fall at any point.
2. Walk into the barn and the windmill area. The ground is solid.
3. Die and respawn three times. The sledgehammer is in the hotbar every time.
4. Hit buildings close to the Town Square. The ground stays.
5. Output shows no errors. A `[Server]` warning appears only if the backpack or tool really is missing.

## Notes

- Don't commit or push. The orchestrator reviews and commits.
- Follow AGENTS.md: `--!strict` on line 1, `task.*` functions only, tabs for indentation.
- If you're blocked, finish the parts you can and explain the blocker in the report.

## Round 2 (weapon only) — ON HOLD, do not do unless the first-spawn test fails

Round 3 below replaces this round. Gemini's Studio run found the cause of the first-spawn loss: `CharacterAdded` can fire before the character is in `workspace`. The old `onCharacterSpawned` then returned without giving a weapon, and it logged nothing. The wait for `workspace` now in `onCharacterSpawned` fixes that. The StarterGear change and the `[Weapon]` logs below are only needed if the first-spawn test in Studio still loses the hammer.

Round 1 is accepted for the ground slab. Don't change `VillageGround` or anything else in `VillageGenerator.luau`.

The round 1 weapon check only covers the moment right after the weapon is given. It does nothing if Roblox replaces the Backpack later, so the sledgehammer can still disappear without a warning. Round 2 fixes this with Roblox's own mechanism for starting tools: `player.StarterGear`. Roblox copies the tools in StarterGear into the Backpack every time the character spawns, so the weapon comes back on every respawn even if the old Backpack is replaced.

Files allowed in round 2: `src/server/ShopServer.luau` (the `GivePlayerWeaponTool` function only), `src/server/init.server.luau` (`equipPlayer` only), `tasks/BOARD.md`, the spec status line, and the report.

- **R1. Keep the equipped weapon in StarterGear.** In `GivePlayerWeaponTool`, after the new weapon Tool is created, also put a clone of it into `player.StarterGear`. First remove any existing Tool in StarterGear that has the `IsDestructionWeapon` attribute, so only one weapon tool is there. Keep everything else in the function as it is.
- **R2. Keep `equipPlayer`'s give-and-check.** Keep the give, the check and the single retry that round 1 added. Their job is to catch the problem when it happens. StarterGear handles the rest.
- **R3. Add a check that StarterGear has the weapon.** In `equipPlayer`, after the give, log a `warn` if `player.StarterGear` has no Tool with the `IsDestructionWeapon` attribute. The message should say `[Server] StarterGear missing weapon for <name> (<UserId>)`. This is for diagnosis only, so keep the warn simple.
- **R4. Document the fix.** The report must say which Roblox behaviour the fix relies on, and say that it hasn't been confirmed in Studio yet. Do this in "What was built" and in the Studio checklist.
- **R5. Diagnostic logging for the weapon (temporary).** The hammer is missing from the first spawn, not only after a respawn. StarterGear is empty until the first give, so R1 may not fix a first-spawn loss. Add these logs so the Output shows what happens to the hammer:
  1. In `GivePlayerWeaponTool`, print `[Weapon] give <weaponId> to <player.Name>` each time it runs.
  2. Each time `GivePlayerWeaponTool` destroys an old weapon Tool, print `[Weapon] removed old <tool.Name> from <where>`, where `<where>` is `backpack` or `character`, and print `debug.traceback()` in the same call so the Output shows the caller.
  3. In `equipPlayer`, print `[Weapon] equipPlayer start for <player.Name>`, then whether the Backpack and the character exist.
  4. In `equipPlayer`, connect `backpack.ChildRemoved` once per Backpack instance (track connected Backpacks in a weak-keyed table, as CombatController does for tools). The handler prints `[Weapon] removed from backpack: <child.Name>` and `os.clock()`.
  5. Prefix every new log line with `[Weapon]`. The report must list each log line, and say that they are temporary.
- **R6. Do not remove the existing warns.** Keep the round 1 warns and the R3 StarterGear warn. Don't change any other behaviour.

Round 2 acceptance criteria:

- [ ] The weapon is in both the Backpack and `player.StarterGear` after each give.
- [ ] Only one weapon Tool is in StarterGear at any time.
- [ ] `scripts/validate.ps1` passes all gates.
- [ ] Round 1's `VillageGround` is unchanged.
- [ ] Every diagnostic line from R5 is present, starts with `[Weapon]`, and is listed in the report.

## Round 3 (replaces round 2)

Files allowed in round 3: `src/server/init.server.luau`, `reports/004-village-ground-and-respawn-weapon.md`, `reports/002-harden-saves-and-purchases.md`, `tasks/BOARD.md`, and the status line of this spec.

Don't add the StarterGear change or the `[Weapon]` logs from round 2. Don't change `VillageGround`, the workspace wait, or any other behaviour.

- **R1. Warn when the character never reaches workspace.** In the first `while` loop of `onCharacterSpawned`, when the 5-second timeout passes, print `warn(string.format("[Server] Character never reached workspace for %s (%d)", player.Name, player.UserId))` before the `return`. This is the only code change in this round.
- **R2. Label the Studio results honestly.** In the Studio results of reports 004 and 002, label each item as one of these, and keep the results as they are:
  - **live**: run in Play mode by pressing keys or clicking.
  - **teleport**: the character was moved by a script, not walked.
  - **code check**: the result came from reading code, not from running it.
  - **simulated**: a function was called directly from the command bar, not through a real purchase or a real player action.
  Report 004 item 1 is a teleport. Report 002 item 3 is a code check. Report 002 item 5 is simulated, because the DevProduct IDs are still placeholders and no real receipt was made. Check every other item the same way. Report 002 item 1 says the player smashed fences. The village code builds no fences, and the user didn't see any in Studio, so remove that claim or mark it as unverified.
- **R3. Say whether the first-spawn test was run.** Report 004 must say whether checklist item 0 (first spawn) was run in Studio. If it wasn't, say so. The reported bug was at first spawn, not respawn.
- **R4. Describe the root cause.** In report 004's "What was built", describe the root cause in the terms above: `CharacterAdded` fires before the character is in `workspace`, and the old code returned silently at that point. Note that the earlier backpack-replacement theory was not the cause.

Round 3 acceptance criteria:

- [ ] R1 warn is present, with the exact text above.
- [ ] Studio results in reports 002 and 004 are labelled live, teleport, code check or simulated.
- [ ] Report 004 says whether the first-spawn test was run.
- [ ] `scripts/validate.ps1` passes all gates.

Studio test checklist for round 2 (add to the report, and run it after the round 1 checklist):

0. First spawn. Press Play. As soon as you spawn, check the Backpack and the hotbar, and copy every `[Weapon]` and `[Server]` line from the Output. Put the copied lines in the report.
1. Die and respawn. The hammer is in the hotbar.
2. Run `game.Players:GetPlayers()[1].StarterGear:GetChildren()` in the command bar while playing. It should list one Tool, the equipped weapon.
3. Buy a different weapon. StarterGear should now list only that weapon, and the hammer should be gone from it.
4. Die and respawn after step 3. The new weapon should be in the hotbar.
