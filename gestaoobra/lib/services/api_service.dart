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

  // ── Método genérico GET ───────────────────────────────────────────────────────
  static Future<dynamic> get(String path) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  // ── Método genérico POST ──────────────────────────────────────────────────────
  static Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  // ── Método genérico PUT ───────────────────────────────────────────────────────
  static Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  // ── Parse e tratamento de erros ───────────────────────────────────────────────
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

  static Future<Map<String, dynamic>> getObra(int id) async =>
      await get('/obras/$id');

  static Future<Map<String, dynamic>> criarObra(Map<String, dynamic> dados) async =>
      await post('/obras', dados);

  static Future<void> editarObra(int id, Map<String, dynamic> dados) async =>
      await put('/obras/$id', dados);

  // ── SEMANAS ───────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> listarSemanas(int obraId) async =>
      await get('/semanas?obra_id=$obraId');

  static Future<Map<String, dynamic>> getSemanaSemana(int id) async =>
      await get('/semanas/$id');

  static Future<Map<String, dynamic>> getSemanaAnterior(int id) async =>
      await get('/semanas/$id/anterior');

  static Future<Map<String, dynamic>> criarSemana(Map<String, dynamic> dados) async =>
      await post('/semanas', dados);

  static Future<void> guardarSemana(int id, Map<String, dynamic> dados) async =>
      await put('/semanas/$id', dados);

  // ── EQUIPA ────────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> listarPessoas() async => await get('/equipa/pessoas');
  static Future<List<dynamic>> listarMaquinas() async => await get('/equipa/maquinas');
  static Future<List<dynamic>> listarViaturas() async => await get('/equipa/viaturas');

  // ── RELATÓRIOS ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getGraficos(int obraId) async =>
      await get('/relatorios/graficos/$obraId');

  static String urlExcel(int obraId) => '${ApiConfig.baseUrl}/relatorios/excel/$obraId';
  static String urlPdf(int semanaId) => '${ApiConfig.baseUrl}/relatorios/pdf/$semanaId';
}

class ApiException implements Exception {
  final String mensagem;
  final int codigo;
  ApiException(this.mensagem, this.codigo);
  @override
  String toString() => mensagem;
}
