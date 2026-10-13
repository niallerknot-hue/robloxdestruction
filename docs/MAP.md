# Map Plan

Overall map bounds: x −300 to 480, z −340 to 360 (studs).

## Zones

| Zone | Shape and position | Notes |
|---|---|---|
| Village pad | x −220 to 140, z −150 to 190, flat at y = 0 | Doubles the old village footprint. Everything from the old village stays on this pad. Edges blend into the land outside over 20 studs. |
| River | Polyline route through 15 points: (−290, −330), (−285, −150), (−270, 0), (−265, 120), (−265, 200), (−215, 250), (−120, 255), (0, 255), (130, 260), (200, 170), (210, 90), (290, 60), (330, 70), (320, 110), (300, 150), width 24 | Runs west of village, south of village, north-east between village and lake, along castle south-west side, and down into lake. Surface at y = −2, channel floor at y = −6. Closest distance to village pad is 35.08 studs (>= 30 studs required). |
| North-east hills | Centre (250, −200), radius 130, height 40 above the land | Rolling hills. They can overlap the north-east corner of the pad, but the pad stays flat. |
| Castle plateau | Centre (400, 0), radius 70, top at y = 35 | Sloped sides, flat top. The castle and the second market town go here, in a later task. |
| Lake | Centre (300, 240), radius 110 (flat basin radius 80) | Surface at y = −2, basin floor at y = −10. River enters directly into the lake from the north shore. Gap to castle plateau is 80 studs; gap to village pad is 57.63 studs. A boathouse will go on the north shore in a later task. |

## Later Tasks by Zone

- **Village pad**: Completed in Task 007 (village doubled with east street cottages, north green church, south row cottages, south-west hamlet, and tree protection).
- **River**: A later task will build a wooden river dock on the pad edge at (−215, 40) and add riverboats.
- **North-east hills**: A later task will place hilltop ruins, stone watchtowers, and mountain trails for player exploration and demolition.
- **Castle plateau**: A later task will build the medieval stone castle, defensive curtain walls, and a second market town atop the plateau.
- **Lake**: A later task will build a lakeside boathouse and fishing pier on the north shore with navigable watercraft.

## Village Footprints

The village pad (x −220 to 140, z −150 to 190) contains the following building, structure, and ground footprints:

| Name | Centre (x, z) | Size (x × z) | Type | Notes |
|---|---|---|---|---|
| Town Square Plaza | (0, 0) | 60 × 60 | Ground part | Central cobblestone plaza (non-destructible createGround) |
| Blacksmith Forge | (38, −10) | 26 × 22 | Building | Commercial street east side, facing West |
| The Red Lion Tavern | (38, 26) | 26 × 22 | Building | Commercial street east side, facing West |
| Village Bakery | (−38, −10) | 26 × 22 | Building | Commercial street west side, facing East |
| Rose Cottage | (−38, 28) | 22 × 18 | Building | West street cottage, facing East |
| Weaver Cottage | (−16, 55) | 18 × 22 | Building | South cottage, facing South |
| Thatcher Cottage | (20, 55) | 18 × 22 | Building | South cottage, facing South |
| Miller's Cottage (East 1) | (100, −60) | 22 × 18 | Building | East street, facing West towards street at x ≈ 80 |
| Carpenter's Cottage (East 2) | (100, 10) | 22 × 18 | Building | East street, facing West towards street at x ≈ 80 |
| Baker's Cottage (East 3) | (100, 80) | 22 × 18 | Building | East street, facing West towards street at x ≈ 80 |
| Village Church | (30, −125) | 58 × 30 | Building | North green, 44×30 stone nave + 14×14 west tower |
| Meadow Cottage (South 1) | (−40, 125) | 18 × 22 | Building | South row, facing North towards Town Square |
| Orchard Cottage (South 2) | (0, 125) | 18 × 22 | Building | South row, facing North towards Town Square |
| Willow Cottage (South 3) | (40, 125) | 18 × 22 | Building | South row, facing North towards Town Square |
| Brook Cottage (Hamlet 1) | (−150, 110) | 22 × 18 | Building | South-west hamlet, facing East |
| Fern Cottage (Hamlet 2) | (−120, 160) | 22 × 18 | Building | South-west hamlet, facing East |
| Hamlet General Store | (−80, 150) | 26 × 22 | Building | South-west hamlet, facing West |
| Farm Barn | (0, −75) | 28 × 36 | Building | North farm, big red barn |
| Farm Windmill | (45, −75) | 16 × 16 | Structure | North farm, octagonal tower + sails |
| Delivery Van | (12, −18) | 8 × 16 | Structure | Town square vehicle |
| Farm Wagon | (−18, 16) | 8 × 12 | Structure | Town square vehicle |
| Pilot Cottage (Kit) | (−195, −120) | 18 × 22 | Model / Kit | North-west pad edge, modular Blender pilot cottage |

### Blender Cottage Kit Workflow

The pilot cottage at (−195, 0, −120) tests the external modeling pipeline for building kits:
1. `tools/blender/build_cottage_kit.py` generates the cottage kit in Blender with destructible pieces (`D_`) and solid walkable surfaces (`S_`), exporting to `build/kits/cottage_tudor.fbx` with FBX Unit Scale.
2. The model is imported into Roblox Studio and saved as `src/templates/cottage_tudor.rbxm` (synced to `ReplicatedStorage.Templates` via Rojo).
3. At server startup, `VillageGenerator.luau` calls `KitLoader.Spawn("cottage_tudor", ...)` which clones the model, registers `D_` parts to `DestructionEngine` (health 60, reward 10), and keeps `S_` floor and foundation pieces solid and non-destructible.
