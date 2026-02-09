import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;


class ApiService {
  // ⚙️ Adresse de ton backend Symfony
  final String baseUrl = "http://10.0.2.2:8000";
 // Android émulateur
  // Si tu testes sur un vrai téléphone : remplace 10.0.2.2 par ton IP locale (ex: 192.168.x.x)

  // ===============================
  // 🔐 Connexion utilisateur (JWT)
  // ===============================
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {

        // 🔥 Sauvegarde locale
        final prefs = await SharedPreferences.getInstance();

        // ———————— COORDONNÉES ——————————
        if (body['lat'] != null && body['lng'] != null) {
          prefs.setDouble('lat', body['lat']);
          prefs.setDouble('lng', body['lng']);
        }

        // ———————— EMAIL ——————————
        // Si le backend ne renvoie pas d'email → on utilise celui entré par l’utilisateur
        final safeEmail = body['email'] ?? email;
        prefs.setString('email', safeEmail);

        // ———————— TOKEN ——————————
        prefs.setString('token', body['token']);

        // ———————— ROLE ——————————
        final role = body['role'] ?? 'user';
        prefs.setString('role', role);

        return {
          'success': true,
          'message': body['message'] ?? 'Connexion réussie',
          'token': body['token'],
          'email': safeEmail,
          'role': role,
          'lat': body['lat'],
          'lng': body['lng'],
        };
      }

