import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../api_service.dart';
import 'package:hive/hive.dart';
import '../../offline_models.dart';
import '../../connectivity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../../main.dart';

/// Model internej kartičky obsahujúcej prednú a zadnú stranu.
/// Môže obsahovať buď text alebo obrázok pre každú stranu.
class _Flashcard {
  final String frontText;
  final String backText;
  final Uint8List? frontImage;
  final Uint8List? backImage;

  const _Flashcard({
    required this.frontText,
    required this.backText,
    this.frontImage,
    this.backImage,
  });
}

/// Obrazovka učenia sa kartičiek pre mobilné zariadenia.
///
/// Zobrazuje kartičky (text alebo obrázok), umožňuje ich otáčať, označovať správne/nesprávne
/// a zaznamenáva štatistiky o učení.
///
/// Podporuje režim offline cez Hive a režim hosťa (bez ukladania štatistík).
///
/// Po úspešnom dokončení sady sa zobrazí gratulačná obrazovka.
class LearningScreenMobile extends StatefulWidget {
  final int setId;
  const LearningScreenMobile({super.key, required this.setId});

  @override
  State<LearningScreenMobile> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreenMobile>
    with SingleTickerProviderStateMixin {
  // PRIDANÉ PRE ŠTATISTIKY
  late DateTime _sessionStart;
  int _correctCount = 0;
  int _totalCount = 0;

  late final AnimationController _controller;
  late final Animation<double> _animation;

  final List<_Flashcard> _cards = [];
  int _currentIndex = 0;
  bool _isFrontSide = true;
  bool _isLoading = true;
  late bool _isGuest;

  /// Inicializuje stav komponentu, nastavenie animácie a načítanie kartičiek.
  @override
  void initState() {
    super.initState();
    // začiatok sedenia
    FirebaseAnalytics.instance.logEvent(name: 'learning_started');
    _sessionStart = DateTime.now();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = Tween<double>(begin: 0, end: pi).animate(_controller);

    _initGuestStatus().then((_) => _loadCards());
  }

  /// Zistí, či má aktuálny používateľ rolu hosťa (guest).
  Future<void> _initGuestStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    _isGuest = role != 'user' && role != 'admin';
  }

  /// Základné dekódovanie base64 reťazcov na obrázky.
  Uint8List? _decode(String? base64) {
    if (base64 == null || base64.isEmpty) return null;
    final cleaned = base64.replaceAll(RegExp(r'[^A-Za-z0-9+/=]+'), '');
    return base64Decode(cleaned);
  }

