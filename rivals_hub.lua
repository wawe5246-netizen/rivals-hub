-- Lua | Rivals Hub v2 | Minimalist Premium UI
-- executor: Medium / KRNL / Synapse / Solara

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Camera           = workspace.CurrentCamera
local LP               = Players.LocalPlayer

local CFG = {
    highlightESP   = true,
    nameESP        = true,
    healthESP      = true,
    teamCheck      = true,
    aimbot         = true,
    requireVisible = true,
    showFOV        = true,
    bhop           = false,
    infJump        = false,
    noClip         = false,
    tpBehind       = false,
    smoothness     = 0.18,
    fovRadius      = 130,
}

local BINDS = {
    aimbot       = Enum.KeyCode.E,
    esp          = Enum.KeyCode.F1,
    aimbotToggle = Enum.KeyCode.F2,
    misc         = Enum.KeyCode.F3,
}

local miscOn = false

-- ══════════════════════════════════
--  COLOUR SYSTEM
-- ══════════════════════════════════
local C = {
    bg       = Color3.fromRGB(10,  10,  11),   -- near-black base
    panel    = Color3.fromRGB(16,  16,  18),   -- panel bg
    card     = Color3.fromRGB(22,  22,  25),   -- row cards
    border   = Color3.fromRGB(38,  38,  44),   -- subtle border
    borderHi = Color3.fromRGB(60,  60,  70),   -- hover border
    accent   = Color3.fromRGB(110, 86,  255),  -- purple accent
    accentDim= Color3.fromRGB(30,  24,  60),   -- accent bg tint
    textPri  = Color3.fromRGB(238, 238, 242),  -- primary text
    textSec  = Color3.fromRGB(120, 120, 132),  -- secondary text
    textMut  = Color3.fromRGB(65,  65,  72),   -- muted / section labels
    white    = Color3.fromRGB(255, 255, 255),
    success  = Color3.fromRGB(52,  211, 153),  -- green dot
    danger   = Color3.fromRGB(248, 81,  73),
}

local F  = Enum.Font.GothamMedium
local FS = Enum.Font.Gotham
local FB = Enum.Font.GothamBold

-- ══════════════════════════════════
--  HELPERS
-- ══════════════════════════════════
local function make(cls, props, parent)
    local o = Instance.new(cls)
    for k,v in pairs(props or {}) do o[k]=v end
    if parent then o.Parent=parent end
    return o
end
local function corner(r,p)  make("UICorner",{CornerRadius=UDim.new(0,r)},p) end
local function stroke(t,c,p) make("UIStroke",{Thickness=t,Color=c,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},p) end
local function pad(t,r,b,l,p) make("UIPadding",{PaddingTop=UDim.new(0,t),PaddingRight=UDim.new(0,r),PaddingBottom=UDim.new(0,b),PaddingLeft=UDim.new(0,l)},p) end
local function anchor(o,ax,ay) o.AnchorPoint=Vector2.new(ax,ay) end
local function tw(o,t,props,style)
    TweenService:Create(o,TweenInfo.new(t,style or Enum.EasingStyle.Quint,Enum.EasingDirection.Out),props):Play()
end
local function lbl(txt,fs,font,col,p)
    return make("TextLabel",{
        Text=txt, TextSize=fs, Font=font, TextColor3=col,
        BackgroundTransparency=1, AutomaticSize=Enum.AutomaticSize.XY,
        TextXAlignment=Enum.TextXAlignment.Left,
    },p)
end

-- ══════════════════════════════════
--  ROOT GUI
-- ══════════════════════════════════
local gui = make("ScreenGui",{
    Name="RivalsHubV2",
    ResetOnSpawn=false,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
    DisplayOrder=10,
},LP.PlayerGui)

-- main window: 280 wide, taller to fit all rows cleanly
local WIN_W, WIN_H = 280, 420
local win = make("Frame",{
    Size     = UDim2.new(0,WIN_W,0,WIN_H),
    Position = UDim2.new(0,24,0.5,-WIN_H/2),
    BackgroundColor3 = C.bg,
    Active   = true,
    ClipsDescendants = true,
},gui)
corner(16,win)
stroke(0.5,C.border,win)

-- ══════════════════════════════════
--  DRAG
-- ══════════════════════════════════
local dragging,dragStart,startPos
win.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true; dragStart=i.Position; startPos=win.Position
    end
