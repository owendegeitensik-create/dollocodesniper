-- Luau, DollosCodeSniper.lua, Roblox client executor, Steal a Brainrot

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Configuration
local max_words = 6
local auto_redeem = false
local redeem_cooldown = 3

-- State
local collected = {}
local collecting = false
local redeeming = false
local running = true
local watched = {}
local watched_containers = {}
local connections = {}
local attempted_codes = {}
local last_redeem = 0
local last_status = "Waiting for Sammy..."

-- Helpers
local function trim(value)
    return tostring(value):gsub("^%s+", ""):gsub("%s+$", "")
end

local function sanitize(value)
    return trim(value):upper():gsub("[^A-Z0-9]", "")
end

local function set_status(message)
    last_status = tostring(message)
end

local function add_connection(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end

local function disconnect_all()
    running = false

    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    table.clear(connections)
end

-- Remove previous copy
local previous = playerGui:FindFirstChild("DollosCodeSniper")
if previous then
    previous:Destroy()
end

-- Main GUI
local gui = Instance.new("ScreenGui")
gui.Name = "DollosCodeSniper"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.Parent = playerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(340, 300)
main.Position = UDim2.new(0.5, -170, 0.5, -150)
main.BackgroundColor3 = Color3.fromRGB(18, 20, 29)
main.BorderSizePixel = 0
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = main

local outline = Instance.new("UIStroke")
outline.Color = Color3.fromRGB(85, 115, 190)
outline.Thickness = 1.4
outline.Parent = main

-- GUI builders
local function make_label(parent, name, text, position, size, text_size, color)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Position = position
    label.Size = size
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color or Color3.fromRGB(235, 238, 245)
    label.Font = Enum.Font.Gotham
    label.TextSize = text_size
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = parent
    return label
end

local function make_button(parent, name, text, position, size)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Position = position
    button.Size = size
    button.BackgroundColor3 = Color3.fromRGB(42, 50, 70)
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Color3.fromRGB(245, 247, 255)
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 12
    button.AutoButtonColor = true
    button.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button

    return button
end

-- Header
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 40)
header.BackgroundColor3 = Color3.fromRGB(29, 34, 48)
header.BorderSizePixel = 0
header.Parent = main

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 10)
headerCorner.Parent = header

make_label(
    header,
    "Title",
    "DOLLO'S CODE SNIPER (BETA)",
    UDim2.fromOffset(12, 0),
    UDim2.new(1, -85, 1, 0),
    12,
    Color3.fromRGB(135, 180, 255)
)

local minimizeButton = make_button(
    header, "Minimize", "—",
    UDim2.new(1, -62, 0, 7),
    UDim2.fromOffset(25, 26)
)

local closeButton = make_button(
    header, "Close", "X",
    UDim2.new(1, -32, 0, 7),
    UDim2.fromOffset(25, 26)
)

-- Status and preview
local statusLabel = make_label(
    main, "Status", last_status,
    UDim2.fromOffset(13, 48),
    UDim2.new(1, -26, 0, 30),
    11,
    Color3.fromRGB(175, 195, 225)
)
statusLabel.TextWrapped = true

local countLabel = make_label(
    main, "Count",
    "WORDS: 0 / 6",
    UDim2.fromOffset(13, 84),
    UDim2.new(1, -26, 0, 22),
    12,
    Color3.fromRGB(135, 180, 255)
)

local previewLabel = make_label(
    main, "Preview",
    "CODE: —",
    UDim2.fromOffset(13, 112),
    UDim2.new(1, -26, 0, 37),
    14,
    Color3.fromRGB(255, 255, 255)
)
previewLabel.TextWrapped = true

-- Max word setting
make_label(
    main, "MaxLabel", "MAX WORDS (1–6)",
    UDim2.fromOffset(13, 161),
    UDim2.fromOffset(130, 27),
    11
)

local maxInput = Instance.new("TextBox")
maxInput.Name = "MaxWords"
maxInput.Position = UDim2.fromOffset(145, 159)
maxInput.Size = UDim2.fromOffset(55, 29)
maxInput.BackgroundColor3 = Color3.fromRGB(38, 44, 59)
maxInput.TextColor3 = Color3.fromRGB(255, 255, 255)
maxInput.PlaceholderText = "1-6"
maxInput.Text = "6"
maxInput.Font = Enum.Font.GothamBold
maxInput.TextSize = 13
maxInput.ClearTextOnFocus = false
maxInput.Parent = main