  /// Alternatívna kontrola roly hosťa.
  /// Používané na oddelenie načítavania public vs. private sád.
  Future<bool> isGuestUser() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    return role != 'user' && role != 'admin';
  }

  /// Načíta kartičky podľa režimu (online/offline + guest).
  /// V prípade chyby sa zobrazí hláška a návrat späť.
  Future<void> _loadCards() async {
    final isOnline = await ConnectivityService.isOnline();

    if (isOnline) {
      try {
        final isGuest = await isGuestUser();
        List<dynamic> raw;

        if (isGuest) {
          raw = await ApiService().getPublicFlashcardsBySet(widget.setId);
        } else {
          final data = await ApiService().loadSetWithFlashcards(widget.setId);
          raw = data['cards'] as List<dynamic>;
        }

        //final raw = data['cards'] as List<dynamic>;

        if (raw.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This set has no flashcards.')),
          );
          Navigator.pop(context);
          return;
        }

        for (final c in raw) {
          _cards.add(
            _Flashcard(
              frontText: c['front_side'] ?? '',
              backText: c['back_side'] ?? '',
              frontImage: _decode(c['image_front']),
              backImage: _decode(c['image_back']),
            ),
          );
        }

        setState(() => _isLoading = false);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to load cards: $e')));
          Navigator.pop(context);
        }
      }
    } else {
      final box = Hive.box<OfflineFlashcardSet>('offlineSets');
      final offlineSet = box.values.firstWhere(
        (s) => s.setId == widget.setId,
        orElse:
            () => OfflineFlashcardSet(
              setId: 0,
              name: '',
              isPublic: false,
              userId: 0,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              flashcards: [],
            ),
      );

      if (offlineSet.flashcards.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This set has no flashcards.')),
          );
          Navigator.pop(context);
        }
        return;
      }

      for (final c in offlineSet.flashcards) {
        _cards.add(
          _Flashcard(
            frontText: c.front,
            backText: c.back,
            frontImage: c.imageFront,
            backImage: c.imageBack,
          ),
        );
      }

      setState(() => _isLoading = false);
    }
  }

  /// Vyčistí animáciu pri zrušení komponentu
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Spustí animáciu pre otočenie kartičky.
  void _flipCard() {
    if (_isFrontSide) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() => _isFrontSide = !_isFrontSide);
  }

  /// Resetuje animáciu a nastaví kartu späť na prednú stranu.
  void _resetCardSide() {
    _isFrontSide = true;
    _controller.reset();
  }

  /// Odosiela údaje o učení na backend.
  /// Hosťovský režim túto akciu preskočí.
  Future<void> _submitSession() async {
    if (_isGuest) return; // Guest neodosiela nic
    final endTime = DateTime.now();
    try {
      await ApiService().submitLearningSession(
        startTime: _sessionStart,
        endTime: endTime,
        correct: _correctCount,
        total: _totalCount,
      );
      // pripadne zobraz snackBar alebo ina UX odozva
    } catch (e) {
      // log alebo upozornit pouzivatela
      debugPrint('Error submitting session: $e');
    }
  }

  /// Používateľ označil, že vedel správnu odpoveď.
  /// Odstráni aktuálnu kartu a ak je posledná, odošle štatistiky.
  void _onKnewIt() {
    _correctCount++;
    _totalCount++;
    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() {
        _cards.removeAt(_currentIndex);
        if (_cards.isEmpty) {
          _resetCardSide();
          _submitSession(); // po poslednej karte odosli session

          return;
        }
        _currentIndex %= _cards.length;
        _resetCardSide();
      });
    });
  }

  /// Používateľ označil, že nevedel odpoveď.
  /// Posunie sa na ďalšiu kartu.
  void _onDidNotKnow() {
    _totalCount++;
    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() {
        _currentIndex = (_currentIndex + 1) % _cards.length;
        if (_cards.isEmpty) {
          _submitSession(); // ── ak by cards prazdne (extra istota)
          return;
        }
        _resetCardSide();
      });
    });
  }

  /// Vytvorí widget pre prednú alebo zadnú stranu kartičky.
  /// Môže obsahovať text alebo obrázok.
  Widget _buildContent(bool isBack) {
    final isLargeText = MyApp.of(context)?.isLargeText ?? false;
    final c = _cards[_currentIndex];
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyLarge?.copyWith(
      fontSize: isLargeText ? 25 : 18,
    );

    if (isBack) {
      return c.backImage != null
          ? Image.memory(
            c.backImage!,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          )
          : Text(c.backText, textAlign: TextAlign.center, style: textStyle);
    } else {
      return c.frontImage != null
          ? Image.memory(
            c.frontImage!,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          )
          : Text(c.frontText, textAlign: TextAlign.center, style: textStyle);
    }
  }

  /// Vytvára vizuálne rozhranie celej obrazovky učenia.
  /// Obsahuje animované preklápanie kartičky a ovládacie tlačidlá.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final frontCardColor = isDark ? Colors.grey[850]! : const Color(0xFFE1E1E1);
    final backCardColor = isDark ? Colors.grey[700]! : const Color(0xFFC1C1C1);
    final iconColor = theme.iconTheme.color;
    final isLargeText = MyApp.of(context)?.isLargeText ?? false;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_cards.isEmpty) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.emoji_events_rounded,
                  size: isLargeText ? 120 : 100,
                  color: Colors.amber[600],
                ),
                const SizedBox(height: 32),
                Text(
                  'Well done!',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isLargeText ? 50 : 35,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'You’ve completed all flashcards in this set.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: isLargeText ? 26 : 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  label: const Text('Go back'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    textStyle: TextStyle(fontSize: isLargeText ? 26 : 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: () => Navigator.pop(context),
            child: Icon(
              Icons.arrow_back,
              color: iconColor,
              size: isLargeText ? 40 : 32,
            ),
          ),
        ),
        title: Text(
          '${_currentIndex + 1}/${_cards.length}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: isLargeText ? 36 : 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _flipCard,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: Tween<double>(begin: 0.85, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.decelerate,
                      ),
                    ),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: SizedBox(
                  key: ValueKey(_cards[_currentIndex]),
                  width: 360,
                  height: 540,
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, _) {
                      final isBack = _animation.value >= pi / 2;
                      return Transform(
                        alignment: Alignment.center,
                        transform:
                            Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateY(_animation.value),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isBack ? backCardColor : frontCardColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform(
                                alignment: Alignment.center,
                                transform:
                                    isBack
                                        ? Matrix4.rotationY(pi)
                                        : Matrix4.identity(),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    24,
                                    24,
                                    48,
                                  ),
                                  child: _buildContent(isBack),
                                ),
                              ),
                              Positioned(
                                bottom: 12,
                                child: Icon(
                                  Icons.sync,
                                  size: 28,
                                  color: isDark ? Colors.white : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  iconSize: isLargeText ? 80 : 60,
                  onPressed: _onDidNotKnow,
                  icon: Icon(Icons.close, color: iconColor),
                ),
                IconButton(
                  iconSize: isLargeText ? 80 : 60,
                  onPressed: _onKnewIt,
                  icon: Icon(Icons.check, color: iconColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
