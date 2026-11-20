function love.conf(t)
    t.window.title = "2048 but in lua :D"
    -- grid is 4 * 100 (tiles) + 5 * 12 (gaps) = 460 wide, plus 90px header
    t.window.width = 460
    t.window.height = 550
end
