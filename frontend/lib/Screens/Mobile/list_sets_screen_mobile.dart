import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../main.dart';
import '../../api_service.dart';
import '../../connectivity_service.dart';
import '../../models.dart';
import '../../offline_models.dart';
import 'dart:typed_data';
import 'dart:convert';

/// Obrazovka pre zobrazenie všetkých flashcard sád používateľa.
///
/// Podporuje online a offline režim.
/// V offline režime načítava sady z Hive a v online režime synchronizuje z backendu.
///
/// Umožňuje používateľovi:
/// - prezerať si sady,
/// - upravovať ich (iba online),
/// - vytvárať nové sady (iba online).
class ListOfSetsScreenMobile extends StatefulWidget {
  const ListOfSetsScreenMobile({Key? key}) : super(key: key);

  @override
  State<ListOfSetsScreenMobile> createState() => _ListOfSetsScreenState();
}

/// Stav pre `ListOfSetsScreenMobile`.
///
/// Zodpovedá za:
/// - načítanie sád z online alebo offline zdroja,
/// - správu loadera,
/// - dekódovanie obrázkov z base64,
/// - vytváranie a editovanie sád.
class _ListOfSetsScreenState extends State<ListOfSetsScreenMobile> {
  /// online / offline dáta
  List<FlashcardSet> _sets = [];

  /// na zobrazenie loadera
  bool _loading = true;

  /// Pomocná metóda pre dekódovanie base64 reťazca na obrázok.
  /// Používa sa pri ukladaní obrázkov kartičiek.
  Uint8List? _decodeBase64(String? base64) {
    if (base64 == null || base64.isEmpty) return null;
    final cleaned = base64.replaceAll(RegExp(r'[^A-Za-z0-9+/=]+'), '');
    return base64Decode(cleaned);
  }

  /// Inicializuje stav obrazovky a načíta sady pri štarte.
  @override
  void initState() {
    super.initState();
    _loadSets();
  }

  /// Načíta sady – ak je online, stiahne z backendu a uloží do Hive.
  /// Ak nie je online, načíta z Hive (offline režim).
  Future<void> _loadSets() async {
    setState(() => _loading = true);

    final box = Hive.box<OfflineFlashcardSet>('offlineSets');
    final online = await ConnectivityService.isOnline();

    if (online) {
      try {
        debugPrint('Online – stahujem zo servera');
        final remoteSets =
            await ApiService().fetchSets()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        await box.clear();

        await Future.wait(
          remoteSets.map((set) async {
            final data = await ApiService().loadSetWithFlashcards(set.setId);

            final offlineCards =
                (data['cards'] as List).map((c) {
                  return OfflineFlashcard(
                    front: c['front_side'],
                    back: c['back_side'],
                    imageFront: _decodeBase64(c['image_front']),
                    imageBack: _decodeBase64(c['image_back']),
                  );
                }).toList();

            await box.add(
              OfflineFlashcardSet(
                setId: set.setId,
                name: set.name,
                isPublic: set.isPublic,
                userId: set.userId,
                createdAt: set.createdAt,
                updatedAt: set.updatedAt,
                flashcards: offlineCards,
              ),
            );
          }),
        );

        setState(() => _sets = remoteSets);
      } catch (e) {
        debugPrint('Chyba pri stahovani: $e');
        _loadFromHive(box);
      }
    } else {
      debugPrint('Offline – nacitavam z Hive');
      _loadFromHive(box);
    }

    setState(() => _loading = false);
  }

  /// Načíta sady z Hive databázy a prevedie ich na `FlashcardSet` objekty.
  void _loadFromHive(Box<OfflineFlashcardSet> box) {
    final local =
        box.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _sets =
        local
            .map(
              (s) => FlashcardSet(
                setId: s.setId,
                name: s.name,
                isPublic: s.isPublic,
                userId: s.userId,
                createdAt: s.createdAt,
                updatedAt: s.updatedAt,
              ),
            )
            .toList();
  }

