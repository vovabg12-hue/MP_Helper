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
local renderStart = new.bool();
local renderEnd = new.bool();
local pages = {
    current = 0,
    enum = {
        {'Основное', faicons('HOUSE')},
        {'Настройки', faicons('GEAR')}
    }
}

local settings = {
    {new.bool(mainIni.settings.antitk),           'Анти ТК',                     'antitk'},
    {new.bool(mainIni.settings.antiarmour),       'Анти пополнение армора',      'antiarmour'},
    {new.bool(mainIni.settings.antihp),           'Анти пополнение ХП',          'antihp'},
    {new.bool(mainIni.settings.antiweapon),       'Анти оружие из инвентаря',    'antiweapon'},
    {new.bool(mainIni.settings.antidm),           'Анти ДМ',                     'antidm'},
    {new.bool(false),                             'Гонка вооружений',            ''},
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

imgui.OnFrame(
    function() return renderWindow[0] end,
    function(player)
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 618, 264
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        imgui.Begin('MP Helper', renderWindow, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoBackground + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)
        
        local dl = imgui.GetBackgroundDrawList();
        local p = imgui.GetCursorScreenPos()
        dl:AddRectFilled(p - imgui.ImVec2(5, 5), p + imgui.ImVec2(163, 255), 0xFF707070, 7, 5);
        dl:AddRectFilled(p + imgui.ImVec2(163, -5), p + imgui.ImVec2(609, 255), 0x80393939, 7, 10);

        imgui.SetCursorPos(imgui.GetCursorPos() - imgui.ImVec2(5, 5));
        imgui.BeginChild('##pages', imgui.ImVec2(168, 260));

        imgui.PushFont(font[40]);
        imgui.SetCursorPosY(15)
        imgui.CenterText('MPHelper');
        imgui.PopFont()
        imgui.PushFont(font[20]);
        imgui.CenterText('Arizona Mesa');
        imgui.PopFont()

        p = imgui.GetCursorScreenPos();
        dl:AddLine(p + imgui.ImVec2(10, 10), p + imgui.ImVec2(158, 10), -1, 2);

        imgui.SetCursorPosY(imgui.GetCursorPosY() + 30)
        local dl = imgui.GetWindowDrawList();
        for k, v in ipairs(pages.enum) do
            local p = imgui.GetCursorScreenPos();
            if (imgui.InvisibleButton(u8('##'..v[1]), imgui.ImVec2(168, 40))) then pages.current = k-1; end

            dl:AddRectFilled(p, p + imgui.ImVec2(168, 40), imgui.IsItemHovered() and 0x80999999 or (pages.current == k-1 and 0x80888888 or 0xFF707070));
            
            dl:AddText(p + imgui.ImVec2(10, 15), -1, v[2]);
            dl:AddTextFontPtr(font[25], 25, p + imgui.ImVec2(40, 5), -1, u8(v[1]));
        end

        imgui.SetCursorPosY(imgui.GetCursorPosY() + 19)
        p = imgui.GetCursorScreenPos();
        if (imgui.InvisibleButton(u8('##close'), imgui.ImVec2(168, 40))) then renderWindow[0] = false; end

        dl:AddRectFilled(p, p + imgui.ImVec2(168, 40), imgui.IsItemHovered() and 0x80999999 or 0x80888888);
        
        dl:AddText(p + imgui.ImVec2(10, 15), -1, faicons('OCTAGON_XMARK'));
        dl:AddTextFontPtr(font[25], 25, p + imgui.ImVec2(40, 5), -1, u8('Закрыть'));

        imgui.EndChild(); imgui.SameLine(); imgui.SetCursorPosX(imgui.GetCursorPosX() - 10);

        imgui.BeginChild('##container', imgui.ImVec2(609, 260));

        if (pages.current == 0) then
            
            imgui.BeginChild('##info_1', imgui.ImVec2(250, 260));
            imgui.SetCursorPos(imgui.GetCursorPos() + imgui.ImVec2(0, 15));
            for k, v in ipairs(settings) do
                imgui.SetCursorPosX(imgui.GetCursorPosX() + 15);
                if (imgui.ToggleButton(v[2], v[1]) and #v[3] ~= 0) then mainIni.settings[v[3]] = v[1][0]; end; imgui.SameLine();
                imgui.Text(u8(v[2]));
            end
            imgui.EndChild(); imgui.SameLine();

            local dl = imgui.GetWindowDrawList();
            local p = imgui.GetCursorScreenPos();

            dl:AddLine(p + imgui.ImVec2(-10, 20), p + imgui.ImVec2(-10, 240), -1, 2)

            imgui.BeginChild('##info_2', imgui.ImVec2(179, 260));
            imgui.SetCursorPosY(10)
            imgui.PushFont(font[18]);
            imgui.CenterText(u8('Радиус действия кнопок'));
            imgui.PopFont()

            imgui.PushStyleColorU32(imgui.Col.Text, 0xFF000000);
            imgui.SetNextItemWidth(179)
            if (imgui.DragFloat('##radius', radius, nil, 0, 100, '%.0f')) then mainIni.settings.radius = radius[0]; end;

            if (imgui.Button('HP', imgui.ImVec2(54, 24))) then       sampSendChat('/hpall '..radius[0]) end; imgui.SameLine();
            if (imgui.Button('Eat', imgui.ImVec2(54, 24))) then      sampSendChat('/eatall '..radius[0]) end; imgui.SameLine();
            if (imgui.Button('Weap', imgui.ImVec2(54, 24))) then     sampSendChat('/weapall '..radius[0]) end;
            
            if (imgui.Button('Azakon', imgui.ImVec2(85, 24))) then   sampSendChat('/azakon '..radius[0]) end; imgui.SameLine();
            if (imgui.Button('Armour', imgui.ImVec2(85, 24))) then   sampSendChat('/armourall '..radius[0]) end;
            
            if (imgui.Button('Repcar', imgui.ImVec2(85, 24))) then   sampSendChat('/repcars '..radius[0]) end; imgui.SameLine();
            if (imgui.Button('UnArmour', imgui.ImVec2(85, 24))) then sampSendChat('/unarmourall '..radius[0]) end;
            
            if (imgui.Button('Freeze', imgui.ImVec2(85, 24))) then   sampSendChat('/freezeall '..radius[0]) end; imgui.SameLine();
            if (imgui.Button('UnFreeze', imgui.ImVec2(85, 24))) then sampSendChat('/unfreezeall '..radius[0]) end;

            imgui.PopStyleColor();
            
            imgui.PushFont(font[18]);
            imgui.CenterText(u8('Скин для выдачи'));
            imgui.PopFont()

            imgui.PushStyleColorU32(imgui.Col.Text, 0xFF000000);
            imgui.SetNextItemWidth(179)
            if (imgui.DragFloat('##skin', skin, nil, 0, 100000, '%.0f')) then mainIni.settings.skin = skin[0]; end;
            if (imgui.Button(u8('Выдать скины'), imgui.ImVec2(179, 24))) then sampSendChat('/skinall '..radius[0]..' '..skin[0]) end;
            imgui.PopStyleColor();
            imgui.EndChild();
        elseif (pages.current == 1) then
            imgui.SetCursorPosX(imgui.GetCursorPosX() + 5)
            imgui.BeginChild('##info_1', imgui.ImVec2(230, 260), nil, imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse);

            local dl = imgui.GetWindowDrawList();
            imgui.PushStyleColorU32(imgui.Col.Border, 0x00000000)
            for k, v in ipairs(gonkaInfo) do
                if k == 1 then imgui.SetCursorPosY(imgui.GetCursorPosY() + 13) end
                local p = imgui.GetCursorScreenPos();
                dl:AddRect(p, p + imgui.ImVec2(110, 75), 0xFF000000, 7)

                imgui.BeginChild('##gonka__'..k, imgui.ImVec2(110, 75), true, imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse);
                p = imgui.GetCursorScreenPos();
                local text = u8(k..' этап');
                dl:AddTextFontPtr(font[18], 18, p - imgui.ImVec2(-(50 - (imgui.CalcTextSize(text).x / 1.5)), 20), -1, text);

                imgui.SetCursorPosY(imgui.GetCursorPosY() - 5)

                imgui.PushFont(font[15])
                imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(5, 1))

                imgui.CenterText(u8('Кол-во убийств'));

                imgui.SetCursorPosY(imgui.GetCursorPosY() - 5)
                imgui.PushStyleColorU32(imgui.Col.Text, 0xFF000000);
                imgui.SetNextItemWidth(90)
                imgui.DragInt('##death__'..k, v[1])
                imgui.PopStyleColor()

                imgui.SetCursorPosY(imgui.GetCursorPosY() - 5)
                imgui.CenterText(u8('ID оружия'));

                imgui.SetCursorPosY(imgui.GetCursorPosY() - 5)
                imgui.PushStyleColorU32(imgui.Col.Text, 0xFF000000);
                imgui.SetNextItemWidth(90)
                imgui.DragInt('##gun__'..k, v[2])
                imgui.PopStyleColor()

                imgui.PopFont()
                imgui.PopStyleVar()
                imgui.EndChild(); if math.fmod(k, 2) ~= 0 then imgui.SameLine(); imgui.SetCursorPosX(imgui.GetCursorPosX() - 5) else imgui.SetCursorPosY(imgui.GetCursorPosY() + 5) end
            end
            imgui.PopStyleColor()

            imgui.EndChild(); imgui.SameLine();

            local dl = imgui.GetWindowDrawList();
            local p = imgui.GetCursorScreenPos();

            dl:AddLine(p + imgui.ImVec2(-10, 20), p + imgui.ImVec2(-10, 240), -1, 2)
            
            imgui.BeginChild('##info_2', imgui.ImVec2(205, 260));
            imgui.PushFont(font[15]);

            local text = u8('Выдача ганов');
            imgui.SetCursorPosY(imgui.GetCursorPosY() + 13)
            imgui.CenterText(text);

            imgui.SetCursorPosY(imgui.GetCursorPosY() - 5)
            imgui.CenterText(u8('ID оружия'));

            imgui.SetCursorPosY(imgui.GetCursorPosY() - 5)
            imgui.PushStyleColorU32(imgui.Col.Text, 0xFF000000);
            imgui.SetNextItemWidth(90)
            if (imgui.DragInt('##gun_give', gun, nil, 0, 100, '%.0f')) then mainIni.settings.gun = gun[0]; end;
            imgui.PopStyleColor()
            imgui.SetCursorPosY(imgui.GetCursorPosY() - 5)
            imgui.CenterText(u8('Патроны:'));

            imgui.SetCursorPosY(imgui.GetCursorPosY() - 5)
            imgui.PushStyleColorU32(imgui.Col.Text, 0xFF000000);
            imgui.SetNextItemWidth(90)
            if (imgui.DragInt('##gun_ammo', ammo, nil, 0, 1000, '%.0f')) then mainIni.settings.ammo = ammo[0]; end;

            if (imgui.Button(u8'Раздать', imgui.ImVec2(85, 24))) then   sampSendChat('/gunall '..radius[0].." "..gun[0].." "..ammo[0]) end; imgui.SameLine();

            imgui.PopStyleColor()

            imgui.PopFont()
            imgui.EndChild()
        end

        imgui.EndChild();

        imgui.End()
    end
)

local mp = {
    type = new.int(0),
    name = new.char[100](),
    prize = new.char[100](),
    result = new.char[512](),
    id = new.int(0)
}

imgui.OnFrame(
    function() return renderStart[0] end,
    function(player)
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 500, 200
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        imgui.Begin('MP Helper >> Start', renderStart, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)
        
        imgui.PushFont(font[25])
        imgui.CenterText(u8('Меню начала мероприятия'))
        imgui.PopFont()

        local dl = imgui.GetWindowDrawList();
        local p = imgui.GetCursorScreenPos();

        imgui.SameLine()
        if (imgui.Button(u8('X##close'), imgui.ImVec2(15, 15))) then renderStart[0] = false; end

        dl:AddLine(p + imgui.ImVec2(5, 0), p + imgui.ImVec2(480, 0), -1, 2)
        dl:AddLine(p + imgui.ImVec2((500 / 3) * 1, 0), p + imgui.ImVec2((500 / 3) * 1, 150), -1, 2)
        dl:AddLine(p + imgui.ImVec2((500 / 3) * 2, 0), p + imgui.ImVec2((500 / 3) * 2, 150), -1, 2)

        imgui.PushStyleColorU32(imgui.Col.Border, 0x00000000)
        imgui.BeginChild('##child_1', imgui.ImVec2(500 / 3, 150), true)

        local p = imgui.GetCursorPos()
        imgui.SetCursorPos(p + imgui.ImVec2(20, 0));
        imgui.Text(u8('Короткое\n    /ao'));
        imgui.SetCursorPos(p + imgui.ImVec2(33, 35));
        imgui.RadioButtonIntPtr('##type_0', mp.type, 0);

        imgui.SetCursorPos(p + imgui.ImVec2(80, 0));
        imgui.Text(u8('Длинное\n    /ao'));
        imgui.SetCursorPos(p + imgui.ImVec2(93, 35));
        imgui.RadioButtonIntPtr('##type_1', mp.type, 1);

        imgui.EndChild(); imgui.SameLine(); imgui.SetCursorPosX(imgui.GetCursorPosX() - 7);
        
        imgui.BeginChild('##child_2', imgui.ImVec2(500 / 3, 150), true, imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)

        imgui.PushFont(font[17])
        imgui.CenterText(u8('Введите название МП'));
        imgui.PushStyleColorU32(imgui.Col.Text, 0xFF000000);
        imgui.SetNextItemWidth(150)
        imgui.InputText('##name', mp.name, sizeof(mp.name));
        imgui.PopStyleColor()

        imgui.CenterText(u8('Введите приз за МП'));
        imgui.PushStyleColorU32(imgui.Col.Text, 0xFF000000);
        imgui.SetNextItemWidth(150)
        imgui.InputText('##prize', mp.prize, sizeof(mp.prize));

        imgui.SetCursorPosY(imgui.GetCursorPosY() + 5);
        if imgui.Button(u8('Отправить /ao'), imgui.ImVec2(150, 30)) then
            lua_thread.create(function()
                for line in u8:decode(str(mp.result)):gmatch('[^\n]+') do
                    sampSendChat(line)
                    wait(1100);
                end
            end)
        end
        imgui.PopFont()
        imgui.PopStyleColor()

        imgui.EndChild(); imgui.SameLine(); imgui.SetCursorPosX(imgui.GetCursorPosX() - 7);
        
        imgui.BeginChild('##child_3', imgui.ImVec2(500 / 3, 150), true, imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)

        imgui.StrCopy(mp.result, 
            u8(mp.type[0] == 0 and
            '/ao Проходит МП "'..u8:decode(str(mp.name))..'". Приз: "'..u8:decode(str(mp.prize))..'" Для участия вводите /gotp' or
            '/ao Уважаемые игроки, сейчас пройдет мероприятие "'..u8:decode(str(mp.name))..'"\n/ao Приз: "'..u8:decode(str(mp.prize))..'"\n/ao Прописывайте /gotp и присоединяйтесь к мероприятию')
        )
        
        local dl = imgui.GetWindowDrawList();
        local p = imgui.GetCursorScreenPos();

        dl:AddRect(p, p + imgui.ImVec2(140, 140), 0xFF000000, 7)

        imgui.PushStyleColorU32(imgui.Col.FrameBg, 0x00000000)
        imgui.InputTextMultiline('##result', mp.result, sizeof(mp.result), imgui.ImVec2(140, 140), imgui.InputTextFlags.ReadOnly)
        imgui.PopStyleColor()

        imgui.EndChild();
        imgui.PopStyleColor()

        imgui.End()
    end
)

imgui.OnFrame(
    function() return renderEnd[0] end,
    function(player)
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 500, 200
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        imgui.Begin('MP Helper >> Start', renderEnd, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)
        
        imgui.PushFont(font[25])
        imgui.CenterText(u8('Меню конца мероприятия'))
        imgui.PopFont()

        local dl = imgui.GetWindowDrawList();
        local p = imgui.GetCursorScreenPos();

        imgui.SameLine()
        if (imgui.Button(u8('X##close'), imgui.ImVec2(15, 15))) then renderEnd[0] = false; end

        dl:AddLine(p + imgui.ImVec2(5, 0), p + imgui.ImVec2(480, 0), -1, 2)
        dl:AddLine(p + imgui.ImVec2((500 / 3) * 1, 0), p + imgui.ImVec2((500 / 3) * 1, 150), -1, 2)
        dl:AddLine(p + imgui.ImVec2((500 / 3) * 2, 0), p + imgui.ImVec2((500 / 3) * 2, 150), -1, 2)

        imgui.PushStyleColorU32(imgui.Col.Border, 0x00000000)
        imgui.BeginChild('##child_1', imgui.ImVec2(500 / 3, 150), true)

        imgui.EndChild(); imgui.SameLine(); imgui.SetCursorPosX(imgui.GetCursorPosX() - 7);
        
        imgui.BeginChild('##child_2', imgui.ImVec2(500 / 3, 150), true, imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)

        imgui.PushFont(font[17])
        imgui.CenterText(u8('Введите название МП'));
        imgui.PushStyleColorU32(imgui.Col.Text, 0xFF000000);
        imgui.SetNextItemWidth(150)
        imgui.InputText('##name', mp.name, sizeof(mp.name));
        imgui.PopStyleColor()

        imgui.CenterText(u8('ID победителя'));
        imgui.PushStyleColorU32(imgui.Col.Text, 0xFF000000);
        imgui.SetNextItemWidth(150)
        imgui.DragInt('##id', mp.id, nil, 0, 1000);
        
        imgui.SetCursorPosY(imgui.GetCursorPosY() + 5);
        if imgui.Button(u8('Отправить /ao'), imgui.ImVec2(150, 30)) then
            if sampIsPlayerConnected(mp.id[0]) then
                
                local playerName = sampIsPlayerConnected(mp.id[0]) and sampGetPlayerNickname(mp.id[0]) or 'unknown'
				
                setClipboardText(playerName)

        
                lua_thread.create(function()
                    for line in u8:decode(str(mp.result)):gmatch('[^\n]+') do
                        sampSendChat(line)
                        wait(1100)
                    end

                    mainIni.settings.antitk = false;
                    mainIni.settings.antiarmour = false;
                    mainIni.settings.antihp = false;
                    mainIni.settings.antiweapon = false;
                    mainIni.settings.antidm = false;
                    settings = {
                        {new.bool(mainIni.settings.antitk),           'Анти ТК',                     'antitk'},
                        {new.bool(mainIni.settings.antiarmour),       'Анти пополнение армора',      'antiarmour'},
                        {new.bool(mainIni.settings.antihp),           'Анти пополнение ХП',          'antihp'},
                        {new.bool(mainIni.settings.antiweapon),       'Анти оружие из инвентаря',    'antiweapon'},
                        {new.bool(mainIni.settings.antidm),           'Анти ДМ',                     'antidm'},
                        {new.bool(false),                             'Гонка вооружений',            ''},
                    }
                end)
            else
                sampAddChatMessage('MPHelper >> {FFFFFF}Игрок не подключен или это вы!', 0xFF0000)
            end
        end
        imgui.PopFont()
        imgui.PopStyleColor()

        imgui.EndChild(); imgui.SameLine(); imgui.SetCursorPosX(imgui.GetCursorPosX() - 7);
        
        imgui.BeginChild('##child_3', imgui.ImVec2(500 / 3, 150), true, imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)

        imgui.StrCopy(mp.result, u8(
            '/ao Победитель мероприятия "'..u8:decode(str(mp.name))..'" - '..(sampIsPlayerConnected(mp.id[0]) and sampGetPlayerNickname(mp.id[0]) or 'unknown')..'['..mp.id[0]..']. Поздравляем!')
        )
        
        local dl = imgui.GetWindowDrawList();
        local p = imgui.GetCursorScreenPos();

        dl:AddRect(p, p + imgui.ImVec2(140, 140), 0xFF000000, 7)

        imgui.PushStyleColorU32(imgui.Col.FrameBg, 0x00000000)
        imgui.InputTextMultiline('##result', mp.result, sizeof(mp.result), imgui.ImVec2(140, 140), imgui.InputTextFlags.ReadOnly)
        imgui.PopStyleColor()

        imgui.EndChild();
        imgui.PopStyleColor()

        imgui.End()
    end
)

function main()
    while not isSampAvailable() do wait(0) end
    sampRegisterChatCommand('mphelp', function()
        renderWindow[0] = not renderWindow[0]
    end)
    sampRegisterChatCommand('mp_start', function()
        renderStart[0] = not renderStart[0]
    end)
    sampRegisterChatCommand('mp_end', function()
        renderEnd[0] = not renderEnd[0]
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

    imgui.GetStyle().FrameRounding = 5
    imgui.GetStyle().FramePadding.y = 5
    
    imgui.GetStyle().Colors[imgui.Col.WindowBg]               = imgui.ImVec4(0.22, 0.22, 0.22, 0.50)
    imgui.GetStyle().Colors[imgui.Col.FrameBg]                = imgui.ImVec4(0.85, 0.85, 0.85, 1.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]         = imgui.ImVec4(0.90, 0.90, 0.90, 1.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBgActive]          = imgui.ImVec4(0.95, 0.95, 0.95, 1.00)

    imgui.GetStyle().Colors[imgui.Col.Button]                = imgui.ImVec4(0.85, 0.85, 0.85, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ButtonHovered]         = imgui.ImVec4(0.90, 0.90, 0.90, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ButtonActive]          = imgui.ImVec4(0.95, 0.95, 0.95, 1.00)

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
    
                if (tkInfo[playerId] >= 6) then
                    sampAddChatMessage('WARNING >> {FFFFFF}Игрок '..sampGetPlayerNickname(playerId)..'['..playerId..'] был замечен в {FF0000}TeamKill {FFFFFF}уже {FF0000}'..tkInfo[playerId]..' раз!!', 0xFF0000)
                    if (tkInfo[playerId] == 6) then
                        lua_thread.create(function()
                            sampAddChatMessage('WARNING >> {FFFFFF}Игрок '..sampGetPlayerNickname(playerId)..'['..playerId..'] был замечен в {FF0000}TeamKill 6 раз{FFFFFF} и был заспавнен!!', 0xFF0000)
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

-- вместо синхры на пулях, используем информацию из килл листа

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
                    sampSendChat('/smp Игрок '..sampGetPlayerNickname(playerId)..'['..playerId..'] сделал '..gonkaInfo[gameInfo[playerId].level + 1][1][0]..' убийств и получил новое оружие (уровень '..(gameInfo[playerId].level + 1)..')')
					sampSendChat('/weap '..playerId..' Новое оружие')
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
    if msg:find("Достал%(а%) оружие из кармана") and mainIni.settings.antiweapon then
        lua_thread.create(function()    
            sampSendChat('/weap '..id.." Нарушение Правил МП")
            wait(500)
            sampSendChat("/pm "..id.." 1 Запрещено брать оружие на МП из инвентаря")
        end)
    end
end

function samp.onApplyPlayerAnimation(id, animname, frameDelta, loop, lockx, locky, freeze, time)
	if mainIni.settings.antihp then
		if (animname == "ped" and frameDelta == "gum_eat") or (animname == "FOOD" and frameDelta == "EAT_Burger") or (animname == "SMOKING" and frameDelta == "M_smk_drag") then
			sampSendChat("/spplayer "..id)
			printStringNow("HEAL "..sampGetPlayerNickname(id), 2000)
			sampSendChat("/pm "..id.." 1 Запрещено пополнять здоровье на мероприятии!")
			sampSendChat('/weap '..id.." Нарушение Правил МП")
		end
	end

	if animname == "goggles" and frameDelta == "goggles_put_on" and mainIni.settings.antiarmour then
		sampSendChat("/spplayer "..id)
		printStringNow("ARMOUR SPAWN "..sampGetPlayerNickname(id), 2000)
		sampSendChat("/pm "..id.." 1 Запрещено пополнять броню на мероприятии!")
		sampSendChat('/weap '..id.." Нарушение Правил МП")
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