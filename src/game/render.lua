local Fonts = require("fonts")
local Themes = require("themes")

local Render = {}

local TILE, GAP = 100, 12

local SLIDE_TIME = 0.1
local POP_TIME = 0.2
local FADE_TIME = 0.9
local JUMP_TIME = 0.45
local FLOAT_TIME = 0.9
local OVER_DELAY = 0.35
local OVER_TIME = 0.6
local OUT_TIME = 0.45
local CAP = 0.716

-- You Win: the path of tiles 2 -> 2048, as moves from one tile to the next.
local PATH = {"r", "r", "u", "u", "r", "r", "u", "u", "r", "r"}
local HERO = 1.7
local WIN_BEAT = 0.07
local WIN_SLIDE = 0.55
local WIN_HOP = 0.085
local TRAVEL_START = 0.05 + #PATH * WIN_BEAT + 0.45

local MASK_SHADER = [[
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec4 px = Texel(tex, uv);
    if (px.a < 0.5) discard;
    return px * color;
}
]]

local BLUR_SHADER = [[
extern vec2 direction;
extern float saturation;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 d1 = direction * 1.3846153846;
    vec2 d2 = direction * 3.2307692308;
    vec4 sum = Texel(tex, uv) * 0.2270270270
        + (Texel(tex, uv + d1) + Texel(tex, uv - d1)) * 0.3162162162
        + (Texel(tex, uv + d2) + Texel(tex, uv - d2)) * 0.0702702703;
    float gray = dot(sum.rgb, vec3(0.2126, 0.7152, 0.0722));
    sum.rgb = mix(vec3(gray), sum.rgb, saturation);
    return sum * color;
}
]]

local themeIndex = 1
local theme = Themes[themeIndex]

local clock = 0
local anim = nil
local maxTile = 0
local shownScore = 0
local jump = {t = JUMP_TIME, height = 0}
local scoreFloats = {}
local words = {current = "", previous = "", t = FADE_TIME}
local screen = nil
local menuBoxes = {}
local blurShader, maskShader, canvases

local ONES = {"ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE", "TEN", "ELEVEN",
    "TWELVE", "THIRTEEN", "FOURTEEN", "FIFTEEN", "SIXTEEN", "SEVENTEEN", "EIGHTEEN", "NINETEEN"}
local TENS = {nil, "TWENTY", "THIRTY", "FORTY", "FIFTY", "SIXTY", "SEVENTY", "EIGHTY", "NINETY"}

