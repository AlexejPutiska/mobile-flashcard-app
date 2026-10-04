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

/// Hlavná domovská obrazovka aplikácie pre mobilné zariadenia.
///
/// Zobrazuje nedávno pridané sady, umožňuje vytvárať nové sady,
/// prezerať štatistiky, navigovať do nastavení a zobraziť public sady v reálnom čase.
///
/// Komunikuje s backendom pomocou REST API a WebSocketov a podporuje aj offline režim pomocou Hive.
class HomeScreenMobile extends StatefulWidget {
  const HomeScreenMobile({super.key});

  @override
  State<HomeScreenMobile> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreenMobile> {
  late IO.Socket socket;

  /// Pripája sa k WebSocket serveru a reaguje na udalosti ako `newPublicSet`.
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

  /// Inicializuje socket, používateľské meno a nedávne sady.
  @override
  void initState() {
    super.initState();
    connectSocket();
    _loadUsername();
    _loadRecentSets();
  }

  bool _loading = true;

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
      //final stats = await ApiService().getStatistics();
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
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 50, 20, 0),
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          username,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight:
                                isLargeText ? FontWeight.bold : FontWeight.w600,
                            fontSize: isLargeText ? 38 : 22,
                          ),
                        ),
                        const Spacer(),
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
                            size: isLargeText ? 45 : 38,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 5),
                          child: Text(
                            'Recently added:',
                            style: TextStyle(
                              fontSize: isLargeText ? 23 : 16,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final online =
                                  await ConnectivityService.isOnline();
                              if (!online) {
                                if (mounted) {
                                  await showDialog(
                                    context: context,
                                    builder: (ctx) {
                                      final isLargeText =
                                          MyApp.of(context)?.isLargeText ??
                                          false;
                                      return AlertDialog(
                                        title: Text(
                                          'Offline',
                                          style: TextStyle(
                                            fontSize: isLargeText ? 32 : 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        content: Text(
                                          'You are offline – creating a set requires internet connection',
                                          style: TextStyle(
                                            fontSize: isLargeText ? 28 : 18,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.of(ctx).pop(),
                                            child: Text(
                                              'OK',
                                              style: TextStyle(
                                                fontSize: isLargeText ? 30 : 20,
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

                              final result = await Navigator.pushNamed(
                                context,
                                '/create',
                              );
                              await Future.delayed(
                                const Duration(milliseconds: 10),
                              );
                              if (!mounted) return;
                              if (result != null) {
                                _loadRecentSets();
                              }
                            },
                            icon: Icon(Icons.add, size: isLargeText ? 27 : 20),
                            label: Text(
                              'Add',
                              style: TextStyle(fontSize: isLargeText ? 23 : 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6546C3),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 25,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (recentlyAdded.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 16),
                              Text(
                                'No sets yet',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: isLargeText ? 30 : 20,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap the Add button to create your first set.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: isLargeText ? 28 : 16,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...recentlyAdded.map((set) {
                        return InkWell(
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/learn',
                              arguments: set.setId,
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(top: 10, bottom: 20),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color:
                                    theme.brightness == Brightness.dark
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade300,
                              ),
                            ),
                            height: isLargeText ? 70 : 54,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              set.name,
                              style: TextStyle(
                                fontSize: isLargeText ? 30 : 16,
                                fontWeight:
                                    isLargeText
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }),

                    const Spacer(),

                    Container(
                      padding: const EdgeInsets.only(bottom: 50),
                      height: 140,
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          GestureDetector(
                            onTap: () async {
                              await Navigator.pushNamed(context, '/sets');
                              _loadRecentSets();
                            },
                            child: Container(
                              width: isLargeText ? 150 : 130,
                              height: isLargeText ? 120 : 90,
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                FontAwesomeIcons.listUl,
                                size: isLargeText ? 60 : 40,
                              ),
                            ),
                          ),
                          const SizedBox(width: 1),
                          GestureDetector(
                            onTap: () => _navigateToStatistics(context),
                            child: Container(
                              width: isLargeText ? 150 : 130,
                              height: isLargeText ? 120 : 90,
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                FontAwesomeIcons.chartColumn,
                                size: isLargeText ? 60 : 40,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
      ),
    );
  }
}
