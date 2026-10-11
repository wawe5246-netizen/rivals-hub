-- Lua | Rivals Hub | Redesign — amber sidebar nav
-- executor: Medium / KRNL / Synapse / Solara

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local CAS              = game:GetService("ContextActionService")
local Camera           = game:GetService("Workspace").CurrentCamera
local LP               = Players.LocalPlayer
local Mouse            = LP:GetMouse()
local ESC_ACTION       = "RivalsHub_ESC"
-- fix workspace ref supaya executor environment tak reject
local workspace        = game:GetService("Workspace")

-- ══════════════════════════════════
--  SHARED CFG
-- ══════════════════════════════════
local CFG = {
    highlightESP   = true,
    nameESP        = true,
    healthESP      = true,
    teamCheck      = true,
    aimbot         = true,
    requireVisible = true,
    aimbotHoldMode = true,   -- true = hold key | false = press to toggle
    showFOV        = true,
    bhop           = false,
    infJump        = false,
    noClip         = false,
    tpBehind       = false,
    autoBurst      = false,  -- controlled M1 fire supaya heat tak overflow
    burstInterval  = 0.12,   -- seconds between shots (tunable)
    smoothness     = 0.18,
    fovRadius      = 400,
}

local BINDS = {
    aimbot       = Enum.KeyCode.E,
    esp          = Enum.KeyCode.F1,
    aimbotToggle = Enum.KeyCode.F2,
    misc         = Enum.KeyCode.F3,
}

local function isHeld(bind)
    if typeof(bind) ~= "EnumItem" then return false end
    if bind.EnumType == Enum.KeyCode then
        return UserInputService:IsKeyDown(bind)
    elseif bind.EnumType == Enum.UserInputType then
        return UserInputService:IsMouseButtonPressed(bind)
    end
    return false
end
local function bindName(b)
    if typeof(b) ~= "EnumItem" then return "?" end
    if b.EnumType == Enum.KeyCode then return b.Name end
    if b == Enum.UserInputType.MouseButton1 then return "M1" end
    if b == Enum.UserInputType.MouseButton2 then return "M2" end
    if b == Enum.UserInputType.MouseButton3 then return "M3" end
    return b.Name
end
local function bindMatches(bind, inp)
    if typeof(bind) ~= "EnumItem" then return false end
    if bind.EnumType == Enum.KeyCode then return inp.KeyCode == bind end
    if bind.EnumType == Enum.UserInputType then return inp.UserInputType == bind end
    return false
end

local miscOn             = false
local aimbotToggleActive = false  -- latch untuk toggle mode
local autoBurstHeld      = false  -- M1 physical ditekan
local burstRunning       = false  -- loop aktif
local burstReleasing     = false  -- kita yang release, bukan player

-- ══════════════════════════════════
--  COLOUR TOKENS — warm amber redesign
-- ══════════════════════════════════
local C = {
    bg       = Color3.fromRGB(17,  16,  16),   -- window bg
    navBg    = Color3.fromRGB(13,  12,  11),   -- sidebar darker
    surface  = Color3.fromRGB(28,  27,  25),   -- card / hover
    border   = Color3.fromRGB(31,  30,  28),   -- separator
    border2  = Color3.fromRGB(42,  40,  37),   -- keybind stroke
    accent   = Color3.fromRGB(232, 184,  75),  -- amber
    accentBg = Color3.fromRGB(40,  32,  10),   -- accent tinted bg
    textPri  = Color3.fromRGB(200, 196, 190),  -- primary text
    textSec  = Color3.fromRGB(122, 117, 113),  -- secondary text
    textMut  = Color3.fromRGB(61,   60,  57),  -- muted / inactive
    on       = Color3.fromRGB(17,  16,  16),   -- thumb when ON (dark on amber)
    success  = Color3.fromRGB(76,  175, 130),  -- status dot
}
local FONT  = Enum.Font.GothamMedium
local FONTS = Enum.Font.Gotham
local FONTB = Enum.Font.GothamBold

-- ══════════════════════════════════
--  UI HELPERS
-- ══════════════════════════════════
local function make(cls, props, parent)
    local o = Instance.new(cls)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end
local function corner(r, p) make("UICorner",  {CornerRadius = UDim.new(0, r)}, p) end
local function stroke(t, c, p) make("UIStroke", {Thickness = t, Color = c, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, p) end
local function pad(t, r, b, l, p) make("UIPadding", {PaddingTop = UDim.new(0,t), PaddingRight = UDim.new(0,r), PaddingBottom = UDim.new(0,b), PaddingLeft = UDim.new(0,l)}, p) end
local function lbl(txt, fs, font, col, p)
    return make("TextLabel", {Text = txt, TextSize = fs, Font = font, TextColor3 = col, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.XY}, p)
end
local function tw(o, t, props) TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad), props):Play() end
local function anchor(o, ax, ay) o.AnchorPoint = Vector2.new(ax, ay) end

-- ══════════════════════════════════
--  SIZES — all pixel, no scale drift
-- ══════════════════════════════════
-- window
local WIN_W   = 260
local WIN_H   = 420
local HDR_H   = 36   -- header
local FTR_H   = 26   -- footer
local NAV_W   = 44   -- sidebar nav width
local BODY_H  = WIN_H - HDR_H - FTR_H  -- 358

-- ══════════════════════════════════
--  BUILD GUI
-- ══════════════════════════════════
-- cuba semua cara parent GUI — gethui > CoreGui > PlayerGui
local safeGui
if typeof(gethui) == "function" then
    local ok, h = pcall(gethui)
    if ok and h then safeGui = h end
end
if not safeGui then
    local ok, h = pcall(function() return game:GetService("CoreGui") end)
    if ok and h then safeGui = h end
