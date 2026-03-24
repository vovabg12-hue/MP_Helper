local imgui = require 'mimgui'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
require "lib.moonloader"
imgui.HotKey = require("imgui_addons").HotKey
local wm = require("windows.message")
local sampev = require "samp.events"
local ffi = require 'ffi'
local inicfg = require "inicfg"
local directIni = "MPHelper.ini"
local addons = require "ADDONS"
local str = ffi.string
local sizeof = ffi.sizeof
local json = require "json" -- Нужен для decodeJson/encodeJson и хранения списка игнора
local mailLogoTexture = nil
local mailLogoPath = nil
local logoLoadTried = false
local logoDrawSize = imgui.ImVec2(290, 124)

ffi.cdef[[
typedef void* HANDLE;
typedef HANDLE HGLOBAL;
typedef void* HWND;
typedef unsigned int UINT;
typedef unsigned long DWORD;
typedef int BOOL;
typedef unsigned long SIZE_T;
HANDLE GlobalAlloc(UINT uFlags, SIZE_T dwBytes);
void* GlobalLock(HGLOBAL hMem);
BOOL GlobalUnlock(HGLOBAL hMem);
HANDLE SetClipboardData(UINT uFormat, HANDLE hMem);
BOOL OpenClipboard(HWND hWndNewOwner);
BOOL CloseClipboard(void);
BOOL EmptyClipboard(void);
int MultiByteToWideChar(UINT CodePage, DWORD dwFlags, const char* lpMultiByteStr, int cbMultiByte, wchar_t* lpWideCharStr, int cchWideChar);
]]

