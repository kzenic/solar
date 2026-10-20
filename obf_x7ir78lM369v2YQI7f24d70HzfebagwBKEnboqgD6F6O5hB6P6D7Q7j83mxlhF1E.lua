--==============================================================
--  SOLAR // AUTO FARM  v1
--  Loop farm for Build a Boat-style waypoints
--  Mobile friendly · semi-transparent · precise timers
--==============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")
local env = (getgenv and getgenv()) or _G

if env.SolarFarmCleanup then pcall(env.SolarFarmCleanup) end

--==============================================================
--  CONFIG
--==============================================================
local TARGET_GAIN = 10000

local WAYPOINTS = {
    Vector3.new(-67.89, 109.88, -291.54),
    Vector3.new(-34.25, 113.01, 1015.99),
    Vector3.new(-59.15, 60.35, 1755.57),
    Vector3.new(-58.76, 54.83, 2559.51),
    Vector3.new(-49.4, 49.37, 3279.51),
    Vector3.new(-39.11, 43.36, 4071.51),
    Vector3.new(-52.92, 76.73, 4917.92),
    Vector3.new(-64.34, 46.81, 5600.81),
    Vector3.new(-65.79, 58.46, 6284.62),
    Vector3.new(-58.31, 70.29, 7015.42),
    Vector3.new(-64.28, 40.29, 7734.5),
    Vector3.new(-74.22, 48.38, 8658.49),
}

local S = {
    active = false,
    antiAfk = true,
    delay = 0.35,
    cooldown = 1.2,
    lang = "en",

    earned = 0,
    flights = 0,
    collected = 0,
    sessionStart = os.clock(),
    afkSince = os.clock(),
    lastInput = os.clock(),
    waypoint = 0,
    status = "idle",

    balance = nil,
    prevBalance = nil,
    balanceName = nil,
    balanceDetected = false,
    lastDelta = nil,
    missedFlights = 0,
}

local farmGen = 0
local setFarmActive
local antiAfkToggle

--==============================================================
--  TEXT
--==============================================================
local L = {
    en = {
        subtitle = "AUTO FARM",
        session = "SESSION",
        controls = "CONTROLS",
        time = "Time",
        afk = "AFK",
        earned = "Collected",
        balance = "Balance",
        lastGain = "Last gain",
        rate = "Per hour",
        eta = "ETA +10k",
        flights = "Flights",
        waypoint = "Waypoint",
        farmOn = "AUTO FARM: ON",
        farmOff = "AUTO FARM: OFF",
        antiOn = "ANTI-AFK: ON",
        antiOff = "ANTI-AFK: OFF",
        delay = "Teleport delay",
    cooldown = "Cooldown between flights",
        reset = "Reset session",
        idle = "Idle",
        farming = "Farming",
        noBalance = "not found",
        noGain = "no gain detected",
        hint = "Drag the header to move · RightShift hides the menu",
        copied = "Link copied",
        langBtn = "RU",
    },
    ru = {
        subtitle = "АВТО-ФАРМ",
        session = "СЕССИЯ",
        controls = "УПРАВЛЕНИЕ",
        time = "Время",
        afk = "АФК",
        earned = "Собрано",
        balance = "Баланс",
        lastGain = "Последний прирост",
        rate = "В час",
        eta = "До +10k",
        flights = "Полётов",
        waypoint = "Точка",
        farmOn = "АВТО-ФАРМ: ВКЛ",
        farmOff = "АВТО-ФАРМ: ВЫКЛ",
        antiOn = "АНТИ-АФК: ВКЛ",
        antiOff = "АНТИ-АФК: ВЫКЛ",
        delay = "Задержка телепорта",
        cooldown = "Кулдаун между полётами",
        reset = "Сбросить сессию",
        idle = "Ожидание",
        farming = "Фармит",
        noBalance = "не найден",
        noGain = "прироста нет",
        hint = "Тяни за шапку · RightShift скрывает меню",
        copied = "Ссылка скопирована",
        langBtn = "EN",
    },
}

local function tr(key)
    local pack = L[S.lang] or L.en
    return pack[key] or key
end

--==============================================================
--  THEME
--==============================================================
local C = {
    panel = Color3.fromRGB(15, 11, 26),
    card = Color3.fromRGB(27, 20, 45),
    cardHi = Color3.fromRGB(36, 27, 60),
    track = Color3.fromRGB(48, 38, 74),
    line = Color3.fromRGB(78, 60, 124),
    purple = Color3.fromRGB(146, 92, 255),
    purple2 = Color3.fromRGB(92, 40, 210),
    pink = Color3.fromRGB(224, 74, 246),
    cyan = Color3.fromRGB(56, 214, 240),
    green = Color3.fromRGB(52, 211, 153),
    yellow = Color3.fromRGB(250, 204, 21),
    red = Color3.fromRGB(248, 113, 113),
    text = Color3.fromRGB(244, 240, 255),
    sub = Color3.fromRGB(152, 142, 188),
    dim = Color3.fromRGB(104, 94, 138),
}

