-- IzttNick Hub | Custom Red UI (no Rayfield) | Press K to open / close
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local Stats = game:GetService("Stats")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--==================================================
-- CUSTOM UI LIBRARY (RED THEME)
--==================================================
local T = {
    bg       = Color3.fromRGB(120, 12, 18),
    top      = Color3.fromRGB(85, 8, 12),
    side     = Color3.fromRGB(100, 10, 15),
    element  = Color3.fromRGB(160, 25, 32),
    elementH = Color3.fromRGB(185, 40, 48),
    accent   = Color3.fromRGB(255, 225, 225),
    off      = Color3.fromRGB(70, 8, 10),
    text     = Color3.fromRGB(255, 255, 255),
    sub      = Color3.fromRGB(255, 200, 200),
    stroke   = Color3.fromRGB(255, 90, 90),
}

local function create(class, props, children)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then o[k] = v end
    end
    for _, c in ipairs(children or {}) do c.Parent = o end
    if props and props.Parent then o.Parent = props.Parent end
    return o
end

local function corner(p, r)
    return create("UICorner", {CornerRadius = UDim.new(0, r or 6), Parent = p})
end

local function stroke(p, c, t)
    return create("UIStroke", {Color = c or T.stroke, Thickness = t or 1, Transparency = 0.5,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = p})
end

local function label(parent, text, size, color, align)
    return create("TextLabel", {
        BackgroundTransparency = 1, Text = text, TextColor3 = color or T.text,
        Font = Enum.Font.GothamMedium, TextSize = size or 14,
        TextXAlignment = align or Enum.TextXAlignment.Left, Parent = parent,
    })
end

-- Remove old copy if script is re-executed
local function getGuiParent()
    local ok, ui = pcall(function() return gethui and gethui() end)
    if ok and ui then return ui end
    local ok2, core = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and core then return core end
    return LP:WaitForChild("PlayerGui")
end
local guiParent = getGuiParent()
for _, p in ipairs({guiParent, LP:WaitForChild("PlayerGui")}) do
    local old = p:FindFirstChild("IzttNickHub")
    if old then old:Destroy() end
end

local Gui = create("ScreenGui", {
    Name = "IzttNickHub", ResetOnSpawn = false, DisplayOrder = 999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
pcall(function() Gui.Parent = guiParent end)
if not Gui.Parent then Gui.Parent = LP:WaitForChild("PlayerGui") end

local MainFrame = create("Frame", {
    Name = "Main", Size = UDim2.fromOffset(600, 390), Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = T.bg, BorderSizePixel = 0,
    ClipsDescendants = true, Parent = Gui,
})
corner(MainFrame, 10)
stroke(MainFrame, T.stroke, 2)
local Scale = create("UIScale", {Scale = 1, Parent = MainFrame})
local fullSize = MainFrame.Size
local minimized = false

-- Top bar
local TopBar = create("Frame", {
    Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = T.top, BorderSizePixel = 0, Parent = MainFrame,
})
local TitleIcon = create("TextLabel", {
    Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(10, 6),
    BackgroundTransparency = 1, Text = "🔥", TextSize = 18, Font = Enum.Font.GothamBold,
    TextColor3 = T.text, Parent = TopBar,
})
local Title = label(TopBar, "IzttNick Hub", 16, T.text)
Title.Position = UDim2.fromOffset(38, 0)
Title.Size = UDim2.new(1, -150, 1, 0)
Title.Font = Enum.Font.GothamBold
local Hint = label(TopBar, "[K] toggle", 12, T.sub, Enum.TextXAlignment.Right)
Hint.Position = UDim2.new(1, -158, 0, 0)
Hint.Size = UDim2.fromOffset(80, 36)

local CloseBtn = create("TextButton", {
    Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -32, 0, 5),
    BackgroundColor3 = T.element, Text = "X", TextColor3 = T.text,
    Font = Enum.Font.GothamBold, TextSize = 14, AutoButtonColor = false, Parent = TopBar,
})
corner(CloseBtn, 6)

local MinBtn = create("TextButton", {
    Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -62, 0, 5),
    BackgroundColor3 = T.element, Text = "-", TextColor3 = T.text,
    Font = Enum.Font.GothamBold, TextSize = 16, AutoButtonColor = false, Parent = TopBar,
})
corner(MinBtn, 6)

-- Dragging
do
    local dragging, dragStart, startPos
    TopBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, i.Position, MainFrame.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- Sidebar + pages
local Side = create("ScrollingFrame", {
    Position = UDim2.fromOffset(0, 36), Size = UDim2.new(0, 140, 1, -36),
    BackgroundColor3 = T.side, BorderSizePixel = 0, ScrollBarThickness = 0,
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = MainFrame,
})
create("UIListLayout", {Padding = UDim.new(0, 4), Parent = Side})
create("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = Side})

local Pages = create("Frame", {
    Position = UDim2.fromOffset(140, 36), Size = UDim2.new(1, -140, 1, -36),
    BackgroundTransparency = 1, Parent = MainFrame,
})

-- Open / Close
local menuOpen = true
local menuKey = Enum.KeyCode.K
local function setMenu(open)
    menuOpen = open
    if open then
        MainFrame.Visible = true
        Scale.Scale = 0.85
        TweenService:Create(Scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {Scale = 1}):Play()
    else
        local tw = TweenService:Create(Scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {Scale = 0.85})
        tw:Play()
        tw.Completed:Connect(function()
            if not menuOpen then MainFrame.Visible = false end
        end)
    end
end
CloseBtn.MouseButton1Click:Connect(function() setMenu(false) end)

local function setMinimized(v)
    minimized = v
    if v then
        fullSize = MainFrame.Size
        Side.Visible = false
        Pages.Visible = false
        MinBtn.Text = "+"
        TweenService:Create(MainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
            Size = UDim2.new(fullSize.X.Scale, fullSize.X.Offset, 0, 36),
        }):Play()
    else
        MinBtn.Text = "-"
        TweenService:Create(MainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {Size = fullSize}):Play()
        task.delay(0.12, function()
            if not minimized then
                Side.Visible = true
                Pages.Visible = true
            end
        end)
    end
end
MinBtn.MouseButton1Click:Connect(function() setMinimized(not minimized) end)

