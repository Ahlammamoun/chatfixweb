import 'package:flutter/material.dart';
import '../api_service.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> with SingleTickerProviderStateMixin {
  final ApiService api = ApiService();

  late final TabController _tab;

  final emailCtrl = TextEditingController();
  final subjectCtrl = TextEditingController();
  final messageCtrl = TextEditingController();

  bool sending = false;
  String? statusMsg;

  static const _blue = Color(0xFF1976D2);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    emailCtrl.dispose();
    subjectCtrl.dispose();
    messageCtrl.dispose();
    super.dispose();
  }

  // ✅ FAQ statique
  final List<Map<String, String>> faqs = const [
    {
      "q": "Comment contacter un professionnel ?",
      "a": "Va dans la recherche, choisis une spécialité, puis clique sur un professionnel pour ouvrir le chat."
    },
    {
      "q": "Pourquoi je ne vois pas mes messages ?",
      "a": "Vérifie ta connexion et ouvre la page Messages (enveloppe). Tire vers le bas pour rafraîchir."
    },
    {
      "q": "Comment envoyer une offre ?",
      "a": "Dans le chat avec le professionnel, appuie sur l’icône 'offre' (étiquette) en haut."
    },
    {
      "q": "Pourquoi je ne vois pas mes messages ?",
      "a": "Vérifie ta connexion internet et ouvre la page Messages (icône enveloppe). Tire vers le bas pour rafraîchir."
    },
    {
      "q": "Comment savoir si mon message a été lu ?",
      "a": "Dans le chat, une coche apparaît quand ton message est envoyé, deux coches quand il est lu."
    },
    {
      "q": "Puis-je discuter avec plusieurs professionnels ?",
      "a": "Oui, tu peux avoir plusieurs conversations en même temps. Elles apparaissent toutes dans ta messagerie."
    },
    {
      "q": "Comment modifier mes informations personnelles ?",
      "a": "Pour l’instant, tu peux modifier ton nom et tes coordonnées depuis les paramètres de ton compte."
    },
    {
      "q": "Je n’arrive pas à me connecter, que faire ?",
      "a": "Vérifie ton email et ton mot de passe. Si le problème persiste, utilise le formulaire de contact du support."
    },
    {
      "q": "Mes offres sont-elles visibles par tout le monde ?",
      "a": "Non, tes offres sont privées et visibles uniquement par le professionnel concerné dans votre conversation."
    },
    {
      "q": "Comment contacter le support ?",
      "a": "Va dans la page Support, onglet Contact, remplis le formulaire et notre équipe te répondra rapidement."
    },
  ];

  InputDecoration _inputDeco(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: _blue) : null,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _sendContact() async {
    setState(() => statusMsg = null);

    final email = emailCtrl.text.trim();
    final subject = subjectCtrl.text.trim();
    final message = messageCtrl.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() => statusMsg = "⚠️ Email invalide");
      return;
    }
    if (subject.isEmpty) {
      setState(() => statusMsg = "⚠️ Objet obligatoire");
      return;
    }
    if (message.isEmpty || message.length < 5) {
      setState(() => statusMsg = "⚠️ Message trop court");
      return;
    }

    setState(() => sending = true);

    try {
      final res = await api.sendSupportContact(
        email: email,
        subject: subject,
        message: message,
      );

      if (!mounted) return;

      setState(() {
        sending = false;
        statusMsg = res['success'] == true
            ? "✅ Message envoyé au support"
            : (res['message'] ?? "❌ Erreur");
      });

      if (res['success'] == true) {
        subjectCtrl.clear();
        messageCtrl.clear();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        sending = false;
        statusMsg = "❌ Erreur réseau";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ AppBar bleu + tabs style app
      appBar: AppBar(
        backgroundColor: _blue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Support", style: TextStyle(color: Colors.white)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "FAQ"),
            Tab(text: "Contact"),
          ],
        ),
      ),

      // ✅ pas de bande blanche
      body: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFB2EBF2), Color(0xFFE3F2FD), Color(0xFFFFFFFF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: TabBarView(
            controller: _tab,
            children: [
              // ---------------- FAQ ----------------
              ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: faqs.length,
                itemBuilder: (_, i) {
                  final f = faqs[i];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: ExpansionTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      leading: const Icon(Icons.help_outline, color: _blue),
                      title: Text(
                        f["q"]!,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        Text(
                          f["a"]!,
                          style: const TextStyle(color: Colors.black87, height: 1.3),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // ---------------- CONTACT ----------------
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // petite carte pour faire propre
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          TextField(
                            controller: emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDeco("Ton email", icon: Icons.email_outlined),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: subjectCtrl,
                            decoration: _inputDeco("Objet", icon: Icons.subject),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: messageCtrl,
                            maxLines: 6,
                            decoration: _inputDeco("Message", icon: Icons.chat_outlined),
                          ),
                          const SizedBox(height: 16),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: sending ? null : _sendContact,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _blue,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              icon: sending
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : const Icon(Icons.send, color: Colors.white),
                              label: Text(
                                sending ? "Envoi..." : "Envoyer",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),

                          if (statusMsg != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: statusMsg!.contains("✅")
                                    ? Colors.green.shade100
                                    : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                statusMsg!,
                                style: TextStyle(
                                  color: statusMsg!.contains("✅")
                                      ? Colors.green.shade900
                                      : Colors.red.shade900,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  const Text(
                    "Nous répondons dès que possible.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
