--[[=========================================================
    KONTRA  •  Venice Script  •  v2 (fix)
    Игра:     https://www.roblox.com/games/87204735676240
    Исправлено: ESP (не заполнялась таблица игроков),
    аимбот (приоритет кадра выше камеры игры),
    FOV (поздний приоритет + защита от ADS + диагностика)
=========================================================--]]

if getgenv().KontraVenice_Unload then pcall(getgenv().KontraVenice_Unload) end

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")

local genv = (getgenv and getgenv()) or _G
local LP = Players.LocalPlayer
local Connections = {}

local function bind(sig, fn)
    local c = sig:Connect(fn); Connections[#Connections + 1] = c; return c
end
local function guiParent()
    local ok, hui = pcall(function() return gethui() end)
    if ok and hui then return hui end
    local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok2 then return cg end
    return LP:WaitForChild("PlayerGui")
end

--===== КОНФИГ =====
local Config = {
    ESP = true, Boxes = true, Names = true, Health = true, Distance = true,
    Tracers = false, TeamCheck = true, ESPMaxDist = 1000,

    Aimbot = true, AimPart = "Head", FOVRadius = 140, AimSmooth = 0.3,
    AimOnHold = false, WallCheck = false, ShowFOV = true,
    AimMode = "Camera", AimMouseSens = 0.6,

    SpeedOn = true, Speed = 24, JumpOn = true, JumpPower = 55,
    InfJump = true, Fullbright = false, NoClip = false,
    Fly = false, FlySpeed = 55, Hitbox = false, HitboxSize = 9,
    FovOn = false, FovSkipADS = true, CameraFOV = 90,
}

--===== ХЕЛПЕРЫ =====
local function getCam() return workspace.CurrentCamera end
local function myHum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function isEnemy(plr)
    if plr == LP then return false end
    if Config.TeamCheck and plr.Team and LP.Team and plr.Team == LP.Team then return false end
    return true
end

local EXCLUDE = Enum.RaycastFilterType.Exclude or Enum.RaycastFilterType.Blacklist
local rayParams = RaycastParams.new()
rayParams.FilterType = EXCLUDE

local function visible(cam, part)
    if not Config.WallCheck then return true end
    local ignore = { part }
    if LP.Character then table.insert(ignore, LP.Character) end
    rayParams.FilterDescendantsInstances = ignore
    local origin = cam.CFrame.Position
    return workspace:Raycast(origin, part.Position - origin, rayParams) == nil
end

--===== РИСОВАНИЕ (Drawing / Frame) =====
local DrawingLib = genv.Drawing
local HAS_DRAWING = false
if DrawingLib then
    HAS_DRAWING = pcall(function()
        local o = DrawingLib.new("Square"); o.Visible = false; o:Remove()
    end)
end

local espGui
if not HAS_DRAWING then
    espGui = Instance.new("ScreenGui")
    espGui.Name = "KontraVeniceESP"
    espGui.ResetOnSpawn, espGui.IgnoreGuiInset = false, true
    espGui.Parent = guiParent()
end

local function newBox(col)
    if HAS_DRAWING then
        local sq = DrawingLib.new("Square")
        sq.Thickness, sq.Filled, sq.Color, sq.Visible = 1, false, col, false
        return { remove = function() pcall(function() sq:Remove() end) end,
                 set = function(x,y,w,h,vis,c)
                     sq.Position, sq.Size = Vector2.new(x,y), Vector2.new(w,h)
                     sq.Color, sq.Visible = c or col, vis end }
    end
    local f = Instance.new("Frame")
    f.BackgroundTransparency, f.BorderSizePixel, f.Visible = 1, 1, false
    f.BorderColor3, f.Parent = col, espGui
    return { remove = function() f:Destroy() end,
             set = function(x,y,w,h,vis,c)
                 f.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
                 f.Size = UDim2.fromOffset(math.floor(w), math.floor(h))
                 f.BorderColor3, f.Visible = c or col, vis end }
end

local function newText(col, size)
    size = size or 14
    if HAS_DRAWING then
        local t = DrawingLib.new("Text")
        t.Size, t.Center, t.Outline, t.OutlineColor, t.Color, t.Visible =
            size, true, true, Color3.new(0,0,0), col, false
        return { remove = function() pcall(function() t:Remove() end) end,
                 set = function(x,y,txt,vis,c)
                     t.Position, t.Text = Vector2.new(x,y), txt
                     t.Color, t.Visible = c or col, vis end }
    end
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency, l.Font, l.TextSize = 1, Enum.Font.GothamBold, size
    l.TextStrokeTransparency, l.TextStrokeColor3 = 0.5, Color3.new(0,0,0)
    l.TextColor3, l.Size, l.TextXAlignment, l.Visible, l.Parent =
        col, UDim2.fromOffset(220, size), Enum.TextXAlignment.Center, false, espGui
    return { remove = function() l:Destroy() end,
             set = function(x,y,txt,vis,c)
                 l.Position = UDim2.fromOffset(math.floor(x-110), math.floor(y))
                 l.Text, l.TextColor3, l.Visible = txt, c or col, vis end }
end

local function newTracer(col)
    if HAS_DRAWING then
        local ln = DrawingLib.new("Line")
        ln.Thickness, ln.Color, ln.Visible = 1, col, false
        return { remove = function() pcall(function() ln:Remove() end) end,
                 set = function(x1,y1,x2,y2,vis,c)
                     ln.From, ln.To = Vector2.new(x1,y1), Vector2.new(x2,y2)
                     ln.Color, ln.Visible = c or col, vis end }
    end
    local f = Instance.new("Frame")
    f.BackgroundColor3, f.BorderSizePixel, f.AnchorPoint, f.Visible, f.Parent =
        col, 0, Vector2.new(0,0.5), false, espGui
    return { remove = function() f:Destroy() end,
             set = function(x1,y1,x2,y2,vis,c)
                 local dx, dy = x2-x1, y2-y1
                 f.Position = UDim2.fromOffset(math.floor(x1), math.floor(y1))
                 f.Size = UDim2.fromOffset(math.floor(math.sqrt(dx*dx+dy*dy)), 1)
                 f.Rotation = math.deg(math.atan2(dy, dx))
                 f.BackgroundColor3, f.Visible = c or col, vis end }
end

local function newCircle(col)
    if HAS_DRAWING then
        local ci = DrawingLib.new("Circle")
        ci.Thickness, ci.Filled, ci.NumSides, ci.Color, ci.Visible = 1, false, 64, col, false
        return { remove = function() pcall(function() ci:Remove() end) end,
                 set = function(x,y,r,vis,c)
                     ci.Position, ci.Radius = Vector2.new(x,y), r
                     ci.Color, ci.Visible = c or col, vis end }
    end
    local f = Instance.new("Frame")
    f.BackgroundTransparency, f.BorderSizePixel, f.AnchorPoint, f.Visible, f.Parent =
        1, 1, Vector2.new(0.5,0.5), false, espGui
    f.BorderColor3 = col
    Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
    return { remove = function() f:Destroy() end,
             set = function(x,y,r,vis,c)
                 f.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
                 f.Size = UDim2.fromOffset(math.floor(r*2), math.floor(r*2))
                 f.BorderColor3, f.Visible = c or col, vis end }
end

--===== ESP (ТЕПЕРЬ ТАБЛИЦА ЗАПОЛНЯЕТСЯ) =====
local GREEN = Color3.fromRGB(0, 255, 140)
local RED = Color3.fromRGB(255, 80, 80)
local espData = {}

local function getESP(plr)
    local o = espData[plr]
    if not o then
        o = { box = newBox(GREEN), name = newText(Color3.new(1,1,1), 14),
              hp = newText(Color3.new(1,1,1), 12), dist = newText(Color3.fromRGB(205,205,205), 12),
              tracer = newTracer(GREEN) }
        espData[plr] = o
    end
    return o
end

local function dropESP(plr)
    local o = espData[plr]
    if o then
        for _, k in pairs(o) do pcall(k.remove) end
        espData[plr] = nil
    end
end

bind(Players.PlayerRemoving, dropESP)

--===== АИМБОТ =====
local holding = false
bind(UserInputService.InputBegan, function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton2 then holding = true end
end)
bind(UserInputService.InputEnded, function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton2 then holding = false end
end)

local function targetPart(plr)
    local char = plr.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    return char:FindFirstChild(Config.AimPart) or char:FindFirstChild("HumanoidRootPart")
end

local function findTarget(cam)
    local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
    local best, bestDist = nil, Config.FOVRadius
    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) then
            local part = targetPart(plr)
            if part then
                local sp = cam:WorldToViewportPoint(part.Position)
                if sp.Z > 0 then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d < bestDist and visible(cam, part) then best, bestDist = plr, d end
                end
            end
        end
    end
    return best
