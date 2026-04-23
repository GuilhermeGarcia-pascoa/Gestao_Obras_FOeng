import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

const bool isLocalhost = false; // Muda para false para usar o servidor de produção
const String meuIpDoPC = '192.168.1.246'; // O teu IP local (para telemóvel via Wi-Fi)
const int port = 6002;
const String servidorProducao = 'http://192.168.1.246:6002/api';

class ApiConfig {
  static String get baseUrl {
    if (!isLocalhost) {
      // Produção — servidor real
      return servidorProducao;
          }

    // Desenvolvimento local — deteta automaticamente a plataforma
    if (kIsWeb) {
      // Chrome / browser
      return 'http://$meuIpDoPC:$port/api';
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
