#!/bin/bash
# Движок Stockfish для плагина «Шахматы».
#   fetch   — Android: собрать arm64 из исходников БЕЗ встроенной нейросети (~1–2 МБ вместо 76 МБ);
#             Windows: скачать официальный exe. Результат — в tools/sf-bin/
#   install — после сборки Windows положить stockfish.exe рядом с программой
# На Android файл из tools/sf-bin/ кладёт в jniLibs скрипт tools/patch_android.py.
#
# Нейросети (данные, ~75 МБ) не входят в APK: приложение скачивает их один раз при первом
# открытии шахмат из релиза stockfish-nets этого репозитория (скрипт сам их туда выкладывает).
# Скачать саму программу нельзя — Android 10+ не даёт запускать скачанные программы.
set -e
NETS_TAG=stockfish-nets

build_android() {
  local ndk="${ANDROID_NDK_LATEST_HOME:-$ANDROID_NDK_HOME}"
  [ -n "$ndk" ] && [ -d "$ndk" ] || { echo "Android NDK не найден"; return 1; }
  export PATH="$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH"
  local tag dir
  tag=$(gh release view -R official-stockfish/Stockfish --json tagName -q .tagName) || return 1
  echo "Stockfish $tag: собираю из исходников без встроенной нейросети"
  rm -rf sf-src && mkdir -p sf-src
  gh release download "$tag" -R official-stockfish/Stockfish --archive=tar.gz -O sf-src/src.tar.gz || return 1
  tar -xzf sf-src/src.tar.gz -C sf-src || return 1
  dir=$(find sf-src -mindepth 2 -maxdepth 2 -type d -name src | head -1)
  [ -n "$dir" ] || { echo "нет папки src в исходниках"; return 1; }
  if ! (cd "$dir" && make -j"$(nproc)" build ARCH=armv8 COMP=ndk EXTRACXXFLAGS=-DNNUE_EMBEDDING_OFF > build.log 2>&1); then
    tail -40 "$dir/build.log"; return 1
  fi
  llvm-strip "$dir/stockfish" 2>/dev/null || true
  ls "$dir"/nn-*.nnue >/dev/null 2>&1 || { echo "нейросети не скачались при сборке"; return 1; }
  cp "$dir/stockfish" tools/sf-bin/libstockfish.so
  # x86_64 — для эмуляторов и планшетов на Intel (не обязательно: не собралось — играет встроенный бот).
  if (cd "$dir" && make clean >/dev/null 2>&1 && make -j"$(nproc)" build ARCH=x86-64 COMP=ndk EXTRACXXFLAGS=-DNNUE_EMBEDDING_OFF > build-x86.log 2>&1); then
    mkdir -p tools/sf-bin/x86_64
    llvm-strip "$dir/stockfish" 2>/dev/null || true
    cp "$dir/stockfish" tools/sf-bin/x86_64/libstockfish.so
    echo "Stockfish x86_64: $(du -h tools/sf-bin/x86_64/libstockfish.so | cut -f1)"
  else
    echo "Stockfish x86_64 не собрался (не страшно):"; tail -5 "$dir/build-x86.log"
  fi
  cp "$dir/../Copying.txt" tools/sf-bin/Stockfish-LICENSE.txt 2>/dev/null || true
  publish_nets "$dir"/nn-*.nnue || return 1
  rm -rf sf-src
}

# Выложить нейросети в релиз stockfish-nets (один раз; пометка «предварительный» — чтобы
# он никогда не считался «последним» релизом и не мешал хабу).
publish_nets() {
  local repo="${GITHUB_REPOSITORY:-Wateroflord/kbju-tracker}" have n
  if ! gh release view "$NETS_TAG" -R "$repo" >/dev/null 2>&1; then
    gh release create "$NETS_TAG" -R "$repo" --prerelease --target "${GITHUB_SHA:-main}" \
      --title "Stockfish: нейросети для шахмат" \
      --notes "Нейросети движка Stockfish (GPL-3.0, github.com/official-stockfish/Stockfish). Шахматы в КБЖУ Трекере скачивают их один раз при первом открытии." || return 1
  fi
  have=$(gh release view "$NETS_TAG" -R "$repo" --json assets -q '.assets[].name')
  for n in "$@"; do
    if echo "$have" | grep -qx "$(basename "$n")"; then echo "нейросеть $(basename "$n") уже в релизе"
    else gh release upload "$NETS_TAG" -R "$repo" "$n" || return 1; echo "нейросеть $(basename "$n") выложена"; fi
  done
}

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
    elif build_android; then
      echo "Stockfish для Android собран: $(du -h tools/sf-bin/libstockfish.so | cut -f1)"
    else
      echo "::warning title=Stockfish::Не удалось собрать Stockfish без нейросети — кладу официальный (76 МБ)."
      echo "Файлы Stockfish для Android:"; echo "$names" | grep android || true
      # Обычная сборка armv8 (работает на всех 64-битных телефонах) — меньше «universal»,
      # где внутри сразу две программы. Если её нет — берём то, что есть.
      f=$(echo "$names" | grep -E '^stockfish-android-armv8\.(tar|zip)' | head -1)
      [ -n "$f" ] || f=$(echo "$names" | grep -E '^stockfish-android-(arm64|armv8)' | grep -v -E 'dotprod|universal' | head -1)
      [ -n "$f" ] || f=$(echo "$names" | grep -E '^stockfish-android-(arm64|armv8)' | grep -v dotprod | head -1)
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
