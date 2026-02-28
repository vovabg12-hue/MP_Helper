local imgui = require('mimgui');
local encoding = require('encoding');
local faicons = require('fAwesome6');
local inicfg = require('inicfg')
local ffi = require('ffi');
local samp = require('lib.samp.events');

local directIni = 'MP Helper.ini';
local mainIni = inicfg.load(inicfg.load({
    settings = {
        antitk         = false,
        antiarmour     = false,
        antihp         = false,
        antiweapon     = false,
        antidm         = false,
        gun            = 24,
        ammo           = 500,
        radius         = 100,
        skin    = 100
    },
}, directIni))
inicfg.save(mainIni, directIni)

encoding.default = 'CP1251';
u8 = encoding.UTF8;

local new = imgui.new;
local font = {};
local str, sizeof = ffi.string, ffi.sizeof;

local renderWindow = new.bool();
local pages = {
    current = 0,
    enum = {
        {'Ãëàâíàÿ', faicons('HOUSE')},
        {'Íà÷àòü ÌÏ', faicons('PLAY')},
        {'Êîíåö ÌÏ', faicons('FLAG_CHECKERED')}
    }
}

local settings = {
    {new.bool(mainIni.settings.antitk),           'Àíòè ÒÊ',                     'antitk'},
    {new.bool(mainIni.settings.antiarmour),       'Àíòè ïîïîëíåíèå àðìîðà',      'antiarmour'},
    {new.bool(mainIni.settings.antihp),           'Àíòè ïîïîëíåíèå ÕÏ',          'antihp'},
    {new.bool(mainIni.settings.antiweapon),       'Àíòè îðóæèå èç èíâåíòàðÿ',    'antiweapon'},
    {new.bool(mainIni.settings.antidm),           'Àíòè ÄÌ',                     'antidm'},
    {new.bool(false),                             'Ãîíêà âîîðóæåíèé',            ''},
}
local radius = new.float(mainIni.settings.radius);
local skin = new.float(mainIni.settings.skin);
local gun = new.int(mainIni.settings.gun);
local ammo = new.int(mainIni.settings.ammo);

local tkInfo = {};

local gonkaInfo = {
    {new.int(1), new.int(24)},
    {new.int(2), new.int(27)},
    {new.int(3), new.int(31)},
    {new.int(4), new.int(29)},
    {new.int(5), new.int(32)},
    {new.int(6), new.int(78)},
};

local gameInfo = {};
local deathInfo = {};

local mp = {
    type = new.int(0),
    name = new.char[100](),
    prize = new.char[100](),
    result = new.char[512](),
    id = new.int(0)
}

local function resetMpSettings()
    mainIni.settings.antitk = false;
    mainIni.settings.antiarmour = false;
    mainIni.settings.antihp = false;
    mainIni.settings.antiweapon = false;
    mainIni.settings.antidm = false;
    settings = {
        {new.bool(mainIni.settings.antitk),           'Àíòè ÒÊ',                     'antitk'},
        {new.bool(mainIni.settings.antiarmour),       'Àíòè ïîïîëíåíèå àðìîðà',      'antiarmour'},
        {new.bool(mainIni.settings.antihp),           'Àíòè ïîïîëíåíèå ÕÏ',          'antihp'},
        {new.bool(mainIni.settings.antiweapon),       'Àíòè îðóæèå èç èíâåíòàðÿ',    'antiweapon'},
        {new.bool(mainIni.settings.antidm),           'Àíòè ÄÌ',                     'antidm'},
        {new.bool(false),                             'Ãîíêà âîîðóæåíèé',            ''},
    }
end

