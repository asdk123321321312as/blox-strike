--=============================================================
--  BLOX STRIKE PREMIUM | by Venice
--  ESP + FOV + FPS Boost + Sky/Particles + AutoBhop
--=============================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local Lighting         = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local Camera           = Workspace.CurrentCamera
local LocalPlayer      = Players.LocalPlayer
local Mouse            = LocalPlayer:GetMouse()

--========== CONFIG ==========
local Config = {
    ESP         = true,
    ESPBox      = true,
    ESPName     = true,
    ESPHealth   = true,
    ESPDistance = true,
    ESPTeamCheck= true,

    FOV         = true,
    FOVValue    = 90,

    FPSBoost    = true,

    SkyEnabled  = true,
    SkyTime     = 14,     -- 0..24
    SkyAmbient  = Color3.fromRGB(140,140,160),
    ParticleCount = 250,
    ParticleSize  = 0.35,
    ParticleSpeed = 12,

    AutoBhop    = false,
    BhopPower   = 60,
}

--========== UI (чёрное кастомное меню) ==========
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BloxStrike_Premium"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- главный фрейм
local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 420, 0, 320)
Main.Position = UDim2.new(0.5, -210, 0.5, -160)
Main.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", Main)
stroke.Color = Color3.fromRGB(35,35,40); stroke.Thickness = 1

-- заголовок
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1,0,0,38)
Header.BackgroundColor3 = Color3.fromRGB(15,15,18)
Header.BorderSizePixel = 0
Header.Parent = Main
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)
local hfix = Instance.new("Frame")
hfix.Size = UDim2.new(1,0,0,12); hfix.Position = UDim2.new(0,0,1,-12)
hfix.BackgroundColor3 = Color3.fromRGB(15,15,18); hfix.BorderSizePixel = 0; hfix.Parent = Header

local Title = Instance.new("TextLabel")
Title.Text = "BLOX STRIKE // PREMIUM"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.TextColor3 = Color3.fromRGB(230,230,235)
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(1,-60,1,0)
Title.Position = UDim2.new(0,14,0,0)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Minimize = Instance.new("TextButton")
Minimize.Text = "—"
Minimize.Font = Enum.Font.GothamBold
Minimize.TextSize = 16
Minimize.TextColor3 = Color3.fromRGB(200,200,205)
Minimize.BackgroundTransparency = 1
Minimize.Size = UDim2.new(0,30,1,0)
Minimize.Position = UDim2.new(1,-34,0,0)
Minimize.Parent = Header
Minimize.MouseButton1Click:Connect(function()
    Main.Visible = not Main.Visible
end)

-- контейнер для вкладок
local TabHolder = Instance.new("Frame")
TabHolder.Size = UDim2.new(1,-20,1,-50)
TabHolder.Position = UDim2.new(0,10,0,44)
TabHolder.BackgroundTransparency = 1
TabHolder.Parent = Main

-- фабрика переключателя (красивый toggle)
local function makeToggle(parent, yPos, text, default, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,28)
    row.Position = UDim2.new(0,0,0,yPos)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Text = text
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextColor3 = Color3.fromRGB(200,200,205)
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(0.6,0,1,0)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0,42,0,20)
    bg.Position = UDim2.new(1,-42,0.5,-10)
    bg.BackgroundColor3 = default and Color3.fromRGB(60,120,255) or Color3.fromRGB(40,40,45)
    bg.Parent = row
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1,0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0,16,0,16)
    knob.Position = default and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)
    knob.BackgroundColor3 = Color3.fromRGB(240,240,245)
    knob.Parent = bg
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)

    local btn = Instance.new("TextButton")
    btn.Text = ""; btn.BackgroundTransparency = 1
    btn.Size = UDim2.new(1,0,1,0); btn.Parent = row

    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        if state then
            bg.BackgroundColor3 = Color3.fromRGB(60,120,255)
            knob:TweenPosition(UDim2.new(1,-18,0.5,-8),"Out","Quad",0.15,true)
        else
            bg.BackgroundColor3 = Color3.fromRGB(40,40,45)
            knob:TweenPosition(UDim2.new(0,2,0.5,-8),"Out","Quad",0.15,true)
        end
        callback(state)
    end)
    return row
end

local function makeSlider(parent, yPos, text, minV, maxV, default, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,38)
    row.Position = UDim2.new(0,0,0,yPos)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Text = text .. ": " .. tostring(default)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextColor3 = Color3.fromRGB(200,200,205)
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1,0,0,16)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1,0,0,6)
    bar.Position = UDim2.new(0,0,0,24)
    bar.BackgroundColor3 = Color3.fromRGB(30,30,34)
    bar.Parent = row
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1,0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default-minV)/(maxV-minV),0,1,0)
    fill.BackgroundColor3 = Color3.fromRGB(60,120,255)
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim
