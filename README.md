# AutoLoot

###### Scary warning: Most of these addons were made long ago during Feenix days, then a lot was changed/added to prepare for Corecraft. Since it died, they still haven't been extensively tested on modern servers.

### [Downloads](https://github.com/Shanghi/AutoLoot/releases)

***

## Purpose:
* Can automatically loot, roll, pass, or do nothing for specific items or items based on type/rarity/iLevel rules.
* Can take and destroy unwanted items in skinning mode.

| Commands | Description |
| --- | --- |
| /autoloot | _open the settings window_ |
| /autoloot <"on"\|"off"> | _shortcut to turn auto-looting on or off_ |
| /autoroll <"on"\|"off"> | _shortcut to turn auto-rolling on or off_ |
| /autopass <"on"\|"off"> | _shortcut to enable or disable passing on everything_ |

## Screenshot:
![!](https://i.imgur.com/h9luVhE.png)

## Using:
You create groups of items, and each group is set to handle looting/rolling for all the items in it. You'll probably have a group of things you always want to take, like badges of justice and quest items. If you keep adding groups/items/rules, then eventually you'll never have to manually loot/roll again, unless you're the unlucky loot master.

To add a rule, click the question mark button and pick something from the list. If it needs to be more specific, you can edit the text it adds to change the type/subtype, quality, and iLvl range. Don't change the order or remove anything though.

Some notes:
* Blank lines in the lists are OK.
* You can drag items to the editbox to add their names.
* "Solo" is for anything you can loot without rolling. "Outside" is for non-raid groups that aren't in an instance. "Raid" is for any raid group, both inside and outside of instances.
* You can use lua pattern matching for item names if you want.
* The pass on everything option only exists because the normal game option for it is broken on so many servers (or at least was back then).
