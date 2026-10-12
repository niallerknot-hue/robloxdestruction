# 001: Destruction Game Foundation

**Status:** review

**Goal:** Build core destruction physics engine, zero-collision debris system, sledgehammer weapon, economy, storefront with Robux/in-game currency, and an Old English Village starting map.

## Files allowed to change

- `src/shared/Constants.luau`
- `src/shared/Types.luau`
- `src/shared/WeaponData.luau`
- `src/shared/ShopData.luau`
- `src/server/init.server.luau`
- `src/server/CollisionManager.luau`
- `src/server/DestructionEngine.luau`
- `src/server/EconomyManager.luau`
- `src/server/ShopServer.luau`
- `src/server/VillageGenerator.luau`
- `src/client/init.client.luau`
- `src/client/CombatController.luau`
- `src/client/VFXController.luau`
- `src/client/UIController.luau`
- `default.project.json`
- `tasks/BOARD.md`
- `reports/001-destruction-game-foundation.md`

## Acceptance criteria

- [x] Zero-collision physics: Players never collide with debris, debris does not collide with other debris (collides only with ground/buildings).
- [x] Authoritative server destruction engine with structural integrity breaks, damage propagation, impulse push, fading debris, and auto-regeneration.
- [x] Sledgehammer starter weapon with client swing animation, hit detection, screen shake, and server validation.
- [x] Dollars economy with DataStore persistence, leaderboard, and dynamic HUD dollar display.
- [x] Multi-tab Armory storefront (Weapons, Skins, Auras, Cash packs via DevProducts) toggleable via UI button and `B` keybind.
- [x] Procedural Old English Village generator (Tudor cottages, shops, bakery, blacksmith, tavern, barn, windmill, forest, vintage vehicles).
- [x] Passes all automated gates in `scripts/validate.ps1` (`rojo build`, `stylua`, `selene`, `strict header`).

## Out of scope

- Multiplayer trading system.
- Sound asset audio uploads (uses engine default sound IDs for prototyping).
- Custom 3D mesh asset IDs (uses procedural Luau constructive CSG/parts).

## Notes

- Server is authoritative on all damage and currency transactions.
- All `.luau` files start with `--!strict`.
