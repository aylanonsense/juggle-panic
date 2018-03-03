pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

function noop() end

local entities

local entity_classes={
	juggler={
		width=14,
		height=8,
		move_x=0,
		update=function(self)
			self.move_x=ternary(btn(1,self.player_num),1,0)-
				ternary(btn(0,self.player_num),1,0)
			self.vx=3*self.move_x
		end,
		draw=function(self)
			self:draw_outline()
		end
	},
	ball={
		width=5,
		height=5,
		is_being_thrown=false,
		init=function(self)
			self.prev_x,self.prev_y=self.x,self.y
		end,
		update=function(self)
			self.prev_x,self.prev_y=self.x,self.y
			if self.is_being_thrown then
				local percent=1-self.throw_frames/self.throw_duration
				local dx,dy=parabola(percent,
					self.throw_distance,self.throw_height)
				self.x=self.throw_start_x+dx
				self.y=self.throw_start_y+dy
				self.vx=self.x-self.prev_x
				self.vy=self.y-self.prev_y
				self.throw_frames-=1
				if self.throw_frames<0 then
					self.throw_frames=0
					self.is_being_thrown=false
				end
			end
			return true -- skip apply_velocity
		end,
		draw=function(self)
			self:draw_outline()
			circfill(self.x+self.width/2,self.y+self.height/2,2,10)
		end,
		throw=function(self,distance,height,duration)
			self.is_being_thrown=true
			self.throw_start_x=self.x
			self.throw_start_y=self.y
			self.throw_distance=distance
			self.throw_height=height
			self.throw_frames=duration
			self.throw_duration=duration
		end
	},
	ball_spawner={}
}

function _init()
	entities={}
	spawn_entity("juggler",10,90,{
		player_num=1
	})
	spawn_entity("juggler",80,90,{
		player_num=0
	})
	local ball=spawn_entity("ball",64,100)
	ball:throw(30,80,100)
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
	rect(0,0,127,127,1)
	-- draw each entity
	local entity
	foreach(entities,function(entity)
		entity:draw()
	end)
end

function spawn_entity(class_name,x,y,args,skip_init)
	local entity
	local the_class=entity_classes[class_name]
	if the_class.extends then
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
			width=0,
			height=0,
			init=noop,
			update=noop,
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

-- get a point along a parabola
function parabola(percent,distance,height)
	return percent*distance,-height+(2*percent-1)*(2*percent-1)*height
end




