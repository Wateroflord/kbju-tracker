import 'dart:io';

import 'package:flutter/services.dart';

import '../platform.dart';

/// Озвучка слов встроенным синтезатором речи Android (на ПК — голосами Windows).
class Tts {
  static const _ch = MethodChannel('kbju/tts');
  static Process? _proc;

  static const _winScript = r'''
Add-Type -AssemblyName System.Speech
$s = New-Object System.Speech.Synthesis.SpeechSynthesizer
$v = $s.GetInstalledVoices() | Where-Object { $_.Enabled -and $_.VoiceInfo.Culture.Name -eq $env:KB_LANG } | Select-Object -First 1
if (-not $v) { $p = $env:KB_LANG.Split('-')[0]; $v = $s.GetInstalledVoices() | Where-Object { $_.Enabled -and $_.VoiceInfo.Culture.TwoLetterISOLanguageName -eq $p } | Select-Object -First 1 }
if (-not $v) { exit 3 }
$s.SelectVoice($v.VoiceInfo.Name)
$s.Speak($env:KB_TEXT)
''';

  static Future<bool> _speakWin(String text, String tag) async {
    try {
      _proc?.kill();
      final p = await Process.start('powershell', ['-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-Command', _winScript],
          environment: {'KB_TEXT': text, 'KB_LANG': tag});
      _proc = p;
      final code = await p.exitCode.timeout(const Duration(seconds: 3), onTimeout: () => 0);
      return code == 0;
    } catch (_) {
      return false;
    }
  }

  /// false — на телефоне нет голоса для этого языка.
  static Future<bool> speak(String text, String lang) async {
    final tag = switch (lang) {
      'pl' => 'pl-PL',
      'uk' => 'uk-UA',
      'ru' => 'ru-RU',
      'de' => 'de-DE',
      _ => 'en-US',
    };
    // Подсказки в скобках не озвучиваем: «to go (on foot)» → «to go».
    final clean = text.replaceAll(RegExp(r'\s*\([^)]*\)'), '').replaceAll('…', '');
    if (isWindows) return _speakWin(clean, tag);
    try {
      return await _ch.invokeMethod<bool>('speak', {'text': clean, 'lang': tag}) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stop() async {
    if (isWindows) {
      _proc?.kill();
      _proc = null;
      return;
    }
    try {
      await _ch.invokeMethod('stop');
    } catch (_) {}
  }
}
