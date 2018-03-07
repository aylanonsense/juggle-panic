pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

--[[
todo:
	ball speed gradually increases
	a tracker shows the current ball speed
	particles spawn when a ball is dropped
	the title screen has a pretty title
	the title screen has balls flying past
	the title screen has music
	balls spawn periodically, dependent on circumstances
	balls can collide in mid-air
	sound effects
	there are plenty of wacky game modes to have fun with

scenes:
	title
	title->game
	game-start
	game
	game-end
	game->title

update_priority:
	1:	juggler_icon
	2:	ball_icon
	3:	score_track
	4:	ball_spawner
	5:	juggler
	6:	ball
	7:	game_over_text_geysers
	8:	mode_select
	9:	title_screen
	10:	camera_operator

render_layer:
	1:	game_over_text_geysers
	2:	ball
	3:	ball_spawner
	4:	juggler
	10:	score_track
	11:	juggler_icon
	12:	ball_icon
	13:	mode_select
	14:	title_screen
	15:	camera_operator
]]

function noop() end

local controllers={1,0}
local catch_fudge=1
local left_wall_x=1
local midpoint_x=64
local right_wall_x=127
local ground_y=114
local sky_y=1
local ball_colors={8,9,10,11,12}
local dark_ball_colors={2,4,4,3,1}
local modes={
	"normal mode",
	"bomb mode","strong arm mode","cooperative mode","bouncy ball mode",
	"long arms mode","infiniball mode","hot potato mode","floaty mode",
	"blackout mode","speedball mode","random"
}

local buttons
local button_presses
local button_releases
local buffered_button_presses

local scene
local game_frame
local screen_shake_frames
local entities
local new_entities
local jugglers
local balls
local title_screen
local camera_operator

