import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _utilizador;
  bool _loading = false;
  String? _erro;

  Map<String, dynamic>? get utilizador => _utilizador;
  bool get estaAutenticado => _utilizador != null;
  bool get loading => _loading;
  String? get erro => _erro;

  Future<bool> login(String email, String password) async {
    _loading = true;
    _erro = null;
    notifyListeners();

    try {
      final data = await ApiService.login(email, password);
      _utilizador = data['utilizador'];
      _loading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _erro = e.mensagem;
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await ApiService.clearToken();
    _utilizador = null;
    notifyListeners();
  }
}
