--[[
================================================================================
        ███████╗██╗     ███████╗███████╗██████╗     SleepScript
        ██╔════╝██║     ██╔════╝██╔════╝██╔══██╗    BloxStrike Edition  v3.0
        ███████╗██║     █████╗  █████╗  ██████╔╝
        ╚════██║██║     ██╔══╝  ██╔══╝  ██╔═══╝
        ███████║███████╗███████╗███████╗██║
        ╚══════╝╚══════╝╚══════╝╚══════╝╚═╝
================================================================================
  v3.0 CHANGES
   - BunnyHop: real strafe acceleration (Quake-style air accel), speed builds
     while strafing with A/D mid-air, air-WalkSpeed override, auto-strafe
   - ESP: rebuilt on BoxHandleAdornment (always renders through walls, no
     Drawing dependency) + Highlight chams + nametags, resolver + diagnostics
   - SkinChanger: 3 SEPARATE categories (Knives / Weapons / Gloves), each with
     own weapon+skin; built-in ★skins always visible + game texture scan
   - Custom sky FIXED: edits the game's existing Sky instead of adding a new
     one, kills Atmosphere haze, forces daytime, full restore
   - Weapon GLOW removed (no more PointLight)
   - FPS Boost reworked: granular toggles + master, full restore, quality picker
================================================================================
  KEYBINDS:  [RightShift] Menu   [F4] Overlay
================================================================================
]]

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
local Stats             = game:GetService("Stats")
local VirtualUser       = game:GetService("VirtualUser")
local CoreGui           = game:GetService("CoreGui")
local HttpService       = game:GetService("HttpService")
local LocalPlayer       = Players.LocalPlayer
local Camera            = Workspace.CurrentCamera

--=====================================================================
-- 2. CORE
--=====================================================================
local SleepScript = { Version = "3.0.0", Connections = {}, Objects = {}, Flags = {}, Unloaded = false }
_G.SleepScript = SleepScript

local function Conn(sig, fn)
	local c = sig:Connect(fn)
	table.insert(SleepScript.Connections, c)
	return c
end

local function New(class, props, parent)
	local i = Instance.new(class)
	if props then for k, v in next, props do pcall(function() i[k] = v end) end end
	if parent then i.Parent = parent end
	return i
end

