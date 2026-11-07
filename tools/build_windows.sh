#!/usr/bin/env bash
# Собирает build/PsychoUniverse.exe. Нужны Godot 4.3 и шаблоны экспорта 4.3
# (в редакторе: Editor → Manage Export Templates → Download and Install).
# GODOT=/путь/к/Godot ./tools/build_windows.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
mkdir -p build
"$GODOT" --headless --import
"$GODOT" --headless --export-release Windows build/PsychoUniverse.exe
echo "Готово: build/PsychoUniverse.exe"
