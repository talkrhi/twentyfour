local function hex(s)
    return {tonumber(s:sub(1, 2), 16) / 255, tonumber(s:sub(3, 4), 16) / 255, tonumber(s:sub(5, 6), 16) / 255}
end

local function list(values)
    local out = {}
    for i, v in ipairs(values) do out[i] = hex(v) end
    return out
end

local function theme(t)
    return {
        name = t.name,
        bg = hex(t.bg),
        hatch = hex(t.hatch),
        panel = hex(t.panel),
        line = hex(t.line),
        cell = hex(t.cell),
        ink = hex(t.ink),
        dark = hex(t.dark),
        light = hex(t.light),
        accents = list(t.accents),
        tiles = list(t.tiles),
        type = list(t.type),
        typeAlpha = t.typeAlpha,
    }
end

return {
    theme {
        name = "POSTER",
        bg = "15130f", hatch = "1f1c17", panel = "221e19", line = "ff7a1a", cell = "2d2822",
        ink = "f4ecdc", dark = "15130f", light = "fbf6ec",
        accents = {"ff6a13", "3fbf4f", "ff3d8b", "ffd23f"},
        tiles = {"efe6d2", "ffd23f", "ff9a1a", "ff6a13", "ff3d3d", "ff3d8b",
                 "b03dff", "3d8bff", "19c4c4", "3fbf4f", "9be23d", "ffffff"},
        type = {"ff6a13", "3fbf4f", "ff3d8b", "ffd23f", "3d8bff", "b03dff"},
        typeAlpha = 0.3,
    },
    theme {
        name = "SIGNAL",
        bg = "17171a", hatch = "202024", panel = "0d0d0f", line = "f2f2f2", cell = "1c1c20",
        ink = "f2f2f2", dark = "0d0d0f", light = "ffffff",
        accents = {"b6e34b", "ec4f9a", "c545e6", "1fc8f5"},
        tiles = {"2a2a30", "3b3b43", "1fc8f5", "0e9ccc", "c545e6", "9a28bf",
                 "ec4f9a", "c92b74", "b6e34b", "84b31f", "ffffff", "ffd84a"},
        type = {"1fc8f5", "ec4f9a", "c545e6", "b6e34b"},
        typeAlpha = 0.16,
    },
    theme {
        name = "NIGHTSHADE",
        bg = "1d0e22", hatch = "28152f", panel = "33283a", line = "45b8d8", cell = "2a2030",
        ink = "efe6f5", dark = "1d0e22", light = "fbf6ff",
        accents = {"c6e04d", "e541c4", "9b3fe8", "4f86f0"},
        tiles = {"4a3d52", "5f4c6b", "4f86f0", "3463c9", "9b3fe8", "7121c2",
                 "e541c4", "c0209f", "c6e04d", "9cbd2a", "fff38a", "ffffff"},
        type = {"c6e04d", "e541c4", "9b3fe8", "4f86f0"},
        typeAlpha = 0.2,
    },
    theme {
        name = "CONCRETE",
        bg = "c8c8c8", hatch = "bababa", panel = "dedede", line = "7a7a7a", cell = "cfcfcf",
        ink = "3c3c3c", dark = "2e2e2e", light = "ffffff",
        accents = {"c38a1c", "d6283a", "8c3ed4", "68779a"},
        tiles = {"f4f4f4", "e6e0d2", "e9b04e", "c38a1c", "f0604f", "d6283a",
                 "b24fdc", "8c3ed4", "68779a", "3f4d72", "262626", "000000"},
        type = {"c38a1c", "d6283a", "8c3ed4", "68779a"},
        typeAlpha = 0.2,
    },
}