-- Notifications
local NotifHolder = create("Frame", {
    Size = UDim2.fromOffset(250, 400), Position = UDim2.new(1, -260, 1, -410),
    BackgroundTransparency = 1, Parent = Gui,
})
create("UIListLayout", {
    VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder, Parent = NotifHolder,
})
local function Notify(title, content, duration)
    local f = create("Frame", {
        Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = T.top, BorderSizePixel = 0,
        BackgroundTransparency = 1, Parent = NotifHolder,
    })
    corner(f, 8)
    local st = stroke(f, T.stroke, 1.5)
    local t = label(f, title, 14, T.text)
    t.Font = Enum.Font.GothamBold
    t.Position = UDim2.fromOffset(10, 4); t.Size = UDim2.new(1, -20, 0, 20)
    local c = label(f, content, 12, T.sub)
    c.Position = UDim2.fromOffset(10, 24); c.Size = UDim2.new(1, -20, 0, 22)
    t.TextTransparency, c.TextTransparency = 1, 1
    TweenService:Create(f, TweenInfo.new(0.2), {BackgroundTransparency = 0.05}):Play()
    TweenService:Create(t, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
    TweenService:Create(c, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
    task.delay(duration or 3, function()
        if not f.Parent then return end
        TweenService:Create(f, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        TweenService:Create(t, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
        TweenService:Create(c, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
        TweenService:Create(st, TweenInfo.new(0.3), {Transparency = 1}):Play()
        Debris:AddItem(f, 0.35)
    end)
end

-- Tabs
local UI = {tabs = {}, registry = {}}
local Tab = {}
Tab.__index = Tab

local function register(tab, name, obj)
    UI.registry[tab.Name .. "/" .. name] = obj
end

local function selectTab(tab)
    for _, t in ipairs(UI.tabs) do
        local active = (t == tab)
        t.Page.Visible = active
        TweenService:Create(t.Button, TweenInfo.new(0.15), {
            BackgroundColor3 = active and T.element or T.side,
        }):Play()
        t.Label.TextColor3 = active and T.text or T.sub
        t.SetIconColor(active and T.text or T.sub)
    end
end

-- icon can be an emoji/glyph string, a number (asset id) or "rbxassetid://..."
function UI:CreateTab(name, icon)
    local tab = setmetatable({}, Tab)
    tab.Name = name
    tab.Button = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = T.side, Text = "",
        AutoButtonColor = false, Parent = Side,
    })
    corner(tab.Button, 6)

    local isImage = type(icon) == "number" or (type(icon) == "string" and icon:find("rbxassetid"))
    if isImage then
        local img = create("ImageLabel", {
            Size = UDim2.fromOffset(18, 18), Position = UDim2.new(0, 9, 0.5, -9),
            BackgroundTransparency = 1, ImageColor3 = T.sub,
            Image = type(icon) == "number" and ("rbxassetid://" .. icon) or icon, Parent = tab.Button,
        })
        tab.SetIconColor = function(c) img.ImageColor3 = c end
    else
        local glyph = create("TextLabel", {
            Size = UDim2.fromOffset(22, 22), Position = UDim2.new(0, 7, 0.5, -11),
            BackgroundTransparency = 1, Text = icon or "•", TextColor3 = T.sub,
            Font = Enum.Font.GothamMedium, TextSize = 16, Parent = tab.Button,
        })
        tab.SetIconColor = function(c) glyph.TextColor3 = c end
    end

    tab.Label = create("TextLabel", {
        Size = UDim2.new(1, -36, 1, 0), Position = UDim2.fromOffset(34, 0),
        BackgroundTransparency = 1, Text = name, TextColor3 = T.sub,
        Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
        Parent = tab.Button,
    })
    tab.Page = create("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 4, ScrollBarImageColor3 = T.accent, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = Pages,
    })
    create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tab.Page})
    create("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = tab.Page})
    tab.Button.MouseButton1Click:Connect(function() selectTab(tab) end)
    table.insert(UI.tabs, tab)
    if #UI.tabs == 1 then selectTab(tab) end
    return tab
end

local function newRow(tab, height)
    local row = create("Frame", {
        Size = UDim2.new(1, -4, 0, height or 34), BackgroundColor3 = T.element,
        BorderSizePixel = 0, Parent = tab.Page,
    })
    corner(row, 6)
    return row
end

function Tab:Section(name)
    local l = label(self.Page, name:upper(), 12, T.sub)
    l.Size = UDim2.new(1, -4, 0, 20)
    l.Font = Enum.Font.GothamBold
    return l
end

function Tab:Label(text)
    local row = newRow(self, 26)
    local l = label(row, text, 13, T.sub)
    l.Position = UDim2.fromOffset(12, 0)
    l.Size = UDim2.new(1, -24, 1, 0)
    return {Set = function(_, t) l.Text = t end}
end

function Tab:Button(name, cb)
    local row = newRow(self)
    local b = create("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = name,
        TextColor3 = T.text, Font = Enum.Font.GothamMedium, TextSize = 14,
        AutoButtonColor = false, Parent = row,
    })
    b.MouseEnter:Connect(function() TweenService:Create(row, TweenInfo.new(0.12), {BackgroundColor3 = T.elementH}):Play() end)
    b.MouseLeave:Connect(function() TweenService:Create(row, TweenInfo.new(0.12), {BackgroundColor3 = T.element}):Play() end)
    b.MouseButton1Click:Connect(function() task.spawn(cb) end)
end

function Tab:Toggle(name, default, cb)
    local row = newRow(self)
    local l = label(row, name, 14)
    l.Position = UDim2.fromOffset(12, 0); l.Size = UDim2.new(1, -70, 1, 0)
    local track = create("Frame", {
        Size = UDim2.fromOffset(38, 20), Position = UDim2.new(1, -48, 0.5, -10),
        BackgroundColor3 = T.off, BorderSizePixel = 0, Parent = row,
    })
    corner(track, 10)
    local knob = create("Frame", {
        Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(2, 2),
        BackgroundColor3 = T.text, BorderSizePixel = 0, Parent = track,
    })
    corner(knob, 8)
    local click = create("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = row})

    local obj = {Value = default and true or false}
    local function render()
        TweenService:Create(track, TweenInfo.new(0.15), {BackgroundColor3 = obj.Value and Color3.fromRGB(60, 220, 90) or T.off}):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {Position = obj.Value and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2)}):Play()
    end
    function obj:Set(v, silent)
        self.Value = v and true or false
        render()
        if not silent and cb then task.spawn(cb, self.Value) end
    end
    click.MouseButton1Click:Connect(function() obj:Set(not obj.Value) end)
    render()
    register(self, name, obj)
    return obj
end