end

local mousemoverel = genv.mousemoverel

--===== МИСК =====
local fbApplied, fbOld = false, {}
local noclipSet = {}
local hitboxOrig = {}

local function setFullbright(on)
    if on and not fbApplied then
        fbOld = { Lighting.Ambient, Lighting.OutdoorAmbient, Lighting.Brightness, Lighting.ClockTime, Lighting.FogEnd }
        Lighting.Ambient, Lighting.OutdoorAmbient = Color3.fromRGB(178,178,178), Color3.fromRGB(178,178,178)
        Lighting.Brightness, Lighting.ClockTime, Lighting.FogEnd = 3, 14, 1e5
        fbApplied = true
    elseif not on and fbApplied then
        Lighting.Ambient, Lighting.OutdoorAmbient, Lighting.Brightness, Lighting.ClockTime, Lighting.FogEnd =
            fbOld[1], fbOld[2], fbOld[3], fbOld[4], fbOld[5]
        fbApplied = false
    end
end

local function applyHitbox()
    local char = LP.Character
    if not char then return end
    for _, n in ipairs({ "Head", "UpperTorso", "Torso", "LowerTorso" }) do
        local p = char:FindFirstChild(n)
        if p and p:IsA("BasePart") then
            if Config.Hitbox then
                if not hitboxOrig[p] then hitboxOrig[p] = p.Size end
                p.Size = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
            elseif hitboxOrig[p] then
                p.Size = hitboxOrig[p]; hitboxOrig[p] = nil
            end
        end
    end
