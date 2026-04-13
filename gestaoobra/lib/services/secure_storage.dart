import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    webOptions: WebOptions(dbName: 'gestaoobra', publicKey: 'gestaoobra_key'),
  );

  static const String _keyToken    = 'jwt_token';
  static const String _keyUserData = 'user_data';

  // ── Token ──────────────────────────────────────────────────────────────────
  static Future<void> saveToken(String token) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyToken, token);
    } else {
      await _storage.write(key: _keyToken, value: token);
    }
  }

  static Future<String?> getToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyToken);
    }
    return await _storage.read(key: _keyToken);
  }

  static Future<void> deleteToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyToken);
    } else {
      await _storage.delete(key: _keyToken);
    }
  }

  // ── Utilizador ─────────────────────────────────────────────────────────────
  static Future<void> saveUser(Map<String, dynamic> user) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserData, jsonEncode(user));
    } else {
      await _storage.write(key: _keyUserData, value: jsonEncode(user));
    }
  }

  static Future<Map<String, dynamic>?> getUser() async {
    String? jsonString;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      jsonString = prefs.getString(_keyUserData);
    } else {
      jsonString = await _storage.read(key: _keyUserData);
    }
    if (jsonString == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(jsonString));
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteUser() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUserData);
    } else {
      await _storage.delete(key: _keyUserData);
    }
  }

  static Future<void> clearAll() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyToken);
      await prefs.remove(_keyUserData);
    } else {
      await _storage.deleteAll();
    }
  }
}