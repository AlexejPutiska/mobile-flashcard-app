# StudyBro app

The Flutter client of StudyBro. Every screen exists twice, as a phone and as a tablet version, and the classes in `lib/Controllers` choose one by screen width (the limit is 600 pixels). Data comes from the REST API through `lib/api_service.dart`, and Hive keeps an offline copy of the sets (`lib/offline_models.dart`).

## Run

Point the app at your backend first: its address is in `lib/api_service.dart` and in the two home screens. Then, on an Android device or emulator:

```bash
flutter pub get
flutter run
```

It was checked with Flutter 3.29.2.

## Generated files

`lib/offline_models.g.dart` comes from `build_runner` and belongs to the Hive models.
