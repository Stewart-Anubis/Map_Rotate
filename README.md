# Map_Rotate
Map rotation for empty server.

### Improved version of "quick_map_rotate - Teki Author" plugin with support for CS:GO and CS:S "Do not test CS:S "

* Test & Compile, SouceMod v1.10.0.6528
* Sorry for my English.

* Author Anubis.
* Version = 1.0

### Decription:Map_Rotate

* It changes the maps, based on own or customized “list.txt” list, when the server is empty.
* For the Plugin to work the “sv_hibernate_when_empty” must be set to “0”, although the plugin itself forces this cvar to “0” .
* Possible to configure map switching as random or linear.
* It is possible to set the minimum amount of players to activate the plugin.

### Server ConVars

* sm_mr_enable - (1)Enable or (0)Disable Map Rotation. Default: 1
* sm_mr_timelimit - Time in minutes before changing map when no one is on the server. Default: 20
* sm_mr_player_quota - Number of players needed to cancel anticipated change map. Default: 1
* sm_mr_mapcycle_enabled - (1)Enable or (0)Disable managed mapcycle on empty server. Default: 1
* sm_mr_mapcycle - .txt file, map list.  Default: maplist.txt
* sm_mr_mapcycle_order - Order of changing maps. 1 = Random , 0 = Linear .. Default: 1

### Thanks

* Teki - quick_map_rotate https://forums.alliedmods.net/showthread.php?t=199800
* tabakhase - https://forums.alliedmods.net/showpost.php?p=2216267&postcount=22