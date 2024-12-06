# TES3MP Lycanthropy (v0.8.1 Compatible)
A compatibility mod which synchronizes lycanthropy infections for TES3MP.

## Requirements
* DataManager (https://github.com/tes3mp-scripts/DataManager)

## Commands
Adds the following admin commands:

* ``/addlycan (pid)`` Damns a player to life as a werewolf!
* ``/removelycan (pid)`` Similar but opposite the prior command!
* ``/purgelycans`` Cures all cases of lycanthropy in players!

## Installation
After dumping this git into your server's custom folder, you need merely add the following line to customScripts.lua:


``require('custom.Lycanthropy.main')``

## Todo
Currently, this script fails to support Hircine's ring--a feature I intend to introduce eventually. Also noticeably lacking: configuration options! I'll look to adding these at a future date.