end
if not safeGui then
    safeGui = LP.PlayerGui
end
print("[RivalsHub] parenting ke: " .. tostring(safeGui))

-- remove any stale instance from a previous execute
for _, loc in ipairs({
    LP.PlayerGui,
    game:GetService("CoreGui"),
    typeof(gethui) == "function" and (pcall(gethui) and gethui() or nil) or nil
}) do
    if loc then
        local old = loc:FindFirstChild("RivalsHub")
        if old then old:Destroy() end
    end
end

local gui = make("ScreenGui", {
    Name           = "RivalsHub",
    ResetOnSpawn   = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,   -- sit above the topbar inset
    DisplayOrder   = 999,    -- on top of every other ScreenGui
}, safeGui)

local win = make("Frame", {
    Size             = UDim2.new(0, WIN_W, 0, WIN_H),
    Position         = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2),
    BackgroundColor3 = C.bg,
    Active           = true,
    ClipsDescendants = true,
}, gui)
corner(10, win)
stroke(0.5, C.border, win)

-- drag header
local dragging, dragStart, startPos
win.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging  = true
        dragStart = i.Position
        startPos  = win.Position
    end
end)
win.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - dragStart
        win.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

-- ── header ──────────────────────────────────────────────
local hdr = make("Frame", {
    Size             = UDim2.new(1, 0, 0, HDR_H),
    Position         = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = C.bg,
    BorderSizePixel  = 0,
}, win)

-- accent dot
local hdot = make("Frame", {
    Size             = UDim2.new(0, 6, 0, 6),
    Position         = UDim2.new(0, 13, 0.5, 0),
    BackgroundColor3 = C.accent,
}, hdr)
anchor(hdot, 0, 0.5); corner(4, hdot)

-- title
local titleLbl = make("TextLabel", {
    Text              = "rivals.hub",
    TextSize          = 11,
    Font              = FONT,
    TextColor3        = C.textSec,
    BackgroundTransparency = 1,
    Position          = UDim2.new(0, 25, 0.5, 0),
    Size              = UDim2.new(0, 120, 0, 14),
    TextXAlignment    = Enum.TextXAlignment.Left,
}, hdr)
anchor(titleLbl, 0, 0.5)

-- close button
local closeBtn = make("TextButton", {
    Size             = UDim2.new(0, 18, 0, 18),
    Position         = UDim2.new(1, -11, 0.5, 0),
    BackgroundColor3 = C.surface,
    Text             = "×",
    TextSize         = 14,
    Font             = FONTB,
    TextColor3       = C.textMut,
    AutoButtonColor  = false,
}, hdr)
anchor(closeBtn, 1, 0.5); corner(4, closeBtn)
closeBtn.MouseEnter:Connect(function() tw(closeBtn, 0.1, {TextColor3 = C.textSec}) end)
closeBtn.MouseLeave:Connect(function() tw(closeBtn, 0.1, {TextColor3 = C.textMut}) end)
closeBtn.MouseButton1Click:Connect(function()
    Camera.CameraType = Enum.CameraType.Custom
    CAS:UnbindAction(ESC_ACTION)   -- release ESC back to Roblox on close
    gui:Destroy()
end)

-- header bottom border
make("Frame", {
    Size             = UDim2.new(1, 0, 0, 1),
    Position         = UDim2.new(0, 0, 1, -1),
    BackgroundColor3 = C.border,
    BorderSizePixel  = 0,
}, hdr)

-- ── footer / status bar ─────────────────────────────────
local footer = make("Frame", {
    Size             = UDim2.new(1, 0, 0, FTR_H),
    Position         = UDim2.new(0, 0, 1, -FTR_H),
    BackgroundColor3 = C.bg,
    BorderSizePixel  = 0,
    ZIndex           = 2,
}, win)
make("Frame", {
    Size             = UDim2.new(1, 0, 0, 1),
    Position         = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = C.border,
    BorderSizePixel  = 0,
}, footer)

local sdot = make("Frame", {
    Size             = UDim2.new(0, 5, 0, 5),
    Position         = UDim2.new(0, 13, 0.5, 0),
    BackgroundColor3 = C.success,
}, footer)
anchor(sdot, 0, 0.5); corner(3, sdot)

local statusLbl = make("TextLabel", {
    Text           = "5 active",
    TextSize       = 10,
    Font           = FONT,
    TextColor3     = C.textMut,
    BackgroundTransparency = 1,
    Position       = UDim2.new(0, 24, 0.5, 0),
    Size           = UDim2.new(0, 80, 0, 14),
    TextXAlignment = Enum.TextXAlignment.Left,
}, footer)
anchor(statusLbl, 0, 0.5)

local creditLbl = make("TextLabel", {
    Text           = "by olivia",
    TextSize       = 9,
    Font           = FONTS,
    TextColor3     = Color3.fromRGB(42, 40, 37),
    BackgroundTransparency = 1,
    Position       = UDim2.new(1, -13, 0.5, 0),
    Size           = UDim2.new(0, 60, 0, 14),
    TextXAlignment = Enum.TextXAlignment.Right,
}, footer)
anchor(creditLbl, 1, 0.5)

local function updateStatus()
    local on = 0
    for _, v in pairs(CFG) do if v == true then on = on + 1 end end
    statusLbl.Text = on .. " active"
end

-- ── body container (between header and footer) ──────────
-- sidebar nav on left, panels fill the rest
local bodyFrame = make("Frame", {
    Size             = UDim2.new(1, 0, 0, BODY_H),
    Position         = UDim2.new(0, 0, 0, HDR_H),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
}, win)

