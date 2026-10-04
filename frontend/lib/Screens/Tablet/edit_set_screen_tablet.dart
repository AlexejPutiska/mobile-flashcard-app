import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../models.dart';
import '../../main.dart';

/// Obrazovka pre úpravu existujúcej sady kartičiek v tabletovom rozhraní.
///
/// Používateľ môže upraviť názov sady, zobraziť existujúce kartičky,
/// meniť ich obsah alebo ich vymazať. Môže tiež pridať novú kartičku.
/// Súčasťou obrazovky je aj možnosť vymazať celú sadu.
class EditSetScreenTablet extends StatefulWidget {
  final FlashcardSet flashcardSet;

  const EditSetScreenTablet({super.key, required this.flashcardSet});

  @override
  State<EditSetScreenTablet> createState() => _EditSetScreenState();
}

class _EditSetScreenState extends State<EditSetScreenTablet> {
  final TextEditingController _setNameController = TextEditingController();
  List<Map<String, dynamic>> cards = [];
  bool _loading = true;
  late int _setId;

  late String _originalName;

  /// Inicializuje stav obrazovky a načíta pôvodné hodnoty:
  /// - názov sady z `widget.flashcardSet`
  /// - zoznam kartičiek pomocou [_loadFlashcards].
  @override
  void initState() {
    super.initState();
    _setId = widget.flashcardSet.setId;
    _originalName = widget.flashcardSet.name;
    _setNameController.text = _originalName;

    _setNameController.addListener(() {
      setState(() {});
    });

    _loadFlashcards();
  }

  /// Načíta všetky kartičky pre daný set z API a uloží ich do `cards`.
  Future<void> _loadFlashcards() async {
    try {
      final result = await ApiService().loadSetWithFlashcards(_setId);
      final List<dynamic> fetchedCards = result['cards'];

      setState(() {
        cards =
            fetchedCards
                .map<Map<String, dynamic>>(
                  (f) => {
                    'flashcardId': f['flashcard_id'],
                    'front': f['front_side'] ?? '',
                    'back': f['back_side'] ?? '',
                    'image_front': f['image_front'],
                  },
                )
                .toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint("Error loading flashcards: $e");
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  /// Overí, či má používateľ zadaný vlastný názov sady.
  bool _isValidCustomName() {
    final trimmed = _setNameController.text.trim();
    return trimmed.isNotEmpty;
  }

  /// Overí, či sa názov sady zmenil oproti pôvodnému.
  bool _hasUnsavedChanges() {
    return _setNameController.text.trim() != _originalName.trim();
  }

  /// Zobrazí potvrdzovací dialóg na zmazanie celej sady.
  /// Ak používateľ potvrdí, zavolá [ApiService.deleteSet] a vráti sa späť.
  Future<void> _confirmAndDeleteSet() async {
    final isLargeText = MyApp.of(context)?.isLargeText ?? false;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Delete set?',
              style: TextStyle(
                fontSize: isLargeText ? 24 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Are you sure you want to delete this set? This action cannot be undone.',
              style: TextStyle(fontSize: isLargeText ? 20 : 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(fontSize: isLargeText ? 20 : 16),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Delete',
                  style: TextStyle(fontSize: isLargeText ? 20 : 16),
                ),
              ),
            ],
          ),
    );

    if (shouldDelete == true) {
      final success = await ApiService().deleteSet(_setId);
      if (success) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to delete set')));
      }
    }
  }

