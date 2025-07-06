import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static late Box _box;
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox('app_storage');
    _prefs = await SharedPreferences.getInstance();
  }

  // Hive methods for complex data
  static Future<void> setData(String key, dynamic value) async {
    await _box.put(key, value);
  }

  static T? getData<T>(String key) {
    return _box.get(key) as T?;
  }

  static Future<void> removeData(String key) async {
    await _box.delete(key);
  }

  static bool hasData(String key) {
    return _box.containsKey(key);
  }

  // SharedPreferences methods for simple data
  static Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  static String? getString(String key) {
    return _prefs.getString(key);
  }

  static Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  static bool? getBool(String key) {
    return _prefs.getBool(key);
  }

  static Future<void> setInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }

  static int? getInt(String key) {
    return _prefs.getInt(key);
  }
}

// Storage keys constants
class StorageKeys {
  static const String userPreferences = 'user_preferences';
  static const String isFirstLaunch = 'is_first_launch';
  static const String themeMode = 'theme_mode';
  static const String language = 'language';
  static const String gemmaModelPath = 'gemma_model_path';
  static const String lastModelCheck = 'last_model_check';
  static const String performanceStats = 'performance_stats';
}