end)
win.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
        local d=i.Position-dragStart
        win.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
    end
end)

-- ══════════════════════════════════
--  HEADER  (48px)
-- ══════════════════════════════════
local hdr = make("Frame",{
    Size=UDim2.new(1,0,0,48),
    BackgroundColor3=C.panel,
    BorderSizePixel=0,
},win)
-- bottom border line on header
make("Frame",{
    Size=UDim2.new(1,0,0,1),
    Position=UDim2.new(0,0,1,-1),
    BackgroundColor3=C.border,
    BorderSizePixel=0,
},hdr)

-- logo dot + title
local logoDot = make("Frame",{
    Size=UDim2.new(0,6,0,6),
    BackgroundColor3=C.accent,
},hdr)
corner(3,logoDot); anchor(logoDot,0,0.5); logoDot.Position=UDim2.new(0,16,0.5,0)

local titleL = lbl("rivals",14,FB,C.textPri,hdr)
anchor(titleL,0,0.5); titleL.Position=UDim2.new(0,28,0.5,0)
local hubL = lbl(" hub",14,F,C.textSec,hdr)
anchor(hubL,0,0.5); hubL.Position=UDim2.new(0,28+titleL.TextBounds.X,0.5,0)

-- live badge
local liveBadge = make("Frame",{
    Size=UDim2.new(0,36,0,18),
    BackgroundColor3=C.accentDim,
},hdr)
corner(9,liveBadge); anchor(liveBadge,1,0.5); liveBadge.Position=UDim2.new(1,-44,0.5,0)
local liveL = make("TextLabel",{
    Text="LIVE", TextSize=9, Font=FB,
    TextColor3=C.accent, BackgroundTransparency=1,
    Size=UDim2.new(1,0,1,0),
    TextXAlignment=Enum.TextXAlignment.Center,
    TextYAlignment=Enum.TextYAlignment.Center,
},liveBadge)

-- close button
local closeBtn = make("TextButton",{
    Size=UDim2.new(0,18,0,18),
    BackgroundTransparency=1,
    Text="✕", TextSize=11, Font=FB,
    TextColor3=C.textMut,
},hdr)
anchor(closeBtn,1,0.5); closeBtn.Position=UDim2.new(1,-14,0.5,0)
closeBtn.MouseEnter:Connect(function() tw(closeBtn,0.1,{TextColor3=C.danger}) end)
closeBtn.MouseLeave:Connect(function() tw(closeBtn,0.1,{TextColor3=C.textMut}) end)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- ══════════════════════════════════
--  TAB BAR  (36px)
-- ══════════════════════════════════
local tabBar = make("Frame",{
    Size=UDim2.new(1,0,0,36),
    Position=UDim2.new(0,0,0,48),
    BackgroundColor3=C.panel,
    BorderSizePixel=0,
    ClipsDescendants=false,
},win)
make("UIListLayout",{
    FillDirection=Enum.FillDirection.Horizontal,
    SortOrder=Enum.SortOrder.LayoutOrder,
},tabBar)
-- tabbar bottom border
make("Frame",{
    Size=UDim2.new(1,0,0,1),
    Position=UDim2.new(0,0,1,0),
    BackgroundColor3=C.border,
    BorderSizePixel=0,
    ZIndex=2,
},tabBar)
-- sliding underline
local tabLine = make("Frame",{
    Size=UDim2.new(0.25,0,0,2),
    Position=UDim2.new(0,0,1,-1),
    BackgroundColor3=C.accent,
    BorderSizePixel=0,
    ZIndex=3,
},tabBar)

-- ══════════════════════════════════
--  BODY  (scroll, fills between tabbar and statusbar)
-- ══════════════════════════════════
-- header(48) + tabBar(36) = 84 top; statusBar(32) bottom
local body = make("ScrollingFrame",{
    Size=UDim2.new(1,0,1,-116),
    Position=UDim2.new(0,0,0,84),
    BackgroundTransparency=1,
    ScrollBarThickness=0,
    CanvasSize=UDim2.new(0,0,0,0),
    AutomaticCanvasSize=Enum.AutomaticSize.Y,
    ClipsDescendants=true,
    BorderSizePixel=0,
},win)

