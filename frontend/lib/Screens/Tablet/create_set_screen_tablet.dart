import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../main.dart';

/// CreateSetScreenTablet slúži na vytvorenie nového flashcard setu v tabletovej verzii.
///
/// Po otvorení obrazovky sa automaticky vytvorí "Untitled set", ktorý sa
/// používateľovi zobrazuje s možnosťou premenovania.
///
/// Používateľ môže:
/// - pridať nové kartičky,
/// - upraviť existujúce kartičky,
/// - premenovať set,
/// - zrušiť tvorbu a zmazať set (ak opustí obrazovku).
///
/// Všetky požiadavky na backend sa vykonávajú prostredníctvom [ApiService].
class CreateSetScreenTablet extends StatefulWidget {
  const CreateSetScreenTablet({super.key});

  @override
  State<CreateSetScreenTablet> createState() => _CreateSetScreenState();
}

/// Stavová trieda pre [CreateSetScreenMobile].
///
/// Obsahuje logiku pre:
/// - vytvorenie počiatočného setu (v [initState]),
/// - validáciu mena setu,
/// - aktualizáciu mena setu na backende,
/// - odstránenie setu pri zrušení operácie,
/// - zobrazovanie a spracovanie flashcard kariet.
class _CreateSetScreenState extends State<CreateSetScreenTablet> {
  /// Kontrolér pre názov setu.
  final TextEditingController _setNameController = TextEditingController();

  /// Zoznam všetkých flashcard kariet pridaných do setu.
  List<Map<String, dynamic>> cards = [];

  /// ID setu v databáze.
  int? _setId;

  /// Indikácia načítavania.
  bool _loading = true;

  /// Pôvodné meno setu (napr. "Untitled set").
  String _originalName = '';

  @override
  void initState() {
    super.initState();
    _setNameController.addListener(() {
      setState(() {});
    });
    _createInitialSet();
  }

  /// Vytvorí dočasný set s názvom ako "Untitled set" a uloží jeho ID.
  Future<void> _createInitialSet() async {
    int counter = 1;
    int? createdId;
    String name;

    while (createdId == null && counter <= 100) {
      name = counter == 1 ? 'Untitled set' : 'Untitled set ($counter)';
      createdId = await ApiService().createSet(name: name, isPublic: false);

      if (createdId != null) {
        setState(() {
          _setId = createdId;
          _setNameController.text = '';
          _originalName = name;
          _loading = false;
        });
        return;
      }

      counter++;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Failed to create set')));
    Navigator.of(context).pop();
  }

  /// Overuje, či meno setu je platné (musí byť neprázdne a nie "Untitled").
  bool _isValidCustomName() {
    final trimmed = _setNameController.text.trim();
    return trimmed.isNotEmpty && !trimmed.startsWith('Untitled set');
  }

  /// Odstráni set zo servera podľa jeho ID.
  Future<void> _deleteSet() async {
    if (_setId != null) {
      await ApiService().deleteSet(_setId!);
    }
  }

  /// Zobrazí potvrdenie pri pokuse o opustenie obrazovky.
  /// Ak používateľ potvrdí, zmaže sa aj vytvorený set
  Future<bool> _onWillPop() async {
    final isLargeText = MyApp.of(context)?.isLargeText ?? false;

    final shouldLeave =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(
                  'Discard changes?',
                  style: TextStyle(
                    fontSize: isLargeText ? 24 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Text(
                  'You have unsaved changes. Do you really want to leave?',
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
        ) ==
        true;

    if (shouldLeave) {
      await _deleteSet();
    }
    return shouldLeave;
  }

  /// Buduje používateľské rozhranie pre tvorbu setu v tabletovom režime.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLargeText = MyApp.of(context)?.isLargeText ?? false;
    final textColor = theme.textTheme.bodyMedium?.color;
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[800] : Colors.grey[200];

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: theme.appBarTheme.backgroundColor,
          centerTitle: true,
          leading: Padding(
            padding: const EdgeInsets.only(left: 20),
            child: InkWell(
              borderRadius: BorderRadius.circular(32),
              onTap: () async {
                if (await _onWillPop()) {
                  Navigator.of(context).pop(true);
                }
              },
              child: Icon(
                Icons.arrow_back,
                size: 32,
                color: theme.iconTheme.color,
              ),
            ),
          ),
          title: Text(
            'New set',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: isLargeText ? 34 : null,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT SIDE: Set name + Add Card
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _setNameController,
                      maxLength: 16,
                      style: TextStyle(fontSize: isLargeText ? 24 : null),
                      decoration: InputDecoration(
                        labelText: 'Enter set name',
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
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.pushNamed(
                          context,
                          '/newcard',
                          arguments: _setId,
                        );
                        if (result is Map<String, dynamic>) {
                          setState(() {
                            cards.add({
                              'flashcardId': result['id'],
                              'front': result['front'],
                              'back': result['back'],
                              'image_front': result['image_front'],
                            });
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Card was added')),
                          );
                        }
                      },
                      icon: Icon(Icons.add, size: isLargeText ? 30 : 24),
                      label: Text(
                        'Add Card',
                        style: TextStyle(fontSize: isLargeText ? 22 : 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 48),

              // RIGHT SIDE: List of Cards
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (cards.isEmpty)
                      Center(
                        child: Text(
                          'No cards added yet.',
                          style: TextStyle(
                            fontSize: isLargeText ? 22 : 18,
                            color: theme.hintColor,
                          ),
                        ),
                      ),
                    if (cards.isNotEmpty)
                      Expanded(
                        child: ListView.builder(
                          itemCount: cards.length,
                          itemBuilder: (context, index) {
                            final card = cards[index];
                            final front =
                                (card['front'] as String?)?.trim() ?? '';
                            final imageFront = card['image_front'];
                            final displayName =
                                front.isNotEmpty
                                    ? front
                                    : (imageFront != null ? '[image]' : '');

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                height: isLargeText ? 66 : 56,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displayName,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontSize: isLargeText ? 22 : 16,
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
                                        final flashcardId = card['flashcardId'];
                                        if (flashcardId != null) {
                                          final result =
                                              await Navigator.pushNamed(
                                                context,
                                                '/editcard',
                                                arguments: flashcardId,
                                              );
                                          if (result == 'deleted') {
                                            setState(
                                              () => cards.removeAt(index),
                                            );
                                          } else if (result == true) {
                                            final updated = await ApiService()
                                                .getFlashcardById(flashcardId);
                                            setState(() {
                                              cards[index] = {
                                                'flashcardId':
                                                    updated['flashcard_id'],
                                                'front':
                                                    updated['front_side'] ?? '',
                                                'back':
                                                    updated['back_side'] ?? '',
                                                'image_front':
                                                    updated['image_front'],
                                              };
                                            });
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed:
                      (_setId == null || !_isValidCustomName())
                          ? null
                          : () async {
                            final newName = _setNameController.text.trim();
                            if (newName != _originalName) {
                              await ApiService().updateSetName(
                                _setId!,
                                newName,
                              );
                            }
                            Navigator.of(context).pop(true);
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Create set',
                    style: TextStyle(
                      fontSize: isLargeText ? 25 : 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              if (!_isValidCustomName())
                Text(
                  'You must change the set name',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: isLargeText ? 19 : 14,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
