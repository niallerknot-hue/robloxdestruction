# Report 002: Harden saves and purchases

**Result:** pass (code review and validation). Studio checklist still to run.

## Files changed

- `src/server/EconomyManager.luau`
- `src/server/ShopServer.luau`
- `src/server/init.server.luau`
- `src/server/DestructionEngine.luau`
- `src/client/CombatController.luau`
- `src/client/VFXController.luau`
- `src/shared/Types.luau`
- `scripts/validate.ps1`
- `rokit.toml`
- `tasks/BOARD.md`
- `tasks/002-harden-saves-and-purchases.md`

## What was built (Round 1)

1. **Robust DataStore Persistence (`EconomyManager.luau`)**:
   - Implemented a unified `retryOperation` helper with backoff (1s, 2s) retrying up to 3 attempts for both `GetAsync` and `SetAsync`.
   - Tracked per-player load state via `loadedPlayers`. If `GetAsync` fails after all retries, the profile is marked as not loaded and `SetAsync` will never overwrite the saved profile.
   - Guarded against player departure during yields in `GetAsync`.
   - Logged explicit `warn` messages with `[EconomyManager]` prefix, player UserId, and error text on all failed attempts and final failures (including startup `GetDataStore`).
   - Added `EconomyManager.IsLoaded(player: Player): boolean` and `EconomyManager.ProfileLoaded` bindable signal.

2. **Save-Before-Grant Purchase Flow (`ShopServer.luau`, `EconomyManager.luau`, `Types.luau`)**:
   - Added `ProcessedReceipts: { [string]: boolean }?` to `PlayerData` in `src/shared/Types.luau`.
   - Structured `MarketplaceService.ProcessReceipt` to enforce the required lifecycle:
     1. Player not in server -> `NotProcessedYet`.
     2. `EconomyManager.IsLoaded(player)` is false -> log warning, return `NotProcessedYet`.
     3. `PurchaseId` already in `ProcessedReceipts` -> return `PurchaseGranted` immediately without duplicate granting.
     4. Deep copy the profile in `EconomyManager.SaveRobuxPurchase`, apply the grant callback to the copy, mark `PurchaseId` in copy's `ProcessedReceipts`, and save with `SetAsync` via retry helper.
     5. Only when save succeeds: sync to client, grant in-game effects (tools/auras), and return `PurchaseGranted`.
     6. If save fails after retries: log warning and return `NotProcessedYet`, keeping the live profile untouched.
   - For unrecognized `ProductId`, logged a warning and returned `NotProcessedYet` (B3).
   - Ensured `AddDollars` and `GrantRobuxPurchase` return boolean status reporting (B4).
   - In `ShopServer.ProcessPurchase` (Skin branch) and `GrantRobuxPurchase` (Skin branch), called `ShopServer.GivePlayerWeaponTool` with the equipped weapon so newly purchased skins immediately appear on the held tool (B6).

3. **Spawn Race Resolution (`init.server.luau`)**:
   - Removed fixed `task.wait(0.2)` race condition. Character spawning now polls `EconomyManager.IsLoaded(player)` every 0.1s up to a 15s timeout before equipping, and aborts if the player leaves (C1).
   - Connected `EconomyManager.ProfileLoaded` so if the character is already loaded in the world when the profile arrives, the saved weapon and aura are given immediately (C2).
   - Equipped weapon always reads from `playerData.EquippedWeapon`, maintaining a single source of truth aligned with `DestructionEngine.ProcessAttack` (C3).

4. **Attack Validation & Cleanup (`DestructionEngine.luau`, `CombatController.luau`)**:
   - In `ProcessAttack`, validated `typeof(impactCFrame) == "CFrame"` and changed distance test to `if not (distance <= maxReach) then return end` to reject NaN values (D1).
   - Kept rate limit check and moved cooldown stamping `playerCooldowns[player] = now` to occur only after type and reach validations pass (D2).
   - Connected `Players.PlayerRemoving` in `DestructionEngine.Init` to clean up `playerCooldowns[player]` (D3).
   - Tracked connected tool instances in `CombatController.luau` with a weak-keyed table (`setmetatable({}, { __mode = "k" })`) to prevent duplicate `tool.Activated` connections (D4).

5. **Type Check Gate & Tooling (`scripts/validate.ps1`, `rokit.toml`)**:
   - Added `luau-lsp = "johnnymorganz/luau-lsp@1.70.1"` to `rokit.toml`.
   - Added `type check` gate to `scripts/validate.ps1` running `rojo sourcemap default.project.json -o build/sourcemap.json` and `luau-lsp analyze --sourcemap build/sourcemap.json` with definition resolution against `build/globalTypes.d.luau`.
   - Resolved strict-mode type errors across all allowed files.

## Round 2 (Review Fixes)

