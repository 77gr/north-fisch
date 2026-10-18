if _G.NorthFisch and _G.NorthFisch.unload then pcall(_G.NorthFisch.unload) end

do
    local FISCH_PLACE, FISCH_GAME = 16732694052, 5750914919
    local function ids()
        local okP, pid = pcall(function() return game.PlaceId end)
        local okG, gid = pcall(function() return game.GameId end)
        return (okP and type(pid) == "number") and pid or 0, (okG and type(gid) == "number") and gid or 0
    end
    local function lp()
        local ok, p = pcall(function() return game:GetService("Players").LocalPlayer end)
        return ok and p or nil
    end
    local started = tick()
    local pid, gid = ids()
    while (not lp() or (pid == 0 and gid == 0)) and tick() - started < 120 do
        wait(0.5)
        pid, gid = ids()
    end
    if not lp() then notify("No se encontro tu jugador, vuelve a cargar", "NORTH FISCH", 4); return end
    if (pid ~= 0 or gid ~= 0) and pid ~= FISCH_PLACE and gid ~= FISCH_GAME then
        notify("Este juego no es Fisch", "NORTH FISCH", 4)
        return
    end
end

local S = {}
local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local UIS         = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Lighting    = nil
pcall(function() Lighting = game:GetService("Lighting") end)

local PATH = {
    shakeGui     = "shakeui",
    shakeButton  = { "safezone", "button" },
    reelGui      = "reel",
    reelFish     = { "bar", "fish" },
    reelPlayer   = { "bar", "playerbar" },
    reelProgress = { "bar", "progress", "bar" },
}

S.VERSION = "v7.0"
S.CONFIG = "north_fisch.cfg"
S.WEBHOOK_FILE = "north_fisch_webhook.txt"

S.running = true
local connections = {}
local allDrawings = {}
local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end

local function rawSet(o, k, v) o[k] = v end

local function probe(kind, value, ...)
    local ok, o = pcall(Drawing.new, kind)
    if not ok or not o then return nil end
    local found
    for i = 1, select("#", ...) do
        local name = select(i, ...)
        if pcall(rawSet, o, name, value) then found = name; break end
    end
    pcall(function() o:Remove() end)
    return found
end

local PN = {
    fontsize = probe("Text",   13,   "FontSize", "TextSize", "Size"),
    center   = probe("Text",   true, "Center"),
    corner   = probe("Square", 4,    "Corner", "Rounding"),
    filled   = probe("Square", true, "Filled"),
    thick    = probe("Square", 1,    "Thickness"),
}

local cache = {}

local function P(o, k, v)
    if not o or not k then return end
    local c = cache[o]
    if not c or c[k] == v then return end
    c[k] = v
    pcall(rawSet, o, k, v)
end
local function Vis(o, v) P(o, "Visible", v) end

local function Pos(o, x, y)
    if not o then return end
    x, y = floor(x), floor(y)
    local c = cache[o]
    if not c or (c._x == x and c._y == y) then return end
    c._x, c._y = x, y
    pcall(rawSet, o, "Position", Vector2.new(x, y))
end

local function Size(o, w, h)
    if not o then return end
    w, h = floor(w), floor(h)
    local c = cache[o]
    if not c or (c._w == w and c._h == h) then return end
    c._w, c._h = w, h
    pcall(rawSet, o, "Size", Vector2.new(w, h))
end

local function LineTo(o, x1, y1, x2, y2)
    if not o then return end
    x1, y1, x2, y2 = floor(x1), floor(y1), floor(x2), floor(y2)
    local c = cache[o]
    if not c then return end
    if c._a ~= x1 or c._b ~= y1 then c._a, c._b = x1, y1; pcall(rawSet, o, "From", Vector2.new(x1, y1)) end
    if c._c ~= x2 or c._d ~= y2 then c._c, c._d = x2, y2; pcall(rawSet, o, "To", Vector2.new(x2, y2)) end
end

