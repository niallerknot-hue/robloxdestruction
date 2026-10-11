--!strict
local CombatController = require(script.CombatController)
local VFXController = require(script.VFXController)
local UIController = require(script.UIController)

CombatController.Init()
VFXController.Init()
UIController.Init()

print("[Client] Destruction Game client fully initialized!")
