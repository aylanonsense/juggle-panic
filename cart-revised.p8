pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

function noop() end

local catch_fudge=1
local ground_y=110

-- what to do next
-- - jugglers can catch and throw balls

-- balls update first
-- then jugglers update
--   1. throw
--   2. catch
-- balls can die now

local entities
local balls

local entity_classes={
	juggler={
		width=14,
		height=8,
		move_x=0,
		left_hand_ball=nil,
		right_hand_ball=nil,
		init=function(self)
			self:calc_hand_hitboxes()
		end,
		update=function(self)
			-- move horizontally when left/right buttons are pressed
			self.move_x=ternary(btn(1,2-self.player_num),1,0)-
				ternary(btn(0,2-self.player_num),1,0)
			self.vx=3*self.move_x
			self:apply_velocity()
			-- keep the juggler in bounds
			if self.x<self.min_x then
				self.x=self.min_x
				self.vx=max(0,self.vx)
			elseif self.x>self.max_x-self.width then
				self.x=self.max_x-self.width
				self.vx=min(0,self.vx)
			end
			-- debug: spawn balls
			if btnp(4,2-self.player_num) then
				local ball=spawn_entity("ball",self.x,self.y)
				ball:throw(rnd(1000)-500,rnd(60)+20,10)
			end
			-- catch balls
			self:calc_hand_hitboxes()
			local ball
			for ball in all(balls) do
				-- if self.left_hand_hitbox then
			end
		end,
		draw=function(self)
			self:draw_outline(14)
			if self.left_hand_hitbox!=nil then
				rect(self.left_hand_hitbox.x+0.5,self.left_hand_hitbox.y+0.5,self.left_hand_hitbox.x+self.left_hand_hitbox.width-0.5,self.left_hand_hitbox.y+self.left_hand_hitbox.height-0.5,7)
			end
			if self.right_hand_hitbox!=nil then
				rect(self.right_hand_hitbox.x+0.5,self.right_hand_hitbox.y+0.5,self.right_hand_hitbox.x+self.right_hand_hitbox.width-0.5,self.right_hand_hitbox.y+self.right_hand_hitbox.height-0.5,7)
			end
			-- rect(self.x+0.5,self.y+0.5,self.x+self.width/2-0.5,self.y+self.height-0.5,7)
			-- rect(self.x+self.width/2+0.5,self.y+0.5,self.x+self.width-0.5,self.y+self.height-0.5,10)
		end,
		calc_hand_hitboxes=function(self)
			if self.left_hand_ball then
				self.left_hand_hitbox=nil
			else
				self.left_hand_hitbox={
					x=self.x,
					y=self.y+1,
					width=self.width/2,
					height=self.height-1
				}
				if self.vx<0 then
					self.left_hand_hitbox.x+=self.vx
					self.left_hand_hitbox.width-=self.vx
				else
					self.left_hand_hitbox.x-=catch_fudge
					self.left_hand_hitbox.width+=catch_fudge
				end
				if self.right_hand_ball then
					if self.vx>0 then
						self.left_hand_hitbox.width+=self.vx
					else
						self.left_hand_hitbox.width+=catch_fudge
					end
				end
			end
			if self.right_hand_ball then
				self.right_hand_hitbox=nil
			else
				self.right_hand_hitbox={
					x=self.x+self.width/2,
					y=self.y+1,
					width=self.width/2,
					height=self.height-1
				}
				if self.vx>0 then
					self.right_hand_hitbox.width+=self.vx
				else
					self.right_hand_hitbox.width+=catch_fudge
				end
				if self.left_hand_ball then
					if self.vx<0 then
						self.right_hand_hitbox.x+=self.vx
						self.right_hand_hitbox.width-=self.vx
					else
						self.right_hand_hitbox.x-=catch_fudge
						self.right_hand_hitbox.width+=catch_fudge
					end
				end
			end
		end
	},
	ball={
		width=5,
		height=5,
		is_being_thrown=false,
		gravity=0,
		add_to_game=function(self)
			add(balls,self)
		end,
		remove_from_game=function(self)
			del(balls,self)
		end,
		init=function(self)
			self:calc_hurtbox()
			self.energy=self.vy*self.vy/2+self.gravity*(ground_y-self.y)
		end,
		update=function(self)
			self.vy+=self.gravity
			self:apply_velocity()
			self:calc_hurtbox()
			-- bounce off walls
			if self.x<0 then
				self.x=0
				self:calc_hurtbox()
				if self.vx<0 then
					self.vx*=-1
				end
			elseif self.x>127-self.width then
				self.x=127-self.width
				self:calc_hurtbox()
				if self.vx>0 then
					self.vx*=-1
				end
			end
			-- bounce off the ground
			if self.y>ground_y-self.height then
				self.y=ground_y-self.height
				self:calc_hurtbox()
				if self.vy>0 then
					-- we do this so that balls don't lose energy over time
					self.vy=-sqrt(2*self.energy)
				end
			end
		end,
		draw=function(self)
			-- self:draw_outline(7)
			rect(self.hurtbox.x+0.5,self.hurtbox.y+0.5,self.hurtbox.x+self.hurtbox.width-0.5,self.hurtbox.y+self.hurtbox.height-0.5,7)
			circfill(self.x+self.width/2,self.y+self.height/2,2,12)
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
			-- calculate kinetic and potential energy too
			self.energy=self.vy*self.vy/2+self.gravity*(ground_y-self.y)
		end,
		calc_hurtbox=function(self)
			self.hurtbox={
				x=self.x,
				y=self.y,
				width=self.width,
				height=self.height
			}
			if self.vy>0 then
				self.hurtbox.y-=self.vy
				self.hurtbox.height+=self.vy
			elseif self.vy<0 then
				self.hurtbox.height-=self.vy
			end
			if self.vx<0 then
				self.hurtbox.width+=mid(0,-self.vx,2)
			end
			if self.vx>0 then
				self.hurtbox.x-=mid(0,self.vx,2)
				self.hurtbox.width+=mid(0,self.vx,2)
			end
		end
	},
	ball_spawner={}
}

function _init()
	entities={}
	balls={}
	spawn_entity("juggler",10,ground_y-8,{
		player_num=1,
		min_x=0,
		max_x=64
	})
	spawn_entity("juggler",80,ground_y-8,{
		player_num=2,
		min_x=64,
		max_x=128
	})
	-- ball=spawn_entity("ball",0,123)
	-- ball:throw(123,123,180)
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
	for entity in all(entities) do
		if not entity.is_alive then
			del(entities,entity)
			entity:remove_from_game()
		end
	end
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
	rectfill(0,ground_y,127,127,0)
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
			add_to_game=noop,
			remove_from_game=noop,
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
		entity:add_to_game()
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
-- function filter(list,func)
-- 	local item
-- 	for item in all(list) do
-- 		if not func(item) then
-- 			del(list,item)
-- 		end
-- 	end
-- end

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

-- check to see if two axis-aligned rectangles are overlapping
function rects_overlapping(x1,y1,w1,h1,x2,y2,w2,h2)
	if type(x2)=="table" then
		x2,y2,w2,h2=x2.x,x2.y,x2.width,x2.height
	elseif type(y1)=="table" then
		x2,y2,w2,h2=y1.x,y1.y,y1.width,y1.height
	end
	if type(x1)=="table" then
		x1,y1,w1,h1=x1.x,x1.y,x1.width,x1.height
	end
	return x1+w1>x2 and x2+w2>x1 and y1+h1>y2 and y2+h2>y1
end
