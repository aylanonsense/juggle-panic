pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

function noop() end

-- what to do next
-- - jugglers can catch and throw balls

local entities

local entity_classes={
	juggler={
		width=14,
		height=8,
		move_x=0,
		update=function(self)
			-- move horizontally when left/right buttons are pressed
			self.move_x=ternary(btn(1,2-self.player_num),1,0)-
				ternary(btn(0,2-self.player_num),1,0)
			self.vx=3*self.move_x
			self:apply_velocity()
			-- keep the juggler in bounds
			self.x=mid(self.min_x,self.x,self.max_x-self.width)
		end,
		draw=function(self)
			self:draw_outline(14)
		end
	},
	ball={
		width=5,
		height=5,
		is_being_thrown=false,
		gravity=0,
		update=function(self)
			self.vy+=self.gravity
			self:apply_velocity()
		end,
		draw=function(self)
			self:draw_outline(14)
			circfill(self.x+self.width/2,self.y+self.height/2,2,10)
		end,
		throw=function(self,distance,height,duration)
			-- let's do some fun math to calculate out the trajectory
			-- duration must be <=180, otherwise overflow will ruin the math
			-- it looks best if duration is an even integer (you get to see the apex)
			local n=(duration+1)*duration/2
			local m=(duration/2+1)*duration/4
			self.vy=n/(m-n/2)
			self.vy*=height/duration
			self.gravity=-self.vy*duration/n
			self.vx=distance/duration
		end
	},
	ball_spawner={}
}

function _init()
	entities={}
	spawn_entity("juggler",10,90,{
		player_num=1,
		min_x=0,
		max_x=64
	})
	spawn_entity("juggler",80,90,{
		player_num=2,
		min_x=64,
		max_x=128
	})
	ball=spawn_entity("ball",0,123)
	ball:throw(123,123,180)
end

-- local skip_frames=0
function _update()
	-- skip_frames+=1
	-- if skip_frames%20>0 then return end

	-- sort entities for updating
	sort(entities,function(entity1,entity2)
		return entity1.update_priority>entity2.update_priority
	end)
	-- update each entity
	local num_entities=#entities
	local i,entity
	for i=1,num_entities do
		local entity=entities[i]
		increment_counter_prop(entity,"frames_alive")
		entity:update()
		if decrement_counter_prop(entity,"frames_to_death") then
			entity:die()
		end
	end
	for i=1,num_entities do
		entities[i]:post_update()
	end
	-- filter out dead entities
	filter(entities,function(entity)
		return entity.is_alive
	end)
	-- sort entities for rendering
	sort(entities,function(entity1,entity2)
		return entity1.render_layer>entity2.render_layer
	end)
end

function _draw()
	-- clear the screen
	cls()
	-- draw the sky
	rectfill(0,0,127,127,8)
	pset(0,0,0)
	pset(127,0,0)
	-- draw each entity
	local entity
	foreach(entities,function(entity)
		entity:draw()
	end)
	-- draw the ground
	rectfill(0,110,127,127,0)
	pset(0,109,0)
	pset(127,109,0)
	pset(63,109,0)
	pset(64,109,0)
end

function spawn_entity(class_name,x,y,args,skip_init)
	local entity
	local the_class=entity_classes[class_name]
	if the_class.extends then
		entity=spawn_entity(the_class.extends,x,y,args,true)
	else
		-- create default entity
		entity={
			is_alive=true,
			frames_alive=0,
			frames_to_death=0,
			update_priority=0,
			render_layer=0,
			x=x or 0,
			y=y or 0,
			vx=0,
			vy=0,
			width=0,
			height=0,
			init=noop,
			update=function()
				self:apply_velocity()
			end,
			post_update=noop,
			draw=noop,
			draw_outline=function(self,color)
				rect(self.x+0.5,self.y+0.5,
					self.x+self.width-0.5,self.y+self.height-0.5,color or 8)
			end,
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

-- if condition is true return the second argument, otherwise the third
function ternary(condition,if_true,if_false)
	return condition and if_true or if_false
end

-- increment a counter, wrapping to 20000 if it risks overflowing
function increment_counter(n)
	return n+ternary(n>32000,-12000,1)
end

-- increment_counter on a property of an object
function increment_counter_prop(obj,k)
	obj[k]=increment_counter(obj[k])
end

-- decrement a counter but not below 0
function decrement_counter(n)
	return max(0,n-1)
end

-- decrement_counter on a property of an object, returns true when it reaches 0
function decrement_counter_prop(obj,k)
	if obj[k]>0 then
		obj[k]=decrement_counter(obj[k])
		return obj[k]<=0
	end
end

-- filter out anything in list for which func is false
function filter(list,func)
	local item
	for item in all(list) do
		if not func(item) then
			del(list,item)
		end
	end
end

-- bubble sorts a list according to a comparison func
function sort(list,func)
	local i
	for i=1,#list do
		local j=i
		while j>1 and func(list[j-1],list[j]) do
			list[j],list[j-1]=list[j-1],list[j]
			j-=1
		end
	end
end