function Tab:Slider(name, min, max, inc, default, cb)
    local row = newRow(self, 50)
    local l = label(row, name, 14)
    l.Position = UDim2.fromOffset(12, 4); l.Size = UDim2.new(1, -90, 0, 20)
    local vl = label(row, "", 13, T.sub, Enum.TextXAlignment.Right)
    vl.Position = UDim2.new(1, -80, 0, 4); vl.Size = UDim2.fromOffset(68, 20)
    local bar = create("Frame", {
        Size = UDim2.new(1, -24, 0, 8), Position = UDim2.fromOffset(12, 33),
        BackgroundColor3 = T.off, BorderSizePixel = 0, Parent = row,
    })
    corner(bar, 4)
    local fill = create("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.accent, BorderSizePixel = 0, Parent = bar})
    corner(fill, 4)

    local obj = {Value = default}
    local function fmt(v) return inc < 1 and string.format("%.2f", v) or tostring(math.floor(v)) end
    function obj:Set(v, silent)
        v = math.clamp(math.floor(v / inc + 0.5) * inc, min, max)
        self.Value = v
        fill.Size = UDim2.fromScale((v - min) / (max - min), 1)
        vl.Text = fmt(v)
        if not silent and cb then task.spawn(cb, v) end
    end
    local dragging = false
    local function update(x)
        local r = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        obj:Set(min + r * (max - min))
    end
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(i.Position.X)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            update(i.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    obj:Set(default, true)
    register(self, name, obj)
    return obj
end

function Tab:Input(name, placeholder, cb)
    local row = newRow(self)
    local l = label(row, name, 14)
    l.Position = UDim2.fromOffset(12, 0); l.Size = UDim2.new(0.5, -12, 1, 0)
    local box = create("TextBox", {
        Size = UDim2.new(0.5, -18, 0, 24), Position = UDim2.new(0.5, 6, 0.5, -12),
        BackgroundColor3 = T.off, Text = "", PlaceholderText = placeholder or "",
        PlaceholderColor3 = T.sub, TextColor3 = T.text, Font = Enum.Font.Gotham, TextSize = 13,
        ClearTextOnFocus = false, Parent = row,
    })
    corner(box, 5)
    local obj = {Box = box, Value = ""}
    function obj:Set(v)
        self.Value = tostring(v)
        box.Text = self.Value
        if cb then task.spawn(cb, self.Value) end
    end
    box.FocusLost:Connect(function()
        obj.Value = box.Text
        if cb then task.spawn(cb, box.Text) end
    end)
    register(self, name, obj)
    return obj
end

function Tab:Dropdown(name, options, default, cb)
    local row = create("Frame", {
        Size = UDim2.new(1, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = T.element, BorderSizePixel = 0, ClipsDescendants = true, Parent = self.Page,
    })
    corner(row, 6)
    create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Parent = row})
    local head = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Text = "", LayoutOrder = 1, Parent = row,
    })
    local l = label(head, name, 14)
    l.Position = UDim2.fromOffset(12, 0); l.Size = UDim2.new(0.5, -12, 1, 0)
    local vl = label(head, tostring(default or "Select") .. "  v", 13, T.sub, Enum.TextXAlignment.Right)
    vl.Position = UDim2.new(0.5, 0, 0, 0); vl.Size = UDim2.new(0.5, -12, 1, 0)
    vl.TextTruncate = Enum.TextTruncate.AtEnd

    local list = create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = T.top, BorderSizePixel = 0, Visible = false,
        ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        LayoutOrder = 2, Parent = row,
    })
    create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Parent = list})
    local search = create("TextBox", {
        Size = UDim2.new(1, -8, 0, 24), BackgroundColor3 = T.off, Text = "", PlaceholderText = "Search...",
        PlaceholderColor3 = T.sub, TextColor3 = T.text, Font = Enum.Font.Gotham, TextSize = 13,
        ClearTextOnFocus = false, LayoutOrder = -1, Visible = false, Parent = list,
    })
    corner(search, 5)

    local obj = {Value = default, Options = options or {}}
    local open = false
    local function setOpen(v)
        open = v
        list.Visible = v
        search.Visible = #obj.Options >= 6
        local h = math.max(#obj.Options, 1) * 26 + (search.Visible and 28 or 0)
        list.Size = UDim2.new(1, 0, 0, v and math.min(h, 160) or 0)
    end
    local function build()
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        for idx, opt in ipairs(obj.Options) do
            local b = create("TextButton", {
                Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Text = tostring(opt), LayoutOrder = idx,
                TextColor3 = T.text, Font = Enum.Font.Gotham, TextSize = 13, AutoButtonColor = false, Parent = list,
            })
            b.MouseEnter:Connect(function() b.BackgroundTransparency = 0.7; b.BackgroundColor3 = T.element end)
            b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
            b.MouseButton1Click:Connect(function()
                obj.Value = opt
                vl.Text = tostring(opt) .. "  v"
                setOpen(false)
                if cb then task.spawn(cb, opt) end
            end)
        end
    end
    function obj:Refresh(newOptions, keep)
        self.Options = newOptions or {}
        if not keep or not table.find(self.Options, self.Value) then
            self.Value = nil
            vl.Text = "Select  v"
        end
        build()
        if open then setOpen(true) end
    end
    search:GetPropertyChangedSignal("Text"):Connect(function()
        local q = search.Text:lower()
        for _, b in ipairs(list:GetChildren()) do
            if b:IsA("TextButton") then
                b.Visible = q == "" or b.Text:lower():find(q, 1, true) ~= nil
            end
        end
    end)
    function obj:Set(v, silent)
        self.Value = v
        vl.Text = tostring(v) .. "  v"
        if not silent and cb then task.spawn(cb, v) end
    end
    head.MouseButton1Click:Connect(function() setOpen(not open) end)
    build()
    register(self, name, obj)
    return obj
end

function Tab:ColorPicker(name, default, cb)
    local row = newRow(self, 56)
    local l = label(row, name, 14)
    l.Position = UDim2.fromOffset(12, 3); l.Size = UDim2.new(1, -24, 0, 20)
    local colors = {
        Color3.fromRGB(255, 40, 40), Color3.fromRGB(255, 140, 0), Color3.fromRGB(255, 255, 0),
        Color3.fromRGB(60, 255, 60), Color3.fromRGB(0, 255, 255), Color3.fromRGB(60, 120, 255),
        Color3.fromRGB(200, 60, 255), Color3.fromRGB(255, 255, 255),
    }
    local holder = create("Frame", {
        Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 28), BackgroundTransparency = 1, Parent = row,
    })
    create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = holder})
    for _, c in ipairs(colors) do
        local b = create("TextButton", {
            Size = UDim2.fromOffset(22, 22), BackgroundColor3 = c, Text = "", AutoButtonColor = false, Parent = holder,
        })
        corner(b, 11)
        stroke(b, Color3.new(1, 1, 1), 1.5)
        b.MouseButton1Click:Connect(function() if cb then task.spawn(cb, c) end end)
    end
end

--==================================================
-- TABS
--==================================================
local Main = UI:CreateTab("Main", "🏠")
local Combat = UI:CreateTab("Combat", "⚔️")
local Visuals = UI:CreateTab("Visuals", "👁️")
local Perf = UI:CreateTab("Performance", "⚡")
local Cross = UI:CreateTab("Crosshair", "🎯")
local TeleportTab = UI:CreateTab("Teleport", "🌀")
local WaypointTab = UI:CreateTab("Waypoints", "📍")
local PlayersTab = UI:CreateTab("Players", "👥")
local ChatTab = UI:CreateTab("Chat Spy", "💬")
local KeybindTab = UI:CreateTab("Keybinds", "⌨️")
local SettingsTab = UI:CreateTab("UI Settings", "⚙️")

--==================================================
-- STATE
--==================================================
local character, humanoid, root
local walkSpeedValue, jumpPowerValue = 16, 50
local flySpeed, flying = 50, false
local flyConnection, flyVelocity, flyGyro
local noclipEnabled = false
local normalGravity = workspace.Gravity

local cframeSpeedEnabled, cframeSpeedValue = false, 1
local hitboxExpanderEnabled, hitboxSize = false, 5

local espEnabled, snaplineEspEnabled = false, false
local rainbowCrosshair, xrayEnabled, touchImmunityEnabled = false, false, false
local highlights, billboards, snaplineObjects = {}, {}, {}
local espColor = Color3.fromRGB(255, 40, 40)
local snaplineColor = Color3.fromRGB(255, 255, 255)

local selectedPlayerName
local savedWaypoints, waypointNameToSave, selectedWaypointName = {}, "", nil
local followConnection
local autoRejoinEnabled = false

local autoAimEnabled, aimbotHold = false, false
local aimPart, fovRadius, showFOV, aimSmoothness = "Head", 150, false, 0.2
local teamCheck, wallCheck = true, false

local keybinds = {Fly = Enum.KeyCode.T, Noclip = Enum.KeyCode.N}
local Mouse = LP:GetMouse()
local tracerOriginMode = "Center"
local boxEspEnabled, healthBarEnabled = false, false
local infiniteJumpEnabled, clickTpEnabled = false, false
local antiVoidEnabled, chatSpyEnabled, freecamEnabled = false, false, false
local boxObjects = {}
local refreshKeyList = function() end
local freecamStop = function() end
local clearAllBoxes = function() end
local flyToggle, noclipToggle

local function getPlayerList()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then table.insert(names, p.Name) end
    end
    return names
end

local function getWaypointList()
    local names = {}
    for n in pairs(savedWaypoints) do table.insert(names, n) end
    if #names == 0 then table.insert(names, "No Waypoints Saved") end
    return names
end

-- Anti-AFK
LP.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- Auto rejoin
GuiService.ErrorMessageChanged:Connect(function()
    if autoRejoinEnabled then
        task.wait(2)
        TeleportService:Teleport(game.PlaceId, LP)
    end
end)

-- FOV circle
local FOVCircle = Drawing.new("Circle")
FOVCircle.Radius = fovRadius
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Thickness = 1.5
FOVCircle.Filled = false
FOVCircle.Visible = false

local function setupCharacter(char)
    character = char
    humanoid = char:WaitForChild("Humanoid")
    root = char:WaitForChild("HumanoidRootPart")
end
if LP.Character then task.spawn(setupCharacter, LP.Character) end

local function stopFly()
    flying = false
    if flyConnection then flyConnection:Disconnect() flyConnection = nil end
    if flyVelocity then flyVelocity:Destroy() flyVelocity = nil end
    if flyGyro then flyGyro:Destroy() flyGyro = nil end