-- ── sidebar nav ─────────────────────────────────────────
local navFrame = make("Frame", {
    Size             = UDim2.new(0, NAV_W, 1, 0),
    Position         = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = C.navBg,
    BorderSizePixel  = 0,
}, bodyFrame)

-- nav right border
make("Frame", {
    Size             = UDim2.new(0, 1, 1, 0),
    Position         = UDim2.new(1, -1, 0, 0),
    BackgroundColor3 = C.border,
    BorderSizePixel  = 0,
}, navFrame)

-- nav separator line between top icons and Keys
local function navSep(ypos)
    local f = make("Frame", {
        Size             = UDim2.new(0, 22, 0, 1),
        Position         = UDim2.new(0.5, 0, 0, ypos),
        BackgroundColor3 = C.border,
        BorderSizePixel  = 0,
    }, navFrame)
    anchor(f, 0.5, 0)
end

-- ── scroll panels (right of nav) ────────────────────────
local panelHost = make("Frame", {
    Size             = UDim2.new(1, -NAV_W, 1, 0),
    Position         = UDim2.new(0, NAV_W, 0, 0),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
}, bodyFrame)

-- ══════════════════════════════════
--  TAB SYSTEM
-- ══════════════════════════════════
local TABS = {"ESP", "Aimbot", "Misc", "Keys"}

-- icon characters — unicode that Roblox's Gotham renders fine
-- ◉ crosshair-ish, ✦ aim, ⚡ misc, ⌨ keys
local NAV_ICONS = {
    ESP    = "◉",
    Aimbot = "✦",
    Misc   = "⚡",
    Keys   = "⌨",
}

local panels   = {}
local navBtns  = {}
local navLines = {}

local function activateTab(name)
    for _, n in ipairs(TABS) do
        navBtns[n].TextColor3  = C.textMut
        navBtns[n].Font        = FONTS
        navLines[n].Visible    = false
        panels[n].Visible      = false
    end
    navBtns[name].TextColor3 = C.accent
    navBtns[name].Font       = FONTB
    navLines[name].Visible   = true
    panels[name].Visible     = true
end

-- Y positions for nav buttons: 10px top padding, 38px per slot
local NAV_SLOT_H = 42
local NAV_SLOTS  = {ESP=0, Aimbot=1, Misc=2, Keys=3}

-- separator between Misc(2) and Keys(3): after slot 2
navSep(10 + NAV_SLOT_H * 3 - 5)  -- placed after Misc

for i, name in ipairs(TABS) do
    local slotIdx = NAV_SLOTS[name]

    -- active indicator bar (left edge, amber)
    local bar = make("Frame", {
        Size             = UDim2.new(0, 2, 0, 16),
        Position         = UDim2.new(0, 0, 0, 10 + slotIdx * NAV_SLOT_H + (NAV_SLOT_H - 16) / 2),
        BackgroundColor3 = C.accent,
        BorderSizePixel  = 0,
        Visible          = false,
    }, navFrame)
    corner(2, bar)
    navLines[name] = bar

    -- nav button
    local btn = make("TextButton", {
        Size             = UDim2.new(0, NAV_W - 2, 0, 34),
        Position         = UDim2.new(0, 1, 0, 10 + slotIdx * NAV_SLOT_H + 4),
        BackgroundColor3 = C.navBg,
        Text             = NAV_ICONS[name],
        TextSize         = 16,
        Font             = FONTS,
        TextColor3       = C.textMut,
        BorderSizePixel  = 0,
        AutoButtonColor  = false,
    }, navFrame)
    corner(6, btn)

    btn.MouseEnter:Connect(function()
        if navBtns[name].TextColor3 ~= C.accent then
            tw(btn, 0.1, {BackgroundColor3 = C.surface, TextColor3 = C.textSec})
        end
    end)
    btn.MouseLeave:Connect(function()
        if navBtns[name].TextColor3 ~= C.accent then
            tw(btn, 0.1, {BackgroundColor3 = C.navBg, TextColor3 = C.textMut})
        end
    end)
    btn.MouseButton1Click:Connect(function()
        -- reset all non-active hover states
        for _, n in ipairs(TABS) do
            tw(navBtns[n], 0.1, {BackgroundColor3 = C.navBg})
        end
        tw(btn, 0.1, {BackgroundColor3 = C.accentBg})
        activateTab(name)
    end)

    navBtns[name] = btn

    -- scroll panel for this tab
    local panel = make("ScrollingFrame", {
        Size                = UDim2.new(1, 0, 1, 0),
        Position            = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        ScrollBarThickness  = 2,
        ScrollBarImageColor3 = C.border2,
        CanvasSize          = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        BorderSizePixel     = 0,
        Visible             = false,
    }, panelHost)
    make("UIListLayout", {
        SortOrder  = Enum.SortOrder.LayoutOrder,
        Padding    = UDim.new(0, 0),
    }, panel)
    panels[name] = panel
end

-- activate first tab
activateTab("ESP")
tw(navBtns["ESP"], 0, {BackgroundColor3 = C.accentBg})

