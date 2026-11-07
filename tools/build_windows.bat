@echo off
rem Сборка build\PsychoUniverse.exe на Windows.
rem Укажи путь к Godot 4.3, если он не лежит рядом: set GODOT=C:\Godot\Godot_v4.3-stable_win64.exe
rem Шаблоны экспорта ставятся один раз в редакторе: Editor -> Manage Export Templates -> Download and Install.
cd /d "%~dp0\.."
if "%GODOT%"=="" set GODOT=Godot_v4.3-stable_win64_console.exe
if not exist build mkdir build
"%GODOT%" --headless --import
"%GODOT%" --headless --export-release Windows build\PsychoUniverse.exe
echo Готово: build\PsychoUniverse.exe
pause
