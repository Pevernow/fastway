local S=minetest.get_translator("fastway")
local function setting_get(name, default)
	return minetest.settings:get(name) or default
end

local dir = minetest.is_yes(setting_get("sprint_forward_only", "false"))
local mod_player_monoids = minetest.get_modpath("player_monoids") ~= nil
local way_timer_step = 0
local way_timer = 0


local function way_step(player, dtime)
  local name = player:get_player_name()
  local ground_pos = vector.add(player:get_pos(), {x=0,y=-1,z=0})
  local ground_block = minetest.get_node_or_nil(ground_pos)
  --fastblock
  if(ground_block ~=nil) then
	if (ground_block.name=="fastway:track") then
	  if mod_player_monoids then
	    player_monoids.speed:add_change(player,3,"fastway:speed")
		player_monoids.jump:add_change(player,2,"fastway:jump")
	  else
	    player:set_physics_override({speed = 3, jump = 2})
	  end
	else
	  if(ground_block.name=="fastway:trampoline") then
	    if mod_player_monoids then
	      player_monoids.jump:add_change(player,4,"fastway:jump")
		else
	      player:set_physics_override({jump = 4})
		end
	  else
	    if(ground_block.name~="air") then
		  if mod_player_monoids then
		    player_monoids.speed:del_change(player, "fastway:speed")
            player_monoids.jump:del_change(player, "fastway:jump")
		  else
            player:set_physics_override({speed = 1, jump = 1})
		  end
	    end
	  end
	end
  end
  --jetpack
  local inventory = player:get_inventory()
  if inventory:contains_item("main", "fastway:jetpack")==true then
    for i=1,inventory:get_size("main") do
      local jetpack = inventory:get_stack("main", i)
	  if jetpack:get_name()=="fastway:jetpack" then
	    local meta = minetest.deserialize(jetpack:get_metadata())
		if not meta or not meta.charge or meta.mode == nil then
		  break
		end
	    if meta.mode ~= nil and meta.mode ~= "disable" then
		  if meta.mode == "enable" then
		    meta.charge = meta.charge - dtime*600
		  elseif meta.mode == "fast" then
		    meta.charge = meta.charge - dtime*3000
		  end
		  
		  if meta.charge<=0 then
		    meta.charge=0
			meta.enable=false
			player_monoids.fly:del_change(player,"fastway:jetpack")
		  end
		  jetpack:set_metadata(minetest.serialize(meta))
		  technic.set_RE_wear(jetpack, meta.charge, 65535)
		  inventory:set_stack("main", i,jetpack)
		end
	    break
	  end
    end
  end
  
  --wayplacer
  local ctrl = player:get_player_control()
  local key_press
  if dir then
    key_press = ctrl.aux1 and ctrl.up and not ctrl.left and not ctrl.right
  else
    key_press = ctrl.aux1 and (ctrl.up or ctrl.left or ctrl.right or ctrl.down)
  end
  
  if not key_press then
    return
  end
  
  local ground_pos = vector.round(player:get_pos())
  
  local yaw = player:get_look_horizontal()
  local testpos = vector.add(ground_pos, {x=0, y=-1, z=0})
  --bug!
  --[[
  if(yaw>315 or yaw<45) then
    testpos = vector.add(ground_pos, {x=0, y=-1, z=1})
  end 
  if(yaw>135 and yaw<225) then
    testpos = vector.add(ground_pos, {x=0, y=-1, z=-1})
  end
  if(yaw>225 and yaw<315) then
    testpos = vector.add(ground_pos, {x=1, y=-1, z=0})
  end
  if(yaw>45 and yaw<135) then
    testpos = vector.add(ground_pos, {x=-1, y=-1, z=0})
  end
  --]]
  local testnode = minetest.get_node_or_nil(testpos)
  if(testnode~=nil) then
	if(testnode.name=="air") then
	local inv=player:get_inventory()
	  if not inv:is_empty("main") and not inv:get_list("main")[1]:is_empty() and inv:get_list("main")[1]:get_definition() then
	    local placeblocks =inv:get_stack("main",1)
	    local done = pcall(
		  function() 
		    minetest.place_node(testpos,{name=placeblocks:get_name()})
		  end
		)
		if done then
		  placeblocks:take_item()
	      inv:set_stack("main",1,placeblocks)
		end
	  end
	end
  end
