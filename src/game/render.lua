local Render = {}

local TILE = 100
local GAP = 12
local TOP = 90

local colors = {
    [0]  = {0.80, 0.76, 0.71},
    [2]  = {0.93, 0.89, 0.85},
    [4]  = {0.93, 0.88, 0.78},
    [8]  = {0.95, 0.69, 0.47},
    [16] = {0.96, 0.58, 0.39},
    [32] = {0.96, 0.49, 0.37},
    [64] = {0.96, 0.37, 0.23},
    [128] = {0.93, 0.81, 0.45},
    [256] = {0.93, 0.80, 0.38},
    [512] = {0.93, 0.78, 0.31},
    [1024] = {0.93, 0.77, 0.25},
    [2048] = {0.93, 0.76, 0.18},
}

local fonts = {}

function Render.load()
    love.graphics.setBackgroundColor(0.98, 0.97, 0.94)
    fonts.big = love.graphics.newFont(36)
    fonts.med = love.graphics.newFont(24)
    fonts.small = love.graphics.newFont(16)
end

local function tileColor(v)
    return colors[v] or {0.24, 0.23, 0.20}
end

local function textColor(v)
    if v <= 4 then return {0.47, 0.43, 0.40} end
    return {0.98, 0.97, 0.95}
end

-- shrink the number as it gets more digits so it fits in the tile
local function tileFont(v)
    if v < 10000 then return fonts.big end
    if v < 100000 then return fonts.med end
    return fonts.small
end

local function drawHeader(board, best, w)
    love.graphics.setColor(0.47, 0.43, 0.40)
    love.graphics.setFont(fonts.big)
    love.graphics.print("2048", GAP, 20)
    love.graphics.setFont(fonts.small)
    love.graphics.printf("SCORE " .. board.score, 0, 22, w - GAP, "right")
    love.graphics.printf("BEST " .. best, 0, 46, w - GAP, "right")
end

local function drawGrid(board, w)
    love.graphics.setColor(0.73, 0.68, 0.63)
    love.graphics.rectangle("fill", 0, TOP, w, w, 8, 8)
    for r = 1, board.size do
        for c = 1, board.size do
            local v = board.cells[r][c]
            local x = GAP + (c - 1) * (TILE + GAP)
            local y = TOP + GAP + (r - 1) * (TILE + GAP)
            love.graphics.setColor(tileColor(v))
            love.graphics.rectangle("fill", x, y, TILE, TILE, 6, 6)
            if v > 0 then
                local font = tileFont(v)
                love.graphics.setFont(font)
                love.graphics.setColor(textColor(v))
                love.graphics.printf(tostring(v), x, y + (TILE - font:getHeight()) / 2, TILE, "center")
            end
        end
    end
end

local function drawOverlay(title, subtitle, w)
    love.graphics.setColor(0.98, 0.97, 0.94, 0.75)
    love.graphics.rectangle("fill", 0, TOP, w, w, 8, 8)
    love.graphics.setColor(0.47, 0.43, 0.40)
    love.graphics.setFont(fonts.big)
    love.graphics.printf(title, 0, TOP + w / 2 - 40, w, "center")
    love.graphics.setFont(fonts.small)
    love.graphics.printf(subtitle, 0, TOP + w / 2 + 10, w, "center")
end

function Render.draw(board, best, showWin)
    local w = board.size * TILE + (board.size + 1) * GAP
    drawHeader(board, best, w)
    drawGrid(board, w)
    if board.over then
        drawOverlay("Game over :(", "Press R to restart", w)
    elseif showWin then
        drawOverlay("You Win!!", "Press C to keep playing, R to restart", w)
    end
end

return Render
