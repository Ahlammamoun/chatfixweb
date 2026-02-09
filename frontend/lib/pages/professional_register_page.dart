import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api_service.dart';

class ProfessionalRegisterPage extends StatefulWidget {
  const ProfessionalRegisterPage({super.key});

  @override
  State<ProfessionalRegisterPage> createState() =>
      _ProfessionalRegisterPageState();
}

class _ProfessionalRegisterPageState extends State<ProfessionalRegisterPage> {
  final _api = ApiService();

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();
  final _zone = TextEditingController();
  final _price = TextEditingController();
  final _siret = TextEditingController();
  final _phone = TextEditingController();
  final _postalCode = TextEditingController();

  // ✅ RIB
  final _ribIban = TextEditingController();

  List<Map<String, dynamic>> _specialities = [];
  int? _selectedSpecialityId;

  // ✅ Photo profil
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  // ✅ Documents
  File? _assuranceFile;
  File? _identityFile;
  File? _proTitleFile;
  File? _ribFile; // optionnel si IBAN

  String _message = '';
  bool _isSuccess = false;
  bool _isLoading = false;
  bool _isFetchingSpecialities = true;

  // ✅ anti multi-open picker (doc)
  bool _pickingDoc = false;

  @override
  void initState() {
    super.initState();
    _loadSpecialities();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    _zone.dispose();
    _price.dispose();
    _siret.dispose();
    _phone.dispose();
    _postalCode.dispose();
    _ribIban.dispose();
    super.dispose();
  }

  bool _isBlank(String? s) => s == null || s.trim().isEmpty;

  String _fileName(File? file) {
    if (file == null) return "Aucun fichier";
    return file.path.split(Platform.pathSeparator).last;
  }

  Future<void> _loadSpecialities() async {
    try {
      final list = await _api.fetchSpecialities();
      if (!mounted) return;
      setState(() {
        _specialities = list;
        _isFetchingSpecialities = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = "Erreur lors du chargement des spécialités : $e";
        _isFetchingSpecialities = false;
        _isSuccess = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      debugPrint("🔥 _pickImage CALLED");

      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      debugPrint("📸 pickedFile => ${pickedFile?.path}");

      if (pickedFile == null) {
        debugPrint("❌ user cancelled");
        return;
      }

      final f = File(pickedFile.path);
      debugPrint("✅ exists => ${await f.exists()} size => ${await f.length()}");

      if (!mounted) return;
      setState(() => _selectedImage = f);
    } catch (e, st) {
      debugPrint("❌ _pickImage error: $e\n$st");
      if (!mounted) return;
      setState(() {
        _message = "Erreur sélection image : $e";
        _isSuccess = false;
      });
    }
  }

  /// ✅ Pick document (PDF/JPG/PNG) et retourne un File
  /// ✅ Anti multi-open : empêche plusieurs OPEN_DOCUMENT (LAUNCH_MULTIPLE)
  Future<File?> _pickDoc() async {
    if (_pickingDoc) return null;
    _pickingDoc = true;
    if (mounted) setState(() {}); // pour désactiver les boutons

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
        allowMultiple: false,
        withData: false,
        withReadStream: false,
        lockParentWindow: true,
      );

      final path = result?.files.single.path;
      if (path == null) return null;

      final f = File(path);

      // Debug utile (taille)
      final exists = await f.exists();
      final size = exists ? await f.length() : 0;
      debugPrint("📄 pickedDoc => $path exists=$exists size=$size");

      return f;
    } catch (e, st) {
      debugPrint("❌ _pickDoc error: $e\n$st");
      if (!mounted) return null;
      setState(() {
        _message = "Erreur sélection fichier : $e";
        _isSuccess = false;
      });
      return null;
    } finally {
      _pickingDoc = false;
      if (mounted) setState(() {}); // ré-active les boutons
    }
  }