      // ❌ échec : sécurisé
      return {
        'success': false,
        'message': body['message'] ?? 'Identifiants invalides',
      };

    } catch (e) {
      return {
        'success': false,
        'message': "Erreur réseau : ${e.toString()}",
      };
    }
  }


  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<Map<String, String>> _authHeaders({bool json = true}) async {
    final token = await _getToken();

    final headers = <String, String>{
      'Accept': 'application/json',
    };

    if (json) {
      headers['Content-Type'] = 'application/json';
    }

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<List<Map<String, dynamic>>> fetchProInbox() async {
    final headers = await _authHeaders(json: false);

    final res = await http.get(
      Uri.parse('$baseUrl/api/pro/messages'),
      headers: headers,
    );

    final body = jsonDecode(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is List) return body.cast<Map<String, dynamic>>();
      return [];
    }

    final msg = (body is Map && body['error'] != null)
        ? body['error'].toString()
        : 'Erreur ${res.statusCode}';
    throw Exception(msg);
  }


  Future<List<Map<String, dynamic>>> fetchProConversation(int clientId) async {
    final headers = await _authHeaders(json: false);

    final res = await http.get(
      Uri.parse('$baseUrl/api/pro/messages/$clientId'),
      headers: headers,
    );

    final body = jsonDecode(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is List) return body.cast<Map<String, dynamic>>();
      return [];
    }

    final msg = (body is Map && body['error'] != null)
        ? body['error'].toString()
        : 'Erreur ${res.statusCode}';
    throw Exception(msg);
  }


  Future<void> sendProMessage({
    required int clientId,
    required String content,
  }) async {
    final headers = await _authHeaders();

    final res = await http.post(
      Uri.parse('$baseUrl/api/pro/messages/$clientId'),
      headers: headers,
      body: jsonEncode({'content': content}),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    dynamic body;
    try { body = jsonDecode(res.body); } catch (_) {}
    final msg = (body is Map && body['error'] != null)
        ? body['error'].toString()
        : 'Erreur ${res.statusCode}';
    throw Exception(msg);
  }










  // ===============================
  // 🧩 Récupération du profil (/api/me)
  // ===============================
  Future<Map<String, dynamic>> getMe(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'user': body['user']};
      }

      return {
        'success': false,
        'message': body['message'] ?? '❌ Impossible de charger le profil',
      };
    } catch (e) {
      return {
        'success': false,
        'message': "🚫 Erreur réseau : ${e.toString()}",
      };
    }
  }

  Future<Map<String, dynamic>> fetchUserCoordinates(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        return {
          'success': true,
          'lat': body['user']['lat'],
          'lng': body['user']['lng'],
          'name': body['user']['name'],
          'lastname': body['user']['lastname'],
        };
      }

      return {
        'success': false,
        'message': body['message'] ?? 'Erreur lors de la récupération du profil'
      };
    } catch (e) {
      return {
        'success': false,
        'message': "Erreur réseau : ${e.toString()}",
      };
    }
  }




  Future<Map<String, dynamic>> registerUser({
    required String email,
    required String password,
    required String postalCode,
    required String city,
    required String name,
    required String lastname,

    // ✅ RIB
    String? ribIban,
    File? ribFile,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/register');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Accept'] = 'application/json';

      // ✅ champs texte
      request.fields.addAll({
        'email': email.trim(),
        'password': password,
        'postalCode': postalCode.trim(),
        'city': city.trim(),
        'role': 'ROLE_USER',
        'name': name.trim(),
        'lastname': lastname.trim(),
      });

      // ✅ IBAN optionnel (si tu en veux)
      if (ribIban != null && ribIban.trim().isNotEmpty) {
        request.fields['ribIban'] = ribIban.trim();
      }

      // ✅ fichier RIB optionnel
      if (ribFile != null) {
        request.files.add(await http.MultipartFile.fromPath('ribFile', ribFile.path));
      }

      final streamed = await request.send();
      final status = streamed.statusCode;
      final responseBody = await streamed.stream.bytesToString();

      dynamic decoded;
      try {
        decoded = jsonDecode(responseBody);
      } catch (_) {
        decoded = null;
      }

      if (status >= 200 && status < 300) {
        return {
          'success': true,
          'message': (decoded is Map && decoded['message'] != null)
              ? decoded['message'].toString()
              : "✅ Compte utilisateur créé avec succès !",
          'token': (decoded is Map) ? decoded['token'] : null,
          'user': (decoded is Map) ? decoded['user'] : null,
        };
      }

      // erreurs JSON
      if (decoded is Map) {
        // support "violations" si tu l’envoies
        if (decoded['violations'] is Map) {
          final violations = (decoded['violations'] as Map).cast<String, dynamic>();
          final msg = violations.entries.map((e) {
            final v = e.value;
            if (v is List) return "• ${v.join(' / ')}";
            return "• ${v.toString()}";
          }).join("\n");
          return {'success': false, 'message': "⚠️ Erreurs de validation :\n$msg"};
        }

        return {
          'success': false,
          'message': decoded['error']?.toString() ?? "❌ Erreur $status",
        };
      }

      // erreurs non JSON
      return {'success': false, 'message': "❌ Erreur $status\n$responseBody"};
    } catch (e) {
      return {'success': false, 'message': "🚫 Erreur réseau : $e"};
    }
  }




  // ===============================
  // 🧩 Enregistrement d’un professionnel
  // ===============================
  Future<Map<String, dynamic>> registerProfessional({
    required String email,
    required String password,
    required String fullName,
    required int specialityId,
    required String zone,
    required double pricePerHour,
    required String siret,
    required String phone,
    required String postalCode,

    required File assuranceFile,
    required File identityFile,
    required File proTitleFile,

    String? ribIban,
    File? ribFile,

    File? profilePicture,
  }) async {
    final uri = Uri.parse('$baseUrl/api/professionals');

    try {
      final request = http.MultipartRequest('POST', uri);

      // ✅ Important: ne JAMAIS définir Content-Type en multipart
      request.headers['Accept'] = 'application/json';

      // ✅ Champs texte (tout en string)
      request.fields.addAll({
        'email': email.trim(),
        'password': password,
        'fullName': fullName.trim(),
        'specialityId': specialityId.toString(),
        'zone': zone.trim(),
        'pricePerHour': pricePerHour.toString(),
        'siret': siret.trim(),
        'phone': phone.trim(),
        'postalCode': postalCode.trim(),
      });

      final iban = ribIban?.trim();
      if (iban != null && iban.isNotEmpty) {
        request.fields['ribIban'] = iban;
      }

      // ✅ Helper pour ajouter un fichier avec filename propre
      Future<void> addFile(String field, File f) async {
        request.files.add(
          await http.MultipartFile.fromPath(
            field,
            f.path,
            filename: p.basename(f.path),
          ),
        );
      }

      await addFile('assurance', assuranceFile);
      await addFile('identity', identityFile);
      await addFile('proTitle', proTitleFile);

      if (ribFile != null) await addFile('ribFile', ribFile);
      if (profilePicture != null) await addFile('profilePicture', profilePicture);


      // ✅ Debug minimal (tu peux enlever après)
      // print("URI => $uri");
      // print("FIELDS => ${request.fields}");
      // print("FILES => ${request.files.map((f) => "${f.field}:${f.filename}").toList()}");

      final streamed = await request.send();
      final status = streamed.statusCode;
      final responseBody = await streamed.stream.bytesToString();

      // JSON safe parse
      dynamic decoded;
      try {
        decoded = jsonDecode(responseBody);
      } catch (_) {
        decoded = null;
      }

      if (status >= 200 && status < 300) {
        final body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
        return {
          'success': true,
          'message': body['message']?.toString() ?? '✅ Inscription réussie',
          'proId': body['professional']?['id'],
          'companyName': body['professional']?['companyName'],
        };
      }

      // erreurs JSON
      if (decoded is Map<String, dynamic>) {
        if (decoded['violations'] is Map) {
          final violations = (decoded['violations'] as Map).cast<String, dynamic>();
          final messages = violations.entries.map((e) {
            final v = e.value;
            if (v is List) return "• ${v.join(' / ')}";
            return "• ${v.toString()}";
          }).join("\n");

          return {'success': false, 'message': "⚠️ Erreurs de validation :\n$messages"};
        }

        return {
          'success': false,
          'message': decoded['error']?.toString() ?? "❌ Erreur $status",
        };
      }

      // erreurs non JSON (HTML, texte)
      return {
        'success': false,
        'message': "❌ Erreur $status\n$responseBody",
      };
    } catch (e) {
      return {'success': false, 'message': "🚫 Erreur réseau : $e"};
    }
  }
  // ===============================
  // 📋 Récupération des spécialités
  // ===============================
  Future<List<Map<String, dynamic>>> fetchSpecialities() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/specialities'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(list);
      } else {
        throw Exception(
          "Erreur ${response.statusCode}: ${response.reasonPhrase}",
        );
      }
    } catch (e) {
      throw Exception("Erreur réseau : $e");
    }
  }

  // ===============================
  // 📸 Upload photo de profil professionnel
  // ===============================
  Future<String> uploadProfilePicture({
    required int proId,
    required File imageFile,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/professionals/$proId/upload'),
      );

      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      final response = await request.send();

      final responseBody = await response.stream.bytesToString();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return "✅ Photo envoyée avec succès";
      } else {
        return "❌ Erreur lors de l'envoi (${response.statusCode}): $responseBody";
      }
    } catch (e) {
      return "🚫 Erreur réseau : ${e.toString()}";
    }
  }

  // ===============================
