/// Modelová trieda pre flashcard set.
///
/// Obsahuje informácie o:
/// - ID setu,
/// - ID používateľa,
/// - názve setu,
/// - verejnosti setu (`isPublic`),
/// - dátumoch vytvorenia a poslednej aktualizácie.
///
/// Používa sa na reprezentáciu flashcard setu v aplikácii.
class FlashcardSet {
  final int setId;
  final int userId;
  final String name;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;

  FlashcardSet({
    required this.setId,
    required this.userId,
    required this.name,
    required this.isPublic,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory konštruktor na vytvorenie inštancie zo JSON objektu.
  factory FlashcardSet.fromJson(Map<String, dynamic> json) {
    return FlashcardSet(
      setId: json['set_id'],
      userId: json['user_id'],
      name: json['name'],
      isPublic: json['is_public_fyn'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

/// Modelová trieda pre jednotlivú flashcard.
///
/// Obsahuje:
/// - ID kartičky,
/// - ID setu, do ktorého patrí,
/// - názov kartičky,
/// - prednú a zadnú stranu (text),
/// - typ dát (`text`, `picture`).
///
/// Táto trieda sa používa pri načítavaní a zobrazovaní kartičiek.
class Flashcard {
  final int flashcardId;
  final int setId;
  final String name;
  final String front;
  final String back;
  final String dataType;

  Flashcard({
    required this.flashcardId,
    required this.setId,
    required this.name,
    required this.front,
    required this.back,
    required this.dataType,
  });

  /// Factory konštruktor na vytvorenie flashcard zo JSON objektu.
  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      flashcardId: json['flashcard_id'],
      setId: json['set_id'],
      name: json['name'],
      front: json['front_side'],
      back: json['back_side'],
      dataType: json['data_type'],
    );
  }
}
