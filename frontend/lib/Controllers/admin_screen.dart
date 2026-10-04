import 'package:flutter/material.dart';
import '../Screens/Mobile/admin_screen_mobile.dart';
import '../Screens/Tablet/admin_screen_tablet.dart';

/// Zobrazuje rozhranie s podporou adaptívneho layoutu.
///
/// Na základe šírky obrazovky vyberá vhodný widget –
/// mobilnú verziu pre menšie zariadenia (šírka < 600),
/// alebo tabletovú verziu pre väčšie obrazovky.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth >= 600) {
      // Tablet layout
      return const AdminScreenTablet();
    } else {
      // Mobile layout
      return const AdminScreenMobile();
    }
  }
}
