import 'package:flutter/material.dart';
import '../Screens/Mobile/create_set_screen_mobile.dart';
import '../Screens/Tablet/create_set_screen_tablet.dart';

/// Zobrazuje rozhranie s podporou adaptívneho layoutu.
///
/// Na základe šírky obrazovky vyberá vhodný widget –
/// mobilnú verziu pre menšie zariadenia (šírka < 600),
/// alebo tabletovú verziu pre väčšie obrazovky.
class CreateSetScreen extends StatelessWidget {
  const CreateSetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth >= 600) {
      return CreateSetScreenTablet();
    } else {
      return CreateSetScreenMobile();
    }
  }
}
