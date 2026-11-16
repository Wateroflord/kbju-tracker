#!/bin/bash
# Движок Stockfish для плагина «Шахматы».
#   fetch   — скачать (на Android-сборке — arm64 для телефона, на Windows — exe) в tools/sf-bin/
#   install — после сборки Windows положить stockfish.exe рядом с программой
# На Android файл из tools/sf-bin/ кладёт в jniLibs скрипт tools/patch_android.py.
set -e
case "$1" in
  fetch)
    names=$(gh release view -R official-stockfish/Stockfish --json assets -q '.assets[].name')
    mkdir -p sf tools/sf-bin
    if [ "$RUNNER_OS" = "Windows" ]; then
      f=$(echo "$names" | grep -E '^stockfish-windows-x86-64' | head -1)
      echo "Stockfish: $f"
      gh release download -R official-stockfish/Stockfish -p "$f" -D sf
      (cd sf && { unzip -q "$f" 2>/dev/null || tar -xf "$f"; })
      bin=$(find sf -type f -name 'stockfish*.exe' -size +1M | head -1)
      cp "$bin" tools/sf-bin/stockfish.exe
      lic=$(find sf -iname 'copying*' | head -1); [ -n "$lic" ] && cp "$lic" tools/sf-bin/Stockfish-LICENSE.txt || true
    else
      f=$(echo "$names" | grep -E '^stockfish-android-(arm64|armv8)' | grep -v dotprod | head -1)
      echo "Stockfish: $f"
      gh release download -R official-stockfish/Stockfish -p "$f" -D sf
      (cd sf && { tar -xf "$f" 2>/dev/null || unzip -q "$f"; })
      bin=$(find sf -type f -name 'stockfish*' ! -name '*.tar*' ! -name '*.zip' ! -name '*.txt' ! -name '*.md' -size +1M | head -1)
      cp "$bin" tools/sf-bin/libstockfish.so
    fi
    rm -rf sf
    ls -la tools/sf-bin
    ;;
  install)
    cp tools/sf-bin/stockfish.exe build/windows/x64/runner/Release/
    [ -f tools/sf-bin/Stockfish-LICENSE.txt ] && cp tools/sf-bin/Stockfish-LICENSE.txt build/windows/x64/runner/Release/ || true
    ;;
esac