  /// Vytvára vizuálne rozhranie obrazovky.
  /// Zobrazuje zoznam sád a umožňuje navigáciu na ich učenie alebo úpravu.
  /// Podporuje veľké písmo podľa nastavení aplikácie.
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isLargeText = MyApp.of(context)?.isLargeText ?? false;
    return Scaffold(
      backgroundColor: t.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: t.scaffoldBackgroundColor,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back, color: t.iconTheme.color, size: 32),
          ),
        ),
        title: Text(
          'List of your sets',
          style: t.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: isLargeText ? 30 : null,
          ),
        ),
      ),

      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _sets.isEmpty
              ? Center(
                child: Text(
                  "You don't have any flashcard sets yet",
                  style: t.textTheme.bodyMedium?.copyWith(
                    color: t.hintColor,
                    fontSize: isLargeText ? 25 : null,
                  ),
                ),
              )
              : ListView.builder(
                itemCount: _sets.length,
                itemBuilder: (ctx, i) {
                  final set = _sets[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color:
                              t.brightness == Brightness.dark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300,
                        ),
                      ),
                      color: t.cardColor,
                      elevation: 1.5,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap:
                            () => Navigator.pushNamed(
                              ctx,
                              '/learn',
                              arguments: set.setId,
                            ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            height: isLargeText ? 80 : 64,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  set.name,
                                  style: t.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    fontSize: isLargeText ? 28 : null,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.edit,
                                    size: isLargeText ? 30 : 25,
                                  ),
                                  color: t.iconTheme.color,
                                  onPressed: () async {
                                    final online =
                                        await ConnectivityService.isOnline();
                                    if (!online) {
                                      if (mounted) {
                                        await showDialog(
                                          context: context,
                                          builder: (ctx) {
                                            final isLargeText =
                                                MyApp.of(
                                                  context,
                                                )?.isLargeText ??
                                                false;
                                            return AlertDialog(
                                              title: Text(
                                                'Offline',
                                                style: TextStyle(
                                                  fontSize:
                                                      isLargeText ? 32 : 22,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              content: Text(
                                                'You are offline – editing is available only online',
                                                style: TextStyle(
                                                  fontSize:
                                                      isLargeText ? 28 : 18,
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () =>
                                                          Navigator.of(
                                                            ctx,
                                                          ).pop(),
                                                  child: Text(
                                                    'OK',
                                                    style: TextStyle(
                                                      fontSize:
                                                          isLargeText ? 30 : 20,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      }
                                      return;
                                    }
                                    final ok = await Navigator.pushNamed(
                                      ctx,
                                      '/editset',
                                      arguments: set,
                                    );
                                    if (ok == true) _loadSets();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 48),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final online = await ConnectivityService.isOnline();
            if (!online) {
              if (mounted) {
                await showDialog(
                  context: context,
                  builder: (ctx) {
                    final isLargeText = MyApp.of(context)?.isLargeText ?? false;
                    return AlertDialog(
                      title: Text(
                        'Offline',
                        style: TextStyle(
                          fontSize: isLargeText ? 32 : 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      content: Text(
                        'You are offline – creating a set requires connection',
                        style: TextStyle(fontSize: isLargeText ? 28 : 18),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text(
                            'OK',
                            style: TextStyle(fontSize: isLargeText ? 30 : 20),
                          ),
                        ),
                      ],
                    );
                  },
                );
              }
              return;
            }

            final created = await Navigator.pushNamed(context, '/create');
            if (created == true) _loadSets();
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: isLargeText ? 62 : 42,
                height: isLargeText ? 62 : 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: t.iconTheme.color ?? Colors.black),
                ),
                child: Icon(
                  Icons.add,
                  size: isLargeText ? 30 : 24,
                  color: t.iconTheme.color,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Create a New Set',
                style: t.textTheme.titleMedium?.copyWith(
                  fontSize: isLargeText ? 24 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