end

bind(LP.CharacterAdded, function()
    task.wait(0.4)
    hitboxOrig = {}
    applyHitbox()
end)

bind(UserInputService.JumpRequest, function()
    if Config.InfJump then
        local h = myHum()
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

bind(RunService.Heartbeat, function()
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        if Config.SpeedOn and hum.WalkSpeed ~= Config.Speed then hum.WalkSpeed = Config.Speed end
        if Config.JumpOn then
            if not hum.UseJumpPower then hum.UseJumpPower = true end
            if hum.JumpPower ~= Config.JumpPower then hum.JumpPower = Config.JumpPower end
        end
    end

    if Config.NoClip and char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false; noclipSet[p] = true end
        end
    elseif not Config.NoClip and next(noclipSet) then
        for p in pairs(noclipSet) do if p.Parent then p.CanCollide = true end end
        noclipSet = {}
    end

    if Config.Fly and char and hum then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local up = UserInputService:IsKeyDown(Enum.KeyCode.Space)
                or hum:GetState() == Enum.HumanoidStateType.Jumping
            local down = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
                or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
            local vy = (up and Config.FlySpeed or 0) - (down and Config.FlySpeed or 0)
            hrp.Velocity = (hum.MoveDirection * Config.FlySpeed) + Vector3.new(0, vy, 0)
        end
    end

    setFullbright(Config.Fullbright)
end)

--===== FOV: базовый FOV игры для детекта ADS =====
local baseFov = nil
task.spawn(function()
    while true do
        task.wait(0.5)
        local cam = getCam()
        if cam and not Config.FovOn then baseFov = cam.FieldOfView end
    end
end)

--===== ГЛАВНЫЙ ЦИКЛ (поздний приоритет = после камеры игры) =====
local fovCircle = newCircle(Color3.fromRGB(255,255,255))
local aimName, espCount, target = "-", 0, nil

local function onRender(dt)
    local cam = getCam()
    if not cam then return end
    local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)

    -- АИМБОТ
    target = nil
    if Config.Aimbot and (not Config.AimOnHold or holding) then
        target = findTarget(cam)
    end
    aimName = target and target.Name or "-"

    if target then
        local part = targetPart(target)
        if part then
            if Config.AimMode == "Mouse" and mousemoverel then
                local sp = cam:WorldToViewportPoint(part.Position)
                if sp.Z > 0 then
                    pcall(mousemoverel,
                        (sp.X - center.X) * Config.AimMouseSens,
                        (sp.Y - center.Y) * Config.AimMouseSens)
                end
            else
                local desired = CFrame.new(cam.CFrame.Position, part.Position)
                cam.CFrame = cam.CFrame:Lerp(desired, math.clamp(Config.AimSmooth, 0.01, 1))
            end
        end
    end

    -- FOV (аккуратно: не мешаем ADS, иначе античит игры нервничает)
    if Config.FovOn then
        local skip = Config.FovSkipADS and baseFov and cam.FieldOfView < baseFov - 6
        if not skip and math.abs(cam.FieldOfView - Config.CameraFOV) > 0.05 then
            cam.FieldOfView = Config.CameraFOV
        end
    end

    -- КРУГ FOV
    fovCircle.set(center.X, center.Y, Config.FOVRadius,
        Config.Aimbot and Config.ShowFOV, target and RED or Color3.fromRGB(255,255,255))

    -- ESP
    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    espCount = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        local o = getESP(plr)                       -- <<< вот этот вызов и был пропущен
        local char = plr.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local show = Config.ESP and char and hum and hum.Health > 0 and hrp and isEnemy(plr)
        local dist = 0

        if show and myRoot then
            dist = (hrp.Position - myRoot.Position).Magnitude
            if dist > Config.ESPMaxDist then show = false end
        end

        if not show then
            o.box.set(0,0,0,0,false); o.name.set(0,0,"",false)
            o.hp.set(0,0,"",false); o.dist.set(0,0,"",false); o.tracer.set(0,0,0,0,false)
        else
            espCount = espCount + 1
            local head = char:FindFirstChild("Head")
            local top = cam:WorldToViewportPoint(
                (head and head.Position + Vector3.new(0, 0.65, 0)) or (hrp.Position + Vector3.new(0, 3, 0)))
            local bottom = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))

            if top.Z > 0 and bottom.Z > 0 then
                local h = math.abs(bottom.Y - top.Y)
                if h > 2 then
                    local w = h * 0.55
                    local x, y = top.X - w/2, top.Y
                    local col = (target == plr) and RED or GREEN

                    if Config.Boxes then o.box.set(x, y, w, h, true, col) else o.box.set(0,0,0,0,false) end
                    if Config.Names then o.name.set(top.X, y - 16, plr.Name, true, Color3.new(1,1,1)) else o.name.set(0,0,"",false) end
                    if Config.Health then o.hp.set(top.X, y + h + 2, math.floor(hum.Health) .. " HP", true, Color3.fromRGB(120,255,120)) else o.hp.set(0,0,"",false) end
                    if Config.Distance then o.dist.set(top.X, y + h + 16, math.floor(dist) .. " м", true, Color3.fromRGB(205,205,205)) else o.dist.set(0,0,"",false) end
                    if Config.Tracers then o.tracer.set(center.X, cam.ViewportSize.Y, top.X, y + h, true, col) else o.tracer.set(0,0,0,0,false) end
                end
            end
        end
    end
