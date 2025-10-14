local NovaLibrary = {}

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local TextService = game:GetService("TextService")

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

-- Variables
local ScreenGui = nil
local MainFrame = nil
local Tabs = {}
local CurrentTab = nil
local Dragging = false
local DragStart = nil
local StartPos = nil

-- VapeV4 Theme
local VapeTheme = {
    Background = Color3.fromRGB(20, 20, 25),
    BackgroundSecondary = Color3.fromRGB(30, 30, 35),
    BackgroundTertiary = Color3.fromRGB(40, 40, 45),
    Accent = Color3.fromRGB(139, 69, 255), -- Purple accent like VapeV4
    AccentDark = Color3.fromRGB(120, 60, 230),
    Text = Color3.fromRGB(255, 255, 255),
    TextDark = Color3.fromRGB(200, 200, 200),
    TextSecondary = Color3.fromRGB(150, 150, 155),
    Border = Color3.fromRGB(50, 50, 55),
    Success = Color3.fromRGB(85, 255, 127),
    Warning = Color3.fromRGB(255, 200, 55),
    Error = Color3.fromRGB(255, 85, 127),
    Shadow = Color3.fromRGB(0, 0, 0)
}

local CurrentTheme = VapeTheme

-- Utility Functions
local function CreateTween(object, properties, duration, easingStyle, easingDirection)
    local tweenInfo = TweenInfo.new(
        duration or 0.3,
        easingStyle or Enum.EasingStyle.Quart,
        easingDirection or Enum.EasingDirection.Out
    )
    return TweenService:Create(object, tweenInfo, properties)
end

local function CreateCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = parent
    return corner
end

