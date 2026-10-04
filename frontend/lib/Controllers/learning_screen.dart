import 'package:flutter/material.dart';
import '../Screens/Mobile/learning_screen_mobile.dart';
import '../Screens/Tablet/learning_screen_tablet.dart';

/// Zobrazuje rozhranie s podporou adaptívneho layoutu.
///
/// Na základe šírky obrazovky vyberá vhodný widget –
/// mobilnú verziu pre menšie zariadenia (šírka < 600),
/// alebo tabletovú verziu pre väčšie obrazovky.
class LearningScreen extends StatelessWidget {
  final int setId;
  const LearningScreen({super.key, required this.setId});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth >= 600) {
      return LearningScreenTablet(setId: setId);
    } else {
      return LearningScreenMobile(setId: setId);
    }
  }
}
