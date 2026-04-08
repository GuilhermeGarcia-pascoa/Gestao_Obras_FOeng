import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api_config/api_config.dart';

class ApiService {
  // ── Token ────────────────────────────────────────────────────────────────────
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  // ── Headers com auth ─────────────────────────────────────────────────────────
  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Métodos HTTP genéricos ────────────────────────────────────────────────────
  static Future<dynamic> get(String path) async {
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}$path'), headers: await _headers());
    return _parse(res);
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: await _headers(), body: jsonEncode(body));
    return _parse(res);
  }

  static Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final res = await http.put(Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: await _headers(), body: jsonEncode(body));
    return _parse(res);
  }

  static Future<dynamic> delete(String path) async {
    final res = await http.delete(Uri.parse('${ApiConfig.baseUrl}$path'), headers: await _headers());
    return _parse(res);
  }

  static dynamic _parse(http.Response res) {
    final data = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    throw ApiException(data['erro'] ?? 'Erro desconhecido', res.statusCode);
  }

  // ── AUTH ─────────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await post('/auth/login', {'email': email, 'password': password});
    await saveToken(data['token']);
    return data;
  }

  // ── OBRAS ─────────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> listarObras({String? estado}) async {
    final query = estado != null ? '?estado=$estado' : '';
    return await get('/obras$query');
  }

  static Future<Map<String, dynamic>> getObra(int id) async => await get('/obras/$id');
  static Future<Map<String, dynamic>> criarObra(Map<String, dynamic> dados) async => await post('/obras', dados);
  static Future<void> editarObra(int id, Map<String, dynamic> dados) async => await put('/obras/$id', dados);
  static Future<void> apagarObra(int id) async => await delete('/obras/$id');

  // ── DIAS ──────────────────────────────────────────────────────────────────────

  /// Datas com registo num mês (para o calendário). mes = "2025-03"
  static Future<List<dynamic>> getDiasMes(int obraId, String mes) async =>
      await get('/dias/anteriores?obra_id=$obraId&mes=$mes');

  /// Lista todos os dias com dados de uma obra (para o picker "copiar de dia")
  static Future<List<dynamic>> listarDiasObra(int obraId) async =>
      await get('/dias/lista?obra_id=$obraId');

  /// Abre (ou cria) um dia por data. data = "2025-03-15"
  static Future<Map<String, dynamic>> getDiaPorData(int obraId, String data) async =>
      await get('/dias/por-data?obra_id=$obraId&data=$data');

  static Future<Map<String, dynamic>> getDia(int id) async => await get('/dias/$id');

  /// Dados do dia com registo mais recente antes deste
  static Future<Map<String, dynamic>> getDiaAnterior(int id) async =>
      await get('/dias/$id/anterior');

  /// Copia dados de um dia específico escolhido pelo utilizador
  static Future<Map<String, dynamic>> copiarDe(int diaId, int fonteId) async =>
      await get('/dias/$diaId/copiar-de?fonte_id=$fonteId');

  static Future<void> guardarDia(int id, Map<String, dynamic> dados) async =>
      await put('/dias/$id', dados);

  // ── EQUIPA ────────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> listarPessoas()  async => await get('/equipa/pessoas');
  static Future<List<dynamic>> listarMaquinas() async => await get('/equipa/maquinas');
  static Future<List<dynamic>> listarViaturas() async => await get('/equipa/viaturas');

  static Future<void> editarPessoa(int id, Map<String, dynamic> dados) async =>
      await put('/equipa/pessoas/$id', dados);
  static Future<void> apagarPessoa(int id) async => await delete('/equipa/pessoas/$id');

  static Future<void> editarMaquina(int id, Map<String, dynamic> dados) async =>
      await put('/equipa/maquinas/$id', dados);
  static Future<void> apagarMaquina(int id) async => await delete('/equipa/maquinas/$id');

  static Future<void> editarViatura(int id, Map<String, dynamic> dados) async =>
      await put('/equipa/viaturas/$id', dados);
  static Future<void> apagarViatura(int id) async => await delete('/equipa/viaturas/$id');

  // ── RELATÓRIOS ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getGraficos(int obraId) async =>
      await get('/relatorios/graficos/$obraId');

  static Future<Map<String, dynamic>> getGraficosTodasObras() async =>
      await get('/relatorios/todas-obras');

  // ── EXPORTAÇÕES ───────────────────────────────────────────────────────────────
  static String urlExcel(int obraId) => '${ApiConfig.baseUrl}/export/excel/$obraId';
  static String urlPdf(String dataInicio, String dataFim) => '${ApiConfig.baseUrl}/export/pdf?dataInicio=$dataInicio&dataFim=$dataFim';

  // ── ADMIN: Utilizadores ───────────────────────────────────────────────────────
  static Future<List<dynamic>> listarUtilizadores() async => await get('/admin/utilizadores');
  
  static Future<Map<String, dynamic>> criarUtilizador(Map<String, dynamic> dados) async =>
      await post('/admin/utilizadores', dados);
  
  static Future<void> apagarUtilizador(int id) async => await delete('/admin/utilizadores/$id');
  
  static Future<void> alterarSenhaUtilizador(int id, String novaSenha) async =>
      await put('/admin/utilizadores/$id/senha', {'password': novaSenha});

        // Novo: obter utilizador atual (seguro)
  static Future<Map<String, dynamic>> getCurrentUser() async {
    final data = await get('/auth/me');
    return data['utilizador'] as Map<String, dynamic>;
  }

  // Opcional: invalidar token no backend (logout)
  static Future<void> logout() async {
    try {
      await post('/auth/logout', {});
    } catch (_) {}
    await clearToken();
  }
}

class ApiException implements Exception {
  final String mensagem;
  final int codigo;
  ApiException(this.mensagem, this.codigo);
  @override
  String toString() => mensagem;
}
