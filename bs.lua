--=====================================================================
--  BLOX STRIKE  •  VENICE FULL SCRIPT v3
--=====================================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local Lighting   = game:GetService("Lighting")
local Tween      = game:GetService("TweenService")
local WS         = game:GetService("Workspace")
local RS         = game:GetService("ReplicatedStorage")
local Http       = game:GetService("HttpService")

local LP = Players.LocalPlayer

local GUI_PARENT = (gethui and gethui()) or game:GetService("CoreGui")
for _, p in ipairs({GUI_PARENT, game:GetService("CoreGui")}) do
    local o = p:FindFirstChild("VeniceBloxStrike")
    if o then o:Destroy() end
end

--=====================================================================
--  FLAGS
--=====================================================================
local Flags = {
    Menu = { Key = "RightShift", Accent = Color3.fromRGB(0,170,255), Transparency = 0.06 },

    ESP = {
        Mode = "Billboard", Enabled = true, Box = true, BoxFill = false, Name = true,
        Health = true, Distance = true, Weapon = true, Tracer = false, Chams = true,
        TeamColor = true, TeamCheck = false, MaxDistance = 2500,
        TextSize = 13, Color = Color3.fromRGB(0,170,255), ShowSelf = false,
    },

    Visual = { FOVEnabled = false, FOV = 100, FPSBoost = false },

    Sky = {
        ClockTime = 14, Brightness = 2, FogEnd = 3000, FogStart = 0,
        FogColor = Color3.fromRGB(170,200,235), Ambient = Color3.fromRGB(90,95,105),
        Outdoor = Color3.fromRGB(140,150,165), Stars = 3000,
        Atmosphere = true, Density = 0.3, Haze = 0, Celestial = true,
    },

    Particles = {
        Enabled = false, Rate = 40, Speed = 4, Lifetime = 3, Size = 0.6,
        Spread = 180, RotSpeed = 1, AccelY = 0, Light = 0.4,
        Color = Color3.fromRGB(255,255,255),
        Texture = "rbxasset://textures/particles/sparkles_main.dds",
    },

    Bhop = { Enabled = false, Always = true, RequireMove = true, AutoStrafe = false,
             StrafeAngle = 35, JumpPower = 55 },

    Skin = {
        Enabled = false, Target = "Weapon", AutoApply = true, Rainbow = false,
        Material = "Изначально", Color = Color3.fromRGB(255,255,255), Reflectance = 0,
        Slots = {
            Weapon = { TextureId = "", Name = "—" },
            Knife  = { TextureId = "", Name = "—" },
            Gloves = { TextureId = "", Name = "—" },
        },
    },
}

--=====================================================================
--  THEME + ХЕЛПЕРЫ
--=====================================================================
local Theme = {
    Bg = Color3.fromRGB(9,9,11), Panel = Color3.fromRGB(15,15,19),
    Card = Color3.fromRGB(21,21,26), Hover = Color3.fromRGB(30,30,37),
    Stroke = Color3.fromRGB(40,40,50), Text = Color3.fromRGB(232,232,240),
    Sub = Color3.fromRGB(135,135,152), Accent = Flags.Menu.Accent,
}

local function new(class, props)
    local o = Instance.new(class)
    for k, v in next, props do if k ~= "Parent" then o[k] = v end end
    if props.Parent then o.Parent = props.Parent end
    return o
end
local function corner(o, r) new("UICorner", { CornerRadius = UDim.new(0, r or 6), Parent = o }) end
local function stroke(o, c, t, tr)
    new("UIStroke", { Color = c or Theme.Stroke, Thickness = t or 1, Transparency = tr or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o })
end
local function makeDraggable(frame, handle)
    handle = handle or frame
    local drag, ds, sp
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag, ds, sp = true, i.Position, frame.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then drag = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - ds
            frame.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)
end
local function matchAny(s, list)
    s = string.lower(s)
    for _, w in ipairs(list) do if string.find(s, w, 1, true) then return true end end
    return false
end

local KNIFE_WORDS = { "knife","нож","bayonet","karambit","dagger","talon","butterfly","m9",
    "huntsman","falchion","bowie","stiletto","ursus","navaja","nomad","paracord","skeleton",
    "classic","flip","gut","shiv","blade" }
local GLOVE_WORDS = { "glove","перчат","wrap","hands","hand","mitt" }

--=====================================================================
--  GUI
--=====================================================================
local ScreenGui = new("ScreenGui", {
    Name = "VeniceBloxStrike", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999, Parent = GUI_PARENT,
})

local WIN_W, WIN_H = 660, 448
local Main = new("Frame", {
    Parent = ScreenGui, Size = UDim2.new(0,WIN_W,0,WIN_H), Position = UDim2.new(0.5,-WIN_W/2,0.5,-WIN_H/2),
    BackgroundColor3 = Theme.Bg, BorderSizePixel = 0, ClipsDescendants = true })
corner(Main, 12); stroke(Main, Theme.Stroke, 1, 0)
new("UIGradient", { Parent = Main, Rotation = 90,
    Color = ColorSequence.new(Color3.fromRGB(14,14,18), Color3.fromRGB(8,8,10)) })

local Top = new("Frame", { Parent = Main, Size = UDim2.new(1,0,0,38), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0 })
new("TextLabel", { Parent = Top, BackgroundTransparency = 1, Position = UDim2.new(0,16,0,0), Size = UDim2.new(1,-140,1,0),
    Text = "BLOX STRIKE", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Text,
    TextXAlignment = Enum.TextXAlignment.Left })
new("TextLabel", { Parent = Top, BackgroundTransparency = 1, Position = UDim2.new(0,110,0,0), Size = UDim2.new(1,-180,1,0),
    Text = "• VENICE", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Accent,
    TextXAlignment = Enum.TextXAlignment.Left })
new("Frame", { Parent = Top, Position = UDim2.new(0,0,1,-1), Size = UDim2.new(1,0,0,1),
    BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0 })

local Sidebar = new("Frame", { Parent = Main, Position = UDim2.new(0,0,0,38), Size = UDim2.new(0,152,1,-38),
    BackgroundColor3 = Theme.Bg, BorderSizePixel = 0 })
new("UIListLayout", { Parent = Sidebar, Padding = UDim.new(0,4), SortOrder = Enum.SortOrder.LayoutOrder })
new("UIPadding", { Parent = Sidebar, PaddingTop = UDim.new(0,12), PaddingLeft = UDim.new(0,10), PaddingRight = UDim.new(0,10) })

local Sep = new("Frame", { Parent = Main, Position = UDim2.new(0,152,0,38), Size = UDim2.new(0,1,1,-38),
    BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0, ZIndex = 5 })

local Content = new("Frame", { Parent = Main, Position = UDim2.new(0,152,0,38), Size = UDim2.new(1,-152,1,-38),
    BackgroundColor3 = Theme.Panel, BorderSizePixel = 0 })

local minBtn = new("TextButton", { Parent = Top, Position = UDim2.new(1,-74,0,8), Size = UDim2.new(0,26,0,22),
    BackgroundColor3 = Theme.Card, Text = "—", Font = Enum.Font.GothamBold, TextSize = 12,
    TextColor3 = Theme.Sub, AutoButtonColor = false })
corner(minBtn,6)
local closeBtn = new("TextButton", { Parent = Top, Position = UDim2.new(1,-42,0,8), Size = UDim2.new(0,26,0,22),
    BackgroundColor3 = Theme.Card, Text = "✕", Font = Enum.Font.GothamBold, TextSize = 12,
    TextColor3 = Theme.Sub, AutoButtonColor = false })
corner(closeBtn,6)

makeDraggable(Main, Top)
makeDraggable(Main, Sidebar)

--=====================================================================
--  КОМПОНЕНТЫ
--=====================================================================
local function addSection(parent, text)
    local f = new("Frame", { Parent = parent, Size = UDim2.new(1,-8,0,24), BackgroundTransparency = 1 })
    new("TextLabel", { Parent = f, BackgroundTransparency = 1, Size = UDim2.new(1,0,1,0),
        Text = string.upper(text), Font = Enum.Font.GothamBold, TextSize = 11,
        TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left })
    new("Frame", { Parent = f, Position = UDim2.new(0,0,1,-6), Size = UDim2.new(1,0,0,1),
        BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0, BackgroundTransparency = 0.5 })
end

local function addLabel(parent, text)
    local l = new("TextLabel", { Parent = parent, Size = UDim2.new(1,-8,0,26), BackgroundColor3 = Theme.Bg,
        BorderSizePixel = 0, Text = text, Font = Enum.Font.GothamMedium, TextSize = 11,
        TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Left })
    corner(l,6)
    new("UIPadding", { Parent = l, PaddingLeft = UDim.new(0,10) })
    return l
end

local function addToggle(parent, text, default, callback)
    local row = new("Frame", { Parent = parent, Size = UDim2.new(1,-8,0,32),
        BackgroundColor3 = Theme.Card, BorderSizePixel = 0 })
    corner(row,7); stroke(row, Theme.Stroke, 1, 0.5)
    new("TextLabel", { Parent = row, BackgroundTransparency = 1, Position = UDim2.new(0,12,0,0),
        Size = UDim2.new(1,-70,1,0), Text = text, Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left })
    local state = default
    local track = new("Frame", { Parent = row, Size = UDim2.new(0,38,0,18), Position = UDim2.new(1,-50,0.5,-9),
        BackgroundColor3 = state and Theme.Accent or Theme.Hover, BorderSizePixel = 0 })
    corner(track,9)
    local knob = new("Frame", { Parent = track, Size = UDim2.new(0,14,0,14),
        Position = state and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7),
        BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0 })
    corner(knob,7)
    local btn = new("TextButton", { Parent = row, BackgroundTransparency = 1, Size = UDim2.new(1,0,1,0), Text = "" })
    local function set(v, fire)
        state = v
        Tween:Create(track, TweenInfo.new(0.15), { BackgroundColor3 = v and Theme.Accent or Theme.Hover }):Play()
        Tween:Create(knob, TweenInfo.new(0.15),
            { Position = v and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7) }):Play()
        if fire ~= false and callback then callback(v) end
    end
    btn.MouseButton1Click:Connect(function() set(not state) end)
    if callback then callback(state) end
    return { Set = set, Get = function() return state end }