local function new(kind)
    local ok, o = pcall(Drawing.new, kind)
    if not ok or not o then return nil end
    cache[o] = {}
    allDrawings[#allDrawings + 1] = o
    return o
end

local function Box(z, color, corner, alpha)
    local s = new("Square")
    Vis(s, false); P(s, "ZIndex", z); P(s, PN.filled, true)
    P(s, "Transparency", alpha or 1); P(s, "Color", color)
    if corner and corner > 0 then P(s, PN.corner, corner) end
    return s
end

local function Outline(z, color, corner)
    local s = new("Square")
    Vis(s, false); P(s, "ZIndex", z); P(s, PN.filled, false)
    P(s, PN.thick, 1); P(s, "Transparency", 1); P(s, "Color", color)
    if corner and corner > 0 then P(s, PN.corner, corner) end
    return s
end

local function Txt(size, color, z, centered, mono)
    local t = new("Text")
    Vis(t, false); P(t, "Font", mono and 3 or 2); P(t, "Outline", false)
    P(t, PN.center, centered == true); P(t, PN.fontsize, size)
    P(t, "Color", color); P(t, "ZIndex", z)
    return t
end

local function Ln(z, color, thick)
    local l = new("Line")
    Vis(l, false); P(l, "ZIndex", z); P(l, "Color", color)
    P(l, "Thickness", thick or 1); P(l, "Transparency", 1)
    return l
end

local function textW(s, size, mono) return floor(#s * size * (mono and 0.6 or 0.52)) end

local function wrap(s, n)
    local lines, cur = {}, ""
    for word in s:gmatch("%S+") do
        if cur == "" then cur = word
        elseif #cur + 1 + #word <= n then cur = cur .. " " .. word
        else lines[#lines + 1] = cur; cur = word end
    end
    if cur ~= "" then lines[#lines + 1] = cur end
    return lines
end

local function clipStr(s, n) if #s > n then return s:sub(1, n - 2) .. ".." end return s end

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local C = {
    shadow  = rgb(0, 0, 0),
    bg      = rgb(10, 10, 11),
    side    = rgb(12, 12, 13),
    line    = rgb(32, 32, 35),
    line2   = rgb(48, 48, 52),
    hover   = rgb(20, 20, 22),
    sel     = rgb(24, 24, 26),
    field   = rgb(15, 15, 17),
    text    = rgb(236, 236, 238),
    dim     = rgb(136, 136, 142),
    faint   = rgb(90, 90, 96),
    white   = rgb(245, 245, 247),
    black   = rgb(10, 10, 11),
    risk    = rgb(229, 72, 77),
    riskDim = rgb(44, 18, 20),
    good    = rgb(120, 220, 150),
}

S.MOUSE_OFFSET_X, S.MOUSE_OFFSET_Y = 0, 0

local function readMouseUIS() return UIS:GetMouseLocation() end
S.mouseObj = nil
do
    local ok, p = pcall(readMouseUIS)
    if not (ok and typeof(p) == "Vector2") then
        local ok2, m = pcall(function() return LocalPlayer:GetMouse() end)
        if ok2 then S.mouseObj = m end
    end
end
local function getMouse()
    if S.mouseObj then return S.mouseObj.X + S.MOUSE_OFFSET_X, S.mouseObj.Y + S.MOUSE_OFFSET_Y end
    local ok, p = pcall(readMouseUIS)
    if ok and p then return p.X + S.MOUSE_OFFSET_X, p.Y + S.MOUSE_OFFSET_Y end
    return -9999, -9999
end

local function inRect(px, py, r)
    return r ~= nil and px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

local function findPath(root, names)
    for i = 1, #names do
        if not root then return nil end
        root = root:FindFirstChild(names[i])
    end
    return root
end

S.hrpCache, S.rodCache, S.charTime = nil, nil, -10
local function refreshChar(now)
    if now - S.charTime < 0.5 and S.hrpCache then return end
    S.charTime = now
    local char = LocalPlayer and LocalPlayer.Character
    S.hrpCache = char and char:FindFirstChild("HumanoidRootPart") or nil
    S.rodCache = nil
    if char then
        local ok, kids = pcall(function() return char:GetChildren() end)
        if ok then
            for _, c in ipairs(kids) do
                local okT, isTool = pcall(function() return c:IsA("Tool") end)
                if okT and isTool then S.rodCache = c.Name; break end
            end
        end
    end
end
local function getHRP(now) refreshChar(now or tick()); return S.hrpCache end

S.vpX, S.vpY, S.vpTime = 1920, 1080, -10
local function getViewport(now)
    if now - S.vpTime > 2 then
        S.vpTime = now
        local ok, vp = pcall(function() return workspace.CurrentCamera.ViewportSize end)
        if ok and vp and vp.X > 0 then S.vpX, S.vpY = vp.X, vp.Y end
    end
    return S.vpX, S.vpY
end

local function rbxActive()
    local ok, a = pcall(isrbxactive)
    return (not ok) or a == true
end

local function fmtTime(s)
    s = floor(s)
    return string.format("%02d:%02d:%02d", floor(s / 3600), floor(s / 60) % 60, s % 60)
end

S.nightCache, S.nightTime = false, -10
local function isNight(now)
    now = now or tick()
    if now - S.nightTime > 1 then
        S.nightTime = now
        local ok, t = pcall(function() return Lighting.ClockTime end)
        if ok and type(t) == "number" then S.nightCache = (t < 6 or t >= 18) end
    end
    return S.nightCache
end

local KEYNAMES = {
    [0x20] = "space", [0x09] = "tab", [0x10] = "shift", [0x11] = "ctrl", [0x12] = "alt",
    [0xA0] = "lshift", [0xA1] = "rshift", [0xA2] = "lctrl", [0xA3] = "rctrl",
    [0x2D] = "ins", [0x2E] = "del", [0x24] = "home", [0x23] = "end",
    [0x21] = "pgup", [0x22] = "pgdn", [0xC0] = "`", [0x14] = "caps",
}
local function keyName(vk)
    if not vk then return "-" end
    if vk >= 0x70 and vk <= 0x87 then return "F" .. (vk - 0x6F) end
    if (vk >= 0x30 and vk <= 0x39) or (vk >= 0x41 and vk <= 0x5A) then return string.char(vk) end
    return KEYNAMES[vk] or string.format("%02X", vk)
end

local function playerNames()
    local d, n = "jugador", "jugador"
    pcall(function() d = LocalPlayer.DisplayName end)
    pcall(function() n = LocalPlayer.Name end)
    return tostring(d), tostring(n)
end

local V = {
    auto_fish = false, instant = false, legit = true, auto_shake = true, auto_cast = true,
    reel_mode = "normal", cast_hold = 1.0, instant_delay = 2.0,
    return_spot = false, fish_spot = "",
    hud = true, hud_bar = true, keys_panel = true,
    auto_totem = false, totem_plan = "aurora", totem_every = 15,
    slot_rod = "1", slot_sundial = "ninguno", slot_aurora = "ninguno",
    region = "todo", dest = "", coords = "", npc = "", rod = "", totem_shop = "Aurora Totem", ex_item = "",
    wide_bar = false, bar_width = 50,
    gc_keys = "Progress,progress,FishProgress,CatchProgress,ReelProgress,reelProgress",
    gc_max = "MaxProgress", gc_fallback = 100,
    markers = true, tp_on_select = false,
    anti_afk = true, afk_minutes = 2,
    discord = false, discord_minutes = 10,
    gui_inset = "auto",
}
local KEYS = { menu = 0x50, fish = 0x70, catch = 0x71, tp = 0x72 }

local spots = {}

local F = {
    state = "IDLE", t = 0, holding = false,
    catches = 0, losses = 0, failures = 0, startTime = tick(),
    maxProg = 0, curProg = 0, lastBc = nil, lastBcT = 0,
    shakeMoveT = 0, shakeClickT = 0, shakeX = -1, shakeY = -1,
    gcStep = 0, statusText = "apagado", lastReturn = 0,
}
local T = {
    busy = false, step = 0, t = 0, item = nil, itemVK = nil,
    status = "apagado", lastAurora = -1e9, lastSundial = -1e9, force = false,
}

local STATE_NAMES = {
    IDLE = "idle", CAST = "lanzando", WAIT = "esperando", SHAKE = "shake",
    REEL = "reel", COOLDOWN = "listo",
}

S.WIN_W, S.WIN_H = 780, 540
local G = { x = 70, y = 110, open = true, min = false, tab = 1, dragging = false, dragX = 0, dragY = 0 }

local function saveConfig()
    local parts = {}
    for k, v in pairs(V) do
        local tv = type(v)
        if tv == "boolean" or tv == "number" then parts[#parts + 1] = "v." .. k .. "=" .. tostring(v)
        elseif tv == "string" then parts[#parts + 1] = "s." .. k .. "=" .. v:gsub("[\r\n]", "") end
    end
    for k, vk in pairs(KEYS) do parts[#parts + 1] = "k." .. k .. "=" .. vk end
    for _, s in ipairs(spots) do
        parts[#parts + 1] = ("spot=%s|%.1f|%.1f|%.1f"):format(s.name, s.pos.X, s.pos.Y, s.pos.Z)
    end
    parts[#parts + 1] = "posx=" .. floor(G.x)
    parts[#parts + 1] = "posy=" .. floor(G.y)
    parts[#parts + 1] = "tab=" .. G.tab
    pcall(writefile, S.CONFIG, table.concat(parts, "\n"))
end

local function loadConfig()
    local okF, exists = pcall(isfile, S.CONFIG)
    if okF and not exists then return end
    local ok, data = pcall(readfile, S.CONFIG)
    if not ok or type(data) ~= "string" then return end
    for line in data:gmatch("[^\r\n]+") do
        local k, v = line:match("^([%w_%.]+)=(.*)$")
        if k == "posx" then G.x = tonumber(v) or G.x
        elseif k == "posy" then G.y = tonumber(v) or G.y
        elseif k == "tab" then G.tab = tonumber(v) or 1
        elseif k == "spot" then
            local n, x, y, z = v:match("^(.-)|([%-%d%.]+)|([%-%d%.]+)|([%-%d%.]+)$")
            if n then spots[#spots + 1] = { name = n, pos = Vector3.new(tonumber(x), tonumber(y), tonumber(z)) } end
        elseif k then
            local kind, name = k:match("^(%a)%.(.+)$")
            if kind == "v" and V[name] ~= nil then
                if type(V[name]) == "boolean" then V[name] = (v == "true")
                elseif type(V[name]) == "number" then V[name] = tonumber(v) or V[name] end
            elseif kind == "s" and type(V[name]) == "string" then V[name] = v
            elseif kind == "k" and KEYS[name] then KEYS[name] = tonumber(v) or KEYS[name] end
        end
    end
end

loadConfig()
V.auto_fish, V.auto_totem = false, false

local ISLANDS = {
    { "Moosewood",        390,  140,   245 },
    { "Roslit Bay",     -1450,  140,   500 },
    { "Snowcap Island",  2760,  265,   350 },
    { "Mushgrove Swamp", 2620,  145,  -740 },
    { "Sunstone Island", -940,  145, -1100 },
    { "Terrapin Island", -180,  145, -1200 },
    { "Forsaken Shores", -2450, 145,   700 },
    { "Ancient Isle",    5900,  145,   500 },
    { "Desolate Deep",   1000,  145,   300 },
}

local IDX = {
    scanning = false, done = false, status = "sin escanear . pulsa escanear el juego",
    places = {}, names = {}, npcs = {}, npcNames = {}, rods = {}, rodNames = {},
    GENERIC = {
        part = true, model = true, meshpart = true, union = true, unionoperation = true, folder = true,
        handle = true, attachment = true, wedge = true, base = true, spawnlocation = true, hitbox = true,
        collision = true, collider = true, root = true, primary = true, light = true, decal = true,
        humanoidrootpart = true, head = true, torso = true, terrain = true, camera = true, effects = true,
        debris = true, ignore = true, clone = true, temp = true, map = true, world = true, misc = true,
    },
}

IDX.TOTEMS = {
    "Aurora Totem", "Avalanche Totem", "Blizzard Totem", "Clearcast Totem", "Meteor Totem",
    "Poseidon Wrath Totem", "Smokescreen Totem", "Sundial Totem", "Tempest Totem", "Windset Totem",
}

IDX.REGION_CAT = { zonas = "zona", islas = "isla", tiendas = "tienda", totems = "totem", cajas = "caja", canas = "cana", lugares = "lugar" }
IDX.REGIONS = { "todo", "zonas", "islas", "tiendas", "totems", "cajas", "canas", "lugares", "mis spots", "islas (aprox)" }

function IDX.posOf(inst)
    if not inst then return nil end
    local ok, pos = pcall(function()
        if inst:IsA("BasePart") then return inst.Position end
        if inst:IsA("Model") then
            local pp = inst.PrimaryPart
            if pp then return pp.Position end
            local r = inst:FindFirstChild("HumanoidRootPart") or inst:FindFirstChild("Head")
            if r then return r.Position end
            local kids = inst:GetChildren()
            for i = 1, min(#kids, 60) do
                if kids[i]:IsA("BasePart") then return kids[i].Position end
            end
            for i = 1, min(#kids, 20) do
                local sub = kids[i]:GetChildren()
                for j = 1, min(#sub, 30) do
                    if sub[j]:IsA("BasePart") then return sub[j].Position end
                end
            end
        end
        return nil
    end)
    return ok and pos or nil
end

function IDX.niceName(n)
    if type(n) ~= "string" or #n < 3 or #n > 48 then return false end
    local l = n:lower()
    if IDX.GENERIC[l] then return false end
    if l:match("^part%d*$") or l:match("^model%d*$") or l:match("^[%d%s%p]+$") then return false end
    return n:match("%a") ~= nil
end

function IDX.categorize(name, parentName)
    local l, p = name:lower(), (parentName or ""):lower()
    if l:find("totem", 1, true) then return "totem" end
    if l:find("crate", 1, true) then return "caja" end
    if l:match("rod$") or l:find(" rod", 1, true) or p:find("rod", 1, true) then return "cana" end
    if p:find("zone", 1, true) then return "zona" end
    if p:find("island", 1, true) or l:find("island", 1, true) or l:find("isle", 1, true) then return "isla" end
    if l:find("shop", 1, true) or l:find("merchant", 1, true) or l:find("store", 1, true) or p:find("shop", 1, true) then return "tienda" end
    return "lugar"
end

function IDX.addNpc(name, inst, pos)
    local base, n = name, 2
    while IDX.npcs[name] do name = base .. " (" .. n .. ")"; n = n + 1 end
    IDX.npcs[name] = { pos = pos, inst = inst }
    IDX.npcNames[#IDX.npcNames + 1] = name
end

function IDX.scanRods()
    local RS
    pcall(function() RS = game:GetService("ReplicatedStorage") end)
    if RS then
        local queue, qi, best, seen = { { RS, 0 } }, 1, nil, 0
        while qi <= #queue and seen < 12000 and S.running do
            local inst, depth = queue[qi][1], queue[qi][2]
            queue[qi] = nil
            qi, seen = qi + 1, seen + 1
            local okN, name = pcall(function() return inst.Name end)
            local okC, kids = pcall(function() return inst:GetChildren() end)
            if okN and okC then
                local l = name:lower()
                if (l == "rods" or l == "rod" or l == "fishingrods") and #kids >= 5 then
                    if not best or #kids > #best then best = kids end
                end
                if depth < 4 and #kids < 3000 then
                    for _, c in ipairs(kids) do queue[#queue + 1] = { c, depth + 1 } end
                end
            end
            if seen % 300 == 0 then wait(0) end
        end
        if best then
            for _, c in ipairs(best) do
                local ok, n = pcall(function() return c.Name end)
                if ok and not IDX.rods[n] then IDX.rods[n] = true; IDX.rodNames[#IDX.rodNames + 1] = n end
            end
        end
    end
    for name, p in pairs(IDX.places) do
        if p.cat == "cana" and not IDX.rods[name] then IDX.rods[name] = true; IDX.rodNames[#IDX.rodNames + 1] = name end
    end
end

function IDX.scan()
    if IDX.scanning then return end
    IDX.scanning, IDX.done = true, false
    IDX.places, IDX.names, IDX.npcs, IDX.npcNames, IDX.rods, IDX.rodNames = {}, {}, {}, {}, {}, {}
    IDX.status = "escaneando..."
    task.spawn(function()
        local isPlayer = {}
        pcall(function() for _, p in ipairs(Players:GetPlayers()) do isPlayer[p.Name] = true end end)
        local queue, qi = {}, 1
        local okT, top = pcall(function() return workspace:GetChildren() end)
        if okT then for _, c in ipairs(top) do queue[#queue + 1] = { c, 1, "workspace", true } end end
        local visited, budget = 0, 0
        while qi <= #queue and visited < 80000 and S.running do
            local item = queue[qi]
            queue[qi] = nil
            qi = qi + 1
            local inst, depth, parentName, parentIsFolder = item[1], item[2], item[3], item[4]
            visited, budget = visited + 1, budget + 1
            local okN, name = pcall(function() return inst.Name end)
            if okN and type(name) == "string" and not isPlayer[name] then
                local isModel, isPart, isFolder = false, false, false
                pcall(function() isModel = inst:IsA("Model") end)
                if not isModel then pcall(function() isPart = inst:IsA("BasePart") end) end
                if not isModel and not isPart then pcall(function() isFolder = inst:IsA("Folder") end) end
                local isNpc = false
                if isModel then
                    pcall(function() isNpc = inst:FindFirstChild("Humanoid") ~= nil end)
                end
                if isNpc then
                    local pos = IDX.posOf(inst)
                    if pos then IDX.addNpc(name, inst, pos) end
                elseif (isModel or isPart) and (depth <= 2 or parentIsFolder) and IDX.niceName(name) and not IDX.places[name] then
                    local pos = IDX.posOf(inst)
                    if pos then
                        IDX.places[name] = { pos = pos, inst = inst, cat = IDX.categorize(name, parentName) }
                        IDX.names[#IDX.names + 1] = name
                    end
                end
                if (isFolder and depth < 7) or (isModel and not isNpc and depth <= 2) then
                    local okC, kids = pcall(function() return inst:GetChildren() end)
                    if okC and #kids < 5000 then
                        for _, c in ipairs(kids) do queue[#queue + 1] = { c, depth + 1, name, isFolder } end
                    end
                end
            end
            if budget >= 200 then
                budget = 0
                IDX.status = ("escaneando . %d objetos . %d lugares . %d npcs"):format(visited, #IDX.names, #IDX.npcNames)
                wait(0)
            end
        end
        IDX.status = "buscando el catalogo de canas..."
        IDX.scanRods()
        table.sort(IDX.names); table.sort(IDX.npcNames); table.sort(IDX.rodNames)
        IDX.scanning, IDX.done = false, true
        IDX.status = ("%d lugares . %d npcs . %d canas"):format(#IDX.names, #IDX.npcNames, #IDX.rodNames)
    end)
end

function IDX.findPlace(name, cat)
    if not name or name == "" then return nil end
    local p = IDX.places[name]
    if p then return p end
    local l = name:lower()
    for n, e in pairs(IDX.places) do
        if (not cat or e.cat == cat) and n:lower():find(l, 1, true) then return e end
    end
    for n, e in pairs(IDX.places) do
        if n:lower():find(l, 1, true) then return e end
    end
    return nil
end

local function findDest(name)
    if not name or name == "" then return nil end
    local spotName = name:match("^%* (.+)$")
    if spotName then
        for i, s in ipairs(spots) do if s.name == spotName then return s.pos, false, i end end
        return nil
    end
    local approx = name:match("^~ (.+)$") or name
    for _, d in ipairs(ISLANDS) do
        if d[1] == approx then return Vector3.new(d[2], d[3], d[4]), true end
    end
    local p = IDX.places[name]
    if p then
        local live = IDX.posOf(p.inst) or p.pos
        return live + Vector3.new(0, 4, 0), false
    end
    return nil
end

local function destOptions()
    local out, r = {}, V.region
    if r == "todo" or r == "mis spots" then
        for _, s in ipairs(spots) do out[#out + 1] = "* " .. s.name end
    end
    if r == "islas (aprox)" or (r == "todo" and not IDX.done) then
        for _, d in ipairs(ISLANDS) do out[#out + 1] = "~ " .. d[1] end
    end
    local want = IDX.REGION_CAT[r]
    if r == "todo" or want then
        for _, n in ipairs(IDX.names) do
            if r == "todo" or IDX.places[n].cat == want then out[#out + 1] = n end
        end
    end
    return out
end

local function totemOptions()
    local out, seen = {}, {}
    for _, n in ipairs(IDX.TOTEMS) do out[#out + 1] = n; seen[n:lower()] = true end
    for _, n in ipairs(IDX.names) do
        if IDX.places[n].cat == "totem" and not seen[n:lower()] then out[#out + 1] = n; seen[n:lower()] = true end
    end
    return out
end

local EX = { path = {}, map = {}, names = {}, status = "elige una raiz" }

function EX.open(inst, label, push)
    if not inst then EX.status = "no se pudo abrir"; return end
    if push then EX.path[#EX.path + 1] = { inst = inst, name = label } end
    EX.map, EX.names = {}, {}
    local ok, kids = pcall(function() return inst:GetChildren() end)
    if ok then
        local countKids = #kids <= 800
        for i = 1, min(#kids, 4000) do
            local c = kids[i]
            local okN, n = pcall(function() return c.Name end)
            if okN then
                local disp = n
                if countKids then
                    local okC, cnt = pcall(function() return #c:GetChildren() end)
                    if okC and cnt > 0 then disp = n .. "  /" .. cnt end
                end
                local base, k = disp, 2
                while EX.map[disp] do disp = base .. " #" .. k; k = k + 1 end
                EX.map[disp] = c
                EX.names[#EX.names + 1] = disp
            end
        end
        table.sort(EX.names)
        EX.status = #EX.names .. " objetos dentro"
    else
        EX.status = "no se pudo leer"
    end
    V.ex_item = ""
end

function EX.root(which)
    EX.path = {}
    local inst, label
    if which == "ws" then inst, label = workspace, "workspace"
    elseif which == "rs" then pcall(function() inst = game:GetService("ReplicatedStorage") end); label = "ReplicatedStorage"
    elseif which == "pg" then pcall(function() inst = LocalPlayer:FindFirstChild("PlayerGui") end); label = "PlayerGui"
    elseif which == "ch" then pcall(function() inst = LocalPlayer.Character end); label = "tu personaje" end
    EX.open(inst, label, true)
end

function EX.pathText()
    if #EX.path == 0 then return "ruta: -" end
    local parts = {}
    for i, p in ipairs(EX.path) do parts[i] = p.name end
    local s = table.concat(parts, " > ")
    if #s > 44 then s = ".." .. s:sub(-42) end
    return s
end

function EX.selected()
    local disp = V.ex_item
    if disp == "" then return nil, nil end
    local inst = EX.map[disp]
    local name = disp:gsub("  /%d+$", ""):gsub(" #%d+$", "")
    return inst, name
end

S.tpStatus = "listo"

local function setState(s, now, status)
    F.state, F.t = s, now
    if status then F.statusText = status end
end

local function teleportTo(pos, raycast, label)
    if not pos then S.tpStatus = "elige un destino"; return end
    task.spawn(function()
        S.charTime = -10
        if not getHRP() then S.tpStatus = "sin personaje"; return end
        local y = pos.Y
        if raycast then
            local ok, res = pcall(function()
                return workspace:Raycast(Vector3.new(pos.X, pos.Y + 150, pos.Z), Vector3.new(0, -400, 0))
            end)
            if ok and res and res.Position then y = res.Position.Y + 5 end
        end
        local cf = CFrame.new(pos.X, y, pos.Z)
        for _ = 1, 6 do
            local h = getHRP()
            if not h then break end
            pcall(function() h.CFrame = cf end)
            wait(0.03)
        end
        S.tpStatus = "llegaste a " .. (label or "destino")
        if F.state ~= "REEL" then setState("COOLDOWN", tick()) end
    end)
end

local function teleportFishingSpot()
    local pos, ray = findDest(V.fish_spot)
    if pos then teleportTo(pos, ray, V.fish_spot) else S.tpStatus = "no tienes spot de pesca" end
end

local GC = { keys = {}, names = {}, sig = "" }

function GC.build()
    local sig = V.gc_keys .. "|" .. V.gc_max
    if sig == GC.sig then return end
    GC.sig = sig
    GC.keys, GC.names = {}, {}
    S.MAX_KEY = V.gc_max:gsub("%s", "")
    if S.MAX_KEY ~= "" then GC.names[1] = S.MAX_KEY end
    for k in V.gc_keys:gmatch("[^,%s]+") do
        GC.keys[#GC.keys + 1] = k
        GC.names[#GC.names + 1] = k
    end
end

S.gcCache, S.gcVals = nil, nil

local function refreshGC()
    GC.build()
    if #GC.keys == 0 then S.gcCache = nil; return end
    local ok, res = pcall(getgc, GC.names)
    if not ok or type(res) ~= "table" or #res == 0 then S.gcCache = nil; return end
    local maxV = 0
    for _, e in ipairs(res) do
        if type(e) == "table" and e.key == S.MAX_KEY and type(e.value) == "number" and e.value > maxV then maxV = e.value end
    end
    if maxV <= 0 then maxV = V.gc_fallback end
    local vals = {}
    for _, k in ipairs(GC.keys) do vals[k] = maxV end
    S.gcCache, S.gcVals = res, vals
end

local function forceProgress()
    if S.gcCache and S.gcVals then pcall(applygc, S.gcCache, S.gcVals) end
end

local function debugGC()
    GC.build()
    local ok, res = pcall(getgc, GC.names)
    if not ok or type(res) ~= "table" then notify("getgc fallo", "NORTH FISCH", 3); return end
    for i = 1, min(#res, 40) do
        local e = res[i]
        if type(e) == "table" then
            print(("[GC] %s = %s (%s)"):format(tostring(e.key), tostring(e.value), tostring(e.type)))
        end
    end
    notify("gc: " .. #res .. " entradas (mira la consola)", "NORTH FISCH", 3)
end

local function readWebhook()
    local okF, ex = pcall(isfile, S.WEBHOOK_FILE)
    if not (okF and ex) then pcall(writefile, S.WEBHOOK_FILE, ""); return nil end
    local ok, d = pcall(readfile, S.WEBHOOK_FILE)
    if not ok or type(d) ~= "string" then return nil end
    d = d:gsub("%s+", "")
    if d:find("^https://") then return d end
    return nil
end

local function jsonSafe(s) return (tostring(s):gsub('[%c"\\]', "")) end

local function sendWebhook(title)
    local url = readWebhook()
    if not url then notify("pega tu webhook en " .. S.WEBHOOK_FILE, "NORTH FISCH", 4); return false end
    local el = tick() - F.startTime
    local perH = el > 60 and floor(F.catches / el * 3600) or 0
    local desc = ("capturas: **%d**\\nperdidas: **%d**\\npor hora: **%d**\\ntiempo: **%s**\\ncana: **%s**"):format(
        F.catches, F.losses, perH, fmtTime(el), jsonSafe(S.rodCache or "ninguna"))
    local body = ('{"embeds":[{"title":"%s","description":"%s","color":15592941}]}'):format(jsonSafe(title), desc)
    return (pcall(httppost, url, body, "application/json"))
end

local UIref = { time = -10 }

local function refreshUI(now)
    if now - UIref.time < 0.1 then return end
    UIref.time = now
    local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    UIref.shakeGui = pg and pg:FindFirstChild(PATH.shakeGui) or nil
    UIref.shakeBtn = findPath(UIref.shakeGui, PATH.shakeButton)
    local reel = pg and pg:FindFirstChild(PATH.reelGui) or nil
    UIref.reelGui  = reel
    UIref.fish     = findPath(reel, PATH.reelFish)
    UIref.pbar     = findPath(reel, PATH.reelPlayer)
    UIref.progress = findPath(reel, PATH.reelProgress)
end

local function guiOn(sg)
    if not sg then return false end
    local ok, en = pcall(function() return sg.Enabled end)
    return (not ok) or en ~= false
end
local function shakeVisible() return UIref.shakeBtn ~= nil and guiOn(UIref.shakeGui) end
local function reelVisible()  return UIref.fish ~= nil and UIref.pbar ~= nil and guiOn(UIref.reelGui) end

local function centerX(f)
    local ok, c = pcall(function()
        local ax = 0
        pcall(function() ax = f.AnchorPoint.X end)
        return f.Position.X.Scale + (0.5 - ax) * f.Size.X.Scale
    end)
    return ok and c or nil
end

local function readProgress()
    if not UIref.progress then return nil end
    local ok, v = pcall(function() return UIref.progress.Size.X.Scale end)
    return ok and v or nil
end

local function insetFor(sg)
    local v = tonumber(V.gui_inset)
    if v then return v end
    local ok, ign = pcall(function() return sg.IgnoreGuiInset end)
    if ok and ign == true then return 0 end
    return 58
end

local REEL_PREDICT = { suave = 0.18, normal = 0.12, rapido = 0.06 }
S.ignoreClickUntil = 0

local function setHold(v)
    if v == F.holding then return end
    F.holding = v
    if v then pcall(mouse1press) else pcall(mouse1release) end
end

local function stopFishing(now)
    setHold(false)
    F.curProg = 0
    setState("IDLE", now, "apagado")
end

local function doShake(now)
    local btn = UIref.shakeBtn
    local ok, ap, as = pcall(function() return btn.AbsolutePosition, btn.AbsoluteSize end)
    if not ok or not ap or not as then return end
    local x = floor(ap.X + as.X / 2)
    local y = floor(ap.Y + as.Y / 2 + insetFor(UIref.shakeGui))
    if x ~= F.shakeX or y ~= F.shakeY then
        F.shakeX, F.shakeY, F.shakeMoveT = x, y, now
        pcall(mousemoveabs, x, y)
    elseif now - F.shakeMoveT >= 0.03 and now - F.shakeClickT >= 0.06 then
        F.shakeClickT = now
        S.ignoreClickUntil = now + 0.2
        pcall(mouse1click)
    end
end

local function trackProgress()
    local p = readProgress()
    if p then
        F.curProg = p
        if p > F.maxProg then F.maxProg = p end
    end
end

local function doReel(now)
    trackProgress()
    local fc, bc = centerX(UIref.fish), centerX(UIref.pbar)
    if not fc or not bc then return end
    local dt = max(now - F.lastBcT, 1 / 240)
    local vb = F.lastBc and (bc - F.lastBc) / dt or 0
    F.lastBc, F.lastBcT = bc, now
    local predicted = (fc - bc) - vb * (REEL_PREDICT[V.reel_mode] or 0.12)
    setHold(predicted > 0)
end

local function updateFishing(now)
    if not V.auto_fish then
        if F.state ~= "IDLE" or F.holding then stopFishing(now) end
        F.statusText = "apagado"
        return
    end
    if T.busy then setHold(false); F.statusText = "usando totem"; return end
    if not rbxActive() then setHold(false); F.statusText = "roblox sin foco"; return end

    refreshUI(now)
    refreshChar(now)
    local s = F.state
    local shaking, reeling = shakeVisible(), reelVisible()

    if reeling and s ~= "REEL" then
        setHold(false)
        F.maxProg, F.curProg, F.lastBc, F.gcStep = 0, 0, nil, 0
        setState("REEL", now, "recogiendo")
        s = "REEL"
    elseif shaking and s ~= "SHAKE" and s ~= "REEL" then
        setHold(false)
        F.shakeX, F.shakeY = -1, -1
        setState("SHAKE", now, "agitando")
        s = "SHAKE"
    end

    if s == "IDLE" then
        if not S.rodCache then F.statusText = "equipa la cana"; return end
        if V.return_spot and V.fish_spot ~= "" and S.hrpCache and now - F.lastReturn > 8 then
            local pos, ray = findDest(V.fish_spot)
            if pos then
                local ok, d = pcall(function() return (S.hrpCache.Position - pos).Magnitude end)
                if ok and d > 40 then
                    F.lastReturn = now
                    teleportTo(pos, ray, V.fish_spot)
                    setState("COOLDOWN", now, "volviendo al spot")
                    return
                end
            end
        end
        if not V.auto_cast then F.statusText = "esperando (lanza tu)"; return end
        F.statusText = "lanzando"
        setHold(true)
        setState("CAST", now)

    elseif s == "CAST" then
        if now - F.t >= V.cast_hold then
            setHold(false)
            setState("WAIT", now, "esperando pique")
        end

    elseif s == "WAIT" then
        if now - F.t > 30 then
            S.ignoreClickUntil = now + 0.2
            pcall(mouse1click)
            F.failures = F.failures + 1
            setState("COOLDOWN", now, "relanzando")
        end

    elseif s == "SHAKE" then
        if shaking then
            if V.auto_shake then doShake(now) else F.statusText = "shake (manual)" end
            F.t = now
        elseif now - F.t > 4 then
            setState("IDLE", now)
        end

    elseif s == "REEL" then
        if reeling then
            if V.wide_bar and UIref.pbar and now - (F.wideT or 0) > 0.1 then
                F.wideT = now
                pcall(function()
                    local sz = UIref.pbar.Size
                    local w = V.bar_width / 100
                    if abs(sz.X.Scale - w) > 0.002 then
                        UIref.pbar.Size = UDim2.new(w, sz.X.Offset, sz.Y.Scale, sz.Y.Offset)
                    end
                end)
            end
            if V.legit then doReel(now) else trackProgress(); F.statusText = "reel (manual)" end
            if V.instant then
                local el = now - F.t
                local d = V.instant_delay
                if (F.gcStep == 0 and el > max(0.05, d - 0.4)) or (F.gcStep == 1 and el > d + 0.4) then
                    F.gcStep = F.gcStep + 1
                    refreshGC()
                end
                if el >= d then forceProgress() end
            end
        else
            setHold(false)
            if F.maxProg >= 0.85 then F.catches = F.catches + 1 else F.losses = F.losses + 1 end
            F.curProg = 0
            setState("COOLDOWN", now, "capturado")
        end

    elseif s == "COOLDOWN" then
        if now - F.t > 1.5 then setState("IDLE", now) end
    end
end

local function slotVK(s) local n = tonumber(s); return (n and n >= 1 and n <= 9) and (0x30 + n) or nil end

local function startTotem(item, now)
    local vk = slotVK(item == "sundial" and V.slot_sundial or V.slot_aurora)
    if not vk then T.status = "falta la tecla del " .. item; return false end
    T.busy, T.step, T.t, T.item, T.itemVK = true, 1, now, item, vk
    setHold(false)
    T.status = "usando " .. item
    return true
end

local function stopTotem()
    if T.busy then pcall(keyrelease, T.itemVK or 0x31) end
    T.busy, T.step, T.force = false, 0, false
end

local function updateTotem(now)
    if T.busy then
        local el = now - T.t
        if T.step == 1 then pcall(keypress, T.itemVK); T.step, T.t = 2, now
        elseif T.step == 2 and el > 0.08 then pcall(keyrelease, T.itemVK); T.step, T.t = 3, now
        elseif T.step == 3 and el > 0.7 then
            S.ignoreClickUntil = now + 0.2
            pcall(mouse1click); T.step, T.t = 4, now
        elseif T.step == 4 and el > 2.0 then
            local rvk = slotVK(V.slot_rod)
            if rvk then pcall(keypress, rvk) end
            T.step, T.t = 5, now
        elseif T.step == 5 and el > 0.08 then
            local rvk = slotVK(V.slot_rod)
            if rvk then pcall(keyrelease, rvk) end
            T.step, T.t = 6, now
        elseif T.step == 6 and el > 0.8 then
            if T.item == "sundial" then T.lastSundial = now else T.lastAurora = now end
            T.busy, T.step = false, 0
            T.status = T.item .. " usado"
            setState("COOLDOWN", now)
        end
        return
    end

    if not V.auto_totem and not T.force then T.status = "apagado"; return end
    if F.state ~= "IDLE" and F.state ~= "COOLDOWN" then return end

    local night = isNight(now)
    local plan = V.totem_plan
    local sundialReady = now - T.lastSundial > 60
    if plan == "aurora" then
        if not night then
            if sundialReady then startTotem("sundial", now) else T.status = "esperando la noche" end
        elseif T.force or now - T.lastAurora > V.totem_every * 60 then
            startTotem("aurora", now)
        else
            T.status = ("aurora en %d min"):format(floor((V.totem_every * 60 - (now - T.lastAurora)) / 60) + 1)
        end
    elseif plan == "siempre de dia" then
        if night and sundialReady then startTotem("sundial", now) else T.status = night and "esperando sundial" or "es de dia" end
    elseif plan == "siempre de noche" then
        if not night and sundialReady then startTotem("sundial", now) else T.status = night and "es de noche" or "esperando sundial" end
    end
    T.force = false
end

local SLOTS9 = { "1", "2", "3", "4", "5", "6", "7", "8", "9" }
local SLOTS0 = { "ninguno", "1", "2", "3", "4", "5", "6", "7", "8", "9" }

local actions = {}

local TABS = {
    { name = "pesca",
      status = function() return V.auto_fish and "on" or "off" end,
      cols = {
        {
            { t = "section", text = "automatizacion", desc = "auto fish e instant catch son independientes" },
            { t = "check", id = "auto_fish", label = "auto fish", key = "fish",
              desc = "lanza, agita, recoge y vuelve a lanzar solo. click en la tecla para cambiarla" },
            { t = "check", id = "instant", label = "instant catch", key = "catch", risk = true,
              desc = "fuerza el progreso del reel editando memoria del juego. puede dejar de funcionar si fisch se actualiza" },
            { t = "slider", id = "instant_delay", label = "instant: esperar", min = 0, max = 4, step = 0.1, fmt = "%.1f s",
              desc = "cuanto dura el reel antes de terminarlo. unos 2 s se ve natural" },
            { t = "check", id = "wide_bar", label = "barra ancha", risk = true,
              desc = "agranda tu barra del reel para que el pez quede dentro mas facil. edita la gui del juego" },
            { t = "slider", id = "bar_width", label = "ancho de la barra", min = 10, max = 90, step = 1, fmt = "%d %%",
              desc = "porcentaje del recorrido del reel. apaga barra ancha para volver al tamano normal" },
            { t = "check", id = "legit", label = "legit reel",
              desc = "el raton mantiene la barra encima del pez en el reel normal. necesita roblox en primer plano" },
            { t = "drop", id = "reel_mode", label = "modo de reel", options = { "suave", "normal", "rapido" },
              desc = "cuanto se adelanta la barra al movimiento del pez" },
            { t = "check", id = "auto_shake", label = "auto shake", desc = "pulsa el boton de agitar donde aparezca" },
            { t = "check", id = "auto_cast", label = "auto lanzar", desc = "mantiene el click para lanzar. apagalo si prefieres lanzar tu" },
            { t = "slider", id = "cast_hold", label = "tiempo de lanzado", min = 0.2, max = 1.2, step = 0.05, fmt = "%.2f s",
              desc = "cuanto se mantiene el click al lanzar. mas tiempo = mas lejos" },
            { t = "section", text = "spot de pesca", desc = "se elige en teleports" },
            { t = "check", id = "return_spot", label = "volver al spot",
              desc = "si te alejas mas de 40 m de tu spot de pesca, te devuelve antes de lanzar" },
            { t = "text", get = function() return "spot: " .. (V.fish_spot ~= "" and V.fish_spot or "ninguno") end },
        },
        {
            { t = "section", text = "estado", desc = "el hud muestra el resto" },
            { t = "text", get = function()
                return (STATE_NAMES[F.state] or "idle") .. " . auto fish " .. (V.auto_fish and "on" or "off") .. " . cana " .. (S.rodCache or "ninguna")
            end },
            { t = "text", get = function()
                return ("capturas %d . perdidas %d . fallos %d"):format(F.catches, F.losses, F.failures)
            end },
            { t = "text", get = function()
                local el, tot = tick() - F.startTime, F.catches + F.losses
                return "por hora " .. (el > 60 and floor(F.catches / el * 3600) or "-") ..
                       " . exito " .. (tot > 0 and (floor(F.catches / tot * 100) .. "%") or "-")
            end },
            { t = "text", get = function() return "reel . " .. (F.state == "REEL" and (floor(F.curProg * 100) .. "%") or "idle") end },
            { t = "text", get = function() return "instant catch . " .. (V.instant and (S.gcCache and "gc listo" or "buscando") or "off") end },
            { t = "btns", list = { { "reiniciar contador", "reset_stats" }, { "debug gc", "debug_gc" } } },
            { t = "section", text = "hud", desc = "panel arriba a la derecha" },
            { t = "check", id = "hud", label = "mostrar hud", desc = "estado, capturas y tiempo" },
            { t = "check", id = "hud_bar", label = "barra de reel", desc = "progreso del reel en vivo dentro del hud" },
            { t = "check", id = "keys_panel", label = "lista de teclas", desc = "arriba a la izquierda: tus teclas y si estan activas" },
        },
      } },

    { name = "totems",
      status = function() return V.auto_totem and "on" or "off" end,
      cols = {
        {
            { t = "section", text = "auto totem", desc = "usa totems entre capturas y luego sigue pescando" },
            { t = "check", id = "auto_totem", label = "auto totem", desc = "los totems que uses tienen que estar en tu hotbar" },
            { t = "drop", id = "totem_plan", label = "plan", options = { "aurora", "siempre de dia", "siempre de noche" },
              desc = "aurora = sundial si es de dia y luego el totem aurora de noche. siempre de dia / noche = sundial cuando cambie el ciclo" },
            { t = "text", get = function() return "estado: " .. T.status end },
            { t = "text", get = function() return "ahora: " .. (isNight() and "noche" or "dia") end },
            { t = "btns", list = { { "usar el plan ahora", "totem_now" }, { "parar", "totem_stop" } } },
            { t = "note", text = "un evento o un cooldown pueden bloquear un totem. el sundial se reintenta cada minuto y el aurora segun el intervalo." },
        },
        {
            { t = "section", text = "hotbar", desc = "en que tecla esta cada cosa" },
            { t = "drop", id = "slot_rod", label = "cana", options = SLOTS9, desc = "se vuelve a equipar despues de cada totem" },
            { t = "drop", id = "slot_sundial", label = "sundial totem", options = SLOTS0 },
            { t = "drop", id = "slot_aurora", label = "aurora totem", options = SLOTS0 },
            { t = "slider", id = "totem_every", label = "repetir aurora cada", min = 5, max = 60, step = 1, fmt = "%d min",
              desc = "minutos entre un totem aurora y el siguiente" },
            { t = "section", text = "tiendas de totems", desc = "todos los totems del juego. los del indice se anaden solos" },
            { t = "drop", id = "totem_shop", label = "totem", options = totemOptions, search = true },
            { t = "btns", list = { { "ir a la tienda", "tp_totem" } } },
            { t = "text", get = function() return S.totemStatus or "elige un totem" end },
        },
      } },

    { name = "teleports",
      status = function() return V.fish_spot ~= "" and "spot" or "" end,
      cols = {
        {
            { t = "section", text = "indice del juego", desc = "lee el mapa en vivo: zonas, islas, tiendas, totems, cajas, canas y npcs" },
            { t = "text", get = function() return clipStr(IDX.status, 44) end },
            { t = "btns", list = { { "escanear el juego", "scan_game" } } },
            { t = "section", text = "destinos", desc = "auto fish sigue despues de llegar" },
            { t = "drop", id = "region", label = "region", options = IDX.REGIONS,
              desc = "filtra la lista de destinos" },
            { t = "drop", id = "dest", label = "destino", options = destOptions, search = true,
              desc = "escribe para buscar. * = tus spots, ~ = posicion aproximada" },
            { t = "btns", list = { { "teleport", "tp_dest" }, { "borrar", "del_dest" } } },
            { t = "btns", list = { { "hacerlo mi spot de pesca", "make_spot" } } },
            { t = "text", get = function() return S.tpStatus end },
            { t = "section", text = "coordenadas", desc = "escribe x, y, z. ejemplo: 383, 135, 244" },
            { t = "input", id = "coords", label = "x, y, z", placeholder = "x, y, z" },
            { t = "btns", list = { { "ir a coordenadas", "tp_coords" }, { "guardar aqui", "save_here" } } },
            { t = "text", get = function()
                local h = S.hrpCache
                if not h then return "tu posicion: -" end
                local ok, p = pcall(function() return h.Position end)
                if not ok then return "tu posicion: -" end
                return ("tu posicion: %d, %d, %d"):format(floor(p.X), floor(p.Y), floor(p.Z))
            end },
        },
        {
            { t = "section", text = "npcs", desc = "todos los npcs que encuentra el indice. escribe para buscar" },
            { t = "drop", id = "npc", label = "npc", options = function() return IDX.npcNames end, search = true },
            { t = "text", get = function() return #IDX.npcNames .. " npcs" end },
            { t = "btns", list = { { "tp al npc", "tp_npc" } } },
            { t = "section", text = "canas", desc = "catalogo de canas del juego y donde se venden" },
            { t = "drop", id = "rod", label = "cana", options = function() return IDX.rodNames end, search = true },
            { t = "btns", list = { { "tp a la cana", "tp_rod" } } },
            { t = "text", get = function() return S.rodStatus or (#IDX.rodNames .. " canas") end },
            { t = "section", text = "marcadores", desc = "senala tu spot de pesca" },
            { t = "check", id = "markers", label = "marcador del spot", desc = "punto en el mundo y flecha en el borde de la pantalla" },
            { t = "check", id = "tp_on_select", label = "tp al elegir destino", desc = "teletransporta en cuanto eliges un destino de la lista" },
        },
      } },

    { name = "explorador",
      status = function() return #EX.path > 0 and tostring(#EX.names) or "" end,
      cols = {
        {
            { t = "section", text = "explorador", desc = "recorre el juego por dentro: carpetas, modelos y gui. si algo no sale en el indice, aqui lo encuentras" },
            { t = "text", get = function() return EX.pathText() end },
            { t = "drop", id = "ex_item", label = "objeto", options = function() return EX.names end, search = true,
              desc = "/n = tiene n objetos dentro. escribe para buscar" },
            { t = "btns", list = { { "entrar", "ex_enter" }, { "subir", "ex_up" } } },
            { t = "btns", list = { { "tp al objeto", "ex_tp" }, { "copiar ruta", "ex_copy" } } },
            { t = "btns", list = { { "guardar como spot", "ex_spot" } } },
            { t = "text", get = function() return clipStr(EX.status, 44) end },
        },
        {
            { t = "section", text = "empezar en", desc = "elige desde donde explorar" },
            { t = "btns", list = { { "workspace", "ex_ws" }, { "replicatedstorage", "ex_rs" } } },
            { t = "btns", list = { { "mi playergui", "ex_pg" }, { "mi personaje", "ex_ch" } } },
            { t = "note", text = "playergui sirve para ver los nombres reales del reel y del shake. si fisch los cambia, copia la ruta y pasamela." },
        },
      } },

    { name = "afk & discord",
      status = function() return V.anti_afk and "afk" or "" end,
      cols = {
        {
            { t = "section", text = "anti-afk", desc = "evita que roblox te expulse por inactividad" },
            { t = "check", id = "anti_afk", label = "anti-afk", desc = "mueve el raton 1 px de vez en cuando" },
            { t = "slider", id = "afk_minutes", label = "cada", min = 1, max = 15, step = 1, fmt = "%d min" },
            { t = "note", text = "volver a entrar solo despues de un kick necesita una app externa y no esta incluido." },
        },
        {
            { t = "section", text = "discord", desc = "tu propio webhook, sin paginas externas" },
            { t = "note", text = "pega la url de tu webhook en north_fisch_webhook.txt, dentro de la carpeta de matcha." },
            { t = "check", id = "discord", label = "reporte de estadisticas", desc = "manda capturas, perdidas y tiempo mientras pescas" },
            { t = "slider", id = "discord_minutes", label = "cada", min = 5, max = 60, step = 1, fmt = "%d min" },
            { t = "btns", list = { { "probar webhook", "wh_test" } } },
        },
      } },

    { name = "ajustes",
      status = function() return "" end,
      cols = {
        {
            { t = "section", text = "teclas", desc = "click en la tecla y pulsa otra. esc cancela" },
            { t = "keyrow", key = "menu",  label = "mostrar / ocultar" },
            { t = "keyrow", key = "fish",  label = "auto fish" },
            { t = "keyrow", key = "catch", label = "instant catch" },
            { t = "keyrow", key = "tp",    label = "tp al spot de pesca" },
            { t = "section", text = "clicks" },
            { t = "drop", id = "gui_inset", label = "ajuste y del shake", options = { "auto", "0", "36", "58" },
              desc = "cambialo si el click del shake cae arriba o abajo del boton" },
            { t = "section", text = "instant catch avanzado", desc = "nombres que busca en la memoria del juego" },
            { t = "input", id = "gc_keys", label = "claves de progreso", placeholder = "Progress,FishProgress",
              desc = "separadas por comas. mayusculas con shift" },
            { t = "input", id = "gc_max", label = "clave del maximo", placeholder = "MaxProgress" },
            { t = "slider", id = "gc_fallback", label = "valor si no hay maximo", min = 1, max = 100, step = 1, fmt = "%d",
              desc = "se usa cuando el juego no tiene la clave del maximo" },
        },
        {
            { t = "section", text = "script" },
            { t = "text", get = function() return "north fisch " .. S.VERSION end },
            { t = "btns", list = { { "guardar config", "save_cfg" } } },
            { t = "btns", list = { { "cerrar script", "unload", true } } },
            { t = "note", text = "la config se guarda sola en north_fisch.cfg cada vez que cambias algo." },
        },
      } },
}
G.tab = clamp(G.tab, 1, #TABS)

S.HEAD, S.SIDE, S.FOOT, S.PAD = 48, 176, 26, 18
S.COL_W = floor((S.WIN_W - S.SIDE - S.PAD * 3) / 2)
S.WRAP = 43
S.LINE_H = 15

local function descLines(w) return w.desc and wrap(w.desc, S.WRAP) or {} end

for ti, tab in ipairs(TABS) do
    for ci, col in ipairs(tab.cols) do
        local oy = 0
        for _, w in ipairs(col) do
            w.tab, w.col = ti, ci
            w.lines = (w.t == "note") and wrap(w.text, S.WRAP) or descLines(w)
            local nl = #w.lines * S.LINE_H
            if w.t == "section" then w.h = 22 + nl + (nl > 0 and 8 or 0) + 6
            elseif w.t == "check" then w.h = 38 + nl + (nl > 0 and 6 or 0)
            elseif w.t == "slider" then w.h = 52 + nl + (nl > 0 and 6 or 0)
            elseif w.t == "drop" or w.t == "input" then w.h = 72 + nl + (nl > 0 and 6 or 0)
            elseif w.t == "btns" then w.h = 42
            elseif w.t == "text" then w.h = 34
            elseif w.t == "note" then w.h = nl + 16
            elseif w.t == "keyrow" then w.h = 40 end
            w.oy = oy
            oy = oy + w.h
        end
        col.contentH = oy
        col.scroll = 0
    end
end

local function mkLines(w, z, color)
    w.dl = {}
    for i, s in ipairs(w.lines) do
        w.dl[i] = Txt(12, color or C.dim, z)
        P(w.dl[i], "Text", s)
    end
end

local allWidgets = {}
for _, tab in ipairs(TABS) do
    for _, col in ipairs(tab.cols) do
        for _, w in ipairs(col) do
            allWidgets[#allWidgets + 1] = w
            local z = 6
            w.parts = {}
            local function part(o) w.parts[#w.parts + 1] = o; return o end
            if w.t ~= "section" and w.t ~= "note" and w.t ~= "btns" then
                w.div = part(Box(z, C.line, 0))
            end
            if w.t == "section" then
                w.lbl = part(Txt(11, C.dim, z + 1, false, true)); P(w.lbl, "Text", w.text)
                w.rule = part(Ln(z, C.line, 1))
                mkLines(w, z + 1)
            elseif w.t == "check" then
                w.hov = part(Box(z, C.hover, 4))
                w.lbl = part(Txt(14, C.text, z + 1)); P(w.lbl, "Text", w.label)
                if w.risk then
                    w.badge = part(Outline(z + 1, C.risk, 3))
                    w.badgeTx = part(Txt(11, C.risk, z + 2, true, true)); P(w.badgeTx, "Text", "risk")
                end
                w.cbBg = part(Box(z + 1, C.field, 3))
                w.cbOl = part(Outline(z + 2, C.line2, 3))
                w.cbOn = part(Box(z + 2, C.white, 3))
                w.ck1 = part(Ln(z + 3, C.black, 2))
                w.ck2 = part(Ln(z + 3, C.black, 2))
                if w.key then
                    w.chipBg = part(Box(z + 1, C.field, 3))
                    w.chipOl = part(Outline(z + 2, C.line2, 3))
                    w.chipTx = part(Txt(12, C.dim, z + 3, true, true))
                end
                mkLines(w, z + 1)
            elseif w.t == "slider" then
                w.hov = part(Box(z, C.hover, 4))
                w.lbl = part(Txt(14, C.text, z + 1)); P(w.lbl, "Text", w.label)
                w.val = part(Txt(12, C.dim, z + 1, false, true))
                w.track = part(Box(z + 1, C.line2, 0))
                w.fill = part(Box(z + 2, C.white, 0))
                w.knob = part(Box(z + 3, C.white, 2))
                mkLines(w, z + 1)
            elseif w.t == "drop" or w.t == "input" then
                w.lbl = part(Txt(14, C.text, z + 1)); P(w.lbl, "Text", w.label)
                w.fBg = part(Box(z + 1, C.field, 4))
                w.fOl = part(Outline(z + 2, C.line2, 4))
                w.fTx = part(Txt(13, C.text, z + 3))
                if w.t == "drop" then
                    w.chA = part(Ln(z + 3, C.dim, 1.5))
                    w.chB = part(Ln(z + 3, C.dim, 1.5))
                else
                    w.caret = part(Ln(z + 3, C.white, 1))
                end
                mkLines(w, z + 1)
            elseif w.t == "btns" then
                w.b = {}
                for i, def in ipairs(w.list) do
                    local danger = def[3]
                    w.b[i] = {
                        label = def[1], act = def[2], danger = danger,
                        bg = part(Box(z + 1, danger and C.riskDim or C.field, 4)),
                        ol = part(Outline(z + 2, danger and C.risk or C.line2, 4)),
                        tx = part(Txt(13, danger and C.risk or C.text, z + 3, true)),
                    }
                    P(w.b[i].tx, "Text", def[1])
                end
            elseif w.t == "text" then
                w.tx = part(Txt(14, C.text, z + 1))
            elseif w.t == "note" then
                mkLines(w, z + 1, C.text)
            elseif w.t == "keyrow" then
                w.hov = part(Box(z, C.hover, 4))
                w.lbl = part(Txt(14, C.text, z + 1)); P(w.lbl, "Text", w.label)
                w.chipBg = part(Box(z + 1, C.field, 3))
                w.chipOl = part(Outline(z + 2, C.line2, 3))
                w.chipTx = part(Txt(12, C.dim, z + 3, true, true))
            end
            if w.dl then for _, o in ipairs(w.dl) do part(o) end end
        end
        col.thumb = Box(8, C.line2, 2)
    end
end

local UI = {
    shadow  = Box(1, C.shadow, 10, 0.45),
    bg      = Box(2, C.bg, 8),
    border  = Outline(3, C.line, 8),
    headLn  = Box(4, C.line, 0),
    footLn  = Box(4, C.line, 0),
    sideLn  = Box(4, C.line, 0),
    side    = Box(3, C.side, 0),
    title   = Txt(16, C.white, 6),
    ver     = Txt(11, C.faint, 6, false, true),
    dot     = Box(6, C.white, 3),
    status  = Txt(11, C.dim, 6, false, true),
    sBg     = Box(5, C.field, 5),
    sOl     = Outline(6, C.line2, 5),
    sTx     = Txt(12, C.faint, 7),
    sCaret  = Ln(7, C.white, 1),
    minA    = Ln(6, C.dim, 1.5),
    xA      = Ln(6, C.dim, 1.5),
    xB      = Ln(6, C.dim, 1.5),
    user1   = Txt(13, C.text, 6),
    user2   = Txt(11, C.faint, 6, false, true),
    gear    = Txt(14, C.dim, 6, true),
    world   = Txt(11, C.faint, 6, false, true),
    hide    = Txt(11, C.faint, 6, false, true),
    hint    = Txt(11, C.dim, 6, false, true),
}
P(UI.title, "Text", "north fisch")
P(UI.ver, "Text", S.VERSION)
P(UI.gear, "Text", "*")
local chrome = {}
for k, o in pairs(UI) do
    if k ~= "sCaret" and k ~= "hint" then chrome[#chrome + 1] = o end
end

local tabUI = {}
for i, tab in ipairs(TABS) do
    tabUI[i] = {
        bg = Box(4, C.sel, 0), bar = Box(5, C.white, 0),
        tx = Txt(14, C.dim, 6), st = Txt(11, C.faint, 6, false, true),
    }
    P(tabUI[i].tx, "Text", tab.name)
end

S.DROP_ROWS = 8
local DD = {
    bg = Box(30, C.field, 4), ol = Outline(31, C.line2, 4),
    rows = {}, more = Txt(11, C.faint, 33, false, true),
}
for i = 1, S.DROP_ROWS do
    DD.rows[i] = { hov = Box(31, C.sel, 3), tx = Txt(13, C.text, 32), mark = Box(32, C.white, 2) }
end

S.SR_ROWS = 8
local SR = { bg = Box(30, C.field, 4), ol = Outline(31, C.line2, 4), rows = {}, empty = Txt(12, C.faint, 32) }
P(SR.empty, "Text", "sin resultados")
for i = 1, S.SR_ROWS do
    SR.rows[i] = { hov = Box(31, C.sel, 3), tx = Txt(13, C.text, 32), tab = Txt(11, C.faint, 32, false, true) }
end

local mkDot   = Box(9, C.white, 6)
local mkLabel = Txt(13, C.white, 9, true)
P(mkLabel, "Outline", true)
local edgeDot   = Box(9, C.white, 7)
local edgeLabel = Txt(13, C.white, 9, true)
P(edgeLabel, "Outline", true)
Size(mkDot, 10, 10); Size(edgeDot, 14, 14)

S.HUD_W = 250
local HUD = {
    shadow = Box(1, C.shadow, 10, 0.4),
    bg     = Box(2, C.bg, 8, 0.94),
    ol     = Outline(3, C.line, 8),
    dot    = Box(4, C.white, 3),
    title  = Txt(14, C.white, 4),
    rule   = Box(3, C.line, 0),
    track  = Box(3, C.line2, 0),
    fill   = Box(4, C.white, 0),
    barTx  = Txt(11, C.faint, 4, false, true),
    lines  = {},
}
P(HUD.title, "Text", "north fisch")
Size(HUD.dot, 6, 6)
local HUD_LABELS = { "macro", "fase", "cana", "instant", "capturas", "perdidas", "fallos", "tiempo" }
for i, lb in ipairs(HUD_LABELS) do
    HUD.lines[i] = { d = Box(4, C.faint, 3), l = Txt(13, C.text, 4), v = Txt(12, C.dim, 4, false, true) }
    Size(HUD.lines[i].d, 5, 5)
    P(HUD.lines[i].l, "Text", lb)
end

local KP = {
    bg = Box(2, C.bg, 6, 0.9), ol = Outline(3, C.line, 6),
    title = Txt(11, C.faint, 4, false, true), rows = {},
}
P(KP.title, "Text", "teclas")
local KP_DEF = { { "auto fish", "fish", "auto_fish" }, { "instant catch", "catch", "instant" }, { "menu", "menu", nil } }
for i in ipairs(KP_DEF) do
    KP.rows[i] = { d = Box(4, C.faint, 3), tx = Txt(12, C.text, 4), k = Txt(11, C.dim, 4, false, true) }
    Size(KP.rows[i].d, 5, 5)
    P(KP.rows[i].tx, "Text", KP_DEF[i][1])
end

S.mx, S.my = -9999, -9999
local hits = {}
local ohits = {}
S.hoverDesc = nil
S.clipTop, S.clipBot = -1e9, 1e9
S.blockRect = nil

S.rebinding, S.rebindArmed = nil, false
S.sliding = nil
S.scrollDrag = nil
S.openDrop = nil
S.focus = nil
S.searchText = ""
local flash = { w = nil, untilT = 0 }
S.shownTab = -1

local function addHit(x, y, w, h, fn, desc)
    local y1, y2 = max(y, S.clipTop), min(y + h, S.clipBot)
    if y2 <= y1 then return end
    hits[#hits + 1] = { x = x, y = y1, w = w, h = y2 - y1, fn = fn, desc = desc }
end

local function isHover(x, y, w, h)
    if S.blockRect and inRect(S.mx, S.my, S.blockRect) then return false end
    if S.my < S.clipTop or S.my > S.clipBot then return false end
    return S.mx >= x and S.mx <= x + w and S.my >= y and S.my <= y + h
end

local function inClip(y, h) return y >= S.clipTop and y + h <= S.clipBot end

local function put(o, x, y, h)
    if inClip(y, h) then Pos(o, x, y); Vis(o, true) else Vis(o, false) end
end
local function putBox(o, x, y, w, h)
    if inClip(y, h) then Pos(o, x, y); Size(o, w, h); Vis(o, true) else Vis(o, false) end
end
local function putLine(o, x1, y1, x2, y2)
    if inClip(min(y1, y2), abs(y2 - y1)) then LineTo(o, x1, y1, x2, y2); Vis(o, true) else Vis(o, false) end
end
local function hide(o) Vis(o, false) end

local function hideWidget(w) for _, o in ipairs(w.parts) do Vis(o, false) end end

local function hideTab(ti)
    for _, col in ipairs(TABS[ti].cols) do
        for _, w in ipairs(col) do hideWidget(w) end
        Vis(col.thumb, false)
    end
end

local function closeDrop()
    S.openDrop = nil
    if S.focus == "drop" then S.focus = nil end
end

local function dropOptions(w)
    local o = w.options
    if type(o) == "function" then o = o() end
    return o or {}
end

local function onValueChanged(id)
    if id == "auto_fish" then
        if not V.auto_fish then stopFishing(tick()) else setState("IDLE", tick(), "iniciando") end
    elseif id == "region" then
        V.dest = ""
    elseif id == "dest" and V.tp_on_select then
        local pos, ray = findDest(V.dest)
        teleportTo(pos, ray, V.dest)
    elseif id == "auto_totem" and not V.auto_totem then
        stopTotem()
    end
    saveConfig()
end

local function startRebind(keyId) S.rebinding, S.rebindArmed = keyId, false; closeDrop(); S.focus = nil end

local function drawDesc(w, x, y)
    if not w.dl then return end
    for i, o in ipairs(w.dl) do put(o, x, y + (i - 1) * S.LINE_H, 14) end
end

local function renderWidget(w, x, y, cw)
    local t = w.t
    local h = w.h
    local flashing = flash.w == w and tick() < flash.untilT

    if w.div then putBox(w.div, x, y + h - 1, cw, 1) end

    if t == "section" then
        put(w.lbl, x, y + 4, 13)
        local lw = textW(w.text, 11, true)
        putLine(w.rule, x + lw + 10, y + 11, x + cw, y + 11)
        drawDesc(w, x, y + 24)

    elseif t == "check" then
        local hov = isHover(x - 8, y, cw + 16, h - 1)
        if hov or flashing then putBox(w.hov, x - 8, y + 1, cw + 16, h - 3) else hide(w.hov) end
        put(w.lbl, x, y + 11, 16)
        if w.badge then
            local bx = x + textW(w.label, 14) + 12
            putBox(w.badge, bx, y + 12, 34, 15)
            put(w.badgeTx, bx + 17, y + 13, 13)
        end
        local cbx, cby = x + cw - 20, y + 10
        putBox(w.cbBg, cbx, cby, 20, 20)
        putBox(w.cbOl, cbx, cby, 20, 20)
        if V[w.id] then
            putBox(w.cbOn, cbx, cby, 20, 20)
            putLine(w.ck1, cbx + 5, cby + 10, cbx + 9, cby + 14)
            putLine(w.ck2, cbx + 9, cby + 14, cbx + 15, cby + 6)
        else
            hide(w.cbOn); hide(w.ck1); hide(w.ck2)
        end
        drawDesc(w, x, y + 34)
        addHit(x - 8, y, cw + 16, h - 1, function()
            V[w.id] = not V[w.id]
            onValueChanged(w.id)
        end, w.desc)
        if w.key then
            local s = (S.rebinding == w.key) and "..." or keyName(KEYS[w.key])
            local chW = max(30, textW(s, 12, true) + 16)
            local chx = cbx - 12 - chW
            putBox(w.chipBg, chx, cby - 1, chW, 22)
            putBox(w.chipOl, chx, cby - 1, chW, 22)
            P(w.chipOl, "Color", (S.rebinding == w.key) and C.white or C.line2)
            P(w.chipTx, "Text", s)
            put(w.chipTx, chx + chW / 2, cby + 3, 14)
            addHit(chx, cby - 1, chW, 22, function() startRebind(w.key) end, "click y pulsa una tecla. esc cancela")
        end

    elseif t == "slider" then
        local hov = isHover(x - 8, y, cw + 16, h - 1) or (S.sliding and S.sliding.w == w)
        if hov or flashing then putBox(w.hov, x - 8, y + 1, cw + 16, h - 3) else hide(w.hov) end
        put(w.lbl, x, y + 11, 16)
        local vs = w.fmt:format(V[w.id])
        P(w.val, "Text", vs)
        put(w.val, x + cw - textW(vs, 12, true), y + 12, 14)
        local ty = y + 38
        local f = (V[w.id] - w.min) / (w.max - w.min)
        local fw = floor(cw * f)
        putBox(w.track, x, ty, cw, 2)
        putBox(w.fill, x, ty, max(1, fw), 2)
        putBox(w.knob, x + fw - 3, ty - 7, 6, 16)
        drawDesc(w, x, y + 52)
        addHit(x - 8, y, cw + 16, h - 1, function() S.sliding = { w = w, x = x, cw = cw } end, w.desc)

    elseif t == "drop" or t == "input" then
        put(w.lbl, x, y + 11, 16)
        local fy = y + 34
        local isOpen = S.openDrop and S.openDrop.w == w
        local focused = (t == "input" and S.focus == w) or (isOpen and S.focus == "drop")
        local hov = isHover(x, fy, cw, 30)
        putBox(w.fBg, x, fy, cw, 30)
        P(w.fBg, "Color", (hov or isOpen or focused or flashing) and C.hover or C.field)
        putBox(w.fOl, x, fy, cw, 30)
        P(w.fOl, "Color", (isOpen or focused) and C.dim or C.line2)
        local s, col
        if t == "drop" then
            if isOpen and S.openDrop.filter ~= "" then s, col = S.openDrop.filter, C.white
            elseif isOpen and w.search then s, col = "escribe para buscar", C.faint
            else
                s = V[w.id]
                if s == "" or s == nil then s, col = "ninguno", C.faint else col = C.text end
            end
            local cx, cy = x + cw - 18, fy + 13
            if isOpen then
                putLine(w.chA, cx - 5, cy + 3, cx, cy - 2); putLine(w.chB, cx, cy - 2, cx + 5, cy + 3)
            else
                putLine(w.chA, cx - 5, cy - 2, cx, cy + 3); putLine(w.chB, cx, cy + 3, cx + 5, cy - 2)
            end
            addHit(x, fy, cw, 30, function()
                if isOpen then closeDrop()
                else
                    S.openDrop = { w = w, x = x, y = fy + 34, cw = cw, filter = "", scroll = 0 }
                    S.focus = "drop"
                end
            end, w.desc)
        else
            s = V[w.id]
            if s == "" then s, col = (focused and "" or w.placeholder), C.faint
            else
                col = C.text
                if #s > 38 then s = focused and (".." .. s:sub(-36)) or (s:sub(1, 36) .. "..") end
            end
            if focused and tick() % 1 < 0.6 then
                local cxp = x + 12 + textW(V[w.id] == "" and "" or s, 13)
                putLine(w.caret, cxp + 1, fy + 8, cxp + 1, fy + 22)
            else
                hide(w.caret)
            end
            addHit(x, fy, cw, 30, function() closeDrop(); S.focus = w end, "escribe y pulsa enter")
        end
        P(w.fTx, "Text", clipStr(s, 38))
        P(w.fTx, "Color", col)
        put(w.fTx, x + 12, fy + 8, 15)
        drawDesc(w, x, y + 72)

    elseif t == "btns" then
        local n = #w.b
        local bw = floor((cw - 10 * (n - 1)) / n)
        for i, b in ipairs(w.b) do
            local bx = x + (i - 1) * (bw + 10)
            local hov = isHover(bx, y + 6, bw, 30)
            putBox(b.bg, bx, y + 6, bw, 30)
            P(b.bg, "Color", hov and (b.danger and rgb(70, 24, 28) or C.sel) or (b.danger and C.riskDim or C.field))
            putBox(b.ol, bx, y + 6, bw, 30)
            P(b.ol, "Color", b.danger and C.risk or (hov and C.dim or C.line2))
            put(b.tx, bx + bw / 2, y + 13, 15)
            addHit(bx, y + 6, bw, 30, function() if actions[b.act] then actions[b.act]() end end, nil)
        end

    elseif t == "text" then
        if w.get then P(w.tx, "Text", clipStr(w.get(), 44)) end
        put(w.tx, x, y + 10, 16)

    elseif t == "note" then
        drawDesc(w, x, y + 6)

    elseif t == "keyrow" then
        local hov = isHover(x - 8, y, cw + 16, h - 1)
        if hov or flashing or S.rebinding == w.key then putBox(w.hov, x - 8, y + 1, cw + 16, h - 3) else hide(w.hov) end
        put(w.lbl, x, y + 12, 16)
        local s = (S.rebinding == w.key) and "pulsa una tecla" or keyName(KEYS[w.key])
        local chW = max(40, textW(s, 12, true) + 18)
        local chx = x + cw - chW
        putBox(w.chipBg, chx, y + 9, chW, 22)
        putBox(w.chipOl, chx, y + 9, chW, 22)
        P(w.chipOl, "Color", (S.rebinding == w.key) and C.white or C.line2)
        P(w.chipTx, "Text", s)
        put(w.chipTx, chx + chW / 2, y + 13, 14)
        addHit(x - 8, y, cw + 16, h - 1, function() startRebind(w.key) end, "click y pulsa una tecla. esc cancela")
    end
end

local colRects = {}

local function renderColumns(ti)
    local tab = TABS[ti]
    local top = G.y + S.HEAD + 14
    local bot = G.y + S.WIN_H - S.FOOT - 10
    local vh = bot - top
    for ci, col in ipairs(tab.cols) do
        local x = G.x + S.SIDE + S.PAD + (ci - 1) * (S.COL_W + S.PAD)
        colRects[ci] = { x = x, y = top, w = S.COL_W, h = vh, col = col }
        local maxS = max(0, col.contentH - vh)
        col.scroll = clamp(col.scroll, 0, maxS)
        S.clipTop, S.clipBot = top, bot
        local y0 = top - col.scroll
        for _, w in ipairs(col) do
            local y = y0 + w.oy
            if y + w.h < top or y > bot then hideWidget(w) else renderWidget(w, x, y, S.COL_W) end
        end
        S.clipTop, S.clipBot = -1e9, 1e9

        if maxS > 0 then
            local th = max(30, floor(vh * vh / col.contentH))
            local ty = top + floor((vh - th) * (col.scroll / maxS))
            local tx = x + S.COL_W + 6
            Pos(col.thumb, tx, ty); Size(col.thumb, 3, th); Vis(col.thumb, true)
            P(col.thumb, "Color", (S.scrollDrag and S.scrollDrag.col == col) and C.dim or C.line2)
            addHit(tx - 4, ty, 11, th, function()
                S.scrollDrag = { col = col, y0 = S.my, s0 = col.scroll, ratio = maxS / max(1, vh - th) }
            end, nil)
        else
            Vis(col.thumb, false)
        end
    end
    for ci = #tab.cols + 1, 2 do colRects[ci] = nil end
end

local function scrollToWidget(w)
    local col = TABS[w.tab].cols[w.col]
    col.scroll = max(0, w.oy - 20)
end

local function searchResults()
    local q = S.searchText:lower()
    local out = {}
    if q == "" then return out end
    for _, w in ipairs(allWidgets) do
        local label = w.label or (w.t == "section" and w.text)
        if label and w.t ~= "text" then
            local hay = (label .. " " .. (w.desc or "")):lower()
            if hay:find(q, 1, true) then out[#out + 1] = w end
            if #out >= S.SR_ROWS then break end
        end
    end
    return out
end

local function renderSearchOverlay(sx, sy, sw)
    local show = S.focus == "search" and S.searchText ~= ""
    if not show then
        Vis(SR.bg, false); Vis(SR.ol, false); Vis(SR.empty, false)
        for _, r in ipairs(SR.rows) do Vis(r.hov, false); Vis(r.tx, false); Vis(r.tab, false) end
        return
    end
    local res = searchResults()
    local rows = max(1, #res)
    local bw, bh = sw + 80, rows * 28 + 8
    local bx, by = sx + sw - bw, sy + 34
    S.blockRect = { x = bx, y = by, w = bw, h = bh }
    Pos(SR.bg, bx, by); Size(SR.bg, bw, bh); Vis(SR.bg, true)
    Pos(SR.ol, bx, by); Size(SR.ol, bw, bh); Vis(SR.ol, true)
    Vis(SR.empty, #res == 0)
    if #res == 0 then Pos(SR.empty, bx + 12, by + 10) end
    for i, r in ipairs(SR.rows) do
        local w = res[i]
        if w then
            local ry = by + 4 + (i - 1) * 28
            local hov = S.mx >= bx and S.mx <= bx + bw and S.my >= ry and S.my <= ry + 28
            Pos(r.hov, bx + 4, ry); Size(r.hov, bw - 8, 28); Vis(r.hov, hov)
            P(r.tx, "Text", clipStr(w.label or w.text, 30)); Pos(r.tx, bx + 12, ry + 6); Vis(r.tx, true)
            local tn = TABS[w.tab].name
            P(r.tab, "Text", tn); Pos(r.tab, bx + bw - 12 - textW(tn, 11, true), ry + 8); Vis(r.tab, true)
            ohits[#ohits + 1] = { x = bx + 4, y = ry, w = bw - 8, h = 28, fn = function()
                G.tab = w.tab
                scrollToWidget(w)
                flash.w, flash.untilT = w, tick() + 1.6
                S.focus, S.searchText = nil, ""
            end }
        else
            Vis(r.hov, false); Vis(r.tx, false); Vis(r.tab, false)
        end
    end
end

local function filteredOptions()
    local opts = dropOptions(S.openDrop.w)
    local f = S.openDrop.filter:lower()
    if f == "" then return opts end
    local out = {}
    for _, o in ipairs(opts) do if o:lower():find(f, 1, true) then out[#out + 1] = o end end
    return out
end

local function renderDropOverlay()
    if not S.openDrop or S.openDrop.w.tab ~= G.tab or not G.open or G.min then
        Vis(DD.bg, false); Vis(DD.ol, false); Vis(DD.more, false)
        for _, r in ipairs(DD.rows) do Vis(r.hov, false); Vis(r.tx, false); Vis(r.mark, false) end
        if S.openDrop and (S.openDrop.w.tab ~= G.tab or not G.open) then closeDrop() end
        return
    end
    local w = S.openDrop.w
    local opts = filteredOptions()
    local maxS = max(0, #opts - S.DROP_ROWS)
    S.openDrop.scroll = clamp(S.openDrop.scroll, 0, maxS)
    local rows = min(S.DROP_ROWS, #opts)
    local extra = (maxS > 0) and 20 or 0
    local bh = max(1, rows) * 26 + 8 + extra
    local bx, by, bw = S.openDrop.x, S.openDrop.y, S.openDrop.cw

    if by + bh > G.y + S.WIN_H - 4 then by = S.openDrop.y - 38 - bh end
    S.blockRect = { x = bx, y = by, w = bw, h = bh }
    Pos(DD.bg, bx, by); Size(DD.bg, bw, bh); Vis(DD.bg, true)
    Pos(DD.ol, bx, by); Size(DD.ol, bw, bh); Vis(DD.ol, true)
    for i, r in ipairs(DD.rows) do
        local o = opts[i + S.openDrop.scroll]
        if o and i <= rows then
            local ry = by + 4 + (i - 1) * 26
            local hov = S.mx >= bx and S.mx <= bx + bw and S.my >= ry and S.my <= ry + 26
            Pos(r.hov, bx + 4, ry); Size(r.hov, bw - 8, 26); Vis(r.hov, hov)
            P(r.tx, "Text", clipStr(o, 36)); Pos(r.tx, bx + 12, ry + 5); Vis(r.tx, true)
            local sel = (V[w.id] == o)
            Pos(r.mark, bx + bw - 18, ry + 10); Size(r.mark, 6, 6); Vis(r.mark, sel)
            ohits[#ohits + 1] = { x = bx + 4, y = ry, w = bw - 8, h = 26, fn = function()
                V[w.id] = o
                closeDrop()
                onValueChanged(w.id)
            end }
        else
            Vis(r.hov, false); Vis(r.tx, false); Vis(r.mark, false)
        end
    end
    if #opts == 0 then
        P(DD.rows[1].tx, "Text", "sin resultados"); Pos(DD.rows[1].tx, bx + 12, by + 9); Vis(DD.rows[1].tx, true)
    end
    if maxS > 0 then
        P(DD.more, "Text", ("rueda o flechas . %d de %d"):format(min(#opts, S.openDrop.scroll + S.DROP_ROWS), #opts))
        Pos(DD.more, bx + 12, by + bh - 18); Vis(DD.more, true)
    else
        Vis(DD.more, false)
    end
end

S.lastSideTick = -10
local function renderMenu(now)
    hits, ohits = {}, {}
    S.blockRect = nil
    S.hoverDesc = nil

    if not G.open then
        if S.shownTab ~= 0 then
            for _, o in ipairs(chrome) do Vis(o, false) end
            Vis(UI.sCaret, false); Vis(UI.hint, false)
            for _, t in ipairs(tabUI) do Vis(t.bg, false); Vis(t.bar, false); Vis(t.tx, false); Vis(t.st, false) end
            for ti = 1, #TABS do hideTab(ti) end
            S.shownTab = 0
        end
        renderDropOverlay()
        renderSearchOverlay(0, 0, 0)
        return
    end

    local x, y = floor(G.x), floor(G.y)
    local H = G.min and S.HEAD or S.WIN_H

    local sw = 220
    local sx, sy = x + S.WIN_W - sw - 78, y + 9
    renderSearchOverlay(sx, sy, sw)
    if not G.min then renderDropOverlay() end

    Pos(UI.shadow, x + 4, y + 6); Size(UI.shadow, S.WIN_W, H)
    Pos(UI.bg, x, y);             Size(UI.bg, S.WIN_W, H)
    Pos(UI.border, x, y);         Size(UI.border, S.WIN_W, H)
    Pos(UI.headLn, x + 1, y + S.HEAD); Size(UI.headLn, S.WIN_W - 2, 1)

    Pos(UI.title, x + 18, y + 15)
    local tx = x + 18 + textW("north fisch", 16) + 14
    Pos(UI.ver, tx, y + 19)
    tx = tx + textW(S.VERSION, 11, true) + 22
    Pos(UI.dot, tx, y + 22); Size(UI.dot, 6, 6)
    P(UI.dot, "Color", V.auto_fish and C.good or C.white)
    P(UI.status, "Text", (STATE_NAMES[F.state] or "idle") .. " . " .. F.catches .. " capturas")
    Pos(UI.status, tx + 12, y + 19)

    local sRect = { x = sx, y = sy, w = sw, h = 30 }
    local sFocus = S.focus == "search"
    Pos(UI.sBg, sx, sy); Size(UI.sBg, sw, 30)
    P(UI.sBg, "Color", (sFocus or inRect(S.mx, S.my, sRect)) and C.hover or C.field)
    Pos(UI.sOl, sx, sy); Size(UI.sOl, sw, 30)
    P(UI.sOl, "Color", sFocus and C.dim or C.line2)
    if S.searchText == "" then
        P(UI.sTx, "Text", sFocus and "" or "buscar cualquier ajuste"); P(UI.sTx, "Color", C.faint)
    else
        P(UI.sTx, "Text", clipStr(S.searchText, 30)); P(UI.sTx, "Color", C.text)
    end
    Pos(UI.sTx, sx + 12, sy + 8)
    local cxp = sx + 12 + textW(S.searchText, 12)
    LineTo(UI.sCaret, cxp + 1, sy + 8, cxp + 1, sy + 22)
    hits[#hits + 1] = { x = sx, y = sy, w = sw, h = 30, fn = function() closeDrop(); S.focus = "search" end,
                        desc = "escribe para buscar cualquier ajuste" }

    local mxb, cxb = x + S.WIN_W - 60, x + S.WIN_W - 30
    local minHov = inRect(S.mx, S.my, { x = mxb - 6, y = y + 12, w = 24, h = 24 })
    local xHov = inRect(S.mx, S.my, { x = cxb - 6, y = y + 12, w = 24, h = 24 })
    LineTo(UI.minA, mxb, y + 24, mxb + 12, y + 24); P(UI.minA, "Color", minHov and C.white or C.dim)
    LineTo(UI.xA, cxb, y + 18, cxb + 12, y + 30);   P(UI.xA, "Color", xHov and C.white or C.dim)
    LineTo(UI.xB, cxb + 12, y + 18, cxb, y + 30);   P(UI.xB, "Color", xHov and C.white or C.dim)
    hits[#hits + 1] = { x = mxb - 6, y = y + 12, w = 24, h = 24, fn = function() G.min = not G.min; closeDrop() end,
                        desc = "minimizar" }
    hits[#hits + 1] = { x = cxb - 6, y = y + 12, w = 24, h = 24, fn = function() G.open = false; closeDrop(); S.focus = nil end,
                        desc = "ocultar (" .. keyName(KEYS.menu) .. " para volver)" }

    if G.min then

        for _, o in ipairs({ UI.footLn, UI.sideLn, UI.side, UI.user1, UI.user2, UI.gear, UI.world, UI.hide, UI.hint, UI.headLn }) do Vis(o, false) end
        for _, t in ipairs(tabUI) do Vis(t.bg, false); Vis(t.bar, false); Vis(t.tx, false); Vis(t.st, false) end
        for ti = 1, #TABS do hideTab(ti) end
        S.shownTab = -1
        for _, o in ipairs({ UI.shadow, UI.bg, UI.border, UI.title, UI.ver, UI.dot, UI.status, UI.sBg, UI.sOl, UI.sTx, UI.minA, UI.xA, UI.xB }) do Vis(o, true) end
        Vis(UI.sCaret, sFocus and (now % 1 < 0.6))
        return
    end

    if S.shownTab ~= G.tab then
        for ti = 1, #TABS do if ti ~= G.tab then hideTab(ti) end end
        S.shownTab = G.tab
    end

    Pos(UI.side, x + 1, y + S.HEAD + 1); Size(UI.side, S.SIDE - 1, S.WIN_H - S.HEAD - S.FOOT - 1)
    Pos(UI.sideLn, x + S.SIDE, y + S.HEAD + 1); Size(UI.sideLn, 1, S.WIN_H - S.HEAD - S.FOOT - 1)
    for i, t in ipairs(tabUI) do
        local r = { x = x + 1, y = y + S.HEAD + 10 + (i - 1) * 34, w = S.SIDE - 2, h = 34 }
        local act = G.tab == i
        local hov = inRect(S.mx, S.my, r) and not (S.blockRect and inRect(S.mx, S.my, S.blockRect))
        Pos(t.bg, r.x, r.y); Size(t.bg, r.w, r.h); Vis(t.bg, act or hov)
        P(t.bg, "Color", act and C.sel or C.hover)
        Pos(t.bar, r.x, r.y); Size(t.bar, 2, r.h); Vis(t.bar, act)
        P(t.tx, "Color", (act or hov) and C.white or C.dim)
        Pos(t.tx, r.x + 18, r.y + 9); Vis(t.tx, true)
        local st = TABS[i].status()
        P(t.st, "Text", st)
        Pos(t.st, r.x + r.w - 14 - textW(st, 11, true), r.y + 12); Vis(t.st, st ~= "")
        hits[#hits + 1] = { x = r.x, y = r.y, w = r.w, h = r.h, fn = function() G.tab = i; closeDrop(); saveConfig() end }
    end

    Vis(UI.headLn, true)

    if now - S.lastSideTick > 5 then
        S.lastSideTick = now
        local d, n = playerNames()
        P(UI.user1, "Text", clipStr(d, 18)); P(UI.user2, "Text", "@" .. clipStr(n, 18))
    end
    Pos(UI.user1, x + 18, y + S.WIN_H - S.FOOT - 50)
    Pos(UI.user2, x + 18, y + S.WIN_H - S.FOOT - 32)
    Pos(UI.gear, x + S.SIDE - 24, y + S.WIN_H - S.FOOT - 44)
    P(UI.gear, "Color", inRect(S.mx, S.my, { x = x + S.SIDE - 36, y = y + S.WIN_H - S.FOOT - 50, w = 24, h = 24 }) and C.white or C.dim)
    hits[#hits + 1] = { x = x + S.SIDE - 36, y = y + S.WIN_H - S.FOOT - 50, w = 24, h = 24,
                        fn = function() G.tab = #TABS; closeDrop() end, desc = "ajustes" }

    Pos(UI.footLn, x + 1, y + S.WIN_H - S.FOOT); Size(UI.footLn, S.WIN_W - 2, 1)
    P(UI.world, "Text", "mundo  " .. (isNight(now) and "noche" or "dia"))
    Pos(UI.world, x + 18, y + S.WIN_H - S.FOOT + 7)
    local hs = keyName(KEYS.menu):lower() .. " ocultar"
    P(UI.hide, "Text", hs)
    Pos(UI.hide, x + S.WIN_W - 18 - textW(hs, 11, true), y + S.WIN_H - S.FOOT + 7)

    renderColumns(G.tab)

    for i = #hits, 1, -1 do
        local h = hits[i]
        if inRect(S.mx, S.my, h) then S.hoverDesc = h.desc; break end
    end
    local hint = S.rebinding and "pulsa una tecla para asignarla . esc cancela"
        or (S.focus and S.focus ~= "drop" and "escribiendo . enter acepta . esc cancela")
        or (S.hoverDesc and clipStr(S.hoverDesc, 60)) or ""
    P(UI.hint, "Text", hint)
    Pos(UI.hint, x + S.SIDE + S.PAD, y + S.WIN_H - S.FOOT + 7)

    for _, o in ipairs(chrome) do Vis(o, true) end
    Vis(UI.sCaret, sFocus and (now % 1 < 0.6))
    Vis(UI.hint, hint ~= "")

    table.insert(hits, 1, { x = x, y = y, w = S.WIN_W, h = S.HEAD, fn = function()
        G.dragging = true; G.dragX, G.dragY = S.mx - G.x, S.my - G.y
    end })
end

S.lastHud = -10
local function renderKeysPanel(now)
    local on = V.keys_panel
    Vis(KP.bg, on); Vis(KP.ol, on); Vis(KP.title, on)
    for _, r in ipairs(KP.rows) do Vis(r.d, on); Vis(r.tx, on); Vis(r.k, on) end
    if not on then return end
    local kx, ky, kw = 14, 58, 176
    local kh = 30 + #KP_DEF * 18
    Pos(KP.bg, kx, ky); Size(KP.bg, kw, kh)
    Pos(KP.ol, kx, ky); Size(KP.ol, kw, kh)
    Pos(KP.title, kx + 12, ky + 8)
    for i, r in ipairs(KP.rows) do
        local def = KP_DEF[i]
        local ry = ky + 26 + (i - 1) * 18
        local active = def[3] and V[def[3]]
        Pos(r.d, kx + 12, ry + 6)
        P(r.d, "Color", active and C.white or C.faint)
        Pos(r.tx, kx + 24, ry)
        P(r.tx, "Color", active and C.white or C.dim)
        local ks = keyName(KEYS[def[2]])
        P(r.k, "Text", ks)
        Pos(r.k, kx + kw - 12 - textW(ks, 11, true), ry + 2)
    end
end

local function renderHUD(now)
    local on = V.hud
    for _, o in ipairs({ HUD.shadow, HUD.bg, HUD.ol, HUD.title, HUD.dot, HUD.rule }) do Vis(o, on) end
    for _, ln in ipairs(HUD.lines) do Vis(ln.d, on); Vis(ln.l, on); Vis(ln.v, on) end
    local barOn = on and V.hud_bar
    Vis(HUD.track, barOn); Vis(HUD.fill, barOn); Vis(HUD.barTx, barOn)
    if not on then return end

    local _, vy = getViewport(now)
    local rows = #HUD.lines
    local h = 44 + rows * 21 + (barOn and 34 or 0)
    local hx, hy = 14, vy - h - 14

    if barOn then
        local tw = S.HUD_W - 28
        local by = hy + 44 + rows * 21 + 18
        Pos(HUD.track, hx + 14, by); Size(HUD.track, tw, 2)
        Pos(HUD.fill, hx + 14, by); Size(HUD.fill, max(1, floor(tw * clamp(F.curProg, 0, 1))), 2)
        Pos(HUD.barTx, hx + 14, by - 15)
        P(HUD.barTx, "Text", F.state == "REEL" and ("reel  " .. floor(F.curProg * 100) .. "%") or "reel")
    end
    if now - S.lastHud < 0.25 then return end
    S.lastHud = now

    Pos(HUD.shadow, hx + 3, hy + 5); Size(HUD.shadow, S.HUD_W, h)
    Pos(HUD.bg, hx, hy);             Size(HUD.bg, S.HUD_W, h)
    Pos(HUD.ol, hx, hy);             Size(HUD.ol, S.HUD_W, h)
    Pos(HUD.dot, hx + 16, hy + 17)
    P(HUD.dot, "Color", V.auto_fish and C.good or C.white)
    Pos(HUD.title, hx + 30, hy + 11)
    Pos(HUD.rule, hx + 14, hy + 36); Size(HUD.rule, S.HUD_W - 28, 1)

    refreshChar(now)
    local phase = T.busy and "totem" or (V.auto_fish and (STATE_NAMES[F.state] or "idle") or "-")
    local inst = "off"
    if V.instant then inst = (F.state == "REEL") and "activo" or "listo" end
    local vals = {
        V.auto_fish and "pescando" or "off",
        phase,
        S.rodCache and S.rodCache:lower() or "ninguna",
        inst,
        tostring(F.catches),
        tostring(F.losses),
        tostring(F.failures),
        fmtTime(now - F.startTime),
    }
    for i, ln in ipairs(HUD.lines) do
        local ly = hy + 46 + (i - 1) * 21
        local v = clipStr(vals[i], 22)
        local off = (v == "off" or v == "-" or v == "ninguna" or v == "0")
        Pos(ln.d, hx + 16, ly + 6)
        P(ln.d, "Color", off and C.faint or C.white)
        Pos(ln.l, hx + 30, ly)
        P(ln.v, "Text", v)
        Pos(ln.v, hx + S.HUD_W - 16 - textW(v, 12, true), ly + 1)
    end
end

S.lastMarkTxt = -10
local function updateMarkers(now)
    local pos = V.markers and findDest(V.fish_spot) or nil
    local hrp = pos and getHRP(now) or nil
    if not pos or not hrp then
        Vis(mkDot, false); Vis(mkLabel, false); Vis(edgeDot, false); Vis(edgeLabel, false)
        return
    end
    local doTxt = now - S.lastMarkTxt >= 0.2
    if doTxt then S.lastMarkTxt = now end
    local label = nil
    if doTxt then
        local ok, d = pcall(function() return (hrp.Position - pos).Magnitude end)
        label = clipStr(V.fish_spot, 24) .. "  " .. (ok and floor(d) or 0) .. "m"
    end
    local sp, onScreen = WorldToScreen(pos)
    if onScreen and sp then
        Pos(mkDot, sp.X - 5, sp.Y - 5); Pos(mkLabel, sp.X, sp.Y - 26)
        if label then P(mkLabel, "Text", label) end
        Vis(mkDot, true); Vis(mkLabel, true); Vis(edgeDot, false); Vis(edgeLabel, false)
    else
        Vis(mkDot, false); Vis(mkLabel, false)
        local shown = false
        pcall(function()
            local cf = workspace.CurrentCamera.CFrame
            local rel = pos - cf.Position
            local rv, uv = cf.RightVector, cf.UpVector
            local rx = rel.X * rv.X + rel.Y * rv.Y + rel.Z * rv.Z
            local ry = rel.X * uv.X + rel.Y * uv.Y + rel.Z * uv.Z
            local len = math.sqrt(rx * rx + ry * ry)
            if len < 1e-3 then return end
            local vx, vy = getViewport(now)
            local radius = min(vx, vy) / 2 - 60
            local px, py = vx / 2 + (rx / len) * radius, vy / 2 - (ry / len) * radius
            Pos(edgeDot, px - 7, py - 7); Pos(edgeLabel, px, py - 28)
            if label then P(edgeLabel, "Text", label) end
            shown = true
        end)
        Vis(edgeDot, shown); Vis(edgeLabel, shown)
    end
end

local function unload()
    if not S.running then return end
    S.running = false
    setHold(false)
    stopTotem()
    saveConfig()
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    for _, o in ipairs(allDrawings) do pcall(function() o:Remove() end) end
    allDrawings, cache = {}, {}
    _G.NorthFisch = nil
    notify("script cerrado", "NORTH FISCH", 3)
end

local function parseCoords(s)
    local nums = {}
    for n in s:gmatch("%-?%d+%.?%d*") do nums[#nums + 1] = tonumber(n) end
    if #nums >= 3 then return Vector3.new(nums[1], nums[2], nums[3]) end
    return nil
end

local function saveHere()
    local hrp = getHRP()
    if not hrp then S.tpStatus = "sin personaje"; return end
    local used = {}
    for _, s in ipairs(spots) do used[s.name] = true end
    local n = 1
    while used["spot " .. n] do n = n + 1 end
    local p = hrp.Position
    spots[#spots + 1] = { name = "spot " .. n, pos = Vector3.new(p.X, p.Y, p.Z) }
    V.dest = "* spot " .. n
    S.tpStatus = "guardado como spot " .. n
    saveConfig()
end

actions.reset_stats = function() F.catches, F.losses, F.failures, F.startTime = 0, 0, 0, tick() end
actions.debug_gc    = function() task.spawn(debugGC) end
actions.totem_now   = function()
    if T.busy then return end
    T.force = true
    if not V.auto_totem then T.status = "usando el plan una vez" end
end
actions.totem_stop  = function() V.auto_totem = false; stopTotem(); T.status = "parado"; saveConfig() end
actions.tp_dest     = function()
    local pos, ray = findDest(V.dest)
    teleportTo(pos, ray, V.dest)
end
actions.del_dest    = function()
    local _, _, idx = findDest(V.dest)
    if not idx then S.tpStatus = "solo se pueden borrar tus spots (*)"; return end
    local name = V.dest
    table.remove(spots, idx)
    if V.fish_spot == name then V.fish_spot = "" end
    V.dest = ""
    S.tpStatus = "borrado"
    saveConfig()
end
actions.make_spot   = function()
    if V.dest == "" then S.tpStatus = "elige un destino primero"; return end
    V.fish_spot = V.dest
    S.tpStatus = "spot de pesca: " .. V.dest
    saveConfig()
end
actions.tp_coords   = function()
    local pos = parseCoords(V.coords)
    if not pos then S.tpStatus = "escribe tres numeros: x, y, z"; return end
    teleportTo(pos, false, "coordenadas")
end
actions.save_here   = saveHere
actions.scan_game   = function() IDX.scan() end
actions.tp_npc      = function()
    local e = IDX.npcs[V.npc]
    if not e then S.tpStatus = "elige un npc (escanea el juego primero)"; return end
    local pos = IDX.posOf(e.inst) or e.pos
    teleportTo(pos + Vector3.new(4, 2, 0), false, V.npc)
end
actions.tp_rod      = function()
    if V.rod == "" then S.rodStatus = "elige una cana"; return end
    local p = IDX.findPlace(V.rod, "cana")
    if not p then S.rodStatus = "no se ve en el mapa (puede no estar a la venta)"; return end
    S.rodStatus = "yendo a " .. clipStr(V.rod, 30)
    teleportTo((IDX.posOf(p.inst) or p.pos) + Vector3.new(0, 4, 0), false, V.rod)
end
actions.tp_totem    = function()
    if V.totem_shop == "" then S.totemStatus = "elige un totem"; return end
    if not IDX.done then S.totemStatus = "escanea el juego en teleports primero"; return end
    local p = IDX.findPlace(V.totem_shop, "totem") or IDX.findPlace(V.totem_shop:gsub(" [Tt]otem$", ""), "totem")
    if not p then S.totemStatus = "no encontrado en el mapa"; return end
    S.totemStatus = "yendo a " .. clipStr(V.totem_shop, 30)
    teleportTo((IDX.posOf(p.inst) or p.pos) + Vector3.new(0, 4, 0), false, V.totem_shop)
end
actions.ex_ws       = function() EX.root("ws") end
actions.ex_rs       = function() EX.root("rs") end
actions.ex_pg       = function() EX.root("pg") end
actions.ex_ch       = function() EX.root("ch") end
actions.ex_enter    = function()
    local inst, name = EX.selected()
    if not inst then EX.status = "elige un objeto"; return end
    EX.open(inst, name, true)
end
actions.ex_up       = function()
    if #EX.path <= 1 then EX.status = "ya estas en la raiz"; return end
    EX.path[#EX.path] = nil
    local top = EX.path[#EX.path]
    EX.open(top.inst, top.name, false)
end
actions.ex_tp       = function()
    local inst, name = EX.selected()
    local pos = IDX.posOf(inst)
    if not pos then EX.status = "ese objeto no tiene posicion"; return end
    EX.status = "yendo a " .. clipStr(name, 30)
    teleportTo(pos + Vector3.new(0, 4, 0), false, name)
end
actions.ex_copy     = function()
    local parts = {}
    for i, p in ipairs(EX.path) do parts[i] = p.name end
    local _, name = EX.selected()
    if name then parts[#parts + 1] = name end
    local s = table.concat(parts, ".")
    if pcall(setclipboard, s) then EX.status = "ruta copiada" else EX.status = s end
end
actions.ex_spot     = function()
    local inst, name = EX.selected()
    local pos = IDX.posOf(inst)
    if not pos then EX.status = "ese objeto no tiene posicion"; return end
    spots[#spots + 1] = { name = clipStr(name, 24), pos = pos + Vector3.new(0, 4, 0) }
    EX.status = "guardado en mis spots"
    saveConfig()
end
actions.wh_test     = function()
    task.spawn(function() if sendWebhook("north fisch . prueba") then notify("webhook enviado", "NORTH FISCH", 2) end end)
end
actions.save_cfg    = function() saveConfig(); notify("config guardada", "NORTH FISCH", 2) end
actions.unload      = unload

local keyPrev = {}
local function edge(vk)
    if not vk then return false end
    local d = iskeypressed(vk)
    local p = keyPrev[vk]
    keyPrev[vk] = d
    return d and not p
end

local function updateRebind()
    local found = nil
    for vk = 0x08, 0xFE do
        if vk ~= 0x01 and vk ~= 0x02 and vk ~= 0x04 and vk ~= 0x05 and vk ~= 0x06 then
            if iskeypressed(vk) then found = vk; break end
        end
    end
    if not S.rebindArmed then
        if not found then S.rebindArmed = true end
        return
    end
    if found then
        if found ~= 0x1B then KEYS[S.rebinding] = found end
        keyPrev[found] = true
        S.rebinding = nil
        saveConfig()
    end
end

local TYPE_KEYS = {}
for vk = 0x30, 0x39 do TYPE_KEYS[vk] = string.char(vk) end
for vk = 0x41, 0x5A do TYPE_KEYS[vk] = string.char(vk + 32) end
for vk = 0x60, 0x69 do TYPE_KEYS[vk] = tostring(vk - 0x60) end
TYPE_KEYS[0x20], TYPE_KEYS[0xBC], TYPE_KEYS[0xBE], TYPE_KEYS[0xBD] = " ", ",", ".", "-"
TYPE_KEYS[0x6D], TYPE_KEYS[0x6E] = "-", "."

S.typePrev, S.bsT, S.bsRep = {}, 0, 0
local function readTyping(now)
    local add, bs, enter, esc, up, down = "", 0, false, false, false, false
    local shift = iskeypressed(0x10) or iskeypressed(0xA0) or iskeypressed(0xA1)
    for vk, ch in pairs(TYPE_KEYS) do
        local d = iskeypressed(vk)
        if d and not S.typePrev[vk] then
            if shift and vk >= 0x41 and vk <= 0x5A then ch = ch:upper()
            elseif shift and vk == 0xBD then ch = "_" end
            add = add .. ch
        end
        S.typePrev[vk] = d
    end
    local b = iskeypressed(0x08)
    if b and not S.typePrev[0x08] then bs, S.bsT, S.bsRep = 1, now, now
    elseif b and now - S.bsT > 0.4 and now - S.bsRep > 0.05 then bs, S.bsRep = 1, now end
    S.typePrev[0x08] = b
    for _, pair in ipairs({ { 0x0D, "enter" }, { 0x1B, "esc" }, { 0x26, "up" }, { 0x28, "down" } }) do
        local vk = pair[1]
        local d = iskeypressed(vk)
        if d and not S.typePrev[vk] then
            if pair[2] == "enter" then enter = true elseif pair[2] == "esc" then esc = true
            elseif pair[2] == "up" then up = true else down = true end
        end
        S.typePrev[vk] = d
    end
    return add, bs, enter, esc, up, down
end

local function applyTyping(now)
    local add, bs, enter, esc, up, down = readTyping(now)
    local function edit(s)
        if bs > 0 then s = s:sub(1, -2) end
        return (s .. add):sub(1, 200)
    end
    if S.focus == "search" then
        S.searchText = edit(S.searchText)
        if esc then S.focus, S.searchText = nil, "" end
        if enter then
            local res = searchResults()
            local w = res[1]
            if w then
                G.tab = w.tab; scrollToWidget(w)
                flash.w, flash.untilT = w, now + 1.6
            end
            S.focus, S.searchText = nil, ""
        end
    elseif S.focus == "drop" and S.openDrop then
        if S.openDrop.w.search then
            local before = S.openDrop.filter
            S.openDrop.filter = edit(S.openDrop.filter)
            if S.openDrop.filter ~= before then S.openDrop.scroll = 0 end
        end
        if up then S.openDrop.scroll = S.openDrop.scroll - 1 end
        if down then S.openDrop.scroll = S.openDrop.scroll + 1 end
        if esc then closeDrop() end
        if enter then
            local opts = filteredOptions()
            local o = opts[1 + S.openDrop.scroll]
            if o then local w = S.openDrop.w; V[w.id] = o; closeDrop(); onValueChanged(w.id) end
        end
    elseif type(S.focus) == "table" then
        local w = S.focus
        V[w.id] = edit(V[w.id])
        if esc then S.focus = nil end
        if enter then S.focus = nil; saveConfig() end
    end
end

S.wheel = 0
pcall(function()
    local c = UIS.InputChanged:Connect(function(input)
        local ok, isWheel = pcall(function() return tostring(input.UserInputType):find("MouseWheel") ~= nil end)
        if ok and isWheel then
            local okZ, z = pcall(function() return input.Position.Z end)
            if okZ and z then S.wheel = S.wheel + z end
        end
    end)
    table.insert(connections, c)
end)

S.wasDown = false
S.afkT, S.afkPhase = tick(), 0
S.lastWebhook = tick()

local function onPress()

    for i = #ohits, 1, -1 do
        local h = ohits[i]
        if inRect(S.mx, S.my, h) then h.fn(); return end
    end

    if S.openDrop then
        local fieldRect = { x = S.openDrop.x, y = S.openDrop.y - 34, w = S.openDrop.cw, h = 30 }
        local inList = S.blockRect and inRect(S.mx, S.my, S.blockRect)
        closeDrop()
        if inList or inRect(S.mx, S.my, fieldRect) then return end
    end
    for i = #hits, 1, -1 do
        local h = hits[i]
        if inRect(S.mx, S.my, h) then
            if S.focus and S.focus ~= "drop" and h.fn then

                S.focus = nil
            end
            h.fn()
            return
        end
    end
    if S.focus ~= "drop" then S.focus = nil end
end

table.insert(connections, RunService.RenderStepped:Connect(function()
    if not S.running then return end
    local now = tick()
    S.mx, S.my = getMouse()
    local down = ismouse1pressed()

    if G.dragging then
        if down then
            local vx, vy = getViewport(now)
            G.x = clamp(S.mx - G.dragX, 0, max(0, vx - S.WIN_W))
            G.y = clamp(S.my - G.dragY, 0, max(0, vy - S.HEAD))
        else G.dragging = false; saveConfig() end
    end
    if S.sliding then
        if down then
            local w = S.sliding.w
            local f = clamp((S.mx - S.sliding.x) / S.sliding.cw, 0, 1)
            local v = w.min + f * (w.max - w.min)
            V[w.id] = clamp(floor(v / w.step + 0.5) * w.step, w.min, w.max)
        else S.sliding = nil; saveConfig() end
    end
    if S.scrollDrag then
        if down then
            S.scrollDrag.col.scroll = S.scrollDrag.s0 + (S.my - S.scrollDrag.y0) * S.scrollDrag.ratio
        else S.scrollDrag = nil end
    end

    if S.wheel ~= 0 then
        if S.openDrop then
            S.openDrop.scroll = S.openDrop.scroll - (S.wheel > 0 and 1 or -1)
        elseif G.open and not G.min then
            for _, r in pairs(colRects) do
                if inRect(S.mx, S.my, r) then r.col.scroll = r.col.scroll - S.wheel * 48 end
            end
        end
        S.wheel = 0
    end

    if down and not S.wasDown and not F.holding and not T.busy and now >= S.ignoreClickUntil and G.open then onPress() end
    S.wasDown = down
    if not S.running then return end

    if S.rebinding then
        updateRebind()
    elseif S.focus and (S.focus ~= "drop" or (S.openDrop and S.openDrop.w.search)) then
        applyTyping(now)
    else
        if S.focus == "drop" then applyTyping(now) end
        if edge(KEYS.menu) then G.open = not G.open; if not G.open then closeDrop(); S.focus = nil end end
        if edge(KEYS.fish) then
            V.auto_fish = not V.auto_fish
            onValueChanged("auto_fish")
            notify("auto fish: " .. (V.auto_fish and "on" or "off"), "NORTH FISCH", 2)
        end
        if edge(KEYS.catch) then
            V.instant = not V.instant
            notify("instant catch: " .. (V.instant and "on" or "off"), "NORTH FISCH", 2)
            saveConfig()
        end
        if edge(KEYS.tp) then teleportFishingSpot() end
    end

    updateTotem(now)
    updateFishing(now)
    renderMenu(now)
    renderHUD(now)
    renderKeysPanel(now)
    updateMarkers(now)

    if V.anti_afk then
        if S.afkPhase == 0 and now - S.afkT > V.afk_minutes * 60 then
            pcall(mousemoverel, 1, 0); S.afkPhase, S.afkT = 1, now
        elseif S.afkPhase == 1 and now - S.afkT > 0.1 then
            pcall(mousemoverel, -1, 0); S.afkPhase, S.afkT = 0, now
        end
    end

    if V.discord and V.auto_fish and now - S.lastWebhook > V.discord_minutes * 60 then
        S.lastWebhook = now
        task.spawn(function() sendWebhook("north fisch . reporte") end)
    end
end))

task.spawn(function()
    wait(3)
    if S.running and not IDX.scanning and not IDX.done then IDX.scan() end
end)

_G.NorthFisch = { unload = unload, version = S.VERSION }
notify(("cargado . %s menu . %s auto fish"):format(keyName(KEYS.menu), keyName(KEYS.fish)), "NORTH FISCH", 4)