end

LP.CharacterAdded:Connect(function(char)
    stopFly()
    if flyToggle then flyToggle:Set(false, true) end
    setupCharacter(char)
end)

--==================================================
-- LOOPS
--==================================================
RunService.Stepped:Connect(function()
    if character then
        if noclipEnabled then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
        if touchImmunityEnabled then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then part.CanTouch = false end
            end
        end
    end
end)

RunService.Heartbeat:Connect(function(dt)
    if humanoid and humanoid.Parent then
        humanoid.UseJumpPower = true
        if humanoid.WalkSpeed ~= walkSpeedValue then humanoid.WalkSpeed = walkSpeedValue end
        if humanoid.JumpPower ~= jumpPowerValue then humanoid.JumpPower = jumpPowerValue end
    end

    if cframeSpeedEnabled and root and humanoid and humanoid.MoveDirection.Magnitude > 0 then
        root.CFrame = root.CFrame + (humanoid.MoveDirection * cframeSpeedValue * dt * 16)
    end

    if hitboxExpanderEnabled then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LP and player.Character then
                local rp = player.Character:FindFirstChild("HumanoidRootPart")
                if rp then
                    rp.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
                    rp.Transparency = 0.7
                    rp.CanCollide = false
                end
            end
        end
    end
end)

--==================================================
-- MAIN TAB
--==================================================
Main:Section("Movement")
Main:Input("Walk Speed (1-500)", "16", function(text)
    local v = tonumber(text)
    if v then walkSpeedValue = math.clamp(math.floor(v), 1, 500) end
end)
Main:Input("Jump Power (1-500)", "50", function(text)
    local v = tonumber(text)
    if v then jumpPowerValue = math.clamp(math.floor(v), 1, 500) end
end)
noclipToggle = Main:Toggle("Noclip", false, function(v) noclipEnabled = v end)
Main:Toggle("Low Gravity", false, function(v) workspace.Gravity = v and 50 or normalGravity end)
Main:Toggle("CFrame Speed (Bypass Limit)", false, function(v) cframeSpeedEnabled = v end)
Main:Slider("CFrame Speed Multiplier", 1, 5, 0.5, 1, function(v) cframeSpeedValue = v end)
Main:Slider("Camera FOV", 70, 120, 1, 70, function(v) Camera.FieldOfView = v end)
Main:Button("Unlock Max Camera Zoom", function()
    LP.CameraMaxZoomDistance = 10000
    Notify("Zoom Unlocked", "You can now zoom out infinitely!", 3)
end)

local function setFly(value)
    if not value then stopFly() return end
    if flying or not root or not root.Parent then return end
    flying = true

    flyVelocity = Instance.new("BodyVelocity")
    flyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    flyVelocity.Velocity = Vector3.zero
    flyVelocity.Parent = root

    flyGyro = Instance.new("BodyGyro")
    flyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    flyGyro.P = 10000
    flyGyro.Parent = root

    flyConnection = RunService.RenderStepped:Connect(function()
        if not flying or not root or not root.Parent then stopFly() return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        local d = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then d += cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then d -= cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then d -= cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then d += cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then d += Vector3.yAxis end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then d -= Vector3.yAxis end
        local speed = flySpeed * (UIS:IsKeyDown(Enum.KeyCode.LeftShift) and 2 or 1)
        local target = d.Magnitude > 0 and d.Unit * speed or Vector3.zero
        flyVelocity.Velocity = flyVelocity.Velocity:Lerp(target, 0.2)
        flyGyro.CFrame = cam.CFrame
    end)
end

Main:Slider("Fly Speed", 1, 500, 1, 50, function(v) flySpeed = v end)
flyToggle = Main:Toggle("Fly", false, setFly)

-- Player proximity alert
Main:Section("Player Proximity Alert")
local proximityEnabled, detectionDistance, showPlayerAlerts, wasPlayerNearby = false, 20, true, false
Main:Toggle("Proximity Detection", false, function(v)
    proximityEnabled = v
    wasPlayerNearby = false
end)
Main:Slider("Detection Distance", 5, 100, 5, 20, function(v) detectionDistance = v end)
Main:Toggle("Show Player Alerts", true, function(v) showPlayerAlerts = v end)

RunService.Heartbeat:Connect(function()
    if not proximityEnabled or not root or not root.Parent or not humanoid or humanoid.Health <= 0 then return end
    local nearby = false
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LP and player.Character then
            local er = player.Character:FindFirstChild("HumanoidRootPart")
            local eh = player.Character:FindFirstChildOfClass("Humanoid")
            if er and eh and eh.Health > 0 and (root.Position - er.Position).Magnitude <= detectionDistance then
                nearby = true
                break
            end
        end
    end
    if showPlayerAlerts then
        if nearby and not wasPlayerNearby then
            Notify("Player Detected", "Someone is nearby!", 2)
        elseif not nearby and wasPlayerNearby then
            Notify("Area Clear", "No nearby players.", 2)
        end
    end
    wasPlayerNearby = nearby
end)

--==================================================
-- COMBAT TAB
--==================================================
local function isPartVisible(targetPart)
    if not wallCheck then return true end
    local origin = Camera.CFrame.Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LP.Character, targetPart.Parent}
    params.IgnoreWater = true
    return workspace:Raycast(origin, targetPart.Position - origin, params) == nil
end

local function getTargetPlayer()
    local closest, shortest = nil, fovRadius
    local mousePos = UIS:GetMouseLocation()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LP then continue end
        if teamCheck and LP.Team and player.Team == LP.Team then continue end
        local char = player.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local part = aimPart == "Random" and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")) or char:FindFirstChild(aimPart)
        if not part then continue end
        local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
        if onScreen then
            local dist = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
            if dist < shortest and isPartVisible(part) then
                shortest, closest = dist, part
            end
        end
    end
    return closest
end

RunService.RenderStepped:Connect(function()
    FOVCircle.Position = UIS:GetMouseLocation()
    FOVCircle.Radius = fovRadius
    FOVCircle.Visible = showFOV and autoAimEnabled
    if autoAimEnabled and aimbotHold and not freecamEnabled then
        local target = getTargetPlayer()
        if target then
            local cur = Camera.CFrame
            local goal = CFrame.new(cur.Position, target.Position)
            Camera.CFrame = cur:Lerp(goal, aimSmoothness)
        end
    end
end)

Combat:Section("Auto Aim (hold right mouse)")
Combat:Toggle("Enable Auto Aim", false, function(v) autoAimEnabled = v end)
Combat:Dropdown("Target Part", {"Head", "HumanoidRootPart", "Random"}, "Head", function(v) aimPart = v end)
Combat:Slider("Aim Smoothness", 0.05, 1, 0.05, 0.2, function(v) aimSmoothness = v end)
Combat:Toggle("Show FOV Circle", false, function(v) showFOV = v end)
Combat:Slider("FOV Radius", 50, 500, 10, 150, function(v) fovRadius = v end)
Combat:Toggle("Team Check", true, function(v) teamCheck = v end)
Combat:Toggle("Wall Check", false, function(v) wallCheck = v end)
Combat:Section("Hitbox")
Combat:Toggle("Hitbox Expander", false, function(v)
    hitboxExpanderEnabled = v
    if not v then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LP and player.Character then
                local rp = player.Character:FindFirstChild("HumanoidRootPart")
                if rp then rp.Size = Vector3.new(2, 2, 1); rp.Transparency = 1 end
            end
        end
    end
end)
Combat:Slider("Hitbox Size", 2, 20, 1, 5, function(v) hitboxSize = v end)

--==================================================
-- VISUALS TAB
--==================================================
local function clearESP(player)
    if highlights[player] then highlights[player]:Destroy() highlights[player] = nil end
    if billboards[player] then billboards[player]:Destroy() billboards[player] = nil end
    if snaplineObjects[player] then snaplineObjects[player]:Remove() snaplineObjects[player] = nil end
