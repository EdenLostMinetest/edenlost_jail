# edenlost_jail
Custom jail mod for EdenLost

Adds the `jail` priv.  Players with the `jail` priv can send players
to jail, or release them from jail.

The "jail" is an in-game area used to isolate misbehaving players.  This mod
does not construct a jail; you must do that yourself.

Jail data is persisted to storage in the file `jail-data.txt`, placed in the
server's `world` directory (same dir as the `map.sqlite` file).

## Commands

1. `/jail player [duration]` - Jails player for an optional duration
   (integer count of seconds - defaults to 0, which means "forever").
1. `/release player` - Releases player from jail, and teleports them to
   the release point, or to spawn in no specific release point was defined.

### Examples

Example command usage:

```
/grant AdminPlayer jail
/jail bad_player 3600
/jail really_bad_player
/release bad_player
```

### Duration hints

| Duration | Human Readable |
| -------- | ------------------------------ |
| (none) | Infinite |
| 1 | 1 second |
| 60 | 1 minute |
| 100 | 1 minute, 40 seconds |
| 600 | 10 minutes |
| 3600 | 1 hour |
| 9999 | 2 hours, 46 minutes, 39 seconds |
| 86400 | 1 day |
| 999999 | ~11.6 days |


## Settings (minetest.conf)

1. `jail_pos` - Where to teleport jailed players to.
1. `jail_release_pos` - Where to teleport released players to.
1. `jail_scan_seconds` - How often to scan for escapees.
   - Do not make this too fast, or server performance could suffer.
1. `jail_max_distance` - How many nodes a player can be away from before being
    considered an 'escapee' and teleported back to jail.

### Example:

```
# Jail
jail_pos = 605,179,-623
jail_release_pos = 0,3,0
jail_scan_seconds = 10
jail_max_distance = 10
```

## Nodes and Tools
This mod also defines a few custom nodes useful for constructing a jail:

1. `jail:jailwall` - Unbreakable jail wall.
1. `jail:glass` - Unbreakable jail glass.
1. `jail:ironbars` - Unbreakable jail bars.

And a non-craftable tool that can break these unbreakable blocks:

1. `jail:pick_warden`


### Examples

```
/giveme jail:pick_warden
/giveme jail:jailwall
/giveme jail:glass
/giveme jail:ironbars
```