  /// Zobrazí dialóg, keď sa používateľ pokúsi opustiť obrazovku so zmenami.
  /// Ak nie sú zmeny, vráti `true`. Inak vyžiada potvrdenie.
  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges()) return true;

    final isLargeText = MyApp.of(context)?.isLargeText ?? false;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Discard name change?',
              style: TextStyle(
                fontSize: isLargeText ? 24 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'You have unsaved changes to the set name. Do you want to leave without saving the new name?',
              style: TextStyle(fontSize: isLargeText ? 20 : 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'No',
                  style: TextStyle(fontSize: isLargeText ? 20 : 16),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Yes',
                  style: TextStyle(fontSize: isLargeText ? 20 : 16),
                ),
              ),
            ],
          ),
    );

    return (shouldDiscard == true);
  }

  /// Vytvorí a vráti UI obrazovky pre editáciu sady.
  /// Zobrazuje pole pre názov, zoznam kartičiek a akcie „Update“ a „Delete“.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;
    final cardColor = isDark ? Colors.grey[800] : Colors.grey[200];
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final isLargeText = MyApp.of(context)?.isLargeText ?? false;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: theme.appBarTheme.backgroundColor,
          centerTitle: true,
          leading: Padding(
            padding: const EdgeInsets.only(left: 20),
            child: InkWell(
              borderRadius: BorderRadius.circular(32),
              onTap: () async {
                final canPop = await _onWillPop();
                if (canPop && mounted) Navigator.pop(context);
              },
              child: Icon(
                Icons.arrow_back,
                color: theme.iconTheme.color,
                size: 32,
              ),
            ),
          ),
          title: Text(
            'Edit set',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: isLargeText ? FontWeight.bold : FontWeight.w500,
              fontSize: isLargeText ? 34 : null,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT: Set name and card list
              Expanded(
                flex: 2,
                child: ListView(
                  children: [
                    const SizedBox(height: 10),
                    TextField(
                      controller: _setNameController,
                      maxLength: 16,
                      style: TextStyle(fontSize: isLargeText ? 24 : null),
                      decoration: InputDecoration(
                        labelText: 'Set name',
                        labelStyle: TextStyle(
                          color: textColor,
                          fontSize: isLargeText ? 23 : null,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      buildCounter: (
                        BuildContext context, {
                        required int currentLength,
                        required bool isFocused,
                        required int? maxLength,
                      }) {
                        return Text(
                          '$currentLength/$maxLength',
                          style: TextStyle(
                            fontSize: isLargeText ? 18 : null,
                            color: theme.hintColor,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    ...cards.asMap().entries.map((entry) {
                      final card = entry.value;
                      final frontText = card['front']?.trim() ?? '';
                      final imageFront = card['image_front'];
                      final displayName =
                          frontText.isNotEmpty
                              ? frontText
                              : (imageFront != null ? '[image]' : '');

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          height: isLargeText ? 66 : 56,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  displayName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: isLargeText ? 22 : 16,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.edit,
                                  size: isLargeText ? 28 : 22,
                                ),
                                color: theme.iconTheme.color,
                                onPressed: () async {
                                  final result = await Navigator.pushNamed(
                                    context,
                                    '/editcard',
                                    arguments: card['flashcardId'],
                                  );
                                  if (!mounted) return;

                                  if (result == 'deleted') {
                                    await _loadFlashcards();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Card was deleted'),
                                      ),
                                    );
                                  } else if (result == true) {
                                    try {
                                      final updated = await ApiService()
                                          .getFlashcardById(
                                            card['flashcardId'],
                                          );
                                      setState(() {
                                        cards[entry.key] = {
                                          'flashcardId':
                                              updated['flashcard_id'],
                                          'front': updated['front_side'] ?? '',
                                          'back': updated['back_side'] ?? '',
                                          'image_front': updated['image_front'],
                                        };
                                      });
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Card was updated'),
                                        ),
                                      );
                                    } catch (e) {
                                      debugPrint(
                                        "Error loading the updated card: $e",
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(width: 32),

              // RIGHT: Add button + action buttons
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    InkWell(
                      onTap: () async {
                        final result = await Navigator.pushNamed(
                          context,
                          '/newcard',
                          arguments: _setId,
                        );

                        if (result != null && result is Map<String, dynamic>) {
                          final front = result['front'] ?? '';
                          final back = result['back'] ?? '';
                          final id = result['id'];
                          final imageFront = result['image_front'];

                          setState(() {
                            cards.add({
                              'flashcardId': id,
                              'front': front,
                              'back': back,
                              'image_front': imageFront,
                            });
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Card was added')),
                          );
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add,
                            size: isLargeText ? 36 : 26,
                            color: theme.iconTheme.color,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'add card',
                            style: TextStyle(
                              fontSize: isLargeText ? 25 : 18,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed:
                          !_isValidCustomName()
                              ? null
                              : () async {
                                final newName = _setNameController.text.trim();
                                if (newName != _originalName) {
                                  await ApiService().updateSetName(
                                    _setId,
                                    newName,
                                  );
                                }
                                Navigator.pop(context, true);
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        elevation: 3,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Update set',
                        style: TextStyle(
                          fontSize: isLargeText ? 22 : 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async => await _confirmAndDeleteSet(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        elevation: 3,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Delete set',
                        style: TextStyle(
                          fontSize: isLargeText ? 22 : 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
