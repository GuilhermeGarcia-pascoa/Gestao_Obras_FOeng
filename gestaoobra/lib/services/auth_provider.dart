import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; // Precisas de adicionar isto no pubspec.yaml se ainda não tiveres
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _utilizador;
  bool _loading = false;
  String? _erro;

  Map<String, dynamic>? get utilizador => _utilizador;
  bool get estaAutenticado => _utilizador != null;
  bool get loading => _loading;
  String? get erro => _erro;

  /// Método para correr quando a App inicia.
  /// Verifica se já existe um utilizador guardado na memória do dispositivo.
  Future<void> verificarLoginInicial() async {
    _loading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final utilizadorString = prefs.getString('dados_utilizador');

      if (utilizadorString != null) {
        // Se encontrou dados guardados, reconstrói o mapa do utilizador
        _utilizador = jsonDecode(utilizadorString);
      }
    } catch (e) {
      _erro = 'Erro ao recuperar sessão local.';
      _utilizador = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Método de Login
  Future<bool> login(String email, String password) async {
    _loading = true;
    _erro = null;
    notifyListeners();

    try {
      final data = await ApiService.login(email, password);
      _utilizador = data['utilizador']; // Assume-se que a API devolve o objeto do utilizador aqui

      // Guarda os dados do utilizador localmente (SharedPreferences) para manter o login
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dados_utilizador', jsonEncode(_utilizador));

      _loading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _erro = e.mensagem;
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _erro = 'Erro inesperado ao fazer login.';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  /// Método de Logout
  Future<void> logout() async {
    // 1. Limpa o token na API
    await ApiService.clearToken();

    // 2. Apaga os dados do utilizador guardados na memória do telemóvel
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dados_utilizador');

    // 3. Limpa o estado atual
    _utilizador = null;
    notifyListeners();
  }
}