-- EdenLost Jail Mod
-- license: Apache 2.0

-- The "jail" and "release" locations should be defined in minetest.conf.
-- If unset, the default to the value of `static_spawnpoint`, and if that is
-- also unset, they default to 0,3,0.
--
-- minetest.conf:
--     jail_pos = x,y,z
--     jail_release_pos = x,y,z
--     jail_scan_seconds = 30
--     jail_max_distance = 10

-- Where to teleport prisoners to.
local jail_pos = {x = 0, y = 3, z = 0}

-- Where to release prisoners to.
local release_pos = {x = 0, y = 3, z = 0}

-- Seconds between scans to send players back to jail.
local jail_scan_seconds = 10

-- How far player may wander from `jail_pos` before teleporting them back to
-- `jail_pos`.
local jail_max_distance = 10

-- File to persist jail data into.
local jail_data_filename = minetest.get_worldpath() .. "/jail-data.txt"

-- key = player name, value is a table (currently write-only)
local players_in_jail = { }


local function format_duration(duration)
  duration = tonumber(duration)
  if duration <= 0 then
    return "forever"
  end

  local result = ""
  if duration >= 86400 then
    result = result .. math.floor(duration / 86400) .. "d "
    duration = duration % 86400
  end

  if duration >= 3600 then
    result = result .. math.floor(duration / 3600) .. "h "
    duration = duration % 3600
  end

  if duration >= 60 then
    result = result .. math.floor(duration / 60) .. "m "
    duration = duration % 60
  end

  if duration > 0 then
    result = result .. duration .. "s "
  end

  -- String likely has a trailing space.  meh.
  return result
end

local function load_jail_data()
  local file = io.open(jail_data_filename, "r")
  if file then
    jailData = minetest.deserialize(file:read("*all"))
    file:close()
  end

  if type(jailData) ~= "table" then
    jailData = {}
  end

  return jailData
end  

local function save_jail_data()
  local file = io.open(jail_data_filename, "w")
  file:write(minetest.serialize(players_in_jail))
  file:close()
end

-- Low level function to release a prisoner, even if they are not logged in.
-- Called from "/release" and via automatic parole.
local function do_release(prisoner)
  -- TODO: Restore any revoked privs, like shout, home, tp
  players_in_jail[prisoner] = nil
  save_jail_data()
end


local function jail_player(jailer, prisoner, duration)
  if (not prisoner) or (prisoner == "") then
    return
  end
  minetest.log("jail_player(" .. jailer .. ", " .. prisoner .. ", "
    .. duration .. ")")

  -- Jail the prisoner, even if they are not logged in.
  players_in_jail[prisoner] = {
    when = os.time(),
    jailer = jailer,
    duration = duration,
    escapes = 0,
  }

  save_jail_data()

  -- If the prisoner is logged in, force them to jail now.
  local player = minetest.get_player_by_name(prisoner)
  if player then
    player:set_pos(jail_pos)
    minetest.chat_send_player(prisoner, "You have been sent to jail")
    -- TODO: Remove "/spawn", "/home", "tp" privs.
  end

  minetest.chat_send_all(prisoner.." has been sent to jail by "..jailer.." for " .. format_duration(duration))
end

local function release_player(jailer, prisoner)
  if prisoner == "" then
    return
  end

  if not players_in_jail[prisoner] then
    minetest.chat_send_player(jailer, "Player '" .. prisoner .. "' was not in jail.")
    return
  end

  do_release(prisoner)

  local player = minetest.get_player_by_name(prisoner)
  if player then
    player:set_pos(release_pos)
    minetest.chat_send_player(prisoner, "You have been released from jail")
    -- TODO: Restore "/spawn", "/home", "tp" privs.
  end

  minetest.chat_send_all(prisoner.." has been released from jail by "..jailer)
end

-- Also handles auto-freeing prisoners when their sentence is up.
local function rejail_escapees ( )
  if type(players_in_jail) ~= "table" then
    players_in_jail = {}
    return
  end

  -- minetest.log("players_in_jail: " .. dump(players_in_jail))
  local is_dirty = false

  for _, player in ipairs(minetest.get_connected_players()) do
    local prisoner = player:get_player_name()
    if (prisoner and players_in_jail[prisoner]) then
      local data = players_in_jail[prisoner]
      if (data.duration > 0) and (os.time() > data.duration + data.when) then
        -- Sentence is over.
        players_in_jail[prisoner] = nil
        player:set_pos(release_pos)
        is_dirty = true
        minetest.chat_send_all(prisoner.. " jail sentence is over.")
      else
        -- Check for escapee status.
        -- Only rejail players if the have gotten "too far" from jail_pos.
        -- This allows them a bit of freedom to wander around in the jail.
        local d = vector.distance(player:get_pos(), jail_pos)
        if d > jail_max_distance then
          player:set_pos(jail_pos)
          data.escapes = data.escapes + 1
          is_dirty = true
          minetest.chat_send_all("Recapturing escaped prisoner " .. prisoner .. "; " .. data.escapes .. " escape attempts. ")
        end
      end
    end
  end

  if is_dirty then
    save_jail_data()
  end

  minetest.after(jail_scan_seconds, rejail_escapees)
