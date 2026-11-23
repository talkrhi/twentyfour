local Render = {}

local TILE, GAP = 100, 12
local HEADER = 0.22

local SLIDE_TIME = 0.1
local POP_TIME = 0.2
local SCORE_FLOAT_TIME = 0.8

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
local anim = nil
local scoreFloats = {}

local function round(n)
    return math.floor(n + 0.5)
end

local function clamp01(p)
    return math.max(0, math.min(1, p))
end

local function easeOutCubic(p)
    return 1 - (1 - p) ^ 3
end

local function easeOutBack(p)
    local c = 1.70158
    return 1 + (c + 1) * (p - 1) ^ 3 + c * (p - 1) ^ 2
end

local function cellKey(r, c)
    return r * 100 + c
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

function Render.animate(events)
    local function cellSet(cells)
        local set = {}
        for _, cell in ipairs(cells) do set[cellKey(cell.r, cell.c)] = true end
        return set
    end
    anim = {
        t = 0,
        slideTime = #events.slides > 0 and SLIDE_TIME or 0,
        slides = events.slides,
        merged = cellSet(events.merges),
        spawned = cellSet(events.spawns),
    }
    if events.gained > 0 then
        scoreFloats[#scoreFloats + 1] = {text = "+" .. events.gained, t = 0}
    end
end

function Render.update(dt)
    if anim then
        anim.t = anim.t + dt
        if anim.t >= anim.slideTime + POP_TIME then anim = nil end
    end
    for i = #scoreFloats, 1, -1 do
        local float = scoreFloats[i]
        float.t = float.t + dt
        if float.t >= SCORE_FLOAT_TIME then table.remove(scoreFloats, i) end
    end
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

local function drawScoreFloats(x, y, w, h)
    love.graphics.setFont(font(h * 0.32))
    for _, float in ipairs(scoreFloats) do
        local p = float.t / SCORE_FLOAT_TIME
        love.graphics.setColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3], 1 - p)
        love.graphics.printf(float.text, x, round(y + h * 0.35 - h * 0.9 * easeOutCubic(p)), w, "center")
    end
end

local function drawHeader(board, best, L)
    local headerH = L.side * HEADER
    local w, h, gap = L.side * 0.28, L.side * 0.13, L.side * 0.03
    local y = round(L.y - headerH + (headerH - h) / 2)
    local cx = L.x + L.side / 2
    local scoreX = round(cx - gap / 2 - w)
    drawScoreBox("SCORE", board.score, scoreX, y, w, h)
    drawScoreBox("BEST", best, round(cx + gap / 2), y, w, h)
    drawScoreFloats(scoreX, y, w, h)
end

local function cellPosition(L, r, c)
    return L.x + L.gap + (c - 1) * (L.tile + L.gap), L.y + L.gap + (r - 1) * (L.tile + L.gap)
end

local function drawTile(v, x, y, L, scale)
    scale = scale or 1
    if scale <= 0.01 then return end
    local half = L.tile / 2
    love.graphics.push()
    love.graphics.translate(round(x + half), round(y + half))
    love.graphics.scale(scale)
    love.graphics.setColor(tileColor(v))
    love.graphics.rectangle("fill", -half, -half, L.tile, L.tile, L.gap * 0.5, L.gap * 0.5)
    if v > 0 then
        local text = tostring(v)
        local f = fitFont(text, L.tile * 0.45, L.tile * 0.82)
        love.graphics.setFont(f)
        love.graphics.setColor(textColor(v))
        love.graphics.printf(text, -half, round(-f:getHeight() / 2), L.tile, "center")
    end
    love.graphics.pop()
end

local function drawSlidingTiles(L)
    local p = easeOutCubic(anim.t / anim.slideTime)
    for _, s in ipairs(anim.slides) do
        local x1, y1 = cellPosition(L, s.fromR, s.fromC)
        local x2, y2 = cellPosition(L, s.toR, s.toC)
        drawTile(s.value, x1 + (x2 - x1) * p, y1 + (y2 - y1) * p, L)
    end
end

local function drawSettledTiles(board, L)
    local p = anim and clamp01((anim.t - anim.slideTime) / POP_TIME) or 1
    for r = 1, board.size do
        for c = 1, board.size do
            local v = board.cells[r][c]
            if v > 0 then
                local scale = 1
                if anim and anim.spawned[cellKey(r, c)] then
                    scale = easeOutBack(p)
                elseif anim and anim.merged[cellKey(r, c)] then
                    scale = 1 + 0.2 * math.sin(math.pi * p)
                end
                local x, y = cellPosition(L, r, c)
                drawTile(v, x, y, L, scale)
            end
        end
    end
end

local function drawBoard(board, L)
    love.graphics.setColor(BOARD_COLOR)
    love.graphics.rectangle("fill", L.x, L.y, L.side, L.side, L.gap * 0.66, L.gap * 0.66)
    for r = 1, board.size do
        for c = 1, board.size do
            local x, y = cellPosition(L, r, c)
            drawTile(0, x, y, L)
        end
    end
    if anim and anim.t < anim.slideTime then
        drawSlidingTiles(L)
    else
        drawSettledTiles(board, L)
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
    drawBoard(board, L)
    if anim then return end
    if board.over then
        drawOverlay("Game over :(", "Press R to restart", L)
    elseif showWin then
        drawOverlay("You Win!!", "Press C to keep playing, R to restart", L)
    end
end

return Render
