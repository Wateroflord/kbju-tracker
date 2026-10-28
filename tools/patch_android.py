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

text = re.sub(r'android:label="[^"]*"', 'android:label="КБЖУ Трекер"', text, count=1)
manifest.write_text(text, encoding="utf-8")
print(text)

# ---------- MainActivity: Health Connect требует FlutterFragmentActivity ----------
for act in ROOT.glob("src/main/**/MainActivity.*"):
    src = act.read_text(encoding="utf-8")
    src = src.replace("io.flutter.embedding.android.FlutterActivity", "io.flutter.embedding.android.FlutterFragmentActivity")
    src = re.sub(r"\bFlutterActivity\(\)", "FlutterFragmentActivity()", src)
    src = re.sub(r"extends FlutterActivity\b", "extends FlutterFragmentActivity", src)
    act.write_text(src, encoding="utf-8")
    print(act, "\n", src)

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
