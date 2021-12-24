---------------------------------------
-- USER DEFAULTS --
---------------------------------------
local palette = app.activeSprite.palettes[1]

-- Default colors:
local colors = {
    stroke = Color{r=0, g=0, b=0, a=255},
    fill = Color{r=255, g=255, b=255, a=255},
}

-- Default Max Sizes:
local maxSize = {
    x = math.floor(app.activeSprite.width/4), 
    y = math.floor(app.activeSprite.width/4), 
}

---------------------------------------
-- BASIC LINES --
---------------------------------------
local function hLine(color, x, y, len)
    -- Horizontal Line
    for i = 1, len do
        app.activeImage:putPixel(x+i, y, color)
    end
end

---------------------------------------
-- ENCODE/DECODE --
---------------------------------------

-- This is your secret 67-bit key (any random bits are OK)
local Key53 = 8186484168865098
local Key14 = 4887

local inv256

local function encode(str)
    if not inv256 then
    inv256 = {}
    for M = 0, 127 do
        local inv = -1
        repeat inv = inv + 2
        until inv * (2*M + 1) % 256 == 1
        inv256[M] = inv
    end
    end
    local K, F = Key53, 16384 + Key14
    return (str:gsub('.',
    function(m)
        local L = K % 274877906944  -- 2^38
        local H = (K - L) / 274877906944
        local M = H % 128
        m = m:byte()
        local c = (m * inv256[M] - (H - M) / 128) % 256
        K = L * F + H + c + m
        return ('%02x'):format(c)
    end
    ))
end

local function decode(str)
    local K, F = Key53, 16384 + Key14
    return (str:gsub('%x%x',
    function(c)
        local L = K % 274877906944  -- 2^38
        local H = (K - L) / 274877906944
        local M = H % 128
        c = tonumber(c, 16)
        local m = (c + (H - M) / 128) * (2*M + 1) % 256
        K = L * F + H + c + m
        return string.char(m)
    end
    ))
end

-- local s = 'Hello world'
-- print(       encode(s) ) --> 80897dfa1dd85ec196bc84
-- print(decode(encode(s))) --> Hello world

---------------------------------------
-- BIT OPERATIONS --
---------------------------------------
local OR, XOR, AND = 1, 3, 4

local function bitoper(a, b, oper)
    local r, m, s = 0, 2^31
    repeat
        s,a,b = a+b+m, a%m, b%m
        r,m = r + m*oper%(s-a-b), m/2
    until m < 1
    return r
end

local function lshift(x, by)
    return x * 2 ^ by
end

local function rshift(x, by)
    return math.floor(x / 2 ^ by)
end

-- print(bitoper(6,3,OR))   --> 7
-- print(bitoper(6,3,XOR))  --> 5
-- print(bitoper(6,3,AND))  --> 2

---------------------------------------
-- TEXT 2 PIXEL ART --
---------------------------------------
local function text2pixelart(fg, bg, x, y, text, encTxt)
    local t = text..'        '
    if(encTxt == true)
    then
        t = encode(t)
    end
    -- Draw each character (limited by 8 chars)
    for j = 1, math.min(string.len(t), 8) do
        local cByte = string.byte(string.sub(t, j, j+1))
        -- Draw character bit pixel art
        for i = 0, 8-1 do
            local a = math.floor(bitoper(rshift(cByte, 8-1-i), 1, AND))
            local col = bg
            if(a==1)
            then
                col = fg
            end
            app.activeImage:putPixel(x+i, y+j, col)
        end
    end
end

---------------------------------------
-- LAYER MANAGEMENT --
---------------------------------------
local function newLayer(name)
    s = app.activeSprite
    lyr = s:newLayer()
    lyr.name = name
    s:newCel(lyr, 1)

    return lyr
end

---------------------------------------
-- USER INTERFACE --
---------------------------------------
local dlg = Dialog("Text 2 Pixel Art")
dlg :separator{ text="Text:" }
    :entry {id="text", label="Text"}
    :check {id = "encodeText", label = "Encode Text: ", text = "", selected = false}

    :separator{ text="Colors:" }
    :color {id="fgColor", label="FG:", color = colors.stroke}
    :color {id="bgColor", label="BG:", color = colors.fill}

    :separator()
    :button {id="ok", text="Add Box", onclick=function()
        local data = dlg.data
        app.transaction(function() 
            newLayer("T2P("..data.text..")")
            text2pixelart(data.fgColor, data.bgColor, 10, 10, data.text, data.encodeText)
        end)
        -- Refresh screen
        app.command.Undo()
        app.command.Redo()
    end
    }
:show{wait=false}
---------------------------------------