pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
--juggle panic
--by bridgs

cartdata("bridgs_jugglepanic_1")

--[[
todo
	title screen music
	stuff that floats past
	effect when player catches a ball
	effect when ball hits the ground
]]

local scene_frame
local is_playing_game
local camera_y
local camera_vy
local ball_speed_level
local end_transition_frames
local screen_shake_frames
local freeze_frames
local frames_since_activity
local frames_since_auto_spawn
local next_player_spawn
local game_mode
local num_resets

local buttons
local button_presses
local button_releases

local players
local balls
local title_balls
local dropped_balls
local ball_spawners
local floating_words
local effects

local debug_mode=false
local ball_colors={9,11,8,10,12}
local game_modes={
	"long arms","strong arm","cooperative",
	"bomb","infiniball","bouncy ball",
	"blackout","speedball","hot potato",
	"floaty","step-by-step"
}

function _init()
	scene_frame=0
	is_playing_game=false
	camera_y=-128
	camera_vy=0
	end_transition_frames=0
	screen_shake_frames=0
	freeze_frames=0
	title_balls={}
	num_resets=0

	-- initialize inputs
	buttons={{},{}}
	button_presses={{},{}}
	button_releases={{},{}}

	-- skip to the game in debug mode
	if debug_mode then
		reset_game()
		camera_y=0
		ball_speed_level=20
		dropped_balls={
			{
				{color_index=1},
				{color_index=2},
				{color_index=3},
				{color_index=4}
			},
			{
				{color_index=5},
				{color_index=1},
				{color_index=2},
				{color_index=3}
			}
		}
	end
end

-- local skip_frame=0
function _update()
	-- skip_frame=(skip_frame+1)%10
	-- if skip_frame>0 then return end
	if freeze_frames>0 then
		freeze_frames=max(0,freeze_frames-1)
		return
	end
	-- increment counters
	scene_frame=increment_counter(scene_frame)
	-- keep track of inputs (because btnp repeats presses)
	local any_button_press=false
	local p
	for p=1,2 do
		local b
		for b=0,4 do
			button_presses[p][b]=btn(b,p-1) and not buttons[p][b]
			button_releases[p][b]=not btn(b,p-1) and buttons[p][b]
			buttons[p][b]=btn(b,p-1)
			any_button_press=any_button_press or button_presses[p][b]
		end
	end
	-- update all the title-screen balls
	if scene_frame%10==0 then
		create_title_ball()
	end
	local title_ball
	for title_ball in all(title_balls) do
		update_title_ball(title_ball)
	end
	-- title screen code
	if not is_playing_game and any_button_press then
		reset_game()
		music(0)
	end
	-- gameplay code
	if is_playing_game then
		frames_since_activity=increment_counter(frames_since_activity)
		frames_since_auto_spawn=increment_counter(frames_since_auto_spawn)
		if scene_frame>150 and end_transition_frames<=0 and game_mode!="cooperative" then
			-- spawn balls if there are none
			if #balls<=0 then
				local something_done=false
				if ball_spawners[1].anim=="fall" then
					ball_spawners[1].frames_to_spawn=1
					frames_since_auto_spawn=0
					something_done=true
				end
				if ball_spawners[2].anim=="fall" then
					ball_spawners[2].frames_to_spawn=1
					frames_since_auto_spawn=0
					something_done=true
				end
				if something_done and game_mode!="bomb" and game_mode!="speedball" then
					ball_speed_level=max(1,flr(ball_speed_level/3))
				end
				frames_since_activity=0
			-- spawn balls if no plays are happening
			elseif frames_since_activity>160 then
				local num_left_balls=0
				local num_right_balls=0
				local ball
				for ball in all(balls) do
					if ball.x<64 then
						num_left_balls+=1
					else
						num_right_balls+=1
					end
				end
				if num_left_balls==num_right_balls then
					if ball_spawners[next_player_spawn].anim=="fall" then
						ball_spawners[next_player_spawn].frames_to_spawn=1
						frames_since_activity=0
						frames_since_auto_spawn=0
					end
					next_player_spawn=3-next_player_spawn
				elseif num_left_balls<num_right_balls then
					if ball_spawners[1].anim=="fall" then
						ball_spawners[1].frames_to_spawn=1
						frames_since_activity=0
						frames_since_auto_spawn=0
					end
				else
					if ball_spawners[2].anim=="fall" then
						ball_spawners[2].frames_to_spawn=1
						frames_since_activity=0
						frames_since_auto_spawn=0
					end
				end
			end
			-- just spawn a ball automatically every so often, for funsies
			if frames_since_auto_spawn>=300 then
				if ball_spawners[next_player_spawn].anim=="fall" then
					ball_spawners[next_player_spawn].frames_to_spawn=1
					frames_since_activity=0
				end
				next_player_spawn=3-next_player_spawn
				frames_since_auto_spawn=0
			end
		end
		-- ending code
		if end_transition_frames>0 then
			end_transition_frames-=1
			if end_transition_frames>150 or end_transition_frames==mid(120,end_transition_frames,130) or end_transition_frames==mid(105,end_transition_frames,110) or end_transition_frames==95 then
				for p=1,2 do
					local options
					local text
					if #dropped_balls[ternary(game_mode=="cooperative",1,p)]<5 then
						text="win"
					else
						text="lose"
					end
					create_floating_word(players[p].x,players[p].y+12,text,rnd_int(1,#ball_colors))
				end
			end
			if end_transition_frames==1 then
				is_playing_game=false
				scene_frame=0
			end
		end
		if (end_transition_frames>0 and end_transition_frames<50) or not is_playing_game then
			camera_vy-=0.4
			camera_y+=camera_vy
			if camera_y<-128 then
				camera_y=-128
				camera_vy=-0.25*camera_vy
			end
		else
			camera_vy+=0.4
			camera_y+=camera_vy
			if camera_y>0 then
				camera_y=0
				camera_vy=-0.25*camera_vy
			end
		end
		-- spawn a ball every so often
		-- 	next_player_num_ball_spawn=3-next_player_num_ball_spawn
		-- end
		-- update all the ball spawners
		local ball_spawner
		for ball_spawner in all(ball_spawners) do
			update_ball_spawner(ball_spawner)
		end
		-- update all the balls
		local ball
		for ball in all(balls) do
			update_ball(ball)
		end
		-- check for balls knocking into each other
		local i
		for i=1,#balls do
			local ball1=balls[i]
			local j
			for j=1,#balls do
				local ball2=balls[j]
				if i!=j and not ball1.held_by and not ball2.held_by then
					local dx=ball1.x-ball2.x
					local dy=ball1.drawn_y-ball2.drawn_y
					if dx==mid(-30,dx,30) and dy==mid(-30,dy,30) and dx*dx+dy*dy<10 then
						if ball1.x<=ball2.x and ball1.vx>=0 and ball2.vx<=0 then
							ball1.vx*=-1.7
							ball2.vx*=-1.7
							freeze_frames+=5
							create_effect(9,92,17,17,ball2.x+dx/2-8,ball2.drawn_y+dy/2-8,3)
							sfx(12,2)
						end
					end
				end
			end
		end
		-- update all the players
		local player
		for player in all(players) do
			update_player(player)
		end
		-- update all the balls
		for ball in all(balls) do
			post_update_ball(ball)
		end
		-- update all the floating words
		local floating_word
		for floating_word in all(floating_words) do
			update_floating_word(floating_word)
		end
		-- update all the effects
		local effect
		for effect in all(effects) do
			update_effect(effect)
		end
		if game_mode=="cooperative" and scene_frame==1050 then
			end_game()
		end
	end
	-- shake the screen
	screen_shake_frames=mid(0,screen_shake_frames-1,17)
end

function _draw()
	local screen_shake_y=-ceil(screen_shake_frames/2)*sin(screen_shake_frames/2.1)--ternary(screen_shake_frames%2==0,1,-1)*min(3,flr(screen_shake_frames/3))
	cls()
	camera(0,camera_y+screen_shake_y)
	-- draw the title
	sspr(18,8,108,71,10,-107)
	if scene_frame%30<22 and not is_playing_game then
		if scene_frame<120 then
			print("(music still being composed)",8,-120,1)
			print("created (with   ) by bridgs",9,-32,5)
			spr(6,65,-34)
			print("https://brid.gs",33,-24,1)
			print("bridgs_dev",43,-16,1)
			spr(7,33,-18)
		else
			print("press any button to start",13,-23,5)
		end
	end
	-- update all the title-screen balls
	local title_ball
	for title_ball in all(title_balls) do
		draw_title_ball(title_ball)
		pal()
	end
	if is_playing_game then
		-- draw a beautiful rainbow sky
		rectfill(0,0,128,127,1)
		rectfill(0,31,128,127,13)
		rectfill(0,39,128,127,12)
		rectfill(0,66,128,127,11)
		rectfill(0,85,128,127,10)
		rectfill(0,96,128,127,9)
		rectfill(0,104,128,127,8)
		rectfill(0,109,128,127,2)
		rectfill(0,114,128,127,0)
		if game_mode=="blackout" and scene_frame>120 then
			rectfill(0,0,127,127,0)
		end
		-- draw controls
		local n=mid(6,flr(scene_frame/2)-80,100)
		pal(13,0)
		sspr(0,62,9,10,20-n,47) -- s key
		sspr(9,62,9,10,31-n,47) -- f key
		sspr(0,82,27,10,17-n,67) -- l-shift key
		sspr(0,72,9,10,87+n,47) -- left arrow key
		sspr(9,72,9,10,98+n,47) -- right arrow key
		sspr(0,92,9,10,93+n,67) -- n key
		pal()
		print("move",23-n,58,0)
		print("move",90+n,58,0)
		print("toss",23-n,78,0)
		print("toss",90+n,78,0)
		if game_mode and is_playing_game and scene_frame<300 then
			print("activated:",46,49-n,0)
			print(game_mode,64-2*#game_mode,56-n,8)
			print("mode",56,63-n,8)
		end
		-- draw the bounds of each player's side
		pset(0,113,0)
		pset(63,113,0)
		pset(64,113,0)
		pset(127,113,0)
		pset(0,0,0)
		-- pset(63,0,0)
		-- pset(64,0,0)
		pset(127,0,0)
		-- draw all the effects
		local effect
		for effect in all(effects) do
			draw_effect(effect)
			pal()
		end
		-- draw all the floating_words
		local floating_word
		for floating_word in all(floating_words) do
			draw_floating_word(floating_word)
			pal()
		end
		-- draw all the ball spawners
		local ball_spawner
		for ball_spawner in all(ball_spawners) do
			draw_ball_spawner(ball_spawner)
			pal()
		end
		-- draw all the balls
		local ball
		for ball in all(balls) do
			draw_ball(ball)
			pal()
		end
		-- draw all the players
		local player
		for player in all(players) do
			draw_player(player)
			pal()
		end
		rectfill(0,114,127,127,0)
		-- draw score
		if game_mode=="cooperative" then
			local i
			for i=1,5 do
				if dropped_balls[1][i] then
					pal(8,ball_colors[dropped_balls[1][i].color_index])
					spr(3,36+8*i,118)
					pal()
				else
					spr(1,36+8*i,118)
				end
			end
			local timer=mid(0,(35-flr(scene_frame/30)),35).." seconds left"
			print(timer,64-2*#timer,13,12)
		else
			if ball_speed_level<5 then
				print("slow",56,119,1)
			elseif ball_speed_level<10 then
				print("fast",56,119,13)
			elseif ball_speed_level<15 then
				print("v.fast",52,119,12)
			elseif ball_speed_level<20 then
				print("2fast!",52,119,11)
			elseif ball_speed_level<25 then
				print("aahh!!",52,119,10)
			elseif ball_speed_level<25 then
				print("!!!!!!",52,119,9)
			elseif ball_speed_level<30 then
				print("nonono",52,119,8)
			elseif ball_speed_level<35 then
				print("max!",56,119,2)
			elseif ball_speed_level<40 then
				print("v.max!",52,119,14)
			elseif ball_speed_level<45 then
				print("2max!!",52,119,15)
			else
				print("allmax",52,119,7)
			end
			local i
			for i=1,5 do
				if dropped_balls[1][i] then
					pal(8,ball_colors[dropped_balls[1][i].color_index])
					spr(3,8*i,118)
					pal()
				else
					spr(1,8*i,118)
				end
			end
			for i=1,5 do
				if dropped_balls[2][i] then
					pal(8,ball_colors[dropped_balls[2][i].color_index])
					spr(3,73+8*i,118)
					pal()
				else
					spr(1,73+8*i,118)
				end
			end
		end
	end
end


-- player methods
function create_player(player_num)
	local player={
		player_num=player_num,
		button_index=3-player_num,
		x=ternary(player_num==1,20,108),
		y=101,
		vx=0,
		pose="wiggle",
		pose_flipped=false,
		anim_frames=0,
		wiggle_frames=0,
		min_bound=ternary(player_num==1,9,73),
		max_bound=ternary(player_num==1,55,119),
		left_hand=nil,
		right_hand=nil,
		most_recent_catch_hand=ternary(player_num==1,"right_hand","left_hand")
	}
	-- add the player to the list of players
	add(players,player)
	return player
end

function update_player(self)
	local extra_x=ternary(game_mode=="long arms",6,0)
	if game_mode=="floaty" then
		self.y=81+20*sin((scene_frame+ternary(self.player_num==1,0,50))/100)
	end
	local vx
	if self.left_hand and self.right_hand then
		vx=1
	elseif self.left_hand or self.right_hand then
		vx=2
	else
		vx=3
	end
	self.vx=vx*(ternary(buttons[self.button_index][1],1,0)-ternary(buttons[self.button_index][0],1,0))
	self.x=mid(self.min_bound,self.x+self.vx,self.max_bound)
	self.anim_frames=max(0,self.anim_frames-1)
	if self.anim_frames<=0 then
		self.pose="wiggle"
	end
	self.wiggle_frames+=1
	if self.wiggle_frames>ternary(self.vx==0,20,5) then
		self.wiggle_frames=0
		if self.pose=="wiggle" then
			self.pose_flipped=not self.pose_flipped
		end
	end
	-- catch balls
	local ball
	for ball in all(balls) do
		if not ball.held_by and (game_mode!="floaty" and ball.y>100) or (game_mode=="floaty" and ball.y==mid(self.y-3,ball.y,self.y+10)) and ball.vy>0 then
			if not self.left_hand and ball.x==mid(self.x-10-extra_x,ball.x,self.x-extra_x) then
				if game_mode=="bomb" then
					create_effect(9,92,17,17,ball.x-8,ball.y-8,3)
					freeze_frames+=7
					screen_shake_frames+=10
					del(balls,ball)
					add(dropped_balls[self.player_num],ball)
					if #dropped_balls[self.player_num]>=5 then
						end_game()
					end
					sfx(11,1)
				else
					sfx(10,1)
					self.left_hand=ball
					ball.held_by=self
					self.most_recent_catch_hand="left_hand"
					self.pose="catch"
					self.pose_flipped=true
					self.anim_frames=15
					freeze_frames+=1
				end
			elseif not self.right_hand and ball.x==mid(self.x+extra_x,ball.x,self.x+10+extra_x) then
				if game_mode=="bomb" then
					create_effect(9,92,17,17,ball.x-8,ball.y-8,3)
					freeze_frames+=7
					screen_shake_frames+=10
					del(balls,ball)
					add(dropped_balls[self.player_num],ball)
					if #dropped_balls[self.player_num]>=5 then
						end_game()
					end
					sfx(11,1)
				else
					sfx(10,1)
					self.right_hand=ball
					ball.held_by=self
					self.most_recent_catch_hand="right_hand"
					self.pose="catch"
					self.pose_flipped=false
					self.anim_frames=15
					freeze_frames+=1
				end
			end
		end
	end
	-- update held balls x-positions
	if self.left_hand then
		self.left_hand.x=self.x-7-extra_x
	end
	if self.right_hand then
		self.right_hand.x=self.x+6+extra_x
	end
	-- throw balls
	if button_presses[self.button_index][4] or game_mode=="hot potato" then
		-- figure out which hand to throw with
		local throwing_hand
		if self.vx>0 and self.left_hand then
			throwing_hand="left_hand"
		elseif self.vx<0 and self.right_hand then
			throwing_hand="right_hand"
		elseif self.right_hand and self.most_recent_catch_hand!="right_hand" then
			throwing_hand="right_hand"
		elseif self.left_hand and self.most_recent_catch_hand!="left_hand" then
			throwing_hand="left_hand"
		elseif self.right_hand then
			throwing_hand="right_hand"
		elseif self.left_hand then
			throwing_hand="left_hand"
		else
			throwing_hand=nil
		end
		-- throw the ball
		if throwing_hand then
			local thrown_ball=self[throwing_hand]
			thrown_ball.y=self.y+4
			thrown_ball.num_steps=3+ball_speed_level
			thrown_ball.height_mult=mid(0.82,0.82+ball_speed_level/40,1.3)
			-- move that ball
			thrown_ball.vy=-0.92
			local vx=0.17
			if self.player_num==1 then
				if self.vx<0 then
					vx=0.15
				elseif self.vx>0 then
					vx=0.19
				end
			else
				if self.vx<0 then
					vx=0.19
				elseif self.vx>0 then
					vx=0.15
				end
			end
			if game_mode=="strong arm" then
				vx*=5
			end
			thrown_ball.vx=vx*ternary(self.player_num==1,1,-1)
			self[throwing_hand]=nil
			thrown_ball.held_by=nil
			self.pose="throw"
			self.pose_flipped=(throwing_hand=="right_hand")
			self.anim_frames=15
			update_ball(thrown_ball,true)
			-- increase ball speed globally
			if game_mode!="cooperative" then
				ball_speed_level=min(ball_speed_level+1,100)
			end
			sfx(2+mid(0,flr(ball_speed_level/5),3),1)
		end
	end
	-- update held balls y-positions
	if self.left_hand then
		if self.pose=="catch" then
			self.left_hand.y=ternary(self.pose_flipped,self.y+7,self.y+1)
		else
			self.left_hand.y=ternary(self.pose_flipped,self.y+6,self.y+2)
		end
	end
	if self.right_hand then
		if self.pose=="catch" then
			self.right_hand.y=ternary(self.pose_flipped,self.y+1,self.y+7)
		else
			self.right_hand.y=ternary(self.pose_flipped,self.y+2,self.y+6)
		end
	end
end

function draw_player(self)
	-- rect(self.x-8.5,self.y+0.5,self.x+8.5,self.y+12.5,0)
	-- pset(self.x+0.5,self.y+0.5,1)
	pal(1,0)
	local sy
	if self.pose=="wiggle" then
		sy=6
	elseif self.pose=="throw" then
		sy=20
	elseif self.pose=="catch" then
		sy=34
	end
	if game_mode=="long arms" then
		sspr(98,sy+73,30,14,self.x-14.5,self.y-0.5,30,14,self.pose_flipped)
	else
		sspr(0,sy,18,14,self.x-8.5,self.y-0.5,18,14,self.pose_flipped)
	end
end


-- ball methods
function create_ball(x,y,color_index)
	local ball={
		x=x,
		y=y,
		drawn_y=y,
		vx=0,
		vy=0,
		num_steps=5,
		color_index=color_index,
		height_mult=1,
		held_by=nil
	}
	-- add the ball to the list of balls
	add(balls,ball)
	return ball
end

function update_ball(self,force)
	local vy=self.vy
	if not self.held_by and (game_mode!="step-by-step" or scene_frame%20==0 or force)  then
		local i
		for i=1,ternary(game_mode=="step-by-step",8,1)*self.num_steps do
			step_ball(self)
		end
	end
	if vy<=0.2 and self.vy>0.2 then
		sfx(6+mid(0,flr(ball_speed_level/5),3),1)
	end
	self.drawn_y=self.y
	if self.drawn_y<100 and game_mode!="floaty" then
		self.drawn_y=self.height_mult*(self.drawn_y-100)+100
	end
end

function step_ball(self)
	local x=self.x
	self.vy+=0.005
	if self.y<116 then
		self.x+=self.vx
	end
	self.y+=self.vy
	if (self.x<64)!=(x<64) then
		frames_since_activity=0
	end
	if self.x<3 then
		self.x=3
		self.vx*=-1
	end
	if self.x>124 then
		self.x=124
		self.vx*=-1
	end
end

function post_update_ball(self)
	if self.y>115 then
		if game_mode=="bouncy ball" then
			self.vy=-self.vy
			self.y=115
		else
			del(balls,self)
		end
		if game_mode=="bomb" then
			create_effect(9,92,17,17,self.x-8,115-8,3)
			local player_num=ternary(self.x<64,1,2)
			if #players>=2 and players[player_num].x==mid(self.x-7,players[player_num].x,self.x+7) then
				freeze_frames+=7
				screen_shake_frames+=10
				add(dropped_balls[player_num],self)
				sfx(11,1)
			else
				freeze_frames+=2
				sfx(17,1)
			end
		else
			add(dropped_balls[ternary(self.x<64 or game_mode=="cooperative",1,2)],self)
			screen_shake_frames+=10
			freeze_frames+=2
			sfx(11,1)
		end
		if #dropped_balls[1]>=5 or #dropped_balls[2]>=5 then
			end_game()
		end
	end
end

function draw_ball(self)
	pal(8,ternary(game_mode=="bomb",0,ball_colors[self.color_index]))
	spr(0,self.x-2.5,self.drawn_y-2.5)
end


-- faux ball
function create_title_ball()
	local side=ternary(rnd()<0.5,-1,1)
	local title_ball={
		x=63+70*side,
		y=-rnd_int(10,90),
		vx=-2.5*side,
		vy=-2.8-0.4*rnd(),
		frames_to_death=300,
		color_index=rnd_int(1,#ball_colors)
	}
	add(title_balls,title_ball)
	return title_ball
end

function update_title_ball(self)
	self.vy+=0.1
	self.x+=self.vx
	self.y+=self.vy
	self.frames_to_death-=1
	if self.frames_to_death<=0 then
		del(title_balls,self)
	end
end

function draw_title_ball(self)
	pal(8,ball_colors[self.color_index])
	spr(0,self.x-2.5,self.y-2.5)
end


-- ball spawner methods
function create_ball_spawner(x,player_num,frames_to_spawn)
	local ball_spawner={
		x=x,
		y=120,
		player_num=player_num,
		color_index=rnd_int(1,#ball_colors),
		color_change_frames=0,
		frames_to_spawn=frames_to_spawn,
		anim="fall"
	}
	add(ball_spawners,ball_spawner)
	return ball_spawner
end

function update_ball_spawner(self)
	if self.anim=="fall" then
		if self.frames_to_spawn>0 then
			self.frames_to_spawn-=1
			if self.frames_to_spawn<=0 then
				self.anim="rise"
			end
		end
	end
	self.color_change_frames+=1
	if self.color_change_frames>2 then
		self.color_change_frames=0
		self.color_index=1+self.color_index%#ball_colors
	end
	-- see if the player grabs the ball
	local player=players[self.player_num]
	if self.anim!="fall" and self.y<=113 and player.y>99 then
		local extra_x=ternary(game_mode=="long arms",6,0)
		local hand
		if player.x-self.x==mid(0+extra_x,player.x-self.x,8+extra_x) and not player.left_hand then
			hand="left_hand"
		elseif self.x-player.x==mid(0+extra_x,self.x-player.x,8+extra_x) and not player.right_hand then
			hand="right_hand"
		end
		if hand then
			local ball=create_ball(self.x,self.y,self.color_index)
			ball.held_by=player
			player[hand]=ball
			player.most_recent_catch_hand=hand
			self.anim="fall"
			player.pose="wiggle"
			sfx(1,0)
			if game_mode=="bomb" then
				self.frames_to_spawn=60
			elseif game_mode=="cooperative" then
				self.frames_to_spawn=135
			elseif game_mode=="infiniball" then
				self.frames_to_spawn=20
			end
		elseif game_mode=="cooperative" then
			local ball=create_ball(self.x,self.y,rnd_int(1,#ball_colors))
			ball.vy=-0.92
			self.anim="fall"
			self.frames_to_spawn=135
		end
	end
	-- animate in an out of the ground
	if self.anim=="fall" then
		self.y=mid(113,self.y+0.15,120)
	end
	if self.anim=="rise" then
		self.y=mid(113,self.y-0.15,120)
	end
end

function draw_ball_spawner(self)
	pal(1,0)
	pal(8,ternary(game_mode=="bomb",0,ball_colors[self.color_index]))
	palt(8,self.anim=="fall")
	spr(2,self.x-3.5,self.y-6.5)
	rectfill(self.x-1.5,114.5,self.x+2.5,117.5,0)
	-- print(self.frames_to_spawn,self.x,self.y-20,7)
end


-- floating text methods
function create_floating_word(x,y,text,color_index)
	local floating_word={
		x=x,
		y=y,
		text=text,
		vx=rnd(0.9)-0.45,
		vy=-4.5-rnd(2.5),--1.5-rnd(0.5),
		color_index=color_index
	}
	add(floating_words,floating_word)
	return floating_word
end

function update_floating_word(self)
	self.vy+=0.2
	self.x+=self.vx
	self.y+=self.vy
end

function draw_floating_word(self)
	print(self.text,self.x-2*#self.text,self.y,ball_colors[self.color_index])
end


-- floating text methods
function create_effect(sx,sy,sw,sh,x,y,frames_to_death)
	local effect={
		sx=sx,
		sy=sy,
		sw=sw,
		sh=sh,
		x=x,
		y=y,
		frames_to_death=frames_to_death
	}
	add(effects,effect)
	return effect
end

function update_effect(self)
	self.frames_to_death-=1
	if self.frames_to_death<=0 then
		del(effects,self)
	end
end

function draw_effect(self)
	sspr(self.sx,self.sy,self.sw,self.sh,self.x,self.y)
end


-- helper methods
function reset_game()
	num_resets+=1
	-- decide game mode
	if num_resets==2 then
		game_mode="long arms"
	elseif num_resets==3 then
		game_mode="cooperative"
	elseif num_resets==5 then
		game_mode="strong arm"
	elseif num_resets==7 then
		game_mode="bomb"
	elseif num_resets==8 then
		game_mode="infiniball"
	elseif num_resets==10 then
		game_mode="bouncy ball"
	elseif num_resets>10 and rnd()<0.4 then
		game_mode=game_modes[rnd_int(1,#game_modes)]
	else
		game_mode=nil
	end

	is_playing_game=true
	scene_frame=0
	camera_vy=0
	frames_since_activity=-100
	next_player_spawn=1
	frames_since_auto_spawn=0
	ball_speed_level=ternary(game_mode=="speedball",100,1)

	-- reset the entities
	players={}
	balls={}
	dropped_balls={{},{}}
	ball_spawners={}
	floating_words={}
	effects={}

	-- make the entities
	create_player(1)
	create_player(2)
	create_ball_spawner(32,1,75-ternary(debug_mode,74,0))
	create_ball_spawner(95,2,75-ternary(debug_mode,74,0))
end

function end_game()
	if end_transition_frames<=0 then
		end_transition_frames=190
		music(1)
		camera_vy=0
		balls={}
		ball_spawners={}
		local p
		for p=1,2 do
			players[p].left_hand=nil
			players[p].right_hand=nil
		end
	end
end

-- if condition is true return the second argument, otherwise the third
function ternary(condition,if_true,if_false)
	return condition and if_true or if_false
end

-- increment a counter, wrapping to 20000 if it risks overflowing
function increment_counter(n)
	return n+ternary(n>32000,-12000,1)
end

function rnd_int(min_val,max_val)
	return flr(min_val+rnd(1+max_val-min_val))
end

__gfx__
00000000000000000008880088000880222222222222222200000000000000002222222222222222222222222222222222222222222222222222222200000123
00888000001110000088888088808880222222222222222205505500110011102222222222222222222222222222222222222222222222222222222200004567
088888000100010000888880088888002222222222222222555555500110111122222222222222222222222222222222222222222222222222222222000089ab
0888880001000100008888800088800022222222222222225555555001111110222222222222222222222222222222222222222222222222222222220000cdef
08888800010001000018881008888800222222222222222205555500101111102222222222222222222222222222222222222222222222222222222200000000
00888000001110000011111088808880222222222222222200555000011111102222222222222222222222222222222222222222222222222222222200000000
00000000000000000001110088000880222222222222222200050000001111002222222222222222222222222222222222222222222222222222222200000000
00000000000000000001110000000000222222222222222200000000000000002222222222222222222222222222222222222222222222222222222200000000
0000000000000000000000000000000000000008888000000000000000000000000000000000000000000000000000000000ccc0000000000000000000000022
000000011110000000000000000000000000888888880000000000000000000999999999900000000000000000000000000ccccc000000000000000000000022
000000011110000000000000000000000888888888880000000000000000009999999999999000000000000000000000000ccccc000000000000000000000022
1001110111100000000000000000000888888888888000aa000000000000099999999999999900000000000000000000000cccccc00000000000088800000022
111111111110000000000000000088888888888880000aaaa00000000000999990000009999990000000000000000000000cccccc00000000008888880000022
011101111110000000000000008888888888888000000aaaa00000000000999900000000999990000000000000000000000cccccc00000888888888880000022
000000011111100000000008888888888888800000000aaaaa00000000099999000000000999900000000000000000000000ccccc00088888888888880000022
00000111111111100100088888888888888800000000aaaaaa00000000099990000000000099000000000000000000000000cccccc0088888888888000000022
00000111111011111100888888888888888000000000aaaaaa00000000099990000000000000000000000000000000000000cccccc0088888888800000000022
00000110011000111008888888808888888000000000aaaaaa00000000099990000000000000000000000000000000000000cccccc0088888880000000000022
0001111001100000000888888880088888880000000aaaaaaa00000000099999000009999999000000000000000000000000cccccc0008888000000000000022
0000000001111000000888888800008888880000000aaaaaaa000000000999990000999999999900000000000000000000000ccccc0008888000000000000022
0000110000000000000088880000000888888000000aaaaaa0000000aa00999990009999999999000000bbbbb000000000000ccccc0008888000000000000022
0001100000000000000000000000000888888000000aaaaaa000000aaaa00999990000999999999000bbbbbbbb00000000000ccccc0000888800088000000022
0001100000000000000000000000000088888800000aaaaa0000000aaaa0099999900000099999900bbbbbbbbb000000000000cccc0000888808888800000022
0001110111100000000000000000000088888800000aaaaa0000000aaaa0009999990000000999900bbbbbbbbb000000000000cccc0000888888888800000022
0001110111100000000000000000000008888880000aaaa00000000aaaa000099999990000999990bbbbbbbb00000bbbb00000cccc0000888888880000000022
0000111111100000000000000000000008888880000aaaa00000000aaaa000009999999999999900bbbbbb000000bbbbbb0000cccc0000888888800000000022
0000011111100000000000000000000008888880000aaaa00000000aaaa000000999999999999000bbbbb000000bbbbbbbb000cccc0000088880000000000022
0001001111100000000000000000000000888888000aaaa0000000aaaaa00000000999999999000bbbbb0000000bbbbbbbb00ccccc0000088880000000000022
0001000111111000000000000000000000888888000aaaa0000000aaaaa00000000009999990000bbbbb000000bbbbbbbbbb0ccccc0000088880000888800022
0001111111111110010000000000000000888888000aaaa0000000aaaa000000000000000000000bbbb000000bbbbbbbbbbb0ccccc0000008888888888880022
0001111111101111110000000000000000888888000aaaaa00000aaaaa000000000000000000000bbbb0000bbbbbbbbb0bbb0ccccc0000008888888888880022
0000000001100011100000000000000000088888000aaaaa00000aaaa0000000000000000000000bbbb0000bbbbbbbb00bbb0ccccc0000008888888888880022
0000000001100000000000000000000000088888000aaaaa00000aaaa0000000000000000000000bbbb0000bbbbbbb000bbb0ccccc0000000888888880000022
0000000001111000000000000000000000088888000aaaaaa000aaaa00000000000000000000000bbbbb00000bbbb000bbbb0ccccc0000000000000000000022
00000000000000000000000000000000000888880000aaaaaaaaaaaa00000000000000000000000bbbbb000000000000bbbb0ccccc0000000000000000000022
00000000000000000000000000888000000888880000aaaaaaaaaaa000000000000000000000000bbbbbb0000000000bbbbb0ccccc0000000000000000000022
000000000000000000000000088888000008888800000aaaaaaaaa00000000000000000000000000bbbbbb00000000bbbbb00cccc00000cccc00000000000022
0000000011110000000000000888888000888888000000aaaaaa0000000000000000000000000000bbbbbbbbbbbbbbbbbbb00cccc000ccccccc0000000000022
100111001111000000000000088888800088888000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbb000cccc00cccccccc0000000000022
11111110111100000000000008888888088888800000000000000000000000000000000000000000000bbbbbbbbbbbbbb0000cccc0ccccccccc0000000000022
0111011111110000000000000088888888888880000000000000000000000000000000000000000000000bbbbbbbbbb000000ccccccccccccc00000000000022
00000011111000000000000000888888888888000000000000000000000000000088800000000000000000000000000000000ccccccccccc0000000000000022
000100011111000000000000008888888888880bbbbb0000000000000000000008888800000000000888000000000000000000ccccccc0000000000000000022
000111111111100000000000000888888888800bbbbbbbb0000000000000000008888880000000008888800000000000000000cccccc00000000000000000022
00011111111111100100000000088888888800bbbbbbbbbb000000000000000008888888000000008888800000000000000000cccc0000000000000000000022
00000000011011111100000000008888888000bbbbbbbbbbb0000000000000000888888800000000888880000000000000000000000000000000000000000022
0000000001100011100000000000088880000bbbbbbbbbbbbb00000000000000088888888000000088888000000000aaaa000000000000000000000000000022
0000000001111000000000000000000000000bbbbbb0bbbbbbb000000000000008888888880000008888880000000aaaaaa00000099999999900000000000022
000000000000000000000000000000000000bbbbbb0000bbbbb000000000000008888808880000008888880000000aaaaaa00009999999999990000000000022
000000000000000000000000000000000000bbbbbb000000bbbb0000000000000888880888800000888888000000aaaaaaa00099999999999990000000000022
000000000000000000000000000000000000bbbbbb000000bbbb0000000000cc0888880088800000888888000000aaaaaa000999999999999990000000000022
00000001111000000000000000000000000bbbbbb00000000bbb00000000cccc0088880088880000888888000000aaaaaa009999999999999900000000000022
00000001111000000000000000000000000bbbbbb00000000bbb0000000ccccc0088888088880000088888000000aaaaa0099999990000000000000000000022
0000000111100000000000000000000000bbbbbb000000000bbb00000ccccccc0088888008888000088888000000aaaaa0099999000000000000000000000022
0000000111100000000000000000000000bbbbb000000000bbbb0000cccccccc0088888008888000088888000000aaaa00999990000000000000000000000022
0000001111110000000000000000000000bbbbb00000000bbbbb000cccc00ccc008888800888880000888800000aaaaa00999900000000000000000000000022
000000111111100000000000000000000bbbbbb000000bbbbbbb00cccc0000cc008888800088880000888800000aaaaa00999900000000000000000000000022
000001111111100000000000000000000bbbbbbbbbbbbbbbbbb00cccc00000cc000888800088888000888800000aaaa009999900000000000000000000000022
00001111111111000000000000000000bbbbbbbbbbbbbbbbbb00cccc000000ccc0088888000888800088880000aaaaa009999000000000000000000000000022
00011111111011100000000000000000bbbbbb0bbbbbbbbbb00cccc0000000ccc0088888000888880088880000aaaaa009999000000000000000000000000022
0111101101100111100000000000000bbbbbb000bbbbbbbb00ccccc0000000ccc0008888000088888088880000aaaa0009999000000000000000000000000022
1111011101111011110000000000000bbbbb00000000000000ccccccccc000ccc0008888000088888088880000aaaa0009999000000000000009990000000022
0ddddddd00ddddddd0000000000000bbbbbb0000000000000cccccccccccc0ccc000888800000888888880000aaaaa0009999000000000000099999000000022
d7777777dd7777777d00000000000bbbbbb0000000000000ccccccccccccc0ccc000888800000088888880000aaaaa0009999000000000000999999000000022
d777dd77dd77ddd77d00000000000bbbbbb000000000000ccccccccccccc00cccc00888000000088888880000aaaa00009999900000000009999999000000022
d77d7777dd77d7777d00000000000bbbbbb000000000000cccccc000000000cccc0008800000000888888000aaaaa00009999900000000099999990000000022
d77ddd77dd77dd777d0000000000bbbbbb000000000000cccccc0000000000cccc0000000000000888880000aaaaa00009999999000000999999900000000022
d7777d77dd77d7777d0000000000bbbbbb000000000000cccccc0000000000ccccc00000000000088888000aaaaa000000999999999999999999000000000022
d77dd777dd77d7777d0000000000bbbbb000000000000ccccccc0000000000ccccc0000000000008888800aaaaaa000000009999999999999000000000000022
d7777777dd7777777d0000000000bbbb0000000000000cccccc00000000000ccccc000000000000088800aaaaaaa000000009999999990000000000000000022
dddddddddddddddddd0000000000bbb00000000000000ccccc0000000000000cccc000000000000000000aaaaaa0000000000000000000000000000000000022
111111111111111111000000000000000000000000000cccc00000000000000ccccc0000000000000000aaaaaaa0000000000000000000000000000000000022
0ddddddd00ddddddd0000000000000000000000000000000000000000000000ccccc0000000000000000aaaaaaa0000000000000000000000000000000000022
d7777777dd7777777d000000000000000000000000000000000000000000000ccccc000000000000000aaaaaaa00000000000000000000000000000000000022
d777d777dd777d777d0000000000000000000000000000000000000000000000cccc000000000000000aaaaaaa00000000000000000000000000000000000022
d77dd777dd777dd77d0000000000000000000000000000000000000000000000ccc0000000000000000aaaaaa000000000000000000000000000000000000022
d7ddd777dd777ddd7d00000000000000000000000000000000000000000000000cc0000000000000000aaaaa0000000000000000000000000000000000000022
d77dd777dd777dd77d000000000000000000000000000000000000000000000000000000000000000000aaa00000000000000000000000000000000000000022
d777d777dd777d777d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000022
d7777777dd7777777d22222222222222222222222222222222222222222222222222222222222222222222222222222222000000000000000000000000000000
dddddddddddddddddd22222222222222222222222222222222222222222222222222222222222222222222222222222222000000000000000000000000000000
11111111111111111122222222222222222222222222222222222222222222222222222222222222222222222222222222000000000000000000000000000000
0ddddddddddddddddddddddddd022222222222222222222222222222222222222222222222222222222222222222222222000000000000011110000000000000
d7777777777777777777777777d22222222222222222222222222222222222222222222222222222222222222222222222000000000000011110000000000000
d77d77777dd7d7d7d7dd7ddd77d22222222222222222222222222222222222222222222222222222222222222222222222100111111000011110000000000000
d77d77777d77d7d7d7d777d777d22222222222222222222222222222222222222222222222222222222222222222222222111111111111111110000000000000
d77d77dd7dd7ddd7d7dd77d777d22222222222222222222222222222222222222222222222222222222222222222222222011100011111111110000000000000
d77d777777d7d7d7d7d777d777d22222222222222222222222222222222222222222222222222222222222222222222222000000000000011111111100000000
d77dd7777dd7d7d7d7d777d777d22222222222222222222222222222222222222222222222222222222222222222222222000000000001111111111111111001
d7777777777777777777777777d22222222222222222222222222222222222222222222222222222222222222222222222000000000001111110001111111111
ddddddddddddddddddddddddddd22222222222222222222222222222222222222222222222222222222222222222222222000000000001100110000000001110
33333333333333333333333333322222222222222222222222222222222222222222222222222222222222222222222222000000000111100110000000000000
0ddddddd000700000000000000222222222222222222222222222222222222222222222222222222222222222222222222000000000000000111100000000000
d7777777d00770000000000000222222222222222222222222222222222222222222222222222222222222222222222222000011000000000000000000000000
d7d777d7d00077000070000000222222222222222222222222222222222222222222222222222222222222222222222222000110000000000000000000000000
d7dd77d7d00077700070000070222222222222222222222222222222222222222222222222222222222222222222222222000110000000000000000000000000
d7d7d7d7d00007770770007700222222222222222222222222222222222222222222222222222222222222222222222222000111000000011110000000000000
d7d77dd7d00007770770777000222222222222222222222222222222222222222222222222222222222222222222222222000111111000011110000000000000
d7d777d7d77000777777770000222222222222222222222222222222222222222222222222222222222222222222222222000011111111011110000000000000
d7777777d00777777777770000222222222222222222222222222222222222222222222222222222222222222222222222000000011111111110000000000000
ddddddddd00007777777700000222222222222222222222222222222222222222222222222222222222222222222222222000000000001111110000000000000
33333333300000777777777000222222222222222222222222222222222222222222222222222222222222222222222222000000000100011111111100000000
22222222200000077777777770222222222222222222222222222222222222222222222222222222222222222222222222000000000111111111111111111001
22222222200000777777700077222222222222222222222222222222222222222222222222222222222222222222222222000000000111111110001111111111
22222222200007777777770000222222222222222222222222222222222222222222222222222222222222222222222222000000000000000110000000001110
22222222200077707077770000222222222222222222222222222222222222222222222222222222222222222222222222000000000000000110000000000000
22222222200070007000777000222222222222222222222222222222222222222222222222222222222222222222222222000000000000000111100000000000
22222222200700000000007000222222222222222222222222222222222222222222222222222222222222222222222222000000000000000000000000000000
22222222200000000000000700222222222222222222222222222222222222222222222222222222222222222222222222000000000000000000000000000000
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222000000000000000000000000000000
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222000000000000001111000000000000
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222100111111100001111000000000000
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222111111111111101111000000000000
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222011100011111111111000000000000
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222000000000000111110000000000000
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222000000000100011111000000000000
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222000000000111111111111100000000
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222000000000111111111111111111001
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222000000000000000110001111111111
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222000000000000000110000000001110
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222000000000000000111100000000000
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
__sfx__
010600002c1422c1422b1422a15229152281522715226152251522315222152201521e1421b142191421613213132171401713117121171110010000100001001713017121171110010000100001000010000100
010400000c7300d751127511a73100700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
010c00000b0100c0210e02113031180411d041210412404126041280412a0412b0412b0312b0212b0110000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010900000b0100c0210e02113031180411d041210412404126041280412a0412b0412b0312b0212b0110000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010600000b0100c0210e02113031180411d041210412404126041280412a0412b0412b0312b0212b0110000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010400000b0100c0210e02113031180411d041210412404126041280412a0412b0412b0312b0212b0110000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010c00002b0102b0212b0312a031280312603124031210311d03118021130210e0210c0210b0210b0110b01100000000000000000000000000000000000000000000000000000000000000000000000000000000
010900002b0102b0212b0312a031280312603124031210311d03118021130210e0210c0210b0210b0110b01100000000000000000000000000000000000000000000000000000000000000000000000000000000
010600002b0102b0212b0312a031280312603124031210311d03118021130210e0210c0210b0210b0110b01100000000000000000000000000000000000000000000000000000000000000000000000000000000
010400002b0102b0212b0312a031280312603124031210311d03118021130210e0210c0210b0210b0110b01100000000000000000000000000000000000000000000000000000000000000000000000000000000
000400001911113131151211e1112b111001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
0104000034640286311e24018231142310f2310d2310c2310a2310823107231042210322103211022110121100200002000020000200002000020000200002000020000200002000020000200002000020000200
0104000023520275312d5513355233552335423353233522335123351233512335123351200500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
0107000024722287322b74224752287522b75224752287522b75224752287522b75224752287522b75224752287522b75224752287522b75224752287522b75224752287522b7522472228712007000070000700
0107000000700007000070024722287522b75224752287522b75224752287522b752247522875200700007000070024752287522b752247522875200700007000070024752287120070000700007000070000700
010600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000071420714208142091520a1520c1520e1521015213152
0106000015152181521a1521e14220142231422513226132231402313123121231110010000100001002313023121231110000000000000000000000000000000000000000000000000000000000000000000000
010800001c64010631046310462104611000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
04 00424344
01 0d424344
00 0e424344
00 0f424344
04 10424344

