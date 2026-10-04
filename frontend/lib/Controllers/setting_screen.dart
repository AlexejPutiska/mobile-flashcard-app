import 'package:flutter/material.dart';
import '../Screens/Mobile/setting_screen_mobile.dart';
import '../Screens/Tablet/setting_screen_tablet.dart';

/// Zobrazuje rozhranie s podporou adaptívneho layoutu.
///
/// Na základe šírky obrazovky vyberá vhodný widget –
/// mobilnú verziu pre menšie zariadenia (šírka < 600),
/// alebo tabletovú verziu pre väčšie obrazovky.
class SettingScreen extends StatelessWidget {
  const SettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth >= 600) {
      // Tablet layout
      return const SettingScreenTablet();
    } else {
      // Mobile layout
      return const SettingScreenMobile();
    }
  }
}
