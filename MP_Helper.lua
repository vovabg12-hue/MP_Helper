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
local json = require "json" -- ��� decodeJson/encodeJson ���� � ���� ��� ����
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
        sampAddChatMessage("������� ID ����������!", -1)
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

    sampAddChatMessage("������� �������: "..#players, -1)

    lua_thread.create(function()
        for _, player in pairs(players) do
            local res, ped = sampGetCharHandleBySampPlayerId(player)

            if res and isCharOnFoot(ped) then
                sampSendChat("/plveh "..player.." "..table.random(clist))
                wait(mainIni.settings.delay)
            end
        end
        sampAddChatMessage("�/� ������ ���� �������!", -1)
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


local tag = "[MPHelper] "
local tagcolor = 0xFF0000
local textcolor = "{FF8C00}"
local warncolor = "{FF8C00}"
local WinState = imgui.new.bool()



function main ()
    sampRegisterChatCommand('mph', function () WinState[0] = not WinState[0] end)
    
    sampAddChatMessage(tag .. textcolor .. "���������: " .. warncolor .. "/mph", tagcolor)
    sampAddChatMessage(tag .. textcolor .. "����� �������: " .. warncolor .. "Hennessy", tagcolor)
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
    imgui.SetNextWindowPos(imgui.ImVec2(500,500), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(500, 343), imgui.Cond.Always)
    imgui.Begin('##Window', WinState, imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar)
    
    if addons.HeaderButton(page == 1, u8("��������")) then
        page = 1
    end
    imgui.SameLine()
        if addons.HeaderButton(page == 3, u8("����� ��")) then
            page = 3
        end
    imgui.SameLine()
    if addons.HeaderButton(page == 4, u8("����� ��")) then
        page = 4
    end
    imgui.SameLine()
    if addons.HeaderButton(page == 2, u8("���������")) then
        page = 2
    end
    
    imgui.SameLine()
    imgui.SetCursorPosX(467)
    imgui.SetCursorPosY(5)
    addons.CloseButton('##closemenu', WinState, 25, 5)
    
    if page == 1 then
        imgui.Separator()
    imgui.Columns(2,'tabledep',true)
    imgui.SetColumnWidth(0,225)
    imgui.Spacing()
    if addons.ToggleButton(u8'���� ��',antitk) then
        mainIni.settings.antitk = antitk[0] save_ini()
    end
    if addons.ToggleButton(u8'���� ���������� ������',antiarmour) then
        mainIni.settings.antiarmour = antiarmour[0] save_ini()
    end
    if addons.ToggleButton(u8'���� ���������� ��������',antihp) then
        mainIni.settings.antihp = antihp[0] save_ini()
    end
    if addons.ToggleButton(u8'���� ������ �� ���������',antigun) then
        mainIni.settings.antigun = antigun[0] save_ini()
    end
    if addons.ToggleButton(u8'���� ��',antidm) then
        mainIni.settings.antidm = antidm[0] save_ini()
    end

    local text = "Made in Arizona RP Mesa"

local window_size = imgui.GetWindowSize()
local text_height = imgui.GetTextLineHeight()

local padding = 10

-- ��������� � ����
imgui.SetCursorPosY(window_size.y - text_height - padding)

-- �����
imgui.SetCursorPosX(padding)

-- ������� ����� �����
imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), text)

    imgui.NextColumn()
    imgui.SetCursorPosX(300)
    imgui.Text(u8'������ ��������')
    imgui.PushItemWidth(223)
    if imgui.SliderInt(u8'##radius', radius, 0, 100) then
        mainIni.settings.radius = radius[0] save_ini()
    end
    imgui.PopItemWidth()
    imgui.PushItemWidth(223)
    if addons.MaterialButton('HP', imgui.ImVec2(70, 27)) then
        sampSendChat('/hpall '..radius[0])
    end
    imgui.SameLine()
    if addons.MaterialButton('Eat', imgui.ImVec2(70, 27)) then
        sampSendChat('/eatall '..radius[0])
    end
    imgui.SameLine()
    if addons.MaterialButton('Weap', imgui.ImVec2(70, 27)) then
        sampSendChat('/weapall '..radius[0])
    end
    if addons.MaterialButton('Azakon', imgui.ImVec2(70, 27)) then
        sampSendChat('/azakon '..radius[0])
    end
    imgui.SameLine()
    if addons.MaterialButton('Armour', imgui.ImVec2(70, 27)) then
        sampSendChat('/Armourall '..radius[0])
    end
    imgui.SameLine()
    if addons.MaterialButton('Repcar', imgui.ImVec2(70, 27)) then
        sampSendChat('/Repcars '..radius[0])
    end
    if addons.MaterialButton('UnArmour', imgui.ImVec2(70, 27)) then
        sampSendChat('/unArmourall '..radius[0])
    end
    imgui.SameLine()
    if addons.MaterialButton('Freeze', imgui.ImVec2(70, 27)) then
        sampSendChat('/freezeall '..radius[0])
    end
    imgui.SameLine()
    if addons.MaterialButton('UnFreeze', imgui.ImVec2(70, 27)) then
        sampSendChat('/unfreezeall '..radius[0])
    end
    if addons.MaterialButton('SpPlayers', imgui.ImVec2(70, 27)) then
        sampSendChat('/spplayers '..radius[0])
    end
    imgui.SameLine()
    if addons.MaterialButton('SpCars', imgui.ImVec2(70, 27)) then
        sampSendChat('/spcars '..radius[0])
    end
    imgui.SameLine()
    if addons.MaterialButton('Cure', imgui.ImVec2(70, 27)) then
        sampSendChat('/cureall '..radius[0])
    end
    imgui.Spacing()
    imgui.PushItemWidth(146)
    imgui.InputTextWithHint(u8'##��� ������2', u8'ID �/� ��� ������', IDT, 256)
    imgui.SameLine()
    if addons.MaterialButton(u8'������', imgui.ImVec2(70, 27)) then
        local ids = u8:decode(str(IDT))
    
        if ids ~= "" then
            plvehall(ids)
        else
            sampAddChatMessage("������� ID ����������!", -1)
        end
    end
    imgui.PushItemWidth(146)
    imgui.InputTextWithHint(u8'##��� ������3', u8'ID ����� ��� ������', IDSK, 256)
    imgui.SameLine()
    if addons.MaterialButton(u8'������ ##2', imgui.ImVec2(70, 27)) then
        sampSendChat('/skinall ' .. radius[0] .. ' ' .. ffi.string(IDSK))
    end
    imgui.PushItemWidth(146)
    imgui.InputTextWithHint(u8'##��� ������4', u8'ID ���� ��� ������', IDG, 256)
    imgui.SameLine()
    if addons.MaterialButton(u8'������ ##3', imgui.ImVec2(70, 27)) then
        sampSendChat('/gunall ' .. radius[0] .. ' ' .. ffi.string(IDG).. ' ' ..tostring(pt[0]))
    end