end

local function updateESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LP or (not espEnabled and not snaplineEspEnabled) then
            clearESP(player)
            continue
        end
        local char = player.Character
        local head = char and char:FindFirstChild("Head")
        if not char or not head or not root then
            clearESP(player)
            continue
        end

        if espEnabled then
            local h = highlights[player]
            if not h or h.Parent ~= char then
                if h then h:Destroy() end
                h = Instance.new("Highlight")
                h.Name = "IzttNickESP"
                h.Adornee = char
                h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                h.FillTransparency = 0.65
                h.OutlineTransparency = 0
                h.Parent = char
                highlights[player] = h
            end
            h.FillColor, h.OutlineColor = espColor, espColor

            local bb = billboards[player]
            local tl
            if not bb then
                bb = Instance.new("BillboardGui")
                bb.Name = "DistanceIndicator"
                bb.Size = UDim2.fromOffset(100, 40)
                bb.StudsOffset = Vector3.new(0, 3, 0)
                bb.AlwaysOnTop = true
                bb.Adornee = head
                tl = Instance.new("TextLabel")
                tl.Size = UDim2.fromScale(1, 1)
                tl.BackgroundTransparency = 1
                tl.TextScaled = true
                tl.Font = Enum.Font.Code
                tl.Parent = bb
                bb.Parent = head
                billboards[player] = bb
            else
                tl = bb:FindFirstChildOfClass("TextLabel")
            end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if tl and hrp then
                tl.Text = string.format("[%s] (%d studs)", player.Name, math.floor((hrp.Position - root.Position).Magnitude))
                tl.TextColor3 = espColor
            end
        else
            if highlights[player] then highlights[player]:Destroy() highlights[player] = nil end
            if billboards[player] then billboards[player]:Destroy() billboards[player] = nil end
        end

        if snaplineEspEnabled then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local sp, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                local line = snaplineObjects[player]
                if not line then
                    line = Drawing.new("Line")
                    line.Thickness = 1
                    snaplineObjects[player] = line
                end
                if onScreen then
                    local vs = Camera.ViewportSize
                    local oy = tracerOriginMode == "Bottom" and vs.Y or (tracerOriginMode == "Top" and 0 or vs.Y / 2)
                    line.From = Vector2.new(vs.X / 2, oy)
                    line.To = Vector2.new(sp.X, sp.Y)
                    line.Color = snaplineColor
                    line.Visible = true
                else
                    line.Visible = false
                end
            end
        else
            if snaplineObjects[player] then snaplineObjects[player]:Remove() snaplineObjects[player] = nil end
        end
    end
end

Visuals:Section("ESP")
Visuals:Toggle("Team ESP + Distance", false, function(v)
    espEnabled = v
    if not v then for _, p in ipairs(Players:GetPlayers()) do clearESP(p) end end
end)
Visuals:ColorPicker("ESP Color", espColor, function(c) espColor = c end)
Visuals:Toggle("Snaplines ESP", false, function(v) snaplineEspEnabled = v end)
Visuals:ColorPicker("Snapline Color", snaplineColor, function(c) snaplineColor = c end)
Visuals:Section("World")
Visuals:Toggle("X-Ray Mode (Walls Transparency)", false, function(v)
    xrayEnabled = v
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("BasePart") and not o:IsDescendantOf(LP.Character) and not (o.Parent and o.Parent:FindFirstChildOfClass("Humanoid")) then
            o.LocalTransparencyModifier = v and 0.6 or 0
        end
    end
end)
Visuals:Toggle("Hazard Immunity (Disable Touch Triggers)", false, function(v)
    touchImmunityEnabled = v
    if not v and character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanTouch = true end
        end
    end
end)
Visuals:Toggle("Remove Fog", false, function(v) Lighting.FogEnd = v and 999999 or 1000 end)
Visuals:Slider("Custom Clock Time", 0, 24, 1, 14, function(v) Lighting.ClockTime = v end)

Players.PlayerRemoving:Connect(clearESP)
RunService.RenderStepped:Connect(function()
    if espEnabled or snaplineEspEnabled then updateESP() end
end)

--==================================================
-- PERFORMANCE TAB
--==================================================
local originalLighting = {
    GlobalShadows = Lighting.GlobalShadows, FogEnd = Lighting.FogEnd,
    Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
}
local fpsBoostEnabled, autoBrightEnabled, showOverlay = false, false, false

local function applyLighting()
    if fpsBoostEnabled then
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
    else
        Lighting.GlobalShadows = originalLighting.GlobalShadows
        Lighting.FogEnd = originalLighting.FogEnd
    end
    if autoBrightEnabled then
        Lighting.Brightness = 3
        Lighting.ClockTime = 14
    else
        Lighting.Brightness = originalLighting.Brightness
        Lighting.ClockTime = originalLighting.ClockTime
    end
end

Perf:Toggle("FPS Boost", false, function(v) fpsBoostEnabled = v applyLighting() end)
Perf:Toggle("Auto Bright", false, function(v) autoBrightEnabled = v applyLighting() end)

local StatsLabel = create("TextLabel", {
    Size = UDim2.fromOffset(180, 25), Position = UDim2.fromScale(0.01, 0.01),
    BackgroundColor3 = T.top, BackgroundTransparency = 0.2, TextColor3 = T.text,
    TextScaled = true, Font = Enum.Font.Code, Text = "FPS: -- | Ping: --ms",
    Visible = false, Parent = Gui,
})
corner(StatsLabel, 6)
Perf:Toggle("Show FPS & Ping Overlay", false, function(v)
    showOverlay = v
    StatsLabel.Visible = v
end)

local frameCount, lastCheck = 0, tick()
RunService.RenderStepped:Connect(function()
    frameCount += 1
    local now = tick()
    if now - lastCheck >= 1 then
        local fps = math.floor(frameCount / (now - lastCheck))
        frameCount, lastCheck = 0, now
        if showOverlay then
            local ok, ping = pcall(function()
                return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
            end)
            StatsLabel.Text = string.format("FPS: %d | Ping: %sms", fps, ok and ping or "--")
        end
    end
end)

--==================================================
-- CROSSHAIR TAB
--==================================================
local CrossGui = create("ScreenGui", {
    Name = "IzttNickCrosshair", ResetOnSpawn = false, IgnoreGuiInset = true, Parent = Gui.Parent,
})
local CrossLabel = create("TextLabel", {
    Size = UDim2.fromOffset(30, 30), Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Text = "+",
    TextColor3 = Color3.fromRGB(0, 255, 0), TextScaled = true, Font = Enum.Font.Code, Parent = CrossGui,
})

Cross:Toggle("Show Crosshair", true, function(v) CrossLabel.Visible = v end)
Cross:Dropdown("Crosshair Style", {"+", ".", "x", "o"}, "+", function(v) CrossLabel.Text = v end)
Cross:Slider("Crosshair Size", 10, 60, 2, 30, function(v) CrossLabel.Size = UDim2.fromOffset(v, v) end)
Cross:Dropdown("Crosshair Color", {"Green", "Red", "White", "Cyan", "Yellow"}, "Green", function(v)
    local colors = {
        Green = Color3.fromRGB(0, 255, 0), Red = Color3.fromRGB(255, 0, 0),
        White = Color3.fromRGB(255, 255, 255), Cyan = Color3.fromRGB(0, 255, 255),
        Yellow = Color3.fromRGB(255, 255, 0),
    }
    rainbowCrosshair = false
    CrossLabel.TextColor3 = colors[v] or colors.Green
end)
Cross:Toggle("Rainbow Crosshair", false, function(v) rainbowCrosshair = v end)

RunService.RenderStepped:Connect(function()
    if rainbowCrosshair then
        CrossLabel.TextColor3 = Color3.fromHSV((tick() * 2) % 1, 1, 1)
    end
end)

