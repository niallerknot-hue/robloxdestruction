# 002: Harden saves and purchases

**Status:** review

**Goal:** Fix the data-loss, lost-purchase and spawn-race problems found in review of task 001, and add a Roblox-aware type check to validation so strict-mode errors fail the build.

**Context:** Task 001 is in review and not approved. Its changes are still uncommitted in the working tree. Build on them. Do not revert them. This task fixes problems in them.

## Files allowed to change

- `src/server/EconomyManager.luau`
- `src/server/ShopServer.luau`
- `src/server/init.server.luau`
- `src/server/DestructionEngine.luau`
- `src/client/CombatController.luau`
- `src/shared/Types.luau`, only to add the one field in B2
- `scripts/validate.ps1`
- `rokit.toml`
- `tasks/BOARD.md`
- `reports/002-harden-saves-and-purchases.md` (new)

Don't change anything else. In particular, leave these alone: `src/shared/Constants.luau`, `src/shared/ShopData.luau`, `src/shared/WeaponData.luau`, `default.project.json`, `stylua.toml`, `selene.toml`, `AGENTS.md`, `CLAUDE.md`, `src/client/UIController.luau`, `src/client/VFXController.luau`, `src/server/VillageGenerator.luau`, `src/server/CollisionManager.luau`.

## Work, in order

Do sections A to C first. Then D and E.

### A. Saves (`EconomyManager.luau`)

- **A1.** Never write a saved profile over data that didn't load. Track whether each player's load succeeded. If `GetAsync` still fails after retries, mark the profile as not loaded, and never call `SetAsync` for that player. A profile may be saved only after a successful load, or after a load that succeeded and returned no saved data (a new player).
- **A2.** Retry `GetAsync` and `SetAsync` up to 3 attempts, with backoff (for example 1 s, then 2 s, using `task.wait`). Use one shared retry helper for both.
- **A3.** Don't silently swallow DataStore errors. Log each failed attempt and each final failure with `warn`, prefixed `[EconomyManager]`, including the UserId and the error text. This also covers the `GetDataStore` call at startup, which currently fails silently. This is required by AGENTS.md.
- **A4.** Add `EconomyManager.IsLoaded(player: Player): boolean`. It returns true only when the player's profile is in memory and was loaded successfully or confirmed new.
- **A5.** If a player leaves while their profile is still loading, don't store the loaded profile afterwards. Check that the player is still in the game after the yield.
- **A6.** Fix a possible strict-mode type error. The `GetAsync` closure uses `playerDataStore`, which is a reassigned upvalue that was narrowed by an `if` outside the closure. Copy it into a local before the closure and check that local.

### B. Purchases (`ShopServer.luau`, `EconomyManager.luau`, `src/shared/Types.luau`)

- **B1.** `ProcessReceipt` must not return `PurchaseGranted` until the purchase has been saved. Required order:
  1. Player not in the server: return `NotProcessedYet`. This is already the case.
  2. `EconomyManager.IsLoaded(player)` is false: log a `warn` and return `NotProcessedYet`.
  3. The `PurchaseId` is already in the profile's `ProcessedReceipts`: return `PurchaseGranted`. Don't grant twice.
  4. Make a deep copy of the profile. Apply the grant to the copy. Add the `PurchaseId` to the copy's `ProcessedReceipts`. Save the copy with `SetAsync`, using the retry helper.
  5. Only if the save succeeds: replace the live profile with the copy, sync to the client, run the server-side effects (give tool, apply aura), and return `PurchaseGranted`.
  6. If the save fails after retries: log a `warn` and return `NotProcessedYet`. The live profile must be unchanged.

  Keep the copy, save and swap logic in `EconomyManager`, so `ShopServer` never edits `sessionData` directly. Express each grant as a change to a `PlayerData` table. That way the copy can be modified without touching live state. Deep-copy nested tables too, so nothing is shared with the live profile.