-- ══════════════════════════════════
--  STATUS BAR  (32px, pinned bottom)
-- ══════════════════════════════════
local statusBar = make("Frame",{
    Size=UDim2.new(1,0,0,32),
    BackgroundColor3=C.panel,
    BorderSizePixel=0,
},win)
anchor(statusBar,0,1); statusBar.Position=UDim2.new(0,0,1,0)
make("Frame",{
    Size=UDim2.new(1,0,0,1),
    BackgroundColor3=C.border,
    BorderSizePixel=0,
},statusBar)
local dot = make("Frame",{Size=UDim2.new(0,5,0,5),BackgroundColor3=C.success},statusBar)
corner(3,dot); anchor(dot,0,0.5); dot.Position=UDim2.new(0,14,0.5,0)
local statusL = make("TextLabel",{
    Text="0 features active",
    TextSize=10, Font=FS,
    TextColor3=C.textMut,
    BackgroundTransparency=1,
    AutomaticSize=Enum.AutomaticSize.XY,
    TextXAlignment=Enum.TextXAlignment.Left,
},statusBar)
anchor(statusL,0,0.5); statusL.Position=UDim2.new(0,26,0.5,0)

local function updateStatus()
    local n=0
    for _,v in pairs(CFG) do if v==true then n=n+1 end end
    statusL.Text=n.." features active"
end

-- ══════════════════════════════════
--  TAB SYSTEM
-- ══════════════════════════════════
local TABS   = {"ESP","Aimbot","Misc","Keybinds"}
local panels = {}
local tabBtns= {}

for i,name in ipairs(TABS) do
    local btn = make("TextButton",{
        Size=UDim2.new(0.25,0,1,0),
        BackgroundColor3=C.panel,
        Text=name, TextSize=11, Font=F,
        TextColor3= i==1 and C.textPri or C.textMut,
        LayoutOrder=i,
        BorderSizePixel=0,
    },tabBar)
    tabBtns[name]=btn

    local panel = make("Frame",{
        Size=UDim2.new(1,0,0,0),
        AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1,
        Visible=i==1,
    },body)
    pad(8,12,12,12,panel)
    make("UIListLayout",{
        SortOrder=Enum.SortOrder.LayoutOrder,
        Padding=UDim.new(0,4),
    },panel)
    panels[name]=panel

    btn.MouseButton1Click:Connect(function()
        for _,n in ipairs(TABS) do
            tw(tabBtns[n],0.15,{TextColor3=C.textMut})
            panels[n].Visible=false
        end
        tw(btn,0.15,{TextColor3=C.textPri})
        panel.Visible=true
        tw(tabLine,0.18,{Position=UDim2.new((i-1)*0.25,0,1,-1)})
    end)
end

-- ══════════════════════════════════
--  ROW BUILDERS
-- ══════════════════════════════════

-- section label
local function secLbl(p,txt,ord)
    local fr = make("Frame",{
        Size=UDim2.new(1,0,0,24),
        BackgroundTransparency=1,
        LayoutOrder=ord,
    },p)
    make("TextLabel",{
        Text=string.upper(txt),
        TextSize=9, Font=FB,
        TextColor3=C.textMut,
        BackgroundTransparency=1,
        AutomaticSize=Enum.AutomaticSize.XY,
        TextXAlignment=Enum.TextXAlignment.Left,
        AnchorPoint=Vector2.new(0,1),
        Position=UDim2.new(0,2,1,0),
    },fr)
end

-- toggle row: clean card with pill
local function toggleRow(p,name,sub,key,ord)
    local row = make("Frame",{
        Size=UDim2.new(1,0,0,46),
        BackgroundColor3=C.card,
        LayoutOrder=ord,
    },p)
    corner(8,row)
    stroke(0.5,C.border,row)

    -- label stack
    local lf = make("Frame",{
        Size=UDim2.new(1,-52,1,0),
        Position=UDim2.new(0,12,0,0),
        BackgroundTransparency=1,
    },row)
    make("UIListLayout",{VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,2)},lf)
    lbl(name,12,F,C.textPri,lf)
    if sub then lbl(sub,10,FS,C.textSec,lf) end

    -- pill toggle
    local pillBg = make("Frame",{
        Size=UDim2.new(0,32,0,18),
        BackgroundColor3= CFG[key] and C.accent or C.border,
        AnchorPoint=Vector2.new(1,0.5),
        Position=UDim2.new(1,-12,0.5,0),
    },row)
    corner(9,pillBg)
    local thumb = make("Frame",{
        Size=UDim2.new(0,12,0,12),
        BackgroundColor3=C.white,
        AnchorPoint=Vector2.new(0,0.5),
        Position=CFG[key] and UDim2.new(1,-15,0.5,0) or UDim2.new(0,3,0.5,0),
    },pillBg)
    corner(6,thumb)

    -- hover glow on card
    row.MouseEnter:Connect(function() tw(row,0.12,{BackgroundColor3=C.card}) stroke(0.5,C.borderHi,row) end)
    row.MouseLeave:Connect(function() stroke(0.5,C.border,row) end)

    pillBg.InputBegan:Connect(function(i)
        if i.UserInputType~=Enum.UserInputType.MouseButton1 then return end
        CFG[key]=not CFG[key]
        tw(pillBg,0.14,{BackgroundColor3=CFG[key] and C.accent or C.border})
        tw(thumb,0.14,{Position=CFG[key] and UDim2.new(1,-15,0.5,0) or UDim2.new(0,3,0.5,0)})
        updateStatus()
    end)
