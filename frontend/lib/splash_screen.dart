import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'api_service.dart';
import 'Controllers/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

/// Načítavacia obrazovka aplikácie (SplashScreen).
///
/// Zodpovedá za:
/// - overenie JWT tokenu (online autorizácia),
/// - prípadne offline login podľa lokálne uložených údajov,
/// - automatickú navigáciu na správnu obrazovku (Home, Admin, Guest alebo Login),
/// - prípravu FCM tokenu na odoslanie.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// Stavová trieda pre `SplashScreen`.
///
/// Obsahuje logiku pre autorizáciu používateľa a prihlásenie
/// (online aj offline) ešte pred zobrazením hlavnej obrazovky.
class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    checkAuth();
  }

  /// Funkcia na hashovanie hesla pomocou SHA-256.
  ///
  /// Používa sa pri offline login validácii.
  String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  /// Overuje autentifikáciu používateľa pri štarte aplikácie.
  ///
  /// Funguje v 3 krokoch:
  /// 1. Online – ak je token platný, používateľa presmeruje podľa roly.
  /// 2. Offline fallback – ak sú uložené prihlasovacie údaje, prihlási bez internetu.
  /// 3. Inak presmeruje na prihlasovaciu obrazovku (`LoginScreen`).
  Future<void> checkAuth() async {
    final token = await ApiService().getToken();
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    final username = prefs.getString('local_username');
    final passwordHash = prefs.getString('local_password_hash');

    // 1. Online overenie tokenu
    if (token != null && role != null) {
      try {
        final isValid = await ApiService().verifyToken(token);
        if (isValid) {
          if (role == 'admin') {
            Navigator.pushReplacementNamed(context, '/admin');
          } else if (role == 'host') {
            Navigator.pushReplacementNamed(context, '/guest');
          } else {
            Navigator.pushReplacementNamed(context, '/home');
          }
          return;
        }
      } catch (e) {
        debugPrint('⚠️ Online token overenie zlyhalo: $e');
        // pokračujeme ďalej
      }
    }

    // 2. Offline fallback login – ak sú uložené údaje
    if (username != null && passwordHash != null) {
      debugPrint('🔌 Offline login: prihlásený ako $username');
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }

    // 3. Inak ideš na LoginScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  /// Získava FCM (Firebase Cloud Messaging) token a posiela ho na backend.
  ///
  /// Token sa použije na push notifikácie. Funguje iba ak je používateľ online.
  Future<void> getAndSendFcmToken() async {
    try {
      debugPrint('ZÍSKAVAM FCM token...');
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      debugPrint('FCM token je: $fcmToken');

      if (fcmToken != null) {
        final jwtToken = await ApiService().getToken();
        if (jwtToken != null) {
          await ApiService().sendTokenToBackend(fcmToken, jwtToken);
        }
      }
    } catch (e) {
      print('Chyba pri získavaní alebo odosielaní FCM tokenu: $e');
    }
  }

  /// Vizuálna časť obrazovky (iba loader).
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
