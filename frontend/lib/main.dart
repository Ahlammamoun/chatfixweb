import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/user_register_page.dart';
import 'pages/professional_register_page.dart';
import 'pages/user_home_page.dart';
import 'pages/professional_home_page.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'pages/transaction_summary_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Stripe.publishableKey = 'pk_live_51FpejlK9Q2TyiugcJQHFelHbKeO4VhmNlPF7q2PlDV0EgxysFtUYKUbo1ZniO7s1jXunu25b3b9jkMBweVAqQes200hA1NzOqq';
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ChatFix',
      theme: ThemeData(
        primaryColor: const Color(0xFF1976D2),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomePage(),
      routes: {
        '/login': (_) => const LoginPage(),
        '/register_user': (_) => const UserRegisterPage(),
        '/register_pro': (_) => const ProfessionalRegisterPage(),
        '/user_home': (context) => const UserHomePage(email: ''),
        '/pro_home': (context) => const ProfessionalHomePage(email: ''),
        '/transaction-summary': (context) => const TransactionSummaryPage(),
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🔹 Fond dégradé bleu clair
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🔹 Logo ChatFix
                  Image.asset(
                    'assets/chatfix_logo.png',
                    height: 150,
                  ),
                  const SizedBox(height: 45),

                  // 🔹 Titre d’accueil
                  const Text(
                    'Bienvenue sur ChatFix',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choisissez votre option pour commencer',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // 🔹 Bouton utilisateur
                  _buildMainButton(
                    context,
                    label: "Créer un compte utilisateur",
                    icon: Icons.person_outline,
                    onPressed: () => Navigator.pushNamed(context, '/register_user'),
                  ),
                  const SizedBox(height: 16),

                  // 🔹 Bouton professionnel
                  _buildMainButton(
                    context,
                    label: "Créer un compte professionnel",
                    icon: Icons.work_outline,
                    onPressed: () => Navigator.pushNamed(context, '/register_pro'),
                  ),
                  const SizedBox(height: 16),

                  // 🔹 Bouton connexion
                  _buildOutlinedButton(
                    context,
                    label: "Se connecter",
                    icon: Icons.login,
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🧩 Bouton principal arrondi
  Widget _buildMainButton(BuildContext context,
      {required String label,
        required IconData icon,
        required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1976D2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 3,
        ),
      ),
    );
  }

  // 🧩 Bouton secondaire (contour)
  Widget _buildOutlinedButton(BuildContext context,
      {required String label,
        required IconData icon,
        required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: const Color(0xFF1976D2)),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1976D2),
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF1976D2), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
