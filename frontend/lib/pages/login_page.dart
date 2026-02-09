import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _api = ApiService();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _result = '';
  bool _isLoading = false;

  // ==============================
  // 🔐 Fonction de connexion
  // ==============================
  Future<void> _login() async {
    if (_email.text.isEmpty || _password.text.isEmpty) {
      setState(() => _result = "⚠️ Veuillez remplir tous les champs");
      return;
    }

    setState(() {
      _isLoading = true;
      _result = '';
    });

    final res = await _api.login(_email.text.trim(), _password.text.trim());

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true && res['token'] != null) {
      final token = res['token'] as String;

      // ✅ IMPORTANT: nettoyer les anciennes infos avant d'écrire les nouvelles
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('name');
      await prefs.remove('lastname');

      // 🔎 On demande le profil au backend pour connaître le rôle + nom/prénom
      final me = await _api.getMe(token);

      if (!mounted) return;

      if (me['success'] == true) {
        final user = me['user'] as Map<String, dynamic>;

        // Ton backend renvoie parfois role = "ROLE_USER" / "ROLE_PROFESSIONAL"
        final rawRole = (user['role'] ?? '').toString().toLowerCase();
        final email = (user['email'] ?? '').toString();

        // ✅ récupère name/lastname (si présents)
        final name = (user['name'] ?? '').toString().trim();
        final lastname = (user['lastname'] ?? '').toString().trim();

        // (optionnel) garde en mémoire
        await prefs.setString('token', token);
        await prefs.setString('email', email);
        await prefs.setString('role', rawRole);

        if (name.isNotEmpty) await prefs.setString('name', name);
        if (lastname.isNotEmpty) await prefs.setString('lastname', lastname);

        // ✅ Navigation
        if (rawRole.contains('professional')) {
          Navigator.pushReplacementNamed(
            context,
            '/pro_home',
            arguments: {'email': email},
          );
        } else {
          Navigator.pushReplacementNamed(
            context,
            '/user_home',
            arguments: {'email': email},
          );
        }
      } else {
        setState(() => _result = me['message'] ?? "❌ Impossible de récupérer le profil.");
      }
    } else {
      setState(() => _result = res['message'] ?? "❌ Erreur de connexion.");
    }
  }

  // ==============================
  // 🖼️ Interface utilisateur
  // ==============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFB2EBF2), Color(0xFFE3F2FD), Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/chatfix_logo.png',
                    height: 90,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Bienvenue sur ChatFix',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                  const SizedBox(height: 30),

                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Adresse e-mail',
                      prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF1976D2)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF1976D2)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                        'Se connecter',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_result.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: _result.contains('❌') || _result.contains('Erreur')
                            ? Colors.red.shade100
                            : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _result,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _result.contains('❌') || _result.contains('Erreur')
                              ? Colors.red.shade900
                              : Colors.green.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Pas encore de compte ? "),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/');
                        },
                        child: const Text(
                          "S'inscrire",
                          style: TextStyle(
                            color: Color(0xFF1976D2),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
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