- **R1. Deprecated property in destruction effect (`src/client/VFXController.luau:86`)**:
  Replaced `sound.Pitch` with `sound.PlaybackSpeed`. `Pitch` is a deprecated but valid `Sound` property, and Roblox's docs point to `PlaybackSpeed` as its replacement. The luau-lsp definitions file leaves deprecated members out, so the `type check` gate flagged it. This was not a runtime error, and the old line did not stop the impact sound or the cleanup. `PlaybackSpeed` changes speed as well as pitch, so the impact sound's length changes slightly. Round 1 said `Pitch` did not exist and threw at runtime. That was wrong, and this section corrects it.
- **R2. Lost updates when a Robux save completes (`EconomyManager.luau`)**:
  Fixed `SaveRobuxPurchase` to never replace `sessionData` with the snapshot copy. Instead, once `SetAsync` successfully persists the purchase, the `applyGrant` callback is applied directly to the live profile (`sessionData[player.UserId]`), and `liveReceipts[purchaseId] = true` is set. This preserves all intermediate gameplay changes (weapon purchases, dollar gains) that occurred while `SetAsync` yielded.
- **R3. Prevention of duplicate in-flight purchase grants (`EconomyManager.luau`, `ShopServer.luau`)**:
  Added an `inFlightPurchases` tracking set in `EconomyManager`. If a `PurchaseId` is already in flight when `ProcessReceipt` runs, it immediately returns `Enum.ProductPurchaseDecision.NotProcessedYet`, allowing Roblox to retry later. `SaveRobuxPurchase` guarantees removal of `purchaseId` from `inFlightPurchases` on all execution paths and errors via a protective `pcall` wrapper.
- **R4. Respawn weapon guarantee (`src/server/init.server.luau`)**:
  `equipPlayer` now waits for the player's Backpack with `player:WaitForChild("Backpack", 5)`. If it doesn't appear within 5 seconds, a warning is logged and the function stops. This is a defensive change. The round 2 review did not confirm that the Backpack is missing on respawn, so the Studio checklist (item 6) tests it.
- **R5. Pinned definitions download in type check gate (`scripts/validate.ps1`)**:
  Updated `scripts/validate.ps1` to download definition types from the pinned release tag `https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.70.1/scripts/globalTypes.d.luau`. Removed `-ErrorAction SilentlyContinue` and empty catch blocks. If the definition file cannot be downloaded or found, the gate fails immediately with a clear error message.

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

## Studio test checklist (copy into the report)

The report must include this for the user to run in Studio:

1. Join, buy a weapon that costs Dollars, leave, rejoin. The weapon is still owned and equipped, and the Dollars are still there.
2. Join with a saved non-hammer weapon equipped. It's equipped on spawn, not the hammer.
3. Buy a skin. The held weapon shows the skin without re-equipping.
4. During join and leave, the Output shows no `[EconomyManager]` warnings.
5. Once real DevProduct IDs are set: buy one Robux pack. Dollars are granted once, with no warning in the Output.
6. Die and respawn. A hammer is in the backpack each time, and the Output shows no warnings.
7. Destroy a building. The impact sound plays, and the Output shows no `Pitch` error.
8. Race test. Buy a Dollars pack with Robux, and while the purchase is still going through, buy a weapon with Dollars. After rejoining, the weapon is still owned, the Dollars add up correctly, and the Output shows no errors.

## Known limitations (not blocking)

- Duplicate protection works within one server. Roblox documents that a `ProcessReceipt` callback can run on two servers at the same time, and this round does not cover that case. Covering it would need a receipt record in the DataStore, written with `UpdateAsync` and keyed on the PurchaseId.
- Whether `RemoteFunction` handlers and `ProcessReceipt` callbacks can overlap on one server is not documented. The race test (item 8) checks this in Studio.
- The 15 s timeout path in `onCharacterSpawned` (`init.server.luau`) calls `GivePlayerWeaponTool` directly, without the Backpack wait. The risk is low, and it only applies after the timeout.

## Corrections to report 001 (put these in report 002)

- "Studio steps needed: None" is wrong. See "Do not do" above.
- The debris fade is not 6 seconds. `src/shared/Constants.luau` sets a 3.0 s lifetime and a 0.8 s fade, so the fade starts at 2.2 s.
- "breaks structural welds" is not implemented. The code unanchors parts. The village has no welds.
- "retry mechanisms" did not exist in `EconomyManager` before this task.
- The "Files changed" list in report 001 includes files git shows as unchanged.

## Studio steps needed

User configuration steps in Roblox Studio:
1. Turn on Game Settings -> Security -> "Enable Studio Access to API Services" so DataStore calls work during testing in Studio.
2. Register real Developer Products in the Creator Hub / Experience settings and replace the sequential placeholder IDs in `WeaponData.luau` (10001–10007) and `ShopData.luau` (20001–20004, 30001–30004, 40001–40004) when enabling live Robux purchases.
3. Run the Studio test checklist above (items 1–8).

## Open questions

- none
