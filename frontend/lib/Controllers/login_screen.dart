import 'package:flutter/material.dart';
import '../Screens/Mobile/login_screen_mobile.dart';
import '../Screens/Tablet/login_screen_tablet.dart';

/// Zobrazuje rozhranie s podporou adaptívneho layoutu.
///
/// Na základe šírky obrazovky vyberá vhodný widget –
/// mobilnú verziu pre menšie zariadenia (šírka < 600),
/// alebo tabletovú verziu pre väčšie obrazovky.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth >= 600) {
      return const LoginTablet();
    } else {
      return const LoginMobile();
    }
  }
}