local function below1000(n)
    local parts = {}
    if n >= 100 then
        parts[#parts + 1] = ONES[math.floor(n / 100)] .. " HUNDRED"
        n = n % 100
    end
    if n >= 20 then
        parts[#parts + 1] = TENS[math.floor(n / 10)] .. (n % 10 > 0 and " " .. ONES[n % 10] or "")
    elseif n > 0 then
        parts[#parts + 1] = ONES[n]
    end
    return table.concat(parts, " ")
end

local function numberWords(n)
    if n >= 1000 then
        local rest = n % 1000
        return below1000(math.floor(n / 1000)) .. " THOUSAND" .. (rest > 0 and " " .. below1000(rest) or "")
    end
    return below1000(n)
end

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

local function easeOutExpo(p)
    return p >= 1 and 1 or 1 - 2 ^ (-10 * p)
end

local function easeInCubic(p)
    return p ^ 3
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function cellKey(r, c)
    return r * 100 + c
end

local function setColor(c, a)
    love.graphics.setColor(c[1], c[2], c[3], a or 1)
end

local function luminance(c)
    return 0.2126 * c[1] + 0.7152 * c[2] + 0.0722 * c[3]
end

local function log2(v)
    return math.floor(math.log(v) / math.log(2) + 0.5)
end

local function tileColor(v)
    local ramp = theme.tiles
    return ramp[math.max(1, math.min(#ramp, log2(v)))]
end

local function inkFor(fill)
    return luminance(fill) > 0.6 and theme.dark or theme.light
end

local function capFont(cap)
    return Fonts.get(cap / CAP, true)
end

local function textWidth(text, cap)
    return capFont(100):getWidth(text) * cap / 100
end

local function drawText(text, cap, x, y)
    local font = capFont(cap)
    love.graphics.setFont(font)
    love.graphics.print(text, round(x), round(y - font:getBaseline() + cap))
    return font:getWidth(text)
end

local function fitCap(lines, maxW, maxH, maxCap, lead)
    local widest = 0
    for _, line in ipairs(lines) do widest = math.max(widest, textWidth(line, 1)) end
    return math.min(maxCap, maxW / widest, maxH / (#lines + (#lines - 1) * lead))
end

local function drawBlock(lines, cx, cy, cap, lead)
    local font = capFont(cap)
    love.graphics.setFont(font)
    local y = cy - cap * (#lines + (#lines - 1) * lead) / 2
    for _, line in ipairs(lines) do
        love.graphics.print(line, cx - font:getWidth(line) / 2, y - font:getBaseline() + cap)
        y = y + cap * (1 + lead)
    end
end

local function chamfer(x, y, w, h, c)
    return {x + c, y, x + w - c, y, x + w, y + c, x + w, y + h - c,
        x + w - c, y + h, x + c, y + h, x, y + h - c, x, y + c}
end

local function hatch(x, y, w, h, spacing, width)
    love.graphics.setLineWidth(width)
    for d = -h, w + spacing, spacing do
        love.graphics.line(x + d, y + h, x + d + h, y)
    end
end

local function clipTo(shape, draw)
    love.graphics.stencil(function() love.graphics.polygon("fill", shape) end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    draw()
    love.graphics.setStencilTest()
end

-- phase shifts the dash pattern along the outline (animate it for marching dashes);
-- open draws a polyline instead of a closed loop.
local function dashedPolygon(pts, pattern, phase, open)
    local n = #pts / 2
    local k, remaining = 1, pattern[1]
    if phase then
        local total = 0
        for _, v in ipairs(pattern) do total = total + v end
        local d = phase % total
        while d >= remaining do
            d = d - remaining
            k = k % #pattern + 1
            remaining = pattern[k]
        end
        remaining = remaining - d
    end
    for i = 1, open and n - 1 or n do
        local j = i % n + 1
        local x1, y1, x2, y2 = pts[2 * i - 1], pts[2 * i], pts[2 * j - 1], pts[2 * j]
        local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        local s = 0
        while len - s > 1e-6 do
            local step = math.min(remaining, len - s)
            if k % 2 == 1 then
                local e = s + step
                love.graphics.line(x1 + (x2 - x1) * s / len, y1 + (y2 - y1) * s / len,
                    x1 + (x2 - x1) * e / len, y1 + (y2 - y1) * e / len)
            end
            s = s + step
            remaining = remaining - step
            if remaining <= 1e-6 then
                k = k % #pattern + 1
                remaining = pattern[k]
            end
        end
    end
end

function Render.resize()
    Fonts.clear()
end

function Render.nextTheme()
    themeIndex = themeIndex % #Themes + 1
    theme = Themes[themeIndex]
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
end

function Render.update(dt)
    clock = clock + dt
    if anim then
        anim.t = anim.t + dt
        if anim.t >= anim.slideTime + POP_TIME then anim = nil end
    end
    jump.t = jump.t + dt
    for i = #scoreFloats, 1, -1 do
        local float = scoreFloats[i]
        float.t = float.t + dt
        if float.t >= FLOAT_TIME then table.remove(scoreFloats, i) end
    end
    words.t = words.t + dt
    if screen then
        screen.t = screen.t + dt
        if screen.out then
            screen.out = screen.out + dt
            if screen.out >= OUT_TIME then screen = nil end
        end
    end
end

-- kind is "over", "win" or nil. Leaving a screen plays its outro before it disappears.
local function trackScreen(kind)
    if kind then
        if not screen or screen.kind ~= kind or screen.out then
            screen = {kind = kind, t = -OVER_DELAY}
            menuBoxes = {}
        end
    elseif screen and not screen.out then
        screen.out = 0
        menuBoxes = {}
    end
end

-- p: how far the board has receded (0 = playing, 1 = fully behind the screen).
-- k: 1 while the screen is up, falling to 0 during the outro.
local function screenProgress()
    if not screen then return 0, 1 end
    local k = screen.out and 1 - easeInCubic(clamp01(screen.out / OUT_TIME)) or 1
    return easeOutCubic(clamp01(screen.t / OVER_TIME)) * k, k
end

local function trackScore(score)
    if score == shownScore then return end
    local gain = score - shownScore
    shownScore = score
    if gain > 0 then
        scoreFloats[#scoreFloats + 1] = {text = "+" .. gain, t = 0}
        jump = {t = 0, height = 0.25 + 0.35 * clamp01(log2(gain) / 11)}
    else
        jump = {t = 0, height = 0.12}
    end
end

local function trackBoard(board)
    local top = 0
    for r = 1, board.size do
        for c = 1, board.size do top = math.max(top, board.cells[r][c]) end
    end
    if top ~= maxTile then
        maxTile = top
        words.previous, words.current, words.t = words.current, numberWords(top), 0
    end
end

local function layout(board)
    local W, H = love.graphics.getDimensions()
    local m = math.min(W, H) * 0.04
    local label = math.max(9, math.min(18, H * 0.018))
    local value = math.max(18, math.min(52, H * 0.05))
    local floatCap = label * 1.5
    local hudH = label * 1.8 + value
    local hudW = textWidth("00000", value) + label + textWidth("+0000", floatCap)

    local side = math.min(W, H) - 2 * m
    local bottom = H - m
    if (W - side) / 2 - m < hudW then
        bottom = H - m - hudH - m * 0.6
        side = math.min(W - 2 * m, bottom - m)
    end
    side = math.max(60, side)
    local scale = side / (board.size * TILE + (board.size + 1) * GAP)
    return {
        W = W, H = H, m = m,
        label = label, value = value, floatCap = floatCap,
        side = side,
        x = round((W - side) / 2),
        y = round(m + (bottom - m - side) / 2),
        tile = TILE * scale,
        gap = GAP * scale,
    }
end

local function drawTypeRows(L, text, alpha)
    if text == "" or alpha <= 0.001 then return end
    local cap = L.H / 4.6
    local font = capFont(cap)
    love.graphics.setFont(font)
    local line = text .. "   "
    local adv = font:getWidth(line)
    local step = cap * 1.16
    local shift = cap - font:getBaseline()
    for row = 0, math.ceil(L.H / step) do
        local y = row * step - cap * 0.3 + shift
        local dir = row % 2 == 0 and 1 or -1
        for layer = 0, 1 do
            local speed = dir * cap * (0.12 + layer * 0.05)
            local offset = (clock * speed + (row * 0.37 + layer * 0.21) * adv) % adv
            setColor(theme.type[(row * 2 + layer) % #theme.type + 1], alpha)
            local x = offset - adv
            while x < L.W do
                love.graphics.print(line, x, y + layer * cap * 0.07)
                x = x + adv
            end
        end
    end
end

local function drawBackground(L, fade)
    setColor(theme.bg)
    love.graphics.rectangle("fill", 0, 0, L.W, L.H)
    if fade <= 0.001 then return end
    local spacing = math.max(6, math.min(L.W, L.H) * 0.012)
    setColor(theme.hatch, fade)
    hatch(0, 0, L.W, L.H, spacing, spacing * 0.32)
    local p = clamp01(words.t / FADE_TIME)
    drawTypeRows(L, words.previous, theme.typeAlpha * (1 - p) * fade)
    drawTypeRows(L, words.current, theme.typeAlpha * p * fade)
end

local function cellPosition(L, r, c)
    return L.x + L.gap + (c - 1) * (L.tile + L.gap), L.y + L.gap + (r - 1) * (L.tile + L.gap)
end

local function digitLines(v)
    local s = tostring(v)
    if #s >= 4 then
        local split = math.ceil(#s / 2)
        return {s:sub(1, split), s:sub(split + 1)}
    end
    return {s}
end

local function drawTile(v, x, y, L, scale, shake)
    scale = scale or 1
    if scale <= 0.01 then return end
    local t = L.tile
    local half = t / 2
    love.graphics.push()
    love.graphics.translate(x + half, y + half)
    love.graphics.scale(scale)
    local shape = chamfer(-half, -half, t, t, t * 0.14)
    if v == 0 then
        setColor(theme.cell)
        love.graphics.polygon("fill", shape)
        love.graphics.pop()
        return
    end

    local fill = tileColor(v)
    local ink = inkFor(fill)
    setColor(fill)
    love.graphics.polygon("fill", shape)
    if v >= 128 then
        clipTo(shape, function()
            setColor(ink, 0.12)
            hatch(-half, -half, t, t, t * 0.08, t * 0.025)
        end)
    end

    local lines = digitLines(v)
    local lead = 0.25
    local cap = fitCap(lines, t * 0.72, t * 0.66, t * 0.46, lead)
    local o = t * (0.03 + 0.06 * (shake or 0))
    setColor(tileColor(v * 4), 0.9)
    drawBlock(lines, o, o * 0.8, cap, lead)
    setColor(ink)
    drawBlock(lines, 0, 0, cap, lead)
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
                local scale, shake = 1, 0
                if anim and anim.spawned[cellKey(r, c)] then
                    scale = easeOutBack(p)
                elseif anim and anim.merged[cellKey(r, c)] then
                    shake = math.sin(math.pi * p)
                    scale = 1 + 0.2 * shake
                end
                local x, y = cellPosition(L, r, c)
                drawTile(v, x, y, L, scale, shake)
            end
        end
    end
end

local function drawBoard(board, L)
    local c = L.side * 0.05
    local o = L.side * 0.016
    setColor(theme.panel)
    love.graphics.polygon("fill", chamfer(L.x, L.y, L.side, L.side, c))
    setColor(theme.line)
    love.graphics.setLineWidth(math.max(1.2, L.side * 0.0045))
    dashedPolygon(chamfer(L.x - o, L.y - o, L.side + 2 * o, L.side + 2 * o, c + o * 0.586),
        {L.side * 0.2, L.side * 0.014, L.side * 0.035, L.side * 0.014})

    for r = 1, board.size do
        for col = 1, board.size do
            local x, y = cellPosition(L, r, col)
            drawTile(0, x, y, L)
        end
    end
    if anim and anim.t < anim.slideTime then
        drawSlidingTiles(L)
    else
        drawSettledTiles(board, L)
    end
end

local function drawValue(text, cap, x, y, accent, alpha)
    local o = cap * 0.07
    setColor(accent, 0.8 * alpha)
    drawText(text, cap, x + o, y + o)
    setColor(theme.ink, alpha)
    drawText(text, cap, x, y)
end

local function jumpPose(p, height)
    if p < 0.75 then
        local q = p / 0.75
        return height * 4 * q * (1 - q), 1 + 0.15 * math.sin(math.pi * q)
    end
    local q = (p - 0.75) / 0.25
    return height * 0.18 * 4 * q * (1 - q), 1
end

local function drawScore(L, alpha)
    local x, valueY = L.m, L.H - L.m - L.value
    local accent = theme.accents[1]
    local text = tostring(shownScore)
    local lift, pop = jumpPose(clamp01(jump.t / JUMP_TIME), jump.height)
    lift = lift * L.value

    setColor(accent, alpha)
    drawText("SCORE", L.label, x, valueY - L.label * 1.8 - lift)
    love.graphics.push()
    love.graphics.translate(x, valueY + L.value - lift)
    love.graphics.scale(pop)
    drawValue(text, L.value, 0, -L.value, accent, alpha)
    love.graphics.pop()

    local floatX = x + capFont(L.value):getWidth(text) * 1.15 + L.label * 0.6
    for _, float in ipairs(scoreFloats) do
        local p = float.t / FLOAT_TIME
        local y = valueY + (L.value - L.floatCap) / 2 - L.value * 1.1 * easeOutCubic(p)
        setColor(accent, (1 - p * p) * alpha)
        drawText(float.text, L.floatCap, floatX, y)
    end
end

local function drawBest(best, L, alpha)
    local right, valueY = L.W - L.m, L.H - L.m - L.value
    setColor(theme.accents[2], alpha)
    drawText("BEST", L.label, right - capFont(L.label):getWidth("BEST"), valueY - L.label * 1.8)
    local text = tostring(best)
    drawValue(text, L.value, right - capFont(L.value):getWidth(text), valueY, theme.accents[2], alpha)
end

local function blurTargets(W, H)
    if not canvases or canvases.w ~= W or canvases.h ~= H then
        local msaa = math.min(4, love.graphics.getSystemLimits().canvasmsaa or 0)
        canvases = {
            w = W, h = H,
            board = love.graphics.newCanvas(W, H, {msaa = msaa}),
            ping = love.graphics.newCanvas(W, H),
            pong = love.graphics.newCanvas(W, H),
        }
    end
    blurShader = blurShader or love.graphics.newShader(BLUR_SHADER)
    return canvases
end

local function shaderPass(src, dst, dx, dy, saturation)
    love.graphics.setCanvas(dst)
    love.graphics.clear(0, 0, 0, 0)
    blurShader:send("direction", {dx, dy})
    blurShader:send("saturation", saturation)
    love.graphics.draw(src)
end

-- Shrinks the board into target (a centre point and side) while blurring, desaturating and dimming it.
local function drawBlurredBoard(board, L, p, target)
    local c = blurTargets(L.W, L.H)
    local side = lerp(L.side, target.side, p)
    local x = lerp(L.x, target.cx - target.side / 2, p)
    local y = lerp(L.y, target.cy - target.side / 2, p)

    love.graphics.push("all")
    love.graphics.setCanvas({c.board, stencil = true})
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.translate(x, y)
    love.graphics.scale(side / L.side)
    love.graphics.translate(-L.x, -L.y)
    drawBoard(board, L)

    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.setShader(blurShader)
    local spread = L.H * 0.0036 * p
    local src = c.board
    for _, f in ipairs({1, 0.5, 0.25}) do
        shaderPass(src, c.ping, spread * f / L.W, 0, 1)
        shaderPass(c.ping, c.pong, 0, spread * f / L.H, 1)
        src = c.pong
    end

    love.graphics.setCanvas()
    blurShader:send("direction", {0, 0})
    blurShader:send("saturation", lerp(1, target.saturation, p))
    local a = lerp(1, target.alpha, p)
    love.graphics.setColor(a, a, a, a)
    love.graphics.draw(src)
    love.graphics.pop()
end

local function drawLine(text, font, x, baseline, color, alpha)
    love.graphics.setFont(font)
    setColor(color, alpha)
    love.graphics.print(text, round(x), round(baseline - font:getBaseline()))
end

-- The left-hand column both end screens share: title, summary and menu.
-- enter(delay) returns the alpha and x/y offset of an element that starts appearing at delay.
local function drawEndText(L, title, summary, menu, titleBaseline, right, enter)
    local x = round(math.max(L.m, L.W * 0.12))
    local titleSize = math.max(26, L.H * 0.055)
    local bodySize = math.max(12, L.H * 0.0165)
    local titleFont, bodyFont = Fonts.mono(titleSize), Fonts.mono(bodySize)
    local lineH = bodyFont:getHeight() * 1.35
    local spacing = bodySize * 3.1

    local a, dx, dy = enter(0)
    drawLine(title, titleFont, x + dx, titleBaseline + dy, theme.ink, a)

    local _, lines = bodyFont:getWrap(summary, right - x)
    a, dx, dy = enter(0.08)
    local subBaseline = titleBaseline + titleSize * 0.7 + bodySize * 0.75
    for i, line in ipairs(lines) do
        drawLine(line, bodyFont, x + dx, subBaseline + (i - 1) * lineH + dy, theme.ink, 0.78 * a)
    end

    local top = subBaseline + (#lines - 1) * lineH + bodySize * 6.2
    for i, item in ipairs(menu.items) do
        local baseline = top + (i - 1) * spacing
        local selected = i == menu.selected
        a, dx, dy = enter(0.14 + 0.05 * i)
        drawLine(item, bodyFont, x + dx, baseline + dy, theme.ink, (selected and 1 or 0.6) * a)
        if selected then
            drawLine(">", bodyFont, x + dx - bodyFont:getWidth("> "), baseline + dy, theme.accents[1], a)
        end
        menuBoxes[i] = {
            x = x - spacing * 0.5, y = baseline - spacing * 0.65,
            w = bodyFont:getWidth(item) + spacing, h = spacing,
        }
    end
end

local function drawGameOver(menu, L, k)
    local rise = L.H * 0.012
    local summary = "The board locked up at " .. screen.score .. " points"
        .. (screen.newBest and ", a new best" or "") .. ". Your biggest tile was " .. screen.top .. "."
    drawEndText(L, "Game Over", summary, menu, L.H * 0.397, L.W - L.m, function(delay)
        local a = easeOutCubic(clamp01((screen.t - delay) / 0.45))
        return a * k, 0, rise * (1 - a)
    end)
end

-- Lays the path out as a staircase inside the free side of the screen: right of the text in
-- landscape, below it in portrait. Positions are tile centres; the last tile is the 2048 hero.
local function winLayout(L)
    local landscape = L.W >= L.H * 1.15
    local rx, ry, rw, rh
    if landscape then
        rx, ry, rw, rh = L.W * 0.5, L.H * 0.14, L.W * 0.44, L.H * 0.72
    else
        rx, ry, rw, rh = L.W * 0.08, L.H * 0.64, L.W * 0.84, L.H * 0.32
    end

    local pts, x, y = {{0, 0}}, 0, 0
    for i, move in ipairs(PATH) do
        local step = i == #PATH and 1.65 + (HERO - 1) / 2 or 1.3
        if move == "r" then x = x + step else y = y - step end
        pts[#pts + 1] = {x, y}
    end
    local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
    for i, pt in ipairs(pts) do
        local h = (i == #pts and HERO or 1) / 2
        minX, maxX = math.min(minX, pt[1] - h), math.max(maxX, pt[1] + h)
        minY, maxY = math.min(minY, pt[2] - h), math.max(maxY, pt[2] + h)
    end

    local s = math.min(rw / (maxX - minX), rh / (maxY - minY)) * 0.88
    local ox, oy = rx + rw / 2 - (minX + maxX) / 2 * s, ry + rh / 2 - (minY + maxY) / 2 * s
    local tiles = {}
    for i, pt in ipairs(pts) do
        tiles[i] = {
            x = ox + pt[1] * s, y = oy + pt[2] * s,
            size = (i == #pts and HERO or 1) * s,
            value = math.floor(2 ^ i + 0.5),
        }
    end
    return {
        landscape = landscape, s = s, tiles = tiles,
        titleBaseline = landscape and L.H * 0.397 or L.H * 0.28,
        textRight = landscape and rx - L.m or L.W - L.m,
    }
end

-- A huge numeral filled with the background hatch, bleeding off the bottom-right corner.
local function drawGiantNumber(L, text, alpha, shift)
    if alpha <= 0.001 then return end
    maskShader = maskShader or love.graphics.newShader(MASK_SHADER)
    local cap = 140
    local font = capFont(cap)
    local scale = L.H * 0.42 / cap
    local w, h = font:getWidth(text) * scale, cap * scale
    local x, y = L.W - w * 0.94 + shift, L.H - h * 0.82
    love.graphics.stencil(function()
        love.graphics.setShader(maskShader)
        love.graphics.setFont(font)
        love.graphics.print(text, x, y - (font:getBaseline() - cap) * scale, 0, scale, scale)
        love.graphics.setShader()
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    local spacing = math.max(6, math.min(L.W, L.H) * 0.012)
    setColor(theme.ink, 0.08 * alpha)
    hatch(x - spacing * 2 + (clock * spacing * 0.6) % spacing, y - spacing, w + spacing * 4, h + spacing * 2,
        spacing, spacing * 0.4)
    love.graphics.setStencilTest()
end

-- The tiles slide in one beat apart, then a dashed cursor hops along them to the hero tile,
-- which lands with a pop and two shockwaves.
local function drawPath(L, W, k)
    local t, tiles = screen.t, W.tiles
    local n = #tiles
    local heroArrive = TRAVEL_START + (n - 1) * WIN_HOP
    local exit = (1 - k) * L.W * 1.2

    local pos = {}
    for i, tile in ipairs(tiles) do
        local e = easeOutExpo(clamp01((t - 0.05 - (i - 1) * WIN_BEAT) / WIN_SLIDE))
        local bob = (i == n and t > heroArrive) and math.sin((t - heroArrive) * 2.2) * W.s * 0.06 or 0
        pos[i] = {x = tile.x + (1 - e) * (L.W + tile.size - tile.x) + exit, y = tile.y + bob, live = e > 0}
    end

    local line = {}
    for i = 1, n do
        if pos[i].live then
            line[#line + 1] = pos[i].x
            line[#line + 1] = pos[i].y
        end
    end
    if #line >= 4 then
        setColor(theme.line, 0.7 * k)
        love.graphics.setLineWidth(math.max(1.2, W.s * 0.035))
        dashedPolygon(line, {W.s * 0.22, W.s * 0.14}, -clock * W.s * 1.2, true)
    end

    for i, tile in ipairs(tiles) do
        if pos[i].live then
            local q = (t - TRAVEL_START - (i - 1) * WIN_HOP) / (i == n and 0.4 or 0.25)
            local bump = (q >= 0 and q <= 1) and math.sin(math.pi * q) or 0
            local scale = 1 + (i == n and 0.3 or 0.16) * bump
            drawTile(tile.value, pos[i].x - tile.size / 2, pos[i].y - tile.size / 2, {tile = tile.size}, scale, bump)
        end
    end

    local hero = pos[n]
    for w = 0, 1 do
        local q = (t - heroArrive - w * 0.12) / 0.8
        if q > 0 and q < 1 then
            local size = tiles[n].size * (1.1 + 2.2 * easeOutCubic(q))
            setColor(theme.accents[w == 0 and 1 or 3], (1 - q) ^ 2 * k)
            love.graphics.setLineWidth(math.max(1, W.s * 0.08 * (1 - q)))
            love.graphics.polygon("line", chamfer(hero.x - size / 2, hero.y - size / 2, size, size, size * 0.14))
        end
    end

    if t >= TRAVEL_START then
        local f = (t - TRAVEL_START) / WIN_HOP
        local i = math.floor(f) + 1
        local x, y, size = hero.x, hero.y, tiles[n].size
        if i < n then
            local q = easeOutCubic(f - (i - 1))
            x, y = lerp(pos[i].x, pos[i + 1].x, q), lerp(pos[i].y, pos[i + 1].y, q)
            size = lerp(tiles[i].size, tiles[i + 1].size, q)
        end
        local r = size * 1.3
        setColor(theme.ink, clamp01((t - TRAVEL_START) / 0.15) * k)
        love.graphics.setLineWidth(math.max(1.5, W.s * 0.045))
        dashedPolygon(chamfer(x - r / 2, y - r / 2, r, r, r * 0.16), {r * 0.2, r * 0.07}, clock * r * 0.25)
    end
end

local function drawWin(menu, L, W, k)
    local slide = L.W * 0.18
    local summary = "You reached " .. screen.top .. " with " .. screen.score .. " points"
        .. (screen.newBest and ", a new best" or "") .. ". Keep going, or start fresh."
    drawEndText(L, "You Win", summary, menu, W.titleBaseline, W.textRight, function(delay)
        local e = easeOutExpo(clamp01((screen.t - 0.25 - delay) / 0.6))
        return e * k, -(1 - e) * slide - (1 - k) * slide, 0
    end)
end

function Render.menuItemAt(x, y)
    if not screen or screen.out or screen.t < 0 then return nil end
    for i, b in ipairs(menuBoxes) do
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then return i end
    end
end

function Render.draw(board, best, showWin, menu)
    trackBoard(board)
    trackScore(board.score)
    local L = layout(board)
    local kind
    if not anim then
        if showWin then kind = "win" elseif board.over then kind = "over" end
    end
    trackScreen(kind)
    if screen and not screen.out then
        screen.score, screen.top, screen.newBest = board.score, maxTile, menu.newBest
    end
    local p, k = screenProgress()
    local W = screen and screen.kind == "win" and winLayout(L)

    drawBackground(L, 1 - p)
    if W then
        local g = easeOutExpo(clamp01(screen.t / 1.4))
        drawGiantNumber(L, tostring(screen.top), g * k, (1 - g) * L.W * 0.5 + (1 - k) * L.W * 0.3)
    end
    if p > 0 then
        local target
        if W then
            local hero = W.tiles[#W.tiles]
            target = {cx = hero.x, cy = hero.y, side = hero.size * 2.5, alpha = 0.35, saturation = 0.35}
        else
            target = {cx = L.W / 2, cy = L.H * 0.47, side = math.min(L.H * 0.3, L.W * 0.6),
                alpha = 0.4, saturation = 0.25}
        end
        drawBlurredBoard(board, L, p, target)
    else
        drawBoard(board, L)
    end
    if p < 1 then
        drawScore(L, 1 - p)
        drawBest(best, L, 1 - p)
    end
    if screen and screen.t >= 0 then
        if W then
            drawPath(L, W, k)
            drawWin(menu, L, W, k)
        else
            drawGameOver(menu, L, k)
        end
    end
end

return Render
