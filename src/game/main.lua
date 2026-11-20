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

local function restart()
    board:reset()
    keepPlaying = false
end

function love.load()
    love.math.setRandomSeed(os.time())
    Render.load()
    board = Board.new(4)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "r" then
        restart()
    elseif board.won and not keepPlaying then
        if key == "c" then keepPlaying = true end
    elseif keyMap[key] then
        board:move(keyMap[key])
        if board.score > best then best = board.score end
    end
end

function love.draw()
    Render.draw(board, best, board.won and not keepPlaying)
end