local Connections = {}
local function connect(signal, fn)
    local c = signal:Connect(fn)
    Connections[#Connections + 1] = c
    return c
end

local function make(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props) do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end

local function round(parent, radius)
    return make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function stroke(parent, color, transparency, thickness)
    return make("UIStroke", {
        Color = color or C.line,
        Transparency = transparency or 0.5,
        Thickness = thickness or 1,
    }, parent)
end

local function gradient(parent, from, to, rotation)
    return make("UIGradient", {
        Color = ColorSequence.new(from, to),
        Rotation = rotation or 0,
    }, parent)
end

--==============================================================
--  GUI PARENT (CoreGui with fallback)
--==============================================================
local function getGuiParent()
    local ok, core = pcall(function()
        return game:GetService("CoreGui")
    end)
    if ok and core then
        local canWrite = pcall(function()
            local probe = Instance.new("Folder")
            probe.Parent = core
            probe:Destroy()
        end)
        if canWrite then return core end
    end
    return PlayerGui
end

local parentGui = getGuiParent()
local oldGui = parentGui:FindFirstChild("SolarFarmGui")
if oldGui then oldGui:Destroy() end

--==============================================================
--  SHELL
--==============================================================
local W, H = 344, 552

local gui = make("ScreenGui", {
    Name = "SolarFarmGui",
    ResetOnSpawn = false,
    DisplayOrder = 999,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, parentGui)

local root = make("Frame", {
    Name = "Root",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.45),
    Size = UDim2.fromOffset(W, H),
    BackgroundTransparency = 1,
    Visible = true,
    Active = true,
}, gui)

local rootScale = make("UIScale", { Scale = 1 }, root)

local function refreshScale()
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(900, 600)
    local fit = math.min((vp.X - 16) / W, (vp.Y - 16) / H)
    fit = math.clamp(fit, 0.5, 1.05)
    rootScale.Scale = fit
end

local panel = make("Frame", {
    Size = UDim2.fromOffset(W, H),
    BackgroundColor3 = C.panel,
    BackgroundTransparency = 0.18,
    BorderSizePixel = 0,
    Active = true,
    ClipsDescendants = true,
}, root)
round(panel, 18)
local panelStroke = stroke(panel, C.purple, 0.45, 1.4)
local panelGrad = gradient(panel, Color3.fromRGB(30, 21, 52), Color3.fromRGB(7, 5, 13), 120)

task.spawn(function()
    while panelGrad and panelGrad.Parent do
        TweenService:Create(panelGrad, TweenInfo.new(6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            Rotation = 160,
        }):Play()
        task.wait(6.1)
        if not panelGrad.Parent then break end
        TweenService:Create(panelGrad, TweenInfo.new(6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            Rotation = 120,
        }):Play()
        task.wait(6.1)
    end
end)

-- header
local HEADER_H = 60
local header = make("Frame", {
    Size = UDim2.new(1, 0, 0, HEADER_H),
    BackgroundTransparency = 1,
    Active = true,
}, panel)

local mark = make("Frame", {
    Position = UDim2.fromOffset(14, 13),
    Size = UDim2.fromOffset(34, 34),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0,
}, header)
round(mark, 10)
gradient(mark, C.purple, C.pink, 45)
make("TextLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Text = "★",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 17,
    Font = Enum.Font.GothamBold,
}, mark)