end

-- slider row
local function sliderRow(p,name,key,min,max,dp,ord)
    local row = make("Frame",{
        Size=UDim2.new(1,0,0,54),
        BackgroundColor3=C.card,
        LayoutOrder=ord,
    },p)
    corner(8,row)
    stroke(0.5,C.border,row)
    pad(8,12,8,12,row)
    make("UIListLayout",{Padding=UDim.new(0,6)},row)

    local top = make("Frame",{Size=UDim2.new(1,0,0,14),BackgroundTransparency=1},row)
    lbl(name,12,F,C.textPri,top)
    local vl = make("TextLabel",{
        Text=tostring(CFG[key]),
        TextSize=11, Font=FS,
        TextColor3=C.accent,
        BackgroundTransparency=1,
        AutomaticSize=Enum.AutomaticSize.XY,
        TextXAlignment=Enum.TextXAlignment.Right,
        AnchorPoint=Vector2.new(1,0),
        Position=UDim2.new(1,0,0,0),
    },top)

    local trackBg = make("Frame",{Size=UDim2.new(1,0,0,3),BackgroundColor3=C.border},row)
    corner(2,trackBg)
    local ratio=(CFG[key]-min)/(max-min)
    local fill=make("Frame",{Size=UDim2.new(ratio,0,1,0),BackgroundColor3=C.accent},trackBg)
    corner(2,fill)

    local drag=make("TextButton",{
        Size=UDim2.new(1,0,0,22),
        BackgroundTransparency=1,Text="",
    },row)
    local held=false
    local function setV(x)
        local r=math.clamp(x/drag.AbsoluteSize.X,0,1)
        local v=min+(max-min)*r
        v=dp==0 and math.floor(v+0.5) or math.floor(v*10^dp+0.5)/10^dp
        CFG[key]=v; fill.Size=UDim2.new(r,0,1,0); vl.Text=tostring(v)
    end
    drag.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then held=true;setV(i.Position.X-drag.AbsolutePosition.X) end
    end)
    drag.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then held=false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if held and i.UserInputType==Enum.UserInputType.MouseMovement then
            setV(i.Position.X-drag.AbsolutePosition.X)
        end
    end)
end

-- keybind row
local function kbRow(p,name,sub,bkey,ord)
    local row = make("Frame",{
        Size=UDim2.new(1,0,0,46),
        BackgroundColor3=C.card,
        LayoutOrder=ord,
    },p)
    corner(8,row)
    stroke(0.5,C.border,row)

    local lf = make("Frame",{
        Size=UDim2.new(1,-70,1,0),
        Position=UDim2.new(0,12,0,0),
        BackgroundTransparency=1,
    },row)
    make("UIListLayout",{VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,2)},lf)
    lbl(name,12,F,C.textPri,lf)
    if sub then lbl(sub,10,FS,C.textSec,lf) end

    local kb = make("TextButton",{
        Size=UDim2.new(0,52,0,24),
        BackgroundColor3=C.bg,
        Text=BINDS[bkey].Name, TextSize=10, Font=FB,
        TextColor3=C.textSec,
        AnchorPoint=Vector2.new(1,0.5),
        Position=UDim2.new(1,-12,0.5,0),
    },row)
    corner(6,kb); stroke(0.5,C.border,kb)

    local listening=false
    kb.MouseButton1Click:Connect(function()
        if listening then
            listening=false
            tw(kb,0.1,{BackgroundColor3=C.bg,TextColor3=C.textSec})
            return
        end
        listening=true
        kb.Text="..."
        tw(kb,0.1,{BackgroundColor3=C.accentDim,TextColor3=C.accent})
    end)
    UserInputService.InputBegan:Connect(function(i)
        if not listening then return end
        if i.UserInputType~=Enum.UserInputType.Keyboard then return end
        listening=false
        BINDS[bkey]=i.KeyCode
        kb.Text=i.KeyCode.Name
        tw(kb,0.1,{BackgroundColor3=C.bg,TextColor3=C.textSec})
    end)
