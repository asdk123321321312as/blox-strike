(function()
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local Workspace = game:GetService("Workspace")
    
    -- Настройки цвета
    local COLOR = Color3.fromRGB(255, 0, 0) -- Красный
    local LINE_COLOR = Color3.fromRGB(255, 255, 255) -- Белый контур
    
    -- Создаем папку ESP
    local espFolder = Instance.new("Folder")
    espFolder.Name = "BloXESP"
    espFolder.Parent = LocalPlayer.PlayerGui or LocalPlayer:FindFirstChild("PlayerGui") or workspace.CurrentCamera
    
    local function createESP(model)
        if not model or not model:IsA("Model") then return end
        
        local highlight = Instance.new("Highlight")
        highlight.Name = "ESP_" .. model.Name
        highlight.Adornee = model
        
        -- Только рабочие свойства
        highlight.FillColor = COLOR
        highlight.FillTransparency = 0.9 -- Прозрачность внутри
        highlight.LineColor = LINE_COLOR
        highlight.LineThickness = 1.5 -- Толщина линии
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- Показывать сквозь стены
        
        highlight.Parent = espFolder
        
        -- Удаление при уничтожении модели
        model.AncestryChanged:Connect(function()
            if not model.Parent then
                highlight:Destroy()
            end
        end)
    end

    -- Функция поиска моделей в указанных папках
    local function scanModels(folderPath)
        local folder = game:GetService("Workspace"):FindFirstChild(folderPath) or Workspace
        if not folder then return end
        
        for _, child in pairs(folder:GetChildren()) do
            if child:IsA("Model") and child:FindFirstChild("HumanoidRootPart") then
                if child ~= LocalPlayer.Character then
                    if not child:FindFirstChildWhichIsA("Highlight") then
                        createESP(child)
                    end
                end
            end
        end
    end

    -- Основной цикл проверки
    while true do
        -- Ищем врагов/игроков в основных папках Blox Strike
        scanModels("Enemies")
        scanModels("Targets")
        scanModels("Players")
        scanModels("Map") -- Иногда враги лежат прямо в карте
        
        -- Также проверяем корень Workspace на случай, если модель там
        for _, child in pairs(Workspace:GetChildren()) do
            if child:IsA("Model") and child:FindFirstChild("HumanoidRootPart") and not child:FindFirstChildWhichIsA("Highlight") then
                if child ~= LocalPlayer.Character then
                    createESP(child)
                end
            end
        end
        
        wait(1) -- Обновление раз в секунду
    end
end)()