  Future<void> _register() async {
    if (_selectedSpecialityId == null) {
      setState(() {
        _message = "⚠️ Veuillez choisir une spécialité";
        _isSuccess = false;
      });
      return;
    }

    if (_isBlank(_email.text) ||
        _isBlank(_password.text) ||
        _isBlank(_phone.text) ||
        _isBlank(_postalCode.text) ||
        _isBlank(_zone.text)) {
      setState(() {
        _message = "⚠️ Merci de remplir tous les champs obligatoires.";
        _isSuccess = false;
      });
      return;
    }

    if (_assuranceFile == null ||
        _identityFile == null ||
        _proTitleFile == null) {
      setState(() {
        _message =
        "⚠️ Merci d’ajouter : Assurance + Pièce d’identité + Titre pro";
        _isSuccess = false;
      });
      return;
    }

    final iban = _ribIban.text.trim();
    if (iban.isEmpty && _ribFile == null) {
      setState(() {
        _message = "⚠️ Merci de fournir un IBAN (texte) ou un fichier RIB.";
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _message = "Envoi en cours...";
      _isSuccess = false;
      _isLoading = true;
    });

    try {
      final result = await _api.registerProfessional(
        email: _email.text.trim(),
        password: _password.text.trim(),
        fullName: _fullName.text.trim(),
        specialityId: _selectedSpecialityId!,
        zone: _zone.text.trim(),
        pricePerHour: double.tryParse(_price.text.trim()) ?? 0,
        siret: _siret.text.trim(),
        phone: _phone.text.trim(),
        postalCode: _postalCode.text.trim(),

        // docs obligatoires
        assuranceFile: _assuranceFile!,
        identityFile: _identityFile!,
        proTitleFile: _proTitleFile!,

        // rib (un des deux)
        ribIban: iban.isEmpty ? null : iban,
        ribFile: _ribFile,

        // photo profil (optionnel)
        profilePicture: _selectedImage,
      );

      if (!mounted) return;
      setState(() {
        _message = (result['message'] ?? '').toString();

        if (result['companyName'] != null) {
          _message += "\n🏢 Société : ${result['companyName']}";
        }

        _isSuccess = (result['success'] == true);
        _isLoading = false;
      });

      if (_isSuccess) {
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/login');
        });
      }
    } catch (e, st) {
      debugPrint("❌ _register error: $e\n$st");
      if (!mounted) return;
      setState(() {
        _message = "Erreur lors de l'inscription : $e";
        _isSuccess = false;
        _isLoading = false;
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
        title: const Text('', style: TextStyle(color: Color(0xFF0D47A1))),
        iconTheme: const IconThemeData(color: Color(0xFF0D47A1)),
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
          child: _isFetchingSpecialities
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // 🟢 Photo de profil
                Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _pickImage,
                      borderRadius: BorderRadius.circular(60),
                      child: Ink(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFBBDEFB),
                          image: _selectedImage != null
                              ? DecorationImage(
                            image: FileImage(_selectedImage!),
                            fit: BoxFit.cover,
                          )
                              : null,
                        ),
                        child: _selectedImage == null
                            ? const Icon(Icons.add_a_photo,
                            size: 36, color: Color(0xFF1565C0))
                            : null,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                _buildTextField(
                    _fullName, "Nom complet", Icons.person_outline),
                _buildDropdown(),
                _buildTextField(
                    _zone, "Ville", Icons.location_on_outlined),
                _buildTextField(
                  _price,
                  "Prix / heure (€)",
                  Icons.euro_symbol,
                  keyboardType: TextInputType.number,
                ),
                _buildTextField(
                  _postalCode,
                  "Code postal",
                  Icons.location_city,
                  keyboardType: TextInputType.number,
                ),
                _buildTextField(
                  _siret,
                  "Numéro SIRET",
                  Icons.confirmation_number_outlined,
                  helper: "14 chiffres sans espaces",
                  keyboardType: TextInputType.number,
                ),
                _buildTextField(
                  _phone,
                  "Numéro de téléphone",
                  Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                _buildTextField(
                  _email,
                  "Adresse e-mail",
                  Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                _buildTextField(
                  _password,
                  "Mot de passe",
                  Icons.lock_outline,
                  obscure: true,
                ),

                const SizedBox(height: 10),

                // ✅ Documents
                _docPickerRow(
                  label: "Assurance (PDF / image)",
                  file: _assuranceFile,
                  onPick: () async {
                    final f = await _pickDoc();
                    if (f == null || !mounted) return;
                    setState(() => _assuranceFile = f);
                  },
                  onClear: () => setState(() => _assuranceFile = null),
                  disabled: _pickingDoc || _isLoading,
                ),
                _docPickerRow(
                  label: "Pièce d’identité (PDF / image)",
                  file: _identityFile,
                  onPick: () async {
                    final f = await _pickDoc();
                    if (f == null || !mounted) return;
                    setState(() => _identityFile = f);
                  },
                  onClear: () => setState(() => _identityFile = null),
                  disabled: _pickingDoc || _isLoading,
                ),
                _docPickerRow(
                  label: "Titre pro (PDF / image)",
                  file: _proTitleFile,
                  onPick: () async {
                    final f = await _pickDoc();
                    if (f == null || !mounted) return;
                    setState(() => _proTitleFile = f);
                  },
                  onClear: () => setState(() => _proTitleFile = null),
                  disabled: _pickingDoc || _isLoading,
                ),

                _buildTextField(
                  _ribIban,
                  "RIB (IBAN) - optionnel si fichier",
                  Icons.account_balance_outlined,
                  helper: "Ex: FR76....",
                ),

                _docPickerRow(
                  label: "RIB (fichier) - optionnel si IBAN",
                  file: _ribFile,
                  onPick: () async {
                    final f = await _pickDoc();
                    if (f == null || !mounted) return;
                    setState(() => _ribFile = f);
                  },
                  onClear: () => setState(() => _ribFile = null),
                  disabled: _pickingDoc || _isLoading,
                ),

                const SizedBox(height: 18),

                // 🟢 Bouton principal
                Center(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding:
                        const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                          : const Text(
                        "S'inscrire",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                if (_message.isNotEmpty)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isSuccess
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isSuccess
                            ? Colors.green
                            : Colors.redAccent,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _isSuccess
                              ? Icons.check_circle
                              : Icons.error_outline,
                          color: _isSuccess
                              ? Colors.green
                              : Colors.redAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _message,
                            style: TextStyle(
                              color: _isSuccess
                                  ? Colors.green.shade900
                                  : Colors.red.shade900,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🧩 UI helpers

  Widget _buildTextField(
      TextEditingController controller,
      String label,
      IconData icon, {
        TextInputType keyboardType = TextInputType.text,
        String? helper,
        bool obscure = false,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          prefixIcon: Icon(icon, color: const Color(0xFF1976D2)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding:
          const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<int>(
        value: _selectedSpecialityId,
        decoration: InputDecoration(
          labelText: 'Spécialité',
          prefixIcon:
          const Icon(Icons.work_outline, color: Color(0xFF1976D2)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding:
          const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        ),
        items: _specialities
            .map(
              (s) => DropdownMenuItem<int>(
            value: s['id'] as int?,
            child: Text((s['name'] ?? '').toString()),
          ),
        )
            .toList(),
        onChanged: (value) => setState(() => _selectedSpecialityId = value),
      ),
    );
  }

  Widget _docPickerRow({
    required String label,
    required File? file,
    required Future<void> Function() onPick,
    required VoidCallback onClear,
    required bool disabled,
  }) {
    final fileName = _fileName(file);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFBBDEFB)),
        ),
        child: Row(
          children: [
            const Icon(Icons.upload_file, color: Color(0xFF1976D2)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(fileName, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: disabled ? null : () async => await onPick(),
              child: Text(disabled ? "..." : "Choisir"),
            ),
            if (file != null)
              IconButton(
                onPressed: disabled ? null : onClear,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
      ),
    );
  }
}