end

local function addSlider(parent, text, min, max, default, decimals, callback)
    decimals = decimals or 0
    local row = new("Frame", { Parent = parent, Size = UDim2.new(1,-8,0,48),
        BackgroundColor3 = Theme.Card, BorderSizePixel = 0 })
    corner(row,7); stroke(row, Theme.Stroke, 1, 0.5)
    local label = new("TextLabel", { Parent = row, BackgroundTransparency = 1, Position = UDim2.new(0,12,0,6),
        Size = UDim2.new(1,-24,0,18), Text = text, Font = Enum.Font.GothamMedium, TextSize = 12,
        TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Left })
    local bar = new("Frame", { Parent = row, Position = UDim2.new(0,12,0,34), Size = UDim2.new(1,-24,0,5),
        BackgroundColor3 = Theme.Bg, BorderSizePixel = 0 })
    corner(bar,3)
    local fill = new("Frame", { Parent = bar, Size = UDim2.new(0,0,1,0), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0 })
    corner(fill,3)
    local knob = new("Frame", { Parent = bar, Size = UDim2.new(0,11,0,11), AnchorPoint = Vector2.new(0.5,0.5),
        Position = UDim2.new(0,0,0.5,0), BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0 })
    corner(knob,6)
    local value, dragging = default, false
    local function render()
        local a = (max > min) and ((value - min)/(max - min)) or 0
        fill.Size = UDim2.new(a,0,1,0); knob.Position = UDim2.new(a,0,0.5,0)
        label.Text = text .. "   " .. ((decimals == 0) and tostring(math.floor(value)) or string.format("%."..decimals.."f", value))
    end
    local function set(v, fire)
        v = math.clamp(v, min, max)
        if decimals == 0 then v = math.floor(v + 0.5) else v = tonumber(string.format("%."..decimals.."f", v)) end
        value = v; render()
        if fire ~= false and callback then callback(value) end
    end
    local hit = new("TextButton", { Parent = row, BackgroundTransparency = 1, Text = "",
        Position = UDim2.new(0,12,0,26), Size = UDim2.new(1,-24,0,20) })
    local function fromMouse()
        local mx = UIS:GetMouseLocation().X
        local rel = math.clamp((mx - bar.AbsolutePosition.X)/math.max(bar.AbsoluteSize.X,1), 0, 1)
        set(min + (max-min)*rel)
    end
    hit.MouseButton1Down:Connect(function() dragging = true; fromMouse() end)
    UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then fromMouse() end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    render()
    return { Set = set, Get = function() return value end }
end