local function Corner(p, r) return New("UICorner", { CornerRadius = UDim.new(0, r or 8) }, p) end
local function Stroke(p, c, t, tr)
	return New("UIStroke", {
		Color = c or Color3.fromRGB(45, 45, 58), Thickness = t or 1,
		Transparency = tr or 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, p)
end
local function Pad(p, t, r, b, l)
	return New("UIPadding", {
		PaddingTop = UDim.new(0, t or 0), PaddingRight = UDim.new(0, r or 0),
		PaddingBottom = UDim.new(0, b or 0), PaddingLeft = UDim.new(0, l or 0),
	}, p)
end
local function Tween(o, t, props, st, dr)
	local tw = TweenService:Create(o, TweenInfo.new(t or 0.22, st or Enum.EasingStyle.Quint, dr or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function GuiParent()
	if gethui then
		local ok, h = pcall(gethui)
		if ok and h then return h end
	end
	local ok, core = pcall(function() return CoreGui end)
	if ok and core then
		local works = pcall(function() local f = Instance.new("Frame"); f.Parent = core; f:Destroy() end)
		if works then return core end
	end
	return LocalPlayer:WaitForChild("PlayerGui")
end
local function GetHum(plr)
	local ch = plr and plr.Character
	if not ch then return nil end
	local h = ch:FindFirstChildOfClass("Humanoid")
	if h then return h end
	for _, d in ipairs(ch:GetDescendants()) do
		if d:IsA("Humanoid") then return d end
	end
end

--=====================================================================
-- 3. THEME + NOTIFY
--=====================================================================
local Theme = {
	Accent = Color3.fromRGB(130, 100, 255), Accent2 = Color3.fromRGB(80, 190, 255),
	Bg = Color3.fromRGB(9, 9, 12), Bg2 = Color3.fromRGB(15, 15, 19),
	Surface = Color3.fromRGB(20, 20, 26), Surface2 = Color3.fromRGB(28, 28, 36),
	Stroke = Color3.fromRGB(44, 44, 56), Text = Color3.fromRGB(238, 238, 248),
	Sub = Color3.fromRGB(142, 142, 162), Good = Color3.fromRGB(96, 226, 148),
	Warn = Color3.fromRGB(250, 196, 88), Bad = Color3.fromRGB(240, 96, 96),
}
local AccentRegistry = {}
local function RegisterAccent(i, p) table.insert(AccentRegistry, { inst = i, prop = p }) end

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

local function Notify(title, text, dur)
	dur = dur or 3
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
	for _, o in ipairs({ card, bar, t1, t2 }) do
		if o:IsA("TextLabel") then Tween(o, 0.25, { TextTransparency = 0 })
		else Tween(o, 0.25, { BackgroundTransparency = o == card and 0.05 or 0 }) end
	end
	Tween(st, 0.25, { Transparency = 0.6 })
	task.delay(dur, function()
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
-- 4. UI LIBRARY
--=====================================================================
local Lib = { Theme = Theme }
local MainGui = New("ScreenGui", {
	Name = "SleepScriptUI", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 900,
}, GuiParent())
SleepScript.Objects[#SleepScript.Objects + 1] = MainGui

local function Hover(b, n, h)
	b.MouseEnter:Connect(function() Tween(b, 0.18, h) end)
	b.MouseLeave:Connect(function() Tween(b, 0.18, n) end)
end

function Lib:Window(cfg)
	cfg = cfg or {}
	local win = { Tabs = {}, Open = true }
	local holder = New("Frame", {
		Name = "SleepHolder", Size = UDim2.fromOffset(660, 460),
		Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1, Visible = false,
	}, MainGui)
	local scale = New("UIScale", { Scale = 0.94 }, holder)
	local shadow = New("Frame", {
		Size = UDim2.new(1, 18, 1, 18), Position = UDim2.new(0.5, 0, 0.5, 9),
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 0,
	}, holder)
	Corner(shadow, 22)
	local root = New("CanvasGroup", {
		Size = UDim2.new(1, -20, 1, -20), Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Theme.Bg,
		BorderSizePixel = 0, GroupTransparency = 1, ClipsDescendants = true, ZIndex = 1,
	}, holder)
	Corner(root, 14)
	Stroke(root, Theme.Stroke, 1, 0.5)

	local topbar = New("Frame", {
		Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Theme.Bg2, BorderSizePixel = 0, ZIndex = 2,
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
	New("TextLabel", {
		Size = UDim2.fromOffset(220, 20), Position = UDim2.new(0, 32, 0.5, -8),
		BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 16,
		Text = cfg.Title or "SleepScript", TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
	}, topbar)
	New("TextLabel", {
		Size = UDim2.fromOffset(300, 14), Position = UDim2.new(0, 33, 0.5, 8),
		BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 10,
		Text = cfg.Subtitle or "bloxstrike edition  •  v" .. SleepScript.Version,
		TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
	}, topbar)
	local grad = New("Frame", {
		Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1),
		BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, ZIndex = 3,
	}, topbar)
	New("UIGradient", {
		Color = ColorSequence.new(Theme.Accent, Theme.Accent2),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(0.5, 0.05),
			NumberSequenceKeypoint.new(1, 0.75),
		}),
	}, grad)

	local function WinBtn(txt, xoff, cb)
		local b = New("TextButton", {
			Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, xoff, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = Theme.Surface,
			BorderSizePixel = 0, Text = txt, Font = Enum.Font.GothamBold, TextSize = 13,
			TextColor3 = Theme.Sub, AutoButtonColor = false, ZIndex = 4,
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
		Tween(holder, 0.3, { Size = minimized and UDim2.fromOffset(250, 44) or UDim2.fromOffset(660, 460) })
	end)
	WinBtn("✕", -14, function() win:Toggle(false) end)

	do
		local dragging, ds, sp = false, nil, nil
		topbar.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				dragging, ds, sp = true, i.Position, holder.Position
			end
		end)
		Conn(UserInputService.InputEnded, function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
		end)
		Conn(UserInputService.InputChanged, function(i)
			if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
				local d = i.Position - ds
				holder.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
			end
		end)
	end

	local sidebar = New("Frame", {
		Size = UDim2.new(0, 142, 1, -58), Position = UDim2.new(0, 12, 0, 50),
		BackgroundColor3 = Theme.Bg2, BorderSizePixel = 0, ZIndex = 2,
	}, root)
	Corner(sidebar, 11)
	Pad(sidebar, 8, 8, 8, 8)
	New("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, sidebar)
	local indicator = New("Frame", {
		Size = UDim2.new(0, 3, 0, 20), Position = UDim2.new(0, 2, 0, 8),
		BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, ZIndex = 3,
	}, sidebar)
	Corner(indicator, 3)
	RegisterAccent(indicator, "BackgroundColor3")

	local contentHolder = New("Frame", {
		Size = UDim2.new(1, -174, 1, -58), Position = UDim2.new(0, 162, 0, 50),
		BackgroundTransparency = 1, ZIndex = 2,
	}, root)

	function win:Toggle(state)
		if state == nil then state = not self.Open end
		self.Open = state
		if state then
			holder.Visible = true
			scale.Scale = 0.94
			root.GroupTransparency = 1
			Tween(scale, 0.32, { Scale = 1 })
			Tween(root, 0.28, { GroupTransparency = 0 })
		else
			Tween(scale, 0.22, { Scale = 0.94 })
			Tween(root, 0.2, { GroupTransparency = 1 })
			task.delay(0.22, function() if not self.Open then holder.Visible = false end end)
		end
	end

	local function MakeTab(name, icon)
		local tab = { Name = name }
		local btn = New("TextButton", {
			Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Bg2,
			BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Text = "", ZIndex = 3,
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
			Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Stroke,
			CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 2,
		}, wrap)
		New("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
		Pad(scroll, 4, 8, 14, 4)
		tab.Content, tab.Wrap = scroll, wrap
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
		tab.Button, tab.Label = btn, lbl
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
				t.Wrap.Visible = true
				Tween(t.Wrap, 0.22, { GroupTransparency = 0 })
				Tween(indicator, 0.25, {
					Position = UDim2.new(0, 2, 0, t.Button.AbsolutePosition.Y - sidebar.AbsolutePosition.Y + 5),
				})
			else
				Tween(t.Wrap, 0.16, { GroupTransparency = 1 })
				task.delay(0.17, function() if win.ActiveTab ~= t then t.Wrap.Visible = false end end)
			end
		end
	end
	win.MakeTab, win.Holder, win.Scale = MakeTab, holder, scale
	return win
end

local function Section(parent, text)
	local f = New("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 }, parent)
	local bar = New("Frame", {
		Size = UDim2.new(0, 3, 0, 13), Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0,
	}, f)
	Corner(bar, 2)
	RegisterAccent(bar, "BackgroundColor3")
	New("TextLabel", {
		Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 12, 0, 0),
		BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12,
		Text = text:upper(), TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, f)
	return f
end

local function Label(parent, text)
	return New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, Font = Enum.Font.Gotham,
		TextSize = 11, TextColor3 = Theme.Sub, Text = text, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, AutomaticSize = Enum.AutomaticSize.Y,
	}, parent)
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
		Text = o.Text or "Toggle", TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, f)
	local pill = New("Frame", {
		Size = UDim2.fromOffset(38, 18), Position = UDim2.new(1, -12, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = Theme.Surface2, BorderSizePixel = 0,
	}, f)
	Corner(pill, 9)
	local knob = New("Frame", {
		Size = UDim2.fromOffset(14, 14), Position = UDim2.new(0, 2, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Theme.Sub, BorderSizePixel = 0,
	}, pill)
	Corner(knob, 7)
	local btn = New("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, f)
	local state = o.Default or false
	local obj = {}
	function obj:Set(v, silent)
		state = v and true or false
		Tween(pill, 0.2, { BackgroundColor3 = state and Theme.Accent or Theme.Surface2 })
		Tween(knob, 0.22, {
			Position = state and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
			BackgroundColor3 = state and Color3.new(1, 1, 1) or Theme.Sub,
		}, Enum.EasingStyle.Back)
		if not silent and o.Callback then task.spawn(o.Callback, state) end
	end
	btn.MouseButton1Click:Connect(function() obj:Set(not state) end)
	Hover(f, { BackgroundTransparency = 0.35 }, { BackgroundTransparency = 0.15 })
	if state then obj:Set(true, true) end
	obj.State = state
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
		Size = UDim2.new(1, -80, 0, 18), Position = UDim2.new(0, 12, 0, 5),
		BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
		Text = o.Text or "Slider", TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, f)
	local val = New("TextLabel", {
		Size = UDim2.new(0, 80, 0, 18), Position = UDim2.new(1, -12, 0, 5),
		AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
		TextSize = 12, TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Right, Text = "0",
	}, f)
	local track = New("Frame", {
		Size = UDim2.new(1, -24, 0, 5), Position = UDim2.new(0, 12, 1, -14),
		BackgroundColor3 = Theme.Surface2, BorderSizePixel = 0,
	}, f)
	Corner(track, 3)
	local fill = New("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0 }, track)
	Corner(fill, 3)
	local knob = New("Frame", {
		Size = UDim2.fromOffset(12, 12), Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}, track)
	Corner(knob, 6)
	local min, max = o.Min or 0, o.Max or 100
	local dec = o.Decimals or 0
	local value = o.Default or min
	local obj = { Value = value }
	local function render()
		local a = (value - min) / math.max(max - min, 0.0001)
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, 0, 0.5, 0)
		local t = dec > 0 and string.format("%." .. dec .. "f", value) or tostring(math.floor(value + 0.5))
		val.Text = (o.Suffix and (t .. o.Suffix)) or t
	end
	function obj:Set(v, silent)
		value = math.clamp(v, min, max)
		obj.Value = value
		render()
		if not silent and o.Callback then task.spawn(o.Callback, value) end
	end
	local dragging = false
	local function upd(i)
		local rel = math.clamp((i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		obj:Set(min + rel * (max - min))
	end
	track.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true; upd(i)
		end
	end)
	Conn(UserInputService.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
	Conn(UserInputService.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then upd(i) end
	end)
	render()
	if o.Callback then task.spawn(o.Callback, value) end
	return obj
end

local function Button(parent, o)
	o = o or {}
	local b = New("TextButton", {
		Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Surface,
		BackgroundTransparency = 0.35, BorderSizePixel = 0, Text = "", AutoButtonColor = false,
	}, parent)
	Corner(b, 9)
	Stroke(b, Theme.Stroke, 1, 0.7)
	New("TextLabel", {
		Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 10, 0, 0),
		BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
		Text = o.Text or "Button", TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, b)
	Hover(b, { BackgroundTransparency = 0.35 }, { BackgroundTransparency = 0.12 })
	b.MouseButton1Click:Connect(function() if o.Callback then task.spawn(o.Callback) end end)
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
		Text = o.Text or "Keybind", TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, f)
	local kb = New("TextButton", {
		Size = UDim2.fromOffset(56, 20), Position = UDim2.new(1, -12, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = Theme.Surface2,
		BorderSizePixel = 0, Text = o.Default or "None", Font = Enum.Font.GothamBold,
		TextSize = 11, TextColor3 = Theme.Accent, AutoButtonColor = false,
	}, f)
	Corner(kb, 6)
	local listening = false
	local key = o.Default or "None"
	kb.MouseButton1Click:Connect(function()
		listening = true
		kb.Text = "..."
		Tween(kb, 0.15, { TextColor3 = Theme.Warn })
	end)
	Conn(UserInputService.InputBegan, function(i, gp)
		if listening then
			listening = false
			Tween(kb, 0.15, { TextColor3 = Theme.Accent })
			key = (i.KeyCode == Enum.KeyCode.Unknown) and ("M" .. i.UserInputType.Value) or i.KeyCode.Name
			kb.Text = key
			if o.Callback then task.spawn(o.Callback, key) end
			return
		end
		if gp then return end
		if i.KeyCode.Name == key and o.Callback then task.spawn(o.Callback, key, true) end
	end)
	if o.Callback then task.spawn(o.Callback, key) end
	return { Key = key }
end

local function Dropdown(parent, o)
	o = o or {}
	local f = New("Frame", {
		Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Surface,
		BackgroundTransparency = 0.35, BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.Y,
	}, parent)
	Corner(f, 9)
	Stroke(f, Theme.Stroke, 1, 0.7)
	New("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, f)
	Pad(f, 2, 4, 4, 4)
	local header = New("TextButton", {
		Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Text = "",
		AutoButtonColor = false, LayoutOrder = 1,
	}, f)
	New("TextLabel", {
		Size = UDim2.new(1, -150, 1, 0), Position = UDim2.new(0, 8, 0, 0),
		BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
		Text = o.Text or "Dropdown", TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, header)
	local valueLbl = New("TextLabel", {
		Size = UDim2.new(0, 160, 1, 0), Position = UDim2.new(1, -26, 0, 0),
		BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 11, Text = "",
		TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, header)
	local arrow = New("TextLabel", {
		Size = UDim2.fromOffset(18, 18), Position = UDim2.new(1, -22, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold, TextSize = 12, Text = "+", TextColor3 = Theme.Sub,
	}, header)
	local list = New("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.2, BorderSizePixel = 0, ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Stroke, Visible = false, LayoutOrder = 2,
		CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, f)
	Corner(list, 7)
	New("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	Pad(list, 3, 3, 3, 3)
	local search = New("TextBox", {
		Size = UDim2.new(1, -6, 0, 20), BackgroundColor3 = Theme.Surface2,
		BorderSizePixel = 0, Font = Enum.Font.Gotham, TextSize = 11, Text = "",
		PlaceholderText = "search...", TextColor3 = Theme.Text,
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
					BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false,
				}, list)
				Corner(b, 5)
				local t = New("TextLabel", {
					Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 8, 0, 0),
					BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11,
					Text = tostring(opt), TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Left,
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
	function obj:Open(st)
		open = st
		arrow.Text = open and "-" or "+"
		search.Visible = open and (#obj.Options > 10)
		list.Visible = open
		if open then
			build(search.Text)
			Tween(list, 0.22, { Size = UDim2.new(1, 0, 0, math.min(math.max(#obj.Options * 23 + 10, 40), 170)) })
		else
			Tween(list, 0.18, { Size = UDim2.new(1, 0, 0, 0) })
		end
	end
	function obj:Set(v, silent)
		obj.Value = v
		valueLbl.Text = tostring(v)
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

Lib.Section, Lib.Label, Lib.Toggle, Lib.Slider = Section, Label, Toggle, Slider
Lib.Button, Lib.Keybind, Lib.Dropdown = Button, Keybind, Dropdown

--=====================================================================
-- 5. GAME DATA
--=====================================================================
local WEAPONS = {
	"AK-47", "M4A1", "M4A4", "M4A1-S", "AWP", "SSG-08", "AUG", "SG-553", "FAMAS",
	"Galil", "SCAR-20", "G3SG1", "MP9", "MAC-10", "MP7", "MP5", "UMP-45", "P90",
	"PP-Bizon", "Nova", "XM1014", "MAG-7", "Sawed-Off", "M249", "Negev", "Glock",
	"Glock-18", "USP", "USP-S", "P2000", "P250", "Five-SeveN", "Tec-9", "CZ75",
	"Dual Berettas", "Desert Eagle", "Deagle", "R8 Revolver", "M1911", "Revolver",
}
local KNIVES = {
	"Karambit", "Butterfly Knife", "Butterfly", "M9 Bayonet", "Bayonet", "Flip Knife",
	"Flip", "Gut Knife", "Gut", "Huntsman Knife", "Falchion Knife", "Bowie Knife",
	"Shadow Daggers", "Skeleton Knife", "Skeleton", "Nomad Knife", "Paracord Knife",
	"Survival Knife", "Ursus Knife", "Stiletto Knife", "Talon Knife", "Classic Knife",
	"Kukri Knife", "Knife",
}
local GLOVES = {
	"Sports Gloves", "Driver Gloves", "Hand Wraps", "Specialist Gloves", "Moto Gloves",
	"Bloodhound Gloves", "Broken Fang Gloves", "Hydra Gloves", "Operator Gloves",
	"Gloves", "Default Gloves",
}
local MATERIALS = {
	"Keep", "Neon", "Metal", "Glass", "Ice", "Marble", "Granite", "Sand", "Foil",
	"Fabric", "SmoothPlastic", "Plastic", "DiamondPlate", "CorrodedMetal", "Slate",
	"Concrete", "Wood", "WoodPlanks", "Cobblestone", "Basalt", "Limestone",
}
local BUILTIN_SKINS = {
	["★ Gold"]     = { Color = Color3.fromRGB(255, 202, 84), Material = "Metal" },
	["★ Chrome"]   = { Color = Color3.fromRGB(226, 230, 240), Material = "Metal", Reflectance = 0.5 },
	["★ Carbon"]   = { Color = Color3.fromRGB(28, 28, 32), Material = "Metal" },
	["★ Fade"]     = { Color = Color3.fromRGB(255, 130, 195), Material = "SmoothPlastic" },
	["★ Crimson"]  = { Color = Color3.fromRGB(185, 28, 42), Material = "Metal" },
	["★ Neon Purple"] = { Color = Color3.fromRGB(168, 96, 255), Material = "Neon" },
	["★ Neon Blue"]   = { Color = Color3.fromRGB(70, 170, 255), Material = "Neon" },
	["★ Neon Green"]  = { Color = Color3.fromRGB(80, 255, 150), Material = "Neon" },
	["★ Toxic"]    = { Color = Color3.fromRGB(190, 255, 60), Material = "Neon" },
	["★ Obsidian"] = { Color = Color3.fromRGB(12, 12, 16), Material = "Glass", Reflectance = 0.4 },
	["★ Frost"]    = { Color = Color3.fromRGB(180, 230, 255), Material = "Ice", Reflectance = 0.3 },
	["★ Sand"]     = { Color = Color3.fromRGB(214, 188, 140), Material = "Sand" },
	["★ White"]    = { Color = Color3.fromRGB(245, 245, 250), Material = "SmoothPlastic" },
	["★ Rainbow"]  = { Rainbow = true },
}

local SKY_PRESETS = {
	["Game Default"] = "default",
	["Space"] = {
		Bk = "rbxassetid://149397692", Dn = "rbxassetid://149397686",
		Ft = "rbxassetid://149397697", Lf = "rbxassetid://149397684",
		Rt = "rbxassetid://149397688", Up = "rbxassetid://149397702",
	},
	["Night"] = {
		Bk = "rbxassetid://12064107", Dn = "rbxassetid://12064152",
		Ft = "rbxassetid://12064121", Lf = "rbxassetid://12063984",
		Rt = "rbxassetid://12064115", Up = "rbxassetid://12064131",
	},
	["Nebula"] = { all = "rbxassetid://10258337305" },
	["Void"] = { all = "rbxassetid://2675785344" },
	["Classic Roblox"] = {
		Bk = "rbxasset://textures/sky/sky512_bk.tex", Dn = "rbxasset://textures/sky/sky512_dn.tex",
		Ft = "rbxasset://textures/sky/sky512_ft.tex", Lf = "rbxasset://textures/sky/sky512_lf.tex",
		Rt = "rbxasset://textures/sky/sky512_rt.tex", Up = "rbxasset://textures/sky/sky512_up.tex",
	},
}

--=====================================================================
-- 6. CAMERA WATCH
--=====================================================================
Conn(Workspace:GetPropertyChangedSignal("CurrentCamera"), function() Camera = Workspace.CurrentCamera end)

--=====================================================================
-- 7. FOV
--=====================================================================
local FOV = { Enabled = false, Value = 100, Original = nil }
SleepScript.FOV = FOV
RunService:BindToRenderStep("SleepFOV", Enum.RenderPriority.Camera.Value + 1, function()
	if not FOV.Enabled then return end
	local cam = Workspace.CurrentCamera
	if cam and math.abs(cam.FieldOfView - FOV.Value) > 0.05 then cam.FieldOfView = FOV.Value end
end)
function FOV:Reset()
	local cam = Workspace.CurrentCamera
	if cam and FOV.Original then cam.FieldOfView = FOV.Original end
end

--=====================================================================
-- 8. ESP  (BoxHandleAdornment-based, always renders)
--=====================================================================
local hasDrawing = false
do
	local ok = pcall(function() local s = Drawing.new("Square") s:Remove() end)
	hasDrawing = ok
end

local ESP = {
	Enabled = false,
	Boxes = true, Chams = true, Names = true, Health = true, Distance = true, Weapon = true,
	TeamCheck = false, UseTeamColor = true, MaxDistance = 2500,
	Color = Color3.fromRGB(255, 255, 255),
	BoxTransparency = 0.35, FillAlpha = 0.25,
	Objects = {}, Debug = "0",
}
SleepScript.ESP = ESP

local function findHumanoid(model)
	if not model then return nil end
	local h = model:FindFirstChildOfClass("Humanoid")
	if h then return h end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Humanoid") then return d end
	end
end

local function findAnchor(model)
	if not model then return nil end
	local h = model:FindFirstChild("Head")
	if h and h:IsA("BasePart") then return h end
	local r = model:FindFirstChild("HumanoidRootPart")
	if r and r:IsA("BasePart") then return r end
	local hum = findHumanoid(model)
	if hum and hum.RootPart then return hum.RootPart end
	return nil
end

local function resolveCharacter(plr)
	local c = plr.Character
	if c and c.Parent and findHumanoid(c) then return c end
	local name = plr.Name
	for _, d in ipairs(Workspace:GetChildren()) do
		if d:IsA("Model") and d.Name == name and findHumanoid(d) then return d end
	end
	for _, d in ipairs(Workspace:GetChildren()) do
		if d:IsA("Model") or d:IsA("Folder") then
			local f = d:FindFirstChild(name)
			if f and (f:IsA("Model") or f:IsA("Folder")) and findHumanoid(f) then return f end
		end
	end
end

local function espColorFor(plr)
	if ESP.UseTeamColor and plr.TeamColor then return plr.TeamColor.Color end
	return ESP.Color
end

local function destroyESP(plr)
	local d = ESP.Objects[plr]
	if not d then return end
	if d.Box and d.Box.Parent then d.Box:Destroy() end
	if d.Highlight and d.Highlight.Parent then d.Highlight:Destroy() end
	if d.Billboard and d.Billboard.Parent then d.Billboard:Destroy() end
	if d.Draw then pcall(function() d.Draw:Remove() end) end
	ESP.Objects[plr] = nil
end

local function createESP(plr)
	local char = resolveCharacter(plr)
	if not char then return false end
	local hrp = findAnchor(char)
	local hum = findHumanoid(char)
	if not hrp or not hum then return false end
	local col = espColorFor(plr)

	local d = { Player = plr, Character = char, Anchor = hrp, Humanoid = hum }

	--// 3D box that renders through walls
	d.Box = New("BoxHandleAdornment", {
		Name = "SleepBox", Adornee = hrp, AlwaysOnTop = true,
		Size = Vector3.new(4, 6, 4), Color3 = col, Transparency = 0.35, ZIndex = 2,
	}, Camera)

	--// chams
	d.Highlight = New("Highlight", {
		Name = "SleepChams", Adornee = char,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		FillTransparency = 1, OutlineTransparency = 1,
		FillColor = col, OutlineColor = col,
	}, char)

	--// nametag
	local bb = New("BillboardGui", {
		Name = "SleepTag", Adornee = hrp, Size = UDim2.fromOffset(200, 62),
		StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0), AlwaysOnTop = true,
		LightInfluence = 0, MaxDistance = math.huge, Enabled = false,
	}, hrp)
	d.Billboard = bb
	d.Name = New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
		TextSize = 13, Text = plr.Name, TextColor3 = col,
		TextStrokeTransparency = 0.4, TextStrokeColor3 = Color3.new(0, 0, 0),
	}, bb)
	d.Info = New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, 16),
		BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11, Text = "",
		TextColor3 = Theme.Sub, TextStrokeTransparency = 0.5, TextStrokeColor3 = Color3.new(0, 0, 0),
	}, bb)
	local barBg = New("Frame", {
		Size = UDim2.new(0, 90, 0, 5), Position = UDim2.new(0.5, 0, 0, 32),
		AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromRGB(15, 15, 15),
		BackgroundTransparency = 0.3, BorderSizePixel = 0,
	}, bb)
	Corner(barBg, 3)
	d.HealthBar = New("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Theme.Good, BorderSizePixel = 0 }, barBg)
	Corner(d.HealthBar, 3)

	ESP.Objects[plr] = d
	return true
end

local function refreshESP()
	for plr, d in pairs(ESP.Objects) do
		local ok = plr.Parent ~= nil and d.Character and d.Character.Parent
			and d.Humanoid and d.Humanoid.Parent and d.Humanoid.Health > 0
		if not ok then destroyESP(plr) end
	end
	if ESP.Enabled then
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer and not ESP.Objects[plr] then createESP(plr) end
		end
	end
	local n = 0
	for _ in pairs(ESP.Objects) do n = n + 1 end
	ESP.Debug = tostring(n)
end
ESP.Refresh = refreshESP

local function updateESP()
	if not ESP.Enabled then
		for _, d in pairs(ESP.Objects) do
			if d.Box then d.Box.Visible = false end
			if d.Highlight then d.Highlight.FillTransparency = 1 d.Highlight.OutlineTransparency = 1 end
			if d.Billboard then d.Billboard.Enabled = false end
		end
		return
	end
	local cam = Workspace.CurrentCamera
	if not cam then return end
	local myPos = cam.CFrame.Position
	local myTeam = LocalPlayer.Team

	for plr, d in pairs(ESP.Objects) do
		local char, hum, anchor = d.Character, d.Humanoid, d.Anchor
		local valid = char and char.Parent and hum and hum.Parent and hum.Health > 0 and anchor and anchor.Parent
		local skip = valid and ESP.TeamCheck and myTeam and plr.Team and plr.Team == myTeam
		if not valid or skip then
			if d.Box then d.Box.Visible = false end
			if d.Highlight then d.Highlight.FillTransparency = 1 d.Highlight.OutlineTransparency = 1 end
			if d.Billboard then d.Billboard.Enabled = false end
			continue
		end

		local dist = (anchor.Position - myPos).Magnitude
		local col = espColorFor(plr)
		local inRange = dist <= ESP.MaxDistance

		if d.Box then
			d.Box.Adornee = anchor
			d.Box.Visible = ESP.Boxes and inRange
			d.Box.Color3 = col
			d.Box.Transparency = ESP.BoxTransparency
			local ok, size = pcall(function() return char:GetExtentsSize() end)
			if ok and size then
				d.Box.Size = Vector3.new(size.X + 0.5, size.Y + 0.5, size.Z + 0.5)
			end
		end

		if d.Highlight then
			d.Highlight.FillColor = col
			d.Highlight.OutlineColor = col
			d.Highlight.FillTransparency = (ESP.Chams and inRange) and (1 - ESP.FillAlpha) or 1
			d.Highlight.OutlineTransparency = (ESP.Chams and inRange) and 0 or 1
		end

		if d.Billboard then
			local show = inRange and (ESP.Names or ESP.Health or ESP.Distance or ESP.Weapon)
			d.Billboard.Enabled = show
			if show then
				d.Name.Visible = ESP.Names
				d.Name.TextColor3 = col
				d.HealthBar.Parent.Visible = ESP.Health
				local hp = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
				d.HealthBar.Size = UDim2.new(hp, 0, 1, 0)
				d.HealthBar.BackgroundColor3 = Color3.fromRGB(math.floor(255 * (1 - hp)), math.floor(255 * hp), 60)
				local p = {}
				if ESP.Distance then p[#p + 1] = ("%dm"):format(math.floor(dist)) end
				if ESP.Weapon then
					local t = char:FindFirstChildOfClass("Tool")
					local a = plr:GetAttribute("Weapon") or plr:GetAttribute("CurrentWeapon") or char:GetAttribute("Weapon")
					p[#p + 1] = t and t.Name or (a and tostring(a)) or "-"
				end
				d.Info.Visible = #p > 0
				d.Info.Text = table.concat(p, "  •  ")
			end
		end
	end
end
ESP.Update = updateESP

Conn(Players.PlayerRemoving, destroyESP)
Conn(Players.PlayerAdded, function(p)
	p.CharacterAdded:Connect(function()
		task.wait(0.4)
		destroyESP(p)
		if ESP.Enabled then createESP(p) end
	end)
end)
for _, p in ipairs(Players:GetPlayers()) do
	if p ~= LocalPlayer then
		p.CharacterAdded:Connect(function()
			task.wait(0.4)
			destroyESP(p)
			if ESP.Enabled then createESP(p) end
		end)
	end
end

--=====================================================================
-- 9. SKIN CHANGER  (3 separate categories)
--=====================================================================
local Skin = {
	Enabled = false,
	Particles = false,
	DeepMesh = false,
	Hue = 0,
	Library = { Knife = {}, Gun = {}, Glove = {} },
	Tracked = {},
	Desired = {},
	Originals = {},
	HiddenSA = {},
	Detected = "-",
	Categories = {
		Knife = { Enabled = true, Weapon = "Auto (equipped)", Skin = "None", Color = "Keep", Material = "Keep" },
		Gun   = { Enabled = true, Weapon = "Auto (equipped)", Skin = "None", Color = "Keep", Material = "Keep" },
		Glove = { Enabled = true, Weapon = "Auto (equipped)", Skin = "None", Color = "Keep", Material = "Keep" },
	},
}
SleepScript.Skin = Skin

local function clean(s) return (s:lower():gsub("[%s_%-%.]", "")) end
local ALL_NAMES = {}
for _, t in ipairs({ WEAPONS, KNIVES, GLOVES }) do
	for _, n in ipairs(t) do ALL_NAMES[#ALL_NAMES + 1] = n end
end

local function detectWeapon(model)
	if not model then return nil end
	local names = { model.Name }
	for _, d in ipairs(model:GetChildren()) do names[#names + 1] = d.Name end
	for _, n in ipairs(names) do
		local c = clean(n)
		for _, w in ipairs(ALL_NAMES) do
			local cw = clean(w)
			if #cw >= 3 and (c == cw or c:find(cw, 1, true)) then return w end
		end
	end
end

local function classifyPart(part, model, inChar)
	local n = part.Name:lower()
	if n:find("knife") or n:find("karambit") or n:find("bayonet") or n:find("dagger")
		or n:find("blade") or n:find("talon") or n:find("flip") or n:find("gut") then return "Knife" end
	if n:find("glove") or n:find("wrap") or n:find("hand") or n:find("arm") or n:find("sleeve") then return "Glove" end
	local c = clean(part.Name)
	for _, w in ipairs(WEAPONS) do
		local cw = clean(w)
		if #cw >= 3 and c:find(cw, 1, true) then return "Gun" end
	end
	local det = detectWeapon(model)
	if det then
		for _, k in ipairs(KNIVES) do if k == det then return "Knife" end end
		for _, g in ipairs(GLOVES) do if g == det then return "Glove" end end
		return "Gun"
	end
	if inChar then return "Body" end
	return "Gun"
end

--// library from game files
local function buildLibrary()
	Skin.Library = { Knife = {}, Gun = {}, Glove = {} }
	local seen = {}
	local function catOf(name, cls)
		local n = name:lower()
		if n:find("knife") or n:find("karambit") or n:find("bayonet") or n:find("dagger")
			or n:find("blade") or n:find("talon") or n:find("bowie") or n:find("gut") then return "Knife" end
		if n:find("glove") or n:find("wrap") or n:find("hand") then return "Glove" end
		return "Gun"
	end
	local function add(name, id, cls)
		if not id or type(id) ~= "string" or id == "" then return end
		if seen[id] then return end
		seen[id] = true
		local cat = catOf(name, cls)
		local key = name
		if Skin.Library[cat][key] then key = name .. " [" .. cls .. "]" end
		if Skin.Library[cat][key] then key = name .. " #" .. tostring(math.random(1000, 9999)) end
		Skin.Library[cat][key] = id
	end
	local function scan(root, budget)
		local n = 0
		for _, d in ipairs(root:GetDescendants()) do
			n = n + 1
			if n > budget then break end
			local id
			if d:IsA("Decal") or d:IsA("Texture") then id = d.Texture
			elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then id = d.Image
			elseif d:IsA("SurfaceAppearance") then id = d.ColorMap
			elseif d:IsA("MeshPart") then id = d.TextureID
			elseif d:IsA("StringValue") then
				local v = d.Value
				if type(v) == "string" and (v:find("rbxassetid") or v:find("asset/?id=")) then id = v end
			end
			if id then add(d.Name, id, d.ClassName) end
		end
	end
	scan(ReplicatedStorage, 40000)
	for _, nm in ipairs({ "Skins", "Skin", "Camos", "Camo", "Finishes", "Textures", "Assets", "Weapons" }) do
		local f = ReplicatedStorage:FindFirstChild(nm)
		if f then scan(f, 8000) end
	end
	local total = 0
	for _, cat in pairs(Skin.Library) do
		for _ in pairs(cat) do total = total + 1 end
	end
	return total
end

local function skinOptions(cat)
	local o = { "None" }
	local k = {}
	for key in pairs(BUILTIN_SKINS) do k[#k + 1] = key end
	table.sort(k)
	for _, key in ipairs(k) do o[#o + 1] = key end
	local g = {}
	for key in pairs(Skin.Library[cat] or {}) do g[#g + 1] = key end
	table.sort(g)
	for _, key in ipairs(g) do o[#o + 1] = key end
	return o
end

--// texture helpers
local function clearSkinChildren(part)
	for _, c in ipairs(part:GetChildren()) do
		if c.Name:sub(1, 9) == "SleepSkin" then c:Destroy() end
	end
end

local function hideSA(part)
	local sa = part:FindFirstChildOfClass("SurfaceAppearance")
	if sa and not Skin.HiddenSA[part] then
		Skin.HiddenSA[part] = sa
		sa.Parent = nil
	end
end
local function restoreSA(part)
	local sa = Skin.HiddenSA[part]
	if sa then
		pcall(function() sa.Parent = part end)
		Skin.HiddenSA[part] = nil
	end
end

local function applyTexture(part, id)
	if not id or id == "" then clearSkinChildren(part) return end
	hideSA(part)
	if part:IsA("MeshPart") then
		pcall(function() part.TextureID = id end)
	end
	local sm = part:FindFirstChildOfClass("SpecialMesh")
	if sm then pcall(function() sm.TextureId = id end) end
	if not part:IsA("MeshPart") or not sm then
		for i, f in ipairs({ "Front", "Back", "Left", "Right", "Top", "Bottom" }) do
			local t = part:FindFirstChild("SleepSkin" .. i)
			if not t then
				t = New("Texture", {
					Name = "SleepSkin" .. i, Face = Enum.NormalId[f],
					StudsPerTileU = 1, StudsPerTileV = 1,
				}, part)
			end
			t.Texture = id
		end
	end
end

local function matchesTarget(cat, model)
	local cfg = Skin.Categories[cat]
	local target = cfg.Weapon
	if target == "Auto (equipped)" or target == "" then return true end
	local ct = clean(target)
	local cn = clean(model.Name)
	if cn:find(ct, 1, true) or ct:find(cn, 1, true) then return true end
	local det = detectWeapon(model)
	return det ~= nil and det == target
end

local function computeDesired(cat, part)
	local cfg = Skin.Categories[cat]
	local skinName = cfg.Skin
	local color, material, texture

	local b = BUILTIN_SKINS[skinName]
	if b then
		if b.Rainbow then
			color = Color3.fromHSV(Skin.Hue, 0.85, 1)
			material = Enum.Material.Neon
		else
			color = b.Color
			if b.Material then material = Enum.Material[b.Material] end
		end
	else
		local id = Skin.Library[cat] and Skin.Library[cat][skinName]
		if id then texture = id end
	end

	if cfg.Material ~= "Keep" then
		local ok, m = pcall(function() return Enum.Material[cfg.Material] end)
		if ok and m then material = m end
	end
	if cfg.Color ~= "Keep" then
		color = COLOR_LOOKUP[cfg.Color] or color
	end
	return color, material, texture
end

local COLOR_LOOKUP = {
	["Gold"] = Color3.fromRGB(255, 202, 84), ["Silver"] = Color3.fromRGB(226, 230, 240),
	["Carbon"] = Color3.fromRGB(28, 28, 32), ["Crimson"] = Color3.fromRGB(185, 28, 42),
	["Neon Purple"] = Color3.fromRGB(168, 96, 255), ["Neon Blue"] = Color3.fromRGB(70, 170, 255),
	["Neon Green"] = Color3.fromRGB(80, 255, 150), ["Toxic"] = Color3.fromRGB(190, 255, 60),
	["Obsidian"] = Color3.fromRGB(12, 12, 16), ["Frost"] = Color3.fromRGB(180, 230, 255),
	["Sand"] = Color3.fromRGB(214, 188, 140), ["White"] = Color3.fromRGB(245, 245, 250),
}

local function stylePart(part, model, inChar)
	if not part:IsA("BasePart") then return end
	local cat = classifyPart(part, model, inChar)
	if cat == "Body" then return end
	if not Skin.Categories[cat].Enabled then return end
	if not matchesTarget(cat, model) then return end

	if not Skin.Originals[part] then
		Skin.Originals[part] = {
			Material = part.Material, Color = part.Color, Reflectance = part.Reflectance,
			TextureID = part:IsA("MeshPart") and part.TextureID or nil,
		}
	end

	local color, material, texture = computeDesired(cat, part)
	if texture then applyTexture(part, texture) else clearSkinChildren(part) restoreSA(part) end
	if color then part.Color = color end
	if material then part.Material = material end

	local d = Skin.Desired[part] or {}
	d.Color = color
	d.Material = material
	d.Texture = texture
	d.Cat = cat
	Skin.Desired[part] = d

	if Skin.Particles then
		local p = part:FindFirstChild("SleepParticles")
		if not p then
			p = New("ParticleEmitter", {
				Name = "SleepParticles", Rate = 10, Lifetime = NumberRange.new(0.3, 0.7),
				Speed = NumberRange.new(0.2, 0.8), Size = NumberSequence.new(0.15),
				LightEmission = 1, LightInfluence = 0,
				Texture = "rbxasset://textures/particles/sparkles_main.dds",
			}, part)
		end
		p.Color = ColorSequence.new(part.Color)
		p.Enabled = true
	else
		local p = part:FindFirstChild("SleepParticles")
		if p then p.Enabled = false end
	end
end

local function restorePart(part)
	local o = Skin.Originals[part]
	if o then
		pcall(function()
			part.Material = o.Material
			part.Color = o.Color
			part.Reflectance = o.Reflectance
			if o.TextureID and part:IsA("MeshPart") then part.TextureID = o.TextureID end
		end)
	end
	clearSkinChildren(part)
	restoreSA(part)
	local p = part:FindFirstChild("SleepParticles")
	if p then p.Enabled = false end
	Skin.Desired[part] = nil
end

local function isViewModel(m)
	if not m:IsA("Model") then return false end
	if m.Parent == Workspace.CurrentCamera then return true end
	local n = m.Name:lower()
	return n:find("view") or n:find("worldmodel") or n:find("arms") or n:find("hands")
		or n:find("weapon") or n:find("fps") or n:find("tool")
end

local function collectParts()
	local out = {}
	local cam = Workspace.CurrentCamera
	if cam then
		for _, c in ipairs(cam:GetChildren()) do
			if c:IsA("BasePart") then
				out[#out + 1] = { part = c, model = c, inChar = false }
			elseif c:IsA("Model") or c:IsA("Folder") then
				for _, d in ipairs(c:GetDescendants()) do
					if d:IsA("BasePart") then out[#out + 1] = { part = d, model = c, inChar = false } end
				end
			end
		end
	end
	for _, c in ipairs(Workspace:GetChildren()) do
		if isViewModel(c) then
			for _, d in ipairs(c:GetDescendants()) do
				if d:IsA("BasePart") then out[#out + 1] = { part = d, model = c, inChar = false } end
			end
		end
	end
	local char = LocalPlayer.Character
	if char then
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then out[#out + 1] = { part = d, model = char, inChar = true } end
		end
	end
	return out
end

local function scanForParts()
	if not Skin.Enabled then return end
	for _, e in ipairs(collectParts()) do
		if not Skin.Tracked[e.part] then
			Skin.Tracked[e.part] = true
			local det = detectWeapon(e.model)
			if det then Skin.Detected = det end
		end
		stylePart(e.part, e.model, e.inChar)
	end
end
Skin.Scan = scanForParts

local function restyleAll()
	for part, d in pairs(Skin.Desired) do
		if not part.Parent then
			Skin.Desired[part] = nil
			Skin.Tracked[part] = nil
			Skin.Originals[part] = nil
		end
	end
	if Skin.Enabled then scanForParts() end
end
Skin.Restyle = restyleAll

local function clearAll()
	for part in pairs(Skin.Originals) do
		if part and part.Parent then restorePart(part) end
	end
	Skin.Originals = {}
	Skin.Desired = {}
	Skin.Tracked = {}
end
Skin.ClearAll = clearAll

-- per-frame re-apply (fights the game resetting values)
local function enforceDesired()
	if not Skin.Enabled then return end
	for part, d in pairs(Skin.Desired) do
		if part.Parent then
			if d.Color and part.Color ~= d.Color then part.Color = d.Color end
			if d.Material and part.Material ~= d.Material then part.Material = d.Material end
			if d.Texture and part:IsA("MeshPart") and part.TextureID ~= d.Texture then
				pcall(function() part.TextureID = d.Texture end)
			end
		end
	end
end
Skin.Enforce = enforceDesired

Conn(Workspace.CurrentCamera.ChildAdded, function(i)
	if Skin.Enabled and isViewModel(i) then scanForParts() end
end)
Conn(Workspace.ChildAdded, function(i)
	if Skin.Enabled and isViewModel(i) then scanForParts() end
end)

--=====================================================================
-- 10. MOVEMENT (bhop + strafe accel)
--=====================================================================
local Move = {
	Bhop = false, InfJump = false, HoldingSpace = false,
	AirStrafe = true, StrafeAccel = 55, MaxSpeed = 55, AutoStrafe = false,
	SpeedEnabled = false, WalkSpeed = 16,
	JumpEnabled = false, JumpPower = 50,
	Sprint = false, SprintKey = "LeftShift", SprintSpeed = 24, Sprinting = false,
	Fly = false,
}
SleepScript.Move = Move

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function getVel(p)
	local ok, v = pcall(function() return p.AssemblyLinearVelocity end)
	if ok and v then return v end
	return p.Velocity
end
local function setVel(p, v)
	local ok = pcall(function() p.AssemblyLinearVelocity = v end)
	if not ok then pcall(function() p.Velocity = v end) end
end

local function isGrounded(hum, hrp)
	if hum.FloorMaterial ~= Enum.Material.Air then return true end
	if not hrp then return false end
	local char = LocalPlayer.Character
	rayParams.FilterDescendantsInstances = char and { char } or {}
	local res = Workspace:Raycast(hrp.Position, Vector3.new(0, -6, 0), rayParams)
	return res ~= nil and (hrp.Position.Y - res.Position.Y) <= 5.0
end

local function doJump(hum)
	pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
	hum.Jump = true
end

Conn(UserInputService.InputBegan, function(i)
	if i.KeyCode == Enum.KeyCode.Space then Move.HoldingSpace = true end
	if i.KeyCode.Name == Move.SprintKey then Move.Sprinting = true end
end)
Conn(UserInputService.InputEnded, function(i)
	if i.KeyCode == Enum.KeyCode.Space then Move.HoldingSpace = false end
	if i.KeyCode.Name == Move.SprintKey then Move.Sprinting = false end
end)

local baseWalkSpeed = 16
local function hookHumanoid()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	baseWalkSpeed = hum.WalkSpeed
	Conn(hum.StateChanged, function(_, new)
		if not Move.Bhop or not Move.HoldingSpace then return end
		if new == Enum.HumanoidStateType.Landed then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp and isGrounded(hum, hrp) then doJump(hum) end
		end
	end)
end

local bhopCD = 0
local autoDir = 1
local autoTimer = 0

Conn(RunService.Heartbeat, function(dt)
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local airborne = not isGrounded(hum, hrp)

	--// AUTO JUMP on landing
	if Move.Bhop and Move.HoldingSpace and not airborne and os.clock() >= bhopCD then
		doJump(hum)
		bhopCD = os.clock() + 0.05
	end

	--// AIR STRAFE ACCEL (speed build-up)
	if Move.Bhop and Move.AirStrafe and Move.HoldingSpace and airborne and hrp then
		local cam = Workspace.CurrentCamera
		if cam then
			local wish = Vector3.zero
			local a = UserInputService:IsKeyDown(Enum.KeyCode.A)
			local d = UserInputService:IsKeyDown(Enum.KeyCode.D)
			if a and not d then wish = -cam.CFrame.RightVector
			elseif d and not a then wish = cam.CFrame.RightVector
			elseif Move.AutoStrafe then
				autoTimer = autoTimer + dt
				if autoTimer > 0.35 then autoTimer = 0 autoDir = -autoDir end
				wish = cam.CFrame.RightVector * autoDir
			end
			if wish.Magnitude > 0.01 then
				wish = wish.Unit
				local vel = getVel(hrp)
				local horiz = Vector3.new(vel.X, 0, vel.Z)
				local proj = horiz:Dot(wish)
				local addSpeed = Move.StrafeAccel * dt
				local accel = math.min(addSpeed, math.max(Move.MaxSpeed - proj, 0))
				if accel > 0 then
					local nv = vel + wish * accel
					local hv = Vector3.new(nv.X, 0, nv.Z)
					if hv.Magnitude > Move.MaxSpeed * 1.6 then
						local s = (Move.MaxSpeed * 1.6) / hv.Magnitude
						nv = Vector3.new(nv.X * s, nv.Y, nv.Z * s)
					end
					setVel(hrp, nv)
				end
			end
		end
	end

	--// airborne WalkSpeed override so the controller doesn't brake us
	if Move.Bhop and Move.HoldingSpace and airborne then
		if hum.WalkSpeed ~= Move.MaxSpeed then hum.WalkSpeed = Move.MaxSpeed end
	elseif Move.SpeedEnabled then
		local target = Move.WalkSpeed
		if Move.Sprint and Move.Sprinting then target = Move.SprintSpeed end
		if math.abs(hum.WalkSpeed - target) > 0.1 then hum.WalkSpeed = target end
	elseif Move.Bhop and hum.WalkSpeed ~= baseWalkSpeed then
		hum.WalkSpeed = baseWalkSpeed
	end

	if Move.InfJump and Move.HoldingSpace then
		if hum:GetState() == Enum.HumanoidStateType.Freefall then doJump(hum) end
	end

	if Move.JumpEnabled and math.abs(hum.JumpPower - Move.JumpPower) > 0.1 then hum.JumpPower = Move.JumpPower end
end)

--// FLY
local flyBV, flyBG
local function stopFly()
	if flyBV then flyBV:Destroy() flyBV = nil end
	if flyBG then flyBG:Destroy() flyBG = nil end
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then setVel(hrp, Vector3.zero) end
end
Conn(RunService.RenderStepped, function()
	if not Move.Fly then return end
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	if not flyBV then
		flyBV = New("BodyVelocity", { Name = "SleepFly", MaxForce = Vector3.new(1, 1, 1) * 1e5, P = 1250 }, hrp)
		flyBG = New("BodyGyro", { Name = "SleepFlyGyro", MaxTorque = Vector3.new(1, 1, 1) * 1e5, P = 1000, D = 50, CFrame = hrp.CFrame }, hrp)
	end
	local cam = Workspace.CurrentCamera
	local speed = 60 * (Move.Sprinting and 2 or 1)
	local dir = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
	if dir.Magnitude > 0 then dir = dir.Unit end
	flyBV.Velocity = dir * speed
	flyBG.CFrame = cam.CFrame
end)
Move.StopFly = stopFly

--=====================================================================
-- 11. VISUALS / SKY (fixed: edits existing Sky)
--=====================================================================
local Sky = { Enabled = false, Preset = "Space", KillAtmosphere = true, Backup = nil }
SleepScript.Sky = Sky

local function getSky()
	local s = Lighting:FindFirstChildOfClass("Sky")
	if s then return s, false end
	return New("Sky", { Name = "SleepSky" }, Lighting), true
end

local function backupSky(sky, created)
	if Sky.Backup then return end
	Sky.Backup = {
		sky = sky, created = created,
		Bk = sky.SkyboxBk, Dn = sky.SkyboxDn, Ft = sky.SkyboxFt,
		Lf = sky.SkyboxLf, Rt = sky.SkyboxRt, Up = sky.SkyboxUp,
		Stars = sky.StarCount, Bodies = sky.CelestialBodiesShown,
		ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness,
	}
end

local function killAtmosphere(on)
	for _, a in ipairs(Lighting:GetChildren()) do
		if a:IsA("Atmosphere") then
			if on then
				if not a:GetAttribute("SleepDensity") then
					a:SetAttribute("SleepDensity", a.Density)
					a:SetAttribute("SleepHaze", a.Haze)
				end
				a.Density = math.min(a.Density, 0.05)
				a.Haze = math.min(a.Haze, 0.3)
			else
				if a:GetAttribute("SleepDensity") then
					a.Density = a:GetAttribute("SleepDensity")
					a.Haze = a:GetAttribute("SleepHaze")
				end
			end
		end
	end
end

local function applySkyPreset(name)
	local sky, created = getSky()
	if not sky then return end
	backupSky(sky, created)
	if name == "Game Default" then
		sky.SkyboxBk, sky.SkyboxDn, sky.SkyboxFt = Sky.Backup.Bk, Sky.Backup.Dn, Sky.Backup.Ft
		sky.SkyboxLf, sky.SkyboxRt, sky.SkyboxUp = Sky.Backup.Lf, Sky.Backup.Rt, Sky.Backup.Up
		sky.StarCount = Sky.Backup.Stars
		sky.CelestialBodiesShown = Sky.Backup.Bodies
		Lighting.ClockTime = Sky.Backup.ClockTime
		Lighting.Brightness = Sky.Backup.Brightness
		killAtmosphere(false)
		return
	end
	local p = SKY_PRESETS[name]
	if type(p) ~= "table" then return end
	if p.all then
		sky.SkyboxBk, sky.SkyboxDn, sky.SkyboxFt = p.all, p.all, p.all
		sky.SkyboxLf, sky.SkyboxRt, sky.SkyboxUp = p.all, p.all, p.all
	else
		sky.SkyboxBk, sky.SkyboxDn, sky.SkyboxFt = p.Bk, p.Dn, p.Ft
		sky.SkyboxLf, sky.SkyboxRt, sky.SkyboxUp = p.Lf, p.Rt, p.Up
	end
	sky.StarCount = 6000
	sky.CelestialBodiesShown = false
	Lighting.ClockTime = 14
	if Lighting.Brightness < 2 then Lighting.Brightness = 2 end
	if Sky.KillAtmosphere then killAtmosphere(true) end
end
Sky.Apply = applySkyPreset

function Sky.SetCustom(id)
	local u = "rbxassetid://" .. tostring(id):gsub("%D", "")
	local sky = getSky()
	if not sky then return end
	backupSky(sky, false)
	sky.SkyboxBk, sky.SkyboxDn, sky.SkyboxFt = u, u, u
	sky.SkyboxLf, sky.SkyboxRt, sky.SkyboxUp = u, u, u
	sky.StarCount = 6000
	sky.CelestialBodiesShown = false
	Lighting.ClockTime = 14
end

function Sky.Restore()
	if not Sky.Backup then return end
	local sky = Sky.Backup.sky
	if Sky.Backup.created and sky and sky.Parent then
		sky:Destroy()
	elseif sky and sky.Parent then
		sky.SkyboxBk, sky.SkyboxDn, sky.SkyboxFt = Sky.Backup.Bk, Sky.Backup.Dn, Sky.Backup.Ft
		sky.SkyboxLf, sky.SkyboxRt, sky.SkyboxUp = Sky.Backup.Lf, Sky.Backup.Rt, Sky.Backup.Up
		sky.StarCount = Sky.Backup.Stars
		sky.CelestialBodiesShown = Sky.Backup.Bodies
	end
	Lighting.ClockTime = Sky.Backup.ClockTime
	Lighting.Brightness = Sky.Backup.Brightness
	killAtmosphere(false)
	Sky.Backup = nil
end

Conn(Lighting.ChildAdded, function(c)
	if c:IsA("Sky") and Sky.Enabled then
		task.wait(0.2)
		applySkyPreset(Sky.Preset)
	end
end)

--// other visuals
local Vis = { Atmosphere = false, Bloom = false, Fullbright = false, Aura = false }
SleepScript.Vis = Vis
local fbBackup
local function setFullbright(on)
	if on then
		fbBackup = {
			Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
			Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
		}
		Lighting.Ambient = Color3.fromRGB(180, 180, 180)
		Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
		Lighting.Brightness = 2
	elseif fbBackup then
		for k, v in pairs(fbBackup) do Lighting[k] = v end
	end
end
local auraEmitter
local function setAura(on)
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	if on then
		if not auraEmitter or not auraEmitter.Parent then
			auraEmitter = New("ParticleEmitter", {
				Name = "SleepAura", Rate = 30, Lifetime = NumberRange.new(0.6, 1.2),
				Speed = NumberRange.new(1, 3), Size = NumberSequence.new(0.3),
				LightEmission = 1, LightInfluence = 0, Rotation = NumberRange.new(0, 360),
				Texture = "rbxasset://textures/particles/sparkles_main.dds",
				Color = ColorSequence.new(Theme.Accent),
			}, hrp)
		end
		auraEmitter.Enabled = true
	elseif auraEmitter then
		auraEmitter.Enabled = false
	end
end

--=====================================================================
-- 12. OVERLAY
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
	BackgroundColor3 = Theme.Bg, BackgroundTransparency = 0.15, BorderSizePixel = 0,
}, OverlayGui)
Corner(oFrame, 10)
Stroke(oFrame, Theme.Stroke, 1, 0.55)
Pad(oFrame, 8, 10, 8, 10)
local oTitle = New("TextLabel", {
	Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
	TextSize = 11, Text = "SleepScript  •  stats", TextColor3 = Theme.Accent,
	TextXAlignment = Enum.TextXAlignment.Left,
}, oFrame)
RegisterAccent(oTitle, "TextColor3")
local function statRow(name, y)
	New("TextLabel", {
		Size = UDim2.new(0.5, 0, 0, 14), Position = UDim2.new(0, 0, 0, y),
		BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11, Text = name,
		TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Left,
	}, oFrame)
	return New("TextLabel", {
		Size = UDim2.new(0.5, 0, 0, 14), Position = UDim2.new(0.5, 0, 0, y),
		BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 11, Text = "0",
		TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Right,
	}, oFrame)
end
local fpsLbl = statRow("FPS", 18)
local pingLbl = statRow("PING", 34)
local memLbl = statRow("MEM", 50)
do
	local dragging, ds, sp = false, nil, nil
	oFrame.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, ds, sp = true, i.Position, oFrame.Position
		end
	end)
	Conn(UserInputService.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
	Conn(UserInputService.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - ds
			oFrame.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
		end
	end)
end
do
	local frames, last = 0, os.clock()
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
				ok, ping = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
			end
			Overlay.Ping = ok and ping or 0
			local ok2, mem = pcall(function() return Stats:GetTotalMemoryUsageMb() end)
			Overlay.Mem = ok2 and mem or 0
			fpsLbl.Text = string.format("%d", math.floor(Overlay.FPS + 0.5))
			fpsLbl.TextColor3 = Overlay.FPS >= 50 and Theme.Good or (Overlay.FPS >= 30 and Theme.Warn or Theme.Bad)
			pingLbl.Text = string.format("%d ms", math.floor(Overlay.Ping + 0.5))
			pingLbl.TextColor3 = Overlay.Ping <= 80 and Theme.Good or (Overlay.Ping <= 160 and Theme.Warn or Theme.Bad)
			memLbl.Text = string.format("%d MB", math.floor(Overlay.Mem))
			task.wait(0.5)
		end
	end)
end
function Overlay:Toggle(s) self.Visible = s oFrame.Visible = s end

--=====================================================================
-- 13. FPS BOOST (reworked, granular + full restore)
--=====================================================================
local Perf = {
	Master = false,
	Shadows = true, PostFX = true, Terrain = true, Fog = false,
	Particles = false, Decals = false, CastShadow = false,
	Quality = "Keep",
	Backup = nil, Hidden = {},
}
SleepScript.Perf = Perf

local function restorePerf()
	if Perf.Backup then
		local b = Perf.Backup
		pcall(function()
			Lighting.GlobalShadows = b.GlobalShadows
			Lighting.FogEnd = b.FogEnd
			Lighting.EnvironmentDiffuseScale = b.EnvironmentDiffuseScale
			Lighting.EnvironmentSpecularScale = b.EnvironmentSpecularScale
			Workspace.Terrain.Decoration = b.Decoration
			Workspace.Terrain.WaterWaveSize = b.WaterWaveSize
			Workspace.Terrain.WaterWaveSpeed = b.WaterWaveSpeed
			Workspace.Terrain.WaterReflectance = b.WaterReflectance
			Workspace.Terrain.WaterTransparency = b.WaterTransparency
			if b.Quality then settings().Rendering.QualityLevel = b.Quality end
		end)
		for _, e in ipairs(Lighting:GetChildren()) do
			if e:GetAttribute("SleepWasEnabled") ~= nil then
				pcall(function()
					e.Enabled = e:GetAttribute("SleepWasEnabled")
					e:SetAttribute("SleepWasEnabled", nil)
				end)
			end
		end
	end
	for _, e in ipairs(Perf.Hidden) do
		if e.inst and e.inst.Parent then pcall(function() e.inst[e.prop] = e.value end) end
	end
	Perf.Hidden = {}
	Perf.Backup = nil
end

local function applyPerf()
	restorePerf()
	if not Perf.Master then return end
	local L = Lighting
	Perf.Backup = {
		GlobalShadows = L.GlobalShadows, FogEnd = L.FogEnd,
		EnvironmentDiffuseScale = L.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = L.EnvironmentSpecularScale,
		Decoration = Workspace.Terrain.Decoration,
		WaterWaveSize = Workspace.Terrain.WaterWaveSize,
		WaterWaveSpeed = Workspace.Terrain.WaterWaveSpeed,
		WaterReflectance = Workspace.Terrain.WaterReflectance,
		WaterTransparency = Workspace.Terrain.WaterTransparency,
		Quality = (function()
			local ok, v = pcall(function() return settings().Rendering.QualityLevel end)
			return ok and v or nil
		end)(),
	}
	if Perf.Shadows then
		L.GlobalShadows = false
		L.EnvironmentDiffuseScale = 0
		L.EnvironmentSpecularScale = 0
	end
	if Perf.Fog then L.FogEnd = 100000 end
	if Perf.Terrain then
		Workspace.Terrain.Decoration = false
		Workspace.Terrain.WaterWaveSize = 0
		Workspace.Terrain.WaterWaveSpeed = 0
		Workspace.Terrain.WaterReflectance = 0
		Workspace.Terrain.WaterTransparency = 1
	end
	if Perf.PostFX then
		for _, e in ipairs(L:GetChildren()) do
			if e:IsA("PostEffect") then
				e:SetAttribute("SleepWasEnabled", e.Enabled)
				e.Enabled = false
			end
		end
	end
	if Perf.Quality ~= "Keep" then
		local lvl = Perf.Quality == "Auto" and Enum.QualityLevel.Automatic
			or Enum.QualityLevel["Level" .. (Perf.Quality:len() == 1 and ("0" .. Perf.Quality) or Perf.Quality)]
		pcall(function() settings().Rendering.QualityLevel = lvl end)
	end
	if Perf.Particles or Perf.Decals or Perf.CastShadow then
		local n = 0
		for _, d in ipairs(Workspace:GetDescendants()) do
			n = n + 1
			if n > 25000 then break end
			if Perf.Particles and d:IsA("ParticleEmitter") and not d:GetAttribute("SleepOwn") then
				table.insert(Perf.Hidden, { inst = d, prop = "Enabled", value = d.Enabled })
				d.Enabled = false
			elseif Perf.Decals and (d:IsA("Decal") or d:IsA("Texture")) then
				table.insert(Perf.Hidden, { inst = d, prop = "Transparency", value = d.Transparency })
				d.Transparency = 1
			elseif Perf.CastShadow and d:IsA("BasePart") and d.CastShadow then
				table.insert(Perf.Hidden, { inst = d, prop = "CastShadow", value = true })
				d.CastShadow = false
			end
		end
	end
end
Perf.Apply = applyPerf
Perf.Restore = restorePerf

--=====================================================================
-- 14. BYPASS
--=====================================================================
local Bypass = { AntiKick = false, AntiVoid = false, AntiAfk = true, AntiRevert = false }
SleepScript.Bypass = Bypass
local function installAntiKick()
	local ok = pcall(function()
		local mt = getrawmetatable(game)
		if not mt or mt.__namecall == nil then error("no mt") end
		setreadonly(mt, false)
		local old = mt.__namecall
		mt.__namecall = newcclosure(function(self, ...)
			if getnamecallmethod() == "Kick" and self == LocalPlayer and Bypass.AntiKick then
				local a = { ... }
				Notify("Anti-Kick", tostring(a[1] or "kicked"), 4)
				return nil
			end
			return old(self, ...)
		end)
		setreadonly(mt, true)
	end)
	if not ok then Notify("Hook", "namecall hook unavailable", 3) end
end
local lastSafe
Conn(RunService.Heartbeat, function()
	if not Bypass.AntiVoid then return end
	local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	if hrp.Position.Y > -50 then lastSafe = hrp.CFrame
	elseif lastSafe then hrp.CFrame = lastSafe + Vector3.new(0, 8, 0) setVel(hrp, Vector3.zero) end
end)
Conn(LocalPlayer.Idled, function()
	if not Bypass.AntiAfk then return end
	VirtualUser:Button2Down(Vector2.zero, Workspace.CurrentCamera.CFrame)
	task.wait(1)
	VirtualUser:Button2Up(Vector2.zero, Workspace.CurrentCamera.CFrame)
end)

--=====================================================================
-- 15. HELPERS
--=====================================================================
local function deepScan()
	print("===== SleepScript Deep Scan =====")
	local r, w, s = {}, {}, {}
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
		local n = d.Name:lower()
		if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction"))
			and (n:find("skin") or n:find("equip") or n:find("apply") or n:find("inventory")) then
			r[#r + 1] = d:GetFullName()
		end
		if d:IsA("Model") and (n:find("knife") or n:find("glove") or n:find("gun")
			or n:find("weapon") or n:find("ak") or n:find("m4") or n:find("awp")) then
			w[#w + 1] = d:GetFullName()
		end
	end
	for _, v in ipairs(r) do print("  REMOTE >", v) end
	for _, v in ipairs(w) do print("  MODEL  >", v) end
	print("===== End =====")
	Notify("Deep Scan", #r .. " remotes / " .. #w .. " models", 4)
end

--=====================================================================
-- 16. CONFIG
--=====================================================================
local ConfigName = "SleepScript_BloxStrike.json"
local function saveConfig()
	local ok = pcall(function()
		writefile(ConfigName, HttpService:JSONEncode({
			ESP = { Enabled = ESP.Enabled, MaxDistance = ESP.MaxDistance, TeamCheck = ESP.TeamCheck },
			Move = { Bhop = Move.Bhop, StrafeAccel = Move.StrafeAccel, MaxSpeed = Move.MaxSpeed },
			FOV = { Enabled = FOV.Enabled, Value = FOV.Value },
		}))
	end)
	Notify("Config", ok and "saved" or "writefile unavailable", 2)
end
local function loadConfig()
	if not (isfile and isfile(ConfigName)) then Notify("Config", "no config", 2) return end
	local ok, d = pcall(function() return HttpService:JSONDecode(readfile(ConfigName)) end)
	if not ok then Notify("Config", "read error", 2) return end
	if d.ESP then
		ESP.MaxDistance = d.ESP.MaxDistance or 2500
		ESP.TeamCheck = d.ESP.TeamCheck or false
		if d.ESP.Enabled then ESP.Enabled = true refreshESP() end
	end
	if d.Move then
		Move.StrafeAccel = d.Move.StrafeAccel or 55
		Move.MaxSpeed = d.Move.MaxSpeed or 55
		Move.Bhop = d.Move.Bhop or false
	end
	if d.FOV then FOV.Value = d.FOV.Value or 100 if d.FOV.Enabled then FOV.Enabled = true end end
	Notify("Config", "loaded", 2)
end

--=====================================================================
-- 17. MENU
--=====================================================================
local Window = Lib:Window({ Title = "SleepScript", Subtitle = "bloxstrike edition  •  v" .. SleepScript.Version })
local Tabs = {
	Visuals  = Window.MakeTab("Visuals", "◈"),
	Skin     = Window.MakeTab("SkinChanger", "✦"),
	Movement = Window.MakeTab("Movement", "➤"),
	Perf     = Window.MakeTab("FPS Boost", "⚡"),
	Misc     = Window.MakeTab("Misc", "⚙"),
	Settings = Window.MakeTab("Settings", "✱"),
}

--// VISUALS
do
	local t = Tabs.Visuals.Content
	Section(t, "ESP / Wallhack")
	local dbg = Label(t, "targets tracked: 0")
	Toggle(t, { Text = "Enable ESP", Default = false, Callback = function(v)
		ESP.Enabled = v
		if v then refreshESP() end
	end })
	Toggle(t, { Text = "3D Boxes (through walls)", Default = true, Callback = function(v) ESP.Boxes = v end })
	Toggle(t, { Text = "Chams (Highlight)", Default = true, Callback = function(v) ESP.Chams = v end })
	Toggle(t, { Text = "Names", Default = true, Callback = function(v) ESP.Names = v end })
	Toggle(t, { Text = "Health Bar", Default = true, Callback = function(v) ESP.Health = v end })
	Toggle(t, { Text = "Distance", Default = true, Callback = function(v) ESP.Distance = v end })
	Toggle(t, { Text = "Weapon", Default = true, Callback = function(v) ESP.Weapon = v end })
	Toggle(t, { Text = "Team Check", Default = false, Callback = function(v) ESP.TeamCheck = v end })
	Toggle(t, { Text = "Team Colors", Default = true, Callback = function(v) ESP.UseTeamColor = v end })
	Slider(t, { Text = "Max Distance", Min = 100, Max = 5000, Default = 2500, Callback = function(v) ESP.MaxDistance = v end })
	Slider(t, { Text = "Box Transparency", Min = 0, Max = 1, Default = 0.35, Decimals = 2, Callback = function(v) ESP.BoxTransparency = v end })
	Slider(t, { Text = "Chams Fill", Min = 0, Max = 1, Default = 0.25, Decimals = 2, Callback = function(v) ESP.FillAlpha = v end })
	Button(t, { Text = "Refresh ESP targets", Callback = function()
		refreshESP()
		Notify("ESP", "tracked: " .. ESP.Debug, 2)
	end })

	Section(t, "Field Of View")
	Toggle(t, { Text = "Custom FOV", Default = false, Callback = function(v)
		if v then
			local cam = Workspace.CurrentCamera
			if cam and not FOV.Original then FOV.Original = cam.FieldOfView end
		end
		FOV.Enabled = v
		if not v then FOV:Reset() end
	end })
	Slider(t, { Text = "FOV Value", Min = 40, Max = 140, Default = 100, Callback = function(v) FOV.Value = v end })
	Button(t, { Text = "Reset FOV", Callback = function() FOV:Reset() end })

	Section(t, "Custom Sky")
	local skyStatus = Label(t, "sky: game default")
	local function updSky() skyStatus.Text = "sky: " .. (Sky.Enabled and Sky.Preset or "game default") end
	Toggle(t, { Text = "Enable Custom Sky", Default = false, Callback = function(v)
		Sky.Enabled = v
		if v then Sky.Apply(Sky.Preset) else Sky.Restore() end
		updSky()
	end })
	Dropdown(t, { Text = "Sky Preset", Options = { "Space", "Night", "Nebula", "Void", "Classic Roblox", "Game Default" },
		Default = "Space", Callback = function(v)
			Sky.Preset = v
			if Sky.Enabled then Sky.Apply(v) end
			updSky()
		end })
	Toggle(t, { Text = "Kill Atmosphere haze (recommended)", Default = true, Callback = function(v)
		Sky.KillAtmosphere = v
		if Sky.Enabled then Sky.Apply(Sky.Preset) end
	end })
	Button(t, { Text = "Apply Sky ID from clipboard (all 6 faces)", Callback = function()
		local ok, clip = pcall(function() return getclipboard() end)
		if ok and clip and clip ~= "" then
			Sky.SetCustom(clip)
			Notify("Sky", "applied: " .. clip, 3)
		else
			Notify("Sky", "clipboard empty", 3)
		end
	end })
	Button(t, { Text = "Restore game sky", Callback = function()
		Sky.Restore()
		updSky()
		Notify("Sky", "restored", 2)
	end })
	Label(t, "If the sky still looks dark: enable Fullbright below (some maps set night).")

	Section(t, "Other visuals")
	Toggle(t, { Text = "Fullbright", Default = false, Callback = setFullbright })
	Toggle(t, { Text = "Extra Atmosphere haze", Default = false, Callback = function(v)
		if v then
			if not Vis.Atm then
				Vis.Atm = New("Atmosphere", { Density = 0.35, Haze = 1.5, Glare = 0.2 }, Lighting)
			end
			Vis.Atm.Parent = Lighting
		elseif Vis.Atm then
			Vis.Atm.Parent = nil
		end
	end })
	Toggle(t, { Text = "Bloom", Default = false, Callback = function(v)
		if v then
			if not Vis.BloomFx then
				Vis.BloomFx = New("BloomEffect", { Intensity = 1.2, Size = 24, Threshold = 0.9 }, Lighting)
			end
			Vis.BloomFx.Enabled = true
		elseif Vis.BloomFx then
			Vis.BloomFx.Enabled = false
		end
	end })
	Toggle(t, { Text = "Player Aura Particles", Default = false, Callback = setAura })
	Slider(t, { Text = "Time Of Day", Min = 0, Max = 24, Default = 14, Callback = function(v) Lighting.ClockTime = v end })
end

--// SKIN
do
	local t = Tabs.Skin.Content
	local status = Label(t, "detected: -   library: not scanned")
	local function updStatus()
		local n = 0
		for _, cat in pairs(Skin.Library) do for _ in pairs(cat) do n = n + 1 end end
		status.Text = string.format("detected: %s   |   game skin textures found: %d", Skin.Detected, n)
	end

	Toggle(t, { Text = "Enable SkinChanger (master)", Default = false, Callback = function(v)
		Skin.Enabled = v
		if v then scanForParts() else clearAll() end
	end })
	Button(t, { Text = "Rescan Game Skin Files", Callback = function()
		local n = buildLibrary()
		for cat, _ in pairs(Skin.Categories) do
			if Skin.Dropdowns and Skin.Dropdowns[cat] then
				Skin.Dropdowns[cat]:SetOptions(skinOptions(cat))
			end
		end
		updStatus()
		Notify("Skin", "found " .. n .. " textures in game files", 3)
	end })
	Button(t, { Text = "Rescan ViewModel", Callback = function()
		Skin.Tracked = {}
		scanForParts()
		Notify("Skin", "viewmodel rescanned", 2)
	end })

	Skin.Dropdowns = {}
	local function buildCategory(cat, title, weaponList)
		Section(t, title)
		Toggle(t, { Text = "Apply to " .. cat .. "s", Default = true, Callback = function(v)
			Skin.Categories[cat].Enabled = v
			restyleAll()
		end })
		Dropdown(t, { Text = "Weapon", Options = (function()
			local o = { "Auto (equipped)" }
			for _, w in ipairs(weaponList) do o[#o + 1] = w end
			return o
		end)(), Default = "Auto (equipped)", Callback = function(v)
			Skin.Categories[cat].Weapon = v
			restyleAll()
		end })
		local dd = Dropdown(t, { Text = "Skin", Options = skinOptions(cat), Default = "None", Callback = function(v)
			Skin.Categories[cat].Skin = v
			restyleAll()
			Notify("Skin", cat .. " -> " .. v, 2)
		end })
		Skin.Dropdowns[cat] = dd
		Dropdown(t, { Text = "Color", Options = (function()
			local o = { "Keep" }
			local k = {}
			for c in pairs(COLOR_LOOKUP) do k[#k + 1] = c end
			table.sort(k)
			for _, c in ipairs(k) do o[#o + 1] = c end
			return o
		end)(), Default = "Keep", Callback = function(v)
			Skin.Categories[cat].Color = v
			restyleAll()
		end })
		Dropdown(t, { Text = "Material", Options = MATERIALS, Default = "Keep", Callback = function(v)
			Skin.Categories[cat].Material = v
			restyleAll()
		end })
	end

	buildCategory("Knife", "Knives", KNIVES)
	buildCategory("Gun", "Weapons", WEAPONS)
	buildCategory("Glove", "Gloves", GLOVES)

	Section(t, "Extras")
	Toggle(t, { Text = "Particles on skins", Default = false, Callback = function(v) Skin.Particles = v restyleAll() end })
	Toggle(t, { Text = "Deep apply (copy mesh from game model)", Default = false, Callback = function(v)
		Skin.DeepMesh = v
		restyleAll()
	end })
	Button(t, { Text = "Apply now", Callback = function() restyleAll() Notify("Skin", "reapplied", 2) end })
	Button(t, { Text = "Clear / restore originals", Callback = function() clearAll() Notify("Skin", "restored", 2) end })
	Label(t, "★ = built-in skin (always visible). Others are real textures found in game files.")
	updStatus()
end

--// MOVEMENT
do
	local t = Tabs.Movement.Content
	Section(t, "Bunny Hop + Strafe")
	Toggle(t, { Text = "Auto BunnyHop (hold Space)", Default = false, Callback = function(v) Move.Bhop = v end })
	Toggle(t, { Text = "Air Strafe Speed Gain", Default = true, Callback = function(v) Move.AirStrafe = v end })
	Slider(t, { Text = "Strafe Acceleration", Min = 10, Max = 150, Default = 55, Callback = function(v) Move.StrafeAccel = v end })
	Slider(t, { Text = "Max Speed", Min = 20, Max = 120, Default = 55, Callback = function(v) Move.MaxSpeed = v end })
	Toggle(t, { Text = "Auto Strafe (no A/D needed)", Default = false, Callback = function(v) Move.AutoStrafe = v end })
	Label(t, "Hold Space + strafe with A/D while airborne — speed builds up every hop.")
	Toggle(t, { Text = "Infinite Jump", Default = false, Callback = function(v) Move.InfJump = v end })

	Section(t, "Speed")
	Toggle(t, { Text = "Custom WalkSpeed", Default = false, Callback = function(v) Move.SpeedEnabled = v end })
	Slider(t, { Text = "WalkSpeed", Min = 8, Max = 200, Default = 16, Callback = function(v) Move.WalkSpeed = v end })
	Toggle(t, { Text = "Custom JumpPower", Default = false, Callback = function(v) Move.JumpEnabled = v end })
	Slider(t, { Text = "JumpPower", Min = 20, Max = 300, Default = 50, Callback = function(v) Move.JumpPower = v end })
	Section(t, "Sprint / Fly")
	Toggle(t, { Text = "Sprint on Hold", Default = false, Callback = function(v) Move.Sprint = v end })
	Keybind(t, { Text = "Sprint Key", Default = "LeftShift", Callback = function(k) Move.SprintKey = k end })
	Slider(t, { Text = "Sprint Speed", Min = 18, Max = 120, Default = 24, Callback = function(v) Move.SprintSpeed = v end })
	Toggle(t, { Text = "Fly (WASD + Space/Ctrl)", Default = false, Callback = function(v)
		Move.Fly = v
		if not v then stopFly() end
	end })
end

--// FPS BOOST
do
	local t = Tabs.Perf.Content
	Section(t, "FPS Boost")
	Toggle(t, { Text = "Enable FPS Boost (master)", Default = false, Callback = function(v)
		Perf.Master = v
		applyPerf()
		Notify("Performance", v and "boost applied" or "restored", 2)
	end })
	Label(t, "Sub-options apply only while master is on. Everything is restored on disable/unload.")
	Toggle(t, { Text = "Disable Global Shadows", Default = true, Callback = function(v) Perf.Shadows = v applyPerf() end })
	Toggle(t, { Text = "Disable Post-Processing", Default = true, Callback = function(v) Perf.PostFX = v applyPerf() end })
	Toggle(t, { Text = "Disable Terrain / Water", Default = true, Callback = function(v) Perf.Terrain = v applyPerf() end })
	Toggle(t, { Text = "Unlimited Fog End", Default = false, Callback = function(v) Perf.Fog = v applyPerf() end })
	Toggle(t, { Text = "Disable World Particles", Default = false, Callback = function(v) Perf.Particles = v applyPerf() end })
	Toggle(t, { Text = "Hide World Decals/Textures", Default = false, Callback = function(v) Perf.Decals = v applyPerf() end })
	Toggle(t, { Text = "Disable Part Shadows (CastShadow)", Default = false, Callback = function(v) Perf.CastShadow = v applyPerf() end })
	Dropdown(t, { Text = "Graphics Quality", Options = { "Keep", "Auto", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" },
		Default = "Keep", Callback = function(v) Perf.Quality = v applyPerf() end })
	Button(t, { Text = "Re-apply boost", Callback = function() applyPerf() Notify("Performance", "reapplied", 2) end })
	Button(t, { Text = "Restore everything", Callback = function() restorePerf() Notify("Performance", "restored", 2) end })
	Section(t, "Note")
	Label(t, "Boost and Fullbright/Custom Sky can conflict — if the world goes flat, turn off Shadows/Terrain here.")
end

--// MISC
do
	local t = Tabs.Misc.Content
	Section(t, "Overlay")
	Toggle(t, { Text = "Show Ping / FPS Overlay", Default = true, Callback = function(v) Overlay:Toggle(v) end })
	Keybind(t, { Text = "Overlay Toggle Key", Default = "F4", Callback = function(_, pressed)
		if pressed then Overlay:Toggle(not Overlay.Visible) end
	end })
	Section(t, "Anticheat / Protection")
	Toggle(t, { Text = "Anti Kick (namecall hook)", Default = false, Callback = function(v)
		Bypass.AntiKick = v
		if v then installAntiKick() end
	end })
	Toggle(t, { Text = "Anti Void", Default = false, Callback = function(v) Bypass.AntiVoid = v end })
	Toggle(t, { Text = "Anti AFK", Default = true, Callback = function(v) Bypass.AntiAfk = v end })
	Section(t, "Diagnostics")
	Button(t, { Text = "Deep Scan game data (console)", Callback = deepScan })
	Button(t, { Text = "Print camera / viewmodel tree", Callback = function()
		print("===== SleepScript Info =====")
		print("Place:", game.PlaceId, game.PlaceVersion)
		local cam = Workspace.CurrentCamera
		print("Camera children:")
		for _, c in ipairs(cam:GetChildren()) do print("  ", c.ClassName, c.Name) end
		print("Workspace models:")
		for _, c in ipairs(Workspace:GetChildren()) do
			if c:IsA("Model") then print("  ", c.ClassName, c.Name) end
		end
		print("ESP tracked:", ESP.Debug)
	end })
end

--// SETTINGS
do
	local t = Tabs.Settings.Content
	Section(t, "Menu")
	Keybind(t, { Text = "Menu Toggle Key", Default = "RightShift", Callback = function(_, pressed)
		if pressed then Window:Toggle() end
	end })
	Slider(t, { Text = "UI Scale", Min = 0.7, Max = 1.4, Default = 1, Decimals = 2, Callback = function(v)
		Window.Scale.Scale = v
	end })
	Button(t, { Text = "Reset Menu Position", Callback = function() Window.Holder.Position = UDim2.new(0.5, 0, 0.5, 0) end })
	Section(t, "Config")
	Button(t, { Text = "Save Config", Callback = saveConfig })
	Button(t, { Text = "Load Config", Callback = loadConfig })
	Button(t, { Text = "Unload Script", Callback = function() SleepScript:Unload() end })
	Section(t, "About")
	Label(t, "SleepScript v" .. SleepScript.Version .. " for BloxStrike.\nRightShift — menu, F4 — overlay.")
end

Window:Select(Tabs.Visuals)

--=====================================================================
-- 18. LOOPS
--=====================================================================
local espTimer, skinTimer = 0, 0
Conn(RunService.RenderStepped, function(dt)
	updateESP()
	enforceDesired()

	espTimer += dt
	if espTimer >= 1 then
		espTimer = 0
		refreshESP()
	end
	skinTimer += dt
	if skinTimer >= 0.25 then
		skinTimer = 0
		if Skin.Enabled then
			scanForParts()
			if Skin.Categories.Gun.Skin == "★ Rainbow" or Skin.Categories.Knife.Skin == "★ Rainbow"
				or Skin.Categories.Glove.Skin == "★ Rainbow" then
				Skin.Hue = (Skin.Hue + 0.05) % 1
			end
		end
	end
end)

Conn(LocalPlayer.CharacterAdded, function()
	task.wait(1)
	hookHumanoid()
	Skin.Tracked, Skin.Desired = {}, {}
	if Skin.Enabled then scanForParts() end
	if Vis.Aura then setAura(true) end
end)
task.spawn(function()
	task.wait(2)
	hookHumanoid()
end)

--=====================================================================
-- 19. UNLOAD
--=====================================================================
function SleepScript:Unload()
	self.Unloaded = true
	for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
	for _, o in ipairs(self.Objects) do pcall(function() o:Destroy() end) end
	for plr in pairs(ESP.Objects) do pcall(function() destroyESP(plr) end) end
	pcall(function() RunService:UnbindFromRenderStep("SleepFOV") end)
	pcall(function() restorePerf() end)
	pcall(function() stopFly() end)
	pcall(function() clearAll() end)
	pcall(function() Sky.Restore() end)
	pcall(function() setFullbright(false) end)
	pcall(function()
		if Vis.Atm then Vis.Atm:Destroy() end
		if Vis.BloomFx then Vis.BloomFx:Destroy() end
		if auraEmitter then auraEmitter:Destroy() end
	end)
	pcall(function() FOV:Reset() end)
	_G.SleepScript = nil
	Notify("SleepScript", "unloaded", 3)
	print("[SleepScript] unloaded")
end

--=====================================================================
-- 20. BOOT
--=====================================================================
Window:Toggle(true)
task.wait(0.4)
Notify("SleepScript v" .. SleepScript.Version, "RightShift — menu  •  F4 — overlay", 4)
print("[SleepScript] v" .. SleepScript.Version .. " loaded | UI: RightShift | Overlay: F4")
