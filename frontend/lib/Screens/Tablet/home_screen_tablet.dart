import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../api_service.dart';
import '../../Controllers/statistics_screen.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../main.dart';
import '../../models.dart';
import '../../connectivity_service.dart';
import 'package:hive/hive.dart';
import '../../offline_models.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Hlavná domovská obrazovka aplikácie pre tabletove zariadenia.
///
/// Zobrazuje nedávno pridané sady, umožňuje vytvárať nové sady,
/// prezerať štatistiky, navigovať do nastavení a zobraziť public sady v reálnom čase.
///
/// Komunikuje s backendom pomocou REST API a WebSocketov a podporuje aj offline režim pomocou Hive.
class HomeScreenTablet extends StatefulWidget {
  const HomeScreenTablet({super.key});

  @override
  State<HomeScreenTablet> createState() => _HomeScreenTabletState();
}

class _HomeScreenTabletState extends State<HomeScreenTablet> {
  late IO.Socket socket;

  /// Pripája sa k WebSocket serveru a reaguje na udalosti ako `newPublicSet`.s
  void connectSocket() {
    socket = IO.io('https://backend-mtaa.onrender.com', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket.onConnect((_) {
      print('Pripojeny na WebSocket');
    });

    socket.on('newPublicSet', (data) {
      print('📬 Prisla realtime sada: ${data['title']}');
      final context = navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📚 New Public Set: ${data['title']}'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    });

    socket.onDisconnect((_) => print('WebSocket odpojeny'));
  }

  List<FlashcardSet> recentlyAdded = [];
  String username = 'Loading...';
  bool _loading = true;

  /// Inicializuje socket, používateľské meno a nedávne sady.
  @override
  void initState() {
    super.initState();
    connectSocket();
    _loadUsername();
    _loadRecentSets();
  }

  /// Načíta meno aktuálne prihláseného používateľa.
  Future<void> _loadUsername() async {
    final user = await ApiService().getCurrentUser();
    if (user != null && mounted) {
      setState(() {
        username = user['name'] ?? 'User';
      });
    }
  }

  Uint8List? _decodeBase64(String? base64) {
    if (base64 == null || base64.isEmpty) return null;
    final cleaned = base64.replaceAll(RegExp(r'[^A-Za-z0-9+/=]+'), '');
    return base64Decode(cleaned);
  }

  /// Načíta najnovšie sady.
  /// V prípade offline režimu použije lokálne uložené dáta z Hive.
  Future<void> _loadRecentSets() async {
    setState(() => _loading = true);
    final online = await ConnectivityService.isOnline();
    final box = Hive.box<OfflineFlashcardSet>('offlineSets');

    if (online) {
      try {
        final remoteSets =
            await ApiService().fetchSets()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        await box.clear();

        await Future.wait(
          remoteSets.map((set) async {
            final fullSet = await ApiService().loadSetWithFlashcards(set.setId);
            final offlineFlashcards =
                (fullSet['cards'] as List).map((card) {
                  return OfflineFlashcard(
                    front: card['front_side'],
                    back: card['back_side'],
                    imageFront: _decodeBase64(card['image_front']),
                    imageBack: _decodeBase64(card['image_back']),
                  );
                }).toList();

            final offlineSet = OfflineFlashcardSet(
              setId: set.setId,
              name: set.name,
              isPublic: set.isPublic,
              userId: set.userId,
              createdAt: set.createdAt,
              updatedAt: set.updatedAt,
              flashcards: offlineFlashcards,
            );

            await box.add(offlineSet);
          }),
        );
        if (!mounted) return;
        setState(() {
          recentlyAdded = remoteSets.reversed.take(4).toList();
        });
      } catch (e) {
        print('Chyba pri fetchnuti dat: $e');
        _loadFromHive(box);
      }
    } else {
      print('Offline – Hive fallback');
      _loadFromHive(box);
    }

    setState(() => _loading = false);
  }

  /// Načíta sady z Hive boxu a prevedie ich na online model `FlashcardSet`.
  void _loadFromHive(Box<OfflineFlashcardSet> box) {
    final local =
        box.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    setState(() {
      recentlyAdded =
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
              .take(4)
              .toList();
    });
  }

  /// Naviguje používateľa na obrazovku štatistík.
  /// Zaznamenáva akciu pomocou Firebase Analytics.
  void _navigateToStatistics(BuildContext context) async {
    try {
      FirebaseAnalytics.instance.logEvent(name: 'statistics_opened');
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const StatisticsScreen()),
      );
      _loadRecentSets();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Statistics are only available Online")),
      );
    }
  }