end

RunService:BindToRenderStep("KontraVenice", Enum.RenderPriority.Last.Value - 1, onRender)

--===== МЕНЮ =====
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name, ScreenGui.ResetOnSpawn, ScreenGui.IgnoreGuiInset = "KontraVeniceMenu", false, true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = guiParent()

local Panel = Instance.new("Frame")
Panel.Size, Panel.Position = UDim2.fromOffset(248, 402), UDim2.new(0, 14, 0.12, 0)
Panel.BackgroundColor3, Panel.BackgroundTransparency, Panel.BorderSizePixel = Color3.fromRGB(17,17,21), 0.08, 0
Panel.Active = true
Panel.Parent = ScreenGui
Instance.new("UICorner", Panel).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size, Title.BackgroundTransparency = UDim2.new(1, -46, 0, 30), 1
Title.Text, Title.TextColor3 = "KONTRA  •  VENICE v2", Color3.fromRGB(0,255,140)
Title.Font, Title.TextSize, Title.Active = Enum.Font.GothamBold, 14, true
Title.Parent = Panel

local Min = Instance.new("TextButton")
Min.Size, Min.Position = UDim2.fromOffset(30, 22), UDim2.new(1, -36, 0, 4)
Min.BackgroundColor3, Min.BorderSizePixel = Color3.fromRGB(35,35,45), 0
Min.TextColor3, Min.Font, Min.TextSize, Min.Text = Color3.new(1,1,1), Enum.Font.GothamBold, 13, "_"
Min.Parent = Panel
Instance.new("UICorner", Min).CornerRadius = UDim.new(0, 6)