--==================================================
-- TELEPORT TAB
--==================================================
TeleportTab:Section("Player Teleport")
local PlayerDropdown = TeleportTab:Dropdown("Select Player", getPlayerList(), nil, function(v)
    selectedPlayerName = v
end)
TeleportTab:Button("Refresh Player List", function()
    PlayerDropdown:Refresh(getPlayerList(), true)
end)
TeleportTab:Button("Teleport to Player", function()
    if not selectedPlayerName then
        Notify("Teleport Error", "Select a player first.", 3)
        return
    end
    local target = Players:FindFirstChild(selectedPlayerName)
    local tr = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if tr and root then
        root.CFrame = tr.CFrame * CFrame.new(0, 0, 3)
        Notify("Teleport Success", "Teleported to " .. selectedPlayerName, 3)
    else
        Notify("Teleport Error", "Target missing or has no character.", 3)
    end
end)
TeleportTab:Toggle("Loop Attach to Selected Player", false, function(v)
    if followConnection then followConnection:Disconnect() followConnection = nil end
    if v then
        followConnection = RunService.RenderStepped:Connect(function()
            if selectedPlayerName and root then
                local target = Players:FindFirstChild(selectedPlayerName)
                local tr = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                if tr then root.CFrame = tr.CFrame * CFrame.new(0, 0, 4) end
            end
        end)
    end
end)
TeleportTab:Toggle("Spectate Selected Player", false, function(v)
    if v and selectedPlayerName then
        local target = Players:FindFirstChild(selectedPlayerName)
        local hum = target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")
        if hum then Camera.CameraSubject = hum end
    elseif humanoid then
        Camera.CameraSubject = humanoid
    end
end)

TeleportTab:Section("Server Utilities")
TeleportTab:Toggle("Auto Rejoin on Kick / Disconnect", false, function(v) autoRejoinEnabled = v end)
TeleportTab:Button("Rejoin Server", function()
    Notify("Server", "Rejoining current server...", 3)
    TeleportService:Teleport(game.PlaceId, LP)
end)
TeleportTab:Button("Server Hop", function()
    Notify("Server", "Searching for a new server...", 3)
    local ok, servers = pcall(function()
        return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/0?sortOrder=Asc&limit=100"))
    end)
    if ok and servers and servers.data then
        for _, s in ipairs(servers.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LP)
                return
            end
        end
    end
    Notify("Server Hop Failed", "Could not find an available server.", 3)
end)

Players.PlayerAdded:Connect(function()
    PlayerDropdown:Refresh(getPlayerList(), true)
end)
Players.PlayerRemoving:Connect(function(player)
    if player.Name == selectedPlayerName then selectedPlayerName = nil end
    task.defer(function() PlayerDropdown:Refresh(getPlayerList(), true) end)
end)

--==================================================
-- WAYPOINTS TAB
--==================================================
local WaypointDropdown
WaypointTab:Section("Custom Waypoints")
WaypointTab:Input("Waypoint Name", "e.g. Base, Shop", function(t) waypointNameToSave = t end)
WaypointTab:Button("Save Current Position", function()
    if waypointNameToSave == "" then
        Notify("Waypoint Error", "Type a name first.", 3)
        return
    end
    if root then
        savedWaypoints[waypointNameToSave] = root.CFrame
        WaypointDropdown:Refresh(getWaypointList(), true)
        Notify("Waypoint Saved", "Saved '" .. waypointNameToSave .. "'", 3)
    end
end)
WaypointDropdown = WaypointTab:Dropdown("Saved Waypoint", getWaypointList(), nil, function(v)
    selectedWaypointName = v
end)
WaypointTab:Button("Teleport to Waypoint", function()
    if not selectedWaypointName or not savedWaypoints[selectedWaypointName] then
        Notify("Teleport Error", "Select a valid waypoint first.", 3)
        return
    end
    if root then
        root.CFrame = savedWaypoints[selectedWaypointName]
        Notify("Teleport Success", "Teleported to " .. selectedWaypointName, 3)
    end
end)
WaypointTab:Button("Delete Waypoint", function()
    if selectedWaypointName and savedWaypoints[selectedWaypointName] then
        savedWaypoints[selectedWaypointName] = nil
        selectedWaypointName = nil
        WaypointDropdown:Refresh(getWaypointList(), false)
        Notify("Waypoint Deleted", "Waypoint removed.", 3)
    end
end)

--==================================================
-- KEYBINDS + UI SETTINGS
--==================================================
KeybindTab:Section("Hotkeys")
KeybindTab:Dropdown("Fly Key", {"T", "F", "E", "X", "V"}, "T", function(v) keybinds.Fly = Enum.KeyCode[v]; refreshKeyList() end)
KeybindTab:Dropdown("Noclip Key", {"N", "G", "H", "J"}, "N", function(v) keybinds.Noclip = Enum.KeyCode[v]; refreshKeyList() end)

SettingsTab:Section("Menu")
SettingsTab:Dropdown("Open / Close Key", {"K", "RightShift", "Insert", "M", "P"}, "K", function(v)
    menuKey = Enum.KeyCode[v]
    Hint.Text = "[" .. v .. "] toggle"
    refreshKeyList()
    Notify("Menu Key", "Menu key set to " .. v, 3)
end)
SettingsTab:Slider("Menu Scale", 0.7, 1.3, 0.05, 1, function(v)
    fullSize = UDim2.fromOffset(600 * v, 390 * v)
    if not minimized then MainFrame.Size = fullSize end
end)
SettingsTab:Button("Destroy UI", function()
    stopFly()
    FOVCircle:Remove()
    freecamStop()
    clearAllBoxes()
    for _, p in ipairs(Players:GetPlayers()) do clearESP(p) end
    CrossGui:Destroy()
    Gui:Destroy()
end)

--==================================================
-- EXTRA FEATURES
--==================================================
do

Visuals:Section("Extra visuals")

local fbEnabled, fbOrig = false, nil
Visuals:Toggle("Fullbright", false, function(v)
    fbEnabled = v
    if v then
        fbOrig = {Lighting.Ambient, Lighting.OutdoorAmbient, Lighting.Brightness, Lighting.GlobalShadows, Lighting.ClockTime}
    elseif fbOrig then
        Lighting.Ambient = fbOrig[1]
        Lighting.OutdoorAmbient = fbOrig[2]
        Lighting.Brightness = fbOrig[3]
        Lighting.GlobalShadows = fbOrig[4]
        Lighting.ClockTime = fbOrig[5]
    end
end)
RunService.Heartbeat:Connect(function()
    if fbEnabled then
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        Lighting.Brightness = 2
        Lighting.GlobalShadows = false
        Lighting.ClockTime = 14
    end
end)

Visuals:Toggle("Box ESP", false, function(v) boxEspEnabled = v end)
Visuals:Toggle("Health Bars", false, function(v) healthBarEnabled = v end)
Visuals:Dropdown("Tracer Origin", {"Bottom", "Center", "Top"}, "Center", function(v) tracerOriginMode = v end)

local function clearBox(player)
    local o = boxObjects[player]
    if o then
        for _, d in pairs(o) do d:Remove() end
        boxObjects[player] = nil
    end
end
clearAllBoxes = function()
    for p in pairs(boxObjects) do clearBox(p) end
end
Players.PlayerRemoving:Connect(clearBox)