end

minetest.register_privilege("jail", { 
    description = "Allows one to send/release prisoners" ,
})

minetest.register_chatcommand("jail", {
    params = "<player> [<duration>]",
    description = "Sends a player to Jail.  'duration' is optional count of seconds, defaults to infinity.",
    privs = {jail=true},
    func = function ( name, param )
      -- Need to match "player_name" or "player_name duration".
      local prisoner, duration = string.match(param, "^([%a%d_-]+)%s+(%d+)$")

      if not prisoner then
        prisoner = string.match(param, "^([%a%d_-]+)")
      end

      -- If duration is not specified, then its forever.
      if not duration then
        duration = 0
      end

      -- If we still have no prisoner, then report error
      if not prisoner then
        minetest.chat_send_player(name, "Expected command format: '/jail name duration' or '/jail name'.")
        return
      end

      jail_player(name, prisoner, tonumber(duration))
    end,
})


minetest.register_chatcommand("release", {
    params = "<player>",
    description = "Releases a player from Jail",
    privs = {jail=true},
    func = function ( name, param )
      release_player(name, param)
    end,
})

minetest.register_alias("wardenpick", "jail:pick_warden")

minetest.register_node("jail:jailwall", {
    description = "Unbreakable Jail Wall",
    tile_images = {"jail_wall.png"},
    is_ground_content = true,
    groups = {unbreakable=1},
    sounds = default.node_sound_stone_defaults(),
})

minetest.register_node("jail:glass", {
    description = "Unbreakable Jail Glass",
    drawtype = "glasslike",
    tile_images = {"jail_glass.png"},
    paramtype = "light",
    sunlight_propagates = true,
    is_ground_content = true,
    groups = {unbreakable=1},
    sounds = default.node_sound_glass_defaults(),
})

minetest.register_node("jail:ironbars", {
    drawtype = "fencelike",
    tiles = {"jail_ironbars.png"},
    inventory_image = "jail_ironbars.png",
    light_propagates = true,
    paramtype = "light",
    is_ground_content = true,
    selection_box = {
      type = "fixed",
      fixed = {-1/7, -1/2, -1/7, 1/7, 1/2, 1/7},
    },
    groups = {unbreakable=1},
    sounds = default.node_sound_stone_defaults(),
})

minetest.register_tool("jail:pick_warden", {
    description = "Warden Pickaxe",
    inventory_image = "jail_wardenpick.png",
    tool_capabilities = {
      full_punch_interval = 0,
      max_drop_level=3,
      groupcaps={
        unbreakable={times={[1]=0, [2]=0, [3]=0}, uses=0, maxlevel=3},
        fleshy = {times={[1]=0, [2]=0, [3]=0}, uses=0, maxlevel=3},
        choppy={times={[1]=0, [2]=0, [3]=0}, uses=0, maxlevel=3},
        bendy={times={[1]=0, [2]=0, [3]=0}, uses=0, maxlevel=3},
        cracky={times={[1]=0, [2]=0, [3]=0}, uses=0, maxlevel=3},
        crumbly={times={[1]=0, [2]=0, [3]=0}, uses=0, maxlevel=3},
        snappy={times={[1]=0, [2]=0, [3]=0}, uses=0, maxlevel=3},
      }
    },
})

local function jail_init()
  local spawn = minetest.setting_get_pos("static_spawnpoint")


  if minetest.setting_get_pos("jail_pos") then
    jail_pos = minetest.setting_get_pos("jail_pos")
  elseif spawn then
    jail_pos = spawn
  end
  minetest.log("jail.jail_pos = " .. minetest.pos_to_string(jail_pos))

  if minetest.setting_get_pos("jail_release_pos") then
    release_pos = minetest.setting_get_pos("jail_release_pos")
  elseif spawn then
    release_pos = spawn
  end
  minetest.log("jail.jail_release_pos = " .. minetest.pos_to_string(release_pos))

  local jmd = tonumber(minetest.settings:get("jail_max_distance"))
  if jmd then
    jail_max_distance = jmd
  end
  minetest.log("jail.jail_max_distance = " .. jail_max_distance)

  local ss = tonumber(minetest.settings:get("jail_scan_seconds"))
  if ss then
    jail_scan_seconds = ss
  end
  minetest.log("jail.jail_scan_seconds = " .. jail_scan_seconds)

  players_in_jail = load_jail_data()
  minetest.log("jail.players_in_jail = " .. #players_in_jail)

  minetest.after(jail_scan_seconds, rejail_escapees)
end

jail_init()

