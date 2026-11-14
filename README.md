# Loot Compare

Compare drops as they hit your bags.

Loot Compare watches your bags and, when a new piece of gear lands in them,
pops up a small window comparing it against what you have equipped in that slot.

## When an item pops up

Only likely upgrades pop up. Each slot is judged on its own against what you are
wearing there, so the filter tightens by itself as your gear improves: grey and
white drops still appear while you are levelling in greys and whites, and stop
once that slot has something better.

| You're wearing | Grey drop | White drop | Green drop | Blue drop | Epic drop |
|---|---|---|---|---|---|
| **Nothing** | Always | Always | Always | Always | Always |
| **Grey** | Higher ilvl | Same ilvl or higher | Same ilvl or higher | Same ilvl or higher | Same ilvl or higher |
| **White** | Higher ilvl | Higher ilvl | Same ilvl or higher | Same ilvl or higher | Same ilvl or higher |
| **Green** | Hidden | Higher ilvl | Higher ilvl | Same ilvl or higher | Same ilvl or higher |
| **Blue** | Hidden | Hidden | Higher ilvl | Higher ilvl | Same ilvl or higher |
| **Epic** | Hidden | Hidden | Hidden | Higher ilvl | Higher ilvl |

"ilvl" is item level, compared with the item in that slot. In short, a drop pops up when:

- the slot is empty, or
- it has a higher item level and is at most one quality tier below what you're wearing, or
- it is higher quality and its item level is not lower.

For rings, trinkets and dual-wielded weapons, the drop is judged against the
weaker of the pair. Gear your class can't use never pops up. Type `/lcomp filter`
to turn the filter off and see every usable drop.

## What it shows

- The looted item and the equipped item, with item levels and the difference
- Every stat you would gain (green) or lose (red) by equipping it
- For rings, trinkets and dual-wielded weapons, the comparison is against the
  weaker of the pair
- For a two-hander, the comparison is against your main hand and off hand together

## What it does

- **Equip button** – equips the item straight from the window. Shows
  "Requires level X" if you can't use it yet, and is disabled in combat.
- **Queue** – several drops line up with `<` and `>` buttons. Items you sell,
  bank or equip drop out on their own.
- **Combat** – the window hides during combat and returns afterwards.
- **Options window** – tick boxes for popups, the upgrade filter, hiding in
  combat and the minimap button, plus buttons to preview the window and reset
  its position. Open it from the minimap button, by typing `/lcomp`, or from
  the game's Options > AddOns list.
- **Minimap button** – left-click opens the options, right-click turns popups
  on or off, drag moves it around the minimap.

## Install

1. **Download** [LootCompare.zip](https://github.com/Jartin47/LootCompare/raw/main/LootCompare.zip).
2. **Extract it.** In File Explorer, right-click `LootCompare.zip`, choose
   **Extract All…**, then **Extract**. You get a folder named `LootCompare`
   containing `LootCompare.toc` and `LootCompare.lua`.
3. **Open your AddOns folder.** By default it is
   `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns`.
   If `Interface` or `AddOns` doesn't exist yet, create it.
4. **Move the `LootCompare` folder into `AddOns`.** The result must look like this:

   ```
   AddOns\LootCompare\LootCompare.toc
   AddOns\LootCompare\LootCompare.lua
   ```

   Windows sometimes extracts to `LootCompare\LootCompare\`. If you see a
   `LootCompare` folder inside another `LootCompare` folder, move the inner one
   into `AddOns`. The game will not find the addon if the two files are nested
   one level too deep, or if they sit loose in `AddOns` without their folder.
5. **Start the game**, or type `/reload` if it is already running. On the
   character select screen, click **AddOns** and make sure **Loot Compare** is ticked.
6. **Check it works:** in game, type `/lcomp test`. A comparison window should
   appear using gear from your bags.

To update, delete the old `AddOns\LootCompare` folder and repeat the steps
above. Your settings are kept.

## Controls

- Right-click the window – dismiss the item shown
- X button – dismiss everything
- Drag – move the window (position is remembered)

## Commands

| Command | Effect |
|---|---|
| `/lcomp` | Open or close the options window |
| `/lcomp help` | List the commands in chat |
| `/lcomp minimap` | Show or hide the minimap button |
| `/lcomp test` | Preview using up to 3 items from your bags |
| `/lcomp filter` | Toggle the upgrade filter |
| `/lcomp combat` | Toggle hiding the window during combat |
| `/lcomp toggle` | Turn popups on or off |
| `/lcomp reset` | Reset the window position |

`/lootcompare` works in place of `/lcomp`.