make("TextLabel", {
    Position = UDim2.fromOffset(58, 11),
    Size = UDim2.fromOffset(150, 20),
    BackgroundTransparency = 1,
    Text = "SOLAR",
    TextColor3 = C.text,
    TextSize = 16,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)

local subtitleLabel = make("TextLabel", {
    Position = UDim2.fromOffset(59, 30),
    Size = UDim2.fromOffset(180, 14),
    BackgroundTransparency = 1,
    Text = tr("subtitle"),
    TextColor3 = C.dim,
    TextSize = 9,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)

local statusPill = make("Frame", {
    Position = UDim2.new(1, -214, 0, 16),
    Size = UDim2.fromOffset(98, 26),
    BackgroundColor3 = C.card,
    BackgroundTransparency = 0.35,
    BorderSizePixel = 0,
}, header)
round(statusPill, 13)
stroke(statusPill, C.line, 0.55, 1)

local statusDot = make("Frame", {
    Position = UDim2.fromOffset(10, 9),
    Size = UDim2.fromOffset(8, 8),
    BackgroundColor3 = C.dim,
    BorderSizePixel = 0,
}, statusPill)
round(statusDot, 4)
local statusGlow = stroke(statusDot, C.dim, 0.5, 1)

local statusLabel = make("TextLabel", {
    Position = UDim2.fromOffset(24, 0),
    Size = UDim2.new(1, -28, 1, 0),
    BackgroundTransparency = 1,
    Text = tr("idle"),
    TextColor3 = C.sub,
    TextSize = 9,
    Font = Enum.Font.GothamMedium,
    TextXAlignment = Enum.TextXAlignment.Left,
}, statusPill)

local function headerButton(text, x, onClick)
    local b = make("TextButton", {
        Position = UDim2.new(1, x, 0, 14),
        Size = UDim2.fromOffset(32, 32),
        BackgroundColor3 = C.card,
        BackgroundTransparency = 0.25,
        Text = text,
        TextColor3 = C.text,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
    }, header)
    round(b, 9)
    stroke(b, C.line, 0.5, 1)
    connect(b.MouseEnter, function()
        TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 0 }):Play()
    end)
    connect(b.MouseLeave, function()
        TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 0.25 }):Play()
    end)
    connect(b.MouseButton1Click, onClick)
    return b
end

--==============================================================
--  DRAG
--==============================================================
local dragging, dragStart, panelStart = false, nil, nil

