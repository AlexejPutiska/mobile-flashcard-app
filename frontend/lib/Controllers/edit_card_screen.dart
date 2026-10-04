import 'package:flutter/material.dart';
import '../../../Screens/Mobile/edit_card_screen_mobile.dart';
import '../../../Screens/Tablet/edit_card_screen_tablet.dart';

/// Zobrazuje rozhranie s podporou adaptívneho layoutu.
///
/// Na základe šírky obrazovky vyberá vhodný widget –
/// mobilnú verziu pre menšie zariadenia (šírka < 600),
/// alebo tabletovú verziu pre väčšie obrazovky.
class EditCardScreen extends StatelessWidget {
  final int flashcardId;

  const EditCardScreen({super.key, required this.flashcardId});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth >= 600) {
      return EditCardScreenTablet(flashcardId: flashcardId);
    } else {
      return EditCardScreenMobile(flashcardId: flashcardId);
    }
  }
}
