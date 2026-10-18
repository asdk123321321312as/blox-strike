-- ESP для Blox Strike (Универсальный, без ошибок)
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")

-- Цвета
local FILL_COLOR = Color3.fromRGB(255, 0, 0) -- Красный (внутри)
local LINE_COLOR = Color3.fromRGB(255, 255, 255) -- Белый (контур)

-- Папка для элементов ESP
local espFolder = Instance.new("Folder")
espFolder.Name = "ESP_Folder"
espFolder.Parent = LocalPlayer.PlayerGui or LocalPlayer:FindFirstChild("PlayerGui") or workspace.CurrentCamera

local function createESP(model)
    if not model or not model:IsA("Model") then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_" .. model.Name
    highlight.Adornee = model
    
    -- Только проверенные свойства
    highlight.FillColor = FILL_COLOR
    highlight.FillTransparency = 0.95 -- Почти невидимый внутри
    highlight.LineColor = LINE_COLOR
    highlight.LineThickness = 2 -- Толщина контура
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- Показывать поверх всего
    
    -- Пытаемся добавить прозрачность линии, если она есть, иначе игнорируем ошибку
    pcall(function()
        highlight.LineTransparency = 0
    end)
    
    highlight.Parent = espFolder
    
    -- Удаляем при уничтожении модели
    model.AncestryChanged:Connect(function()
        if not model.Parent then
            highlight:Destroy()
        end
    end)
end

local function scanForTargets()
    -- Ищем во всем Workspace
    for _, child in pairs(Workspace:GetChildren()) do
        if child:IsA("Model") and child:FindFirstChild("HumanoidRootPart") then
            if child ~= LocalPlayer.Character then
                if not child:FindFirstChildWhichIsA("Highlight") then
                    createESP(child)
                end
            end
        end
    end
end

while true do
    scanForTargets()
    wait(1) -- Проверяем раз в секунду, чтобы не грузить процессор
end

print("ESP Loaded!")
