pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

local buttons
local button_presses
local button_releases

local players
local balls
local dropped_balls

function _init()
	-- initialize inputs
	buttons={{},{}}
	button_presses={{},{}}
	button_releases={{},{}}

	-- make the entities
	players={}
	balls={}
	dropped_balls={{},{}}
	create_player(1)
	create_player(2)
end

-- local skip_frame=0
function _update()
	-- skip_frame=(skip_frame+1)%10
	-- if skip_frame>0 then return end
	-- keep track of inputs (because btnp repeats presses)
	local p
	for p=1,2 do
		local b
		for b=0,5 do
			button_presses[p][b]=btn(b,p-1) and not buttons[p][b]
			button_releases[p][b]=not btn(b,p-1) and buttons[p][b]
			buttons[p][b]=btn(b,p-1)
		end
	end
	-- update all the players
	local player
	for player in all(players) do
		update_player(player)
	end
	-- update all the balls
	local ball
	for ball in all(balls) do
		update_ball(ball)
	end
end

function _draw()
	cls()
	-- draw a beautiful rainbow sky
	rectfill(0,0,128,26,1)
	rectfill(0,27,128,37,13)
	rectfill(0,38,128,65,12)
	rectfill(0,66,128,83,11)
	rectfill(0,66,128,83,11)
	rectfill(0,84,128,96,10)
	rectfill(0,97,128,106,9)
	rectfill(0,97,128,106,9)
	rectfill(0,107,128,113,8)
	rectfill(0,114,128,127,0)
	-- draw the bounds of each player's side
	pset(0,113,0)
	pset(63,113,0)
	pset(64,113,0)
	pset(127,113,0)
	-- draw all the players
	local player
	for player in all(players) do
		draw_player(player)
		pal()
	end
	-- draw all the balls
	local ball
	for ball in all(balls) do
		draw_ball(ball)
		pal()
	end
	-- draw score
	local i
	for i=1,5 do
		spr(1,12+6*i,118)
		if dropped_balls[1][i] then
			pal(8,dropped_balls[1][i].color)
			spr(0,12+6*i,118)
			pal()
		end
	end
	for i=1,5 do
		spr(1,73+6*i,118)
		if dropped_balls[2][i] then
			pal(8,dropped_balls[2][i].color)
			spr(0,73+6*i,118)
			pal()
		end
	end
end


-- player methods
function create_player(player_num)
	local player={
		player_num=player_num,
		button_index=3-player_num,
		x=ternary(player_num==1,29,99),
		y=101,
		vx=0,
		min_bound=ternary(player_num==1,9,73),
		max_bound=ternary(player_num==1,55,119),
		left_hand=nil,
		right_hand=nil,
		most_recent_catch_hand=ternary(player_num==1,"right_hand","left_hand")
	}
	-- create a ball for the player to hold
	local ball=create_ball(ternary(player_num==1,10,11))
	player[player.most_recent_catch_hand]=ball
	ball.held_by=player
	-- add the player to the list of players
	add(players,player)
	return player
end

function update_player(self)
	self.vx=ternary(buttons[self.button_index][1],1,0)-ternary(buttons[self.button_index][0],1,0)
	self.x=mid(self.min_bound,self.x+self.vx,self.max_bound)
	-- catch balls
	local ball
	for ball in all(balls) do
		if not ball.held_by and ball.catchable_by_player_num==self.player_num and ball.y>100 then
			if not self.left_hand and ball.x==mid(self.x-9,ball.x,self.x) then
				self.left_hand=ball
				ball.held_by=self
				self.most_recent_catch_hand="left_hand"
			elseif not self.right_hand and ball.x==mid(self.x,ball.x,self.x+9) then
				self.right_hand=ball
				ball.held_by=self
				self.most_recent_catch_hand="right_hand"
			end
		end
	end
	-- local i
	-- for i=1,#balls do
	-- 	local ball=balls[i]

	-- end
	-- update held balls
	if self.left_hand then
		self.left_hand.x=self.x-5
		self.left_hand.y=105
	end
	if self.right_hand then
		self.right_hand.x=self.x+4
		self.right_hand.y=105
	end
	-- throw balls
	if button_presses[self.button_index][4] then
		-- figure out which hand to throw with
		local throwing_hand
		if self.vx>0 and self.right_hand then
			throwing_hand="right_hand"
		elseif self.vx<0 and self.left_hand then
			throwing_hand="left_hand"
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
			thrown_ball.vy=-5
			thrown_ball.vx=ternary(self.player_num==1,1,-1)
			self[throwing_hand]=nil
			thrown_ball.held_by=nil
			thrown_ball.catchable_by_player_num=3-self.player_num
		end
	end
end

function draw_player(self)
	rect(self.x-8.5,self.y+0.5,self.x+8.5,self.y+12.5,0)
	pset(self.x+0.5,self.y+0.5,1)
end


-- ball methods
function create_ball(color)
	local ball={
		x=50,
		y=50,
		vx=0,
		vy=0,
		color=color,
		held_by=nil,
		catchable_by_player_num=nil
	}
	-- add the ball to the list of balls
	add(balls,ball)
	return ball
end

function update_ball(self)
	if not self.held_by then
		self.vy+=0.15
		self.x+=self.vx
		self.y+=self.vy
	end
	if self.y>115 then
		del(balls,self)
		add(dropped_balls[self.catchable_by_player_num],self)
	end
end

function draw_ball(self)
	-- rect(self.x-1.5,self.y-1.5,self.x+2.5,self.y+2.5,0)
	-- pset(self.x+0.5,self.y+0.5,1)
	pal(8,self.color)
	spr(0,self.x-2.5,self.y-2.5)
	-- print(self.y,self.x+6,self.y,7)
end


-- helper methods
-- if condition is true return the second argument, otherwise the third
function ternary(condition,if_true,if_false)
	return condition and if_true or if_false
end
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00888000001110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08888800010001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08888800010001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08888800010001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00888000001110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
