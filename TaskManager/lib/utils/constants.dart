import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConstants {
  // Base API URL:
  // - Android Emulator: 10.0.2.2 trỏ về localhost của máy tính
  // - Web / Windows / macOS: 127.0.0.1
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:3000/api';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://127.0.0.1:3000/api';
  }

  // Key lưu trữ SharedPreferences
  static const String keyToken = 'auth_token';
  static const String keyUser = 'auth_user';
}