  /// Vytvára vizuálne rozhranie domovskej obrazovky.
  ///
  /// Obsahuje:
  /// - Pozdrav používateľovi
  /// - Tlačidlo na pridanie novej sady
  /// - Zoznam nedávno pridaných sád (alebo výzvu na pridanie)
  /// - Navigáciu do `/sets` a `/statistics`
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLargeText = MyApp.of(context)?.isLargeText ?? false;
    final textScale = isLargeText ? 1.3 : 1.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(80, 50, 80, 30),
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.grey,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            username,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontSize: isLargeText ? 40 : 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            final result = await Navigator.pushNamed(
                              context,
                              '/settings',
                            );
                            if (result == true && mounted) {
                              setState(() {});
                            }
                          },
                          icon: Icon(
                            Icons.settings,
                            size: isLargeText ? 42 : 32,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recently added:',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: isLargeText ? 26 : 20,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final online = await ConnectivityService.isOnline();
                            if (!online && mounted) {
                              await showDialog(
                                context: context,
                                builder:
                                    (ctx) => AlertDialog(
                                      title: Text(
                                        'Offline',
                                        style: TextStyle(
                                          fontSize: isLargeText ? 30 : 22,
                                        ),
                                      ),
                                      content: Text(
                                        'You are offline – creating a set requires internet connection',
                                        style: TextStyle(
                                          fontSize: isLargeText ? 26 : 18,
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.of(ctx).pop(),
                                          child: Text(
                                            'OK',
                                            style: TextStyle(
                                              fontSize: isLargeText ? 28 : 20,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                              );
                              return;
                            }
                            final result = await Navigator.pushNamed(
                              context,
                              '/create',
                            );
                            await Future.delayed(
                              const Duration(milliseconds: 10),
                            );
                            if (!mounted) return;
                            if (result != null) _loadRecentSets();
                          },
                          icon: Icon(Icons.add, size: isLargeText ? 28 : 22),
                          label: Text(
                            'Add',
                            style: TextStyle(fontSize: isLargeText ? 22 : 18),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6546C3),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 25,
                              vertical: 12,
                            ),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Flashcard sets
                    recentlyAdded.isEmpty
                        ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            'No sets yet.',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: isLargeText ? 24 : 18,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                        )
                        : Wrap(
                          spacing: 20,
                          runSpacing: 20,
                          children:
                              recentlyAdded.map((set) {
                                return InkWell(
                                  onTap:
                                      () => Navigator.pushNamed(
                                        context,
                                        '/learn',
                                        arguments: set.setId,
                                      ),
                                  child: Container(
                                    width: 220,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.cardColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color:
                                            theme.brightness == Brightness.dark
                                                ? Colors.grey.shade700
                                                : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      set.name,
                                      style: TextStyle(
                                        fontSize: isLargeText ? 24 : 18,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),

                    const Spacer(),

                    // Bottom actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _actionButton(
                          icon: FontAwesomeIcons.listUl,
                          onTap: () async {
                            await Navigator.pushNamed(context, '/sets');
                            _loadRecentSets();
                          },
                          isLargeText: isLargeText,
                        ),
                        const SizedBox(width: 30),
                        _actionButton(
                          icon: FontAwesomeIcons.chartColumn,
                          onTap: () => _navigateToStatistics(context),
                          isLargeText: isLargeText,
                        ),
                      ],
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isLargeText,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isLargeText ? 110 : 90,
        height: isLargeText ? 110 : 90,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: isLargeText ? 50 : 38),
      ),
    );
  }
}
