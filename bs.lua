--===================================================================
--  BloxStrike ESP v6  (без аимбота)  |  Venice
--  RShift — ESP вкл/выкл
--  F2 — краткий дамп        F3 — ПОИСК ИСТОЧНИКА ПОЗИЦИЙ (радар)
--===================================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local Workspace        = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui          = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

--===================================================================
-- НАСТРОЙКИ
--===================================================================
local CONFIG = {
	Enabled      = true,
	TeamCheck    = true,
	SkipSpectators = true,
	MaxDist      = 1500,

	-- сглаживание, чтобы квадрат не дёргался
	Smooth       = 0.35,   -- 1 = без сглаживания, меньше = плавнее
	Linger       = 0.45,   -- сколько секунд держать квадрат после пропажи модели

	Box          = true,
	Name         = true,
	Health       = true,
	Armor        = true,
	Weapon       = true,
	Distance     = true,
	Tracer       = true,
	Highlight    = true,
	Skeleton     = false,
	WallCheck    = false,

	BoxThickness = 1.5,
	TextSize     = 14,

	EnemyColor   = Color3.fromRGB(255, 70, 70),
	TeamColor    = Color3.fromRGB(90, 180, 255),
	HealthColor  = Color3.fromRGB(60, 255, 130),
	ArmorColor   = Color3.fromRGB(90, 170, 255),
	BackColor    = Color3.fromRGB(20, 20, 20),
}

--===================================================================
-- БАЗА
--===================================================================
local FONT  = (Drawing.Fonts and Drawing.Fonts.UI) or 0
local esp   = {}
local ready = false

local function newDraw(class, props)
	local d = Drawing.new(class)
	for k, v in pairs(props) do d[k] = v end
	d.Visible = false
	return d
end

local function findDeep(root, name)
	if not root then return nil end
	local d = root:FindFirstChild(name)
	if d then return d end
	for _, x in ipairs(root:GetDescendants()) do
		if x.Name == name then return x end
	end
	return nil
end

local function getChar(plr)
	local c = plr.Character
	if c and c.Parent and c:FindFirstChild("Head") then return c end
	local folder = Workspace:FindFirstChild("Characters")
	if folder then
		local m = folder:FindFirstChild(plr.Name)
		if m and m:FindFirstChild("Head") then return m end
	end
	return nil
end

local function getTeam(plr)
	local t = plr:GetAttribute("Team")
	return type(t) == "string" and t or nil
end

local function isDead(plr, char)
	if plr:GetAttribute("Dead") == true then return true end
	if char and char:GetAttribute("Dead") == true then return true end
	local hp = plr:GetAttribute("Health")
	if type(hp) == "number" and hp <= 0 then return true end
	return false
end

local function getHP(plr)
	local h = plr:GetAttribute("Health")
	if type(h) ~= "number" then return nil, nil end
	local m = plr:GetAttribute("MaxHealth")
	return h, (type(m) == "number" and m) or 100
end

local function getArmor(plr)
	local raw = plr:GetAttribute("Armor")
	if type(raw) ~= "string" then return nil end
	local ok, d = pcall(HttpService.JSONDecode, HttpService, raw)
	if ok and type(d) == "table" and type(d.Health) == "number" then
		return math.clamp(d.Health, 0, 100), d.Type
	end
	return nil
end

local wCache = setmetatable({}, {__mode = "k"})
local function getWeapon(plr)
	local raw = plr:GetAttribute("CurrentEquipped")
	if type(raw) ~= "string" then return nil end
	local c = wCache[plr]
	if c and c.raw == raw then return c.name end
	local ok, d = pcall(HttpService.JSONDecode, HttpService, raw)
	local n = (ok and type(d) == "table" and d.Name) or nil
	wCache[plr] = {raw = raw, name = n}
	return n
end

--===================================================================
-- ВИДИМОСТЬ
--===================================================================
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude

local function isVisible(char, part)
	local ignore = {}
	if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
	rp.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, rp)
	return hit == nil or hit.Instance:IsDescendantOf(char)
end