end
if page == 2 then
    imgui.Separator()
    imgui.Text(u8'���� ������� ������� �� ����� �������� �/�')
    imgui.PushItemWidth(200)
    imgui.InputTextWithHint(u8'##��� ������', u8'Jonny_Hennessy', ignor, 256)
    imgui.SameLine()
    if addons.AnimButton(u8'��������') then
        local nick = u8:decode(str(ignor))
    
        if nick ~= "" then
            table.insert(ignorList, nick)
            save_ignore()
            ffi.copy(ignor, "")
        end
    end
    imgui.Text(u8'�������� ������ �/� � ��')
    if imgui.SliderInt(u8'##radius', delay, 0, 10000) then
        mainIni.settings.delay = delay[0] save_ini()
    end
    imgui.Text(u8'���-�� �������� ��� ������')
    if imgui.InputInt(u8'##��� ������528', pt, 0, 0, imgui.InputTextFlags.CharsDecimal) then
        mainIni.settings.pt = pt[0] save_ini()
    end

end
if page == 3 then
    imgui.Separator()
    imgui.Columns(2, 'mpstart', true)
    imgui.SetColumnWidth(0,125)
    -- 1 ������� (��� /ao)
    
    imgui.RadioButtonIntPtr('##type_0', mp.type, 0)
    imgui.SameLine()
    imgui.Text(u8'�������� /ao')

    
    imgui.RadioButtonIntPtr('##type_1', mp.type, 1)
    imgui.SameLine()
    imgui.Text(u8'������� /ao')
    imgui.NextColumn()

    -- 2 ������� (����)

    imgui.PushItemWidth(-1)
    imgui.InputTextWithHint('##name', u8'�������� ��', mp.name, 256)
    imgui.InputTextWithHint('##prize', u8'���� �� ��', mp.priz, 256)
    imgui.PopItemWidth()

    imgui.Spacing()
    imgui.Spacing()

    

    imgui.Columns(1)

    -- 3 ������� (���������)
    imgui.Separator()
    imgui.StrCopy(mp.result, 
        u8(mp.type[0] == 0 and
        '/ao �������� �� "'..u8:decode(str(mp.name))..'". ����: "'..u8:decode(str(mp.priz))..'" ��� ������� ������� /gotp' or
        '/ao ��������� ������, ������ ������� ����������� "'..u8:decode(str(mp.name))..'"\n/ao ����: "'..u8:decode(str(mp.priz))..'"\n/ao ������������ /gotp � ��������������� � �����������')
    )

    imgui.InputTextMultiline('##result', mp.result, sizeof(mp.result), imgui.ImVec2(-1, 120), imgui.InputTextFlags.ReadOnly)
    imgui.Separator()
    if addons.AnimButton(u8'��������� /ao') then
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
imgui.Text(u8'ID ����������')
imgui.PushItemWidth(88)
imgui.InputInt('##ID ����������', mp.winner, 0, 0, imgui.InputTextFlags.CharsDecimal)
imgui.Separator()
imgui.StrCopy(mp.result_end, u8(
    '/ao ���������� ����������� "'..u8:decode(str(mp.name))..'" - '..
    (sampIsPlayerConnected(mp.winner[0]) and sampGetPlayerNickname(mp.winner[0]) or 'unknown')..
    '['..mp.winner[0]..']. �����������!'
))