- **B2.** In `src/shared/Types.luau`, add one optional field to `PlayerData`: `ProcessedReceipts: { [string]: boolean }?`. Change nothing else in that file. Treat `nil` as an empty table, because existing saves don't have this field. This is the only shared-file change allowed.
- **B3.** For a `ProductId` that doesn't match any product, log a `warn` with the ProductId and return `NotProcessedYet`. Keep that behaviour, but make it visible.
- **B4.** Make the grant helpers report failure. `AddDollars` should return a boolean like the `Unlock*` functions do. `GrantRobuxPurchase` must fail if any step fails.
- **B5.** Dollar purchases and in-game purchases (`ProcessPurchase`) don't need an immediate save. Leave them as they are. Only the Robux path needs the save-before-grant behaviour.
- **B6.** After a skin is bought (`ProcessPurchase`, Skin branch) or granted by Robux (`GrantRobuxPurchase`, Skin branch), call `ShopServer.GivePlayerWeaponTool` with the equipped weapon. That makes the new skin appear on the held tool straight away. `ProcessEquip` already does this.

### C. Spawn race (`init.server.luau`, `EconomyManager.luau`)

- **C1.** Remove the fixed `task.wait(0.2)` followed by a read of the profile. Give the starting weapon and aura only once `EconomyManager.IsLoaded(player)` is true. Poll every 0.1 s, with a timeout of 15 s. If the timeout passes, give the default sledgehammer and log a `warn`. Stop waiting if the player leaves.
- **C2.** When a profile finishes loading, if the player's character is already in the world, give the saved weapon and aura then. This covers players whose character spawned before their data arrived. Choose the mechanism yourself, for example a `BindableEvent` fired by `EconomyManager`.
- **C3.** The weapon handed to the player must match `EquippedWeapon` in the profile. `DestructionEngine.ProcessAttack` uses that same field for damage, so there must be one source of truth.

### D. Attack validation and cleanup (`DestructionEngine.luau`, `CombatController.luau`)

- **D1.** In `ProcessAttack`, check `typeof(impactCFrame) == "CFrame"` before using it. Change the distance test to `if not (distance <= maxReach) then return end`, so a NaN position is rejected. A plain `>` check lets NaN through.
- **D2.** Validate before stamping the cooldown. Keep the rate-limit check where it is. Move `playerCooldowns[player] = now` to after the type and distance checks pass, so a malformed request doesn't use up the player's cooldown.
- **D3.** Clear `playerCooldowns` when players leave. In `DestructionEngine.Init`, connect `Players.PlayerRemoving` and set that player's entry to nil. Add `local Players = game:GetService("Players")` to the module.
- **D4.** In `CombatController.luau`, connect `tool.Activated` only once per tool instance. Track connected tools in a weak-keyed table, `setmetatable({}, { __mode = "k" })`. The current code connects again every time the tool is added to the character.

### E. Type-check gate (`scripts/validate.ps1`, `rokit.toml`)

- **E1.** Add `luau-lsp = "johnnymorganz/luau-lsp@1.70.1"` to `rokit.toml`, then run `rokit install`. If rokit asks you to trust the tool, stop and tell the user to run `rokit trust johnnymorganz/luau-lsp` in their own terminal. Continue once they confirm. Don't change trust settings yourself.
- **E2.** Generate a sourcemap into `build/`, which is git-ignored: `rojo sourcemap default.project.json -o build/sourcemap.json`.
- **E3.** Run `luau-lsp analyze` on `src`, passing the sourcemap from E2 with `--sourcemap PATH`. The 1.70.1 source confirms that flag. Run `luau-lsp analyze --help` on the installed binary to confirm the flags. Use the default formatter, so don't pass `--formatter`. The `luacheck` formatter always exits 0 and can't fail the gate. The default formatter exits 1 when it finds errors. Check that a directory argument works for `src`. If it doesn't, pass the `.luau` files explicitly. The Roblox API types come built in, according to the luau-lsp README.
- **E4.** Add a gate named `type check` to `scripts/validate.ps1`, in the same style as the other gates. Put it after the `selene` gate and before the `strict header` check. The gate runs the sourcemap step and then the analyzer. `Run-Gate` only reads the exit code of the last command in its script block, so check the sourcemap's exit code yourself. The gate must fail if either command fails. It fails on any error. Warnings print but don't fail the gate. List the warnings in the report.
- **E5.** If errors appear in files outside the allowed list, don't edit those files. Leave the gate failing and list the errors in the report under "Open questions". Don't disable the gate to get a pass.