local entity_classes={
	juggler={
		update_priority=5,
		render_layer=4,
		width=18,
		height=11,
		move_x=0,
		left_hand_ball=nil,
		right_hand_ball=nil,
		most_recent_catch_hand=nil,
		anim=nil,
		anim_frames=0,
		sprite_num=0,
		sprite_flipped=false,
		stationary_frames=0,
		wiggle_frames=0,
		throw_cooldown_frames=0,
		add_to_game=function(self)
			jugglers[self.player_num]=self
		end,
		on_scene_change=function(self)
			self.is_paused=(scene=="title->game")
			if scene=="game-end" then
				self.spawner=nil
				self.left_hand_ball=nil
				self.right_hand_ball=nil
			elseif scene=="title" then
				self:die()
			end
		end,
		init=function(self)
			self:calc_hand_hitboxes()
		end,
		update=function(self)
			local controller=controllers[self.player_num]
			-- move horizontally when left/right buttons are pressed
			self.move_x=ternary(buttons[controller][1],1,0)-
				ternary(buttons[controller][0],1,0)
			local move_speed=1+ternary(self.left_hand_ball,0,1)+ternary(self.right_hand_ball,0,1)
			self.vx=move_speed*self.move_x
			-- don't move if forced to be stationary (during throws/catches)
			if self.stationary_frames>0 then
				self.vx=0
			end
			decrement_counter_prop(self,"stationary_frames")
			self:apply_velocity()
			-- keep the juggler in bounds
			if self.x<self.min_x then
				self.x=self.min_x
				self.vx=max(0,self.vx)
			elseif self.x>self.max_x-self.width then
				self.x=self.max_x-self.width
				self.vx=min(0,self.vx)
			end
			-- throw balls
			decrement_counter_prop(self,"throw_cooldown_frames")
			if (buffered_button_presses[controller][4]>0 or buffered_button_presses[controller][5]>0) and self.throw_cooldown_frames<=0 then
				buffered_button_presses[controller][4]=0
				buffered_button_presses[controller][5]=0
				local preferred_throw_hand=ternary(self.most_recent_catch_hand=="left","right","left")
				if self.move_x<0 then
					preferred_throw_hand="left"
				elseif self.move_x>0 then
					preferred_throw_hand="right"
				end
				if self.left_hand_ball or self.right_hand_ball then
					self.anim="throw"
					self.anim_frames=20
					self.wiggle_frames=0
					self.vx=0
					self.stationary_frames=max(6,self.stationary_frames)
					self.throw_cooldown_frames=4
				end
				-- throw with the left hand unless the right hand is preferred and can throw instead
				local thrown_ball
				if self.left_hand_ball and (preferred_throw_hand=="left" or not self.right_hand_ball) then
					self.sprite_flipped=false
					self:reposition_held_balls()
					thrown_ball=self.left_hand_ball
					self.left_hand_ball=nil
				elseif self.right_hand_ball then
					self.sprite_flipped=true
					self:reposition_held_balls()
					thrown_ball=self.right_hand_ball
					self.right_hand_ball=nil
				end
				if thrown_ball then
					local throw_dist=63
					local ball_center=thrown_ball.x+thrown_ball.width/2
					local landing_x=ball_center+self.throw_dir*throw_dist
					-- make it a little more obvious which side the ball is going to land on
					if landing_x==mid(midpoint_x-4,landing_x,midpoint_x) then
						throw_dist=self.throw_dir*(midpoint_x-4-ball_center)
					end
					if landing_x==mid(midpoint_x,landing_x,midpoint_x+4) then
						throw_dist=self.throw_dir*(midpoint_x+4-ball_center)
					end
					thrown_ball:throw(self.throw_dir*throw_dist,80,60)
				end
			end
			-- catch balls
			self:calc_hand_hitboxes()
			local ball
			for ball in all(balls) do
				if not ball.is_held_by_juggler and ball.vy>=0 and (not ball.is_held_by_spawner or ball.spawner.is_above_ground) then
					local is_catching_with_left_hand=(self.left_hand_hitbox and rects_overlapping(self.left_hand_hitbox,ball.hurtbox))
					local is_catching_with_right_hand=(self.right_hand_hitbox and rects_overlapping(self.right_hand_hitbox,ball.hurtbox))
					if is_catching_with_left_hand or is_catching_with_right_hand then
						if ball.is_held_by_spawner then
							ball.spawner.held_ball=nil
							ball.spawner=nil
							ball.is_held_by_spawner=false
							self.stationary_frames=max(2,self.stationary_frames)
						else
							self.stationary_frames=max(3,self.stationary_frames)
						end
						self.anim_frames=20
						self.anim="catch"
						self.wiggle_frames=0
						self.vx=0
						self.throw_cooldown_frames=ternary(self.left_hand_ball or self.right_hand_ball,0,min(4,self.throw_cooldown_frames))
					end
					-- catch with the left hand if the right can't catch it or if the right is farther from the ball
					if is_catching_with_left_hand and (not is_catching_with_right_hand or ball.x+ball.width/2<self.x+self.width/2) then
						self.left_hand_ball=ball
						self.left_hand_hitbox=nil
						ball:catch()
						self.sprite_flipped=true
						self.most_recent_catch_hand="left"
					-- otherwise catch with the right hand
					elseif is_catching_with_right_hand then
						self.right_hand_ball=ball
						self.right_hand_hitbox=nil
						ball:catch()
						self.sprite_flipped=false
						self.most_recent_catch_hand="right"
					end
				end
			end
			-- calc render data
			if self.anim and self.vx!=0 then
				self.anim_frames=0
				self.anim=nil
				self.sprite_flipped=not self.sprite_flipped
			end
			if decrement_counter_prop(self,"anim_frames") then
				self.anim=nil
				self.sprite_flipped=not self.sprite_flipped
			end
			if self.anim=="catch" then
				self.sprite_num=2
			elseif self.anim=="throw" then
				self.sprite_num=1
			else
				self.sprite_num=0
			end
			if not self.anim then
				increment_counter_prop(self,"wiggle_frames")
				if self.wiggle_frames>ternary(self.move_x==0,20,4) then
					self.sprite_flipped=not self.sprite_flipped
					self.wiggle_frames=0
				end
			end
			-- reposition any held balls
			self:reposition_held_balls()
		end,
		draw=function(self)
			-- self:draw_outline(14)
			pal(7,0)
			draw_sprite(0,8+14*self.sprite_num,18,14,self.x,self.y-3,self.sprite_flipped)
			-- draw hitboxes
			-- pal()
			-- if self.left_hand_hitbox then
			-- 	rect(self.left_hand_hitbox.x+0.5,self.left_hand_hitbox.y+0.5,self.left_hand_hitbox.x+self.left_hand_hitbox.width-0.5,self.left_hand_hitbox.y+self.left_hand_hitbox.height-0.5,7)
			-- end
			-- if self.right_hand_hitbox then
			-- 	rect(self.right_hand_hitbox.x+0.5,self.right_hand_hitbox.y+0.5,self.right_hand_hitbox.x+self.right_hand_hitbox.width-0.5,self.right_hand_hitbox.y+self.right_hand_hitbox.height-0.5,7)
			-- end
		end,
		calc_hand_hitboxes=function(self)
			if self.left_hand_ball then
				self.left_hand_hitbox=nil
			else
				self.left_hand_hitbox={
					x=self.x,
					y=self.y+1,
					width=6,
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
					x=self.x+self.width-6,
					y=self.y+1,
					width=6,
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
		end,
		reposition_held_balls=function(self)
			-- calculate hand positions
			local lx,ly,rx,ry
			if self.sprite_num==2 then
				lx,ly,rx,ry=7,2,7,8
			elseif self.sprite_num==1 then
				lx,ly,rx,ry=7,1,7,7
			else
				lx,ly,rx,ry=7,3,7,7
			end
			if self.sprite_flipped then
				lx,ly,rx,ry=rx,ry,lx,ly
			end
			-- move any held balls to those positions
			if self.left_hand_ball then
				self.left_hand_ball.x=self.x+self.width/2-lx-2
				self.left_hand_ball.y=self.y+ly-self.left_hand_ball.height
			end
			if self.right_hand_ball then
				self.right_hand_ball.x=self.x+self.width/2+rx+2-self.right_hand_ball.width
				self.right_hand_ball.y=self.y+ry-self.right_hand_ball.height
			end
		end
	},
	juggler_icon={
		update_priority=1,
		render_layer=11,
		y=ground_y+1,
		width=18,
		height=3,
		visibility_frames=0,
		on_scene_change=function(self)
			if scene=="title" then
				self:die()
			end
		end,
		update=function(self)
			decrement_counter_prop(self,"visibility_frames")
		end,
		draw=function(self)
			if self.visibility_frames>0 then
				line(self.x+0.5,self.y+0.5,self.x+0.5,self.y+self.height-0.5,1)
				line(self.x+0.5,self.y+1.5,self.x+self.width-0.5,self.y+1.5,1)
				line(self.x+self.width-0.5,self.y+0.5,self.x+self.width-0.5,self.y+self.height-0.5,1)
			end
		end,
		show=function(self,juggler)
			self.x=juggler.x
			self.visibility_frames=90
		end
	},
	ball={
		update_priority=6,
		render_layer=2,
		width=5,
		height=5,
		gravity=0,
		freeze_frames=0,
		bounce_dir=nil,
		is_held_by_juggler=false,
		is_held_by_spawner=false,
		color=7,
		add_to_game=function(self)
			add(balls,self)
		end,
		remove_from_game=function(self)
			del(balls,self)
		end,
		on_scene_change=function(self)
			if scene=="game-end" then
				self:die()
			end
		end,
		init=function(self)
			self:calc_hurtbox()
			self.energy=self.vy*self.vy/2+self.gravity*(ground_y-self.y-self.height)
		end,
		update=function(self)
			if not self.is_held_by_juggler and not self.is_held_by_spawner then
				if self.freeze_frames>0 then
					decrement_counter_prop(self,"freeze_frames")
				else
					self.bounce_dir=nil
					self.vy+=self.gravity
					self:apply_velocity()
					self:calc_hurtbox()
					-- bounce off walls
					if self.x<left_wall_x then
						self.x=left_wall_x
						self:calc_hurtbox()
						if self.vx<0 then
							self.vx*=-1
							self.bounce_dir="left"
							self.freeze_frames=1
						end
					elseif self.x>right_wall_x-self.width then
						self.x=right_wall_x-self.width
						self:calc_hurtbox()
						if self.vx>0 then
							self.vx*=-1
							self.bounce_dir="right"
							self.freeze_frames=1
						end
					end
					-- bounce off the ground
					-- if self.y>ground_y-self.height then
					-- 	self.y=ground_y-self.height
					-- 	self:calc_hurtbox()
					-- 	if self.vy>0 then
					-- 		-- we do this so that balls don't lose energy over time
					-- 		self.vy=-sqrt(2*self.energy)
					-- 		self.bounce_dir="down"
					-- 		self.freeze_frames=2
					-- 	end
					-- end
				end
			end
		end,
		post_update=function(self)
			-- balls that hit the ground die
			if not self.is_held_by_juggler and not self.is_held_by_spawner and self.y>=ground_y-self.height then
				self:die()
				shake_screen(10)
				local player_num=ternary(self.x+self.width/2<midpoint_x,1,2)
				jugglers[player_num].score_track:add_mark(self.color)
				local juggler=jugglers[player_num]
				juggler.icon:show(juggler)
				local ball_icon=spawn_entity("ball_icon",self.x,ground_y,{color=self.color})
				if #juggler.score_track.marks>=1 then
					change_scene("game-end")
				end
			end
		end,
		draw=function(self)
			-- each ball has a color
			colorwash(self.color)
			-- draw the ball squished against the wall/ground
			if self.bounce_dir then
				if self.bounce_dir=="left" or self.bounce_dir=="right" then
					if abs(self.vx)<1 then
						spr(0,self.x-0.5,self.y-0.5)
					else
						draw_sprite(ternary(abs(self.vx)>5,40,36),88,4,9,self.x+ternary(self.bounce_dir=="right",1,0),self.y-2,self.bounce_dir=="left")
					end
				elseif self.bounce_dir=="down" then
					if abs(self.vy)<4 then
						spr(0,self.x-0.5,self.y-0.5)
					else
						draw_sprite(24,ternary(abs(self.vy)>18,80,76),9,4,self.x-2,self.y+1)
					end
				end
			else
				local speed=sqrt(self.vx*self.vx+self.vy*self.vy)
				-- if it's going slow, just draw an undeformed ball
				if speed<5 then
					spr(0,self.x-0.5,self.y-0.5)
				-- otherwise draw a deformed version
				else
					local angle=atan2(self.vx,self.vy)
					local flip_horizontal=(self.vx<0)
					local flip_vertical=(self.vy>0)
					-- figure out which sprite we're going to use
					local sprite_num=flr(24*angle+0.5)
					if flip_vertical then
						sprite_num=24-sprite_num
					end
					if flip_horizontal then
						sprite_num=12-sprite_num
					end
					-- find the right sprite location based on angle
					local sy,sw,sh
					if sprite_num==0 then
						sy,sw,sh=123,16,5
					elseif sprite_num==1 then
						sy,sw,sh=117,15,6
					elseif sprite_num==2 then
						sy,sw,sh=108,13,9
					elseif sprite_num==3 then
						sy,sw,sh=97,11,11
					elseif sprite_num==4 then
						sy,sw,sh=84,9,13
					elseif sprite_num==5 then
						sy,sw,sh=69,6,15
					elseif sprite_num==6 then
						sy,sw,sh=53,5,16
					end
					-- find the right sprite location based on speed
					local sx=mid(0,flr((speed-5)/9),3)*sw
					local x,y=self.x,self.y
					-- handle the other 270 degrees
					if not flip_horizontal then
						x+=self.width-sw
					end
					if flip_vertical then
						y+=self.height-sh
					end
					-- draw the sprite
					draw_sprite(sx,sy,sw,sh,x,y,flip_horizontal,flip_vertical)
				end
			end
		end,
		throw=function(self,distance,height,duration)
			self.is_held_by_juggler=false
			-- let's do some fun math to calculate out the trajectory
			-- duration must be <=180, otherwise overflow will ruin the math
			-- it looks best if duration is an even integer (you get to see the apex)
			local n=(duration+1)*duration/2
			local m=(duration/2+1)*duration/4
			self.vy=n/(m-n/2)
			self.vy*=height/duration
			self.gravity=-self.vy*duration/n
			self.vx=distance/duration
			-- calculate kinetic and potential energy
			self.energy=self.vy*self.vy/2+self.gravity*(ground_y-self.y-self.height)
		end,
		catch=function(self)
			self.is_held_by_juggler=true
			self.freeze_frames=0
			self.vx=0
			self.vy=0
			self.bounce_dir=nil
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
	ball_icon={
		update_priority=2,
		render_layer=12,
		width=5,
		height=5,
		color=7,
		frames_to_death=90,
		draw=function(self)
			pal(7,self.color)
			spr(3,self.x-0.5,self.y+0.5)
		end
	},
	ball_spawner={
		update_priority=4,
		render_layer=3,
		width=5,
		height=4,
		held_ball=nil,
		is_above_ground=false,
		on_scene_change=function(self)
			if scene=="game-end" then
				self:die()
			end
		end,
		update=function(self)
			if self.held_ball then
				self.y=max(ground_y-self.height,self.y-0.2)
				self.held_ball.y=self.y-4
			else
				self.y=min(ground_y+3,self.y+0.1)
			end
			self.is_above_ground=(self.y<=ground_y-1.5)
			if self.frames_alive%50==0 then
				self:spawn_ball()
			end
		end,
		draw=function(self)
			pal(7,0)
			draw_sprite(36,84,5,4,self.x,self.y)
		end,
		on_game_end=function(self)
			self.held_ball=nil
		end,
		spawn_ball=function(self)
			if scene=="game" and not self.held_ball then
				self.held_ball=spawn_entity("ball",self.x,self.y-4,{
					is_held_by_spawner=true,
					spawner=self,
					color=ball_colors[rnd_int(1,#ball_colors)]
				})
				return true
			else
				return false
			end
		end
	},
	score_track={
		update_priority=3,
		render_layer=10,
		y=ground_y+6,
		width=39,
		height=7,
		on_scene_change=function(self)
			if scene=="title" then
				self:die()
			end
		end,
		init=function(self)
			self.marks={}
		end,
		draw=function(self)
			local i
			for i=1,5 do
				local sprite=1
				if self.marks[i] then
					sprite=2
					pal(7,self.marks[i])
				end
				spr(sprite,self.x+8*i-7.5,self.y+0.5)
			end
		end,
		add_mark=function(self,color)
			add(self.marks,color)
		end
	},
	camera_operator={
		update_priority=10,
		render_layer=15,
		y=-127,
		vy=0,
		update=function(self)
			-- fall up/down during scene transitions
			if scene=="title->game" or scene=="game-start" then
				self.vy+=0.5
			elseif scene=="game->title" then
				self.vy-=0.5
			end
			self:apply_velocity()
			-- bounce off bottom of screen
			if (scene=="title->game" or scene=="game-start") and self.y>0 then
				self.y=0
				self.vy=-0.25*self.vy
				if self.vy>-0.5 then
					self.vy=0
					change_scene("game")
				elseif scene!="game-start" then
					change_scene("game-start")
				end
			end
			-- bounce off top of screen
			if scene=="game->title" and self.y<-127 then
				self.y=-127
				self.vy=-0.25*self.vy
				if self.vy<0.5 then
					self.vy=0
					change_scene("title")
				end
			end
		end
	},
	title_screen={
		update_priority=9,
		render_layer=14,
		x=64,
		y=-64,
		on_scene_change=function(self)
			self.is_paused=(scene=="game-start" or scene=="game" or scene=="game-end")
		end,
		init=function(self)
			self.mode_select=spawn_entity("mode_select")
		end,
		update=function(self)
			local any_button_press=false
			local p
			for p=1,2 do
				local b
				for b=4,5 do
					if button_presses[controllers[p]][b] then
						any_button_press=true
					end
				end
			end
			if scene=="title" and any_button_press then
				change_scene("title->game")
			end
		end,
		draw=function(self)
			-- draw title
			draw_sprite(32,0,96,76,self.x-48,self.y-50)
			-- draw start prompt
			if self.frames_alive%30<22 and scene=="title" then
				print("press any button to start",self.x-49.5,self.y+50.5,5)
			end
		end
	},
	mode_select={
		update_priority=8,
		render_layer=13,
		x=16,
		y=-30,
		width=95,
		height=8,
		mode_index=1,
		mode_x=16,
		last_mode_index=nil,
		last_mode_x=64,
		last_mode_dir=1,
		line_length=0,
		on_scene_change=function(self)
			self.is_paused=(scene=="game-start" or scene=="game" or scene=="game-end")
		end,
		update=function(self)
			if scene=="title" then
				-- change modes
				if btnp(0,controllers[1]) or btnp(0,controllers[2]) then
					self:prev_mode()
				end 
				if btnp(1,controllers[1]) or btnp(1,controllers[2]) then
					self:next_mode()
				end
			end
			-- move modes into and out of view
			self.mode_x+=0.3*(self.x-self.mode_x)
			self.last_mode_x+=0.3*(self.x+87*self.last_mode_dir-self.last_mode_x)
			-- give the player an indiciation of how far they've scrolled
			local ideal_line_length=ternary(self.mode_index==1,0,76*((self.mode_index-1)/(#modes-1)))
			self.line_length+=0.3*(ideal_line_length-self.line_length)
		end,
		draw=function(self)
			-- draw current mode
			self:draw_mode(self.mode_index,self.mode_x)
			-- draw last mode
			if self.last_mode_index then
				self:draw_mode(self.last_mode_index,self.last_mode_x)
			end
			-- draw blinders
			rectfill(self.x-45.5,self.y+0.5,self.x+4.5,self.y+7.5,0)
			rectfill(self.x+90.5,self.y+0.5,self.x+141.5,self.y+7.5,0)
			-- draw progress line
			if self.line_length>0.1 then
				line(self.x+9.5,self.y+8.5,self.x+9.5+self.line_length,self.y+8.5,1)
			end
			-- draw left/right arrows
			local left_arrow_sprite=19
			local right_arrow_sprite=19
			if scene=="title" then
				if btnp(0,controllers[1]) or btnp(0,controllers[2]) then
					left_arrow_sprite=35
				elseif btn(0,controllers[1]) or btn(0,controllers[2]) then
					left_arrow_sprite=51
				end
				if btnp(1,controllers[1]) or btnp(1,controllers[2]) then
					right_arrow_sprite=35
				elseif btn(1,controllers[1]) or btn(1,controllers[2]) then
					right_arrow_sprite=51
				end
			else
				colorwash(1)
				palt(5,true)
			end
			spr(left_arrow_sprite,self.x-2.5,self.y+0.5,1,1)
			spr(right_arrow_sprite,self.x+90.5,self.y+0.5,1,1,true)
		end,
		next_mode=function(self)
			self.last_mode_index=self.mode_index
			self.last_mode_x=self.x
			self.last_mode_dir=-1
			self.mode_index=1+self.mode_index%#modes
			self.mode_x=self.x+87
		end,
		prev_mode=function(self)
			self.last_mode_index=self.mode_index
			self.last_mode_x=self.x
			self.last_mode_dir=1
			self.mode_index-=1
			if self.mode_index<=0 then
				self.mode_index=#modes
			end
			self.mode_x=self.x-87
		end,
		draw_mode=function(self,mode_index,x)
			local mode=modes[mode_index]
			-- figure out the right color for the mode (white or rainbow)
			local light_color,dark_color
			if mode_index==1 then
				light_color,dark_color=7,5
			else
				local color_index=1+flr(game_frame/2)%#ball_colors
				light_color,dark_color=ball_colors[color_index],dark_ball_colors[color_index]
			end
			print(mode,x+48.5-2*#mode,self.y+2.5,dark_color)
			print(mode,x+48.5-2*#mode,self.y+1.5,light_color)
		end
	},
	game_over_text_geysers={
		update_priority=7,
		render_layer=1,
		on_scene_change=function(self)
			if scene=="title" then
				self:die()
			end
		end,
		init=function(self)
			self.messages={}
		end,
		update=function(self)
			foreach(self.messages,function(msg)
				msg.vy+=0.2
				msg.x+=msg.vx
				msg.y+=msg.vy
			end)
		end,
		post_update=function(self)
			local f=self.frames_alive
			if f<40 or f==mid(60,f,70) or f==mid(80,f,85) or f==95 then
				local p
				for p=1,2 do
					local juggler=jugglers[p]
					add(self.messages,{
						text=ternary(#juggler.score_track.marks>=5,"lose","win"),
						x=juggler.x+juggler.width/2,
						y=juggler.y+juggler.height/2,
						vx=rnd(0.9)-0.45,
						vy=-rnd(2.5)-4.5,
						color=ball_colors[rnd_int(1,#ball_colors)]
					})
				end
			end
			if f==140 then
				change_scene("game->title")
			end
		end,
		draw=function(self)
			foreach(self.messages,function(msg)
				print(msg.text,msg.x-2*#msg.text,msg.y,msg.color)
			end)
		end
	}
}

function _init()
	-- initialize input vars
	buttons={}
	button_presses={}
	button_releases={}
	buffered_button_presses={}
	-- start on the title screen
	change_scene("title")
	-- initialize game vars
	game_frame=0
	screen_shake_frames=0
	-- initialize entity vars
	entities={}
	new_entities={}
	jugglers={}
	balls={}
	-- create our starting entities
	camera_operator=spawn_entity("camera_operator")
	title_screen=spawn_entity("title_screen")
	-- add new entities to the game
	add_new_entities()
end

-- local skip_frames=0
function _update()
	-- keep track of inputs (because btnp repeats presses)
	local p
	for p=0,8 do
		if not buttons[p] then
			buttons[p]={}
			button_presses[p]={}
			button_releases[p]={}
			buffered_button_presses[p]={}
		end
		local b
		for b=0,5 do
			button_presses[p][b]=btn(b,p) and not buttons[p][b]
			button_releases[p][b]=not btn(b,p) and buttons[p][b]
			buttons[p][b]=btn(b,p)
			if button_presses[p][b] then
				buffered_button_presses[p][b]=4
			else
				buffered_button_presses[p][b]=decrement_counter(buffered_button_presses[p][b] or 0)
			end
		end
	end
	-- skip_frames+=1
	-- if skip_frames%15>0 then return end
	game_frame=increment_counter(game_frame)
	screen_shake_frames=decrement_counter(screen_shake_frames)
	-- sort entities for updating
	sort(entities,function(entity1,entity2)
		return entity1.update_priority>entity2.update_priority
	end)
	-- update each entity
	local entity
	for entity in all(entities) do
		if not entity.is_paused then
			increment_counter_prop(entity,"frames_alive")
			entity:update()
			if decrement_counter_prop(entity,"frames_to_death") then
				entity:die()
			end
		end
	end
	for entity in all(entities) do
		if not entity.is_paused then
			entity:post_update()
		end
	end
	-- add new entities to the game
	add_new_entities()
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
	-- shake the screen
	local screen_shake_y=-ceil(screen_shake_frames/2)*sin(screen_shake_frames/2.1)
	camera(0,screen_shake_y+camera_operator.y)
	-- clear the screen
	cls()
	-- draw the sky
	local l,r=left_wall_x+0.5,right_wall_x-0.5
	rectfill(l,sky_y+0.5,r,127.5,1)
	rectfill(l,32.5,r,127.5,13)
	rectfill(l,39.5,r,127.5,12)
	rectfill(l,65.5,r,127.5,11)
	rectfill(l,85.5,r,127.5,10)
	rectfill(l,96.5,r,127.5,9)
	rectfill(l,104.5,r,127.5,8)
	rectfill(l,109.5,r,127.5,2)
	pset(l,sky_y+0.5,0)
	pset(r,sky_y+0.5,0)
	-- draw each entity
	foreach(entities,function(entity)
		if entity.render_layer<10 then
			entity:draw()
			pal()
		end
	end)
	-- draw rects so that nothing is rendered off screen
	rectfill(-10.5,-137.5,137.5,0.5,0)
	rectfill(-10.5,0.5,0.5,137.5,0)
	rectfill(127.5,0.5,137.5,137.5,0)
	rectfill(-10.5,ground_y+0.5,137.5,137.5,0)
	-- draw the corners
	pset(l,ground_y-0.5,0)
	pset(r,ground_y-0.5,0)
	pset(midpoint_x-0.5,ground_y-0.5,0)
	pset(midpoint_x+0.5,ground_y-0.5,0)
	-- draw ui entities
	foreach(entities,function(entity)
		if entity.render_layer>=10 then
			entity:draw()
			pal()
		end
	end)
	-- draw debug info
	camera()
	rect(0,0,127,127,3)
	print("scene:    "..scene,3,3,3)
	print("entities: "..#entities,3,10,3)
end

function change_scene(s)
	-- inform all the entities
	if scene!=s then
		scene=s
		foreach(entities,function(entity)
			entity:on_scene_change()
		end)	
	end
	-- and then do stuff based on the scene
	if scene=="title->game" then
		spawn_entity("juggler",8,ground_y-entity_classes.juggler.height,{
			player_num=1,
			min_x=left_wall_x,
			max_x=midpoint_x,
			throw_dir=1,
			icon=spawn_entity("juggler_icon"),
			score_track=spawn_entity("score_track",13),
			spawner=spawn_entity("ball_spawner",36,ground_y+3)
		})
		spawn_entity("juggler",102,ground_y-entity_classes.juggler.height,{
			player_num=2,
			min_x=midpoint_x,
			max_x=right_wall_x,
			throw_dir=-1,
			icon=spawn_entity("juggler_icon"),
			score_track=spawn_entity("score_track",76),
			spawner=spawn_entity("ball_spawner",87,ground_y+3)
		})
	elseif scene=="game-end" then
		spawn_entity("game_over_text_geysers")
	end
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
			is_paused=false,
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
			on_scene_change=noop,
			init=noop,
			update=function(self)
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
	-- add the class name
	entity.class_name=class_name
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
		add(new_entities,entity)
	end
	-- return it
	return entity
end

function add_new_entities()
	local entity
	for entity in all(new_entities) do
		add(entities,entity)
		entity:add_to_game()
		entity:on_scene_change()
	end
	new_entities={}
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

function draw_sprite(sx,sy,sw,sh,x,y,...)
	sspr(sx,sy,sw,sh,x+0.5,y+0.5,sw,sh,...)
end

function shake_screen(frames)
	screen_shake_frames=min(screen_shake_frames+frames,17)
end

-- returns a random integer between min_val and max_val, inclusive
function rnd_int(min_val,max_val)
	return flr(min_val+rnd(1+max_val-min_val))
end

function colorwash(c)
	local i
	for i=1,15 do
		pal(i,c)
	end
end

__gfx__
00000000000000007700077000000000880000000000000888800000000000000000000000000000000000000000000000008000000000000000000000888888
00777000001110007770777000070000880000000008888880000000000000000000000000000000000000000000000000008000000000000000000000088888
07777700010001000777770000777000888888888888088000000000000000000000000000000000000000000000000000088000000000000000000000000008
07777700010001000077700007777700800000000000880000000000000000000000000000000000000000000000000000080800000000000000000000000008
07777700010001000777770000000000800000000088000000000000000000000000000000000000000000000000000000080800000000000000000000000008
00777000001110007770777000000000800000008800000000000000000000000000000000000000000000000000000000080800000000000000000000000008
00000000000000007700077000000000800000088000000000000000000000000000000000000000000000000000000000080800000000000000000000000000
00000000000000000000000000000000800000880008000000000000000000000000000000000000000000000000000000080800000000000000000000000000
00000000000000000022222200000070800008000000888000000000000000000000000000000000000000000000000000080800000000000000000000000000
00000000000000000022222200000770000080000000000888000000000000000000000008888800000000000000000000080800000000000000880088880000
00000000000000000022222200007770000800000000000000888000000000000000000080000888000000000000000000080800000000000008888808800000
00000007777000000022222200077770088000000000000000000888800000000000000800000000880000000000000000800800000000000088088880000000
00000007777000000022222200057770080000000000000000088800088000000000008800088888800000000000000000800800000000000088880888800000
70077707777000000022222200005770000000000000000000080888888888000000008008800000000000000888000000800800000000008888008000800000
77777777777000000022222200000570000000000000000000080000008888888000088080000000000000088000800000800800000000008880880008000000
07770777777000000022222200000050000000000000800000800000000008000000080800000000000000088888000000800800000008880088000088000000
00000007777770000022222200000000000000000000800000800000000008000000080800008800000000880000000000800800000880008880000080000000
000007777777777007222222000000e0000000000000800008800000000008000000088000888800000088800000000000800800008888880080088800000000
00000777777077777722222200000ee0000000000000080008000000000008000008088000888888880088000000000000800800000000000080800000000000
0000077007700077702222220000eee0000000000000080880000000000008000000888000008000000808000000000000800800000000000088000000000000
000777700770000000222222000eeee0000000000000088800000000000008000000808800008000008008000000000000800800000000000880000000000000
0000000007777000002222220000eee0000000000000000000000000000008000000808088008000008008000000000000800800000000888080000000000000
00007700000000000022222200000ee0000000000000000000000000000008000008008008888000008008000000000888800800000000800080000000000000
000770000000000000222222000000e0000000000000000000000000000008000008008000088000008008000008888080800800000008888888000000008888
00077000000000000022222200000000000000000000000000000000000008000080008000000000008008800008888880800800000888088808880000888000
00077707777000000022222200000060000000000000000000000000000008000800008800000000000800088000000800080800000888888888888888000000
00077707777000000022222200000660000000000000000000000000000008008000000088888800000888000880008880088800088800000000000000000000
00007777777000000022222200006660000000000000000000000000000008008000000000000000000000888888888800008808888000000000000000000000
00000777777000000022222200066660000000000000000000000000000008080000000000000000000000000000000000008888880000000000000000000000
00070077777000000022222200006660000000000000000000000000000008800000000000000000000000000000000000000000000000000000000000000000
00070007777770000022222200000660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077777777777700722222200000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077777777077777722222222222222000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000077000777022222222222222000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000077000000022222222222222000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000077770000022222222222222000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000022222222222222000000008800000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000022222222222222000000008800000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000022222222222222000000088000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000777700000022222222222222000000088888888800000000000000000000000000000000000000000000000000000000000000000000000000000000
70077700777700000022222222222222000000088800000888000000000000000000000000000000000000000000000000000000000000000000000000000000
77777770777700000022222222222222000000888000000008800000000000000080000000000000000000000000000000000000000000000000000000000000
07770777777700000022222222222222000000880000000008800000000000000080000000000000000000000000000000000000000000000000000000000000
00000077777000000022222222222222000008880000000080000000000000000080000000000000000000000000000000000000000000000000000000000000
00070007777700000022222222222222000008800000000800000000000000000088000000000000000000000000000000000000000000000000000000000000
00077777777770000022222222222222000008800000088000000000000000000088000000000000000000000000000000000000000000000000000000000000
00077777777777700722222222222222000008800008800000000000000000000088000000000000000000000000000000000000000000000000000000000000
00000000077077777722222222222222000008888880000000000000880000000080800000000000000000000000000000000000000000000000000000000000
00000000077000777022222222222222000088800000000000000008808000000080080000000000000000000000000000000088888888888800000000000000
00000000077770000022222222222222000088800000000000000080008000000080080000000000000000008000000000008800000888888888000000000000
22222222222222222222222222222222000088088800000000000800008000000080080000000800000000008000000000880000888000000008000000000000
22222222222222222222222222222222000088000088800000000800008000000080008000000800000000008000000000800088000000000000000000000000
22222222222222222222222222222222000088000000088880000800008000000080000800000800000000008000000000808800000000000000000000000000
0bbb00aaa00099000880222222222222000080000000000000000800008000000080000800000800000000008800000000880000000000000000000000000000
0bbbb0aaa00999008880222222222222000880000000000000008000008000000080000080000800000000008800000000880000000000000000000000000000
bbbbbaaaaa0999008880222222222222000880000000000000008000008000000080000080000800000000008800000000800000000000000000000000000000
bbbbbaaaaa0999008880222222222222000880000000000000008000008000000080000008000800000000008800000008800000000000000000000000000000
bbbbbaaaa00999008880222222222222000800000000000000008880888800000080000000800800000000008800000008800000000000000000000000000000
0bbb0aaaa00999008880222222222222000800000000000000008888888888800080000000800080000000008800000080800000000000000000000000000000
0bb000aaa00999008880222222222222000800000000000000008000800800000080000000800080000000008800000080800000000000000000000000000000
000000aaa00999008880222222222222000800000000000000008000880800000080000000080080000000000880000080800000000000000000000000000000
000000aaa00999008880222222222222000800000000000000008000080800000080000000080080000000000880000080800000000000000000000000000000
000000aa000999008880222222222222000800000000000000000000080800000080000000008080000000000880000008800000000000000000000000000000
00000000000990008880222222222222000880000000000000000000080800000080000000000880000000000808000008800000000000000000000000000000
00000000000990008880222222222222000000000000000000000000080800000080000000000088000000000808000000800000000000000000000000000000
00000000000000008880222222222222000000000000000000000000008800000080000000000008000000008808000000800000000000000000000000000000
00000000000000008880222222222222000000000000000000000000008800000080000000000008800000000008000000080000000000000000000000000000
00000000000000008800222222222222000000000000000000000000008800000080000000000000000000000008800000088800000000000000000000000000
00000000000000000800222222222222000000000000000000000000008800000000000000000000000000000008800000008088880000008800000000000000
000bb0000aa000099000008022222222000000000000000000000000008800000000000000000000000000000008800000008000008888888000000000000000
00bbbb00aaaa00999900088822222222000000000000000000000000008800000000000000000000000000000000800000008000000000000000000000000000
00bbbb00aaaa00999900088822222222000000000000000000000000008800000000000000000000000000000000800000008000000000000000000000000080
0bbbbb0aaaaa00999000888822222222800000000000000000000000008800000000000000000000000000000000800000000800000000000000000000000088
0bbbb00aaaa009999000888022222222800000000000000000000000008800000000000000000000000000000000800000000080000000000000000000000088
0bbbb00aaaa009999000888022222222800000000000000000000000000000000000000000000000000000000000800000000008000000008800000000000088
00bb00aaaa0009990008880022222222888888880000000000000000000000000000000000000000000000000000800000000000880000880000000000888888
000000aaaa0099990008880000ccccc0022222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
000000aaa0009990000888000ccccccc022222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
0000000000009990008880000ccccccc022222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
00000000000099000088800000ccccc0022222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
00000000000000000088800000000000022222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
0000000000000000008800000cc000cc022222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
000000000000000000880000ccccccccc22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
0000000000000000000000000ccccccc022222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
000000bbb000000aaa00000009900000008870007222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
00000bbbb00000aaaa00000099900000088877777222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
0000bbbbb00000aaaa00000999900000888807770222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
0000bbbb00000aaaa000000999000000888007770222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
0000bbbb00000aaaa0000099990000088880000000c0222222222222222222222222222222222222222222222222222222222222222222222222222222222222
0000bbb00000aaaa000009999000008888000cc00ccc222222222222222222222222222222222222222222222222222222222222222222222222222222222222
000000000000aaa000000999000000888000cccc0ccc222222222222222222222222222222222222222222222222222222222222222222222222222222222222
000000000000aa0000009999000008888000cccc00cc222222222222222222222222222222222222222222222222222222222222222222222222222222222222
000000000000000000009990000008880000cccc00cc222222222222222222222222222222222222222222222222222222222222222222222222222222222222
000000000000000000009900000088880000cccc00cc222222222222222222222222222222222222222222222222222222222222222222222222222222222222
000000000000000000000000000088800000cccc0ccc222222222222222222222222222222222222222222222222222222222222222222222222222222222222
0000000000000000000000000008880000000cc00ccc222222222222222222222222222222222222222222222222222222222222222222222222222222222222
000000000000000000000000000880000000000000c0222222222222222222222222222222222222222222222222222222222222222222222222222222222222
0000000bbbb00000000aaa0000000099900000000088222222222222222222222222222222222222222222222222222222222222222222222222222222222222
0000000bbbb0000000aaaa0000000999900000008888222222222222222222222222222222222222222222222222222222222222222222222222222222222222
000000bbbbb000000aaaaa0000009999900000088888222222222222222222222222222222222222222222222222222222222222222222222222222222222222
000000bbbb000000aaaaa00000099999000000888880222222222222222222222222222222222222222222222222222222222222222222222222222222222222
000000bbbb00000aaaaa000000999990000008888800222222222222222222222222222222222222222222222222222222222222222222222222222222222222
000000000000000aaaa0000000999900000008880000222222222222222222222222222222222222222222222222222222222222222222222222222222222222
000000000000000aa000000009999000000088800000222222222222222222222222222222222222222222222222222222222222222222222222222222222222
00000000000000000000000009900000000888000000222222222222222222222222222222222222222222222222222222222222222222222222222222222222
00000000000000000000000000000000008880000000222222222222222222222222222222222222222222222222222222222222222222222222222222222222
00000000000000000000000000000000088800000000222222222222222222222222222222222222222222222222222222222222222222222222222222222222
00000000000000000000000000000000088000000000222222222222222222222222222222222222222222222222222222222222222222222222222222222222
0000000000bbb0000000000aaa000000000099900000000008882222222222222222222222222222222222222222222222222222222222222222222222222222
00000000bbbbb00000000aaaaa000000009999900000000888882222222222222222222222222222222222222222222222222222222222222222222222222222
0000000bbbbbb0000000aaaaaa000000099999000000008888802222222222222222222222222222222222222222222222222222222222222222222222222222
0000000bbbbb0000000aaaaaa0000009999990000000888888002222222222222222222222222222222222222222222222222222222222222222222222222222
0000000bbbb0000000aaaaa000000099999000000088888800002222222222222222222222222222222222222222222222222222222222222222222222222222
000000000000000000aaa00000000999990000000888888000002222222222222222222222222222222222222222222222222222222222222222222222222222
00000000000000000000000000000999000000008888800000002222222222222222222222222222222222222222222222222222222222222222222222222222
00000000000000000000000000000000000000088880000000002222222222222222222222222222222222222222222222222222222222222222222222222222
00000000000000000000000000000000000000088000000000002222222222222222222222222222222222222222222222222222222222222222222222222222
00000000000bbb000000000000aaa000000000000099000000000000888022222222222222222222222222222222222222222222222222222222222222222222
000000000bbbbbb000000000aaaaaa00000000099999900000000088888822222222222222222222222222222222222222222222222222222222222222222222
00000000bbbbbbb0000000aaaaaaaa00000009999999900000088888888022222222222222222222222222222222222222222222222222222222222222222222
00000000bbbbbb0000000aaaaaaaa000000999999999000088888888800022222222222222222222222222222222222222222222222222222222222222222222
000000000bbb000000000aaaaaa00000009999999000008888888800000022222222222222222222222222222222222222222222222222222222222222222222
000000000000000000000aaa00000000009999000000008888800000000022222222222222222222222222222222222222222222222222222222222222222222
00000000000bbb00000000000000aa00000000000000000000000000000000002222222222222222222222222222222222222222222222222222222222222222
0000000000bbbbbb0000000aaaaaaaaa000000999999999900888888888888882222222222222222222222222222222222222222222222222222222222222023
000000000bbbbbbb000000aaaaaaaaaa000099999999999988888888888888882222222222222222222222222222222222222222222222222222222222224567
000000000bbbbbbb000000aaaaaaaaaa0000999999999990088888888888888022222222222222222222222222222222222222222222222222222222222289ab
00000000000bbbb00000000000aaaa0000000000000000000000000000000000222222222222222222222222222222222222222222222222222222222222cdef
