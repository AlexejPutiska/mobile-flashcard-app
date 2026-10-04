import 'package:hive/hive.dart';
import 'dart:typed_data';

part 'offline_models.g.dart';

/// Model pre offline uložený flashcard set pomocou Hive.
///
/// Obsahuje:
/// - ID setu, názov a verejnosť,
/// - zoznam kartičiek (`OfflineFlashcard`),
/// - údaje o vlastníkovi (userId),
/// - dátum vytvorenia a poslednej úpravy.
///
/// Tento model sa používa pri offline režime aplikácie.
@HiveType(typeId: 0)
class OfflineFlashcardSet extends HiveObject {
  @HiveField(0)
  int setId;

  @HiveField(1)
  String name;

  @HiveField(2)
  bool isPublic;

  @HiveField(3)
  List<OfflineFlashcard> flashcards;

  @HiveField(4)
  int userId;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime updatedAt;

  OfflineFlashcardSet({
    required this.setId,
    required this.name,
    required this.isPublic,
    required this.flashcards,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// Model pre jednu offline flashcard uloženú v Hive.
///
/// Obsahuje:
/// - prednú a zadnú stranu ako texty,
/// - voliteľne obrázky (vo formáte `Uint8List`),
///   ktoré reprezentujú binárne dáta.
///
/// Používa sa spolu s `OfflineFlashcardSet` v offline režime.
@HiveType(typeId: 1)
class OfflineFlashcard extends HiveObject {
  @HiveField(0)
  String front;

  @HiveField(1)
  String back;

  @HiveField(2)
  Uint8List? imageFront;

  @HiveField(3)
  Uint8List? imageBack;

  OfflineFlashcard({
    required this.front,
    required this.back,
    this.imageFront,
    this.imageBack,
  });
}