local function drawMainPage()
    imgui.BeginChild('##main_left', imgui.ImVec2(420, 360), true)
    imgui.PushFont(font[20])
    imgui.Text(u8('Êîìàíäû ïî ðàäèóñó'))
    imgui.PopFont()

    imgui.Text(u8('Ðàäèóñ:'))
    imgui.SetNextItemWidth(160)
    if (imgui.DragFloat('##radius', radius, 0.5, 0, 100, '%.0f')) then mainIni.settings.radius = radius[0]; end;

    if (imgui.Button('HP', imgui.ImVec2(95, 32))) then sampSendChat('/hpall '..radius[0]) end; imgui.SameLine();
    if (imgui.Button('Eat', imgui.ImVec2(95, 32))) then sampSendChat('/eatall '..radius[0]) end; imgui.SameLine();
    if (imgui.Button('Weap', imgui.ImVec2(95, 32))) then sampSendChat('/weapall '..radius[0]) end; imgui.SameLine();
    if (imgui.Button('Azakon', imgui.ImVec2(95, 32))) then sampSendChat('/azakon '..radius[0]) end;

    if (imgui.Button('Armour', imgui.ImVec2(95, 32))) then sampSendChat('/armourall '..radius[0]) end; imgui.SameLine();
    if (imgui.Button('UnArmour', imgui.ImVec2(95, 32))) then sampSendChat('/unarmourall '..radius[0]) end; imgui.SameLine();
    if (imgui.Button('Freeze', imgui.ImVec2(95, 32))) then sampSendChat('/freezeall '..radius[0]) end; imgui.SameLine();
    if (imgui.Button('UnFreeze', imgui.ImVec2(95, 32))) then sampSendChat('/unfreezeall '..radius[0]) end;

    if (imgui.Button('Repcar', imgui.ImVec2(120, 32))) then sampSendChat('/repcars '..radius[0]) end

    imgui.Separator()
    imgui.PushFont(font[18])
    imgui.Text(u8('Âûäàòü ñêèí'))
    imgui.PopFont()
    imgui.SetNextItemWidth(160)
    if (imgui.DragFloat('##skin', skin, 1.0, 0, 100000, '%.0f')) then mainIni.settings.skin = skin[0]; end;
    if (imgui.Button(u8('Âûäàòü ñêèí'), imgui.ImVec2(160, 32))) then sampSendChat('/skinall '..radius[0]..' '..skin[0]) end;

    imgui.Separator()
    imgui.PushFont(font[18])
    imgui.Text(u8('Ðàçäà÷à îðóæèÿ'))
    imgui.PopFont()
    imgui.Text(u8('ID îðóæèÿ:'))
    imgui.SetNextItemWidth(160)
    if (imgui.DragInt('##gun_give', gun, 1, 0, 100, '%.0f')) then mainIni.settings.gun = gun[0]; end;
    imgui.Text(u8('Ïàòðîíû:'))
    imgui.SetNextItemWidth(160)
    if (imgui.DragInt('##gun_ammo', ammo, 5, 0, 1000, '%.0f')) then mainIni.settings.ammo = ammo[0]; end;
    if (imgui.Button(u8'Ðàçäàòü', imgui.ImVec2(160, 32))) then sampSendChat('/gunall '..radius[0]..' '..gun[0]..' '..ammo[0]) end;
    imgui.EndChild(); imgui.SameLine();

    imgui.BeginChild('##main_right', imgui.ImVec2(210, 360), true)
    imgui.PushFont(font[18])
    imgui.CenterText(u8('Ãîíêà âîîðóæåíèé'))
    imgui.PopFont()
    for k, v in ipairs(gonkaInfo) do
        imgui.Text(u8(k..' ýòàï'))
        imgui.SetNextItemWidth(90)
        imgui.DragInt('##death__'..k, v[1], 1, 0, 999)
        imgui.SameLine()
        imgui.SetNextItemWidth(90)
        imgui.DragInt('##gun__'..k, v[2], 1, 0, 999)
    end
    imgui.EndChild()

    imgui.SetCursorPosY(imgui.GetCursorPosY() + 8)
    imgui.BeginChild('##settings_bottom', imgui.ImVec2(635, 120), true)
    imgui.PushFont(font[18])
    imgui.Text(u8('Íàñòðîéêè'))
    imgui.PopFont()
    for k, v in ipairs(settings) do
        if (imgui.ToggleButton(v[2], v[1]) and #v[3] ~= 0) then mainIni.settings[v[3]] = v[1][0]; end
        imgui.SameLine()
        imgui.Text(u8(v[2]))
    end
    imgui.EndChild()
end

local function drawStartPage()
    imgui.BeginChild('##start_wrap', imgui.ImVec2(635, 488), true)
    imgui.PushFont(font[20])
    imgui.CenterText(u8('Ìåíþ íà÷àëà ìåðîïðèÿòèÿ'))
    imgui.PopFont()
    imgui.Separator()

    imgui.BeginChild('##start_left', imgui.ImVec2(200, 420), true)
    imgui.Text(u8('Òèï îáúÿâëåíèÿ'))
    imgui.RadioButtonIntPtr(u8('Êîðîòêîå /ao##type_0'), mp.type, 0)
    imgui.RadioButtonIntPtr(u8('Äëèííîå /ao##type_1'), mp.type, 1)
    imgui.EndChild(); imgui.SameLine();

    imgui.BeginChild('##start_center', imgui.ImVec2(210, 420), true)
    imgui.Text(u8('Ââåäèòå íàçâàíèå ÌÏ'))
    imgui.InputText('##name', mp.name, sizeof(mp.name));
    imgui.Text(u8('Ââåäèòå ïðèç çà ÌÏ'))
    imgui.InputText('##prize', mp.prize, sizeof(mp.prize));
    if imgui.Button(u8('Îòïðàâèòü /ao'), imgui.ImVec2(180, 36)) then
        lua_thread.create(function()
            for line in u8:decode(str(mp.result)):gmatch('[^\n]+') do
                sampSendChat(line)
                wait(1100);
            end
        end)
    end
    imgui.EndChild(); imgui.SameLine();

    imgui.BeginChild('##start_right', imgui.ImVec2(205, 420), true)
    imgui.StrCopy(mp.result,
        u8(mp.type[0] == 0 and
        '/ao Ïðîõîäèò ÌÏ "'..u8:decode(str(mp.name))..'". Ïðèç: "'..u8:decode(str(mp.prize))..'" Äëÿ ó÷àñòèÿ ââîäèòå /gotp' or
        '/ao Óâàæàåìûå èãðîêè, ñåé÷àñ ïðîéäåò ìåðîïðèÿòèå "'..u8:decode(str(mp.name))..'"\n/ao Ïðèç: "'..u8:decode(str(mp.prize))..'"\n/ao Ïðîïèñûâàéòå /gotp è ïðèñîåäèíÿéòåñü ê ìåðîïðèÿòèþ')
    )
    imgui.InputTextMultiline('##result_start', mp.result, sizeof(mp.result), imgui.ImVec2(185, 390), imgui.InputTextFlags.ReadOnly)
    imgui.EndChild()
    imgui.EndChild()
end

local function drawEndPage()
    imgui.BeginChild('##end_wrap', imgui.ImVec2(635, 488), true)
    imgui.PushFont(font[20])
    imgui.CenterText(u8('Ìåíþ êîíöà ìåðîïðèÿòèÿ'))
    imgui.PopFont()
    imgui.Separator()

    imgui.BeginChild('##end_left', imgui.ImVec2(200, 420), true)
    imgui.Text(u8('Ââåäèòå íàçâàíèå ÌÏ'))
    imgui.InputText('##name_end', mp.name, sizeof(mp.name));
    imgui.Text(u8('ID ïîáåäèòåëÿ'))
    imgui.DragInt('##id', mp.id, 1, 0, 1000);
    if imgui.Button(u8('Îòïðàâèòü /ao'), imgui.ImVec2(180, 36)) then
        if sampIsPlayerConnected(mp.id[0]) then
            local playerName = sampIsPlayerConnected(mp.id[0]) and sampGetPlayerNickname(mp.id[0]) or 'unknown'
            setClipboardText(playerName)
            lua_thread.create(function()
                for line in u8:decode(str(mp.result)):gmatch('[^\n]+') do
                    sampSendChat(line)
                    wait(1100)
                end
                resetMpSettings()
            end)
        else
            sampAddChatMessage('MPHelper >> {FFFFFF}Èãðîê íå ïîäêëþ÷åí èëè ýòî âû!', 0xFF0000)
        end
    end
    imgui.EndChild(); imgui.SameLine();

    imgui.BeginChild('##end_right', imgui.ImVec2(420, 420), true)
    imgui.StrCopy(mp.result, u8(
        '/ao Ïîáåäèòåëü ìåðîïðèÿòèÿ "'..u8:decode(str(mp.name))..'" - '..(sampIsPlayerConnected(mp.id[0]) and sampGetPlayerNickname(mp.id[0]) or 'unknown')..'['..mp.id[0]..']. Ïîçäðàâëÿåì!')
    )
    imgui.InputTextMultiline('##result_end', mp.result, sizeof(mp.result), imgui.ImVec2(400, 390), imgui.InputTextFlags.ReadOnly)
    imgui.EndChild()
    imgui.EndChild()
end

imgui.OnFrame(
    function() return renderWindow[0] end,
    function(player)
        local resX, resY = getScreenResolution()
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(840, 560), imgui.Cond.FirstUseEver)
        imgui.Begin('MP Helper', renderWindow, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)

        imgui.BeginChild('##sidebar', imgui.ImVec2(170, 520), true)
        imgui.PushFont(font[25])
        imgui.CenterText('MP Helper')
        imgui.PopFont()
        imgui.Separator()
        for k, v in ipairs(pages.enum) do
            if imgui.Selectable(u8(v[2]..' '..v[1]), pages.current == k - 1, 0, imgui.ImVec2(150, 42)) then
                pages.current = k - 1
            end
        end
        imgui.SetCursorPosY(470)
        if imgui.Button(u8('Çàêðûòü'), imgui.ImVec2(150, 35)) then renderWindow[0] = false end
        imgui.EndChild(); imgui.SameLine();

        imgui.BeginChild('##content', imgui.ImVec2(645, 520), false)
        if pages.current == 0 then
            drawMainPage()
        elseif pages.current == 1 then
            drawStartPage()
        else
            drawEndPage()
        end
        imgui.EndChild()

        imgui.End()
    end
)