// 🔍 Recherche de professionnels
// ===============================
  Future<List<Map<String, dynamic>>> searchProfessionals({
    String? speciality,
    String? zone,
    String? query,
    double? lat,
    double? lng,

  }) async {
    try {
      // Normalisation AVANT l’envoi API
      final normalizedSpeciality = speciality?.trim().toLowerCase();
      final normalizedZone = zone?.trim().toLowerCase();
      final normalizedQuery = query?.trim().toLowerCase();

      final uri = Uri.parse('$baseUrl/api/professionals/search').replace(
        queryParameters: {
          if (normalizedSpeciality != null && normalizedSpeciality.isNotEmpty)
            'speciality': normalizedSpeciality,
          if (normalizedZone != null && normalizedZone.isNotEmpty)
            'zone': normalizedZone,
          if (normalizedQuery != null && normalizedQuery.isNotEmpty)
            'query': normalizedQuery,
          if (lat != null) 'lat': lat.toString(),
          if (lng != null) 'lng': lng.toString(),

        },
      );

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(list);
      } else {
        throw Exception("Erreur ${response.statusCode}: ${response.reasonPhrase}");
      }
    } catch (e) {
      throw Exception("Erreur réseau : $e");
    }
  }


  Future<void> sendMessage({
    required int professionalId,
    required String content,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final res = await http.post(
      Uri.parse("$baseUrl/api/messages"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "professional_id": professionalId,
        "content": content,
      }),
    );

    print("STATUS: ${res.statusCode}");
    print("BODY: ${res.body}");

    if (res.statusCode != 200) {
      throw Exception("Erreur envoi message");
    }
  }

  Future<List<Map<String, dynamic>>> fetchConversation(int professionalId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final res = await http.get(
      Uri.parse("$baseUrl/api/messages/$professionalId"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Erreur chargement conversation");
    }

    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  }

  Future<void> createOffer({
    required int professionalId,
    required double price,
    String? message,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final res = await http.post(
      Uri.parse("$baseUrl/api/offers"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "professional_id": professionalId,
        "price": price,
        "message": message,
      }),
    );

    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception("Erreur création offre");
    }
  }






  // ===============================
  // 📥 Inbox USER (threads + unread)
  // ===============================
  Future<List<Map<String, dynamic>>> fetchUserInbox() async {
    final headers = await _authHeaders(json: false);

    // 🔥 Endpoint à créer côté Symfony (exemple)
    final res = await http.get(
      Uri.parse('$baseUrl/api/user/messages'),
      headers: headers,
    );

    print("USER INBOX STATUS: ${res.statusCode}");
    print("USER INBOX BODY: ${res.body}");

    dynamic body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      body = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is List) return body.cast<Map<String, dynamic>>();
      return [];
    }

    final msg = (body is Map && body['error'] != null)
        ? body['error'].toString()
        : 'Erreur ${res.statusCode}';
    throw Exception(msg);
  }


  Future<Map<String, dynamic>> sendSupportContact({
    required String email,
    required String subject,
    required String message,
  }) async {
    final headers = await _authHeaders(); // garde ton Bearer si connecté

    final res = await http.post(
      Uri.parse('$baseUrl/api/support/contact'),
      headers: headers,
      body: jsonEncode({
        "email": email,
        "subject": subject,
        "message": message,
      }),
    );

    dynamic body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      body = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return {
        "success": true,
        "message": (body is Map && body["message"] != null) ? body["message"] : "OK",
      };
    }

    return {
      "success": false,
      "message": (body is Map && body["error"] != null) ? body["error"] : "Erreur ${res.statusCode}",
    };
  }


  Future<Map<String, dynamic>> createPaymentIntentForOffer(int offerId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final res = await http.post(
      Uri.parse("$baseUrl/api/offers/$offerId/payment-intent"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    print("PAYMENT INTENT RES => ${res.statusCode} ${res.body}");

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Erreur payment-intent: ${res.body}");
    }

    return Map<String, dynamic>.from(jsonDecode(res.body));
  }



  Future<void> acceptOffer(int offerId) async {
    final headers = await _authHeaders();

    final res = await http.post(
      Uri.parse('$baseUrl/api/pro/offers/$offerId/accept'),
      headers: headers,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Erreur accept offer: ${res.statusCode}");
    }
  }

  Future<void> refuseOffer(int offerId) async {
    final headers = await _authHeaders();

    final res = await http.post(
      Uri.parse('$baseUrl/api/pro/offers/$offerId/refuse'),
      headers: headers,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Erreur refuse offer: ${res.statusCode}");
    }
  }

  Future<Map<String, dynamic>> getTransactionSummary(int offerId) async {
    final headers = await _authHeaders();

    final res = await http.get(
      Uri.parse('$baseUrl/api/offers/$offerId/transaction-summary'),
      headers: headers,
    );

    print("TRANSACTION SUMMARY => ${res.statusCode} ${res.body}");

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Erreur transaction summary: ${res.body}");
    }

    return Map<String, dynamic>.from(jsonDecode(res.body));
  }


  Future<void> rateOffer(int offerId, int value) async {
    final headers = await _authHeaders();

    final res = await http.post(
      Uri.parse('$baseUrl/api/offers/$offerId/rate'),
      headers: headers,
      body: jsonEncode({'value': value}),
    );

    print("RATE OFFER => ${res.statusCode} ${res.body}");

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Erreur notation: ${res.body}");
    }
  }













}