local Content = Instance.new("ScrollingFrame")
Content.Size, Content.Position = UDim2.new(1, -10, 1, -38), UDim2.fromOffset(5, 34)
Content.BackgroundTransparency, Content.BorderSizePixel = 1, 0
Content.ScrollBarThickness = 3
Content.CanvasSize = UDim2.new(0,0,0,0)
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.Parent = Panel

local Layout = Instance.new("UIListLayout")
Layout.Padding, Layout.SortOrder = UDim.new(0, 4), Enum.SortOrder.LayoutOrder
Layout.Parent = Content

local Diag = Instance.new("TextLabel")
Diag.Size, Diag.BackgroundColor3, Diag.BorderSizePixel = UDim2.new(1,-8,0,44), Color3.fromRGB(22,22,28), 0
Diag.TextColor3, Diag.Font, Diag.TextSize = Color3.fromRGB(150,255,195), Enum.Font.Code, 11
Diag.TextXAlignment, Diag.TextYAlignment, Diag.TextWrapped = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top, true
Diag.Text = "запуск..."
Diag.Parent = Content

task.spawn(function()
    while Diag.Parent do
        local cam = getCam()
        Diag.Text = string.format(
            "Drawing: %s | игроков: %d\nESP рисует: %d | цель аима: %s\nFOV игры: %s | мой FOV: %s",
            HAS_DRAWING and "да" or "нет(Frame)", #Players:GetPlayers(), espCount, aimName,
            cam and math.floor(cam.FieldOfView) or "?", Config.FovOn and tostring(Config.CameraFOV) or "выкл")
        task.wait(0.25)
    end
end)

local function addHeader(text)
    local l = Instance.new("TextLabel")
    l.Size, l.BackgroundTransparency = UDim2.new(1,-8,0,20), 1
    l.Text, l.TextColor3 = text, Color3.fromRGB(140,140,160)
    l.Font, l.TextSize, l.TextXAlignment = Enum.Font.GothamBold, 11, Enum.TextXAlignment.Left
    l.Parent = Content
end

local function addRow(text)
    local row = Instance.new("Frame")
    row.Size, row.BackgroundColor3, row.BorderSizePixel = UDim2.new(1,-8,0,26), Color3.fromRGB(27,27,34), 0
    row.Parent = Content
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size, lbl.Position, lbl.BackgroundTransparency = UDim2.new(1,-68,1,0), UDim2.fromOffset(8,0), 1
    lbl.Text, lbl.TextColor3 = text, Color3.fromRGB(232,232,238)
    lbl.Font, lbl.TextSize, lbl.TextXAlignment = Enum.Font.GothamMedium, 12, Enum.TextXAlignment.Left
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size, btn.Position = UDim2.fromOffset(58,20), UDim2.new(1,-64,0.5,-10)
    btn.BackgroundColor3, btn.BorderSizePixel = Color3.fromRGB(45,45,55), 0
    btn.Font, btn.TextSize, btn.TextColor3, btn.Text = Enum.Font.GothamBold, 11, Color3.new(1,1,1), "OFF"
    btn.Parent = row
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    return btn
end

local function addToggle(text, key, onChange)
    local btn = addRow(text)
    local function refresh()
        local v = Config[key]
        btn.Text = v and "ON" or "OFF"
        btn.BackgroundColor3 = v and Color3.fromRGB(0,150,90) or Color3.fromRGB(45,45,55)
    end
    btn.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]; refresh()
        if onChange then onChange(Config[key]) end
    end)
    refresh()
end

