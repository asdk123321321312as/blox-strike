--[[
================================================================================
        ███████╗██╗     ███████╗███████╗██████╗     SleepScript
        ██╔════╝██║     ██╔════╝██╔════╝██╔══██╗    BloxStrike Edition
        ███████╗██║     █████╗  █████╗  ██████╔╝    v1.0
        ╚════██║██║     ██╔══╝  ██╔══╝  ██╔═══╝
        ███████║███████╗███████╗███████╗██║
        ╚══════╝╚══════╝╚══════╝╚══════╝╚═╝
================================================================================
  FEATURES
   • Smooth black animated UI (own library, no Rayfield)
   • ESP: chams (Highlight), 2D boxes, tracers, names, health, distance, weapon
   • SkinChanger: knives / gloves / all weapons / finishes / gloves
   • AutoBunnyHop (hold Space) + InfiniteJump
   • Visuals: custom sky, atmosphere, particles, weapon glow, fullbright
   • Standalone draggable Ping/FPS/Memory overlay
   • FPS Boost (restorable) + AntiCheat bypass suite
   • Config save/load
================================================================================
  KEYBINDS:  [RightShift] Menu   [F4] Overlay   [Mouse2] Aim assist
================================================================================
]]

--=====================================================================
-- 0. UNLOAD PREVIOUS INSTANCE
--=====================================================================
if _G.SleepScript and _G.SleepScript.Unload then
	pcall(function() _G.SleepScript:Unload() end)
end

--=====================================================================
-- 1. SERVICES
--=====================================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui        = game:GetService("StarterGui")
local Stats             = game:GetService("Stats")
local VirtualUser       = game:GetService("VirtualUser")
local CoreGui           = game:GetService("CoreGui")
local LocalPlayer       = Players.LocalPlayer
local Camera            = Workspace.CurrentCamera

--=====================================================================
-- 2. CORE OBJECT + UTILITIES
--=====================================================================
local SleepScript = {
	Version    = "1.0.0",
	Connections = {},
	Objects    = {},
	Backups    = {},
	Flags      = {},
	Unloaded   = false,
}
_G.SleepScript = SleepScript

local function Conn(signal, fn)
	local c = signal:Connect(fn)
	table.insert(SleepScript.Connections, c)
	return c
end

local function New(class, props, parent)
	local inst = Instance.new(class)
	if props then
		for k, v in next, props do
			pcall(function() inst[k] = v end)
		end
	end
	if parent then inst.Parent = parent end
	return inst
end

local function Corner(parent, r)
	return New("UICorner", { CornerRadius = UDim.new(0, r or 8) }, parent)
end

