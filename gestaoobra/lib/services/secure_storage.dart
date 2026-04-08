// lib/services/secure_storage.dart
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _keyToken = 'jwt_token';
  static const String _keyUserData = 'user_data';

  // Token
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _keyToken, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _keyToken);
  }

  // Utilizador
  static Future<void> saveUser(Map<String, dynamic> user) async {
    await _storage.write(key: _keyUserData, value: jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final String? jsonString = await _storage.read(key: _keyUserData);
    if (jsonString == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(jsonString));
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteUser() async {
    await _storage.delete(key: _keyUserData);
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}