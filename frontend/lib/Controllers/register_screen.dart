import 'package:flutter/material.dart';
import '../Screens/Mobile/register_screen_mobile.dart';
import '../Screens/Tablet/register_screen_tablet.dart';

/// Zobrazuje rozhranie s podporou adaptívneho layoutu.
///
/// Na základe šírky obrazovky vyberá vhodný widget –
/// mobilnú verziu pre menšie zariadenia (šírka < 600),
/// alebo tabletovú verziu pre väčšie obrazovky.
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth >= 600) {
      return const RegisterScreenTablet();
    } else {
      return const RegisterScreenMobile();
    }
  }
}