local function Stroke(parent, color, thickness, transparency)
	return New("UIStroke", {
		Color = color or Color3.fromRGB(45, 45, 58),
		Thickness = thickness or 1,
		Transparency = transparency or 0.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function Pad(parent, t, r, b, l)
	return New("UIPadding", {
		PaddingTop = UDim.new(0, t or 0),
		PaddingRight = UDim.new(0, r or 0),
		PaddingBottom = UDim.new(0, b or 0),
		PaddingLeft = UDim.new(0, l or 0),
	}, parent)
end

local function Tween(obj, time, props, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(
		time or 0.22,
		style or Enum.EasingStyle.Quint,
		dir or Enum.EasingDirection.Out
	), props)
	t:Play()
	return t
end

local function GuiParent()
	if gethui then
		local ok, hui = pcall(gethui)
		if ok and hui then return hui end
	end
	local ok, core = pcall(function() return CoreGui end)
	if ok and core then
		local works = pcall(function()
			local f = Instance.new("Frame"); f.Parent = core; f:Destroy()
		end)
		if works then return core end
	end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local function IsAlive(plr)
	local char = plr and plr.Character
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function GetHRP(plr)
	local char = plr and plr.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
end

--=====================================================================
-- 3. THEME
--=====================================================================
local Theme = {
	Accent   = Color3.fromRGB(130, 100, 255),
	Accent2  = Color3.fromRGB(80, 190, 255),
	Bg       = Color3.fromRGB(9, 9, 12),
	Bg2      = Color3.fromRGB(15, 15, 19),
	Surface  = Color3.fromRGB(20, 20, 26),
	Surface2 = Color3.fromRGB(28, 28, 36),
	Stroke   = Color3.fromRGB(44, 44, 56),
	Text     = Color3.fromRGB(238, 238, 248),
	Sub      = Color3.fromRGB(142, 142, 162),
	Good     = Color3.fromRGB(96, 226, 148),
	Warn     = Color3.fromRGB(250, 196, 88),
	Bad      = Color3.fromRGB(240, 96, 96),
}
local AccentRegistry = {}
local function RegisterAccent(inst, prop)
	table.insert(AccentRegistry, { inst = inst, prop = prop })
end

--=====================================================================
-- 4. NOTIFICATIONS
--=====================================================================
local NotifyGui = New("ScreenGui", {
	Name = "SleepNotify", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1000,
}, GuiParent())
SleepScript.Objects[#SleepScript.Objects + 1] = NotifyGui

local NotifyHolder = New("Frame", {
	Size = UDim2.fromOffset(260, 400), Position = UDim2.new(1, -18, 0, 60),
	AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1,
}, NotifyGui)
New("UIListLayout", {
	Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
}, NotifyHolder)

local function Notify(title, text, duration)
	duration = duration or 3
	local card = New("Frame", {
		Size = UDim2.fromOffset(250, 54), BackgroundColor3 = Theme.Bg2,
		BackgroundTransparency = 1, BorderSizePixel = 0,
	}, NotifyHolder)
	Corner(card, 10)
	local st = Stroke(card, Theme.Accent, 1, 1)
	local bar = New("Frame", {
		Size = UDim2.new(0, 3, 1, -14), Position = UDim2.new(0, 7, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0, BackgroundTransparency = 1,
	}, card)
	Corner(bar, 4)
	local t1 = New("TextLabel", {
		Size = UDim2.new(1, -26, 0, 18), Position = UDim2.new(0, 18, 0, 8),
		BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13,
		TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
		Text = title, TextTransparency = 1,
	}, card)
	local t2 = New("TextLabel", {
		Size = UDim2.new(1, -26, 0, 16), Position = UDim2.new(0, 18, 0, 26),
		BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11,
		TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Left,
		Text = text or "", TextWrapped = true, TextTransparency = 1,
	}, card)

	local grp = { card, bar, t1, t2 }
	for _, o in ipairs(grp) do
		if o:IsA("TextLabel") then
			Tween(o, 0.25, { TextTransparency = 0 })
		else
			Tween(o, 0.25, { BackgroundTransparency = o == card and 0.05 or 0 })
		end
	end
	Tween(st, 0.25, { Transparency = 0.6 })

	task.delay(duration, function()
		if not card.Parent then return end
		Tween(card, 0.25, { BackgroundTransparency = 1 })
		Tween(t1, 0.2, { TextTransparency = 1 })
		Tween(t2, 0.2, { TextTransparency = 1 })
		Tween(st, 0.2, { Transparency = 1 })
		task.wait(0.3)
		card:Destroy()
	end)
end
SleepScript.Notify = Notify

--=====================================================================
-- 5. UI LIBRARY
--=====================================================================
local Lib = {}
Lib.Theme = Theme

local MainGui = New("ScreenGui", {
	Name = "SleepScriptUI", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 900,
}, GuiParent())
SleepScript.Objects[#SleepScript.Objects + 1] = MainGui

local function Hover(btn, normal, hovered, extra)
	btn.MouseEnter:Connect(function()
		Tween(btn, 0.18, hovered)
		if extra then extra(true) end
	end)
	btn.MouseLeave:Connect(function()
		Tween(btn, 0.18, normal)
		if extra then extra(false) end
	end)
end

--// WINDOW ------------------------------------------------------------
function Lib:Window(cfg)
	cfg = cfg or {}
	local win = { Tabs = {}, Open = true, Flags = SleepScript.Flags }

	local holder = New("Frame", {
		Name = "SleepHolder", Size = UDim2.fromOffset(640, 442),
		Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1, Visible = false,
	}, MainGui)
	local scale = New("UIScale", { Scale = 0.94 }, holder)

	local shadow = New("Frame", {
		Name = "Shadow", Size = UDim2.new(1, 18, 1, 18),
		Position = UDim2.new(0.5, 0, 0.5, 9), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45,
		BorderSizePixel = 0, ZIndex = 0,
	}, holder)
	Corner(shadow, 22)

	local root = New("CanvasGroup", {
		Name = "Root", Size = UDim2.new(1, -20, 1, -20),
		Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Bg, BorderSizePixel = 0, GroupTransparency = 1,
		ClipsDescendants = true, ZIndex = 1,
	}, holder)
	Corner(root, 14)
	Stroke(root, Theme.Stroke, 1, 0.5)

	--// TOPBAR
	local topbar = New("Frame", {
		Name = "Topbar", Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Theme.Bg2, BorderSizePixel = 0, ZIndex = 2,
	}, root)
	Corner(topbar, 14)
	New("Frame", {
		Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14),
		BackgroundColor3 = Theme.Bg2, BorderSizePixel = 0, ZIndex = 2,
	}, topbar)

	local logo = New("Frame", {
		Size = UDim2.fromOffset(9, 9), Position = UDim2.new(0, 16, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0, ZIndex = 3,
	}, topbar)
	Corner(logo, 5)
	RegisterAccent(logo, "BackgroundColor3")

	local title = New("TextLabel", {
		Size = UDim2.fromOffset(200, 20), Position = UDim2.new(0, 32, 0.5, -8),
		BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 16,
		Text = cfg.Title or "SleepScript", TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
	}, topbar)

	local sub = New("TextLabel", {
		Size = UDim2.fromOffset(260, 14), Position = UDim2.new(0, 33, 0.5, 8),
		BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 10,
		Text = cfg.Subtitle or "bloxstrike edition  •  v" .. SleepScript.Version,
		TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
	}, topbar)

	local grad = New("Frame", {
		Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1),
		BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, ZIndex = 3,
	}, topbar)
	New("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Theme.Accent),
			ColorSequenceKeypoint.new(1, Theme.Accent2),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.75),
			NumberSequenceKeypoint.new(0.5, 0.05),
			NumberSequenceKeypoint.new(1, 0.75),
		}),
	}, grad)

	--// WINDOW BUTTONS
	local function WinBtn(txt, xoff, cb)
		local b = New("TextButton", {
			Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, xoff, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = Theme.Surface,
			BorderSizePixel = 0, Text = txt, Font = Enum.Font.GothamBold,
			TextSize = 13, TextColor3 = Theme.Sub, AutoButtonColor = false, ZIndex = 4,
		}, topbar)
		Corner(b, 8)
		Hover(b, { BackgroundColor3 = Theme.Surface, TextColor3 = Theme.Sub },
			{ BackgroundColor3 = Theme.Surface2, TextColor3 = Theme.Text })
		b.MouseButton1Click:Connect(cb)
		return b
	end

	local minimized = false
	WinBtn("—", -46, function()
		minimized = not minimized
		if minimized then
			Tween(holder, 0.3, { Size = UDim2.fromOffset(240, 44) })
			Tween(root, 0.3, { Size = UDim2.new(1, -20, 1, -20) })
		else
			Tween(holder, 0.3, { Size = UDim2.fromOffset(640, 442) })
		end
	end)
	WinBtn("✕", -14, function() win:Toggle(false) end)

	--// DRAG
	do
		local dragging, dragStart, startPos = false, nil, nil
		topbar.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1
				or i.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = i.Position
				startPos = holder.Position
			end
		end)
		Conn(UserInputService.InputEnded, function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1
				or i.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
		Conn(UserInputService.InputChanged, function(i)
			if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
				or i.UserInputType == Enum.UserInputType.Touch) then
				local d = i.Position - dragStart
				holder.Position = UDim2.new(
					startPos.X.Scale, startPos.X.Offset + d.X,
					startPos.Y.Scale, startPos.Y.Offset + d.Y
				)
			end
		end)
	end

	--// SIDEBAR
	local sidebar = New("Frame", {
		Size = UDim2.new(0, 138, 1, -58), Position = UDim2.new(0, 12, 0, 50),
		BackgroundColor3 = Theme.Bg2, BorderSizePixel = 0, ZIndex = 2,
	}, root)
	Corner(sidebar, 11)
	Pad(sidebar, 8, 8, 8, 8)
	New("UIListLayout", {
		Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder,
	}, sidebar)

	local indicator = New("Frame", {
		Size = UDim2.new(0, 3, 0, 20), Position = UDim2.new(0, 2, 0, 8),
		BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, ZIndex = 3,
	}, sidebar)
	Corner(indicator, 3)
	RegisterAccent(indicator, "BackgroundColor3")

	--// CONTENT
	local contentHolder = New("Frame", {
		Size = UDim2.new(1, -170, 1, -58), Position = UDim2.new(0, 158, 0, 50),
		BackgroundTransparency = 1, ZIndex = 2,
	}, root)

	--// ANIMATION HELPERS
	function win:Toggle(state)
		if state == nil then state = not self.Open end
		self.Open = state
		if state then
			holder.Visible = true
			scale.Scale = 0.94
			root.GroupTransparency = 1
			Tween(scale, 0.32, { Scale = 1 })
			Tween(root, 0.28, { GroupTransparency = 0 })
			Tween(shadow, 0.32, { BackgroundTransparency = 0.45 })
		else
			Tween(scale, 0.22, { Scale = 0.94 })
			Tween(root, 0.2, { GroupTransparency = 1 })
			task.delay(0.22, function()
				if not self.Open then holder.Visible = false end
			end)
		end
	end

	--// TABS
	local function MakeTab(name, icon)
		local tab = { Name = name, Elements = {}, Conn = {} }

		local btn = New("TextButton", {
			Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Bg2,
			BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
			Text = "", ZIndex = 3,
		}, sidebar)
		Corner(btn, 8)
		local lbl = New("TextLabel", {
			Size = UDim2.new(1, -22, 1, 0), Position = UDim2.new(0, 20, 0, 0),
			BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
			Text = (icon and icon .. "  " or "") .. name, TextColor3 = Theme.Sub,
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
		}, btn)

		local wrap = New("CanvasGroup", {
			Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
			Visible = false, GroupTransparency = 1, ZIndex = 2,
		}, contentHolder)

		local scroll = New("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
			BorderSizePixel = 0, ScrollBarThickness = 3,
			ScrollBarImageColor3 = Theme.Stroke,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 2,
		}, wrap)
		New("UIListLayout", {
			Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder,
		}, scroll)
		Pad(scroll, 4, 8, 14, 4)

		tab.Content = scroll

		btn.MouseEnter:Connect(function()
			if win.ActiveTab ~= tab then
				Tween(btn, 0.18, { BackgroundTransparency = 0.75 })
				Tween(lbl, 0.18, { TextColor3 = Theme.Text })
			end
		end)
		btn.MouseLeave:Connect(function()
			if win.ActiveTab ~= tab then
				Tween(btn, 0.18, { BackgroundTransparency = 1 })
				Tween(lbl, 0.18, { TextColor3 = Theme.Sub })
			end
		end)
		btn.MouseButton1Click:Connect(function() win:Select(tab) end)

		tab.Button = btn
		tab.Label = lbl
		win.Tabs[#win.Tabs + 1] = tab
		return tab
	end

	function win:Select(tab)
		if win.ActiveTab == tab then return end
		win.ActiveTab = tab
		for _, t in ipairs(win.Tabs) do
			local active = (t == tab)
			Tween(t.Label, 0.2, { TextColor3 = active and Theme.Text or Theme.Sub })
			Tween(t.Button, 0.2, { BackgroundTransparency = active and 0.85 or 1 })
			if active then
				t.Wrap = t.Wrap or t.Content.Parent
				t.Wrap.Visible = true
				Tween(t.Wrap, 0.22, { GroupTransparency = 0 })
				Tween(indicator, 0.25, {
					Position = UDim2.new(0, 2, 0, t.Button.AbsolutePosition.Y - sidebar.AbsolutePosition.Y + 5),
					Size = UDim2.new(0, 3, 0, 20),
				})
			else
				local w = t.Content.Parent
				Tween(w, 0.16, { GroupTransparency = 1 })
				task.delay(0.17, function()
					if win.ActiveTab ~= t then w.Visible = false end
				end)
			end
		end
	end

	win.MakeTab = MakeTab
	win.Holder = holder
	win.Root = root
	return win
end

--// COMPONENTS --------------------------------------------------------
local function Section(parent, text)
	local f = New("Frame", {
		Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
	}, parent)
	local bar = New("Frame", {
		Size = UDim2.new(0, 3, 0, 13), Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
	}, f)
	Corner(bar, 2)
	RegisterAccent(bar, "BackgroundColor3")
	New("TextLabel", {
		Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 12, 0, 0),
		BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12,
		Text = text:upper(), TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, f)
	return f
end

local function Toggle(parent, o)
	o = o or {}
	local f = New("Frame", {
		Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Surface,
		BackgroundTransparency = 0.35, BorderSizePixel = 0,
	}, parent)
	Corner(f, 9)
	Stroke(f, Theme.Stroke, 1, 0.7)
	New("TextLabel", {
		Size = UDim2.new(1, -60, 1, 0), Position = UDim2.new(0, 12, 0, 0),
		BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
		Text = o.Text or "Toggle", TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, f)

	local pill = New("Frame", {
		Size = UDim2.fromOffset(38, 18), Position = UDim2.new(1, -12, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = Theme.Surface2,
		BorderSizePixel = 0,
	}, f)
	Corner(pill, 9)
	local knob = New("Frame", {
		Size = UDim2.fromOffset(14, 14), Position = UDim2.new(0, 2, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Theme.Sub,
		BorderSizePixel = 0,
	}, pill)
	Corner(knob, 7)

	local btn = New("TextButton", {
		Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
		Text = "", AutoButtonColor = false,
	}, f)

	local state = o.Default or false
	local obj = {}

	function obj:Set(v, silent)
		state = v and true or false
		SleepScript.Flags[o.Flag or o.Text] = state
		Tween(pill, 0.2, { BackgroundColor3 = state and Theme.Accent or Theme.Surface2 })
		Tween(knob, 0.22, {
			Position = state and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
			BackgroundColor3 = state and Color3.new(1, 1, 1) or Theme.Sub,
		}, Enum.EasingStyle.Back)
		if not silent and o.Callback then
			task.spawn(o.Callback, state)
		end
	end

	btn.MouseButton1Click:Connect(function() obj:Set(not state) end)
	Hover(f, { BackgroundTransparency = 0.35 }, { BackgroundTransparency = 0.15 })

	if state then obj:Set(true, true) end
	return obj
end

local function Slider(parent, o)
	o = o or {}
	local f = New("Frame", {
		Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = Theme.Surface,
		BackgroundTransparency = 0.35, BorderSizePixel = 0,
	}, parent)
	Corner(f, 9)
	Stroke(f, Theme.Stroke, 1, 0.7)
	New("TextLabel", {
		Size = UDim2.new(1, -70, 0, 18), Position = UDim2.new(0, 12, 0, 5),
		BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
		Text = o.Text or "Slider", TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, f)
	local val = New("TextLabel", {
		Size = UDim2.new(0, 60, 0, 18), Position = UDim2.new(1, -12, 0, 5),
		AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Accent,
		TextXAlignment = Enum.TextXAlignment.Right, Text = tostring(o.Default or 0),
	}, f)

	local track = New("Frame", {
		Size = UDim2.new(1, -24, 0, 5), Position = UDim2.new(0, 12, 1, -14),
		BackgroundColor3 = Theme.Surface2, BorderSizePixel = 0,
	}, f)
	Corner(track, 3)
	local fill = New("Frame", {
		Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
	}, track)
	Corner(fill, 3)
	local knob = New("Frame", {
		Size = UDim2.fromOffset(12, 12), Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, track)
	Corner(knob, 6)

	local min = o.Min or 0
	local max = o.Max or 100
	local decimals = o.Decimals or 0
	local value = o.Default or min
	local obj = {}

	local function render()
		local a = (value - min) / math.max(max - min, 0.0001)
		Tween(fill, 0.08, { Size = UDim2.new(a, 0, 1, 0) }, Enum.EasingStyle.Linear)
		knob.Position = UDim2.new(a, 0, 0.5, 0)
		local txt = decimals > 0
			and string.format("%." .. decimals .. "f", value)
			or tostring(math.floor(value + 0.5))
		val.Text = (o.Suffix and (txt .. o.Suffix)) or txt
	end

	function obj:Set(v, silent)
		value = math.clamp(v, min, max)
		SleepScript.Flags[o.Flag or o.Text] = value
		render()
		if not silent and o.Callback then task.spawn(o.Callback, value) end
	end

	local dragging = false
	local function update(input)
		local rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		obj:Set(min + rel * (max - min))
	end
	track.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1
			or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			update(i)
		end
	end)
	Conn(UserInputService.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1
			or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	Conn(UserInputService.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
			or i.UserInputType == Enum.UserInputType.Touch) then
			update(i)
		end
	end)

	render()
	if o.Callback then task.spawn(o.Callback, value) end
	return obj
end

local function Button(parent, o)
	o = o or {}
	local b = New("TextButton", {
		Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Surface,
		BackgroundTransparency = 0.35, BorderSizePixel = 0, Text = "",
		AutoButtonColor = false,
	}, parent)
	Corner(b, 9)
	Stroke(b, Theme.Stroke, 1, 0.7)
	New("TextLabel", {
		Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 10, 0, 0),
		BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
		Text = o.Text or "Button", TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, b)
	Hover(b, { BackgroundTransparency = 0.35 }, { BackgroundTransparency = 0.12 })
	b.MouseButton1Click:Connect(function()
		if o.Callback then task.spawn(o.Callback) end
	end)
	return b
end

local function Keybind(parent, o)
	o = o or {}
	local f = New("Frame", {
		Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Surface,
		BackgroundTransparency = 0.35, BorderSizePixel = 0,
	}, parent)
	Corner(f, 9)
	Stroke(f, Theme.Stroke, 1, 0.7)
	New("TextLabel", {
		Size = UDim2.new(1, -80, 1, 0), Position = UDim2.new(0, 12, 0, 0),
		BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
		Text = o.Text or "Keybind", TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, f)
	local keyBtn = New("TextButton", {
		Size = UDim2.fromOffset(56, 20), Position = UDim2.new(1, -12, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = Theme.Surface2,
		BorderSizePixel = 0, Text = o.Default or "None", Font = Enum.Font.GothamBold,
		TextSize = 11, TextColor3 = Theme.Accent, AutoButtonColor = false,
	}, f)
	Corner(keyBtn, 6)

	local listening = false
	local key = o.Default or "None"
	local obj = { Key = key }

	local function setKey(k)
		key = k
		obj.Key = k
		keyBtn.Text = k
		SleepScript.Flags[o.Flag or o.Text] = k
		if o.Callback then task.spawn(o.Callback, k) end
	end

	keyBtn.MouseButton1Click:Connect(function()
		listening = true
		keyBtn.Text = "..."
		Tween(keyBtn, 0.15, { TextColor3 = Theme.Warn })
	end)

	Conn(UserInputService.InputBegan, function(i, gp)
		if listening then
			listening = false
			Tween(keyBtn, 0.15, { TextColor3 = Theme.Accent })
			local name = (i.KeyCode == Enum.KeyCode.Unknown)
				and ("M" .. i.UserInputType.Value) or i.KeyCode.Name
			setKey(name)
			return
		end
		if gp then return end
		if i.KeyCode.Name == key and o.Callback then
			task.spawn(o.Callback, key, true)
		end
	end)

	if o.Callback then task.spawn(o.Callback, key) end
	return obj
end

local function Dropdown(parent, o)
	o = o or {}
	local f = New("Frame", {
		Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Surface,
		BackgroundTransparency = 0.35, BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, parent)
	Corner(f, 9)
	Stroke(f, Theme.Stroke, 1, 0.7)
	New("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, f)
	Pad(f, 2, 4, 4, 4)

	local header = New("TextButton", {
		Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
		Text = "", AutoButtonColor = false, LayoutOrder = 1,
	}, f)
	New("TextLabel", {
		Size = UDim2.new(1, -70, 1, 0), Position = UDim2.new(0, 8, 0, 0),
		BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
		Text = o.Text or "Dropdown", TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, header)
	local valueLbl = New("TextLabel", {
		Size = UDim2.new(0, 130, 1, 0), Position = UDim2.new(1, -26, 0, 0),
		BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 11,
		Text = "", TextColor3 = Theme.Accent,
		TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
	}, header)
	local arrow = New("TextLabel", {
		Size = UDim2.fromOffset(18, 18), Position = UDim2.new(1, -22, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold, TextSize = 12, Text = "+",
		TextColor3 = Theme.Sub,
	}, header)

	local list = New("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.2, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Stroke,
		Visible = false, LayoutOrder = 2, CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, f)
	Corner(list, 7)
	New("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	Pad(list, 3, 3, 3, 3)

	local search = New("TextBox", {
		Size = UDim2.new(1, -6, 0, 20), BackgroundColor3 = Theme.Surface2,
		BorderSizePixel = 0, Font = Enum.Font.Gotham, TextSize = 11,
		Text = "", PlaceholderText = "search...", TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.Sub, ClearTextOnFocus = false, Visible = false,
	}, list)
	Corner(search, 5)
	Pad(search, 0, 4, 0, 4)

	local obj = { Options = o.Options or {}, Value = o.Default or (o.Options and o.Options[1]) }
	local open = false

	local function build(filter)
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("TextButton") then c:Destroy() end
		end
		filter = (filter or ""):lower()
		local shown = 0
		for _, opt in ipairs(obj.Options) do
			if filter == "" or tostring(opt):lower():find(filter, 1, true) then
				shown = shown + 1
				local b = New("TextButton", {
					Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = Theme.Bg,
					BackgroundTransparency = 1, BorderSizePixel = 0, Text = "",
					AutoButtonColor = false,
				}, list)
				Corner(b, 5)
				local t = New("TextLabel", {
					Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 8, 0, 0),
					BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11,
					Text = tostring(opt), TextColor3 = Theme.Sub,
					TextXAlignment = Enum.TextXAlignment.Left,
				}, b)
				if obj.Value == opt then
					t.TextColor3 = Theme.Accent
					b.BackgroundTransparency = 0.7
				end
				Hover(b, { BackgroundTransparency = 1 }, { BackgroundTransparency = 0.8 })
				b.MouseButton1Click:Connect(function()
					obj:Set(opt)
					obj:Open(false)
				end)
			end
		end
		list.CanvasSize = UDim2.new(0, 0, 0, math.max(shown * 23 + (search.Visible and 24 or 0), 10))
	end

	function obj:Open(state)
		open = state
		arrow.Text = open and "-" or "+"
		search.Visible = open and (#obj.Options > 10)
		list.Visible = open
		if open then
			build(search.Text)
			Tween(list, 0.22, {
				Size = UDim2.new(1, 0, 0, math.min(math.max(#obj.Options * 23 + 10, 40), 170)),
			})
		else
			Tween(list, 0.18, { Size = UDim2.new(1, 0, 0, 0) })
		end
	end

	function obj:Set(v, silent)
		obj.Value = v
		valueLbl.Text = tostring(v)
		SleepScript.Flags[o.Flag or o.Text] = v
		if open then build(search.Text) end
		if not silent and o.Callback then task.spawn(o.Callback, v) end
	end

	function obj:SetOptions(opts)
		obj.Options = opts
		if not table.find(opts, obj.Value) then obj.Value = opts[1] end
		valueLbl.Text = tostring(obj.Value)
		if open then build(search.Text) end
	end

	header.MouseButton1Click:Connect(function() obj:Open(not open) end)
	search:GetPropertyChangedSignal("Text"):Connect(function() build(search.Text) end)

	if obj.Value then obj:Set(obj.Value, true) end
	return obj
end

local function ColorPicker(parent, o)
	o = o or {}
	local f = New("Frame", {
		Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Surface,
		BackgroundTransparency = 0.35, BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, parent)
	Corner(f, 9)
	Stroke(f, Theme.Stroke, 1, 0.7)
	New("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, f)
	Pad(f, 2, 6, 4, 6)

	local header = New("TextButton", {
		Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Text = "",
		AutoButtonColor = false, LayoutOrder = 1,
	}, f)
	New("TextLabel", {
		Size = UDim2.new(1, -60, 1, 0), Position = UDim2.new(0, 6, 0, 0),
		BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
		Text = o.Text or "Color", TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, header)
	local swatch = New("Frame", {
		Size = UDim2.fromOffset(38, 18), Position = UDim2.new(1, -4, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = o.Default or Theme.Accent,
		BorderSizePixel = 0,
	}, header)
	Corner(swatch, 5)
	Stroke(swatch, Theme.Stroke, 1, 0.4)

	local body = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, Visible = false,
		LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.Y,
	}, f)
	New("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, body)

	local color = o.Default or Theme.Accent
	local obj = {}

	local function apply()
		swatch.BackgroundColor3 = color
		SleepScript.Flags[o.Flag or o.Text] = color
		if o.Callback then task.spawn(o.Callback, color) end
	end

	local comps = { "R", "G", "B" }
	local sliders = {}
	for i, c in ipairs(comps) do
		sliders[c] = Slider(body, {
			Text = c, Min = 0, Max = 255, Default = math.floor(color[c] * 255),
			Callback = function(v)
				color = Color3.fromRGB(
					math.floor(sliders.R and sliders.R.Value or 0),
					math.floor(sliders.G and sliders.G.Value or 0),
					math.floor(sliders.B and sliders.B.Value or 0)
				)
				apply()
			end,
		})
	end
	-- keep references for reading
	for i, c in ipairs(comps) do sliders[c].Value = math.floor(color[c] * 255) end

	function obj:Set(c, silent)
		color = c
		sliders.R.Value = math.floor(c.R * 255)
		sliders.G.Value = math.floor(c.G * 255)
		sliders.B.Value = math.floor(c.B * 255)
		apply()
	end

	header.MouseButton1Click:Connect(function()
		local open = not body.Visible
		body.Visible = open
		Tween(body, 0.2, { Size = open and UDim2.new(1, 0, 0, 132) or UDim2.new(1, 0, 0, 0) })
	end)

	apply()
	return obj
end

Lib.Section = Section
Lib.Toggle = Toggle
Lib.Slider = Slider
Lib.Button = Button
Lib.Keybind = Keybind
Lib.Dropdown = Dropdown
Lib.ColorPicker = ColorPicker

--=====================================================================
-- 6. GAME DATA (BloxStrike)
--=====================================================================
local WEAPONS = {
	"AK-47", "M4A1", "M4A1-S", "AWP", "SSG-08", "AUG", "SG-553", "FAMAS",
	"Galil AR", "SCAR-20", "G3SG1", "MP9", "MAC-10", "MP7", "MP5-SD", "UMP-45",
	"P90", "PP-Bizon", "Nova", "XM1014", "MAG-7", "Sawed-Off", "M249", "Negev",
	"Glock-18", "USP-S", "P2000", "P250", "Five-SeveN", "Tec-9", "CZ75-Auto",
	"Dual Berettas", "Desert Eagle", "R8 Revolver", "M1911", "Revolver",
}
local KNIVES = {
	"Karambit", "Butterfly Knife", "M9 Bayonet", "Bayonet", "Flip Knife",
	"Gut Knife", "Huntsman Knife", "Falchion Knife", "Bowie Knife",
	"Shadow Daggers", "Skeleton Knife", "Nomad Knife", "Paracord Knife",
	"Survival Knife", "Ursus Knife", "Stiletto Knife", "Talon Knife",
	"Classic Knife", "Kukri Knife",
}
local GLOVES = {
	"Sports Gloves", "Driver Gloves", "Hand Wraps", "Specialist Gloves",
	"Moto Gloves", "Bloodhound Gloves", "Broken Fang Gloves",
	"Hydra Gloves", "Operator Gloves", "Default Gloves",
}
local FINISHES = {
	"Vanilla", "Fade", "Slaughter", "Case Hardened", "Damascus Steel",
	"Crimson Web", "Doppler", "Marble Fade", "Tiger Tooth", "Blue Steel",
	"Rust Coat", "Night", "Ultraviolet", "Asiimov", "Hyper Beast", "Redline",
	"Vulcan", "Fire Serpent", "Dragon Lore", "Printstream", "Neo-Noir",
	"Wild Lotus", "Emerald", "Sapphire", "Ruby", "Black Pearl",
	"Gamma Doppler", "Lore", "Boreal Forest", "Scarlet", "Midnight",
}
local SKIN_PRESETS = {
	["Gold"]        = { Material = "Metal",   Color = Color3.fromRGB(255, 202, 84),  Reflectance = 0.35 },
	["Neon Purple"] = { Material = "Neon",    Color = Color3.fromRGB(168, 96, 255) },
	["Neon Blue"]   = { Material = "Neon",    Color = Color3.fromRGB(70, 170, 255) },
	["Neon Green"]  = { Material = "Neon",    Color = Color3.fromRGB(80, 255, 150) },
	["Galaxy"]      = { Material = "Glass",   Color = Color3.fromRGB(96, 70, 200),  Reflectance = 0.45 },
	["Frost"]       = { Material = "Ice",     Color = Color3.fromRGB(180, 230, 255), Reflectance = 0.3 },
	["Chrome"]      = { Material = "Metal",   Color = Color3.fromRGB(225, 228, 240), Reflectance = 0.6 },
	["Carbon"]      = { Material = "Metal",   Color = Color3.fromRGB(28, 28, 32),   Reflectance = 0.2 },
	["Blood Red"]   = { Material = "SmoothPlastic", Color = Color3.fromRGB(190, 30, 45) },
	["Toxic"]       = { Material = "Neon",    Color = Color3.fromRGB(190, 255, 60) },
	["Obsidian"]    = { Material = "Glass",   Color = Color3.fromRGB(12, 12, 16),   Reflectance = 0.4 },
	["Sand"]        = { Material = "Sand",    Color = Color3.fromRGB(214, 188, 140) },
	["Marble"]      = { Material = "Marble",  Color = Color3.fromRGB(240, 240, 245) },
	["Granite"]     = { Material = "Granite", Color = Color3.fromRGB(90, 90, 96) },
	["Rainbow"]     = { Rainbow = true },
	["Factory New"] = { Material = "SmoothPlastic", Color = Color3.fromRGB(245, 245, 250) },
}

--=====================================================================
-- 7. SKYBOX / VISUAL PRESETS
--=====================================================================
local SKY_PRESETS = {
	["Game Default"] = "default",
	["Deep Space"] = {
		Up = "rbxassetid://159454299", Dn = "rbxassetid://159454296",
		Lf = "rbxassetid://159454293", Rt = "rbxassetid://159454290",
		Ft = "rbxassetid://159454287", Bk = "rbxassetid://159454311",
	},
	["Nebula"] = {
		Up = "rbxassetid://10799413050", Dn = "rbxassetid://10799413050",
		Lf = "rbxassetid://10799413050", Rt = "rbxassetid://10799413050",
		Ft = "rbxassetid://10799413050", Bk = "rbxassetid://10799413050",
	},
	["Night Sky"] = {
		Up = "rbxassetid://10258337305", Dn = "rbxassetid://10258337305",
		Lf = "rbxassetid://10258337305", Rt = "rbxassetid://10258337305",
		Ft = "rbxassetid://10258337305", Bk = "rbxassetid://10258337305",
	},
	["Sky Blue"] = {
		Up = "rbxassetid://150553469", Dn = "rbxassetid://150553469",
		Lf = "rbxassetid://150553469", Rt = "rbxassetid://150553469",
		Ft = "rbxassetid://150553469", Bk = "rbxassetid://150553469",
	},
}

--=====================================================================
-- 8. ESP MODULE
--=====================================================================
local ESP = {
	Enabled = false, Boxes = true, Chams = true, Names = true, Health = true,
	Distance = true, Weapon = true, Tracers = false, TeamCheck = true,
	MaxDistance = 1200, UseTeamColor = true, Color = Color3.fromRGB(255, 255, 255),
	Thickness = 1, FillAlpha = 0.25,
	Objects = {},
}

local hasDrawing = false
do
	local ok = pcall(function()
		local s = Drawing.new("Square")
		s:Remove()
	end)
	hasDrawing = ok
end
ESP.HasDrawing = hasDrawing

local function espColorFor(plr)
	if ESP.UseTeamColor and plr.TeamColor then
		return plr.TeamColor.Color
	end
	return ESP.Color
end

local function createESP(plr)
	local char = plr.Character
	if not char then return end
	local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not head or not hum then return end

	local data = { Player = plr, Character = char }

	--// CHAMS
	local hl = New("Highlight", {
		Name = "SleepChams", Adornee = char,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		FillTransparency = 1, OutlineTransparency = 0,
		FillColor = espColorFor(plr), OutlineColor = espColorFor(plr),
	}, char)
	data.Highlight = hl

	--// NAMETAG
	local bb = New("BillboardGui", {
		Name = "SleepESP", Adornee = head,
		Size = UDim2.fromOffset(190, 60),
		StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0),
		AlwaysOnTop = true, LightInfluence = 0, MaxDistance = math.huge,
	}, head)
	data.Billboard = bb

	local nameLbl = New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold, TextSize = 13, Text = plr.Name,
		TextColor3 = espColorFor(plr), TextStrokeTransparency = 0.4,
		TextStrokeColor3 = Color3.new(0, 0, 0),
	}, bb)
	data.Name = nameLbl

	local infoLbl = New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, 16),
		BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11,
		Text = "", TextColor3 = Theme.Sub, TextStrokeTransparency = 0.5,
		TextStrokeColor3 = Color3.new(0, 0, 0),
	}, bb)
	data.Info = infoLbl

	local barBg = New("Frame", {
		Size = UDim2.new(0, 90, 0, 5), Position = UDim2.new(0.5, 0, 0, 32),
		AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromRGB(20, 20, 20),
		BackgroundTransparency = 0.35, BorderSizePixel = 0,
	}, bb)
	Corner(barBg, 3)
	local barFill = New("Frame", {
		Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Theme.Good,
		BorderSizePixel = 0,
	}, barBg)
	Corner(barFill, 3)
	data.HealthBar = barFill

	--// DRAWINGS
	if hasDrawing then
		data.Box = Drawing.new("Square")
		data.Box.Thickness = ESP.Thickness
		data.Box.Filled = false
		data.Box.Transparency = 1
		data.Box.Visible = false

		data.Fill = Drawing.new("Square")
		data.Fill.Filled = true
		data.Fill.Transparency = ESP.FillAlpha
		data.Fill.Visible = false

		data.Tracer = Drawing.new("Line")
		data.Tracer.Thickness = 1
		data.Tracer.Transparency = 1
		data.Tracer.Visible = false
	end

	ESP.Objects[plr] = data
end

local function removeESP(plr)
	local data = ESP.Objects[plr]
	if not data then return end
	for _, k in ipairs({ "Highlight", "Billboard" }) do
		if data[k] and data[k].Parent then data[k]:Destroy() end
	end
	if hasDrawing then
		for _, k in ipairs({ "Box", "Fill", "Tracer" }) do
			if data[k] then pcall(function() data[k]:Remove() end) end
		end
	end
	ESP.Objects[plr] = nil
end

local function refreshESP()
	for plr, data in pairs(ESP.Objects) do
		if plr.Parent == nil or data.Character ~= plr.Character then
			removeESP(plr)
		end
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and plr.Character and not ESP.Objects[plr] then
			createESP(plr)
		end
	end
end

local function updateESP()
	if not ESP.Enabled then
		for _, data in pairs(ESP.Objects) do
			if data.Highlight then data.Highlight.FillTransparency = 1; data.Highlight.OutlineTransparency = 1 end
			if data.Billboard then data.Billboard.Enabled = false end
			if data.Box then data.Box.Visible = false end
			if data.Fill then data.Fill.Visible = false end
			if data.Tracer then data.Tracer.Visible = false end
		end
		return
	end

	local myPos = Camera.CFrame.Position
	local vpSize = Camera.ViewportSize
	local myTeam = LocalPlayer.Team

	for plr, data in pairs(ESP.Objects) do
		local char = data.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local head = char and char:FindFirstChild("Head")
		local valid = hum and hrp and head and hum.Health > 0

		local skip = false
		if valid and ESP.TeamCheck and myTeam and plr.Team and plr.Team == myTeam then
			skip = true
		end

		if not valid or skip then
			if data.Highlight then
				data.Highlight.FillTransparency = 1
				data.Highlight.OutlineTransparency = 1
			end
			if data.Billboard then data.Billboard.Enabled = false end
			if data.Box then data.Box.Visible = false end
			if data.Fill then data.Fill.Visible = false end
			if data.Tracer then data.Tracer.Visible = false end
			continue
		end

		local dist = (hrp.Position - myPos).Magnitude
		local col = espColorFor(plr)
		local inRange = dist <= ESP.MaxDistance

		--// CHAMS
		if data.Highlight then
			data.Highlight.FillColor = col
			data.Highlight.OutlineColor = col
			data.Highlight.FillTransparency = (ESP.Chams and inRange) and (1 - ESP.FillAlpha) or 1
			data.Highlight.OutlineTransparency = (ESP.Chams and inRange) and 0 or 1
		end

		--// BILLBOARD
		if data.Billboard then
			local show = inRange and (ESP.Names or ESP.Health or ESP.Distance or ESP.Weapon)
			data.Billboard.Enabled = show
			if show then
				data.Name.Visible = ESP.Names
				data.Name.TextColor3 = col
				data.HealthBar.Parent.Visible = ESP.Health
				local hp = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
				data.HealthBar.Size = UDim2.new(hp, 0, 1, 0)
				data.HealthBar.BackgroundColor3 = Color3.fromRGB(
					math.floor(255 * (1 - hp)), math.floor(255 * hp), 60
				)
				local parts = {}
				if ESP.Distance then parts[#parts + 1] = ("%dm"):format(math.floor(dist)) end
				if ESP.Weapon then
					local w = char:FindFirstChildOfClass("Tool")
					local attr = plr:GetAttribute("Weapon") or plr:GetAttribute("CurrentWeapon")
						or char:GetAttribute("Weapon")
					parts[#parts + 1] = w and w.Name or (attr and tostring(attr)) or "-"
				end
				data.Info.Visible = #parts > 0
				data.Info.Text = table.concat(parts, "  •  ")
			end
		end

		--// 2D BOX
		if hasDrawing and data.Box then
			local want = inRange and ESP.Boxes
			if want then
				local cf, size = char:GetBoundingBox()
				local topW    = (cf * CFrame.new(0, size.Y / 2, 0)).Position
				local bottomW = (cf * CFrame.new(0, -size.Y / 2, 0)).Position
				local rightW  = (cf * CFrame.new(size.X / 2, 0, 0)).Position
				local leftW   = (cf * CFrame.new(-size.X / 2, 0, 0)).Position

				local t2, tOn = Camera:WorldToViewportPoint(topW)
				local b2, bOn = Camera:WorldToViewportPoint(bottomW)
				local r2      = Camera:WorldToViewportPoint(rightW)
				local l2      = Camera:WorldToViewportPoint(leftW)

				if tOn or bOn then
					local x1 = math.min(l2.X, r2.X)
					local x2 = math.max(l2.X, r2.X)
					local y1 = math.min(t2.Y, b2.Y)
					local y2 = math.max(t2.Y, b2.Y)
					local w = math.max(x2 - x1, 6)
					local h = math.max(y2 - y1, 6)

					data.Box.Visible = true
					data.Box.Color = col
					data.Box.Thickness = ESP.Thickness
					data.Box.Position = Vector2.new(x1 - 1, y1 - 1)
					data.Box.Size = Vector2.new(w + 2, h + 2)

					data.Fill.Visible = ESP.FillAlpha > 0
					data.Fill.Color = col
					data.Fill.Transparency = ESP.FillAlpha
					data.Fill.Position = Vector2.new(x1, y1)
					data.Fill.Size = Vector2.new(w, h)
				else
					data.Box.Visible = false
					data.Fill.Visible = false
				end
			else
				data.Box.Visible = false
				data.Fill.Visible = false
			end
		end

		--// TRACER
		if hasDrawing and data.Tracer then
			local want = inRange and ESP.Tracers
			if want then
				local hp, on = Camera:WorldToViewportPoint(head.Position)
				if on then
					data.Tracer.Visible = true
					data.Tracer.Color = col
					data.Tracer.From = Vector2.new(vpSize.X / 2, vpSize.Y)
					data.Tracer.To = Vector2.new(hp.X, hp.Y)
				else
					data.Tracer.Visible = false
				end
			else
				data.Tracer.Visible = false
			end
		end
	end
end
ESP.Refresh = refreshESP
ESP.Update = updateESP
ESP.Remove = removeESP

Conn(Players.PlayerAdded, function(p)
	p.CharacterAdded:Connect(function()
		task.wait(0.35)
		removeESP(p)
		if ESP.Enabled then createESP(p) end
	end)
end)
Conn(Players.PlayerRemoving, removeESP)
if LocalPlayer.CharacterAdded then
	Conn(LocalPlayer.CharacterAdded, function()
		task.wait(1)
		refreshESP()
	end)
end
for _, p in ipairs(Players:GetPlayers()) do
	if p ~= LocalPlayer then
		p.CharacterAdded:Connect(function()
			task.wait(0.35)
			removeESP(p)
			if ESP.Enabled then createESP(p) end
		end)
	end
end

--=====================================================================
-- 9. SKIN CHANGER MODULE
--=====================================================================
local Skin = {
	Enabled = false,
	Preset = "Gold",
	Targets = { Knife = true, Gloves = true, Guns = true, Arms = false },
	Glow = false,
	GlowBrightness = 3,
	Particles = false,
	Rainbow = false,
	Hue = 0,
	Tracked = {},
	Originals = {},
}
SleepScript.Skin = Skin

local function isViewModel(inst)
	if not inst:IsA("Model") and not inst:IsA("Folder") then return false end
	local n = inst.Name:lower()
	return n:find("view") or n:find("arm") or n:find("hand")
		or n:find("weapon") or n:find("worldmodel") or n:find("tool")
end

local function classifyPart(part)
	local n = part.Name:lower()
	for _, k in ipairs({ "knife", "karambit", "bayonet", "dagger", "blade" }) do
		if n:find(k) then return "Knife" end
	end
	for _, g in ipairs({ "glove", "wrap", "hand" }) do
		if n:find(g) then return "Gloves" end
	end
	for _, w in ipairs({ "arm", "sleeve" }) do
		if n:find(w) then return "Arms" end
	end
	return "Guns"
end

local function currentPreset()
	if Skin.Rainbow then
		return { Material = "Neon", Color = Color3.fromHSV(Skin.Hue, 0.85, 1) }
	end
	local p = SKIN_PRESETS[Skin.Preset]
	if p and p.Rainbow then
		return { Material = "Neon", Color = Color3.fromHSV(Skin.Hue, 0.85, 1) }
	end
	return p or SKIN_PRESETS["Gold"]
end

local function stylePart(part)
	if not part:IsA("BasePart") then return end
	local kind = classifyPart(part)
	if not Skin.Targets[kind] then
		-- restore original for untargeted
		local orig = Skin.Originals[part]
		if orig then
			part.Material = orig.Material
			part.Color = orig.Color
			part.Reflectance = orig.Reflectance
		end
		return
	end

	if not Skin.Originals[part] then
		Skin.Originals[part] = {
			Material = part.Material, Color = part.Color, Reflectance = part.Reflectance,
		}
	end

	local preset = currentPreset()
	local okMat, mat = pcall(function() return Enum.Material[preset.Material] end)
	if okMat and mat then part.Material = mat end
	if preset.Color then part.Color = preset.Color end
	if preset.Reflectance then part.Reflectance = preset.Reflectance end

	--// GLOW
	if Skin.Glow then
		local light = part:FindFirstChild("SleepGlow")
		if not light then
			light = New("PointLight", {
				Name = "SleepGlow", Range = 10, Brightness = Skin.GlowBrightness,
			}, part)
		end
		light.Color = preset.Color or Color3.new(1, 1, 1)
		light.Brightness = Skin.GlowBrightness
		light.Enabled = true
	else
		local light = part:FindFirstChild("SleepGlow")
		if light then light.Enabled = false end
	end

	--// PARTICLES
	if Skin.Particles then
		local pe = part:FindFirstChild("SleepParticles")
		if not pe then
			pe = New("ParticleEmitter", {
				Name = "SleepParticles", Rate = 12, Lifetime = NumberRange.new(0.3, 0.7),
				Speed = NumberRange.new(0.2, 0.8), Size = NumberSequence.new(0.16),
				LightEmission = 1, LightInfluence = 0,
				Texture = "rbxasset://textures/particles/sparkles_main.dds",
			}, part)
		end
		pe.Color = ColorSequence.new(preset.Color or Color3.new(1, 1, 1))
		pe.Enabled = true
	else
		local pe = part:FindFirstChild("SleepParticles")
		if pe then pe.Enabled = false end
	end
end

local function trackModel(model)
	if Skin.Tracked[model] then return end
	Skin.Tracked[model] = true
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then stylePart(d) end
	end
end

local function scanForViewModels()
	if not Skin.Enabled then return end
	local candidates = {}
	for _, c in ipairs(Camera:GetChildren()) do
		if isViewModel(c) then candidates[#candidates + 1] = c end
	end
	for _, c in ipairs(Workspace:GetChildren()) do
		if isViewModel(c) then candidates[#candidates + 1] = c end
	end
	local char = LocalPlayer.Character
	if char then
		for _, c in ipairs(char:GetChildren()) do
			if c:IsA("Model") and isViewModel(c) then candidates[#candidates + 1] = c end
		end
	end
	for _, m in ipairs(candidates) do trackModel(m) end
end

Conn(Camera.ChildAdded, function(i) if isViewModel(i) then trackModel(i) end end)
Conn(Workspace.ChildAdded, function(i) if isViewModel(i) then trackModel(i) end end)

--=====================================================================
-- 10. MOVEMENT MODULE
--=====================================================================
local Move = {
	Bhop = false, InfJump = false, HoldingSpace = false,
	WalkSpeed = 16, JumpPower = 50, SpeedEnabled = false,
	JumpEnabled = false, Sprint = false, SprintKey = "LeftShift", SprintSpeed = 24,
	Fly = false,
}
SleepScript.Move = Move

local function getHum()
	local char = LocalPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

Conn(UserInputService.InputBegan, function(i, gp)
	if i.KeyCode == Enum.KeyCode.Space then Move.HoldingSpace = true end
	if i.KeyCode.Name == Move.SprintKey then Move.Sprinting = true end
end)
Conn(UserInputService.InputEnded, function(i)
	if i.KeyCode == Enum.KeyCode.Space then Move.HoldingSpace = false end
	if i.KeyCode.Name == Move.SprintKey then Move.Sprinting = false end
end)

local bhopCooldown = 0
Conn(RunService.RenderStepped, function(dt)
	local hum = getHum()
	if not hum then return end

	if Move.Bhop and Move.HoldingSpace then
		local grounded = hum.FloorMaterial ~= Enum.Material.Air
			and hum:GetState() ~= Enum.HumanoidStateType.Jumping
			and hum:GetState() ~= Enum.HumanoidStateType.Freefall
		if grounded and os.clock() >= bhopCooldown then
			hum.Jump = true
			bhopCooldown = os.clock() + 0.03
		end
	end

	if Move.InfJump and Move.HoldingSpace then
		if hum:GetState() == Enum.HumanoidStateType.Freefall then
			hum.Jump = true
		end
	end

	if Move.SpeedEnabled then
		local target = Move.WalkSpeed
		if Move.Sprint and Move.Sprinting then target = Move.SprintSpeed end
		if math.abs(hum.WalkSpeed - target) > 0.1 then hum.WalkSpeed = target end
	end
	if Move.JumpEnabled and math.abs(hum.JumpPower - Move.JumpPower) > 0.1 then
		hum.JumpPower = Move.JumpPower
	end
end)

--// FLY
local flyBV, flyBG
local function stopFly()
	local char = LocalPlayer.Character
	if flyBV then flyBV:Destroy(); flyBV = nil end
	if flyBG then flyBG:Destroy(); flyBG = nil end
	if char then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then hrp.Velocity = Vector3.new(0, 0, 0) end
	end
end

Conn(RunService.RenderStepped, function(dt)
	if not Move.Fly then return end
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return end

	if not flyBV then
		flyBV = New("BodyVelocity", {
			Name = "SleepFly", MaxForce = Vector3.new(1, 1, 1) * 1e5, P = 1250,
			Velocity = Vector3.new(0, 0, 0),
		}, hrp)
		flyBG = New("BodyGyro", {
			Name = "SleepFlyGyro", MaxTorque = Vector3.new(1, 1, 1) * 1e5,
			P = 1000, D = 50, CFrame = hrp.CFrame,
		}, hrp)
	end

	local speed = 60 * (Move.Sprinting and 2 or 1)
	local dir = Vector3.new(0, 0, 0)
	local camCF = Camera.CFrame
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += camCF.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= camCF.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= camCF.RightVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += camCF.RightVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0, 1, 0) end
	if dir.Magnitude > 0 then dir = dir.Unit end

	flyBV.Velocity = dir * speed
	flyBG.CFrame = camCF
end)
Move.StopFly = stopFly

--=====================================================================
-- 11. AIM ASSIST
--=====================================================================
local Aim = {
	Enabled = false, FOV = 90, Smoothing = 8, TeamCheck = true,
	Part = "Head", Holding = false, Visible = false,
}
SleepScript.Aim = Aim

Conn(UserInputService.InputBegan, function(i, gp)
	if i.UserInputType == Enum.UserInputType.MouseButton2 then Aim.Holding = true end
end)
Conn(UserInputService.InputEnded, function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton2 then Aim.Holding = false end
end)

local function closestTarget()
	local best, bestAngle = nil, Aim.FOV
	local camPos = Camera.CFrame.Position
	local look = Camera.CFrame.LookVector
	local myTeam = LocalPlayer.Team

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and IsAlive(plr) then
			if not (Aim.TeamCheck and myTeam and plr.Team == myTeam) then
				local char = plr.Character
				local part = char:FindFirstChild(Aim.Part) or char:FindFirstChild("Head")
				if part then
					local delta = part.Position - camPos
					local angle = math.deg(math.acos(math.clamp(look:Dot(delta.Unit), -1, 1)))
					if angle < bestAngle then
						if Aim.Visible then
							local params = RaycastParams.new()
							params.FilterDescendantsInstances = { LocalPlayer.Character }
							params.FilterType = Enum.RaycastFilterType.Exclude
							local hit = Workspace:Raycast(camPos, delta, params)
							if hit and not hit.Instance:IsDescendantOf(char) then continue end
						end
						best, bestAngle = part, angle
					end
				end
			end
		end
	end
	return best
end

RunService:BindToRenderStep("SleepAim", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if not Aim.Enabled or not Aim.Holding then return end
	local target = closestTarget()
	if not target then return end
	local camPos = Camera.CFrame.Position
	local goal = CFrame.lookAt(camPos, target.Position)
	local a = 1 - math.exp(-Aim.Smoothing * dt)
	Camera.CFrame = Camera.CFrame:Lerp(goal, a)
end)

--=====================================================================
-- 12. VISUALS (SKY / LIGHTING / PARTICLES)
--=====================================================================
local Vis = {
	CustomSky = false, SkyPreset = "Deep Space",
	Atmosphere = false, Bloom = false, Fullbright = false,
	Aura = false, WeaponGlow = false, TimeOfDay = 14,
	SkyInstance = nil, AuraEmitter = nil,
}
SleepScript.Vis = Vis

local SkyBackup = {}

local function applySky(presetName)
	if Vis.SkyInstance then
		Vis.SkyInstance:Destroy()
		Vis.SkyInstance = nil
	end
	if presetName == "Game Default" then return end
	local p = SKY_PRESETS[presetName]
	if type(p) ~= "table" then return end
	Vis.SkyInstance = New("Sky", {
		Name = "SleepSky",
		SkyboxUp = p.Up, SkyboxDn = p.Dn, SkyboxLf = p.Lf,
		SkyboxRt = p.Rt, SkyboxFt = p.Ft, SkyboxBk = p.Bk,
		StarCount = 5000, CelestialBodiesShown = true,
	}, Lighting)
end

function Vis.SetSkyPreset(name)
	Vis.SkyPreset = name
	if Vis.CustomSky then applySky(name) end
end

function Vis.SetCustomSky(id)
	if Vis.SkyInstance then Vis.SkyInstance:Destroy() end
	local u = "rbxassetid://" .. tostring(id):gsub("%D", "")
	Vis.SkyInstance = New("Sky", {
		Name = "SleepSky", SkyboxUp = u, SkyboxDn = u, SkyboxLf = u,
		SkyboxRt = u, SkyboxFt = u, SkyboxBk = u, StarCount = 5000,
	}, Lighting)
end

local function setFullbright(on)
	if on then
		SkyBackup.Ambient = Lighting.Ambient
		SkyBackup.OutdoorAmbient = Lighting.OutdoorAmbient
		SkyBackup.Brightness = Lighting.Brightness
		SkyBackup.ClockTime = Lighting.ClockTime
		Lighting.Ambient = Color3.fromRGB(180, 180, 180)
		Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.GlobalShadows = false
	else
		for k, v in pairs(SkyBackup) do Lighting[k] = v end
	end
end

local function setAura(on)
	local char = LocalPlayer.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	if on then
		if not Vis.AuraEmitter or not Vis.AuraEmitter.Parent then
			Vis.AuraEmitter = New("ParticleEmitter", {
				Name = "SleepAura", Rate = 30, Lifetime = NumberRange.new(0.6, 1.2),
				Speed = NumberRange.new(1, 3), Size = NumberSequence.new(0.3),
				LightEmission = 1, LightInfluence = 0, Rotation = NumberRange.new(0, 360),
				Texture = "rbxasset://textures/particles/sparkles_main.dds",
				Color = ColorSequence.new(Theme.Accent),
			}, hrp)
		end
		Vis.AuraEmitter.Enabled = true
	else
		if Vis.AuraEmitter then Vis.AuraEmitter.Enabled = false end
	end
end

local function setWeaponGlow(on)
	Skin.Glow = on
	scanForViewModels()
end

--=====================================================================
-- 13. OVERLAY (PING / FPS / MEMORY)
--=====================================================================
local Overlay = { Visible = true, FPS = 0, Ping = 0, Mem = 0 }
SleepScript.Overlay = Overlay

local OverlayGui = New("ScreenGui", {
	Name = "SleepOverlay", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 950,
}, GuiParent())
SleepScript.Objects[#SleepScript.Objects + 1] = OverlayGui

local oFrame = New("Frame", {
	Size = UDim2.fromOffset(168, 76), Position = UDim2.new(0, 14, 0, 14),
	BackgroundColor3 = Theme.Bg, BackgroundTransparency = 0.15,
	BorderSizePixel = 0, Visible = true,
}, OverlayGui)
Corner(oFrame, 10)
Stroke(oFrame, Theme.Stroke, 1, 0.55)
Pad(oFrame, 8, 10, 8, 10)

local oTitle = New("TextLabel", {
	Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold, TextSize = 11, Text = "SleepScript  •  stats",
	TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left,
}, oFrame)
RegisterAccent(oTitle, "TextColor3")

local function statRow(name, y)
	New("TextLabel", {
		Size = UDim2.new(0.5, 0, 0, 14), Position = UDim2.new(0, 0, 0, y),
		BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11,
		Text = name, TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Left,
	}, oFrame)
	return New("TextLabel", {
		Size = UDim2.new(0.5, 0, 0, 14), Position = UDim2.new(0.5, 0, 0, y),
		BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 11,
		Text = "0", TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Right,
	}, oFrame)
end

local fpsLbl = statRow("FPS", 18)
local pingLbl = statRow("PING", 34)
local memLbl = statRow("MEM", 50)

--// DRAG
do
	local dragging, ds, sp = false, nil, nil
	oFrame.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1
			or i.UserInputType == Enum.UserInputType.Touch then
			dragging, ds, sp = true, i.Position, oFrame.Position
		end
	end)
	Conn(UserInputService.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1
			or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
	Conn(UserInputService.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
			or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - ds
			oFrame.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
		end
	end)
end

--// STATS LOOP
do
	local frames, accum, last = 0, 0, os.clock()
	Conn(RunService.RenderStepped, function()
		frames = frames + 1
		local now = os.clock()
		if now - last >= 1 then
			Overlay.FPS = frames / (now - last)
			frames, last = 0, now
		end
	end)

	task.spawn(function()
		while not SleepScript.Unloaded do
			local ok, ping = pcall(function() return LocalPlayer:GetNetworkPing() * 1000 end)
			if not ok or not ping or ping <= 0 then
				ok, ping = pcall(function()
					return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
				end)
			end
			Overlay.Ping = ok and ping or 0
			local ok2, mem = pcall(function() return Stats:GetTotalMemoryUsageMb() end)
			Overlay.Mem = ok2 and mem or 0

			fpsLbl.Text = string.format("%d", math.floor(Overlay.FPS + 0.5))
			fpsLbl.TextColor3 = Overlay.FPS >= 50 and Theme.Good
				or (Overlay.FPS >= 30 and Theme.Warn or Theme.Bad)
			pingLbl.Text = string.format("%d ms", math.floor(Overlay.Ping + 0.5))
			pingLbl.TextColor3 = Overlay.Ping <= 80 and Theme.Good
				or (Overlay.Ping <= 160 and Theme.Warn or Theme.Bad)
			memLbl.Text = string.format("%d MB", math.floor(Overlay.Mem))
			task.wait(0.5)
		end
	end)
end

function Overlay:Toggle(state)
	self.Visible = state
	oFrame.Visible = state
end

--=====================================================================
-- 14. FPS BOOST
--=====================================================================
local Boost = { Enabled = false }
SleepScript.Boost = Boost

local function applyBoost(on)
	local L = Lighting
	if on then
		Boost.Backup = {
			GlobalShadows = L.GlobalShadows,
			FogEnd = L.FogEnd,
			EnvironmentDiffuseScale = L.EnvironmentDiffuseScale,
			EnvironmentSpecularScale = L.EnvironmentSpecularScale,
			QualityLevel = (function()
				local ok, v = pcall(function() return settings().Rendering.QualityLevel end)
				return ok and v or nil
			end)(),
			TerrainDecoration = Workspace.Terrain.Decoration,
			WaterWaveSize = Workspace.Terrain.WaterWaveSize,
			WaterWaveSpeed = Workspace.Terrain.WaterWaveSpeed,
			WaterReflectance = Workspace.Terrain.WaterReflectance,
			WaterTransparency = Workspace.Terrain.WaterTransparency,
		}

		L.GlobalShadows = false
		L.EnvironmentDiffuseScale = 0
		L.EnvironmentSpecularScale = 0
		Workspace.Terrain.Decoration = false
		Workspace.Terrain.WaterWaveSize = 0
		Workspace.Terrain.WaterWaveSpeed = 0
		Workspace.Terrain.WaterReflectance = 0
		Workspace.Terrain.WaterTransparency = 1

		pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
		pcall(function() settings().Rendering.MeshPartDetail = Enum.MeshDetailLevel.Level01 end)
		pcall(function() settings().Rendering.AnimationController = 0 end)

		--// disable heavy post effects
		for _, e in ipairs(L:GetChildren()) do
			if e:IsA("PostEffect") or e:IsA("BloomEffect")
				or e:IsA("BlurEffect") or e:IsA("SunRaysEffect")
				or e:IsA("DepthOfFieldEffect") then
				if not e:GetAttribute("SleepKeep") then
					e:SetAttribute("SleepWasEnabled", e.Enabled)
					e.Enabled = false
				end
			end
		end
		Boost.PostDisabled = true
	else
		local b = Boost.Backup
		if b then
			L.GlobalShadows = b.GlobalShadows
			L.FogEnd = b.FogEnd
			L.EnvironmentDiffuseScale = b.EnvironmentDiffuseScale
			L.EnvironmentSpecularScale = b.EnvironmentSpecularScale
			Workspace.Terrain.Decoration = b.TerrainDecoration
			Workspace.Terrain.WaterWaveSize = b.WaterWaveSize
			Workspace.Terrain.WaterWaveSpeed = b.WaterWaveSpeed
			Workspace.Terrain.WaterReflectance = b.WaterReflectance
			Workspace.Terrain.WaterTransparency = b.WaterTransparency
			if b.QualityLevel then
				pcall(function() settings().Rendering.QualityLevel = b.QualityLevel end)
			end
		end
		for _, e in ipairs(L:GetChildren()) do
			if e:GetAttribute("SleepWasEnabled") ~= nil then
				e.Enabled = e:GetAttribute("SleepWasEnabled")
				e:SetAttribute("SleepWasEnabled", nil)
			end
		end
	end
end

--=====================================================================
-- 15. ANTICHEAT BYPASS / PROTECTION
--=====================================================================
local Bypass = {
	AntiKick = false, AntiVoid = false, AntiAfk = false, AntiRevert = false,
	SafeMode = true,
}
SleepScript.Bypass = Bypass

--// ANTI KICK (namecall hook)
local function installAntiKick()
	local ok = pcall(function()
		local mt = getrawmetatable(game)
		if not mt or mt.__namecall == nil then error("no metatable") end
		setreadonly(mt, false)
		local old = mt.__namecall
		mt.__namecall = newcclosure(function(self, ...)
			local method = getnamecallmethod()
			if method == "Kick" and self == LocalPlayer and Bypass.AntiKick then
				local args = { ... }
				Notify("Anti-Kick", tostring(args[1] or "kicked"), 4)
				return nil
			end
			return old(self, ...)
		end)
		setreadonly(mt, true)
	end)
	if not ok then
		Notify("Hook", "namecall hook unavailable", 3)
	end
end

--// ANTI VOID
local lastSafe = nil
Conn(RunService.Heartbeat, function()
	if not Bypass.AntiVoid then return end
	local hrp = GetHRP(LocalPlayer)
	if not hrp then return end
	if hrp.Position.Y > -50 then
		lastSafe = hrp.CFrame
	elseif lastSafe then
		hrp.CFrame = lastSafe + Vector3.new(0, 8, 0)
		hrp.Velocity = Vector3.new(0, 0, 0)
	end
end)

--// ANTI AFK
Conn(LocalPlayer.Idled, function()
	if not Bypass.AntiAfk then return end
	VirtualUser:Button2Down(Vector2.new(0, 0), Camera.CFrame)
	task.wait(1)
	VirtualUser:Button2Up(Vector2.new(0, 0), Camera.CFrame)
end)

--// ANTI REVERT (re-apply local-only changes)
task.spawn(function()
	while not SleepScript.Unloaded do
		if Bypass.AntiRevert then
			local hum = getHum()
			if hum and Move.SpeedEnabled and math.abs(hum.WalkSpeed - Move.WalkSpeed) > 0.1 then
				hum.WalkSpeed = Move.WalkSpeed
			end
			if Aim.Enabled and Camera then
				-- keep our FOV if the game fights it
			end
		end
		task.wait(0.35)
	end
end)

--=====================================================================
-- 16. MISC HELPERS
--=====================================================================
local function deepScan()
	print("===== SleepScript :: Deep Scan =====")
	print("[Weapons in ReplicatedStorage]")
	local foundW, foundS, foundR = {}, {}, {}
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
		local n = d.Name:lower()
		if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
			if n:find("skin") or n:find("equip") or n:find("apply")
				or n:find("inventory") or n:find("loadout") then
				foundR[#foundR + 1] = d:GetFullName() .. " [" .. d.ClassName .. "]"
			end
		end
		if d:IsA("Model") and (n:find("knife") or n:find("glove") or n:find("gun")
			or n:find("weapon") or n:find("ak") or n:find("m4") or n:find("awp")) then
			foundW[#foundW + 1] = d:GetFullName()
		end
		if (d:IsA("Decal") or d:IsA("Texture") or d:IsA("StringValue"))
			and (n:find("skin") or n:find("camo") or n:find("finish")) then
			foundS[#foundS + 1] = d:GetFullName()
		end
	end
	for _, v in ipairs(foundR) do print("  REMOTE >", v) end
	for _, v in ipairs(foundW) do print("  MODEL  >", v) end
	for _, v in ipairs(foundS) do print("  SKIN   >", v) end
	print("===== End =====")
	Notify("Deep Scan", #foundR .. " remotes / " .. #foundW .. " models found", 4)
end

local function fireSkinRemotes()
	local fired = 0
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
		if d:IsA("RemoteEvent") and (d.Name:lower():find("skin")
			or d.Name:lower():find("equip")) then
			pcall(function() d:FireServer(Skin.Preset) end)
			fired = fired + 1
		end
	end
	Notify("Skin Remote", "fired on " .. fired .. " remotes", 3)
end

--=====================================================================
-- 17. CONFIG
--=====================================================================
local ConfigName = "SleepScript_BloxStrike.json"

local function saveConfig()
	local data = {
		ESP = { Enabled = ESP.Enabled, Boxes = ESP.Boxes, Chams = ESP.Chams,
			Names = ESP.Names, Health = ESP.Health, Distance = ESP.Distance,
			Tracers = ESP.Tracers, TeamCheck = ESP.TeamCheck, MaxDistance = ESP.MaxDistance },
		Skin = { Enabled = Skin.Enabled, Preset = Skin.Preset, Glow = Skin.Glow },
		Move = { Bhop = Move.Bhop, InfJump = Move.InfJump, WalkSpeed = Move.WalkSpeed },
		Aim = { Enabled = Aim.Enabled, FOV = Aim.FOV, Smoothing = Aim.Smoothing },
	}
	local ok = pcall(function()
		writefile(ConfigName, HttpService:JSONEncode(data))
	end)
	if ok then Notify("Config", "saved", 2) else Notify("Config", "writefile unavailable", 2) end
end

local function loadConfig()
	if not (isfile and isfile(ConfigName)) then
		Notify("Config", "no config found", 2)
		return
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(readfile(ConfigName))
	end)
	if not ok then Notify("Config", "read error", 2) return end
	if decoded.ESP then
		ESP.Boxes = decoded.ESP.Boxes ~= false
		ESP.Chams = decoded.ESP.Chams ~= false
		ESP.Names = decoded.ESP.Names ~= false
		ESP.Health = decoded.ESP.Health ~= false
		ESP.Distance = decoded.ESP.Distance ~= false
		ESP.Tracers = decoded.ESP.Tracers or false
		ESP.MaxDistance = decoded.ESP.MaxDistance or 1200
		if decoded.ESP.Enabled then ESP.Enabled = true; refreshESP() end
	end
	if decoded.Skin then
		Skin.Preset = decoded.Skin.Preset or Skin.Preset
		Skin.Glow = decoded.Skin.Glow or false
		if decoded.Skin.Enabled then Skin.Enabled = true; scanForViewModels() end
	end
	if decoded.Move then
		Move.Bhop = decoded.Move.Bhop or false
		Move.WalkSpeed = decoded.Move.WalkSpeed or 16
	end
	Notify("Config", "loaded", 2)
end

--=====================================================================
-- 18. BUILD MENU
--=====================================================================
local Window = Lib:Window({
	Title = "SleepScript",
	Subtitle = "bloxstrike edition  •  v" .. SleepScript.Version,
})

local Tabs = {
	Combat   = Window.MakeTab("Combat", "◆"),
	Visuals  = Window.MakeTab("Visuals", "◈"),
	Skin     = Window.MakeTab("SkinChanger", "✦"),
	Movement = Window.MakeTab("Movement", "➤"),
	Misc     = Window.MakeTab("Misc / Perf", "⚙"),
	Settings = Window.MakeTab("Settings", "✱"),
}

--// -------- COMBAT --------
do
	local t = Tabs.Combat.Content
	Section(t, "Aim Assist")
	Toggle(t, { Text = "Enable Aim Assist", Default = false, Flag = "AimEnabled",
		Callback = function(v) Aim.Enabled = v end })
	Keybind(t, { Text = "Aim Key", Default = "MouseButton2",
		Callback = function(k)
			if k == "MouseButton2" then
				Aim.HoldMode = "mouse2"
			end
		end })
	Slider(t, { Text = "FOV", Min = 10, Max = 360, Default = 90, Suffix = "°",
		Callback = function(v) Aim.FOV = v end })
	Slider(t, { Text = "Smoothing", Min = 1, Max = 30, Default = 8, Decimals = 1,
		Callback = function(v) Aim.Smoothing = v end })
	Dropdown(t, { Text = "Target Part", Options = { "Head", "HumanoidRootPart", "UpperTorso" },
		Default = "Head", Callback = function(v) Aim.Part = v end })
	Toggle(t, { Text = "Team Check", Default = true, Callback = function(v) Aim.TeamCheck = v end })
	Toggle(t, { Text = "Visible Check (wall check)", Default = false,
		Callback = function(v) Aim.Visible = v end })

	Section(t, "Extras")
	Toggle(t, { Text = "Hitbox Info (console scan)", Default = false,
		Callback = function() deepScan() end })
end

--// -------- VISUALS --------
do
	local t = Tabs.Visuals.Content
	Section(t, "ESP / Wallhack")
	Toggle(t, { Text = "Enable ESP", Default = false, Flag = "ESPEnabled",
		Callback = function(v)
			ESP.Enabled = v
			if v then refreshESP() end
		end })
	Toggle(t, { Text = "2D Boxes" .. (hasDrawing and "" or " (no Drawing)"),
		Default = true, Callback = function(v) ESP.Boxes = v end })
	Toggle(t, { Text = "Chams (highlight)", Default = true,
		Callback = function(v) ESP.Chams = v end })
	Toggle(t, { Text = "Names", Default = true, Callback = function(v) ESP.Names = v end })
	Toggle(t, { Text = "Health Bar", Default = true, Callback = function(v) ESP.Health = v end })
	Toggle(t, { Text = "Distance", Default = true, Callback = function(v) ESP.Distance = v end })
	Toggle(t, { Text = "Weapon", Default = true, Callback = function(v) ESP.Weapon = v end })
	Toggle(t, { Text = "Tracers", Default = false, Callback = function(v) ESP.Tracers = v end })
	Toggle(t, { Text = "Team Check", Default = true, Callback = function(v) ESP.TeamCheck = v end })
	Toggle(t, { Text = "Team Colors", Default = true, Callback = function(v) ESP.UseTeamColor = v end })
	Slider(t, { Text = "Max Distance", Min = 100, Max = 3000, Default = 1200,
		Callback = function(v) ESP.MaxDistance = v end })
	Slider(t, { Text = "Fill Alpha", Min = 0, Max = 1, Default = 0.25, Decimals = 2,
		Callback = function(v) ESP.FillAlpha = v end })
	ColorPicker(t, { Text = "ESP Color", Default = Color3.fromRGB(255, 255, 255),
		Callback = function(c) ESP.Color = c end })

	Section(t, "World / Sky")
	Toggle(t, { Text = "Custom Sky", Default = false,
		Callback = function(v) Vis.CustomSky = v; if v then applySky(Vis.SkyPreset) else applySky("Game Default") end end })
	Dropdown(t, { Text = "Sky Preset", Options = (function()
			local o = {}
			for k in pairs(SKY_PRESETS) do o[#o + 1] = k end
			table.sort(o)
			return o
		end)(), Default = "Deep Space",
		Callback = function(v) Vis.SetSkyPreset(v) end })
	Button(t, { Text = "Apply Custom Sky ID (from clipboard)", Callback = function()
		local ok, clip = pcall(function() return getclipboard() end)
		if ok and clip and clip ~= "" then
			Vis.SetCustomSky(clip)
			Notify("Sky", "applied ID: " .. clip, 3)
		else
			Notify("Sky", "clipboard empty", 3)
		end
	end })
	Toggle(t, { Text = "Atmosphere (haze)", Default = false, Callback = function(v)
		if v then
			if not Vis.Atm then
				Vis.Atm = New("Atmosphere", { Density = 0.35, Haze = 1.5, Glare = 0.2,
					Color = Color3.fromRGB(180, 190, 220) }, Lighting)
			end
			Vis.Atm.Parent = Lighting
		elseif Vis.Atm then
			Vis.Atm.Parent = nil
		end
	end })
	Toggle(t, { Text = "Bloom", Default = false, Callback = function(v)
		if v then
			if not Vis.BloomFx then
				Vis.BloomFx = New("BloomEffect", { Intensity = 1.2, Size = 24,
					Threshold = 0.9 }, Lighting)
			end
			Vis.BloomFx.Enabled = true
		elseif Vis.BloomFx then
			Vis.BloomFx.Enabled = false
		end
	end })
	Toggle(t, { Text = "Fullbright", Default = false, Callback = setFullbright })
	Slider(t, { Text = "Time Of Day", Min = 0, Max = 24, Default = 14,
		Callback = function(v) Lighting.ClockTime = v end })

	Section(t, "Effects")
	Toggle(t, { Text = "Player Aura Particles", Default = false, Callback = function(v)
		setAura(v)
		if v and LocalPlayer.CharacterAdded then
			LocalPlayer.CharacterAdded:Connect(function()
				task.wait(1); setAura(true)
			end)
		end
	end })
	Toggle(t, { Text = "Weapon Glow + Particles", Default = false, Callback = setWeaponGlow })
	Slider(t, { Text = "Glow Brightness", Min = 1, Max = 10, Default = 3,
		Callback = function(v) Skin.GlowBrightness = v; scanForViewModels() end })
end

--// -------- SKIN --------
do
	local t = Tabs.Skin.Content
	Section(t, "Skin Changer (local ViewModel)")
	Toggle(t, { Text = "Enable Skin Changer", Default = false, Flag = "SkinEnabled",
		Callback = function(v)
			Skin.Enabled = v
			if v then scanForViewModels() end
		end })
	Dropdown(t, { Text = "Preset / Finish", Options = (function()
			local o = {}
			for k in pairs(SKIN_PRESETS) do o[#o + 1] = k end
			table.sort(o)
			return o
		end)(), Default = "Gold", Callback = function(v)
		Skin.Preset = v
		Skin.Rainbow = (v == "Rainbow")
		scanForViewModels()
	end })
	Dropdown(t, { Text = "Game Finish (name)", Options = FINISHES, Default = "Vanilla",
		Callback = function(v) Skin.GameFinish = v end })

	Section(t, "Targets")
	Toggle(t, { Text = "Knives", Default = true, Callback = function(v) Skin.Targets.Knife = v; scanForViewModels() end })
	Toggle(t, { Text = "Gloves", Default = true, Callback = function(v) Skin.Targets.Gloves = v; scanForViewModels() end })
	Toggle(t, { Text = "Weapons", Default = true, Callback = function(v) Skin.Targets.Guns = v; scanForViewModels() end })
	Toggle(t, { Text = "Arms / Sleeves", Default = false, Callback = function(v) Skin.Targets.Arms = v; scanForViewModels() end })

	Section(t, "Effects")
	Toggle(t, { Text = "Glow on Weapon", Default = false, Callback = function(v)
		Skin.Glow = v; scanForViewModels()
	end })
	Toggle(t, { Text = "Particles on Weapon", Default = false, Callback = function(v)
		Skin.Particles = v; scanForViewModels()
	end })

	Section(t, "Actions")
	Button(t, { Text = "Rescan ViewModel", Callback = function()
		Skin.Tracked = {}
		scanForViewModels()
		Notify("SkinChanger", "rescanned", 2)
	end })
	Button(t, { Text = "Try Fire Skin Remotes", Callback = fireSkinRemotes })
	Button(t, { Text = "Deep Scan Game Data (console)", Callback = deepScan })
	Button(t, { Text = "Randomize Preset", Callback = function()
		local keys = {}
		for k in pairs(SKIN_PRESETS) do keys[#keys + 1] = k end
		Skin.Preset = keys[math.random(1, #keys)]
		Skin.Rainbow = (Skin.Preset == "Rainbow")
		scanForViewModels()
		Notify("SkinChanger", "random: " .. Skin.Preset, 2)
	end })

	Section(t, "Weapon / Knife / Glove reference")
	Dropdown(t, { Text = "Weapon List", Options = WEAPONS, Default = "AK-47",
		Callback = function(v) Skin.SelectedWeapon = v end })
	Dropdown(t, { Text = "Knife List", Options = KNIVES, Default = "Karambit",
		Callback = function(v) Skin.SelectedKnife = v end })
	Dropdown(t, { Text = "Glove List", Options = GLOVES, Default = "Sports Gloves",
		Callback = function(v) Skin.SelectedGlove = v end })
end

--// -------- MOVEMENT --------
do
	local t = Tabs.Movement.Content
	Section(t, "Bunny Hop")
	Toggle(t, { Text = "Auto BunnyHop (hold Space)", Default = false, Flag = "Bhop",
		Callback = function(v) Move.Bhop = v end })
	Toggle(t, { Text = "Infinite Jump", Default = false,
		Callback = function(v) Move.InfJump = v end })
	Section(t, "Speed")
	Toggle(t, { Text = "Custom WalkSpeed", Default = false,
		Callback = function(v) Move.SpeedEnabled = v end })
	Slider(t, { Text = "WalkSpeed", Min = 8, Max = 200, Default = 16,
		Callback = function(v) Move.WalkSpeed = v end })
	Toggle(t, { Text = "Custom JumpPower", Default = false,
		Callback = function(v) Move.JumpEnabled = v end })
	Slider(t, { Text = "JumpPower", Min = 20, Max = 300, Default = 50,
		Callback = function(v) Move.JumpPower = v end })
	Section(t, "Sprint")
	Toggle(t, { Text = "Sprint on Hold", Default = false, Callback = function(v) Move.Sprint = v end })
	Keybind(t, { Text = "Sprint Key", Default = "LeftShift",
		Callback = function(k) Move.SprintKey = k end })
	Slider(t, { Text = "Sprint Speed", Min = 18, Max = 120, Default = 24,
		Callback = function(v) Move.SprintSpeed = v end })
	Section(t, "Fly")
	Toggle(t, { Text = "Fly (WASD + Space/Ctrl)", Default = false, Callback = function(v)
		Move.Fly = v
		if not v then stopFly() end
	end })
end

--// -------- MISC --------
do
	local t = Tabs.Misc.Content
	Section(t, "Performance")
	Toggle(t, { Text = "Boost FPS (aggressive)", Default = false, Callback = function(v)
		Boost.Enabled = v
		applyBoost(v)
		Notify("Performance", v and "boost applied" or "restored", 2)
	end })
	Button(t, { Text = "Restore All Lighting", Callback = function()
		applyBoost(false)
		Notify("Performance", "lighting restored", 2)
	end })

	Section(t, "Overlay")
	Toggle(t, { Text = "Show Ping / FPS Overlay", Default = true, Callback = function(v)
		Overlay:Toggle(v)
	end })
	Keybind(t, { Text = "Overlay Toggle Key", Default = "F4", Callback = function(k, pressed)
		if pressed then Overlay:Toggle(not Overlay.Visible) end
	end })

	Section(t, "Anticheat / Protection")
	Toggle(t, { Text = "Anti Kick (hook)", Default = false, Callback = function(v)
		Bypass.AntiKick = v
		if v then installAntiKick() end
	end })
	Toggle(t, { Text = "Anti Void", Default = false, Callback = function(v) Bypass.AntiVoid = v end })
	Toggle(t, { Text = "Anti AFK", Default = true, Callback = function(v) Bypass.AntiAfk = v end })
	Toggle(t, { Text = "Anti Revert (keep local changes)", Default = false,
		Callback = function(v) Bypass.AntiRevert = v end })
	Toggle(t, { Text = "Safe Mode (local-only edits)", Default = true,
		Callback = function(v) Bypass.SafeMode = v end })

	Section(t, "Diagnostics")
	Button(t, { Text = "Deep Scan Game Data (console)", Callback = deepScan })
	Button(t, { Text = "Print Player / Camera info", Callback = function()
		print("===== SleepScript Info =====")
		print("Place:", game.PlaceId, game.PlaceVersion)
		print("Camera:", Camera)
		print("Character:", LocalPlayer.Character)
		print("ViewModel candidates in Camera:", #Camera:GetChildren())
		for _, c in ipairs(Camera:GetChildren()) do print("  cam child:", c.ClassName, c.Name) end
	end })
end

--// -------- SETTINGS --------
do
	local t = Tabs.Settings.Content
	Section(t, "Menu")
	Keybind(t, { Text = "Menu Toggle Key", Default = "RightShift", Callback = function(k, pressed)
		if pressed then Window:Toggle() end
	end })
	ColorPicker(t, { Text = "Accent Color", Default = Theme.Accent, Callback = function(c)
		Theme.Accent = c
		for _, reg in ipairs(AccentRegistry) do
			pcall(function() reg.inst[reg.prop] = c end)
		end
	end })
	Slider(t, { Text = "UI Scale", Min = 0.7, Max = 1.4, Default = 1, Decimals = 2,
		Callback = function(v)
			Window.Holder.UIScale.Scale = v
		end })
	Button(t, { Text = "Reset Menu Position", Callback = function()
		Window.Holder.Position = UDim2.new(0.5, 0, 0.5, 0)
	end })

	Section(t, "Config")
	Button(t, { Text = "Save Config", Callback = saveConfig })
	Button(t, { Text = "Load Config", Callback = loadConfig })
	Button(t, { Text = "Unload Script", Callback = function() SleepScript:Unload() end })

	Section(t, "About")
	New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 1,
		Font = Enum.Font.Gotham, TextSize = 11, TextWrapped = true,
		TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Left,
		Text = "SleepScript v" .. SleepScript.Version ..
			" for BloxStrike.\nESP, SkinChanger, AutoBhop, Visuals, Perf.\nKeybinds: RightShift (menu) / F4 (overlay) / Mouse2 (aim).",
	}, t)
end

Window:Select(Tabs.Combat)

--=====================================================================
-- 19. MAIN LOOPS
--=====================================================================
local espAccum = 0
Conn(RunService.RenderStepped, function(dt)
	updateESP()

	--// rainbow
	if Skin.Rainbow and Skin.Enabled then
		Skin.Hue = (Skin.Hue + dt * 0.35) % 1
		for model in pairs(Skin.Tracked) do
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then stylePart(d) end
			end
		end
	end

	--// skin re-apply (anti revert)
	espAccum += dt
	if espAccum > 0.4 then
		espAccum = 0
		if Skin.Enabled then
			scanForViewModels()
			for model in pairs(Skin.Tracked) do
				if not model.Parent then
					Skin.Tracked[model] = nil
				elseif not Skin.Rainbow then
					for _, d in ipairs(model:GetDescendants()) do
						if d:IsA("BasePart") then stylePart(d) end
					end
				end
			end
		end
	end
end)

Conn(LocalPlayer.CharacterAdded, function()
	task.wait(1.2)
	if Skin.Enabled then
		Skin.Tracked = {}
		scanForViewModels()
	end
	if Vis.Aura then setAura(true) end
end)

--=====================================================================
-- 20. UNLOAD
--=====================================================================
function SleepScript:Unload()
	self.Unloaded = true
	for _, c in ipairs(self.Connections) do
		pcall(function() c:Disconnect() end)
	end
	for _, o in ipairs(self.Objects) do
		pcall(function() o:Destroy() end)
	end
	for plr in pairs(ESP.Objects) do
		pcall(function() ESP.Remove(plr) end)
	end
	pcall(function() RunService:UnbindFromRenderStep("SleepAim") end)
	pcall(function() applyBoost(false) end)
	pcall(function() stopFly() end)
	pcall(function()
		if Vis.SkyInstance then Vis.SkyInstance:Destroy() end
		if Vis.Atm then Vis.Atm:Destroy() end
		if Vis.BloomFx then Vis.BloomFx:Destroy() end
		if Vis.AuraEmitter then Vis.AuraEmitter:Destroy() end
	end)
	pcall(function()
		for part, orig in pairs(Skin.Originals) do
			if part and part.Parent then
				part.Material = orig.Material
				part.Color = orig.Color
				part.Reflectance = orig.Reflectance
			end
		end
	end)
	_G.SleepScript = nil
	Notify("SleepScript", "unloaded", 3)
	print("[SleepScript] unloaded")
end

--=====================================================================
-- 21. BOOT
--=====================================================================
Window:Toggle(true)
task.wait(0.35)
Notify("SleepScript v" .. SleepScript.Version, "RightShift — menu  •  F4 — overlay", 4)
task.delay(0.6, function()
	Notify("Tip", "SkinChanger is local (ViewModel). Use Deep Scan to map remotes.", 5)
end)
print("[SleepScript] loaded for BloxStrike | UI: RightShift | Overlay: F4")
