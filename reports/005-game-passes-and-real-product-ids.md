# Report 005: Real product IDs and game passes

**Result:** pass

## Files changed

- `src/shared/ShopData.luau`
- `src/shared/WeaponData.luau`
- `src/shared/Types.luau`
- `src/shared/Constants.luau`
- `src/server/ShopServer.luau`
- `src/server/init.server.luau`
- `src/client/UIController.luau`
- `tasks/BOARD.md`
- `tasks/005-game-passes-and-real-product-ids.md`
- `reports/005-game-passes-and-real-product-ids.md`

## What was built

1. **Currency Packs Real Developer Product IDs**:
   - In `src/shared/ShopData.luau` (lines 118, 125, 132, 139), updated the four `CurrencyPacks` developer product IDs from placeholders to verified real IDs:
     - `$5,000 Cash`: `3718210185` (49 Robux)
     - `$25,000 Cash`: `3718210329` (199 Robux)
     - `$100,000 Cash`: `3718210379` (599 Robux)
     - `$500,000 Cash`: `3718210435` (1499 Robux)

2. **Game Pass Migration & Real IDs for Weapons, Skins, and Auras**:
   - In `src/shared/Types.luau` (lines 23, 34, 46), renamed `DevProductId: number?` to `GamePassId: number?` across `WeaponInfo`, `AuraInfo`, and `SkinInfo` type definitions.
   - In `src/shared/WeaponData.luau` (lines 25, 38, 51, 64, 77, 90, 103), replaced placeholder developer product IDs with real `GamePassId` values for all 7 priced weapons:
     - `spiked_sledge`: `2029166261` (49 Robux)
     - `iron_demolisher`: `2029628260` (99 Robux)
     - `heavy_sledge_axe`: `2029556255` (199 Robux)
     - `industrial_jackhammer`: `2029280263` (399 Robux)
     - `dual_chainsaws`: `2028710268` (699 Robux)
     - `dynamite_launcher`: `2029922261` (999 Robux)
     - `plasma_annihilator`: `2029562268` (1499 Robux)
     - Free starter `sledgehammer` has no ID.
   - In `src/shared/ShopData.luau` (lines 20, 30, 40, 50, 72, 82, 93, 104), replaced placeholder IDs with real `GamePassId` values for all 4 priced skins and 4 priced auras:
     - Skins: `golden` (`2028500272`, 149 Robux), `magma` (`2029034268`, 299 Robux), `void_obsidian` (`2030108260`, 449 Robux), `galaxy` (`2029340258`, 699 Robux). Starter `default` has no ID.
     - Auras: `dollar_rain` (`2029172263`, 99 Robux), `electric_storm` (`2028830266`, 249 Robux), `inferno_blaze` (`2029034269`, 399 Robux), `shadow_rift` (`2030648258`, 599 Robux). Starter `none` has no ID.

3. **Server Game Pass Granting & Verification**:
   - In `src/shared/Constants.luau` (line 23), added `CheckGamePass = "CheckGamePass"` to `Remotes`.
   - In `src/server/init.server.luau` (line 37), registered `ensureRemoteEvent(Constants.Remotes.CheckGamePass)`.
   - In `src/server/ShopServer.luau`:
     - Lines 166–203: Pruned `GrantRobuxPurchase` by removing weapon, skin, and aura branches so `ProcessReceipt` strictly processes currency packs and logs an unknown product warning otherwise.
     - Lines 204–226: Implemented `findItemByGamePassId(passId)` helper mapping a pass ID to its category, ID, and metadata.
     - Lines 228–306: Implemented `ShopServer.GrantGamePass(player: Player, passId: number): boolean`. Checks session ownership first (returning `true` immediately without network call), verifies with `MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)` inside `pcall`, rechecks ownership after web yield, unlocks and equips the item, and invokes appropriate visual/tool update functions (`GivePlayerWeaponTool` or `ApplyAura`).
     - Lines 308–397: Implemented `ShopServer.SyncGamePasses(player: Player)`. Spawns in background (`task.spawn`), checks ownership of all 15 game pass items with up to 3 retries (1 second wait between attempts), marks owned items with `Unlock*` functions without altering equipped loadouts, and warns once per item only on final failure.
     - Lines 105–109: In `ShopServer.Init`, connected `EconomyManager.ProfileLoaded` to `ShopServer.SyncGamePasses`, and synced already loaded players.
     - Lines 112–118: Connected `MarketplaceService.PromptGamePassPurchaseFinished` to call `GrantGamePass` when `wasPurchased` is `true`.
     - Lines 121–129: Connected `CheckGamePass` remote event to validate argument type (`typeof(passId) == "number"`) and invoke `GrantGamePass`.

4. **Client UI & Store Game Pass Integration**:
   - In `src/client/UIController.luau`:
     - Lines 111–114, 150–170: Weapon cards now invoke `MarketplaceService:PromptGamePassPurchase(player, weapon.GamePassId)`. Dollar and Robux action buttons are rendered side-by-side when the Robux option is present and item is not owned.
     - Lines 208–211, 246–268: Skin cards now display a dedicated Robux action button alongside the dollar button for unowned skins with `PriceRobux > 0` and `GamePassId`. Clicking invokes `MarketplaceService:PromptGamePassPurchase(player, skin.GamePassId)`.
     - Lines 305–308, 343–365: Aura cards now display a dedicated Robux action button alongside the dollar button for unowned auras with `PriceRobux > 0` and `GamePassId`. Clicking invokes `MarketplaceService:PromptGamePassPurchase(player, aura.GamePassId)`.
     - Lines 366–420: Currency packs retain `PromptProductPurchase(player, pack.DevProductId)`.
     - Lines 600, 626–632: In `UIController.Init`, connected `MarketplaceService.PromptGamePassPurchaseFinished` to fire `CheckGamePass:FireServer(passId)` when `purchasedPlayer == player` and `wasPurchased == true`.

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

## Studio test checklist (copy from spec)

> **Warning regarding Studio purchases:**
> Read this before you test. Roblox's documentation doesn't say whether Studio purchases charge real Robux. A July 2026 DevForum report says they did. Check your Robux balance before you start, and check it again afterwards. Use the cheapest pass, Spiked Sledge (49 Robux), for the first test.

1. Buy Spiked Sledge with Robux. The weapon unlocks and equips straight away, with no rejoin. If it doesn't, the Output will show which listener ran.
2. Leave and rejoin. Spiked Sledge is still owned, even if the saved profile doesn't have it.
3. After buying it, the Robux button for Spiked Sledge is gone.
4. Buy a skin or an aura with Robux. The button works, and the item is unlocked and equipped straight away. Test this only if you're happy to spend the Robux.
5. Buy $5,000 Cash with Robux. Dollars are granted once, and a second purchase grants again.
6. Output shows no `[ShopServer]` or `[EconomyManager]` warnings, unless a sync or ownership check actually failed.

*Note: In accordance with the prompt's instructions ("Don't make any purchase in Roblox Studio, and don't change anything in Studio's Game Settings or the Creator Hub"), live Robux purchases were not executed during automated verification to protect real Robux balances and avoid modifying cloud state.*

## Studio steps needed

None. All IDs and connections are in sync via Rojo. When the user tests purchases in Studio or on live Roblox servers, follow the checklist above.

## Open questions

None. All 19 real product/pass IDs are integrated and all validation gates pass.