RunService.RenderStepped:Connect(function()
    local active = boxEspEnabled or healthBarEnabled
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LP then continue end
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not active or not hrp or not head or not hum or hum.Health <= 0 then
            clearBox(player)
            continue
        end
        local top, onTop = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y / 2 + 0.3, 0))
        local bot, onBot = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
        local o = boxObjects[player]
        if not o then
            o = {box = Drawing.new("Square"), barBg = Drawing.new("Line"), bar = Drawing.new("Line")}
            o.box.Thickness = 1.5
            o.box.Filled = false
            o.barBg.Thickness = 4
            o.barBg.Color = Color3.new(0, 0, 0)
            o.bar.Thickness = 2
            boxObjects[player] = o
        end
        if onTop and onBot then
            local h = math.abs(bot.Y - top.Y)
            local w = h * 0.55
            local x, y = top.X - w / 2, top.Y
            o.box.Visible = boxEspEnabled
            o.box.Size = Vector2.new(w, h)
            o.box.Position = Vector2.new(x, y)
            o.box.Color = espColor
            local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
            o.barBg.Visible = healthBarEnabled
            o.barBg.From = Vector2.new(x - 6, y + h + 1)
            o.barBg.To = Vector2.new(x - 6, y - 1)
            o.bar.Visible = healthBarEnabled
            o.bar.From = Vector2.new(x - 6, y + h)
            o.bar.To = Vector2.new(x - 6, y + h - h * ratio)
            o.bar.Color = Color3.fromHSV(ratio * 0.33, 1, 1)
        else
            o.box.Visible, o.barBg.Visible, o.bar.Visible = false, false, false
        end
    end
end)

local WM = create("TextLabel", {
    Size = UDim2.fromOffset(320, 24), Position = UDim2.new(0.5, -160, 0, 6),
    BackgroundColor3 = T.top, BackgroundTransparency = 0.15, TextColor3 = T.text,
    Font = Enum.Font.GothamMedium, TextSize = 13, Text = "IzttNick Hub", Visible = false, Parent = Gui,
})
corner(WM, 6)
stroke(WM)
local wmOn = false
Visuals:Toggle("Watermark", false, function(v)
    wmOn = v
    WM.Visible = v
end)
local wmFrames, wmLast = 0, tick()
RunService.RenderStepped:Connect(function()
    wmFrames += 1
    local now = tick()
    if now - wmLast >= 1 then
        local fps = math.floor(wmFrames / (now - wmLast))
        wmFrames, wmLast = 0, now
        if wmOn then
            local ok, ping = pcall(function()
                return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
            end)
            WM.Text = string.format("IzttNick Hub | %d FPS | %sms | %s", fps, ok and ping or "--", os.date("%H:%M"))
        end
    end
end)

Main:Section("Extra movement")

Main:Toggle("Infinite Jump", false, function(v) infiniteJumpEnabled = v end)
UIS.JumpRequest:Connect(function()
    if infiniteJumpEnabled and humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

Main:Toggle("Click Teleport (Ctrl + Click)", false, function(v) clickTpEnabled = v end)

Main:Toggle("Anti-Void", false, function(v) antiVoidEnabled = v end)
local lastSafe
RunService.Heartbeat:Connect(function()
    if not antiVoidEnabled or not root or not root.Parent or not humanoid then return end
    local fp = workspace.FallenPartsDestroyHeight
    local limit = (fp > -100000) and (fp + 120) or -300
    if root.Position.Y > limit + 50 and humanoid.FloorMaterial ~= Enum.Material.Air then
        lastSafe = root.CFrame
    elseif root.Position.Y < limit and lastSafe then
        root.AssemblyLinearVelocity = Vector3.zero
        root.CFrame = lastSafe + Vector3.new(0, 5, 0)
        Notify("Anti-Void", "Moved back to safe ground.", 2)
    end
end)

local fcPos, fcYaw, fcPitch, fcSpeed = Vector3.zero, 0, 0, 3
Main:Slider("Freecam Speed", 1, 10, 1, 3, function(v) fcSpeed = v end)
local function setFreecam(v)
    freecamEnabled = v
    if v then
        local look = Camera.CFrame.LookVector
        fcPitch = math.asin(math.clamp(look.Y, -1, 1))
        fcYaw = math.atan2(-look.X, -look.Z)
        fcPos = Camera.CFrame.Position
        Camera.CameraType = Enum.CameraType.Scriptable
        if root then root.Anchored = true end
    else
        UIS.MouseBehavior = Enum.MouseBehavior.Default
        Camera.CameraType = Enum.CameraType.Custom
        if humanoid then Camera.CameraSubject = humanoid end
        if root then root.Anchored = false end
    end
end
freecamStop = function()
    if freecamEnabled then setFreecam(false) end
end
Main:Toggle("Freecam (hold RMB to look)", false, setFreecam)
RunService.RenderStepped:Connect(function(dt)
    if not freecamEnabled then return end
    if aimbotHold then
        UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
        local d = UIS:GetMouseDelta()
        fcYaw -= d.X * 0.003
        fcPitch = math.clamp(fcPitch - d.Y * 0.003, -1.5, 1.5)
    else
        UIS.MouseBehavior = Enum.MouseBehavior.Default
    end
    local rot = CFrame.Angles(0, fcYaw, 0) * CFrame.Angles(fcPitch, 0, 0)
    local move, vert = Vector3.zero, 0
    if UIS:IsKeyDown(Enum.KeyCode.W) then move += Vector3.new(0, 0, -1) end
    if UIS:IsKeyDown(Enum.KeyCode.S) then move += Vector3.new(0, 0, 1) end
    if UIS:IsKeyDown(Enum.KeyCode.A) then move += Vector3.new(-1, 0, 0) end
    if UIS:IsKeyDown(Enum.KeyCode.D) then move += Vector3.new(1, 0, 0) end
    if UIS:IsKeyDown(Enum.KeyCode.E) then vert += 1 end
    if UIS:IsKeyDown(Enum.KeyCode.Q) then vert -= 1 end
    local mult = UIS:IsKeyDown(Enum.KeyCode.LeftShift) and 3 or 1
    local delta = (rot:VectorToWorldSpace(move) + Vector3.new(0, vert, 0)) * fcSpeed * 20 * mult * dt
    fcPos += delta
    Camera.CFrame = CFrame.new(fcPos) * rot
end)

Main:Button("Reset Character", function()
    if humanoid then humanoid.Health = 0 end
end)

Main:Button("Copy Position", function()
    if root then
        local pos = root.Position
        local text = string.format("%.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z)
        local ok = pcall(function() setclipboard(text) end)
        Notify(ok and "Position Copied" or "Copy Failed", ok and text or "Clipboard not supported.", 3)
    end
end)

PlayersTab:Section("Server players")
local playerRows, playerInfo = {}, {}
local function refreshPlayerList()
    for _, r in ipairs(playerRows) do r:Destroy() end
    table.clear(playerRows)
    table.clear(playerInfo)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local row = newRow(PlayersTab, 36)
            local n = label(row, p.Name, 13)
            n.Position = UDim2.fromOffset(10, 0)
            n.Size = UDim2.new(0.42, -10, 1, 0)
            n.TextTruncate = Enum.TextTruncate.AtEnd
            local info = label(row, "", 12, T.sub)
            info.Position = UDim2.new(0.42, 0, 0, 0)
            info.Size = UDim2.new(0.38, 0, 1, 0)
            info.TextTruncate = Enum.TextTruncate.AtEnd
            local btn = create("TextButton", {
                Size = UDim2.fromOffset(44, 22), Position = UDim2.new(1, -52, 0.5, -11),
                BackgroundColor3 = T.off, Text = "TP", TextColor3 = T.text,
                Font = Enum.Font.GothamMedium, TextSize = 12, AutoButtonColor = false, Parent = row,
            })
            corner(btn, 5)
            btn.MouseButton1Click:Connect(function()
                local c = p.Character
                local hrp = c and c:FindFirstChild("HumanoidRootPart")
                if hrp and root then
                    root.CFrame = hrp.CFrame * CFrame.new(0, 0, 3)
                else
                    Notify("Teleport Error", p.Name .. " has no character.", 3)
                end
            end)
            table.insert(playerRows, row)
            playerInfo[p] = info
        end
    end
end
PlayersTab:Button("Refresh Players", refreshPlayerList)
refreshPlayerList()
Players.PlayerAdded:Connect(function() task.delay(0.2, refreshPlayerList) end)
Players.PlayerRemoving:Connect(function() task.delay(0.2, refreshPlayerList) end)
task.spawn(function()
    while Gui.Parent do
        task.wait(1)
        if menuOpen and PlayersTab.Page.Visible then
            for p, info in pairs(playerInfo) do
                local c = p.Character
                local hrp = c and c:FindFirstChild("HumanoidRootPart")
                local d = (hrp and root) and math.floor((hrp.Position - root.Position).Magnitude) or nil
                info.Text = (p.Team and p.Team.Name or "No team") .. " | " .. (d and (d .. " studs") or "--")
            end
        end
    end
end)

ChatTab:Section("Chat spy")
local chatLog = {}
ChatTab:Toggle("Enable Chat Spy", false, function(v) chatSpyEnabled = v end)
ChatTab:Button("Clear Log", function()
    for _, r in ipairs(chatLog) do r:Destroy() end
    table.clear(chatLog)
end)
local function addChat(p, msg)
    if not chatSpyEnabled then return end
    local row = create("Frame", {
        Size = UDim2.new(1, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = T.element, BorderSizePixel = 0, Parent = ChatTab.Page,
    })
    corner(row, 6)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5),
        PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = row,
    })
    local l = label(row, "[" .. p.Name .. "] " .. msg, 13)
    l.Size = UDim2.new(1, 0, 0, 0)
    l.AutomaticSize = Enum.AutomaticSize.Y
    l.TextWrapped = true
    table.insert(chatLog, row)
    if #chatLog > 50 then
        chatLog[1]:Destroy()
        table.remove(chatLog, 1)
    end