local function addDropdown(parent, text, options, default, callback)
    local cont = new("Frame", { Parent = parent, Size = UDim2.new(1,-8,0,0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
    new("UIListLayout", { Parent = cont, Padding = UDim.new(0,4), SortOrder = Enum.SortOrder.LayoutOrder })
    local btn = new("TextButton", { Parent = cont, Size = UDim2.new(1,0,0,32), BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0, Text = text .. "   ▾   " .. tostring(default), Font = Enum.Font.GothamMedium,
        TextSize = 12, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false })
    corner(btn,7); stroke(btn, Theme.Stroke, 1, 0.5)
    new("UIPadding", { Parent = btn, PaddingLeft = UDim.new(0,12) })
    local list = new("Frame", { Parent = cont, Size = UDim2.new(1,0,0,0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Bg, BorderSizePixel = 0, Visible = false })
    corner(list,7); stroke(list, Theme.Stroke, 1, 0.3)
    new("UIListLayout", { Parent = list, Padding = UDim.new(0,3), SortOrder = Enum.SortOrder.LayoutOrder })
    new("UIPadding", { Parent = list, PaddingTop = UDim.new(0,5), PaddingBottom = UDim.new(0,5),
        PaddingLeft = UDim.new(0,5), PaddingRight = UDim.new(0,5) })
    for _, opt in ipairs(options) do
        local it = new("TextButton", { Parent = list, Size = UDim2.new(1,0,0,26), BackgroundColor3 = Theme.Card,
            BorderSizePixel = 0, Text = opt, Font = Enum.Font.GothamMedium, TextSize = 12,
            TextColor3 = Theme.Sub, AutoButtonColor = false })
        corner(it,5)
        it.MouseEnter:Connect(function() it.BackgroundColor3 = Theme.Hover; it.TextColor3 = Theme.Text end)
        it.MouseLeave:Connect(function() it.BackgroundColor3 = Theme.Card; it.TextColor3 = Theme.Sub end)
        it.MouseButton1Click:Connect(function()
            btn.Text = text .. "   ▾   " .. opt
            list.Visible = false
            if callback then callback(opt) end
        end)
    end
    btn.MouseButton1Click:Connect(function() list.Visible = not list.Visible end)
    if callback then callback(default) end
    return { Get = function() return default end }
end

local function addButton(parent, text, callback)
    local b = new("TextButton", { Parent = parent, Size = UDim2.new(1,-8,0,32), BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0, Text = text, Font = Enum.Font.GothamMedium, TextSize = 12,
        TextColor3 = Theme.Text, AutoButtonColor = false })
    corner(b,7); stroke(b, Theme.Stroke, 1, 0.5)
    b.MouseEnter:Connect(function() b.BackgroundColor3 = Theme.Hover end)
    b.MouseLeave:Connect(function() b.BackgroundColor3 = Theme.Card end)
    b.MouseButton1Click:Connect(callback)
    return b
end

local function addTextBox(parent, text, default, callback)
    local row = new("Frame", { Parent = parent, Size = UDim2.new(1,-8,0,32),
        BackgroundColor3 = Theme.Card, BorderSizePixel = 0 })
    corner(row,7); stroke(row, Theme.Stroke, 1, 0.5)
    new("TextLabel", { Parent = row, BackgroundTransparency = 1, Position = UDim2.new(0,12,0,0),
        Size = UDim2.new(1,-140,1,0), Text = text, Font = Enum.Font.GothamMedium, TextSize = 12,
        TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left })
    local box = new("TextBox", { Parent = row, Position = UDim2.new(1,-124,0.5,-12), Size = UDim2.new(0,112,0,24),
        BackgroundColor3 = Theme.Bg, BorderSizePixel = 0, Text = default, Font = Enum.Font.Gotham,
        TextSize = 12, TextColor3 = Theme.Text, ClearTextOnFocus = false })
    corner(box,5); stroke(box, Theme.Stroke, 1, 0.4)
    box.FocusLost:Connect(function() if callback then callback(box.Text) end end)
    return box
end

local function addScroll(parent, height)
    local s = new("ScrollingFrame", { Parent = parent, Size = UDim2.new(1,-8,0,height),
        BackgroundColor3 = Theme.Card, BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Stroke, CanvasSize = UDim2.new(0,0,0,0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y })
    corner(s,7); stroke(s, Theme.Stroke, 1, 0.5)
    new("UIListLayout", { Parent = s, Padding = UDim.new(0,3), SortOrder = Enum.SortOrder.LayoutOrder })
    new("UIPadding", { Parent = s, PaddingTop = UDim.new(0,6), PaddingBottom = UDim.new(0,6),
        PaddingLeft = UDim.new(0,6), PaddingRight = UDim.new(0,6) })
    return s
end

--  COLOR PICKER
local pickerState = { R = 255, G = 255, B = 255 }
local pickerCallback, pickerUpdating = nil, false
local PickerFrame = new("Frame", { Parent = ScreenGui, Size = UDim2.new(0,230,0,0),
    AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0.5,-115,0.5,-110),
    BackgroundColor3 = Theme.Bg, BorderSizePixel = 0, Visible = false, ZIndex = 60 })
corner(PickerFrame,9); stroke(PickerFrame, Theme.Stroke, 1, 0)
new("UIListLayout", { Parent = PickerFrame, Padding = UDim.new(0,6), SortOrder = Enum.SortOrder.LayoutOrder })
new("UIPadding", { Parent = PickerFrame, PaddingTop = UDim.new(0,8), PaddingBottom = UDim.new(0,8),
    PaddingLeft = UDim.new(0,8), PaddingRight = UDim.new(0,8) })
local pickerTitle = new("TextLabel", { Parent = PickerFrame, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,20),
    Text = "Цвет", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Text,
    TextXAlignment = Enum.TextXAlignment.Left })
local pickerPreview = new("Frame", { Parent = PickerFrame, Size = UDim2.new(1,0,0,34),
    BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0 })
corner(pickerPreview,7); stroke(pickerPreview, Theme.Stroke, 1, 0)
local pickerBody = new("Frame", { Parent = PickerFrame, Size = UDim2.new(1,0,0,0),
    AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
new("UIListLayout", { Parent = pickerBody, Padding = UDim.new(0,5), SortOrder = Enum.SortOrder.LayoutOrder })
local function pickerApply()
    if pickerUpdating then return end
    local c = Color3.fromRGB(pickerState.R, pickerState.G, pickerState.B)
    pickerPreview.BackgroundColor3 = c
    if pickerCallback then pickerCallback(c) end
end
local rS = addSlider(pickerBody, "R", 0, 255, 255, 0, function(v) pickerState.R = v; pickerApply() end)
local gS = addSlider(pickerBody, "G", 0, 255, 255, 0, function(v) pickerState.G = v; pickerApply() end)
local bS = addSlider(pickerBody, "B", 0, 255, 255, 0, function(v) pickerState.B = v; pickerApply() end)
local function openPicker(title, color, cb)
    pickerCallback = cb; pickerUpdating = true
    pickerState.R = math.floor(color.R * 255)
    pickerState.G = math.floor(color.G * 255)
    pickerState.B = math.floor(color.B * 255)
    rS.Set(pickerState.R, false); gS.Set(pickerState.G, false); bS.Set(pickerState.B, false)
    pickerUpdating = false
    pickerPreview.BackgroundColor3 = color
    pickerTitle.Text = "Цвет  •  " .. title
    PickerFrame.Visible = true
end
makeDraggable(PickerFrame, pickerTitle)
local function addColorPicker(parent, text, default, callback)
    local row = new("Frame", { Parent = parent, Size = UDim2.new(1,-8,0,32),
        BackgroundColor3 = Theme.Card, BorderSizePixel = 0 })
    corner(row,7); stroke(row, Theme.Stroke, 1, 0.5)
    new("TextLabel", { Parent = row, BackgroundTransparency = 1, Position = UDim2.new(0,12,0,0),
        Size = UDim2.new(1,-80,1,0), Text = text, Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left })
    local sw = new("Frame", { Parent = row, Position = UDim2.new(1,-58,0.5,-9), Size = UDim2.new(0,46,0,18),
        BackgroundColor3 = default, BorderSizePixel = 0 })
    corner(sw,5); stroke(sw, Theme.Stroke, 1, 0)
    local b = new("TextButton", { Parent = row, BackgroundTransparency = 1, Size = UDim2.new(1,0,1,0), Text = "" })
    b.MouseButton1Click:Connect(function()
        openPicker(text, sw.BackgroundColor3, function(c)
            sw.BackgroundColor3 = c
            if callback then callback(c) end
        end)
    end)
    return { Set = function(c) sw.BackgroundColor3 = c end }
end

--=====================================================================
--  ВКЛАДКИ
--=====================================================================
local Pages, TabBtns, order = {}, {}, 0
local function createTab(name)
    order = order + 1
    local btn = new("TextButton", { Parent = Sidebar, Size = UDim2.new(1,0,0,32), BackgroundColor3 = Theme.Bg,
        BorderSizePixel = 0, Text = name, Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false, LayoutOrder = order })
    corner(btn,7)
    new("UIPadding", { Parent = btn, PaddingLeft = UDim.new(0,14) })
    local ind = new("Frame", { Parent = btn, Size = UDim2.new(0,3,0,16), Position = UDim2.new(0,0,0.5,-8),
        BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Visible = false })
    corner(ind,2)
    local page = new("ScrollingFrame", { Parent = Content, Size = UDim2.new(1,0,1,0),
        BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Stroke, CanvasSize = UDim2.new(0,0,0,0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y })
    new("UIListLayout", { Parent = page, Padding = UDim.new(0,6), SortOrder = Enum.SortOrder.LayoutOrder })
    new("UIPadding", { Parent = page, PaddingTop = UDim.new(0,12), PaddingBottom = UDim.new(0,12),
        PaddingLeft = UDim.new(0,12), PaddingRight = UDim.new(0,12) })
    Pages[name], TabBtns[name] = page, btn
    btn.MouseEnter:Connect(function()
        if not page.Visible then btn.BackgroundColor3 = Theme.Card; btn.TextColor3 = Theme.Text end
    end)
    btn.MouseLeave:Connect(function()
        if not page.Visible then btn.BackgroundColor3 = Theme.Bg; btn.TextColor3 = Theme.Sub end
    end)
    btn.MouseButton1Click:Connect(function()
        for n, p in pairs(Pages) do
            p.Visible = (n == name)
            local b = TabBtns[n]
            b.BackgroundColor3 = (n == name) and Theme.Card or Theme.Bg
            b.TextColor3 = (n == name) and Theme.Text or Theme.Sub
            local i = b:FindFirstChildOfClass("Frame"); if i then i.Visible = (n == name) end
        end
    end)
    return page
end

local tabESP  = createTab("ESP")
local tabList = createTab("Игроки")
local tabVis  = createTab("Визуал")
local tabSky  = createTab("Небо")
local tabPart = createTab("Частицы")
local tabSkin = createTab("Скины")
local tabBhop = createTab("BunnyHop")
local tabCfg  = createTab("Настройки")

--=====================================================================
--  БАЗА ДАННЫХ ИГРОКА
--=====================================================================
local function getRoot(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
        or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        or char:FindFirstChild("LowerTorso") or char:FindFirstChildWhichIsA("BasePart")
end
local function getHead(char)
    if not char then return nil end
    return char:FindFirstChild("Head") or getRoot(char)
end
local function getWeapon(player, char)
    if not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then return tool.Name end
    return char:GetAttribute("Weapon") or player:GetAttribute("Weapon") or player:GetAttribute("CurrentWeapon")
end

--=====================================================================
--  ESP
--=====================================================================
local drawingOK = (function()
    if not Drawing then return false end
    return pcall(function()
        local d = Drawing.new("Square"); d.Visible = false
        if d.Remove then d:Remove() elseif d.Destroy then d:Destroy() end
    end)
end)()

local function removeD(d)
    if not d then return end
    if d.Remove then pcall(function() d:Remove() end)
    elseif d.Destroy then pcall(function() d:Destroy() end) end
end

local espCache = {}
local espErr = ""

local function newD(class, props)
    local ok, d = pcall(Drawing.new, class)
    if not ok then return nil end
    for k, v in pairs(props) do d[k] = v end
    return d
end

local function createDrawingESP()
    return {
        box     = newD("Square", { Thickness = 1, Filled = false, Transparency = 0.15, Color = Flags.ESP.Color, Visible = false }),
        boxFill = newD("Square", { Thickness = 0, Filled = true, Transparency = 0.85, Color = Flags.ESP.Color, Visible = false }),
        name    = newD("Text", { Size = Flags.ESP.TextSize, Center = true, Outline = true, OutlineColor = Color3.new(0,0,0), Color = Color3.new(1,1,1), Visible = false, Font = 2 }),
        dist    = newD("Text", { Size = Flags.ESP.TextSize - 1, Center = true, Outline = true, OutlineColor = Color3.new(0,0,0), Color = Color3.fromRGB(200,200,210), Visible = false, Font = 2 }),
        weapon  = newD("Text", { Size = Flags.ESP.TextSize - 1, Center = true, Outline = true, OutlineColor = Color3.new(0,0,0), Color = Color3.fromRGB(255,215,120), Visible = false, Font = 2 }),
        hpBg    = newD("Square", { Filled = true, Transparency = 0.5, Color = Color3.fromRGB(15,15,15), Visible = false }),
        hp      = newD("Square", { Filled = true, Color = Color3.fromRGB(0,255,120), Visible = false }),
        tracer  = newD("Line", { Thickness = 1, Transparency = 0.4, Color = Flags.ESP.Color, Visible = false }),
    }
end
local function hideDrawingESP(c) for _, d in pairs(c) do if d then d.Visible = false end end end
local function destroyDrawingESP(c) for _, d in pairs(c) do removeD(d) end end

local function createBillboardESP(char)
    local bb = Instance.new("BillboardGui")
    bb.Name = "VeniceESP"
    bb.Size = UDim2.new(0, 3.4, 0, 5.8)
    bb.StudsOffsetWorldSpace = Vector3.new(0, 0.25, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.ClipsDescendants = false
    bb.MaxDistance = Flags.ESP.MaxDistance
    bb.Adornee = getRoot(char)
    bb.Parent = char

    local fill = new("Frame", { Parent = bb, Size = UDim2.new(1,0,1,0), BackgroundColor3 = Flags.ESP.Color,
        BackgroundTransparency = 0.85, BorderSizePixel = 0, Visible = false })
    local box = new("Frame", { Parent = bb, Size = UDim2.new(1,0,1,0), BackgroundColor3 = Color3.new(1,1,1),
        BackgroundTransparency = 1, BorderSizePixel = 0 })
    local boxStroke = new("UIStroke", { Parent = box, Color = Flags.ESP.Color, Thickness = 1.6 })

    local hpBg = new("Frame", { Parent = bb, Position = UDim2.new(-0.09,0,0,0), Size = UDim2.new(0.06,0,1,0),
        BackgroundColor3 = Color3.fromRGB(15,15,15), BackgroundTransparency = 0.45, BorderSizePixel = 0 })
    local hp = new("Frame", { Parent = bb, Position = UDim2.new(-0.09,0,0,0), Size = UDim2.new(0.06,0,1,0),
        BackgroundColor3 = Color3.fromRGB(0,255,120), BorderSizePixel = 0, AnchorPoint = Vector2.new(0,1) })

    local nameL = new("TextLabel", { Parent = bb, Position = UDim2.new(0.5,0,0,0), AnchorPoint = Vector2.new(0.5,1),
        Size = UDim2.new(1,0,0.22,0), BackgroundTransparency = 1, Text = "", TextScaled = true,
        Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1,1,1),
        TextStrokeTransparency = 0, TextStrokeColor3 = Color3.new(0,0,0) })
    local distL = new("TextLabel", { Parent = bb, Position = UDim2.new(0.5,0,1,0), AnchorPoint = Vector2.new(0.5,0),
        Size = UDim2.new(1,0,0.18,0), BackgroundTransparency = 1, Text = "", TextScaled = true,
        Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(210,210,220),
        TextStrokeTransparency = 0, TextStrokeColor3 = Color3.new(0,0,0) })
    local wpnL = new("TextLabel", { Parent = bb, Position = UDim2.new(0.5,0,1,0), AnchorPoint = Vector2.new(0.5,0),
        Size = UDim2.new(1,0,0.18,0), BackgroundTransparency = 1, Text = "", TextScaled = true,
        Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(255,215,120),
        TextStrokeTransparency = 0, TextStrokeColor3 = Color3.new(0,0,0) })

    return bb, { fill = fill, box = box, boxStroke = boxStroke, hp = hp, hpBg = hpBg,
                 name = nameL, dist = distL, weapon = wpnL }
end

-- ГАРАНТИРОВАННЫЙ СЛОЙ: Highlight сквозь стены
local function updateHighlights()
    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        local h = char and char:FindFirstChild("VeniceHL")
        local show = Flags.ESP.Enabled and char and (p ~= LP or Flags.ESP.ShowSelf)
            and not (Flags.ESP.TeamCheck and LP.Team and p.Team == LP.Team)
        if show then
            if not h then
                h = Instance.new("Highlight")
                h.Name = "VeniceHL"
                h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                h.FillTransparency = Flags.ESP.Chams and 0.55 or 0.85
                h.OutlineTransparency = 0
                h.Adornee = char
                h.Parent = char
            end
            local col = Flags.ESP.TeamColor and p.TeamColor.Color or Flags.ESP.Color
            h.FillColor, h.OutlineColor = col, col
        elseif h then h:Destroy() end
    end
end

local function updateESP()
    local cam = WS.CurrentCamera
    if not cam then return end
    local useD = (Flags.ESP.Mode == "Drawing") or (Flags.ESP.Mode == "Авто" and drawingOK)
    local vp = cam.ViewportSize
    local camPos = cam.CFrame.Position

    for _, player in ipairs(Players:GetPlayers()) do
        local c = espCache[player]
        if not c then c = {}; espCache[player] = c end

        local char = player.Character
        local root = getRoot(char)
        local head = getHead(char)
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local hp   = hum and hum.Health or 100
        local maxhp = (hum and hum.MaxHealth) or 100

        local skip = (player == LP and not Flags.ESP.ShowSelf)
        if Flags.ESP.TeamCheck and LP.Team and player.Team == LP.Team then skip = true end

        local alive = (Flags.ESP.Enabled == true) and (skip == false) and (root ~= nil)
            and ((hum == nil) or (hp > 0))
        local dist = 0
        if alive then
            dist = (root.Position - camPos).Magnitude
            if dist > Flags.ESP.MaxDistance then alive = false end
        end

        --  переключение движка
        if useD then
            if c.bb then c.bb:Destroy(); c.bb, c.r = nil, nil end
            if not c.d then c.d = createDrawingESP() end
        else
            if c.d then destroyDrawingESP(c.d); c.d = nil end
            if char and (not c.bb or not c.bb.Parent) then c.bb, c.r = createBillboardESP(char) end
        end

        --  DRAWING
        if c.d then
            local d = c.d
            if not alive then
                hideDrawingESP(d)
            else
                local top = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 0.6, 0))
                local bot = cam:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                if top.Z > 0 and bot.Z > 0 then
                    local color = Flags.ESP.TeamColor and player.TeamColor.Color or Flags.ESP.Color
                    local h = math.clamp(math.abs(top.Y - bot.Y), 8, 3000)
                    local w = h * 0.55
                    local x, y = bot.X - w/2, top.Y
                    d.box.Color = color; d.box.Visible = Flags.ESP.Box
                    d.box.Position = Vector2.new(x, y); d.box.Size = Vector2.new(w, h)
                    d.boxFill.Color = color; d.boxFill.Visible = Flags.ESP.Box and Flags.ESP.BoxFill
                    d.boxFill.Position = Vector2.new(x, y); d.boxFill.Size = Vector2.new(w, h)
                    d.name.Color = color; d.name.Visible = Flags.ESP.Name
                    d.name.Text = player.DisplayName .. " (@" .. player.Name .. ")"
                    d.name.Position = Vector2.new(top.X, y - 17)
                    d.dist.Visible = Flags.ESP.Distance
                    d.dist.Text = string.format("%d m", math.floor(dist))
                    d.dist.Position = Vector2.new(top.X, y + h + 3)
                    local wpn = getWeapon(player, char)
                    d.weapon.Visible = Flags.ESP.Weapon and wpn ~= nil
                    d.weapon.Text = wpn or ""
                    d.weapon.Position = Vector2.new(top.X, y + h + 17)
                    d.hpBg.Visible = Flags.ESP.Health
                    d.hpBg.Position = Vector2.new(x - 6, y); d.hpBg.Size = Vector2.new(3, h)
                    local pct = math.clamp(hp / math.max(maxhp, 1), 0, 1)
                    d.hp.Visible = Flags.ESP.Health
                    d.hp.Color = Color3.fromRGB(255 * (1 - pct), 255 * pct, 40)
                    d.hp.Position = Vector2.new(x - 6, y + h * (1 - pct))
                    d.hp.Size = Vector2.new(3, h * pct)
                    d.tracer.Visible = Flags.ESP.Tracer
                    d.tracer.Color = color
                    d.tracer.From = Vector2.new(vp.X/2, vp.Y)
                    d.tracer.To = Vector2.new(top.X, y + h)
                else
                    hideDrawingESP(d)
                end
            end
        end

        --  BILLBOARD
        if c.bb and c.r then
            local r = c.r
            if char then
                local rr = getRoot(char)
                if c.bb.Adornee ~= rr then c.bb.Adornee = rr end
            end
            c.bb.MaxDistance = Flags.ESP.MaxDistance
            c.bb.Enabled = alive
            if alive then
                local color = Flags.ESP.TeamColor and player.TeamColor.Color or Flags.ESP.Color
                r.box.Visible = Flags.ESP.Box
                r.boxStroke.Color = color
                r.fill.Visible = Flags.ESP.Box and Flags.ESP.BoxFill
                r.fill.BackgroundColor3 = color
                r.name.Visible = Flags.ESP.Name
                r.name.TextColor3 = color
                r.name.Text = player.DisplayName
                r.dist.Visible = Flags.ESP.Distance
                r.dist.Text = string.format("%d m", math.floor(dist))
                local wpn = getWeapon(player, char)
                r.weapon.Visible = Flags.ESP.Weapon and wpn ~= nil
                r.weapon.Text = wpn or ""
                r.hpBg.Visible = Flags.ESP.Health
                local pct = math.clamp(hp / math.max(maxhp, 1), 0, 1)
                r.hp.Visible = Flags.ESP.Health
                r.hp.BackgroundColor3 = Color3.fromRGB(255 * (1 - pct), 255 * pct, 40)
                r.hp.Size = UDim2.new(0.06, 0, pct, 0)
            end
        end
    end

    for p, c in pairs(espCache) do
        if not p.Parent then
            if c.d then destroyDrawingESP(c.d) end
            if c.bb then c.bb:Destroy() end
            espCache[p] = nil
        end
    end
end

Players.PlayerRemoving:Connect(function(p)
    local c = espCache[p]
    if c then
        if c.d then destroyDrawingESP(c.d) end
        if c.bb then c.bb:Destroy() end
        espCache[p] = nil
    end
end)

--=====================================================================
--  FOV / FPS BOOST
--=====================================================================
RunService:BindToRenderStep("VeniceFOV", Enum.RenderPriority.Camera.Value + 1, function()
    local cam = WS.CurrentCamera
    if cam and Flags.Visual.FOVEnabled then cam.FieldOfView = Flags.Visual.FOV end
end)

local FPS = { active = false, saved = {} }
local function setFPSBoost(on)
    if on and not FPS.active then
        FPS.active = true
        local s = FPS.saved
        s.GlobalShadows = Lighting.GlobalShadows; Lighting.GlobalShadows = false
        s.EnvDiff, s.EnvSpec = Lighting.EnvironmentDiffuseScale, Lighting.EnvironmentSpecularScale
        Lighting.EnvironmentDiffuseScale, Lighting.EnvironmentSpecularScale = 0, 0
        local T = WS.Terrain
        s.WaterWaveSize, s.WaterWaveSpeed = T.WaterWaveSize, T.WaterWaveSpeed
        s.WaterReflectance, s.WaterTransparency = T.WaterReflectance, T.WaterTransparency
        T.WaterWaveSize, T.WaterWaveSpeed, T.WaterReflectance, T.WaterTransparency = 0, 0, 0, 1
        s.Effects = {}
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("PostEffect") then table.insert(s.Effects, {o = e, v = e.Enabled}); e.Enabled = false
            elseif e:IsA("Atmosphere") then table.insert(s.Effects, {o = e, v = e.Density}); e.Density = 0 end
        end
        for _, d in ipairs(WS:GetDescendants()) do if d:IsA("BasePart") then d.CastShadow = false end end
        s.Emitters = {}
        for _, d in ipairs(WS:GetDescendants()) do
            if d:IsA("ParticleEmitter") and d.Name ~= "VeniceEmitter" then
                table.insert(s.Emitters, {o = d, v = d.Rate}); d.Rate = 0
            end
        end
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    elseif not on and FPS.active then
        FPS.active = false
        local s = FPS.saved
        Lighting.GlobalShadows = s.GlobalShadows
        Lighting.EnvironmentDiffuseScale, Lighting.EnvironmentSpecularScale = s.EnvDiff, s.EnvSpec
        local T = WS.Terrain
        T.WaterWaveSize, T.WaterWaveSpeed = s.WaterWaveSize, s.WaterWaveSpeed
        T.WaterReflectance, T.WaterTransparency = s.WaterReflectance, s.WaterTransparency
        for _, e in ipairs(s.Effects or {}) do
            if e.o.Parent then
                if e.o:IsA("Atmosphere") then e.o.Density = e.v else e.o.Enabled = e.v end
            end
        end
        for _, e in ipairs(s.Emitters or {}) do if e.o.Parent then e.o.Rate = e.v end end
        for _, d in ipairs(WS:GetDescendants()) do if d:IsA("BasePart") then d.CastShadow = true end end
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level07 end)
    end
end

--=====================================================================
--  НЕБО
--=====================================================================
local function getSky()
    local sky = Lighting:FindFirstChildOfClass("Sky")
    if not sky then sky = Instance.new("Sky"); sky.Parent = Lighting end
    return sky
end
local function getAtmo()
    local a = Lighting:FindFirstChildOfClass("Atmosphere")
    if not a then a = Instance.new("Atmosphere"); a.Parent = Lighting end
    return a
end
local SPACE_TEX = { Bk = "rbxassetid://159454299", Dn = "rbxassetid://159454300", Ft = "rbxassetid://159454301",
    Lf = "rbxassetid://159454302", Rt = "rbxassetid://159454303", Up = "rbxassetid://159454304" }

local function applySky()
    local S = Flags.Sky
    Lighting.ClockTime = S.ClockTime
    Lighting.Brightness = S.Brightness
    Lighting.FogColor = S.FogColor
    Lighting.FogEnd = S.FogEnd
    Lighting.FogStart = math.max(0, math.min(S.FogStart, S.FogEnd - 5))
    Lighting.Ambient = S.Ambient
    Lighting.OutdoorAmbient = S.Outdoor
    local sky = getSky()
    sky.StarCount = math.clamp(S.Stars, 0, 10000)
    sky.CelestialBodiesShown = S.Celestial
    local a = getAtmo()
    a.Density = S.Atmosphere and S.Density or 0
    a.Haze = S.Haze
end
local function applySkyTextures(t)
    if not t then return end
    local sky = getSky()
    sky.SkyboxBk, sky.SkyboxDn, sky.SkyboxFt = t.Bk, t.Dn, t.Ft
    sky.SkyboxLf, sky.SkyboxRt, sky.SkyboxUp = t.Lf, t.Rt, t.Up
end

local SKY_PRESETS = {
    ["День"] = { ClockTime=14, Brightness=2, FogEnd=4000, FogColor=Color3.fromRGB(175,205,240), Ambient=Color3.fromRGB(95,100,110), Outdoor=Color3.fromRGB(150,160,175), Stars=2000, Atmosphere=true, Density=0.25, Haze=0 },
    ["Закат"] = { ClockTime=17.7, Brightness=2.3, FogEnd=2600, FogColor=Color3.fromRGB(255,140,75), Ambient=Color3.fromRGB(125,85,70), Outdoor=Color3.fromRGB(190,115,90), Stars=1500, Atmosphere=true, Density=0.35, Haze=1 },
    ["Ночь"] = { ClockTime=0, Brightness=1.2, FogEnd=2000, FogColor=Color3.fromRGB(18,22,42), Ambient=Color3.fromRGB(45,50,72), Outdoor=Color3.fromRGB(58,64,90), Stars=6000, Atmosphere=true, Density=0.2, Haze=0 },
    ["Космос"] = { ClockTime=0, Brightness=0.5, FogEnd=8000, FogColor=Color3.fromRGB(4,4,14), Ambient=Color3.fromRGB(28,28,45), Outdoor=Color3.fromRGB(40,40,65), Stars=9000, Atmosphere=false, Density=0, Haze=0, Tex=SPACE_TEX },
    ["Красный"] = { ClockTime=18.5, Brightness=2, FogEnd=1800, FogColor=Color3.fromRGB(180,30,30), Ambient=Color3.fromRGB(120,40,40), Outdoor=Color3.fromRGB(160,55,55), Stars=3000, Atmosphere=true, Density=0.5, Haze=2 },
    ["Фиолетовый"] = { ClockTime=19, Brightness=1.8, FogEnd=2200, FogColor=Color3.fromRGB(120,60,220), Ambient=Color3.fromRGB(90,60,140), Outdoor=Color3.fromRGB(120,85,190), Stars=4000, Atmosphere=true, Density=0.45, Haze=1 },
    ["Матрица"] = { ClockTime=1, Brightness=1.4, FogEnd=1400, FogColor=Color3.fromRGB(10,60,25), Ambient=Color3.fromRGB(30,90,45), Outdoor=Color3.fromRGB(45,130,65), Stars=2000, Atmosphere=true, Density=0.4, Haze=0 },
    ["Туман"] = { ClockTime=8, Brightness=1.6, FogEnd=650, FogColor=Color3.fromRGB(200,205,215), Ambient=Color3.fromRGB(150,155,165), Outdoor=Color3.fromRGB(180,185,195), Stars=500, Atmosphere=true, Density=0.6, Haze=3 },
    ["Ад"] = { ClockTime=17, Brightness=2.4, FogEnd=1200, FogColor=Color3.fromRGB(255,90,20), Ambient=Color3.fromRGB(140,60,30), Outdoor=Color3.fromRGB(200,90,40), Stars=1000, Atmosphere=true, Density=0.6, Haze=2 },
}
local function applySkyPreset(name)
    if name == "Сброс" then Flags.Sky.Stars = 3000; applySky(); return end
    local p = SKY_PRESETS[name]; if not p then return end
    Flags.Sky.ClockTime, Flags.Sky.Brightness = p.ClockTime, p.Brightness
    Flags.Sky.FogEnd, Flags.Sky.FogColor = p.FogEnd, p.FogColor
    Flags.Sky.Ambient, Flags.Sky.Outdoor = p.Ambient, p.Outdoor
    Flags.Sky.Stars, Flags.Sky.Atmosphere = p.Stars, p.Atmosphere
    Flags.Sky.Density, Flags.Sky.Haze = p.Density, p.Haze
    applySkyTextures(p.Tex); applySky()
end

--=====================================================================
--  ЧАСТИЦЫ
--=====================================================================
local PartHost, Emitter
local TEX = {
    ["Искры"] = "rbxasset://textures/particles/sparkles_main.dds",
    ["Дым"] = "rbxasset://textures/particles/smoke_main.dds",
    ["Огонь"] = "rbxasset://textures/particles/fire_main.dds",
    ["Свечение"] = "rbxasset://textures/particles/glow_main.dds",
    ["Взрыв"] = "rbxasset://textures/particles/explosion01_implosion_main.dds",
}
local function applyParticles()
    if not Flags.Particles.Enabled then
        if PartHost then PartHost:Destroy(); PartHost, Emitter = nil, nil end
        return
    end
    if not (PartHost and PartHost.Parent) then
        PartHost = Instance.new("Part")
        PartHost.Name = "VeniceParticleHost"
        PartHost.Anchored, PartHost.CanCollide = true, false
        PartHost.CanQuery, PartHost.CanTouch = false, false
        PartHost.Transparency = 1; PartHost.Size = Vector3.new(1,1,1)
        PartHost.Parent = WS
        Emitter = Instance.new("ParticleEmitter")
        Emitter.Name = "VeniceEmitter"; Emitter.Parent = PartHost
    end
    local P = Flags.Particles
    Emitter.Texture = P.Texture
    Emitter.Rate = P.Rate
    Emitter.Lifetime = NumberRange.new(P.Lifetime * 0.6, P.Lifetime * 1.4)
    Emitter.Speed = NumberRange.new(P.Speed * 0.5, P.Speed * 1.5)
    Emitter.SpreadAngle = Vector2.new(P.Spread, P.Spread)
    Emitter.Rotation = NumberRange.new(0, 360)
    Emitter.RotSpeed = NumberRange.new(-P.RotSpeed * 30, P.RotSpeed * 30)
    Emitter.Acceleration = Vector3.new(0, P.AccelY, 0)
    Emitter.LightEmission = P.Light
    Emitter.Color = ColorSequence.new(P.Color)
    Emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, P.Size * 0.2), NumberSequenceKeypoint.new(0.5, P.Size),
        NumberSequenceKeypoint.new(1, P.Size * 0.2) })
    Emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0),
        NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1) })