local function CreateStroke(parent, color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or CurrentTheme.Border
    stroke.Thickness = thickness or 1
    stroke.Parent = parent
    return stroke
end

local function CreateGradient(parent, colors)
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new(colors)
    gradient.Parent = parent
    return gradient
end

-- Main Library Functions
function NovaLibrary:CreateWindow(options)
    options = options or {}
    local windowTitle = options.Title or "Vape"
    local toggleKey = options.ToggleKey or Enum.KeyCode.LeftShift
    
    -- Create ScreenGui
    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "VapeV4GUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = CoreGui
    
    -- Main VapeV4 style container
    MainFrame = Instance.new("Frame")
    MainFrame.Name = "VapeFrame"
    MainFrame.Size = UDim2.new(0, 460, 0, 600)
    MainFrame.Position = UDim2.new(0, 50, 0.5, -300)
    MainFrame.BackgroundColor3 = CurrentTheme.Background
    MainFrame.BorderSizePixel = 0
    MainFrame.Visible = false
    MainFrame.Parent = ScreenGui
    
    CreateCorner(MainFrame, 16)
    
    -- Drop shadow
    local ShadowFrame = Instance.new("Frame")
    ShadowFrame.Name = "Shadow"
    ShadowFrame.Size = UDim2.new(1, 20, 1, 20)
    ShadowFrame.Position = UDim2.new(0, -10, 0, -10)
    ShadowFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    ShadowFrame.BackgroundTransparency = 0.8
    ShadowFrame.ZIndex = -1
    ShadowFrame.Parent = MainFrame
    
    CreateCorner(ShadowFrame, 26)
    
    -- VapeV4 Header
    local HeaderFrame = Instance.new("Frame")
    HeaderFrame.Name = "Header"
    HeaderFrame.Size = UDim2.new(1, 0, 0, 60)
    HeaderFrame.Position = UDim2.new(0, 0, 0, 0)
    HeaderFrame.BackgroundColor3 = CurrentTheme.BackgroundSecondary
    HeaderFrame.BorderSizePixel = 0
    HeaderFrame.Parent = MainFrame
    
    CreateCorner(HeaderFrame, 16)
    
    -- Header bottom fix
    local HeaderFix = Instance.new("Frame")
    HeaderFix.Size = UDim2.new(1, 0, 0, 16)
    HeaderFix.Position = UDim2.new(0, 0, 1, -16)
    HeaderFix.BackgroundColor3 = CurrentTheme.BackgroundSecondary
    HeaderFix.BorderSizePixel = 0
    HeaderFix.Parent = HeaderFrame
    
    -- Vape logo
    local VapeLogo = Instance.new("TextLabel")
    VapeLogo.Name = "VapeLogo"
    VapeLogo.Size = UDim2.new(0, 200, 1, 0)
    VapeLogo.Position = UDim2.new(0, 20, 0, 0)
    VapeLogo.BackgroundTransparency = 1
    VapeLogo.Text = windowTitle .. " V4"
    VapeLogo.TextColor3 = CurrentTheme.Text
    VapeLogo.TextSize = 22
    VapeLogo.TextXAlignment = Enum.TextXAlignment.Left
    VapeLogo.Font = Enum.Font.GothamBold
    VapeLogo.Parent = HeaderFrame
    
    -- Search bar (VapeV4 style)
    local SearchFrame = Instance.new("Frame")
    SearchFrame.Size = UDim2.new(0, 160, 0, 30)
    SearchFrame.Position = UDim2.new(1, -180, 0.5, -15)
    SearchFrame.BackgroundColor3 = CurrentTheme.BackgroundTertiary
    SearchFrame.BorderSizePixel = 0
    SearchFrame.Parent = HeaderFrame
    
    CreateCorner(SearchFrame, 15)
    
    local SearchBox = Instance.new("TextBox")
    SearchBox.Size = UDim2.new(1, -30, 1, 0)
    SearchBox.Position = UDim2.new(0, 15, 0, 0)
    SearchBox.BackgroundTransparency = 1
    SearchBox.Text = ""
    SearchBox.PlaceholderText = "Search..."
    SearchBox.TextColor3 = CurrentTheme.Text
    SearchBox.PlaceholderColor3 = CurrentTheme.TextSecondary
    SearchBox.TextSize = 12
    SearchBox.Font = Enum.Font.Gotham
    SearchBox.Parent = SearchFrame
    
    -- Main content area (scrollable)
    local ContentFrame = Instance.new("ScrollingFrame")
    ContentFrame.Name = "Content"
    ContentFrame.Size = UDim2.new(1, 0, 1, -70)
    ContentFrame.Position = UDim2.new(0, 0, 0, 70)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.BorderSizePixel = 0
    ContentFrame.ScrollBarThickness = 4
    ContentFrame.ScrollBarImageColor3 = CurrentTheme.Accent
    ContentFrame.Parent = MainFrame
    
    local ContentLayout = Instance.new("UIListLayout")
    ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ContentLayout.Padding = UDim.new(0, 12)
    ContentLayout.Parent = ContentFrame
    
    local ContentPadding = Instance.new("UIPadding")
    ContentPadding.PaddingTop = UDim.new(0, 15)
    ContentPadding.PaddingBottom = UDim.new(0, 15)
    ContentPadding.PaddingLeft = UDim.new(0, 15)
    ContentPadding.PaddingRight = UDim.new(0, 15)
    ContentPadding.Parent = ContentFrame
    
    -- Update content size
    local function UpdateContentSize()
        ContentFrame.CanvasSize = UDim2.new(0, 0, 0, ContentLayout.AbsoluteContentSize.Y + 30)
    end
    
    ContentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateContentSize)
    
    -- Dragging functionality
    local function StartDrag(input)
        Dragging = true
        DragStart = input.Position
        StartPos = MainFrame.Position
    end
    
    local function UpdateDrag(input)
        if Dragging then
            local delta = input.Position - DragStart
            MainFrame.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + delta.X, StartPos.Y.Scale, StartPos.Y.Offset + delta.Y)
        end
    end
    
    local function EndDrag()
        Dragging = false
    end
    
    HeaderFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            StartDrag(input)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            UpdateDrag(input)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            EndDrag()
        end
    end)
    
    -- Toggle GUI with Left Shift
    local GuiVisible = false
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == toggleKey then
            GuiVisible = not GuiVisible
            MainFrame.Visible = GuiVisible
            
            if GuiVisible then
                -- Fade in animation
                MainFrame.BackgroundTransparency = 1
                CreateTween(MainFrame, {BackgroundTransparency = 0}, 0.3):Play()
            end
        end
    end)
    
    local WindowFunctions = {}
    
    function WindowFunctions:CreateCategory(categoryName)
        local Category = {}
        
        -- VapeV4 style category container
        local CategoryFrame = Instance.new("Frame")
        CategoryFrame.Name = categoryName
        CategoryFrame.Size = UDim2.new(1, 0, 0, 50)
        CategoryFrame.BackgroundColor3 = CurrentTheme.BackgroundSecondary
        CategoryFrame.BorderSizePixel = 0
        CategoryFrame.Parent = ContentFrame
        
        CreateCorner(CategoryFrame, 12)
        
        -- Category header
        local CategoryHeader = Instance.new("Frame")
        CategoryHeader.Size = UDim2.new(1, 0, 0, 40)
        CategoryHeader.BackgroundColor3 = CurrentTheme.BackgroundTertiary
        CategoryHeader.BorderSizePixel = 0
        CategoryHeader.Parent = CategoryFrame
        
        CreateCorner(CategoryHeader, 12)
        
        -- Header bottom fix
        local CategoryHeaderFix = Instance.new("Frame")
        CategoryHeaderFix.Size = UDim2.new(1, 0, 0, 12)
        CategoryHeaderFix.Position = UDim2.new(0, 0, 1, -12)
        CategoryHeaderFix.BackgroundColor3 = CurrentTheme.BackgroundTertiary
        CategoryHeaderFix.BorderSizePixel = 0
        CategoryHeaderFix.Parent = CategoryHeader
        
        local CategoryTitle = Instance.new("TextLabel")
        CategoryTitle.Size = UDim2.new(1, -20, 1, 0)
        CategoryTitle.Position = UDim2.new(0, 15, 0, 0)
        CategoryTitle.BackgroundTransparency = 1
        CategoryTitle.Text = categoryName
        CategoryTitle.TextColor3 = CurrentTheme.Text
        CategoryTitle.TextSize = 16
        CategoryTitle.TextXAlignment = Enum.TextXAlignment.Left
        CategoryTitle.Font = Enum.Font.GothamBold
        CategoryTitle.Parent = CategoryHeader
        
        -- Modules container
        local ModulesContainer = Instance.new("Frame")
        ModulesContainer.Size = UDim2.new(1, -20, 1, -50)
        ModulesContainer.Position = UDim2.new(0, 10, 0, 50)
        ModulesContainer.BackgroundTransparency = 1
        ModulesContainer.Parent = CategoryFrame
        
        -- Grid layout for modules (2 columns like VapeV4)
        local ModulesLayout = Instance.new("UIGridLayout")
        ModulesLayout.CellSize = UDim2.new(0, 200, 0, 35)
        ModulesLayout.CellPadding = UDim2.new(0, 10, 0, 8)
        ModulesLayout.SortOrder = Enum.SortOrder.LayoutOrder
        ModulesLayout.Parent = ModulesContainer
        
        local function UpdateCategorySize()
            local rows = math.ceil(#ModulesContainer:GetChildren() / 2)
            local height = 50 + (rows * 43) + 10 -- Header + modules + padding
            CategoryFrame.Size = UDim2.new(1, 0, 0, height)
            UpdateContentSize()
        end
        
        function Category:CreateModule(moduleName, options)
            options = options or {}
            local enabled = options.Default or false
            local callback = options.Callback or function() end
            
            -- VapeV4 style module button
            local ModuleButton = Instance.new("TextButton")
            ModuleButton.Name = moduleName
            ModuleButton.Size = UDim2.new(0, 200, 0, 35)
            ModuleButton.BackgroundColor3 = enabled and CurrentTheme.Accent or CurrentTheme.BackgroundTertiary
            ModuleButton.BorderSizePixel = 0
            ModuleButton.Text = moduleName
            ModuleButton.TextColor3 = CurrentTheme.Text
            ModuleButton.TextSize = 13
            ModuleButton.Font = Enum.Font.Gotham
            ModuleButton.Parent = ModulesContainer
            
            CreateCorner(ModuleButton, 8)
            
            local isEnabled = enabled
            
            ModuleButton.MouseButton1Click:Connect(function()
                isEnabled = not isEnabled
                
                CreateTween(ModuleButton, {
                    BackgroundColor3 = isEnabled and CurrentTheme.Accent or CurrentTheme.BackgroundTertiary
                }, 0.2):Play()
                
                callback(isEnabled)
            end)
            
            -- Hover effect
            ModuleButton.MouseEnter:Connect(function()
                if not isEnabled then
                    CreateTween(ModuleButton, {BackgroundColor3 = CurrentTheme.BackgroundTertiary:lerp(CurrentTheme.Accent, 0.3)}, 0.2):Play()
                end
            end)
            
            ModuleButton.MouseLeave:Connect(function()
                if not isEnabled then
                    CreateTween(ModuleButton, {BackgroundColor3 = CurrentTheme.BackgroundTertiary}, 0.2):Play()
                end
            end)
            
            UpdateCategorySize()
            
            local ModuleFunctions = {}
            function ModuleFunctions:SetEnabled(value)
                isEnabled = value
                ModuleButton.BackgroundColor3 = isEnabled and CurrentTheme.Accent or CurrentTheme.BackgroundTertiary
            end
            
            return ModuleFunctions
        end
        
        return Category
    end
    
    return WindowFunctions
end
    
    -- Dragging
    local function StartDrag(input)
        Dragging = true
        DragStart = input.Position
        StartPos = MainFrame.Position
    end
    
    local function UpdateDrag(input)
        if Dragging then
            local delta = input.Position - DragStart
            MainFrame.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + delta.X, StartPos.Y.Scale, StartPos.Y.Offset + delta.Y)
        end
    end
    
    local function EndDrag()
        Dragging = false
    end
    
    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            StartDrag(input)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            UpdateDrag(input)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            EndDrag()
        end
    end)
    
    -- Toggle GUI
    local GuiVisible = true
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == toggleKey then
            GuiVisible = not GuiVisible
            MainFrame.Visible = GuiVisible
        end
    end)
    
    -- Close functionality
    CloseButton.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
        if BlurEffect then
            BlurEffect:Destroy()
        end
    end)
    
    -- Button hover effects
    local function CreateButtonHover(button, hoverColor)
        local originalColor = button.BackgroundColor3
        
        button.MouseEnter:Connect(function()
            CreateTween(button, {BackgroundColor3 = hoverColor}, 0.2):Play()
        end)
        
        button.MouseLeave:Connect(function()
            CreateTween(button, {BackgroundColor3 = originalColor}, 0.2):Play()
        end)
    end
    
    CreateButtonHover(CloseButton, Color3.fromRGB(255, 100, 147))
    
    local WindowFunctions = {}
    
    function WindowFunctions:CreateTab(tabName)
        local Tab = {}
        
        -- VapeV4 style tab button
        local TabButton = Instance.new("TextButton")
        TabButton.Name = tabName
        TabButton.Size = UDim2.new(0, 100, 1, 0)
        TabButton.BackgroundColor3 = CurrentTheme.BackgroundTertiary
        TabButton.BorderSizePixel = 0
        TabButton.Text = tabName
        TabButton.TextColor3 = CurrentTheme.TextSecondary
        TabButton.TextSize = 13
        TabButton.Font = Enum.Font.Gotham
        TabButton.Parent = TabList
        
        CreateCorner(TabButton, 10)
        
        -- Tab content area
        local TabContent = Instance.new("ScrollingFrame")
        TabContent.Name = tabName .. "Content"
        TabContent.Size = UDim2.new(1, 0, 1, 0)
        TabContent.Position = UDim2.new(0, 0, 0, 0)
        TabContent.BackgroundTransparency = 1
        TabContent.BorderSizePixel = 0
        TabContent.ScrollBarThickness = 2
        TabContent.ScrollBarImageColor3 = CurrentTheme.Accent
        TabContent.Visible = false
        TabContent.Parent = ContentArea
        
        local ContentLayout = Instance.new("UIListLayout")
        ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
        ContentLayout.Padding = UDim.new(0, 10)
        ContentLayout.Parent = TabContent
        
        local ContentPadding = Instance.new("UIPadding")
        ContentPadding.PaddingTop = UDim.new(0, 10)
        ContentPadding.PaddingBottom = UDim.new(0, 10)
        ContentPadding.PaddingLeft = UDim.new(0, 0)
        ContentPadding.PaddingRight = UDim.new(0, 0)
        ContentPadding.Parent = TabContent
        
        -- Update tab list canvas size
        local function UpdateTabList()
            TabList.CanvasSize = UDim2.new(0, TabListLayout.AbsoluteContentSize.X, 0, 0)
        end
        
        TabListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateTabList)
        
        Tabs[tabName] = {Button = TabButton, Content = TabContent}
        
        local function SelectTab()
            for _, tab in pairs(Tabs) do
                tab.Content.Visible = false
                CreateTween(tab.Button, {
                    BackgroundColor3 = CurrentTheme.BackgroundTertiary,
                    TextColor3 = CurrentTheme.TextSecondary
                }, 0.2):Play()
            end
            
            TabContent.Visible = true
            CreateTween(TabButton, {
                BackgroundColor3 = CurrentTheme.Accent,
                TextColor3 = CurrentTheme.Text
            }, 0.2):Play()
            
            CurrentTab = tabName
        end
        
        TabButton.MouseButton1Click:Connect(SelectTab)
        
        if not CurrentTab then
            SelectTab()
        end
        
        -- VapeV4 style button hover
        CreateButtonHover(TabButton, CurrentTheme.AccentDark)
        
        function Tab:CreateSection(sectionName)
            local Section = {}
            
            -- VapeV4 style section container
            local SectionFrame = Instance.new("Frame")
            SectionFrame.Name = sectionName
            SectionFrame.Size = UDim2.new(1, 0, 0, 30)
            SectionFrame.BackgroundColor3 = CurrentTheme.BackgroundSecondary
            SectionFrame.BorderSizePixel = 0
            SectionFrame.Parent = TabContent
            
            CreateCorner(SectionFrame, 15)
            
            -- Section header
            local SectionHeader = Instance.new("Frame")
            SectionHeader.Size = UDim2.new(1, 0, 0, 35)
            SectionHeader.BackgroundColor3 = CurrentTheme.BackgroundTertiary
            SectionHeader.BorderSizePixel = 0
            SectionHeader.Parent = SectionFrame
            
            CreateCorner(SectionHeader, 15)
            
            -- Fix section header bottom
            local SectionHeaderFix = Instance.new("Frame")
            SectionHeaderFix.Size = UDim2.new(1, 0, 0, 15)
            SectionHeaderFix.Position = UDim2.new(0, 0, 1, -15)
            SectionHeaderFix.BackgroundColor3 = CurrentTheme.BackgroundTertiary
            SectionHeaderFix.BorderSizePixel = 0
            SectionHeaderFix.Parent = SectionHeader
            
            local SectionTitle = Instance.new("TextLabel")
            SectionTitle.Size = UDim2.new(1, -20, 1, 0)
            SectionTitle.Position = UDim2.new(0, 15, 0, 0)
            SectionTitle.BackgroundTransparency = 1
            SectionTitle.Text = sectionName
            SectionTitle.TextColor3 = CurrentTheme.Text
            SectionTitle.TextSize = 14
            SectionTitle.TextXAlignment = Enum.TextXAlignment.Left
            SectionTitle.Font = Enum.Font.GothamBold
            SectionTitle.Parent = SectionHeader
            
            local SectionContent = Instance.new("Frame")
            SectionContent.Size = UDim2.new(1, -20, 1, -40)
            SectionContent.Position = UDim2.new(0, 10, 0, 40)
            SectionContent.BackgroundTransparency = 1
            SectionContent.Parent = SectionFrame
            
            local SectionLayout = Instance.new("UIListLayout")
            SectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
            SectionLayout.Padding = UDim.new(0, 8)
            SectionLayout.Parent = SectionContent
            
            local function UpdateSectionSize()
                local contentSize = SectionLayout.AbsoluteContentSize.Y
                SectionFrame.Size = UDim2.new(1, 0, 0, contentSize + 55)
                
                -- Update tab content canvas size
                local totalSize = ContentLayout.AbsoluteContentSize.Y
                TabContent.CanvasSize = UDim2.new(0, 0, 0, totalSize + 20)
            end
            
            SectionLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateSectionSize)
            
            function Section:CreateButton(options)
                options = options or {}
                local buttonText = options.Text or "Button"
                local callback = options.Callback or function() end
                
                local Button = Instance.new("TextButton")
                Button.Size = UDim2.new(1, 0, 0, 30)
                Button.BackgroundColor3 = CurrentTheme.Accent
                Button.BorderSizePixel = 0
                Button.Text = buttonText
                Button.TextColor3 = CurrentTheme.Text
                Button.TextSize = 13
                Button.Font = Enum.Font.Gotham
                Button.Parent = SectionContent
                
                CreateCorner(Button, 8)
                
                Button.MouseButton1Click:Connect(function()
                    CreateTween(Button, {BackgroundColor3 = CurrentTheme.AccentDark}, 0.1):Play()
                    wait(0.1)
                    CreateTween(Button, {BackgroundColor3 = CurrentTheme.Accent}, 0.1):Play()
                    callback()
                end)
                
                CreateButtonHover(Button, CurrentTheme.AccentDark)
                UpdateSectionSize()
                
                return Button
            end
            
            function Section:CreateToggle(options)
                options = options or {}
                local toggleText = options.Text or "Toggle"
                local defaultState = options.Default or false
                local callback = options.Callback or function() end
                
                local ToggleFrame = Instance.new("Frame")
                ToggleFrame.Size = UDim2.new(1, 0, 0, 35)
                ToggleFrame.BackgroundColor3 = CurrentTheme.Background
                ToggleFrame.BorderSizePixel = 0
                ToggleFrame.Parent = SectionContent
                
                CreateCorner(ToggleFrame, 6)
                CreateStroke(ToggleFrame, CurrentTheme.Border)
                
                local ToggleLabel = Instance.new("TextLabel")
                ToggleLabel.Size = UDim2.new(1, -50, 1, 0)
                ToggleLabel.Position = UDim2.new(0, 10, 0, 0)
                ToggleLabel.BackgroundTransparency = 1
                ToggleLabel.Text = toggleText
                ToggleLabel.TextColor3 = CurrentTheme.Text
                ToggleLabel.TextSize = 14
                ToggleLabel.TextXAlignment = Enum.TextXAlignment.Left
                ToggleLabel.Font = Enum.Font.Gotham
                ToggleLabel.Parent = ToggleFrame
                
                local ToggleButton = Instance.new("TextButton")
                ToggleButton.Size = UDim2.new(0, 40, 0, 20)
                ToggleButton.Position = UDim2.new(1, -45, 0.5, -10)
                ToggleButton.BackgroundColor3 = defaultState and CurrentTheme.Success or CurrentTheme.Border
                ToggleButton.BorderSizePixel = 0
                ToggleButton.Text = ""
                ToggleButton.Parent = ToggleFrame
                
                CreateCorner(ToggleButton, 10)
                
                local ToggleIndicator = Instance.new("Frame")
                ToggleIndicator.Size = UDim2.new(0, 16, 0, 16)
                ToggleIndicator.Position = defaultState and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
                ToggleIndicator.BackgroundColor3 = CurrentTheme.Text
                ToggleIndicator.BorderSizePixel = 0
                ToggleIndicator.Parent = ToggleButton
                
                CreateCorner(ToggleIndicator, 8)
                
                local isToggled = defaultState
                
                ToggleButton.MouseButton1Click:Connect(function()
                    isToggled = not isToggled
                    
                    CreateTween(ToggleButton, {
                        BackgroundColor3 = isToggled and CurrentTheme.Success or CurrentTheme.Border
                    }, 0.2):Play()
                    
                    CreateTween(ToggleIndicator, {
                        Position = isToggled and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
                    }, 0.2):Play()
                    
                    callback(isToggled)
                end)
                
                UpdateSectionSize()
                
                local ToggleFunctions = {}
                function ToggleFunctions:SetValue(value)
                    isToggled = value
                    ToggleButton.BackgroundColor3 = isToggled and CurrentTheme.Success or CurrentTheme.Border
                    ToggleIndicator.Position = isToggled and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
                end
                
                return ToggleFunctions
            end
            
            return Section
        end
        
        return Tab
    end
    
    return WindowFunctions
end

return NovaLibrary
