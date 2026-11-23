local Board = require("board")
local Render = require("render")

local board
local best = 0
local keepPlaying = false

local keyMap = {
    left = "left", a = "left",
    right = "right", d = "right",
    up = "up", w = "up",
    down = "down", s = "down",
}

local function fitWindowToScreen()
    local dw, dh = love.window.getDesktopDimensions()
    local w, h = math.floor(dw * 0.9), math.floor(dh * 0.8)
    love.window.updateMode(w, h)
    love.window.setPosition(math.floor((dw - w) / 2), math.floor((dh - h) / 2))
end

local function restart()
    board:reset()
    keepPlaying = false
    Render.animate(board.events)
end

function love.load()
    love.math.setRandomSeed(os.time())
    Render.load()
    board = Board.new(4)
    Render.animate(board.events)
    fitWindowToScreen()
end

function love.update(dt)
    Render.update(dt)
end

function love.resize()
    Render.resize()
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "r" then
        restart()
    elseif key == "f" then
        love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
    elseif board.won and not keepPlaying then
        if key == "c" then keepPlaying = true end
    elseif keyMap[key] then
        if board:move(keyMap[key]) then Render.animate(board.events) end
        if board.score > best then best = board.score end
    end
end

function love.draw()
    Render.draw(board, best, board.won and not keepPlaying)
end