## Do not do (user does these)

- Create the DevProducts in the Creator Hub and replace the placeholder IDs. The current IDs are sequential placeholders: 10001–10007 in `WeaponData.luau`, and 20001–20004, 30001–30004 and 40001–40004 in `ShopData.luau`.
- Turn on Game Settings → Security → "Enable Studio Access to API Services". Without it, saves won't work in Studio.
- Playtest. Put the checklist below in the report instead.
- Map, model and UI placement in Studio.

## Acceptance criteria

- [ ] Sections A to E are done, or any item that isn't is explained in the report.
- [ ] No DataStore call is wrapped in a silent `pcall`.
- [ ] `ProcessReceipt` never returns `PurchaseGranted` before a successful `SetAsync`.
- [ ] A failed load never leads to a save over the saved profile.
- [ ] `scripts/validate.ps1` passes all gates, including `type check`. If it can't pass because of errors outside the allowed files, the report says exactly which errors remain.
- [ ] This task changes only the allowed files. Task 001's uncommitted changes will still appear in `git status`. Those are not part of this task, so don't revert or stage them.

## Studio test checklist (copy into the report)

The report must include this for the user to run in Studio:

1. Join, buy a weapon that costs Dollars, leave, rejoin. The weapon is still owned and equipped, and the Dollars are still there.
2. Join with a saved non-hammer weapon equipped. It's equipped on spawn, not the hammer.
3. Buy a skin. The held weapon shows the skin without re-equipping.
4. During join and leave, the Output shows no `[EconomyManager]` warnings.
5. Once real DevProduct IDs are set: buy one Robux pack. Dollars are granted once, with no warning in the Output.

## Corrections to report 001 (put these in report 002)

- "Studio steps needed: None" is wrong. See "Do not do" above.
- The debris fade is not 6 seconds. `src/shared/Constants.luau` sets a 3.0 s lifetime and a 0.8 s fade, so the fade starts at 2.2 s.
- "breaks structural welds" is not implemented. The code unanchors parts. The village has no welds.
- "retry mechanisms" did not exist in `EconomyManager` before this task.
- The "Files changed" list in report 001 includes files git shows as unchanged.

## Notes

- Don't commit or push. The orchestrator reviews and commits.
- Follow AGENTS.md: `--!strict` on line 1, `task.*` functions only, tabs for indentation.
- If you're blocked, finish the parts you can and explain the blocker in the report. Don't guess.

## Round 2 (after the round 1 review)

Round 1 (sections A to E) is already in the working tree. Don't redo it. Round 1 left the `type check` gate failing, and the review found the problems below. Do only these items, and keep the round 1 report as it is. Add a "Round 2" section to the report.

Files allowed in round 2: the files listed at the top, plus `src/client/VFXController.luau` for R1 only.

