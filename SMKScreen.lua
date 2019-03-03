--[[
This is adapted from SethBling's MariFlow project

--

MariFlow is Copyright © 2017 SethBling LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

The GNU General Public License can be found at <https://www.gnu.org/licenses/>.
]]

SMKScreen = {}

ConfigParams = {
	"ScreenWidth",
	"ScreenHeight",
	"ExtraInputs",
	"NumButtons",
	"Skew",
	"TiltShift",
	"InputResolution",
}
cfg = {}

cfg.ScreenWidth = 15
cfg.ScreenHeight = 15
ScreenSize = nil
HalfWidth = nil
cfg.Skew = 1.05
cfg.TiltShift = 0.3
cfg.InputResolution = 24
TileSize = 32
FirstMap = 0x00
LastMap = 0x13
NumMaps = LastMap - FirstMap + 1
ExtraInputNames = {
	"Speed",
	"Backwards",
	"Item Box",
}
cfg.ExtraInputs = NumMaps + #ExtraInputNames

map = nil
kartX = nil
kartY = nil
direction = nil
map = nil
currentCourse = -1

function configUpdated()
	HalfWidth = math.floor(cfg.ScreenWidth/2)
	ScreenSize = cfg.ScreenWidth*cfg.ScreenHeight
end

configUpdated()


function getPositions(player)
	if player == 1 then
		kartX = memory.readwordsigned(0x7e0088)
		kartY = memory.readwordsigned(0x7e008C)

		direction = memory.readbyte(0x7e102B)
		kartSpeed = memory.readwordsigned(0x7e10EA)
	else
		kartX = memory.readwordsigned(0x7e008A)
		kartY = memory.readwordsigned(0x7e008E)

		direction = memory.readbyte(0x7e112B)
		kartSpeed = memory.readwordsigned(0x7e11EA)
	end
end

function getLap()
	return memory.readbyte(0x7e10C1)-128
end

function getSurface()
	val = memory.readbyte(0x7e10AE)
	if val == 64 then
		return 1
	end
	if val == 84 then
		return 0
	end
	if val == 128 then
		return -1
	end
end

function getPhysics(physics)
	if physics == 0x54 then --dirt
		return 0
	elseif physics == 0x5A then --lily pads/grass
		return 0
	elseif physics == 0x5C then --shallow water
		return 0
	elseif physics == 0x58 then --snow
		return 0
	elseif physics == 0x56 then --chocodirt
		return -0.5
	elseif physics == 0x40 then --road
		return 1
	elseif physics == 0x46 then --dirt road
		return 0.75
	elseif physics == 0x52 then --loose dirt
		return 0.5
	elseif physics == 0x42 then --ghost road
		return 1
	elseif physics == 0x10 then --jump pad
		return 1.5
	elseif physics == 0x4E then --light ghost road
		return 1
	elseif physics == 0x50 then --wood bridge
		return 1
	elseif physics == 0x1E then --starting line
		return 1
	elseif physics == 0x44 then --castle road
		return 1
	elseif physics == 0x16 then --speed boost
		return 2
	elseif physics == 0x80 then --wall
		return -1.5
	elseif physics == 0x26 then	--oob grass
		return -1.5
	elseif physics == 0x22 then --deep water
		return -1
	elseif physics == 0x20 then --pit
		return -2
	elseif physics == 0x82 then --ghost house border
		return -1.5
	elseif physics == 0x24 then --lava
		return -2
	elseif physics == 0x4C then --choco road
		return 1
	elseif physics == 0x12 then --choco bump
		return 0.75
	elseif physics == 0x1C then --choco bump
		return 0.75
	elseif physics == 0x5E then --mud
		return 0.5
	elseif physics == 0x48 then --wet sand
		return 0.75
	elseif physics == 0x4A then --sand road
		return 1
	elseif physics == 0x84 then --ice blocks
		return -1.5
	elseif physics == 0x28 then --unsure
		return -1
	elseif physics == 0x14 then --? box
		return 1.5
	elseif physics == 0x1A then --coin
		return 1.25
	elseif physics == 0x18 then --oil spill
		return -0.75
	else
		--print("Error reading physics type " .. physics .. " for tile " .. tile .. " at x=" .. x .. ", y=" .. y)
		print("Error")
		return 0
	end
end

function getItemBox()
	return memory.readbyte(0x7e0D70)
end

function isTurnedAround()
	if bit.band(memory.readbyte(0x7e010B), 0x10) ~= 0 then
		return 1
	else
		return 0
	end
end

function readMap()
	map = {}

	for x=1,128 do
		map[x] = {}
		for y=1,128 do
			local tile = memory.readbyte(0x7f0000+((x-1)+(y-1)*128)*1)

			map[x][y] = getPhysics(memory.readbyte(0x7e0B00+tile))
		end
	end
end

function getCourse()
	return memory.readbyte(0x7e0124)
end

function getGameMode()
	return memory.readbyte(0x7e00B5)
end