--===================================================================
-- СКЕЛЕТ
--===================================================================
local SKEL = {
	{"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"LowerTorso","HumanoidRootPart"},
	{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
	{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
	{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
	{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}

--===================================================================
-- ЖИЗНЕННЫЙ ЦИКЛ
--===================================================================
local function hide(t)
	t.box.Visible = false; t.name.Visible = false; t.dist.Visible = false
	t.info.Visible = false
	t.hpBg.Visible = false; t.hpBar.Visible = false
	t.arBg.Visible = false; t.arBar.Visible = false
	t.tracer.Visible = false
	for _, l in ipairs(t.skel) do l.Visible = false end
	if t.hl then t.hl.Enabled = false end
end

local function mkText(size)
	return newDraw("Text", {Size = size, Center = true, Outline = true,
	                       OutlineColor = Color3.new(0,0,0), Color = Color3.new(1,1,1),
	                       Font = FONT, ZIndex = 5})
end

local function createESP(plr)
	esp[plr] = {
		box    = newDraw("Square", {Thickness = CONFIG.BoxThickness, Filled = false,
		                            Color = CONFIG.EnemyColor, ZIndex = 3}),
		name   = mkText(CONFIG.TextSize),
		dist   = mkText(CONFIG.TextSize - 1),
		info   = mkText(CONFIG.TextSize - 2),
		hpBg   = newDraw("Square", {Thickness = 0, Filled = true, Color = CONFIG.BackColor, ZIndex = 3}),
		hpBar  = newDraw("Square", {Thickness = 0, Filled = true, Color = CONFIG.HealthColor, ZIndex = 4}),
		arBg   = newDraw("Square", {Thickness = 0, Filled = true, Color = CONFIG.BackColor, ZIndex = 3}),
		arBar  = newDraw("Square", {Thickness = 0, Filled = true, Color = CONFIG.ArmorColor, ZIndex = 4}),
		tracer = newDraw("Line",   {Thickness = 1.5, Color = CONFIG.EnemyColor, ZIndex = 2}),
		hl     = nil,
		skel   = {},
		last   = nil,   -- {top = Vector3, bot = Vector3, t = tick()}
	}
end

local function destroyESP(plr)
	local t = esp[plr]
	if not t then return end
	for _, k in ipairs({"box","name","dist","info","hpBg","hpBar","arBg","arBar","tracer"}) do
		t[k]:Remove()
	end
	for _, l in ipairs(t.skel) do l:Remove() end
	if t.hl then t.hl:Destroy() end
	esp[plr] = nil
end

--===================================================================
-- СГЛАЖИВАНИЕ ПОЗИЦИЙ (лечит дёрганье и пропадание)
--===================================================================
local function getSmoothedPositions(t, char, head, root)
	local topW = head.Position + Vector3.new(0, head.Size.Y / 2, 0)

	local lf, rf = char:FindFirstChild("LeftFoot"), char:FindFirstChild("RightFoot")
	local bottomY = (lf and rf)
		and math.min(lf.Position.Y - lf.Size.Y / 2, rf.Position.Y - rf.Size.Y / 2)
		or  (root.Position.Y - 2.6)
	local botW = Vector3.new(topW.X, bottomY, topW.Z)

	local now = tick()
	if t.last and (now - t.last.t) < CONFIG.Linger then
		local a = math.clamp(CONFIG.Smooth, 0.01, 1)
		topW = t.last.top:Lerp(topW, a)
		botW = t.last.bot:Lerp(botW, a)
	end
	t.last = {top = topW, bot = botW, t = now}
	return topW, botW
end

--===================================================================
-- ОТРИСОВКА
--===================================================================
local function render()
	if not ready then return end

	local myTeam   = getTeam(LocalPlayer)
	local camPos   = Camera.CFrame.Position
	local screenXY = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
	local now      = tick()

	for plr, t in pairs(esp) do
		local char = getChar(plr)
		local head = char and char:FindFirstChild("Head")
		local root = char and char:FindFirstChild("HumanoidRootPart")

		local ok = CONFIG.Enabled and plr ~= LocalPlayer and char and head and root

		if ok and CONFIG.SkipSpectators and plr:GetAttribute("IsSpectating") == true then
			ok = false
		end

		local sameTeam = false
		if ok and myTeam then
			local et = getTeam(plr)
			sameTeam = et ~= nil and et == myTeam
			if CONFIG.TeamCheck and sameTeam then ok = false end
		end

		if ok and isDead(plr, char) then ok = false end

		local dist = 0
		if ok then
			dist = (root.Position - camPos).Magnitude
			if dist > CONFIG.MaxDist then ok = false end
			if ok and CONFIG.WallCheck and not isVisible(char, head) then ok = false end
		end

		-- если модель пропала — держим квадрат по последней позиции
		local topW, botW, stale
		if ok then
			topW, botW = getSmoothedPositions(t, char, head, root)
		elseif t.last and (now - t.last.t) < CONFIG.Linger then
			topW, botW, stale = t.last.top, t.last.bot, true
			dist = (topW - camPos).Magnitude
		else
			hide(t); continue
		end

		local col = sameTeam and CONFIG.TeamColor or CONFIG.EnemyColor

		local top, onTop    = Camera:WorldToViewportPoint(topW)
		local bot, onBottom = Camera:WorldToViewportPoint(botW)
		if not (onTop and onBottom) or top.Z <= 0 or bot.Z <= 0 then
			hide(t); continue
		end

		local height = math.max(bot.Y - top.Y, 4)
		local width  = height * 0.55
		local minX   = top.X - width / 2
		local cx     = top.X

		t.box.Visible = CONFIG.Box
		if CONFIG.Box then
			t.box.Color, t.box.Thickness = col, CONFIG.BoxThickness
			t.box.Position = Vector2.new(minX, top.Y)
			t.box.Size     = Vector2.new(width, height)
		end

		t.name.Visible = CONFIG.Name
		if CONFIG.Name then
			local skin = plr:GetAttribute("PresentationCharacterName")
			t.name.Text = plr.Name .. (skin and (" | " .. skin) or "") .. (stale and " ~" or "")
			t.name.Position = Vector2.new(cx, top.Y - CONFIG.TextSize - 4)
		end

		t.dist.Visible = CONFIG.Distance
		if CONFIG.Distance then
			t.dist.Text     = string.format("[%d studs]", math.floor(dist))
			t.dist.Position = Vector2.new(cx, bot.Y + 4)
		end

		t.info.Visible = CONFIG.Weapon
		if CONFIG.Weapon then
			t.info.Text     = getWeapon(plr) or ""
			t.info.Position = Vector2.new(cx, bot.Y + CONFIG.TextSize + 5)
		end

		local hp, maxHP = getHP(plr)
		t.hpBg.Visible  = CONFIG.Health and hp ~= nil
		t.hpBar.Visible = CONFIG.Health and hp ~= nil
		if CONFIG.Health and hp then
			local f  = math.clamp(hp / math.max(maxHP or 100, 1), 0, 1)
			local bx = minX - 6
			t.hpBg.Position  = Vector2.new(bx, top.Y)
			t.hpBg.Size      = Vector2.new(3, height)
			t.hpBar.Color    = Color3.fromRGB(math.floor(255 * (1 - f)), math.floor(255 * f), 40)
			t.hpBar.Position = Vector2.new(bx, bot.Y - height * f)
			t.hpBar.Size     = Vector2.new(3, height * f)
		end

		local armor = getArmor(plr)
		t.arBg.Visible  = CONFIG.Armor and armor ~= nil
		t.arBar.Visible = CONFIG.Armor and armor ~= nil
		if CONFIG.Armor and armor then
			local f  = math.clamp(armor / 100, 0, 1)
			local bx = minX - 11
			t.arBg.Position  = Vector2.new(bx, top.Y)
			t.arBg.Size      = Vector2.new(3, height)
			t.arBar.Position = Vector2.new(bx, bot.Y - height * f)
			t.arBar.Size     = Vector2.new(3, height * f)
		end

		t.tracer.Visible = CONFIG.Tracer
		if CONFIG.Tracer then
			t.tracer.Color = col
			t.tracer.From  = screenXY
			t.tracer.To    = Vector2.new(cx, bot.Y)
		end

		if CONFIG.Highlight and char then
			if not t.hl or t.hl.Parent ~= char then
				if t.hl then t.hl:Destroy() end
				local h = Instance.new("Highlight")
				h.Name, h.DepthMode = "VeniceESP", Enum.HighlightDepthMode.AlwaysOnTop
				h.FillTransparency, h.OutlineTransparency = 0.72, 0.25
				h.Parent = char
				t.hl = h
			end
			t.hl.Adornee, t.hl.Enabled = char, true
			t.hl.FillColor, t.hl.OutlineColor = col, col
		elseif t.hl then
			t.hl.Enabled = false
		end

		if CONFIG.Skeleton and char then
			local idx = 0
			for _, pr in ipairs(SKEL) do
				local a, b = char:FindFirstChild(pr[1]), char:FindFirstChild(pr[2])
				if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
					local pa, oa = Camera:WorldToViewportPoint(a.Position)
					local pb, ob = Camera:WorldToViewportPoint(b.Position)
					if oa and ob and pa.Z > 0 and pb.Z > 0 then
						idx += 1
						local line = t.skel[idx]
						if not line then
							line = newDraw("Line", {Thickness = 1, Color = col, ZIndex = 2})
							t.skel[idx] = line
						end
						line.Visible, line.Color = true, col
						line.From = Vector2.new(pa.X, pa.Y)
						line.To   = Vector2.new(pb.X, pb.Y)
					end
				end
			end
			for i = idx + 1, #t.skel do t.skel[i].Visible = false end
		else
			for _, l in ipairs(t.skel) do l.Visible = false end
		end
	end
end

--===================================================================
-- ДАМП (F2)
--===================================================================
local function dump()
	print("===== ДАМП v4 =====")
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			local char = getChar(plr)
			print(plr.Name ..
			      " | Team=" .. tostring(getTeam(plr)) ..
			      " | HP=" .. tostring(getHP(plr)) ..
			      " | Armor=" .. tostring(getArmor(plr)) ..
			      " | Weapon=" .. tostring(getWeapon(plr)) ..
			      " | Dead=" .. tostring(plr:GetAttribute("Dead")) ..
			      " | Char=" .. tostring(char ~= nil) ..
			      " | PresVis=" .. tostring(char and char:GetAttribute("ClientCharacterPresentationVisible")))
		end
	end
	print("====================")
end

--===================================================================
-- ПОИСК ИСТОЧНИКА ПОЗИЦИЙ (F3)
--===================================================================
local ROOTS = {Workspace, ReplicatedStorage, CoreGui}

local function scanRoots(fn)
	for _, root in ipairs(ROOTS) do
		if root then
			for _, d in ipairs(root:GetDescendants()) do
				fn(d, root)
			end
		end
	end
end

local function hunt()
	print("############ RADAR HUNT ############")

	print("--- PlayerGui ---")
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	if pg then
		for _, c in ipairs(pg:GetDescendants()) do
			if c:IsA("GuiObject") and c.Visible then
				print(string.format("   [%s] %s  absPos=%s absSize=%s",
					c.ClassName, c:GetFullName(), tostring(c.AbsolutePosition), tostring(c.AbsoluteSize)))
			end
		end
	else
		print("   нет PlayerGui")
	end

	print("--- CoreGui (дети) ---")
	for _, c in ipairs(CoreGui:GetChildren()) do
		print("   " .. c.Name .. " [" .. c.ClassName .. "]")
	end

	print("--- Workspace (верхний уровень) ---")
	for _, c in ipairs(Workspace:GetChildren()) do
		print("   " .. c.Name .. " [" .. c.ClassName .. "]")
	end

	print("--- Workspace.Characters ---")
	local folder = Workspace:FindFirstChild("Characters")
	if folder then
		for _, c in ipairs(folder:GetChildren()) do
			local pos = c:IsA("Model") and c:GetPivot().Position or Vector3.zero
			print(string.format("   %s [%s] pos=%.1f,%.1f,%.1f  PresVis=%s",
				c.Name, c.ClassName, pos.X, pos.Y, pos.Z,
				tostring(c:GetAttribute("ClientCharacterPresentationVisible"))))
		end
	else
		print("   нет папки Characters")
	end

	print("--- Объекты с никами игроков (вне персонажа) ---")
	for _, plr in ipairs(Players:GetPlayers()) do
		local hits = {}
		scanRoots(function(d)
			if d.Name == plr.Name and not (Workspace:FindFirstChild("Characters")
			     and d:IsDescendantOf(Workspace.Characters)) then
				local extra = ""
				if d:IsA("GuiObject") then
					extra = "  absPos=" .. tostring(d.AbsolutePosition) ..
					        " size=" .. tostring(d.AbsoluteSize) ..
					        " vis=" .. tostring(d.Visible)
				elseif d:IsA("BasePart") then
					extra = "  pos=" .. tostring(d.Position)
				end
				table.insert(hits, "   [" .. d.ClassName .. "] " .. d:GetFullName() .. extra)
			end
		end)
		if #hits > 0 then
			print("### " .. plr.Name .. " — совпадений " .. #hits)
			for i = 1, math.min(#hits, 12) do print(hits[i]) end
		end
	end

	print("--- Объекты-метки (radar/blip/dot/marker/pin/minimap) ---")
	for _, pat in ipairs({"radar","minimap","blip","marker","pin","dot"}) do
		local hits = {}
		scanRoots(function(d)
			if d.Name:lower():find(pat) then
				local extra = ""
				if d:IsA("GuiObject") then
					extra = "  absPos=" .. tostring(d.AbsolutePosition) .. " vis=" .. tostring(d.Visible)
				elseif d:IsA("BasePart") then
					extra = "  pos=" .. tostring(d.Position)
				end
				table.insert(hits, "   [" .. d.ClassName .. "] " .. d:GetFullName() .. extra)
			end
		end)
		if #hits > 0 then
			print("### паттерн '" .. pat .. "' — " .. #hits)
			for i = 1, math.min(#hits, 10) do print(hits[i]) end
		end
	end

	print("--- ReplicatedStorage (дети) ---")
	for _, c in ipairs(ReplicatedStorage:GetChildren()) do
		print("   " .. c.Name .. " [" .. c.ClassName .. "]")
	end

	print("####################################")
end

--===================================================================
-- ПОДКЛЮЧЕНИЕ
--===================================================================
for _, plr in ipairs(Players:GetPlayers()) do createESP(plr) end
Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(destroyESP)

local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn = "VeniceESP", false
gui.Parent = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Size                   = UDim2.new(0, 280, 0, 22)
label.Position               = UDim2.new(0, 10, 0, 10)
label.BackgroundColor3       = Color3.new(0, 0, 0)
label.BackgroundTransparency = 0.5
label.TextColor3             = Color3.fromRGB(0, 255, 130)
label.Font                   = Enum.Font.Code
label.TextSize               = 14
label.TextXAlignment         = Enum.TextXAlignment.Left
label.Text                   = " BloxStrike ESP: ON  [RShift] [F2] [F3=radar hunt]"
label.Parent                 = gui

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		CONFIG.Enabled = not CONFIG.Enabled
		label.Text = " BloxStrike ESP: " .. (CONFIG.Enabled and "ON" or "OFF") .. "  [RShift] [F2] [F3=radar hunt]"
	elseif input.KeyCode == Enum.KeyCode.F2 then
		dump()
	elseif input.KeyCode == Enum.KeyCode.F3 then
		hunt()
	end
end)

if Drawing then
	ready = true
	RunService.RenderStepped:Connect(render)
	print("[Venice] ESP v6 загружен. RShift — ESP, F2 — дамп, F3 — radar hunt.")
else
	warn("[Venice] Нет Drawing API — нужен executor.")
end