end
local PART_PRESETS = {
    ["Искры"] = { Texture=TEX["Искры"], Rate=45, Speed=3, Lifetime=3, Size=0.6, Spread=180, AccelY=0, RotSpeed=1, Light=1, Color=Color3.fromRGB(255,240,180) },
    ["Снег"] = { Texture=TEX["Искры"], Rate=120, Speed=1, Lifetime=7, Size=0.35, Spread=180, AccelY=-1.5, RotSpeed=0.6, Light=0.1, Color=Color3.fromRGB(255,255,255) },
    ["Огонь"] = { Texture=TEX["Огонь"], Rate=70, Speed=2, Lifetime=1.6, Size=2.2, Spread=45, AccelY=4, RotSpeed=0.4, Light=1, Color=Color3.fromRGB(255,140,40) },
    ["Звёзды"] = { Texture=TEX["Свечение"], Rate=25, Speed=0.6, Lifetime=5, Size=1.1, Spread=180, AccelY=0, RotSpeed=0.2, Light=1, Color=Color3.fromRGB(150,200,255) },
    ["Пузыри"] = { Texture=TEX["Свечение"], Rate=30, Speed=1.2, Lifetime=6, Size=0.9, Spread=180, AccelY=2, RotSpeed=0.3, Light=0.4, Color=Color3.fromRGB(140,255,220) },
    ["Пыль"] = { Texture=TEX["Дым"], Rate=40, Speed=0.8, Lifetime=6, Size=1.6, Spread=180, AccelY=0.2, RotSpeed=0.2, Light=0, Color=Color3.fromRGB(210,205,190) },
    ["Матрица"] = { Texture=TEX["Свечение"], Rate=60, Speed=2.5, Lifetime=3, Size=0.7, Spread=180, AccelY=-2, RotSpeed=0.5, Light=0.8, Color=Color3.fromRGB(60,255,120) },
    ["Кровь"] = { Texture=TEX["Взрыв"], Rate=35, Speed=3, Lifetime=2.5, Size=1.2, Spread=180, AccelY=-3, RotSpeed=0.8, Light=0, Color=Color3.fromRGB(200,20,20) },
}

