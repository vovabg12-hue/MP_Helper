local imgui = require 'mimgui'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
require "lib.moonloader"
imgui.HotKey = require("imgui_addons").HotKey
local wm = require("windows.message")
local hasSampev, sampev = pcall(require, "lib.samp.events")
if not hasSampev or not sampev then
    sampev = require "samp.events"
end
local ffi = require 'ffi'
local inicfg = require "inicfg"
local directIni = "MPHelper.ini"
local addons = require "ADDONS"
local ltn12Ok, ltn12 = pcall(require, "ltn12")
local httpsOk, https = pcall(require, "ssl.https")
local httpOk, http = pcall(require, "socket.http")
local str = ffi.string
local sizeof = ffi.sizeof
local json = require "json" -- Нужен для decodeJson/encodeJson и хранения списка игнора
local mailLogoTexture = nil
local mailLogoPath = nil
local logoLoadTried = false
local logoDrawSize = imgui.ImVec2(290, 124)
local isMpSendInProgress = false
local FIXED_TS_RADIUS = 400
local scriptChatMessage

local function getScriptDirectory()
    local scriptPath = thisScript().path or ""
    return scriptPath:match("^(.*[\\/])") or ""
end

local function readBinaryFile(path, maxBytes)
    local file = io.open(path, "rb")
    if not file then
        return nil
    end

    local content = file:read(maxBytes or "*a")
    file:close()

    return content
end

local function getPngSize(path)
    local header = readBinaryFile(path, 24)
    if not header or #header < 24 then
        return nil, nil
    end

    if header:sub(1, 8) ~= "\137PNG\r\n\026\n" then
        return nil, nil
    end

    local w1, w2, w3, w4, h1, h2, h3, h4 = header:byte(17, 24)
    local width = ((w1 * 256 + w2) * 256 + w3) * 256 + w4
    local height = ((h1 * 256 + h2) * 256 + h3) * 256 + h4

    if width <= 0 or height <= 0 then
        return nil, nil
    end

    return width, height
end

local function updateLogoDrawSize(path)
    local maxWidth, maxHeight = 290, 124
    local width, height = getPngSize(path)

    if not width or not height then
        logoDrawSize = imgui.ImVec2(maxWidth, maxHeight)
        return
    end

    local scale = math.min(maxWidth / width, maxHeight / height)
    logoDrawSize = imgui.ImVec2(math.floor(width * scale + 0.5), math.floor(height * scale + 0.5))
end

local function ensureMailLogoAssets()
    local scriptDir = getScriptDirectory()
    local logoDir = scriptDir .. "MPHelper\\"
    local logoPath = logoDir .. "arizona_mesa_logo.png"

    if not doesDirectoryExist(logoDir) then
        createDirectory(logoDir)
    end

    mailLogoPath = logoPath
end

local function tryLoadMailLogoTexture()
    if mailLogoTexture or logoLoadTried or not mailLogoPath then
        return
    end

    if not doesFileExist(mailLogoPath) then
        return
    end

    local ok, texture = pcall(imgui.CreateTextureFromFile, mailLogoPath)
    if ok and texture then
        mailLogoTexture = texture
        updateLogoDrawSize(mailLogoPath)
    end
    logoLoadTried = true
end

local mainIni = inicfg.load({
    settings = {
        antitk = false,
        antiarmour = false,
        antihp = false,
        antigun = false,
        antidm = false,
        autotsradius = false,
        autospawnradius = false,
        radius = 100,
        delay = 4000,
        pt = 500
    },
    ignorlist = {
        list = "[]",
    }
}, "MPHelper")

local ignorList = {}
if mainIni.ignorlist.list and mainIni.ignorlist.list ~= "" then
    ignorList = json.decode(mainIni.ignorlist.list) or {}
end
function save_ignore()
    mainIni.ignorlist.list = json.encode(ignorList)
    save_ini()
end
function isIgnored(nick)
    for _, v in ipairs(ignorList) do
        if v == nick then
            return true
        end
    end
    if eventAutomation.mode == "set_spawn" then
        eventAutomation.active = false
        eventSpawnStatusText = u8("Позиция: Не удалось автоустановить")
        eventSpawnStatusColor = imgui.ImVec4(0.90, 0.35, 0.35, 1.0)
        return
    end

    return false
end
function table.contains(t, element)
    for _, value in pairs(t) do
        if value == element then
            return true
        end
    end
    return false
end

