--[[
================================================================================
        ███████╗██╗     ███████╗███████╗██████╗     SleepScript
        ██╔════╝██║     ██╔════╝██╔════╝██╔══██╗    BloxStrike Edition
        ███████╗██║     █████╗  █████╗  ██████╔╝    v2.0
        ╚════██║██║     ██╔══╝  ██╔══╝  ██╔═══╝
        ███████║███████╗███████╗███████╗██║
        ╚══════╝╚══════╝╚══════╝╚══════╝╚═╝
================================================================================
  v2.0 CHANGES
   - Combat/aimbot tab REMOVED
   - ESP rebuilt: Drawing boxes + SelectionBox + Highlight + Billboard fallback
     + robust character resolver (works when plr.Character is nil/mismatched)
   - AutoBunnyHop rebuilt: raycast ground check + Humanoid.StateChanged + cooldown
   - FOV rebuilt: real Camera.FieldOfView with anti-revert render step + reset
   - SkinChanger rebuilt: pick weapon/knife -> pick in-game skin -> apply
     (scans game files for real skin textures, copies meshes from game models)
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
local SleepScript = {
	Version = "2.0.0",
	Connections = {},
	Objects = {},
	Flags = {},
	Unloaded = false,
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
local function Tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(
		t or 0.22, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
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

local function GetHum(plr)
	local char = plr and plr.Character
	if not char then return nil end
	local h = char:FindFirstChildOfClass("Humanoid")
	if h then return h end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("Humanoid") then return d end
	end
end

--=====================================================================
-- 3. THEME / NOTIFY
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
local function RegisterAccent(inst, prop)
	table.insert(AccentRegistry, { inst = inst, prop = prop })
end

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

local function Hover(b, normal, hovered)
	b.MouseEnter:Connect(function() Tween(b, 0.18, hovered) end)
	b.MouseLeave:Connect(function() Tween(b, 0.18, normal) end)
end

function Lib:Window(cfg)
	cfg = cfg or {}
	local win = { Tabs = {}, Open = true }

	local holder = New("Frame", {
		Name = "SleepHolder", Size = UDim2.fromOffset(640, 442),
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
		Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Theme.Bg2,
		BorderSizePixel = 0, ZIndex = 2,
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
		Size = UDim2.fromOffset(280, 14), Position = UDim2.new(0, 33, 0.5, 8),
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
		Tween(holder, 0.3, { Size = minimized and UDim2.fromOffset(240, 44) or UDim2.fromOffset(640, 442) })
	end)
	WinBtn("✕", -14, function() win:Toggle(false) end)

	do
		local dragging, ds, sp = false, nil, nil
		topbar.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1
				or i.UserInputType == Enum.UserInputType.Touch then
				dragging, ds, sp = true, i.Position, holder.Position
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
				holder.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
			end
		end)
	end

	local sidebar = New("Frame", {
		Size = UDim2.new(0, 138, 1, -58), Position = UDim2.new(0, 12, 0, 50),
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
		Size = UDim2.new(1, -170, 1, -58), Position = UDim2.new(0, 158, 0, 50),
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
			task.delay(0.22, function()
				if not self.Open then holder.Visible = false end
			end)
		end
	end

	local function MakeTab(name, icon)
		local tab = { Name = name }
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
			Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Stroke,
			CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 2,
		}, wrap)
		New("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
		Pad(scroll, 4, 8, 14, 4)

		tab.Content = scroll
		tab.Wrap = wrap
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
				task.delay(0.17, function()
					if win.ActiveTab ~= t then t.Wrap.Visible = false end
				end)
			end
		end
	end

	win.MakeTab = MakeTab
	win.Holder = holder
	win.Scale = scale
	return win
end

--// COMPONENTS
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
		Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1,
		Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.Sub,
		Text = text, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.Y,
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
		Text = o.Text or "Toggle", TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
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
		SleepScript.Flags[o.Flag or o.Text] = state
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
		Size = UDim2.new(1, -70, 0, 18), Position = UDim2.new(0, 12, 0, 5),
		BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
		Text = o.Text or "Slider", TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, f)
	local val = New("TextLabel", {
		Size = UDim2.new(0, 70, 0, 18), Position = UDim2.new(1, -12, 0, 5),
		AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Accent,
		TextXAlignment = Enum.TextXAlignment.Right, Text = "0",
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
	local decimals = o.Decimals or 0
	local value = o.Default or min
	local obj = { Value = value }

	local function render()
		local a = (value - min) / math.max(max - min, 0.0001)
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, 0, 0.5, 0)
		local txt = decimals > 0 and string.format("%." .. decimals .. "f", value) or tostring(math.floor(value + 0.5))
		val.Text = (o.Suffix and (txt .. o.Suffix)) or txt
	end
	function obj:Set(v, silent)
		value = math.clamp(v, min, max)
		obj.Value = value
		SleepScript.Flags[o.Flag or o.Text] = value
		render()
		if not silent and o.Callback then task.spawn(o.Callback, value) end
	end
	local dragging = false
	local function update(i)
		local rel = math.clamp((i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		obj:Set(min + rel * (max - min))
	end
	track.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			update(i)
		end
	end)
	Conn(UserInputService.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	Conn(UserInputService.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
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
		BackgroundTransparency = 0.35, BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.Y,
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
		Size = UDim2.new(1, -140, 1, 0), Position = UDim2.new(0, 8, 0, 0),
		BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
		Text = o.Text or "Dropdown", TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, header)
	local valueLbl = New("TextLabel", {
		Size = UDim2.new(0, 150, 1, 0), Position = UDim2.new(1, -26, 0, 0),
		BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 11,
		Text = "", TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Right,
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
			Tween(list, 0.22, { Size = UDim2.new(1, 0, 0, math.min(math.max(#obj.Options * 23 + 10, 40), 170)) })
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
		BackgroundTransparency = 0.35, BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.Y,
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
		Text = o.Text or "Color", TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, header)
	local swatch = New("Frame", {
		Size = UDim2.fromOffset(38, 18), Position = UDim2.new(1, -4, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = o.Default or Theme.Accent, BorderSizePixel = 0,
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
	local sliders = {}
	local function apply()
		swatch.BackgroundColor3 = color
		SleepScript.Flags[o.Flag or o.Text] = color
		if o.Callback then task.spawn(o.Callback, color) end
	end
	for _, c in ipairs({ "R", "G", "B" }) do
		sliders[c] = Slider(body, {
			Text = c, Min = 0, Max = 255, Default = math.floor(color[c] * 255),
			Callback = function()
				color = Color3.fromRGB(
					math.floor(sliders.R.Value), math.floor(sliders.G.Value), math.floor(sliders.B.Value))
				apply()
			end,
		})
	end
	function obj:Set(c)
		color = c
		sliders.R.Value = math.floor(c.R * 255)
		sliders.G.Value = math.floor(c.G * 255)
		sliders.B.Value = math.floor(c.B * 255)
		apply()
	end
	header.MouseButton1Click:Connect(function()
		local op = not body.Visible
		body.Visible = op
		Tween(body, 0.2, { Size = op and UDim2.new(1, 0, 0, 132) or UDim2.new(1, 0, 0, 0) })
	end)
	apply()
	return obj
end

Lib.Section, Lib.Label, Lib.Toggle = Section, Label, Toggle
Lib.Slider, Lib.Button, Lib.Keybind = Slider, Button, Keybind
Lib.Dropdown, Lib.ColorPicker = Dropdown, ColorPicker

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
local FINISHES = {
	"Vanilla", "Fade", "Slaughter", "Case Hardened", "Damascus", "Damascus Steel",
	"Crimson Web", "Doppler", "Marble Fade", "Tiger Tooth", "Blue Steel", "Rust Coat",
	"Night", "Ultraviolet", "Asiimov", "Hyper Beast", "Redline", "Vulcan",
	"Fire Serpent", "Dragon Lore", "Printstream", "Neo-Noir", "Wild Lotus",
	"Emerald", "Sapphire", "Ruby", "Black Pearl", "Gamma Doppler", "Lore",
	"Boreal Forest", "Scarlet", "Midnight", "Contraband", "Neon Rider", "Cyber",
}
local MATERIAL_PRESETS = {
	"Neon", "Metal", "Glass", "Ice", "Marble", "Granite", "Sand", "Foil", "Fabric",
	"SmoothPlastic", "Plastic", "DiamondPlate", "CorrodedMetal", "CorrodedMetal",
	"Slate", "Concrete", "Wood", "WoodPlanks", "Cobblestone", "Basalt", "Limestone",
}
local COLOR_PRESETS = {
	["Gold"] = Color3.fromRGB(255, 202, 84),
	["Silver"] = Color3.fromRGB(220, 224, 235),
	["Carbon"] = Color3.fromRGB(26, 26, 30),
	["Crimson"] = Color3.fromRGB(190, 30, 45),
	["Neon Purple"] = Color3.fromRGB(168, 96, 255),
	["Neon Blue"] = Color3.fromRGB(70, 170, 255),
	["Neon Green"] = Color3.fromRGB(80, 255, 150),
	["Toxic"] = Color3.fromRGB(190, 255, 60),
	["Obsidian"] = Color3.fromRGB(12, 12, 16),
	["Frost"] = Color3.fromRGB(180, 230, 255),
	["Sand"] = Color3.fromRGB(214, 188, 140),
	["White"] = Color3.fromRGB(245, 245, 250),
}

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
-- 6. CAMERA WATCH
--=====================================================================
Conn(Workspace:GetPropertyChangedSignal("CurrentCamera"), function()
	Camera = Workspace.CurrentCamera
end)

--=====================================================================
-- 7. FOV (real camera FOV, anti-revert)
--=====================================================================
local FOV = { Enabled = false, Value = 100, Original = nil }
SleepScript.FOV = FOV

RunService:BindToRenderStep("SleepFOV", Enum.RenderPriority.Camera.Value + 1, function()
	if not FOV.Enabled then return end
	local cam = Workspace.CurrentCamera
	if not cam then return end
	if math.abs(cam.FieldOfView - FOV.Value) > 0.05 then
		cam.FieldOfView = FOV.Value
	end
end)

function FOV:Reset()
	if FOV.Original then
		local cam = Workspace.CurrentCamera
		if cam then cam.FieldOfView = FOV.Original end
	end
end

--=====================================================================
-- 8. ESP (rebuilt)
--=====================================================================
local hasDrawing = false
do
	local ok = pcall(function()
		local s = Drawing.new("Square")
		s:Remove()
	end)
	hasDrawing = ok
end

local ESP = {
	Enabled = false,
	Mode = hasDrawing and "Drawing" or "SelectionBox", -- Drawing / SelectionBox
	Chams = true, Boxes = true, Names = true, Health = true, Distance = true,
	Weapon = true, TeamCheck = true, UseTeamColor = true,
	MaxDistance = 1500, Color = Color3.fromRGB(255, 255, 255),
	FillAlpha = 0.2, Thickness = 1,
	Objects = {}, Debug = "",
	HasDrawing = hasDrawing,
}
SleepScript.ESP = ESP

--// character resolver -------------------------------------------------
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
	local best, bestY
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and (not bestY or d.Position.Y > bestY) then
			best, bestY = d, d.Position.Y
		end
	end
	return best
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
	return nil
end

local function espColorFor(plr)
	if ESP.UseTeamColor and plr.TeamColor then return plr.TeamColor.Color end
	return ESP.Color
end

local function destroyESP(plr)
	local d = ESP.Objects[plr]
	if not d then return end
	if d.Highlight and d.Highlight.Parent then d.Highlight:Destroy() end
	if d.Billboard and d.Billboard.Parent then d.Billboard:Destroy() end
	if d.SelectionBox and d.SelectionBox.Parent then d.SelectionBox:Destroy() end
	if d.Box then pcall(function() d.Box:Remove() end) end
	if d.Fill then pcall(function() d.Fill:Remove() end) end
	ESP.Objects[plr] = nil
end

local function createESP(plr)
	local char = resolveCharacter(plr)
	if not char then return false end
	local anchor = findAnchor(char)
	local hum = findHumanoid(char)
	if not anchor or not hum then return false end

	local d = { Player = plr, Character = char, Anchor = anchor, Humanoid = hum }

	d.Highlight = New("Highlight", {
		Name = "SleepChams", Adornee = char,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		FillTransparency = 1, OutlineTransparency = 1,
		FillColor = espColorFor(plr), OutlineColor = espColorFor(plr),
	}, char)

	d.SelectionBox = New("SelectionBox", {
		Name = "SleepBox", Adornee = char, LineThickness = ESP.Thickness,
		Color3 = espColorFor(plr), Transparency = 1, SurfaceTransparency = 1,
		Visible = false,
	}, Camera)

	local bb = New("BillboardGui", {
		Name = "SleepTag", Adornee = anchor,
		Size = UDim2.fromOffset(200, 62),
		StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0),
		AlwaysOnTop = true, LightInfluence = 0, MaxDistance = math.huge,
		Enabled = false,
	}, anchor)
	d.Billboard = bb

	d.Name = New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold, TextSize = 13, Text = plr.Name,
		TextColor3 = espColorFor(plr), TextStrokeTransparency = 0.4,
		TextStrokeColor3 = Color3.new(0, 0, 0),
	}, bb)
	d.Info = New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, 16),
		BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11,
		Text = "", TextColor3 = Theme.Sub, TextStrokeTransparency = 0.5,
		TextStrokeColor3 = Color3.new(0, 0, 0),
	}, bb)
	local barBg = New("Frame", {
		Size = UDim2.new(0, 90, 0, 5), Position = UDim2.new(0.5, 0, 0, 32),
		AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromRGB(15, 15, 15),
		BackgroundTransparency = 0.3, BorderSizePixel = 0,
	}, bb)
	Corner(barBg, 3)
	d.HealthBar = New("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Theme.Good, BorderSizePixel = 0 }, barBg)
	Corner(d.HealthBar, 3)

	if hasDrawing then
		d.Box = Drawing.new("Square")
		d.Box.Thickness = ESP.Thickness
		d.Box.Filled = false
		d.Box.Visible = false
		d.Fill = Drawing.new("Square")
		d.Fill.Filled = true
		d.Fill.Transparency = ESP.FillAlpha
		d.Fill.Visible = false
	end

	ESP.Objects[plr] = d
	return true
end

local function refreshESP()
	for plr, d in pairs(ESP.Objects) do
		local ok = plr.Parent ~= nil
			and d.Character and d.Character.Parent
			and d.Humanoid and d.Humanoid.Parent
			and d.Humanoid.Health > 0
		if not ok then destroyESP(plr) end
	end
	if not ESP.Enabled then return end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and not ESP.Objects[plr] then
			createESP(plr)
		end
	end
	ESP.Debug = string.format("tracked: %d", (function()
		local n = 0
		for _ in pairs(ESP.Objects) do n = n + 1 end
		return n
	end)())
end
ESP.Refresh = refreshESP

local function updateESP()
	if not ESP.Enabled then
		for _, d in pairs(ESP.Objects) do
			if d.Highlight then d.Highlight.FillTransparency = 1; d.Highlight.OutlineTransparency = 1 end
			if d.Billboard then d.Billboard.Enabled = false end
			if d.SelectionBox then d.SelectionBox.Visible = false end
			if d.Box then d.Box.Visible = false end
			if d.Fill then d.Fill.Visible = false end
		end
		return
	end

	local cam = Workspace.CurrentCamera
	if not cam then return end
	local myPos = cam.CFrame.Position
	local myTeam = LocalPlayer.Team

	for plr, d in pairs(ESP.Objects) do
		local char = d.Character
		local hum = d.Humanoid
		local anchor = d.Anchor
		local valid = char and char.Parent and hum and hum.Parent and hum.Health > 0 and anchor and anchor.Parent
		local skip = false
		if valid and ESP.TeamCheck and myTeam and plr.Team and plr.Team == myTeam then skip = true end

		if not valid or skip then
			if d.Highlight then d.Highlight.FillTransparency = 1; d.Highlight.OutlineTransparency = 1 end
			if d.Billboard then d.Billboard.Enabled = false end
			if d.SelectionBox then d.SelectionBox.Visible = false end
			if d.Box then d.Box.Visible = false end
			if d.Fill then d.Fill.Visible = false end
			continue
		end

		local dist = (anchor.Position - myPos).Magnitude
		local col = espColorFor(plr)
		local inRange = dist <= ESP.MaxDistance

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
				d.Name.Text = plr.Name
				d.Name.TextColor3 = col
				d.HealthBar.Parent.Visible = ESP.Health
				local hp = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
				d.HealthBar.Size = UDim2.new(hp, 0, 1, 0)
				d.HealthBar.BackgroundColor3 = Color3.fromRGB(
					math.floor(255 * (1 - hp)), math.floor(255 * hp), 60)
				local parts = {}
				if ESP.Distance then parts[#parts + 1] = ("%dm"):format(math.floor(dist)) end
				if ESP.Weapon then
					local w = char:FindFirstChildOfClass("Tool")
					local a = plr:GetAttribute("Weapon") or plr:GetAttribute("CurrentWeapon")
						or char:GetAttribute("Weapon")
					parts[#parts + 1] = w and w.Name or (a and tostring(a)) or "-"
				end
				d.Info.Visible = #parts > 0
				d.Info.Text = table.concat(parts, "  •  ")
			end
		end

		if d.SelectionBox then
			d.SelectionBox.Adornee = char
			d.SelectionBox.Color3 = col
			d.SelectionBox.LineThickness = ESP.Thickness
			d.SelectionBox.Transparency = (ESP.Boxes and inRange and ESP.Mode == "SelectionBox") and 0 or 1
			d.SelectionBox.Visible = ESP.Boxes and inRange and ESP.Mode == "SelectionBox"
		end

		if hasDrawing and d.Box then
			local want = inRange and ESP.Boxes and ESP.Mode == "Drawing"
			if want then
				local cf, size = char:GetBoundingBox()
				local topW = (cf * CFrame.new(0, size.Y / 2, 0)).Position
				local botW = (cf * CFrame.new(0, -size.Y / 2, 0)).Position
				local rW = (cf * CFrame.new(size.X / 2, 0, 0)).Position
				local lW = (cf * CFrame.new(-size.X / 2, 0, 0)).Position
				local t2, tOn = cam:WorldToViewportPoint(topW)
				local b2, bOn = cam:WorldToViewportPoint(botW)
				local r2 = cam:WorldToViewportPoint(rW)
				local l2 = cam:WorldToViewportPoint(lW)
				if tOn or bOn then
					local x1 = math.min(l2.X, r2.X)
					local x2 = math.max(l2.X, r2.X)
					local y1 = math.min(t2.Y, b2.Y)
					local y2 = math.max(t2.Y, b2.Y)
					local w = math.max(x2 - x1, 6)
					local h = math.max(y2 - y1, 6)
					d.Box.Visible = true
					d.Box.Color = col
					d.Box.Thickness = ESP.Thickness
					d.Box.Position = Vector2.new(x1 - 1, y1 - 1)
					d.Box.Size = Vector2.new(w + 2, h + 2)
					d.Fill.Visible = ESP.FillAlpha > 0
					d.Fill.Color = col
					d.Fill.Transparency = ESP.FillAlpha
					d.Fill.Position = Vector2.new(x1, y1)
					d.Fill.Size = Vector2.new(w, h)
				else
					d.Box.Visible = false
					d.Fill.Visible = false
				end
			else
				d.Box.Visible = false
				d.Fill.Visible = false
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
-- 9. SKIN CHANGER (rebuilt: weapon -> skin -> apply)
--=====================================================================
local Skin = {
	Enabled = false,
	Weapon = "Auto (equipped)",
	SkinName = "None",
	SkinId = "",
	Material = "Keep",
	ColorName = "Keep",
	UseTexture = true,
	UseMaterial = false,
	UseColor = false,
	Glow = false,
	GlowBrightness = 3,
	Particles = false,
	DeepMesh = false,
	Targets = { Knife = true, Gloves = true, Guns = true, Arms = false },
	Library = {},
	Tracked = {},
	Originals = {},
	Detected = "unknown",
}
SleepScript.Skin = Skin

local ALL_NAMES = {}
for _, t in ipairs({ WEAPONS, KNIVES, GLOVES }) do
	for _, n in ipairs(t) do ALL_NAMES[#ALL_NAMES + 1] = n end
end

local function clean(s) return (s:lower():gsub("[%s_%-%.]", "")) end

--// skin library from game files
local function buildLibrary()
	Skin.Library = {}
	local seen = {}
	local count = 0
	local function consider(name, id, src)
		if not id or id == "" or type(id) ~= "string" then return end
		if seen[id] then return end
		seen[id] = true
		count = count + 1
		local key = name
		if Skin.Library[key] then key = name .. " [" .. src .. "]" end
		if Skin.Library[key] then key = name .. " #" .. count end
		Skin.Library[key] = { Id = id, Source = src }
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
			if id then consider(d.Name, id, d.ClassName) end
		end
	end
	scan(ReplicatedStorage, 40000)
	for _, nm in ipairs({ "Skins", "Skin", "Camos", "Camo", "Finishes", "Textures", "Assets", "Weapons" }) do
		local f = ReplicatedStorage:FindFirstChild(nm)
		if f then scan(f, 8000) end
	end
	return count
end

local function libraryOptions()
	local o = { "None" }
	local keys = {}
	for k in pairs(Skin.Library) do keys[#keys + 1] = k end
	table.sort(keys)
	for _, k in ipairs(keys) do o[#o + 1] = k end
	for _, f in ipairs(FINISHES) do
		if not table.find(o, f) then o[#o + 1] = f end
	end
	return o
end

--// model / part matching
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
	return nil
end
Skin.DetectWeapon = detectWeapon

local function matchesTarget(model)
	local target = Skin.Weapon
	if target == "Auto (equipped)" or target == "" then return true end
	local ct = clean(target)
	local cn = clean(model.Name)
	if cn:find(ct, 1, true) or ct:find(cn, 1, true) then return true end
	local detected = detectWeapon(model)
	if detected and detected == target then return true end
	return false
end

local function classifyPart(part, model)
	local n = part.Name:lower()
	if n:find("knife") or n:find("karambit") or n:find("bayonet") or n:find("dagger")
		or n:find("blade") or n:find("talon") or n:find("flip") or n:find("gut") then
		return "Knife"
	end
	if n:find("glove") or n:find("wrap") then return "Gloves" end
	if n:find("hand") or n:find("sleeve") then return "Arms" end
	local c = clean(part.Name)
	for _, w in ipairs(WEAPONS) do
		local cw = clean(w)
		if #cw >= 3 and c:find(cw, 1, true) then return "Guns" end
	end
	local det = detectWeapon(model)
	if det then
		for _, k in ipairs(KNIVES) do if k == det then return "Knife" end end
		for _, g in ipairs(GLOVES) do if g == det then return "Gloves" end end
		return "Guns"
	end
	if n:find("arm") then return "Arms" end
	return "Guns"
end

--// apply helpers
local function clearSkinChildren(part)
	for _, c in ipairs(part:GetChildren()) do
		if c.Name:sub(1, 9) == "SleepSkin" then c:Destroy() end
	end
end

local function applyTexture(part, id)
	if not Skin.UseTexture or not id or id == "" then clearSkinChildren(part) return end
	if part:IsA("MeshPart") then
		pcall(function() part.TextureID = id end)
		return
	end
	local sm = part:FindFirstChildOfClass("SpecialMesh")
	if sm then
		pcall(function() sm.TextureId = id end)
	end
	local faces = { "Front", "Back", "Left", "Right", "Top", "Bottom" }
	for i, f in ipairs(faces) do
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

local function applyDeepMesh(part, model)
	if not Skin.DeepMesh or Skin.Weapon == "Auto (equipped)" then return end
	local key = clean(Skin.Weapon)
	local src
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
		if d:IsA("MeshPart") or d:IsA("SpecialMesh") or d:IsA("Model") or d:IsA("Tool") then
			if clean(d.Name):find(key, 1, true) then src = d break end
		end
	end
	if not src then return end
	local meshPart = src:IsA("MeshPart") and src or src:FindFirstChildOfClass("MeshPart")
	if meshPart and part:IsA("MeshPart") then
		pcall(function()
			if meshPart.MeshId ~= "" then part.MeshId = meshPart.MeshId end
			if meshPart.TextureID ~= "" then part.TextureID = meshPart.TextureID end
		end)
	end
end

local function restorePart(part)
	local o = Skin.Originals[part]
	if not o then return end
	pcall(function()
		part.Material = o.Material
		part.Color = o.Color
		part.Reflectance = o.Reflectance
		if o.TextureID and part:IsA("MeshPart") then part.TextureID = o.TextureID end
	end)
	clearSkinChildren(part)
	local l = part:FindFirstChild("SleepGlow")
	if l then l.Enabled = false end
	local p = part:FindFirstChild("SleepParticles")
	if p then p.Enabled = false end
end

local function stylePart(part, model)
	if not part:IsA("BasePart") then return end
	if not Skin.Enabled then return end
	if not matchesTarget(model) then return end
	local kind = classifyPart(part, model)
	if not Skin.Targets[kind] then return end

	if not Skin.Originals[part] then
		Skin.Originals[part] = {
			Material = part.Material, Color = part.Color,
			Reflectance = part.Reflectance,
			TextureID = part:IsA("MeshPart") and part.TextureID or nil,
		}
	end

	local lib = Skin.Library[Skin.SkinName]
	if Skin.SkinName == "None" then
		clearSkinChildren(part)
	elseif lib then
		applyTexture(part, lib.Id)
	else
		-- builtin finish name: still apply a procedural texture-less look
		clearSkinChildren(part)
	end

	if Skin.UseMaterial and Skin.Material ~= "Keep" then
		local ok, m = pcall(function() return Enum.Material[Skin.Material] end)
		if ok and m then part.Material = m end
	end
	if Skin.UseColor and COLOR_PRESETS[Skin.ColorName] then
		part.Color = COLOR_PRESETS[Skin.ColorName]
	end
	if Skin.UseColor and Skin.ColorName == "Rainbow" then
		part.Color = Color3.fromHSV(Skin.Hue or 0, 0.85, 1)
	end

	if Skin.Glow then
		local l = part:FindFirstChild("SleepGlow")
		if not l then
			l = New("PointLight", { Name = "SleepGlow", Range = 10 }, part)
		end
		l.Color = part.Color
		l.Brightness = Skin.GlowBrightness
		l.Enabled = true
	else
		local l = part:FindFirstChild("SleepGlow")
		if l then l.Enabled = false end
	end

	if Skin.Particles then
		local p = part:FindFirstChild("SleepParticles")
		if not p then
			p = New("ParticleEmitter", {
				Name = "SleepParticles", Rate = 12, Lifetime = NumberRange.new(0.3, 0.7),
				Speed = NumberRange.new(0.2, 0.8), Size = NumberSequence.new(0.16),
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

	if Skin.DeepMesh then applyDeepMesh(part, model) end
end

local function isViewModel(m)
	if not m:IsA("Model") then return false end
	if m.Parent == Workspace.CurrentCamera then return true end
	local n = m.Name:lower()
	return n:find("view") or n:find("worldmodel") or n:find("arms") or n:find("hands")
		or n:find("weapon") or n:find("fps") or n:find("tool") or n:find("viewmodel")
end

local function trackModel(model)
	if Skin.Tracked[model] then return end
	Skin.Tracked[model] = true
	local det = detectWeapon(model)
	if det then Skin.Detected = det end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then stylePart(d, model) end
	end
end

local function scanForViewModels()
	local seen = {}
	local function scan(container)
		for _, c in ipairs(container:GetChildren()) do
			if isViewModel(c) and not seen[c] then
				seen[c] = true
				trackModel(c)
			end
		end
	end
	scan(Workspace.CurrentCamera)
	scan(Workspace)
	local char = LocalPlayer.Character
	if char then scan(char) end
end
Skin.Scan = scanForViewModels

local function restyleAll()
	for model in pairs(Skin.Tracked) do
		if not model.Parent then
			Skin.Tracked[model] = nil
		else
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then stylePart(d, model) end
			end
		end
	end
end
Skin.Restyle = restyleAll

local function clearAll()
	for part in pairs(Skin.Originals) do
		if part and part.Parent then restorePart(part) end
	end
end
Skin.ClearAll = clearAll

Conn(Workspace.CurrentCamera.ChildAdded, function(i)
	if Skin.Enabled and isViewModel(i) then trackModel(i) end
end)
Conn(Workspace.ChildAdded, function(i)
	if Skin.Enabled and isViewModel(i) then trackModel(i) end
end)

--=====================================================================
-- 10. MOVEMENT (rebuilt bhop)
--=====================================================================
local Move = {
	Bhop = false, InfJump = false, HoldingSpace = false, SpaceRequest = false,
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
	if res and (hrp.Position.Y - res.Position.Y) <= 5.0 then return true end
	return false
end

local function doJump(hum)
	local ok = pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
	if not ok then hum.Jump = true end
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
Conn(UserInputService.JumpRequest, function() Move.SpaceRequest = true end)

-- instant re-jump on landing
local function hookHumanoid()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	Conn(hum.StateChanged, function(_, new)
		if not Move.Bhop or not Move.HoldingSpace then return end
		if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if isGrounded(hum, hrp) then doJump(hum) end
		end
	end)
end

local bhopCD = 0
Conn(RunService.Heartbeat, function()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")

	if Move.Bhop and Move.HoldingSpace and os.clock() >= bhopCD then
		if isGrounded(hum, hrp) then
			doJump(hum)
			bhopCD = os.clock() + 0.05
		end
	end

	if Move.InfJump and (Move.HoldingSpace or Move.SpaceRequest) then
		if hum:GetState() == Enum.HumanoidStateType.Freefall
			or hum:GetState() == Enum.HumanoidStateType.Jumping then
			doJump(hum)
		end
		Move.SpaceRequest = false
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
	if flyBV then flyBV:Destroy(); flyBV = nil end
	if flyBG then flyBG:Destroy(); flyBG = nil end
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then hrp.Velocity = Vector3.new(0, 0, 0) end
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
-- 11. VISUALS
--=====================================================================
local Vis = {
	CustomSky = false, SkyPreset = "Deep Space", Atmosphere = false, Bloom = false,
	Fullbright = false, Aura = false, TimeOfDay = 14,
}
SleepScript.Vis = Vis

local function applySky(name)
	if Vis.SkyInstance then Vis.SkyInstance:Destroy() Vis.SkyInstance = nil end
	if name == "Game Default" then return end
	local p = SKY_PRESETS[name]
	if type(p) ~= "table" then return end
	Vis.SkyInstance = New("Sky", {
		Name = "SleepSky", SkyboxUp = p.Up, SkyboxDn = p.Dn, SkyboxLf = p.Lf,
		SkyboxRt = p.Rt, SkyboxFt = p.Ft, SkyboxBk = p.Bk, StarCount = 5000,
	}, Lighting)
end

function Vis.SetCustomSky(id)
	if Vis.SkyInstance then Vis.SkyInstance:Destroy() end
	local u = "rbxassetid://" .. tostring(id):gsub("%D", "")
	Vis.SkyInstance = New("Sky", {
		Name = "SleepSky", SkyboxUp = u, SkyboxDn = u, SkyboxLf = u,
		SkyboxRt = u, SkyboxFt = u, SkyboxBk = u, StarCount = 5000,
	}, Lighting)
end

local fbBackup
local function setFullbright(on)
	if on then
		fbBackup = {
			Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
			Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
			GlobalShadows = Lighting.GlobalShadows,
		}
		Lighting.Ambient = Color3.fromRGB(180, 180, 180)
		Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.GlobalShadows = false
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

function Overlay:Toggle(state)
	self.Visible = state
	oFrame.Visible = state
end

--=====================================================================
-- 13. FPS BOOST
--=====================================================================
local Boost = { Enabled = false }
SleepScript.Boost = Boost

local function applyBoost(on)
	local L = Lighting
	if on then
		Boost.Backup = {
			GlobalShadows = L.GlobalShadows, FogEnd = L.FogEnd,
			EnvironmentDiffuseScale = L.EnvironmentDiffuseScale,
			EnvironmentSpecularScale = L.EnvironmentSpecularScale,
			QualityLevel = (function()
				local ok, v = pcall(function() return settings().Rendering.QualityLevel end)
				return ok and v or nil
			end)(),
			Decoration = Workspace.Terrain.Decoration,
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
		for _, e in ipairs(L:GetChildren()) do
			if e:IsA("PostEffect") then
				e:SetAttribute("SleepWasEnabled", e.Enabled)
				e.Enabled = false
			end
		end
	else
		local b = Boost.Backup
		if b then
			L.GlobalShadows = b.GlobalShadows
			L.FogEnd = b.FogEnd
			L.EnvironmentDiffuseScale = b.EnvironmentDiffuseScale
			L.EnvironmentSpecularScale = b.EnvironmentSpecularScale
			Workspace.Terrain.Decoration = b.Decoration
			Workspace.Terrain.WaterWaveSize = b.WaterWaveSize
			Workspace.Terrain.WaterWaveSpeed = b.WaterWaveSpeed
			Workspace.Terrain.WaterReflectance = b.WaterReflectance
			Workspace.Terrain.WaterTransparency = b.WaterTransparency
			if b.QualityLevel then pcall(function() settings().Rendering.QualityLevel = b.QualityLevel end) end
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
	elseif lastSafe then
		hrp.CFrame = lastSafe + Vector3.new(0, 8, 0)
		hrp.Velocity = Vector3.zero
	end
end)

Conn(LocalPlayer.Idled, function()
	if not Bypass.AntiAfk then return end
	VirtualUser:Button2Down(Vector2.zero, Workspace.CurrentCamera.CFrame)
	task.wait(1)
	VirtualUser:Button2Up(Vector2.zero, Workspace.CurrentCamera.CFrame)
end)

task.spawn(function()
	while not SleepScript.Unloaded do
		if Bypass.AntiRevert then
			local hum = GetHum(LocalPlayer)
			if hum and Move.SpeedEnabled and math.abs(hum.WalkSpeed - Move.WalkSpeed) > 0.1 then
				hum.WalkSpeed = Move.WalkSpeed
			end
		end
		task.wait(0.35)
	end
end)

--=====================================================================
-- 15. HELPERS
--=====================================================================
local function deepScan()
	print("===== SleepScript :: Deep Scan =====")
	local r, w, s = {}, {}, {}
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
		local n = d.Name:lower()
		if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction"))
			and (n:find("skin") or n:find("equip") or n:find("apply") or n:find("inventory")) then
			r[#r + 1] = d:GetFullName() .. " [" .. d.ClassName .. "]"
		end
		if d:IsA("Model") and (n:find("knife") or n:find("glove") or n:find("gun")
			or n:find("weapon") or n:find("ak") or n:find("m4") or n:find("awp")) then
			w[#w + 1] = d:GetFullName()
		end
		if (d:IsA("Decal") or d:IsA("Texture") or d:IsA("StringValue"))
			and (n:find("skin") or n:find("camo") or n:find("finish")) then
			s[#s + 1] = d:GetFullName()
		end
	end
	for _, v in ipairs(r) do print("  REMOTE >", v) end
	for _, v in ipairs(w) do print("  MODEL  >", v) end
	for _, v in ipairs(s) do print("  SKIN   >", v) end
	print("===== End =====")
	Notify("Deep Scan", #r .. " remotes / " .. #w .. " models / " .. #s .. " skins", 4)
end

--=====================================================================
-- 16. CONFIG
--=====================================================================
local ConfigName = "SleepScript_BloxStrike.json"
local function saveConfig()
	local ok = pcall(function()
		writefile(ConfigName, HttpService:JSONEncode({
			ESP = { Enabled = ESP.Enabled, Boxes = ESP.Boxes, Chams = ESP.Chams,
				Names = ESP.Names, Health = ESP.Health, Distance = ESP.Distance,
				TeamCheck = ESP.TeamCheck, MaxDistance = ESP.MaxDistance, Mode = ESP.Mode },
			Skin = { Weapon = Skin.Weapon, SkinName = Skin.SkinName, Glow = Skin.Glow },
			Move = { Bhop = Move.Bhop, WalkSpeed = Move.WalkSpeed },
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
		ESP.Boxes = d.ESP.Boxes ~= false
		ESP.Chams = d.ESP.Chams ~= false
		ESP.Names = d.ESP.Names ~= false
		ESP.Health = d.ESP.Health ~= false
		ESP.Distance = d.ESP.Distance ~= false
		ESP.MaxDistance = d.ESP.MaxDistance or 1500
		if d.ESP.Enabled then ESP.Enabled = true refreshESP() end
	end
	if d.Skin then Skin.Weapon = d.Skin.Weapon or Skin.Weapon Skin.SkinName = d.Skin.SkinName or "None" end
	if d.Move then Move.Bhop = d.Move.Bhop or false Move.WalkSpeed = d.Move.WalkSpeed or 16 end
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
	Misc     = Window.MakeTab("Misc / Perf", "⚙"),
	Settings = Window.MakeTab("Settings", "✱"),
}

--// -------- VISUALS --------
do
	local t = Tabs.Visuals.Content
	Section(t, "ESP / Wallhack")
	local dbg = Label(t, "tracked: 0")
	Toggle(t, { Text = "Enable ESP", Default = false, Flag = "ESPEnabled", Callback = function(v)
		ESP.Enabled = v
		if v then refreshESP() end
	end })
	Dropdown(t, { Text = "Box Mode", Options = { "Drawing", "SelectionBox" },
		Default = hasDrawing and "Drawing" or "SelectionBox",
		Callback = function(v)
			ESP.Mode = v
			if v == "Drawing" and not hasDrawing then
				Notify("ESP", "no Drawing API in this executor", 3)
			end
		end })
	Toggle(t, { Text = "Boxes", Default = true, Callback = function(v) ESP.Boxes = v end })
	Toggle(t, { Text = "Chams (Highlight)", Default = true, Callback = function(v) ESP.Chams = v end })
	Toggle(t, { Text = "Names", Default = true, Callback = function(v) ESP.Names = v end })
	Toggle(t, { Text = "Health Bar", Default = true, Callback = function(v) ESP.Health = v end })
	Toggle(t, { Text = "Distance", Default = true, Callback = function(v) ESP.Distance = v end })
	Toggle(t, { Text = "Weapon", Default = true, Callback = function(v) ESP.Weapon = v end })
	Toggle(t, { Text = "Team Check", Default = true, Callback = function(v) ESP.TeamCheck = v end })
	Toggle(t, { Text = "Team Colors", Default = true, Callback = function(v) ESP.UseTeamColor = v end })
	Slider(t, { Text = "Max Distance", Min = 100, Max = 4000, Default = 1500, Callback = function(v) ESP.MaxDistance = v end })
	Slider(t, { Text = "Fill Alpha", Min = 0, Max = 1, Default = 0.2, Decimals = 2, Callback = function(v) ESP.FillAlpha = v end })
	Slider(t, { Text = "Box Thickness", Min = 1, Max = 4, Default = 1, Callback = function(v) ESP.Thickness = v end })
	ColorPicker(t, { Text = "ESP Color", Default = Color3.fromRGB(255, 255, 255), Callback = function(c) ESP.Color = c end })
	Button(t, { Text = "Refresh ESP Targets", Callback = function()
		refreshESP()
		Notify("ESP", ESP.Debug, 2)
	end })

	Section(t, "Field Of View")
	local fovSlider
	Toggle(t, { Text = "Custom FOV", Default = false, Callback = function(v)
		if v then
			local cam = Workspace.CurrentCamera
			if cam and not FOV.Original then FOV.Original = cam.FieldOfView end
		end
		FOV.Enabled = v
		if not v then FOV:Reset() end
	end })
	fovSlider = Slider(t, { Text = "FOV Value", Min = 40, Max = 140, Default = 100, Callback = function(v)
		FOV.Value = v
		local cam = Workspace.CurrentCamera
		if cam and not FOV.Enabled then cam.FieldOfView = v end
	end })
	Button(t, { Text = "Reset FOV to game default", Callback = function() FOV:Reset() end })
	Button(t, { Text = "FOV presets: 90 / 110 / 120", Callback = function()
		FOV.Value = (FOV.Value >= 120) and 90 or (FOV.Value >= 110 and 120 or 110)
		fovSlider:Set(FOV.Value, true)
		Notify("FOV", "set to " .. FOV.Value, 2)
	end })

	Section(t, "World / Sky")
	Toggle(t, { Text = "Custom Sky", Default = false, Callback = function(v)
		Vis.CustomSky = v
		applySky(v and Vis.SkyPreset or "Game Default")
	end })
	Dropdown(t, { Text = "Sky Preset", Options = (function()
		local o = {}
		for k in pairs(SKY_PRESETS) do o[#o + 1] = k end
		table.sort(o)
		return o
	end)(), Default = "Deep Space", Callback = function(v)
		Vis.SkyPreset = v
		if Vis.CustomSky then applySky(v) end
	end })
	Button(t, { Text = "Apply Sky ID from clipboard", Callback = function()
		local ok, clip = pcall(function() return getclipboard() end)
		if ok and clip and clip ~= "" then
			Vis.SetCustomSky(clip)
			Notify("Sky", "applied: " .. clip, 3)
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
				Vis.BloomFx = New("BloomEffect", { Intensity = 1.2, Size = 24, Threshold = 0.9 }, Lighting)
			end
			Vis.BloomFx.Enabled = true
		elseif Vis.BloomFx then
			Vis.BloomFx.Enabled = false
		end
	end })
	Toggle(t, { Text = "Fullbright", Default = false, Callback = setFullbright })
	Slider(t, { Text = "Time Of Day", Min = 0, Max = 24, Default = 14, Callback = function(v) Lighting.ClockTime = v end })

	Section(t, "Effects")
	Toggle(t, { Text = "Player Aura Particles", Default = false, Callback = setAura })
end

--// -------- SKIN --------
do
	local t = Tabs.Skin.Content
	local status = Label(t, "detected weapon: unknown  |  library: not scanned")

	local function updateStatus()
		status.Text = string.format("detected weapon: %s  |  library: %d skins  |  target: %s",
			Skin.Detected,
			(function() local n = 0 for _ in pairs(Skin.Library) do n = n + 1 end return n end)(),
			Skin.Weapon)
	end

	Section(t, "1. Weapon")
	Dropdown(t, { Text = "Select Weapon / Knife", Options = (function()
		local o = { "Auto (equipped)" }
		for _, w in ipairs(WEAPONS) do o[#o + 1] = w end
		for _, k in ipairs(KNIVES) do o[#o + 1] = k end
		for _, g in ipairs(GLOVES) do o[#o + 1] = g end
		return o
	end)(), Default = "Auto (equipped)", Callback = function(v)
		Skin.Weapon = v
		updateStatus()
		restyleAll()
	end })

	Section(t, "2. Skin")
	Toggle(t, { Text = "Enable SkinChanger", Default = false, Flag = "SkinEnabled", Callback = function(v)
		Skin.Enabled = v
		if v then scanForViewModels() else clearAll() end
	end })
	local skinDd
	skinDd = Dropdown(t, { Text = "Skin from game files", Options = libraryOptions(), Default = "None",
		Callback = function(v)
			Skin.SkinName = v
			local lib = Skin.Library[v]
			Skin.SkinId = lib and lib.Id or ""
			restyleAll()
			Notify("Skin", v == "None" and "cleared" or ("applied: " .. v), 2)
		end })
	Button(t, { Text = "Rescan Game Skins (files)", Callback = function()
		local n = buildLibrary()
		skinDd:SetOptions(libraryOptions())
		updateStatus()
		Notify("Skin", "found " .. n .. " skin textures in game", 3)
	end })
	Button(t, { Text = "Rescan ViewModel", Callback = function()
		Skin.Tracked = {}
		scanForViewModels()
		updateStatus()
		Notify("Skin", "viewmodel rescanned", 2)
	end })

	Section(t, "3. Extra styling")
	Toggle(t, { Text = "Use Material", Default = false, Callback = function(v) Skin.UseMaterial = v restyleAll() end })
	Dropdown(t, { Text = "Material", Options = MATERIAL_PRESETS, Default = "Neon", Callback = function(v)
		Skin.Material = v
		restyleAll()
	end })
	Toggle(t, { Text = "Use Color", Default = false, Callback = function(v) Skin.UseColor = v restyleAll() end })
	Dropdown(t, { Text = "Color", Options = (function()
		local o = { "Rainbow" }
		local k = {}
		for c in pairs(COLOR_PRESETS) do k[#k + 1] = c end
		table.sort(k)
		for _, c in ipairs(k) do o[#o + 1] = c end
		return o
	end)(), Default = "Gold", Callback = function(v) Skin.ColorName = v restyleAll() end })
	Toggle(t, { Text = "Glow on weapon", Default = false, Callback = function(v) Skin.Glow = v restyleAll() end })
	Slider(t, { Text = "Glow Brightness", Min = 1, Max = 10, Default = 3, Callback = function(v)
		Skin.GlowBrightness = v
		restyleAll()
	end })
	Toggle(t, { Text = "Particles on weapon", Default = false, Callback = function(v) Skin.Particles = v restyleAll() end })
	Toggle(t, { Text = "Deep apply (copy mesh from game model)", Default = false,
		Callback = function(v) Skin.DeepMesh = v restyleAll() end })

	Section(t, "Apply to")
	Toggle(t, { Text = "Knives", Default = true, Callback = function(v) Skin.Targets.Knife = v restyleAll() end })
	Toggle(t, { Text = "Gloves", Default = true, Callback = function(v) Skin.Targets.Gloves = v restyleAll() end })
	Toggle(t, { Text = "Weapons", Default = true, Callback = function(v) Skin.Targets.Guns = v restyleAll() end })
	Toggle(t, { Text = "Arms / Sleeves", Default = false, Callback = function(v) Skin.Targets.Arms = v restyleAll() end })

	Section(t, "Actions")
	Button(t, { Text = "Apply now", Callback = function() restyleAll() Notify("Skin", "reapplied", 2) end })
	Button(t, { Text = "Clear / restore originals", Callback = function() clearAll() Notify("Skin", "restored", 2) end })
	Button(t, { Text = "Deep Scan game data (console)", Callback = deepScan })
	updateStatus()
end

--// -------- MOVEMENT --------
do
	local t = Tabs.Movement.Content
	Section(t, "Bunny Hop")
	Toggle(t, { Text = "Auto BunnyHop (hold Space)", Default = false, Flag = "Bhop", Callback = function(v) Move.Bhop = v end })
	Toggle(t, { Text = "Infinite Jump", Default = false, Callback = function(v) Move.InfJump = v end })
	Label(t, "Bhop jumps automatically the moment you touch the ground while Space is held.")
	Section(t, "Speed")
	Toggle(t, { Text = "Custom WalkSpeed", Default = false, Callback = function(v) Move.SpeedEnabled = v end })
	Slider(t, { Text = "WalkSpeed", Min = 8, Max = 200, Default = 16, Callback = function(v) Move.WalkSpeed = v end })
	Toggle(t, { Text = "Custom JumpPower", Default = false, Callback = function(v) Move.JumpEnabled = v end })
	Slider(t, { Text = "JumpPower", Min = 20, Max = 300, Default = 50, Callback = function(v) Move.JumpPower = v end })
	Section(t, "Sprint")
	Toggle(t, { Text = "Sprint on Hold", Default = false, Callback = function(v) Move.Sprint = v end })
	Keybind(t, { Text = "Sprint Key", Default = "LeftShift", Callback = function(k) Move.SprintKey = k end })
	Slider(t, { Text = "Sprint Speed", Min = 18, Max = 120, Default = 24, Callback = function(v) Move.SprintSpeed = v end })
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
	Toggle(t, { Text = "Anti Revert (keep local changes)", Default = false, Callback = function(v) Bypass.AntiRevert = v end })
	Section(t, "Diagnostics")
	Button(t, { Text = "Deep Scan Game Data (console)", Callback = deepScan })
	Button(t, { Text = "Print camera / character info", Callback = function()
		print("===== SleepScript Info =====")
		print("Place:", game.PlaceId, game.PlaceVersion)
		print("Camera:", Workspace.CurrentCamera)
		print("Character:", LocalPlayer.Character)
		print("Camera children:")
		for _, c in ipairs(Workspace.CurrentCamera:GetChildren()) do print("  ", c.ClassName, c.Name) end
		print("ESP:", ESP.Debug)
	end })
end

--// -------- SETTINGS --------
do
	local t = Tabs.Settings.Content
	Section(t, "Menu")
	Keybind(t, { Text = "Menu Toggle Key", Default = "RightShift", Callback = function(_, pressed)
		if pressed then Window:Toggle() end
	end })
	ColorPicker(t, { Text = "Accent Color", Default = Theme.Accent, Callback = function(c)
		Theme.Accent = c
		for _, reg in ipairs(AccentRegistry) do
			pcall(function() reg.inst[reg.prop] = c end)
		end
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
	Label(t, "SleepScript v" .. SleepScript.Version .. " for BloxStrike.\nESP • SkinChanger • AutoBhop • Visuals • FOV • Perf.\nRightShift — menu, F4 — overlay.")
end

Window:Select(Tabs.Visuals)

--=====================================================================
-- 18. LOOPS
--=====================================================================
local espTimer = 0
local skinTimer = 0
Conn(RunService.RenderStepped, function(dt)
	updateESP()

	espTimer += dt
	if espTimer >= 1 then
		espTimer = 0
		refreshESP()
	end

	skinTimer += dt
	if skinTimer >= 0.2 then
		skinTimer = 0
		if Skin.Enabled then
			scanForViewModels()
			if Skin.ColorName == "Rainbow" and Skin.UseColor then
				Skin.Hue = ((Skin.Hue or 0) + 0.07) % 1
			end
			restyleAll()
		end
		-- garbage collect originals
		for part in pairs(Skin.Originals) do
			if part and not part.Parent then Skin.Originals[part] = nil end
		end
	end
end)

Conn(LocalPlayer.CharacterAdded, function()
	task.wait(1)
	hookHumanoid()
	Skin.Tracked = {}
	if Skin.Enabled then scanForViewModels() end
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
	pcall(function() applyBoost(false) end)
	pcall(function() stopFly() end)
	pcall(function() clearAll() end)
	pcall(function()
		if Vis.SkyInstance then Vis.SkyInstance:Destroy() end
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
task.delay(0.8, function()
	Notify("Skin", "open SkinChanger -> Rescan Game Skins", 5)
end)
print("[SleepScript] loaded | UI: RightShift | Overlay: F4")
