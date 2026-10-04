import 'package:flutter/material.dart';
import '../../api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Obrazovka prihlasovania pre mobilné zariadenia.
///
/// Obsahuje možnosť:
/// - prihlásiť sa ako registrovaný používateľ (user/admin),
/// - prihlásiť sa ako hosť (bez registrácie),
/// - prejsť na registračnú obrazovku.
///
/// Využíva:
/// - `SharedPreferences` na lokálne uloženie mena a hashovaného hesla,
/// - `FirebaseAnalytics` na logovanie udalostí,
/// - `ApiService` na komunikáciu s backendom.
class LoginMobile extends StatefulWidget {
  const LoginMobile({super.key});

  @override
  State<LoginMobile> createState() => _LoginMobileState();
}

/// Stav triedy `LoginMobile`.
///
/// Spravuje vstupné polia, spúšťa autentifikáciu a reaguje na výsledok:
/// - Ukladá údaje lokálne pri úspešnom logine.
/// - Presmeruje na `/admin`, `/home` alebo `/guest`.
/// - Zobrazí snackbary pri chybných vstupoch alebo neúspechu.
class _LoginMobileState extends State<LoginMobile> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  /// Spracuje prihlasovanie používateľa.
  ///
  /// Ak sú vstupné údaje validné, zavolá `ApiService().login()` a uloží
  /// údaje do `SharedPreferences`:
  /// - lokálne používateľské meno,
  /// - SHA256 hash hesla.
  ///
  /// Presmeruje používateľa podľa roly na `/admin` alebo `/home`.
  void handleLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fill in all fields')));
      return;
    }

    final api = ApiService();
    final success = await api.login(email, password);

    if (success) {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('role');

      await prefs.setString('local_username', email);
      await prefs.setString(
        'local_password_hash',
        sha256.convert(utf8.encode(password)).toString(),
      );

      FirebaseAnalytics.instance.logEvent(name: 'login_success');

      Navigator.pushReplacementNamed(
        context,
        role == 'admin' ? '/admin' : '/home',
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Successful Login')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Login Failed')));
    }
  }

  /// Spracuje prihlásenie hosťa.
  ///
  /// Zavolá `ApiService().guestLogin()` a po úspechu presmeruje na `/guest`.
  void handleGuestLogin() async {
    final response = await ApiService().guestLogin();
    if (response) {
      FirebaseAnalytics.instance.logEvent(name: 'guest_login');
      Navigator.pushReplacementNamed(context, '/guest');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to log in as Guest')),
      );
    }
  }

  /// Vytvára rozhranie prihlasovacej obrazovky.
  ///
  /// Obsahuje:
  /// - logo aplikácie,
  /// - textové polia pre email a heslo,
  /// - tlačidlo Login,
  /// - tlačidlo prechodu na registráciu,
  /// - možnosť pokračovať ako hosť.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.school, size: 96),
              const SizedBox(height: 32),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: handleLogin,
                child: const Text('Login'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/register');
                },
                child: const Text('Don\'t have an account? Register'),
              ),
              OutlinedButton(
                onPressed: handleGuestLogin,
                child: const Text('Continue as Guest'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
