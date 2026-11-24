"""Помощник для проверки на эмуляторе: найти элемент на экране по тексту и нажать на него.

python3 ui.py tap "Шахматы"      — нажать на первый элемент с таким текстом/описанием
python3 ui.py has "Плагины"      — код 0, если элемент есть на экране
"""
import re
import subprocess
import sys
import time


def dump():
    for _ in range(3):
        subprocess.run(["adb", "shell", "uiautomator", "dump", "/sdcard/ui.xml"], capture_output=True)
        r = subprocess.run(["adb", "shell", "cat", "/sdcard/ui.xml"], capture_output=True, text=True)
        if "<hierarchy" in r.stdout:
            return r.stdout
        time.sleep(1)
    return ""


def find(xml, needle):
    for m in re.finditer(r"<node [^>]*>", xml):
        n = m.group(0)
        text = (re.search(r' text="([^"]*)"', n) or [None, ""])[1]
        desc = (re.search(r' content-desc="([^"]*)"', n) or [None, ""])[1]
        hint = (re.search(r' hint="([^"]*)"', n) or [None, ""])[1]  # подписи полей ввода
        if needle in text or needle in desc or needle in hint:
            b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', n)
            if b:
                x1, y1, x2, y2 = map(int, b.groups())
                return (x1 + x2) // 2, (y1 + y2) // 2
    return None


cmd, needle = sys.argv[1], sys.argv[2]
xml = dump()
pos = find(xml, needle)
if cmd == "tapscroll":
    # Не видно — прокрутить вниз и поискать ещё (до 5 раз).
    for _ in range(5):
        if pos:
            break
        size = subprocess.run(["adb", "shell", "wm", "size"], capture_output=True, text=True).stdout
        m = re.search(r"(\d+)x(\d+)", size)
        w, h = (int(m.group(1)), int(m.group(2))) if m else (1080, 1920)
        subprocess.run(["adb", "shell", "input", "swipe", str(w // 2), str(h * 3 // 4), str(w // 2), str(h // 3), "500"])
        time.sleep(1)
        xml = dump()
        pos = find(xml, needle)
    cmd = "tap"
if cmd == "has":
    print(needle, "found" if pos else "NOT FOUND")
    sys.exit(0 if pos else 1)
if cmd == "tap":
    if not pos:
        print("NOT FOUND:", needle)
        sys.exit(1)
    subprocess.run(["adb", "shell", "input", "tap", str(pos[0]), str(pos[1])])
    print("tap", needle, pos)