-- ══════════════════════════════════
--  ROW BUILDERS
-- ══════════════════════════════════
local function secLbl(p, txt, ord)
    local fr = make("Frame", {
        Size              = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        LayoutOrder       = ord,
    }, p)
    pad(0, 12, 0, 12, fr)
    local l = make("TextLabel", {
        Text           = txt,
        TextSize       = 9,
        Font           = FONTB,
        TextColor3     = C.textMut,
        BackgroundTransparency = 1,
        Position       = UDim2.new(0, 0, 1, 0),
        Size           = UDim2.new(1, 0, 0, 12),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, fr)
    anchor(l, 0, 1)
end

local function toggleRow(p, name, sub, key, ord)
    local row = make("Frame", {
        Size              = UDim2.new(1, 0, 0, 38),
        BackgroundColor3  = C.bg,
        BorderSizePixel   = 0,
        LayoutOrder       = ord,
    }, p)

    -- top separator
    make("Frame", {
        Size             = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = C.border,
        BorderSizePixel  = 0,
    }, row)

    local inner = make("Frame", {
        Size             = UDim2.new(1, 0, 0, 37),
        Position         = UDim2.new(0, 0, 0, 1),
        BackgroundTransparency = 1,
    }, row)
    pad(0, 12, 0, 12, inner)

    -- text left side
    local lf = make("Frame", {
        Size             = UDim2.new(1, -40, 1, 0),
        BackgroundTransparency = 1,
    }, inner)
    make("UIListLayout", {
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding           = UDim.new(0, 2),
    }, lf)
    make("TextLabel", {
        Text           = name,
        TextSize       = 11,
        Font           = FONT,
        TextColor3     = C.textPri,
        BackgroundTransparency = 1,
        Size           = UDim2.new(1, 0, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, lf)
    if sub then
        make("TextLabel", {
            Text           = sub,
            TextSize       = 9,
            Font           = FONTS,
            TextColor3     = C.textSec,
            BackgroundTransparency = 1,
            Size           = UDim2.new(1, 0, 0, 12),
            TextXAlignment = Enum.TextXAlignment.Left,
        }, lf)
    end

    -- pill toggle
    local pill = make("Frame", {
        Size             = UDim2.new(0, 28, 0, 15),
        Position         = UDim2.new(1, -28, 0.5, 0),
        BackgroundColor3 = CFG[key] and C.accent or C.border2,
    }, inner)
    anchor(pill, 0, 0.5); corner(8, pill)

    local thumb = make("Frame", {
        Size             = UDim2.new(0, 11, 0, 11),
        BackgroundColor3 = CFG[key] and C.on or C.textMut,
        Position         = CFG[key] and UDim2.new(1, -13, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
    }, pill)
    anchor(thumb, 0, 0.5); corner(6, thumb)

    -- hover tint via a child Frame
    local hoverBg = make("Frame", {
        Size             = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
        BorderSizePixel  = 0,
        ZIndex           = row.ZIndex,
    }, inner)

    row.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement then
            tw(hoverBg, 0.1, {BackgroundTransparency = 0.96})
        end
    end)
    row.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement then
            tw(hoverBg, 0.1, {BackgroundTransparency = 1})
        end
    end)

    pill.InputBegan:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        CFG[key] = not CFG[key]
        tw(pill,  0.12, {BackgroundColor3 = CFG[key] and C.accent or C.border2})
        tw(thumb, 0.12, {
            BackgroundColor3 = CFG[key] and C.on or C.textMut,
            Position         = CFG[key] and UDim2.new(1, -13, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
        })
        updateStatus()
    end)
end

local function sliderRow(p, name, key, min, max, dp, ord)
    local row = make("Frame", {
        Size              = UDim2.new(1, 0, 0, 50),
        BackgroundColor3  = C.bg,
        BorderSizePixel   = 0,
        LayoutOrder       = ord,
    }, p)
    make("Frame", {
        Size             = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = C.border,
        BorderSizePixel  = 0,
    }, row)

    local inner = make("Frame", {
        Size     = UDim2.new(1, 0, 0, 49),
        Position = UDim2.new(0, 0, 0, 1),
        BackgroundTransparency = 1,
    }, row)
    pad(9, 12, 10, 12, inner)
    make("UIListLayout", {Padding = UDim.new(0, 7)}, inner)

    -- top row: label + value
    local top = make("Frame", {
        Size             = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
    }, inner)
    make("TextLabel", {
        Text           = name,
        TextSize       = 11,
        Font           = FONT,
        TextColor3     = C.textPri,
        BackgroundTransparency = 1,
        Size           = UDim2.new(0.6, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, top)
    local vl = make("TextLabel", {
        Text           = tostring(CFG[key]),
        TextSize       = 10,
        Font           = FONTS,
        TextColor3     = C.accent,
        BackgroundTransparency = 1,
        Position       = UDim2.new(1, 0, 0, 0),
        Size           = UDim2.new(0.4, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Right,
    }, top)
    anchor(vl, 1, 0); vl.Position = UDim2.new(1, 0, 0, 0)

    -- track
    local track = make("Frame", {
        Size             = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = C.border2,
    }, inner)
    corner(2, track)

    local ratio = (CFG[key] - min) / (max - min)
    local fill = make("Frame", {
        Size             = UDim2.new(ratio, 0, 1, 0),
        BackgroundColor3 = C.accent,
    }, track)
    corner(2, fill)

    -- invisible drag region taller than track
    local drag = make("TextButton", {
        Size             = UDim2.new(1, 0, 0, 22),
        Position         = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint      = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Text             = "",
    }, track)

    local held = false
    local function setV(x)
        local r = math.clamp(x / track.AbsoluteSize.X, 0, 1)
        local v = min + (max - min) * r
        v = dp == 0 and math.floor(v + 0.5) or math.floor(v * 10^dp + 0.5) / 10^dp
        CFG[key] = v
        fill.Size = UDim2.new(r, 0, 1, 0)
        vl.Text   = tostring(v)
    end
    drag.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            held = true
            setV(i.Position.X - track.AbsolutePosition.X)
        end
    end)
    drag.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then held = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if held and i.UserInputType == Enum.UserInputType.MouseMovement then
            setV(i.Position.X - track.AbsolutePosition.X)
        end
    end)
end

local function kbRow(p, name, sub, bkey, ord)
    local row = make("Frame", {
        Size              = UDim2.new(1, 0, 0, 38),
        BackgroundColor3  = C.bg,
        BorderSizePixel   = 0,
        LayoutOrder       = ord,
    }, p)
    make("Frame", {
        Size             = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = C.border,
        BorderSizePixel  = 0,
    }, row)

    local inner = make("Frame", {
        Size     = UDim2.new(1, 0, 0, 37),
        Position = UDim2.new(0, 0, 0, 1),
        BackgroundTransparency = 1,
    }, row)
    pad(0, 12, 0, 12, inner)

    local lf = make("Frame", {
        Size             = UDim2.new(1, -64, 1, 0),
        BackgroundTransparency = 1,
    }, inner)
    make("UIListLayout", {
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding           = UDim.new(0, 2),
    }, lf)
    make("TextLabel", {
        Text           = name,
        TextSize       = 11,
        Font           = FONT,
        TextColor3     = C.textPri,
        BackgroundTransparency = 1,
        Size           = UDim2.new(1, 0, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, lf)
    if sub then
        make("TextLabel", {
            Text           = sub,
            TextSize       = 9,
            Font           = FONTS,
            TextColor3     = C.textSec,
            BackgroundTransparency = 1,
            Size           = UDim2.new(1, 0, 0, 12),
            TextXAlignment = Enum.TextXAlignment.Left,
        }, lf)
    end

    local kb = make("TextButton", {
        Size             = UDim2.new(0, 48, 0, 22),
        Position         = UDim2.new(1, -48, 0.5, 0),
        BackgroundColor3 = C.surface,
        Text             = bindName(BINDS[bkey]),
        TextSize         = 10,
        Font             = FONTB,
        TextColor3       = C.textSec,
        AutoButtonColor  = false,
    }, inner)
    anchor(kb, 0, 0.5); corner(5, kb); stroke(0.5, C.border2, kb)

    local listening = false
    UserInputService.InputBegan:Connect(function(i)
        if not listening then return end
        local isKey    = i.UserInputType == Enum.UserInputType.Keyboard
        local isM2     = i.UserInputType == Enum.UserInputType.MouseButton2
        local isM3     = i.UserInputType == Enum.UserInputType.MouseButton3
        -- M1 kena handle dekat InputEnded sebab klik button guna M1
        -- tapi kalau bukan button kb sendiri yang diclik, capture terus
        if not isKey and not isM2 and not isM3 then return end
        listening = false
        if isKey then
            BINDS[bkey] = i.KeyCode
        else
            BINDS[bkey] = i.UserInputType
        end
        kb.Text       = bindName(BINDS[bkey])
        kb.TextColor3 = C.textSec
        tw(kb, 0.1, {BackgroundColor3 = C.surface})
    end)
    -- M1 captured bila button dilepas supaya tak conflict dengan click button itself
    kb.MouseButton1Click:Connect(function()
        if not listening then
            -- start listen
            listening     = true
            kb.Text       = "..."
            kb.TextColor3 = C.accent
            tw(kb, 0.1, {BackgroundColor3 = C.accentBg})
        else
            -- second click = set to M1
            listening         = false
            BINDS[bkey]       = Enum.UserInputType.MouseButton1
            kb.Text           = "M1"
            kb.TextColor3     = C.textSec
            tw(kb, 0.1, {BackgroundColor3 = C.surface})
        end
    end)
end

-- ══════════════════════════════════
--  POPULATE PANELS
-- ══════════════════════════════════
secLbl(panels.ESP,    "visuals",    1)
toggleRow(panels.ESP, "Highlight",  "wallhack glow",      "highlightESP", 2)
toggleRow(panels.ESP, "Name",       "floating label",     "nameESP",      3)
toggleRow(panels.ESP, "Health bar", "hp under name",      "healthESP",    4)
toggleRow(panels.ESP, "Team check", "skip teammates",     "teamCheck",    5)
toggleRow(panels.ESP, "FOV circle", "show radius ring",   "showFOV",      6)

secLbl(panels.Aimbot,    "targeting",      1)
toggleRow(panels.Aimbot, "Aimbot",         "camera lock",         "aimbot",         2)
toggleRow(panels.Aimbot, "Require visible","skip wall targets",   "requireVisible", 3)
toggleRow(panels.Aimbot, "Hold to aim",    "off = press to toggle","aimbotHoldMode", 4)
secLbl(panels.Aimbot,    "tuning",         5)
sliderRow(panels.Aimbot, "Smoothness",     "smoothness",  0,   1, 2, 6)
sliderRow(panels.Aimbot, "FOV radius",     "fovRadius",  30, 600, 0, 7)

secLbl(panels.Misc,    "movement",   1)
toggleRow(panels.Misc, "Bhop",       "auto bunny hop",    "bhop",    2)
toggleRow(panels.Misc, "Inf jump",   "jump anywhere",     "infJump", 3)
secLbl(panels.Misc,    "combat",     4)
toggleRow(panels.Misc, "No clip",    "pass through walls","noClip",  5)
toggleRow(panels.Misc, "TP behind",  "loop tp near enemy","tpBehind",6)
secLbl(panels.Misc,    "burst",      7)
toggleRow(panels.Misc, "Auto burst", "heat-safe firerate","autoBurst",8)
sliderRow(panels.Misc, "Burst gap",  "burstInterval", 0.06, 0.40, 2, 9)

secLbl(panels.Keys,  "keybinds",       1)
kbRow(panels.Keys, "Aimbot key",   "hold / toggle to lock", "aimbot",       2)
kbRow(panels.Keys, "Toggle ESP",   "on / off",              "esp",          3)
kbRow(panels.Keys, "Toggle aimbot","on / off",              "aimbotToggle", 4)
kbRow(panels.Keys, "Toggle misc",  "bhop+noclip+inf",       "misc",         5)

updateStatus()

-- ══════════════════════════════════
--  HIGHLIGHT ESP
-- ══════════════════════════════════
local HL_NAME = "RivalsHub_HL"
local function isEnemy(p)
    if not CFG.teamCheck then return true end
    if p.Team == nil or LP.Team == nil then return true end
    return p.Team ~= LP.Team
end
local function getChar(p) return p.Character end
local function getRoot(p) local c = getChar(p); return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum(p)  local c = getChar(p); return c and c:FindFirstChildOfClass("Humanoid") end
local function getHead(p)
    local c = getChar(p)
    return c and (c:FindFirstChild("HitboxHead") or c:FindFirstChild("Head"))
end

local ESP_COL = {
    enemyFill    = Color3.fromRGB(220, 40,  40),
    enemyOutline = Color3.fromRGB(255, 100, 100),
    teamFill     = Color3.fromRGB(40,  100, 220),
    teamOutline  = Color3.fromRGB(100, 160, 255),
    enemyName    = Color3.fromRGB(255, 80,  80),
    teamName     = Color3.fromRGB(80,  160, 255),
}

local function applyHL(p)
    local c = getChar(p); if not c then return end
    local h = c:FindFirstChild(HL_NAME)
    if not h then
        h           = Instance.new("Highlight")
        h.Name      = HL_NAME
        h.Adornee   = c
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Parent    = c
    end
    local enemy           = isEnemy(p)
    h.FillColor           = enemy and ESP_COL.enemyFill    or ESP_COL.teamFill
    h.FillTransparency    = 0.5
    h.OutlineColor        = enemy and ESP_COL.enemyOutline or ESP_COL.teamOutline
    h.OutlineTransparency = 0
end
local function removeHL(p)
    local c = getChar(p); if not c then return end
    local h = c:FindFirstChild(HL_NAME); if h then h:Destroy() end
end

-- ══════════════════════════════════
--  DRAWING ESP
-- ══════════════════════════════════
local espObjs = {}
local function makeDrawESP(p)
    if espObjs[p] then return end
    local d = {}
    d.name = Drawing.new("Text"); d.name.Size = 14; d.name.Center = true; d.name.Outline = true
    d.name.OutlineColor = Color3.new(0,0,0); d.name.Color = Color3.fromRGB(255,60,60); d.name.Visible = false
    d.hbg  = Drawing.new("Square"); d.hbg.Filled = true; d.hbg.Color = Color3.fromRGB(20,20,20)
    d.hbg.Transparency = 0.45; d.hbg.Visible = false
    d.hbar = Drawing.new("Square"); d.hbar.Filled = true; d.hbar.Visible = false
    d.hlbl = Drawing.new("Text"); d.hlbl.Size = 11; d.hlbl.Center = true; d.hlbl.Outline = true
    d.hlbl.OutlineColor = Color3.new(0,0,0); d.hlbl.Color = Color3.fromRGB(255,255,255); d.hlbl.Visible = false
    espObjs[p] = d
end
local function destroyDrawESP(p)
    local d = espObjs[p]; if not d then return end
    for _, o in pairs(d) do pcall(function() o:Remove() end) end
    espObjs[p] = nil
end

local function w2s(pos)
    local sp, on = Camera:WorldToViewportPoint(pos)
    return Vector2.new(sp.X, sp.Y), on, sp.Z
end

local function updateDrawESP()
    for _, p in ipairs(Players:GetPlayers() or {}) do
        if p == LP then continue end
        if not CFG.nameESP and not CFG.healthESP then destroyDrawESP(p); continue end
        if not isEnemy(p) then destroyDrawESP(p); continue end
        local root = getRoot(p); local hum = getHum(p)
        if not root or not hum then destroyDrawESP(p); continue end
        makeDrawESP(p); local d = espObjs[p]
        local sp, onScreen, depth = w2s(root.Position + Vector3.new(0, 3.2, 0))
        if not onScreen or depth < 0 then for _, o in pairs(d) do o.Visible = false end; continue end
        local sz = math.clamp(1000 / depth, 8, 20)
        if CFG.nameESP then
            d.name.Position = Vector2.new(sp.X, sp.Y - sz*1.7)
            d.name.Text     = p.Name
            d.name.Size     = sz
            d.name.Color    = isEnemy(p) and ESP_COL.enemyName or ESP_COL.teamName
            d.name.Visible  = true
        else d.name.Visible = false end
        if CFG.healthESP then
            local hp = 0; local mhp = 100
            pcall(function() hp = hum.Health; mhp = hum.MaxHealth end)
            hp = math.clamp(hp, 0, mhp)
            local ratio = mhp > 0 and hp / mhp or 0
            local bw, bh = sz*1.5, 4
            local bx, by = sp.X - bw/2, sp.Y + sz*1.2
            d.hbg.Size     = Vector2.new(bw, bh); d.hbg.Position  = Vector2.new(bx, by); d.hbg.Visible  = true
            d.hbar.Size    = Vector2.new(bw*ratio, bh); d.hbar.Position = Vector2.new(bx, by)
            d.hbar.Color   = Color3.fromRGB(math.floor(255*(1-ratio)), math.floor(255*ratio), 0); d.hbar.Visible = true
            d.hlbl.Position = Vector2.new(sp.X, by+bh+1)
            d.hlbl.Text     = string.format("%d/%d", math.floor(hp), math.floor(mhp))
            d.hlbl.Size     = math.clamp(sz*0.72, 8, 13); d.hlbl.Visible = true
        else d.hbg.Visible = false; d.hbar.Visible = false; d.hlbl.Visible = false end
    end
end

local function syncHL()
    for _, p in ipairs(Players:GetPlayers() or {}) do
        if p == LP then continue end
        if CFG.highlightESP and getChar(p) then
            applyHL(p)
        else
            removeHL(p)
        end
    end
end

-- ══════════════════════════════════
--  FOV CIRCLE
-- ══════════════════════════════════
local fovCircle = Drawing.new("Circle")
fovCircle.Filled    = false
fovCircle.NumSides  = 64
fovCircle.Thickness = 1.2
fovCircle.Color     = Color3.fromRGB(255, 255, 255)
fovCircle.Position  = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
fovCircle.Radius    = CFG.fovRadius
fovCircle.Visible   = CFG.showFOV and CFG.aimbot
Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
end)

-- ══════════════════════════════════
--  AIMBOT
--  probe confirmed:
--  - CameraType = Scriptable (Rivals set sendiri, kita tak perlu tukar)
--  - Camera.CFrame lerp JALAN (CFrame changed: true)
--  - HitboxHead confirmed ada, parent = character model
--  - punca tak function: FOV 130px terlalu kecil, semua target dead (hp=0)
--  fix: pure camera lerp, FOV besar, skip dead + dead-body robust
-- ══════════════════════════════════
local PRED_FACTOR = 0.065

local function isAlive(p)
    local hum = getHum(p)
    if not hum then return false end
    local hp = 0
    pcall(function() hp = hum.Health end)
    return hp > 0
end

local function isVisible(p)
    local c = getChar(p); if not c then return false end
    local head = c:FindFirstChild("HitboxHead") or c:FindFirstChild("Head")
    if not head then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LP.Character or workspace, c}
    params.IgnoreWater = true
    local origin = Camera.CFrame.Position
    local result = workspace:Raycast(origin, head.Position - origin, params)
    return result == nil or result.Instance:IsDescendantOf(c)
end

local function getBest()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local bestD, bestP = CFG.fovRadius, nil

    for _, p in ipairs(Players:GetPlayers() or {}) do
        if p == LP then continue end
        if not isEnemy(p) then continue end
        local c = getChar(p); if not c then continue end
        -- HitboxHead confirmed parent = character (e.g. "Reyo1706")
        local part = c:FindFirstChild("HitboxHead") or c:FindFirstChild("Head")
        if not part then continue end
        if not isAlive(p) then continue end
        if CFG.requireVisible and not isVisible(p) then continue end

        local root = getRoot(p)
        local vel  = Vector3.zero
        if root then pcall(function() vel = root.AssemblyLinearVelocity end) end
        local pred = part.Position + vel * PRED_FACTOR

        local sp, on, depth = w2s(pred)
        if not on or depth < 0 then continue end

        local dist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if dist < bestD then
            bestD = dist
            bestP = { part = part, player = p }
        end
    end
    return bestP
end

-- { part, player } — simpan player ref terus
local lockedTarget = nil

local function targetValid(t)
    if not t then return false end
    if not t.part or not t.part.Parent then return false end
    if not t.player or not t.player.Parent then return false end
    if not isEnemy(t.player) then return false end
    if not isAlive(t.player) then return false end
    return true
end

local function doAimbot()
    if not CFG.aimbot then
        lockedTarget = nil
        aimbotToggleActive = false
        return
    end
    -- hold mode: aktif selagi key ditekan
    -- toggle mode: aktif sampai key ditekan lagi (latch diurus kat InputBegan)
    local active = CFG.aimbotHoldMode and isHeld(BINDS.aimbot) or aimbotToggleActive
    if not active then
        lockedTarget = nil
        return
    end

    -- validate + acquire lock
    if not targetValid(lockedTarget) then
        lockedTarget = getBest()
    end
    if not lockedTarget then return end

    -- update pred tiap frame (target bergerak)
    local root = getRoot(lockedTarget.player)
    local vel  = Vector3.zero
    if root then pcall(function() vel = root.AssemblyLinearVelocity end) end
    local targetPos = lockedTarget.part.Position + vel * PRED_FACTOR

    -- pure camera lerp — CameraType Scriptable Rivals set sendiri, tak perlu kita tukar
    local smooth = math.clamp(CFG.smoothness, 0.04, 1)
    Camera.CFrame = Camera.CFrame:Lerp(
        CFrame.new(Camera.CFrame.Position, targetPos), smooth)
end

-- ══════════════════════════════════
--  TELEPORT BEHIND
-- ══════════════════════════════════
local function getNearestEnemy()
    local best, bestD = nil, math.huge
    for _, p in ipairs(Players:GetPlayers() or {}) do
        if p == LP or not isEnemy(p) then continue end
        local root = getRoot(p); if not root then continue end
        local hum  = getHum(p);  if not hum  then continue end
        local nearHp = 0; pcall(function() nearHp = hum.Health end)
        if nearHp <= 0 then continue end
        local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then continue end
        local d = (myRoot.Position - root.Position).Magnitude
        if d < bestD then bestD = d; best = p end
    end
    return best
end

RunService.Heartbeat:Connect(function()
    if not CFG.tpBehind then return end
    local target = getNearestEnemy(); if not target then return end
    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local eRoot  = getRoot(target)
    if not myRoot or not eRoot then return end
    local hum    = getHum(target)
    local tpHp   = 0; if hum then pcall(function() tpHp = hum.Health end) end
    if tpHp <= 0 then return end
    myRoot.CFrame = CFrame.new(eRoot.Position + Vector3.new(0, 6, 0), eRoot.Position)
end)

-- ══════════════════════════════════
--  BHOP
-- ══════════════════════════════════
local bhopLatch = false
RunService.RenderStepped:Connect(function()
    if not CFG.bhop then return end
    local c = LP.Character; if not c then return end
    local hum = c:FindFirstChildOfClass("Humanoid"); if not hum then return end
    if hum.FloorMaterial ~= Enum.Material.Air and not bhopLatch then
        hum:ChangeState(Enum.HumanoidStateType.Jumping); bhopLatch = true
    elseif hum.FloorMaterial == Enum.Material.Air then bhopLatch = false end
end)

-- ══════════════════════════════════
--  INFINITE JUMP
-- ══════════════════════════════════
game:GetService("ContextActionService"):BindAction("RivalsInfJump", function(_, state)
    if not CFG.infJump then return end
    if state ~= Enum.UserInputState.Begin then return end
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end, false, Enum.KeyCode.Space)

-- ══════════════════════════════════
--  NOCLIP
-- ══════════════════════════════════
RunService.Stepped:Connect(function()
    if not CFG.noClip then return end
    local c = LP.Character; if not c then return end
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
    end
end)

-- ══════════════════════════════════
--  GLOBAL KEYBIND TOGGLES
-- ══════════════════════════════════
UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if bindMatches(BINDS.esp, inp) then
        CFG.highlightESP = not CFG.highlightESP
        CFG.nameESP      = CFG.highlightESP
        CFG.healthESP    = CFG.highlightESP
        if not CFG.highlightESP then
            for _, p in ipairs(Players:GetPlayers() or {}) do removeHL(p); destroyDrawESP(p) end
        end
    end
    -- aimbot key: dalam toggle mode, press = flip latch
    -- dalam hold mode, isHeld() handle kat doAimbot() — sini buat nothing
    if bindMatches(BINDS.aimbot, inp) and not CFG.aimbotHoldMode then
        if CFG.aimbot then
            aimbotToggleActive = not aimbotToggleActive
        end
    end
    if bindMatches(BINDS.aimbotToggle, inp) then
        CFG.aimbot = not CFG.aimbot
        fovCircle.Visible = CFG.showFOV and CFG.aimbot
        if not CFG.aimbot then lockedTarget = nil; aimbotToggleActive = false end
    end
    if bindMatches(BINDS.misc, inp) then
        miscOn = not miscOn
        CFG.bhop = miscOn; CFG.infJump = miscOn; CFG.noClip = miscOn
    end
end)

-- ══════════════════════════════════
--  AUTO-BURST
--  intercept M1: press → wait holdTime → release → wait burstInterval → repeat
--  supaya heat tak sempat overflow past accurate window
--  requires executor globals mouse1press / mouse1release (KRNL/Synapse/Solara)
-- ══════════════════════════════════
local hasBurstAPI = typeof(mouse1press) == "function"
                 and typeof(mouse1release) == "function"

local function runAutoBurst()
    burstRunning = true
    while CFG.autoBurst and autoBurstHeld do
        if hasBurstAPI then
            pcall(mouse1press)
            task.wait(0.04)
            -- flag dulu supaya InputEnded tau ini kita yang release, bukan player
            burstReleasing = true
            pcall(mouse1release)
            burstReleasing = false
        end
        task.wait(math.max(CFG.burstInterval, 0.06))
    end
    -- clean release bila player betul-betul lepas M1
    burstReleasing = true
    if hasBurstAPI then pcall(mouse1release) end
    burstReleasing = false
    burstRunning = false
end

UserInputService.InputBegan:Connect(function(i, gpe)
    if gpe then return end
    if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    autoBurstHeld = true
    if CFG.autoBurst and not burstRunning then
        if hasBurstAPI then
            task.spawn(runAutoBurst)
        else
            -- executor tak support mouse1press — warn sekali je
            warn("[RivalsHub] auto-burst: executor ni tak support mouse1press/mouse1release")
        end
    end
end)

UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        -- ignore release yang kita sendiri generate dalam burst loop
        if not burstReleasing then
            autoBurstHeld = false
        end
    end
end)

-- ══════════════════════════════════
--  PLAYER LIFECYCLE
-- ══════════════════════════════════
local function hookPlayer(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.15); destroyDrawESP(p); removeHL(p)
    end)