function main()
    while not isSampAvailable() do wait(0) end
    sampRegisterChatCommand('mph', function()
        renderWindow[0] = not renderWindow[0]
    end)

    sampAddChatMessage('MPHelper >> {FFFFFF}Loaded!', 0xFF0000)
    wait(-1)
end

function onScriptTerminate(scr, quitGame) 
    if (scr == thisScript()) then inicfg.save(mainIni, directIni); end
end

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil;
    imgui.SwitchContext()

    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true
    iconRanges = imgui.new.ImWchar[3](faicons.min_range, faicons.max_range, 0)
    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(faicons.get_font_data_base85('solid'), 25, config, iconRanges)

    imgui.GetStyle().FrameRounding = 6
    imgui.GetStyle().FramePadding.y = 6
    imgui.GetStyle().WindowRounding = 8

    imgui.GetStyle().Colors[imgui.Col.Text]                   = imgui.ImVec4(0.95, 0.95, 0.95, 1.00)
    imgui.GetStyle().Colors[imgui.Col.WindowBg]               = imgui.ImVec4(0.12, 0.13, 0.15, 0.98)
    imgui.GetStyle().Colors[imgui.Col.ChildBg]                = imgui.ImVec4(0.16, 0.17, 0.20, 0.95)
    imgui.GetStyle().Colors[imgui.Col.FrameBg]                = imgui.ImVec4(0.22, 0.24, 0.29, 1.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]         = imgui.ImVec4(0.27, 0.30, 0.36, 1.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBgActive]          = imgui.ImVec4(0.31, 0.34, 0.41, 1.00)

    imgui.GetStyle().Colors[imgui.Col.Button]                 = imgui.ImVec4(0.24, 0.36, 0.58, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ButtonHovered]          = imgui.ImVec4(0.29, 0.43, 0.67, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ButtonActive]           = imgui.ImVec4(0.20, 0.31, 0.49, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Header]                 = imgui.ImVec4(0.24, 0.36, 0.58, 0.90)
    imgui.GetStyle().Colors[imgui.Col.HeaderHovered]          = imgui.ImVec4(0.29, 0.43, 0.67, 0.95)
    imgui.GetStyle().Colors[imgui.Col.HeaderActive]           = imgui.ImVec4(0.20, 0.31, 0.49, 0.95)

    font[40] = imgui.GetIO().Fonts:AddFontFromFileTTF(getWorkingDirectory()..'\\MP Helper\\Inter-Regular.ttf', 40, nil, imgui.GetIO().Fonts:GetGlyphRangesCyrillic())
    font[20] = imgui.GetIO().Fonts:AddFontFromFileTTF(getWorkingDirectory()..'\\MP Helper\\Inter-Regular.ttf', 20, nil, imgui.GetIO().Fonts:GetGlyphRangesCyrillic())
    font[25] = imgui.GetIO().Fonts:AddFontFromFileTTF(getWorkingDirectory()..'\\MP Helper\\Inter-Regular.ttf', 25, nil, imgui.GetIO().Fonts:GetGlyphRangesCyrillic())
    font[18] = imgui.GetIO().Fonts:AddFontFromFileTTF(getWorkingDirectory()..'\\MP Helper\\Inter-Regular.ttf', 18, nil, imgui.GetIO().Fonts:GetGlyphRangesCyrillic())
    font[17] = imgui.GetIO().Fonts:AddFontFromFileTTF(getWorkingDirectory()..'\\MP Helper\\Inter-Regular.ttf', 17, nil, imgui.GetIO().Fonts:GetGlyphRangesCyrillic())
    font[15] = imgui.GetIO().Fonts:AddFontFromFileTTF(getWorkingDirectory()..'\\MP Helper\\Inter-Regular.ttf', 15, nil, imgui.GetIO().Fonts:GetGlyphRangesCyrillic())
