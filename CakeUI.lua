--[[
    CakeUI v0.1.0
    Original Roblox/Luau UI module.

    Design references:
      LinoriaLib: https://github.com/violin-suzutsuki/LinoriaLib
      Fluent:    https://github.com/dawid-scripts/Fluent

    This implementation does not contain copied LinoriaLib or Fluent source.
    If third-party code is added later, include that project's original
    copyright notice and license text in the distributed package.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
assert(LocalPlayer, "CakeUI must be required from a client LocalScript")

local CakeUI = {
    Version = "0.1.0",
}

local DEFAULT_THEME = {
    Background = Color3.fromRGB(17, 18, 23),
    Surface = Color3.fromRGB(23, 24, 31),
    SurfaceRaised = Color3.fromRGB(30, 31, 40),
    Border = Color3.fromRGB(48, 49, 61),
    Text = Color3.fromRGB(238, 239, 245),
    Muted = Color3.fromRGB(151, 154, 169),
    Accent = Color3.fromRGB(123, 92, 255),
    AccentHover = Color3.fromRGB(101, 75, 216),
    Danger = Color3.fromRGB(219, 75, 88),
}

local function create(className, parent, properties)
    local object = Instance.new(className)
    for property, value in pairs(properties or {}) do
        object[property] = value
    end
    object.Parent = parent
    return object
end

local function addCorner(object, radius)
    create("UICorner", object, {
        CornerRadius = UDim.new(0, radius or 7),
    })
end

local function addStroke(object, color, thickness)
    create("UIStroke", object, {
        Color = color or DEFAULT_THEME.Border,
        Thickness = thickness or 1,
        Transparency = 0.08,
    })
end

local function playTween(object, duration, properties)
    if not object or not object.Parent then
        return
    end

    local tween = TweenService:Create(
        object,
        TweenInfo.new(duration or 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        properties
    )
    tween:Play()
    return tween
end

local function roundedFrame(parent, name, size, position, color, radius)
    local frame = create("Frame", parent, {
        Name = name,
        Size = size,
        Position = position or UDim2.new(),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
    })
    addCorner(frame, radius or 7)
    return frame
end

local function makeLabel(parent, text, size, position, options)
    options = options or {}
    return create("TextLabel", parent, {
        Name = options.Name or "Label",
        Size = size,
        Position = position or UDim2.new(),
        BackgroundTransparency = 1,
        Text = text or "",
        Font = options.Font or Enum.Font.Gotham,
        TextSize = options.TextSize or 12,
        TextColor3 = options.TextColor3 or DEFAULT_THEME.Text,
        TextXAlignment = options.TextXAlignment or Enum.TextXAlignment.Left,
        TextYAlignment = options.TextYAlignment or Enum.TextYAlignment.Center,
        TextWrapped = options.TextWrapped == true,
        RichText = false,
    })
end

local function makeButton(parent, text, size, position, theme)
    local button = create("TextButton", parent, {
        Size = size,
        Position = position or UDim2.new(),
        BackgroundColor3 = theme.SurfaceRaised,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = text or "",
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = theme.Text,
    })
    addCorner(button, 6)
    addStroke(button, theme.Border, 1)

    button.MouseEnter:Connect(function()
        if button.Parent then
            playTween(button, 0.12, { BackgroundColor3 = theme.AccentHover })
        end
    end)
    button.MouseLeave:Connect(function()
        if button.Parent then
            playTween(button, 0.12, { BackgroundColor3 = theme.SurfaceRaised })
        end
    end)
    return button
end

local function formatNumber(value, decimals)
    decimals = math.clamp(tonumber(decimals) or 0, 0, 4)
    if decimals == 0 then
        return tostring(math.floor(value + 0.5))
    end
    return string.format("%." .. tostring(decimals) .. "f", value)
end

local function parseHex(text)
    local hex = string.gsub(text or "", "#", "")
    hex = string.gsub(hex, "%s", "")
    if #hex ~= 6 or not string.match(hex, "^%x%x%x%x%x%x$") then
        return nil
    end

    local red = tonumber(string.sub(hex, 1, 2), 16)
    local green = tonumber(string.sub(hex, 3, 4), 16)
    local blue = tonumber(string.sub(hex, 5, 6), 16)
    return Color3.fromRGB(red, green, blue)
end

local function colorToHex(color)
    return string.format(
        "%02X%02X%02X",
        math.floor(color.R * 255 + 0.5),
        math.floor(color.G * 255 + 0.5),
        math.floor(color.B * 255 + 0.5)
    )
end

local function normalizeDefault(values, default)
    if type(default) == "number" and values[default] ~= nil then
        return values[default]
    end
    for _, value in ipairs(values) do
        if value == default then
            return value
        end
    end
    return values[1]
end

local function registerConnection(context, signal, callback)
    local connection = signal:Connect(callback)
    table.insert(context._connections, connection)
    return connection
end

local function createContext(options)
    options = options or {}
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local theme = table.clone(DEFAULT_THEME)

    if typeof(options.Accent) == "Color3" then
        theme.Accent = options.Accent
    end
    theme.AccentHover = theme.Accent:Lerp(Color3.new(0, 0, 0), 0.18)

    local context = {
        Theme = theme,
        _connections = {},
        _accentRefs = {},
        _accentCallbacks = {},
        _destroyed = false,
        _windows = {},
    }

    function context:Connect(signal, callback)
        if self._destroyed then
            return nil
        end
        return registerConnection(self, signal, callback)
    end

    function context:RegisterAccent(object, property)
        table.insert(self._accentRefs, { Object = object, Property = property })
        object[property] = self.Theme.Accent
    end

    function context:OnAccentChanged(callback)
        table.insert(self._accentCallbacks, callback)
    end

    function context:SetAccent(color)
        if typeof(color) ~= "Color3" then
            return
        end

        self.Theme.Accent = color
        self.Theme.AccentHover = color:Lerp(Color3.new(0, 0, 0), 0.18)

        for index = #self._accentRefs, 1, -1 do
            local item = self._accentRefs[index]
            if item.Object and item.Object.Parent then
                item.Object[item.Property] = color
            else
                table.remove(self._accentRefs, index)
            end
        end

        for _, callback in ipairs(self._accentCallbacks) do
            local success, errorMessage = pcall(callback, color)
            if not success then
                warn("[CakeUI] Accent update failed:", errorMessage)
            end
        end
    end

    local gui = create("ScreenGui", playerGui, {
        Name = options.GuiName or "CakeUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = options.DisplayOrder or 40,
    })
    context.Gui = gui

    local toastHolder = create("Frame", gui, {
        Name = "Notifications",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -18, 1, -18),
        Size = UDim2.fromOffset(300, 190),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    create("UIListLayout", toastHolder, {
        Padding = UDim.new(0, 7),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
    })
    context._toastHolder = toastHolder

    function context:Notify(data)
        data = data or {}
        if self._destroyed then
            return
        end

        local title = tostring(data.Title or "CakeUI")
        local message = tostring(data.Content or data.Message or "")
        local duration = math.max(1, tonumber(data.Duration) or 3)

        local toast = roundedFrame(
            self._toastHolder,
            "Notification",
            UDim2.new(1, 0, 0, 66),
            UDim2.new(),
            self.Theme.Surface,
            8
        )
        toast.BackgroundTransparency = 0.08
        addStroke(toast, self.Theme.Accent, 1)

        makeLabel(toast, title, UDim2.new(1, -24, 0, 20), UDim2.fromOffset(12, 8), {
            Font = Enum.Font.GothamBold,
            TextSize = 13,
        })
        makeLabel(toast, message, UDim2.new(1, -24, 0, 28), UDim2.fromOffset(12, 30), {
            TextColor3 = self.Theme.Muted,
            TextSize = 11,
            TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top,
        })

        toast.BackgroundTransparency = 1
        playTween(toast, 0.15, { BackgroundTransparency = 0.08 })

        task.delay(duration, function()
            if toast and toast.Parent then
                playTween(toast, 0.15, { BackgroundTransparency = 1 })
                task.wait(0.17)
                if toast and toast.Parent then
                    toast:Destroy()
                end
            end
        end)
        return toast
    end

    function context:Destroy()
        if self._destroyed then
            return
        end
        self._destroyed = true
        for _, connection in ipairs(self._connections) do
            if connection.Connected then
                connection:Disconnect()
            end
        end
        table.clear(self._connections)
        if self.Gui and self.Gui.Parent then
            self.Gui:Destroy()
        end
    end

    return context
end

function CakeUI:CreateWindow(options)
    options = options or {}
    local ui = createContext(options)

    local windowWidth = math.max(560, tonumber(options.Width) or 720)
    local windowHeight = math.max(380, tonumber(options.Height) or 470)

    local windowFrame = roundedFrame(
        ui.Gui,
        "Window",
        UDim2.fromOffset(windowWidth, windowHeight),
        UDim2.new(0.5, -windowWidth / 2, 0.5, -windowHeight / 2),
        ui.Theme.Background,
        10
    )
    windowFrame.ClipsDescendants = false
    addStroke(windowFrame, ui.Theme.Border, 1)

    local topbar = create("Frame", windowFrame, {
        Name = "Topbar",
        Size = UDim2.new(1, 0, 0, 53),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    makeLabel(topbar, tostring(options.Title or "CakeUI"), UDim2.new(1, -130, 0, 23), UDim2.fromOffset(17, 7), {
        Font = Enum.Font.GothamBold,
        TextSize = 16,
    })
    makeLabel(topbar, tostring(options.Subtitle or "Custom interface"), UDim2.new(1, -130, 0, 16), UDim2.fromOffset(17, 29), {
        TextColor3 = ui.Theme.Muted,
        TextSize = 10,
    })

    local minimizeButton = makeButton(topbar, "—", UDim2.fromOffset(30, 28), UDim2.new(1, -76, 0, 12), ui.Theme)
    local closeButton = makeButton(topbar, "×", UDim2.fromOffset(30, 28), UDim2.new(1, -39, 0, 12), ui.Theme)

    local separator = create("Frame", windowFrame, {
        Size = UDim2.new(1, -20, 0, 1),
        Position = UDim2.fromOffset(10, 52),
        BackgroundColor3 = ui.Theme.Border,
        BorderSizePixel = 0,
    })

    local sidebar = roundedFrame(
        windowFrame,
        "Sidebar",
        UDim2.new(0, 151, 1, -72),
        UDim2.fromOffset(10, 61),
        ui.Theme.Surface,
        8
    )
    addStroke(sidebar, ui.Theme.Border, 1)

    local navHolder = create("ScrollingFrame", sidebar, {
        Name = "Navigation",
        Position = UDim2.fromOffset(7, 8),
        Size = UDim2.new(1, -14, 1, -16),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = ui.Theme.Accent,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    })
    create("UIListLayout", navHolder, {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    local content = create("Frame", windowFrame, {
        Name = "Content",
        Position = UDim2.fromOffset(171, 61),
        Size = UDim2.new(1, -181, 1, -72),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    local window = {
        UI = ui,
        Frame = windowFrame,
        Sidebar = sidebar,
        Content = content,
        _pages = {},
        _tabs = {},
        _selectedTab = nil,
        _minimized = false,
        _oldHeight = windowHeight,
    }
    table.insert(ui._windows, window)

    function window:Notify(data)
        return ui:Notify(data)
    end

    function window:SetAccent(color)
        ui:SetAccent(color)
    end

    function window:Destroy()
        ui:Destroy()
    end

    local function refreshTabs()
        for _, tab in ipairs(window._tabs) do
            local selected = tab == window._selectedTab
            tab.Button.BackgroundColor3 = selected and ui.Theme.Accent or ui.Theme.Surface
            tab.Button.TextColor3 = selected and Color3.new(1, 1, 1) or ui.Theme.Muted
            tab.Button.BackgroundTransparency = selected and 0 or 1
        end
    end

    local function selectTab(tab)
        window._selectedTab = tab
        for _, item in ipairs(window._tabs) do
            item.Page.Visible = item == tab
        end
        refreshTabs()
    end

    ui:OnAccentChanged(function()
        refreshTabs()
        for _, tab in ipairs(window._tabs) do
            tab.Page.ScrollBarImageColor3 = ui.Theme.Accent
        end
        navHolder.ScrollBarImageColor3 = ui.Theme.Accent
    end)

    local dragging = false
    local dragStart = nil
    local startPosition = nil

    ui:Connect(topbar.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = windowFrame.Position
        end
    end)

    ui:Connect(UserInputService.InputChanged, function(input)
        if not dragging then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        if not dragStart or not startPosition then
            return
        end
        local delta = input.Position - dragStart
        windowFrame.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end)

    ui:Connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    ui:Connect(minimizeButton.MouseButton1Click, function()
        window._minimized = not window._minimized
        sidebar.Visible = not window._minimized
        content.Visible = not window._minimized
        separator.Visible = not window._minimized
        local targetHeight = window._minimized and 53 or window._oldHeight
        playTween(windowFrame, 0.18, { Size = UDim2.fromOffset(windowWidth, targetHeight) })
        minimizeButton.Text = window._minimized and "□" or "—"
    end)

    ui:Connect(closeButton.MouseButton1Click, function()
        ui:Destroy()
    end)
    closeButton.MouseEnter:Connect(function()
        playTween(closeButton, 0.12, { BackgroundColor3 = ui.Theme.Danger })
    end)
    closeButton.MouseLeave:Connect(function()
        playTween(closeButton, 0.12, { BackgroundColor3 = ui.Theme.SurfaceRaised })
    end)

    function window:AddTab(data)
        data = data or {}
        local title = tostring(data.Title or data.Name or ("Tab " .. tostring(#self._tabs + 1)))

        local button = create("TextButton", navHolder, {
            Name = title .. "Button",
            Size = UDim2.new(1, 0, 0, 35),
            BackgroundColor3 = ui.Theme.Surface,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "  " .. tostring(data.Icon or "•") .. "   " .. title,
            Font = Enum.Font.GothamMedium,
            TextSize = 11,
            TextColor3 = ui.Theme.Muted,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        addCorner(button, 6)

        local page = create("ScrollingFrame", content, {
            Name = title .. "Page",
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = ui.Theme.Accent,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
        })
        local pageLayout = create("UIListLayout", page, {
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
        create("UIPadding", page, {
            PaddingTop = UDim.new(0, 2),
            PaddingBottom = UDim.new(0, 8),
            PaddingLeft = UDim.new(0, 2),
            PaddingRight = UDim.new(0, 5),
        })

        local tab = {
            Window = self,
            UI = ui,
            Title = title,
            Button = button,
            Page = page,
            _layout = pageLayout,
        }
        table.insert(self._tabs, tab)

        ui:Connect(button.MouseButton1Click, function()
            selectTab(tab)
        end)
        ui:Connect(button.MouseEnter, function()
            if window._selectedTab ~= tab then
                playTween(button, 0.12, { BackgroundTransparency = 0.35 })
            end
        end)
        ui:Connect(button.MouseLeave, function()
            if window._selectedTab ~= tab then
                playTween(button, 0.12, { BackgroundTransparency = 1 })
            end
        end)

        function tab:AddSection(sectionTitle)
            local section = roundedFrame(
                page,
                tostring(sectionTitle or "Section"),
                UDim2.new(1, -7, 0, 60),
                UDim2.new(),
                ui.Theme.Surface,
                8
            )
            addStroke(section, ui.Theme.Border, 1)

            makeLabel(section, tostring(sectionTitle or "Section"), UDim2.new(1, -24, 0, 20), UDim2.fromOffset(12, 8), {
                Font = Enum.Font.GothamBold,
                TextSize = 12,
            })

            local holder = create("Frame", section, {
                Name = "Controls",
                Position = UDim2.fromOffset(12, 35),
                Size = UDim2.new(1, -24, 0, 0),
                BackgroundTransparency = 1,
            })
            local holderLayout = create("UIListLayout", holder, {
                Padding = UDim.new(0, 8),
                SortOrder = Enum.SortOrder.LayoutOrder,
            })

            local function resizeSection()
                local height = holderLayout.AbsoluteContentSize.Y
                holder.Size = UDim2.new(1, -24, 0, height)
                section.Size = UDim2.new(1, -7, 0, 44 + height + 14)
            end
            ui:Connect(holderLayout:GetPropertyChangedSignal("AbsoluteContentSize"), resizeSection)

            local sectionApi = {
                UI = ui,
                Frame = section,
                Container = holder,
            }

            function sectionApi:AddLabel(text)
                local label = create("TextLabel", holder, {
                    Name = "InfoLabel",
                    Size = UDim2.new(1, 0, 0, 24),
                    BackgroundTransparency = 1,
                    Text = tostring(text or ""),
                    Font = Enum.Font.Gotham,
                    TextSize = 11,
                    TextColor3 = ui.Theme.Muted,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                })
                return label
            end

            function sectionApi:AddButton(data)
                data = data or {}
                local labelText = tostring(data.Title or data.Text or "Button")
                local buttonControl = makeButton(holder, labelText, UDim2.new(1, 0, 0, 32), UDim2.new(), ui.Theme)
                ui:Connect(buttonControl.MouseButton1Click, function()
                    local callback = data.Callback or data.Func
                    if callback then
                        local ok, err = pcall(callback)
                        if not ok then
                            warn("[CakeUI] Button callback failed:", err)
                            ui:Notify({ Title = "Callback error", Content = tostring(err), Duration = 4 })
                        end
                    end
                end)
                return buttonControl
            end

            function sectionApi:AddToggle(title, data)
                data = data or {}
                local row = create("TextButton", holder, {
                    Name = tostring(title or "Toggle"),
                    Size = UDim2.new(1, 0, 0, 30),
                    BackgroundTransparency = 1,
                    Text = "",
                    AutoButtonColor = false,
                })

                makeLabel(row, tostring(data.Text or title or "Toggle"), UDim2.new(1, -64, 1, 0), UDim2.new(), {
                    TextSize = 11,
                })

                local switch = roundedFrame(
                    row,
                    "Switch",
                    UDim2.fromOffset(38, 20),
                    UDim2.new(1, -40, 0.5, -10),
                    ui.Theme.SurfaceRaised,
                    10
                )
                addStroke(switch, ui.Theme.Border, 1)
                local knob = create("Frame", switch, {
                    Name = "Knob",
                    Size = UDim2.fromOffset(14, 14),
                    Position = UDim2.fromOffset(3, 3),
                    BackgroundColor3 = ui.Theme.Muted,
                    BorderSizePixel = 0,
                })
                addCorner(knob, 7)

                local value = data.Default == true
                local function paint()
                    switch.BackgroundColor3 = value and ui.Theme.Accent or ui.Theme.SurfaceRaised
                    knob.BackgroundColor3 = value and Color3.new(1, 1, 1) or ui.Theme.Muted
                    playTween(knob, 0.12, {
                        Position = value and UDim2.new(1, -17, 0, 3) or UDim2.fromOffset(3, 3)
                    })
                end

                local function setValue(newValue, fireCallback)
                    value = newValue == true
                    paint()
                    if fireCallback and data.Callback then
                        local ok, err = pcall(data.Callback, value)
                        if not ok then
                            warn("[CakeUI] Toggle callback failed:", err)
                        end
                    end
                end

                ui:OnAccentChanged(paint)
                ui:Connect(row.MouseButton1Click, function()
                    setValue(not value, true)
                end)
                paint()

                return {
                    Frame = row,
                    SetValue = function(_, newValue) setValue(newValue, true) end,
                    GetValue = function() return value end,
                }
            end

            function sectionApi:AddSlider(title, data)
                data = data or {}
                local minimum = tonumber(data.Min) or 0
                local maximum = tonumber(data.Max) or 100
                if maximum <= minimum then
                    maximum = minimum + 1
                end
                local decimals = data.Decimals or data.Rounding or 0
                local value = math.clamp(tonumber(data.Default) or minimum, minimum, maximum)

                local row = create("Frame", holder, {
                    Name = tostring(title or "Slider"),
                    Size = UDim2.new(1, 0, 0, 47),
                    BackgroundTransparency = 1,
                })
                makeLabel(row, tostring(data.Text or title or "Slider"), UDim2.new(1, -65, 0, 20), UDim2.new(), {
                    TextSize = 11,
                })
                local valueLabel = makeLabel(row, formatNumber(value, decimals), UDim2.fromOffset(60, 20), UDim2.new(1, -60, 0, 0), {
                    TextSize = 11,
                    TextColor3 = ui.Theme.Accent,
                    TextXAlignment = Enum.TextXAlignment.Right,
                })
                ui:RegisterAccent(valueLabel, "TextColor3")

                local bar = roundedFrame(row, "SliderBar", UDim2.new(1, 0, 0, 6), UDim2.fromOffset(0, 30), ui.Theme.SurfaceRaised, 4)
                local fill = roundedFrame(bar, "Fill", UDim2.new(0, 0, 1, 0), UDim2.new(), ui.Theme.Accent, 4)
                ui:RegisterAccent(fill, "BackgroundColor3")

                local draggingSlider = false
                local function setValue(newValue, fireCallback)
                    value = math.clamp(tonumber(newValue) or minimum, minimum, maximum)
                    local alpha = (value - minimum) / (maximum - minimum)
                    fill.Size = UDim2.new(alpha, 0, 1, 0)
                    valueLabel.Text = formatNumber(value, decimals)
                    if fireCallback and data.Callback then
                        local ok, err = pcall(data.Callback, value)
                        if not ok then
                            warn("[CakeUI] Slider callback failed:", err)
                        end
                    end
                end
                local function updateFromX(x)
                    if bar.AbsoluteSize.X <= 0 then
                        return
                    end
                    local alpha = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
                    local newValue = minimum + (maximum - minimum) * alpha
                    local factor = 10 ^ math.clamp(tonumber(decimals) or 0, 0, 4)
                    newValue = math.floor(newValue * factor + 0.5) / factor
                    setValue(newValue, true)
                end

                ui:Connect(bar.InputBegan, function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        draggingSlider = true
                        updateFromX(input.Position.X)
                    end
                end)
                ui:Connect(UserInputService.InputChanged, function(input)
                    if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        updateFromX(input.Position.X)
                    end
                end)
                ui:Connect(UserInputService.InputEnded, function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        draggingSlider = false
                    end
                end)

                setValue(value, false)
                return {
                    Frame = row,
                    SetValue = function(_, newValue) setValue(newValue, true) end,
                    GetValue = function() return value end,
                }
            end

            function sectionApi:AddDropdown(title, data)
                data = data or {}
                local values = data.Values or data.Options or {}
                local selected = normalizeDefault(values, data.Default)
                local isOpen = false

                local row = create("Frame", holder, {
                    Name = tostring(title or "Dropdown"),
                    Size = UDim2.new(1, 0, 0, 34),
                    BackgroundTransparency = 1,
                    ClipsDescendants = false,
                })
                makeLabel(row, tostring(data.Text or title or "Dropdown"), UDim2.new(0.42, -4, 0, 30), UDim2.new(), {
                    TextSize = 11,
                })

                local choice = makeButton(row, tostring(selected or "Select") .. "  ▾", UDim2.new(0.58, 0, 0, 30), UDim2.new(0.42, 0, 0, 0), ui.Theme)
                choice.TextSize = 10

                local listHeight = math.min(#values * 27, 135)
                local list = create("ScrollingFrame", row, {
                    Name = "Options",
                    Position = UDim2.new(0.42, 0, 0, 34),
                    Size = UDim2.new(0.58, 0, 0, listHeight),
                    BackgroundColor3 = ui.Theme.SurfaceRaised,
                    BorderSizePixel = 0,
                    ScrollBarThickness = 2,
                    ScrollBarImageColor3 = ui.Theme.Accent,
                    CanvasSize = UDim2.fromOffset(0, #values * 27),
                    Visible = false,
                    ZIndex = 10,
                })
                addCorner(list, 6)
                addStroke(list, ui.Theme.Border, 1)
                create("UIListLayout", list, {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 1),
                })

                local function setOpen(open)
                    isOpen = open
                    list.Visible = open
                    row.Size = UDim2.new(1, 0, 0, open and (36 + listHeight) or 34)
                    choice.Text = tostring(selected or "Select") .. (open and "  ▴" or "  ▾")
                    resizeSection()
                end

                local api = {}
                function api:GetValue()
                    return selected
                end
                function api:SetValue(newValue)
                    selected = newValue
                    choice.Text = tostring(selected or "Select") .. (isOpen and "  ▴" or "  ▾")
                    if data.Callback then
                        local ok, err = pcall(data.Callback, selected)
                        if not ok then
                            warn("[CakeUI] Dropdown callback failed:", err)
                        end
                    end
                end

                for index, option in ipairs(values) do
                    local optionButton = create("TextButton", list, {
                        Name = "Option",
                        Size = UDim2.new(1, -4, 0, 26),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        AutoButtonColor = false,
                        Text = "  " .. tostring(option),
                        Font = Enum.Font.Gotham,
                        TextSize = 10,
                        TextColor3 = ui.Theme.Text,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        LayoutOrder = index,
                        ZIndex = 11,
                    })
                    ui:Connect(optionButton.MouseEnter, function()
                        optionButton.BackgroundTransparency = 0.75
                    end)
                    ui:Connect(optionButton.MouseLeave, function()
                        optionButton.BackgroundTransparency = 1
                    end)
                    ui:Connect(optionButton.MouseButton1Click, function()
                        selected = option
                        setOpen(false)
                        choice.Text = tostring(selected) .. "  ▾"
                        if data.Callback then
                            local ok, err = pcall(data.Callback, selected)
                            if not ok then
                                warn("[CakeUI] Dropdown callback failed:", err)
                            end
                        end
                    end)
                end

                ui:Connect(choice.MouseButton1Click, function()
                    setOpen(not isOpen)
                end)
                ui:OnAccentChanged(function(color)
                    list.ScrollBarImageColor3 = color
                end)
                return api
            end

            function sectionApi:AddInput(title, data)
                data = data or {}
                local row = create("Frame", holder, {
                    Name = tostring(title or "Input"),
                    Size = UDim2.new(1, 0, 0, 36),
                    BackgroundTransparency = 1,
                })
                makeLabel(row, tostring(data.Text or title or "Input"), UDim2.new(0.42, -4, 1, 0), UDim2.new(), {
                    TextSize = 11,
                })
                local box = create("TextBox", row, {
                    Size = UDim2.new(0.58, 0, 0, 30),
                    Position = UDim2.new(0.42, 0, 0, 2),
                    BackgroundColor3 = ui.Theme.SurfaceRaised,
                    BorderSizePixel = 0,
                    ClearTextOnFocus = false,
                    Text = tostring(data.Default or ""),
                    PlaceholderText = tostring(data.Placeholder or "Type here..."),
                    Font = Enum.Font.Gotham,
                    TextSize = 10,
                    TextColor3 = ui.Theme.Text,
                    PlaceholderColor3 = ui.Theme.Muted,
                })
                addCorner(box, 6)
                addStroke(box, ui.Theme.Border, 1)

                ui:Connect(box.FocusLost, function(enterPressed)
                    if data.Callback then
                        local ok, err = pcall(data.Callback, box.Text, enterPressed)
                        if not ok then
                            warn("[CakeUI] Input callback failed:", err)
                        end
                    end
                end)
                return {
                    Frame = row,
                    SetValue = function(_, value) box.Text = tostring(value or "") end,
                    GetValue = function() return box.Text end,
                    TextBox = box,
                }
            end

            function sectionApi:AddColorPicker(title, data)
                data = data or {}
                local current = typeof(data.Default) == "Color3" and data.Default or ui.Theme.Accent
                local row = create("Frame", holder, {
                    Name = tostring(title or "Color"),
                    Size = UDim2.new(1, 0, 0, 36),
                    BackgroundTransparency = 1,
                })
                makeLabel(row, tostring(data.Text or title or "Color"), UDim2.new(0.42, -4, 1, 0), UDim2.new(), {
                    TextSize = 11,
                })
                local hexBox = create("TextBox", row, {
                    Size = UDim2.new(0, 82, 0, 28),
                    Position = UDim2.new(1, -112, 0, 2),
                    BackgroundColor3 = ui.Theme.SurfaceRaised,
                    BorderSizePixel = 0,
                    ClearTextOnFocus = false,
                    Text = colorToHex(current),
                    PlaceholderText = "RRGGBB",
                    Font = Enum.Font.Code,
                    TextSize = 11,
                    TextColor3 = ui.Theme.Text,
                })
                addCorner(hexBox, 5)
                addStroke(hexBox, ui.Theme.Border, 1)

                local swatch = roundedFrame(row, "Swatch", UDim2.fromOffset(24, 24), UDim2.new(1, -27, 0, 4), current, 5)
                addStroke(swatch, ui.Theme.Border, 1)

                local function setValue(color, fireCallback)
                    if typeof(color) ~= "Color3" then
                        return
                    end
                    current = color
                    swatch.BackgroundColor3 = color
                    hexBox.Text = colorToHex(color)
                    if fireCallback and data.Callback then
                        local ok, err = pcall(data.Callback, current)
                        if not ok then
                            warn("[CakeUI] ColorPicker callback failed:", err)
                        end
                    end
                end

                ui:Connect(hexBox.FocusLost, function()
                    local parsed = parseHex(hexBox.Text)
                    if parsed then
                        setValue(parsed, true)
                    else
                        hexBox.Text = colorToHex(current)
                        ui:Notify({
                            Title = "Invalid color",
                            Content = "Enter a 6-digit hex value, for example 7B5CFF.",
                            Duration = 3,
                        })
                    end
                end)

                return {
                    Frame = row,
                    SetValue = function(_, color) setValue(color, true) end,
                    GetValue = function() return current end,
                }
            end

            function sectionApi:AddKeybind(title, data)
                data = data or {}
                local currentKey = data.Default or Enum.KeyCode.RightShift
                local listening = false

                local row = create("Frame", holder, {
                    Name = tostring(title or "Keybind"),
                    Size = UDim2.new(1, 0, 0, 34),
                    BackgroundTransparency = 1,
                })
                makeLabel(row, tostring(data.Text or title or "Keybind"), UDim2.new(1, -95, 1, 0), UDim2.new(), {
                    TextSize = 11,
                })
                local keyButton = makeButton(row, currentKey.Name, UDim2.fromOffset(88, 28), UDim2.new(1, -88, 0, 2), ui.Theme)
                keyButton.TextSize = 10

                ui:Connect(keyButton.MouseButton1Click, function()
                    listening = true
                    keyButton.Text = "Press key..."
                end)

                ui:Connect(UserInputService.InputBegan, function(input, gameProcessed)
                    if gameProcessed then
                        return
                    end
                    if listening then
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                            currentKey = input.KeyCode
                            keyButton.Text = currentKey.Name
                            listening = false
                        end
                    elseif input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == currentKey then
                        if data.Callback then
                            local ok, err = pcall(data.Callback, currentKey)
                            if not ok then
                                warn("[CakeUI] Keybind callback failed:", err)
                            end
                        end
                    end
                end)

                return {
                    Frame = row,
                    GetValue = function() return currentKey end,
                    SetValue = function(_, keyCode)
                        if typeof(keyCode) == "EnumItem" and keyCode.EnumType == Enum.KeyCode then
                            currentKey = keyCode
                            keyButton.Text = keyCode.Name
                        end
                    end,
                }
            end

            resizeSection()
            return sectionApi
        end

        if not self._selectedTab then
            selectTab(tab)
        end
        return tab
    end

    ui.Window = window
    return window
end

return CakeUI
