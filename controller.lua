-- infile command syntax:
-- P*button* - Press *button*
-- R - Reset
-- W - Pause (as in "Wait")
-- A*number* - Advance *number* frames uninterrupted
-- I (or anything else but preferably I because other things could be reassigned in the future) - Ignore inputs and continue
--emu.speedmode("maximum")
--emu.speedmode("turbo")
buttons = {"B"}
-- memory mappings: xspeed, yspeed, terrain
-- structure layout: {memory location, number of bytes + "s" for signed or "u" for unsigned}
mems = {{0x10ea, "2u"}, -- Speed
        {0x0088, "2u"}, -- X position
        {0x008c, "2u"}, -- Y position
        {0x10c1, "1u"}, -- Current laps + 127
        {0x104e, "1u"}, -- Boosted
        {0x1030, "1u"}, -- Shrunk
        {0x0e00, "1u"}, -- Coins
        {0x101f, "2u"}, -- Jump height
        {0x1061, "1u"}, -- Mole
        {0x10a0, "1u"}, -- Kart status
        {0x1052, "1u"}} -- Collision
screen = require "SMKScreen"
frame = 0
function step()
    for i=1,#buttons do
        joypad.set(1, {[buttons[i]]=1})
    end
    emu.frameadvance()
end

step()
buttons = {}
while frame < 322 do
    step()
    frame = frame + 1
end
state = savestate.create()
savestate.save(state)
frame = -1

while true do
    frame = frame + 1
    if frame >= 0 and frame % 4 == 0 then
        outfile = io.open("out", "w")
        outfile:write(frame .. "\n" .. isTurnedAround() .. "\n")
        for i=1,#mems do
            loc = 0x7e0000 + mems[i][1]
            if mems[i][2] == "1u" then
                val = memory.readbyte(loc)
            elseif mems[i][2] == "1s" then
                val = memory.readbytesigned(loc)
            elseif mems[i][2] == "2u" then
                val = memory.readword(loc)
            else
                val = memory.readwordsigned(loc)
            end
            outfile:write(val .. "\n")
        end
        data = screen.getScreen()
        for i=1,#data do
            outfile:write(data[i] .. "\n")
        end
        io.close(outfile)

        buttons = {}

        infile = io.open("in", "r")
        str = infile:read()

        while str == nil do
            io.close(infile)
            infile = io.open("in", "r")
            str = infile:read()
        end

        while str ~= nil do
            cmd = string.sub(str, 1, 1)
            if cmd == "P" then
                buttons[#buttons+1] = string.sub(str, 2, -1)
            elseif cmd == "R" then
                frame = -1
                savestate.load(state)
                break
            elseif cmd == "W" then
                io.close(infile)
                infile = io.open("in", "w")
                io.close(infile)
                emu.pause()
                infile = io.open("in", "r")
            elseif cmd == "A" then
                frame = -tonumber(string.sub(str, 2, -1))
            else
                break
            end
            str = infile:read()
        end
        io.close(infile)
        infile = io.open("in", "w")
        io.close(infile)
    end
    step()
end