end)

function samp.onBulletSync(playerId, data)
    if mainIni.settings.antidm then
        sampSendChat("/spplayer "..playerId)
        printStringNow("DM "..sampGetPlayerNickname(playerId), 2000)
        sampSendChat("/pm "..playerId.." 1 Çàïðåùåíî èñïîëüçîâàòü îðóæèå íà ìåðîïðèÿòèè!")
        sampSendChat('/weap '..playerId.." Íàðóøåíèå Ïðàâèë ÌÏ")
    end

    if mainIni.settings.antitk then
        local result1, handle1 = sampGetCharHandleBySampPlayerId(playerId);
        local result2, handle2 = sampGetCharHandleBySampPlayerId(data.targetId);
        if (data.targetId == select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))) then result2 = true; handle2 = PLAYER_PED; end
        if result1 and result2 then
            local skin1, skin2 = getCharModel(handle1), getCharModel(handle2)
            if (skin1 == skin2) then
                if not tkInfo[playerId] then tkInfo[playerId] = 1; else tkInfo[playerId] = tkInfo[playerId] + 1; end;
    
                if (tkInfo[playerId] >= 6) then
                    sampAddChatMessage('WARNING >> {FFFFFF}Èãðîê '..sampGetPlayerNickname(playerId)..'['..playerId..'] áûë çàìå÷åí â {FF0000}TeamKill {FFFFFF}óæå {FF0000}'..tkInfo[playerId]..' ðàç!!', 0xFF0000)
                    if (tkInfo[playerId] == 6) then
                        lua_thread.create(function()
                            sampAddChatMessage('WARNING >> {FFFFFF}Èãðîê '..sampGetPlayerNickname(playerId)..'['..playerId..'] áûë çàìå÷åí â {FF0000}TeamKill 6 ðàç{FFFFFF} è áûë çàñïàâíåí!!', 0xFF0000)
                            wait(0)
                            sampSendChat('/spplayer '..playerId)
                            wait(0)
                            sampSendChat('/pm '..playerId..' 1 Âû áûëè çàñïàâíåíû çà ÒÊ!')
                        end)
                        tkInfo[playerId] = 0;
                    end
                end
            end
        end
    end