end

-- ══════════════════════════════════
--  POPULATE TABS
-- ══════════════════════════════════
secLbl(panels.ESP,"visibility",1)
toggleRow(panels.ESP,"Highlight ESP","wallhack glow on enemies","highlightESP",2)
toggleRow(panels.ESP,"Name ESP","floating name tag","nameESP",3)
toggleRow(panels.ESP,"Health bar","hp bar under tag","healthESP",4)
toggleRow(panels.ESP,"Team check","skip teammates","teamCheck",5)

secLbl(panels.Aimbot,"targeting",1)
toggleRow(panels.Aimbot,"Aimbot","camera lock","aimbot",2)
toggleRow(panels.Aimbot,"Require visible","ignore wallbang targets","requireVisible",3)
toggleRow(panels.Aimbot,"FOV circle","show aim radius ring","showFOV",4)
secLbl(panels.Aimbot,"tuning",5)
sliderRow(panels.Aimbot,"Smoothness","smoothness",0,1,2,6)
sliderRow(panels.Aimbot,"FOV radius","fovRadius",30,300,0,7)

secLbl(panels.Misc,"movement",1)
toggleRow(panels.Misc,"Bhop","auto bunny hop","bhop",2)
toggleRow(panels.Misc,"Infinite jump","jump anywhere","infJump",3)
toggleRow(panels.Misc,"No clip","pass through walls","noClip",4)
secLbl(panels.Misc,"combat",5)
toggleRow(panels.Misc,"Teleport behind","loop tp behind nearest enemy","tpBehind",6)

secLbl(panels.Keybinds,"keybinds",1)
kbRow(panels.Keybinds,"Aimbot hold","hold to lock","aimbot",2)
kbRow(panels.Keybinds,"Toggle ESP","on / off","esp",3)
kbRow(panels.Keybinds,"Toggle aimbot","on / off","aimbotToggle",4)
kbRow(panels.Keybinds,"Toggle misc","bhop + noclip + inf","misc",5)

updateStatus()

-- ══════════════════════════════════
--  HIGHLIGHT ESP
-- ══════════════════════════════════
local HL_NAME="RivalsHubV2_HL"
local function isEnemy(p) return not CFG.teamCheck or p.Team~=LP.Team end
local function getChar(p) return p.Character end
local function getRoot(p) local c=getChar(p); return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum(p)  local c=getChar(p); return c and c:FindFirstChildOfClass("Humanoid") end
local function getHead(p) local c=getChar(p); return c and c:FindFirstChild("Head") end

local function applyHL(p)
    local c=getChar(p); if not c then return end
    if c:FindFirstChild(HL_NAME) then return end
    local h=Instance.new("Highlight")
    h.Name=HL_NAME; h.Adornee=c
    h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    h.FillColor=Color3.fromRGB(110,86,255); h.FillTransparency=0.6
    h.OutlineColor=Color3.fromRGB(180,160,255); h.OutlineTransparency=0
    h.Parent=c
end
local function removeHL(p)
    local c=getChar(p); if not c then return end
    local h=c:FindFirstChild(HL_NAME); if h then h:Destroy() end
end

-- ══════════════════════════════════
--  DRAWING ESP
-- ══════════════════════════════════
local espObjs={}
local function makeDrawESP(p)
    if espObjs[p] then return end
    local d={}
    d.name=Drawing.new("Text")
    d.name.Size=14; d.name.Center=true; d.name.Outline=true
    d.name.OutlineColor=Color3.new(0,0,0)
    d.name.Color=Color3.fromRGB(180,160,255)
    d.name.Visible=false
    d.hbg=Drawing.new("Square")
    d.hbg.Filled=true; d.hbg.Color=Color3.fromRGB(15,15,15)
    d.hbg.Transparency=0.4; d.hbg.Visible=false
    d.hbar=Drawing.new("Square")
    d.hbar.Filled=true; d.hbar.Visible=false
    d.hlbl=Drawing.new("Text")
    d.hlbl.Size=11; d.hlbl.Center=true; d.hlbl.Outline=true
    d.hlbl.OutlineColor=Color3.new(0,0,0)
    d.hlbl.Color=Color3.fromRGB(255,255,255)
    d.hlbl.Visible=false
    espObjs[p]=d
