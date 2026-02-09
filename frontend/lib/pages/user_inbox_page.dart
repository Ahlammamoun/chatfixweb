import 'package:flutter/material.dart';
import '../api_service.dart';
import 'chat_page.dart';

class UserInboxPage extends StatefulWidget {
  const UserInboxPage({super.key});

  @override
  State<UserInboxPage> createState() => _UserInboxPageState();
}

class _UserInboxPageState extends State<UserInboxPage> {
  final ApiService api = ApiService();

  bool loading = true;
  List<Map<String, dynamic>> threads = [];

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

  // ✅ Badge visible même si API renvoie 0 partout (fallback)
  int get badgeCount {
    if (totalUnread > 0) return totalUnread;
    return threads.length;
  }

  @override
  void initState() {
    super.initState();
    _loadInbox();
  }

  Future<void> _loadInbox() async {
    try {
      final data = await api.fetchUserInbox();
      if (!mounted) return;
      setState(() {
        threads = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      debugPrint("Erreur inbox user: $e");
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
    return Scaffold(
      // 🔵 même style que pages pro: AppBar bleu + flèche + enveloppe
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        elevation: 0,
        centerTitle: true,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),

        title: const SizedBox.shrink(),

        actions: [
          IconButton(
            tooltip: "Messages",
            onPressed: () {}, // déjà sur la page messages
            icon: _buildBadge(
              child: const Icon(Icons.mail_outline, color: Colors.white),
              count: badgeCount,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),

      // ✅ enlève bande blanche en haut
      body: SafeArea(
        top: false,
        bottom: true,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFB2EBF2), Color(0xFFE3F2FD), Color(0xFFFFFFFF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
            onRefresh: _loadInbox,
            child: threads.isEmpty
                ? const Center(child: Text("Aucun message pour l’instant."))
                : ListView.separated(
              padding: const EdgeInsets.only(top: 8),
              itemCount: threads.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final t = threads[i];

                final unread = _toInt(t['unreadCount'], fallback: 0);
                final proId = _toInt(t['professionalId'], fallback: 0);
                final proName = (t['professionalName'] ?? 'Professionnel').toString();
                final lastMessage = (t['lastMessage'] ?? '').toString();

                return ListTile(
                  title: Text(
                    proName,
                    style: TextStyle(
                      fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: unread > 0
                      ? CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.red,
                    child: Text(
                      unread > 99 ? '99+' : unread.toString(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                      : const Icon(Icons.chevron_right),
                  onTap: proId <= 0
                      ? null
                      : () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          professionalId: proId,
                          professionalName: proName,
                        ),
                      ),
                    );
                    _loadInbox();
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