end
for _, p in ipairs(Players:GetPlayers() or {}) do if p ~= LP then hookPlayer(p) end end
Players.PlayerAdded:Connect(hookPlayer)
Players.PlayerRemoving:Connect(function(p) destroyDrawESP(p); removeHL(p) end)

-- ══════════════════════════════════
--  MAIN LOOP
-- ══════════════════════════════════
RunService.RenderStepped:Connect(function()
    syncHL()
    updateDrawESP()
    doAimbot()
    fovCircle.Radius  = CFG.fovRadius
    fovCircle.Visible = CFG.showFOV and CFG.aimbot
end)

-- ══════════════════════════════════
--  ESC INTERCEPT
--  Bind ESC at priority 2000 — above Roblox's pause-menu listener
--  (~1000). Sink the keypress so the pause menu never opens while
--  the panel is alive. Unbound when × closes the hub.
-- ══════════════════════════════════
CAS:BindActionAtPriority(ESC_ACTION, function(_, inputState)
    if inputState ~= Enum.UserInputState.Begin then
        return Enum.ContextActionResult.Pass
    end
    -- sink: Roblox pause menu never fires
    return Enum.ContextActionResult.Sink
end, false, 2000, Enum.KeyCode.Escape)

print("[RivalsHub] amber sidebar | muzzle redirect aimbot | F1 ESP | F2 Aimbot | F3 Misc | hold E lock | ESC blocked")