connect(header.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        panelStart = root.Position
    end
end)
connect(UIS.InputChanged, function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        local d = input.Position - dragStart
        root.Position = UDim2.new(
            panelStart.X.Scale, panelStart.X.Offset + d.X,
            panelStart.Y.Scale, panelStart.Y.Offset + d.Y
        )
    end
end)
connect(UIS.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

--==============================================================
--  BODY
--==============================================================
local body = make("ScrollingFrame", {
    Position = UDim2.fromOffset(12, HEADER_H + 2),
    Size = UDim2.new(1, -24, 1, -HEADER_H - 12),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = C.purple,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollingDirection = Enum.ScrollingDirection.Y,
}, panel)
pcall(function() body.AutomaticCanvasSize = Enum.AutomaticSize.Y end)
pcall(function() body.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable end)
make("UIPadding", {
    PaddingRight = UDim.new(0, 6),
}, body)
make("UIListLayout", {
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, body)

local function card(order)
    local c = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.card,
        BackgroundTransparency = 0.32,
        BorderSizePixel = 0,
        LayoutOrder = order,
    }, body)
    round(c, 14)
    stroke(c, C.line, 0.7, 1)
    make("UIPadding", {
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 12),
        PaddingBottom = UDim.new(0, 12),
    }, c)
    make("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, c)
    return c
end

local function section(parent, order, textKey)
    local holder = make("Frame", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        LayoutOrder = order,
    }, parent)
    local bar = make("Frame", {
        Position = UDim2.fromOffset(0, 2),
        Size = UDim2.fromOffset(3, 12),
        BackgroundColor3 = C.purple,
        BorderSizePixel = 0,
    }, holder)
    round(bar, 2)
    local label = make("TextLabel", {
        Position = UDim2.fromOffset(11, 0),
        Size = UDim2.new(1, -11, 1, 0),
        BackgroundTransparency = 1,
        Text = tr(textKey),
        TextColor3 = C.sub,
        TextSize = 9,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, holder)
    return label
end

local function statRow(parent, order, key, color, big)
    local row = make("Frame", {
        Size = UDim2.new(1, 0, 0, big and 34 or 24),
        BackgroundTransparency = 1,
        LayoutOrder = order,
    }, parent)

    local name = make("TextLabel", {
        Size = UDim2.new(0.45, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = tr(key),
        TextColor3 = C.sub,
        TextSize = big and 11 or 10,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local value = make("TextLabel", {
        Position = UDim2.new(0.45, 0, 0, 0),
        Size = UDim2.new(0.55, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "—",
        TextColor3 = color or C.text,
        TextSize = big and 18 or 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)

    return name, value
end

--==============================================================
--  CONTROLS
--==============================================================
local function bigButton(parent, order, onClick)
    local b = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = C.cardHi,
        BackgroundTransparency = 0.25,
        AutoButtonColor = false,
        Text = "",
        LayoutOrder = order,
    }, parent)
    round(b, 12)
    local bStroke = stroke(b, C.line, 0.6, 1.2)
    local bGrad = gradient(b, C.cardHi, C.cardHi, 20)

    local label = make("TextLabel", {
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.fromOffset(14, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = C.text,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, b)

    local dot = make("Frame", {
        Position = UDim2.new(1, -28, 0.5, -5),
        Size = UDim2.fromOffset(10, 10),
        BackgroundColor3 = C.dim,
        BorderSizePixel = 0,
    }, b)
    round(dot, 5)

    connect(b.MouseEnter, function()
        TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 0.08 }):Play()
    end)
    connect(b.MouseLeave, function()
        TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 0.25 }):Play()
    end)
    connect(b.MouseButton1Click, onClick)

    return { button = b, label = label, dot = dot, stroke = bStroke, grad = bGrad }
end

local function renderButton(api, on)
    local info = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    TweenService:Create(api.stroke, info, {
        Color = on and C.pink or C.line,
        Transparency = on and 0.25 or 0.6,
    }):Play()
    TweenService:Create(api.dot, info, { BackgroundColor3 = on and C.green or C.dim }):Play()
    api.grad.Color = ColorSequence.new(
        on and C.purple2 or C.cardHi,
        on and C.purple or C.cardHi
    )
end

local function toggleRow(parent, order, onClick)
    local row = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundColor3 = C.cardHi,
        BackgroundTransparency = 0.42,
        AutoButtonColor = false,
        Text = "",
        LayoutOrder = order,
    }, parent)
    round(row, 11)
    local rowStroke = stroke(row, C.line, 0.7, 1)

    local label = make("TextLabel", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -74, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = C.text,
        TextSize = 11,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local pill = make("Frame", {
        Position = UDim2.new(1, -56, 0.5, -13),
        Size = UDim2.fromOffset(48, 26),
        BackgroundColor3 = C.track,
        BorderSizePixel = 0,
    }, row)
    round(pill, 13)
    local pillStroke = stroke(pill, C.line, 0.5, 1)

    local knob = make("Frame", {
        Position = UDim2.fromOffset(3, 3),
        Size = UDim2.fromOffset(20, 20),
        BackgroundColor3 = Color3.fromRGB(240, 236, 250),
        BorderSizePixel = 0,
    }, pill)
    round(knob, 10)

    local state = false
    local info = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

    local api = { label = label, row = row }

    function api.render(on)
        state = on
        TweenService:Create(pill, info, { BackgroundColor3 = on and C.purple or C.track }):Play()
        TweenService:Create(knob, info, {
            Position = on and UDim2.new(1, -23, 0, 3) or UDim2.fromOffset(3, 3),
        }):Play()
        TweenService:Create(pillStroke, info, {
            Color = on and C.pink or C.line,
            Transparency = on and 0.2 or 0.5,
        }):Play()
        TweenService:Create(rowStroke, info, { Color = on and C.purple or C.line }):Play()
    end

    function api.get() return state end
    function api.set(value)
        if state == value then return end
        api.render(value)
        if onClick then onClick(value) end
    end

    connect(row.MouseButton1Click, function()
        api.set(not state)
    end)
    connect(row.MouseEnter, function()
        TweenService:Create(row, TweenInfo.new(0.12), { BackgroundTransparency = 0.2 }):Play()
    end)
    connect(row.MouseLeave, function()
        TweenService:Create(row, TweenInfo.new(0.12), { BackgroundTransparency = 0.42 }):Play()
    end)

    return api
end

local function rangeSlider(parent, order, labelKey, minValue, maxValue, defaultValue, onChange)
    local row = make("Frame", {
        Size = UDim2.new(1, 0, 0, 62),
        BackgroundTransparency = 1,
        LayoutOrder = order,
    }, parent)

    local label = make("TextLabel", {
        Size = UDim2.new(1, -70, 0, 18),
        BackgroundTransparency = 1,
        Text = tr(labelKey),
        TextColor3 = C.text,
        TextSize = 10,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local badge = make("Frame", {
        Position = UDim2.new(1, -62, 0, 0),
        Size = UDim2.fromOffset(62, 20),
        BackgroundColor3 = C.panel,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
    }, row)
    round(badge, 6)
    stroke(badge, C.purple, 0.6, 1)

    local valueText = make("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        TextColor3 = C.text,
        TextSize = 9,
        Font = Enum.Font.GothamBold,
    }, badge)

    local track = make("Frame", {
        Position = UDim2.fromOffset(0, 40),
        Size = UDim2.new(1, 0, 0, 7),
        BackgroundColor3 = C.track,
        BorderSizePixel = 0,
    }, row)
    round(track, 4)

    local fill = make("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = C.purple,
        BorderSizePixel = 0,
    }, track)
    round(fill, 4)
    gradient(fill, C.purple, C.pink)

    local knob = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(22, 22),
        BackgroundColor3 = Color3.fromRGB(250, 248, 255),
        BorderSizePixel = 0,
        ZIndex = 4,
    }, track)
    round(knob, 11)
    stroke(knob, C.purple, 0.05, 2)

    -- tall hit area is important for touch
    local hit = make("TextButton", {
        Position = UDim2.fromOffset(-10, 24),
        Size = UDim2.new(1, 20, 0, 34),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 5,
    }, row)

    local MIN, MAX = minValue, maxValue

    local function apply(value, fire)
        value = math.clamp(value, MIN, MAX)
        local p = (value - MIN) / (MAX - MIN)
        knob.Position = UDim2.new(p, 0, 0.5, 0)
        fill.Size = UDim2.new(p, 0, 1, 0)
        valueText.Text = string.format("%.2f s", value)
        if fire and onChange then
            onChange(value)
        end
    end

    local sliding = false
    local function fromInput(input)
        local rel = (input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
        apply(MIN + (MAX - MIN) * math.clamp(rel, 0, 1), true)
    end

    connect(hit.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            fromInput(input)
        end
    end)
    connect(UIS.InputChanged, function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            fromInput(input)
        end
    end)
    connect(UIS.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)

    apply(defaultValue, false)
    return { label = label, set = function(v) apply(v, true) end }
end

--==============================================================
--  LAYOUT
--==============================================================
local sessionCard = card(1)
local sessionSection = section(sessionCard, 1, "session")

local timeName, timeValue = statRow(sessionCard, 2, "time", C.text, true)
local afkName, afkValue = statRow(sessionCard, 3, "afk", C.cyan, false)
local earnedName, earnedValue = statRow(sessionCard, 4, "earned", C.yellow, true)
local balanceName, balanceValue = statRow(sessionCard, 5, "balance", C.green, true)
local gainName, gainValue = statRow(sessionCard, 6, "lastGain", C.cyan, false)
local rateName, rateValue = statRow(sessionCard, 7, "rate", C.purple, false)
local etaName, etaValue = statRow(sessionCard, 8, "eta", Color3.fromRGB(255, 150, 100), false)
local flightsName, flightsValue = statRow(sessionCard, 9, "flights", C.sub, false)
local wpName, wpValue = statRow(sessionCard, 10, "waypoint", C.sub, false)

local controlsCard = card(2)
local controlsSection = section(controlsCard, 1, "controls")

local farmBtn = bigButton(controlsCard, 2, function()
    setFarmActive(not S.active)
end)

antiAfkToggle = toggleRow(controlsCard, 3, function(value)
    S.antiAfk = value
    if antiAfkToggle then
        antiAfkToggle.label.Text = value and tr("antiOn") or tr("antiOff")
    end
end)
antiAfkToggle.render(S.antiAfk)
antiAfkToggle.label.Text = S.antiAfk and tr("antiOn") or tr("antiOff")

local delayControl = rangeSlider(controlsCard, 4, "delay", 0.2, 1, S.delay, function(value)
    S.delay = value
end)

local cooldownControl = rangeSlider(controlsCard, 5, "cooldown", 1, 3, S.cooldown, function(value)
    S.cooldown = value
end)

local resetBtn = bigButton(controlsCard, 6, function()
    S.earned = 0
    S.flights = 0
    S.collected = 0
    S.sessionStart = os.clock()
    S.prevBalance = S.balance
    S.lastDelta = nil
    S.missedFlights = 0
    S.lastInput = os.clock()
end)
resetBtn.label.Text = tr("reset")
resetBtn.dot.Visible = false
farmBtn.label.Text = tr("farmOff")

local footer = make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 18),
    BackgroundTransparency = 1,
    Text = tr("hint"),
    TextColor3 = C.dim,
    TextSize = 8,
    Font = Enum.Font.Gotham,
    LayoutOrder = 3,
    TextWrapped = true,
}, body)

