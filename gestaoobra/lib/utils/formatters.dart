import 'package:intl/intl.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Centraliza toda a formatação de datas, moeda e números da app.
// Importa este ficheiro em vez de criar instâncias de NumberFormat/DateFormat
// espalhadas por vários ecrãs.
//
// Uso:
//   import '../utils/formatters.dart';
//   Text(Fmt.moeda(valor));
//   Text(Fmt.data(datetime));
// ──────────────────────────────────────────────────────────────────────────────

class Fmt {
  Fmt._(); // Classe utilitária — não instanciável

  // ── Formatadores (criados uma vez e reutilizados) ─────────────────────────
  static final _moeda      = NumberFormat.currency(locale: 'pt_PT', symbol: '€');
  static final _moeda0     = NumberFormat.currency(locale: 'pt_PT', symbol: '€', decimalDigits: 0);
  static final _moeda2     = NumberFormat.currency(locale: 'pt_PT', symbol: '€', decimalDigits: 2);
  static final _numero     = NumberFormat.decimalPattern('pt_PT');
  static final _dataLonga  = DateFormat("EEEE, d 'de' MMMM 'de' yyyy", 'pt_PT');
  static final _dataMedia  = DateFormat("d MMM yyyy", 'pt_PT');
  static final _dataCalend = DateFormat("EEEE, d MMM", 'pt_PT');
  static final _dataApi    = DateFormat('yyyy-MM-dd');
  static final _dataMes    = DateFormat('yyyy-MM');
  static final _horaMin    = DateFormat('HH:mm');

  // ── Moeda ─────────────────────────────────────────────────────────────────
  /// "€ 1.234,56"
  static String moeda(dynamic valor) => _moeda.format(_parseNum(valor));

  /// "€ 1.235" (sem decimais — para dashboards)
  static String moeda0(dynamic valor) => _moeda0.format(_parseNum(valor));

  /// "€ 1.234,56" (sempre 2 decimais)
  static String moeda2(dynamic valor) => _moeda2.format(_parseNum(valor));

  // ── Datas ─────────────────────────────────────────────────────────────────
  /// "segunda-feira, 8 de abril de 2025"
  static String dataLonga(DateTime d) => _dataLonga.format(d);

  /// "8 abr 2025"
  static String dataMedia(DateTime d) => _dataMedia.format(d);

  /// "segunda-feira, 8 abr" (para cabeçalhos de dia)
  static String dataCalendario(DateTime d) => _dataCalend.format(d);

  /// "2025-04-08" (para enviar à API)
  static String dataApi(DateTime d) => _dataApi.format(d);

  /// "2025-04" (para filtros de mês)
  static String dataMes(DateTime d) => _dataMes.format(d);

  /// "14:30"
  static String hora(DateTime d) => _horaMin.format(d);

  // ── Parsers ───────────────────────────────────────────────────────────────
  /// Converte qualquer valor (String, int, double, null) em double
  static double parseDouble(dynamic val) => _parseNum(val);

  /// Converte String "YYYY-MM-DD" em DateTime (retorna hoje se inválido)
  static DateTime parseData(String? s) {
    if (s == null || s.isEmpty) return DateTime.now();
    try {
      return DateTime.parse(s);
    } catch (_) {
      return DateTime.now();
    }
  }

  /// Converte String "YYYY-MM-DD" em DateTime? (retorna null se inválido)
  static DateTime? parseDataOpcional(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  // ── Números ───────────────────────────────────────────────────────────────
  /// "1.234,56"
  static String numero(dynamic valor) => _numero.format(_parseNum(valor));

  /// "8,5 h"
  static String horas(dynamic valor) => '${_parseNum(valor).toStringAsFixed(1)} h';

  /// "142,3 km"
  static String km(dynamic valor) => '${_parseNum(valor).toStringAsFixed(1)} km';

  // ── Interno ───────────────────────────────────────────────────────────────
  static double _parseNum(dynamic val) {
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is num) return val.toDouble();
    final s = val.toString().replaceAll(',', '.').trim();
    return double.tryParse(s) ?? 0.0;
  }
}