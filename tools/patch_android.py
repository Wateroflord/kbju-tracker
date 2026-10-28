"""Настраивает сгенерированный Android-проект: разрешения, Health Connect, название, minSdk."""
import pathlib
import re

ROOT = pathlib.Path("android/app")

# ---------- AndroidManifest.xml ----------
manifest = ROOT / "src/main/AndroidManifest.xml"
text = manifest.read_text(encoding="utf-8")

permissions = [
    "android.permission.INTERNET",
    "android.permission.ACTIVITY_RECOGNITION",
    "android.permission.health.READ_STEPS",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.RECEIVE_BOOT_COMPLETED",
    "android.permission.VIBRATE",
    "android.permission.SCHEDULE_EXACT_ALARM",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_HEALTH",
    "android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS",
    "android.permission.CAMERA",
]
for p in permissions:
    if p not in text:
        text = re.sub(
            r"(<manifest[^>]*>)",
            rf'\1\n    <uses-permission android:name="{p}"/>',
            text,
            count=1,
        )

# Health Connect должен быть виден приложению (Android 11+)
if "com.google.android.apps.healthdata" not in text:
    queries = (
        "    <queries>\n"
        '        <package android:name="com.google.android.apps.healthdata"/>\n'
        "        <intent>\n"
        '            <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE"/>\n'
        "        </intent>\n"
        "        <intent>\n"
        '            <action android:name="android.intent.action.TTS_SERVICE"/>\n'
        "        </intent>\n"
        "        <intent>\n"
        '            <action android:name="android.speech.action.RECOGNIZE_SPEECH"/>\n'
        "        </intent>\n"
        "    </queries>\n"
    )
    inner = queries.split("<queries>\n", 1)[1].rsplit("    </queries>", 1)[0]
    if "<queries>" in text:
        text = text.replace("<queries>", "<queries>\n" + inner.rstrip("\n"), 1)
    else:
        text = text.replace("</manifest>", queries + "</manifest>")

# Экран объяснения разрешений Health Connect
_main_act = re.search(r"<activity[^>]*android:name=\"\.MainActivity\"[\s\S]*?</activity>", text)
if _main_act and "ACTION_SHOW_PERMISSIONS_RATIONALE" not in _main_act.group(0):
    rationale = (
        "            <intent-filter>\n"
        '                <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE"/>\n'
        "            </intent-filter>\n"
    )
    text = re.sub(r"(<activity[^>]*android:name=\"\.MainActivity\"[\s\S]*?)(</activity>)",
                  lambda m: m.group(1) + rationale + "        " + m.group(2), text, count=1)

if "ViewPermissionUsageActivity" not in text:
    alias = (
        "        <activity-alias\n"
        '            android:name="ViewPermissionUsageActivity"\n'
        '            android:exported="true"\n'
        '            android:targetActivity=".MainActivity"\n'
        '            android:permission="android.permission.START_VIEW_PERMISSION_USAGE">\n'
        "            <intent-filter>\n"
        '                <action android:name="android.intent.action.VIEW_PERMISSION_USAGE"/>\n'
        '                <category android:name="android.intent.category.HEALTH_PERMISSIONS"/>\n'
        "            </intent-filter>\n"
        "        </activity-alias>\n"
    )
    text = text.replace("    </application>", alias + "    </application>", 1)

if "ScheduledNotificationReceiver" not in text:
    receivers = (
        '        <receiver android:exported="false" '
        'android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>\n'
        '        <receiver android:exported="false" '
        'android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">\n'
        "            <intent-filter>\n"
        '                <action android:name="android.intent.action.BOOT_COMPLETED"/>\n'
        '                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>\n'
        '                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>\n'
        '                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>\n'
        "            </intent-filter>\n"
        "        </receiver>\n"
    )
    text = text.replace("    </application>", receivers + "    </application>", 1)

