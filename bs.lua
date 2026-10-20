--=============================================================
--  BLOX STRIKE PREMIUM  |  by Venice
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
    ESP = true, ESPBox = true, ESPName = true, ESPHealth = true,
    ESPDistance = true, ESPTeamCheck = true,
    FOV = true, FOVValue = 90,
    FPSBoost = true,
    SkyEnabled = true, SkyTime = 14,
    SkyAmbient = Color3.fromRGB(140,140,160),
    ParticleCount = 250, ParticleSize = 0.35, ParticleSpeed = 12,
    AutoBhop = false, BhopPower = 60,
}

--========== ЧЁРНОЕ МЕНЮ ==========
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BloxStrike_Premium"
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 430, 0, 350)
Main.Position = UDim2.new(0.5, -215, 0.5, -175)
Main.BackgroundColor3 = Color3.fromRGB(10,10,12)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0,10)
local stroke = Instance.new("UIStroke", Main)
stroke.Color = Color3.fromRGB(35,35,40); stroke.Thickness = 1

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1,0,0,38)
Header.BackgroundColor3 = Color3.fromRGB(15,15,18)
Header.BorderSizePixel = 0
Header.Parent = Main
Instance.new("UICorner", Header).CornerRadius = UDim.new(0,10)
local hfix = Instance.new("Frame")
hfix.Size = UDim2.new(1,0,0,12); hfix.Position = UDim2.new(0,0,1,-12)
hfix.BackgroundColor3 = Color3.fromRGB(15,15,18); hfix.BorderSizePixel = 0; hfix.Parent = Header

local Title = Instance.new("TextLabel")
Title.Text = "BLOX STRIKE // PREMIUM"
Title.Font = Enum.Font.GothamBold; Title.TextSize = 15
Title.TextColor3 = Color3.fromRGB(230,230,235)
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(1,-60,1,0); Title.Position = UDim2.new(0,14,0,0)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local MinBtn = Instance.new("TextButton")
MinBtn.Text = "—"; MinBtn.Font = Enum.Font.GothamBold; MinBtn.TextSize = 16
MinBtn.TextColor3 = Color3.fromRGB(200,200,205); MinBtn.BackgroundTransparency = 1
MinBtn.Size = UDim2.new(0,30,1,0); MinBtn.Position = UDim2.new(1,-34,0,0)
MinBtn.Parent = Header

-- вкладки
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1,-20,0,26)
TabBar.Position = UDim2.new(0,10,0,44)
TabBar.BackgroundTransparency = 1
TabBar.Parent = Main

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1,-20,1,-80)
Content.Position = UDim2.new(0,10,0,74)
Content.BackgroundTransparency = 1
Content.Parent = Main

local pages = {}
local tabBtns = {}
local function addTab(name)
    local b = Instance.new("TextButton")
    b.Text = name; b.Font = Enum.Font.GothamBold; b.TextSize = 12
    b.TextColor3 = Color3.fromRGB(180,180,185)
    b.BackgroundColor3 = Color3.fromRGB(20,20,24)
    b.Size = UDim2.new(0,90,1,0)
    b.Position = UDim2.new(0, (#tabBtns)*94, 0, 0)
    b.Parent = TabBar
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)

    local p = Instance.new("ScrollingFrame")
    p.Size = UDim2.new(1,0,1,0); p.BackgroundTransparency = 1
    p.BorderSizePixel = 0; p.ScrollBarThickness = 4
    p.CanvasSize = UDim2.new(0,0,0,400); p.Visible = false
    p.Parent = Content
    pages[name] = p
    table.insert(tabBtns, {btn=b, page=p})

    b.MouseButton1Click:Connect(function()
        for _, t in ipairs(tabBtns) do
            t.page.Visible = false
            t.btn.TextColor3 = Color3.fromRGB(180,180,185)
            t.btn.BackgroundColor3 = Color3.fromRGB(20,20,24)
        end
        p.Visible = true
        b.TextColor3 = Color3.fromRGB(255,255,255)
        b.BackgroundColor3 = Color3.fromRGB(45,45,55)
    end)
    return p
end

MinBtn.MouseButton1Click:Connect(function()
    Main.Visible = false
end)

-- хелперы UI
local function toggle(parent, y, text, default, cb)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,28); row.Position = UDim2.new(0,0,0,y)
    row.BackgroundTransparency = 1; row.Parent = parent
    local lbl = Instance.new("TextLabel")
    lbl.Text = text; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 13
    lbl.TextColor3 = Color3.fromRGB(210,210,215); lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(0.6,0,1,0); lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0,42,0,20); bg.Position = UDim2.new(1,-42,0.5,-10)
    bg.BackgroundColor3 = default and Color3.fromRGB(60,120,255) or Color3.fromRGB(40,40,45)
    bg.Parent = row; Instance.new("UICorner", bg).CornerRadius = UDim.new(1,0)
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0,16,0,16)
    knob.Position = default and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)
    knob.BackgroundColor3 = Color3.fromRGB(240,240,245); knob.Parent = bg
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)
    local btn = Instance.new("TextButton")
    btn.Text=""; btn.BackgroundTransparency=1; btn.Size=UDim2.new(1,0,1,0); btn.Parent=row
    btn.MouseButton1Click:Connect(function()
        local s = not (bg.BackgroundColor3 == Color3.fromRGB(60,120,255))
        bg.BackgroundColor3 = s and Color3.fromRGB(60,120,255) or Color3.fromRGB(40,40,45)
        knob:TweenPosition(s and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8),"Out","Quad",0.15,true)
        cb(s)
    end)
    return row
end

local function slider(parent