--=====================================================================
--  SKINCHANGER — СКИНЫ ИЗ ИГРЫ
--=====================================================================
local skinOriginals = setmetatable({}, { __mode = "k" })

local function saveOriginal(part)
    if skinOriginals[part] then return end
    skinOriginals[part] = { TextureID = part:IsA("MeshPart") and part.TextureID or nil,
                            Color = part.Color, Material = part.Material, Reflectance = part.Reflectance }
end
local function restorePart(part)
    local o = skinOriginals[part]
    if not o then return end
    if part:IsA("MeshPart") and o.TextureID then part.TextureID = o.TextureID end
    part.Color, part.Material, part.Reflectance = o.Color, o.Material, o.Reflectance
    skinOriginals[part] = nil
end

local function skinParts(inst)
    local out = {}
    for _, d in ipairs(inst:GetDescendants()) do
        if d:IsA("MeshPart") or d:IsA("SpecialMesh")
            or d:IsA("Decal") or d:IsA("Texture") or d:IsA("BasePart") then
            table.insert(out, d)
        end
    end
    return out
end

local function applySkinTo(inst, slot)
    if not inst then return end
    local tex = slot and slot.TextureId or ""
    local colored = false
    for _, d in ipairs(inst:GetDescendants()) do
        if d:IsA("MeshPart") then
            saveOriginal(d)
            if tex ~= "" then d.TextureID = tex end
            d.Color = Flags.Skin.Color
            if Flags.Skin.Material ~= "Изначально" then
                local m = Enum.Material[Flags.Skin.Material]; if m then d.Material = m end
            end
            d.Reflectance = Flags.Skin.Reflectance
            colored = true
        elseif d:IsA("SpecialMesh") then
            if tex ~= "" then d.TextureId = tex end
        elseif d:IsA("Decal") or d:IsA("Texture") then
            if tex ~= "" then d.Texture = tex end
        elseif d:IsA("BasePart") then
            saveOriginal(d)
            d.Color = Flags.Skin.Color
            if Flags.Skin.Material ~= "Изначально" then
                local m = Enum.Material[Flags.Skin.Material]; if m then d.Material = m end
            end
            d.Reflectance = Flags.Skin.Reflectance
        end
    end
    return colored
end

local function toolKind(tool)
    local n = tool.Name
    if matchAny(n, GLOVE_WORDS) then return "Gloves" end
    if matchAny(n, KNIFE_WORDS) then return "Knife" end
    return "Weapon"
end

local function equippedTool()
    return LP.Character and LP.Character:FindFirstChildOfClass("Tool")
end

local function gloveInstances()
    local out = {}
    local function scan(root)
        if not root then return end
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("BasePart") and matchAny(d.Name, GLOVE_WORDS) then table.insert(out, d) end
        end
    end
    scan(LP.Character)
    scan(WS.CurrentCamera)
    return out
end

local function applyEquipped()
    if not Flags.Skin.Enabled then return end
    local tool = equippedTool()
    if tool then
        local kind = toolKind(tool)
        applySkinTo(tool, Flags.Skin.Slots[kind])
    end
    local gloves = gloveInstances()
    if #gloves > 0 then
        for _, g in ipairs(gloves) do applySkinTo(g, Flags.Skin.Slots.Gloves) end
    end
end

local function hookTool(tool)
    if not tool:IsA("Tool") then return end
    tool.Equipped:Connect(function()
        if not Flags.Skin.Enabled or not Flags.Skin.AutoApply then return end
        task.wait(0.05)
        applyEquipped()
    end)
end

if LP.Character then
    for _, t in ipairs(LP.Character:GetChildren()) do hookTool(t) end
    LP.Character.ChildAdded:Connect(function(ch)
        if ch:IsA("Tool") then
            hookTool(ch)
            if Flags.Skin.Enabled and Flags.Skin.AutoApply then
                task.wait(0.05); applyEquipped()
            end
        end
    end)
end
do
    local bp = LP:FindFirstChildOfClass("Backpack")
    if bp then bp.ChildAdded:Connect(hookTool) end
end
LP.CharacterAdded:Connect(function(char)
    task.wait(1)
    for _, t in ipairs(char:GetChildren()) do hookTool(t) end
    if Flags.Skin.Enabled then applyEquipped() end
end)

--  СКАНЕР КАТАЛОГА СКИНОВ ИГРЫ
local catalog = {}

