@echo off
rem ==========================================================================
rem  THE WILD WEST / SPACE / CYBER / OCEAN - баннер при запуске cmd.exe
rem  Темы: wildwest, space, cyber, ocean - внутри темы сцена выбирается случайно.
rem
rem    COWBOY_BANNER=off     вместо картинки - меню выбора темы
rem    COWBOY_BANNER=none    не показывать ничего
rem    COWBOY_THEME=<тема>   wildwest | space | cyber | ocean | any
rem    COWBOY_BANNER=ascii   без псевдографики (для консолей не в cp866)
rem    COWBOY_ALWAYS=1       показывать и в cmd /c (для скриптов и тестов)
rem
rem  Убрать совсем:
rem    reg delete "HKCU\Software\Microsoft\Command Processor" /v AutoRun /f
rem ==========================================================================

if defined COWBOY_BANNER_DONE goto :eof
set "COWBOY_BANNER_DONE=1"

rem Переключатель один на оба шелла, регистр не важен, пробелы не важны:
rem "set X=off " в cmd даёт значение "off " - это ловушка, поэтому режем пробелы.
rem Пробелы режем в два шага: подстановка %ПЕРЕМ: =% на НЕОПРЕДЕЛЕННОЙ
rem переменной даёт пробел, а не пустую строку.
set "OFF=%COWBOY_CMD%"
if not defined OFF set "OFF=%COWBOY_BANNER%"
set "OFF=%OFF: =%"
if /I "%OFF%"=="none" goto :eof
rem Баннер - только в интерактивном окне (в командной строке нет /c или /k),
rem иначе он засоряет вывод у скриптов.
if defined COWBOY_ALWAYS goto :nocheck
echo %cmdcmdline% | find /i "/c " >nul && goto :eof
echo %cmdcmdline% | find /i "/k " >nul && goto :eof
:nocheck

setlocal
set "ESC="

rem --- кодовая страница консоли (языконезависимо) ------------------------
set "CP="
for /f "delims=" %%a in ('chcp') do set "RAW=%%a"
set "RAW=%RAW: =%"
set "RAW=%RAW::=/%"
for /f "tokens=1,* delims=/" %%a in ("%RAW%") do set "CP=%%b"
if /I "%OFF%"=="ascii" set "CP=000"

rem Меню - после определения кодировки: красивая рамка требует cp866.
rem "off" - старое имя для menu, работает как синоним.
if /I "%OFF%"=="menu" goto :menu
if /I "%OFF%"=="off" goto :menu

rem --- тема ---------------------------------------------------------------
set "TH=%COWBOY_THEME%"
set "TH=%TH: =%"
if not defined TH set "TH=wildwest"
if /I "%TH%"=="any" goto :anytheme
if /I "%TH%"=="menu" goto :menu
if /I "%TH%"=="off" goto :menu
if /I "%TH%"=="space" goto :th_space
if /I "%TH%"=="cyber" goto :th_cyber
if /I "%TH%"=="ocean" goto :th_ocean
:th_wildwest
set "TH=wildwest"
set "NS=4"
goto :pick
:th_space
set "TH=space"
set "NS=2"
goto :pick
:th_cyber
set "TH=cyber"
set "NS=2"
goto :pick
:th_ocean
set "TH=ocean"
set "NS=2"
goto :pick
goto :th_wildwest

:anytheme
set /a R=%RANDOM% %% 4
if "%R%"=="0" goto :th_wildwest
if "%R%"=="1" goto :th_space
if "%R%"=="2" goto :th_cyber
goto :th_ocean

:pick
rem --- сцена: случайно внутри темы, но не та же, что в прошлый раз ---------
set /a S=%RANDOM% %% %NS%
set "SF=%TEMP%\cowboy-scene-%TH%.txt"
set "PREV="
if exist "%SF%" set /p PREV=<"%SF%"
if "%PREV%"=="%S%" set /a S=(%S%+1) %% %NS%
> "%SF%" echo %S%

rem --- метка [тема] в приветствии: только если попросили подсказки -------
set "TAG="
if defined COWBOY_HINT set "TAG=   [%TH%]"

rem --- время суток, приветствие и поговорка по теме ----------------------
for /f "tokens=1 delims=:." %%a in ("%TIME%") do set "HOUR=%%a"
if not defined HOUR set "HOUR=12"
set /a HOUR=%HOUR% 2>nul
if not defined HOUR set "HOUR=12"
set /a GI=%RANDOM% %% 4
set /a SI=%RANDOM% %% 6

rem поговорки всех тем: русские (FR_тема_N) и английские (EN_тема_N)
set "FR_wildwest_1=Случай ведёт только на запад."
set "FR_wildwest_2=Сначала скажи "howdy", потом запускай терминал."
set "FR_wildwest_3=Под седлом бага не ищи - он сверху, в стеке."
set "FR_wildwest_4=Терпение, лошади и длинный pipeline - основа любого деплоя."
set "FR_wildwest_5=Раннее утро идеально для rm -rf. И для кофе."
set "FR_wildwest_6=Кто не рискует, тот не едет верхом."
set "FR_space_1=Критическая масса не прощает поспешных коммитов."
set "FR_space_2=В вакууме никто не слышит твой деплой - он всё равно упадёт."
set "FR_space_3=Спутник связи полезнее спутника-обвинителя."
set "FR_space_4=Чем выше орбита, тем ближе к звезде релиз."
set "FR_space_5=Скажи "поехали", отодвинься от пульта и нажми Enter."
set "FR_space_6=Гравитация терпелива: она дождётся."
set "FR_cyber_1=Матрица была красива, пока ты не открыл продакшн."
set "FR_cyber_2=Никогда не коммить в пятницу. Никогда."
set "FR_cyber_3=Стек-трейс тебя палит - он честнее полиции."
set "FR_cyber_4=Тёмный экран - не баг, а фича: он говорит правду."
set "FR_cyber_5=Кто ищет логи, тот теряет время. Кто их читает - находит истину."
set "FR_cyber_6=Не бойся отладчика. Бойся продакшна."
set "FR_ocean_1=Подводные лодки не терпят подводных камней в коде."
set "FR_ocean_2=Течение уносит баги к дедлайну быстрее, чем ты думаешь."
set "FR_ocean_3=На дне только логи и иллюминаторы."
set "FR_ocean_4=Глубже значит темнее: в логах всегда так."
set "FR_ocean_5=Проверь иллюминаторы, прежде чем уходить в рейс."
set "FR_ocean_6=Шторм снаружи, дедлайн внутри - одинаково страшно."
set "EN_wildwest_1=Luck rides only west."
set "EN_wildwest_2=Say howdy before you touch the shell."
set "EN_wildwest_3=The bug is never under the saddle, it is in the stack."
set "EN_wildwest_4=Patience, horses, and one long pipeline."
set "EN_wildwest_5=Early morning is perfect for rm -rf. And for coffee."
set "EN_wildwest_6=No risk, no ride."
set "EN_space_1=Critical mass does not forgive premature commits."
set "EN_space_2=In vacuum nobody hears your deploy - it still fails."
set "EN_space_3=A comms satellite beats an accusation satellite."
set "EN_space_4=The higher the orbit, the closer to star release."
set "EN_space_5=Say to be, step back from the panel and press Enter."
set "EN_space_6=Gravity is patient, it will wait."
set "EN_cyber_1=The Matrix was pretty until you hit production."
set "EN_cyber_2=Never commit on Friday. Never."
set "EN_cyber_3=Your stack trace betrays you, it is more honest than the police."
set "EN_cyber_4=A black screen is not a bug, it is a feature: it tells the truth."
set "EN_cyber_5=Those who search logs lose time. Those who read them find truth."
set "EN_cyber_6=Do not fear the debugger. Fear production."
set "EN_ocean_1=Submarines do not like underwater rocks in the code."
set "EN_ocean_2=The current carries bugs to the deadline faster than you think."
set "EN_ocean_3=At the bottom there are only logs and portholes."
set "EN_ocean_4=Deeper means darker: in logs it is always so."
set "EN_ocean_5=Check the portholes before you sail."
set "EN_ocean_6=A storm outside, a deadline inside, equally scary."

