# Agent instructions: robloxdestruction

Roblox game written in Luau. Files on disk are the source of truth. Rojo syncs them into Roblox Studio.
The game concept is not decided yet (see README.md).

## Layout

- `src/server/` maps to `ServerScriptService.Server`
- `src/client/` maps to `StarterPlayer.StarterPlayerScripts.Client`
- `src/shared/` maps to `ReplicatedStorage.Shared`
- File suffixes set the Roblox script type: `*.server.luau` is a Script, `*.client.luau` is a LocalScript,
  and plain `*.luau` is a ModuleScript.
- `default.project.json` is the Rojo mapping. Don't change it unless a task says to.
- `build/` and `*.rbxl` are generated and git-ignored. Never commit them.

## Code rules

- Line 1 of every `.luau` file is `--!strict`.
- The server is authoritative. Never trust values from a client (damage, currency, purchases, positions).
  Validate them on the server.
- Use `task.wait`, `task.spawn` and `task.delay`. Don't use the deprecated `wait`, `spawn` or `delay`.
- Wrap DataStore calls in `pcall` with retries. A failed save must be logged, never silently dropped.
- Disconnect event connections you no longer need, for example when a character or player is removed.
- Keep modules small and single-purpose. Logic used by both client and server goes in `src/shared/`.
- Follow `stylua.toml` and `selene.toml`. Don't change them unless a task says to.

## Editing rules

- Edit files on disk only. Rojo overwrites changes made inside Studio to synced scripts.
- Only change the files listed under "Files allowed to change" in your task spec.
- Don't commit or push. The orchestrator reviews the changes and commits them.
- Maps, models and UI placement happen in Studio, by hand. Don't try to script them. Describe what needs
  building in the "Studio steps needed" section of your report.

## Workflow

1. Read your task spec in `tasks/NNN-short-name.md`. Its template is `tasks/TEMPLATE.md`.
   Task status is tracked in `tasks/BOARD.md`.
2. Implement the task.
3. Run `powershell -ExecutionPolicy Bypass -File scripts/validate.ps1`. Fix problems and re-run until every gate passes.
4. Write `reports/NNN-short-name.md`. Its template is `reports/TEMPLATE.md`.
5. Set the task's status to `review` in `tasks/BOARD.md`.
