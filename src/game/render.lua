local Render = {}

local TILE, GAP = 100, 12
local HEADER = 0.22

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

local BOARD_COLOR = {0.73, 0.68, 0.63}
local TEXT_COLOR = {0.47, 0.43, 0.40}

local fontCache = {}

local function round(n)
    return math.floor(n + 0.5)
end

local function font(size)
    size = math.max(6, round(size))
    if not fontCache[size] then fontCache[size] = love.graphics.newFont(size) end
    return fontCache[size]
end

local function fitFont(text, maxSize, width)
    local f = font(maxSize)
    local textWidth = f:getWidth(text)
    if textWidth > width then f = font(maxSize * width / textWidth) end
    return f
end

function Render.load()
    love.graphics.setBackgroundColor(0.98, 0.97, 0.94)
end

function Render.resize()
    fontCache = {}
end

local function layout(board)
    local W, H = love.graphics.getDimensions()
    local margin = math.min(W, H) * 0.04
    local side = math.min(W - 2 * margin, (H - 2 * margin) / (1 + HEADER))
    local scale = side / (board.size * TILE + (board.size + 1) * GAP)
    local top = (H - side * (1 + HEADER)) / 2
    return {
        side = side,
        x = round((W - side) / 2),
        y = round(top + side * HEADER),
        tile = TILE * scale,
        gap = GAP * scale,
    }
end

local function tileColor(v)
    return colors[v] or {0.24, 0.23, 0.20}
end

local function textColor(v)
    if v <= 4 then return TEXT_COLOR end
    return {0.98, 0.97, 0.95}
end

local function drawScoreBox(label, value, x, y, w, h)
    love.graphics.setColor(BOARD_COLOR)
    love.graphics.rectangle("fill", x, y, w, h, h * 0.12, h * 0.12)

    love.graphics.setFont(font(h * 0.22))
    love.graphics.setColor(0.93, 0.89, 0.85)
    love.graphics.printf(label, x, round(y + h * 0.12), w, "center")

    local text = tostring(value)
    local f = fitFont(text, h * 0.42, w * 0.88)
    love.graphics.setFont(f)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(text, x, round(y + h * 0.4 + (h * 0.5 - f:getHeight()) / 2), w, "center")
end

local function drawHeader(board, best, L)
    local headerH = L.side * HEADER
    local w, h, gap = L.side * 0.28, L.side * 0.13, L.side * 0.03
    local y = round(L.y - headerH + (headerH - h) / 2)
    local cx = L.x + L.side / 2
    drawScoreBox("SCORE", board.score, round(cx - gap / 2 - w), y, w, h)
    drawScoreBox("BEST", best, round(cx + gap / 2), y, w, h)
end

local function drawGrid(board, L)
    love.graphics.setColor(BOARD_COLOR)
    love.graphics.rectangle("fill", L.x, L.y, L.side, L.side, L.gap * 0.66, L.gap * 0.66)
    for r = 1, board.size do
        for c = 1, board.size do
            local v = board.cells[r][c]
            local x = round(L.x + L.gap + (c - 1) * (L.tile + L.gap))
            local y = round(L.y + L.gap + (r - 1) * (L.tile + L.gap))
            love.graphics.setColor(tileColor(v))
            love.graphics.rectangle("fill", x, y, L.tile, L.tile, L.gap * 0.5, L.gap * 0.5)
            if v > 0 then
                local text = tostring(v)
                local f = fitFont(text, L.tile * 0.45, L.tile * 0.82)
                love.graphics.setFont(f)
                love.graphics.setColor(textColor(v))
                love.graphics.printf(text, x, round(y + (L.tile - f:getHeight()) / 2), L.tile, "center")
            end
        end
    end
end

local function drawOverlay(title, subtitle, L)
    love.graphics.setColor(0.98, 0.97, 0.94, 0.75)
    love.graphics.rectangle("fill", L.x, L.y, L.side, L.side, L.gap * 0.66, L.gap * 0.66)
    love.graphics.setColor(TEXT_COLOR)
    local titleFont = font(L.side * 0.085)
    love.graphics.setFont(titleFont)
    love.graphics.printf(title, L.x, round(L.y + L.side / 2 - titleFont:getHeight()), L.side, "center")
    love.graphics.setFont(fitFont(subtitle, L.side * 0.036, L.side * 0.9))
    love.graphics.printf(subtitle, L.x, round(L.y + L.side * 0.52), L.side, "center")
end

function Render.draw(board, best, showWin)
    local L = layout(board)
    drawHeader(board, best, L)
    drawGrid(board, L)
    if board.over then
        drawOverlay("Game over :(", "Press R to restart", L)
    elseif showWin then
        drawOverlay("You Win!!", "Press C to keep playing, R to restart", L)
    end
end

return Render
