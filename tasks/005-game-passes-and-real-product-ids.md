# 005: Real product IDs, and game passes for weapons, skins and auras

**Status:** review

**Goal:** Use the real Roblox IDs for the four currency packs, and sell the 15 priced weapons, skins and auras as game passes. Passes are one-time purchases that Roblox tracks, so a player can't pay twice for the same item.

**Why:** Right now the weapons, skins and auras are developer products. Developer products can be bought again and again, and the server doesn't check ownership before charging. The Skins and Auras tabs also have no Robux buttons at all.

## Real IDs (already checked)

Game pass IDs were checked against Roblox. Each one returns the expected name and Robux price.

| Item | Type | Robux | ID |
|---|---|---|---|
| $5,000 Cash | Developer product | 49 | 3718210185 |
| $25,000 Cash | Developer product | 199 | 3718210329 |
| $100,000 Cash | Developer product | 599 | 3718210379 |
| $500,000 Cash | Developer product | 1499 | 3718210435 |
| Spiked Sledge | Game pass | 49 | 2029166261 |
| Iron Demolisher | Game pass | 99 | 2029628260 |
| Heavy Sledge-Axe | Game pass | 199 | 2029556255 |
| Industrial Jackhammer | Game pass | 399 | 2029280263 |
| Dual Chainsaws | Game pass | 699 | 2028710268 |
| Dynamite Launcher | Game pass | 999 | 2029922261 |
| Plasma Annihilator | Game pass | 1499 | 2029562268 |
| Pure Gold (skin) | Game pass | 149 | 2028500272 |
| Molten Magma (skin) | Game pass | 299 | 2029034268 |
| Void Obsidian (skin) | Game pass | 449 | 2030108260 |
| Cosmic Galaxy (skin) | Game pass | 699 | 2029340258 |
| Dollar Shower (aura) | Game pass | 99 | 2029172263 |
| Electric Storm (aura) | Game pass | 249 | 2028830266 |
| Inferno Blaze (aura) | Game pass | 399 | 2029034269 |
| Shadow Rift (aura) | Game pass | 599 | 2030648258 |

Keys in the data files: weapons are `spiked_sledge`, `iron_demolisher`, `heavy_sledge_axe`, `industrial_jackhammer`, `dual_chainsaws`, `dynamite_launcher` and `plasma_annihilator`. Skins are `golden`, `magma`, `void_obsidian` and `galaxy`. Auras are `dollar_rain`, `electric_storm`, `inferno_blaze` and `shadow_rift`.

The starter items (`sledgehammer`, the `default` skin and the `none` aura) are free and have no ID. Leave them alone.

## Files allowed to change

- `src/shared/ShopData.luau`
- `src/shared/WeaponData.luau`
- `src/shared/Types.luau` (the three `DevProductId` fields on weapons, skins and auras only)
- `src/shared/Constants.luau` (one new remote name only)
- `src/server/ShopServer.luau`
- `src/server/init.server.luau` (one `ensureRemoteEvent` line only)
- `src/client/UIController.luau`
- `tasks/BOARD.md`
- `tasks/005-game-passes-and-real-product-ids.md` (status line only)
- `reports/005-game-passes-and-real-product-ids.md` (new)

Don't change anything else. In particular, leave the save and load code in `EconomyManager.luau` alone, along with the rest of the village and the client combat code.

## Work

### A. Currency packs stay developer products

1. In `ShopData.luau`, change the four `CurrencyPacks` IDs: 40001 becomes 3718210185, 40002 becomes 3718210329, 40003 becomes 3718210379 and 40004 becomes 3718210435.
2. Keep `ProcessReceipt` and the currency-pack branch in `GrantRobuxPurchase`. Keep the unknown-product warning, too.

### B. Weapons, skins and auras become game passes

3. **Data.** In `WeaponData.luau`, `ShopData.luau` (skins and auras) and `Types.luau`, rename `DevProductId` to `GamePassId` on the 15 priced items, and give each one the ID from the table above. Keep the type as an optional number. Don't rename `DevProductId` on the currency packs.
4. **Server, granting.** In `ShopServer.luau`, add these two functions:
   - `ShopServer.GrantGamePass(player: Player, passId: number): boolean`. Find the item whose `GamePassId` matches. If the item is already owned in the session, return `true` straight away, with no web call. Otherwise call `MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)` inside `pcall`. If the call fails, warn and return `false`. If the player owns the pass, unlock the item with `EconomyManager.UnlockWeapon`, `UnlockSkin` or `UnlockAura`. Then equip it with the matching `Equip` function, and apply its effect: a weapon gets `GivePlayerWeaponTool`, a skin re-runs `GivePlayerWeaponTool` with the equipped weapon, and an aura runs `ApplyAura`. Check ownership again after the web call returns, because two calls can overlap.
   - `ShopServer.SyncGamePasses(player: Player)`. For each of the 15 items, check ownership with `UserOwnsGamePassAsync` inside `pcall`, and retry up to 3 times with `task.wait(1)` between attempts. If the player owns the pass, mark the item owned with the `Unlock*` function. Don't change what's equipped. Warn once per item on final failure. Run this in a `task.spawn`, so it never blocks the spawn code.
