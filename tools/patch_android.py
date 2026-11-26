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
    "android.permission.health.READ_WEIGHT",
    "android.permission.health.READ_SLEEP",
    "android.permission.health.READ_EXERCISE",
    "android.permission.health.READ_TOTAL_CALORIES_BURNED",
    "android.permission.health.READ_DISTANCE",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.RECEIVE_BOOT_COMPLETED",
    "android.permission.VIBRATE",
    "android.permission.SCHEDULE_EXACT_ALARM",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_HEALTH",
    "android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS",
    "android.permission.CAMERA",
    # ---- плагины ----
    "android.permission.ACCESS_FINE_LOCATION",   # Winter Walks
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.FLASHLIGHT",             # Выживание в лесу (фонарик)
    "android.permission.READ_MEDIA_AUDIO",       # Winter Music
    "android.permission.READ_EXTERNAL_STORAGE",
    "android.permission.WAKE_LOCK",
    "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK",
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
        # плагины: звонок 112 (лес), ссылки и карты (прогулки), камера (Mog Battle)
        "        <intent>\n"
        '            <action android:name="android.intent.action.DIAL"/>\n'
        "        </intent>\n"
        "        <intent>\n"
        '            <action android:name="android.intent.action.VIEW"/>\n'
        '            <data android:scheme="https"/>\n'
        "        </intent>\n"
        "        <intent>\n"
        '            <action android:name="android.intent.action.VIEW"/>\n'
        '            <data android:scheme="geo"/>\n'
        "        </intent>\n"
        "        <intent>\n"
        '            <action android:name="android.media.action.IMAGE_CAPTURE"/>\n'
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

# Плагин Winter Music: фоновое воспроизведение и кнопки на экране блокировки (audio_service).
if "com.ryanheise.audioservice.AudioService" not in text:
    audio = (
        '        <service android:name="com.ryanheise.audioservice.AudioService"\n'
        '            android:foregroundServiceType="mediaPlayback"\n'
        '            android:exported="true">\n'
        "            <intent-filter>\n"
        '                <action android:name="android.media.browse.MediaBrowserService"/>\n'
        "            </intent-filter>\n"
        "        </service>\n"
        '        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"\n'
        '            android:exported="true">\n'
        "            <intent-filter>\n"
        '                <action android:name="android.intent.action.MEDIA_BUTTON"/>\n'
        "            </intent-filter>\n"
        "        </receiver>\n"
    )
    text = text.replace("    </application>", audio + "    </application>", 1)

# Плагин «Шахматы»: движок Stockfish — программа в папке нативных библиотек, её нужно распаковывать.
if "extractNativeLibs" not in text:
    text = text.replace("<application", '<application android:extractNativeLibs="true"', 1)

text = re.sub(r'android:label="[^"]*"', 'android:label="КБЖУ Трекер"', text, count=1)
# Свой класс приложения: ловит падения Android-части до запуска Flutter (tools/android/WinterApp.kt).
text = text.replace('android:name="${applicationName}"', 'android:name=".WinterApp"', 1)
_tag = re.search(r"<application[^>]*>", text)
if _tag and "android:name=" not in _tag.group(0):
    text = text.replace("<application", '<application android:name=".WinterApp"', 1)
# Сервер Winter Chat (рейтинг Winter Arc) работает по обычному http в домашней сети.
if "usesCleartextTraffic" not in text:
    text = text.replace("<application", '<application android:usesCleartextTraffic="true"', 1)

# Резервная копия Android на Google Диск: только файл данных, без фото (лимит копии — 25 МБ).
_app = re.search(r"<application[^>]*>", text)
if _app and "fullBackupContent" not in _app.group(0):
    tag = _app.group(0)
    tag = re.sub(r'\s*android:allowBackup="[^"]*"', "", tag)
    tag = tag.replace(
        "<application",
        '<application\n        android:allowBackup="true"\n'
        '        android:fullBackupContent="@xml/backup_rules"\n'
        '        android:dataExtractionRules="@xml/data_extraction_rules"',
        1,
    )
    text = text.replace(_app.group(0), tag, 1)
manifest.write_text(text, encoding="utf-8")
print(text)

# ---------- Нативный код: MainActivity (канал шагомера) и служба шагов ----------
TOOLS = pathlib.Path(__file__).resolve().parent / "android"
acts = list(ROOT.glob("src/main/**/MainActivity.*"))
for act in acts:
    act.unlink()
kotlin_dir = ROOT / "src/main/kotlin/com/kbju/kbju_tracker"
kotlin_dir.mkdir(parents=True, exist_ok=True)
for name in ("MainActivity.kt", "StepService.kt", "KbjuWidget.kt", "WinterApp.kt"):
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

