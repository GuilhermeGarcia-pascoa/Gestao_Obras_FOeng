import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;


// ─── CONFIGURAÇÃO CENTRAL DA API ─────────────────────────────────────────────
// Edita apenas este ficheiro quando precisares de mudar o ambiente.
// isLocalhost = true  → usa o servidor local (desenvolvimento)
// isLocalhost = false → usa o servidor de produção (servidor real)
const bool isLocalhost = false;
const String meuIpDoPC = '192.168.1.62'; // O teu IP local (para telemóvel via Wi-Fi)
const int port = 3001;
const String servidorProducao = 'http://192.168.1.246:3001/api';

class ApiConfig {
  static String get baseUrl {
    if (!isLocalhost) {
      // Produção — servidor real
      return servidorProducao;
          }

    // Desenvolvimento local — deteta automaticamente a plataforma
    if (kIsWeb) {
      // Chrome / browser
      return 'http://localhost:$port/api';
    }

    try {
      if (Platform.isAndroid) {
        // Emulador Android usa 10.0.2.2 para chegar ao localhost do PC
        return 'http://$meuIpDoPC:$port/api';
      }
      if (Platform.isIOS) {
        return 'http://localhost:$port/api';
      }
    } catch (_) {}

    // Fallback — telemóvel físico via Wi-Fi
    return 'http://$meuIpDoPC:$port/api';
  }
}