- **R1. Deprecated property in the destruction effect (`src/client/VFXController.luau`, line 86).** Change `sound.Pitch` to `sound.PlaybackSpeed`. `Pitch` is a deprecated but valid `Sound` property, and Roblox's docs name `PlaybackSpeed` as its replacement. The luau-lsp definitions file leaves deprecated members out, so the type check flags it. This is not a runtime error, and the rest of the effect still runs. `PlaybackSpeed` changes speed as well as pitch, so the impact sound's length changes slightly. Correct the round 1 report on this point. Round 1 said `Pitch` doesn't exist and throws at runtime. That was wrong. (This spec made that claim, and it was my error.)
- **R2. Lost updates when a Robux save completes (`EconomyManager.luau`, `SaveRobuxPurchase`).** B1 step 5 says to replace the live profile with the copy after the save. That's wrong, and it was my error in this spec. `SetAsync` yields. While it yields, `ProcessPurchase`, `AddDollars`, `SpendDollars` and the unlock functions keep changing the live profile. Replacing it afterwards throws those changes away. A player who buys a weapon during a Robux save keeps the Dollars and loses the weapon. Fix: after the save succeeds, apply the same grant to the live profile (run the `applyGrant` callback on the live data). Set `ProcessedReceipts[purchaseId] = true` on the live profile, sync to the client, and do the server-side effects. Don't replace `sessionData`. Keep the copy for the save only. Each grant is applied once to the copy, for the save, and once to the live profile, after the save. Never apply the same grant to the live profile twice. R3 stops concurrent duplicates.
- **R3. The same purchase handled twice at once (`EconomyManager.luau`, `ShopServer.luau`).** Step 3 of B1 only checks what has already been saved. If Roblox calls `ProcessReceipt` again for a PurchaseId while the first call is still saving, both calls can grant it. Keep an in-flight set of PurchaseIds in `EconomyManager`. If the id is already in flight, return `NotProcessedYet`, so Roblox retries later. Remove the id from the set on every exit path, including errors.
- **R4. Respawn can leave the player with no weapon (`src/server/init.server.luau`, `equipPlayer`).** The old code waited 0.2 s before reading the Backpack. The round 1 code removed that wait. On respawn, once the profile is loaded, `equipPlayer` runs straight away. `GivePlayerWeaponTool` returns silently when `player:FindFirstChild("Backpack")` is nil. Fix: have `equipPlayer` wait for the Backpack before giving the tool, for example `player:WaitForChild("Backpack", 5)`. If it is still missing, log a `warn` and stop. The round 2 review could not confirm that the Backpack is missing on respawn, so treat this as a defensive change. The checklist item below tests it.
- **R5. The type check downloads its definitions from an unpinned branch (`scripts/validate.ps1`).** The gate loads `build/globalTypes.d.luau`. If that file is missing, the script downloads it from `main`, and `-ErrorAction SilentlyContinue` plus an empty `catch {}` hide any failure. The analyzer needs this file. Without it, it reports hundreds of "Unknown type" errors. The copy currently in `build/` came from `main`, and it is not the same file as the 1.70.1 release. Fix:
  1. Change the download URL to the release tag: `https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.70.1/scripts/globalTypes.d.luau`.
  2. Delete the existing `build/globalTypes.d.luau`, so the pinned copy is downloaded.
  3. Remove `-ErrorAction SilentlyContinue` and the empty `catch`. If the file is still missing after the attempt, the gate fails with a clear message.

  Checked already: the tagged file gives the same analyzer result as the current file. The only error is `Pitch`.
- **R6. Report and Studio checklist.** Report 002 gets a "Round 2" section that lists R1 to R5 and what changed. It also corrects the `Pitch` claim. Add these two items to the Studio checklist:
  6. Die and respawn. A hammer is in the backpack each time, and the Output shows no warnings.
  7. Destroy a building. The impact sound plays, and the Output shows no `Pitch` error.
  8. Race test. Buy a Dollars pack with Robux, and while the purchase is still going through, buy a weapon with Dollars. After rejoining, the weapon is still owned, the Dollars add up correctly, and the Output shows no errors.

Round 2 acceptance criteria:

- [ ] R1 to R6 are done, or each item that isn't is explained in the report.
- [ ] `scripts/validate.ps1` passes all gates, including `type check`, with the pinned definitions file.
- [ ] No gate result is hidden or suppressed.
