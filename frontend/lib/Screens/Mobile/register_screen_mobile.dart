import 'package:flutter/material.dart';
import '../../api_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Registrácia pre mobilné zariadenia.
///
/// Obrazovka umožňuje vytvoriť nový používateľský účet.
/// Obsahuje validáciu mena, e-mailu a hesla.
/// Po úspešnej registrácii presmeruje na prihlasovaciu obrazovku.
class RegisterScreenMobile extends StatefulWidget {
  const RegisterScreenMobile({super.key});

  @override
  State<RegisterScreenMobile> createState() => _RegisterScreenMobileState();
}

/// Stavová trieda pre registráciu používateľa.
///
/// Validuje vstupy pomocou regulárnych výrazov.
/// Volá `ApiService().register()` na registráciu používateľa.
/// Zobrazuje vizuálnu spätnú väzbu pre každý vstup pomocou ikonky.
class _RegisterScreenMobileState extends State<RegisterScreenMobile> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isNameValid = false;
  bool isEmailValid = false;
  bool isPasswordValid = false;

  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  final nameRegex = RegExp(r'^[a-zA-Zá-žÁ-Ž\s]{2,}$');

  /// Spracuje registráciu po kliknutí na tlačidlo.
  ///
  /// - Validuje vstupy.
  /// - Ak sú údaje správne, pokúsi sa zaregistrovať používateľa.
  /// - V prípade úspechu zobrazí snackbar a presmeruje na login.
  /// - Pri neúspechu zobrazí chybové hlásenie.
  void handleRegister() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (!isNameValid || !isEmailValid || !isPasswordValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter all data correctly !')),
      );
      return;
    }

    final api = ApiService();
    final success = await api.register(name, email, password);

    if (success) {
      FirebaseAnalytics.instance.logEvent(name: 'register_success');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Registration Succesful')));
      Navigator.pushNamed(context, '/login');
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Registration Failed')));
    }
  }

  /// Vytvára `TextField` s validáciou.
  ///
  /// Používa sa pre meno, e-mail a heslo.
  /// Každý vstup má ikonu (✔️ alebo ❌) indikujúcu správnosť.
  Widget _buildValidatedField({
    required String label,
    required TextEditingController controller,
    required bool isValid,
    required void Function(String) onChanged,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            isValid ? Icons.check_circle : Icons.cancel,
            key: ValueKey<bool>(isValid),
            color: isValid ? Colors.green : Colors.red,
          ),
        ),
      ),
    );
  }

  /// Vytvára samotné rozhranie registračnej obrazovky.
  ///
  /// Obsahuje tri vstupné polia a dve tlačidlá.
  /// - `Register` aktivuje `handleRegister()`.
  /// - `Login` presmeruje na prihlasovaciu obrazovku.
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
              const Icon(Icons.person_add, size: 96),
              const SizedBox(height: 32),
              _buildValidatedField(
                label: 'Name',
                controller: nameController,
                isValid: isNameValid,
                onChanged: (value) {
                  setState(() {
                    isNameValid = nameRegex.hasMatch(value.trim());
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildValidatedField(
                label: 'Email',
                controller: emailController,
                isValid: isEmailValid,
                onChanged: (value) {
                  setState(() {
                    isEmailValid = emailRegex.hasMatch(value.trim());
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildValidatedField(
                label: 'Password',
                controller: passwordController,
                isValid: isPasswordValid,
                obscureText: true,
                onChanged: (value) {
                  setState(() {
                    isPasswordValid = value.trim().length >= 6;
                  });
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: handleRegister,
                child: const Text('Register'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                child: const Text('Do you have an Account ? --> Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