set "PART=ДОБРЫЙ ВЕЧЕР"
set "PARTA=GOOD EVENING"
if %HOUR% LSS 5 set "PART=ДОБРАЯ НОЧЬ"
if %HOUR% LSS 5 set "PARTA=GOOD NIGHT"
if %HOUR% GEQ 5 if %HOUR% LSS 12 set "PART=ДОБРОЕ УТРО"
if %HOUR% GEQ 5 if %HOUR% LSS 12 set "PARTA=GOOD MORNING"
if %HOUR% GEQ 12 if %HOUR% LSS 18 set "PART=ДОБРЫЙ ДЕНЬ"
if %HOUR% GEQ 12 if %HOUR% LSS 18 set "PARTA=GOOD AFTERNOON"

if /I "%TH%"=="wildwest" goto :say_wildwest
if /I "%TH%"=="space" goto :say_space
if /I "%TH%"=="cyber" goto :say_cyber
goto :say_ocean
:say_wildwest
set "G1=H O W D Y"
set "G2=Y O H O,  C O W B O Y"
set "G3=E V E N I N G,  S T R A N G E R"
set "G4=K I N G  O F  T H E  H I L L"
if "%GI%"=="0" set "HI=%G1%"
if "%GI%"=="1" set "HI=%G2%"
if "%GI%"=="2" set "HI=%G3%"
if "%GI%"=="3" set "HI=%G4%"
for /f "tokens=1,* delims==" %%f in ('set FR_wildwest_%SI%') do set "FR=%%g"
for /f "tokens=1,* delims==" %%f in ('set EN_wildwest_%SI%') do set "FE=%%g"
goto :say_done
:say_space
set "G1=H E Y,  A S T R O N A U T"
set "G2=T O  B E  O R  N O T  T O  B E"
set "G3=L A U N C H  T - M I N U T S"
set "G4=M I S S I O N  C O N T R O L"
if "%GI%"=="0" set "HI=%G1%"
if "%GI%"=="1" set "HI=%G2%"
if "%GI%"=="2" set "HI=%G3%"
if "%GI%"=="3" set "HI=%G4%"
for /f "tokens=1,* delims==" %%f in ('set FR_space_%SI%') do set "FR=%%g"
for /f "tokens=1,* delims==" %%f in ('set EN_space_%SI%') do set "FE=%%g"
goto :say_done
:say_cyber
set "G1=W E L C O M E ,  N E T R U N N E R"
set "G2=G O O D  E V E N I N G ,  H A C K E R"
set "G3=S Y S T E M  R E A D Y"
set "G4=N E O N  L I G H T S  O N"
if "%GI%"=="0" set "HI=%G1%"
if "%GI%"=="1" set "HI=%G2%"
if "%GI%"=="2" set "HI=%G3%"
if "%GI%"=="3" set "HI=%G4%"
for /f "tokens=1,* delims==" %%f in ('set FR_cyber_%SI%') do set "FR=%%g"
for /f "tokens=1,* delims==" %%f in ('set EN_cyber_%SI%') do set "FE=%%g"
goto :say_done
:say_ocean
set "G1=A H O Y,  M A T E S"
set "G2=P O R T  A H O Y"
set "G3=M O O R I N G  S T A R"
set "G4=C L E A R  W A T E R S"
if "%GI%"=="0" set "HI=%G1%"
if "%GI%"=="1" set "HI=%G2%"
if "%GI%"=="2" set "HI=%G3%"
if "%GI%"=="3" set "HI=%G4%"
for /f "tokens=1,* delims==" %%f in ('set FR_ocean_%SI%') do set "FR=%%g"
for /f "tokens=1,* delims==" %%f in ('set EN_ocean_%SI%') do set "FE=%%g"
goto :say_done
:say_done

rem --- выбор сцены --------------------------------------------------------
:d_first
if /I "%TH%"=="wildwest" goto :d_wildwest
if /I "%TH%"=="space" goto :d_space
if /I "%TH%"=="cyber" goto :d_cyber
if /I "%TH%"=="ocean" goto :d_ocean
goto :d_ocean
:d_wildwest
if not "%CP%"=="866" goto :a_wildwest
if "%S%"=="0" goto :wagon_dos
if "%S%"=="1" goto :wire_dos
if "%S%"=="2" goto :fire_dos
goto :saloon_dos
:d_space
if not "%CP%"=="866" goto :a_space
if "%S%"=="0" goto :planet_dos
goto :satellite_dos
:d_cyber
if not "%CP%"=="866" goto :a_cyber
if "%S%"=="0" goto :city_dos
goto :matrix_dos
:d_ocean
if not "%CP%"=="866" goto :a_ocean
if "%S%"=="0" goto :submarine_dos
goto :whale_dos

:a_wildwest
if "%S%"=="0" goto :wagon_asc
if "%S%"=="1" goto :wire_asc
if "%S%"=="2" goto :fire_asc
goto :saloon_asc
:a_space
if "%S%"=="0" goto :planet_asc
goto :satellite_asc
:a_cyber
if "%S%"=="0" goto :city_asc
goto :matrix_asc
:a_ocean
if "%S%"=="0" goto :submarine_asc
goto :whale_asc

