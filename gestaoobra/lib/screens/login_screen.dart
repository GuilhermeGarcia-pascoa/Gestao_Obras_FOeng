import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _verPassword   = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preenche o email e a password')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok   = await auth.login(email, password);

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
    final auth      = context.watch<AuthProvider>();
    final theme     = Theme.of(context);
    final isDark    = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    // Cores adaptadas ao tema
    final bgColor      = isDark ? const Color(0xFF121212) : const Color(0xFF1A1A2E);
    final cardColor    = isDark ? const Color(0xFF1E1F2A) : Colors.white;
    final iconColor    = isDark ? Colors.white70 : Colors.white;
    final tituloColor  = isDark ? Colors.white70 : Colors.white54;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Logo ─────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.construction, color: iconColor, size: 52),
                ),
                const SizedBox(height: 20),
                Text(
                  'Gestão de Obra',
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Inicia sessão para continuar',
                  style: TextStyle(color: tituloColor, fontSize: 14),
                ),
                const SizedBox(height: 40),

                // ── Card de login ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Iniciar sessão',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Email
                      TextField(
                        controller:    _emailCtrl,
                        keyboardType:  TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect:   false,
                        decoration: InputDecoration(
                          labelText:  'Email',
                          prefixIcon: Icon(Icons.email_outlined, color: colorScheme.primary),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextField(
                        controller:      _passwordCtrl,
                        obscureText:     !_verPassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted:     (_) => _login(),
                        decoration: InputDecoration(
                          labelText:  'Password',
                          prefixIcon: Icon(Icons.lock_outline, color: colorScheme.primary),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _verPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey,
                            ),
                            onPressed: () => setState(() => _verPassword = !_verPassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Botão entrar
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: ElevatedButton(
                          key: ValueKey(auth.loading),
                          onPressed: auth.loading ? null : _login,
                          child: auth.loading
                              ? const SizedBox(
                                  height: 22,
                                  width:  22,
                                  child:  CircularProgressIndicator(
                                    color:       Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Entrar',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Versão discreta
                Text(
                  'v1.6.7',
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}