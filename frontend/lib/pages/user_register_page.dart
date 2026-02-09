import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../api_service.dart';

class UserRegisterPage extends StatefulWidget {
  const UserRegisterPage({super.key});

  @override
  State<UserRegisterPage> createState() => _UserRegisterPageState();
}

class _UserRegisterPageState extends State<UserRegisterPage> {
  final _api = ApiService();

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _lastnameCtrl = TextEditingController();
  final _postalCodeCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  // ✅ RIB
  final _ribIbanCtrl = TextEditingController();
  File? _ribFile;

  String _result = '';
  bool _isLoading = false;
  bool _isSuccess = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _nameCtrl.dispose();
    _lastnameCtrl.dispose();
    _postalCodeCtrl.dispose();
    _cityCtrl.dispose();
    _ribIbanCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickRibFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      withData: false,
    );

    if (res != null && res.files.single.path != null) {
      setState(() {
        _ribFile = File(res.files.single.path!);
      });
    }
  }

  void _clearRibFile() {
    setState(() => _ribFile = null);
  }

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _result = "⏳ Inscription en cours...";
      _isSuccess = false;
    });

    // ✅ règle : si fichier choisi, on n’envoie pas ribIban
    final ribIbanToSend =
    (_ribFile != null) ? null : _ribIbanCtrl.text.trim();

    final result = await _api.registerUser(
      email: _email.text.trim(),
      password: _password.text.trim(),
      name: _nameCtrl.text.trim(),
      lastname: _lastnameCtrl.text.trim(),
      postalCode: _postalCodeCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      ribIban: ribIbanToSend != null && ribIbanToSend.isNotEmpty ? ribIbanToSend : null,
      ribFile: _ribFile,
    );

    setState(() {
      _isLoading = false;
      _result = result['message']?.toString() ?? 'Réponse inconnue';
      _isSuccess = result['success'] == true;
    });

    if (!mounted) return;

    if (_isSuccess) {
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
      });
    }

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 30),

                Image.asset('assets/chatfix_logo.png', height: 80),
                const SizedBox(height: 12),

                const Text(
                  'Créer un compte',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                const SizedBox(height: 30),

                _field(
                  controller: _nameCtrl,
                  label: 'Prénom',
                  icon: Icons.person,
                ),
                const SizedBox(height: 16),

                _field(
                  controller: _lastnameCtrl,
                  label: 'Nom',
                  icon: Icons.badge,
                ),
                const SizedBox(height: 16),

                _field(
                  controller: _email,
                  label: 'Adresse e-mail',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                _field(
                  controller: _postalCodeCtrl,
                  label: 'Code postal',
                  icon: Icons.location_on_outlined,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                _field(
                  controller: _cityCtrl,
                  label: 'Ville',
                  icon: Icons.location_city,
                ),
                const SizedBox(height: 16),

                _field(
                  controller: _password,
                  label: 'Mot de passe',
                  icon: Icons.lock_outline,
                  obscureText: true,
                ),

                const SizedBox(height: 24),

                // ✅ RIB IBAN (optionnel)
                _field(
                  controller: _ribIbanCtrl,
                  label: 'RIB (IBAN) - pour le cashback',
                  icon: Icons.account_balance,
                  helperText: _ribFile != null
                      ? "Un fichier RIB est sélectionné : l’IBAN ne sera pas envoyé."
                      : "Ex: FR76.... (sans espaces).",
                  enabled: _ribFile == null, // désactivé si fichier choisi
                ),



                const SizedBox(height: 12),

                // ✅ RIB fichier (optionnel, pour le cashback)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _pickRibFile,
                        icon: const Icon(Icons.upload_file),
                        label: Text(_ribFile == null
                            ? "Choisir un fichier RIB (PDF/JPG/PNG)"
                            : "RIB sélectionné"),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (_ribFile != null)
                      IconButton(
                        onPressed: _isLoading ? null : _clearRibFile,
                        icon: const Icon(Icons.close),
                        tooltip: "Retirer le fichier",
                      ),
                  ],
                ),

                if (_ribFile != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "📄 ${_ribFile!.path.split('/').last}",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                        : const Text(
                      "Créer mon compte",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                if (_result.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isSuccess ? Colors.green.shade100 : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isSuccess ? Colors.green : Colors.redAccent,
                      ),
                    ),
                    child: Text(
                      _result,
                      style: TextStyle(
                        color: _isSuccess ? Colors.green.shade900 : Colors.red.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/login'),
                  child: const Text(
                    "Déjà un compte ? Se connecter",
                    style: TextStyle(
                      color: Color(0xFF1976D2),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? helperText,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: Icon(icon, color: const Color(0xFF1976D2)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
