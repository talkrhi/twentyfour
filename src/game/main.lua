local Board = require("board")
local Render = require("render")

local board
local best = 0
local startBest = 0
local keepPlaying = false
local MENUS = {
    over = {"Retry", "Quit"},
    win = {"Keep playing", "Retry", "Quit"},
}
local menu = {items = MENUS.over, selected = 1, newBest = false}

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
    startBest = best
    menu.selected = 1
    Render.animate(board.events)
end

local function activeMenu()
    if board.won and not keepPlaying then return MENUS.win end
    if board.over then return MENUS.over end
end

local function choose(i)
    local item = menu.items[i]
    if item == "Keep playing" then
        keepPlaying = true
    elseif item == "Retry" then
        restart()
    elseif item == "Quit" then
        love.event.quit()
    end
end

function love.load()
    love.math.setRandomSeed(os.time())
    board = Board.new(4)
    Render.animate(board.events)
    fitWindowToScreen()
end

function love.update(dt)
    local items = activeMenu()
    if items and items ~= menu.items then
        menu.items, menu.selected = items, 1
    end
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
    elseif key == "t" then
        Render.nextTheme()
    elseif activeMenu() then
        if key == "c" and menu.items == MENUS.win then
            keepPlaying = true
        elseif key == "up" or key == "w" then
            menu.selected = (menu.selected - 2) % #menu.items + 1
        elseif key == "down" or key == "s" then
            menu.selected = menu.selected % #menu.items + 1
        elseif key == "return" or key == "kpenter" or key == "space" then
            choose(menu.selected)
        end
    elseif keyMap[key] then
        if board:move(keyMap[key]) then Render.animate(board.events) end
        best = math.max(best, board.score)
    end
end

function love.mousemoved(x, y)
    if activeMenu() then
        menu.selected = Render.menuItemAt(x, y) or menu.selected
    end
end

function love.mousepressed(x, y, button)
    local i = activeMenu() and button == 1 and Render.menuItemAt(x, y)
    if i then choose(i) end
end

function love.draw()
    menu.newBest = board.score > startBest
    Render.draw(board, best, board.won and not keepPlaying, menu)
end