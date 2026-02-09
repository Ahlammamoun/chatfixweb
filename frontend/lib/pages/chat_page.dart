import 'package:flutter/material.dart';
import '../api_service.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class ChatPage extends StatefulWidget {
  final int professionalId;
  final String professionalName;

  const ChatPage({
    super.key,
    required this.professionalId,
    required this.professionalName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ApiService api = ApiService();
  final TextEditingController ctrl = TextEditingController();
  final ScrollController scrollCtrl = ScrollController();

  List<Map<String, dynamic>> items = [];
  bool loading = true;

  // ✅ comme côté PRO : message erreur + regex email/tel
  String? errorMsg;

  final RegExp _emailRegex = RegExp(
    r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
    caseSensitive: false,
  );

  final RegExp _phoneRegex = RegExp(
    r'(\+?\d[\d\s\-.]{7,}\d)',
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    ctrl.dispose();
    scrollCtrl.dispose();
    super.dispose();
  }

  bool _containsForbiddenInfo(String text) {
    return _emailRegex.hasMatch(text) || _phoneRegex.hasMatch(text);
  }

  Future<void> payOffer(int offerId) async {
    try {
      final res = await api.createPaymentIntentForOffer(offerId);
      final clientSecret = res['clientSecret'];

      if (clientSecret == null) {
        throw Exception("clientSecret manquant");
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'ChatFix',
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      // 🔥 IMPORTANT : on rappelle le backend pour qu’il vérifie le PI et mette paid
      await api.createPaymentIntentForOffer(offerId);

      // 🔄 reload pour voir "paid"
      await _load();

     // ✅ récupérer le résumé (coordonnées client + pro + infos paiement)
      final summary = await api.getTransactionSummary(offerId);


      if (!mounted) return;



      // ✅ aller sur l'écran résumé
      Navigator.pushNamed(
        context,
        '/transaction-summary',
        arguments: summary,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Paiement effectué")),
      );
    } on StripeException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Paiement annulé / échoué : ${e.error.localizedMessage ?? ''}",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur paiement : $e")),
      );
    }
  }

  Future<void> _load() async {
    try {
      final data = await api.fetchConversation(widget.professionalId);
      print("CHAT DATA => $data");
      if (!mounted) return;
      setState(() {
        items = data;
        loading = false;
      });

      await Future.delayed(const Duration(milliseconds: 100));
      if (scrollCtrl.hasClients) {
        scrollCtrl.jumpTo(scrollCtrl.position.maxScrollExtent);
      }
    } catch (e) {
      debugPrint("Erreur chargement conversation user: $e");
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _send() async {
    final text = ctrl.text.trim();
    if (text.isEmpty) return;

    // ✅ même blocage que côté PRO
    if (_containsForbiddenInfo(text)) {
      if (!mounted) return;
      setState(() {
        errorMsg =
        "❌ Pour votre sécurité, le partage d’email ou de numéro de téléphone est interdit dans le chat.";
      });
      return;
    }

    if (!mounted) return;
    setState(() => errorMsg = null);

    try {
      await api.sendMessage(
        professionalId: widget.professionalId,
        content: text,
      );
      ctrl.clear();
      _load();
    } catch (e) {
      debugPrint("Erreur envoi message user: $e");
    }
  }

  void _showOfferDialog() {
    final priceCtrl = TextEditingController();
    final msgCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Faire une offre"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Prix proposé (€)"),
            ),
            TextField(
              controller: msgCtrl,
              decoration: const InputDecoration(labelText: "Message (optionnel)"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              final price = double.tryParse(priceCtrl.text.replaceAll(',', '.'));
              if (price == null || price <= 0) return;

              try {
                await api.createOffer(
                  professionalId: widget.professionalId,
                  price: price,
                  message: msgCtrl.text,
                );
                if (context.mounted) Navigator.pop(context);
                _load();
              } catch (e) {
                debugPrint("Erreur création offre: $e");
              }
            },
            child: const Text("Envoyer l’offre"),
          ),
        ],
      ),
    );
  }

  bool get hasPendingOffer {
    return items.any((i) => i['type'] == 'offer' && i['status'] == 'pending');
  }

  Widget _buildMessageBubble(Map<String, dynamic> m) {
    final isMine = m['isMine'] == true;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isMine ? Colors.blue : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          (m['content'] ?? '').toString(),
          style: TextStyle(color: isMine ? Colors.white : Colors.black),
        ),
      ),
    );
  }

  Widget _buildOfferBubble(Map<String, dynamic> o) {
    final status = (o['status'] ?? 'pending').toString();
    final price = (o['price'] ?? '').toString();
    final msg = (o['message'] ?? '').toString();

    String title;
    if (status == 'accepted') {
      title = "✅ Offre acceptée";
    } else if (status == 'refused') {
      title = "❌ Offre refusée";
    } else if (status == 'paid') {
      title = "✅ Offre payée";
    } else {
      title = "💼 Offre en attente";
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: const Color(0xFF1976D2), // 🔵 bleu foncé (tu peux ajuster)

          border: Border.all(color: Colors.black, width: 1.5), // ⚫ contour noir
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text("💰 $price €", style: const TextStyle(color: Colors.white)),
            if (msg.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(msg, style: const TextStyle(color: Colors.white)),
            ],

            const SizedBox(height: 6),
            Chip(
              label: Text(status, style: const TextStyle(color: Colors.white)),
              backgroundColor: status == 'pending'
                  ? Colors.deepOrange
                  : (status == 'accepted' || status == 'paid')
                  ? Colors.green
                  : Colors.red,
            ),


            // ✅ BOUTON PAYER UNIQUEMENT SI ACCEPTED
            if (status == 'accepted') ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => payOffer((o['id'] as num).toInt()),
                  child: const Text("Payer"),
                ),
              ),
            ],

            // ✅ BOUTON RÉSUMÉ POUR LE CLIENT QUAND PAYÉ
            if (status == 'paid') ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      final offerId = (o['id'] as num).toInt();
                      final summary = await api.getTransactionSummary(offerId);

                      if (!context.mounted) return;
                      Navigator.pushNamed(
                        context,
                        '/transaction-summary',
                        arguments: summary,
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Erreur résumé : $e")),
                      );
                    }
                  },
                  child: const Text("Voir le résumé"),
                ),
              ),
            ],



          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.professionalName),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_offer),
            onPressed: (loading || hasPendingOffer) ? null : _showOfferDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  if (item['type'] == 'offer') {
                    return _buildOfferBubble(item);
                  }
                  return _buildMessageBubble(item);
                },
              ),
            ),
          ),

          // ✅ affichage erreur comme côté PRO
          if (errorMsg != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                errorMsg!,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    decoration: const InputDecoration(
                      hintText: "Répondre…",
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

