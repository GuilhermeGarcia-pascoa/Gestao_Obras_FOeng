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
  String get role => (_utilizador?['role'] ?? '').toString();
  bool get isAdmin => role == 'admin';
  bool get isGestor => role == 'gestor';
  bool get podeGerirRecursos => isAdmin || isGestor;
  bool get podeAcederAdmin => isAdmin;

  // ── 1. Verificar sessão ao abrir a app ─────────────────────────────────────
  Future<void> verificarLoginInicial() async {
    _loading = true;
    notifyListeners();

    try {
      final token = await SecureStorage.getToken();
      if (token == null) {
        _utilizador = null;
        return;
      }

      final userData = await ApiService.getCurrentUser();
      _utilizador = userData;
      // Atualiza os dados do utilizador no armazenamento local
      await SecureStorage.saveUser(userData);
    } catch (_) {
      // Token expirado ou inválido — limpa tudo e redireciona para login
      _utilizador = null;
      await SecureStorage.clearAll();
    } finally {
      // O finally garante que loading é sempre false, mesmo que a app
      // vá para background e volte a meio da chamada de rede
      _loading = false;
      notifyListeners();
    }
  }

  // ── 2. Login ───────────────────────────────────────────────────────────────
  Future<bool> login(String email, String password) async {
    _loading = true;
    _erro = null;
    notifyListeners();

    try {
      final data = await ApiService.login(email, password);
      _utilizador = data['utilizador'];
      return true;
    } on ApiException catch (e) {
      _erro = e.mensagem;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── 3. Logout ──────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await ApiService.logout();
    _utilizador = null;
    notifyListeners();
  }
}
