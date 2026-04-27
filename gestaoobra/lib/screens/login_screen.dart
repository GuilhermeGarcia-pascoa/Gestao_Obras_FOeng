import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _verPassword = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preenche o email e a password')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok = await auth.login(email, password);

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.erro ?? 'Erro ao iniciar sessão'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const seed = Color(0xFF185FA5);

    return Scaffold(
      body: SafeArea(
          child: Center( // Centraliza horizontalmente o conteúdo
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Container(
                // Define a largura máxima para o formulário não ir de um lado ao outro em tablets/web
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch, // Garante que os campos ocupam a largura do maxWidth
                  children: [
                    // --- Ícone ---
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: seed.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: seed.withOpacity(0.25), width: 1.5),
                        ),
                        child: const Icon(Icons.construction_rounded, color: seed, size: 48),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Gestão de Obra',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? const Color(0xFFE8EDF5) : const Color(0xFF1A2233),
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Inicia sessão para continuar',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 14),
                    ),
                    const SizedBox(height: 36),

                    // --- Card do Formulário ---
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2530) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Iniciar sessão',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFE8EDF5) : const Color(0xFF1A2233),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            style: TextStyle(color: isDark ? const Color(0xFFE8EDF5) : const Color(0xFF1A2233)),
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined, color: seed),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passwordCtrl,
                            obscureText: !_verPassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _login(),
                            style: TextStyle(color: isDark ? const Color(0xFFE8EDF5) : const Color(0xFF1A2233)),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline, color: seed),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _verPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: const Color(0xFF8B9BB4),
                                ),
                                onPressed: () => setState(() => _verPassword = !_verPassword),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: auth.loading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: seed,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: auth.loading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : const Text('Entrar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),
                    Text(
                      'v2.6.7',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    
  }
}