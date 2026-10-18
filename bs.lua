-- ESP для Blox Strike (Roblox)
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- Настройки цвета (можно менять RGB значения)
local COLOR = Color3.fromRGB(255, 0, 0) -- Красный
local OUTLINE_COLOR = Color3.fromRGB(0, 0, 0) -- Черная обводка для контраста

-- Папка для ESP элементов
local espFolder = Instance.new("Folder")
espFolder.Name = "BloXStrikeESP"
espFolder.Parent = LocalPlayer.PlayerGui or LocalPlayer:FindFirstChild("PlayerGui") or workspace.CurrentCamera

-- Функция создания ESP для модели
local function createESP(model)
    if not model or not model:IsA("Model") then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_" .. model.Name
    highlight.Adornee = model
    highlight.FillTransparency = 0.95 -- Почти невидимый внутри
    highlight.LineTransparency = 0
    highlight.FillColor = COLOR
    highlight.LineColor = OUTLINE_COLOR
    highlight.OutlineTransparency = 0
    highlight.Parent = espFolder
    
    -- Удаляем, если модель уничтожена
    model.AncestryChanged:Connect(function()
        if not model.Parent then
            highlight:Destroy()
        end
    end)
end

-- Ищем всех персонажей в игре
-- В Blox Strike враги часто лежат в папке "Enemies", "Targets" или просто в Workspace
local function scanForTargets()
    for _, child in pairs(Workspace:GetChildren()) do
        if child:IsA("Model") and child:FindFirstChild("HumanoidRootPart") then
            -- Проверяем, чтобы не подсветить самого себя
            if child ~= LocalPlayer.Character then
                -- Создаем ESP только если его еще нет
                if not child:FindFirstChildWhichIsA("Highlight") then
                    createESP(child)
                end
            end
        end
    end
end

-- Запускаем сканирование каждые полсекунды
while true do
    scanForTargets()
    wait(0.5)
end

print("BloX Strike ESP Loaded!")