end
local function destroyDrawESP(p)
    local d=espObjs[p]; if not d then return end
    for _,o in pairs(d) do pcall(function() o:Remove() end) end
    espObjs[p]=nil
end

local function w2s(pos)
    local sp,on=Camera:WorldToViewportPoint(pos)
    return Vector2.new(sp.X,sp.Y),on,sp.Z
end

local function updateDrawESP()
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP then continue end
        if not CFG.nameESP and not CFG.healthESP then destroyDrawESP(p); continue end
        if not isEnemy(p) then destroyDrawESP(p); continue end
        local root=getRoot(p); local hum=getHum(p)
        if not root or not hum then destroyDrawESP(p); continue end
        makeDrawESP(p); local d=espObjs[p]
        local sp,onScreen,depth=w2s(root.Position+Vector3.new(0,3.2,0))
        if not onScreen or depth<0 then
            for _,o in pairs(d) do o.Visible=false end; continue
        end
        local sz=math.clamp(1000/depth,8,20)
        if CFG.nameESP then
            d.name.Position=Vector2.new(sp.X,sp.Y-sz*1.7)
            d.name.Text=p.Name; d.name.Size=sz; d.name.Visible=true
        else d.name.Visible=false end
        if CFG.healthESP then
            local hp=math.clamp(hum.Health,0,hum.MaxHealth)
            local ratio=hum.MaxHealth>0 and hp/hum.MaxHealth or 0
            local bw,bh=sz*1.5,4
            local bx=sp.X-bw/2; local by=sp.Y+sz*1.2
            d.hbg.Size=Vector2.new(bw,bh); d.hbg.Position=Vector2.new(bx,by); d.hbg.Visible=true
            d.hbar.Size=Vector2.new(bw*ratio,bh); d.hbar.Position=Vector2.new(bx,by)
            d.hbar.Color=Color3.fromRGB(math.floor(255*(1-ratio)),math.floor(255*ratio),0)
            d.hbar.Visible=true
            d.hlbl.Position=Vector2.new(sp.X,by+bh+1)
            d.hlbl.Text=string.format("%d/%d",math.floor(hp),math.floor(hum.MaxHealth))
            d.hlbl.Size=math.clamp(sz*0.72,8,13); d.hlbl.Visible=true
        else d.hbg.Visible=false; d.hbar.Visible=false; d.hlbl.Visible=false end
    end
end

local function syncHL()
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP then continue end
        if CFG.highlightESP and isEnemy(p) and getChar(p) then applyHL(p)
        else removeHL(p) end
    end
end

-- ══════════════════════════════════
--  FOV CIRCLE
-- ══════════════════════════════════
local fovCircle=Drawing.new("Circle")
fovCircle.Filled=false; fovCircle.NumSides=64; fovCircle.Thickness=1
fovCircle.Color=Color3.fromRGB(110,86,255)
fovCircle.Position=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
fovCircle.Radius=CFG.fovRadius
fovCircle.Visible=CFG.showFOV and CFG.aimbot
Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    fovCircle.Position=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
end)

-- ══════════════════════════════════
--  AIMBOT
-- ══════════════════════════════════
local function isVisible(p)
    local head=getHead(p); if not head then return false end
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances={LP.Character,getChar(p)}
    params.IgnoreWater=true
    local origin=Camera.CFrame.Position
    local result=workspace:Raycast(origin,head.Position-origin,params)
    return result==nil or result.Instance:IsDescendantOf(getChar(p))
end

local function getBest()
    local center=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
    local bestD,bestP=CFG.fovRadius,nil
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP or not isEnemy(p) then continue end
        local c=getChar(p); if not c then continue end
        local part=c:FindFirstChild("Head") or getRoot(p); if not part then continue end
        local hum=getHum(p); if not hum or hum.Health<=0 then continue end
        if CFG.requireVisible and not isVisible(p) then continue end
        local sp,on,depth=w2s(part.Position); if not on or depth<0 then continue end
        local dist=(Vector2.new(sp.X,sp.Y)-center).Magnitude
        if dist<bestD then bestD=dist; bestP=part end
    end
    return bestP