end

minetest.register_globalstep(function(dtime)
  way_timer = way_timer + dtime
  if way_timer >= way_timer_step then
    for _, player in ipairs(minetest.get_connected_players()) do
      way_step(player, way_timer)
    end
    way_timer = 0
  end
end)

minetest.register_tool("fastway:parachute",{
  description = S("parachute"),
  inventory_image = "fastway_parachute.png",
  stack_max = 1,
  on_use = function(itemstack, user, pointed_thing)
    local old = user:get_player_velocity()
	user:add_player_velocity({x=0,y=(1-old.y),z=0})
	itemstack:add_wear(2184)--65536/20(times)
	return itemstack
  end
})
minetest.register_craft({
	recipe = {
		{"wool:white", "wool:white", "wool:white"},
		{"default:stick", "", "default:stick"},
		{"", "technic:zinc_ingot", ""},
	},
	output = "fastway:parachute 3"
})

minetest.register_node("fastway:track",{
  description = S("track"),
  inventory_image = "fastway_track.png",
  tiles = {"fastway_track.png", "fastway_track_side.png", "fastway_track_side.png", "fastway_track_side.png", "fastway_track_side.png", "fastway_track_side.png"},
  groups = {crumbly = 3},
  paramtype2 = "facedir",
  is_ground_content = false
})

minetest.register_craft({
	recipe = {
		{"wool:red","technic:zinc_ingot", "wool:red"},
		{"", "default:stone", ""},
		{"", "wool:white", ""},
	},
	output = "fastway:track 3"
})

minetest.register_node("fastway:trampoline",{
  description = S("trampoline"),
  inventory_image = "fastway_trampoline.png",
  tiles = {"fastway_trampoline.png", "fastway_trampoline_side.png", "fastway_trampoline_side.png", "fastway_trampoline_side.png", "fastway_trampoline_side.png", "fastway_trampoline_side.png"},
  groups = {crumbly = 3}
})

minetest.register_craft({
	recipe = {
		{"basic_materials:chain_steel","", "basic_materials:chain_steel"},
		{"wool:yellow", "wool:grey", "wool:yellow"},
		{"default:stick", "technic:zinc_ingot", "default:stick"},
	},
	output = "fastway:trampoline 3"
})

technic.register_power_tool("fastway:jetpack", 65535)
minetest.register_tool("fastway:jetpack", {
	description = S("jetpack"),
	inventory_image = "fastway_jetpack.png",
	stack_max = 1,
	wear_represents = "technic_RE_charge",
	on_refill = technic.refill_RE_charge,
	on_use = function(itemstack, player, pointed_thing)
	    local meta = minetest.deserialize(itemstack:get_metadata())
		if not meta then
		    return
		end
		if meta.mode == nil then
		    meta.mode = "disable"
		end
	    if meta.mode=="disable" then
	        player_monoids.fly:add_change(player,true,"fastway:jetpack")
			player_monoids.speed:del_change(player,"fastway:jetpack")
			meta.mode = "enable"
		elseif meta.mode=="enable" then
		    player_monoids.speed:add_change(player,3,"fastway:jetpack")
		    player_monoids.fly:add_change(player,true,"fastway:jetpack")
			meta.mode = "fast"
		elseif meta.mode=="fast" then
		    player_monoids.fly:del_change(player,"fastway:jetpack")
			player_monoids.speed:del_change(player,"fastway:jetpack")
			meta.mode = "disable"
		end
		minetest.chat_send_player(player:get_player_name(), meta.mode)
		itemstack:set_metadata(minetest.serialize(meta))
		return itemstack
	end
})
minetest.register_craft({
	recipe = {
		{"technic:battery","default:obsidian", "technic:battery"},
		{"dye:red", "default:obsidian", "dye:red"},
		{"technic:rubber", "technic:diamond_drill_head", "technic:rubber"},
	},
	output = "fastway:jetpack"
})
