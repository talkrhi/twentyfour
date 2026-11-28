local Fonts = {}

local PATHS = {
    regular = {
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial.ttf",
        "C:/Windows/Fonts/arial.ttf",
        "/usr/share/fonts/truetype/msttcorefonts/Arial.ttf",
    },
    bold = {
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/Library/Fonts/Arial Bold.ttf",
        "C:/Windows/Fonts/arialbd.ttf",
        "/usr/share/fonts/truetype/msttcorefonts/Arial_Bold.ttf",
    },
    mono = {
        "/System/Applications/Utilities/Terminal.app/Contents/Resources/Fonts/SF-Mono-Regular.otf",
        "/System/Library/Fonts/SFNSMono.ttf",
        "/System/Library/Fonts/Menlo.ttc",
        "C:/Windows/Fonts/consola.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
    },
}

local data = {}
local cache = {}

local function load(weight)
    if data[weight] == nil then
        data[weight] = false
        for _, path in ipairs(PATHS[weight]) do
            local file = io.open(path, "rb")
            if file then
                data[weight] = love.filesystem.newFileData(file:read("*a"), path:match("[^/]+$"))
                file:close()
                break
            end
        end
    end
    return data[weight]
end

local function get(size, weight)
    size = math.max(6, math.floor(size + 0.5))
    local key = weight .. size
    if not cache[key] then
        local fileData = load(weight)
        cache[key] = fileData and love.graphics.newFont(fileData, size) or love.graphics.newFont(size)
    end
    return cache[key]
end

function Fonts.get(size, bold)
    return get(size, bold and "bold" or "regular")
end

function Fonts.mono(size)
    return get(size, "mono")
end

function Fonts.clear()
    cache = {}
end

return Fonts