local CF_UNICODETEXT = 13
local CP_UTF8 = 65001
local GMEM_MOVEABLE = 0x0002

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
        sampAddChatMessage("Введите ID транспорта!", -1)
        return
    end

    local chars = getAllChars()
    local players = {}

    for _, char in pairs(chars) do
        local result, id = sampGetPlayerIdByCharHandle(char)

        if result then
            local nick = sampGetPlayerNickname(id)

            if not isIgnored(nick) then
                table.insert(players, id)
            end
        end
    end

    sampAddChatMessage("Найдено игроков: "..#players, -1)

    lua_thread.create(function()
        for _, player in pairs(players) do
            local res, ped = sampGetCharHandleBySampPlayerId(player)

            if res and isCharOnFoot(ped) then
                sampSendChat("/plveh "..player.." "..table.random(clist))
                wait(mainIni.settings.delay)
            end
        end
        sampAddChatMessage("Т/С выданы всем игрокам!", -1)
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
local tkInfo = {};


local tag = "[ MPHelper ] "
local tagcolor = 0xCC4545
local textcolor = "{FFFFFF}"
local warncolor = "{FFFFFF}"
local WinState = imgui.new.bool()

local function formatPrize(prizeText)
    local digits = tostring(prizeText or ""):gsub("%D", "")

    if digits == "" then
        return "00,000,000"
    end

    while #digits < 8 do
        digits = "0" .. digits
    end

    if #digits == 8 then
        return digits:sub(1, 2) .. "," .. digits:sub(3, 5) .. "," .. digits:sub(6, 8)
    end

    local parts = {}
    while #digits > 3 do
        table.insert(parts, 1, digits:sub(-3))
        digits = digits:sub(1, -4)
    end
    table.insert(parts, 1, digits)

    return table.concat(parts, ",")
end

local function setClipboardText(text)
    local utf8Text = tostring(text or "")
    local wideSize = ffi.C.MultiByteToWideChar(CP_UTF8, 0, utf8Text, #utf8Text, ffi.NULL, 0)

    if wideSize <= 0 then
        return false
    end

    local wideBuffer = ffi.new("wchar_t[?]", wideSize + 1)
    ffi.C.MultiByteToWideChar(CP_UTF8, 0, utf8Text, #utf8Text, wideBuffer, wideSize)
    wideBuffer[wideSize] = 0

    local memSize = ffi.sizeof("wchar_t") * (wideSize + 1)
    local memory = ffi.C.GlobalAlloc(GMEM_MOVEABLE, memSize)

    if memory == nil or memory == ffi.NULL then
        return false
    end

    local locked = ffi.C.GlobalLock(memory)
    if locked == nil or locked == ffi.NULL then
        return false
    end

    ffi.copy(locked, wideBuffer, memSize)
    ffi.C.GlobalUnlock(memory)

    if ffi.C.OpenClipboard(ffi.NULL) == 0 then
        return false
    end

    ffi.C.EmptyClipboard()
    local result = ffi.C.SetClipboardData(CF_UNICODETEXT, memory)
    ffi.C.CloseClipboard()

    return result ~= nil
end

local function buildWinnerClipboardText()
    local winnerNick = sampIsPlayerConnected(mp.winner[0]) and sampGetPlayerNickname(mp.winner[0]) or "Неизвестно"
    local mpName = u8:decode(str(mp.name))
    local prize = formatPrize(u8:decode(str(mp.priz)))

    return table.concat({
        winnerNick,
        mpName ~= "" and mpName or "Без названия",
        prize
    }, "\n")
end


function main ()
    ensureMailLogoAssets()
    sampRegisterChatCommand('mph', function () WinState[0] = not WinState[0] end)
    
    sampAddChatMessage(tag .. textcolor .. "Подготовка к работе, пожалуйста, подождите..", tagcolor)
    sampAddChatMessage(tag .. textcolor .. "Открыть главное меню: " .. warncolor .. "/mph", tagcolor)
    while true do
        wait(0)
        imgui.Procces = true
    end
end
local page = 1

addEventHandler('onWindowMessage', function(msg, wparam, lparam)
    if wparam == 27 then
        if WinState[0] then
            if msg == wm.WM_KEYDOWN then
                consumeWindowMessage(true, false)
            end
            if msg == wm.WM_KEYUP then
                WinState[0] = false
            end
        end
    end
end)

imgui.OnFrame(function() return WinState[0] end, function(player)
    tryLoadMailLogoTexture()
    imgui.SetNextWindowPos(imgui.ImVec2(500,500), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(590, 343), imgui.Cond.Always)
    imgui.Begin('##Window', WinState, imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar)

    imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(26, 12))
    imgui.SetWindowFontScale(1.15)
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
    imgui.SetWindowFontScale(1.0)
    imgui.PopStyleVar()

    imgui.SameLine()
    imgui.SetCursorPosX(557)
    imgui.SetCursorPosY(5)
    addons.CloseButton('##closemenu', WinState, 25, 5)

    if page == 1 then
        imgui.Separator()
    imgui.Columns(2,'tabledep',true)
    imgui.SetColumnWidth(0,290)
    local leftColumnStartX = imgui.GetCursorPosX()
    local leftColumnWidth = imgui.GetColumnWidth()
    local logoPosY = math.max(imgui.GetCursorPosY() - 35, 0)
    imgui.SetCursorPosY(logoPosY)
    local logoPosX = leftColumnStartX + math.max((leftColumnWidth - logoDrawSize.x) / 2, 0)
    imgui.SetCursorPosX(logoPosX)
    if mailLogoTexture then
        imgui.Image(mailLogoTexture, logoDrawSize)
    end
    imgui.SetCursorPosY(math.max(imgui.GetCursorPosY() - 30, 0))
    imgui.Separator()
    imgui.SetCursorPosY(math.max(imgui.GetCursorPosY() - -5, 0))
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
    local bottomTitleTop = u8("MPHelper")
    local bottomY = math.max(imgui.GetCursorPosY(), imgui.GetWindowHeight() - 28)
    imgui.SetCursorPosY(bottomY)
    imgui.SetCursorPosX(leftColumnStartX + math.max((leftColumnWidth - imgui.CalcTextSize(bottomTitleTop).x) / 2, 0))
    imgui.TextColored(imgui.ImVec4(0.92, 0.92, 0.92, 1.0), bottomTitleTop)

    imgui.NextColumn()
    imgui.SetCursorPosY(39)
    local rightColumnStartX = imgui.GetCursorPosX()
    local rightColumnWidth = imgui.GetColumnWidth()
    local itemSpacingX = imgui.GetStyle().ItemSpacing.x
    local radiusButtonSize = imgui.ImVec2(75, 27)
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
    if addons.MaterialButton('Azakon', radiusButtonSize) then
        sampSendChat('/azakon '..radius[0])
    end
    imgui.SameLine()
    if addons.MaterialButton('Armour', radiusButtonSize) then
        sampSendChat('/Armourall '..radius[0])
    end
    imgui.SameLine()
    if addons.MaterialButton('Repcar', radiusButtonSize) then
        sampSendChat('/Repcars '..radius[0])
    end
    imgui.SetCursorPosX(rightColumnStartX + math.max((rightColumnWidth - radiusButtonsRowWidth) / 2, 0))
    if addons.MaterialButton('UnArmour', radiusButtonSize) then
        sampSendChat('/unArmourall '..radius[0])
    end
    imgui.SameLine()
    if addons.MaterialButton('Freeze', radiusButtonSize) then
        sampSendChat('/freezeall '..radius[0])
    end
    imgui.SameLine()
    if addons.MaterialButton('UnFreeze', radiusButtonSize) then
        sampSendChat('/unfreezeall '..radius[0])
    end
    imgui.SetCursorPosX(rightColumnStartX + math.max((rightColumnWidth - radiusButtonsRowWidth) / 2, 0))
    if addons.MaterialButton('SpPlayers', radiusButtonSize) then
        sampSendChat('/spplayers '..radius[0])
    end
    imgui.SameLine()
    if addons.MaterialButton('SpCars', radiusButtonSize) then
        sampSendChat('/spcars '..radius[0])
    end
    imgui.SameLine()
    if addons.MaterialButton('Cure', radiusButtonSize) then
        sampSendChat('/cureall '..radius[0])
    end
    imgui.Spacing()
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
            sampAddChatMessage("Введите ID транспорта!", -1)
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
end
if page == 2 then
    imgui.Separator()
    imgui.Text(u8'Ники игроков которым не нужно выдавать Т/С')
    imgui.PushItemWidth(200)
    imgui.InputTextWithHint(u8'##ignore_nick', u8'Jonny_Hennessy', ignor, 256)
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
    imgui.StrCopy(mp.result,
        u8(mp.type[0] == 0 and
        '/ao Проходит МП "'..u8:decode(str(mp.name))..'". Приз: "'..u8:decode(str(mp.priz))..'" Для участия вводите /gotp' or
        '/ao Уважаемые игроки, сейчас пройдет мероприятие "'..u8:decode(str(mp.name))..'"\n/ao Приз: "'..u8:decode(str(mp.priz))..'"\n/ao Прописывайте /gotp и присоединяйтесь к мероприятию')
    )

    imgui.InputTextMultiline('##result', mp.result, sizeof(mp.result), imgui.ImVec2(-1, 100), imgui.InputTextFlags.ReadOnly)
    imgui.Separator()
    if addons.AnimButton(u8'Отправить /ao') then
        local text = u8:decode(str(mp.result))

        lua_thread.create(function()
            for line in text:gmatch('[^\n]+') do
                sampSendChat(line)
                wait(1100)
            end
        end)
    end
end
if page == 4 then
imgui.Separator()
imgui.Text(u8'ID Победителя')
imgui.PushItemWidth(90)
imgui.InputInt('##winner_id', mp.winner, 0, 0, imgui.InputTextFlags.CharsDecimal)
imgui.Separator()
imgui.StrCopy(mp.result_end, u8(
    '/ao Победитель мероприятия "'..u8:decode(str(mp.name))..'" - '..
    (sampIsPlayerConnected(mp.winner[0]) and (sampGetPlayerNickname(mp.winner[0])..'['..mp.winner[0]..']') or 'Игрок не найден!')..
    '. Поздравляем!'
))

imgui.InputTextMultiline('##result_end', mp.result_end, 512, imgui.ImVec2(565, 80), imgui.InputTextFlags.ReadOnly)
imgui.Separator()
if addons.AnimButton(u8'Отправить итог /ao') then
    if sampIsPlayerConnected(mp.winner[0]) then
        lua_thread.create(function()
            local text = u8:decode(ffi.string(mp.result_end))
            for line in text:gmatch('[^\n]+') do
                sampSendChat(line)
                wait(1100)
            end

            local clipboardText = buildWinnerClipboardText()
            if setClipboardText(clipboardText) then
                sampAddChatMessage(tag .. textcolor .. "Данные победителя скопированы в буфер обмена.", tagcolor)
            else
                sampAddChatMessage(tag .. textcolor .. "Не удалось скопировать данные в буфер обмена.", tagcolor)
            end
        end)
    else
        sampAddChatMessage("Игрок не найден!", -1)
    end
end
end

end)



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
                    sampAddChatMessage('WARNING >> {FFFFFF}Игрок '..sampGetPlayerNickname(playerId)..'['..playerId..'] был замечен в {FF0000}TeamKill {FFFFFF}уже {FF0000}'..tkInfo[playerId]..' раз!!', 0xFF0000)
                    if (tkInfo[playerId] == 5) then
                        lua_thread.create(function()
                            sampAddChatMessage('WARNING >> {FFFFFF}Игрок '..sampGetPlayerNickname(playerId)..'['..playerId..'] совершил {FF0000}TeamKill 5 раз{FFFFFF} и был наказан!!', 0xFF0000)
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

    c[imgui.Col.Text]                   = imgui.ImVec4(1.00, 1.00, 1.00, 0.95)
    c[imgui.Col.TextDisabled]           = imgui.ImVec4(0.70, 0.70, 0.70, 1.00)

    c[imgui.Col.WindowBg]               = imgui.ImVec4(0.08, 0.08, 0.10, 0.92)
    c[imgui.Col.ChildBg]                = imgui.ImVec4(0.10, 0.10, 0.12, 0.85)
    c[imgui.Col.PopupBg]                = imgui.ImVec4(0.10, 0.10, 0.12, 0.95)

    c[imgui.Col.Border]                 = imgui.ImVec4(1.00, 1.00, 1.00, 0.08)
    c[imgui.Col.BorderShadow]           = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)

    c[imgui.Col.FrameBg]                = imgui.ImVec4(0.15, 0.15, 0.18, 0.85)
    c[imgui.Col.FrameBgHovered]         = imgui.ImVec4(0.20, 0.20, 0.25, 0.90)
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
