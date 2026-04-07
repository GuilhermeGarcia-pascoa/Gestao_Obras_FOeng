import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  int? _userId;

  ThemeMode get themeMode => _themeMode;

  Future<void> setUserId(int? userId, {String? temaBD}) async {
  if (userId == _userId) return;

  _userId = userId;
  _themeMode = ThemeMode.system;

  if (_userId != null) {
    if (temaBD != null) {
      _themeMode = _parseThemeMode(temaBD);
    } else {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_themeKey(_userId!));
      _themeMode = _parseThemeMode(value);
    }
  }

  notifyListeners();   // agora está seguro
}

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    
    if (_userId == null) return;
    
    // Guarda local
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey(_userId!), _themeMode.name);
    
    // Envia para backend
    await _updateThemeBackend();
  }

  Future<void> _updateThemeBackend() async {
    if (_userId == null) return;
    try {
      await ApiService.put('/auth/prefs/tema', {'tema_preferido': _themeMode.name});
    } catch (e) {
      // Silencioso se falhar, mantém local
    }
  }

  String _themeKey(int userId) => 'theme_mode_user_$userId';

  ThemeMode _parseThemeMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}
