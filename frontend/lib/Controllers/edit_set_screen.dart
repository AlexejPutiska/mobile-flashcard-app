import 'package:flutter/material.dart';
import '../Screens/Mobile/edit_set_screen_mobile.dart';
import '../Screens/Tablet/edit_set_screen_tablet.dart';
import '../../models.dart';

/// Zobrazuje rozhranie s podporou adaptívneho layoutu.
///
/// Na základe šírky obrazovky vyberá vhodný widget –
/// mobilnú verziu pre menšie zariadenia (šírka < 600),
/// alebo tabletovú verziu pre väčšie obrazovky.
class EditSetScreen extends StatelessWidget {
  const EditSetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // ✅ Získaj argument od Navigatora
    final flashcardSet =
        ModalRoute.of(context)?.settings.arguments as FlashcardSet;

    if (screenWidth >= 600) {
      // ✅ Tablet layout s argumentom
      return EditSetScreenTablet(flashcardSet: flashcardSet);
    } else {
      // ✅ Mobile layout s argumentom
      return EditSetScreenMobile(flashcardSet: flashcardSet);
    }
  }
}