local function scanCatalog()
    catalog = {}
    local seen = {}
    local function grab(obj)
        local id
        if obj:IsA("MeshPart") then id = obj.TextureID
        elseif obj:IsA("SpecialMesh") then id = obj.TextureId
        elseif obj:IsA("Decal") or obj:IsA("Texture") then id = obj.Texture end
        if not id or id == "" or seen[id] then return end
        seen[id] = true
        local path, a, depth = obj.Name, obj.Parent, 0
        while a and a ~= RS and a ~= WS and depth < 3 do
            path = a.Name .. " / " .. path; a = a.Parent; depth = depth + 1
        end
        table.insert(catalog, { id = id, name = path })
    end

    local list = RS:GetDescendants()
    for i = 1, math.min(#list, 30000) do grab(list[i]) end
    --  плюс то, что реально в руках и на персонаже
    local tool = equippedTool()
    if tool then for _, d in ipairs(tool:GetDescendants()) do grab(d) end end
    for _, d in ipairs(gloveInstances()) do grab(d) end

    table.sort(catalog, function(a, b) return a.name < b.name end)
    return catalog
end

--=====================================================================
--  НАПОЛНЕНИЕ ВКЛАДОК
--=====================================================================
addSection(tabESP, "Движок отрисовки")
addDropdown(tabESP, "Режим ESP", { "Billboard", "Авто", "Drawing" }, Flags.ESP.Mode, function(v) Flags.ESP.Mode = v end)
addLabel(tabESP, "Billboard — работает всегда. Drawing — тоньше, но требует поддержки экзекутора.")

addSection(tabESP, "Основное")
addToggle(tabESP, "Включить ESP", Flags.ESP.Enabled, function(v) Flags.ESP.Enabled = v end)
addToggle(tabESP, "Коробка", Flags.ESP.Box, function(v) Flags.ESP.Box = v end)
addToggle(tabESP, "Заливка коробки", Flags.ESP.BoxFill, function(v) Flags.ESP.BoxFill = v end)
addToggle(tabESP, "Подсветка сквозь стены (Highlight)", Flags.ESP.Chams, function(v) Flags.ESP.Chams = v end)

addSection(tabESP, "Информация")
addToggle(tabESP, "Имя", Flags.ESP.Name, function(v) Flags.ESP.Name = v end)
addToggle(tabESP, "Здоровье", Flags.ESP.Health, function(v) Flags.ESP.Health = v end)
addToggle(tabESP, "Оружие", Flags.ESP.Weapon, function(v) Flags.ESP.Weapon = v end)
addToggle(tabESP, "Дистанция", Flags.ESP.Distance, function(v) Flags.ESP.Distance = v end)
addToggle(tabESP, "Трассеры (только Drawing)", Flags.ESP.Tracer, function(v) Flags.ESP.Tracer = v end)

addSection(tabESP, "Настройки")
addToggle(tabESP, "Цвет команды", Flags.ESP.TeamColor, function(v) Flags.ESP.TeamColor = v end)
addToggle(tabESP, "Игнорировать союзников", Flags.ESP.TeamCheck, function(v) Flags.ESP.TeamCheck = v end)
addToggle(tabESP, "Показывать себя", Flags.ESP.ShowSelf, function(v) Flags.ESP.ShowSelf = v end)
addColorPicker(tabESP, "Цвет ESP", Flags.ESP.Color, function(c) Flags.ESP.Color = c end)
addSlider(tabESP, "Макс. дистанция", 100, 8000, Flags.ESP.MaxDistance, 0, function(v) Flags.ESP.MaxDistance = v end)

-- Игроки
addSection(tabList, "Данные игроков")
local listScroll = addScroll(tabList, 340)
local function refreshList()
    for _, c in ipairs(listScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    local cam = WS.CurrentCamera
    local sorted = {}
    for _, p in ipairs(Players:GetPlayers()) do table.insert(sorted, p) end
    table.sort(sorted, function(a, b) return a.Name:lower() < b.Name:lower() end)
    for _, p in ipairs(sorted) do
        local char = p.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = getRoot(char)
        local dist = (root and cam) and math.floor((root.Position - cam.CFrame.Position).Magnitude) or 0
        local row = new("Frame", { Parent = listScroll, Size = UDim2.new(1,0,0,28), BackgroundColor3 = Theme.Bg, BorderSizePixel = 0 })
        corner(row,5)
        new("Frame", { Parent = row, Size = UDim2.new(0,3,0,18), Position = UDim2.new(0,4,0.5,-9),
            BackgroundColor3 = (p.TeamColor and p.TeamColor.Color) or Theme.Sub, BorderSizePixel = 0 })
        new("TextLabel", { Parent = row, BackgroundTransparency = 1, Position = UDim2.new(0,12,0,0),
            Size = UDim2.new(0.5,0,1,0), Text = p.DisplayName .. "  (@" .. p.Name .. ")",
            Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
        new("TextLabel", { Parent = row, BackgroundTransparency = 1, Position = UDim2.new(0.5,0,0,0),
            Size = UDim2.new(0.2,0,1,0), Text = string.format("HP %d", hum and math.floor(hum.Health) or 0),
            Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Color3.fromRGB(90,220,140),
            TextXAlignment = Enum.TextXAlignment.Left })
        new("TextLabel", { Parent = row, BackgroundTransparency = 1, Position = UDim2.new(0.7,0,0,0),
            Size = UDim2.new(0.3,0,1,0), Text = (getWeapon(p, char) or "—") .. "  •  " .. dist .. "m",
            Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.Sub,
            TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd })
    end
end

-- Визуал
addSection(tabVis, "Обзор (FOV)")
addToggle(tabVis, "Изменить FOV", Flags.Visual.FOVEnabled, function(v) Flags.Visual.FOVEnabled = v end)
addSlider(tabVis, "Значение FOV", 60, 150, Flags.Visual.FOV, 0, function(v) Flags.Visual.FOV = v end)
addSection(tabVis, "Производительность")
addToggle(tabVis, "FPS Boost", Flags.Visual.FPSBoost, function(v) setFPSBoost(v) end)
addButton(tabVis, "Убрать тени со всех объектов", function()
    for _, d in ipairs(WS:GetDescendants()) do if d:IsA("BasePart") then d.CastShadow = false end end
end)

-- Небо
addSection(tabSky, "Пресеты")
addDropdown(tabSky, "Пресет", { "День","Закат","Ночь","Космос","Красный","Фиолетовый","Матрица","Туман","Ад" },
    "День", function(v) applySkyPreset(v) end)
addButton(tabSky, "Сбросить небо", function() applySkyPreset("Сброс") end)
addSection(tabSky, "Ручная настройка")
addSlider(tabSky, "Время суток", 0, 24, Flags.Sky.ClockTime, 1, function(v) Flags.Sky.ClockTime = v; applySky() end)
addSlider(tabSky, "Яркость", 0, 5, Flags.Sky.Brightness, 1, function(v) Flags.Sky.Brightness = v; applySky() end)
addSlider(tabSky, "Дальность тумана", 100, 10000, Flags.Sky.FogEnd, 0, function(v) Flags.Sky.FogEnd = v; applySky() end)
addColorPicker(tabSky, "Цвет тумана", Flags.Sky.FogColor, function(c) Flags.Sky.FogColor = c; applySky() end)
addColorPicker(tabSky, "Освещение", Flags.Sky.Ambient, function(c) Flags.Sky.Ambient = c; applySky() end)
addColorPicker(tabSky, "Уличный свет", Flags.Sky.Outdoor, function(c) Flags.Sky.Outdoor = c; applySky() end)
addSlider(tabSky, "Кол-во звёзд", 0, 10000, Flags.Sky.Stars, 0, function(v) Flags.Sky.Stars = v; applySky() end)
addToggle(tabSky, "Солнце / Луна", Flags.Sky.Celestial, function(v) Flags.Sky.Celestial = v; applySky() end)
addToggle(tabSky, "Атмосфера", Flags.Sky.Atmosphere, function(v) Flags.Sky.Atmosphere = v; applySky() end)
addSlider(tabSky, "Плотность", 0, 1, Flags.Sky.Density, 2, function(v) Flags.Sky.Density = v; applySky() end)

-- Частицы
addSection(tabPart, "Частицы")
addToggle(tabPart, "Включить частицы", Flags.Particles.Enabled, function(v) Flags.Particles.Enabled = v; applyParticles() end)
addDropdown(tabPart, "Пресет", { "Искры","Снег","Огонь","Звёзды","Пузыри","Пыль","Матрица","Кровь" }, "Искры", function(v)
    local p = PART_PRESETS[v]; if not p then return end
    Flags.Particles.Texture, Flags.Particles.Rate = p.Texture, p.Rate
    Flags.Particles.Speed, Flags.Particles.Lifetime = p.Speed, p.Lifetime
    Flags.Particles.Size, Flags.Particles.Spread = p.Size, p.Spread
    Flags.Particles.AccelY, Flags.Particles.RotSpeed = p.AccelY, p.RotSpeed
    Flags.Particles.Light, Flags.Particles.Color = p.Light, p.Color
    applyParticles()
end)
addDropdown(tabPart, "Текстура", { "Искры","Дым","Огонь","Свечение","Взрыв" }, "Искры", function(v)
    Flags.Particles.Texture = TEX[v]; applyParticles()
end)
addSlider(tabPart, "Количество", 1, 400, Flags.Particles.Rate, 0, function(v) Flags.Particles.Rate = v; applyParticles() end)
addSlider(tabPart, "Скорость", 0, 30, Flags.Particles.Speed, 1, function(v) Flags.Particles.Speed = v; applyParticles() end)
addSlider(tabPart, "Время жизни", 0.3, 15, Flags.Particles.Lifetime, 1, function(v) Flags.Particles.Lifetime = v; applyParticles() end)
addSlider(tabPart, "Размер", 0.05, 8, Flags.Particles.Size, 2, function(v) Flags.Particles.Size = v; applyParticles() end)
addSlider(tabPart, "Разброс", 0, 180, Flags.Particles.Spread, 0, function(v) Flags.Particles.Spread = v; applyParticles() end)
addSlider(tabPart, "Гравитация", -20, 20, Flags.Particles.AccelY, 1, function(v) Flags.Particles.AccelY = v; applyParticles() end)
addSlider(tabPart, "Свечение", 0, 1, Flags.Particles.Light, 2, function(v) Flags.Particles.Light = v; applyParticles() end)
addColorPicker(tabPart, "Цвет", Flags.Particles.Color, function(c) Flags.Particles.Color = c; applyParticles() end)

-- Скины ---------------------------------------------------------------
addSection(tabSkin, "SkinChanger")
addToggle(tabSkin, "Включить SkinChanger", Flags.Skin.Enabled, function(v)
    Flags.Skin.Enabled = v
    if v then applyEquipped() else
        for _, d in pairs(skinOriginals) do end
        for _, t in ipairs((LP.Character and LP.Character:GetChildren()) or {}) do
            if t:IsA("Tool") then for _, d in ipairs(t:GetDescendants()) do restorePart(d) end end
        end
        for _, g in ipairs(gloveInstances()) do restorePart(g) end
    end
end)
addToggle(tabSkin, "Авто-применение при смене оружия", Flags.Skin.AutoApply, function(v) Flags.Skin.AutoApply = v end)
addToggle(tabSkin, "RGB перелив", Flags.Skin.Rainbow, function(v) Flags.Skin.Rainbow = v end)

addSection(tabSkin, "Цель скина")
addDropdown(tabSkin, "Куда применять", { "Оружие", "Ножи", "Перчатки" }, "Оружие", function(v)
    Flags.Skin.Target = (v == "Ножи") and "Knife" or (v == "Перчатки") and "Gloves" or "Weapon"
    updateTargetLabel()
end)
local targetLabel = addLabel(tabSkin, "Выбранный скин: —")

local function updateTargetLabel()
    local s = Flags.Skin.Slots[Flags.Skin.Target]
    local rus = Flags.Skin.Target == "Knife" and "Ножи" or Flags.Skin.Target == "Gloves" and "Перчатки" or "Оружие"
    targetLabel.Text = "Цель: " .. rus .. "   |   Скин: " .. (s.Name ~= "" and s.Name or "—")
end

addSection(tabSkin, "Каталог скинов из игры")
addLabel(tabSkin, "Жми «Сканировать» — вытащу все текстуры оружия, ножей и перчаток из игры.")
local catalogScroll = addScroll(tabSkin, 260)
local catalogSearch = addTextBox(tabSkin, "Поиск", "", function(txt)
    Flags.Skin.Search = string.lower(txt)
end)

local function fillCatalog()
    for _, c in ipairs(catalogScroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
    local filter = Flags.Skin.Search or ""
    local shown = 0
    for _, item in ipairs(catalog) do
        if filter == "" or string.find(string.lower(item.name), filter, 1, true) then
            shown = shown + 1
            if shown > 300 then break end
            local b = new("TextButton", { Parent = catalogScroll, Size = UDim2.new(1,0,0,26),
                BackgroundColor3 = Theme.Bg, BorderSizePixel = 0, Text = item.name,
                Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.Sub,
                TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false })
            corner(b,5)
            new("UIPadding", { Parent = b, PaddingLeft = UDim.new(0,8) })
            b.MouseEnter:Connect(function() b.BackgroundColor3 = Theme.Hover; b.TextColor3 = Theme.Text end)
            b.MouseLeave:Connect(function()
                local sel = Flags.Skin.Slots[Flags.Skin.Target]
                b.BackgroundColor3 = (sel.TextureId == item.id) and Theme.Hover or Theme.Bg
                b.TextColor3 = (sel.TextureId == item.id) and Theme.Accent or Theme.Sub
            end)
            b.MouseButton1Click:Connect(function()
                local slot = Flags.Skin.Slots[Flags.Skin.Target]
                slot.TextureId = item.id
                slot.Name = item.name
                Flags.Skin.Enabled = true
                updateTargetLabel()
                applyEquipped()
                for _, c in ipairs(catalogScroll:GetChildren()) do
                    if c:IsA("TextButton") then c.BackgroundColor3 = Theme.Bg; c.TextColor3 = Theme.Sub end
                end
                b.BackgroundColor3 = Theme.Hover; b.TextColor3 = Theme.Accent
            end)
            if Flags.Skin.Slots[Flags.Skin.Target].TextureId == item.id then
                b.BackgroundColor3 = Theme.Hover; b.TextColor3 = Theme.Accent
            end
        end
    end
    if shown == 0 then
        local l = new("TextButton", { Parent = catalogScroll, Size = UDim2.new(1,0,0,26),
            BackgroundColor3 = Theme.Bg, BorderSizePixel = 0, Text = "Ничего не найдено",
            Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Left })
        new("UIPadding", { Parent = l, PaddingLeft = UDim.new(0,8) })
    end
end

addButton(tabSkin, "Сканировать скины в игре", function()
    task.spawn(function()
        scanCatalog()
        fillCatalog()
        print("[Venice] Найдено скинов: " .. #catalog)
    end)
end)
addButton(tabSkin, "Обновить список", fillCatalog)

addSection(tabSkin, "Ручная правка")
addButton(tabSkin, "Применить сейчас", function() Flags.Skin.Enabled = true; applyEquipped() end)
addButton(tabSkin, "Вернуть оригинал", function()
    for _, t in ipairs((LP.Character and LP.Character:GetChildren()) or {}) do
        if t:IsA("Tool") then for _, d in ipairs(t:GetDescendants()) do restorePart(d) end end
    end
    for _, g in ipairs(gloveInstances()) do restorePart(g) end
end)
addDropdown(tabSkin, "Материал", { "Изначально","Plastic","Metal","Wood","WoodPlanks","Marble","Slate",
    "Concrete","Granite","Brick","Glass","Neon","ForceField","Ice","DiamondPlate","Foil","Cobblestone",
    "Sand","Fabric","Grass","Asphalt","CorrodedMetal" }, Flags.Skin.Material, function(v)
    Flags.Skin.Material = v; applyEquipped()
end)
addColorPicker(tabSkin, "Цвет оружия", Flags.Skin.Color, function(c)
    Flags.Skin.Color = c
    if Flags.Skin.Enabled and not Flags.Skin.Rainbow then applyEquipped() end
end)
addSlider(tabSkin, "Отражаемость", 0, 1, Flags.Skin.Reflectance, 2, function(v)
    Flags.Skin.Reflectance = v; if Flags.Skin.Enabled then applyEquipped() end
end)
addTextBox(tabSkin, "Свой Texture ID", "", function(txt)
    Flags.Skin.Slots[Flags.Skin.Target].TextureId = txt
    Flags.Skin.Slots[Flags.Skin.Target].Name = "custom"
    updateTargetLabel(); applyEquipped()
end)

-- BunnyHop
addSection(tabBhop, "AutoBunnyHop")
addToggle(tabBhop, "Включить AutoBunnyHop", Flags.Bhop.Enabled, function(v) Flags.Bhop.Enabled = v end)
addToggle(tabBhop, "Работать без удержания пробела", Flags.Bhop.Always, function(v) Flags.Bhop.Always = v end)
addToggle(tabBhop, "Только при движении", Flags.Bhop.RequireMove, function(v) Flags.Bhop.RequireMove = v end)
addToggle(tabBhop, "Авто-стрейф в воздухе", Flags.Bhop.AutoStrafe, function(v) Flags.Bhop.AutoStrafe = v end)
addSlider(tabBhop, "Угол стрейфа", 5, 70, Flags.Bhop.StrafeAngle, 0, function(v) Flags.Bhop.StrafeAngle = v end)
addSlider(tabBhop, "Сила прыжка", 30, 200, Flags.Bhop.JumpPower, 0, function(v)
    Flags.Bhop.JumpPower = v
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum.UseJumpPower = true; hum.JumpPower = v end) end
end)

-- Настройки
addSection(tabCfg, "Интерфейс")
addColorPicker(tabCfg, "Акцентный цвет", Theme.Accent, function(c)
    Theme.Accent = c
    for _, b in pairs(TabBtns) do
        local i = b:FindFirstChildOfClass("Frame"); if i then i.BackgroundColor3 = c end
    end
end)
addSlider(tabCfg, "Прозрачность окна", 0, 0.6, Flags.Menu.Transparency, 2, function(v)
    Flags.Menu.Transparency = v; Main.BackgroundTransparency = v
end)
addTextBox(tabCfg, "Клавиша меню", Flags.Menu.Key, function(txt) Flags.Menu.Key = txt end)
addButton(tabCfg, "Пересоздать ESP", function()
    for p, c in pairs(espCache) do
        if c.d then destroyDrawingESP(c.d) end
        if c.bb then c.bb:Destroy() end
        espCache[p] = nil
    end
end)
addSection(tabCfg, "Диагностика")
local diagLabel = addLabel(tabCfg, "Ошибок нет")
addLabel(tabCfg, "Drawing API: " .. (drawingOK and "доступен" or "недоступен"))

--=====================================================================
--  ВОДЯНОЙ ЗНАК
--=====================================================================
local wm = new("Frame", { Parent = ScreenGui, Position = UDim2.new(0,14,1,-44), Size = UDim2.new(0,400,0,30),
    BackgroundColor3 = Theme.Bg, BorderSizePixel = 0 })
corner(wm,7); stroke(wm, Theme.Stroke, 1, 0.4)
new("TextLabel", { Parent = wm, BackgroundTransparency = 1, Position = UDim2.new(0,10,0,0),
    Size = UDim2.new(0,80,1,0), Text = "VENICE", Font = Enum.Font.GothamBold, TextSize = 12,
    TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left })
local wmText = new("TextLabel", { Parent = wm, BackgroundTransparency = 1, Position = UDim2.new(0,66,0,0),
    Size = UDim2.new(1,-76,1,0), Text = "", Font = Enum.Font.GothamMedium, TextSize = 12,
    TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd)

--=====================================================================
--  ЦИКЛЫ
--=====================================================================
local frames, lastT, hue = 0, os.clock(), 0

RunService.RenderStepped:Connect(function(dt)
    local ok, err = pcall(updateESP)
    espErr = ok and "" or tostring(err)
    pcall(updateHighlights)

    if PartHost and PartHost.Parent then
        local cam = WS.CurrentCamera
        if cam then PartHost.CFrame = CFrame.new(cam.CFrame.Position) end
    end

    if Flags.Skin.Enabled and Flags.Skin.Rainbow then
        hue = (hue + dt * 0.35) % 1
        local col = Color3.fromHSV(hue, 0.85, 1)
        local tool = equippedTool()
        if tool then
            for _, d in ipairs(tool:GetDescendants()) do
                if d:IsA("BasePart") then d.Color = col end
            end
        end
    end

    frames = frames + 1
    local now = os.clock()
    if now - lastT >= 0.5 then
        local fps = math.floor(frames / (now - lastT))
        frames, lastT = 0, now
        local txt = string.format("FPS: %d  •  Игроков: %d  •  ESP: %s",
            fps, #Players:GetPlayers(), Flags.ESP.Enabled and "ON" or "OFF")
        if espErr ~= "" then txt = txt .. "  •  ERR: " .. espErr end
        wmText.Text = txt
        diagLabel.Text = espErr ~= "" and ("Ошибка: " .. espErr) or "Ошибок нет"
    end
end)

RunService.RenderStepped:Connect(function()
    if not Flags.Bhop.Enabled then return end
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    local root = getRoot(char)
    if not root then return end

    local grounded = hum.FloorMaterial ~= Enum.Material.Air
        or hum:GetState() == Enum.HumanoidStateType.Landed

    if grounded then
        if Flags.Bhop.Always or UIS:IsKeyDown(Enum.KeyCode.Space) then
            local moving = true
            if Flags.Bhop.RequireMove then
                local v = root.AssemblyLinearVelocity
                moving = Vector3.new(v.X, 0, v.Z).Magnitude > 2
            end
            if moving then
                hum.Jump = true
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
            end
        end
    elseif Flags.Bhop.AutoStrafe then
        local v = root.AssemblyLinearVelocity
        local flat = Vector3.new(v.X, 0, v.Z)
        if flat.Magnitude > 4 then
            hum.AutoRotate = false
            local yaw = math.atan2(-flat.X, -flat.Z)
            root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw + math.rad(Flags.Bhop.StrafeAngle), 0)
        end
    else
        hum.AutoRotate = true
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        task.wait(0.5)
        if Pages["Игроки"].Visible then refreshList() end
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        task.wait(0.3)
        if Flags.Skin.Enabled and Flags.Skin.AutoApply then applyEquipped() end
    end
end)

--=====================================================================
--  СВОРАЧИВАНИЕ / КНОПКИ / ХОТКЕИ
--=====================================================================
local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Sidebar.Visible = not minimized
    Content.Visible = not minimized
    Sep.Visible = not minimized
    Tween:Create(Main, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = minimized and UDim2.new(0,WIN_W,0,38) or UDim2.new(0,WIN_W,0,WIN_H) }):Play()
end)

closeBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
    for _, c in pairs(espCache) do
        if c.d then destroyDrawingESP(c.d) end
        if c.bb then c.bb:Destroy() end
    end
    if PartHost then PartHost:Destroy() end
    pcall(function() RunService:UnbindFromRenderStep("VeniceFOV") end)
end)

UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    local key = Flags.Menu.Key
    if i.KeyCode == Enum.KeyCode.RightShift or i.KeyCode == Enum.KeyCode.Insert
        or (key and key ~= "" and i.KeyCode == Enum.KeyCode[key]) then
        Main.Visible = not Main.Visible
    end
end)

--=====================================================================
--  СТАРТ
--=====================================================================
Pages["ESP"].Visible = true
TabBtns["ESP"].BackgroundColor3 = Theme.Card
TabBtns["ESP"].TextColor3 = Theme.Text
local fi = TabBtns["ESP"]:FindFirstChildOfClass("Frame")
if fi then fi.Visible = true end

updateTargetLabel()
applySky()
task.spawn(function() scanCatalog(); fillCatalog() end)
print("[Venice] Blox Strike v3 loaded. Меню: RightShift / Insert")