# Правила резервной копии (app_flutter — папка данных Flutter)
_files = [
    '<include domain="root" path="app_flutter/kbju_data.json"/>',
    '<include domain="root" path="app_flutter/kbju_data.bak.json"/>',
]
(res / "xml/backup_rules.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n<full-backup-content>\n    '
    + "\n    ".join(_files)
    + "\n</full-backup-content>\n",
    encoding="utf-8",
)
(res / "xml/data_extraction_rules.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n<data-extraction-rules>\n'
    "    <cloud-backup>\n        " + "\n        ".join(_files) + "\n    </cloud-backup>\n"
    "    <device-transfer>\n        " + "\n        ".join(_files) + "\n    </device-transfer>\n"
    "</data-extraction-rules>\n",
    encoding="utf-8",
)
print("backup rules written")

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


# ---------- Плагины: compileSdk 36 (file_picker, geolocator), Stockfish, упаковка .so ----------
g = ROOT / "build.gradle.kts"
gs = g.read_text(encoding="utf-8")
gs = re.sub(r"compileSdk = [^\n]+", "compileSdk = 36", gs, count=1)
if "useLegacyPackaging" not in gs:
    gs = gs.replace("android {", "android {\n    packaging {\n        jniLibs {\n            useLegacyPackaging = true\n        }\n    }", 1)
g.write_text(gs, encoding="utf-8")

# ---------- WorkManager: падение при запуске (сборка 36) ----------
# Push-Up Arena (камера + ML Kit) затянула старый WorkManager 2.7.0 с базой Room 2.2.5.
# Их правила для R8 написаны под старый режим: R8 вырезал конструктор WorkDatabase_Impl,
# и приложение падало сразу при запуске («Failed to create an instance of WorkDatabase»)
# на любом процессоре. Поэтому: (1) все модули androidx.work — современной версии,
# (2) конструктор баз Room и воркеров нельзя вырезать.
WORK_VERSION = "2.10.1"
gs = g.read_text(encoding="utf-8")
if "androidx.work" not in gs:
    gs += (
        "\n// Все модули WorkManager одной современной версии (см. tools/patch_android.py).\n"
        "configurations.all {\n"
        "    resolutionStrategy.eachDependency {\n"
        f'        if (requested.group == "androidx.work") useVersion("{WORK_VERSION}")\n'
        "    }\n"
        "}\n"
    )
if 'proguardFiles("proguard-rules.pro")' not in gs:
    gs, n = re.subn(r"(buildTypes\s*\{\s*release\s*\{)", r'\1\n            proguardFiles("proguard-rules.pro")', gs, count=1)
    print("proguard-rules.pro подключён в release:", bool(n))
g.write_text(gs, encoding="utf-8")
rules = ROOT / "proguard-rules.pro"
old_rules = rules.read_text(encoding="utf-8") if rules.exists() else ""
if "androidx.room.RoomDatabase" not in old_rules:
    rules.write_text(old_rules + """
# База WorkManager/Room создаётся через рефлексию — без конструктора приложение падает при запуске.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { <init>(...); }
-keep class * extends androidx.work.ListenableWorker { <init>(android.content.Context, androidx.work.WorkerParameters); }
-keep class * extends androidx.work.InputMerger { <init>(); }
""", encoding="utf-8")
print("WorkManager:", WORK_VERSION, "+ правила R8")

root_gradle = pathlib.Path("android/build.gradle.kts")
rs = root_gradle.read_text(encoding="utf-8")
if "compileSdkVersion" not in rs:
    rs = """subprojects {
    afterEvaluate {
        val ext = extensions.findByName("android")
        if (ext != null) {
            try {
                ext.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType).invoke(ext, 36)
            } catch (e: Exception) {
            }
        }
    }
}

""" + rs
    root_gradle.write_text(rs, encoding="utf-8")

sf = pathlib.Path("tools/sf-bin/libstockfish.so")
if sf.exists():
    jni = ROOT / "src/main/jniLibs/arm64-v8a"
    jni.mkdir(parents=True, exist_ok=True)
    (jni / "libstockfish.so").write_bytes(sf.read_bytes())
    print("stockfish:", jni / "libstockfish.so", sf.stat().st_size)
    sf86 = pathlib.Path("tools/sf-bin/x86_64/libstockfish.so")
    if sf86.exists():
        jni86 = ROOT / "src/main/jniLibs/x86_64"
        jni86.mkdir(parents=True, exist_ok=True)
        (jni86 / "libstockfish.so").write_bytes(sf86.read_bytes())
        print("stockfish x86_64:", sf86.stat().st_size)
else:
    print("WARNING: tools/sf-bin/libstockfish.so нет — шахматы без Stockfish")