local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 5)
inputCorner.Parent = maxInput

local autoButton = make_button(
    main, "AutoRedeem", "AUTO REDEEM: OFF",
    UDim2.fromOffset(210, 159),
    UDim2.fromOffset(117, 29)
)

-- Main controls
local finishButton = make_button(
    main, "Finish", "FINISH + REDEEM",
    UDim2.fromOffset(13, 207),
    UDim2.fromOffset(153, 36)
)

local clearButton = make_button(
    main, "Clear", "CLEAR",
    UDim2.fromOffset(174, 207),
    UDim2.fromOffset(153, 36)
)

make_label(
    main, "Footer",
    "Listening for Sammy's code announcements",
    UDim2.fromOffset(13, 256),
    UDim2.new(1, -26, 0, 23),
    10,
    Color3.fromRGB(135, 150, 175)
)

-- Display
local function refresh()
    countLabel.Text = string.format(
        "WORDS: %d / %d",
        #collected,
        max_words
    )

    local code = table.concat(collected, "")
    previewLabel.Text = "CODE: " .. (code ~= "" and code or "—")
    statusLabel.Text = last_status
end

-- Word collection
local function clear_words()
    table.clear(collected)
    collecting = false
    set_status("Cleared. Waiting for next announcement.")
    refresh()
end

local function update_max()
    local value = tonumber(maxInput.Text)

    if not value then
        value = 6
    end

    max_words = math.clamp(math.floor(value), 1, 6)
    maxInput.Text = tostring(max_words)

    if #collected > max_words then
        while #collected > max_words do
            table.remove(collected)
        end
    end

    set_status("Maximum word count set to " .. max_words)
    refresh()
end

add_connection(maxInput.FocusLost, update_max)

-- Auto redeem toggle
add_connection(autoButton.MouseButton1Click, function()
    auto_redeem = not auto_redeem

    autoButton.Text = auto_redeem
        and "AUTO REDEEM: ON"
        or "AUTO REDEEM: OFF"

    autoButton.BackgroundColor3 = auto_redeem
        and Color3.fromRGB(35, 105, 75)
        or Color3.fromRGB(42, 50, 70)

    set_status(auto_redeem
        and "Auto redeem enabled"
        or "Manual redemption enabled")

    refresh()
end)

-- Exact confirmed game redemption controls
local function open_codes()
    local codesGui = playerGui:FindFirstChild("Codes")
    if not codesGui then
        return nil, nil
    end

    if codesGui:IsA("ScreenGui") then
        codesGui.Enabled = true
    end

    local panel = codesGui:FindFirstChild("Codes")
    if not panel then
        return nil, nil
    end

    if panel:IsA("GuiObject") then
        panel.Visible = true
    end

    local redeemPanel = panel:FindFirstChild("CodeRedeem")
    local textbox = redeemPanel and redeemPanel:FindFirstChild("TextBox")
    local confirm = panel:FindFirstChild("Confirm")

    if not textbox or not textbox:IsA("TextBox") then
        return nil, nil
    end

    if not confirm or not confirm:IsA("ImageButton") then
        return nil, nil
    end

    return textbox, confirm
end

