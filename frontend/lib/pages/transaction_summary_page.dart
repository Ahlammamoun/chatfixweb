import 'package:flutter/material.dart';
import '../api_service.dart';

class TransactionSummaryPage extends StatelessWidget {
  const TransactionSummaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
    ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    final offer = (args['offer'] ?? {}) as Map<String, dynamic>;
    final payment = (args['payment'] ?? {}) as Map<String, dynamic>;
    final client = (args['client'] ?? {}) as Map<String, dynamic>;
    final pro = (args['professional'] ?? {}) as Map<String, dynamic>;

    final offerId = (offer['id'] as num?)?.toInt();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Résumé de la transaction"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle("💳 Paiement"),
            _row(
              "Montant",
              "${(((payment['amountCents'] ?? 0) as num) / 100).toStringAsFixed(2)} €",
            ),
            _row("Date", (offer['paidAt'] ?? '').toString()),
            _row("Statut", (payment['status'] ?? '').toString()),

            const SizedBox(height: 20),

            _sectionTitle("👤 Client"),
            _row(
              "Nom",
              "${(client['name'] ?? '').toString()} ${(client['lastname'] ?? '').toString()}",
            ),
            _row("Email", (client['email'] ?? '').toString()),


            const SizedBox(height: 20),

            _sectionTitle("🧑‍🔧 Professionnel"),
            _row("Nom", (pro['fullName'] ?? '').toString()),
            _row("Société", (pro['companyName'] ?? '').toString()),
            _row("Téléphone", (pro['phoneNumber'] ?? '').toString()),
            _row("Email", (pro['email'] ?? '').toString()),
            _row("Zone", (pro['zone'] ?? '').toString()),

            const SizedBox(height: 24),

            // ✅ Bouton noter
            if (offerId != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showRateDialog(context, offerId),
                  icon: const Icon(Icons.star_rate),
                  label: const Text("Noter le professionnel"),
                ),
              )
            else
              const Text(
                "Impossible de noter : id de l’offre manquant dans le résumé.",
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }

  void _showRateDialog(BuildContext context, int offerId) {
    int selected = 5;
    final api = ApiService();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text("Noter le professionnel"),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final v = i + 1;
              final filled = v <= selected;
              return IconButton(
                onPressed: () => setStateDialog(() => selected = v),
                icon: Icon(
                  filled ? Icons.star : Icons.star_border,
                  color: filled ? Colors.amber : Colors.grey,
                ),
              );
            }),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await api.rateOffer(offerId, selected);
                  if (context.mounted) Navigator.pop(ctx);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("✅ Merci pour votre note !")),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Erreur notation : $e")),
                  );
                }
              },
              child: const Text("Envoyer"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text("$label :")),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : "-",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