end

-- âìåñòî ñèíõðû íà ïóëÿõ, èñïîëüçóåì èíôîðìàöèþ èç êèëë ëèñòà

local wasJustHere = {}

function samp.onPlayerDeathNotification(playerId, targetId, weapon)
    if settings[6][1][0] then
        lua_thread.create(function()
            wait(500)
            local _, pl = sampGetCharHandleBySampPlayerId(playerId)
            local t, tl = sampGetCharHandleBySampPlayerId(targetId)
            if (t or wasJustHere[targetId]) and _ then
                if not gameInfo[playerId] then gameInfo[playerId] = {level = 0, kills = 0} end
                
                if not deathInfo[targetId] then gameInfo[playerId].kills = gameInfo[playerId].kills + 1; end
    
                if (gameInfo[playerId].level ~= 6 and gameInfo[playerId].kills >= gonkaInfo[gameInfo[playerId].level + 1][1][0] and not deathInfo[targetId]) then
                    sampSendChat('/smp Èãðîê '..sampGetPlayerNickname(playerId)..'['..playerId..'] ñäåëàë '..gonkaInfo[gameInfo[playerId].level + 1][1][0]..' óáèéñòâ è ïîëó÷èë íîâîå îðóæèå (óðîâåíü '..(gameInfo[playerId].level + 1)..')')
                    sampSendChat('/weap '..playerId..' Íîâîå îðóæèå')
                    sampSendChat('/givegun '..playerId..' '..gonkaInfo[gameInfo[playerId].level + 1][2][0]..' 500')
                    wait(5100)
                    sampSendChat('/setarmour '..playerId..' 150')
                    wait(5100)
                    sampSendChat('/sethp '..playerId..' 120')
                    wait(0)
                    gameInfo[playerId] = {level = gameInfo[playerId].level + 1, kills = 0}
                end

                deathInfo[targetId] = true;
                wait(1000)
                local result, health = pcall(sampGetPlayerHealth, targetId);
                while result and health == 0 do wait(0) result, health = pcall(sampGetPlayerHealth, targetId) end
                deathInfo[targetId] = nil;
            end
        end)
    end