imgui.InputTextMultiline('##result_end', mp.result_end, 512, imgui.ImVec2(475, 80), imgui.InputTextFlags.ReadOnly)
imgui.Separator()
if addons.AnimButton(u8'��������� ���� /ao') then
    if sampIsPlayerConnected(mp.winner[0]) then
        lua_thread.create(function()
            local text = u8:decode(ffi.string(mp.result_end))
            for line in text:gmatch('[^\n]+') do
                sampSendChat(line)
                wait(1100)
            end
        end)
    else
        sampAddChatMessage("����� �� ������!", -1)
    end
end
end

end)



function sampev.onBulletSync(playerId, data)
    if mainIni.settings.antidm then
        sampSendChat("/spplayer "..playerId)
        printStringNow("DM "..sampGetPlayerNickname(playerId), 2000)
        sampSendChat("/pm "..playerId.." 1 ��������� ������������ ������ �� �����������!")
        sampSendChat('/weap '..playerId.." ��������� ������ ��")
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
                    sampAddChatMessage('WARNING >> {FFFFFF}����� '..sampGetPlayerNickname(playerId)..'['..playerId..'] ��� ������� � {FF0000}TeamKill {FFFFFF}��� {FF0000}'..tkInfo[playerId]..' ���!!', 0xFF0000)
                    if (tkInfo[playerId] == 5) then
                        lua_thread.create(function()
                            sampAddChatMessage('WARNING >> {FFFFFF}����� '..sampGetPlayerNickname(playerId)..'['..playerId..'] ��� ������� � {FF0000}TeamKill 5 ���{FFFFFF} � ��� ���������!!', 0xFF0000)
                            wait(0)
                            sampSendChat('/spplayer '..playerId)
                            wait(0)
                            sampSendChat('/pm '..playerId..' 1 �� ���� ���������� �� ��!')
                        end)
                        tkInfo[playerId] = 0;
                    end
                end
            end
        end
    end
end

function sampev.onApplyPlayerAnimation(id, animname, frameDelta, loop, lockx, locky, freeze, time)
	if mainIni.settings.antihp then
		if (animname == "ped" and frameDelta == "gum_eat") or (animname == "FOOD" and frameDelta == "EAT_Burger") or (animname == "SMOKING" and frameDelta == "M_smk_drag") then
			sampSendChat("/spplayer "..id)
			printStringNow("HEAL "..sampGetPlayerNickname(id), 2000)
			sampSendChat("/pm "..id.." 1 ��������� ��������� �������� �� �����������!")
			sampSendChat('/weap '..id.." ��������� ������ ��")
		end
	end
	if animname == "goggles" and frameDelta == "goggles_put_on" and mainIni.settings.antiarmour then
		sampSendChat("/spplayer "..id)
		printStringNow("ARMOUR SPAWN "..sampGetPlayerNickname(id), 2000)
		sampSendChat("/pm "..id.." 1 ��������� ��������� ����� �� �����������!")
		sampSendChat('/weap '..id.." ��������� ������ ��")
	end
end

function sampev.onPlayerChatBubble(id, col, dist, dur, msg)
    if msg:find("������%(�%) ������ �� �������") and mainIni.settings.antigun then
        lua_thread.create(function()    
            sampSendChat('/weap '..id.." ��������� ������ ��")
            wait(500)
            sampSendChat("/pm "..id.." 1 ��������� ����� ������ �� �� �� ���������")
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

    -- ���������
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

    -- ?? ���������������� (�������� ������)
    style.Alpha = 0.92

    -- ?? ����� (glass + ������ ������)
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

    -- ������ (������ ������ ����)
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

    -- ����
    c[imgui.Col.Tab]                    = imgui.ImVec4(0.15, 0.15, 0.20, 0.85)
    c[imgui.Col.TabHovered]             = imgui.ImVec4(0.30, 0.80, 1.00, 0.6)
    c[imgui.Col.TabActive]              = imgui.ImVec4(0.30, 0.80, 1.00, 0.9)
end
