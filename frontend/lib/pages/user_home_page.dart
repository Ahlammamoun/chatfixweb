import 'package:flutter/material.dart';
import '../api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_page.dart';
import 'user_inbox_page.dart';
import 'support_page.dart';


class UserHomePage extends StatefulWidget {
  final String email;
  const UserHomePage({super.key, required this.email});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  final ApiService api = ApiService();
  final TextEditingController searchCtrl = TextEditingController();

  List<Map<String, dynamic>> pros = [];
  List<Map<String, dynamic>> specialities = [];

  String? selectedSpeciality;
  String? userName;
  bool isLoading = false;

  // ✅ Inbox threads + badge global
  bool inboxLoading = true;
  List<Map<String, dynamic>> threads = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadUserCoordinates();
    await _loadUserName();
    _loadSpecialities();
    _loadInbox();
  }
  String? _photoUrl(dynamic profilePicture) {
    final p = (profilePicture ?? '').toString().trim();
    if (p.isEmpty) return null;

    // Si l'API renvoie déjà une URL complète
    if (p.startsWith('http://') || p.startsWith('https://')) return p;

    // Normaliser en chemin web
    final path = p.startsWith('/') ? p : '/$p';

    // ⚠️ adapte si ton ApiService expose baseUrl autrement
    return "${api.baseUrl}$path";
  }

  Widget _proAvatar(Map<String, dynamic> p) {
    final url = _photoUrl(p['profilePicture'] ?? p['profile_picture']);
    return CircleAvatar(
      radius: 26,
      backgroundColor: Colors.grey.shade200,
      backgroundImage: url != null ? NetworkImage(url) : null,
      child: url == null ? const Icon(Icons.person, color: Colors.black54) : null,
    );
  }


  Widget _stars(dynamic avg, dynamic count) {
    final double a =
    (avg is num) ? avg.toDouble() : double.tryParse('$avg') ?? 0.0;
    final int c = (count is num) ? count.toInt() : int.tryParse('$count') ?? 0;

    if (c == 0) {
      return const Text(
        "Nouveau",
        style: TextStyle(fontSize: 12, color: Colors.black54),
      );
    }

    final int filled = a.round().clamp(0, 5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          final on = i < filled;
          return Icon(
            on ? Icons.star : Icons.star_border,
            size: 18,
            color: on ? Colors.amber : Colors.grey,
          );
        }),
        const SizedBox(width: 6),
        Text(
          "($c)",
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
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

  int get threadsCount => threads.length;

  /// ✅ Badge visible:
  /// - si unread > 0 => unread
  /// - sinon => nombre de conversations
  int get badgeCount {
    if (totalUnread > 0) return totalUnread;
    return threadsCount;
  }

  Future<void> _loadInbox() async {
    try {
      final data = await api.fetchUserInbox();
      if (!mounted) return;
      setState(() {
        threads = data;
        inboxLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => inboxLoading = false);
      debugPrint("Erreur inbox user: $e");
    }
  }

  Future<void> _loadUserCoordinates() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    final data = await api.fetchUserCoordinates(token);

    if (data['success'] == true) {
      if (data['lat'] != null && data['lng'] != null) {
        await prefs.setDouble('lat', data['lat']);
        await prefs.setDouble('lng', data['lng']);
      }
      if (data['name'] != null) await prefs.setString('name', data['name']);
      if (data['lastname'] != null) await prefs.setString('lastname', data['lastname']);
    }
  }

  Future<void> _loadSpecialities() async {
    try {
      final data = await api.fetchSpecialities();
      if (!mounted) return;
      setState(() => specialities = data);
    } catch (e) {
      debugPrint("Erreur chargement spécialités: $e");
    }
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('name');
    final lastname = prefs.getString('lastname');

    if (name != null && lastname != null) {
      if (!mounted) return;
      setState(() => userName = "$name $lastname");
      return;
    }

    final email = prefs.getString('email') ?? widget.email;
    if (!mounted) return;
    setState(() => userName = email.split('@').first);
  }

  Future<void> _search() async {
    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final double? lat = prefs.getDouble('lat');
      final double? lng = prefs.getDouble('lng');

      final data = await api.searchProfessionals(
        speciality: selectedSpeciality,
        query: searchCtrl.text,
        lat: lat,
        lng: lng,
      );

      if (!mounted) return;
      setState(() => pros = data);
    } catch (e) {
      debugPrint("Erreur recherche: $e");
    } finally {
      if (!mounted) return;
      setState(() => isLoading = false);
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

  Future<void> _openInbox() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserInboxPage()),
    );
    _loadInbox();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🔵 AppBar bleu, seulement flèche + enveloppe
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        elevation: 0,
        centerTitle: true,

        leading: Navigator.canPop(context)
            ? IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        )
            : null,

        title: const SizedBox.shrink(),

        actions: [
          IconButton(
            tooltip: "Support",
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SupportPage()),
              );
            },
          ),
          IconButton(
            tooltip: "Messages",
            onPressed: inboxLoading ? null : _openInbox,
            icon: _buildBadge(
              child: const Icon(Icons.mail_outline, color: Colors.white),
              count: badgeCount,
            ),
          ),

        ],
      ),

      // ✅ Supprime la bande blanche du haut
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header user
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Color(0xFF1976D2),
                      child: Icon(Icons.person, size: 30, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName != null ? "Bienvenue à toi ${userName!}" : "Bienvenue",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D47A1),
                            ),
                          ),
                          Text(
                            widget.email,
                            style: const TextStyle(fontSize: 14, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                // SPECIALITÉ
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Spécialité',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  value: selectedSpeciality,
                  items: specialities
                      .map((spec) => DropdownMenuItem<String>(
                    value: spec['name'] as String,
                    child: Text(spec['name']),
                  ))
                      .toList(),
                  onChanged: (value) => setState(() => selectedSpeciality = value),
                ),

                const SizedBox(height: 16),

                // RECHERCHER
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _search,
                    icon: const Icon(Icons.search, color: Colors.white),
                    label: const Text(
                      "Rechercher",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Liste pros
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : pros.isEmpty
                      ? const Center(child: Text("Aucun professionnel trouvé"))
                      : ListView.builder(
                    itemCount: pros.length,
                    itemBuilder: (context, index) {
                      final p = pros[index];
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 3,
                        child: ListTile(
                          leading: _proAvatar(p),
                          title: Row(
                            children: [
                              Expanded(child: Text(p['fullName'] ?? '')),
                              _stars(p['avgRating'], p['ratingCount']),
                            ],
                          ),
                          subtitle: Text(
                            "${p['speciality']} • ${p['zone']}\n"
                                "${p['pricePerHour']}€/h — ${p['distance']} km",
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatPage(
                                  professionalId: p['id'],
                                  professionalName: p['fullName'],
                                ),
                              ),
                            );
                            _loadInbox();
                          },
                        ),


                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

