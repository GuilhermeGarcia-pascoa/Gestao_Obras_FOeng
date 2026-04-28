import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config/api_config.dart';
import 'secure_storage.dart';

class ApiService {
  // ── Headers com auth ──────────────────────────────────────────────────────
  static Future<Map<String, String>> _headers() async {
    final token = await SecureStorage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Métodos HTTP genéricos ─────────────────────────────────────────────────
  static Future<dynamic> get(String path) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<dynamic> delete(String path) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  static dynamic _parse(http.Response res) {
    final data = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    throw ApiException(data['erro'] ?? 'Erro desconhecido', res.statusCode);
  }

  // ── AUTH ───────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await post('/auth/login', {'email': email, 'password': password});
    await SecureStorage.saveToken(data['token']);
    await SecureStorage.saveUser(data['utilizador']);
    return data;
  }

  static Future<Map<String, dynamic>> getCurrentUser() async {
    final data = await get('/auth/me');
    return data['utilizador'] as Map<String, dynamic>;
  }

  static Future<void> logout() async {
    try {
      await post('/auth/logout', {});
    } catch (_) {
      // Ignora erro de rede no logout — limpa sempre o armazenamento local
    }
    await SecureStorage.clearAll();
  }

  // ── OBRAS ──────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> listarObras({
    String? estado,
    List<String>? tipos,
    String? dataInicio,
    String? dataFim,
    String? orcamentoMin,
    String? orcamentoMax,
  }) async {
    final queryParts = <String>[];

    void addSingle(String key, String? value) {
      final clean = value?.trim();
      if (clean == null || clean.isEmpty) return;
      queryParts.add(
        '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(clean)}',
      );
    }

    if (estado != null && estado.trim().isNotEmpty) {
      addSingle('estado', estado);
    }
    if (tipos != null && tipos.isNotEmpty) {
      for (final tipo in tipos) {
        final clean = tipo.trim();
        if (clean.isEmpty) continue;
        queryParts.add(
          '${Uri.encodeQueryComponent('tipo')}=${Uri.encodeQueryComponent(clean)}',
        );
      }
    }

    addSingle('dataInicio', dataInicio);
    addSingle('dataFim', dataFim);
    addSingle('orcamentoMin', orcamentoMin);
    addSingle('orcamentoMax', orcamentoMax);

    final query = queryParts.isEmpty ? '' : '?${queryParts.join('&')}';
    final uri = Uri.parse('${ApiConfig.baseUrl}/obras$query');

    final res = await http.get(uri, headers: await _headers());
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getObra(int id) async => await get('/obras/$id');
  static Future<Map<String, dynamic>> criarObra(Map<String, dynamic> dados) async => await post('/obras', dados);
  static Future<void> editarObra(int id, Map<String, dynamic> dados) async => await put('/obras/$id', dados);
  static Future<void> apagarObra(int id) async => await delete('/obras/$id');

  // ── DIAS ───────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getDiasMes(int obraId, String mes) async =>
      await get('/dias/anteriores?obra_id=$obraId&mes=$mes');

  static Future<List<dynamic>> listarDiasObra(int obraId) async =>
      await get('/dias/lista?obra_id=$obraId');

  static Future<Map<String, dynamic>> getDiaPorData(int obraId, String data) async =>
      await get('/dias/por-data?obra_id=$obraId&data=$data');

  static Future<Map<String, dynamic>> getDia(int id) async => await get('/dias/$id');

  static Future<Map<String, dynamic>> getDiaAnterior(int id) async =>
      await get('/dias/$id/anterior');

  static Future<Map<String, dynamic>> copiarDe(int diaId, int fonteId) async =>
      await get('/dias/$diaId/copiar-de?fonte_id=$fonteId');

  static Future<void> guardarDia(int id, Map<String, dynamic> dados) async =>
      await put('/dias/$id', dados);

  static Future<void> apagarDia(int id) async =>
      await delete('/dias/$id');

  // ── EQUIPA ─────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> listarPessoas({String estado = 'ativas'}) async =>
      await get('/equipa/pessoas?estado=$estado');
  static Future<List<dynamic>> listarMaquinas({String estado = 'ativas'}) async =>
      await get('/equipa/maquinas?estado=$estado');
  static Future<List<dynamic>> listarViaturas({String estado = 'ativas'}) async =>
      await get('/equipa/viaturas?estado=$estado');

  static Future<void> editarPessoa(int id, Map<String, dynamic> dados) async =>
      await put('/equipa/pessoas/$id', dados);
  static Future<void> apagarPessoa(int id) async => await delete('/equipa/pessoas/$id');

  static Future<void> editarMaquina(int id, Map<String, dynamic> dados) async =>
      await put('/equipa/maquinas/$id', dados);
  static Future<void> apagarMaquina(int id) async => await delete('/equipa/maquinas/$id');

  static Future<void> editarViatura(int id, Map<String, dynamic> dados) async =>
      await put('/equipa/viaturas/$id', dados);
  static Future<void> apagarViatura(int id) async => await delete('/equipa/viaturas/$id');

  // ── RELATÓRIOS ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getGraficos(int obraId) async =>
      await get('/relatorios/graficos/$obraId');

  static Future<Map<String, dynamic>> getGraficosTodasObras() async =>
      await get('/relatorios/todas-obras');

  // ── EXPORTAÇÕES ───────────────────────────────────────────────────────────
  static Future<List<int>> downloadExcel(int obraId) async {
    final headers = await _headers();
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/export/excel/$obraId'),
      headers: headers,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.bodyBytes;
    }
    String mensagem;
    try {
      final data = jsonDecode(res.body);
      mensagem = data['erro'] ?? 'Erro ao descarregar Excel';
    } catch (_) {
      mensagem = 'Erro ao descarregar Excel (${res.statusCode})';
    }
    throw ApiException(mensagem, res.statusCode);
  }

  static Future<List<int>> downloadPdf(String dataInicio, String dataFim) async {
    final headers = await _headers();
    final res = await http.get(
      Uri.parse(
          '${ApiConfig.baseUrl}/export/pdf?dataInicio=$dataInicio&dataFim=$dataFim'),
      headers: headers,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.bodyBytes;
    }
    String mensagem;
    try {
      final data = jsonDecode(res.body);
      mensagem = data['erro'] ?? 'Erro ao descarregar PDF';
    } catch (_) {
      mensagem = 'Erro ao descarregar PDF (${res.statusCode})';
    }
    throw ApiException(mensagem, res.statusCode);
  }

  // ── ADMIN: Utilizadores ────────────────────────────────────────────────────
  static Future<List<dynamic>> listarUtilizadores() async => await get('/admin/utilizadores');

  static Future<Map<String, dynamic>> criarUtilizador(Map<String, dynamic> dados) async =>
      await post('/admin/utilizadores', dados);

  static Future<void> apagarUtilizador(int id) async => await delete('/admin/utilizadores/$id');

  static Future<void> alterarSenhaUtilizador(int id, String novaSenha) async =>
      await put('/admin/utilizadores/$id/senha', {'password': novaSenha});

  static Future<void> alterarRoleUtilizador(int id, String novaRole) async =>
      await put('/admin/utilizadores/$id/role', {'role': novaRole});

  static Future<List<dynamic>> listarLogs() async {
    final response = await get('/admin/logs');
    return response as List<dynamic>;
  }

  // ── SYNC fo_panel ──────────────────────────────────────────────────────────

  /// Devolve o estado da última sincronização:
  /// { ultimoSync, proximoSync, emExecucao, totalInseridas, totalActualizadas, ... }
  static Future<Map<String, dynamic>> getSyncStatus() async {
    final data = await get('/sync/status');
    return data as Map<String, dynamic>;
  }

  /// Força uma sincronização manual imediata.
  /// Devolve { ok, syncedAt, inseridas, actualizadas, ignoradas }
  static Future<Map<String, dynamic>> sincronizarAgora() async {
    final data = await post('/sync/agora', {});
    return data as Map<String, dynamic>;
  }
}

class ApiException implements Exception {
  final String mensagem;
  final int codigo;
  ApiException(this.mensagem, this.codigo);
  @override
  String toString() => mensagem;
}