--==============================================================
--  HELPERS
--==============================================================
local function hms(seconds)
    seconds = math.max(0, math.floor(seconds))
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function shortTime(seconds)
    if seconds <= 0 or seconds > 359999 then return "--:--" end
    seconds = math.floor(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then return string.format("%dh %02dm", h, m) end
    return string.format("%02dm %02ds", m, s)
end

local function fmtNumber(value)
    local n = math.floor(value or 0)
    local s = tostring(n)
    local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
    return (out:gsub("^%s+", ""))
end

local function isMoneyName(name)
    local n = name:lower()
    return n:find("gold") or n:find("coin") or n:find("money")
        or n:find("cash") or n:find("dollar") or n:find("balance")
        or n:find("gem") or n:find("credit")
end

-- Все числовые статы, которые вообще можно прочитать у игрока.
-- Ключ — сам объект, чтобы отслеживать его значение между полётами.
local function collectNumericStats()
    local list = {}
    local seen = {}

    local function push(obj, priority)
        if seen[obj] then return end
        if not (obj:IsA("IntValue") or obj:IsA("NumberValue")) then return end
        local val = tonumber(obj.Value)
        if not val then return end
        seen[obj] = true
        list[#list + 1] = { obj = obj, value = val, priority = priority, name = obj.Name }
    end

    local stats = LP:FindFirstChild("leaderstats")
    if stats then
        for _, stat in ipairs(stats:GetChildren()) do
            push(stat, isMoneyName(stat.Name) and 2 or 1)
        end
    end

    for _, folder in ipairs(LP:GetChildren()) do
        if folder:IsA("Folder") or folder:IsA("Configuration") then
            for _, stat in ipairs(folder:GetChildren()) do
                push(stat, isMoneyName(stat.Name) and 2 or 0)
            end
        end
    end

    return list
end

-- Главный «денежный» стат: приоритет у имени, иначе самый крупный.
local function pickCurrency(list)
    local best = nil
    for _, entry in ipairs(list) do
        if entry.priority == 2 then
            if not best or entry.value > best.value then best = entry end
        end
    end
    if best then return best end
    for _, entry in ipairs(list) do
        if not best or entry.value > best.value then best = entry end
    end
    return best
end

-- Снимок всех статов: { [obj] = value }
local function snapshot()
    local snap = {}
    for _, entry in ipairs(collectNumericStats()) do
        snap[entry.obj] = entry.value
    end
    return snap
end

-- Ищем, какой стат реально вырос после полёта.
-- Возвращает name, delta, newValue или nil, если прироста не было.
local function diffSnapshot(before)
    local candidates = {}
    for _, entry in ipairs(collectNumericStats()) do
        local old = before[entry.obj]
        if old ~= nil then
            local delta = entry.value - old
            if delta > 0 then
                candidates[#candidates + 1] = {
                    name = entry.name,
                    delta = delta,
                    value = entry.value,
                    priority = entry.priority,
                }
            end
        end
    end

    if #candidates == 0 then return nil end

    local best = nil
    for _, c in ipairs(candidates) do
        if not best then
            best = c
        elseif c.priority > best.priority then
            best = c
        elseif c.priority == best.priority and c.delta > best.delta then
            best = c
        end
    end
    return best
end

-- Текущий баланс без выдумок: только реальный стат или nil.
local function getPlayerBalance()
    local entry = pickCurrency(collectNumericStats())
    if entry then return entry.value, entry.name end
    return nil, nil
end

local function getRoot()
    local ch = LP.Character
    if not ch then return nil, nil end
    return ch:FindFirstChild("HumanoidRootPart"), ch:FindFirstChildOfClass("Humanoid")
end

--==============================================================
--  FARM LOOP
--==============================================================
local function farmLoop(gen)
    while S.active and gen == farmGen do
        local char = LP.Character
        if not char then
            local ok = false
            task.spawn(function()
                LP.CharacterAdded:Wait()
                ok = true
            end)
            local t = 0
            while not ok and t < 2 and S.active and gen == farmGen do
                task.wait(0.05)
                t = t + 0.05
            end
            char = LP.Character
        end

        local root = char and char:WaitForChild("HumanoidRootPart", 2)
        if not root then
            task.wait(0.15)
        else
            -- снимок баланса ДО полёта
            local before = snapshot()
            local startBalance = pickCurrency(collectNumericStats())
            if startBalance then
                S.balance = startBalance.value
                S.balanceName = startBalance.name
                S.balanceDetected = true
            end

            for i, pos in ipairs(WAYPOINTS) do
                if not S.active or gen ~= farmGen then return end
                S.waypoint = i

                local hold = S.delay + (i == #WAYPOINTS and 0.25 or 0)
                local t = 0
                while t < hold do
                    if not S.active or gen ~= farmGen then return end
                    if not root.Parent then break end
                    root.CFrame = CFrame.new(pos)
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    task.wait(0.02)
                    t = t + 0.02
                end
            end

            if not S.active or gen ~= farmGen then return end

            S.flights = S.flights + 1

            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                pcall(function() hum.Health = 0 end)
            end
            pcall(function() LP:LoadCharacter() end)

            -- быстрый опрос награды: интервал 0.05 с, лимит — кулдаун
            local result = nil
            local waited = 0
            while waited < S.cooldown and S.active and gen == farmGen do
                result = diffSnapshot(before)
                if result then break end
                task.wait(0.05)
                waited = waited + 0.05
            end

            if result then
                local prev = result.value - result.delta
                S.earned = S.earned + result.delta
                S.collected = S.earned
                S.prevBalance = prev
                S.balance = result.value
                S.balanceName = result.name
                S.lastDelta = result.delta
                S.balanceDetected = true
                S.missedFlights = 0
            else
                S.missedFlights = S.missedFlights + 1
                S.lastDelta = nil
                local current = pickCurrency(collectNumericStats())
                if current then
                    S.balance = current.value
                    S.balanceName = current.name
                end
            end

            -- остаток кулдауна: весь интервал между полётами = S.cooldown
            while waited < S.cooldown and S.active and gen == farmGen do
                task.wait(0.05)
                waited = waited + 0.05
            end
        end
    end
end

setFarmActive = function(value)
    if S.active == value then return end
    S.active = value
    farmGen = farmGen + 1

    if value then
        local current, name = getPlayerBalance()
        if current then
            S.balance = current
            S.prevBalance = current
            S.balanceName = name
            S.balanceDetected = true
        else
            S.balanceDetected = false
        end
        S.waypoint = 0
        local gen = farmGen
        task.spawn(function() farmLoop(gen) end)
    else
        S.waypoint = 0
    end

    renderButton(farmBtn, value)
    farmBtn.label.Text = value and tr("farmOn") or tr("farmOff")
    statusLabel.Text = value and tr("farming") or tr("idle")
    statusLabel.TextColor3 = value and C.green or C.sub
    statusDot.BackgroundColor3 = value and C.green or C.dim
    statusGlow.Color = value and C.green or C.dim
end

--==============================================================
--  ANTI-AFK
--==============================================================
local afkConnection
local function refreshAntiAfk()
    if afkConnection then
        afkConnection:Disconnect()
        afkConnection = nil
    end
    if not S.antiAfk then return end

    afkConnection = LP.Idled:Connect(function()
        pcall(function()
            local cam = workspace.CurrentCamera
            VirtualUser:Button2Down(Vector2.zero, cam and cam.CFrame or CFrame.new())
            task.wait(1)
            VirtualUser:Button2Up(Vector2.zero, cam and cam.CFrame or CFrame.new())
        end)
    end)
end

refreshAntiAfk()

local function nudge()
    pcall(function()
        local cam = workspace.CurrentCamera
        VirtualUser:Button2Down(Vector2.zero, cam and cam.CFrame or CFrame.new())
        task.wait(0.4)
        VirtualUser:Button2Up(Vector2.zero, cam and cam.CFrame or CFrame.new())
    end)
end

task.spawn(function()
    while gui and gui.Parent do
        task.wait(45)
        if S.antiAfk and (os.clock() - S.lastInput) > 40 then
            nudge()
        end
    end
end)

--==============================================================
--  ACTIVITY TRACKING
--==============================================================
local function markActivity()
    S.lastInput = os.clock()
end
connect(UIS.InputBegan, markActivity)
connect(UIS.InputChanged, markActivity)
connect(UIS.TouchTap, markActivity)

--==============================================================
--  HEADER BUTTONS
--==============================================================
local minimized = false
local langButton

local function applyLanguage()
    subtitleLabel.Text = tr("subtitle")
    sessionSection.Text = tr("session")
    controlsSection.Text = tr("controls")

    timeName.Text = tr("time")
    afkName.Text = tr("afk")
    earnedName.Text = tr("earned")
    balanceName.Text = tr("balance")
    gainName.Text = tr("lastGain")
    rateName.Text = tr("rate")
    etaName.Text = tr("eta")
    flightsName.Text = tr("flights")
    wpName.Text = tr("waypoint")

    farmBtn.label.Text = S.active and tr("farmOn") or tr("farmOff")
    antiAfkToggle.label.Text = S.antiAfk and tr("antiOn") or tr("antiOff")
    delayControl.label.Text = tr("delay")
    cooldownControl.label.Text = tr("cooldown")
    resetBtn.label.Text = tr("reset")
    footer.Text = tr("hint")
    statusLabel.Text = S.active and tr("farming") or tr("idle")
    if langButton then langButton.Text = tr("langBtn") end
end

local function setMinimized(value)
    minimized = value
    body.Visible = not value
    TweenService:Create(panel, TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(W, value and HEADER_H or H),
    }):Play()
    if not value then
        task.delay(0.1, function()
            if not minimized then body.Visible = true end
        end)
    end
end

langButton = headerButton("RU", -110, function()
    S.lang = (S.lang == "en") and "ru" or "en"
    applyLanguage()
end)

local minButton
minButton = headerButton("–", -76, function()
    setMinimized(not minimized)
    minButton.Text = minimized and "+" or "–"
end)

local cleanup
headerButton("×", -42, function()
    if cleanup then cleanup() end
end)

--==============================================================
--  LIVE STATS
--==============================================================
local balanceClock = 0
local pulseClock = 0

task.spawn(function()
    while gui and gui.Parent do
        local elapsed = os.clock() - S.sessionStart
        local afk = os.clock() - S.lastInput

        timeValue.Text = hms(elapsed)
        afkValue.Text = hms(afk)
        earnedValue.Text = fmtNumber(S.earned)
        flightsValue.Text = tostring(S.flights)
        wpValue.Text = S.waypoint > 0
            and (S.waypoint .. " / " .. #WAYPOINTS)
            or "—"

        local rate = elapsed > 1 and (S.earned / elapsed * 3600) or 0
        rateValue.Text = fmtNumber(rate)

        if rate > 0 then
            local remaining = math.max(0, TARGET_GAIN - S.earned)
            etaValue.Text = shortTime(remaining / rate * 3600)
        else
            etaValue.Text = "--:--"
        end

        -- баланс: показываем реальное значение и откуда поднялись
        balanceClock = balanceClock + 0.25
        if balanceClock >= 1 then
            balanceClock = 0
            local current, name = getPlayerBalance()
            if current then
                S.balance = current
                S.balanceName = name
                S.balanceDetected = true
            end
        end

        if S.balanceDetected and S.balance then
            balanceValue.Text = fmtNumber(S.balance)
            balanceValue.TextColor3 = C.green
        else
            balanceValue.Text = tr("noBalance")
            balanceValue.TextColor3 = C.dim
        end

        if S.lastDelta then
            local from = S.prevBalance or (S.balance and (S.balance - S.lastDelta))
            gainValue.Text = string.format(
                "+%s  (%s → %s)",
                fmtNumber(S.lastDelta),
                fmtNumber(from),
                fmtNumber(S.balance)
            )
            gainValue.TextColor3 = C.cyan
        elseif S.missedFlights > 0 then
            gainValue.Text = tr("noGain")
            gainValue.TextColor3 = C.red
        else
            gainValue.Text = "—"
            gainValue.TextColor3 = C.dim
        end

        pulseClock = pulseClock + 0.25
        if pulseClock >= 0.5 then
            pulseClock = 0
            local color = S.active and C.green or C.dim
            statusDot.BackgroundColor3 = color
            statusGlow.Color = color
        end

        task.wait(0.25)
    end
end)

--==============================================================
--  CLOSE / CLEANUP
--==============================================================
cleanup = function()
    S.active = false
    farmGen = farmGen + 1
    if afkConnection then afkConnection:Disconnect() end
    for _, c in ipairs(Connections) do
        pcall(function() c:Disconnect() end)
    end
    Connections = {}
    if gui then gui:Destroy() end
    env.SolarFarmCleanup = nil
end
env.SolarFarmCleanup = cleanup

connect(UIS.InputBegan, function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        root.Visible = not root.Visible
    end
end)

--==============================================================
--  BOOT ANIMATION
--==============================================================
refreshScale()
local cam = workspace.CurrentCamera
if cam then
    connect(cam:GetPropertyChangedSignal("ViewportSize"), refreshScale)
end
connect(workspace:GetPropertyChangedSignal("CurrentCamera"), function()
    local c = workspace.CurrentCamera
    if c then
        c:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScale)
    end
    refreshScale()
end)

local finalScale = rootScale.Scale
rootScale.Scale = finalScale * 0.92
panel.BackgroundTransparency = 1
panelStroke.Transparency = 1
TweenService:Create(rootScale, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Scale = finalScale,
}):Play()
TweenService:Create(panel, TweenInfo.new(0.35, Enum.EasingStyle.Quint), {
    BackgroundTransparency = 0.18,
}):Play()
TweenService:Create(panelStroke, TweenInfo.new(0.4), {
    Transparency = 0.45,
}):Play()

applyLanguage()
print("[Solar] Auto Farm v1 loaded")