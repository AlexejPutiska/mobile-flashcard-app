// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OfflineFlashcardSetAdapter extends TypeAdapter<OfflineFlashcardSet> {
  @override
  final int typeId = 0;

  @override
  OfflineFlashcardSet read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineFlashcardSet(
      setId: fields[0] as int,
      name: fields[1] as String,
      isPublic: fields[2] as bool,
      flashcards: (fields[3] as List).cast<OfflineFlashcard>(),
      userId: fields[4] as int,
      createdAt: fields[5] as DateTime,
      updatedAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineFlashcardSet obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.setId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.isPublic)
      ..writeByte(3)
      ..write(obj.flashcards)
      ..writeByte(4)
      ..write(obj.userId)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineFlashcardSetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OfflineFlashcardAdapter extends TypeAdapter<OfflineFlashcard> {
  @override
  final int typeId = 1;

  @override
  OfflineFlashcard read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineFlashcard(
      front: fields[0] as String,
      back: fields[1] as String,
      imageFront: fields[2] as Uint8List?,
      imageBack: fields[3] as Uint8List?,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineFlashcard obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.front)
      ..writeByte(1)
      ..write(obj.back)
      ..writeByte(2)
      ..write(obj.imageFront)
      ..writeByte(3)
      ..write(obj.imageBack);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineFlashcardAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