local function addCycle(text, key, values, fmt, onChange)
    local btn = addRow(text)
    local idx = 1
    for i, v in ipairs(values) do if v == Config[key] then idx = i end end
    local function refresh()
        local v = values[idx]; Config[key] = v
        btn.Text = fmt and fmt(v) or tostring(v)
        btn.BackgroundColor3 = Color3.fromRGB(58,58,78)
        if onChange then onChange(v) end
    end
    btn.MouseButton1Click:Connect(function() idx = idx % #values + 1; refresh() end)
    refresh()
end

addHeader("ВИЗУАЛЫ")
addToggle("ESP", "ESP")
addToggle("Боксы", "Boxes")
addToggle("Ники", "Names")
addToggle("HP", "Health")
addToggle("Дистанция", "Distance")
addToggle("Трассеры", "Tracers")
addToggle("Проверка команды", "TeamCheck")
addCycle("Лимит дистанции", "ESPMaxDist", {300,600,1000,2000,5000}, function(v) return v .. "м" end)

addHeader("АИМБОТ")
addToggle("Аимбот", "Aimbot")
addToggle("Круг FOV", "ShowFOV")
addCycle("Часть", "AimPart", {"Head","HumanoidRootPart"}, function(v) return v=="Head" and "Голова" or "Корпус" end)
addCycle("FOV радиус", "FOVRadius", {60,90,140,200,260})
addCycle("Плавность", "AimSmooth", {0.1,0.2,0.3,0.5,0.8,1}, function(v) return tostring(v) end)
addToggle("Только ПКМ (ПК)", "AimOnHold")
addToggle("Только видимые", "WallCheck")
addCycle("Способ", "AimMode", {"Camera","Mouse"}, function(v) return v=="Camera" and "Камера" or "Мышь" end)
addCycle("Чувств. мыши", "AimMouseSens", {0.3,0.5,0.8,1.2}, function(v) return tostring(v) end)

addHeader("FOV КАМЕРЫ (кикает — выключи)")
addToggle("Менять FOV", "FovOn")
addToggle("Не менять в прицеле", "FovSkipADS")
addCycle("Значение FOV", "CameraFOV", {70,80,90,100,110})

addHeader("МИСК")
addToggle("Speed", "SpeedOn")
addCycle("Значение Speed", "Speed", {16,22,28,36,50})
addToggle("Jump Power", "JumpOn")
addCycle("Значение Jump", "JumpPower", {50,75,100,150})
addToggle("Infinite Jump", "InfJump")
addToggle("Fullbright", "Fullbright")
addToggle("NoClip", "NoClip")
addToggle("Fly", "Fly")
addCycle("Скорость полёта", "FlySpeed", {30,55,90,150})
addToggle("Hitbox Expander", "Hitbox", applyHitbox)
addCycle("Размер хитбокса", "HitboxSize", {6,9,12,16,20}, function(v) return v .. "ст" end, applyHitbox)

addHeader("ПРОЧЕЕ")
local unloadBtn = addRow("Unload скрипта")
unloadBtn.Text, unloadBtn.BackgroundColor3 = "ВЫКЛ", Color3.fromRGB(150,50,50)

-- перетаскивание (мышь + тач)
local dragging, dragStart, startPos
local function startDrag(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging, dragStart, startPos = true, input.Position, Panel.Position
    end
end
bind(Title.InputBegan, startDrag)
bind(Panel.InputBegan, function(input)
    if not dragging then startDrag(input) end
end)
bind(UserInputService.InputChanged, function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        Panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                   startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
bind(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)

local minimized = false
Min.MouseButton1Click:Connect(function()
    minimized = not minimized
    Content.Visible = not minimized
    Panel.Size = minimized and UDim2.fromOffset(248, 30) or UDim2.fromOffset(248, 402)
    Min.Text = minimized and "□" or "_"
end)

--===== UNLOAD =====
local function unload()
    pcall(function() RunService:UnbindFromRenderStep("KontraVenice") end)
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    for p in pairs(espData) do dropESP(p) end
    pcall(fovCircle.remove)
    setFullbright(false)
    for p in pairs(noclipSet) do if p.Parent then p.CanCollide = true end end
    Config.Hitbox = false; applyHitbox()
    pcall(function() ScreenGui:Destroy() end)
    pcall(function() if espGui then espGui:Destroy() end end)
    getgenv().KontraVenice_Unload = nil
end

getgenv().KontraVenice_Unload = unload
unloadBtn.MouseButton1Click:Connect(unload)

print("[Kontra | Venice v2] OK. Drawing:", HAS_DRAWING, "| игроков:", #Players:GetPlayers(),
      "| камера:", getCam() and "есть" or "нет")
