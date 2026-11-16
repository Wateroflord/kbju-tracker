#!/bin/bash
# Проверка супер-приложения на эмуляторе: запуск, шторка, экран плагинов, переключение в плагин и обратно.
# Скриншоты и журнал — в out/.
set +e
APK=$1
PKG=com.kbju.kbju_tracker
UI="python3 tools/smoke/ui.py"
mkdir -p out
shot() { sleep "${2:-3}"; adb exec-out screencap -p > "out/$1.png"; adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1; adb shell cat /sdcard/ui.xml > "out/$1.xml"; echo "--- $1"; }
step() { echo "$1" >> out/steps.txt; }

adb install -r "$APK" > out/install.txt 2>&1 || { step "install FAIL"; cat out/install.txt; exit 1; }
adb logcat -c
adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
shot 01_start 25
[ -n "$(adb shell pidof $PKG)" ] && step "start OK" || step "start FAIL"

$UI tap "Plugins" && step "handle OK" || step "handle FAIL"
shot 02_drawer
$UI has "Macro Tracker" && step "drawer shows KBJU OK" || step "drawer shows KBJU FAIL"

$UI tap "Turn on and off" && step "manage OK" || step "manage FAIL"
shot 03_plugins
ALL=("Expiry" "Winter Language" "Chess" "Minesweeper" "Winter Music" "Winter Paint" "Drawing lessons" "Winter Walks" "Forest survival" "Mog Battle")
for p in "${ALL[@]}"; do $UI tapscroll "$p" && step "toggle $p OK" || step "toggle $p FAIL"; sleep 1; done
shot 04_plugins_on 2
adb shell input keyevent 4
shot 05_back 2

n=0
for p in "${ALL[@]}"; do
  n=$((n+1))
  $UI tap "Plugins" >/dev/null; sleep 2
  $UI tap "$p" && step "open $p OK" || step "open $p FAIL"
  shot "06_${n}_${p// /_}" 8
  if [ -z "$(adb shell pidof $PKG)" ]; then
    step "$p alive FAIL (crash)"
    adb logcat -d -s AndroidRuntime:E flutter:E > "out/crash_${n}.txt"
    adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; sleep 15
  else
    step "$p alive OK"
  fi
  # закрыть разрешения/диалоги, если открылись (например, геолокация)
  $UI tap "Don’t allow" >/dev/null 2>&1 || $UI tap "Don't allow" >/dev/null 2>&1 || true
done
# вернуться в «Сапёр», чтобы проверить «Назад»
$UI tap "Plugins" >/dev/null; sleep 2; $UI tap "Minesweeper" >/dev/null; sleep 4

# «Назад» на главном экране плагина — обратно в КБЖУ (шторка уже закрыта).
adb shell input keyevent 4
shot 07_back_to_kbju 4
[ -n "$(adb shell pidof $PKG)" ] && step "back keeps app OK" || step "back keeps app FAIL"
$UI has "Male" && step "back returns to KBJU OK" || step "back returns to KBJU FAIL"
$UI tap "Plugins" >/dev/null; sleep 2
shot 08_drawer_after 2

adb logcat -d -s AndroidRuntime:E flutter:E flutter:W > out/logcat.txt
cat out/steps.txt
grep -q FAIL out/steps.txt && exit 1 || exit 0
