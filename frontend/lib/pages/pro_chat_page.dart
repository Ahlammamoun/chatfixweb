import 'package:flutter/material.dart';
import '../api_service.dart';

class ProChatPage extends StatefulWidget {
  final int clientId;
  final String clientName;

  const ProChatPage({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<ProChatPage> createState() => _ProChatPageState();
}

class _ProChatPageState extends State<ProChatPage> {
  final ApiService api = ApiService();
  final TextEditingController ctrl = TextEditingController();
  final ScrollController scrollCtrl = ScrollController();

  List<Map<String, dynamic>> items = [];
  bool loading = true;

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

  Future<void> _load() async {
    final data = await api.fetchProConversation(widget.clientId);

    if (!mounted) return;
    setState(() {
      items = data;
      loading = false;
    });

    await Future.delayed(const Duration(milliseconds: 100));
    if (scrollCtrl.hasClients) {
      scrollCtrl.jumpTo(scrollCtrl.position.maxScrollExtent);
    }
  }

  bool _containsForbiddenInfo(String text) {
    return _emailRegex.hasMatch(text) || _phoneRegex.hasMatch(text);
  }

  Future<void> _send() async {
    final text = ctrl.text.trim();
    if (text.isEmpty) return;

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

    await api.sendProMessage(
      clientId: widget.clientId,
      content: text,
    );

    ctrl.clear();
    _load();
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
      title = "💰 Offre payée";
    } else {
      title = "💼 Offre reçue";
    }

    return Align(
      alignment: Alignment.centerLeft, // côté pro : vient du client
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: const Color(0xFF1976D2), // 🔵 bleu clair (recommandé)

          border: Border.all(color: Colors.black, width: 1.5), // contour noir
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text("💰 $price €", style: const TextStyle(color: Colors.white)),
            if (msg.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(msg, style: const TextStyle(color: Colors.white)),
            ],

            const SizedBox(height: 6),

            Chip(label: Text(status)),

// ✅ Boutons seulement si pending
            if (status == 'pending') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: () async {
                        await api.acceptOffer(o['id']);
                        _load();
                      },
                      child: const Text("Accepter"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () async {
                        await api.refuseOffer(o['id']);
                        _load();
                      },
                      child: const Text("Refuser"),
                    ),
                  ),
                ],
              ),
            ],

// ✅ Bouton résumé UNIQUEMENT si payé
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
      appBar: AppBar(title: Text(widget.clientName)),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
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