-- Confirmed redemption handler
local function redeem_code()
    if redeeming then
        return false
    end

    if #collected == 0 then
        set_status("No words collected")
        refresh()
        return false
    end

    local code = sanitize(table.concat(collected, ""))

    if code == "" then
        set_status("Code is empty")
        refresh()
        return false
    end

    if attempted_codes[code] then
        set_status("Already attempted: " .. code)
        refresh()
        return false
    end

    if os.clock() - last_redeem < redeem_cooldown then
        set_status("Redemption cooldown. Wait a moment.")
        refresh()
        return false
    end

    redeeming = true
    set_status("Opening Codes interface...")
    refresh()

    local textbox, confirm = open_codes()

    if not textbox or not confirm then
        set_status("Codes controls not found. Open Codes manually.")
        redeeming = false
        refresh()
        return false
    end

    if type(getconnections) ~= "function"
        or type(firesignal) ~= "function" then
        set_status("Executor missing required event functions")
        redeeming = false
        refresh()
        return false
    end

    local ok, result = pcall(function()
        local handlers = getconnections(confirm.Activated)
        local enabled_count = 0

        for _, connection in ipairs(handlers) do
            if connection.Enabled then
                enabled_count += 1
            end
        end

        if enabled_count ~= 1 then
            error("Expected one enabled Confirm handler; found " .. enabled_count)
        end

        textbox.Text = code
        task.wait(0.2)

        attempted_codes[code] = true
        last_redeem = os.clock()

        firesignal(confirm.Activated)
    end)

    redeeming = false

    if ok then
        set_status("Submitted: " .. code .. " — check game response")
        collecting = false
        refresh()
        return true
    else
        set_status("Redemption error: " .. tostring(result))
        refresh()
        return false
    end
end

-- Finish and clear
add_connection(finishButton.MouseButton1Click, function()
    if #collected == 0 then
        set_status("No words to redeem")
        refresh()
        return
    end

    collecting = false
    redeem_code()
end)

add_connection(clearButton.MouseButton1Click, clear_words)

-- Announcement recognition
local trigger_phrases = {
    "the code is",
    "your code is",
    "code is",
    "use code",
    "redeem code",
    "new code",
    "code:",
    "code -"
}

local function is_redemption_response(message)
    local lower = message:lower()

    local blocked_phrases = {
        "sold out",
        "invalid code",
        "already redeemed",
        "already used",
        "wait before trying",
        "too many attempts",
        "successfully redeemed"
    }

    for _, phrase in ipairs(blocked_phrases) do
        if lower:find(phrase, 1, true) then
            return true
        end
    end

    return false
end

local function is_instruction(message)
    local lower = trim(message):lower()

    if lower == "wait" or lower == "wait!" then
        return true
    end

    local blocked = {
        "this code",
        "code has",
        "code does",
        "code contains",
        "numbers",
        "number",
        "letters",
        "letter",
        "redeem it",
        "go to the codes",
        "limited time",
        "good luck",
        "sammy"
    }

    for _, phrase in ipairs(blocked) do
        if lower:find(phrase, 1, true) then
            return true
        end
    end

    return false
end