end

function samp.onPlayerStreamOut(id)
    lua_thread.create(function()
        wasJustHere[id] = true
        wait(3000)
        wasJustHere[id] = false
    end)
    return true
end

-- 

function samp.onPlayerChatBubble(id, col, dist, dur, msg)
    if msg:find("Äîñòàë%(à%) îðóæèå èç êàðìàíà") and mainIni.settings.antiweapon then
        lua_thread.create(function()    
            sampSendChat('/weap '..id.." Íàðóøåíèå Ïðàâèë ÌÏ")
            wait(500)
            sampSendChat("/pm "..id.." 1 Çàïðåùåíî áðàòü îðóæèå íà ÌÏ èç èíâåíòàðÿ")
        end)
    end
end

function samp.onApplyPlayerAnimation(id, animname, frameDelta, loop, lockx, locky, freeze, time)
    if mainIni.settings.antihp then
        if (animname == "ped" and frameDelta == "gum_eat") or (animname == "FOOD" and frameDelta == "EAT_Burger") or (animname == "SMOKING" and frameDelta == "M_smk_drag") then
            sampSendChat("/spplayer "..id)
            printStringNow("HEAL "..sampGetPlayerNickname(id), 2000)
            sampSendChat("/pm "..id.." 1 Çàïðåùåíî ïîïîëíÿòü çäîðîâüå íà ìåðîïðèÿòèè!")
            sampSendChat('/weap '..id.." Íàðóøåíèå Ïðàâèë ÌÏ")
        end
    end

    if animname == "goggles" and frameDelta == "goggles_put_on" and mainIni.settings.antiarmour then
        sampSendChat("/spplayer "..id)
        printStringNow("ARMOUR SPAWN "..sampGetPlayerNickname(id), 2000)
        sampSendChat("/pm "..id.." 1 Çàïðåùåíî ïîïîëíÿòü áðîíþ íà ìåðîïðèÿòèè!")
        sampSendChat('/weap '..id.." Íàðóøåíèå Ïðàâèë ÌÏ")
    end
end

function imgui.CenterText(text)
    imgui.SetCursorPosX(imgui.GetWindowSize().x / 2 - imgui.CalcTextSize(text).x / 2)
    imgui.Text(text)
end

function imgui.ToggleButton(str_id, bool)
    local rBool = false
 
    if LastActiveTime == nil then
       LastActiveTime = {}
    end
    if LastActive == nil then
       LastActive = {}
    end
 
    local function ImSaturate(f)
       return f < 0.0 and 0.0 or (f > 1.0 and 1.0 or f)
    end
  
    local p = imgui.GetCursorScreenPos()
    local draw_list = imgui.GetWindowDrawList()
 
    local height = imgui.GetTextLineHeightWithSpacing() + (imgui.GetStyle().FramePadding.y / 2)
    local width = height * 1.85
    local radius = height * 0.50
    local ANIM_SPEED = 0.15
 
    if imgui.InvisibleButton(str_id, imgui.ImVec2(width, height)) then
       bool[0] = not bool[0]
       rBool = true
       LastActiveTime[tostring(str_id)] = os.clock()
       LastActive[str_id] = true
    end
 
    local t = bool[0] and 1.0 or 0.0
 
    if LastActive[str_id] then
       local time = os.clock() - LastActiveTime[tostring(str_id)]
       if time <= ANIM_SPEED then
          local t_anim = ImSaturate(time / ANIM_SPEED)
          t = bool[0] and t_anim or 1.0 - t_anim
       else
          LastActive[str_id] = false
       end
    end
 
    draw_list:AddCircleFilled(imgui.ImVec2(p.x + radius + t * (width - radius * 2.0), p.y + radius), radius - 1.5, 0xFFD9D9D9, 30)
    draw_list:AddRect(p, imgui.ImVec2(p.x + width, p.y + height), 0xFFB1B1B1, 10)
    return rBool
 end
