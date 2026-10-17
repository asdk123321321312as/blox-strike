--===================================================================
--  BloxStrike ESP v4  |  Lua (Roblox / Luau)  |  Venice
--  RShift — вкл/выкл        F2 — расширенный дамп
--  Без Humanoid: риг на AnimationController
--===================================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

--===================================================================
-- НАСТРОЙКИ
--===================================================================
local CONFIG = {
	Enabled      = true,
	TeamCheck    = false,   -- включи, когда найдём, где хранится команда
	MaxDist      = 1500,

	Box          = true,
	Name         = true,
	Health       = true,
	Distance     = true,
	Tracer       = true,
	Highlight    = true,
	Skeleton     = false,

	BoxThickness = 1.5,
	TextSize     = 14,

	EnemyColor   = Color3.fromRGB(255, 70, 70),
	TeamColor    = Color3.fromRGB(90, 180, 255),
	HealthColor  = Color3.fromRGB(60, 255, 130),
	BackColor    = Color3.fromRGB(20, 20, 20),

	VisualName   = "CharacterArmor",
	Debug        = true,
}

--===================================================================
-- БАЗА
--===================================================================
local FONT  = (Drawing.Fonts and Drawing.Fonts.UI) or 0
local esp   = {}
local ready = false

local cache = setmetatable({}, {__mode = "k"})   -- [Character] = visual

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

local function getVisual(char)
	if not char then return nil end
	local v = cache[char]
	if v and v.Parent then return v end
	v = char:FindFirstChild(CONFIG.VisualName) or findDeep(char, CONFIG.VisualName) or char
	cache[char] = v
	return v
end

--===================================================================
-- HP: Humanoid -> атрибут -> ValueObject (с кэшем источника)
--===================================================================
local hpSrc = setmetatable({}, {__mode = "k"})   -- [char] = {holder, key|inst, max}

local function resolveHP(char, plr)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then return {kind = "hum", hum = hum} end

	local names = {health = true, hp = true, currenthealth = true}

	for _, holder in ipairs({plr, char}) do
		for k, v in pairs(holder:GetAttributes()) do
			if names[k:lower()] and type(v) == "number" then
				local mx = holder:GetAttribute("MaxHealth") or holder:GetAttribute("MaxHP")
				return {kind = "attr", holder = holder, key = k,
				        max = (type(mx) == "number" and mx) or 100}
			end
		end
	end

	for _, holder in ipairs({plr, char}) do
		for _, d in ipairs(holder:GetDescendants()) do
			local n = d.Name:lower()
			if names[n] and d:IsA("ValueBase") and type(d.Value) == "number" then
				local mx = holder:FindFirstChild("MaxHealth") or holder:FindFirstChild("MaxHP")
				local max = (mx and mx:IsA("ValueBase") and type(mx.Value) == "number")
				            and mx.Value or 100
				return {kind = "value", inst = d, max = max}
			end
		end
	end

	return nil
end

local function getHP(char, plr)
	local src = hpSrc[char]
	if src then
		if src.kind == "hum" then
			if src.hum.Parent then return src.hum.Health, src.hum.MaxHealth end
		elseif src.kind == "attr" then
			local v = src.holder:GetAttribute(src.key)
			if type(v) == "number" then return v, src.max end
		elseif src.kind == "value" then
			if src.inst.Parent then return src.inst.Value, src.max end
		end
	end
	local new = resolveHP(char, plr)
	hpSrc[char] = new
	if not new then return nil, nil end
	if new.kind == "hum"   then return new.hum.Health, new.hum.MaxHealth end
	if new.kind == "attr"  then return new.holder:GetAttribute(new.key), new.max end
	return new.inst.Value, new.max
end

--===================================================================
-- КОМАНДА: Team -> атрибуты -> ValueObject (кэш 1 сек)
--===================================================================
local TEAM_KEYS = {"team", "teamname", "side", "faction", "squad"}
local teamCache = setmetatable({}, {__mode = "k"})   -- [Player] = {v, t}

local function matchTeamKey(s)
	s = s:lower()
	for _, k in ipairs(TEAM_KEYS) do
		if s == k or s:find(k) then return true end
	end
	return false
end

local function resolveTeam(plr, char)
	if plr.Team then return tostring(plr.Team) end

	for _, holder in ipairs({plr, char}) do
		if holder then
			for k, v in pairs(holder:GetAttributes()) do
				if matchTeamKey(k) then return tostring(v) end
			end
		end
	end

	for _, holder in ipairs({plr, char}) do
		if holder then
			for _, d in ipairs(holder:GetDescendants()) do
				if matchTeamKey(d.Name) and d:IsA("ValueBase") then
					return tostring(d.Value)
				end
			end
		end
	end
	return nil
