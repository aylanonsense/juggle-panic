pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

local buttons
local button_presses
local button_releases

local players
local balls

function _init()
	-- initialize inputs
	buttons={{},{}}
	button_presses={{},{}}
	button_releases={{},{}}

	-- make the entities
	players={}
	balls={}
	create_player(1)
	create_player(2)
	create_ball()
end

function _update()
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
	end
	-- draw all the balls
	local ball
	for ball in all(balls) do
		draw_ball(ball)
	end
end


-- player methods
function create_player(player_num)
	local player={
		button_index=3-player_num,
		x=ternary(player_num==1,29,99),
		y=101,
		vx=0,
		min_bound=ternary(player_num==1,9,73),
		max_bound=ternary(player_num==1,55,119),
		left_hand=nil,
		right_hand=nil
	}
	-- create a ball for the player to hold
	local ball=create_ball()
	player[ternary(player_num==1,"left_hand","right_hand")]=ball
	ball.held_by=player
	-- add the player to the list of players
	add(players,player)
	return player
end

function update_player(self)
	self.vx=ternary(buttons[self.button_index][1],1,0)-ternary(buttons[self.button_index][0],1,0)
	self.x=mid(self.min_bound,self.x+self.vx,self.max_bound)
	-- update held balls
	if self.left_hand then
		self.left_hand.x=self.x-5
		self.left_hand.y=105
	end
	if self.right_hand then
		self.right_hand.x=self.x+4
		self.right_hand.y=105
	end
end

function draw_player(self)
	rect(self.x-8.5,self.y+0.5,self.x+8.5,self.y+12.5,0)
	pset(self.x+0.5,self.y+0.5,1)
end


-- ball methods
function create_ball()
	local ball={
		x=50,
		y=50,
		vx=0,
		vy=0,
		held_by=nil
	}
	-- add the ball to the list of balls
	add(balls,ball)
	return ball
end

function update_ball(self)
	if not self.held_by then
		self.vy+=0.1
		self.x+=self.vx
		self.y+=self.vy
	end
end

function draw_ball(self)
	rect(self.x-1.5,self.y-1.5,self.x+2.5,self.y+2.5,0)
	pset(self.x+0.5,self.y+0.5,1)
end


-- helper methods
-- if condition is true return the second argument, otherwise the third
function ternary(condition,if_true,if_false)
	return condition and if_true or if_false
end
