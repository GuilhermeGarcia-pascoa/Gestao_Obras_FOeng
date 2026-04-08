import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();

  static const String _keyToken = 'jwt_token';
  static const String _keyUser = 'user_data';

  // --- Token ---
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _keyToken, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _keyToken);
  }

  // --- User Data ---
  static Future<void> saveUser(Map<String, dynamic> user) async {
    // FIX: Changed .toString() to jsonEncode()
    final String jsonStr = jsonEncode(user); 
    await _storage.write(key: _keyUser, value: jsonStr);
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final jsonStr = await _storage.read(key: _keyUser);
    if (jsonStr == null) return null;
    try {
      // FIX: jsonDecode returns dynamic, so we cast it safely
      final dynamic decoded = jsonDecode(jsonStr);
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      return null;
    }
  }

  static Future<void> deleteUser() async {
    await _storage.delete(key: _keyUser);
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