end

local function getTeam(plr, char)
	local c = teamCache[plr]
	if c and (tick() - c.t) < 1 then return c.v end
	local v = resolveTeam(plr, char)
	teamCache[plr] = {v = v, t = tick()}
	return v
end

--===================================================================
-- СКЕЛЕТ
--===================================================================
local SKELETON_R15 = {
	{"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"LowerTorso","HumanoidRootPart"},
	{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
	{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
	{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
	{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local SKELETON_R6 = {
	{"Head","Torso"},{"Torso","HumanoidRootPart"},
	{"Torso","Left Arm"},{"Torso","Right Arm"},
	{"Torso","Left Leg"},{"Torso","Right Leg"},
}
local function rigPairs(char)
	if char:FindFirstChild("UpperTorso") then return SKELETON_R15 end
	if char:FindFirstChild("Torso")      then return SKELETON_R6  end
	return nil
end

--===================================================================
-- ЖИЗНЕННЫЙ ЦИКЛ ESP
--===================================================================
local function hide(t)
	t.box.Visible = false; t.name.Visible = false; t.dist.Visible = false
	t.hpBg.Visible = false; t.hpBar.Visible = false; t.tracer.Visible = false
	for _, l in ipairs(t.skel) do l.Visible = false end
	if t.hl then t.hl.Enabled = false end
end

local function createESP(plr)
	esp[plr] = {
		box    = newDraw("Square", {Thickness = CONFIG.BoxThickness, Filled = false,
		                            Color = CONFIG.EnemyColor, ZIndex = 3}),
		name   = newDraw("Text",   {Size = CONFIG.TextSize, Center = true, Outline = true,
		                            OutlineColor = Color3.new(0,0,0), Color = Color3.new(1,1,1),
		                            Font = FONT, ZIndex = 4}),
		dist   = newDraw("Text",   {Size = CONFIG.TextSize - 1, Center = true, Outline = true,
		                            OutlineColor = Color3.new(0,0,0), Color = Color3.new(1,1,1),
		                            Font = FONT, ZIndex = 4}),
		hpBg   = newDraw("Square", {Thickness = 0, Filled = true, Color = CONFIG.BackColor, ZIndex = 3}),
		hpBar  = newDraw("Square", {Thickness = 0, Filled = true, Color = CONFIG.HealthColor, ZIndex = 4}),
		tracer = newDraw("Line",   {Thickness = 1.5, Color = CONFIG.EnemyColor, ZIndex = 2}),
		hl     = nil,
		skel   = {},
	}
end

local function destroyESP(plr)
	local t = esp[plr]
	if not t then return end
	t.box:Remove(); t.name:Remove(); t.dist:Remove()
	t.hpBg:Remove(); t.hpBar:Remove(); t.tracer:Remove()
	for _, l in ipairs(t.skel) do l:Remove() end
	if t.hl then t.hl:Destroy() end
	esp[plr] = nil
end

--===================================================================
-- ГЕОМЕТРИЯ
--===================================================================
local CORNERS = {
	Vector3.new(-0.5,-0.5,-0.5), Vector3.new(-0.5,-0.5, 0.5),
	Vector3.new(-0.5, 0.5,-0.5), Vector3.new(-0.5, 0.5, 0.5),
	Vector3.new( 0.5,-0.5,-0.5), Vector3.new( 0.5,-0.5, 0.5),
	Vector3.new( 0.5, 0.5,-0.5), Vector3.new( 0.5, 0.5, 0.5),
}

local function projectCorners(cf, size)
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	local seen = false
	for _, c in ipairs(CORNERS) do
		local w  = cf * Vector3.new(c.X * size.X, c.Y * size.Y, c.Z * size.Z)
		local sp, on = Camera:WorldToViewportPoint(w)
		if on and sp.Z > 0 then
			seen = true
			minX = math.min(minX, sp.X); maxX = math.max(maxX, sp.X)
			minY = math.min(minY, sp.Y); maxY = math.max(maxY, sp.Y)
		end
	end
	if not seen then return nil end
	return minX, minY, maxX, maxY
end

--===================================================================
-- ОТРИСОВКА
--===================================================================
local function render()
	if not ready then return end

	local myTeam   = getTeam(LocalPlayer, LocalPlayer.Character)
	local camPos   = Camera.CFrame.Position
	local screenXY = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)

	for plr, t in pairs(esp) do
		local char = plr.Character
		local head = char and char:FindFirstChild("Head")
		local root = char and char:FindFirstChild("HumanoidRootPart")

		local ok = CONFIG.Enabled and plr ~= LocalPlayer and char and head and root

		local sameTeam = false
		if ok and myTeam then
			local et = getTeam(plr, char)
			sameTeam = et ~= nil and et == myTeam
			if CONFIG.TeamCheck and sameTeam then ok = false end
		end

		-- мёртв?
		local hp, maxHP
		if ok then
			hp, maxHP = getHP(char, plr)
			if hp and hp <= 0 then ok = false end
		end

		local dist = 0
		if ok then
			dist = (root.Position - camPos).Magnitude
			if dist > CONFIG.MaxDist then ok = false end
		end

		if not ok then hide(t); continue end

		local col = sameTeam and CONFIG.TeamColor or CONFIG.EnemyColor

		-----------------------------------------------------------
		-- рамка: макушка Head -> низ ступней
		-----------------------------------------------------------
		local topPos = head.Position + Vector3.new(0, head.Size.Y / 2, 0)

		local lf, rf = char:FindFirstChild("LeftFoot"), char:FindFirstChild("RightFoot")
		local bottomY
		if lf and rf then
			bottomY = math.min(lf.Position.Y - lf.Size.Y / 2, rf.Position.Y - rf.Size.Y / 2)
		else
			bottomY = root.Position.Y - 2.6
		end
		local feetPos = Vector3.new(head.Position.X, bottomY, head.Position.Z)

		local top, onTop    = Camera:WorldToViewportPoint(topPos)
		local bot, onBottom = Camera:WorldToViewportPoint(feetPos)

		if not (onTop and onBottom) or top.Z <= 0 or bot.Z <= 0 then
			hide(t); continue
		end

		local height  = math.max(bot.Y - top.Y, 4)
		local width   = height * 0.55
		local minX    = top.X - width / 2
		local maxY    = bot.Y
		local centerX = top.X

		-- рамка
		t.box.Visible = CONFIG.Box
		if CONFIG.Box then
			t.box.Color     = col
			t.box.Thickness = CONFIG.BoxThickness
			t.box.Position  = Vector2.new(minX, top.Y)
			t.box.Size      = Vector2.new(width, height)
		end

		-- ник
		t.name.Visible = CONFIG.Name
		if CONFIG.Name then
			t.name.Text     = plr.Name
			t.name.Position = Vector2.new(centerX, top.Y - CONFIG.TextSize - 4)
		end

		-- дистанция
		t.dist.Visible = CONFIG.Distance
		if CONFIG.Distance then
			t.dist.Text     = string.format("[%d studs]", math.floor(dist))
			t.dist.Position = Vector2.new(centerX, maxY + 4)
		end

		-- HP
		t.hpBg.Visible  = CONFIG.Health and hp ~= nil
		t.hpBar.Visible = CONFIG.Health and hp ~= nil
		if CONFIG.Health and hp then
			local f  = math.clamp(hp / math.max(maxHP or 100, 1), 0, 1)
			local bx = minX - 6
			t.hpBg.Position  = Vector2.new(bx, top.Y)
			t.hpBg.Size      = Vector2.new(3, height)
			t.hpBar.Color    = Color3.fromRGB(math.floor(255 * (1 - f)), math.floor(255 * f), 40)
			t.hpBar.Position = Vector2.new(bx, maxY - height * f)
			t.hpBar.Size     = Vector2.new(3, height * f)
		end

		-- трассер
		t.tracer.Visible = CONFIG.Tracer
		if CONFIG.Tracer then
			t.tracer.Color = col
			t.tracer.From  = screenXY
			t.tracer.To    = Vector2.new(centerX, maxY)
		end

		-- подсветка (тело + обвес CharacterArmor)
		if CONFIG.Highlight then
			if not t.hl or t.hl.Parent ~= char then
				if t.hl then t.hl:Destroy() end
				local h = Instance.new("Highlight")
				h.Name                = "VeniceESP"
				h.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
				h.FillTransparency    = 0.72
				h.OutlineTransparency = 0.25
				h.Parent              = char
				t.hl = h
			end
			t.hl.Adornee      = char
			t.hl.Enabled      = true
			t.hl.FillColor    = col
			t.hl.OutlineColor = col
		elseif t.hl then
			t.hl.Enabled = false
		end

		-- скелет
		if CONFIG.Skeleton then
			local list, idx = rigPairs(char), 0
			if list then
				for _, pr in ipairs(list) do
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
							line.Visible = true
							line.Color   = col
							line.From    = Vector2.new(pa.X, pa.Y)
							line.To      = Vector2.new(pb.X, pb.Y)
						end
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
-- РАСШИРЕННЫЙ ДАМП (F2)
--===================================================================
local function dumpTree(inst, indent, out, maxIndent)
	indent = indent or 0
	out = out or {}
	table.insert(out, string.rep("  ", indent) .. inst.Name .. " [" .. inst.ClassName .. "]")
	if indent < (maxIndent or 4) then
		for _, c in ipairs(inst:GetChildren()) do
			dumpTree(c, indent + 1, out, maxIndent)
		end
	end
	return out
end

local function dumpAttrs(inst, tag)
	local a = inst:GetAttributes()
	local out = {}
	for k, v in pairs(a) do
		table.insert(out, "   " .. tag .. " attr: " .. k .. " = " .. tostring(v))
	end
	return out
end

local function dumpValues(inst, tag, limit)
	local out, n = {}, 0
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("ValueBase") then
			n += 1
			if n <= (limit or 40) then
				table.insert(out, "   " .. tag .. ": " .. d.Name .. " [" .. d.ClassName ..
					"] = " .. tostring(d.Value))
			end
		end
	end
	table.insert(out, "   " .. tag .. ": всего ValueBase = " .. n)
	return out
end

local function dump()
	local lp = LocalPlayer
	print("############ ДАМП v2 ############")

	print("--- LOCAL PLAYER ---")
	print("   Team = " .. tostring(lp.Team) ..
	      " | TeamColor = " .. tostring(lp.TeamColor) ..
	      " | UserId = " .. lp.UserId)
	for _, l in ipairs(dumpAttrs(lp, "LocalPlayer")) do print(l) end
	for _, l in ipairs(dumpValues(lp, "LocalPlayer")) do print(l) end
	print("   Дерево Player:")
	for _, l in ipairs(dumpTree(lp, 2, {}, 3)) do print(l) end

	print("--- LOCAL CHARACTER ---")
	local ch = lp.Character
	if ch then
		print("   Model = " .. ch.Name .. " | Attributes = " .. tostring(#ch:GetAttributes()))
		for _, l in ipairs(dumpAttrs(ch, "Character")) do print(l) end
		for _, l in ipairs(dumpValues(ch, "Character")) do print(l) end
		print("   Дети Character:")
		for _, c in ipairs(ch:GetChildren()) do
			print("      " .. c.Name .. " [" .. c.ClassName .. "]")
		end
	else
		print("   нет персонажа")
	end

	print("--- WORKSPACE (верхний уровень) ---")
	for _, c in ipairs(Workspace:GetChildren()) do
		print("   " .. c.Name .. " [" .. c.ClassName .. "]")
	end

	print("--- ВРАГ ---")
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= lp and plr.Character then
			print("   " .. plr.Name ..
			      " | Team=" .. tostring(plr.Team) ..
			      " | attrs=" .. tostring(#plr:GetAttributes()))
			for _, l in ipairs(dumpAttrs(plr, "Enemy")) do print(l) end
			for _, l in ipairs(dumpAttrs(plr.Character, "EnemyChar")) do print(l) end
			for _, l in ipairs(dumpValues(plr, "EnemyPlayer", 15)) do print(l) end
			break
		end
	end
	print("##################################")
end

--===================================================================
-- СОЗДАНИЕ / УДАЛЕНИЕ
--===================================================================
for _, plr in ipairs(Players:GetPlayers()) do createESP(plr) end
Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(destroyESP)

--===================================================================
-- ПЛАШКА + КЛАВИШИ
--===================================================================
local gui = Instance.new("ScreenGui")
gui.Name = "VeniceESP"
gui.ResetOnSpawn = false
gui.Parent = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Size                   = UDim2.new(0, 250, 0, 22)
label.Position               = UDim2.new(0, 10, 0, 10)
label.BackgroundColor3       = Color3.new(0, 0, 0)
label.BackgroundTransparency = 0.5
label.TextColor3             = Color3.fromRGB(0, 255, 130)
label.Font                   = Enum.Font.Code
label.TextSize               = 14
label.TextXAlignment         = Enum.TextXAlignment.Left
label.Text                   = " BloxStrike ESP: ON  [RShift] [F2=дамп]"
label.Parent                 = gui

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		CONFIG.Enabled = not CONFIG.Enabled
		label.Text = " BloxStrike ESP: " .. (CONFIG.Enabled and "ON" or "OFF") .. "  [RShift] [F2=дамп]"
	elseif input.KeyCode == Enum.KeyCode.F2 then
		dump()
	end
end)

--===================================================================
-- СТАРТ
--===================================================================
if Drawing then
	ready = true
	RunService.RenderStepped:Connect(render)
	print("[Venice] ESP v4 загружен. RShift — вкл/выкл, F2 — расширенный дамп.")
else
	warn("[Venice] Нет Drawing API — нужен executor.")
end