end
local function hookChat(p)
    p.Chatted:Connect(function(m) addChat(p, m) end)
end
for _, p in ipairs(Players:GetPlayers()) do hookChat(p) end
Players.PlayerAdded:Connect(hookChat)

KeybindTab:Section("Current hotkeys")
local kl = {
    menu = KeybindTab:Label(""),
    fly = KeybindTab:Label(""),
    noclip = KeybindTab:Label(""),
    aim = KeybindTab:Label("Auto aim (hold): Right Mouse"),
    ctp = KeybindTab:Label("Click teleport: Ctrl + Left Click"),
    fc = KeybindTab:Label("Freecam: hold Right Mouse to look, WASD / Q / E to move"),
    boost = KeybindTab:Label("Fly boost: hold Left Shift"),
}
refreshKeyList = function()
    kl.menu:Set("Open / close menu: " .. menuKey.Name)
    kl.fly:Set("Fly: " .. keybinds.Fly.Name)
    kl.noclip:Set("Noclip: " .. keybinds.Noclip.Name)
end
refreshKeyList()

local accentColor = Color3.fromHSV(0.989, 0.9, 1)

local function ckey(c)
    return string.format("%.4f,%.4f,%.4f", c.R, c.G, c.B)
end

local function makePalette(h, sat)
    return {
        bg = Color3.fromHSV(h, 0.9 * sat, 0.47), top = Color3.fromHSV(h, 0.93 * sat, 0.33),
        side = Color3.fromHSV(h, 0.9 * sat, 0.39), element = Color3.fromHSV(h, 0.84 * sat, 0.63),
        elementH = Color3.fromHSV(h, 0.78 * sat, 0.73), off = Color3.fromHSV(h, 0.9 * sat, 0.27),
        accent = Color3.fromHSV(h, 0.12 * sat, 1), sub = Color3.fromHSV(h, 0.22 * sat, 1),
        stroke = Color3.fromHSV(h, 0.65 * sat, 1),
    }
end

local function applyAccent(color)
    accentColor = color
    local h, s = color:ToHSV()
    local new = makePalette(h, s < 0.15 and 0 or 1)
    local map = {}
    for k, old in pairs(T) do
        if new[k] then map[ckey(old)] = new[k] end
    end
    for _, d in ipairs(Gui:GetDescendants()) do
        if d:IsA("GuiObject") then
            local nb = map[ckey(d.BackgroundColor3)]
            if nb then d.BackgroundColor3 = nb end
            if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
                local nt = map[ckey(d.TextColor3)]
                if nt then d.TextColor3 = nt end
                if d:IsA("TextBox") then
                    local np = map[ckey(d.PlaceholderColor3)]
                    if np then d.PlaceholderColor3 = np end
                end
            end
            if d:IsA("ImageLabel") then
                local ni = map[ckey(d.ImageColor3)]
                if ni then d.ImageColor3 = ni end
            end
            if d:IsA("ScrollingFrame") then
                local ns = map[ckey(d.ScrollBarImageColor3)]
                if ns then d.ScrollBarImageColor3 = ns end
            end
        elseif d:IsA("UIStroke") then
            local nc = map[ckey(d.Color)]
            if nc then d.Color = nc end
        end
    end
    for k, v in pairs(new) do T[k] = v end
end

local CONFIG_FILE = "IzttNickHub_config.json"
local skip = {
    ["Main/Fly"] = true,
    ["Main/Freecam (hold RMB to look)"] = true,
    ["Teleport/Select Player"] = true,
    ["Teleport/Loop Attach to Selected Player"] = true,
    ["Teleport/Spectate Selected Player"] = true,
    ["Waypoints/Saved Waypoint"] = true,
    ["Waypoints/Waypoint Name"] = true,
}
local function c2t(c) return {c.R, c.G, c.B} end
local function t2c(t) return Color3.new(t[1], t[2], t[3]) end

local function saveConfig()
    local data = {values = {}, esp = c2t(espColor), snap = c2t(snaplineColor), accent = c2t(accentColor)}
    for key, obj in pairs(UI.registry) do
        local t = type(obj.Value)
        if not skip[key] and (t == "boolean" or t == "number" or t == "string") then
            data.values[key] = obj.Value
        end
    end
    local ok = pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(data)) end)
    Notify(ok and "Config Saved" or "Save Failed", ok and CONFIG_FILE or "writefile is not supported.", 3)
end

local function loadConfig()
    local ok, raw = pcall(function() return readfile(CONFIG_FILE) end)
    if not ok then
        Notify("Load Failed", "No saved config found.", 3)
        return
    end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or type(data) ~= "table" then
        Notify("Load Failed", "Config file is corrupted.", 3)
        return
    end
    for key, v in pairs(data.values or {}) do
        local obj = UI.registry[key]
        if obj and obj.Set and not skip[key] then pcall(obj.Set, obj, v) end
    end
    if data.esp then espColor = t2c(data.esp) end
    if data.snap then snaplineColor = t2c(data.snap) end
    if data.accent then applyAccent(t2c(data.accent)) end
    Notify("Config Loaded", "Your settings were restored.", 3)
end

SettingsTab:Section("Config")
SettingsTab:Button("Save Config", saveConfig)
SettingsTab:Button("Load Config", loadConfig)
SettingsTab:Section("Theme")
SettingsTab:ColorPicker("Menu Accent Color", accentColor, applyAccent)
SettingsTab:Button("Reset Theme", function()
    applyAccent(Color3.fromHSV(0.989, 0.9, 1))
end)

end

--==================================================
-- INPUT HANDLER
--==================================================
UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == menuKey then
        setMenu(not menuOpen)
    elseif input.KeyCode == keybinds.Fly then
        flyToggle:Set(not flying)
    elseif input.KeyCode == keybinds.Noclip then
        noclipToggle:Set(not noclipEnabled)
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 and clickTpEnabled and UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
        if root and Mouse.Hit then
            root.CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0, 3, 0))
        end
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
        aimbotHold = true
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aimbotHold = false
    end
end)

Notify("IzttNick Hub", "Loaded! Press K to open / close.", 4)