local function add_word(word)
    if #collected >= max_words then
        return false
    end

    local clean = sanitize(word)
    if clean == "" then
        return false
    end

    table.insert(collected, clean)

    set_status("Captured word " .. #collected .. ": " .. clean)
    refresh()

    if #collected >= max_words then
        collecting = false

        if auto_redeem then
            set_status("Maximum reached. Redeeming...")
            refresh()
            task.defer(function()
                if running then
                    redeem_code()
                end
            end)
        else
            set_status("Maximum reached. Press FINISH + REDEEM.")
            refresh()
        end

        return false
    end

    return true
end

local function begin_collection()
    table.clear(collected)
    collecting = true

    set_status("Sammy's code announcement detected")
    refresh()
end

-- Detect trigger phrases at the beginning of a message.
-- Also supports Sammy placing code words in the same announcement.
local function detect_trigger(message)
    local lower = message:lower()

    if is_redemption_response(message) then
        return false, nil
    end

    for _, phrase in ipairs(trigger_phrases) do
        local start_pos, end_pos = lower:find(phrase, 1, true)

        if start_pos and start_pos <= 35 then
            local prefix = trim(message:sub(1, start_pos - 1)):lower()

            -- Allow announcement prefixes such as "Sammy:" or "Sammy says:"
            if #prefix > 0 and #prefix > 35 then
                continue
            end

            local remainder = trim(message:sub(end_pos + 1))
            remainder = remainder:gsub("^[%s:%-!%.]+", "")

            return true, remainder
        end
    end

    return false, nil
end

local function process_announcement(raw_text)
    if not running then
        return
    end

    local message = trim(raw_text)

    if message == "" or is_redemption_response(message) then
        return
    end

    -- Trigger can be a standalone message or part of the announcement.
    local triggered, remainder = detect_trigger(message)

    if triggered then
        begin_collection()

        if remainder and remainder ~= "" then
            if not is_instruction(remainder) then
                for word in remainder:gmatch("[%w]+") do
                    if not add_word(word) then
                        break
                    end
                end
            end
        end

        return
    end

    if not collecting then
        return
    end

    if is_instruction(message) then
        set_status("Ignored Sammy's instruction")
        refresh()
        return
    end

    -- Later code fragments are expected as individual words.
    -- Multi-word commentary is ignored to avoid collecting unrelated text.
    if message:find("%s") then
        set_status("Ignored announcement commentary")
        refresh()
        return
    end

    add_word(message)
end

-- Watch text objects for changes
local function watch_text(object, process_existing)
    if watched[object] then
        return
    end

    if not (
        object:IsA("TextLabel")
        or object:IsA("TextButton")
        or object:IsA("TextBox")
    ) then
        return
    end

    watched[object] = true

    local previous_text = object.Text

    add_connection(object:GetPropertyChangedSignal("Text"), function()
        if not running or not object.Parent then
            return
        end

        local current_text = object.Text

        if current_text ~= previous_text then
            previous_text = current_text
            process_announcement(current_text)
        end
    end)

    if process_existing and previous_text ~= "" then
        process_announcement(previous_text)
    end
end

-- Attach to notification containers, including newly added descendants.
local function watch_container(container)
    if not container or watched_containers[container] then
        return
    end

    watched_containers[container] = true

    if container:IsA("TextLabel")
        or container:IsA("TextButton")
        or container:IsA("TextBox") then
        watch_text(container, true)
    end

    for _, object in ipairs(container:GetDescendants()) do
        watch_text(object, true)
    end

    add_connection(container.DescendantAdded, function(object)
        task.defer(function()
            if running then
                watch_text(object, true)

                for _, descendant in ipairs(object:GetDescendants()) do
                    watch_text(descendant, true)
                end
            end
        end)
    end)
end

-- Find the current Sammy notification GUI.
local function find_notification_root()
    local top_gui = playerGui:FindFirstChild("TopNotification")

    if not top_gui then
        return nil
    end

    local nested = top_gui:FindFirstChild("TopNotification")

    return nested or top_gui
end

-- Watch for notification GUI creation and replacement.
task.spawn(function()
    local last_root = nil

    while running do
        local current_root = find_notification_root()

        if current_root and current_root ~= last_root then
            last_root = current_root
            watch_container(current_root)

            set_status("Sammy announcement watcher connected")
            refresh()
        elseif not current_root and last_root then
            last_root = nil
            set_status("Waiting for TopNotification GUI...")
            refresh()
        end

        task.wait(1)
    end
end)

-- Detect TopNotification being created after script startup.
add_connection(playerGui.ChildAdded, function(child)
    if child.Name == "TopNotification" then
        task.wait(0.1)

        if running then
            local root = find_notification_root()

            if root then
                watch_container(root)
                set_status("Sammy announcement watcher connected")
                refresh()
            end
        end
    end
end)

-- Dragging
local dragging = false
local drag_start
local start_position

add_connection(header.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        drag_start = input.Position
        start_position = main.Position
    end
end)

add_connection(UserInputService.InputChanged, function(input)
    if dragging and (
        input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
    ) then

        local delta = input.Position - drag_start

        main.Position = UDim2.new(
            start_position.X.Scale,
            start_position.X.Offset + delta.X,
            start_position.Y.Scale,
            start_position.Y.Offset + delta.Y
        )
    end
end)

add_connection(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- Minimize
local minimized = false

add_connection(minimizeButton.MouseButton1Click, function()
    minimized = not minimized

    for _, child in ipairs(main:GetChildren()) do
        if child ~= header
            and child ~= outline
            and child ~= mainCorner
            and child:IsA("GuiObject") then

            child.Visible = not minimized
        end
    end

    main.Size = minimized
        and UDim2.fromOffset(340, 40)
        or UDim2.fromOffset(340, 300)
end)

-- Close
add_connection(closeButton.MouseButton1Click, function()
    disconnect_all()
    gui:Destroy()
end)

refresh()
set_status("Waiting for Sammy's announcement...")
refresh()

print("[DollosCodeSniper] Loaded. Waiting for Sammy.")
