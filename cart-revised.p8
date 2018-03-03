pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

function noop() end

local entities

local entity_classes={}

function _init()
	entities={}
end

function _update()
	local num_entities=#entities

	-- update each entity
	local i,entity
	for i=1,num_entities do
		local entity=entities[i]
		local skip_apply_velocity=entity:update()
		if not skip_apply_velocity then
			entity:apply_velocity()
		end
	end
end

function _draw()
	-- clear the screen
	cls()
	-- draw each entity
	local entity
	foreach(entities,function(entity)
		entity:draw()
	end)
end

function spawn_entity(class_name,x,y,args,skip_init)
	local entity
	local the_class=entity_classes[class_name]
	if the_class.extends>0 then
		entity=spawn_entity(the_class.extends,x,y,args,true)
	else
		-- create default entity
		entity={
			frames_alive=0,
			frames_to_death=0,
			render_layer=5,
			x=x or 0,
			y=y or 0,
			vx=0,
			vy=0,
			init=noop,
			update=noop,
			draw=noop,
			die=function(self)
				if self.is_alive then
					self:on_death()
					self.is_alive=false
				end
			end,
			on_death=noop,
			apply_velocity=function(self)
				self.x+=self.vx
				self.y+=self.vy
			end
		}
	end
	-- add class properties/methods onto it
	local k,v
	for k,v in pairs(the_class) do
		entity[k]=v
	end
	-- add properties onto it from the arguments
	for k,v in pairs(args or {}) do
		entity[k]=v
	end
	if not skip_init then
		-- initialize it
		entity:init()
		add(entities,entity)
	end
	-- return it
	return entity
end
