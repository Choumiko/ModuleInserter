Sick of having to put dozens of modules in your drills, assemblers, etc. by hand?

Configure ModuleInserter with a setup for machines, mark the area and watch your Pocketbots do the hard work

Click the buttons(grey squares) with the item or module at your cursor, to set what module should go into which entity. To remove entities/modules click with an empty cursor.
To clear modules from entities only set the entity without modules.
Craft the module inserter item (it's where blueprints/deconstruction planner are), mark the area where your machines are and watch your bots.

Notes:
    Modules will first be taken from your inventory, if you don't have enough it will take them from the logistics network (for entities in logistics range only). The fake entity that is used to make the bots fly to the machine is inserted into your inventory. So it will only work if you have a personal roboport and a couple free slots in your inventory.

***
###Changelog
2.0.2

 - fixed error in UI initialisation  
 
2.0.1

- fixed error in migration file

2.0.0

- version for Factorio 0.15.x
- ModuleInserter unlocks when researching construction robots

1.0.0

- version for Factorio 0.14.x

0.2.3

- allow productivity modules in beacons if the prototype supports it

0.2.2

- requires Factorio 0.13.12
- fixed that using /c game.player.force.research_all_technologies would disable recipes. If you have an affected save, use /c game.player.force.reset_recipes()
- removed the fake technology

0.2.1

- check for module-inserter item when area is selected
- shift selecting an area also removes vanilla module requests
- unresearch the fake technology when researched via console command

0.1.4/0.2.0

- shift selecting an area removes pending insertion jobs
- insertion jobs get canceled when updating to 0.1.4
- changed module inserter item to selection tool (MP/Player afk safe)
- fixed data not being cleaned up when ghost timed out