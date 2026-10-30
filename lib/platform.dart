import 'dart:io';

import 'package:flutter/foundation.dart';

/// Приложение работает на Windows (версия для ПК).
bool get isWindows => !kIsWeb && Platform.isWindows;

/// Приложение работает на телефоне Android.
bool get isAndroid => !kIsWeb && Platform.isAndroid;
