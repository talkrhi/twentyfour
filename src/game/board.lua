local Board = {}
Board.__index = Board

function Board.new(size)
    local self = setmetatable({}, Board)
    self.size = size or 4
    self:reset()
    return self
end

function Board:reset()
    self.cells = {}
    for r = 1, self.size do
        self.cells[r] = {}
        for c = 1, self.size do
            self.cells[r][c] = 0
        end
    end
    self.score = 0
    self.won = false
    self.over = false
    self.events = {slides = {}, merges = {}, spawns = {}, gained = 0}
    self:spawn()
    self:spawn()
end

function Board:spawn()
    local empty = {}
    for r = 1, self.size do
        for c = 1, self.size do
            if self.cells[r][c] == 0 then
                empty[#empty + 1] = {r, c}
            end
        end
    end
    if #empty == 0 then return end
    local cell = empty[love.math.random(#empty)]
    self.cells[cell[1]][cell[2]] = love.math.random() < 0.9 and 2 or 4
    self.events.spawns[#self.events.spawns + 1] = {r = cell[1], c = cell[2]}
end

function Board:slideLine(line)
    local tiles = {}
    for i = 1, self.size do
        if line[i] ~= 0 then tiles[#tiles + 1] = {value = line[i], from = i} end
    end
    local result, gained, slides, merges = {}, 0, {}, {}
    local i = 1
    while i <= #tiles do
        local tile, nextTile = tiles[i], tiles[i + 1]
        local to = #result + 1
        slides[#slides + 1] = {from = tile.from, to = to, value = tile.value}
        if nextTile and tile.value == nextTile.value then
            local merged = tile.value * 2
            result[to] = merged
            gained = gained + merged
            if merged == 2048 then self.won = true end
            slides[#slides + 1] = {from = nextTile.from, to = to, value = nextTile.value}
            merges[#merges + 1] = to
            i = i + 2
        else
            result[to] = tile.value
            i = i + 1
        end
    end
    for j = #result + 1, self.size do result[j] = 0 end
    return result, gained, slides, merges
end

function Board:lineCoords(dir, k)
    local coords, n = {}, self.size
    for i = 1, n do
        if dir == "left" then
            coords[i] = {k, i}
        elseif dir == "right" then
            coords[i] = {k, n - i + 1}
        elseif dir == "up" then
            coords[i] = {i, k}
        else
            coords[i] = {n - i + 1, k}
        end
    end
    return coords
end

function Board:canMove()
    for r = 1, self.size do
        for c = 1, self.size do
            local v = self.cells[r][c]
            if v == 0 then return true end
            if c < self.size and self.cells[r][c + 1] == v then return true end
            if r < self.size and self.cells[r + 1][c] == v then return true end
        end
    end
    return false
end

function Board:move(dir)
    if self.over then return false end
    local moved = false
    local events = {slides = {}, merges = {}, spawns = {}, gained = 0}
    for k = 1, self.size do
        local coords = self:lineCoords(dir, k)
        local line = {}
        for i = 1, self.size do
            line[i] = self.cells[coords[i][1]][coords[i][2]]
        end
        local newLine, gained, slides, merges = self:slideLine(line)
        self.score = self.score + gained
        events.gained = events.gained + gained
        for _, s in ipairs(slides) do
            local from, to = coords[s.from], coords[s.to]
            events.slides[#events.slides + 1] = {
                fromR = from[1], fromC = from[2], toR = to[1], toC = to[2], value = s.value,
            }
        end
        for _, m in ipairs(merges) do
            events.merges[#events.merges + 1] = {r = coords[m][1], c = coords[m][2]}
        end
        for i = 1, self.size do
            local r, c = coords[i][1], coords[i][2]
            if self.cells[r][c] ~= newLine[i] then moved = true end
            self.cells[r][c] = newLine[i]
        end
    end
    if moved then
        self.events = events
        self:spawn()
        if not self:canMove() then self.over = true end
    end
    return moved
end

return Board
