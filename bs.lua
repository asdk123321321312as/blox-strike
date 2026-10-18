-- Исправленный ESP для Blox Strike
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- Цвета (RGB)
local COLOR = Color3.fromRGB(255, 0, 0) -- Красный fill
local OUTLINE_COLOR = Color3.fromRGB(0, 0, 0) -- Черная обводка

-- Папка для ESP, чтобы не засорять экран
local espFolder = Instance.new("Folder")
espFolder.Name = "BloXStrikeESP"
espFolder.Parent = LocalPlayer.PlayerGui or LocalPlayer:FindFirstChild("PlayerGui") or workspace.CurrentCamera

-- Функция создания ESP
local function createESP(model)
    if not model or not model:IsA("Model") then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_" .. model.Name
    highlight.Adornee = model
    
    -- Настройки (исправлено)
    highlight.FillColor = COLOR
    highlight.FillTransparency = 0.9 -- Сильная прозрачность внутри
    highlight.LineColor = OUTLINE_COLOR
    highlight.LineThickness = 1 -- Толщина белой/цветной обводки
    highlight.OutlineColor = OUTLINE_COLOR -- Цвет внешней рамки
    highlight.OutlineTransparency = 0 -- Внешняя рамка видимая
    
    highlight.Parent = espFolder
    
    -- Удаляем ESP, если модель удалена из игры
    model.AncestryChanged:Connect(function()
        if not model.Parent then
            highlight:Destroy()
        end
    end)
end

-- Сканирование врагов/игроков
local function scanForTargets()
    -- Проходим по всем детям Workspace
    for _, child in pairs(Workspace:GetChildren()) do
        if child:IsA("Model") and child:FindFirstChild("HumanoidRootPart") then
            -- Не подсвечиваем себя
            if child ~= LocalPlayer.Character then
                -- Если еще нет ESP, создаем его
                if not child:FindFirstChildWhichIsA("Highlight") then
                    createESP(child)
                end
            end
        end
    end
end

-- Запускаем цикл
while true do
    scanForTargets()
    wait(0.5) -- Проверка каждые полсекунды
end

print("ESP Loaded!")
