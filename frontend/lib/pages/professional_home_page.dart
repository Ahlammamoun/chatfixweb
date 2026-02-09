import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_service.dart';
import 'pro_chat_page.dart';
import 'support_page.dart';


class ProfessionalHomePage extends StatefulWidget {
  final String email;
  const ProfessionalHomePage({super.key, required this.email});

  @override
  State<ProfessionalHomePage> createState() => _ProfessionalHomePageState();
}

class _ProfessionalHomePageState extends State<ProfessionalHomePage> {
  final api = ApiService();

  bool loading = true;
  List<Map<String, dynamic>> threads = [];

  String _proDisplayName = "";

  @override
  void initState() {
    super.initState();
    _loadProIdentity(); // ✅ récupère le pro connecté
    _loadInbox();
  }

  int _toInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  int get totalUnread {
    int sum = 0;
    for (final t in threads) {
      sum += _toInt(t['unreadCount'], fallback: 0);
    }
    return sum;
  }

  Future<void> _loadProIdentity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() => _proDisplayName = widget.email);
        return;
      }

      final me = await api.getMe(token);

      if (!mounted) return;

      if (me['success'] == true && me['user'] != null) {
        final u = me['user'] as Map<String, dynamic>;

        // ✅ PRIORITÉ : nom pro (Professional.fullName)
        final pro = u['professional'];
        final proFullName = (pro is Map && pro['fullName'] != null)
            ? pro['fullName'].toString().trim()
            : '';

        if (proFullName.isNotEmpty) {
          setState(() => _proDisplayName = proFullName);
          return;
        }

        // fallback: name/lastname user
        final name = (u['name'] ?? '').toString().trim();
        final lastname = (u['lastname'] ?? '').toString().trim();
        final full = "$name $lastname".trim();

        setState(() => _proDisplayName = full.isNotEmpty ? full : widget.email);
      } else {
        setState(() => _proDisplayName = widget.email);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _proDisplayName = widget.email);
    }
  }

  Future<void> _loadInbox() async {
    try {
      final data = await api.fetchProInbox();
      if (!mounted) return;
      setState(() {
        threads = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      debugPrint("Erreur inbox pro: $e");
    }
  }

  Widget _buildBadge({required Widget child, required int count}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (count > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              constraints: const BoxConstraints(minWidth: 18),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleName = _proDisplayName.isNotEmpty ? _proDisplayName : widget.email;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2), // 🔵 bleu
        iconTheme: const IconThemeData(color: Colors.white),

        title: Text(
          "Messages pour $titleName",
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white),
        ),

        actions: [
          IconButton(
            tooltip: "Support",
            icon: const Icon(Icons.help_outline), // plus besoin de color ici
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SupportPage()),
              );
            },
          ),

          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: "Messages non lus",
              onPressed: () {},
              icon: _buildBadge(
                child: const Icon(Icons.chat_bubble_outline),
                count: totalUnread,
              ),
            ),
          ),
        ],
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadInbox,
        child: threads.isEmpty
            ? const Center(child: Text("Aucun message pour l’instant."))
            : ListView.separated(
          itemCount: threads.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final t = threads[i];

            final unread = _toInt(t['unreadCount'], fallback: 0);
            final clientId = _toInt(t['clientId'], fallback: 0);
            final clientName = (t['clientName'] ?? 'Client').toString();
            final lastMessage = (t['lastMessage'] ?? '').toString();

            return ListTile(
              leading: Icon(
                unread > 0 ? Icons.mark_chat_unread : Icons.chat_bubble_outline,
                color: unread > 0 ? Colors.blue : null,
              ),
              title: Text(
                clientName,
                style: TextStyle(
                  fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
              trailing: unread > 0
                  ? CircleAvatar(
                radius: 12,
                child: Text(
                  unread.toString(),
                  style: const TextStyle(fontSize: 12),
                ),
              )
                  : null,
              onTap: clientId <= 0
                  ? null
                  : () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProChatPage(
                      clientId: clientId,
                      clientName: clientName,
                    ),
                  ),
                );
                _loadInbox(); // refresh après retour du chat
              },
            );
          },
        ),
      ),
    );
  }
}