rem ======================= МЕНЮ ТЕМ =====================================
:menu
setlocal
set "CURT=%COWBOY_THEME%"
if not defined CURT set "CURT=wildwest"
set "CURT=%CURT: =%"
rem Маркер темы - звёздочка, а не ">": в echo это знак перенаправления вывода.
rem Поле маркера всегда 2 символа, иначе строки съезжают по колонкам.
set "MK1=  "
set "MK2=  "
set "MK3=  "
set "MK4=  "
set "MK5=  "
if /I "%CURT%"=="wildwest" set "MK1= *"
if /I "%CURT%"=="space" set "MK2= *"
if /I "%CURT%"=="cyber" set "MK3= *"
if /I "%CURT%"=="ocean" set "MK4= *"
if /I "%CURT%"=="any" set "MK5= *"
echo(
rem --- красивое меню (нужна cp866) ---
if not "%CP%"=="866" goto :menu_ascii
echo   ╔════════════════════════════════════════════════════════════╗
echo   ║   Т Е М Ы   Б А Н Н Е Р О В   -   что рисовать?            ║
echo   ╠════════════════════════════════════════════════════════════╣
echo   ║%MK1% wildwest  Дикий Запад    4 шт                         ║
echo   ║%MK2% space     Космос         2 шт                         ║
echo   ║%MK3% cyber     Киберпанк      2 шт                         ║
echo   ║%MK4% ocean     Океан          2 шт                         ║
echo   ║%MK5% any       любая тема   ^(случайно^)                     ║
echo   ╚════════════════════════════════════════════════════════════╝
echo(
echo   Сейчас активна тема: %CURT%
echo(
echo   Переключить тему ^(работает и в PowerShell, и в cmd^):
echo       setx COWBOY_THEME wildwest
echo       setx COWBOY_THEME space
echo       setx COWBOY_THEME cyber
echo       setx COWBOY_THEME ocean
echo       setx COWBOY_THEME any        ^(каждая картинка случайная^)
echo(
echo   Только для этого окна ^(без setx^):
echo       set COWBOY_THEME=ocean        cmd
echo       $env:COWBOY_THEME = 'ocean'   PowerShell
echo(
echo   Что бывает в COWBOY_BANNER:
echo       ^(не задана^) рисовать картинку  setx COWBOY_BANNER ""
echo       menu        показать это меню   setx COWBOY_BANNER menu
echo       none        не выводить ничего   setx COWBOY_BANNER none
echo       ascii       без псевдографики     setx COWBOY_BANNER ascii
echo       plain       без цвета            setx COWBOY_BANNER plain
echo       off - старое имя для menu, то же самое
echo(
echo   Подсказки в баннере - отдельно:    setx COWBOY_HINT on
goto :menu_done
:menu_ascii
echo   +------------------------------------------------------------+
echo   ^|   B A N N E R   T H E M E S   -   pick one                 ^|
echo   +------------------------------------------------------------+
echo   ^|%MK1% wildwest  WILD WEST      4 шт                         ^|
echo   ^|%MK2% space     SPACE          2 шт                         ^|
echo   ^|%MK3% cyber     CYBER          2 шт                         ^|
echo   ^|%MK4% ocean     OCEAN          2 шт                         ^|
echo   ^|%MK5% any       any theme   ^(random^)                        ^|
echo   +------------------------------------------------------------+
echo(
echo   Current theme: %CURT%
echo(
echo   Switch theme ^(works in PowerShell and cmd^):
echo       setx COWBOY_THEME wildwest
echo       setx COWBOY_THEME space
echo       setx COWBOY_THEME cyber
echo       setx COWBOY_THEME ocean
echo       setx COWBOY_THEME any        ^(random picture each time^)
echo(
echo   This window only ^(no setx^):
echo       set COWBOY_THEME=ocean        cmd
echo       $env:COWBOY_THEME = 'ocean'   PowerShell
echo(
echo   Values of COWBOY_BANNER:
echo       ^(unset^)        draw the picture  setx COWBOY_BANNER ""
echo       menu        show this menu        setx COWBOY_BANNER menu
echo       none        show nothing          setx COWBOY_BANNER none
echo       ascii       no box drawing        setx COWBOY_BANNER ascii
echo       plain       no colors            setx COWBOY_BANNER plain
echo       off - old name of menu, same thing
echo(
echo   Hints in the banner:    setx COWBOY_HINT on
:menu_done
endlocal
goto :eof


rem ===== wildwest / wagon =====
:wagon_dos
echo(
echo [38;5;214m   [38;5;250m*[38;5;214m              [38;5;250m*[38;5;214m                                       [38;5;250m*[38;5;214m              [38;5;250m*
echo [38;5;214m           [38;5;250m·[38;5;214m                      ═════════                       [38;5;250m·
echo [38;5;214m               \/            ═══════════════════    [38;5;250m*
echo [38;5;214m       [38;5;250m·[38;5;214m\/                ═══════════════════[38;5;250m*[38;5;214m═════
echo [38;5;214m                          ═════════════════════════         ───────────
echo [38;5;214m                          ═════════════════════════         /───────────\
echo [38;5;214m     ─────────             ═══════════════════════          │           │
echo [38;5;214m     /─────────\               ═══════════════              │           │
echo [38;5;214m     │         │                                            │           │
echo [38;5;94m════════════════════════════════════════════════════════════════════════════
echo(
echo                   [38;5;223m           ──────────────────
echo       [38;5;71m  _^|_  [0m     [38;5;223m          /                  \
echo       [38;5;71m  ^| ^|  [0m     [38;5;223m      ────/                  \────      [0m    [38;5;71m_^|_
echo       [38;5;71m _^| ^|_ [0m     [38;5;137m     /     │                │     \     [0m    [38;5;71m^| ^|
echo       [38;5;71m^| ^| ^| ^|[0m     [38;5;137m    │      │                │      │    [0m    [38;5;71m ^|
echo       [38;5;71m^|_^| ^|_^|[0m     [38;5;137m     /─────│────────────────│─────\
echo                   [38;5;238m       O                      O
echo(
echo(
echo [38;5;240m          ..  .   ..
echo [38;5;240m              .   .
echo(
echo [1;38;5;231m                       T H E   S U N S E T   T R A I L
echo(
echo [1;38;5;84m  %HI%,[0m [38;5;245m%USERNAME%[1;38;5;84m!   %PART%[0m%TAG%[0m
echo [38;5;223m  "%FR%"[0m
if defined COWBOY_HINT echo [38;5;242m  COWBOY_THEME=тема - сменить тему   ^|   COWBOY_BANNER=menu - меню тем[0m
goto :done

:wagon_asc
echo(
echo    *              *                                       *              *
echo            .                      =========                       .
echo                \/            ===================    *
echo        .\/                ===================*=====
echo                           =========================         -----------
echo                           =========================         /-----------\
echo      ---------             =======================          ^|           ^|
echo      /---------\               ===============              ^|           ^|
echo      ^|         ^|                                            ^|           ^|
echo ============================================================================
echo(
echo                              ------------------
echo         _^|_                 /                  \
echo         ^| ^|             ----/                  \----          _^|_
echo        _^| ^|_           /     ^|                ^|     \         ^| ^|
echo       ^| ^| ^| ^|         ^|      ^|                ^|      ^|         ^|
echo       ^|_^| ^|_^|          /-----^|----------------^|-----\
echo                          O                      O
echo(
echo(
echo           ..  .   ..
echo               .   .
echo(
echo                        T H E   S U N S E T   T R A I L
echo(
echo   %HI%, %USERNAME%!   %PARTA%%TAG%
echo   "%FE%"
if defined COWBOY_HINT echo   COWBOY_THEME=theme - switch   ^|   COWBOY_BANNER=menu - menu
goto :done

rem ===== wildwest / wire =====
:wire_dos
echo(
echo [38;5;214m   [38;5;250m*[38;5;214m              [38;5;250m*[38;5;214m                                       [38;5;250m*[38;5;214m              [38;5;250m*
echo [38;5;214m           [38;5;250m·[38;5;214m                                                      [38;5;250m·
echo [38;5;214m                                                    [38;5;250m*
echo [38;5;214m       [38;5;250m·
echo [38;5;214m                                ═════════════               ───────────
echo [38;5;214m                              ═════════════════             /───────────\
echo [38;5;214m     ─────────                ═════════════════             │           │
echo [38;5;214m     /─────────\               ═══════════════              │           │
echo [38;5;214m     │         │                                            │           │
echo [38;5;94m════════════════════════════════════════════════════════════════════════════
echo(
echo           [38;5;137m ┬ [0m                                                  [38;5;137m ┬
echo           [38;5;137m─┼─[0m                                                  [38;5;137m─┼─
echo           [38;5;137m │\[38;5;245m                                                  /│
echo           [38;5;137m │ [38;5;245m\                                                / │
echo           [38;5;137m │ [38;5;245m \______________________________________________/  │
echo           [38;5;137m │ [0m                 [38;5;71m  _^|_  [0m                          [38;5;137m │
echo           [38;5;137m │ [0m                 [38;5;71m  ^| ^|  [0m       [38;5;244m  __         __ [0m   [38;5;137m │
echo           [38;5;137m ┴ [0m                 [38;5;71m _^| ^|_ [0m       [38;5;244m/    \     /  \ [0m   [38;5;137m ┴
echo [38;5;240m                              ^| ^| ^| ^|       \____/     \__/
echo [38;5;240m                              ^|_^| ^|_^|
echo [38;5;240m                    ..   .
echo(
echo [1;38;5;231m                          T H E   L O N G   W I R E
echo(
echo [1;38;5;84m  %HI%,[0m [38;5;245m%USERNAME%[1;38;5;84m!   %PART%[0m%TAG%[0m
echo [38;5;223m  "%FR%"[0m
if defined COWBOY_HINT echo [38;5;242m  COWBOY_THEME=тема - сменить тему   ^|   COWBOY_BANNER=menu - меню тем[0m
goto :done

:wire_asc
echo(
echo    *              *                                       *              *
echo            .                                                      .
echo                                                     *
echo        .
echo                                 =============               -----------
echo                               =================             /-----------\
echo      ---------                =================             ^|           ^|
echo      /---------\               ===============              ^|           ^|
echo      ^|         ^|                                            ^|           ^|
echo ============================================================================
echo(
echo            +                                                    +
echo           -┼-                                                  -┼-
echo            ^|\                                                  /^|
echo            ^| \                                                / ^|
echo            ^|  \______________________________________________/  ^|
echo            ^|                    _^|_                             ^|
echo            ^|                    ^| ^|           __         __     ^|
echo            T                   _^| ^|_        /    \     /  \     T
echo                               ^| ^| ^| ^|       \____/     \__/
echo                               ^|_^| ^|_^|
echo                     ..   .
echo(
echo                           T H E   L O N G   W I R E
echo(
echo   %HI%, %USERNAME%!   %PARTA%%TAG%
echo   "%FE%"
if defined COWBOY_HINT echo   COWBOY_THEME=theme - switch   ^|   COWBOY_BANNER=menu - menu
goto :done

rem ===== wildwest / fire =====
:fire_dos
echo(
echo [38;5;60m  [38;5;250m*[38;5;60m             [38;5;250m*[38;5;60m                    [38;5;250m*[38;5;60m             [38;5;250m*[38;5;60m                    [38;5;250m*
echo [38;5;60m           ░░░░░              [38;5;250m·[38;5;60m                                  [38;5;250m·
echo [38;5;60m        [38;5;187m░░░░[38;5;60m [38;5;187m░░░░░░[38;5;60m                         [38;5;250m·
echo [38;5;60m        [38;5;187m░░░[38;5;60m [38;5;187m░░░░░░░[38;5;60m    [38;5;250m*[38;5;60m                                  [38;5;250m*
echo [38;5;60m        [38;5;187m░░░░░░░[38;5;60m [38;5;187m░░░[38;5;60m                                       ───────────
echo [38;5;60m      [38;5;250m·[38;5;60m  [38;5;187m░░░░░░░░░[38;5;60m                                        /───────────\
echo [38;5;60m             [38;5;250m*[38;5;60m        ─────────                           │           │
echo [38;5;60m                      /─────────\                         │           │
echo [38;5;60m                      │         │                         │           │
echo [38;5;94m════════════════════════════════════════════════════════════════════════════
echo                                         ·
echo                                     ·
echo                                   ·   ·
echo                                   [38;5;202m    ^^
echo                 [38;5;71m  _^|_  [0m           [38;5;202m   ^^^^^^
echo                 [38;5;71m  ^| ^|  [0m           [38;5;202m  ^^^^^^^^^^
echo                 [38;5;71m _^| ^|_ [0m           [38;5;202m ^^^^^^^^^^^^^^
echo                 [38;5;71m^| ^| ^| ^|[0m           [38;5;202m ███████
echo                 [38;5;71m^|_^| ^|_^|[0m          [38;5;94m \───────/
echo                                  [38;5;94m /───────\
echo [38;5;240m                              ..   .
echo(
echo(
echo [1;38;5;231m                       C A M P F I R E   A T   D U S K
echo(
echo [1;38;5;84m  %HI%,[0m [38;5;245m%USERNAME%[1;38;5;84m!   %PART%[0m%TAG%[0m
echo [38;5;223m  "%FR%"[0m
if defined COWBOY_HINT echo [38;5;242m  COWBOY_THEME=тема - сменить тему   ^|   COWBOY_BANNER=menu - меню тем[0m
goto :done

:fire_asc
echo(
echo   *             *                    *             *                    *
echo            ooooo              .                                  .
echo         oooo oooooo                         .
echo         ooo ooooooo    *                                  *
echo         ooooooo ooo                                       -----------
echo       .  ooooooooo                                        /-----------\
echo              *        ---------                           ^|           ^|
echo                       /---------\                         ^|           ^|
echo                       ^|         ^|                         ^|           ^|
echo ============================================================================
echo                                         .
echo                                     .
echo                                   .   .
echo                                       ^^
echo                   _^|_                ^^^^^^
echo                   ^| ^|               ^^^^^^^^^^
echo                  _^| ^|_             ^^^^^^^^^^^^^^
echo                 ^| ^| ^| ^|            #######
echo                 ^|_^| ^|_^|           \-------/
echo                                   /-------\
echo                               ..   .
echo(
echo(
echo                        C A M P F I R E   A T   D U S K
echo(
echo   %HI%, %USERNAME%!   %PARTA%%TAG%
echo   "%FE%"
if defined COWBOY_HINT echo   COWBOY_THEME=theme - switch   ^|   COWBOY_BANNER=menu - menu
goto :done

rem ===== wildwest / saloon =====
:saloon_dos
echo(
echo [38;5;60m  [38;5;250m*[38;5;60m             [38;5;250m*[38;5;60m                    [38;5;250m*[38;5;60m             [38;5;250m*[38;5;60m                    [38;5;250m*
echo [38;5;60m                              [38;5;250m·[38;5;60m                                  [38;5;250m·
echo [38;5;60m         [38;5;250m·[38;5;60m                                  [38;5;250m·[38;5;60m           [38;5;187m░░░░░░░░░
echo [38;5;60m                       [38;5;250m*[38;5;60m             │                  [38;5;187m░░░░░░░░░
echo [38;5;60m                                     │                  [38;5;187m░░░░░░░░░
echo [38;5;60m      [38;5;250m·[38;5;60m                              │                    [38;5;187m░░░░░[38;5;60m      [38;5;250m·
echo [38;5;60m             [38;5;250m*[38;5;60m            ┌──────────────────────┐
echo [38;5;60m                          │  S A L O O N │                   [38;5;250m·
echo [38;5;60m                          └──────────────────────┘
echo(
echo(
echo                 [38;5;137m┌──────────────────────────────────────────┐
echo                 [38;5;137m│  ███████                        ███████  │
echo                 [38;5;137m│  ███████                        ███████  │
echo                 [38;5;137m│  ███████                        ███████  │
echo                 [38;5;137m│                  \    /                  │
echo                 [38;5;137m│                   \  /                   │
echo                 [38;5;137m│                    \/                    │
echo                 [38;5;137m└──────────────────────────────────────────┘
echo                 [38;5;137m════════════════════════════════════════════
echo [38;5;240m                    ..   .   ..
echo(
echo(
echo [1;38;5;231m                T H E   L A S T   S A L O O N   I N   T O W N
echo(
echo [1;38;5;84m  %HI%,[0m [38;5;245m%USERNAME%[1;38;5;84m!   %PART%[0m%TAG%[0m
echo [38;5;223m  "%FR%"[0m
if defined COWBOY_HINT echo [38;5;242m  COWBOY_THEME=тема - сменить тему   ^|   COWBOY_BANNER=menu - меню тем[0m
goto :done

:saloon_asc
echo(
echo   *             *                    *             *                    *
echo                               .                                  .
echo          .                                  .           ooooooooo
echo                        *             ^|                  ooooooooo
echo                                      ^|                  ooooooooo
echo       .                              ^|                    ooooo      .
echo              *            +----------------------+
echo                           ^|  S A L O O N ^|                   .
echo                           +----------------------+
echo(
echo(
echo                 +------------------------------------------+
echo                 ^|  #######                        #######  ^|
echo                 ^|  #######                        #######  ^|
echo                 ^|  #######                        #######  ^|
echo                 ^|                  \    /                  ^|
echo                 ^|                   \  /                   ^|
echo                 ^|                    \/                    ^|
echo                 +------------------------------------------+
echo                 ============================================
echo                     ..   .   ..
echo(
echo(
echo                 T H E   L A S T   S A L O O N   I N   T O W N
echo(
echo   %HI%, %USERNAME%!   %PARTA%%TAG%
echo   "%FE%"
if defined COWBOY_HINT echo   COWBOY_THEME=theme - switch   ^|   COWBOY_BANNER=menu - menu
goto :done

rem ===== space / planet =====
:planet_dos
echo(
echo [38;5;17m    [38;5;250m*[38;5;17m                      [38;5;250m*[38;5;17m                        [38;5;250m*[38;5;17m                /\
echo [38;5;17m                   [38;5;250m·[38;5;17m                        [38;5;250m·[38;5;17m                     [38;5;250m·[38;5;17m /  \
echo [38;5;17m            [38;5;250m*[38;5;17m                      [38;5;250m*[38;5;17m                        [38;5;250m*[38;5;17m      ──────
echo [38;5;17m                        ─────────────────────────────              │ ░  │[38;5;250m·
echo [38;5;17m                ─────────────────────────────────────────────      │    │
echo [38;5;17m            ─────────────────────────────────────────────────────  ──────
echo [38;5;17m              ──────────────▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒──────────────     \  /
echo [38;5;17m                              ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒                  ^^
echo [38;5;17m                      ▒▒       ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒     ▒▒               ^^
echo [38;5;17m                     ▒▒▒▒     ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
echo [38;5;17m                     ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
echo [38;5;17m                     ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒       ▒▒▒▒▒▒▒
echo [38;5;17m                     ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒         ▒▒▒▒▒▒
echo [38;5;17m                      ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒       ▒▒▒▒▒▒
echo [38;5;17m                         ▒▒▒▒▒▒▒     ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
echo [38;5;17m            ─────────────────────────────────────────────────────
echo [38;5;17m                ─────────────────────────────────────────────
echo [38;5;17m                        ─────────────────────────────
echo [38;5;17m       ░░░░░
echo [38;5;17m     ░░░░░░░░░
echo [38;5;17m    ░░░░░░░░░░░
echo [38;5;17m     ░░░░░░░░░
echo [38;5;17m       ░░░░░
echo [1;38;5;231m                        O R B I T   O F   F A M I L Y
echo(
echo [1;38;5;84m  %HI%,[0m [38;5;245m%USERNAME%[1;38;5;84m!   %PART%[0m%TAG%[0m
echo [38;5;223m  "%FR%"[0m
if defined COWBOY_HINT echo [38;5;242m  COWBOY_THEME=тема - сменить тему   ^|   COWBOY_BANNER=menu - меню тем[0m
goto :done

:planet_asc
echo(
echo     *                      *                        *                /\
echo                    .                        .                     . /  \
echo             *                      *                        *      ------
echo                         -----------------------------              ^| o  ^|.
echo                 ---------------------------------------------      ^|    ^|
echo             -----------------------------------------------------  ------
echo               --------------:::::::::::::::::::::--------------     \  /
echo                               ::::::::::::::::::::::                  ^^
echo                       ::       :::::::::::::::::     ::               ^^
echo                      ::::     ::::::::::::::::::::::::::
echo                      :::::::::::::::::::::::::::::::::::
echo                      :::::::::::::::::::::       :::::::
echo                      ::::::::::::::::::::         ::::::
echo                       ::::::::::::::::::::       ::::::
echo                          :::::::     :::::::::::::::
echo             -----------------------------------------------------
echo                 ---------------------------------------------
echo                         -----------------------------
echo        ooooo
echo      ooooooooo
echo     ooooooooooo
echo      ooooooooo
echo        ooooo
echo                         O R B I T   O F   F A M I L Y
echo(
echo   %HI%, %USERNAME%!   %PARTA%%TAG%
echo   "%FE%"
if defined COWBOY_HINT echo   COWBOY_THEME=theme - switch   ^|   COWBOY_BANNER=menu - menu
goto :done

rem ===== space / satellite =====
:satellite_dos
echo(
echo [38;5;17m  [38;5;250m*[38;5;17m            [38;5;250m*[38;5;17m                                       [38;5;250m*[38;5;17m              [38;5;250m*
echo [38;5;17m                      [38;5;250m·[38;5;17m                [38;5;250m·[38;5;17m       [38;5;250m·
echo [38;5;17m         [38;5;250m*[38;5;17m                                                     [38;5;250m*
echo [38;5;17m                              [38;5;250m·[38;5;17m                                           [38;5;250m·
echo(
echo [38;5;17m                      ┌─────────┐ ┌──────┐┌──────────┐
echo [38;5;17m                      │─────────│ │      ││──────────│
echo [38;5;17m                      │[38;5;250m·········[38;5;17m│ │░░░░░░││[38;5;250m··········[38;5;17m│
echo [38;5;17m                      │─────────│ │      ││──────────│
echo [38;5;17m                      │[38;5;250m·········[38;5;17m│ │  [38;5;250m·[38;5;17m   ││[38;5;250m··········[38;5;17m│
echo [38;5;17m                      └─────────┘ │      │└──────────┘
echo [38;5;17m                                  └──────┘
echo [38;5;17m                                     /\
echo [38;5;17m                                    /  \
echo [38;5;17m                     ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
echo [38;5;17m              ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
echo [38;5;17m         ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
echo [38;5;17m     ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
echo [38;5;17m  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
echo [38;5;17m▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
echo [38;5;17m▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
echo [38;5;17m▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
echo [38;5;17m▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
echo [1;38;5;231m                     D E E P   S P A C E   N E T W O R K
echo(
echo [1;38;5;84m  %HI%,[0m [38;5;245m%USERNAME%[1;38;5;84m!   %PART%[0m%TAG%[0m
echo [38;5;223m  "%FR%"[0m
if defined COWBOY_HINT echo [38;5;242m  COWBOY_THEME=тема - сменить тему   ^|   COWBOY_BANNER=menu - меню тем[0m
goto :done

:satellite_asc
echo(
echo   *            *                                       *              *
echo                       .                .       .
echo          *                                                     *
echo                               .                                           .
echo(
echo                       +---------+ +------++----------+
echo                       ^|---------^| ^|      ^|^|----------^|
echo                       ^|---------^| ^|oooooo^|^|----------^|
echo                       ^|---------^| ^|      ^|^|----------^|
echo                       ^|---------^| ^|  .   ^|^|----------^|
echo                       +---------+ ^|      ^|+----------+
echo                                   +------+
echo                                      /\
echo                                     /  \
echo                      :::::::::::::::::::::::::::::::::::
echo               :::::::::::::::::::::::::::::::::::::::::::::::::
echo          :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
echo      :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
echo   :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
echo ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
echo ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
echo ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
echo ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
echo                      D E E P   S P A C E   N E T W O R K
echo(
echo   %HI%, %USERNAME%!   %PARTA%%TAG%
echo   "%FE%"
if defined COWBOY_HINT echo   COWBOY_THEME=theme - switch   ^|   COWBOY_BANNER=menu - menu
goto :done

rem ===== cyber / city =====
:city_dos
echo(
echo [38;5;17m            [38;5;250m*[38;5;17m                                 [38;5;250m*
echo [38;5;17m     [38;5;250m*[38;5;17m                                                     ░░░░░░░░░      [38;5;250m*
echo [38;5;17m                    [38;5;250m*[38;5;17m      [38;5;67m\[38;5;17m                      [38;5;250m*[38;5;17m       ░░░░░░░░░░░
echo [38;5;17m       [38;5;67m\[38;5;17m                    [38;5;67m\[38;5;17m                             ░░░░░░░░░░[38;5;67m\
echo [38;5;17m        [38;5;67m\[38;5;17m                                        [38;5;67m\[38;5;17m         ░░░░░░░░░ [38;5;67m\
echo [38;5;17m                  [38;5;67m\[38;5;17m                               [38;5;67m\
echo [38;5;17m                   [38;5;67m\[38;5;17m                 [38;5;67m\
echo [38;5;17m                              ┌────────────┐              [38;5;67m\
echo [38;5;17m                              │ N E O N  │                 [38;5;67m\[38;5;17m            [38;5;67m\
echo [38;5;17m                              └────────────┘             ────────        [38;5;67m\
echo [38;5;17m              ─────────                                  │      │
echo [38;5;17m              │       │                                  │      │
echo [38;5;17m   ────────── │       │                                  │      │
echo [38;5;17m   │        │ │       │                       ────────── │      │
echo [38;5;17m   │        │ │ [38;5;220m▒[38;5;17m  [38;5;220m▒[38;5;17m  │                       │        │ │      │───────────
echo [38;5;17m   │        │ │       │                       │        │ │ [38;5;220m▒[38;5;17m  [38;5;220m▒[38;5;17m ││         │
echo [38;5;17m   │ [38;5;220m▒[38;5;17m  [38;5;220m▒[38;5;17m  [38;5;220m▒[38;5;17m│ │       │                       │        │ │      ││         │
echo [38;5;17m   │        │ │       │                       │        │ │      ││         │
echo [38;5;17m   │        │ │       │   ────────            │        │ │      ││ [38;5;220m▒[38;5;17m  [38;5;220m▒[38;5;17m  [38;5;220m▒[38;5;17m │
echo [38;5;17m   ────────── ─────────   ────────            ────────── ───────────────────
echo(
echo(
echo(
echo [1;38;5;231m                             N E O N   N I G H T
echo(
echo [1;38;5;84m  %HI%,[0m [38;5;245m%USERNAME%[1;38;5;84m!   %PART%[0m%TAG%[0m
echo [38;5;223m  "%FR%"[0m
if defined COWBOY_HINT echo [38;5;242m  COWBOY_THEME=тема - сменить тему   ^|   COWBOY_BANNER=menu - меню тем[0m
goto :done

:city_asc
echo(
echo             *                                 *
echo      *                                                     ooooooooo      *
echo                     *      \                      *       ooooooooooo
echo        \                    \                             oooooooooo\
echo         \                                        \         ooooooooo \
echo                   \                               \
echo                    \                 \
echo                               +------------+              \
echo                               ^| N E O N  ^|                 \            \
echo                               +------------+             --------        \
echo               ---------                                  ^|      ^|
echo               ^|       ^|                                  ^|      ^|
echo    ---------- ^|       ^|                                  ^|      ^|
echo    ^|        ^| ^|       ^|                       ---------- ^|      ^|
echo    ^|        ^| ^| #  #  ^|                       ^|        ^| ^|      ^|-----------
echo    ^|        ^| ^|       ^|                       ^|        ^| ^| #  # ^|^|         ^|
echo    ^| #  #  #^| ^|       ^|                       ^|        ^| ^|      ^|^|         ^|
echo    ^|        ^| ^|       ^|                       ^|        ^| ^|      ^|^|         ^|
echo    ^|        ^| ^|       ^|   --------            ^|        ^| ^|      ^|^| #  #  # ^|
echo    ---------- ---------   --------            ---------- -------------------
echo(
echo(
echo(
echo                              N E O N   N I G H T
echo(
echo   %HI%, %USERNAME%!   %PARTA%%TAG%
echo   "%FE%"
if defined COWBOY_HINT echo   COWBOY_THEME=theme - switch   ^|   COWBOY_BANNER=menu - menu
goto :done

rem ===== cyber / matrix =====
:matrix_dos
echo(
echo [38;5;17m [38;5;120m█[38;5;17m                                         [38;5;120m█[38;5;17m                             [38;5;120m█
echo [38;5;17m ·                                         [38;5;29m1[38;5;17m  [38;5;120m█[38;5;17m                       [38;5;120m█[38;5;17m  e
echo [38;5;17m 9                 [38;5;120m█[38;5;17m                       ·  ·  [38;5;120m█[38;5;17m        [38;5;120m█[38;5;17m           c  d
echo [38;5;17m [38;5;29m4[38;5;17m     [38;5;120m█[38;5;17m           5     [38;5;120m█[38;5;17m        [38;5;120m█[38;5;17m        6  c  c  [38;5;120m█[38;5;17m     ·           5  ·
echo [38;5;17m 5     ·        [38;5;120m█[38;5;17m  ·  [38;5;120m█[38;5;17m  [38;5;29mf[38;5;17m     [38;5;120m█[38;5;17m  e     [38;5;120m█[38;5;17m  5  [38;5;29m7[38;5;17m  ·  b     [38;5;29m4[38;5;17m           ·  c
echo [38;5;17m    [38;5;120m█[38;5;17m  [38;5;29m0[38;5;17m     [38;5;120m█[38;5;17m  ·  [38;5;29m7[38;5;17m  [38;5;29m7[38;5;17m  [38;5;29m1[38;5;17m     [38;5;29ma[38;5;17m  6     [38;5;29m7[38;5;17m  e  [38;5;29m0[38;5;17m  3  [38;5;29m0[38;5;17m     [38;5;29m1[38;5;17m           ·  [38;5;29m4
echo [38;5;17m    e  9     ·  3  ·  ·  [38;5;29m4[38;5;17m     [38;5;29m7[38;5;17m  [38;5;29m0[38;5;17m  [38;5;120m█[38;5;17m  [38;5;29mf[38;5;17m  ·  5  6  [38;5;29ma[38;5;17m  [38;5;120m█[38;5;17m        [38;5;120m█[38;5;17m     b  2
echo [38;5;17m    [38;5;29m7[38;5;17m  6  [38;5;120m█[38;5;17m  [38;5;29m0[38;5;17m  5  c  [38;5;29m0[38;5;17m  ·  [38;5;120m█[38;5;17m  [38;5;29m7[38;5;17m  ·  [38;5;29ma[38;5;17m  [38;5;29m7[38;5;17m     ·  ·  [38;5;29ma[38;5;17m  [38;5;29m1[38;5;17m     [38;5;120m█[38;5;17m  e  [38;5;120m█[38;5;17m  b  9
echo [38;5;17m    6  [38;5;29m1[38;5;17m  ·  c  6  ·  9  [38;5;29m0[38;5;17m  9  [38;5;29mf[38;5;17m  ·  2  ·     e  d  ·  [38;5;29m0[38;5;17m     [38;5;29ma[38;5;17m  [38;5;29mf[38;5;17m  [38;5;29ma[38;5;17m  c  6
echo [38;5;17m    ·  b  [38;5;29m0[38;5;17m  b  ·        [38;5;29m4[38;5;17m  ·  c  [38;5;29m7[38;5;17m  ·  ·     [38;5;29mf[38;5;17m  e  2  b     c  6  6  ·
echo [38;5;17m┌·········································································┐
echo [38;5;17m│ ^> ·[38;5;29m0[38;5;17mxDEADBEEF[38;5;120m█[38;5;17md        ·  [38;5;29m4[38;5;17m     ·  b        3  ·  ·  ·     [38;5;29m0[38;5;17m  ·  [38;5;29m7[38;5;17m      │
echo [38;5;17m└─────────────────────────────────────────────────────────────────────────┘
echo [38;5;17m    ·     [38;5;29m7[38;5;17m  9  ·           ·        ·           [38;5;29m0[38;5;17m  ·        ·  ·  b
echo [38;5;17m    ·     [38;5;29mf[38;5;17m  e  6                    [38;5;29m4[38;5;17m              [38;5;29ma[38;5;17m        ·  5  ·
echo [38;5;17m    ·        5  [38;5;29m4[38;5;17m                    [38;5;29m0[38;5;17m              2        [38;5;29m4[38;5;17m  [38;5;29m4[38;5;17m  ·
echo [38;5;17m    3        3  [38;5;29m1[38;5;17m                    ·              [38;5;29m0[38;5;17m        2     e
echo [38;5;17m    ·        9  [38;5;29m1[38;5;17m                    ·              d        [38;5;29m0[38;5;17m     ·
echo [38;5;17m             [38;5;29m7[38;5;17m                       [38;5;29ma[38;5;17m                             [38;5;29m0
echo [38;5;17m             ·                       ·                             9
echo [38;5;17m                                                                   ·
echo(
echo(
echo [1;38;5;231m                     G H O S T   I N   T H E   S H E L L
echo(
echo [1;38;5;84m  %HI%,[0m [38;5;245m%USERNAME%[1;38;5;84m!   %PART%[0m%TAG%[0m
echo [38;5;223m  "%FR%"[0m
if defined COWBOY_HINT echo [38;5;242m  COWBOY_THEME=тема - сменить тему   ^|   COWBOY_BANNER=menu - меню тем[0m
goto :done

:matrix_asc
echo(
echo  #                                         #                             #
echo  .                                         1  #                       #  e
echo  9                 #                       .  .  #        #           c  d
echo  4     #           5     #        #        6  c  c  #     .           5  .
echo  5     .        #  .  #  f     #  e     #  5  7  .  b     4           .  c
echo     #  0     #  .  7  7  1     a  6     7  e  0  3  0     1           .  4
echo     e  9     .  3  .  .  4     7  0  #  f  .  5  6  a  #        #     b  2
echo     7  6  #  0  5  c  0  .  #  7  .  a  7     .  .  a  1     #  e  #  b  9
echo     6  1  .  c  6  .  9  0  9  f  .  2  .     e  d  .  0     a  f  a  c  6
echo     .  b  0  b  .        4  .  c  7  .  .     f  e  2  b     c  6  6  .
echo +-------------------------------------------------------------------------+
echo ^| ^> .0xDEADBEEF#d        .  4     .  b        3  .  .  .     0  .  7      ^|
echo +-------------------------------------------------------------------------+
echo     .     7  9  .           .        .           0  .        .  .  b
echo     .     f  e  6                    4              a        .  5  .
echo     .        5  4                    0              2        4  4  .
echo     3        3  1                    .              0        2     e
echo     .        9  1                    .              d        0     .
echo              7                       a                             0
echo              .                       .                             9
echo                                                                    .
echo(
echo(
echo                      G H O S T   I N   T H E   S H E L L
echo(
echo   %HI%, %USERNAME%!   %PARTA%%TAG%
echo   "%FE%"
if defined COWBOY_HINT echo   COWBOY_THEME=theme - switch   ^|   COWBOY_BANNER=menu - menu
goto :done

rem ===== ocean / submarine =====
:submarine_dos
echo(
echo [38;5;19m────────────────────────────────────────────────────────────────────────────
echo [38;5;19m ┌  ┐  ┌  ┐  ┌  ┐  ┌  ┐  ┌  ┐  ┌  ┐  ┌  ┐  ┌  ┐  ┌  ┐  ┌  ┐  ┌  ┐  ┌  ┐
echo [38;5;19m────────────────────────────────────────────────────────────────────────────
echo [38;5;19m         [38;5;37m/[38;5;19m              [38;5;37m/[38;5;19m                   [38;5;37m/[38;5;19m             [38;5;37m/[38;5;19m          [38;5;37m/
echo [38;5;19m          [38;5;37m/[38;5;19m              [38;5;37m/[38;5;19m           ───     [38;5;37m/[38;5;19m             [38;5;37m/[38;5;19m          [38;5;37m/
echo [38;5;19m           [38;5;37m/[38;5;19m    \│[38;5;37m/[38;5;19m       [38;5;37m/[38;5;19m           │       [38;5;37m/[38;5;19m             [38;5;37m/[38;5;19m       \│[38;5;37m//
echo [38;5;19m        [38;5;159mo[38;5;19m   [38;5;37m/[38;5;19m              [38;5;37m/[38;5;19m      ┌───────┐    [38;5;37m/[38;5;19m             [38;5;37m/[38;5;19m          [38;5;37m/
echo [38;5;19m             [38;5;37m/[38;5;19m              [38;5;37m/[38;5;19m     │       │     [38;5;37m/[38;5;19m             [38;5;37m/[38;5;19m   [38;5;159mo
echo [38;5;19m              [38;5;37m/[38;5;19m    [38;5;159mo[38;5;19m         [38;5;37m/[38;5;19m   ┌─────────┐                   [38;5;37m/
echo [38;5;19m            [38;5;159mo[38;5;19m                 [38;5;37m/[38;5;19m  │         │                    \│[38;5;37m/
echo [38;5;19m                      /─────────────────────────────────\ /\
echo [38;5;19m                      │─────────────────────────────────│─  │         [38;5;159mo
echo [38;5;19m                      │    [38;5;220mo[38;5;19m       [38;5;220mo[38;5;19m       [38;5;220mo[38;5;19m       [38;5;220mo[38;5;19m    │ \/
echo [38;5;19m      [38;5;159mo[38;5;19m               │─────────────────────────────────│        [38;5;159mo
echo [38;5;19m                       └───────────────────────────────┘
echo [38;5;19m                              ─────         ─────
echo(
echo(
echo [38;5;19m              │                                                    │
echo [38;5;19m      │       /                                           │        /
echo [38;5;19m      /       │                                           /        │
echo [38;5;19m      │       /                                           │        /
echo [38;5;19m      /       │                                           /        │
echo [1;38;5;231m                             D E E P   W A T E R
echo(
echo [1;38;5;84m  %HI%,[0m [38;5;245m%USERNAME%[1;38;5;84m!   %PART%[0m%TAG%[0m
echo [38;5;223m  "%FR%"[0m
if defined COWBOY_HINT echo [38;5;242m  COWBOY_THEME=тема - сменить тему   ^|   COWBOY_BANNER=menu - меню тем[0m
goto :done

:submarine_asc
echo(
echo ----------------------------------------------------------------------------
echo  +  +  +  +  +  +  +  +  +  +  +  +  +  +  +  +  +  +  +  +  +  +  +  +
echo ----------------------------------------------------------------------------
echo          /              /                   /             /          /
echo           /              /           ---     /             /          /
echo            /    \^|/       /           ^|       /             /       \^|//
echo         o   /              /      +-------+    /             /          /
echo              /              /     ^|       ^|     /             /   o
echo               /    o         /   +---------+                   /
echo             o                 /  ^|         ^|                    \^|/
echo                       /---------------------------------\ /\
echo                       ^|---------------------------------^|-  ^|         o
echo                       ^|    o       o       o       o    ^| \/
echo       o               ^|---------------------------------^|        o
echo                        +-------------------------------+
echo                               -----         -----
echo(
echo(
echo               ^|                                                    ^|
echo       ^|       /                                           ^|        /
echo       /       ^|                                           /        ^|
echo       ^|       /                                           ^|        /
echo       /       ^|                                           /        ^|
echo                              D E E P   W A T E R
echo(
echo   %HI%, %USERNAME%!   %PARTA%%TAG%
echo   "%FE%"
if defined COWBOY_HINT echo   COWBOY_THEME=theme - switch   ^|   COWBOY_BANNER=menu - menu
goto :done

rem ===== ocean / whale =====
:whale_dos
echo(
echo [38;5;19m──────────│─────────────────────────────────────────────────────────────────
echo [38;5;19m  ┌   ┐  / \ ┐  ┌   ┐  ┌   ┐  ┌   ┐  ┌   ┐  ┌   ┐  ┌   ┐  ┌   ┐  ┌   ┐
echo [38;5;19m────────────────────────────────────────────────────────────────────────────
echo [38;5;19m       \     [38;5;37m/[38;5;19m    [38;5;37m/[38;5;19m               [38;5;37m/[38;5;19m               [38;5;37m/[38;5;19m             [38;5;37m/
echo [38;5;19m                   [38;5;37m/[38;5;19m          o    [38;5;37m/[38;5;19m               [38;5;37m/[38;5;19m             [38;5;37m/
echo [38;5;19m                    [38;5;37m/[38;5;19m            o  [38;5;37m/[38;5;19m               [38;5;37m/[38;5;19m             [38;5;37m/
echo [38;5;19m                     [38;5;37m/[38;5;19m      o        [38;5;37m/[38;5;19m               [38;5;37m/[38;5;19m            \│[38;5;37m/
echo [38;5;19m        \│[38;5;37m/[38;5;19m           [38;5;37m/[38;5;19m               [38;5;37m/[38;5;19m       o       [38;5;37m/
echo [38;5;19m                       [38;5;37m/[38;5;19m   o                           [38;5;37m/
echo [38;5;19m                                                        /
echo(
echo [38;5;19m                      █████████████████████                            \│/
echo [38;5;19m      \│/       █████████████████████████████████     ████████████
echo [38;5;19m             ███████████████████████████████████████████████████████
echo [38;5;19m           ██████████████████████████████████████████████
echo [38;5;19m          ██████ ████████████████████████████████████████
echo [38;5;19m           ██████████████████████████████████████████████
echo [38;5;19m             ███████████████████████████████████████████████████████
echo [38;5;19m                █████████████████████████████████     ████████████
echo [38;5;19m            │         ████/██████\█████████                           │
echo [38;5;19m     │      /              ██████                             │       /
echo [38;5;19m     /      │                                                 /       │
echo [38;5;19m     │      /                                                 │       /
echo [1;38;5;231m                S O M E W H E R E   A B O V E   T H E   S E A
echo(
echo [1;38;5;84m  %HI%,[0m [38;5;245m%USERNAME%[1;38;5;84m!   %PART%[0m%TAG%[0m
echo [38;5;223m  "%FR%"[0m
if defined COWBOY_HINT echo [38;5;242m  COWBOY_THEME=тема - сменить тему   ^|   COWBOY_BANNER=menu - меню тем[0m
goto :done

:whale_asc
echo(
echo ----------^|-----------------------------------------------------------------
echo   +   +  / \ +  +   +  +   +  +   +  +   +  +   +  +   +  +   +  +   +
echo ----------------------------------------------------------------------------
echo        \     /    /               /               /             /
echo                    /          o    /               /             /
echo                     /            o  /               /             /
echo                      /      o        /               /            \^|/
echo         \^|/           /               /       o       /
echo                        /   o                           /
echo                                                         /
echo(
echo                       #####################                            \^|/
echo       \^|/       #################################     ############
echo              #######################################################
echo            ##############################################
echo           ###### ########################################
echo            ##############################################
echo              #######################################################
echo                 #################################     ############
echo             ^|         ####/######\#########                           ^|
echo      ^|      /              ######                             ^|       /
echo      /      ^|                                                 /       ^|
echo      ^|      /                                                 ^|       /
echo                 S O M E W H E R E   A B O V E   T H E   S E A
echo(
echo   %HI%, %USERNAME%!   %PARTA%%TAG%
echo   "%FE%"
if defined COWBOY_HINT echo   COWBOY_THEME=theme - switch   ^|   COWBOY_BANNER=menu - menu
goto :done

:done
endlocal
goto :eof