function table.random(t)
    local keyset = {}
    for k in pairs(t) do
        table.insert(keyset, k)
    end
    return t[keyset[math.random(#keyset)]]
end
function splitIds(str)
    local t = {}
    for id in string.gmatch(str, "%d+") do
        table.insert(t, tonumber(id))
    end
    return t
end
function plvehall(ids)
    local clist = splitIds(ids)

    if #clist < 1 then
        scriptChatMessage("Введите ID транспорта!")
        return
    end

    local chars = getAllChars()
    local players = {}

    local px, py, pz = getCharCoordinates(PLAYER_PED)

    for _, char in pairs(chars) do
        if char ~= PLAYER_PED then
            local result, id = sampGetPlayerIdByCharHandle(char)

            if result then
                local nick = sampGetPlayerNickname(id)
                local cx, cy, cz = getCharCoordinates(char)
                local distance = getDistanceBetweenCoords3d(px, py, pz, cx, cy, cz)

                if not isIgnored(nick) and distance <= FIXED_TS_RADIUS then
                    table.insert(players, id)
                end
            end
        end
    end

    if #players == 0 then
        scriptChatMessage("Игроки в радиусе не найдены!")
        return
    end

    scriptChatMessage("Найдено игроков: "..#players)

    lua_thread.create(function()
        for _, player in pairs(players) do
            local res, ped = sampGetCharHandleBySampPlayerId(player)

            if res and isCharOnFoot(ped) then
                sampSendChat("/plveh "..player.." "..table.random(clist))
                wait(mainIni.settings.delay)
            end
        end
        scriptChatMessage("Т/С выданы всем игрокам!")
    end)
end

function setFuelAllInRadius(targetRadius, fuelAmount)
    local px, py, pz = getCharCoordinates(PLAYER_PED)
    local vehicles = getAllVehicles()
    local vehicleIds = {}

    for _, vehicle in pairs(vehicles) do
        if doesVehicleExist(vehicle) then
            local vx, vy, vz = getCarCoordinates(vehicle)
            local distance = getDistanceBetweenCoords3d(px, py, pz, vx, vy, vz)
            if distance <= targetRadius then
                local result, carId = sampGetVehicleIdByCarHandle(vehicle)
                if result and carId then
                    table.insert(vehicleIds, carId)
                end
            end
        end
    end

    if #vehicleIds == 0 then
        scriptChatMessage("Машины в радиусе не найдены!")
        return
    end

    lua_thread.create(function()
        for _, carId in ipairs(vehicleIds) do
            sampSendChat("/setfuel "..carId.." "..fuelAmount)
            wait(1500)
        end
        scriptChatMessage("Топливо успешно выдано всем машинам в радиусе!")
    end)
end

if not doesFileExist("MPHelper.ini") then
    inicfg.save(mainIni, "MPHelper.ini")
end

local antitk = imgui.new.bool((mainIni.settings.antitk))
local antiarmour = imgui.new.bool((mainIni.settings.antiarmour))
local antihp = imgui.new.bool((mainIni.settings.antihp))
local antigun = imgui.new.bool((mainIni.settings.antigun))
local antidm = imgui.new.bool((mainIni.settings.antidm))
local autotsradius = imgui.new.bool((mainIni.settings.autotsradius))
local autospawnradius = imgui.new.bool((mainIni.settings.autospawnradius))
local radius = imgui.new.int((mainIni.settings.radius))
local delay = imgui.new.int((mainIni.settings.delay))
local pt = imgui.new.int[1](tonumber(mainIni.settings.pt) or 500)
local ignor = imgui.new.char[256]()
local IDT = imgui.new.char[256]()
local IDSK = imgui.new.char[256]()
local IDG = imgui.new.char[256]()

local mp = {
    name = imgui.new.char[256](),
    type = imgui.new.int(0),
    priz = imgui.new.char[256](),
    result = imgui.new.char[512](),
    winner = imgui.new.int(0),
    result_end = imgui.new.char[512]()
}
local eventConfigWindow = imgui.new.bool(false)
local eventSlotIdText = imgui.new.char[8]()
local eventPlayerLimit = imgui.new.int(0)
local eventTeleportTime = imgui.new.int(0)
local eventPassword = imgui.new.char[32]()
local eventHp = imgui.new.int(0)
local eventArmour = imgui.new.int(0)
local eventSkin = imgui.new.int(0)
local eventRepeatTp = imgui.new.bool(false)
local eventAllowDamage = imgui.new.bool(false)
local eventAccessoryEffect = imgui.new.bool(false)
local eventGuards = imgui.new.bool(false)
local eventPlayerCollision = imgui.new.bool(true)
local eventSpawnApplied = false
local eventSpawnStatusText = u8("Позиция: Не установлено")
local eventSpawnStatusColor = imgui.ImVec4(0.85, 0.35, 0.35, 1.0)
local eventSpawnMessageSent = false
local hideSpawnDialogsUntil = 0
local hiddenEventDialogsUntil = {}
local eventAutomation = {
    active = false,
    mode = nil,
    stage = nil,
    valueStep = 1,
    toggleStep = 1,
    valueSteps = {},
    toggleSteps = {},
    startAfterSave = false,
    slot = 0,
    loading = false,
    pendingInput = nil,
    inRulesMenu = false
}

local EVENT_MENU_INDEX = {
    RULES_MENU = 1,
    SPAWN_POS = 2,
    BROADCAST = 3,
    PLAYER_LIMIT = 4,
    TELEPORT_TIME = 5,
    PASSWORD = 6,
    HP = 7,
    ARMOUR = 8,
    SKIN = 9,
    REPEAT_TP = 13,
    DAMAGE_PLAYERS = 15,
    ACCESSORY_EFFECT = 16,
    GUARDS = 17,
    PLAYER_COLLISION = 24,
    START_EVENT = 25,
    SAVE_CHANGES = 26
}

local RULES_MENU_INDEX = {
    REPEAT_TP = 0,
    DAMAGE_PLAYERS = 2,
    ACCESSORY_EFFECT = 3,
    GUARDS = 4,
    PLAYER_COLLISION = 8,
    START_EVENT = 10
}

imgui.StrCopy(eventPassword, "0")

local function normalizeDialogText(value)
    local text = tostring(value or ""):upper()
    text = text:gsub("{[%x]+}", "")
    text = text:gsub("\t", " ")
    text = text:gsub("%s+", " ")
    return text
end

local function resolveDialogLineBySlot(dialogText, slotId)
    local wanted = tonumber(slotId)
    if wanted == nil then
        return 0
    end
    wanted = math.max(0, math.floor(wanted))
    local wantedRaw = tostring(wanted)
    local wantedPadded = string.format("%02d", wanted)

    local slotRowIndex = 0
    local parsedRows = {}
    for rawLine in tostring(dialogText or ""):gmatch("[^\r\n]+") do
        local line = normalizeDialogText(rawLine)
        local bracketSlot = line:match("%[(%d+)%]")
        local idSlot = line:match("ID%s*:?%s*(%d+)")
        local slotWordSlot = line:match("СЛОТ%s*:?%s*(%d+)")
        local plainNumber = line:match("^(%d+)%D")
        local token = bracketSlot or idSlot or slotWordSlot or plainNumber
        local parsedSlot = tonumber(token)

        if parsedSlot ~= nil then
            table.insert(parsedRows, { row = slotRowIndex, slot = parsedSlot, token = token })
            if token == wantedRaw or token == wantedPadded or parsedSlot == wanted then
                return slotRowIndex
            end
            slotRowIndex = slotRowIndex + 1
        end
    end

    if #parsedRows > 0 then
        local hasZeroSlot = false
        for _, row in ipairs(parsedRows) do
            if row.slot == 0 then
                hasZeroSlot = true
                break
            end
        end

        if not hasZeroSlot then
            local oneBasedWanted = wanted + 1
            for _, row in ipairs(parsedRows) do
                if row.slot == oneBasedWanted then
                    return row.row
                end
            end
        end

        local firstSlotRowIndex = parsedRows[1].row
        local firstParsedSlotValue = parsedRows[1].slot
        local relative = wanted - firstParsedSlotValue
        if relative >= 0 then
            return firstSlotRowIndex + relative
        end
        return math.max(firstSlotRowIndex, math.min(29, wanted))
    end

    return math.max(0, math.min(29, wanted))
end

local function clampEventValues()
    eventPlayerLimit[0] = math.max(0, eventPlayerLimit[0])
    eventTeleportTime[0] = math.max(1, math.min(300, eventTeleportTime[0]))
    eventHp[0] = math.max(5, math.min(250, eventHp[0]))
    eventArmour[0] = math.max(5, math.min(250, eventArmour[0]))
    eventSkin[0] = math.max(0, eventSkin[0])
end

local function getEventSlotId()
    local raw = ffi.string(eventSlotIdText)
    if raw == "" then
        return nil
    end
    local num = tonumber(raw)
    if not num then
        return nil
    end
    num = math.floor(num)
    if num < 0 then
        num = 0
    end
    if num > 29 then
        num = 29
    end
    return num
end

local function startEventAutomation(mode)
    clampEventValues()
    local slotId = getEventSlotId()
    if slotId == nil then
        eventAutomation.active = false
        eventSpawnStatusText = u8("Позиция: Укажите слот 0-29")
        eventSpawnStatusColor = imgui.ImVec4(0.90, 0.35, 0.35, 1.0)
        scriptChatMessage("Укажите номер слота МП (0-29), затем повторите действие.")
        return
    end
    eventAutomation.active = true
    eventAutomation.mode = mode
    eventAutomation.stage = "select_slot"
    eventAutomation.valueStep = 1
    eventAutomation.toggleStep = 1
    eventAutomation.valueSteps = {}
    eventAutomation.toggleSteps = {}
    eventAutomation.startAfterSave = mode == "apply_and_start"
    eventAutomation.slot = slotId
    eventAutomation.loading = (mode == "load")
    eventAutomation.pendingInput = nil
    eventAutomation.inRulesMenu = false
    if mode == "set_spawn" then
        eventSpawnApplied = false
        eventSpawnMessageSent = false
        hideSpawnDialogsUntil = os.clock() + 8
        eventSpawnStatusText = u8("Позиция: Выполняется сохранение...")
        eventSpawnStatusColor = imgui.ImVec4(0.95, 0.80, 0.20, 1.0)
    end
    sampSendChat("/eventmenu")
end

local function resolveDialogLineByKeywords(dialogText, keywords, fallbackIndex)
    local lineIndex = 0
    for rawLine in tostring(dialogText or ""):gmatch("[^\r\n]+") do
        local line = normalizeDialogText(rawLine)
        local matched = true
        for _, keyword in ipairs(keywords) do
            if not line:find(keyword, 1, true) then
                matched = false
                break
            end
        end
        if matched then
            return lineIndex
        end
        lineIndex = lineIndex + 1
    end
    return fallbackIndex or 0
end

local function parseFieldValue(dialogText, fieldName)
    local safeField = normalizeDialogText(fieldName):gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    for rawLine in tostring(dialogText or ""):gmatch("[^\r\n]+") do
        local line = normalizeDialogText(rawLine)
        if line:find(safeField, 1, true) then
            local value = line:match(":%s*([^\n\r]+)")
            if value then
                return normalizeDialogText(value)
            end
        end
    end
    return ""
end

local function parseFieldNumberByAliases(dialogText, aliases, fallback)
    for rawLine in tostring(dialogText or ""):gmatch("[^\r\n]+") do
        local line = normalizeDialogText(rawLine)
        for _, alias in ipairs(aliases) do
            if line:find(alias, 1, true) then
                local afterColon = line:match(":%s*([%-]?%d+)")
                if afterColon then
                    return tonumber(afterColon) or fallback
                end
                local anyNumber = line:match("([%-]?%d+)")
                if anyNumber then
                    return tonumber(anyNumber) or fallback
                end
            end
        end
    end
    return fallback
end

local function resolveDialogLineByAliases(dialogText, aliases, fallbackIndex)
    local rowIndex = 0
    for rawLine in tostring(dialogText or ""):gmatch("[^\r\n]+") do
        local line = normalizeDialogText(rawLine)
        if line ~= "" then
            for _, alias in ipairs(aliases or {}) do
                if line:find(normalizeDialogText(alias), 1, true) then
                    return rowIndex
                end
            end
            rowIndex = rowIndex + 1
        end
    end
    if fallbackIndex ~= nil then
        return fallbackIndex
    end
    return nil
end

local function findDialogRowByAliases(dialogText, aliases)
    local rowIndex = 0
    for rawLine in tostring(dialogText or ""):gmatch("[^\r\n]+") do
        local line = normalizeDialogText(rawLine)
        if line ~= "" then
            for _, alias in ipairs(aliases or {}) do
                if line:find(normalizeDialogText(alias), 1, true) then
                    return rowIndex, line
                end
            end
            rowIndex = rowIndex + 1
        end
    end
    return nil, nil
end

local function parseBoolFromValueText(valuePart)
    local value = normalizeDialogText(valuePart or "")
    if value == "" then
        return nil
    end

    if value:find("ДА", 1, true)
        or value:find("РАЗРЕШ", 1, true)
        or value:find("ВКЛ", 1, true)
        or value:find("ON", 1, true)
        or value:find("TRUE", 1, true)
        or value:find("АКТИВ", 1, true)
        or value:find("[+]", 1, true)
        or value:find("(+)", 1, true) then
        return true
    end

    if value:find("НЕТ", 1, true)
        or value:find("ЗАПРЕЩ", 1, true)
        or value:find("ВЫКЛ", 1, true)
        or value:find("OFF", 1, true)
        or value:find("FALSE", 1, true)
        or value:find("НЕАКТИВ", 1, true)
        or value:find("ОТКЛ", 1, true)
        or value:find("[-]", 1, true)
        or value:find("(-)", 1, true) then
        return false
    end

    return nil
end

local function parseFieldBoolByAliases(dialogText, aliases, fallback)
    for rawLine in tostring(dialogText or ""):gmatch("[^\r\n]+") do
        local line = normalizeDialogText(rawLine)
        for _, alias in ipairs(aliases) do
            if line:find(alias, 1, true) then
                local valuePart = line:match(":%s*(.+)$") or line
                local parsed = parseBoolFromValueText(valuePart)
                if parsed ~= nil then
                    return parsed
                end
            end
        end
    end
    return fallback
end

local function parseFieldBoolByRowIndex(dialogText, rowIndex, fallback)
    local wanted = tonumber(rowIndex)
    if wanted == nil then
        return fallback
    end
    wanted = math.max(0, math.floor(wanted))
    local currentIndex = 0
    for rawLine in tostring(dialogText or ""):gmatch("[^\r\n]+") do
        local line = normalizeDialogText(rawLine)
        if line ~= "" then
            if currentIndex == wanted then
                local parsed = parseBoolFromValueText(line)
                if parsed ~= nil then
                    return parsed
                end
                break
            end
            currentIndex = currentIndex + 1
        end
    end
    return fallback
end

local function parseDamageAllowed(dialogText, fallback)
    local positive = parseFieldBoolByAliases(dialogText, {
        "НАНЕСЕНИЕ УРОНА ДРУГИМ ИГРОКАМ",
        "УРОН ДРУГИМ ИГРОКАМ",
        "УРОН ПО ИГРОКАМ"
    }, nil)
    if positive ~= nil then
        return positive
    end

    local negative = parseFieldBoolByAliases(dialogText, {
        "ЗАПРЕТ УРОНА ПО ИГРОКАМ"
    }, nil)
    if negative ~= nil then
        return not negative
    end

    return fallback
end

local function isEventAutomationDialog(titleText, bodyText)
    local title = normalizeDialogText(titleText)
    local body = normalizeDialogText(bodyText)

    local titleLooksEvent = title:find("МЕРОПРИЯТ", 1, true)
        or title:find("СПАВ", 1, true)
        or title:find("ПРАВИЛ", 1, true)
        or title:find("РЕДАКТИРОВАН", 1, true)

    local bodyLooksEvent = body:find("МЕРОПРИЯТ", 1, true)
        or body:find("ПОЗИЦ", 1, true)
        or body:find("СПАВ", 1, true)
        or body:find("ПОВТОР", 1, true)
        or body:find("КОЛЛИЗ", 1, true)

    return titleLooksEvent or bodyLooksEvent
end

local function needsToggle(dialogText, fieldName, targetYes)
    local current = parseFieldValue(dialogText, fieldName)
    if current == "" then
        return true
    end
    local isYes = current:find("ДА", 1, true) ~= nil
    return isYes ~= targetYes
end
local tkInfo = {};


local tag = "[ Event Helper ] "
local tagcolor = 0xCC4545
local textcolor = "{FFFFFF}"
local warncolor = "{FFFFFF}"
local WinState = imgui.new.bool()

scriptChatMessage = function(message)
    local msg = tostring(message or "")
    if msg:sub(1, #tag) ~= tag then
        msg = tag .. textcolor .. msg
    end
    sampAddChatMessage(msg, tagcolor)
end

local function formatPrize(prizeText)
    local digits = tostring(prizeText or ""):gsub("%D", "")

    if digits == "" then
        return ""
    end

    digits = digits:gsub("^0+", "")
    if digits == "" then
        return "0"
    end

    local parts = {}
    while #digits > 3 do
        table.insert(parts, 1, digits:sub(-3))
        digits = digits:sub(1, -4)
    end
    table.insert(parts, 1, digits)

    return table.concat(parts, ",")
end

local function getOrganizerNickname()
    local ok, isConnected, myId = pcall(sampGetPlayerIdByCharHandle, PLAYER_PED)
    if ok and isConnected then
        local nickOk, nick = pcall(sampGetPlayerNickname, myId)
        if nickOk and nick then
            return nick
        end
    end
    return "Unknown"
end

local function parsePrizeAmount(prizeText)
    local digits = tostring(prizeText or ""):gsub("%D", "")
    if digits == "" then
        return 0
    end
    return tonumber(digits) or 0
end

local function postJson(url, payload)
    if not ltn12Ok or not ltn12 then
        return false, "Модуль ltn12 недоступен."
    end

    local isHttps = url:match("^https://") ~= nil
    local client = nil
    if isHttps then
        client = httpsOk and https or nil
        if not client then
            return false, "HTTPS-клиент недоступен (ssl.https)."
        end
    else
        client = httpOk and http or nil
        if not client then
            return false, "HTTP-клиент недоступен (socket.http)."
        end
    end

    local encodeOk, body = pcall(json.encode, payload)
    if not encodeOk or type(body) ~= "string" then
        return false, "Ошибка сериализации JSON."
    end
    local responseBody = {}

    pcall(function()
        client.TIMEOUT = 5
    end)

    local requestOk, ok, statusCode, _, statusLine = pcall(client.request, {
        url = url,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#body)
        },
        source = ltn12.source.string(body),
        sink = ltn12.sink.table(responseBody)
    })

    if not requestOk then
        return false, "Ошибка запроса."
    end

    if not ok then
        return false, tostring(statusCode or statusLine or "Ошибка запроса.")
    end

    local code = tonumber(statusCode) or 0
    if code >= 200 and code < 300 then
        return true, code
    end

    return false, "HTTP " .. tostring(statusCode or statusLine or "unknown")
end

local function sendMpResultToServer()
    if isMpSendInProgress then
        return
    end

    local winnerNick = sampIsPlayerConnected(mp.winner[0]) and sampGetPlayerNickname(mp.winner[0]) or ""
    local mpName = str(mp.name)
    local prize = parsePrizeAmount(u8:decode(str(mp.priz)))
    local organizerNick = getOrganizerNickname()

    local payload = {
        nick = winnerNick,
        mp = mpName,
        prize = prize,
        organizer = organizerNick
    }

    isMpSendInProgress = true

    local ok, resultOrError = pcall(postJson, "https://mp-table-rryn.onrender.com/mp", payload)
    local sentOk = ok and resultOrError == true

    isMpSendInProgress = false

    if sentOk then
        scriptChatMessage(":true: Данные успешно переданы в таблицу.")
    else
        if ok and resultOrError then
            scriptChatMessage(":warning: Ошибка отправки: " .. tostring(resultOrError))
        end
        scriptChatMessage(":x: Не удалось передать данные в таблицу.")
    end
end

local function disableMainProtectionToggles()
    antitk[0] = false
    antiarmour[0] = false
    antihp[0] = false
    antigun[0] = false
    antidm[0] = false

    mainIni.settings.antitk = false
    mainIni.settings.antiarmour = false
    mainIni.settings.antihp = false
    mainIni.settings.antigun = false
    mainIni.settings.antidm = false
    autotsradius[0] = false
    autospawnradius[0] = false
    mainIni.settings.autotsradius = false
    mainIni.settings.autospawnradius = false
    save_ini()
end

local autoTsRadiusThreadRunning = false
local autoSpawnRadiusThreadRunning = false

local function collectPlayersInFixedRadius()
    local chars = getAllChars()
    local players = {}
    local px, py, pz = getCharCoordinates(PLAYER_PED)

    for _, char in pairs(chars) do
        if char ~= PLAYER_PED then
            local result, id = sampGetPlayerIdByCharHandle(char)
            if result then
                local nick = sampGetPlayerNickname(id)
                local cx, cy, cz = getCharCoordinates(char)
                local distance = getDistanceBetweenCoords3d(px, py, pz, cx, cy, cz)
                local hasVehicle = isCharInAnyCar(char)
                if not isIgnored(nick) and distance <= FIXED_TS_RADIUS and not hasVehicle then
                    table.insert(players, id)
                end
            end
        end
    end

    return players
end

local function startAutoTsRadiusThread()
    if autoTsRadiusThreadRunning then
        return
    end

    autoTsRadiusThreadRunning = true
    lua_thread.create(function()
        while mainIni.settings.autotsradius do
            local vehicleId = u8:decode(str(IDT)):match("%d+")

            if not vehicleId or vehicleId == "" then
                scriptChatMessage("Укажите ID Т/С в поле \"ID Т/С для выдачи\".")
                autotsradius[0] = false
                mainIni.settings.autotsradius = false
                save_ini()
                break
            end

            local players = collectPlayersInFixedRadius()
            for _, player in ipairs(players) do
                if not mainIni.settings.autotsradius then
                    break
                end
                sampSendChat("/plveh " .. player .. " " .. vehicleId)
                wait(mainIni.settings.delay)
            end

            if #players == 0 then
                wait(mainIni.settings.delay)
            end
        end

        autoTsRadiusThreadRunning = false
    end)
end

local function startAutoSpawnRadiusThread()
    if autoSpawnRadiusThreadRunning then
        return
    end

    local spawnedPlayers = {}
    autoSpawnRadiusThreadRunning = true
    lua_thread.create(function()
        while mainIni.settings.autospawnradius do
            local chars = getAllChars()
            local px, py, pz = getCharCoordinates(PLAYER_PED)
            local playersInRadius = {}

            for _, char in pairs(chars) do
                if not mainIni.settings.autospawnradius then
                    break
                end

                if char ~= PLAYER_PED then
                    local result, id = sampGetPlayerIdByCharHandle(char)
                    if result then
                        local nick = sampGetPlayerNickname(id)
                        local cx, cy, cz = getCharCoordinates(char)
                        local distance = getDistanceBetweenCoords3d(px, py, pz, cx, cy, cz)
                        if not isIgnored(nick) and distance <= FIXED_TS_RADIUS then
                            local inVehicle = isCharInAnyCar(char)
                            playersInRadius[id] = true

                            if inVehicle then
                                spawnedPlayers[id] = nil
                            elseif not spawnedPlayers[id] then
                                sampSendChat("/spplayer " .. id)
                                sampSendChat("/pm " .. id .. " 1 Вы были заспавнены с мероприятия за выход из ТС.")
                                spawnedPlayers[id] = true
                            end
                        end
                    end
                end
            end

            for id in pairs(spawnedPlayers) do
                if not playersInRadius[id] then
                    spawnedPlayers[id] = nil
                end
            end

            wait(0)
        end

        autoSpawnRadiusThreadRunning = false
    end)
end


function main ()
    ensureMailLogoAssets()
    sampRegisterChatCommand('mph', function () WinState[0] = not WinState[0] end)

    autotsradius[0] = false
    autospawnradius[0] = false
    mainIni.settings.autotsradius = false
    mainIni.settings.autospawnradius = false
    save_ini()
    scriptChatMessage("Подготовка к работе, пожалуйста, подождите..")
    scriptChatMessage("Открыть главное меню: " .. warncolor .. "/mph")
    scriptChatMessage("Разработчик скрипта: V.Harrison")
    while true do
        wait(0)
        imgui.Procces = true
    end
end
local page = 1

addEventHandler('onWindowMessage', function(msg, wparam, lparam)
    if wparam == 27 then
        if WinState[0] or eventConfigWindow[0] then
            if msg == wm.WM_KEYDOWN then
                consumeWindowMessage(true, false)
            end
            if msg == wm.WM_KEYUP then
                if eventConfigWindow[0] then
                    eventConfigWindow[0] = false
                elseif WinState[0] then
                    WinState[0] = false
                end
            end
        end
    end
end)

imgui.OnFrame(function() return WinState[0] end, function(player)
    tryLoadMailLogoTexture()
    local io = imgui.GetIO()
    local windowSize = imgui.ImVec2(590, 365)
    imgui.SetNextWindowPos(
        imgui.ImVec2(
            (io.DisplaySize.x - windowSize.x) * 0.5,
            (io.DisplaySize.y - windowSize.y) * 0.5
        ),
        imgui.Cond.Once
    )
    imgui.SetNextWindowSize(windowSize, imgui.Cond.Always)
    imgui.Begin(
        '##Window',
        WinState,
        imgui.WindowFlags.NoScrollbar
            + imgui.WindowFlags.NoScrollWithMouse
            + imgui.WindowFlags.NoResize
            + imgui.WindowFlags.NoCollapse
            + imgui.WindowFlags.NoTitleBar
            + imgui.WindowFlags.NoSavedSettings
    )

    imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(26, 12))
    if addons.HeaderButton(page == 1, u8("Основное")) then
        page = 1
    end
    imgui.SameLine(nil, 40)
    if addons.HeaderButton(page == 3, u8("Начало МП")) then
        page = 3
    end
    imgui.SameLine(nil, 40)
    if addons.HeaderButton(page == 4, u8("Конец МП")) then
        page = 4
    end
    imgui.SameLine(nil, 40)
    if addons.HeaderButton(page == 2, u8("Настройки")) then
        page = 2
    end
    imgui.PopStyleVar()
    imgui.SameLine()
    imgui.SetCursorPosX(557)
    imgui.SetCursorPosY(5)
    addons.CloseButton('##closemenu', WinState, 25, 5)

    if page == 1 then
        imgui.Separator()
    imgui.Columns(2,'tabledep',false)
    imgui.SetColumnWidth(0,290)
    local leftColumnStartX = imgui.GetCursorPosX()
    local leftColumnWidth = imgui.GetColumnWidth()
    local logoPosY = math.max(imgui.GetCursorPosY() - 20, 0)
    imgui.SetCursorPosY(logoPosY)
    local logoPosX = leftColumnStartX + math.max((leftColumnWidth - logoDrawSize.x) / 2, 0)
    imgui.SetCursorPosX(logoPosX)
    if mailLogoTexture then
        imgui.Image(mailLogoTexture, logoDrawSize)
    end
    imgui.SetCursorPosY(math.max(imgui.GetCursorPosY() - 30, 0))
    imgui.SetCursorPosY(math.max(imgui.GetCursorPosY() + 5, 0))
    if addons.ToggleButton(u8'Анти ТК',antitk) then
        mainIni.settings.antitk = antitk[0] save_ini()
    end
    if addons.ToggleButton(u8'Анти пополнение армора',antiarmour) then
        mainIni.settings.antiarmour = antiarmour[0] save_ini()
    end
    if addons.ToggleButton(u8'Анти пополнение здоровья',antihp) then
        mainIni.settings.antihp = antihp[0] save_ini()
    end
    if addons.ToggleButton(u8'Анти оружие из инвентаря',antigun) then
        mainIni.settings.antigun = antigun[0] save_ini()
    end
    if addons.ToggleButton(u8'Анти ДМ',antidm) then
        mainIni.settings.antidm = antidm[0] save_ini()
    end
    if addons.ToggleButton(u8'Авто выдача Т/С',autotsradius) then
        if autotsradius[0] then
            local vehicleId = u8:decode(str(IDT)):match("%d+")
            if not vehicleId or vehicleId == "" then
                autotsradius[0] = false
                mainIni.settings.autotsradius = false
                save_ini()
                scriptChatMessage("Укажите ID Т/С в поле \"ID Т/С для выдачи\".")
            else
                mainIni.settings.autotsradius = true
                save_ini()
                startAutoTsRadiusThread()
                scriptChatMessage("Автовыдача Т/С в радиусе включена.")
            end
        else
            mainIni.settings.autotsradius = false
            save_ini()
            scriptChatMessage("Автовыдача Т/С в радиусе выключена.")
        end
    end
    if addons.ToggleButton(u8'Авто Spawn',autospawnradius) then
        mainIni.settings.autospawnradius = autospawnradius[0]
        save_ini()
        if autospawnradius[0] then
            startAutoSpawnRadiusThread()
            scriptChatMessage("Авто Spawn игроков без Т/С в радиусе включен.")
        else
            scriptChatMessage("Авто Spawn игроков без Т/С в радиусе выключен.")
        end
    end
    local bottomTitleTop = u8("Event Helper")
    local bottomY = math.max(imgui.GetCursorPosY(), imgui.GetWindowHeight() - 30)
    imgui.SetCursorPosY(bottomY)
    imgui.SetCursorPosX(leftColumnStartX + math.max((leftColumnWidth - imgui.CalcTextSize(bottomTitleTop).x) / 2, 0))
    imgui.TextColored(imgui.ImVec4(0.92, 0.92, 0.92, 1.0), bottomTitleTop)

    imgui.NextColumn()
    imgui.SetCursorPosY(39)
    local rightColumnStartX = imgui.GetCursorPosX()
    local rightColumnWidth = imgui.GetColumnWidth()
    local itemSpacingX = imgui.GetStyle().ItemSpacing.x
    local radiusButtonSize = imgui.ImVec2(75, 27)
    local azakonButtonSize = imgui.ImVec2(240, 27)
    local radiusSliderWidth = 240
    local radiusButtonsRowWidth = radiusButtonSize.x * 3 + itemSpacingX * 2
    local radiusTitle = u8'Радиус действия'

    imgui.SetCursorPosX(rightColumnStartX + math.max((rightColumnWidth - imgui.CalcTextSize(radiusTitle).x) / 2, 0))
    imgui.Text(radiusTitle)
    imgui.SetCursorPosX(rightColumnStartX + math.max((rightColumnWidth - radiusSliderWidth) / 2, 0))
    imgui.PushItemWidth(radiusSliderWidth)
    if imgui.SliderInt(u8'##radius', radius, 0, 100) then
        mainIni.settings.radius = radius[0] save_ini()
    end
    imgui.PopItemWidth()
    imgui.SetCursorPosX(rightColumnStartX + math.max((rightColumnWidth - radiusButtonsRowWidth) / 2, 0))
    if addons.MaterialButton('HP', radiusButtonSize) then
        sampSendChat('/hpall '..radius[0])
    end
    imgui.SameLine()
    if addons.MaterialButton('Eat', radiusButtonSize) then
        sampSendChat('/eatall '..radius[0])
    end
    imgui.SameLine()
    if addons.MaterialButton('Weap', radiusButtonSize) then
        sampSendChat('/weapall '..radius[0])
    end
    imgui.SetCursorPosX(rightColumnStartX + math.max((rightColumnWidth - radiusButtonsRowWidth) / 2, 0))
    if addons.MaterialButton('Armour', radiusButtonSize) then
        sampSendChat('/Armourall '..radius[0])
    end
    imgui.SameLine()
    if addons.MaterialButton('UnArmour', radiusButtonSize) then
        sampSendChat('/unArmourall '..radius[0])
    end
    imgui.SameLine()
    if addons.MaterialButton('Cure', radiusButtonSize) then
        sampSendChat('/cureall '..radius[0])
    end
    imgui.SetCursorPosX(rightColumnStartX + math.max((rightColumnWidth - radiusButtonsRowWidth) / 2, 0))
    if addons.MaterialButton('Freeze', radiusButtonSize) then
        sampSendChat('/freezeall '..radius[0])
    end
    imgui.SameLine()
    if addons.MaterialButton('UnFreeze', radiusButtonSize) then
        sampSendChat('/unfreezeall '..radius[0])
    end
    imgui.SameLine()
    if addons.MaterialButton('SpPlayers', radiusButtonSize) then
        sampSendChat('/spplayers '..radius[0])
    end
    imgui.SetCursorPosX(rightColumnStartX + math.max((rightColumnWidth - azakonButtonSize.x) / 2, 0))
    if addons.MaterialButton('Azakon', azakonButtonSize) then
        sampSendChat('/azakon '..radius[0])
    end
    imgui.SetCursorPosX(rightColumnStartX + math.max((rightColumnWidth - radiusButtonsRowWidth) / 2, 0))
    if addons.MaterialButton('Repcar', radiusButtonSize) then
        sampSendChat('/Repcars '..radius[0])
    end
    imgui.SameLine()
    if addons.MaterialButton('SetFuel', radiusButtonSize) then
        setFuelAllInRadius(FIXED_TS_RADIUS, 100)
    end
    imgui.SameLine()
    if addons.MaterialButton('SpCars', radiusButtonSize) then
        sampSendChat('/spcars '..radius[0])
    end
    local giveInputWidth = 160
    local giveButtonSize = imgui.ImVec2(70, 27)
    local giveRowWidth = giveInputWidth + itemSpacingX + giveButtonSize.x

    imgui.SetCursorPosX(rightColumnStartX + math.max((rightColumnWidth - giveRowWidth) / 2, 0))
    imgui.PushItemWidth(giveInputWidth)
    imgui.InputTextWithHint(u8'##veh_ids', u8'ID Т/С для выдачи', IDT, 256)
    imgui.PopItemWidth()
    imgui.SameLine()
    if addons.MaterialButton(u8'Выдать', giveButtonSize) then
        local ids = u8:decode(str(IDT))

        if ids ~= "" then
            plvehall(ids)
        else
            scriptChatMessage("Введите ID транспорта!")
        end
    end
    imgui.SetCursorPosX(rightColumnStartX + math.max((rightColumnWidth - giveRowWidth) / 2, 0))
    imgui.PushItemWidth(giveInputWidth)
    imgui.InputTextWithHint(u8'##skin_id', u8'ID скина для выдачи', IDSK, 256)
    imgui.PopItemWidth()
    imgui.SameLine()
    if addons.MaterialButton(u8'Выдать ##2', giveButtonSize) then
        sampSendChat('/skinall ' .. radius[0] .. ' ' .. ffi.string(IDSK))
    end
    imgui.SetCursorPosX(rightColumnStartX + math.max((rightColumnWidth - giveRowWidth) / 2, 0))
    imgui.PushItemWidth(giveInputWidth)
    imgui.InputTextWithHint(u8'##gun_id', u8'ID гана для выдачи', IDG, 256)
    imgui.PopItemWidth()
    imgui.SameLine()
    if addons.MaterialButton(u8'Выдать ##3', giveButtonSize) then
        sampSendChat('/gunall ' .. radius[0] .. ' ' .. ffi.string(IDG).. ' ' ..tostring(pt[0]))
    end
    local columnsTop = imgui.GetCursorScreenPos().y - imgui.GetCursorPosY()
    local windowPos = imgui.GetWindowPos()
    local separatorX = windowPos.x + 290
    imgui.GetWindowDrawList():AddLine(
        imgui.ImVec2(separatorX, columnsTop),
        imgui.ImVec2(separatorX, columnsTop + imgui.GetWindowHeight() - 40),
        imgui.GetColorU32(imgui.Col.Border),
        1.0
    )
end
if page == 2 then
    imgui.Separator()
    imgui.Text(u8'Ники игроков которым не нужно выдавать Т/С')
    imgui.PushItemWidth(200)
    imgui.InputTextWithHint(u8'##ignore_nick', u8'Vladimir_Harrison', ignor, 256)
    imgui.SameLine()
    if addons.AnimButton(u8'Добавить') then
        local nick = u8:decode(str(ignor))

        if nick ~= "" then
            table.insert(ignorList, nick)
            save_ignore()
            ffi.copy(ignor, "")
        end
    end
    imgui.Text(u8'Задержка выдачи Т/С в мс')
    if imgui.SliderInt(u8'##radius', delay, 0, 10000) then
        mainIni.settings.delay = delay[0] save_ini()
    end
    imgui.Text(u8'Кол-во патронов для выдачи')
    if imgui.InputInt(u8'##ammo_count', pt, 0, 0, imgui.InputTextFlags.CharsDecimal) then
        mainIni.settings.pt = pt[0] save_ini()
    end

end
if page == 3 then
    imgui.Separator()
    imgui.Columns(2, 'mpstart', true)
    imgui.SetColumnWidth(0,125)
    -- 1 колонка (тип /ao)

    imgui.RadioButtonIntPtr('##type_0', mp.type, 0)
    imgui.SameLine()
    imgui.Text(u8'Короткое /ao')


    imgui.RadioButtonIntPtr('##type_1', mp.type, 1)
    imgui.SameLine()
    imgui.Text(u8'Длинное /ao')
    imgui.NextColumn()

    -- 2 колонка (данные)

    imgui.PushItemWidth(-1)
    imgui.InputTextWithHint('##name', u8'Название МП', mp.name, 256)
    imgui.InputTextWithHint('##prize', u8'Приз за МП', mp.priz, 256)
    imgui.PopItemWidth()

    imgui.Spacing()
    imgui.Spacing()



    imgui.Columns(1)

    -- 3 блок (результат)
    imgui.Separator()
    local formattedPrize = formatPrize(u8:decode(str(mp.priz)))
    imgui.StrCopy(mp.result,
        u8(mp.type[0] == 0 and
        '/ao [Event] Проходит МП "'..u8:decode(str(mp.name))..'". Приз: "'..formattedPrize..'" Для участия вводите /gotp' or
        '/ao [Event] Уважаемые игроки, сейчас пройдет мероприятие "'..u8:decode(str(mp.name))..'"\n/ao [Event] Приз: "'..formattedPrize..'"\n/ao [Event] Прописывайте /gotp и присоединяйтесь к мероприятию')
    )

    imgui.InputTextMultiline('##result', mp.result, sizeof(mp.result), imgui.ImVec2(-1, 70), imgui.InputTextFlags.ReadOnly)
    imgui.Separator()
    if addons.AnimButton(u8'Настройка мероприятия') then
        eventConfigWindow[0] = true
    end
    imgui.Spacing()
    if addons.AnimButton(u8'Отправить /ao') then
        local text = u8:decode(str(mp.result))

        lua_thread.create(function()
            for line in text:gmatch('[^\n]+') do
                sampSendChat(line)
                wait(1100)
            end
        end)
        startEventAutomation("apply_and_start")
    end
end
if page == 4 then
imgui.Separator()
imgui.Text(u8'ID Победителя')
imgui.PushItemWidth(90)
imgui.InputInt('##winner_id', mp.winner, 0, 0, imgui.InputTextFlags.CharsDecimal)
imgui.Separator()
imgui.StrCopy(mp.result_end, u8(
    '/ao [Event] Победитель мероприятия "'..u8:decode(str(mp.name))..'" - '..
    (sampIsPlayerConnected(mp.winner[0]) and (sampGetPlayerNickname(mp.winner[0])..'['..mp.winner[0]..']') or 'Игрок не найден!')..
    '. Поздравляем!'
))

imgui.InputTextMultiline('##result_end', mp.result_end, 512, imgui.ImVec2(565, 70), imgui.InputTextFlags.ReadOnly)
imgui.Separator()
if addons.AnimButton(u8'Отправить итог /ao') then
    if sampIsPlayerConnected(mp.winner[0]) then
        lua_thread.create(function()
            local text = u8:decode(ffi.string(mp.result_end))
            for line in text:gmatch('[^\n]+') do
                sampSendChat(line)
                wait(1100)
            end

            sendMpResultToServer()
            disableMainProtectionToggles()
        end)
    else
        scriptChatMessage("Игрок не найден!")
    end
end
end

end)

imgui.OnFrame(function() return eventConfigWindow[0] end, function()
    imgui.SetNextWindowSize(imgui.ImVec2(430, 420), imgui.Cond.FirstUseEver)
    imgui.Begin(u8'Настройка мероприятия', eventConfigWindow, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)

    imgui.Text(u8'Номер слота МП')
    imgui.PushItemWidth(80)
    if imgui.InputTextWithHint(u8'##event_slot_id', u8'0-29', eventSlotIdText, 8, imgui.InputTextFlags.CharsDecimal) then
        eventAutomation.active = false
    end
    imgui.PopItemWidth()
    imgui.SameLine()
    if addons.MaterialButton(u8'+', imgui.ImVec2(28, 24)) then
        local slotId = getEventSlotId() or 0
        slotId = math.min(29, slotId + 1)
        imgui.StrCopy(eventSlotIdText, tostring(slotId))
        eventAutomation.active = false
    end
    imgui.SameLine()
    if addons.MaterialButton(u8'-', imgui.ImVec2(28, 24)) then
        local slotId = getEventSlotId() or 0
        slotId = math.max(0, slotId - 1)
        imgui.StrCopy(eventSlotIdText, tostring(slotId))
        eventAutomation.active = false
    end

    if addons.MaterialButton(u8'Позиция спавна', imgui.ImVec2(170, 26)) then
        startEventAutomation("set_spawn")
    end
    imgui.SetCursorPosY(imgui.GetCursorPosY() + 3)
    imgui.TextColored(eventSpawnStatusColor, eventSpawnStatusText)

    imgui.PushItemWidth(120)
    imgui.InputInt(u8'Лимит игроков', eventPlayerLimit, 0, 0)
    imgui.InputInt(u8'Время действия телепорта', eventTeleportTime, 0, 0)
    imgui.InputTextWithHint(u8'##event_password', u8'Пароль', eventPassword, 32)
    imgui.SameLine()
    imgui.Text(u8'Пароль для входа')
    imgui.InputInt(u8'Выдать здоровье', eventHp, 0, 0)
    imgui.InputInt(u8'Выдать бронь', eventArmour, 0, 0)
    imgui.InputInt(u8'Выдать скин', eventSkin, 0, 0)
    imgui.PopItemWidth()

    imgui.Checkbox(u8'Повторный телепорт', eventRepeatTp)
    imgui.Checkbox(u8'Нанесение урона другим игрокам', eventAllowDamage)
    imgui.Checkbox(u8'Эффект от аксессуаров', eventAccessoryEffect)
    imgui.Checkbox(u8'Охранники', eventGuards)
    imgui.Checkbox(u8'Коллизия игроков', eventPlayerCollision)

    imgui.Separator()
    if addons.MaterialButton(u8'Применить настройки', imgui.ImVec2(190, 28)) then
        startEventAutomation("apply")
    end

    imgui.End()
end)

function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    local decodedTitle = normalizeDialogText(title)
    local now = os.clock()
    local dialogIsEvent = isEventAutomationDialog(title, text)

    if eventAutomation.active and dialogIsEvent then
        hiddenEventDialogsUntil[dialogId] = now + 10
    end

    if hiddenEventDialogsUntil[dialogId] and hiddenEventDialogsUntil[dialogId] < now then
        hiddenEventDialogsUntil[dialogId] = nil
    end

    if not eventAutomation.active and hiddenEventDialogsUntil[dialogId] then
        return false
    end

    if now < hideSpawnDialogsUntil and not eventAutomation.active then
        return false
    end

    if not eventAutomation.active then
        return
    end

    local decodedText = normalizeDialogText(text)
    local decodedButton1 = normalizeDialogText(button1)

    if eventAutomation.stage == "select_slot" and decodedTitle:find("РЕДАКТИРОВАН", 1, true) and decodedTitle:find("МЕРОПРИЯТ", 1, true) then
        eventAutomation.stage = "edit_menu"
    end

    if eventAutomation.stage == "select_slot" and (style == 2 or style == 4 or style == 5) then
        local slotLine = resolveDialogLineBySlot(text, eventAutomation.slot)
        sampSendDialogResponse(dialogId, 1, slotLine, "")
        eventAutomation.stage = "edit_menu"
        return false
    end

    if decodedTitle:find("СПИСОК", 1, true) and decodedTitle:find("МЕРОПРИЯТ", 1, true) then
        local slotLine = resolveDialogLineBySlot(text, eventAutomation.slot)
        sampSendDialogResponse(dialogId, 1, slotLine, "")
        eventAutomation.stage = "edit_menu"
        return false
    end

    if eventAutomation.mode == "set_spawn" then
        local isListStyle = (style == 2 or style == 4 or style == 5)

        if eventAutomation.stage == "edit_menu" and isListStyle then
            local spawnManageLine = resolveDialogLineByAliases(text, { "ПОЗИЦИИ СПАВНА", "ПОЗИЦИЯ СПАВНА", "СПАВН" }, EVENT_MENU_INDEX.SPAWN_POS)
            sampSendDialogResponse(dialogId, 1, spawnManageLine, "")
            eventAutomation.stage = "spawn_manage"
            return false
        end

        if eventAutomation.stage == "spawn_manage" then
            local editPosLine = resolveDialogLineByKeywords(text, { "РЕДАКТИРОВАТЬ", "ПОЗИЦ" }, 2)
            sampSendDialogResponse(dialogId, 1, editPosLine, "")
            eventAutomation.stage = "spawn_pick_slot"
            return false
        end

        if eventAutomation.stage == "spawn_pick_slot" and isListStyle then
            local spawnSlotLine = resolveDialogLineBySlot(text, 1)
            sampSendDialogResponse(dialogId, 1, spawnSlotLine, "")
            eventSpawnApplied = true
            eventSpawnStatusText = u8("Позиция: Установлена")
            eventSpawnStatusColor = imgui.ImVec4(0.20, 0.85, 0.30, 1.0)
            eventAutomation.active = false
            hideSpawnDialogsUntil = os.clock() + 5
            if not eventSpawnMessageSent then
                eventSpawnMessageSent = true
                scriptChatMessage("Позиция спавна успешно установлена.")
            end
            return false
        end
    end

    if eventAutomation.mode == "set_spawn" then
        return false
    end

    if eventAutomation.pendingInput ~= nil and (style == 1 or decodedButton1:find("ИЗМЕНИТЬ", 1, true) or decodedButton1:find("ЗАМЕНИТЬ", 1, true)) then
        local value = eventAutomation.pendingInput
        eventAutomation.pendingInput = nil
        sampSendDialogResponse(dialogId, 1, 0, value)
        return false
    end

    local isEditDialog = decodedTitle:find("РЕДАКТИРОВАН", 1, true) and decodedTitle:find("МЕРОПРИЯТ", 1, true)
    local isListStyle = (style == 2 or style == 4 or style == 5)

    local isRulesMenuDialog = eventAutomation.inRulesMenu and isListStyle

    if eventAutomation.mode == "load" then
        if not ((eventAutomation.stage == "edit_menu" and isListStyle and not decodedTitle:find("СПИСОК", 1, true)) or isEditDialog) then
            return false
        end
    else
        if isRulesMenuDialog then
        elseif eventAutomation.stage == "edit_menu" and isListStyle and not decodedTitle:find("СПИСОК", 1, true) then
        elseif not isEditDialog then
            return false
        end
    end

    if eventAutomation.mode == "load" then
        eventPlayerLimit[0] = parseFieldNumberByAliases(text, { "ЛИМИТ ИГРОКОВ" }, eventPlayerLimit[0])
        eventTeleportTime[0] = parseFieldNumberByAliases(text, { "ВРЕМЯ ДЕЙСТВИЯ ТЕЛЕПОРТА", "ВРЕМЯ ТЕЛЕПОРТА" }, eventTeleportTime[0])
        eventHp[0] = parseFieldNumberByAliases(text, { "ВЫДАТЬ ЗДОРОВЬЕ", "ЗДОРОВЬЕ" }, eventHp[0])
        eventArmour[0] = parseFieldNumberByAliases(text, { "ВЫДАТЬ БРОНЮ", "ВЫДАТЬ БРОНЬ", "БРОНЯ", "БРОНЬ" }, eventArmour[0])
        eventSkin[0] = parseFieldNumberByAliases(text, { "ВЫДАТЬ СКИН", "СКИН" }, eventSkin[0])
        local loadedPassword = parseFieldValue(text, "ПАРОЛЬ")
        if loadedPassword ~= "" then
            imgui.StrCopy(eventPassword, loadedPassword:gsub("%s+", ""))
        else
            imgui.StrCopy(eventPassword, "0")
        end
        do
            local parsed = parseFieldBoolByAliases(text, { "ПОВТОРНЫЙ ТЕЛЕПОРТ" }, nil)
            if parsed ~= nil then
                eventRepeatTp[0] = parsed
            end
        end
        do
            local parsed = parseDamageAllowed(text, nil)
            if parsed ~= nil then
                eventAllowDamage[0] = parsed
            end
        end
        do
            local parsed = parseFieldBoolByAliases(text, { "ЭФФЕКТЫ ОТ АКСЕССУАРОВ", "ЭФФЕКТ ОТ АКСЕССУАРОВ", "ЭФФЕКТ ОТ АКСЕССУАРОН" }, nil)
            if parsed ~= nil then
                eventAccessoryEffect[0] = parsed
            end
        end
        do
            local parsed = parseFieldBoolByAliases(text, { "ОХРАННИКИ" }, nil)
            if parsed ~= nil then
                eventGuards[0] = parsed
            end
        end
        do
            local parsed = parseFieldBoolByAliases(text, { "КОЛЛИЗИЯ ИГРОКОВ" }, nil)
            if parsed ~= nil then
                eventPlayerCollision[0] = parsed
            end
        end
        eventAutomation.active = false
        sampSendDialogResponse(dialogId, 0, 0, "")
        return false
    end

    if eventAutomation.mode == "apply" or eventAutomation.mode == "apply_and_start" then
        if #eventAutomation.valueSteps == 0 then
            local messageText = 'Проходит МП "' .. u8:decode(str(mp.name)) .. '". Приз: "' .. formatPrize(u8:decode(str(mp.priz))) .. '". Для участия вводите /gotp'
            eventAutomation.valueSteps = {
                { name = "СООБЩЕНИЕ НА ВЕСЬ СЕРВЕР", index = EVENT_MENU_INDEX.BROADCAST, input = messageText },
                { name = "ЛИМИТ ИГРОКОВ", index = EVENT_MENU_INDEX.PLAYER_LIMIT, input = tostring(eventPlayerLimit[0]) },
                { name = "ВРЕМЯ ДЕЙСТВИЯ ТЕЛЕПОРТА", index = EVENT_MENU_INDEX.TELEPORT_TIME, input = tostring(eventTeleportTime[0]) },
                { name = "ПАРОЛЬ ДЛЯ ВХОДА", index = EVENT_MENU_INDEX.PASSWORD, input = u8:decode(str(eventPassword)) ~= "" and u8:decode(str(eventPassword)) or "0" },
                { name = "ВЫДАТЬ ЗДОРОВЬЕ", index = EVENT_MENU_INDEX.HP, input = tostring(eventHp[0]) },
                { name = "ВЫДАТЬ БРОНЮ", index = EVENT_MENU_INDEX.ARMOUR, input = tostring(eventArmour[0]) },
                { name = "ВЫДАТЬ СКИН", index = EVENT_MENU_INDEX.SKIN, input = tostring(eventSkin[0]) }
            }
            eventAutomation.toggleSteps = {
                { index = RULES_MENU_INDEX.REPEAT_TP, name = "ПОВТОРНЫЙ ТЕЛЕПОРТ", aliases = { "ПОВТОРНЫЙ ТЕЛЕПОРТ", "ПОВТОР ТЕЛЕПОРТА" }, target = eventRepeatTp[0] },
                { index = RULES_MENU_INDEX.DAMAGE_PLAYERS, name = "НАНЕСЕНИЕ УРОНА ДРУГИМ ИГРОКАМ", aliases = { "НАНЕСЕНИЕ УРОНА ДРУГИМ ИГРОКАМ", "УРОН ДРУГИМ ИГРОКАМ", "ЗАПРЕТ УРОНА ПО ИГРОКАМ" }, parser = parseDamageAllowed, target = eventAllowDamage[0] },
                { index = RULES_MENU_INDEX.ACCESSORY_EFFECT, name = "ЭФФЕКТЫ ОТ АКСЕССУАРОВ", aliases = { "ЭФФЕКТЫ ОТ АКСЕССУАРОВ", "ЭФФЕКТ ОТ АКСЕССУАРОВ" }, target = eventAccessoryEffect[0] },
                { index = RULES_MENU_INDEX.GUARDS, name = "ОХРАННИКИ", aliases = { "ОХРАННИКИ" }, target = eventGuards[0] },
                { index = RULES_MENU_INDEX.PLAYER_COLLISION, name = "КОЛЛИЗИЯ ИГРОКОВ", aliases = { "КОЛЛИЗИЯ ИГРОКОВ", "КОЛЛИЗИЯ" }, target = eventPlayerCollision[0] }
            }
        end

        if eventAutomation.valueStep <= #eventAutomation.valueSteps then
            local step = eventAutomation.valueSteps[eventAutomation.valueStep]
            eventAutomation.valueStep = eventAutomation.valueStep + 1
            eventAutomation.pendingInput = step.input
            sampSendDialogResponse(dialogId, 1, step.index, "")
            return false
        end

        if not eventAutomation.inRulesMenu then
            eventAutomation.inRulesMenu = true
            sampSendDialogResponse(dialogId, 1, EVENT_MENU_INDEX.RULES_MENU, "")
            return false
        end

        local toggleClicks = {}
        for _, step in ipairs(eventAutomation.toggleSteps) do
            local rowIndex = step.index
            local rowByAlias = resolveDialogLineByAliases(text, step.aliases or {}, nil)
            if rowByAlias ~= nil then
                rowIndex = rowByAlias
            end

            local currentValue = nil
            if step.parser then
                currentValue = step.parser(text, nil)
            end
            if currentValue == nil and step.aliases then
                currentValue = parseFieldBoolByAliases(text, step.aliases, nil)
            end
            if currentValue == nil then
                currentValue = parseFieldBoolByRowIndex(text, rowIndex, nil)
            end
            if currentValue ~= nil and currentValue ~= step.target then
                table.insert(toggleClicks, rowIndex)
            end
        end

        local needStartEvent = eventAutomation.startAfterSave
        eventAutomation.active = false
        eventAutomation.valueSteps = {}
        eventAutomation.toggleSteps = {}
        eventAutomation.valueStep = 1
        eventAutomation.toggleStep = 1
        eventAutomation.inRulesMenu = false

        lua_thread.create(function()
            for _, rowIndex in ipairs(toggleClicks) do
                sampSendDialogResponse(dialogId, 1, rowIndex, "")
                wait(120)
            end
            if needStartEvent then
                sampSendDialogResponse(dialogId, 1, RULES_MENU_INDEX.START_EVENT, "")
            end
            scriptChatMessage("Настройки успешно применены.")
        end)
        return false
    end

    return false
end



function sampev.onBulletSync(playerId, data)
    if mainIni.settings.antidm then
        sampSendChat("/spplayer "..playerId)
        printStringNow("DM "..sampGetPlayerNickname(playerId), 2000)
        sampSendChat("/pm "..playerId.." 1 Запрещено использовать оружие на мероприятии!")
        sampSendChat('/weap '..playerId.." Нарушение Правил МП")
    end

    if mainIni.settings.antitk then
        local result1, handle1 = sampGetCharHandleBySampPlayerId(playerId);
        local result2, handle2 = sampGetCharHandleBySampPlayerId(data.targetId);
        if (data.targetId == select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))) then result2 = true; handle2 = PLAYER_PED; end
        if result1 and result2 then
            local skin1, skin2 = getCharModel(handle1), getCharModel(handle2)
            if (skin1 == skin2) then
                if not tkInfo[playerId] then tkInfo[playerId] = 1; else tkInfo[playerId] = tkInfo[playerId] + 1; end;

                if (tkInfo[playerId] >= 3) then
                    scriptChatMessage('WARNING >> {FFFFFF}Игрок '..sampGetPlayerNickname(playerId)..'['..playerId..'] был замечен в {FF0000}TeamKill {FFFFFF}уже {FF0000}'..tkInfo[playerId]..' раз!!')
                    if (tkInfo[playerId] == 5) then
                        lua_thread.create(function()
                            scriptChatMessage('WARNING >> {FFFFFF}Игрок '..sampGetPlayerNickname(playerId)..'['..playerId..'] совершил {FF0000}TeamKill 5 раз{FFFFFF} и был наказан!!')
                            wait(0)
                            sampSendChat('/spplayer '..playerId)
                            wait(0)
                            sampSendChat('/pm '..playerId..' 1 Вы были заспавнены за ТК!')
                        end)
                        tkInfo[playerId] = 0;
                    end
                end
            end
        end
    end
end

local function punishHealViolation(id)
    sampSendChat("/spplayer "..id)
    printStringNow("HEAL "..sampGetPlayerNickname(id), 2000)
    sampSendChat("/pm "..id.." 1 Запрещено пополнять здоровье на мероприятии!")
    sampSendChat('/weap '..id.." Нарушение Правил МП")
end

function sampev.onApplyPlayerAnimation(id, animname, frameDelta, loop, lockx, locky, freeze, time)
    if mainIni.settings.antihp then
        if (animname == "ped" and frameDelta == "gum_eat") or (animname == "FOOD" and frameDelta == "EAT_Burger") or (animname == "SMOKING" and frameDelta == "M_smk_drag") then
            punishHealViolation(id)
        end
    end
    if animname == "goggles" and frameDelta == "goggles_put_on" and mainIni.settings.antiarmour then
        sampSendChat("/spplayer "..id)
        printStringNow("ARMOUR SPAWN "..sampGetPlayerNickname(id), 2000)
        sampSendChat("/pm "..id.." 1 Запрещено пополнять броню на мероприятии!")
        sampSendChat('/weap '..id.." Нарушение Правил МП")
    end
end

local function findPlayerIdByNickname(nickname)
    for id = 0, 1003 do
        if sampIsPlayerConnected(id) and sampGetPlayerNickname(id) == nickname then
            return id
        end
    end
end

local function getPlayerIdFromChatMessage(text)
    local nickname = text:match('^([%w_]+) выпил%(а%) бутылку пива$')

    if nickname == nil then
        return nil
    end

    return findPlayerIdByNickname(nickname)
end

function sampev.onServerMessage(color, text)
    if mainIni.settings.antihp and text:find("выпил%(а%) бутылку пива") then
        local id = getPlayerIdFromChatMessage(text)
        if id ~= nil then
            punishHealViolation(id)
        end
    end
end

function sampev.onPlayerChatBubble(id, col, dist, dur, msg)
    if msg:find("Достал%(а%) оружие из кармана") and mainIni.settings.antigun then
        lua_thread.create(function()
            sampSendChat('/weap '..id.." Нарушение Правил МП")
            wait(500)
            sampSendChat("/pm "..id.." 1 Запрещено брать оружие на МП из инвентаря")
        end)
    end
end

function imgui.VerticalSeparator()
    local draw_list = imgui.GetWindowDrawList()
    local pos = imgui.GetCursorScreenPos()
    local window_height = imgui.GetWindowHeight()
    local separator_x = pos.x
    local separator_color = imgui.GetColorU32(imgui.Col.Border)

    draw_list:AddLine(
        {separator_x, pos.y},
        {separator_x, pos.y + window_height},
        separator_color,
        1.0
    )
    imgui.Dummy({0, window_height})
end

function save_ini()
    inicfg.save(mainIni, directIni)
end

imgui.OnInitialize(function()
    GlassTheme()
end)

function GlassTheme()
    imgui.SwitchContext()
    local style = imgui.GetStyle()

    -- Основные параметры
    style.WindowPadding = imgui.ImVec2(12, 12)
    style.WindowRounding = 10.0
    style.ChildRounding = 8.0
    style.FramePadding = imgui.ImVec2(8, 6)
    style.FrameRounding = 8.0
    style.ItemSpacing = imgui.ImVec2(8, 6)
    style.ItemInnerSpacing = imgui.ImVec2(6, 5)
    style.ScrollbarSize = 12.0
    style.ScrollbarRounding = 10.0
    style.GrabMinSize = 8.0
    style.GrabRounding = 6.0
    style.PopupRounding = 8.0

    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)

    -- Прозрачность интерфейса (общая альфа)
    style.Alpha = 0.92

    -- Цвета (glass + темная тема)
    local c = style.Colors

    c[imgui.Col.Text]                   = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
    c[imgui.Col.TextDisabled]           = imgui.ImVec4(0.70, 0.70, 0.70, 1.00)

    c[imgui.Col.WindowBg]               = imgui.ImVec4(0.08, 0.08, 0.10, 1.00)
    c[imgui.Col.ChildBg]                = imgui.ImVec4(0.10, 0.10, 0.12, 0.98)
    c[imgui.Col.PopupBg]                = imgui.ImVec4(0.10, 0.10, 0.12, 1.00)

    c[imgui.Col.Border]                 = imgui.ImVec4(1.00, 1.00, 1.00, 0.08)
    c[imgui.Col.BorderShadow]           = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)

    c[imgui.Col.FrameBg]                = imgui.ImVec4(0.15, 0.15, 0.18, 0.98)
    c[imgui.Col.FrameBgHovered]         = imgui.ImVec4(0.20, 0.20, 0.25, 1.00)
    c[imgui.Col.FrameBgActive]          = imgui.ImVec4(0.25, 0.25, 0.30, 1.00)

    -- Акценты (голубой цвет темы)
    c[imgui.Col.CheckMark]              = imgui.ImVec4(0.30, 0.80, 1.00, 1.00)
    c[imgui.Col.SliderGrab]             = imgui.ImVec4(0.30, 0.80, 1.00, 0.9)
    c[imgui.Col.SliderGrabActive]       = imgui.ImVec4(0.40, 0.90, 1.00, 1.0)

    c[imgui.Col.Button]                 = imgui.ImVec4(0.15, 0.15, 0.20, 0.90)
    c[imgui.Col.ButtonHovered]          = imgui.ImVec4(0.25, 0.25, 0.30, 1.00)
    c[imgui.Col.ButtonActive]           = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)

    c[imgui.Col.Header]                 = imgui.ImVec4(0.18, 0.18, 0.22, 0.85)
    c[imgui.Col.HeaderHovered]          = imgui.ImVec4(0.25, 0.25, 0.30, 0.95)
    c[imgui.Col.HeaderActive]           = imgui.ImVec4(0.30, 0.30, 0.35, 1.00)

    c[imgui.Col.TitleBg]                = imgui.ImVec4(0.10, 0.10, 0.12, 0.95)
    c[imgui.Col.TitleBgActive]          = imgui.ImVec4(0.12, 0.12, 0.15, 1.00)
    c[imgui.Col.TitleBgCollapsed]       = imgui.ImVec4(0.10, 0.10, 0.12, 0.75)

    c[imgui.Col.ScrollbarBg]            = imgui.ImVec4(0.05, 0.05, 0.07, 0.50)
    c[imgui.Col.ScrollbarGrab]          = imgui.ImVec4(0.20, 0.20, 0.25, 0.80)
    c[imgui.Col.ScrollbarGrabHovered]   = imgui.ImVec4(0.30, 0.30, 0.35, 0.90)
    c[imgui.Col.ScrollbarGrabActive]    = imgui.ImVec4(0.40, 0.40, 0.45, 1.00)

    c[imgui.Col.Separator]              = imgui.ImVec4(1.00, 1.00, 1.00, 0.08)
    c[imgui.Col.SeparatorHovered]       = imgui.ImVec4(0.30, 0.80, 1.00, 0.8)
    c[imgui.Col.SeparatorActive]        = imgui.ImVec4(0.30, 0.80, 1.00, 1.0)

    c[imgui.Col.ResizeGrip]             = imgui.ImVec4(0.30, 0.80, 1.00, 0.25)
    c[imgui.Col.ResizeGripHovered]      = imgui.ImVec4(0.30, 0.80, 1.00, 0.6)
    c[imgui.Col.ResizeGripActive]       = imgui.ImVec4(0.30, 0.80, 1.00, 0.9)

    c[imgui.Col.ModalWindowDimBg]       = imgui.ImVec4(0.00, 0.00, 0.00, 0.55)

    c[imgui.Col.TextSelectedBg]         = imgui.ImVec4(0.30, 0.80, 1.00, 0.25)

    -- Вкладки
    c[imgui.Col.Tab]                    = imgui.ImVec4(0.15, 0.15, 0.20, 0.85)
    c[imgui.Col.TabHovered]             = imgui.ImVec4(0.30, 0.80, 1.00, 0.6)
    c[imgui.Col.TabActive]              = imgui.ImVec4(0.30, 0.80, 1.00, 0.9)
end
