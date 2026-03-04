import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  // إعدادات المسح
  String _unknownBarcodeAction = 'save'; // save, ask, reject
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  // إعدادات التقرير
  bool _showUnknown = true;
  bool _showMatching = true;

  // إعدادات العرض
  bool _darkMode = false;
  String _language = 'ar';

  // Getters
  String get unknownBarcodeAction => _unknownBarcodeAction;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get showUnknown => _showUnknown;
  bool get showMatching => _showMatching;
  bool get darkMode => _darkMode;
  String get language => _language;

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _unknownBarcodeAction = prefs.getString('unknownBarcodeAction') ?? 'save';
    _soundEnabled = prefs.getBool('soundEnabled') ?? true;
    _vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
    _showUnknown = prefs.getBool('showUnknown') ?? true;
    _showMatching = prefs.getBool('showMatching') ?? true;
    _darkMode = prefs.getBool('darkMode') ?? false;
    _language = prefs.getString('language') ?? 'ar';
    notifyListeners();
  }

  Future<void> setUnknownBarcodeAction(String value) async {
    _unknownBarcodeAction = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('unknownBarcodeAction', value);
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundEnabled', value);
    notifyListeners();
  }

  Future<void> setVibrationEnabled(bool value) async {
    _vibrationEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibrationEnabled', value);
    notifyListeners();
  }

  Future<void> setShowUnknown(bool value) async {
    _showUnknown = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showUnknown', value);
    notifyListeners();
  }

  Future<void> setShowMatching(bool value) async {
    _showMatching = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showMatching', value);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    _language = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', value);
    notifyListeners();
  }
}