function getTile(parallelDist, orthDist, facingVec)
	local dir = facingVec
	local orth = {-dir[2], dir[1]}

	if cfg.TiltShift ~= 0 then
		parallelDist = parallelDist * parallelDist * cfg.TiltShift
	end

	orthDist = orthDist * (parallelDist * (cfg.Skew - 1) + 1)

	local dx = parallelDist*dir[1]+orthDist*orth[1]
	local dy = parallelDist*dir[2]+orthDist*orth[2]

	local worldX = math.floor((kartX+TileSize/2+dx*cfg.InputResolution)/TileSize)+1
	local worldY = math.floor((kartY+TileSize/2+dy*cfg.InputResolution)/TileSize)-1

	if worldX >= 1 and worldX <= 128 and worldY >= 1 and worldY <= 128 then
		return map[worldX][worldY]
	else
		return -1
	end
end

function SMKScreen.getScreen(player)
	if map == nil or getGameMode() == 0x1C and getCourse() ~= currentCourse then
		currentCourse = getCourse()
		readMap()
	end

	getPositions(player)

	local angel = direction * 1.40625
	local dir = {math.sin(math.rad(angel)), -math.cos(math.rad(angel))}
	local orth = {-dir[2], dir[1]}

	local inputs = {}

	-- Add base tiles
	for tileRow = cfg.ScreenHeight, 1, -1 do
		for tileCol = -HalfWidth, HalfWidth do
			inputs[#inputs+1] = getTile(tileRow, tileCol, dir)
		end
	end

	-- Add enemy karts
	for k=1,8 do
		if k ~= player then
			local base = 0x7e0F00+0x100*k
			local kX = math.floor(memory.readwordsigned(base+0x18) * 4)
			local kY = math.floor(memory.readwordsigned(base+0x1C) * 4)
			local dx = kX - kartX
			local dy = kY - kartY
			local row = math.floor((dx*dir[1] + dy*dir[2]) / cfg.InputResolution)
			local col = math.floor((dx*orth[1] + dy*orth[2]) / cfg.InputResolution)

			col = col / (row * (cfg.Skew - 1) + 1)
			if cfg.TiltShift ~= 0 then
				row = math.sqrt(row / cfg.TiltShift)
			end

			col = math.floor(col + HalfWidth + 1)
			row = math.floor(cfg.ScreenHeight - row + 1)

			if row >= 1 and row <= cfg.ScreenHeight and col >= 1 and col <= cfg.ScreenWidth then
				inputs[(row - 1)*cfg.ScreenWidth+col] = -0.5
			end
		end
	end

	-- Add items
	for i=1,6 do
		local base = 0x7e1a00 + 0x80*(i-1)
		local alive = memory.readbyte(base + 0x13)
		if alive ~= 0 then
			local itemX = math.floor(memory.readwordsigned(base + 0x18) * 4)
			local itemY = math.floor(memory.readwordsigned(base + 0x1C) * 4)
			local dx = itemX - kartX
			local dy = itemY - kartY
			local row = math.floor((dx*dir[1] + dy*dir[2]) / cfg.InputResolution)
			local col = math.floor((dx*orth[1] + dy*orth[2]) / cfg.InputResolution)

			col = col / (row * (cfg.Skew - 1) + 1)
			if cfg.TiltShift ~= 0 then
				row = math.sqrt(row / cfg.TiltShift)
			end

			col = math.floor(col + HalfWidth + 1)
			row = math.floor(cfg.ScreenHeight - row + 1)

			if row >= 1 and row <= cfg.ScreenHeight and col >= 1 and col <= cfg.ScreenWidth then
				inputs[(row - 1)*cfg.ScreenWidth+col] = -1.0
			end
		end
	end

	-- Add current map inputs
	for i=FirstMap,LastMap do
		if currentCourse == i then
			inputs[#inputs+1] = 1
		else
			inputs[#inputs+1] = 0
		end
	end

	-- Add miscellaneous inputs
	inputs[#inputs+1] = kartSpeed / (1024.0)
	inputs[#inputs+1] = getItemBox() / 16.0

	return inputs
end

function SMKScreen.isGameplay()
	if getGameMode() ~= 0x1C then
		return false
	end

	local lap = getLap()
	if lap >= 5 then
		return false
	end

	if lap < 0 then
		return false
	end

	return true
end

function SMKScreen.fileHeader(numButtons)
	cfg.NumButtons = numButtons

	local text = ""
	for i=1,#ConfigParams do
		text = text .. cfg[ConfigParams[i]] .. " "
	end

	return text
end

function SMKScreen.screenText(screen)
	local text = ""
	idx = 1
	for i=1,cfg.ScreenWidth do
		for j=1,cfg.ScreenHeight do
			text = text .. screen[idx] .. " "
			idx = idx + 1
		end
		text = text .. "\n"
	end
	for i=1,NumMaps do
		text = text .. screen[idx] .. " "
		idx = idx + 1
	end
	text = text .. "\n"
	for i=1,#ExtraInputNames do
		text = text .. screen[idx] .. " "
		idx = idx + 1
	end
	text = text .. "\n"

	return text
end

function SMKScreen.configure(header, verify)
	for i=1,#header do
		if verify then
			assert(cfg[ConfigParams[i]] == header[i])
		else
			cfg[ConfigParams[i]] = tonumber(header[i])
			print(ConfigParams[i] .. ": " .. header[i])
		end
	end

	configUpdated()
end

return SMKScreen