end

local function doAimbot()
    if not CFG.aimbot then return end
    if not UserInputService:IsKeyDown(BINDS.aimbot) then return end
    local target=getBest(); if not target then return end
    local smooth=math.clamp(1-CFG.smoothness,0.01,1)
    Camera.CFrame=Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position,target.Position),smooth)
end

-- ══════════════════════════════════
--  TELEPORT BEHIND
-- ══════════════════════════════════
local function getNearestEnemy()
    local best,bestD=nil,math.huge
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP or not isEnemy(p) then continue end
        local root=getRoot(p); if not root then continue end
        local hum=getHum(p); if not hum or hum.Health<=0 then continue end
        local myRoot=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then continue end
        local d=(myRoot.Position-root.Position).Magnitude
        if d<bestD then bestD=d; best=p end
    end
    return best
end

RunService.Heartbeat:Connect(function()
    if not CFG.tpBehind then return end
    local target=getNearestEnemy(); if not target then return end
    local myRoot=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local eRoot=getRoot(target)
    if not myRoot or not eRoot then return end
    local hum=getHum(target); if not hum or hum.Health<=0 then return end
    myRoot.CFrame=CFrame.new(eRoot.Position+Vector3.new(0,6,0),eRoot.Position)
end)

-- ══════════════════════════════════
--  BHOP
-- ══════════════════════════════════
local bhopLatch=false
RunService.RenderStepped:Connect(function()
    if not CFG.bhop then return end
    local c=LP.Character; if not c then return end
    local hum=c:FindFirstChildOfClass("Humanoid"); if not hum then return end
    if hum.FloorMaterial~=Enum.Material.Air and not bhopLatch then
        hum:ChangeState(Enum.HumanoidStateType.Jumping); bhopLatch=true
    elseif hum.FloorMaterial==Enum.Material.Air then bhopLatch=false end
end)

-- ══════════════════════════════════
--  INFINITE JUMP
-- ══════════════════════════════════
game:GetService("ContextActionService"):BindAction("RivalsInfJump",function(_,state)
    if not CFG.infJump then return end
    if state~=Enum.UserInputState.Begin then return end
    local hum=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end,false,Enum.KeyCode.Space)

-- ══════════════════════════════════
--  NOCLIP
-- ══════════════════════════════════
RunService.Stepped:Connect(function()
    if not CFG.noClip then return end
    local c=LP.Character; if not c then return end
    for _,p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") and p.CanCollide then p.CanCollide=false end
    end
end)

-- ══════════════════════════════════
--  GLOBAL KEYBIND TOGGLES
-- ══════════════════════════════════
UserInputService.InputBegan:Connect(function(inp,gpe)
    if gpe then return end
    if inp.KeyCode==BINDS.esp then
        CFG.highlightESP=not CFG.highlightESP
        CFG.nameESP=CFG.highlightESP
        CFG.healthESP=CFG.highlightESP
        if not CFG.highlightESP then
            for _,p in ipairs(Players:GetPlayers()) do removeHL(p); destroyDrawESP(p) end
        end
    end
    if inp.KeyCode==BINDS.aimbotToggle then
        CFG.aimbot=not CFG.aimbot
        fovCircle.Visible=CFG.showFOV and CFG.aimbot
    end
    if inp.KeyCode==BINDS.misc then
        miscOn=not miscOn
        CFG.bhop=miscOn; CFG.infJump=miscOn; CFG.noClip=miscOn
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
for _,p in ipairs(Players:GetPlayers()) do if p~=LP then hookPlayer(p) end end
Players.PlayerAdded:Connect(hookPlayer)
Players.PlayerRemoving:Connect(function(p) destroyDrawESP(p); removeHL(p) end)

-- ══════════════════════════════════
--  MAIN LOOP
-- ══════════════════════════════════
RunService.RenderStepped:Connect(function()
    syncHL()
    updateDrawESP()
    doAimbot()
    fovCircle.Radius=CFG.fovRadius
    fovCircle.Visible=CFG.showFOV and CFG.aimbot
end)

print("[RivalsHub v2] loaded — drag | ✕ close | F1 ESP | F2 Aimbot | F3 Misc | hold E lock")
