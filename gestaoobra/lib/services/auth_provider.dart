import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/secure_storage.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _utilizador;
  bool _loading = false;
  String? _erro;

  Map<String, dynamic>? get utilizador => _utilizador;
  bool get estaAutenticado => _utilizador != null;
  bool get loading => _loading;
  String? get erro => _erro;

  // ──────────────────────────────────────
  // 1. Verificar sessão ao abrir a app
  Future<void> verificarLoginInicial() async {
    _loading = true;
    notifyListeners();

    try {
      final token = await SecureStorage.getToken();
      if (token == null) {
        _utilizador = null;
        return;
      }

      // Chama o novo endpoint /auth/me
      final userData = await ApiService.getCurrentUser();
      _utilizador = userData;
      await SecureStorage.saveUser(userData);
    } catch (e) {
      _utilizador = null;
      await SecureStorage.clearAll();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ──────────────────────────────────────
  // 2. Login
  Future<bool> login(String email, String password) async {
    _loading = true;
    _erro = null;
    notifyListeners();

    try {
      final data = await ApiService.login(email, password);
      final token = data['token'];
      final user = data['utilizador'];

      await SecureStorage.saveToken(token);
      await SecureStorage.saveUser(user);

      _utilizador = user;
      return true;
    } on ApiException catch (e) {
      _erro = e.mensagem;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ──────────────────────────────────────
  // 3. Logout
  Future<void> logout() async {
    await ApiService.logout(); // opcional: invalidar token no backend
    await SecureStorage.clearAll();
    _utilizador = null;
    notifyListeners();
  }
}