5. **Server, when to check.**
   - In `ShopServer.Init`, connect `EconomyManager.ProfileLoaded` and call `SyncGamePasses` for the player. `ProfileLoaded` is a `BindableEvent` on `EconomyManager`, and it passes the player.
   - In `ShopServer.Init`, connect `MarketplaceService.PromptGamePassPurchaseFinished`. When `wasPurchased` is true, call `GrantGamePass`. The server always checks ownership itself, so this is safe even if the event arrives twice.
   - Connect a server listener to a new remote, `Constants.Remotes.CheckGamePass`. It takes a pass ID from the client, and calls `GrantGamePass` for it. If the player doesn't own the item, the listener does nothing. Reject any argument that isn't a number.
   - Add `Constants.Remotes.CheckGamePass = "CheckGamePass"`, and in `init.server.luau` call `ensureRemoteEvent(Constants.Remotes.CheckGamePass)`.
6. **Server, remove the old Robux paths.** In `GrantRobuxPurchase`, delete the weapon, skin and aura branches, because those items are now passes. Keep the currency-pack branch and the unknown-product warning.
7. **Client, buy buttons.** In `UIController.luau`:
   - For the weapon Robux button, change the prompt to `MarketplaceService:PromptGamePassPurchase(player, weapon.GamePassId)`. Keep the check that hides the button when the item is owned.
   - Skins and Auras have no Robux button today. Add one to each card, the same way the Weapons tab does. Show it only when the item has a `PriceRobux` above 0, has a `GamePassId`, and isn't owned. It calls `PromptGamePassPurchase`. Place it beside the dollar button without covering it.
   - Currency packs keep `PromptProductPurchase`.
   - Connect `MarketplaceService.PromptGamePassPurchaseFinished` on the client. When `wasPurchased` is true, fire `CheckGamePass` with the pass ID. This covers the case where the event only fires on the client.
8. **Keep the rest the same.** Equip-on-purchase stays as it is. The unknown-product warning stays. The UI still hides a Robux button for an owned item.

## Acceptance criteria

- [ ] The four currency packs use 3718210185, 3718210329, 3718210379 and 3718210435.
- [ ] The 15 priced items use `GamePassId` with the IDs from the table. No weapon, skin or aura has a `DevProductId`.
- [ ] The starter items (`sledgehammer`, `default`, `none`) have no ID.
- [ ] `ProcessReceipt` only handles the four currency packs. The weapon, skin and aura branches are gone.
- [ ] Every pass grant checks `UserOwnsGamePassAsync` on the server before it unlocks anything.
- [ ] `SyncGamePasses` runs on `ProfileLoaded`, in a `task.spawn`, with three attempts.
- [ ] The Skins and Auras tabs show a Robux button for each priced item that isn't owned.
- [ ] `scripts/validate.ps1` passes all gates.
- [ ] The report lists each change, with file and line.

## Studio test checklist (copy into the report)

Read this before you test. Roblox's documentation doesn't say whether Studio purchases charge real Robux. A July 2026 DevForum report says they did. Check your Robux balance before you start, and check it again afterwards. Use the cheapest pass, Spiked Sledge (49 Robux), for the first test.

1. Buy Spiked Sledge with Robux. The weapon unlocks and equips straight away, with no rejoin. If it doesn't, the Output will show which listener ran.
2. Leave and rejoin. Spiked Sledge is still owned, even if the saved profile doesn't have it.
3. After buying it, the Robux button for Spiked Sledge is gone.
4. Buy a skin or an aura with Robux. The button works, and the item is unlocked and equipped straight away. Test this only if you're happy to spend the Robux.
5. Buy $5,000 Cash with Robux. Dollars are granted once, and a second purchase grants again.
6. Output shows no `[ShopServer]` or `[EconomyManager]` warnings, unless a sync or ownership check actually failed.

## Notes

- Don't commit or push. The orchestrator reviews and commits.
- Follow AGENTS.md: `--!strict` on line 1, `task.*` functions only, tabs for indentation.
- If you're blocked, finish the parts you can and explain the blocker in the report.
