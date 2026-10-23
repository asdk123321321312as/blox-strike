--[[
================================================================================
        ███████╗██╗     ███████╗███████╗██████╗     SleepScript
        ██╔════╝██║     ██╔════╝██╔════╝██╔══██╗    BloxStrike Edition  v6.0
        ███████╗██║     █████╗  █████╗  ██████╔╝
        ╚════██║██║     ██╔══╝  ██╔══╝  ██╔═══╝
        ███████║███████╗███████╗███████╗██║
        ╚══════╝╚══════╝╚══════╝╚══════╝╚═╝
================================================================================
  v6.0 FIXES
   - CAMERA SPIN ON SHOOT: caused by frame hitches from heavy per-frame scans.
     Everything is now cached + throttled. No GetExtentsSize/GetDescendants spam.
     ESP work runs AFTER the camera update so it can never delay it.
   - ESP: TeamCheck OFF by default (was hiding everyone), smarter player->model
     resolver (partial names + nested folders), live target counter, self-test.
     ESP is ON by default so you immediately see if it works.
   - STRAFE: very fast acceleration, wide adjustable sliders (accel up to 600,
     max speed up to 300). Speed builds instantly while holding Space + moving.
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
local LocalPlayer       = Players.LocalPlayer
local Camera            = Workspace.CurrentCamera

--=====================================================================
-- 2. CORE
--=====================================================================
local SleepScript = { Version = "6.0.0", Connections = {}, Objects = {}, Unloaded = false }
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
local function getVel(p)
	local ok, v = pcall(function() return p.AssemblyLinearVelocity end)
	if ok and v then return v end
	return p.Velocity
end
local function setVel(p, v)
	local ok = pcall(function() p.AssemblyLinearVelocity = v end)
	if not ok then pcall(function() p.Velocity = v end) end
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
	local obj = { State = state }
	function obj:Set(v, silent)
		state = v and true or false
		obj.State = state
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
-- 5. DATA
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
local CameraChanged = {}
local function OnCameraChanged(fn) table.insert(CameraChanged, fn) end
Conn(Workspace:GetPropertyChangedSignal("CurrentCamera"), function()
	Camera = Workspace.CurrentCamera
	task.defer(function()
		for _, fn in ipairs(CameraChanged) do pcall(fn) end
	end)
end)

--=====================================================================
-- 7. FOV
--=====================================================================
local FOV = { Enabled = true, Value = 100, Original = nil, Mode = "Safe" }
SleepScript.FOV = FOV
local fovTimer = 0
Conn(RunService.Heartbeat, function(dt)
	if FOV.Mode ~= "Safe" or not FOV.Enabled then return end
	fovTimer = fovTimer + dt
	if fovTimer < 0.3 then return end
	fovTimer = 0
	local cam = Workspace.CurrentCamera
	if cam and math.abs(cam.FieldOfView - FOV.Value) > 0.5 then cam.FOV = nil cam.FieldOfView = FOV.Value end
end)
RunService:BindToRenderStep("SleepFOV", Enum.RenderPriority.Camera.Value - 1, function()
	if FOV.Mode ~= "Instant" or not FOV.Enabled then return end
	local cam = Workspace.CurrentCamera
	if cam and math.abs(cam.FieldOfView - FOV.Value) > 0.5 then cam.FieldOfView = FOV.Value end
end)
function FOV:Reset()
	local cam = Workspace.CurrentCamera
	if cam and FOV.Original then cam.FieldOfView = FOV.Original end
end

--=====================================================================
-- 8. ESP
--=====================================================================
local EspGui = New("ScreenGui", {
	Name = "SleepESP", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 500,
}, GuiParent())
SleepScript.Objects[#SleepScript.Objects + 1] = EspGui

local ESP = {
	Enabled = true,
	Boxes = true, Names = true, Health = true, Distance = true, Weapon = true,
	TeamCheck = false, UseTeamColor = true, MaxDistance = 2500,
	Color = Color3.fromRGB(255, 255, 255),
	FillAlpha = 0.10, Thickness = 1.5,
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
end
local function resolveCharacter(plr)
	local c = plr.Character
	if c and c.Parent and findHumanoid(c) then return c end
	local pn = plr.Name:lower()
	local function try(m)
		if m and m:IsA("Model") and m ~= LocalPlayer.Character and findHumanoid(m) then
			local n = m.Name:lower()
			if n == pn or n:find(pn, 1, true) or pn:find(n, 1, true) then return m end
		end
	end
	for _, d in ipairs(Workspace:GetChildren()) do
		local m = try(d)
		if m then return m end
		if d:IsA("Folder") or d:IsA("Model") then
			for _, ch in ipairs(d:GetChildren()) do
				local m2 = try(ch)
				if m2 then return m2 end
			end
		end
	end
end
local function espColorFor(plr)
	if ESP.UseTeamColor and plr.TeamColor then return plr.TeamColor.Color end
	return ESP.Color
end

local boundsCache = {}
local function getBounds(char, root)
	local c = boundsCache[char]
	if c and os.clock() - c.t < 0.4 then return c.minY, c.maxY, c.r end
	local minY, maxY, maxR
	local rx, ry, rz = root.Position.X, root.Position.Y, root.Position.Z
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			local dx, dy, dz = d.Position.X - rx, d.Position.Y - ry, d.Position.Z - rz
			local flatSq = dx * dx + dz * dz
			if math.abs(dy) < 12 and flatSq < 144 then
				local s = d.Size
				local y1, y2 = d.Position.Y - s.Y / 2, d.Position.Y + s.Y / 2
				minY = minY and math.min(minY, y1) or y1
				maxY = maxY and math.max(maxY, y2) or y2
				local r = math.sqrt(flatSq) + math.max(s.X, s.Z) / 2
				maxR = maxR and math.max(maxR, r) or r
			end
		end
	end
	if not minY or (maxY - minY) > 25 then
		minY, maxY, maxR = ry - 3, ry + 3, 2.2
	end
	boundsCache[char] = { minY = minY, maxY = maxY, r = math.max(maxR or 2.2, 1.5), t = os.clock() }
	return minY, maxY, math.max(maxR or 2.2, 1.5)
end

local function destroyESP(plr)
	local d = ESP.Objects[plr]
	if not d then return end
	if d.Gui and d.Gui.Parent then d.Gui:Destroy() end
	if d.Box and d.Box.Parent then d.Box:Destroy() end
	if d.Highlight and d.Highlight.Parent then d.Highlight:Destroy() end
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

	local gui = New("Frame", {
		Name = "Box_" .. plr.Name, Size = UDim2.fromOffset(60, 100),
		Position = UDim2.fromOffset(0, 0), BackgroundColor3 = col,
		BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 1,
	}, EspGui)
	d.Gui = gui
	d.GuiFill = New("Frame", {
		Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = col,
		BackgroundTransparency = 1 - ESP.FillAlpha, BorderSizePixel = 0, ZIndex = 1,
	}, gui)
	d.GuiStroke = New("UIStroke", { Thickness = ESP.Thickness, Color = col, Transparency = 0 }, gui)
	d.GuiName = New("TextLabel", {
		Size = UDim2.new(1, 80, 0, 15), Position = UDim2.new(0.5, 0, 0, -16),
		AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold, TextSize = 13, Text = plr.Name, TextColor3 = col,
		TextStrokeTransparency = 0.35, TextStrokeColor3 = Color3.new(0, 0, 0), ZIndex = 2,
	}, gui)
	d.GuiInfo = New("TextLabel", {
		Size = UDim2.new(1, 80, 0, 14), Position = UDim2.new(0.5, 0, 1, 1),
		AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1,
		Font = Enum.Font.Gotham, TextSize = 11, Text = "", TextColor3 = Theme.Sub,
		TextStrokeTransparency = 0.4, TextStrokeColor3 = Color3.new(0, 0, 0), ZIndex = 2,
	}, gui)
	local hb = New("Frame", {
		Size = UDim2.new(0, 3, 1, 0), Position = UDim2.new(0, -6, 0, 0),
		BackgroundColor3 = Color3.fromRGB(15, 15, 15), BackgroundTransparency = 0.3,
		BorderSizePixel = 0, ZIndex = 2,
	}, gui)
	Corner(hb, 2)
	d.GuiHealth = New("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Theme.Good, BorderSizePixel = 0 }, hb)
	Corner(d.GuiHealth, 2)

	d.Highlight = New("Highlight", {
		Name = "SleepChams", Adornee = char,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		FillTransparency = 1, OutlineTransparency = 1,
		FillColor = col, OutlineColor = col,
	}, char)
	d.Box = New("BoxHandleAdornment", {
		Name = "SleepAdorn", Adornee = hrp, AlwaysOnTop = true,
		Size = Vector3.new(4, 6, 4), Color3 = col, Transparency = 0.4, Visible = false,
	}, Camera)

	ESP.Objects[plr] = d
	return true
end

local function refreshESP()
	for plr, d in pairs(ESP.Objects) do
		local dead = plr.Parent == nil or not d.Character or not d.Character.Parent
			or not d.Humanoid or not d.Humanoid.Parent or d.Humanoid.Health <= 0
			or not d.Gui or not d.Gui.Parent
		if dead then destroyESP(plr) end
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
	local cam = Workspace.CurrentCamera
	if not cam then return end
	local camRight = cam.CFrame.RightVector
	local myPos = cam.CFrame.Position
	local myTeam = LocalPlayer.Team

	for plr, d in pairs(ESP.Objects) do
		local char, hum, anchor = d.Character, d.Humanoid, d.Anchor
		local valid = char and char.Parent and hum and hum.Parent and hum.Health > 0 and anchor and anchor.Parent
		if not valid then
			if d.Gui then d.Gui.Visible = false end
			continue
		end
		local skip = ESP.TeamCheck and myTeam and plr.Team and plr.Team == myTeam
		if skip or not ESP.Enabled then
			if d.Gui then d.Gui.Visible = false end
			if d.Highlight then d.Highlight.FillTransparency = 1 d.Highlight.OutlineTransparency = 1 end
			if d.Box then d.Box.Visible = false end
			continue
		end

		local dist = (anchor.Position - myPos).Magnitude
		if dist > ESP.MaxDistance then
			if d.Gui then d.Gui.Visible = false end
			if d.Box then d.Box.Visible = false end
			if d.Highlight then d.Highlight.FillTransparency = 1 d.Highlight.OutlineTransparency = 1 end
			continue
		end

		local col = espColorFor(plr)
		local a3, aOn = cam:WorldToViewportPoint(anchor.Position)

		if d.Gui then
			if ESP.Boxes and aOn and a3.Z > 0 then
				local minY, maxY, r = getBounds(char, anchor)
				local cx, cz = anchor.Position.X, anchor.Position.Z
				local midY = (minY + maxY) / 2
				local topW = Vector3.new(cx, maxY + 0.35, cz)
				local botW = Vector3.new(cx, minY - 0.35, cz)
				local midW = Vector3.new(cx, midY, cz)
				local t3 = cam:WorldToViewportPoint(topW)
				local b3 = cam:WorldToViewportPoint(botW)
				local r3 = cam:WorldToViewportPoint(midW + camRight * (r + 0.2))
				local l3 = cam:WorldToViewportPoint(midW - camRight * (r + 0.2))

				local x1 = math.min(l3.X, r3.X)
				local x2 = math.max(l3.X, r3.X)
				local y1 = math.min(t3.Y, b3.Y)
				local y2 = math.max(t3.Y, b3.Y)
				local w = math.max(x2 - x1, 8)
				local h = math.max(y2 - y1, 10)

				d.Gui.Visible = true
				d.Gui.Position = UDim2.fromOffset(math.floor(x1), math.floor(y1))
				d.Gui.Size = UDim2.fromOffset(math.floor(w), math.floor(h))
				d.GuiStroke.Color = col
				d.GuiStroke.Thickness = ESP.Thickness
				d.GuiFill.BackgroundColor3 = col
				d.GuiFill.BackgroundTransparency = 1 - ESP.FillAlpha
				d.GuiName.Visible = ESP.Names
				d.GuiName.TextColor3 = col

				local hp = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
				d.GuiHealth.Parent.Visible = ESP.Health
				d.GuiHealth.Size = UDim2.new(1, 0, hp, 0)
				d.GuiHealth.Position = UDim2.new(0, 0, 1 - hp, 0)
				d.GuiHealth.BackgroundColor3 = Color3.fromRGB(math.floor(255 * (1 - hp)), math.floor(255 * hp), 60)

				local parts = {}
				if ESP.Distance then parts[#parts + 1] = ("%dm"):format(math.floor(dist)) end
				if ESP.Weapon then
					local tl = char:FindFirstChildOfClass("Tool")
					local a = plr:GetAttribute("Weapon") or plr:GetAttribute("CurrentWeapon") or char:GetAttribute("Weapon")
					parts[#parts + 1] = tl and tl.Name or (a and tostring(a)) or "-"
				end
				d.GuiInfo.Visible = #parts > 0
				d.GuiInfo.Text = table.concat(parts, "  •  ")
			else
				d.Gui.Visible = false
			end
		end

		if d.Box then
			d.Box.Adornee = anchor
			d.Box.Visible = ESP.Boxes and ESP.BoxMode == "3D"
			if d.Box.Visible then
				local minY, maxY, r = getBounds(char, anchor)
				d.Box.Color3 = col
				d.Box.Size = Vector3.new(r * 2, maxY - minY, r * 2)
			end
		end
		if d.Highlight then
			d.Highlight.FillColor = col
			d.Highlight.OutlineColor = col
			d.Highlight.FillTransparency = ESP.Chams and 0.75 or 1
			d.Highlight.OutlineTransparency = ESP.Chams and 0 or 1
		end
	end
end
ESP.Update = updateESP
ESP.BoxMode = "2D"

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
OnCameraChanged(function()
	for plr in pairs(ESP.Objects) do destroyESP(plr) end
	if ESP.Enabled then refreshESP() end
end)

--=====================================================================
-- 9. SKIN CHANGER
--=====================================================================
local Skin = {
	Enabled = false,
	Assignments = {},
	Library = {},
	Desired = {},
	Originals = {},
	HiddenSA = {},
	Detected = "-",
	Parts = 0,
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
local function buildLibrary()
	Skin.Library = {}
	local seen = {}
	local function add(name, id)
		if not id or type(id) ~= "string" or id == "" then return end
		if seen[id] then return end
		seen[id] = true
		local key = name
		if Skin.Library[key] then key = name .. " #" .. tostring(math.random(1000, 9999)) end
		Skin.Library[key] = id
	end
	local n = 0
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
		n = n + 1
		if n > 50000 then break end
		local id
		if d:IsA("Decal") or d:IsA("Texture") then id = d.Texture
		elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then id = d.Image
		elseif d:IsA("SurfaceAppearance") then id = d.ColorMap
		elseif d:IsA("MeshPart") then id = d.TextureID
		elseif d:IsA("StringValue") then
			local v = d.Value
			if type(v) == "string" and (v:find("rbxassetid") or v:find("asset/?id=")) then id = v end
		end
		if id then add(d.Name, id) end
	end
	local total = 0
	for _ in pairs(Skin.Library) do total = total + 1 end
	return total
end
local function skinOptions()
	local o = { "None" }
	local k = {}
	for key in pairs(BUILTIN_SKINS) do k[#k + 1] = key end
	table.sort(k)
	for _, key in ipairs(k) do o[#o + 1] = key end
	local g = {}
	for key in pairs(Skin.Library) do g[#g + 1] = key end
	table.sort(g)
	for _, key in ipairs(g) do o[#o + 1] = key end
	return o
end
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
	if not id or id == "" then clearSkinChildren(part) restoreSA(part) return end
	hideSA(part)
	if part:IsA("MeshPart") then pcall(function() part.TextureID = id end) end
	local sm = part:FindFirstChildOfClass("SpecialMesh")
	if sm then pcall(function() sm.TextureId = id end) end
	if not part:IsA("MeshPart") and not sm then
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
local function assignmentFor(model)
	local det = detectWeapon(model)
	if det and Skin.Assignments[det] then return Skin.Assignments[det] end
	return Skin.Assignments["*"]
end
local function stylePart(part, model)
	if not part:IsA("BasePart") then return end
	local skinName = assignmentFor(model)
	if not skinName or skinName == "None" then return end
	if not Skin.Originals[part] then
		Skin.Originals[part] = {
			Material = part.Material, Color = part.Color, Reflectance = part.Reflectance,
			TextureID = part:IsA("MeshPart") and part.TextureID or nil,
		}
	end
	local color, material, texture
	local b = BUILTIN_SKINS[skinName]
	if b then
		color = b.Color
		if b.Material then material = Enum.Material[b.Material] end
	else
		local id = Skin.Library[skinName]
		if id then
			texture = id
			color = Color3.new(1, 1, 1)
		end
	end
	if texture then applyTexture(part, texture) else clearSkinChildren(part) restoreSA(part) end
	if color then part.Color = color end
	if material then part.Material = material end
	Skin.Desired[part] = { Color = color, Material = material, Texture = texture }
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
	Skin.Desired[part] = nil
end
local function isViewModel(m)
	if not m:IsA("Model") then return false end
	if m.Parent == Workspace.CurrentCamera then return true end
	local n = m.Name:lower()
	return n:find("view") or n:find("worldmodel") or n:find("arms") or n:find("hands")
		or n:find("weapon") or n:find("fps") or n:find("tool")
end

--// cached workspace scan (heavy part) -------------------------------
local wsCache = { list = {}, t = 0 }
local extCache = setmetatable({}, { __mode = "k" })
local function workspaceList()
	if os.clock() - wsCache.t < 1 then return wsCache.list end
	wsCache.list = Workspace:GetChildren()
	wsCache.t = os.clock()
	return wsCache.list
end
local function modelExtent(m)
	local c = extCache[m]
	if c and os.clock() - c.t < 5 then return c.v end
	local ok, v = pcall(function() return m:GetExtentsSize() end)
	v = ok and v or nil
	extCache[m] = { v = v, t = os.clock() }
	return v
end

local function collectParts()
	local out = {}
	local cam = Workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position
	local function push(part, model) out[#out + 1] = { part = part, model = model } end

	if cam then
		for _, c in ipairs(cam:GetChildren()) do
			if c:IsA("BasePart") then push(c, c)
			elseif c:IsA("Model") or c:IsA("Folder") then
				for _, d in ipairs(c:GetDescendants()) do
					if d:IsA("BasePart") then push(d, c) end
				end
			end
		end
	end
	for _, c in ipairs(workspaceList()) do
		if isViewModel(c) then
			for _, d in ipairs(c:GetDescendants()) do
				if d:IsA("BasePart") then push(d, c) end
			end
		end
	end
	if camPos then
		for _, c in ipairs(workspaceList()) do
			if c:IsA("Model") and not isViewModel(c) and not Players:GetPlayerFromCharacter(c) then
				local ext = modelExtent(c)
				if ext and ext.Magnitude < 30 then
					local parts, near = {}, false
					for _, d in ipairs(c:GetChildren()) do
						if d:IsA("BasePart") then
							parts[#parts + 1] = d
							if not near and (d.Position - camPos).Magnitude < 14 then near = true end
						end
					end
					if near and #parts <= 40 then
						for _, d in ipairs(parts) do push(d, c) end
					end
				end
			end
		end
	end
	return out
end

local function scanForParts()
	if not Skin.Enabled then return end
	local list = collectParts()
	Skin.Parts = #list
	for _, e in ipairs(list) do
		local det = detectWeapon(e.model)
		if det then Skin.Detected = det end
		stylePart(e.part, e.model)
	end
end
Skin.Scan = scanForParts
local function restyleAll()
	for part in pairs(Skin.Desired) do
		if not part.Parent then
			Skin.Desired[part] = nil
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
	Skin.Originals, Skin.Desired = {}, {}
end
Skin.ClearAll = clearAll
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
OnCameraChanged(function()
	Skin.Desired = {}
	if Skin.Enabled then scanForParts() end
end)

--=====================================================================
-- 10. MOVEMENT
--=====================================================================
local Move = {
	Bhop = false, InfJump = false, HoldingSpace = false,
	AirStrafe = true, StrafeAccel = 200, MaxSpeed = 90, AutoStrafe = false,
	SpeedEnabled = false, WalkSpeed = 16,
	JumpEnabled = false, JumpPower = 50,
	Sprint = false, SprintKey = "LeftShift", SprintSpeed = 24, Sprinting = false,
	Fly = false,
}
SleepScript.Move = Move

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
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
local lastAirHoriz = nil
local function hookHumanoid()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	baseWalkSpeed = hum.WalkSpeed
	Conn(hum.StateChanged, function(_, new)
		if not Move.Bhop or not Move.HoldingSpace then return end
		if new == Enum.HumanoidStateType.Landed then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				if lastAirHoriz then
					local v = getVel(hrp)
					setVel(hrp, Vector3.new(lastAirHoriz.X, v.Y, lastAirHoriz.Z))
				end
				if isGrounded(hum, hrp) then doJump(hum) end
			end
		end
	end)
end

local bhopCD, autoTimer, autoDir = 0, 0, 1
Conn(RunService.Heartbeat, function(dt)
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local airborne = not isGrounded(hum, hrp)
	local holding = Move.HoldingSpace
	local vel = getVel(hrp)
	local horiz = Vector3.new(vel.X, 0, vel.Z)
	local speed = horiz.Magnitude
	lastAirHoriz = airborne and horiz or nil

	if Move.Bhop and holding and not airborne and os.clock() >= bhopCD then
		doJump(hum)
		bhopCD = os.clock() + 0.05
	end

	if Move.Bhop and Move.AirStrafe and holding and airborne then
		local cam = Workspace.CurrentCamera
		if cam then
			local wish = Vector3.zero
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then wish += cam.CFrame.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then wish -= cam.CFrame.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then wish -= cam.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then wish += cam.CFrame.RightVector end
			if wish.Magnitude < 0.01 and Move.AutoStrafe then
				autoTimer = autoTimer + dt
				if autoTimer > 0.3 then autoTimer = 0 autoDir = -autoDir end
				wish = cam.CFrame.RightVector * autoDir
			end
			if wish.Magnitude > 0.01 then
				wish = Vector3.new(wish.X, 0, wish.Z).Unit
				local room = Move.MaxSpeed - speed
				if room > 0 then
					local add = math.min(Move.StrafeAccel * dt, room)
					setVel(hrp, vel + wish * add)
				end
			end
		end
	end

	if Move.Bhop and holding then
		local target = math.clamp(math.max(speed, baseWalkSpeed), baseWalkSpeed, Move.MaxSpeed)
		if math.abs(hum.WalkSpeed - target) > 0.1 then hum.WalkSpeed = target end
	elseif Move.SpeedEnabled then
		local target = Move.WalkSpeed
		if Move.Sprint and Move.Sprinting then target = Move.SprintSpeed end
		if math.abs(hum.WalkSpeed - target) > 0.1 then hum.WalkSpeed = target end
	elseif hum.WalkSpeed ~= baseWalkSpeed then
		hum.WalkSpeed = baseWalkSpeed
	end

	if Move.InfJump and holding then
		if hum:GetState() == Enum.HumanoidStateType.Freefall then doJump(hum) end
	end
	if Move.JumpEnabled and math.abs(hum.JumpPower - Move.JumpPower) > 0.1 then hum.JumpPower = Move.JumpPower end
end)

local flyBV, flyBG
local function stopFly()
	if flyBV then flyBV:Destroy() flyBV = nil end
	if flyBG then flyBG:Destroy() flyBG = nil end
	local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if hrp then setVel(hrp, Vector3.zero) end
end
Conn(RunService.RenderStepped, function()
	if not Move.Fly then return end
	local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
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
-- 11. SKY
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
			elseif a:GetAttribute("SleepDensity") then
				a.Density = a:GetAttribute("SleepDensity")
				a.Haze = a:GetAttribute("SleepHaze")
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

local Vis = { Fullbright = false, Aura = false }
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
	local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
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
-- 13. FPS BOOST
--=====================================================================
local Perf = {
	Master = false, Shadows = true, PostFX = true, Terrain = true, Fog = false,
	Particles = false, Decals = false, Quality = "Keep", Backup = nil, Hidden = {},
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
	Perf.Hidden, Perf.Backup = {}, nil
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
			or Enum.QualityLevel["Level" .. (#Perf.Quality == 1 and ("0" .. Perf.Quality) or Perf.Quality)]
		pcall(function() settings().Rendering.QualityLevel = lvl end)
	end
	if Perf.Particles or Perf.Decals then
		local n = 0
		for _, d in ipairs(Workspace:GetDescendants()) do
			n = n + 1
			if n > 25000 then break end
			if Perf.Particles and d:IsA("ParticleEmitter") then
				table.insert(Perf.Hidden, { inst = d, prop = "Enabled", value = d.Enabled })
				d.Enabled = false
			elseif Perf.Decals and (d:IsA("Decal") or d:IsA("Texture")) then
				table.insert(Perf.Hidden, { inst = d, prop = "Transparency", value = d.Transparency })
				d.Transparency = 1
			end
		end
	end
end
Perf.Apply, Perf.Restore = applyPerf, restorePerf

--=====================================================================
-- 14. BYPASS
--=====================================================================
local Bypass = { AntiKick = false, AntiVoid = false, AntiAfk = true }
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
	if not ok then Notify("Hook", "hook unavailable", 3) end
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
-- 15. MENU
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

do -- VISUALS
	local t = Tabs.Visuals.Content
	Section(t, "ESP")
	local dbg = Label(t, "targets: 0   (if 0 — напиши, разберём)")
	local esdToggle
	esdToggle = Toggle(t, { Text = "Enable ESP", Default = true, Callback = function(v)
		ESP.Enabled = v
		if v then refreshESP() else for plr in pairs(ESP.Objects) do destroyESP(plr) end end
	end })
	Toggle(t, { Text = "Boxes", Default = true, Callback = function(v) ESP.Boxes = v end })
	Toggle(t, { Text = "Names", Default = true, Callback = function(v) ESP.Names = v end })
	Toggle(t, { Text = "Health Bar", Default = true, Callback = function(v) ESP.Health = v end })
	Toggle(t, { Text = "Distance", Default = true, Callback = function(v) ESP.Distance = v end })
	Toggle(t, { Text = "Weapon", Default = true, Callback = function(v) ESP.Weapon = v end })
	Toggle(t, { Text = "Only enemies (team check)", Default = false, Callback = function(v) ESP.TeamCheck = v end })
	Toggle(t, { Text = "Chams (Highlight)", Default = false, Callback = function(v) ESP.Chams = v end })
	Toggle(t, { Text = "Team colors", Default = true, Callback = function(v) ESP.UseTeamColor = v end })
	Slider(t, { Text = "Max Distance", Min = 100, Max = 5000, Default = 2500, Callback = function(v) ESP.MaxDistance = v end })
	Slider(t, { Text = "Box Thickness", Min = 1, Max = 4, Default = 1.5, Decimals = 1, Callback = function(v) ESP.Thickness = v end })
	Slider(t, { Text = "Box Fill", Min = 0, Max = 0.5, Default = 0.10, Decimals = 2, Callback = function(v) ESP.FillAlpha = v end })
	Dropdown(t, { Text = "Render method", Options = { "2D GUI", "3D Adornment" }, Default = "2D GUI",
		Callback = function(v) ESP.BoxMode = v == "3D Adornment" and "3D" or "2D" end })
	Button(t, { Text = "Refresh targets", Callback = function() refreshESP() Notify("ESP", "tracked: " .. ESP.Debug, 2) end })
	Button(t, { Text = "ESP self-test (red box, 3s)", Callback = function()
		local g = New("Frame", {
			Size = UDim2.fromOffset(160, 260), Position = UDim2.new(0.5, -80, 0.5, -130),
			BackgroundTransparency = 1, ZIndex = 50,
		}, EspGui)
		Stroke(g, Color3.fromRGB(255, 60, 60), 3, 0)
		local lbl = New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0.5, 0, 0, -24),
			AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.fromRGB(255, 60, 60),
			Text = "ESP WORKS",
		}, g)
		task.delay(3, function() g:Destroy() end)
	end })

	Section(t, "Field Of View")
	Toggle(t, { Text = "Custom FOV", Default = true, Callback = function(v)
		if v then
			local cam = Workspace.CurrentCamera
			if cam and not FOV.Original then FOV.Original = cam.FieldOfView end
		end
		FOV.Enabled = v
		if not v then FOV:Reset() end
	end })
	Dropdown(t, { Text = "Apply Mode", Options = { "Safe", "Instant", "Off" }, Default = "Safe",
		Callback = function(v) FOV.Mode = v end })
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
	Button(t, { Text = "Restore game sky", Callback = function() Sky.Restore() updSky() end })

	Section(t, "Other")
	Toggle(t, { Text = "Fullbright", Default = false, Callback = setFullbright })
	Toggle(t, { Text = "Player Aura Particles", Default = false, Callback = setAura })
end

do -- SKIN
	local t = Tabs.Skin.Content
	local status = Label(t, "detected: -   |   parts: 0   |   game skins: 0")
	local function updStatus()
		local n = 0
		for _ in pairs(Skin.Library) do n = n + 1 end
		status.Text = string.format("detected: %s   |   parts: %d   |   game skins: %d", Skin.Detected, Skin.Parts, n)
	end
	Toggle(t, { Text = "Enable SkinChanger", Default = false, Callback = function(v)
		Skin.Enabled = v
		if v then scanForParts() Notify("Skin", "tracked " .. Skin.Parts .. " parts", 3) else clearAll() end
		updStatus()
	end })
	Section(t, "Pick weapon and skin")
	local weaponDd = Dropdown(t, {
		Text = "Weapon / Knife",
		Options = (function()
			local o = { "Auto (everything)" }
			for _, w in ipairs(WEAPONS) do o[#o + 1] = w end
			for _, k in ipairs(KNIVES) do o[#o + 1] = k end
			for _, g in ipairs(GLOVES) do o[#o + 1] = g end
			return o
		end)(),
		Default = "Auto (everything)",
	})
	local skinDd = Dropdown(t, { Text = "Skin (from game)", Options = skinOptions(), Default = "★ Gold" })
	Button(t, { Text = ">>> APPLY SKIN <<<", Callback = function()
		local w, s = weaponDd.Value, skinDd.Value
		Skin.Assignments[(w == "Auto (everything)") and "*" or w] = s
		Skin.Enabled = true
		scanForParts()
		restyleAll()
		updStatus()
		Notify("Skin", w .. " -> " .. s, 3)
	end })
	Button(t, { Text = "Remove skin from this weapon", Callback = function()
		local w = weaponDd.Value
		Skin.Assignments[(w == "Auto (everything)") and "*" or w] = nil
		clearAll()
		restyleAll()
		Notify("Skin", "removed: " .. w, 2)
	end })
	Button(t, { Text = "Rescan game skins", Callback = function()
		local n = buildLibrary()
		skinDd:SetOptions(skinOptions())
		updStatus()
		Notify("Skin", "found " .. n .. " skins", 3)
	end })
	Section(t, "Assignments")
	local listLbl = Label(t, "none")
	Skin.UpdateList = function()
		local p = {}
		for k, v in pairs(Skin.Assignments) do p[#p + 1] = (k == "*" and "ALL" or k) .. " -> " .. v end
		table.sort(p)
		listLbl.Text = #p > 0 and table.concat(p, "\n") or "none"
	end
	Skin.UpdateList()
	updStatus()
end

do -- MOVEMENT
	local t = Tabs.Movement.Content
	Section(t, "Bunny Hop + Strafe")
	Toggle(t, { Text = "Auto BunnyHop (hold Space)", Default = false, Callback = function(v) Move.Bhop = v end })
	Toggle(t, { Text = "Air Strafe (builds speed)", Default = true, Callback = function(v) Move.AirStrafe = v end })
	Slider(t, { Text = "Strafe Acceleration", Min = 20, Max = 600, Default = 200, Callback = function(v) Move.StrafeAccel = v end })
	Slider(t, { Text = "Max Speed", Min = 20, Max = 300, Default = 90, Callback = function(v) Move.MaxSpeed = v end })
	Button(t, { Text = "Preset: Normal (accel 80 / max 45)", Callback = function()
		Move.StrafeAccel, Move.MaxSpeed = 80, 45
		Notify("Strafe", "normal preset", 2)
	end })
	Button(t, { Text = "Preset: Fast (accel 200 / max 90)", Callback = function()
		Move.StrafeAccel, Move.MaxSpeed = 200, 90
		Notify("Strafe", "fast preset", 2)
	end })
	Button(t, { Text = "Preset: Insane (accel 450 / max 180)", Callback = function()
		Move.StrafeAccel, Move.MaxSpeed = 450, 180
		Notify("Strafe", "insane preset", 2)
	end })
	Toggle(t, { Text = "Auto Strafe (no A/D needed)", Default = false, Callback = function(v) Move.AutoStrafe = v end })
	Toggle(t, { Text = "Infinite Jump", Default = false, Callback = function(v) Move.InfJump = v end })
	Label(t, "Держи Space и стрейфь A/D в воздухе — скорость наберётся почти сразу. Больше accel = быстрее набор.")
	Section(t, "Speed")
	Toggle(t, { Text = "Custom WalkSpeed", Default = false, Callback = function(v) Move.SpeedEnabled = v end })
	Slider(t, { Text = "WalkSpeed", Min = 8, Max = 200, Default = 16, Callback = function(v) Move.WalkSpeed = v end })
	Toggle(t, { Text = "Custom JumpPower", Default = false, Callback = function(v) Move.JumpEnabled = v end })
	Slider(t, { Text = "JumpPower", Min = 20, Max = 300, Default = 50, Callback = function(v) Move.JumpPower = v end })
	Section(t, "Sprint / Fly")
	Toggle(t, { Text = "Sprint on Hold", Default = false, Callback = function(v) Move.Sprint = v end })
	Keybind(t, { Text = "Sprint Key", Default = "LeftShift", Callback = function(k) Move.SprintKey = k end })
	Toggle(t, { Text = "Fly", Default = false, Callback = function(v)
		Move.Fly = v
		if not v then stopFly() end
	end })
end

do -- PERF
	local t = Tabs.Perf.Content
	Section(t, "FPS Boost")
	Toggle(t, { Text = "Enable FPS Boost (master)", Default = false, Callback = function(v)
		Perf.Master = v
		applyPerf()
		Notify("Performance", v and "applied" or "restored", 2)
	end })
	Toggle(t, { Text = "Disable Global Shadows", Default = true, Callback = function(v) Perf.Shadows = v applyPerf() end })
	Toggle(t, { Text = "Disable Post-Processing", Default = true, Callback = function(v) Perf.PostFX = v applyPerf() end })
	Toggle(t, { Text = "Disable Terrain / Water", Default = true, Callback = function(v) Perf.Terrain = v applyPerf() end })
	Toggle(t, { Text = "Unlimited Fog End", Default = false, Callback = function(v) Perf.Fog = v applyPerf() end })
	Toggle(t, { Text = "Disable World Particles", Default = false, Callback = function(v) Perf.Particles = v applyPerf() end })
	Toggle(t, { Text = "Hide World Decals", Default = false, Callback = function(v) Perf.Decals = v applyPerf() end })
	Dropdown(t, { Text = "Graphics Quality", Options = { "Keep", "Auto", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" },
		Default = "Keep", Callback = function(v) Perf.Quality = v applyPerf() end })
	Button(t, { Text = "Restore everything", Callback = function() restorePerf() end })
end

do -- MISC
	local t = Tabs.Misc.Content
	Section(t, "Overlay")
	Toggle(t, { Text = "Show Ping / FPS Overlay", Default = true, Callback = function(v) Overlay:Toggle(v) end })
	Keybind(t, { Text = "Overlay Toggle Key", Default = "F4", Callback = function(_, pressed)
		if pressed then Overlay:Toggle(not Overlay.Visible) end
	end })
	Section(t, "Anticheat")
	Toggle(t, { Text = "Anti Kick", Default = false, Callback = function(v)
		Bypass.AntiKick = v
		if v then installAntiKick() end
	end })
	Toggle(t, { Text = "Anti Void", Default = false, Callback = function(v) Bypass.AntiVoid = v end })
	Toggle(t, { Text = "Anti AFK", Default = true, Callback = function(v) Bypass.AntiAfk = v end })
	Section(t, "Diagnostics")
	Button(t, { Text = "Print camera / viewmodel tree", Callback = function()
		print("===== SleepScript Info =====")
		print("Place:", game.PlaceId, game.PlaceVersion)
		local cam = Workspace.CurrentCamera
		print("Camera children:")
		for _, c in ipairs(cam:GetChildren()) do print("  ", c.ClassName, c.Name) end
		print("Players:")
		for _, p in ipairs(Players:GetPlayers()) do
			print("  ", p.Name, "char:", p.Character and p.Character:GetFullName() or "nil")
		end
		print("ESP tracked:", ESP.Debug, "| Skin parts:", Skin.Parts)
	end })
end

do -- SETTINGS
	local t = Tabs.Settings.Content
	Section(t, "Menu")
	Keybind(t, { Text = "Menu Toggle Key", Default = "RightShift", Callback = function(_, pressed)
		if pressed then Window:Toggle() end
	end })
	Slider(t, { Text = "UI Scale", Min = 0.7, Max = 1.4, Default = 1, Decimals = 2, Callback = function(v) Window.Scale.Scale = v end })
	Button(t, { Text = "Unload Script", Callback = function() SleepScript:Unload() end })
	Section(t, "About")
	Label(t, "SleepScript v" .. SleepScript.Version ..