# Фоновый шагомер (служба + автозапуск после перезагрузки)
if ".StepService" not in text:
    step = (
        '        <service android:name=".StepService" android:exported="false" '
        'android:foregroundServiceType="health"/>\n'
        '        <receiver android:name=".StepBootReceiver" android:exported="true">\n'
        "            <intent-filter>\n"
        '                <action android:name="android.intent.action.BOOT_COMPLETED"/>\n'
        '                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>\n'
        "            </intent-filter>\n"
        "        </receiver>\n"
    )
    text = text.replace("    </application>", step + "    </application>", 1)

# Виджет на главный экран
if ".KbjuWidget" not in text:
    widget = (
        '        <receiver android:name=".KbjuWidget" android:exported="false">\n'
        "            <intent-filter>\n"
        '                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>\n'
        "            </intent-filter>\n"
        '            <meta-data android:name="android.appwidget.provider" android:resource="@xml/kbju_widget_info"/>\n'
        "        </receiver>\n"
    )
    text = text.replace("    </application>", widget + "    </application>", 1)

text = re.sub(r'android:label="[^"]*"', 'android:label="КБЖУ Трекер"', text, count=1)
manifest.write_text(text, encoding="utf-8")
print(text)

# ---------- Нативный код: MainActivity (канал шагомера) и служба шагов ----------
TOOLS = pathlib.Path(__file__).resolve().parent / "android"
acts = list(ROOT.glob("src/main/**/MainActivity.*"))
for act in acts:
    act.unlink()
kotlin_dir = ROOT / "src/main/kotlin/com/kbju/kbju_tracker"
kotlin_dir.mkdir(parents=True, exist_ok=True)
for name in ("MainActivity.kt", "StepService.kt", "KbjuWidget.kt"):
    (kotlin_dir / name).write_text((TOOLS / name).read_text(encoding="utf-8"), encoding="utf-8")
    print("copied", kotlin_dir / name)
drawable = ROOT / "src/main/res/drawable"
drawable.mkdir(parents=True, exist_ok=True)
(drawable / "ic_stat_steps.xml").write_text((TOOLS / "ic_stat_steps.xml").read_text(encoding="utf-8"), encoding="utf-8")

# Ресурсы виджета
res = ROOT / "src/main/res"
for sub in ("layout", "xml"):
    (res / sub).mkdir(parents=True, exist_ok=True)
W = TOOLS / "widget"
(res / "layout/kbju_widget.xml").write_text((W / "kbju_widget.xml").read_text(encoding="utf-8"), encoding="utf-8")
(res / "xml/kbju_widget_info.xml").write_text((W / "kbju_widget_info.xml").read_text(encoding="utf-8"), encoding="utf-8")
for f in W.glob("widget_*.xml"):
    (drawable / f.name).write_text(f.read_text(encoding="utf-8"), encoding="utf-8")
print("widget resources copied")

# ---------- build.gradle(.kts): minSdk 26 (Health Connect) + desugaring (уведомления) ----------
for name in ("build.gradle.kts", "build.gradle"):
    g = ROOT / name
    if not g.exists():
        continue
    src = g.read_text(encoding="utf-8")
    kts = name.endswith(".kts")
    src = re.sub(r"minSdk(Version)?\s*=?\s*[^\n]+", "minSdk = 26" if kts else "minSdkVersion 26", src, count=1)
    if "coreLibraryDesugaringEnabled" not in src:
        src = re.sub(
            r"(compileOptions\s*\{)",
            r"\1\n        " + ("isCoreLibraryDesugaringEnabled = true" if kts else "coreLibraryDesugaringEnabled true"),
            src,
            count=1,
        )
    if "desugar_jdk_libs" not in src:
        dep = ('    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'
               if kts else "    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'")
        if re.search(r"^dependencies\s*\{", src, flags=re.M):
            src = re.sub(r"^dependencies\s*\{", "dependencies {\n" + dep, src, count=1, flags=re.M)
        else:
            src += "\ndependencies {\n" + dep + "\n}\n"
    g.write_text(src, encoding="utf-8")
    print(g, "\n", src)
